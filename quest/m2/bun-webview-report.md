# [XS] Bun.WebView's calls that never settle are reported upstream, if still a bug

## Goal

Someone checks whether Bun.WebView's chrome backend still leaves `evaluate`, `click`, and `cdp` pending forever on the newest Bun, after Chrome's renderer crashes or while the page's main thread is busy. They also search oven-sh/bun's issues and Bun.WebView's docs for a duplicate report or documented behavior. The maintainer then decides whether to file the issue drafted below on oven-sh/bun. Either way, the decision and its reason end up in this quest's history.

## Plan

Found on [kixel-ai/rind#1171](https://github.com/kixel-ai/rind/pull/1171), which bounds every Bun.WebView call in `site/scripts/browser.ts` with a 45 s deadline and Chrome's `Inspector.targetCrashed` event after the site check hung for 44 minutes in CI. That bound stays whatever Bun does, so this quest changes no rind code.

Decided with the maintainer on 2026-11-28: ✅ don't file now; open this quest to verify first (rejected: file as drafted now).

- oven-sh/bun is outside [the orgs AGENTS.md lists](/AGENTS.md#development): an agent posts there only text the maintainer approved, with no standing approval.
- Rerun the repro below on the newest stable Bun and Chromium, outside `nix develop .#site` if nixpkgs lags. If it no longer reproduces, say which Bun version fixed it, and the quest finishes without filing.
- Search oven-sh/bun's issues for `WebView` with `crash`, `pending`, `hang`, and `timeout`, and read Bun.WebView's docs for how `timeout` and renderer crashes are meant to behave. A duplicate gets a link and, with approval, a comment adding this repro instead of a new issue.
- Update the draft's versions and output to what the rerun saw, and show the maintainer the final text before posting.

Seen on Bun 1.4.4+38afee6c8 (Linux x64), Chromium 157.0.8103.78 (nixpkgs, via `BUN_CHROME_PATH`), kernel 7.2.

Repro, run as `bun repro.ts`:

```ts
const pending = (p: Promise<unknown>) =>
	Promise.race([p.then((v) => `resolved ${v}`, (e) => `rejected: ${e}`), Bun.sleep(10_000).then(() => "STILL PENDING after 10 s")]);
const open = async () => {
	const view = new Bun.WebView({ backend: { type: "chrome", url: false, argv: ["--no-sandbox"] } });
	await view.navigate("data:text/html,<button id=b>b</button>");
	return view;
};

// 1. The page's main thread is busy.
let view = await open();
await view.evaluate("void setTimeout(() => { for (;;); }, 0)");
await Bun.sleep(200);
console.log("busy: click with timeout 1000:", await pending(view.click("#b", { timeout: 1000 })));
console.log("busy: evaluate:", await pending(view.evaluate("1 + 1")));
view.close();

// 2. The renderer crashes while an evaluate is pending.
view = await open();
view.addEventListener("Inspector.targetCrashed", () => console.log("crash: Inspector.targetCrashed received"));
const waiting = view.evaluate("new Promise(() => {})");
const crash = view.cdp("Page.crash");
console.log("crash: the pending evaluate:", await pending(waiting));
console.log("crash: Page.crash itself:", await pending(crash));
console.log("crash: a later click with timeout 1000:", await pending(view.click("#b", { timeout: 1000 })));
view.close();
process.exit(0);
```

Its output on 1.4.4:

```
busy: click with timeout 1000: STILL PENDING after 10 s
busy: evaluate: STILL PENDING after 10 s
crash: the pending evaluate: STILL PENDING after 10 s
crash: Inspector.targetCrashed received
crash: Page.crash itself: STILL PENDING after 10 s
crash: a later click with timeout 1000: STILL PENDING after 10 s
```

Draft issue for oven-sh/bun:

> **Title:** Bun.WebView (chrome backend): evaluate/click/cdp never settle when the renderer crashes or the page's main thread is busy, ignoring `click`'s `timeout`
>
> **Bun version:** 1.4.4+38afee6c8 (Linux x64), Chromium 157.0.8103.78 via `BUN_CHROME_PATH`.
>
> **Repro:** the script above.
>
> **Expected:** `click` rejects once its `timeout` passes. After `Inspector.targetCrashed`, every pending and later `evaluate`, `click`, and `cdp` rejects, such as with "target crashed". On a busy page a call either waits until a caller-given timeout rejects it, or the docs say it waits forever.
>
> **Actual:** the output above. Only one call of each kind may be pending, so every later call of that kind throws `ERR_INVALID_STATE` ("an evaluate() is already pending") and the view is unusable. Killing the renderer with SIGKILL, as the kernel's OOM killer would, behaves like `Page.crash`. `navigate` after a crash does resolve.
>
> **Impact:** a CI page check built on Bun.WebView hung for 44 minutes until the job was cancelled. It now races every call against its own deadline and `Inspector.targetCrashed`.

## Waiting

- Maintainer: approve posting the drafted Bun.WebView issue (calls never settling after a renderer crash or on a busy page) to oven-sh/bun, once it has been rerun on the newest Bun and oven-sh/bun has been searched for duplicates. An agent may not post outside the maintainer's orgs without this approval.
  - File as drafted (Recommended) - if it still reproduces on the newest Bun: the root fix belongs in Bun, and the repro is minimal and self-contained
  - Don't file - rind's site check is already bounded, and nothing else in rind uses Bun.WebView

## Related

- [Upstream reports](/quest/m2/upstream-reports.md) - reports rind's `UPSTREAM.md` workarounds in a batch, once the maintainer says rind is mature enough; this report is separate, at the maintainer's call (2026-11-28)
