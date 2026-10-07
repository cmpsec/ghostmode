# Contributing to GhostMode

Thanks for considering it. This project stays honest and useful only if people
who actually run it push back on it — so disagreement, bug reports, and "this
architecture decision is wrong" issues are as welcome as pull requests.

## Reporting a problem

Open an issue with:
- What you ran (`ghostmode ...`) and what you expected
- What actually happened — paste the real output, not a paraphrase
- Your distro and whether it's a fresh install or an upgrade

If it's security-sensitive (something that could leak a real IP, location, or
similar), please still open it as a normal issue unless it's actively
exploitable by a remote party — this is a defensive tool for the device it's
installed on, not a service with external attack surface, so most findings
don't need private disclosure. Use your judgment; if in doubt, say so in the
issue and a maintainer will advise.

## Proposing a feature

Open an issue first for anything beyond a small fix — describe the problem
it solves, not just the implementation. Some ideas already under
consideration are listed in the README's Roadmap section; feel free to argue
for a different priority order.

## Code changes

- Match the existing style: one module per `lib/*.sh` file, one clear
  responsibility per module, no feature logic in `bin/ghostmode` itself.
- `bash -n <file>` every module you touch before opening a PR — zero syntax
  warnings is the bar, not a suggestion.
- No logging of the tool's own operations, anywhere — this is a deliberate
  project-wide design decision (see the README), not an oversight to "fix."
- If you touch anything that runs with elevated privileges (`sudo`), explain
  in the PR description exactly what it does and why it needs to be
  privileged. These get read more carefully than everything else.
- Test on an actual Debian/Kali machine where possible — a lot of this
  project's bugs only show up on a real system, not in a sandbox.

## Scope

GhostMode protects the device it's installed on. Contributions that add
capability against *other* systems (exploits, unauthorized access tooling,
etc.) are out of scope and will be closed — that's a different project.
