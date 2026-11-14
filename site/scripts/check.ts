// Checks the built site in dist/, offline: every page has its Markdown twin, a
// line in llms.txt, and a sitemap entry; every link into the site or the
// repository resolves, anchors included; nothing loads from a third party; and
// the merge queue rebuilds the site when any repository file it reads or links
// changes.
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { Lexer, type Token } from "marked";
import { hrefs, lex } from "../src/lib/markdown";
import { origin, pages, twinPath } from "../src/lib/pages";
import { repoUrl, root, sources } from "../src/lib/repo";

const dist = path.resolve("dist");
const errors = new Set<string>();
const fail = (msg: string) => void errors.add(msg);

function walk(dir: string): string[] {
	return readdirSync(dir).flatMap((name) => {
		const full = path.join(dir, name);
		return statSync(full).isDirectory() ? walk(full) : [full];
	});
}
const files = walk(dist).map((f) => `/${path.relative(dist, f).split(path.sep).join("/")}`);
const text = (file: string) => readFileSync(path.join(dist, file), "utf8");

// Pages, and what lists them.
const built = files
	.filter((f) => f.endsWith(".html"))
	.map((f) => (f === "/index.html" ? "/" : f.slice(0, -".html".length)));
const listed = new Set(pages.map((p) => p.path));
for (const page of built) if (!listed.has(page)) fail(`${page} is built but missing from src/lib/pages.ts`);
const llms = text("/llms.txt");
const sitemap = text("/sitemap.xml");
for (const page of pages) {
	if (!built.includes(page.path)) fail(`${page.path} is listed in src/lib/pages.ts but not built`);
	if (!files.includes(twinPath(page))) fail(`${page.path} has no Markdown twin at ${twinPath(page)}`);
	if (!llms.includes(`](${origin}${twinPath(page)})`)) fail(`llms.txt does not list ${twinPath(page)}`);
	if (!sitemap.includes(`<loc>${origin}${page.path}</loc>`)) fail(`sitemap.xml does not list ${page.path}`);
}

// The ids a built page's anchors can name.
const ids = (file: string) =>
	new Set([...tags(text(file))].flatMap(([, attrs]) => attrs.filter(([name]) => name === "id").map(([, value]) => value)));

// GitHub's anchor for each heading of a repository Markdown file.
function anchors(file: string): Set<string> {
	const plain = (tokens: Token[]): string =>
		tokens
			.map((t) => ("tokens" in t && t.tokens ? plain(t.tokens) : "text" in t ? t.text : ""))
			.join("");
	// A repeated slug takes the next `-n` no earlier anchor holds, as github-slugger does,
	// so `Foo`, `Foo`, `Foo-1` are `foo`, `foo-1`, `foo-1-1`.
	const counts = new Map<string, number>();
	const out = new Set<string>();
	for (const t of Lexer.lex(readFileSync(path.join(root, file), "utf8"))) {
		if (t.type !== "heading") continue;
		const base = plain(t.tokens ?? [])
			.toLowerCase()
			.replace(/[^\p{L}\p{M}\p{N}\p{Pc} -]/gu, "")
			.replaceAll(" ", "-");
		let slug = base;
		while (out.has(slug)) {
			const n = (counts.get(base) ?? 0) + 1;
			counts.set(base, n);
			slug = `${base}-${n}`;
		}
		out.add(slug);
	}
	return out;
}

// The merge queue's scope for the site, from sh/dispatch.sh.
const dispatch = readFileSync(path.join(root, "sh/dispatch.sh"), "utf8").match(/^\s*\[site\]='([^']+)'/m);
if (!dispatch) throw new Error("sh/dispatch.sh has no [site] scope");
const scope = new RegExp(dispatch[1]);
const repoFiles = new Set<string>(sources);

