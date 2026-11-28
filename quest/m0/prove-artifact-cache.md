# [S] Share admin/prove's translations through fedora's artifact cache

## Goal

`admin/prove` shares Aeneas's translations between hosts through fedora's
S3-style artifact cache, under the `rind/` prefix, instead of over ssh to
`RIND_PROVE_CACHE_HOST`. It finds the cache on every run from
`${XDG_CONFIG_HOME:-$HOME/.config}/artifact-cache/url`, with the writers'
token in `token` beside it, so a change needs no restart. Its own Lake half
goes: `lake_get`, `lake_put`, `lake build -o`, and the ssh helpers behind
them. The proofs' Lake outputs stay with the shared Lake cache that
`~/.lake/config.toml` already points at.

Non-goals: changing what a run proves, the translation key, or the Lake
cache itself.

## Plan

Why m0: [kixel-ai/dotfiles#412](https://github.com/kixel-ai/dotfiles/pull/412)
removed `RIND_PROVE_CACHE_HOST` from every host, so a run now shares no
translations. On desktop, in #412's earlier version, translations from
fedora cut a run from 441s to 247s wall and from 1341 to 371 CPU-s; every
agent running `admin/prove` pays the difference until this lands, on the
hosts every task shares.

Decided 2026-11-28 (maintainer, `/quest-run` interview):

- ✅ Store translations in the artifact cache under `rind/` and drop
  `admin/prove`'s Lake half, leaving Lake outputs to the shared Lake cache
  (decided on #412).
- ✅ When the `url` file exists but the cache is unreachable (a 502 through
  desktop's or nixos's forwarder means fedora is away) or the write token is
  missing, fail the run, as the ssh path does today (rejected: build locally
  and skip the upload).
- ✅ Every host with the `url` file uses it (rejected: only fedora and
  desktop). A host without the file runs with its local cache alone.
- ✅ No environment variable chooses the host (rejected: keeping
  `RIND_PROVE_CACHE_HOST`, which needs a T3 Code restart on every change).

The store's API, from #412:

- `GET <url>/rind/<key>` returns 200 with the object or 404; `HEAD` the
  same without a body. Reads need no token.
- `PUT <url>/rind/<key>` with `Authorization: Bearer <token>` and a
  `Content-Length` stores up to 1 GiB, replacing any object there: use
  `curl -fsS -T <file>`, not `-T -`, since a chunked body gets 411. No token
  gets 401.
- A key is up to 16 `/`-separated names matching
  `[A-Za-z0-9_][A-Za-z0-9._-]{0,127}`. Objects unused for 14 days expire,
  and the least recently used go past 100 GiB, Lake included, so the remote
  side needs no pruning from `admin/prove`.

Recommendations, the implementer's to take:

- Key objects `rind/translations/<key>.tar.gz`, keeping the local
  `~/.cache/rind/translations` as the first layer, so a host rereads its own
  entries without a request.
- Check the `url` and `token` files once at startup, so a missing token
  fails before any translation runs rather than at the first upload.
- Update the header comment, `cached`'s comment, and any doc naming
  `RIND_PROVE_CACHE_HOST`.
- [#1172](https://github.com/kixel-ai/rind/pull/1172) also edits
  `admin/prove`, near the `lake build` call; expect a conflict there.

Validate on desktop with a translation fedora already holds: a miss locally
fetches it, a fresh key is uploaded and reads back from another host, and a
run with the token moved aside fails before translating. Record wall and
CPU time against the baseline above.

Once merged, delete fedora's `~/.cache/rind/translations` and
`~/.cache/rind/lake`, which only the ssh path used.

## Related

- [kixel-ai/dotfiles#412](https://github.com/kixel-ai/dotfiles/pull/412) - the artifact cache this reads and writes
- [#1138](https://github.com/kixel-ai/rind/pull/1138) - added the ssh cache this replaces
