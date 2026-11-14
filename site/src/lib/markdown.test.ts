import { expect, test } from "bun:test";
import type { Token } from "marked";
import { hrefs, inline, lex, markdown } from "./markdown";

// Each link's destination and title, nested ones included.
function links(tokens: Token[]): [string, string | null | undefined][] {
	return tokens.flatMap((t) => [
		...(t.type === "link" ? [[t.href, t.title] as [string, string | null | undefined]] : []),
		...("tokens" in t && t.tokens ? links(t.tokens) : []),
	]);
}

// A destination with any character survives being written back as Markdown.
test.each([
	"[a](<https://example.com/a)b>)",
	"[a](https://en.wikipedia.org/wiki/X_(y))",
	"[a](<https://example.com/a b>)",
	"[a](<https://example.com/\\<x\\>>)",
	"[a](https://example.com/a\\b)",
	'[a](https://example.com "say \\"hi\\" \\\\ there")',
	"[a][r]\n\n[r]: <https://example.com/(r> 'ref'",
])("%s", (source) => {
	const before = lex(source);
	const paragraph = before.find((t) => t.type === "paragraph");
	const written = inline(paragraph && "tokens" in paragraph ? (paragraph.tokens ?? []) : []);
	expect(links(lex(written))).toEqual(links(before));
	expect(links(before).length).toBe(1);
});

// Links in table cells, header and body, are found like any other.
test("hrefs reads table cells", () => {
	expect(hrefs(lex("| [Head](/head) |\n| --- |\n| [Missing](/missing) |"))).toEqual(["/head", "/missing"]);
});

// An ordered list keeps the number it starts at.
test("markdown keeps an ordered list's start", () => {
	const written = markdown(lex("3. three\n4. four"));
	expect(written).toBe("3. three\n4. four");
	expect(lex(written).find((t) => t.type === "list")).toMatchObject({ ordered: true, start: 3 });
});

// A task item's checkbox has no rendering, so it fails rather than vanish.
test("markdown refuses a task list", () => {
	expect(() => markdown(lex("- [ ] todo"))).toThrow("task list item");
});
