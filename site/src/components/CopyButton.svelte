<script>
	// Copies `text`. It renders only once hydrated, so a page read without
	// JavaScript shows no button that does nothing.
	import { onMount } from "svelte";

	let { text } = $props();
	let ready = $state(false);
	let label = $state("Copy");

	onMount(() => {
		ready = true;
	});

	async function copy() {
		try {
			await navigator.clipboard.writeText(text);
			label = "Copied";
		} catch {
			label = "Copy failed";
		}
		setTimeout(() => {
			label = "Copy";
		}, 2000);
	}
</script>

{#if ready}
	<button type="button" onclick={copy}>{label}</button>
{/if}

<style>
	button {
		position: absolute;
		top: 0.5rem;
		right: 0.5rem;
		font: inherit;
		font-size: 0.85rem;
		padding: 0.25rem 0.75rem;
		border: 1px solid var(--border);
		border-radius: 0.375rem;
		background: var(--bg);
		color: var(--fg);
		cursor: pointer;
	}
	button:hover {
		border-color: var(--accent);
	}
</style>
