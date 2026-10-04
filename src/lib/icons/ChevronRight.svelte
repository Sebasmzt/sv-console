<script lang="ts">
	interface Props {
		size?: number;
		class?: string;
	}
	let { size = 24, class: className = '' }: Props = $props();
</script>

<!-- Tabler: chevron-right -->
<svg
	xmlns="http://www.w3.org/2000/svg"
	width={size}
	height={size}
	viewBox="0 0 24 24"
	fill="none"
	stroke="currentColor"
	stroke-width="1.5"
	stroke-linecap="round"
	stroke-linejoin="round"
	class={className}
>
	<path stroke="none" d="M0 0h24v24H0z" fill="none"/>
	<path d="M9 6l6 6l-6 6" />
</svg>
