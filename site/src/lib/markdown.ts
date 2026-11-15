import { Lexer, Parser, type Token, type Tokens, type TokensList } from "marked";

// Parse a Markdown document, resolving its reference links.
export function lex(source: string): TokensList {
	return Lexer.lex(source, { gfm: true });
}

// The blocks under the heading named `title`, up to the next heading as deep or shallower.
export function section(tokens: Token[], title: string): Token[] {
	const start = tokens.findIndex((t) => t.type === "heading" && t.text === title);
	if (start < 0) throw new Error(`the README has no heading "${title}"`);
	const depth = (tokens[start] as Tokens.Heading).depth;
	const rest = tokens.slice(start + 1);
	const end = rest.findIndex((t) => t.type === "heading" && t.depth <= depth);
	return end < 0 ? rest : rest.slice(0, end);
}

export const html = (blocks: Token[]): string => Parser.parse(blocks);
export const inlineHtml = (inline: Token[]): string => Parser.parseInline(inline);

// Blocks as their source wrote them, so a fragment of a document says exactly
// what the document does. Reference definitions are left to `definitions`.
export const blocks = (tokens: Token[]): string =>
	tokens
		.filter((t) => t.type !== "space" && t.type !== "def")
		.map((t) => t.raw.trimEnd())
		.join("\n\n");

// Spans as their source wrote them.
export const spans = (tokens: Token[]): string =>
	tokens
		.map((t) => t.raw)
		.join("")
		.trim();

// The definitions in `source` of the reference links `tokens` use, so a fragment
// of it reads on its own: the tag of `[text][tag]`, `[tag][]`, or `[tag]`,
// normalized as marked keys them.
export function definitions(tokens: Token[], source: Token[]): string {
	const tags = new Set(
		links(tokens)
			.map((t) => t.raw.match(/\]\[([^\]]+)\]$/)?.[1] ?? t.raw.match(/^!?\[([\s\S]*)\](?:\[\])?$/)?.[1])
			.filter((tag) => tag !== undefined)
			.map((tag) => tag.trim().replace(/\s+/g, " ").toLowerCase()),
	);
	return source
		.filter((t): t is Tokens.Def => t.type === "def" && tags.has(t.tag))
		.map((t) => t.raw.trim())
		.join("\n");
}

// A Markdown link to `href`, which may hold any character: one with spaces,
// parentheses, or angle brackets goes between escaped angle brackets.
export function link(label: string, href: string, title?: string | null): string {
	const dest = /[\s()<>\\]/.test(href) ? `<${href.replace(/[<>\\]/g, "\\$&")}>` : href;
	return `[${label}](${dest}${title ? ` "${title.replace(/["\\]/g, "\\$&")}"` : ""})`;
}

// Every link and image in some tokens, nested ones included.
function links(tokens: Token[]): (Tokens.Link | Tokens.Image)[] {
	const found: (Tokens.Link | Tokens.Image)[] = [];
	const walk = (list: Token[]) => {
		for (const t of list) {
			if (t.type === "link" || t.type === "image") found.push(t as Tokens.Link | Tokens.Image);
			if ("tokens" in t && t.tokens) walk(t.tokens);
			if (t.type === "list") for (const item of (t as Tokens.List).items) walk(item.tokens);
			if (t.type === "table") {
				const table = t as Tokens.Table;
				for (const cell of [...table.header, ...table.rows.flat()]) walk(cell.tokens);
			}
		}
	};
	walk(tokens);
	return found;
}

// Every link target in some tokens, nested ones included.
export const hrefs = (tokens: Token[]): string[] =>
	links(tokens)
		.filter((t) => t.type === "link")
		.map((t) => t.href);
