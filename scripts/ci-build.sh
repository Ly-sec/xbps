#!/usr/bin/env bash
# ci-build.sh — CI build pipeline (run as builder, upstream already cloned)
set -euo pipefail

: "${XBPS_TARGET_ARCH:=x86_64}"
: "${XBPS_ALLOW_RESTRICTED:=no}"
export XBPS_TARGET_ARCH XBPS_ALLOW_RESTRICTED

echo "=== Overlaying custom templates ==="
bash scripts/overlay-packages.sh

echo "=== Bootstrapping build environment ==="
for i in 1 2 3; do
	if ./void-packages/xbps-src binary-bootstrap; then
		echo "Bootstrap succeeded."
		break
	fi
	echo "Bootstrap attempt $i failed, retrying in 5s..."
	sleep 5
done

echo "=== Updating upstream ==="
git -C void-packages fetch --depth=1 origin master
git -C void-packages reset --hard origin/master
bash scripts/overlay-packages.sh

echo "=== Building packages ==="
XBPS_MAKEJOBS=$(nproc) bash scripts/build.sh
