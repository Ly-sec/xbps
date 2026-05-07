#!/usr/bin/env bash
# overlay-packages.sh — Copy custom package templates into upstream tree
#
# For each directory under pkgs/<pkgname>/, this script:
#   1. Removes any existing upstream srcpkgs/<pkgname> directory.
#   2. Copies template, patches/, and update into void-packages/srcpkgs/<pkgname>/.
#
# Usage: bash scripts/overlay-packages.sh [pkgname ...]
#   If pkgname(s) are given, only those packages are overlaid.
#   If none given, all packages under pkgs/ are overlaid.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$REPO_ROOT/void-packages"

if [ ! -d "$UPSTREAM_DIR/srcpkgs" ]; then
	echo "[overlay] Error: upstream void-packages not found at $UPSTREAM_DIR"
	echo "[overlay] Run 'bash scripts/setup.sh' first."
	exit 1
fi

PKG_DIR="$REPO_ROOT/pkgs"

overlay_package() {
	local pkgname="$1"
	local src="$PKG_DIR/$pkgname"
	local dst="$UPSTREAM_DIR/srcpkgs/$pkgname"

	if [ ! -f "$src/template" ]; then
		echo "[overlay] Warning: $src/template not found, skipping $pkgname"
		return
	fi

	# Remove upstream version
	if [ -d "$dst" ]; then
		rm -rf "$dst"
	fi

	mkdir -p "$dst"

	# Copy template (required)
	cp "$src/template" "$dst/template"
	echo "[overlay] $pkgname: template copied"

	# Copy patches (optional)
	if [ -d "$src/patches" ]; then
		cp -r "$src/patches" "$dst/"
		echo "[overlay] $pkgname: patches copied ($(ls -1 "$src/patches" | wc -l) files)"
	fi

	# Copy update file (optional)
	if [ -f "$src/update" ]; then
		cp "$src/update" "$dst/update"
		echo "[overlay] $pkgname: update check config copied"
	fi

	# Copy any other files (e.g. INSTALL, REMOVE, options)
	for extra in INSTALL REMOVE options; do
		if [ -f "$src/$extra" ]; then
			cp "$src/$extra" "$dst/$extra"
			echo "[overlay] $pkgname: $extra copied"
		fi
	done
}

if [ $# -gt 0 ]; then
	# Overlay only specified packages
	for pkg in "$@"; do
		overlay_package "$pkg"
	done
else
	# Overlay all packages
	if [ -d "$PKG_DIR" ]; then
		for pkgdir in "$PKG_DIR"/*/; do
			[ -d "$pkgdir" ] || continue
			pkg="$(basename "$pkgdir")"
			overlay_package "$pkg"
		done
	fi
fi

echo "[overlay] Done."
