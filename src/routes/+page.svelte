<script>
    import "../lib/auto.ts";
    import { onMount } from "svelte";
    import { Terminal } from "$lib/icons";

    onMount(() => {
        setTimeout(() => {
            console.log("Welcome to the console log demo!");
            console.log("app");
            console.info("This is an info message with some data:", {
                user: "demo",
                timestamp: new Date(),
            });
            console.warn("This is a warning message");
            console.error("This is an error message");
        }, 100);
    });

    function testConsole() {
        console.log("Button clicked!", new Date().toISOString());
        console.log("User interaction detected");
        console.log("This is a test log");
        console.info("User interaction detected");
        console.warn("This is a test warning");
        console.error("This is a test error");
    }

    function testManyLogs() {
        for (let i = 1; i <= 25; i++) {
            setTimeout(() => {
                console.log(
                    `Batch log ${i}/25 - testing log management (last 20 kept, older deleted after 6s)`,
                );
            }, i * 200);
        }
    }

    function testLogTypes() {
        setTimeout(() => console.log("This is a regular log message"), 100);
        setTimeout(
            () =>
                console.info("Info with JSON:", {
                    user: "demo",
                    settings: { theme: "dark", notifications: true },
                    count: 42,
                    active: false,
                    metadata: null,
                }),
            200,
        );
        setTimeout(
            () =>
                console.warn("Warning with array:", [
                    "item1",
                    "item2",
                    { nested: true },
                ]),
            300,
        );
        setTimeout(
            () =>
                console.error("Error with complex object:", {
                    error: "Authentication failed",
                    code: 401,
                    details: {
                        message: "Invalid token",
                        timestamp: "2025-01-01T12:00:00Z",
                        retry: true,
                        attempts: 3,
                    },
                }),
            400,
        );
    }

    function testLogsWithNoTimeout() {
        console.log("This is a regular log message");
        console.info("Info with JSON:", {
            user: "demo",
            settings: { theme: "dark", notifications: true },
            count: 42,
            active: false,
            metadata: null,
        });
        console.warn("Warning with array:", [
            "item1",
            "item2",
            { nested: true },
        ]);
        console.error("Error with complex object:", {
            error: "Authentication failed",
            code: 401,
            details: {
                message: "Invalid token",
                timestamp: "2025-01-01T12:00:00Z",
                retry: true,
                attempts: 3,
            },
        });
    }

    function testJSONExamples() {
        console.log("Simple object:", { name: "John", age: 30 });
        console.log("Nested structure:", {
            api: {
                endpoint: "/users",
                method: "GET",
                params: { limit: 10, offset: 0 },
            },
            response: {
                status: 200,
                data: [
                    { id: 1, name: "Alice", active: true },
                    { id: 2, name: "Bob", active: false },
                ],
                meta: {
                    total: 2,
                    hasMore: false,
                    nextPage: null,
                },
            },
        });
    }
</script>

<div class="demo-page">
    <main>
        <!-- Hero Section -->
        <header class="hero">
            <div class="hero-icon">
                <Terminal size={32} />
            </div>
            <h1>sv-console</h1>
            <p class="tagline">
                A floating developer console for Svelte 5 with JSON syntax highlighting
            </p>
            <div class="badges">
                <span class="badge">Svelte 5</span>
                <span class="badge">Zero Dependencies</span>
                <span class="badge">Dev Only</span>
            </div>
        </header>

        <!-- Test Buttons -->
        <section class="test-section">
            <h2>Interactive Demo</h2>
            <p class="section-desc">Click the buttons below to test different console outputs</p>

            <div class="button-group">
                <button class="btn btn-primary" onclick={testLogTypes}>
                    Log Types
                </button>
                <button class="btn btn-secondary" onclick={testJSONExamples}>
                    JSON Highlighting
                </button>
                <button class="btn btn-secondary" onclick={testManyLogs}>
                    Batch Logs
                </button>
                <button class="btn btn-secondary" onclick={testConsole}>
                    Mixed Test
                </button>
                <button class="btn btn-secondary" onclick={testLogsWithNoTimeout}>
                    Instant Logs
                </button>
            </div>
        </section>

        <!-- Usage Section -->
        <section class="usage-section">
            <h2>Quick Start</h2>

            <div class="usage-cards">
                <div class="usage-card">
                    <div class="card-header">
                        <span class="step-number">1</span>
                        <h3>Install</h3>
                    </div>
                    <pre><code>npm install sv-console</code></pre>
                </div>

                <div class="usage-card">
                    <div class="card-header">
                        <span class="step-number">2</span>
                        <h3>Auto Import</h3>
                    </div>
                    <pre><code><span class="code-comment">// In your +layout.svelte or main file</span>
