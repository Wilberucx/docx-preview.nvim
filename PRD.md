# PRD: nvim-docx-preview

> Live `.docx` preview for Neovim, inspired by `markdown-preview.nvim`.  
> Escribís en Markdown con todos tus motions → ves el output real en el browser.

---

## 1. Problem Statement

Neovim users working with `.docx` output (via Pandoc) have no way to preview
the final document without alt-tabbing to an office suite after each export.
The existing `markdown-preview.nvim` only renders Markdown styles (GitHub-like),
not the actual `.docx` formatting defined by a reference template.

**Goal:** Provide a live browser preview that reflects the actual `.docx` output
as faithfully as possible, with zero hardcoded paths or values.

---

## 2. Goals

- ✅ Live preview that updates on save (no manual commands)
- ✅ Reflects actual `.docx` template styles (via mammoth.js style maps)
- ✅ Zero hardcoded paths, ports, binaries, or templates
- ✅ Modular and maintainable codebase — each layer has a single responsibility
- ✅ User-configurable via a Lua `setup()` call
- ✅ Works as a standalone Neovim plugin (lazy.nvim / packer compatible)

## 3. Non-Goals

- ❌ Perfect pixel-to-pixel `.docx` rendering (not feasible without a full Word engine)
- ❌ Editing the document from the browser
- ❌ Support for complex layouts (multi-column, text boxes, embedded charts)
- ❌ Replacing Pandoc (it remains the conversion backbone)

---

## 4. Technology Stack

| Layer                 | Technology             | Reason                                                           |
| --------------------- | ---------------------- | ---------------------------------------------------------------- |
| Neovim plugin         | **Lua**                | Native plugin API, autocmds, job control                         |
| Preview server        | **Bun + TypeScript**   | Fast startup, native WebSocket, runs mammoth.js without overhead |
| docx → HTML           | **mammoth.js**         | Best-in-class docx parser, custom style maps                     |
| md → docx             | **Pandoc** (external)  | User's existing tool, called as subprocess                       |
| Browser communication | **WebSocket**          | Push updates without polling                                     |
| Preview page          | **Vanilla HTML + CSS** | No framework needed, injected HTML from mammoth                  |

**Why Bun over Node:**

- Cold start ~3× faster than Node
- Native TypeScript (no build step for development)
- Built-in `Bun.serve()` with WebSocket support — no express/ws dependencies
- Built-in file watcher API

---

## 5. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      NEOVIM                             │
│                                                         │
│  Buffer (markdown)                                      │
│       │  BufWritePost autocmd                           │
│       ▼                                                 │
│  plugin/lua ──── job:start() ──────────────────────┐   │
│       │                                            │   │
│       │  sends: { file, config }                   │   │
│       ▼                                            ▼   │
│  server manager (lua/server.lua)           Bun server  │
└────────────────────────────────────────────────────────┘
                                                  │
                              ┌───────────────────┤
                              │                   │
                         HTTP :port          WS :port
                              │                   │
                         preview.html      push HTML on change
                              │                   │
                              └────── browser ─────┘
                                          │
                              receives updated HTML,
                              injects into DOM (no reload)
```

**Flow on save:**

1. Autocmd fires → Lua notifies Bun server via stdin/socket
2. Bun server runs `pandoc <file.md> -o <tmp.docx> --reference-doc=<template>`
3. mammoth converts `tmp.docx` → HTML using configured style map
4. WebSocket broadcasts new HTML to all connected browsers
5. Browser injects HTML into preview container (no full page reload)

---

## 6. Directory Structure

```
nvim-docx-preview/
│
├── plugin/
│   └── nvim-docx-preview.lua        # Plugin entrypoint (autoloaded by Neovim)
│
├── lua/
│   └── docx-preview/
│       ├── init.lua                 # Public API: setup(), open(), close(), toggle()
│       ├── config.lua               # Config schema, defaults, validation
│       ├── server.lua               # Bun server lifecycle (start, stop, restart)
│       ├── autocmd.lua              # BufWritePost and BufDelete handlers
│       ├── commands.lua             # User-facing :DocxPreview commands
│       └── utils.lua                # Path resolution, OS detection, logging
│
├── server/
│   ├── src/
│   │   ├── index.ts                 # Entry point, reads config from argv/env
│   │   ├── server.ts                # Bun.serve() setup (HTTP + WebSocket)
│   │   ├── converter.ts             # pandoc → docx → HTML pipeline
│   │   ├── watcher.ts               # File system watcher (backup trigger)
│   │   ├── styles.ts                # Mammoth style map loader
│   │   └── logger.ts                # Structured logging
│   ├── assets/
│   │   └── preview.html             # Browser shell (injects received HTML)
│   ├── package.json
│   └── tsconfig.json
│
├── scripts/
│   └── install-server.sh            # Installs Bun deps (called by plugin on setup)
│
└── README.md
```

**Rule:** No file does more than one thing. `converter.ts` only converts.
`server.ts` only manages connections. `config.lua` only owns config logic.

---

## 7. Configuration Spec (Lua)

All values have defaults. Nothing is hardcoded outside `config.lua`.

```lua
require("docx-preview").setup({
  -- Binaries (resolved from $PATH if not absolute)
  binaries = {
    pandoc = "pandoc",   -- or "/usr/local/bin/pandoc"
    bun    = "bun",
  },

  -- Server
  server = {
    port    = 8765,
    host    = "127.0.0.1",
    autostart = true,     -- start server when plugin loads
  },

  -- Conversion
  conversion = {
    reference_doc = nil,            -- path to .docx template; nil = pandoc default
    output_dir    = vim.fn.stdpath("cache") .. "/docx-preview",  -- tmp files
    extra_pandoc_args = {},         -- e.g. { "--toc", "--highlight-style=kate" }
  },

  -- Mammoth style map file (optional)
  -- See: https://github.com/mwilliamson/mammoth.js#custom-style-map
  mammoth = {
    style_map_file = nil,   -- path to .mammoth-styles file
  },

  -- Browser
  browser = {
    open_cmd = nil,   -- nil = auto-detect (xdg-open / open / start)
    -- or: "firefox", "chromium", function(url) ... end
  },

  -- Triggers
  autocmd = {
    enabled    = true,
    filetypes  = { "markdown" },
    events     = { "BufWritePost" },
  },

  -- Logging
  log = {
    level = "warn",   -- "debug" | "info" | "warn" | "error"
  },
})
```

**Config validation:** `config.lua` must validate every field on `setup()` and
emit a clear error (not a crash) if a required binary is missing.

---

## 8. Server API (Internal)

The Bun server accepts commands via **stdin** (newline-delimited JSON) when
launched as a Neovim job:

```jsonc
// Neovim → Server
{ "cmd": "convert", "file": "/absolute/path/to/file.md" }
{ "cmd": "shutdown" }

