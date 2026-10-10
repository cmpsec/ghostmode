<p align="center">
  <img src="assets/banner.png" alt="GhostMode — privacy and anonymity toolkit for Linux" width="100%">
</p>

<p align="center">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-7ee787.svg">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Linux%20(Kali--based)-5b8cff.svg">
  <img alt="Shell" src="https://img.shields.io/badge/bash-%3E%3D5.0-8a8a8a.svg">
  <img alt="Status" src="https://img.shields.io/badge/status-open%20research%20project-blueviolet.svg">
</p>

# GhostMode V3.0

**A command-line privacy and anonymity toolkit for Linux.**

GhostMode wipes forensic traces, routes your whole system through Tor with a real kill switch, fakes your GPS location, rotates your network fingerprint, scrubs metadata from your files, and gives you one command (`ghostmode security`) that teaches the security principles behind all of it — no prior security background required.

It is built for one goal: **close the gap between "I installed a privacy tool" and "I actually understand what my computer is doing on the network."** Regular users shouldn't need a security background to get a professional-grade privacy posture. GhostMode tries to make that gap as small as a terminal command.

This is an open security research project. It is not a finished product and never claims to be "unhackable" or "100% anonymous" — no tool can honestly claim that. It documents its own limits (see [Honest Limitations](#honest-limitations)) because a privacy tool that oversells itself is more dangerous than one that doesn't exist.

---

## Table of Contents

- [Overview](#overview)
- [Who this is for](#who-this-is-for)
- [Installation](#installation)
- [Command Reference](#command-reference)
- [Preview](#preview)
- [How Your Traffic Actually Flows](#how-your-traffic-actually-flows)
- [Architecture](#architecture)
- [Honest Limitations](#honest-limitations)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

<p align="center">
  <img src="assets/overview.png" alt="Overview of GhostMode's five modules: Tor + kill switch, fingerprint rotation, fake GPS location, metadata scrubbing, forensic cleanup" width="100%">
</p>

---

## Who this is for

Anyone who wants their Linux machine to leak less — journalists, researchers, activists, or anyone who just doesn't think their ISP, router, or every app on their laptop needs to know everything about them. It was built and tested on **Kali Linux**, but the underlying tools (`systemd`, `iptables`, Tor, `ffmpeg`, `exiftool`) exist on virtually every Debian-based distribution, so it is reasonably portable with minor adjustments.

It is **not** built for attacking other people's systems. It protects the device it's installed on; it does not help compromise anyone else's.

---

## Installation

Works on **any Debian/Kali-based machine** — nothing in the installer is tied to a specific username, hostname, or hardware. Every credential and path is supplied by you at install time.

```bash
git clone https://github.com/cmpsec/ghostmode.git
cd ghostmode
chmod +x install.sh
./install.sh
```

The installer is interactive and runs in 9 steps:

1. Checks and installs missing dependencies (`curl`, `iproute2`, `iptables`, `pciutils`)
2. Installs GhostMode (copies `bin/` and `lib/` to `~/.local/`) and saves the sudo password **once** so nothing asks for it again. See [Sudo password](#sudo-password-typed-once) below.
3. Installs the auto-cleanup `systemd` timer (low priority, CPU-capped). The default interval is 1 hour. You can set minutes, hours, or days, and change it later with `ghostmode timer`.
4. Enables and starts the timer
5. Enables `systemd` lingering (so scheduled tasks run even without an active login session)
6. Turns off zsh command suggestions and installs a history guard. Every cleanup, including the timer, empties shell history from the root: the file, the in-memory list of new shells, and a hook that refuses to save new lines. Suggestions come back only from `ghostmode destroy`, and only after that wipe. An open terminal's scrollback stays in the window until you close it.
7. Optionally enables Tor for all device connections right away
8. Optionally adds `ghostmode`/`gs` shell aliases
9. Runs a smoke test, then offers to delete the source checkout — **the installed copy is fully independent of it** (verified: `bin/ghostmode` has zero references back to the install directory)

Re-running `install.sh` on an existing install **updates it in place** — your saved state (Tor on/off, custom paths, kill switch config, and the saved sudo password) is preserved unless you type a new password at the prompt, which replaces the stored one. If Tor was already on, it gets re-armed with whatever fixes shipped since.

### Sudo password (typed once)

`install.sh` asks for your sudo password one time. It stores that password in:

```text
~/.config/ghostmode/sudo.pass
```

The file mode is `600` (only your user can read it). Every later privileged step — the timer, `ghostmode` / `delete` / `auto`, Tor, the kill switch, fingerprint rotation — reads this file and passes it to `sudo -S`. You are not prompted again. The password is not placed on the command line.

That file lives only on this machine. It is **not** written into the git repository, the README, or the copied `lib/` scripts. `ghostmode destroy` deletes `~/.config/ghostmode`, including this file.

There is also a sudoers drop-in for `/usr/local/libexec/ghostmode-priv`. That is a fallback if the password file is missing. With the file present, the stored password is what the tool uses, so the hourly run does not stop and wait for a keyboard.

---

## Command Reference

```
ghostmode                          Full cleanup of the layers this tool can reach
ghostmode --force                  Same cleanup, after closing this user's Cursor and cursor-agent
ghostmode status                   Full status report (nothing is deleted)
ghostmode verify                   Re-check Cursor databases and shell history
ghostmode delete                   Same full cleanup. Also removes saved networks except the active one
ghostmode delete --force           Delete, after closing this user's Cursor
ghostmode auto                     Timer run. Includes shell history. Skips Cursor databases if Cursor is open
ghostmode timer [30min|2h|1d]      How often the timer runs
ghostmode shield on|off|status     Fail-closed IPv6, DNS, and LAN-announce checks used with Tor

ghostmode connections              Incoming/outgoing connections + public IP/country
ghostmode connections kill <pid>   Kill a suspicious connection's process
ghostmode connections block <ip>   Block an IP entirely (iptables)

ghostmode tor on                   Tor for all device connections (persists across reboots)
ghostmode tor off                  Disable Tor
ghostmode tor status               Current Tor status
ghostmode torbrowser [path]        Launch Tor Browser exempted from the system-wide tunnel
                                    (prevents Tor-inside-Tor connection failures)

ghostmode killswitch on            Arm the kill switch (optionally asks for a VPN fallback)
ghostmode killswitch off           Disarm it, restore normal networking
ghostmode killswitch status        Armed state, VPN fallback path, watchdog status

ghostmode location fake <lat> <lon>  Fixed fake GPS location (via GeoClue2)
ghostmode location random            Random fake location
ghostmode location off               Restore the real location

ghostmode fingerprint rotate       Rotate MAC address + hostname once, right now
ghostmode fingerprint rotate --machine-id
                                   Also regenerate /etc/machine-id. This drops sessions and needs a reboot. The default does not touch it.
ghostmode fingerprint auto on      Rotate both automatically on every boot
ghostmode fingerprint auto off     Stop automatic rotation

ghostmode metadata photo <path>    Strip capture date, GPS, camera/device info, all EXIF
ghostmode metadata audio <path>    Remove mains-hum fingerprint + shift voiceprint + strip metadata
ghostmode metadata video <path>    Same as photo + audio, applied to a video file

ghostmode paths add <path>         Watch a folder/file — wiped on every clean/delete/auto run
ghostmode paths remove <path>      Stop watching it
ghostmode paths list               Show all watched paths and their current state

ghostmode security                 Security principles, traffic flow, and hardware-hardening guide
ghostmode destroy                  Fully remove GhostMode from this system (irreversible)
ghostmode help / -h / h            This list
```

A few commands deserve more explanation:

**`ghostmode torbrowser`** exists because of a real architectural conflict: once `tor on` routes your *entire system* through Tor, launching the separate Tor Browser Bundle on top nests Tor inside Tor, breaking its TLS handshake to relays. `torbrowser` runs it as a dedicated, unprivileged system user that's explicitly exempted from the system-wide redirect — it connects to the real Tor network directly instead.

**`ghostmode killswitch`** only enforces while Tor is meant to be on. In double-protection mode (the default), it does not distinguish between Tor crashing and you running `tor off` manually — either way, your internet stays cut until you explicitly run `killswitch off`. This is intentional: see [How Your Traffic Actually Flows](#how-your-traffic-actually-flows) for why.

**`ghostmode destroy`** requires typing `DESTROY` in full, not `y/n` — this is deliberately harder to trigger by accident than anything else in the tool.

GhostMode keeps **no logs of its own operations**, by design. The timer discards successful output (`StandardOutput=null`). A failed step can still show up on stderr. A privacy tool that logs its own cleanup would be a new trace of what it cleared.

`ghostmode` and `ghostmode delete` clear Cursor conversation databases (`state.vscdb`, its `-wal`/`-shm` sidecars, workspace copies, `~/.cursor/chats`, and agent stores). That database also holds the Cursor session token, so the wipe logs you out. If Cursor or `cursor-agent` is running, the step is red and tells you to close it, unless you pass `--force`, which closes only this user's Cursor processes. The timer never passes `--force`: it skips those databases and prints a yellow line, while still clearing shell history.

On an SSD, and on btrfs, `shred` does not guarantee a physical erase. This tool uses `rm` and truncate. That removes the name from the filesystem and from the programs that would read it. It is not a forensic wipe, and it is not 100%.

---

## Preview

`ghostmode help` in the terminal:

<p align="center">
  <img src="assets/screenshot.png" alt="Output of ghostmode help listing every command" width="100%">
</p>

---

## How Your Traffic Actually Flows

This is the part most privacy tools skip. Here is exactly what changes, and doesn't, when you turn Tor and the kill switch on — using the kill switch's core job (stopping an IP leak to a target site) as the concrete example.

**Baseline, no protection:**

```
Your device → Router → ISP → Internet backbone → Target website
```

Your ISP sees every DNS query, every destination IP, the domain name inside the TLS handshake (SNI), and the timing/volume of your traffic — even though it can't read HTTPS content itself.

**With `ghostmode tor on` (anonsurf, system-wide):**

```
Your device → Router → ISP (sees only "connecting to Tor") → Guard relay → Middle relay → Exit relay → Target website
```

All outbound traffic is forced through Tor's local TransPort via an `iptables REDIRECT` rule. No single party (not your ISP, not any one relay) knows both who you are and what you're visiting.

**The gap `killswitch` closes — without it:**

If the Tor process dies unexpectedly while you're mid-session with a target site:
- New connection attempts to the (now-dead) local TransPort typically fail fast — but this is a side effect of nothing listening on that port, not a guarantee.
- Already-established connections live in the kernel's connection-tracking table; depending on exact system state, they do not necessarily terminate cleanly.
- Some applications retry automatically without a proxy as a resilience feature. If that happens here, the retry goes out on your **real IP**, straight to the target site, with no warning.

**With it:**

The watchdog checks every 5 seconds whether Tor is actually running. The moment it isn't:
- It sets `iptables`'s **default OUTPUT policy to DROP** — not a redirect rule, a default-deny at the kernel level. This blocks every outbound packet regardless of what any single application's retry logic tries to do.
- The only exception is loopback, so the local system keeps functioning.
- If a VPN fallback was configured, it attempts to bring that up as a replacement path.
- In double-protection mode, this holds even if **you** are the one who ran `tor off` — the only way back to normal traffic is `killswitch off`, explicitly.

The difference in one sentence: a `REDIRECT` rule assumes the destination is there; a `DROP` policy doesn't need it to be. That's the entire reason the kill switch is a second, independent mechanism instead of just trusting Tor to stay up.

---

## Architecture

```
ghostmode/
├── bin/
│   └── ghostmode          Thin entry point — sources lib/, dispatches to the
│                           requested command. Contains cmd_help and nothing else.
├── lib/
│   ├── 01-globals.sh       Colors, trace-path lists, shared config paths
│   ├── 02-checks.sh        All status-check functions (what cmd_status reports on)
│   ├── 03-clean.sh         The cleaning engine: cmd_status, cmd_clean, cmd_delete
│   ├── 04-connections.sh   ghostmode connections
│   ├── 05-tor.sh           ghostmode tor
│   ├── 06-killswitch.sh    ghostmode killswitch
│   ├── 07-location.sh      ghostmode location
│   ├── 08-fingerprint.sh   ghostmode fingerprint
│   ├── 09-torbrowser.sh    ghostmode torbrowser
│   ├── 10-metadata.sh      ghostmode metadata
│   ├── 11-paths.sh         ghostmode paths
│   ├── 12-destroy.sh       ghostmode destroy
│   ├── 13-security.sh      ghostmode security
│   ├── 14-history.sh       Shell-history guard and root wipe
│   ├── 15-cursor.sh        Cursor conversation stores
│   ├── 16-shield.sh        Tor shield (IPv6, DNS, LAN announce)
│   ├── 17-extra.sh         Login logs, git credentials, editors, messengers
│   ├── 18-verify.sh        ghostmode verify
│   └── 21-timer.sh         ghostmode timer
├── systemd/
│   ├── ghostmode-timer.service   Hourly auto-clean, templated by install.sh
│   └── ghostmode-timer.timer
└── install.sh              The only installer — see Installation above
```

`bin/ghostmode` sources every file in `lib/` and nothing else; it carries no feature logic itself. Each module in `lib/` is independently syntax-checkable and has a single, named responsibility. Persistence (the hourly timer, Tor-on-boot, the kill switch watchdog, fingerprint rotation) runs as **system-level `systemd` units** with an explicit `User=` directive, rather than `--user` units relying on login-session lingering — the latter turned out to be unreliable across reboots in testing, which is why the architecture uses the former.

**Dependencies:** `bash`, `systemd`, `iptables`, `iproute2` (`ip`, `ss`), `curl`, `ffmpeg`, `exiftool` (or `mat2`, auto-detected if present), `tor` (installed automatically via [Und3rf10w/kali-anonsurf](https://github.com/Und3rf10w/kali-anonsurf) on first `tor on`, since it has no official `apt` package), GeoClue2 (ships by default on Kali).

---

## Honest Limitations

A tool that doesn't say what it can't do isn't trustworthy. So:

- **There is no 100% wipe and no 100% anonymity.** After a successful run, these are still there: the router's DHCP and MAC log, the Wi-Fi access point's association log, the ISP's record of your address and connection times, any cloud copy (GitHub, browser sync, Telegram on the server), firmware, and SSD spare area. `ghostmode security` names each of these. A green status line means that one layer checked out, not that the machine is clean.
- **The sudo password is stored on the machine, on purpose, so the timer never asks.** It sits in `~/.config/ghostmode/sudo.pass` with mode `600`. Treat that file like a password. Full-disk encryption matters, because anyone who can read it can sudo. It is not in the git repo. `ghostmode destroy` deletes it. The sudoers helper is only a fallback when that file is gone.
- **`ghostmode` deletes local git credential files** (`~/.git-credentials`, `~/.config/gh/hosts.yml`, and the credential helper) so a token used to push is not left on disk. It does not delete project `.git` directories, and it does not delete the copy on GitHub.
- **Cursor `state.vscdb` is the conversation body.** Clearing it logs you out. Empty files the next time Cursor starts are expected.
- **Voiceprint/mains-hum scrubbing (`metadata audio`/`video`) significantly reduces matchability. It does not mathematically guarantee it can never be matched by any technique, present or future.** Treat it as a strong layer, not a certainty.
- **`fingerprint rotate` changes your MAC address and hostname — local-network-level identifiers.** It does not touch browser-level fingerprinting (canvas, WebGL, fonts); that's Tor Browser's job, and it already does it.
- **Visual content in photos/videos (faces, recognizable locations) is not something `metadata` can fix.** Metadata scrubbing and content analysis are different problems.
- **No independent security audit has been done on this codebase.** It's been tested by its author and users reporting back, not reviewed by a third party. Treat it accordingly.

---

## Roadmap

Ideas under consideration for future versions — not commitments, not a schedule:

- [ ] Multi-hop chaining (VPN → Tor → VPN) for an additional routing layer
- [ ] `ghostmode audit` — a self-check command that reviews the current config against security best practices and flags drift
- [ ] A dead-man's-switch mode: auto-run `destroy` if the tool isn't "checked in" within a configurable window
- [ ] Pluggable transport support for Tor (for use in networks that actively block Tor traffic)
- [ ] Broader distro support beyond Debian/Kali (Arch, Fedora derivatives)
- [ ] Encrypted, passphrase-protected storage for `ghostmode paths` targets
- [ ] Optional lightweight dashboard/GUI front-end for non-terminal users
- [ ] Hardware security key (e.g. YubiKey) confirmation step for `destroy`

Have an idea, or a different priority order? Open an issue — the list above is a starting point, not a fixed plan.

---

## Contributing

This is an open security research project, and it stays useful only if people who actually use it push back on it. Bug reports, architecture criticism, feature proposals, and pull requests are all genuinely welcome — including "this design decision is wrong and here's why."

If you're not sure where to start: run `ghostmode security` and `ghostmode help`, read [Architecture](#architecture), then open an issue describing what you found or what you'd like to change. See `CONTRIBUTING.md` for the specifics.

## License

MIT — see `LICENSE`. Use it, fork it, audit it, ship it in something else; just carry the license notice along.