<span class="code-keyword">import</span> <span class="code-string">'sv-console/auto'</span>;</code></pre>
                    <p class="card-note">Console appears automatically in dev mode</p>
                </div>

                <div class="usage-card">
                    <div class="card-header">
                        <span class="step-number">OR</span>
                        <h3>Manual Component</h3>
                    </div>
                    <pre><code><span class="code-keyword">import</span> {"{"} FloatingDevCards {"}"} <span class="code-keyword">from</span> <span class="code-string">'sv-console'</span>;

<span class="code-tag">&lt;FloatingDevCards /&gt;</span></code></pre>
                </div>
            </div>
        </section>

        <!-- Features -->
        <section class="features-section">
            <h2>Features</h2>
            <div class="features-grid">
                <div class="feature-card">
                    <h4>JSON Highlighting</h4>
                    <p>Beautiful syntax highlighting for JSON objects</p>
                </div>
                <div class="feature-card">
                    <h4>Auto Cleanup</h4>
                    <p>Old logs auto-delete after 6 seconds (keeps last 20)</p>
                </div>
                <div class="feature-card">
                    <h4>Draggable</h4>
                    <p>Drag to reposition, persists in localStorage</p>
                </div>
                <div class="feature-card">
                    <h4>Filter Logs</h4>
                    <p>Filter by log, info, warn, or error levels</p>
                </div>
            </div>
        </section>

        <!-- Footer -->
        <footer class="footer">
            <p>
                Built with Svelte 5 &middot;
                <a href="https://github.com/SebasGDEV/sv-console" target="_blank" rel="noopener">GitHub</a> &middot;
                <a href="https://www.npmjs.com/package/sv-console" target="_blank" rel="noopener">npm</a>
            </p>
        </footer>
    </main>
</div>

