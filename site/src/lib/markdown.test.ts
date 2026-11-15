import { expect, test } from "bun:test";
import { blocks, definitions, hrefs, html, lex, section, spans } from "./markdown";

// A section quoted with its definitions renders as it does inside its document.
test.each([
	// Reference links, full, collapsed, and shortcut, with their definitions elsewhere.
	"[a][R] and [r][] and [r]",
	"[a][multi  word]",
	// Spans and blocks the source wrote in a form a writer could get wrong.
	"_a*b_ and __a**b__",
	"[a\\]b](/guide)",
	"3. three\n4. four",
	"10. parent\n    - child",
	"- [ ] todo",
	"````text\n```\n````",
])("%s", (body) => {
	const doc = lex(`intro\n\n## S\n\n${body}\n\n## T\n\n[r]: https://example.com/r\n[multi word]: </m (x)> "t"\n`);
	const quoted = section(doc, "S");
	const twin = `${blocks(quoted)}\n\n${definitions(quoted, doc)}`;
	expect(html(lex(twin))).toBe(html(quoted));
});

test("spans quote inline source as written", () => {
	const [paragraph] = lex("a _b*c_ [d][r]\n\n[r]: /r");
	expect(spans((paragraph as { tokens: never[] }).tokens)).toBe("a _b*c_ [d][r]");
});

// Links in table cells, header and body, are found like any other.
test("hrefs reads table cells", () => {
	expect(hrefs(lex("| [Head](/head) |\n| --- |\n| [Missing](/missing) |"))).toEqual(["/head", "/missing"]);
});
