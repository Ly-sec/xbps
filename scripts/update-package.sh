#!/usr/bin/env bash
# update-package.sh — Update a package template to a new version
#
# Usage: bash scripts/update-package.sh <pkgname> [new-version]
#
# If new-version is given, the template is updated in-place.
# If new-version is omitted, the latest version from update-check is used.
#
# This script:
#   1. Determines the new version (from argument or update-check).
#   2. Updates the version= line in pkgs/<pkgname>/template.
#   3. Resets the revision to 1 (since it's a new upstream version).
#   4. Clears the checksum (you must regenerate it — or set it to an
#      invalid value so xbps-src will compute it).
#
# After running this, you should:
#   1. Regenerate the checksum:
#      (cd void-packages && ./xbps-src check-pkg <pkgname>)
#   2. Or clear the checksum and let xbps-src fill it in during build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 1 ]; then
	echo "Usage: bash scripts/update-package.sh <pkgname> [new-version]"
	echo ""
	echo "Arguments:"
	echo "  pkgname       Name of the package to update"
	echo "  new-version   Target version (optional; if omitted, uses latest from update-check)"
	exit 1
fi

PKGNAME="$1"
NEW_VERSION="${2:-}"
TEMPLATE_FILE="$REPO_ROOT/pkgs/$PKGNAME/template"

if [ ! -f "$TEMPLATE_FILE" ]; then
	echo "[update-pkg] Error: template not found at $TEMPLATE_FILE"
	exit 1
fi

# Determine current version
CURRENT_VERSION=$(grep -E '^version=' "$TEMPLATE_FILE" | sed 's/version=//' | tr -d '"')
echo "[update-pkg] Current version of $PKGNAME: $CURRENT_VERSION"

# Determine new version
if [ -z "$NEW_VERSION" ]; then
	echo "[update-pkg] Running update-check to find latest version..."
	UPSTREAM_DIR="$REPO_ROOT/void-packages"
	if [ ! -f "$UPSTREAM_DIR/xbps-src" ]; then
		bash "$SCRIPT_DIR/setup.sh"
	fi
	bash "$SCRIPT_DIR/overlay-packages.sh" "$PKGNAME"

	OUTPUT=$("$UPSTREAM_DIR/xbps-src" update-check "$PKGNAME" 2>/dev/null || true)
	if [ -z "$OUTPUT" ]; then
		echo "[update-pkg] Error: update-check returned no output for $PKGNAME"
		exit 1
	fi

	NEW_VERSION=$(echo "$OUTPUT" | sort -V | tail -1)
	if [ -z "$NEW_VERSION" ] || [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
		echo "[update-pkg] $PKGNAME is already at the latest version ($CURRENT_VERSION)."
		exit 0
	fi
fi

echo "[update-pkg] Updating $PKGNAME: $CURRENT_VERSION → $NEW_VERSION"

# Update version in template (handles quoted and unquoted)
if grep -qE '^version=' "$TEMPLATE_FILE"; then
	sed -i "s/^version=.*$/version=${NEW_VERSION}/" "$TEMPLATE_FILE"
fi

# Reset revision to 1 for new upstream version
if grep -qE '^revision=' "$TEMPLATE_FILE"; then
	sed -i "s/^revision=.*$/revision=1/" "$TEMPLATE_FILE"
fi

# Clear the checksum so xbps-src recalcuates it (or the user can run check-pkg)
if grep -qE '^checksum=' "$TEMPLATE_FILE"; then
	if grep -qE '^checksum=$' "$TEMPLATE_FILE"; then
		:  # already empty
	else
		sed -i "s/^checksum=.*$/checksum=/" "$TEMPLATE_FILE"
		echo "[update-pkg] WARNING: checksum cleared. Regenerate with:"
		echo "  (cd void-packages && ./xbps-src check-pkg $PKGNAME)"
	fi
fi

echo "[update-pkg] Template updated."
echo ""
echo "Next steps:"
echo "  1. Verify the template changes: git diff pkgs/$PKGNAME/template"
echo "  2. Regenerate the checksum:"
	echo "     bash scripts/overlay-packages.sh $PKGNAME"
	echo "     (cd void-packages && ./xbps-src check-pkg $PKGNAME)"
	echo "     # Then copy the checksum back to pkgs/$PKGNAME/template"
echo "  3. Build and test: bash scripts/build.sh $PKGNAME"
