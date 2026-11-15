#!/usr/bin/env bash
# Build site/, the landing page, from its frozen lockfile after its unit tests,
# check the output's pages, policy, and links (site/scripts/check.ts), and load
# it in headless Chrome (site/scripts/browser.ts).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../site"
bun install --frozen-lockfile
bun test
bun run build
bun scripts/browser.ts
