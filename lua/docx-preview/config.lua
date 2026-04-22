local M = {}

local defaults = {
  binaries = {
    pandoc = "pandoc",
    bun = "bun",
  },
  server = {
    port = 8765,
    host = "127.0.0.1",
    autostart = false,
  },
  conversion = {
    reference_doc = nil,
    output_dir = "/tmp/docx-preview",
    extra_pandoc_args = {},
  },
  mammoth = {
    style_map_file = nil,
  },
  browser = {
    open_cmd = nil,
  },
  autocmd = {
    enabled = true,
    filetypes = { "markdown" },
    events = { "BufWritePost" },
  },
  log = {
    level = "warn",
  },
  export = {
    output_dir = nil,
    open_after_export = true,
    pdf_engines = { "wkhtmltopdf", "weasyprint", "pdflatex" },
  },
  style = {
    auto_detect = true,
    auto_generate = false,
  },
  workspace = {
    dir = nil,
    sanitize_wikilinks = true,
    timestamp_copies = true,
    open_after_copy = true,
  },
}

local config = vim.deepcopy(defaults)

local function validate_config(opts)
  vim.validate({
    binaries = { opts.binaries, "table" },
    ["binaries.pandoc"] = { opts.binaries.pandoc, "string" },
    ["binaries.bun"] = { opts.binaries.bun, "string" },
    server = { opts.server, "table" },
    ["server.port"] = { opts.server.port, "number" },
    ["server.host"] = { opts.server.host, "string" },
    ["server.autostart"] = { opts.server.autostart, "boolean" },
    conversion = { opts.conversion, "table" },
    ["conversion.reference_doc"] = { opts.conversion.reference_doc, "string", true },
    ["conversion.output_dir"] = { opts.conversion.output_dir, "string" },
    ["conversion.extra_pandoc_args"] = { opts.conversion.extra_pandoc_args, "table" },
    mammoth = { opts.mammoth, "table" },
    ["mammoth.style_map_file"] = { opts.mammoth.style_map_file, "string", true },
    browser = { opts.browser, "table" },
    ["browser.open_cmd"] = { opts.browser.open_cmd, { "string", "function" }, true },
    autocmd = { opts.autocmd, "table" },
    ["autocmd.enabled"] = { opts.autocmd.enabled, "boolean" },
    ["autocmd.filetypes"] = { opts.autocmd.filetypes, "table" },
    ["autocmd.events"] = { opts.autocmd.events, "table" },
    log = { opts.log, "table" },
    ["log.level"] = { opts.log.level, "string" },
    export = { opts.export, "table" },
    ["export.output_dir"] = { opts.export.output_dir, "string", true },
    ["export.open_after_export"] = { opts.export.open_after_export, "boolean" },
    ["export.pdf_engines"] = { opts.export.pdf_engines, "table" },
    style = { opts.style, "table" },
    ["style.auto_detect"] = { opts.style.auto_detect, "boolean" },
    ["style.auto_generate"] = { opts.style.auto_generate, "boolean" },
    workspace = { opts.workspace, "table" },
    ["workspace.dir"] = { opts.workspace.dir, "string", true },
    ["workspace.sanitize_wikilinks"] = { opts.workspace.sanitize_wikilinks, "boolean" },
    ["workspace.timestamp_copies"] = { opts.workspace.timestamp_copies, "boolean" },
    ["workspace.open_after_copy"] = { opts.workspace.open_after_copy, "boolean" },
  })
end

local function validate_binaries(opts)
  local pandoc_path = opts.binaries.pandoc
  local bun_path = opts.binaries.bun

  if vim.fn.executable(pandoc_path) == 0 then
    error(string.format("pandoc binary not found: '%s'. Please install pandoc or specify the path in the config.",
      pandoc_path))
  end

  if vim.fn.executable(bun_path) == 0 then
    error(string.format("bun binary not found: '%s'. Please install bun or specify the path in the config.", bun_path))
  end
end

function M.setup(opts)
  opts = opts or {}

  vim.validate({
    opts = { opts, "table" },
  })

  local user_config = vim.deepcopy(defaults)

  -- vim.tbl_deep_extend is a pure function — result must be assigned back
  user_config = vim.tbl_deep_extend("force", user_config, opts)

  validate_config(user_config)
  validate_binaries(user_config)

  config = user_config
  return config
end

function M.get()
  return config
end

function M.get_server_url()
  return string.format("http://%s:%d", config.server.host, config.server.port)
end

return M
