# AGENTS.md — nvim-docx-preview

> Instructions for AI coding agents working on this repository.
> Read this file completely before writing a single line of code.

---

## 1. Project Overview

`nvim-docx-preview` is a Neovim plugin that provides live `.docx` preview in
the browser while editing Markdown. It uses Pandoc to convert `.md → .docx`
and mammoth.js to convert `.docx → HTML`, served via a Bun WebSocket server.

Full specification: see `PRD.md` at the root of this repository.

---

## 2. Git Flow — Non-Negotiable

This project follows strict Git Flow. Violating this will result in your work
being rejected regardless of quality.

### Branch Structure

```
main        ← production only. Tagged releases. Never commit directly.
dev         ← integration branch. All features merge here first.
feature/*   ← one branch per feature/task.
fix/*       ← one branch per bug fix.
```

### Rules

1. **NEVER commit to `main` directly.** Not even a typo fix.
2. **NEVER commit to `dev` directly.** Always go through a feature branch.
3. Every feature branch is cut from `dev`, not from `main`.
4. Feature branches are merged back into `dev` via PR/MR only.
5. `dev` is merged into `main` only for releases, with a version tag.

### Branch Naming

```
feature/config-schema-validation
feature/bun-server-lifecycle
feature/mammoth-converter
feature/websocket-broadcaster
feature/browser-preview-shell
fix/pandoc-path-resolution
fix/server-crash-on-empty-file
```

### Commit Messages (Conventional Commits)

Format: `type(scope): short description`

```
feat(config): add binary path validation on setup()
feat(server): implement stdin command listener
feat(converter): add pandoc → mammoth pipeline
fix(autocmd): prevent duplicate triggers on rapid saves
chore(deps): add mammoth 1.8.0 to package.json
docs(readme): add installation instructions
refactor(server): extract WebSocket broadcaster to own module
test(converter): add unit tests for error handling
```

Types: `feat` · `fix` · `chore` · `docs` · `refactor` · `test` · `perf`

**One logical change per commit.** Do not batch unrelated changes.

---

## 3. Workflow for Every Task

Follow this sequence without skipping steps:

```
1. Read the PRD section relevant to your task
2. Check existing code — do not duplicate, do not reinvent
3. Cut feature branch from dev
4. Implement with tests where applicable
5. Self-review: apply the checklist in section 6
6. Commit with conventional commit message
7. Do NOT merge — leave the branch ready for review
```

If you are unsure where code belongs, **create a new file** with a single
responsibility. Never add code to an existing file that doesn't belong there.

---

## 4. Architecture Rules (from PRD)

These are hard constraints. Do not negotiate them.

### 4.1 No Hardcoded Values

WRONG:

```typescript
const port = 8765;
const pandocPath = "/usr/local/bin/pandoc";
const template = "~/Documents/template.docx";
```

RIGHT:

```typescript
// All values come from config passed at runtime
const { port, pandocPath, referencDoc } = config;
```

Every configurable value lives in `lua/docx-preview/config.lua`.
The Bun server receives its config via CLI args or stdin at startup.
Never hardcode a port, path, binary name, or filename anywhere.

### 4.2 Single Responsibility Per File

Each file does exactly one thing. If you can't describe what a file does in
one sentence, it needs to be split.

| File           | Does                                                        |
| -------------- | ----------------------------------------------------------- |
| `config.lua`   | Owns config schema, defaults, and validation. Nothing else. |
| `server.lua`   | Manages Bun process lifecycle. Nothing else.                |
| `autocmd.lua`  | Registers and clears autocmds. Nothing else.                |
| `converter.ts` | Runs pandoc → mammoth pipeline. Nothing else.               |
| `server.ts`    | Manages HTTP and WebSocket connections. Nothing else.       |
| `watcher.ts`   | Watches filesystem for changes. Nothing else.               |
| `styles.ts`    | Loads and parses mammoth style maps. Nothing else.          |

### 4.3 Errors Are Data, Not Exceptions

WRONG:

```typescript
const result = await runPandoc(file);
// if pandoc fails, this throws and crashes the server
```

RIGHT:

```typescript
const result = await runPandoc(file);
if (!result.ok) {
  broadcast({ type: "error", message: result.error });
  return;
}
```

The Bun server must NEVER crash due to a conversion error.
All errors must be caught, structured, and sent to the browser or back to Neovim.

### 4.4 Lua Side Owns Lifecycle

The Bun server is a dumb worker. It does not decide when to start or stop.
Neovim (via `server.lua`) is the process owner.

The server only responds to commands. It does not have opinions about when
to run.

---

## 5. Directory Structure Reference

