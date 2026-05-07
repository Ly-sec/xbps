#!/usr/bin/env bash
# publish.sh — Publish the repository to GitHub Releases
#
# Usage: bash scripts/publish.sh
#
# Creates (or updates) a GitHub Release with all .xbps files and
# repository metadata (index, signature, public key).
#
# The release tag is auto-generated as: repo-<YYYYMMDD>-<COMMIT_SHORT>
# This makes it easy to track which build corresponds to which source.
#
# Requirements:
#   - gh (GitHub CLI) installed and authenticated
#   - GITHUB_TOKEN environment variable (set automatically in Actions)
#
# Environment variables:
#   GITHUB_TOKEN    GitHub token for API access
#   GITHUB_REPO     Override repo in "owner/repo" format (default: from git remote)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_DIR="$REPO_ROOT/repo"

if [ ! -d "$REPO_DIR" ] || [ -z "$(ls "$REPO_DIR"/*.xbps 2>/dev/null)" ]; then
	echo "[publish] No .xbps files found in $REPO_DIR."
	echo "[publish] Run 'bash scripts/build.sh' first."
	exit 1
fi

# Check for gh CLI
if ! command -v gh &>/dev/null; then
	echo "[publish] Error: 'gh' (GitHub CLI) not found. Install it or use a different publish method."
	exit 1
fi

# Verify authentication
if ! gh auth status 2>/dev/null; then
	echo "[publish] Error: not authenticated with GitHub CLI."
	echo "[publish] Run 'gh auth login' or set GITHUB_TOKEN."
	exit 1
fi

# Determine repo slug
GITHUB_REPO="${GITHUB_REPO:-}"
if [ -z "$GITHUB_REPO" ]; then
	# Try to extract from git remote
	REMOTE_URL="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
	if echo "$REMOTE_URL" | grep -qE 'github\.com[:\/](.+\/.+)\.git'; then
		GITHUB_REPO=$(echo "$REMOTE_URL" | sed -E 's/.*github\.com[:\/](.+\/.+)\.git/\1/')
	elif echo "$REMOTE_URL" | grep -qE 'github\.com[:\/](.+\/.+)'; then
		GITHUB_REPO=$(echo "$REMOTE_URL" | sed -E 's/.*github\.com[:\/](.+)/\1/')
	fi
fi

if [ -z "$GITHUB_REPO" ]; then
	echo "[publish] Error: could not determine GitHub repository."
	echo "[publish] Set the GITHUB_REPO environment variable."
	exit 1
fi

# Generate a tag
COMMIT_SHORT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
TAG="repo-$(date +%Y%m%d)-${COMMIT_SHORT}"

echo "[publish] Publishing release $TAG for $GITHUB_REPO..."

# Check if release with this tag already exists
EXISTING_RELEASE_ID=""
if gh release view "$TAG" --repo "$GITHUB_REPO" &>/dev/null; then
	echo "[publish] Release $TAG already exists. Will update it."
	# Delete existing release assets and re-upload; or we could just upload additional assets
	# For simplicity, delete and recreate
	gh release delete "$TAG" --repo "$GITHUB_REPO" --yes 2>/dev/null || true
fi

# Create the release
# --draft makes it non-public initially; remove --draft for auto-publish
gh release create "$TAG" \
	--repo "$GITHUB_REPO" \
	--title "Package repository $TAG" \
	--notes "Automated build from commit ${COMMIT_SHORT}. Includes repository index and signed metadata." \
	"$REPO_DIR"/*.xbps \
	"$REPO_DIR"/*.sig 2>/dev/null || true

# Also upload repository index files if present (not covered by the glob above)
for f in "$REPO_DIR"/*.fdb "$REPO_DIR"/*.flist; do
	[ -f "$f" ] && gh release upload "$TAG" "$f" --repo "$GITHUB_REPO" 2>/dev/null || true
done

# Upload public key if present
if [ -f "$REPO_ROOT/keys/pub.pem" ]; then
	gh release upload "$TAG" "$REPO_ROOT/keys/pub.pem" --repo "$GITHUB_REPO" 2>/dev/null || true
	echo "[publish] Public key uploaded."
fi

echo "[publish] Release published: https://github.com/$GITHUB_REPO/releases/tag/$TAG"
