#!/usr/bin/env bash
set -euo pipefail
bin=target/release/claude-setup-system
case "$RUNNER_OS" in
  Linux) undefined() { nm -D --undefined-only "$1" | awk '{print $NF}' | sed 's/@.*//' | sort -u; } ;;
  macOS) undefined() { nm -u "$1" | sed 's/^_//' | sort -u; } ;;
  *) echo "no reader for $RUNNER_OS" >&2; exit 1 ;;
esac

# Whole names, never substrings. `sendfile64` is a file copy sitting
# beside `copy_file_range` in any libc, and a substring match calls it
# networking -- which is exactly how an earlier version of this
# measurement reported a socket in a program that has never opened
# one.
# Before believing an empty answer, prove the instrument works. A
# missing binary, or an `nm` that reports "no symbols", yields an
# empty list -- which every test below reads as "imports nothing
# bad" and passes. A check that goes green when its own tool is
# broken is worse than no check, and this one did exactly that in
# draft: `nm -u` against an ELF file (it needs `-D`) printed nothing
# and the step passed a program that opens sockets for a living.
test -f "$bin" || { echo "no binary at $bin" >&2; exit 1; }
count=$(undefined "$bin" | grep -c . || true)
if [ "$count" -lt 10 ]; then
  echo "read only $count undefined symbols from $bin; the reader is not working" >&2
  exit 1
fi
echo "read $count undefined symbols"

net=$(undefined "$bin" | grep -xE 'socket|socketpair|connect|bind|listen|accept|accept4|sendto|sendmsg|recvfrom|recvmsg|getaddrinfo|gethostbyname|gethostbyname2|res_query|res_search' || true)
echo "network imports: ${net:-(none)}"

# Enforced on both. Reported without failing on macOS for one
# release, because what this proves is that *our* code never reaches
# for a socket while what it reads is whatever the linker left after
# resolving that platform's std -- not the same claim, and no local
# measurement could say whether they coincide there.
#
# `0.0.8`'s run said it: none, on all seven, on macOS as on Linux.
if [ -n "$net" ]; then
  echo "this build imports network symbols:" >&2
  echo "$net" >&2
  exit 1
fi
echo "no network symbol is imported"

set -euo pipefail
bin=target/release/claude-setup-system
case "$RUNNER_OS" in
  Linux) undefined() { nm -D --undefined-only "$1" | awk '{print $NF}' | sed 's/@.*//' | sort -u; } ;;
  macOS) undefined() { nm -u "$1" | sed 's/^_//' | sort -u; } ;;
esac
test -f "$bin" || { echo "no binary at $bin" >&2; exit 1; }
count=$(undefined "$bin" | grep -c . || true)
if [ "$count" -lt 10 ]; then
  echo "read only $count undefined symbols from $bin; the reader is not working" >&2
  exit 1
fi

spawn=$(undefined "$bin" | grep -xE 'execve|execv|execvp|execvpe|fork|vfork|posix_spawn|posix_spawnp' || true)
declared=$("$bin" provider-info | python3 -c 'import json,sys; print("yes" if "launch" in json.load(sys.stdin)["supported_commands"] else "no")')
echo "launch declared: $declared"
echo "spawn imports: ${spawn:-(none)}"

# `clippy.toml` refuses `std::process::Command` outside the two places
# allowed to hold it. This asks the shipped bytes the same question,
# which is the stronger form of it: it survives the lint being wrong,
# bypassed, or read by someone with no reason to trust it.
#
# Measured on Linux across all seven binaries, then on macOS by
# `0.0.8`'s own run, and the two agree exactly: every build that
# declares `launch` imports `execvp` and nothing else. `0.0.8` still
# carried the era when antigravity declared none and imported no
# spawn symbol at all -- all seven declare it now (antigravity's is
# a documented-home binding), so today the negative arm is enforced
# on nobody, and stays because the day a launch slips out of a
# declaration is the day the spawn symbol must fail here.
# So the linker drops what nothing calls and the absence is real
# rather than incidental -- which is what had to be true before this
# could be enforced anywhere.
#
# It shipped reporting-only on macOS for exactly one release. That
# was not caution for its own sake: asserting a property of a system
# nobody has measured is the habit this repository keeps taking out
# of its own documents, and the first draft of this job enforced the
# network step on macOS while writing that sentence one step below.
if [ "$declared" = "no" ] && [ -n "$spawn" ]; then
  echo "no launch is declared and yet this build can spawn" >&2
  exit 1
fi
if [ "$declared" = "yes" ] && [ -z "$spawn" ]; then
  echo "launch is declared and this build imports nothing that could" >&2
  exit 1
fi
echo "the import table agrees with the declaration"
