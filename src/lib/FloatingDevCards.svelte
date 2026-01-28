<script lang="ts">
    import { onMount, onDestroy } from "svelte";
    import { Terminal, Minus, X, Move, ChevronDown } from "$lib/icons";
    import * as DropdownMenu from "$lib/components/ui/dropdown-menu";
    import { Button } from "$lib/components/ui/button";

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
    let dragStartX = 0;
    let dragStartY = 0;
    let dragCurrentX = $state(0);
    let dragCurrentY = $state(0);
    let pillElement: HTMLDivElement | null = null;

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
            }
        }
    });

    onDestroy(() => {
        if (cleanupInterval) {
            clearInterval(cleanupInterval);
        }
        if (isBrowser) {
            document.removeEventListener("click", handleClickOutside);
        }
    });

    function toggleVisibility() {
        isVisible = !isVisible;
    }

    function togglePositionMenu(event?: Event) {
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
        if (isBrowser) {
            const consoleContainer = document.querySelector(".console-logs");
            if (consoleContainer) {
                consoleContainer.scrollTop = consoleContainer.scrollHeight;
            }
        }
    }

    function clearLogs() {
        logs = [];
    }

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

    function getLogLevelColor(level: LogEntry["level"]) {
        switch (level) {
            case "error":
                return "#ff4444";
            case "warn":
                return "#ffaa00";
            case "info":
                return "#4488ff";
            default:
                return "inherit";
        }
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
        class="sv-console"
        class:top-left={position === "top-left"}
        class:top-right={position === "top-right"}
        class:bottom-left={position === "bottom-left"}
        class:bottom-right={position === "bottom-right"}
        class:bottom-center={position === "bottom-center"}
    >
        {#if isVisible}
            <div class="console-panel glass">
                <div class="panel-content">
                    <div class="console-section">
                        <div class="console-controls">
                            <div class="filter-group">
                                <DropdownMenu.Root>
                                    <DropdownMenu.Trigger class="log-filter">
                                        <span>
                                            {#if logFilter === "all"}
                                                All ({logs.length})
                                            {:else if logFilter === "log"}
                                                Log ({logs.filter((l) => l.level === "log").length})
                                            {:else if logFilter === "info"}
                                                Info ({logs.filter((l) => l.level === "info").length})
                                            {:else if logFilter === "warn"}
                                                Warn ({logs.filter((l) => l.level === "warn").length})
                                            {:else if logFilter === "error"}
                                                Error ({logs.filter((l) => l.level === "error").length})
                                            {/if}
                                        </span>
                                        <ChevronDown size={14} />
                                    </DropdownMenu.Trigger>
                                    <DropdownMenu.Content align="start" class="dropdown-content glass">
                                        <DropdownMenu.RadioGroup bind:value={logFilter}>
                                            <DropdownMenu.RadioItem value="all">
                                                All ({logs.length})
                                            </DropdownMenu.RadioItem>
                                            <DropdownMenu.RadioItem value="log">
                                                Log ({logs.filter((l) => l.level === "log").length})
                                            </DropdownMenu.RadioItem>
                                            <DropdownMenu.RadioItem value="info">
                                                Info ({logs.filter((l) => l.level === "info").length})
                                            </DropdownMenu.RadioItem>
                                            <DropdownMenu.RadioItem value="warn">
                                                Warn ({logs.filter((l) => l.level === "warn").length})
                                            </DropdownMenu.RadioItem>
                                            <DropdownMenu.RadioItem value="error">
                                                Error ({logs.filter((l) => l.level === "error").length})
                                            </DropdownMenu.RadioItem>
                                        </DropdownMenu.RadioGroup>
                                    </DropdownMenu.Content>
                                </DropdownMenu.Root>
                            </div>
                            <Button variant="destructive" size="sm" class="clear-btn" onclick={clearLogs}>
                                <X size={14} />
                                Clear
                            </Button>
                            <Button
                                variant="ghost"
                                size="icon-sm"
                                onclick={toggleVisibility}
                                class="minimize-btn"
                            >
                                <Minus size={16} />
                            </Button>
                        </div>

                        <div class="console-logs">
                            {#each filteredLogs as log (log.id)}
                                <div
                                    class="log-entry"
                                    class:error={log.level === "error"}
                                    class:warn={log.level === "warn"}
                                    class:info={log.level === "info"}
                                >
                                    <div class="log-header">
                                        <span class="log-time">{formatTime(log.timestamp)}</span>
                                        <span class="log-level" data-level={log.level}>
                                            {log.level.toUpperCase()}
                                        </span>
                                    </div>
                                    <div class="log-content">
                                        {#each log.args as arg, index}
                                            {#if index > 0}<span class="log-separator"> </span>{/if}
                                            {#if arg.type === "json"}
                                                <div class="log-json-container">
                                                    {#if arg.expanded}
                                                        <!-- svelte-ignore a11y_click_events_have_key_events -->
                                                        <!-- svelte-ignore a11y_no_static_element_interactions -->
                                                        <div
                                                            class="log-json expanded"
                                                            onclick={() => toggleExpansion(log.id, index)}
                                                        >
                                                            <div class="expand-header">
                                                                <span class="expand-indicator">▼</span>
                                                                <span class="expand-text">
                                                                    {arg.content.split("\n").length > 6
                                                                        ? "Large JSON Object (click to compact)"
                                                                        : "JSON Object (click to collapse)"}
                                                                </span>
                                                            </div>
                                                            <div class="json-content">
                                                                {@html highlightJSON(arg.content)}
                                                            </div>
                                                        </div>
                                                    {:else}
                                                        <!-- svelte-ignore a11y_click_events_have_key_events -->
                                                        <!-- svelte-ignore a11y_no_static_element_interactions -->
                                                        <div
                                                            class="log-json collapsed"
                                                            onclick={() => toggleExpansion(log.id, index)}
                                                        >
                                                            <div class="expand-header">
                                                                <span class="expand-indicator">▶</span>
                                                                <span class="expand-text">
                                                                    {arg.content.split("\n").length > 6
                                                                        ? "Large JSON Object (click to expand)"
                                                                        : "JSON Object (click to expand)"}
                                                                </span>
                                                            </div>
                                                            <div class="json-preview">
                                                                {@html highlightJSON(getCollapsedPreview(arg.content))}
                                                            </div>
                                                        </div>
                                                    {/if}
                                                </div>
                                            {:else}
                                                <span class="log-text">{arg.content}</span>
                                            {/if}
                                        {/each}
                                    </div>
                                </div>
                            {:else}
                                <div class="no-logs">
                                    <Terminal size={24} />
                                    <p>No logs to display</p>
                                    <small>Console logs will appear here</small>
                                </div>
                            {/each}
                        </div>
                    </div>
                </div>
            </div>
        {:else}
            <div
                class="toolbar-pill glass"
                class:dragging={isDragging}
                bind:this={pillElement}
                style={isDragging ? `position: fixed; left: ${dragCurrentX - 50}px; top: ${dragCurrentY - 28}px; transform: none;` : ''}
            >
                <Button
                    variant="ghost"
                    size="icon"
                    class="toolbar-item console-btn"
                    onclick={toggleVisibility}
                    title="Console ({logs.length} logs)"
                >
                    <Terminal size={20} />
                    {#if logs.length > 0}
                        <span class="badge">{logs.length}</span>
                    {/if}
                </Button>

                <!-- svelte-ignore a11y_no_static_element_interactions -->
                <div
                    class="drag-handle"
                    onmousedown={handleMoveButtonDragStart}
                    ontouchstart={handleMoveButtonDragStart}
                    title="Drag to reposition or click for menu"
                >
                    <Button
                        variant="ghost"
                        size="icon"
                        class="toolbar-item position-btn"
                        onclick={(e) => { if (!isDragging) togglePositionMenu(e); }}
                    >
                        <Move size={20} />
                    </Button>
                </div>

                {#if showPositionMenu}
                    <div class="position-dropdown glass">
                        <div class="position-grid">
                            <Button
                                variant="outline"
                                size="sm"
                                class="position-option {position === 'top-left' ? 'active' : ''}"
                                onclick={() => selectPosition("top-left")}
                            >
                                <div class="position-visual">
                                    <div class="corner top-left"></div>
                                </div>
                                <span>Top Left</span>
                            </Button>
                            <Button
                                variant="outline"
                                size="sm"
                                class="position-option {position === 'top-center' ? 'active' : ''}"
                                onclick={() => selectPosition("top-center")}
                            >
                                <div class="position-visual">
                                    <div class="corner top-center"></div>
                                </div>
                                <span>Top Center</span>
                            </Button>
                            <Button
                                variant="outline"
                                size="sm"
                                class="position-option {position === 'top-right' ? 'active' : ''}"
                                onclick={() => selectPosition("top-right")}
                            >
                                <div class="position-visual">
                                    <div class="corner top-right"></div>
                                </div>
                                <span>Top Right</span>
                            </Button>
                            <Button
                                variant="outline"
                                size="sm"
                                class="position-option {position === 'bottom-left' ? 'active' : ''}"
                                onclick={() => selectPosition("bottom-left")}
                            >
                                <div class="position-visual">
                                    <div class="corner bottom-left"></div>
                                </div>
                                <span>Bottom Left</span>
                            </Button>
                            <Button
                                variant="outline"
                                size="sm"
                                class="position-option {position === 'bottom-right' ? 'active' : ''}"
                                onclick={() => selectPosition("bottom-right")}
                            >
                                <div class="position-visual">
                                    <div class="corner bottom-right"></div>
                                </div>
                                <span>Bottom Right</span>
                            </Button>
                            <Button
                                variant="outline"
                                size="sm"
                                class="position-option {position === 'bottom-center' ? 'active' : ''}"
                                onclick={() => selectPosition("bottom-center")}
                            >
                                <div class="position-visual">
                                    <div class="corner bottom-center"></div>
                                </div>
                                <span>Bottom Center</span>
                            </Button>
                        </div>
                    </div>
                {/if}
            </div>
        {/if}
    </div>
{/if}

<style>
    /* ========================================
       GLASSMORPHISM DESIGN SYSTEM
       ======================================== */

    .sv-console {
        position: fixed;
        z-index: 10000;
        font-family:
            ui-sans-serif,
            system-ui,
            -apple-system,
            BlinkMacSystemFont,
            "Segoe UI",
            Roboto,
            "Helvetica Neue",
            Arial,
            "Noto Sans",
            sans-serif;
        transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }

    /* Glassmorphism base class */
    .glass {
        background: rgba(15, 23, 42, 0.75);
        backdrop-filter: blur(16px) saturate(180%);
        -webkit-backdrop-filter: blur(16px) saturate(180%);
        border: 1px solid rgba(148, 163, 184, 0.15);
        box-shadow:
            0 8px 32px rgba(0, 0, 0, 0.4),
            0 0 0 1px rgba(255, 255, 255, 0.05) inset,
            0 1px 0 rgba(255, 255, 255, 0.1) inset;
    }

    /* Position variants */
    .sv-console.top-left {
        top: 20px;
        left: 20px;
    }

    .sv-console.top-right {
        top: 20px;
        right: 20px;
    }

    .sv-console.bottom-left {
        bottom: 20px;
        left: 20px;
    }

    .sv-console.bottom-right {
        bottom: 20px;
        right: 20px;
    }

    .sv-console.bottom-center {
        bottom: 20px;
        left: 50%;
        transform: translateX(-50%);
    }

    .sv-console.top-center {
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
    }

    /* ========================================
       TOOLBAR PILL (Minimized State)
       ======================================== */

    .toolbar-pill {
        border-radius: 50px;
        padding: 8px;
        display: flex;
        align-items: center;
        gap: 4px;
        position: relative;
        transition: all 0.2s ease;
        user-select: none;
    }

    .toolbar-pill.dragging {
        opacity: 0.9;
        z-index: 10001;
        transition: none;
    }

    .drag-handle {
        cursor: grab;
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .drag-handle:active {
        cursor: grabbing;
    }

    .toolbar-pill:hover {
        background: rgba(15, 23, 42, 0.85);
        border-color: rgba(148, 163, 184, 0.25);
        box-shadow:
            0 12px 40px rgba(0, 0, 0, 0.5),
            0 0 0 1px rgba(255, 255, 255, 0.08) inset,
            0 1px 0 rgba(255, 255, 255, 0.15) inset;
    }

    :global(.toolbar-item) {
        background: transparent !important;
        border: none !important;
        color: rgba(226, 232, 240, 0.9) !important;
        width: 40px !important;
        height: 40px !important;
        border-radius: 50% !important;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        transition: all 0.2s ease;
        position: relative;
        padding: 0 !important;
    }

    :global(.toolbar-item:hover) {
        background: rgba(148, 163, 184, 0.15) !important;
        color: #fff !important;
        transform: scale(1.05);
    }

    :global(.toolbar-item:active) {
        transform: scale(0.95);
    }

    .badge {
        position: absolute;
        top: 2px;
        right: 2px;
        background: linear-gradient(135deg, #f43f5e, #e11d48);
        color: white;
        font-size: 10px;
        font-weight: 600;
        padding: 2px 6px;
        border-radius: 10px;
        min-width: 16px;
        text-align: center;
        line-height: 1.2;
        box-shadow: 0 2px 8px rgba(244, 63, 94, 0.4);
    }

    /* ========================================
       CONSOLE PANEL (Expanded State)
       ======================================== */

    .console-panel {
        border-radius: 16px;
        min-width: 420px;
        max-width: 520px;
        max-height: 60vh;
        animation: expandPanel 0.25s cubic-bezier(0.16, 1, 0.3, 1);
        overflow: hidden;
        color: rgba(226, 232, 240, 0.95);
    }

    @keyframes expandPanel {
        from {
            opacity: 0;
            transform: scale(0.92) translateY(10px);
        }
        to {
            opacity: 1;
            transform: scale(1) translateY(0);
        }
    }

    .panel-content {
        padding: 4px;
    }

    /* Console Controls */
    .console-controls {
        display: flex;
        gap: 8px;
        padding: 8px 8px 12px;
        align-items: center;
        border-bottom: 1px solid rgba(148, 163, 184, 0.1);
    }

    .filter-group {
        flex: 1;
    }

    :global(.log-filter) {
        width: 100% !important;
        padding: 8px 12px !important;
        border: 1px solid rgba(148, 163, 184, 0.2) !important;
        border-radius: 10px !important;
        background: rgba(30, 41, 59, 0.6) !important;
        font-size: 12px !important;
        color: rgba(226, 232, 240, 0.9) !important;
        font-weight: 500 !important;
        transition: all 0.2s ease;
        display: flex !important;
        align-items: center;
        justify-content: space-between !important;
        gap: 8px;
        cursor: pointer;
        height: auto !important;
        backdrop-filter: blur(8px);
    }

    :global(.log-filter:hover) {
        border-color: rgba(148, 163, 184, 0.35) !important;
        background: rgba(30, 41, 59, 0.8) !important;
    }

    :global(.log-filter:focus) {
        outline: none;
        border-color: rgba(99, 102, 241, 0.6) !important;
        box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15) !important;
    }

    .console-section {
        display: flex;
        flex-direction: column;
        height: 100%;
        min-height: 300px;
    }

    /* ========================================
       DROPDOWN MENU
       ======================================== */

    :global(.dropdown-content) {
        background: rgba(15, 23, 42, 0.9) !important;
        backdrop-filter: blur(16px) saturate(180%) !important;
        -webkit-backdrop-filter: blur(16px) saturate(180%) !important;
        border: 1px solid rgba(148, 163, 184, 0.15) !important;
        border-radius: 12px !important;
        min-width: 180px;
        z-index: 10002;
        color: rgba(226, 232, 240, 0.95) !important;
        box-shadow:
            0 8px 32px rgba(0, 0, 0, 0.4),
            0 0 0 1px rgba(255, 255, 255, 0.05) inset !important;
    }

    :global(.dropdown-content [data-slot="dropdown-menu-radio-item"]) {
        color: rgba(226, 232, 240, 0.9) !important;
        background: transparent;
        transition: all 0.15s ease;
        border-radius: 8px;
        margin: 2px 4px;
    }

    :global(.dropdown-content [data-slot="dropdown-menu-radio-item"]:hover) {
        background: rgba(148, 163, 184, 0.12) !important;
        color: #fff !important;
    }

    :global(.dropdown-content [data-slot="dropdown-menu-radio-item"][data-state="checked"]) {
        background: rgba(99, 102, 241, 0.2) !important;
        color: #a5b4fc !important;
    }

    :global(.dropdown-content [data-slot="dropdown-menu-radio-item"] svg) {
        color: #a5b4fc !important;
        fill: #a5b4fc !important;
    }

    /* ========================================
       POSITION DROPDOWN
       ======================================== */

    .position-dropdown {
        position: absolute;
        right: 0;
        border-radius: 14px;
        padding: 12px;
        z-index: 10001;
        animation: slideIn 0.2s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .sv-console.bottom-left .position-dropdown,
    .sv-console.bottom-right .position-dropdown,
    .sv-console.bottom-center .position-dropdown {
        bottom: calc(100% + 12px);
    }

    .sv-console.top-left .position-dropdown,
    .sv-console.top-right .position-dropdown {
        top: calc(100% + 12px);
    }

    .position-grid {
        display: grid;
        grid-template-columns: 1fr;
        gap: 4px;
        min-width: 150px;
    }

    :global(.position-option) {
        display: flex !important;
        align-items: center;
        gap: 10px;
        padding: 10px 14px !important;
        background: transparent !important;
        border: 1px solid rgba(148, 163, 184, 0.15) !important;
        border-radius: 10px !important;
        color: rgba(226, 232, 240, 0.9) !important;
        cursor: pointer;
        transition: all 0.2s ease;
        font-size: 12px !important;
        font-weight: 500 !important;
        text-align: left;
        justify-content: flex-start !important;
        height: auto !important;
    }

    :global(.position-option:hover) {
        background: rgba(148, 163, 184, 0.1) !important;
        border-color: rgba(148, 163, 184, 0.25) !important;
        color: #fff !important;
    }

    :global(.position-option.active) {
        background: rgba(99, 102, 241, 0.15) !important;
        border-color: rgba(99, 102, 241, 0.4) !important;
        color: #a5b4fc !important;
    }

    :global(.position-option.active .corner) {
        background: #a5b4fc;
        box-shadow: 0 0 8px rgba(165, 180, 252, 0.5);
    }

    .position-visual {
        width: 22px;
        height: 16px;
        background: rgba(30, 41, 59, 0.8);
        border-radius: 4px;
        position: relative;
        border: 1px solid rgba(148, 163, 184, 0.2);
    }

    .corner {
        width: 5px;
        height: 5px;
        background: rgba(148, 163, 184, 0.6);
        border-radius: 2px;
        position: absolute;
        transition: all 0.2s ease;
    }

    .corner.top-left { top: 2px; left: 2px; }
    .corner.top-center { top: 2px; left: 50%; transform: translateX(-50%); }
    .corner.top-right { top: 2px; right: 2px; }
    .corner.bottom-left { bottom: 2px; left: 2px; }
    .corner.bottom-right { bottom: 2px; right: 2px; }
    .corner.bottom-center { bottom: 2px; left: 50%; transform: translateX(-50%); }

    /* ========================================
       BUTTONS
       ======================================== */

    :global(.clear-btn) {
        background: linear-gradient(135deg, rgba(239, 68, 68, 0.9), rgba(220, 38, 38, 0.9)) !important;
        color: white !important;
        border: none !important;
        border-radius: 10px !important;
        font-weight: 500 !important;
        box-shadow: 0 2px 8px rgba(239, 68, 68, 0.3);
        transition: all 0.2s ease;
    }

    :global(.clear-btn:hover) {
        background: linear-gradient(135deg, rgba(239, 68, 68, 1), rgba(220, 38, 38, 1)) !important;
        box-shadow: 0 4px 12px rgba(239, 68, 68, 0.4);
        transform: translateY(-1px);
    }

    :global(.clear-btn svg) {
        color: white !important;
        stroke: white !important;
    }

    :global(.minimize-btn) {
        color: rgba(226, 232, 240, 0.7) !important;
        border-radius: 8px !important;
    }

    :global(.minimize-btn:hover) {
        background: rgba(148, 163, 184, 0.15) !important;
        color: #fff !important;
    }

    /* ========================================
       CONSOLE LOGS
       ======================================== */

    .console-logs {
        flex: 1;
        overflow-y: auto;
        background: rgba(2, 6, 23, 0.5);
        border: 1px solid rgba(148, 163, 184, 0.1);
        border-radius: 12px;
        margin: 0 8px 8px;
        padding: 8px;
        font-family:
            "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas,
            "Courier New", monospace;
        font-size: 12px;
        line-height: 1.4;
        scroll-behavior: smooth;
        max-height: 300px;
        min-height: 200px;
    }

    .log-entry {
        margin: 4px 0;
        padding: 8px 10px;
        border-radius: 10px;
        background: rgba(30, 41, 59, 0.4);
        border: 1px solid rgba(148, 163, 184, 0.08);
        transition: all 0.2s ease;
        position: relative;
        overflow: hidden;
    }

    .log-entry:hover {
        background: rgba(30, 41, 59, 0.6);
        border-color: rgba(148, 163, 184, 0.15);
    }

    .log-entry.error {
        border-left: 3px solid #f43f5e;
        background: rgba(244, 63, 94, 0.08);
    }

    .log-entry.warn {
        border-left: 3px solid #f59e0b;
        background: rgba(245, 158, 11, 0.08);
    }

    .log-entry.info {
        border-left: 3px solid #6366f1;
        background: rgba(99, 102, 241, 0.08);
    }

    .log-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 8px;
        opacity: 0.85;
    }

    .log-time {
        font-size: 11px;
        color: rgba(148, 163, 184, 0.8);
        font-weight: 500;
        font-family: inherit;
    }

    .log-level {
        font-size: 9px;
        font-weight: 600;
        padding: 3px 8px;
        border-radius: 6px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }

    .log-level[data-level="error"] {
        background: rgba(244, 63, 94, 0.15);
        color: #fb7185;
    }

    .log-level[data-level="warn"] {
        background: rgba(245, 158, 11, 0.15);
        color: #fbbf24;
    }

    .log-level[data-level="info"] {
        background: rgba(99, 102, 241, 0.15);
        color: #a5b4fc;
    }

    .log-level[data-level="log"] {
        background: rgba(148, 163, 184, 0.15);
        color: rgba(148, 163, 184, 0.9);
    }

    .log-content {
        display: flex;
        flex-direction: column;
        gap: 6px;
    }

    .log-text {
        white-space: pre-wrap;
        word-break: break-word;
        color: rgba(226, 232, 240, 0.95);
        font-size: 12px;
        line-height: 1.5;
        font-family: inherit;
    }

    /* ========================================
       JSON DISPLAY
       ======================================== */

    .log-json-container {
        margin: 4px 0;
        display: inline-block;
        width: 100%;
    }

    .log-json {
        background: rgba(2, 6, 23, 0.6);
        border: 1px solid rgba(148, 163, 184, 0.12);
        border-radius: 10px;
        font-family: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New", monospace;
        font-size: 11px;
        line-height: 1.4;
        text-align: left;
        cursor: pointer;
        transition: all 0.2s ease;
        overflow: hidden;
    }

    .log-json:hover {
        border-color: rgba(148, 163, 184, 0.2);
        background: rgba(2, 6, 23, 0.8);
    }

    .log-json.collapsed {
        padding: 10px 14px;
    }

    .log-json.expanded {
        padding: 10px 14px 14px;
    }

    .expand-header {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 8px;
        font-size: 10px;
        color: rgba(148, 163, 184, 0.7);
        font-weight: 600;
    }

    .expand-indicator {
        color: rgba(148, 163, 184, 0.8);
        font-family: monospace;
        font-size: 9px;
        width: 10px;
        text-align: center;
    }

    .expand-text {
        font-size: 9px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        opacity: 0.9;
    }

    .json-content {
        white-space: pre;
        overflow-x: auto;
        max-height: 300px;
        overflow-y: auto;
        padding-top: 8px;
        border-top: 1px solid rgba(148, 163, 184, 0.1);
    }

    .json-preview {
        opacity: 0.85;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        font-size: 10px;
        line-height: 1.3;
    }

    /* JSON Syntax Highlighting */
    :global(.json-key) {
        color: #93c5fd;
        font-weight: 600;
    }

    :global(.json-string) {
        color: #86efac;
    }

    :global(.json-number) {
        color: #c4b5fd;
    }

    :global(.json-boolean) {
        color: #fcd34d;
        font-weight: 600;
    }

    :global(.json-null) {
        color: #fb7185;
        font-weight: 600;
        font-style: italic;
    }

    :global(.json-bracket) {
        color: rgba(148, 163, 184, 0.8);
        font-weight: bold;
    }

    :global(.json-comma),
    :global(.json-colon) {
        color: rgba(148, 163, 184, 0.7);
    }

    .log-separator {
        margin: 0 6px;
        color: rgba(148, 163, 184, 0.5);
    }

    /* ========================================
       EMPTY STATE
       ======================================== */

    .no-logs {
        text-align: center;
        color: rgba(148, 163, 184, 0.6);
        margin: 40px 20px;
        padding: 24px;
        background: rgba(30, 41, 59, 0.3);
        border: 1px dashed rgba(148, 163, 184, 0.15);
        border-radius: 12px;
        font-size: 12px;
    }

    .no-logs p {
        margin: 12px 0 4px;
        color: rgba(148, 163, 184, 0.8);
        font-weight: 500;
    }

    .no-logs small {
        color: rgba(148, 163, 184, 0.5);
    }

    /* ========================================
       ANIMATIONS
       ======================================== */

    @keyframes slideIn {
        from {
            opacity: 0;
            transform: scale(0.95) translateY(4px);
        }
        to {
            opacity: 1;
            transform: scale(1) translateY(0);
        }
    }

    /* ========================================
       RESPONSIVE
       ======================================== */

    @media (max-width: 480px) {
        .sv-console {
            bottom: 16px;
            right: 16px;
        }

        .console-panel {
            min-width: 280px;
            max-width: calc(100vw - 32px);
        }

        .console-controls {
            flex-direction: column;
            gap: 8px;
        }

        .filter-group {
            width: 100%;
        }
    }
</style>
