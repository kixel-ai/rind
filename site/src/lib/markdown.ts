import { decodeHTMLStrict } from "entities";
import { Lexer, Parser, Renderer, type Token, type Tokens, type TokensList, walkTokens } from "marked";

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

// One line of Markdown in a table cell, such as a gap's reason, read as
// inline text, as GitHub reads a cell: a leading `-` is no list.
export const cell = (text: string): string => Parser.parseInline(Lexer.lexInline(text, { gfm: true }));
export const inlineHtml = (inline: Token[]): string => Parser.parseInline(inline);

// Blocks as their source wrote them, so a fragment of a document says exactly
// what the document does.
export const blocks = (tokens: Token[]): string =>
	tokens
		.filter((t) => t.type !== "space")
		.map((t) => t.raw.replace(/\n+$/, ""))
		.join("\n\n");

// Spans as their source wrote them.
export const spans = (tokens: Token[]): string =>
	tokens
		.map((t) => t.raw)
		.join("")
		.trim();

// The definitions in `source`, wherever it nests them, of the links `tokens`
// resolve, so a fragment of it reads on its own. They are matched by target, so
// no label needs parsing; one an inline link happens to share is harmless. They
// are the definitions that won in `source`, so they go before the fragment,
// since the first of a label's definitions wins over any the fragment repeats.
export function definitions(tokens: Token[], source: TokensList): string {
	const targets = new Set(links(tokens).map((t) => target(t.href, t.title)));
	return Object.entries(source.links)
		.filter(([, def]) => targets.has(target(def.href, def.title)))
		.map(([tag, def]) => `[${tag}]: ${target(def.href, def.title)}`)
		.join("\n");
}

// A link's destination and title as Markdown writes them: an empty destination,
// or one with spaces, parentheses, or angle brackets, goes between escaped angle
// brackets.
function target(href: string, title?: string | null): string {
	const dest = href === "" || /[\s()<>\\]/.test(href) ? `<${href.replace(/[<>\\]/g, "\\$&")}>` : href;
	return `${dest}${title ? ` "${title.replace(/["\\]/g, "\\$&")}"` : ""}`;
}

// A Markdown link to `href`, which may hold any character.
export const link = (label: string, href: string, title?: string | null): string =>
	`[${label}](${target(href, title)})`;

// Every link and image in some tokens, nested ones included.
function links(tokens: Token[]): (Tokens.Link | Tokens.Image)[] {
	const found: (Tokens.Link | Tokens.Image)[] = [];
	walkTokens(tokens, (t) => {
		if (t.type === "link" || t.type === "image") found.push(t as Tokens.Link | Tokens.Image);
	});
	return found;
}

// Every link target in some tokens, nested ones included.
export const hrefs = (tokens: Token[]): string[] =>
	links(tokens)
		.filter((t) => t.type === "link")
		.map((t) => t.href);

// A heading's text, without the tags of any HTML in it and with its character
// references decoded, as GitHub reads it. A code span keeps its own text.
const plain = (tokens: Token[]): string =>
	tokens
		.map((t) => {
			if (t.type === "html") return "";
			if ("tokens" in t && t.tokens) return plain(t.tokens);
			if (!("text" in t)) return "";
			return t.type === "text" ? decodeHTMLStrict(t.text) : t.text;
		})
		.join("");

// GitHub's anchor for each heading of one document, called in document order.
// A repeated slug takes the next `-n` no earlier anchor holds, as
// github-slugger does, so `Foo`, `Foo`, `Foo-1` are `foo`, `foo-1`, `foo-1-1`.
export function slugger(): (heading: Tokens.Heading) => string {
	const counts = new Map<string, number>();
	const taken = new Set<string>();
	return (heading) => {
		const base = plain(heading.tokens)
			.toLowerCase()
			.replace(/[^\p{L}\p{M}\p{N}\p{Pc} -]/gu, "")
			.replaceAll(" ", "-");
		let slug = base;
		while (taken.has(slug)) {
			const n = (counts.get(base) ?? 0) + 1;
			counts.set(base, n);
			slug = `${base}-${n}`;
		}
		taken.add(slug);
		return slug;
	};
}

// A run of a document's blocks as HTML, a code block apart so the page can add
// a copy button.
export type Segment = { html: string } | { code: string; lang: string };

// A whole document as HTML segments, each heading carrying GitHub's anchor as
// its id, so a link to `#section` lands as it does on GitHub.
export function segments(tokens: Token[]): Segment[] {
	const slug = slugger();
	const renderer = new Renderer();
	renderer.heading = function (heading) {
		return `<h${heading.depth} id="${slug(heading)}">${this.parser.parseInline(heading.tokens)}</h${heading.depth}>\n`;
	};
	const out: Segment[] = [];
	let run: Token[] = [];
	const flush = () => {
		if (run.length > 0) out.push({ html: Parser.parse(run, { renderer }) });
		run = [];
	};
	for (const t of tokens) {
		if (t.type === "code") {
			flush();
			out.push({ code: (t as Tokens.Code).text, lang: (t as Tokens.Code).lang ?? "" });
		} else run.push(t);
	}
	flush();
	return out;
}

// `source` with each link destination `resolve` changes rewritten, inline and
// in definitions. The result must render as `source` does with its links
// resolved, so a rewrite that touched anything else, such as code that quotes
// a link, fails rather than ships.
export function rebase(source: string, resolve: (href: string) => string): string {
	const before = lex(source);
	let out = source;
	const all = [...links(before).map((t) => t.href), ...Object.values(before.links).map((l) => l.href)];
	for (const href of new Set(all)) {
		const to = resolve(href);
		if (to === href) continue;
		const from = spelled(href);
		// Callbacks, since a replacement string would read `$` in a destination.
		const dest = target(to);
		out = out
			.replace(new RegExp(`(\\]\\(\\s*)(?:<${from}>|${from})(?=[\\s)])`, "g"), (_, head: string) => head + dest)
			.replace(new RegExp(`(^(?: {0,3}>[ \\t]?)* {0,3}\\[[^\\]\\n]+\\]:[ \\t]*)(?:<${from}>|${from})(?=\\s|$)`, "gm"), (_, head: string) => head + dest);
	}
	const expected = lex(source);
	for (const t of links(expected)) t.href = resolve(t.href);
	if (html(lex(out)) !== html(expected)) {
		throw new Error(`rewriting the links in a document changed more than their destinations:\n${out}`);
	}
	return out;
}

// A pattern for `href` as the source may spell it: Markdown lets a backslash
// escape any ASCII punctuation, which the lexer drops from the destination.
const spelled = (href: string) =>
	[...href].map((c) => (/[!-/:-@[-`{-~]/.test(c) ? `\\\\?${escapeRegExp(c)}` : escapeRegExp(c))).join("");

const escapeRegExp = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