// The build reads repository files only through repo.ts's `read`, which takes
// one of `sources`, so the scope check above sees every file it reads: no other
// source file may touch the file system or import from outside site/.
const site = path.join(root, "site");
for (const file of walk(path.join(site, "src"))) {
	const rel = path.relative(site, file);
	const body = readFileSync(file, "utf8");
	for (const m of body.matchAll(/\b(?:from|import)\s*\(?\s*["']([^"']+)["']/g)) {
		if (/^(?:node:)?fs(?:\/|$)/.test(m[1]) && rel !== path.join("src", "lib", "repo.ts")) {
			fail(`${rel}: imports ${m[1]}; read repository files through repo.ts's read() instead`);
		}
		if (m[1].startsWith(".") && path.relative(site, path.resolve(path.dirname(file), m[1])).startsWith("..")) {
			fail(`${rel}: imports ${m[1]}, outside site/; read it through repo.ts's read() instead`);
		}
	}
}

const blob = new RegExp(`^${repoUrl}/(?:blob|tree)/main/([^#?]+)`);
const raw = /^https:\/\/raw\.githubusercontent\.com\/kixel-ai\/rind\/main\/([^#?]+)/;

// Check one URL found in `from`, resolved against it as a browser would. A
// resource is fetched by the page itself, so it must be served from the site;
// a link the reader follows may go anywhere.
function check(from: string, url: string, resource: boolean) {
	let u: URL;
	let fragment: string;
	try {
		u = new URL(url, `${origin}${from}`);
		fragment = decodeURIComponent(u.hash.slice(1));
	} catch {
		return fail(`${from}: ${url} is not a valid URL`);
	}
	if (u.protocol === "data:") return;
	if (u.origin === origin) {
		const target = decodeURIComponent(u.pathname);
		const file = target.endsWith("/") ? `${target}index.html` : target;
		const found = [file, `${file}.html`].find((f) => files.includes(f));
		if (!found) return fail(`${from}: ${url} is not in the build`);
		if (fragment && !ids(found).has(fragment)) fail(`${from}: ${found} has no id "${fragment}"`);
		return;
	}
	if (u.protocol !== "https:") return fail(`${from}: ${url} is neither on this site nor https`);
	if (resource) return fail(`${from}: ${url} loads from a third party`);
	const located = `${u.origin}${u.pathname}`;
	const repoPath = located.match(blob)?.[1] ?? located.match(raw)?.[1];
	if (repoPath === undefined) return;
	const file = decodeURIComponent(repoPath).replace(/\/$/, "");
	repoFiles.add(file);
	if (!existsSync(path.join(root, file))) return fail(`${from}: ${url} names ${file}, which the repository lacks`);
	if (fragment && !(file.endsWith(".md") && anchors(file).has(fragment))) {
		fail(`${from}: ${url} names an anchor ${file} lacks`);
	}
}

// Stylesheets, inline or built, load through url() and a quoted @import, in
// any case, since CSS names are ASCII case-insensitive.
function css(file: string, body: string) {
	for (const m of body.matchAll(/url\(\s*['"]?([^'")]+)/gi)) check(file, m[1], true);
	for (const m of body.matchAll(/@import\s+['"]([^'"]+)/gi)) check(file, m[1], true);
}

// A numeric character reference's character, or U+FFFD where HTML gives one
// for zero, a surrogate, or a value past Unicode.
const codePoint = (n: number) =>
	n === 0 || n > 0x10ffff || (n >= 0xd800 && n <= 0xdfff) ? "\ufffd" : String.fromCodePoint(n);

// The URLs of a srcset's candidates. A URL may hold commas, as a data: URL
// does, so a candidate ends at whitespace, or at a comma closing the URL.
function srcset(value: string): string[] {
	const urls: string[] = [];
	let rest = value;
	for (;;) {
		rest = rest.replace(/^[\s,]+/, "");
		if (rest === "") return urls;
		const url = rest.match(/^\S+/)?.[0] ?? "";
		rest = rest.slice(url.length);
		if (url.endsWith(",")) {
			urls.push(url.replace(/,+$/, ""));
			continue;
		}
		urls.push(url);
		// Skip the descriptors, up to the comma that ends the candidate.
		rest = rest.replace(/^(?:[^,(]|\([^)]*\))*/, "");
	}
}

// Each start tag's lowercased name and attributes, however their values are
// quoted, with character references in the values decoded.
function* tags(html: string): Generator<[string, [string, string][]]> {
	const decode = (v: string) =>
		v.replace(/&(?:#(\d+)|#x([\da-f]+)|(amp|quot|apos|lt|gt));/gi, (_, dec, hex, named) =>
			dec || hex
				? codePoint(Number.parseInt(dec ?? hex, dec ? 10 : 16))
				: { amp: "&", quot: '"', apos: "'", lt: "<", gt: ">" }[named.toLowerCase() as "amp"],
		);
	const tag = /<([a-z][^\s/>]*)((?:\s*[^\s"'>/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*)\s*\/?>/gi;
	const attr = /([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;
	// Script and style bodies are raw text, and comments hold no tags.
	const markup = html
		.replace(/<!--[\s\S]*?-->/g, "")
		.replace(/(<(script|style)\b[^>]*>)[\s\S]*?<\/\2\s*>/gi, "$1");
	for (const m of markup.matchAll(tag)) {
		const attrs = [...m[2].matchAll(attr)].map((a): [string, string] => [
			a[1].toLowerCase(),
			decode(a[2] ?? a[3] ?? a[4] ?? ""),
		]);
		yield [m[1].toLowerCase(), attrs];
	}
}

// Scripts, inline or built, load every module specifier, local ones included:
// `import "x"`, `import("x")` or ``import(`x`)``, and the `from "x"` of named
// imports and re-exports, minified or not.
function js(file: string, body: string) {
	for (const m of body.matchAll(/\b(?:import\s*\(?|from)\s*(["'`])((?:(?!\1).)+)\1/g)) {
		// A template literal with a substitution names no one module to check.
		if (m[1] !== "`" || !m[2].includes("${")) check(file, m[2], true);
	}
}

// A page's markup, or an iframe's `srcdoc`, which the browser renders as one.
function page(file: string, html: string) {
	for (const [tag, attrs] of tags(html)) {
		for (const [name, value] of attrs) {
			if (tag === "base" && name === "href") {
				fail(`${file}: <base href> changes how every URL resolves, which this check does not follow`);
			} else if (name === "srcset" || name === "imagesrcset") {
				for (const url of srcset(value)) check(file, url, true);
			} else if (name === "href" && (tag === "a" || tag === "area")) {
				check(file, value, false);
			} else if (["href", "xlink:href", "src", "poster", "data", "ping", "component-url", "renderer-url"].includes(name)) {
				check(file, value, true);
			} else if (name === "style") {
				css(file, value);
			} else if (name === "srcdoc") {
				page(file, value);
			}
		}
	}
	for (const m of html.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style\s*>/gi)) css(file, m[1]);
	for (const m of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)) {
		const type = m[1].match(/\btype\s*=\s*["']?([^"'\s>]+)/i)?.[1].toLowerCase();
		if (type === undefined || type === "module" || type.endsWith("javascript")) js(file, m[2]);
	}
}

for (const file of files) {
	if (file.endsWith(".html")) {
		page(file, text(file));
	} else if (file.endsWith(".css")) {
		css(file, text(file));
	} else if (file.endsWith(".js")) {
		js(file, text(file));
	} else if (file.endsWith(".md") || file.endsWith(".txt")) {
		// Links, and URLs quoted as text, such as the prompt's.
		const body = text(file);
		for (const href of hrefs(lex(body))) check(file, href, false);
		for (const m of body.matchAll(/https?:\/\/[^\s)<>"'`\]]+/g)) check(file, m[0], false);
	}
}
for (const m of sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)) check("/sitemap.xml", m[1], false);

for (const file of repoFiles) {
	if (!scope.test(file)) fail(`sh/dispatch.sh's [site] scope misses ${file}, which the site reads or links`);
}

if (errors.size > 0) {
	for (const e of errors) console.error(`error: ${e}`);
	process.exit(1);
}
console.log(`site: ${built.length} page(s), ${files.length} files, and every link checked`);
