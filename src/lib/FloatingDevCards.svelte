<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import { Terminal, Minus, Move, ChevronRight } from "#lib/icons/index.js";

    interface Props {
        startMinimized?: boolean;
    }

    let { startMinimized = false }: Props = $props();

    interface LogEntry {
        id: string;
        timestamp: Date;
        level: "log" | "info" | "warn" | "error";
        args: Array<{
            type: "json" | "text";
            content: string;
            raw?: any;
            expanded: boolean;
        }>;
        message: string;
    }

    let isDev = $state(false);
    let isVisible = $state(false);
    let isBrowser = $state(false);
    let logs = $state<LogEntry[]>([]);
    let activeTab = $state<"console">("console");
    let logFilter = $state<"all" | "log" | "info" | "warn" | "error">("all");
    let cleanupInterval: ReturnType<typeof setInterval>;
    let isIntercepting = false;
    let lastLogContent = $state({
        log: "",
        info: "",
        warn: "",
        error: ""
    });
    let position = $state<
        | "top-left"
        | "top-right"
        | "top-center"
        | "bottom-left"
        | "bottom-right"
        | "bottom-center"
    >("bottom-center");
    let showPositionMenu = $state(false);
    let justOpenedMenu = false;

    // Drag state
    let isDragging = $state(false);
    let dragStartX = $state(0);
    let dragStartY = $state(0);
    let dragCurrentX = $state(0);
    let dragCurrentY = $state(0);
    let pillElement: HTMLDivElement | null = $state(null);
    let logsElement: HTMLDivElement | null = $state(null);
    let suppressNextClick = false;

    const filters = ["all", "log", "info", "warn", "error"] as const;
    const positions = [
        "top-left",
        "top-center",
        "top-right",
        "bottom-left",
        "bottom-center",
        "bottom-right",
    ] as const;

    const originalConsole = {
        log: console.log,
        info: console.info,
        warn: console.warn,
        error: console.error
    };

    onMount(() => {
        isBrowser = typeof window !== "undefined";

        if (isBrowser) {
            const savedPosition = localStorage.getItem(
                "floating-dev-cards-position",
            );
            if (
                savedPosition &&
                [
                    "top-left",
                    "top-right",
                    "top-center",
                    "bottom-left",
                    "bottom-right",
                    "bottom-center",
                ].includes(savedPosition)
            ) {
                position = savedPosition as typeof position;
            }

            const isProduction =
                (typeof process !== "undefined" &&
                    process.env?.NODE_ENV === "production") ||
                (typeof process !== "undefined" &&
                    process.env?.NODE_ENV === "prod") ||
                (window.location.hostname !== "localhost" &&
                    window.location.hostname !== "127.0.0.1" &&
                    !window.location.hostname.includes("localhost") &&
                    window.location.protocol === "https:") ||
                !window.location.port ||
                window.location.port === "80" ||
                window.location.port === "443";

            isDev =
                !isProduction &&
                ((typeof process !== "undefined" &&
                    process.env?.NODE_ENV === "development") ||
                    window.location.hostname === "localhost" ||
                    window.location.hostname === "127.0.0.1" ||
                    window.location.hostname.includes("localhost") ||
                    window.location.hostname.startsWith("192.168.") ||
                    [
                        "5173",
                        "5174",
                        "3000",
                        "8080",
                        "4000",
                        "8000",
                        "9000",
                    ].includes(window.location.port) ||
                    window.location.search.includes("dev") ||
                    window.location.search.includes("debug") ||
                    window.location.search.includes("local"));

            if (isDev) {
                isVisible = startMinimized ? false : true;
                interceptConsole();
                cleanupInterval = setInterval(cleanupOldLogs, 10000);
                document.addEventListener("click", handleClickOutside);
                document.addEventListener("keydown", handleKeydown);
            }
        }
    });

    onDestroy(() => {
        if (cleanupInterval) {
            clearInterval(cleanupInterval);
        }
        if (isBrowser) {
            document.removeEventListener("click", handleClickOutside);
            document.removeEventListener("keydown", handleKeydown);
        }
    });

    function handleKeydown(event: KeyboardEvent) {
        if (event.key === "Escape" && showPositionMenu) {
            showPositionMenu = false;
        }
    }

    function handlePositionClick(event: MouseEvent) {
        if (suppressNextClick) {
            suppressNextClick = false;
            return;
        }
        togglePositionMenu(event);
    }

    function toggleVisibility() {
        isVisible = !isVisible;
    }

    function togglePositionMenu(event: Event) {
        if (event) {
            event.stopPropagation();
        }
        showPositionMenu = !showPositionMenu;

        if (showPositionMenu) {
            justOpenedMenu = true;
            setTimeout(() => {
                justOpenedMenu = false;
            }, 100);
        }
    }

    function selectPosition(newPosition: typeof position) {
        position = newPosition;
        showPositionMenu = false;

        if (isBrowser) {
            localStorage.setItem("floating-dev-cards-position", position);
        }
    }

    function handleClickOutside(event: MouseEvent) {
        const target = event.target as Element;

        if (justOpenedMenu) {
            return;
        }

        if (showPositionMenu && !target.closest(".position-menu-container")) {
            showPositionMenu = false;
        }
    }

    // Drag handlers for minimized pill - only from Move button
    let isPotentialDrag = false;
    const DRAG_THRESHOLD = 8; // pixels to move before starting drag

    function handleMoveButtonDragStart(event: MouseEvent | TouchEvent) {
        if (isVisible) return; // Only drag when minimized

        event.preventDefault();
        event.stopPropagation();

        const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
        const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;

        dragStartX = clientX;
        dragStartY = clientY;
        dragCurrentX = clientX;
        dragCurrentY = clientY;
        isPotentialDrag = true;
        isDragging = false;

        document.addEventListener('mousemove', handleDragMove);
        document.addEventListener('mouseup', handleDragEnd);
        document.addEventListener('touchmove', handleDragMove, { passive: false });
        document.addEventListener('touchend', handleDragEnd);
    }

    function handleDragMove(event: MouseEvent | TouchEvent) {
        if (!isPotentialDrag) return;

        const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
        const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;

        const distance = Math.sqrt(
            Math.pow(clientX - dragStartX, 2) +
            Math.pow(clientY - dragStartY, 2)
        );

        // Only start visual dragging after threshold
        if (distance > DRAG_THRESHOLD) {
            isDragging = true;
            if ('touches' in event) {
                event.preventDefault(); // Prevent scrolling on touch
            }
        }

        if (isDragging) {
            dragCurrentX = clientX;
            dragCurrentY = clientY;
        }
    }

    function handleDragEnd() {
        document.removeEventListener('mousemove', handleDragMove);
        document.removeEventListener('mouseup', handleDragEnd);
        document.removeEventListener('touchmove', handleDragMove);
        document.removeEventListener('touchend', handleDragEnd);

        if (!isDragging) {
            // It was a click, not a drag - reset state
            isPotentialDrag = false;
            return;
        }

        // Determine the nearest snap position based on drag end coordinates
        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;

        // Determine horizontal position (left, center, right)
        let horizontal: 'left' | 'center' | 'right';
        if (dragCurrentX < viewportWidth / 3) {
            horizontal = 'left';
        } else if (dragCurrentX > (viewportWidth * 2) / 3) {
            horizontal = 'right';
        } else {
            horizontal = 'center';
        }

        // Determine vertical position (top, bottom)
        const vertical = dragCurrentY < viewportHeight / 2 ? 'top' : 'bottom';

        // Map to position
        let newPosition: typeof position;
        if (vertical === 'top') {
            if (horizontal === 'left') newPosition = 'top-left';
            else if (horizontal === 'right') newPosition = 'top-right';
            else newPosition = 'top-center';
        } else {
            if (horizontal === 'left') newPosition = 'bottom-left';
            else if (horizontal === 'right') newPosition = 'bottom-right';
            else newPosition = 'bottom-center';
        }

        selectPosition(newPosition);

        // The pointer release also fires a click on the handle; ignore it
        suppressNextClick = true;
        setTimeout(() => {
            suppressNextClick = false;
        }, 0);
        isDragging = false;
        isPotentialDrag = false;
        dragCurrentX = 0;
        dragCurrentY = 0;
    }

    function interceptConsole() {
        console.log = (...args: any[]) => {
            const currentLogContent = args.map((arg) => String(arg)).join(" ");
            if (currentLogContent !== lastLogContent.log) {
                originalConsole.log(...args);
                if (!isIntercepting) {
                    lastLogContent.log = currentLogContent;
                    addLogEntry("log", args);
                }
            }
        };

        console.info = (...args: any[]) => {
            const currentLogContent = args.map((arg) => String(arg)).join(" ");
            if (currentLogContent !== lastLogContent.info) {
                originalConsole.info(...args);
                if (!isIntercepting) {
                    lastLogContent.info = currentLogContent;
                    addLogEntry("info", args);
                }
            }
        };

        console.warn = (...args: any[]) => {
            const currentLogContent = args.map((arg) => String(arg)).join(" ");
            if (currentLogContent !== lastLogContent.warn) {
                originalConsole.warn(...args);
                if (!isIntercepting) {
                    lastLogContent.warn = currentLogContent;
                    addLogEntry("warn", args);
                }
            }
        };

        console.error = (...args: any[]) => {
            const currentLogContent = args.map((arg) => String(arg)).join(" ");
            if (currentLogContent !== lastLogContent.error) {
                originalConsole.error(...args);
                if (!isIntercepting) {
                    lastLogContent.error = currentLogContent;
                    addLogEntry("error", args);
                }
            }
        };
    }

    function addLogEntry(level: LogEntry["level"], args: any[]) {
        if (isIntercepting) {
            return;
        }

        const message = args.map((arg) => String(arg)).join(" ");

        if (
            message.includes("FloatingDevCards:") ||
            message.includes("svelte-dev-floating") ||
            message.includes("floating-console")
        ) {
            return;
        }

        const now = new Date();
        const lastLog = logs[logs.length - 1];
        if (lastLog && lastLog.message === message && lastLog.level === level) {
            return;
        }

        isIntercepting = true;

        try {
            const processedArgs = args.map((arg) => {
                if (typeof arg === "object" && arg !== null) {
                    try {
                        const jsonContent = JSON.stringify(arg, null, 2);
                        if (
                            jsonContent.length > 10 &&
                            (jsonContent.includes("{") ||
                                jsonContent.includes("["))
                        ) {
                            const lineCount = jsonContent.split("\n").length;
                            return {
                                type: "json" as const,
                                content: jsonContent,
                                raw: arg,
                                expanded: lineCount <= 6,
                            };
                        }
                    } catch {
                        // If JSON.stringify fails, treat as text
                    }
                }

                return {
                    type: "text" as const,
                    content: String(arg),
                    expanded: false,
                };
            });

            const entry: LogEntry = {
                id: crypto.randomUUID(),
                timestamp: now,
                level,
                args: processedArgs,
                message,
            };

            logs = [...logs, entry];
            cleanupOldLogs();

            requestAnimationFrame(() => {
                scrollToBottom();
            });
        } catch (error) {
            console.info("error", error);
        } finally {
            isIntercepting = false;
        }
    }

    function cleanupOldLogs() {
        const now = new Date().getTime();
        const sixSecondsAgo = now - 6000;

        if (logs.length > 20) {
            const last20 = logs.slice(-20);
            const older = logs.slice(0, -20);
            const validOlder = older.filter(
                (log) => log.timestamp.getTime() > sixSecondsAgo,
            );
            logs = [...validOlder, ...last20];
        }
    }

    function scrollToBottom() {
        if (logsElement) {
            logsElement.scrollTop = logsElement.scrollHeight;
        }
    }

    function clearLogs() {
        logs = [];
    }

    let levelCounts = $derived({
        all: logs.length,
        log: logs.filter((l) => l.level === "log").length,
        info: logs.filter((l) => l.level === "info").length,
        warn: logs.filter((l) => l.level === "warn").length,
        error: logs.filter((l) => l.level === "error").length,
    });

    let filteredLogs = $derived(
        logFilter === "all"
            ? logs
            : logs.filter((log) => log.level === logFilter),
    );

    function formatTime(date: Date) {
        return date.toLocaleTimeString("en-US", {
            hour12: false,
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit",
            fractionalSecondDigits: 3,
        });
    }

    function toggleExpansion(logId: string, argIndex: number) {
        logs = logs.map((log) => {
            if (log.id === logId) {
                return {
                    ...log,
                    args: log.args.map((arg, index) => {
                        if (index === argIndex) {
                            return { ...arg, expanded: !arg.expanded };
                        }
                        return arg;
                    }),
                };
            }
            return log;
        });
    }

    function describeJSON(content: string): string {
        try {
            const parsed = JSON.parse(content);
            if (Array.isArray(parsed)) return `Array(${parsed.length})`;
            if (parsed && typeof parsed === "object") {
                const n = Object.keys(parsed).length;
                return `Object, ${n} ${n === 1 ? "key" : "keys"}`;
            }
        } catch {
            // Not parseable, fall through
        }
        return "JSON";
    }

    function getCollapsedPreview(content: string, maxLength = 80): string {
        try {
            const parsed = JSON.parse(content);
            if (Array.isArray(parsed)) {
                return `Array(${parsed.length}) [${parsed
                    .slice(0, 2)
                    .map((v) =>
                        typeof v === "object" ? "{...}" : JSON.stringify(v),
                    )
                    .join(", ")}${parsed.length > 2 ? ", ..." : ""}]`;
            } else if (typeof parsed === "object" && parsed !== null) {
                const keys = Object.keys(parsed);
                const preview = keys
                    .slice(0, 3)
                    .map((key) => {
                        const value = parsed[key];
                        const valueStr =
                            typeof value === "object"
                                ? Array.isArray(value)
                                    ? `[${value.length}]`
                                    : "{...}"
                                : JSON.stringify(value);
                        return `${key}: ${valueStr}`;
                    })
                    .join(", ");
                return `{${preview}${keys.length > 3 ? ", ..." : ""}}`;
            }
        } catch {
            // Fallback to string truncation
        }

        const compactContent = content
            .replace(/\s+/g, " ")
            .replace(/\n/g, " ")
            .trim();

        if (compactContent.length <= maxLength) return compactContent;

        const truncated = compactContent.substring(0, maxLength);
        const lastComma = truncated.lastIndexOf(",");
        const lastColon = truncated.lastIndexOf(":");

        if (lastColon > lastComma && lastColon > maxLength - 20) {
            return truncated.substring(0, lastColon + 1) + " ...";
        } else if (lastComma > maxLength - 20) {
            return truncated.substring(0, lastComma) + ", ...";
        }

        return truncated + "...";
    }

    function highlightJSON(jsonString: string): string {
        let highlighted = jsonString;

        highlighted = highlighted.replace(
            /("(?:[^"\\]|\\.)*")(\s*):/g,
            '<span class="json-key">$1</span>$2<span class="json-colon">:</span>',
        );

        highlighted = highlighted.replace(
            /:\s*("(?:[^"\\]|\\.)*")/g,
            ': <span class="json-string">$1</span>',
        );
        highlighted = highlighted.replace(
            /\[\s*("(?:[^"\\]|\\.)*")/g,
            '[<span class="json-string">$1</span>',
        );
        highlighted = highlighted.replace(
            /,\s*("(?:[^"\\]|\\.)*")/g,
            ', <span class="json-string">$1</span>',
        );

        highlighted = highlighted.replace(
            /:\s*(-?\d+\.?\d*)\b/g,
            ': <span class="json-number">$1</span>',
        );
        highlighted = highlighted.replace(
            /\[\s*(-?\d+\.?\d*)\b/g,
            '[<span class="json-number">$1</span>',
        );
        highlighted = highlighted.replace(
            /,\s*(-?\d+\.?\d*)\b/g,
            ', <span class="json-number">$1</span>',
        );

        highlighted = highlighted.replace(
            /:\s*(true|false)\b/g,
            ': <span class="json-boolean">$1</span>',
        );
        highlighted = highlighted.replace(
            /\[\s*(true|false)\b/g,
            '[<span class="json-boolean">$1</span>',
        );
        highlighted = highlighted.replace(
            /,\s*(true|false)\b/g,
            ', <span class="json-boolean">$1</span>',
        );

        highlighted = highlighted.replace(
            /:\s*(null)\b/g,
            ': <span class="json-null">$1</span>',
        );
        highlighted = highlighted.replace(
            /\[\s*(null)\b/g,
            '[<span class="json-null">$1</span>',
        );
        highlighted = highlighted.replace(
            /,\s*(null)\b/g,
            ', <span class="json-null">$1</span>',
        );

        highlighted = highlighted.replace(
            /([{}[\]])/g,
            '<span class="json-bracket">$1</span>',
        );

        highlighted = highlighted.replace(
            /,(?![^"]*"[^"]*:)/g,
            '<span class="json-comma">,</span>',
        );

        return highlighted;
    }
</script>


{#if isDev}
    <div
        class="sv-console {position}"
        class:is-top={position.startsWith("top")}
    >
        {#if isVisible}
            <section class="shell panel" aria-label="Console">
                <div class="core panel-core">
                    <header class="toolbar">
                        <div class="tabs" role="tablist" aria-label="Filter logs">
                            {#each filters as filter}
                                <button
                                    type="button"
                                    role="tab"
                                    class="tab"
                                    class:active={logFilter === filter}
                                    aria-selected={logFilter === filter}
                                    onclick={() => (logFilter = filter)}
                                >
                                    <span class="tab-label">{filter}</span>
                                    <span
                                        class="tab-count"
                                        data-level={filter}
                                        class:has-items={levelCounts[filter] > 0}
                                    >
                                        {levelCounts[filter]}
                                    </span>
                                </button>
                            {/each}
                        </div>
                        <div class="actions">
                            <button
                                type="button"
                                class="text-btn"
                                onclick={clearLogs}
                                disabled={logs.length === 0}
                            >
                                Clear
                            </button>
                            <button
                                type="button"
                                class="icon-btn"
                                aria-label="Minimize console"
                                title="Minimize"
                                onclick={toggleVisibility}
                            >
                                <Minus size={16} />
                            </button>
                        </div>
                    </header>

                    <div class="logs" bind:this={logsElement}>
                        {#each filteredLogs as log (log.id)}
                            <article class="row" data-level={log.level}>
                                <time
                                    class="time"
                                    datetime={log.timestamp.toISOString()}
                                >
                                    {formatTime(log.timestamp)}
                                </time>
                                <div class="body">
                                    <span class="sr-only">{log.level}:</span>
                                    {#each log.args as arg, index}
                                        {#if arg.type === "json"}
                                            <div class="json" class:open={arg.expanded}>
                                                <button
                                                    type="button"
                                                    class="json-toggle"
                                                    aria-expanded={arg.expanded}
                                                    onclick={() => toggleExpansion(log.id, index)}
                                                >
                                                    <span class="chevron">
                                                        <ChevronRight size={12} />
                                                    </span>
                                                    <span class="json-kind">
                                                        {describeJSON(arg.content)}
                                                    </span>
                                                    {#if !arg.expanded}
                                                        <span class="json-preview">
                                                            {@html highlightJSON(getCollapsedPreview(arg.content))}
                                                        </span>
                                                    {/if}
                                                </button>
                                                {#if arg.expanded}
                                                    <pre class="json-content">{@html highlightJSON(arg.content)}</pre>
                                                {/if}
                                            </div>
                                        {:else}
                                            <span class="text">{arg.content}</span>{#if index < log.args.length - 1}{" "}{/if}
                                        {/if}
                                    {/each}
                                </div>
                            </article>
                        {:else}
                            <div class="empty">
                                <span class="empty-icon"><Terminal size={18} /></span>
                                <p class="empty-title">
                                    {logFilter === "all" ? "No logs yet" : `No ${logFilter} messages`}
                                </p>
                                <p class="empty-hint">
                                    Calls to console.log, info, warn and error show up here.
                                </p>
                            </div>
                        {/each}
                    </div>
                </div>
            </section>
        {:else}
            <div
                class="shell pill position-menu-container"
                class:dragging={isDragging}
                bind:this={pillElement}
                style={isDragging
                    ? `transform: translate(${dragCurrentX - dragStartX}px, ${dragCurrentY - dragStartY}px) scale(1.04);`
                    : ""}
            >
                <div class="core pill-core">
                    <button
                        type="button"
                        class="pill-btn"
                        onclick={toggleVisibility}
                        aria-label="Open console ({logs.length} logs)"
                        title="Open console"
                    >
                        <Terminal size={18} />
                        {#if logs.length > 0}
                            <span
                                class="pill-count"
                                class:has-errors={levelCounts.error > 0}
                            >
                                {logs.length}
                            </span>
                        {/if}
                    </button>
                    <span class="pill-divider" aria-hidden="true"></span>
                    <button
                        type="button"
                        class="pill-btn handle"
                        aria-label="Move console"
                        aria-haspopup="menu"
                        aria-expanded={showPositionMenu}
                        title="Drag to move, click to pick a corner"
                        onmousedown={handleMoveButtonDragStart}
                        ontouchstart={handleMoveButtonDragStart}
                        onclick={handlePositionClick}
                    >
                        <Move size={16} />
                    </button>
                </div>

                {#if showPositionMenu}
                    <div class="shell menu" role="menu" aria-label="Console position">
                        <div class="core menu-core">
                            <div class="pos-grid">
                                {#each positions as option}
                                    <button
                                        type="button"
                                        role="menuitemradio"
                                        class="pos"
                                        class:active={position === option}
                                        aria-checked={position === option}
                                        aria-label={option.replace("-", " ")}
                                        title={option.replace("-", " ")}
                                        onclick={() => selectPosition(option)}
                                    >
                                        <span class="pos-screen">
                                            <span class="pos-mark {option}"></span>
                                        </span>
                                    </button>
                                {/each}
                            </div>
                        </div>
                    </div>
                {/if}
            </div>
        {/if}
    </div>
{/if}

<style>
    /* ----------------------------------------
       Tokens (light first, dark via system)
       ---------------------------------------- */

    .sv-console {
        --sv-ease: cubic-bezier(0.32, 0.72, 0, 1);
        --sv-font: "Geist", ui-sans-serif, system-ui, -apple-system,
            "Segoe UI", sans-serif;
        --sv-mono: "Geist Mono", ui-monospace, "SF Mono", "JetBrains Mono",
            Menlo, Consolas, monospace;

        --sv-shell: rgb(244 244 245 / 0.62);
        --sv-shell-ring: rgb(24 24 27 / 0.07);
        --sv-core: rgb(255 255 255 / 0.94);
        --sv-core-highlight: inset 0 1px 0 rgb(255 255 255 / 0.9);
        --sv-shadow: 0 1px 2px rgb(24 24 27 / 0.04),
            0 18px 40px -12px rgb(24 24 27 / 0.16);

        --sv-text: #18181b;
        --sv-muted: #71717a;
        --sv-faint: #a1a1aa;
        --sv-line: rgb(24 24 27 / 0.06);
        --sv-hover: rgb(24 24 27 / 0.045);
        --sv-active: rgb(24 24 27 / 0.08);

        --sv-error: #dc2626;
        --sv-error-bg: rgb(220 38 38 / 0.05);
        --sv-warn: #b45309;
        --sv-warn-bg: rgb(217 119 6 / 0.06);
        --sv-info: #2563eb;

        --sv-json-key: #3f3f46;
        --sv-json-string: #15803d;
        --sv-json-number: #0369a1;
        --sv-json-boolean: #be185d;

        position: fixed;
        z-index: 10000;
        font-family: var(--sv-font);
        font-size: 12px;
        line-height: 1.5;
        color: var(--sv-text);
        -webkit-font-smoothing: antialiased;
    }

    @media (prefers-color-scheme: dark) {
        .sv-console {
            --sv-shell: rgb(39 39 42 / 0.5);
            --sv-shell-ring: rgb(255 255 255 / 0.07);
            --sv-core: rgb(15 15 17 / 0.92);
            --sv-core-highlight: inset 0 1px 0 rgb(255 255 255 / 0.06);
            --sv-shadow: 0 1px 2px rgb(0 0 0 / 0.3),
                0 24px 48px -12px rgb(0 0 0 / 0.55);

            --sv-text: #f4f4f5;
            --sv-muted: #a1a1aa;
            --sv-faint: #71717a;
            --sv-line: rgb(255 255 255 / 0.06);
            --sv-hover: rgb(255 255 255 / 0.045);
            --sv-active: rgb(255 255 255 / 0.09);

            --sv-error: #f87171;
            --sv-error-bg: rgb(248 113 113 / 0.07);
            --sv-warn: #fbbf24;
            --sv-warn-bg: rgb(251 191 36 / 0.06);
            --sv-info: #60a5fa;

            --sv-json-key: #d4d4d8;
            --sv-json-string: #86efac;
            --sv-json-number: #7dd3fc;
            --sv-json-boolean: #f9a8d4;
        }
    }

    .sv-console button {
        font: inherit;
        color: inherit;
        background: none;
        border: 0;
        margin: 0;
        padding: 0;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
    }

    .sv-console button:focus-visible {
        outline: 2px solid var(--sv-info);
        outline-offset: 2px;
    }

    .sr-only {
        position: absolute;
        width: 1px;
        height: 1px;
        overflow: hidden;
        clip: rect(0 0 0 0);
        white-space: nowrap;
    }

    /* ----------------------------------------
       Placement
       ---------------------------------------- */

    .sv-console.top-left { top: 20px; left: 20px; }
    .sv-console.top-right { top: 20px; right: 20px; }
    .sv-console.bottom-left { bottom: 20px; left: 20px; }
    .sv-console.bottom-right { bottom: 20px; right: 20px; }

    .sv-console.top-center,
    .sv-console.bottom-center {
        left: 50%;
        transform: translateX(-50%);
    }
    .sv-console.top-center { top: 20px; }
    .sv-console.bottom-center { bottom: 20px; }

    /* ----------------------------------------
       Double bezel: outer shell + inner core
       ---------------------------------------- */

    .shell {
        background: var(--sv-shell);
        box-shadow: 0 0 0 1px var(--sv-shell-ring), var(--sv-shadow);
        backdrop-filter: blur(20px) saturate(160%);
        -webkit-backdrop-filter: blur(20px) saturate(160%);
    }

    .core {
        background: var(--sv-core);
        box-shadow: var(--sv-core-highlight), 0 0 0 1px var(--sv-line);
    }

    /* ----------------------------------------
       Minimized pill
       ---------------------------------------- */

    .pill {
        position: relative;
        border-radius: 999px;
        padding: 3px;
        user-select: none;
        transition: transform 0.5s var(--sv-ease);
    }

    .pill.dragging {
        transition: none;
        cursor: grabbing;
    }

    .pill-core {
        display: flex;
        align-items: center;
        gap: 2px;
        padding: 3px;
        border-radius: 999px;
    }

    .pill-btn {
        position: relative;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 6px;
        height: 32px;
        min-width: 32px;
        padding: 0 8px !important;
        border-radius: 999px;
        color: var(--sv-muted) !important;
        transition:
            background-color 0.4s var(--sv-ease),
            color 0.4s var(--sv-ease),
            transform 0.4s var(--sv-ease);
    }

    .pill-btn:hover {
        background: var(--sv-hover) !important;
        color: var(--sv-text) !important;
    }

    .pill-btn:active {
        transform: scale(0.94);
    }

    .pill-btn.handle {
        cursor: grab;
        touch-action: none;
    }

    .pill-count {
        font-family: var(--sv-mono);
        font-size: 11px;
        font-variant-numeric: tabular-nums;
        color: var(--sv-text);
    }

    .pill-count.has-errors {
        color: var(--sv-error);
    }

    .pill-divider {
        width: 1px;
        height: 16px;
        background: var(--sv-line);
    }

    /* ----------------------------------------
       Position menu
       ---------------------------------------- */

    .menu {
        position: absolute;
        left: 0;
        right: 0;
        width: max-content;
        margin-inline: auto;
        padding: 3px;
        border-radius: 16px;
        z-index: 1;
        transform-origin: bottom center;
        animation: sv-pop 0.5s var(--sv-ease);
    }

    .sv-console:not(.is-top) .menu { bottom: calc(100% + 8px); }
    .sv-console.is-top .menu {
        top: calc(100% + 8px);
        transform-origin: top center;
    }
    .sv-console.top-left .menu,
    .sv-console.bottom-left .menu { margin-left: 0; }
    .sv-console.top-right .menu,
    .sv-console.bottom-right .menu { margin-right: 0; }

    .menu-core {
        border-radius: 13px;
        padding: 6px;
    }

    .pos-grid {
        display: grid;
        grid-template-columns: repeat(3, auto);
        gap: 4px;
    }

    .pos {
        display: grid;
        place-items: center;
        width: 44px;
        height: 34px;
        border-radius: 9px;
        transition: background-color 0.4s var(--sv-ease);
    }

    .pos:hover { background: var(--sv-hover) !important; }
    .pos.active { background: var(--sv-active) !important; }

    .pos-screen {
        position: relative;
        width: 28px;
        height: 18px;
        border-radius: 4px;
        box-shadow: inset 0 0 0 1px var(--sv-faint);
        opacity: 0.6;
        transition: opacity 0.4s var(--sv-ease);
    }

    .pos:hover .pos-screen,
    .pos.active .pos-screen { opacity: 1; }

    .pos-mark {
        position: absolute;
        width: 9px;
        height: 3px;
        border-radius: 2px;
        background: var(--sv-muted);
    }

    .pos.active .pos-mark { background: var(--sv-text); }

    .pos-mark.top-left { top: 3px; left: 3px; }
    .pos-mark.top-center { top: 3px; left: 9.5px; }
    .pos-mark.top-right { top: 3px; right: 3px; }
    .pos-mark.bottom-left { bottom: 3px; left: 3px; }
    .pos-mark.bottom-center { bottom: 3px; left: 9.5px; }
    .pos-mark.bottom-right { bottom: 3px; right: 3px; }

    /* ----------------------------------------
       Expanded panel
       ---------------------------------------- */

    .panel {
        width: 480px;
        max-width: calc(100vw - 32px);
        padding: 4px;
        border-radius: 20px;
        transform-origin: bottom center;
        animation: sv-panel 0.6s var(--sv-ease);
    }

    .sv-console.is-top .panel { transform-origin: top center; }
    .sv-console.top-left .panel,
    .sv-console.bottom-left .panel { transform-origin: bottom left; }
    .sv-console.top-right .panel,
    .sv-console.bottom-right .panel { transform-origin: bottom right; }
    .sv-console.top-left .panel { transform-origin: top left; }
    .sv-console.top-right .panel { transform-origin: top right; }

    .panel-core {
        display: flex;
        flex-direction: column;
        border-radius: 16px;
        overflow: hidden;
    }

    .toolbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
        padding: 8px 8px 8px 10px;
        border-bottom: 1px solid var(--sv-line);
    }

    .tabs {
        display: flex;
        gap: 2px;
        min-width: 0;
        overflow-x: auto;
        scrollbar-width: none;
    }

    .tabs::-webkit-scrollbar { display: none; }

    .tab {
        display: inline-flex;
        align-items: baseline;
        gap: 6px;
        padding: 5px 10px !important;
        border-radius: 999px;
        color: var(--sv-muted) !important;
        white-space: nowrap;
        transition:
            background-color 0.4s var(--sv-ease),
            color 0.4s var(--sv-ease);
    }

    .tab-label {
        text-transform: capitalize;
        font-weight: 500;
    }

    .tab:hover { color: var(--sv-text) !important; }

    .tab.active {
        background: var(--sv-active) !important;
        color: var(--sv-text) !important;
    }

    .tab-count {
        font-family: var(--sv-mono);
        font-size: 10.5px;
        font-variant-numeric: tabular-nums;
        color: var(--sv-faint);
    }

    .tab-count.has-items[data-level="error"] { color: var(--sv-error); }
    .tab-count.has-items[data-level="warn"] { color: var(--sv-warn); }

    .actions {
        display: flex;
        align-items: center;
        gap: 2px;
        flex-shrink: 0;
    }

    .text-btn {
        padding: 5px 10px !important;
        border-radius: 999px;
        font-weight: 500;
        color: var(--sv-muted) !important;
        transition:
            background-color 0.4s var(--sv-ease),
            color 0.4s var(--sv-ease),
            transform 0.4s var(--sv-ease);
    }

    .text-btn:hover:not(:disabled) {
        background: var(--sv-hover) !important;
        color: var(--sv-text) !important;
    }

    .text-btn:active:not(:disabled) { transform: scale(0.96); }

    .text-btn:disabled {
        opacity: 0.4;
        cursor: default;
    }

    .icon-btn {
        display: grid;
        place-items: center;
        width: 28px;
        height: 28px;
        border-radius: 999px;
        color: var(--sv-muted) !important;
        transition:
            background-color 0.4s var(--sv-ease),
            color 0.4s var(--sv-ease),
            transform 0.4s var(--sv-ease);
    }

    .icon-btn:hover {
        background: var(--sv-hover) !important;
        color: var(--sv-text) !important;
    }

    .icon-btn:active { transform: scale(0.92); }

    /* ----------------------------------------
       Log rows
       ---------------------------------------- */

    .logs {
        min-height: 220px;
        max-height: min(380px, 55vh);
        overflow-y: auto;
        overscroll-behavior: contain;
        font-family: var(--sv-mono);
        font-size: 11.5px;
        line-height: 1.6;
        scrollbar-width: thin;
        scrollbar-color: var(--sv-active) transparent;
    }

    .row {
        display: grid;
        grid-template-columns: auto minmax(0, 1fr);
        gap: 12px;
        padding: 7px 14px;
        border-bottom: 1px solid var(--sv-line);
        box-shadow: inset 2px 0 0 transparent;
        animation: sv-row 0.5s var(--sv-ease);
    }

    .row:last-child { border-bottom: 0; }

    .row[data-level="info"] { box-shadow: inset 2px 0 0 var(--sv-info); }

    .row[data-level="warn"] {
        background: var(--sv-warn-bg);
        box-shadow: inset 2px 0 0 var(--sv-warn);
    }

    .row[data-level="error"] {
        background: var(--sv-error-bg);
        box-shadow: inset 2px 0 0 var(--sv-error);
    }

    .time {
        color: var(--sv-faint);
        font-variant-numeric: tabular-nums;
        white-space: nowrap;
    }

    .body {
        min-width: 0;
        color: var(--sv-text);
    }

    .row[data-level="warn"] .text { color: var(--sv-warn); }
    .row[data-level="error"] .text { color: var(--sv-error); }

    .text {
        white-space: pre-wrap;
        word-break: break-word;
    }

    /* ----------------------------------------
       JSON
       ---------------------------------------- */

    .json {
        margin: 4px 0 2px;
        border-radius: 10px;
        box-shadow: inset 0 0 0 1px var(--sv-line);
        overflow: hidden;
    }

    .json-toggle {
        display: flex;
        align-items: center;
        gap: 8px;
        width: 100%;
        padding: 6px 10px !important;
        text-align: left;
        color: var(--sv-muted) !important;
        transition: background-color 0.4s var(--sv-ease);
    }

    .json-toggle:hover { background: var(--sv-hover) !important; }

    .chevron {
        display: grid;
        place-items: center;
        flex-shrink: 0;
        transition: transform 0.5s var(--sv-ease);
    }

    .json.open .chevron { transform: rotate(90deg); }

    .json-kind {
        flex-shrink: 0;
        font-family: var(--sv-font);
        font-size: 11px;
        font-weight: 500;
        color: var(--sv-muted);
    }

    .json-preview {
        min-width: 0;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        color: var(--sv-text);
    }

    .json-content {
        margin: 0;
        padding: 8px 12px 10px;
        max-height: 280px;
        overflow: auto;
        border-top: 1px solid var(--sv-line);
        font: inherit;
        white-space: pre;
        color: var(--sv-text);
        animation: sv-fade 0.4s var(--sv-ease);
    }

    .sv-console :global(.json-key) { color: var(--sv-json-key); }
    .sv-console :global(.json-string) { color: var(--sv-json-string); }
    .sv-console :global(.json-number) { color: var(--sv-json-number); }
    .sv-console :global(.json-boolean) { color: var(--sv-json-boolean); }
    .sv-console :global(.json-null) {
        color: var(--sv-faint);
        font-style: italic;
    }
    .sv-console :global(.json-bracket),
    .sv-console :global(.json-comma),
    .sv-console :global(.json-colon) { color: var(--sv-faint); }

    /* ----------------------------------------
       Empty state
       ---------------------------------------- */

    .empty {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 4px;
        min-height: 220px;
        padding: 24px;
        text-align: center;
        font-family: var(--sv-font);
    }

    .empty-icon {
        display: grid;
        place-items: center;
        width: 36px;
        height: 36px;
        margin-bottom: 8px;
        border-radius: 999px;
        color: var(--sv-muted);
        box-shadow: inset 0 0 0 1px var(--sv-line);
    }

    .empty-title {
        margin: 0;
        font-size: 13px;
        font-weight: 500;
        color: var(--sv-text);
    }

    .empty-hint {
        margin: 0;
        max-width: 32ch;
        color: var(--sv-muted);
    }

    /* ----------------------------------------
       Motion
       ---------------------------------------- */

    @keyframes sv-panel {
        from {
            opacity: 0;
            transform: translateY(8px) scale(0.97);
        }
    }

    @keyframes sv-pop {
        from {
            opacity: 0;
            transform: translateY(4px) scale(0.96);
        }
    }

    @keyframes sv-row {
        from {
            opacity: 0;
            transform: translateY(4px);
        }
    }

    @keyframes sv-fade {
        from { opacity: 0; }
    }

    @media (prefers-reduced-motion: reduce) {
        .sv-console *,
        .sv-console *::before,
        .sv-console *::after {
            animation: none !important;
            transition: none !important;
        }
    }

    @media (prefers-reduced-transparency: reduce) {
        .shell {
            backdrop-filter: none;
            -webkit-backdrop-filter: none;
        }
        .core { background: var(--sv-text); background: Canvas; }
    }

    /* ----------------------------------------
       Small screens
       ---------------------------------------- */

    @media (max-width: 520px) {
        .sv-console.top-left,
        .sv-console.bottom-left { left: 12px; }
        .sv-console.top-right,
        .sv-console.bottom-right { right: 12px; }
        .sv-console.top-left,
        .sv-console.top-right,
        .sv-console.top-center { top: 12px; }
        .sv-console.bottom-left,
        .sv-console.bottom-right,
        .sv-console.bottom-center { bottom: 12px; }

        .panel { max-width: calc(100vw - 24px); }
        .toolbar { padding-left: 6px; }
        .row { padding: 7px 10px; gap: 8px; }
        .time { font-size: 10.5px; }
    }
</style>
