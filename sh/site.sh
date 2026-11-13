#!/usr/bin/env bash
# Build site/, the landing page, from its frozen lockfile, and check the
# output's pages and links (site/scripts/check.ts).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../site"
bun install --frozen-lockfile
bun run build
