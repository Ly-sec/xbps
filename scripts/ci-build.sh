#!/usr/bin/env bash
# ci-build.sh — Full CI build pipeline (run as non-root user)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Clone upstream if needed
if [ ! -d void-packages/.git ]; then
	git clone --depth=1 https://github.com/void-linux/void-packages.git
fi

# Overlay templates and bootstrap
bash scripts/overlay-packages.sh
for i in 1 2 3; do
	./void-packages/xbps-src binary-bootstrap && break
	echo "Bootstrap attempt $i failed, retrying..."
	sleep 5
done

# Update upstream and re-overlay (reset may remove our files)
git -C void-packages fetch --depth=1 origin master
git -C void-packages reset --hard origin/master
bash scripts/overlay-packages.sh

# Build all packages
XBPS_MAKEJOBS=$(nproc) bash scripts/build.sh
