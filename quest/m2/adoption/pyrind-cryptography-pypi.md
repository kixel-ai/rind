# [S] pyrind-cryptography on PyPI

## Goal

`pip install pyrind-cryptography` works: release.yml publishes the package in `rind-python/cryptography/` to PyPI as a pure wheel and sdist, by trusted publishing, whenever a version PyPI lacks lands on `main`.
A retry on a later push finishes a partial upload, as pyrind's does.
Non-goals: new hazmat features, and changing how pyrind itself releases.

## Plan

- Versioning: ✅ the package keeps its own version in its `pyproject.toml`, bumped by hand when it changes, and release.yml publishes any version PyPI lacks (rejected: lockstep with pyrind's version). It is pure Python and changes independently of pyrind's Rust; its pyrind requirement already bounds which pyrind it runs on.
- Model the job on the `pyrind-publish` job and `sh/pyrind-unpublished.sh`. release-plz doesn't know this package, so the check compares the pyproject version with PyPI directly rather than with a release-plz tag. Keep the `publish` environment and `id-token: write`, so no PyPI token is stored anywhere.
- PyPI trusted publisher: ✅ registered as a pending publisher for the new project name, pointing at moq-dev/rind, `release.yml`, and the `publish` environment. When the workflow PR is ready, the agent offers to drive Chrome through PyPI's form while the maintainer is logged in, and the maintainer confirms the submit (rejected: the maintainer registers it by hand from written field values).
- Planned as a follow-up of moq-dev/rind#553, which added the package.

## Waiting

- Maintainer: register the pending trusted publisher on PyPI for `pyrind-cryptography` before the first publish. It needs a logged-in PyPI account, so an agent can only drive the form with the maintainer present. Check at https://pypi.org/manage/account/publishing/.
