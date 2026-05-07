#!/usr/bin/env bash
# setup.sh — Bootstrap the build environment
#
# Clones the upstream void-packages repository (if not already present)
# and runs binary-bootstrap to set up the build masterdir.
#
# Usage: bash scripts/setup.sh
#
# Options:
#   --bootstrap-only    Only run binary-bootstrap, skip clone
#   --clone-only        Only clone upstream, skip bootstrap

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
[ -f "$REPO_ROOT/etc/build.conf" ] && source "$REPO_ROOT/etc/build.conf"

: "${UPSTREAM_REPO:=https://github.com/void-linux/void-packages.git}"
: "${UPSTREAM_BRANCH:=master}"
: "${BOOTSTRAP:=yes}"
: "${XBPS_TARGET_ARCH:=x86_64}"

CLONE_ONLY=0
BOOTSTRAP_ONLY=0

for arg in "$@"; do
	case "$arg" in
		--clone-only) CLONE_ONLY=1 ;;
		--bootstrap-only) BOOTSTRAP_ONLY=1 ;;
	esac
done

UPSTREAM_DIR="$REPO_ROOT/void-packages"

# Clone upstream if needed
if [ "$BOOTSTRAP_ONLY" -eq 0 ]; then
	if [ -d "$UPSTREAM_DIR/.git" ]; then
		echo "[setup] Upstream already cloned at $UPSTREAM_DIR"
	else
		echo "[setup] Cloning upstream void-packages ($UPSTREAM_BRANCH)..."
		mkdir -p "$UPSTREAM_DIR"
		git clone --depth=1 --branch="$UPSTREAM_BRANCH" "$UPSTREAM_REPO" "$UPSTREAM_DIR"
		echo "[setup] Clone complete."
	fi
fi

if [ "$CLONE_ONLY" -eq 1 ]; then
	exit 0
fi

# Bootstrap (download the build masterdir)
if [ "$BOOTSTRAP" = "yes" ]; then
	BOOTSTRAP_MARKER="$UPSTREAM_DIR/hostdir/.bootstrap-${XBPS_TARGET_ARCH}"
	if [ -f "$BOOTSTRAP_MARKER" ]; then
		echo "[setup] Bootstrap already complete for $XBPS_TARGET_ARCH (delete $BOOTSTRAP_MARKER to redo)."
	else
		echo "[setup] Running binary-bootstrap for $XBPS_TARGET_ARCH..."
		"$UPSTREAM_DIR/xbps-src" -a "$XBPS_TARGET_ARCH" binary-bootstrap
		mkdir -p "$(dirname "$BOOTSTRAP_MARKER")"
		touch "$BOOTSTRAP_MARKER"
		echo "[setup] Bootstrap complete."
	fi
else
	echo "[setup] BOOTSTRAP=no, skipping. Ensure your host system has all build dependencies."
fi

echo "[setup] Environment ready."
