<script lang="ts">
	// The benchmarks page's controls: a CPU and the libraries to show. The
	// page's own CSS shows what they pick, so they work with JavaScript off;
	// with it on, the address holds the view, as `?cpu=nixos&libs=rind,ring`,
	// so a number quoted elsewhere can link to it.
	import { onMount } from "svelte";

	interface Option {
		id: string;
		label: string;
		detail: string;
	}
	interface Props {
		groups: { label: string; cpus: Option[] }[];
		libraries: { id: string; name: string }[];
	}
	const { groups, libraries }: Props = $props();

	const cpuIds = groups.flatMap((g) => g.cpus.map((c) => c.id));
	const libIds = libraries.map((l) => l.id);
	let cpu = $state(cpuIds[0]);
	let libs = $state([...libIds]);
	// The address is read before it is written, so a linked view isn't lost.
	let ready = $state(false);

	onMount(() => {
		const query = new URLSearchParams(location.search);
		const picked = query.get("cpu");
		if (picked !== null && cpuIds.includes(picked)) cpu = picked;
		// An empty list shows none; one naming no library this page has, such as
		// a renamed one, shows them all rather than an empty table.
		const listed = query.get("libs");
		const known = libIds.filter((id) => listed?.split(",").includes(id));
		if (listed === "" || known.length > 0) libs = known;
		ready = true;
		// A link to a CPU elsewhere on the page, such as a gap's host, switches
		// to it in place, keeping the libraries picked.
		const follow = (e: MouseEvent) => {
			const link = (e.target as Element | null)?.closest<HTMLAnchorElement>("a[data-cpu]");
			if (!link || !cpuIds.includes(link.dataset.cpu ?? "") || e.button !== 0) return;
			if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
			e.preventDefault();
			cpu = link.dataset.cpu as string;
			document.getElementById("times")?.scrollIntoView();
		};
		document.addEventListener("click", follow);
		return () => document.removeEventListener("click", follow);
	});

	$effect(() => {
		if (!ready) return;
		const query = new URLSearchParams(location.search);
		if (cpu === cpuIds[0]) query.delete("cpu");
		else query.set("cpu", cpu);
		// Kept in the page's order, whatever order they were picked in.
		const shown = libIds.filter((id) => libs.includes(id));
		if (shown.length === libIds.length) query.delete("libs");
		else query.set("libs", shown.join(","));
		const search = query.toString().replaceAll("%2C", ",");
		history.replaceState(history.state, "", `${location.pathname}${search ? `?${search}` : ""}${location.hash}`);
	});
</script>

<form class="picker" aria-label="What to show">
	<fieldset class="cpus">
		<legend>CPU</legend>
		{#each groups as group (group.label)}
			<div class="group">
				<span class="group-label">{group.label}</span>
				{#each group.cpus as option (option.id)}
					<label>
						<input type="radio" name="cpu" id={`cpu-${option.id}`} value={option.id} bind:group={cpu} />
						<span>{option.label}</span>
						<small>{option.detail}</small>
					</label>
				{/each}
			</div>
		{/each}
	</fieldset>
	<fieldset class="libs">
		<legend>Libraries</legend>
		{#each libraries as library (library.id)}
			<label>
				<input type="checkbox" name="libs" id={`lib-${library.id}`} value={library.id} bind:group={libs} />
				<span>{library.name}</span>
			</label>
		{/each}
	</fieldset>
</form>

<style>
	.picker {
		display: grid;
		gap: 1rem;
	}
	fieldset {
		border: 1px solid var(--border);
		border-radius: 0.75rem;
		padding: 0.5rem 1rem 0.75rem;
		margin: 0;
	}
	legend {
		font-weight: 600;
		padding: 0 0.25rem;
	}
	.group {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: 0.25rem 0.5rem;
		margin-top: 0.25rem;
	}
	.group-label {
		color: var(--muted);
		font-size: 0.85rem;
		flex-basis: 100%;
	}
	label {
		display: inline-flex;
		align-items: baseline;
		gap: 0.3rem;
		padding: 0.15rem 0.6rem;
		border: 1px solid var(--border);
		border-radius: 999px;
		cursor: pointer;
		white-space: nowrap;
	}
	label:has(input:checked) {
		background: var(--surface);
		border-color: var(--accent);
	}
	label small {
		color: var(--muted);
	}
	.libs {
		display: flex;
		flex-wrap: wrap;
		gap: 0.4rem;
	}
	.libs legend {
		margin-bottom: 0.25rem;
	}
</style>