```
nvim-docx-preview/
├── plugin/
│   └── nvim-docx-preview.lua        # Autoloaded entrypoint
├── lua/
│   └── docx-preview/
│       ├── init.lua                 # Public API
│       ├── config.lua               # Config schema + validation
│       ├── server.lua               # Bun process lifecycle
│       ├── autocmd.lua              # BufWritePost handlers
│       ├── commands.lua             # :DocxPreview* commands
│       └── utils.lua                # Shared utilities
├── server/
│   ├── src/
│   │   ├── index.ts                 # Server entry point
│   │   ├── server.ts                # HTTP + WebSocket
│   │   ├── converter.ts             # pandoc → mammoth
│   │   ├── watcher.ts               # File watcher
│   │   ├── styles.ts                # Style map loader
│   │   └── logger.ts                # Structured logging
│   ├── assets/
│   │   └── preview.html             # Browser shell
│   ├── package.json
│   └── tsconfig.json
├── scripts/
│   └── install-server.sh
├── PRD.md
└── AGENTS.md                        # ← you are here
```

If you need to create a file not listed here, that is fine — but justify it
with a single-sentence description in your commit message.

---

## 6. Pre-Commit Checklist

Run through this before every commit. If any item fails, fix it first.

```
[ ] My branch is cut from `dev`, not from `main`
[ ] My branch name follows the naming convention
[ ] I have not modified files outside my task's scope
[ ] No hardcoded paths, ports, or filenames
[ ] No file does more than one thing
[ ] All error paths return structured errors, not thrown exceptions
[ ] Commit message follows conventional commits format
[ ] The server still starts cleanly after my changes
[ ] I have not introduced new dependencies without updating package.json
[ ] If I changed config schema, I updated config.lua defaults and validation
```

---

## 7. Dependency Policy

### Adding a dependency to the Bun server

Before adding any npm package:

1. Check if Bun's standard library already covers it (`Bun.file`, `Bun.serve`, etc.)
2. If the package has >1M weekly downloads and is actively maintained: OK
3. If it's a niche package with <100K downloads: discuss first, do not add silently

Current approved dependencies:

- `mammoth` — docx → HTML conversion (core feature, no alternative)

### Lua dependencies

Zero. The Neovim plugin must have no external Lua dependencies.
Use only the Neovim built-in APIs (`vim.fn`, `vim.api`, `vim.loop`/`vim.uv`).

---

## 8. TypeScript Style

```typescript
// Always explicit return types on exported functions
export async function convert(
  file: string,
  config: ConverterConfig,
): Promise<ConversionResult> {}

// Result type pattern for error handling (no throws in async code)
type ConversionResult =
  | { ok: true; html: string; durationMs: number }
  | { ok: false; error: string };

// Config types are always interfaces, not type aliases
interface ServerConfig {
  port: number;
  host: string;
  pandocBin: string;
  referencDoc: string | null;
  outputDir: string;
}

// No `any`. Ever. Use `unknown` and narrow it.
```

---

## 9. Lua Style

```lua
-- Module pattern: always return a table
local M = {}

-- Private functions have no M. prefix
local function resolve_binary(name)
  -- ...
end

-- Public API always goes through M
function M.setup(opts)
  -- ...
end

return M

-- Use vim.validate() for config validation
vim.validate({
  port = { opts.server.port, "number" },
  host = { opts.server.host, "string" },
})
```

---

## 10. Phase Awareness

The PRD defines 3 implementation phases. Know which phase you are in.

```
Phase 1 — MVP (start here)
  Core pipeline working end to end.
  No polish, no edge cases, just functional.

Phase 2 — Polish
  Only start after Phase 1 is merged to dev and tested.

Phase 3 — Nice to have
  Only start after Phase 2 is merged to dev and tested.
```

**Do not implement Phase 2 features while Phase 1 is incomplete.**
This is how projects turn into perpetual WIPs.

---

## 11. What to Do When Stuck

In order of preference:

1. Re-read the PRD — the answer is probably there
2. Check existing code in the repo for patterns already established
3. Check official docs: [Bun docs](https://bun.sh/docs), [mammoth.js](https://github.com/mwilliamson/mammoth.js), [Neovim Lua API](https://neovim.io/doc/user/lua.html)
4. If still blocked: leave a `TODO` comment with a clear description of the
   blocker and move on. Do not invent solutions for things you are uncertain about.

```typescript
// TODO: unclear if mammoth handles password-protected docx.
// Needs testing with a locked file. For now, treat as conversion error.
```

---

_This file is a living document. If the architecture evolves, update this file
in the same PR that changes the architecture._
