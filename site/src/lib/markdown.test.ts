import { expect, test } from "bun:test";
import { hrefs, html, lex, markdown } from "./markdown";

// The twin's Markdown renders to the same HTML as the source it was written from.
test.each([
	// Link destinations and titles.
	"[a](<https://example.com/a)b>)",
	"[a](https://en.wikipedia.org/wiki/X_(y))",
	"[a](<https://example.com/a b>)",
	"[a](<https://example.com/\\<x\\>>)",
	"[a](https://example.com/a\\b)",
	'[a](https://example.com "say \\"hi\\" \\\\ there")',
	"[a][r]\n\n[r]: <https://example.com/(r> 'ref'",
	// Link labels, whose escapes marked removes.
	"[a\\]b](/guide)",
	"[a\\[b\\*c\\_d](/guide)",
	"[x `]` y](/z) and [**bold \\] text**](/w)",
	// Lists: starts, and items continued past markers of any width.
	"3. three\n4. four",
	"3. parent\n   - child",
	"10. parent\n    - child",
	"- one\n- two\n\n  more of two",
])("%s", (source) => {
	expect(html(lex(markdown(lex(source))))).toBe(html(lex(source)));
});

// A task item's checkbox has no rendering, so it fails rather than vanish.
test("markdown refuses a task list", () => {
	expect(() => markdown(lex("- [ ] todo"))).toThrow("task list item");
});

// Links in table cells, header and body, are found like any other.
test("hrefs reads table cells", () => {
	expect(hrefs(lex("| [Head](/head) |\n| --- |\n| [Missing](/missing) |"))).toEqual(["/head", "/missing"]);
});
