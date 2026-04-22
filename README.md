# nvim-docx-preview

> Live `.docx` preview for Neovim — edit Markdown, see the actual Word document in your browser.

`nvim-docx-preview` is a Neovim plugin that provides real-time preview of `.docx` files in your browser while editing Markdown. It uses Pandoc to convert `md → docx` and mammoth.js to convert `docx → HTML`, served via a Bun WebSocket server.

```
┌─────────────────────┐     ┌─────────────────────┐
│     Neovim          │     │      Browser        │
│                     │     │                     │
│  edit .md ─────┐    │     │  preview.html       │
│                │    │     │  ←── WebSocket      │
│  BufWritePost  │    │────▶│                     │
│  autocmd       │    │     │  live HTML          │
│                ▼    │     │  updates            │
│  pandoc ────────────┼────▶│                     │
│  (md → docx)        │     │    window.print()   │
│                ▼    │     │         (PDF)       │
│  mammoth ───────────┘     │                     │
│  (docx → HTML)      │     │                     │
└─────────────────────┘     └─────────────────────┘
```

---

## ✨ Features

- **Live preview** — updates automatically on save
- **Export to HTML, PDF, DOCX** — fully formatted documents
- **Companion CSS** — customizable Word-like stylesheet
- **Workspace mode** — export from Obsidian vaults without modifying originals
- **Print support** — browser print dialog from Neovim
- **Zero hardcoded values** — fully configurable

---

## 📋 Requirements

| Requirement | Version | Notes                    |
| ----------- | ------- | ------------------------ |
| Neovim      | ≥ 0.9.0 | For modern Lua APIs      |
| Bun         | ≥ 1.0   | For the preview server   |
| Pandoc      | ≥ 3.0   | For md → docx conversion |

### Optional (for PDF export)

| Tool        | Priority                |
| ----------- | ----------------------- |
| wkhtmltopdf | 1st — best CSS fidelity |
| weasyprint  | 2nd — pure Python       |
| pdflatex    | 3rd — fallback, no CSS  |

---

## 🚀 Installation

### Using lazy.nvim (recommended)

```lua
-- ~/.config/nvim/lua/plugins/docx-preview.lua
return {
  "Wilberucx/docx-preview.nvim",
  event = "VeryLazy",
  config = function()
    require("docx-preview").setup({
      -- configuration (see below)
    })
  end,
}
```

### Using packer.nvim

```lua
use("Wilberucx/docx-preview.nvim")
```

### Manual

```sh
# Clone to your Neovim runtime path
git clone https://github.com/Wilberucx/docx-preview.nvim.git \
  ~/.local/share/nvim/site/pack/vendor/start/nvim-docx-preview
```

---

## ⚙️ Post-Installation

No extra installation needed! The Bun server is bundled with the plugin and runs automatically.

If you use a plugin manager that runs `post-install` hooks, you may need to install dependencies:

```sh
cd ~/.local/share/nvim/site/pack/vendor/start/nvim-docx-preview/server
bun install
```

---

## ⚙️ Configuration

`setup()` accepts all options. Defaults are shown:

```lua
require("docx-preview").setup({
  -- Binary paths
  binaries = {
    pandoc = "pandoc",
    bun = "bun",
  },

  -- Server settings
  server = {
    port = 8765,
    host = "127.0.0.1",
    autostart = true,  -- start server when Neovim opens
  },

  -- Conversion settings
  conversion = {
    reference_doc = nil,  -- path to .docx template
    output_dir = vim.fn.stdpath("cache") .. "/docx-preview",
    extra_pandoc_args = {},
  },

  -- Mammoth style map
  mammoth = {
    style_map_file = nil,  -- custom style mappings
  },

  -- Browser settings
  browser = {
    open_cmd = nil,  -- custom open command
  },

  -- Autocmd settings
  autocmd = {
    enabled = true,
    filetypes = { "markdown" },
    events = { "BufWritePost" },
  },

  -- Export settings (Phase 2)
  export = {
    output_dir = nil,  -- nil = same dir as source
    open_after_export = true,
    pdf_engines = { "wkhtmltopdf", "weasyprint", "pdflatex" },
  },

  -- Style settings (Phase 2)
  style = {
    auto_detect = true,
    auto_generate = false,
  },

  -- Workspace settings (Phase 3)
  workspace = {
    dir = nil,  -- absolute path, nil = disabled
    sanitize_wikilinks = true,
    timestamp_copies = true,
    open_after_copy = true,
  },

  -- Logging
  log = {
    level = "warn",  -- "debug", "info", "warn", "error"
  },
})
```

---

## 📖 Commands

### Preview commands (Phase 1)

| Command              | Description             |
| -------------------- | ----------------------- |
| `:DocxPreviewOpen`   | Open preview in browser |
| `:DocxPreviewClose`  | Stop preview server     |
| `:DocxPreviewToggle` | Toggle preview          |
| `:DocxPreviewStatus` | Show server status      |

