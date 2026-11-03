# [S] Confine release credentials to publishing

## Goal

Only a release job on an allowed ref can obtain rind's publishing credentials,
and crates.io publishing no longer depends on a long-lived registry token.

## Plan

- Keep this in m0 because repository-level publishing credentials are an
  avoidable release-security exposure, even though no compromise is known.
- Follow MoQ's protected `publish` environment: move `APP_CLIENT_ID` and
  `APP_PRIVATE_KEY` out of repository secrets and into that environment.
- Configure crates.io trusted publishing for every published rind crate and
  update the release workflow to authenticate with GitHub OIDC instead of
  `CARGO_REGISTRY_TOKEN`.
- Rotate the GitHub App private key after the workflow uses the environment,
  then delete the superseded repository secrets and registry token.
- Keep the environment restricted to the release refs the workflow actually
  uses. Do not expose write credentials to pull requests or general branch
  workflows.
- Check the workflow and trusted-publisher configuration without publishing a
  duplicate version. Treat the next real release as the end-to-end smoke test.

