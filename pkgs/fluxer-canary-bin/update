#!/usr/bin/env bash
set -euo pipefail

PKGDIR="$(cd "$(dirname "$0")" && pwd)"
pkgname=fluxer-canary-bin
current=$(grep -E '^version=' "$PKGDIR/template" | sed 's/version=//' | tr -d '"')

latest=$(curl -sL "https://api.fluxer.app/dl/desktop/canary/linux/x64/" \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)

if [ -z "$latest" ] || [ "$latest" = "$current" ]; then
  exit 0
fi

checksum_x86_64=$(curl -sL --max-time 300 \
  "https://api.fluxer.app/dl/desktop/canary/linux/x64/${latest}/tar_gz" \
  | sha256sum | cut -d' ' -f1)

checksum_aarch64=$(curl -sL --max-time 300 \
  "https://api.fluxer.app/dl/desktop/canary/linux/arm64/${latest}/tar_gz" \
  | sha256sum | cut -d' ' -f1)

echo "UPDATE:$pkgname|$current|$latest|$checksum_x86_64|$checksum_aarch64"
