// Loads each built page in headless Chrome under its Content-Security-Policy
// and fails if the policy refuses anything, a request fails, or the landing
// page's copy button does not put the prompt on the clipboard.
import path from "node:path";
import { prompt } from "../src/lib/landing";
import { pages } from "../src/lib/pages";

const dist = path.resolve("dist");
const server = Bun.serve({
	hostname: "127.0.0.1",
	port: 0,
	async fetch(req) {
		const { pathname } = new URL(req.url);
		const name = pathname === "/" ? "/index.html" : pathname;
		for (const file of [name, `${name}.html`]) {
			const body = Bun.file(path.join(dist, path.normalize(file)));
			if (await body.exists()) return new Response(body);
		}
		return new Response("not found", { status: 404 });
	},
});

// Spawn a fresh Chrome, never one already running with remote debugging, such
// as a signed-in browser. Its sandbox guards against hostile pages, but this
// page comes from the checkout whose code the build already ran, and Nix's
// Chromium cannot sandbox itself where Ubuntu's AppArmor denies it user
// namespaces.
const view = new Bun.WebView({ backend: { type: "chrome", url: false, argv: ["--no-sandbox"] } });
const errors: string[] = [];
// The page whose requests the network listeners are seeing.
let current = "about:blank";

// Click the copy button and read back what it put on the clipboard.
async function copies() {
	// The button appears once its island hydrates, which the policy must allow.
	await view.scrollTo("button", { timeout: 5000 });
	await view.click("button", { timeout: 5000 });
	// The handler awaits the clipboard before it relabels the button.
	const label = await view.evaluate(`new Promise((resolve) => {
		const button = document.querySelector("button");
		const poll = () => (button.textContent === "Copy" ? requestAnimationFrame(poll) : resolve(button.textContent));
		poll();
	})`);
	if (label !== "Copied") throw new Error(`the copy button says "${label}"`);
	const copied = await view.evaluate("navigator.clipboard.readText()");
	if (copied !== prompt) throw new Error(`the copy button copied ${JSON.stringify(copied)}`);
}

try {
	await view.navigate("about:blank");
	// Recorded by a script the policy does not govern, before the page's own.
	await view.cdp("Page.enable");
	await view.cdp("Page.addScriptToEvaluateOnNewDocument", {
		source: `window.__violations = [];
			document.addEventListener("securitypolicyviolation", (e) =>
				window.__violations.push(e.effectiveDirective + " refused " + (e.blockedURI || "inline code")));`,
	});
	// Every request a page makes must succeed, so a missing image or chunk fails too.
	await view.cdp("Network.enable");
	view.addEventListener("Network.responseReceived", (e) => {
		const { response } = (e as MessageEvent).data;
		if (response.status >= 400) errors.push(`${current}: ${response.url} returned ${response.status}`);
	});
	const urls = new Map<string, string>();
	view.addEventListener("Network.requestWillBeSent", (e) => {
		const { requestId, request } = (e as MessageEvent).data;
		urls.set(requestId, request.url);
	});
	view.addEventListener("Network.loadingFailed", (e) => {
		const { requestId, errorText, blockedReason } = (e as MessageEvent).data;
		errors.push(`${current}: ${urls.get(requestId)} failed: ${blockedReason ?? errorText}`);
	});
	await view.cdp("Browser.grantPermissions", {
		origin: server.url.origin,
		permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"],
	});

	for (const page of pages) {
		current = page.path;
		await view.navigate(new URL(page.path, server.url).href);
		if (page.path === "/") {
			try {
				await copies();
			} catch (e) {
				errors.push(`${page.path}: ${e instanceof Error ? e.message : e}`);
			}
		}
		for (const v of (await view.evaluate("window.__violations")) as string[]) {
			errors.push(`${page.path}: the Content-Security-Policy's ${v}`);
		}
	}
} finally {
	view.close();
	server.stop();
}

if (errors.length > 0) {
	for (const e of errors) console.error(`error: ${e}`);
	process.exit(1);
}
console.log(`site: ${pages.length} page(s) load under their policy, and the copy button copies the prompt`);
