#!/usr/bin/env bash
# init-upstream.sh — Vendor the upstream commit-regrets/samsung_tizen_tv_root
# tree into ./upstream/samsung_tizen_tv_root/, stripping its .git history.
#
# This is self-contained: once you run it, the rest of the toolkit works
# without a working internet connection (as long as Docker and dropbear
# tarball mirrors are reachable at build time).
#
# Re-running updates the vendored copy. Existing local changes are overwritten.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UPSTREAM_DIR="${REPO_ROOT}/upstream/samsung_tizen_tv_root"
UPSTREAM_URL="https://github.com/commit-regrets/samsung_tizen_tv_root.git"
UPSTREAM_REF="${UPSTREAM_REF:-main}"

mkdir -p "${REPO_ROOT}/upstream"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "[init-upstream] cloning ${UPSTREAM_URL}@${UPSTREAM_REF}"
git clone --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_URL" "${TMP}/upstream"

# Capture the upstream commit hash for NOTICE.md purposes
UPSTREAM_SHA=$(git -C "${TMP}/upstream" rev-parse HEAD)
UPSTREAM_SHORT=$(git -C "${TMP}/upstream" rev-parse --short HEAD)

# Drop .git — we vendor source, not history
rm -rf "${TMP}/upstream/.git" "${TMP}/upstream/.github"

# Replace existing vendored copy
rm -rf "$UPSTREAM_DIR"
mkdir -p "$UPSTREAM_DIR"
cp -R "${TMP}/upstream/." "$UPSTREAM_DIR/"

# Mark the vendor origin so others know where it came from
cat > "${UPSTREAM_DIR}/VENDOR_ORIGIN.md" <<EOF
# Vendored from upstream

This directory is a vendored snapshot of
[commit-regrets/samsung_tizen_tv_root](https://github.com/commit-regrets/samsung_tizen_tv_root).

| | |
|---|---|
| Upstream URL | ${UPSTREAM_URL} |
| Ref          | ${UPSTREAM_REF} |
| Commit       | \`${UPSTREAM_SHA}\` (\`${UPSTREAM_SHORT}\`) |
| Vendored on  | $(date -u +'%Y-%m-%d') |

License: see \`LICENSE\` in this directory (MIT, upstream). Attribution in the
repo-root \`NOTICE.md\`. Re-sync by running \`build/init-upstream.sh\`.
EOF

echo "[init-upstream] ✅ vendored ${UPSTREAM_URL}@${UPSTREAM_SHORT}"
echo "              → ${UPSTREAM_DIR}"
