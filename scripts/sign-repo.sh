#!/usr/bin/env bash
# sign-repo.sh — Sign the XBPS repository index
#
# Usage: bash scripts/sign-repo.sh
#
# Signs all packages in repo/ using xbps-rindex.
# Requires either:
#   - etc/signing.conf with PRIVKEY, PUBKEY, SIGNEDBY variables, OR
#   - Environment variables: XBPS_PRIVKEY, XBPS_PUBKEY, XBPS_SIGNEDBY
#
# If PRIVKEY is set to a file path, the key file must exist.
# If PRIVKEY contains the literal key data (PEM), it is written to a temp file.
#
# SECRETS WARNING:
#   The private key is sensitive. In CI, store it as a GitHub Secret.
#   Never commit the key to the repository.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source signing config if present
if [ -f "$REPO_ROOT/etc/signing.conf" ]; then
	# shellcheck source=/dev/null
	source "$REPO_ROOT/etc/signing.conf"
fi

# Environment variables override config file
: "${PRIVKEY:=${XBPS_PRIVKEY:-}}"
: "${PUBKEY:=${XBPS_PUBKEY:-}}"
: "${SIGNEDBY:=${XBPS_SIGNEDBY:-}}"

REPO_DIR="$REPO_ROOT/repo"

if [ ! -d "$REPO_DIR" ] || [ -z "$(ls "$REPO_DIR"/*.xbps 2>/dev/null)" ]; then
	echo "[sign] No .xbps files found in $REPO_DIR. Build packages first."
	exit 1
fi

if [ -z "$SIGNEDBY" ]; then
	echo "[sign] Error: SIGNEDBY is not set."
	echo "[sign] Set it in etc/signing.conf or the XBPS_SIGNEDBY env var."
	echo "[sign] Example: SIGNEDBY=\"Your Name <you@example.com>\""
	exit 1
fi

# Determine how to provide the private key
KEY_ARG=""

if [ -n "$PRIVKEY" ]; then
	# Check if PRIVKEY is a file path or inline PEM content
	if [ -f "$PRIVKEY" ]; then
		# It's a file path — use it directly
		KEY_ARG="--privkey $PRIVKEY"
	elif echo "$PRIVKEY" | grep -q "^-----BEGIN"; then
		# It's inline PEM content — write to temp file
		TMP_KEY=$(mktemp /tmp/xbps-privkey.XXXXXXXXXX.pem)
		trap 'rm -f "$TMP_KEY"' EXIT
		echo "$PRIVKEY" > "$TMP_KEY"
		chmod 600 "$TMP_KEY"
		KEY_ARG="--privkey $TMP_KEY"
	else
		echo "[sign] Warning: PRIVKEY is set but doesn't point to a file or contain PEM data."
		echo "[sign] xbps-rindex will look for ~/.ssh/id_ed25519 as fallback."
	fi
fi

# Build the signing command
CMD="xbps-rindex --sign --signedby \"$SIGNEDBY\""
if [ -n "$KEY_ARG" ]; then
	CMD="$CMD $KEY_ARG"
fi
# --pubkey flag removed: xbps-rindex --sign does not support it.
# The public key is automatically embedded and derived from the private key.
# Copy keys/pub.pem manually for distribution to clients.
CMD="$CMD $REPO_DIR"

echo "[sign] Signing repository as \"$SIGNEDBY\"..."
eval "$CMD"

echo "[sign] Repository signed successfully."
echo "[sign] Public key for distribution: $REPO_ROOT/keys/pub.pem"
