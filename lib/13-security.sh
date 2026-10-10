#!/usr/bin/env bash
# shellcheck shell=bash
# Part of Ghost Mode — sourced by bin/ghostmode, not run directly.

cmd_security() {
cat << EOF

${BLD}${BLU}╔══════════════════════════════════════════════════╗${RST}
${BLD}${BLU}║              GHOST MODE — SECURITY GUIDE        ║${RST}
${BLD}${BLU}╚══════════════════════════════════════════════════╝${RST}

${BLD}${CYN}[ 1. Core Security Principles ]${RST}

${BLD}Zero Trust${RST}
Never assume a device, network, or person is safe by default — not even
your own home WiFi, not even a laptop that was in your sight the whole
time. Verify every time instead of trusting because something "seemed
fine last time."

${BLD}Need to Know${RST}
Only access or hold the information strictly necessary for the task in
front of you. Don't keep old logs, old screenshots, old notes "just in
case" — anything you hold is something that can leak later.

${BLD}Least Privilege${RST}
Run everything with the minimum permission it needs. Don't stay logged
in as root. Don't give an app more access than the one thing you need
from it.

${BLD}Defense in Depth${RST}
Never rely on a single layer. Tor alone is one layer. Tor + kill switch
+ firewall + disk encryption + good habits is defense in depth — if one
layer fails, the next one catches it. This is exactly why we built the
kill switch: it's the layer that catches Tor's own failure.

${BLD}Assume Breach${RST}
Operate as if your system could already be compromised. This is why
compartmentalization matters: if one identity/session is burned, it
should not be able to lead back to everything else you do.

${BLD}Compartmentalization${RST}
Separate identities never share: usernames, passwords, writing style,
browser profiles, or timing patterns. Mixing them even once can link
them permanently.

${BLD}${CYN}[ 2. Operational Discipline — your daily habits ]${RST}

- Clean traces after every session, not "when you remember." This is
  the entire purpose of ${GRN}ghostmode${RST} — but the tool only helps if you
  actually run it consistently, not just when something feels risky.
- Never reuse a password, username, or even a specific writing style
  across different identities — these connect them.
- Assume anything you type can be logged somewhere (keylogger, shared
  machine, shoulder surfing) and think before you type sensitive data.
- Lock your screen every single time you step away, no exceptions.
- Use a strong full-disk encryption passphrase — without it, physical
  access to the laptop means everything else here is irrelevant.

${BLD}${CYN}[ 3. How Your Traffic Actually Flows ]${RST}

${YLW}Without any protection:${RST}
  Your device → Router (WiFi) → ISP → Internet backbone → Destination

  What your ${BLD}ISP${RST} sees at this stage, even over HTTPS:
  - Every DNS query you make = literally every domain name you look up
  - The destination IP of every connection (IPs aren't encrypted)
  - The SNI field inside the TLS handshake, which reveals the domain
    name even though the page content itself is encrypted
  - Timing and data volume (enough to guess video vs text vs voice)
  - What they can ${BLD}NOT${RST} see: the actual content of HTTPS traffic

${YLW}With a VPN:${RST}
  Device → Router → ISP (sees only an encrypted tunnel to the VPN IP)
         → VPN provider → Internet → Destination

  The ISP now sees nothing useful. But the VPN provider sees everything
  the ISP used to see — a VPN does not remove the trust problem, it
  ${BLD}relocates${RST} it from your ISP to whoever runs the VPN.

${YLW}With Tor (what anonsurf gives your whole system):${RST}
  Device → Router → ISP (sees only that you're using Tor)
         → Guard relay → Middle relay → Exit relay → Destination

  No single party sees both who you are and what you're visiting: the
  guard relay knows your IP but not your destination; the exit relay
  knows the destination but not your IP. The exit node ${BLD}can${RST} see
  unencrypted (non-HTTPS) traffic content, same as any ISP could.

${RED}${BLD}Three leaks that quietly defeat all of this:${RST}
- ${BLD}DNS leak${RST}: DNS queries going straight to your ISP's resolver instead
  of through the VPN/Tor tunnel — your real browsing leaks even though
  the "connection" looks protected.
- ${BLD}WebRTC leak${RST}: browsers can reveal your real IP via WebRTC (built for
  peer-to-peer calls) even while a VPN/Tor is active. Tor Browser
  handles this; a regular browser usually does not.
- ${BLD}SNI leak${RST}: even through an encrypted tunnel, the destination domain
  can still appear in plaintext inside the TLS handshake unless
  Encrypted SNI / encrypted DNS is also in place.

${GRY}This is exactly why the kill switch exists: the moment Tor itself
drops, it cuts your connection immediately instead of silently falling
back to your real, unprotected one.${RST}

${BLD}${CYN}[ 4. Physical / Hardware-Level Protection ]${RST}

No software setting can fix a hardware leak. This is the layer under
everything else:

${BLD}GPS${RST}
Most laptops (unlike phones) have ${BLD}no real GPS chip${RST} at all — "location"
on a laptop is usually WiFi-based positioning, which is exactly what
${GRN}ghostmode location${RST} fakes. If your model does have a cellular/WWAN card
with real GPS, disabling it in BIOS (if offered) is the realistic option
— physical removal means desoldering, not practical for most people.

${BLD}Camera${RST}
Simplest and fully reversible: physically cover the lens (tape, a
sliding cover). Permanent disabling means disconnecting the internal
ribbon cable (opening the laptop, not reversible without reassembly) or
disabling it in BIOS if supported. A software block (kernel module
blacklist) only stops an unprivileged process — not one with root.

${BLD}Microphone${RST}
Same logic: a software mute is not enough against an attacker who
already has root — they can simply un-mute it. A BIOS-level disable, or
a physical disconnect, is the only mute that malware cannot undo.

${BLD}Bluetooth / WiFi${RST}
Use a hardware kill switch if your laptop has one; otherwise disable
unused radios in BIOS when you don't need them — reduces both attack
surface and passive tracking (MAC broadcasts).

${BLD}Speakers${RST}
This one is a much more advanced, rare threat: malware using ultrasonic
audio between nearby devices to exfiltrate data with no network
connection at all. This targets extremely high-value, often air-gapped
targets — almost certainly outside your actual threat model. Mentioned
for completeness, not something to act on by default.

${BLD}${CYN}[ 5. The Full Picture — what this device actually is ]${RST}

Think of security as layers stacked on top of each other: hardware →
firmware/BIOS → OS kernel → applications → your own behavior. Your
${BLD}overall${RST} security is only as strong as the weakest layer — perfect
software protection is still defeated by an uncovered camera, and a
perfect VPN is still defeated by reusing a password once.

Software (this tool included) can only ever protect the software layer.
It cannot fix a hardware leak, and it cannot fix a habit. The real
"mental model" to keep is simple: ${BLD}know at every moment which layer
you're relying on, and know that it only takes one weak layer to
undo all the others.${RST}

${BLD}${CYN}[ 6. What never leaves the machine's hands ]${RST}

A cleanup on this laptop does not erase:

- The router's DHCP leases, MAC addresses, and device names.
- The Wi-Fi access point's association log.
- What the ISP stored: your address there, when you connected, and how much data moved. If Tor drops for a moment, the ISP sees the destination too.
- A mobile operator, if this machine has a SIM. Ghost Mode does not control the modem and cannot delete the carrier's records.
- Cloud copies: browser sync, Drive, GitHub, Telegram on the server. Deleting the local file does not delete the server. Turn sync off, or the wipe is local only.
- Other devices on the network. This install covers this machine only.
- The hardware itself: SSD spare area, firmware, Intel ME or AMD PSP, the TPM, and UEFI variables. This tool does not run nvme sanitize or hdparm security-erase. Those erase the whole disk, including the system.

${BLD}${CYN}[ 7. Network shield, DNS, and WebRTC ]${RST}

${GRN}ghostmode tor on${RST} starts the shield after the tunnel is up.
${GRN}ghostmode tor off${RST} and ${GRN}ghostmode destroy${RST} put back the IPv6, NTP, DHCP hostname, and captive-portal settings that were saved. If the kill switch is still armed, IPv4 stays closed.

While Tor is on, ${GRN}ghostmode status${RST} turns red if a global IPv6 address is up, if resolv.conf points at a public resolver, or if a connection is established by a process that is not Tor. There is no single line that says the network is protected.

WebRTC and DNS-over-HTTPS inside a normal browser can bypass the system resolver. No clean iptables rule stops them without breaking the browser. Use Tor Browser for browsing, and turn WebRTC and DNS-over-HTTPS off in a normal browser. This tool does not write those settings into a Firefox profile.

The shield blocks mDNS, SSDP, and NetBIOS, so local printers and device discovery stop while it is on. It also stops systemd-timesyncd, so the clock can drift. It does not set a fake time.

${BLD}${CYN}[ 8. History, Cursor, and the disk ]${RST}

The sudo password is entered once at install and kept in ~/.config/ghostmode/sudo.pass (mode 600) so the timer and later commands do not ask again. ghostmode destroy deletes that file. It is not stored in the git repository.

Every cleanup, including the timer, empties shell history and keeps command suggestions off. Suggestions come back only from ${GRN}ghostmode destroy${RST}, and only after the history files are emptied. Scrollback in a terminal you still have open lives in that window until you close it. The timer does not close terminals.

Cursor conversation text lives in SQLite (state.vscdb and the files next to it), not only in agent-transcripts. Deleting state.vscdb logs you out of Cursor, because the session token is in that database. The timer skips those databases while Cursor or cursor-agent is running and says so. It does not pretend they were cleared.

On an SSD, and on btrfs, shred does not guarantee a physical erase. rm is what this tool uses. It removes the file from the operating system and from the programs that read it. It does not promise a forensic or 100% wipe.

Closing a program is what drops that program's RAM. The timer does not kill the browser, the terminal, or Cursor. If the disk is not encrypted, physical access bypasses the rest. If the screen does not lock, the same is true for anyone at the keyboard.

EOF
}

