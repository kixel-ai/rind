# [XS] Retire the crates.io registry token

## Goal

After the first release that publishes through crates.io trusted publishing,
no long-lived crates.io token can publish rind.

## Plan

The release job no longer reads `CARGO_REGISTRY_TOKEN`, but the secret stays
until a real release proves the OIDC path. Delete this quest once the token
is gone.

## Waiting

- Maintainer: once a release publishes through trusted publishing (the
  release job's log shows release-plz retrieving a trusted publishing token
  and every changed crate publishing), delete the `CARGO_REGISTRY_TOKEN`
  repository secret and revoke that token on crates.io. An agent holds no
  crates.io login to revoke it. Check: `gh api repos/moq-dev/rind/actions/secrets`
  no longer lists it.
- Maintainer: recommended, at the same time, turn on each published crate's
  crates.io "require trusted publishing" setting, so a leaked API token cannot
  publish it. Check: `trustpub_only` is true in
  `https://crates.io/api/v1/crates/<crate>` for every published crate.
