#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTROL="$ROOT/control/control"
PAYLOAD="$ROOT/payload"
PAYLOAD_APP="$ROOT/payload/Applications/Showcase.app"
BUILD="$ROOT/build"
REMOTE_BASE="${REMOTE_BASE:-/tmp/showcase-deb-build}"

IPAD_HOST="${IPAD_HOST:-localhost}"
IPAD_PORT="${IPAD_PORT:-2222}"
IPAD_USER="${IPAD_USER:-root}"
IPAD_PASS="${IPAD_PASS:-alpine}"

SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -p "$IPAD_PORT"
)

SCP_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -P "$IPAD_PORT"
)

field() {
  awk -F': ' -v key="$1" '$1 == key { print $2; exit }' "$CONTROL"
}

PKG="$(field Package)"
VER="$(field Version)"
ARCH="$(field Architecture)"
DEB_NAME="${PKG}_${VER}_${ARCH}.deb"

if [ ! -d "$PAYLOAD_APP" ]; then
  echo "Missing payload: $PAYLOAD_APP"
  echo "Run scripts/fetch-installed-app.sh first."
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/showcase-rootful.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/rootfs" "$WORK/rootfs/DEBIAN" "$BUILD" "$ROOT/repo/debs"

cp -R "$PAYLOAD"/. "$WORK/rootfs"/
cp "$ROOT/control/control" "$WORK/rootfs/DEBIAN/control"
cp "$ROOT/control/postinst" "$WORK/rootfs/DEBIAN/postinst"
cp "$ROOT/control/prerm" "$WORK/rootfs/DEBIAN/prerm"
cp "$ROOT/control/postrm" "$WORK/rootfs/DEBIAN/postrm"

find "$WORK/rootfs" -name '.DS_Store' -delete
find "$WORK/rootfs" -name '._*' -delete
xattr -cr "$WORK/rootfs" 2>/dev/null || true

COPYFILE_DISABLE=1 tar --format ustar -C "$WORK" -cf "$WORK/rootfs.tar" rootfs

sshpass -p "$IPAD_PASS" ssh "${SSH_OPTS[@]}" "$IPAD_USER@$IPAD_HOST" \
  "rm -rf '$REMOTE_BASE' && mkdir -p '$REMOTE_BASE'"

sshpass -p "$IPAD_PASS" scp "${SCP_OPTS[@]}" \
  "$WORK/rootfs.tar" \
  "$IPAD_USER@$IPAD_HOST:$REMOTE_BASE/rootfs.tar"

sshpass -p "$IPAD_PASS" ssh "${SSH_OPTS[@]}" "$IPAD_USER@$IPAD_HOST" "
set -e
cd '$REMOTE_BASE'
tar xf rootfs.tar
cd rootfs
find . -name '._*' -delete
find . -name '.DS_Store' -delete

chown root:wheel .
chown -R root:wheel Applications usr Library DEBIAN
chmod 0755 . Applications Applications/Showcase.app usr usr/bin usr/lib Library Library/LaunchDaemons
chmod 0644 Applications/Showcase.app/Info.plist Applications/Showcase.app/Icon*.png
chmod 4755 Applications/Showcase.app/Showcase Applications/Showcase.app/carplay_bt Applications/Showcase.app/carplay_services
chmod 0755 usr/bin/BTdaemon usr/lib/libBTstack.dylib
chmod 0644 Library/LaunchDaemons/ch.ringwald.BTstack.plist
chmod 0755 DEBIAN/postinst DEBIAN/prerm DEBIAN/postrm
chmod 0644 DEBIAN/control

find . -path ./DEBIAN -prune -o -type f -exec md5sum {} \\; > DEBIAN/md5sums
chmod 0644 DEBIAN/md5sums

dpkg-deb -Zgzip -z9 -b . '../$DEB_NAME'
dpkg-deb -I '../$DEB_NAME'
dpkg-deb -c '../$DEB_NAME' | sed -n '1,80p'
"

sshpass -p "$IPAD_PASS" scp "${SCP_OPTS[@]}" \
  "$IPAD_USER@$IPAD_HOST:$REMOTE_BASE/$DEB_NAME" \
  "$BUILD/$DEB_NAME"

cp "$BUILD/$DEB_NAME" "$ROOT/repo/debs/$DEB_NAME"

echo "Built $BUILD/$DEB_NAME"
echo "Copied repo payload to $ROOT/repo/debs/$DEB_NAME"
