#!/usr/bin/env bash
# ci-build.sh — CI build pipeline (run as a non-root user, upstream already cloned)
set -euo pipefail

: "${XBPS_TARGET_ARCH:=x86_64}"
: "${XBPS_ALLOW_RESTRICTED:=no}"

# GitHub runners can block unprivileged uid_map writes used by xbps-uunshare.
# Force a CI-safe chroot method when running in Actions unless overridden.
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
	: "${XBPS_CHROOT_CMD:=bwrap}"
	: "${XBPS_BUILD_ENVIRONMENT:=void-packages-ci}"
	echo "[ci-build] Using XBPS_CHROOT_CMD=$XBPS_CHROOT_CMD"
fi

export XBPS_TARGET_ARCH XBPS_ALLOW_RESTRICTED XBPS_CHROOT_CMD XBPS_BUILD_ENVIRONMENT

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