// Server → Neovim (stdout)
{ "status": "ready", "url": "http://127.0.0.1:8765" }
{ "status": "converted", "file": "file.md", "duration_ms": 120 }
{ "status": "error", "message": "pandoc not found" }
```

WebSocket messages (Server → Browser):

```jsonc
{ "type": "update", "html": "<article>...</article>" }
{ "type": "error",  "message": "Conversion failed: ..." }
```

---

## 9. Browser Preview Shell (`preview.html`)

- Minimal HTML — just a container and WebSocket client script
- CSS injected from mammoth output + optional user CSS file
- On `update` message: `container.innerHTML = html` (no full reload)
- On `error` message: shows a non-intrusive toast

**No frameworks. No bundler. Pure browser APIs.**

---

## 10. Conversion Pipeline Detail (`converter.ts`)

```
Input: absolute path to .md file

Step 1 — pandoc
  pandoc <file.md> \
    -o <output_dir>/<uuid>.docx \
    [--reference-doc=<template>] \
    [..extra_pandoc_args]

Step 2 — mammoth
  mammoth(<uuid>.docx, { styleMap: loadStyleMap() })
  → returns { value: htmlString, messages: [] }

Step 3 — cleanup
  delete <uuid>.docx from output_dir

Output: HTML string → sent to WebSocket broadcaster
```

Each step is a separate async function. Errors in any step are caught and
returned as structured objects — never thrown to crash the server.

---

## 11. Neovim Commands

```
:DocxPreviewOpen      # Start server + open browser
:DocxPreviewClose     # Close browser tab + stop server
:DocxPreviewToggle    # Toggle open/close
:DocxPreviewStatus    # Show server status + config in use
:DocxPreviewLog       # Open server log in a split
```

---

## 12. Mammoth Limitations (documented, not bugs)

| Feature                   | Support                             |
| ------------------------- | ----------------------------------- |
| Headings H1–H6            | ✅ Full                             |
| Paragraphs, bold, italic  | ✅ Full                             |
| Tables (basic)            | ✅ Full                             |
| Ordered / unordered lists | ✅ Full                             |
| Images (embedded)         | ⚠️ Extracted as base64, may be slow |
| Headers / Footers         | ❌ Not supported by mammoth         |
| Multi-column layout       | ❌ Not supported                    |
| Complex table merges      | ⚠️ Partial                          |
| Custom fonts rendering    | ❌ Browser fonts only               |

---

## 13. Implementation Phases

### Phase 1 — Core (MVP)

- [ ] `config.lua` with full schema and validation
- [ ] `server.lua` starts/stops Bun as a Neovim job
- [ ] `converter.ts` runs pandoc → mammoth pipeline
- [ ] `server.ts` serves `preview.html` + WebSocket
- [ ] `autocmd.lua` triggers on BufWritePost
- [ ] Basic `preview.html` shell
- [ ] `:DocxPreviewOpen` and `:DocxPreviewToggle` commands

### Phase 2 — Polish

- [ ] `styles.ts` loads user-provided mammoth style map
- [ ] Browser error toasts
- [ ] `:DocxPreviewStatus` and `:DocxPreviewLog`
- [ ] Auto-detect browser by OS
- [ ] `install-server.sh` script

### Phase 3 — Nice to have

- [ ] Multiple buffer support (multiple previews)
- [ ] Scroll sync (approximate, based on headings)
- [ ] CSS injection from user config
- [ ] Health check command (`:checkhealth docx-preview`)

---

## 14. Dependencies

**Neovim plugin (zero external Lua deps)**

**Bun server (`package.json`):**

```json
{
  "dependencies": {
    "mammoth": "^1.8.0"
  },
  "devDependencies": {
    "@types/bun": "latest"
  }
}
```

**System (user must have):**

- `bun` >= 1.0
- `pandoc` >= 3.0
- A browser

---

## 15. Non-negotiable Architecture Rules

1. **No hardcoded paths** — every path goes through `config.lua` resolution
2. **No hardcoded ports** — port always comes from config
3. **No hardcoded template** — `reference_doc = nil` is valid (uses pandoc default)
4. **Single responsibility per file** — if you're unsure where code belongs, create a new file
5. **Errors are data** — no unhandled exceptions in the Bun server; all errors become structured responses
6. **Lua side owns lifecycle** — the server is a dumb worker; Neovim decides when to start/stop

---

_Generated for use with an AI coding agent. Each phase can be implemented independently._
