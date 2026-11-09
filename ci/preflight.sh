#!/usr/bin/env bash
# Decides, before anything expensive starts, whether this runner can build an AOSP-class image.
#
#   ci/preflight.sh [min_disk_gb] [min_ram_gb] [min_cpus]
#
# Exit codes: 0 sufficient, 3 insufficient (with the measurement that failed), 4 missing tooling.
# The numbers are printed either way, because a preflight report is the artifact most runs of this
# workflow will produce.
set -euo pipefail

min_disk="${1:-400}"
min_ram="${2:-32}"
min_cpus="${3:-8}"

fail=0

disk_free_gb="$(df -Pk / | awk 'NR==2 {printf "%d", $4/1024/1024}')"
ram_gb="$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)"
cpus="$(nproc)"

printf '%-12s %-10s %-10s %s\n' resource required measured verdict
for row in "disk ${min_disk} ${disk_free_gb}" "ram ${min_ram} ${ram_gb}" "cpus ${min_cpus} ${cpus}"; do
  set -- $row
  if (( $3 >= $2 )); then verdict=ok; else verdict=INSUFFICIENT; fail=1; fi
  printf '%-12s %-10s %-10s %s\n' "$1" "$2" "$3" "$verdict"
done

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "preflight: guest/android/build.sh requires Linux x86_64, this is $(uname -s) $(uname -m)" >&2
  fail=1
fi

missing=0
for tool in git python3 curl unzip; do
  command -v "$tool" >/dev/null || { echo "preflight: missing $tool" >&2; missing=1; }
done
(( missing == 0 )) || exit 4

if (( fail != 0 )); then
  cat >&2 <<'MESSAGE'
preflight: this runner cannot build an AOSP-class image.

A standard GitHub-hosted runner has ~70 GB of disk and 16 GB of RAM; a full GrapheneOS-derived
build needs about 400 GB and 32 GB or more. Options, in order of cost:

  1. Set CARBONHV_BUILDER_LABEL to a self-hosted machine with the resources above:
       gh variable set CARBONHV_BUILDER_LABEL --repo <owner>/carbonhv-guest-grapheneos \
           --body '["self-hosted","linux","x64","carbonhv-builder"]'
  2. Run this repository's workflow on a paid larger runner, which has the disk and is billed per
     minute. That costs money and is the repository owner's decision, not the workflow's.
  3. Keep using the labelled AOSP Cuttlefish stand-in from carbonhv-guest-android while the real
     image is being built. It is not GrapheneOS and is never described as such.

No build was started. Nothing was downloaded.
MESSAGE
  exit 3
fi

echo "preflight: runner is sufficient"