### Style commands (Phase 2)

| Command          | Description            |
| ---------------- | ---------------------- |
| `:DocxStyleNew`  | Generate companion CSS |
| `:DocxStyleOpen` | Open CSS in split      |

### Export commands (Phase 2)

| Command             | Description       |
| ------------------- | ----------------- |
| `:DocxExportHtml`   | Export to HTML    |
| `:DocxExportPdf`    | Export to PDF     |
| `:DocxExportDocx`   | Export to DOCX    |
| `:DocxPreviewPrint` | Print via browser |

### Workspace commands (Phase 3)

| Command              | Description        |
| -------------------- | ------------------ |
| `:DocxWorkspaceCopy` | Copy to workspace  |
| `:DocxWorkspaceOpen` | Open workspace dir |

---

## 🔧 Usage

### Basic workflow

```vim
" Open a markdown file
:e documento.md

" Open live preview
:DocxPreviewOpen

" Edit normally, save with :w
" Preview updates automatically in browser
```

### Exporting documents

```vim
" Export current file to HTML
:DocxExportHtml

" Export to PDF
:DocxExportPdf

" Export to DOCX
:DocxExportDocx

" Print to PDF via browser
:DocxPreviewPrint
```

### Custom CSS

```vim
" Generate companion CSS for current file
:DocxStyleNew

" Edit the generated .css file
:DocxStyleOpen

" Export will use the companion CSS automatically
:DocxExportHtml
```

### Workspace (Obsidian vaults)

```lua
-- In your init.lua or plugin config:
require("docx-preview").setup({
  workspace = {
    dir = "/path/to/workspace",  -- must be absolute
    sanitize_wikilinks = true,   -- transform [[wikilinks]]
    timestamp_copies = true,      -- append timestamp
  },
})
```

```vim
" Copy current vault file to workspace
:DocxWorkspaceCopy

" Export automatically uses the copy
:DocxExportPdf

" Original vault file stays untouched
```

---

## 🎨 CSS Variables

The default CSS template uses CSS custom properties. Edit the variables in your companion CSS:

```css
:root {
  /* Fonts */
  --font-body: "Calibri", "Carlito", sans-serif;
  --font-heading: "Calibri Light", "Carlito", sans-serif;
  --font-mono: "Consolas", "Courier New", monospace;

  /* Font sizes (pt units match Word) */
  --size-body: 11pt;
  --size-h1: 16pt;
  --size-h2: 13pt;

  /* Colors */
  --color-body: #000000;
  --color-heading: #1f3864;
  --color-link: #0563c1;

  /* Page (A4) */
  --page-width: 21cm;
  --margin-top: 2.54cm;
  --margin-bottom: 2.54cm;
  --margin-side: 2.54cm;
}
```

---

## 🐛 Troubleshooting

### Server won't start

```vim
" Check Pandoc is installed
:!pandoc --version

" Check Bun is installed
:!bun --version

" Check server status
:DocxPreviewStatus
```

### PDF export fails

```vim
" Install wkhtmltopdf (recommended)
:!sudo apt install wkhtmltopdf

" Or weasyprint
:!pip install weasyprint
```

### Preview not updating

```sh
" Restart the server
:DocxPreviewClose
:DocxPreviewOpen
```

### Port in use

```lua
-- Change port in config
require("docx-preview").setup({
  server = { port = 8766 },
})
```

---

## 📂 File Structure

```
nvim-docx-preview/
├── lua/docx-preview/
│   ├── init.lua           -- Public API
│   ├── config.lua         -- Configuration
│   ├── commands.lua      -- :Docx* commands
│   ├── server.lua        -- Bun process manager
│   ├── autocmd.lua      -- Auto-updates on save
│   ├── utils.lua        -- Utilities
│   ├── style.lua        -- Companion CSS (Phase 2)
│   ├── export.lua      -- Export pipeline (Phase 2)
│   ├── workspace.lua   -- Workspace copy (Phase 3)
│   ├── sanitizer.lua   -- Obsidian→Markdown (Phase 3)
│   └── templates/
│       └── default.css  -- CSS template
├── server/
│   ├── src/
│   │   ├── index.ts     -- Server entry
│   │   ├── server.ts   -- HTTP + WebSocket
│   │   ├── converter.ts-- pandoc → mammoth
│   │   └── ...
│   └── assets/
│       └── preview.html -- Browser shell
├── PRD.md              -- Product spec
├── AGENTS.md           -- Developer docs
└── README.md           -- This file
```

---

## 📜 License

MIT

---

## 🙏 Acknowledgments

- [mammoth.js](https://github.com/mwilliamson/mammoth.js) — Best docx → HTML converter
- [Pandoc](https://pandoc.org/) — The conversion backbone
- [Bun](https://bun.sh/) — Fast server runtime

