# aws-lc and BoringSSL vector files

Copies of the vector files in [aws-lc] and [BoringSSL] that cover an
algorithm rind offers. `admin/sync-vectors` fetches them, unmodified, from the
revisions it pins, and lists every file. Both repositories are hundreds of
megabytes, so rind keeps these copies rather than submodules.

Each directory holds its upstream's `LICENSE`. To update, bump a revision in
`admin/sync-vectors` and rerun it.

The tests read them through `rind/src/test/file_test.rs`, which parses the
FileTest format both projects share.

`rfc9180/test-vectors.json` holds [RFC 9180]'s HPKE vectors, from the
CFRG draft's repository at the revision `admin/sync-vectors` pins: the base
mode's, one per line, for the KEMs rind offers. The revision in
[hpkewg/hpke] repeats them unchanged. They are IETF contributions, under
[BCP 78].

[aws-lc]: https://github.com/aws/aws-lc
[BoringSSL]: https://boringssl.googlesource.com/boringssl
[RFC 9180]: https://www.rfc-editor.org/rfc/rfc9180.html
[hpkewg/hpke]: https://github.com/hpkewg/hpke
[BCP 78]: https://www.rfc-editor.org/info/bcp78
