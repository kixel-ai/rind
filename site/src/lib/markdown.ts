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

// Markdown for blocks, with reference links written inline, so a fragment
// reads on its own without the definitions at the end of its source.
export function markdown(blocks: Token[]): string {
	return blocks
		.map(block)
		.filter((b) => b !== "")
		.join("\n\n");
}

function block(token: Token): string {
	switch (token.type) {
		case "space":
		// A reference definition is written inline at each link that uses it.
		case "def":
			return "";
		case "paragraph":
			return inline(token.tokens ?? []);
		case "code":
			return token.raw.trimEnd();
		case "list": {
			const list = token as Tokens.List;
			const start = list.start === "" ? 1 : list.start;
			return list.items
				.map((item, i) => {
					if (item.task) throw new Error(`no Markdown rendering for a task list item: ${item.raw}`);
					const marker = list.ordered ? `${start + i}.` : "-";
					const body = item.tokens.map((t) => (t.type === "text" ? inline(t.tokens ?? []) : block(t)));
					// A continuation line is indented past the marker, or it leaves the item.
					return `${marker} ${body.join("\n").replaceAll("\n", `\n${" ".repeat(marker.length + 1)}`)}`;
				})
				.join("\n");
		}
		default:
			throw new Error(`no Markdown rendering for a ${token.type} block`);
	}
}

// Inline tokens as Markdown. In a link's label, marked has already removed the
// escapes from text, so `label` puts them back where a character would close the
// label or start a span.
export function inline(tokens: Token[], label = false): string {
	return tokens
		.map((t) => {
			switch (t.type) {
				case "text":
					if (t.tokens) return inline(t.tokens, label);
					return label ? t.raw.replace(/[\\[\]*_`<!]/g, "\\$&") : t.raw;
				case "strong":
					return `**${inline(t.tokens ?? [], label)}**`;
				case "em":
					return `*${inline(t.tokens ?? [], label)}*`;
				case "link":
					return link(inline(t.tokens ?? [], true), t.href, t.title);
				case "codespan":
				case "escape":
				case "br":
					return t.raw;
				default:
					throw new Error(`no Markdown rendering for a ${t.type} span`);
			}
		})
		.join("");
}

// A Markdown link to `href`, which may hold any character: one with spaces,
// parentheses, or angle brackets goes between escaped angle brackets.
export function link(label: string, href: string, title?: string | null): string {
	const dest = /[\s()<>\\]/.test(href) ? `<${href.replace(/[<>\\]/g, "\\$&")}>` : href;
	return `[${label}](${dest}${title ? ` "${title.replace(/["\\]/g, "\\$&")}"` : ""})`;
}

// Every link target in some tokens, nested ones included.
export function hrefs(tokens: Token[]): string[] {
	const found: string[] = [];
	const walk = (list: Token[]) => {
		for (const t of list) {
			if (t.type === "link") found.push(t.href);
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
