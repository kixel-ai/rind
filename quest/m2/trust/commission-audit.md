# [S] Commission the third-party audit and apply for its funding

## Goal

An outside firm has begun the Phase 1 audit that [AUDIT-SCOPE.md](/AUDIT-SCOPE.md) scopes, funded through at least one program [AUDIT-FUNDING.md](/AUDIT-FUNDING.md) lists, and the maintainer has recorded where its report is published.

## Plan

The scope is written and the funding file is a stub of facts and links; the pitch, the budget, and contacting anyone are the maintainer's. Nothing here an agent can do: engaging an auditor and submitting applications act in the maintainer's name.

Keep the "no one outside the project has audited it" warning in README.md during fieldwork. Once the final report names what was reviewed and at which commit, finish this quest by deleting `AUDIT-FUNDING.md` and updating README.md, AUDIT.md, and AUDIT-SCOPE.md together to say what was audited.

## Waiting

- Maintainer: pick the route. Options: OSTIF-managed audit funded by Sovereign Tech Agency or another funder; a direct Sovereign Tech Fund application (the program asks for work over EUR 50,000); or a firm engaged directly. Recommendation: ask OSTIF first, since it scopes, selects the firm, and publishes, and the Sovereign Tech Agency funds audits through it; apply to the Fund directly only for a larger package that includes proof work.
- Maintainer: write the applications from `AUDIT-FUNDING.md`'s notes and submit them. Check: an application or an email exists for each route picked.
- Maintainer: set the budget and timeline. Recommendation: price Phase 1 alone first, using the inventory in `AUDIT-SCOPE.md` as the size, and decide Phase 2 from its findings.
- Maintainer: name the audit firm if the route needs one. Recommendation: let OSTIF propose firms with Rust, assembly, and constant-time experience, and ask each whether it can review Lean and HOL Light trust bases or will subcontract that part.
- Maintainer: commit, or not, to publishing the report. Recommendation: publish it with fixes landed first, as OSTIF's reports are; a project that sells being verified loses the claim if findings are hidden.
- Maintainer: cut the release tag the auditor will freeze on. Recommendation: after the TCB ledger and the human sign-off policy quests land, so the audit starts from the documented trust base.

## Related

- [Publish TCB & Axiom Ledger, bind VG theorems in CI, and draft human sign-off policy](/quest/m2/trust/tcb-ledger-and-human-signoff.md)
