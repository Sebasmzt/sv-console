<script lang="ts">
	interface Props {
		size?: number;
		class?: string;
	}
	let { size = 24, class: className = '' }: Props = $props();
</script>

<!-- Tabler: x -->
<svg
	xmlns="http://www.w3.org/2000/svg"
	width={size}
	height={size}
	viewBox="0 0 24 24"
	fill="none"
	stroke="currentColor"
	stroke-width="2"
	stroke-linecap="round"
	stroke-linejoin="round"
	class={className}
>
	<path stroke="none" d="M0 0h24v24H0z" fill="none"/>
	<path d="M18 6l-12 12" />
	<path d="M6 6l12 12" />
</svg>
