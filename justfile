# List available recipes
default:
    @just --list

# Start the Vite dev server
dev:
    bun run dev

# Format source files with oxfmt
fmt:
    bun run format

# Remove build output and node_modules
clean:
    rm -rf .svelte-kit dist node_modules
