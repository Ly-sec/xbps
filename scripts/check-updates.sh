#!/usr/bin/env bash
# check-updates.sh — Check all packages for newer upstream versions
#
# Usage: bash scripts/check-updates.sh [pkgname ...]
#
# For each package, runs xbps-src update-check and reports any newer
# versions found. If a package has a custom update file in
# pkgs/<pkgname>/update, it is used; otherwise xbps-src's default
# heuristic applies.
#
# In CI mode (--ci), output is formatted for GitHub Actions issue creation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
[ -f "$REPO_ROOT/etc/build.conf" ] && source "$REPO_ROOT/etc/build.conf"

CI_MODE=0
for arg in "$@"; do
	if [ "$arg" = "--ci" ]; then
		CI_MODE=1
		shift
	fi
done

UPSTREAM_DIR="$REPO_ROOT/void-packages"

# Ensure upstream exists
if [ ! -f "$UPSTREAM_DIR/xbps-src" ]; then
	bash "$SCRIPT_DIR/setup.sh"
fi

# Overlay our packages so update files are available
bash "$SCRIPT_DIR/overlay-packages.sh" "$@"

check_package() {
	local pkgname="$1"
	local template="$UPSTREAM_DIR/srcpkgs/$pkgname/template"

	if [ ! -f "$template" ]; then
		echo "[update-check] Skipping $pkgname: no template found"
		return
	fi

	# Extract current version
	local current_version
	current_version=$(grep -E '^version=' "$template" | sed 's/version=//' | tr -d '"')
	[ -z "$current_version" ] && current_version="(unknown)"

	echo "[update-check] Checking $pkgname (current: $current_version)..."

	# Run update-check
	# xbps-src update-check outputs candidate versions to stdout
	local output
	output=$("$UPSTREAM_DIR/xbps-src" update-check "$pkgname" 2>/dev/null || true)

	if [ -z "$output" ]; then
		echo "[update-check] $pkgname: no newer version found (or check failed)"
	elif echo "$output" | grep -q "^$current_version$"; then
		echo "[update-check] $pkgname: up to date ($current_version)"
	else
		# Get latest version from output
		local latest
		latest=$(echo "$output" | sort -V | tail -1)
		[ -z "$latest" ] && latest="$current_version"

		if [ "$latest" != "$current_version" ]; then
			# Version differs — determine if this is newer
			local newer
			newer=$(printf '%s\n%s\n' "$current_version" "$latest" | sort -V | tail -1)
			if [ "$newer" = "$latest" ] && [ "$latest" != "$current_version" ]; then
				echo "[update-check] ★ $pkgname: $current_version → $latest UPDATE AVAILABLE"
				if [ "$CI_MODE" -eq 1 ]; then
					# Output in a format that can be parsed by CI
					echo "UPDATE: $pkgname|$current_version|$latest"
				fi
			else
				echo "[update-check] $pkgname: current version $current_version is latest"
			fi
		else
			echo "[update-check] $pkgname: up to date ($current_version)"
		fi
	fi
}

echo "[update-check] Checking packages for updates..."
echo ""

UPDATES_FOUND=0
UPDATE_DATA=""

if [ $# -gt 0 ]; then
	for pkg in "$@"; do
		output=$(check_package "$pkg" 2>&1)
		echo "$output"
		if echo "$output" | grep -q "UPDATE:"; then
			UPDATES_FOUND=$((UPDATES_FOUND + 1))
			UPDATE_DATA="$UPDATE_DATA"$'\n'"$output"
		fi
	done
else
	for pkgdir in "$REPO_ROOT/pkgs"/*/; do
		[ -d "$pkgdir" ] || continue
		[ -f "$pkgdir/template" ] || continue
		pkg="$(basename "$pkgdir")"
		output=$(check_package "$pkg" 2>&1)
		echo "$output"
		if echo "$output" | grep -q "UPDATE:"; then
			UPDATES_FOUND=$((UPDATES_FOUND + 1))
			UPDATE_DATA="$UPDATE_DATA"$'\n'"$output"
		fi
	done
fi

echo ""
echo "[update-check] Done. ${UPDATES_FOUND} update(s) found."

if [ "$CI_MODE" -eq 1 ] && [ "$UPDATES_FOUND" -gt 0 ]; then
	echo "UPDATE_SUMMARY<<EOF" >> "$GITHUB_ENV" 2>/dev/null || true
	echo "$UPDATE_DATA" >> "$GITHUB_ENV" 2>/dev/null || true
	echo "EOF" >> "$GITHUB_ENV" 2>/dev/null || true
fi

exit 0