<style>
    /* ========================================
       CLEAN MINIMAL DESIGN
       ======================================== */

    .demo-page {
        --color-bg: #fafafa;
        --color-surface: #ffffff;
        --color-border: #e5e7eb;
        --color-text: #1f2937;
        --color-text-muted: #6b7280;
        --color-primary: #6366f1;
        --color-primary-hover: #4f46e5;

        min-height: 100vh;
        background: var(--color-bg);
        color: var(--color-text);
        font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }

    main {
        max-width: 720px;
        margin: 0 auto;
        padding: 60px 24px 40px;
    }

    /* ========================================
       HERO SECTION
       ======================================== */

    .hero {
        text-align: center;
        margin-bottom: 48px;
    }

    .hero-icon {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 64px;
        height: 64px;
        background: var(--color-primary);
        border-radius: 16px;
        margin-bottom: 20px;
        color: white;
    }

    h1 {
        font-size: 2.5rem;
        font-weight: 700;
        letter-spacing: -0.02em;
        margin: 0 0 12px;
        color: var(--color-text);
    }

    .tagline {
        font-size: 1.1rem;
        color: var(--color-text-muted);
        margin: 0 0 20px;
        line-height: 1.6;
    }

    .badges {
        display: flex;
        gap: 8px;
        justify-content: center;
        flex-wrap: wrap;
    }

    .badge {
        padding: 4px 12px;
        background: #f3f4f6;
        border: 1px solid var(--color-border);
        border-radius: 16px;
        font-size: 0.8rem;
        font-weight: 500;
        color: var(--color-text-muted);
    }

    /* ========================================
       TEST SECTION
       ======================================== */

    .test-section {
        background: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: 16px;
        padding: 32px;
        margin-bottom: 40px;
        text-align: center;
    }

    .test-section h2 {
        font-size: 1.25rem;
        font-weight: 600;
        margin: 0 0 8px;
    }

    .section-desc {
        color: var(--color-text-muted);
        margin: 0 0 24px;
        font-size: 0.95rem;
    }

    .button-group {
        display: flex;
        gap: 10px;
        justify-content: center;
        flex-wrap: wrap;
    }

    .btn {
        padding: 10px 18px;
        border: none;
        border-radius: 10px;
        font-size: 0.9rem;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.15s ease;
    }

    .btn-primary {
        background: var(--color-primary);
        color: white;
    }

    .btn-primary:hover {
        background: var(--color-primary-hover);
    }

    .btn-secondary {
        background: #f3f4f6;
        color: var(--color-text);
        border: 1px solid var(--color-border);
    }

    .btn-secondary:hover {
        background: #e5e7eb;
    }

    /* ========================================
       USAGE SECTION
       ======================================== */

    .usage-section {
        margin-bottom: 40px;
    }

    .usage-section h2 {
        text-align: center;
        font-size: 1.25rem;
        font-weight: 600;
        margin: 0 0 20px;
    }

    .usage-cards {
        display: grid;
        gap: 12px;
    }

    .usage-card {
        background: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: 12px;
        padding: 20px;
    }

    .card-header {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 12px;
    }

    .step-number {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 24px;
        height: 24px;
        background: var(--color-primary);
        border-radius: 6px;
        font-size: 0.75rem;
        font-weight: 600;
        color: white;
    }

    .card-header h3 {
        font-size: 1rem;
        font-weight: 600;
        margin: 0;
    }

    .usage-card pre {
        background: #f9fafb;
        border: 1px solid var(--color-border);
        border-radius: 8px;
        padding: 14px;
        margin: 0;
        overflow-x: auto;
        font-size: 0.85rem;
        line-height: 1.6;
    }

    .usage-card code {
        font-family: "SF Mono", Monaco, "Cascadia Code", Consolas, monospace;
        color: var(--color-text);
    }

    .code-keyword { color: #7c3aed; }
    .code-string { color: #059669; }
    .code-comment { color: #9ca3af; }
    .code-tag { color: #2563eb; }

    .card-note {
        margin: 10px 0 0;
        font-size: 0.85rem;
        color: var(--color-text-muted);
    }

    /* ========================================
       FEATURES SECTION
       ======================================== */

    .features-section {
        margin-bottom: 40px;
    }

    .features-section h2 {
        text-align: center;
        font-size: 1.25rem;
        font-weight: 600;
        margin: 0 0 20px;
    }

    .features-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 12px;
    }

    @media (max-width: 500px) {
        .features-grid {
            grid-template-columns: 1fr;
        }
    }

    .feature-card {
        background: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: 12px;
        padding: 20px;
    }

    .feature-card h4 {
        font-size: 0.95rem;
        font-weight: 600;
        margin: 0 0 6px;
    }

    .feature-card p {
        font-size: 0.85rem;
        color: var(--color-text-muted);
        margin: 0;
        line-height: 1.5;
    }

    /* ========================================
       FOOTER
       ======================================== */

    .footer {
        text-align: center;
        padding-top: 20px;
        border-top: 1px solid var(--color-border);
    }

    .footer p {
        font-size: 0.9rem;
        color: var(--color-text-muted);
        margin: 0;
    }

    .footer a {
        color: var(--color-primary);
        text-decoration: none;
    }

    .footer a:hover {
        text-decoration: underline;
    }

    /* ========================================
       RESPONSIVE
       ======================================== */

    @media (max-width: 640px) {
        main {
            padding: 40px 16px 32px;
        }

        h1 {
            font-size: 2rem;
        }

        .test-section {
            padding: 24px 16px;
        }
    }
</style>
