#!/usr/bin/env bash
# build.sh — Build packages with xbps-src
#
# Usage: bash scripts/build.sh [pkgname ...]
#
# If pkgname(s) are given, only those packages are built.
# If none are given, ALL packages under pkgs/ are built.
#
# Steps:
#   1. Source build config.
#   2. Clone upstream if needed (via setup.sh).
#   3. Overlay custom packages (via overlay-packages.sh).
#   4. Build each requested package with xbps-src.
#   5. Collect resulting .xbps files into repo/.
#   6. Update the XBPS repository index.
#
# Environment variables:
#   XBPS_TARGET_ARCH   Architecture to build for (default: x86_64)
#   XBPS_MAKEJOBS      Parallel jobs (default: from nproc)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
[ -f "$REPO_ROOT/etc/build.conf" ] && source "$REPO_ROOT/etc/build.conf"

: "${XBPS_TARGET_ARCH:=x86_64}"
: "${XBPS_MAKEJOBS:=$(nproc)}"
export XBPS_MAKEJOBS

UPSTREAM_DIR="$REPO_ROOT/void-packages"

# Ensure upstream exists and is bootstrapped
if [ ! -f "$UPSTREAM_DIR/xbps-src" ]; then
	echo "[build] Setting up build environment..."
	bash "$SCRIPT_DIR/setup.sh"
fi

# Overlay our packages
bash "$SCRIPT_DIR/overlay-packages.sh" "$@"

build_package() {
	local pkgname="$1"
	echo ""
	echo "========================================================================"
	echo "[build] Building $pkgname for $XBPS_TARGET_ARCH..."
	echo "========================================================================"

	# Run xbps-src from within the upstream directory
	# xbps-src options:
	#   -a <arch>     Cross-compile for target architecture
	#   -j <jobs>     Parallel job count
	#   pkg <name>    Build a package and its dependencies
	if [ "$XBPS_TARGET_ARCH" = "x86_64" ]; then
		# Native build
		"$UPSTREAM_DIR/xbps-src" -j "$XBPS_MAKEJOBS" pkg "$pkgname"
	else
		# Cross build
		"$UPSTREAM_DIR/xbps-src" -a "$XBPS_TARGET_ARCH" -j "$XBPS_MAKEJOBS" pkg "$pkgname"
	fi

	echo "[build] $pkgname built successfully."
}

# Determine which packages to build
if [ $# -gt 0 ]; then
	BUILD_LIST=("$@")
else
	# Build all packages that have templates
	BUILD_LIST=()
	for pkgdir in "$REPO_ROOT/pkgs"/*/; do
		[ -d "$pkgdir" ] || continue
		[ -f "$pkgdir/template" ] || continue
		pkg="$(basename "$pkgdir")"
		BUILD_LIST+=("$pkg")
	done
fi

# Build each package
for pkg in "${BUILD_LIST[@]}"; do
	build_package "$pkg"
done

# Collect built packages into repo/
echo ""
echo "[build] Collecting built packages into repo/..."
mkdir -p "$REPO_ROOT/repo"

# xbps-src places built packages in hostdir/binpkgs/ (or hostdir/binpkgs/<arch>/)
BINPKGS_DIR="$UPSTREAM_DIR/hostdir/binpkgs"
if [ "$XBPS_TARGET_ARCH" != "x86_64" ]; then
	BINPKGS_DIR="$BINPKGS_DIR/$XBPS_TARGET_ARCH"
fi

COPIED=0
if [ -d "$BINPKGS_DIR" ]; then
	for xbps_file in "$BINPKGS_DIR"/*.xbps; do
		[ -f "$xbps_file" ] || continue
		cp "$xbps_file" "$REPO_ROOT/repo/"
		COPIED=$((COPIED + 1))
	done
fi

echo "[build] Copied $COPIED .xbps files to repo/."

# Generate repository index (if we have packages)
if [ "$COPIED" -gt 0 ]; then
	echo "[build] Generating repository index..."
	xbps-rindex -a "$REPO_ROOT/repo/"*.xbps 2>/dev/null
	echo "[build] Repository index updated."
fi

echo ""
echo "[build] Done. Built packages are in repo/."
echo "[build] To sign the repository, run: bash scripts/sign-repo.sh"
