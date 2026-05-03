# Requirements

End users who install the `.deb` need a rootful iPad, Personal Hotspot, and the runtime packages declared by APT. They do not need a compiler, SDK, headers, or signing tools.

## Runtime

| Item | Requirement |
| --- | --- |
| Device | Cellular iPad with Personal Hotspot |
| Tested model | iPad Air 1 cellular, A1475, iPad4,2 |
| Tested firmware | iOS 12.5.8 |
| Jailbreak | Rootful |
| Package manager | Sileo, Cydia, Zebra, or APT-compatible frontend |

The package declares these dependencies.

```text
firmware (>= 12.0)
libssl3 (>= 3.2.1)
uikittools
```

The package bundles the BTstack runtime files it needs.

```text
/usr/bin/BTdaemon
/usr/lib/libBTstack.dylib
/Library/LaunchDaemons/ch.ringwald.BTstack.plist
```

## Build

Source builds need these tools on the iPad.

| Tool or path | Purpose |
| --- | --- |
| `/usr/bin/clang` | Objective-C and C build |
| `/usr/bin/ldid` | Entitlement signing |
| `/usr/include/openssl/*.h` | OpenSSL headers |
| `/tmp/iPhoneOS10.3.sdk` | clang sysroot |

The Mac-side helper scripts use USB SSH forwarding. `IPAD_PORT` means the local forwarded port on the Mac.

```text
IPAD_HOST=localhost
IPAD_PORT=2222
IPAD_USER=root
IPAD_PASS=alpine
```

Forward to the SSH port your iPad uses.

```sh
iproxy 2222 <ipad-sshd-port>
```
