# [S] Confine release credentials to publishing

## Goal

Only a release job on an allowed ref can obtain rind's publishing credentials,
and crates.io publishing no longer depends on a long-lived registry token.

## Plan

- Keep this in m0 because repository-level publishing credentials are an
  avoidable release-security exposure, even though no compromise is known.
- The release job already names a `publish` environment restricted to
  `main`, but the environment has no secrets: `APP_CLIENT_ID`,
  `APP_PRIVATE_KEY`, and `CARGO_REGISTRY_TOKEN` are repository secrets. Fix
  the stale workflow comment while correcting that configuration.
- Follow MoQ's protected `publish` environment by storing a replacement
  GitHub App key there, then deleting the repository-level `APP_CLIENT_ID`
  and `APP_PRIVATE_KEY` before revoking the old key. Never put the replacement
  private key in a repository secret.
- Configure crates.io trusted publishing for every published rind crate and
  scope each publisher to `.github/workflows/release.yml` and the `publish`
  environment. Grant only that release job `id-token: write`, and remove
  `CARGO_REGISTRY_TOKEN` after OIDC authentication works.
- Confirm the release-plz version pinned by Nix supports crates.io's native
  OIDC exchange, updating it if necessary. Do not keep a registry-token
  fallback.
- Keep the GitHub environment's deployment branch policy restricted to
  exactly `main`. Do not expose write credentials to pull requests or general
  branch workflows.
- Trusted publishing cannot create a crate. Document that a new adapter's
  first version is published manually with a short-lived, crate-scoped token
  that is never stored as a repository secret; later versions use OIDC.
- Check the workflow and trusted-publisher configuration without publishing a
  duplicate version. Treat the next real release as the end-to-end smoke test.

