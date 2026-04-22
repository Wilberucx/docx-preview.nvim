local M = {}

local get_config = nil
local get_sanitizer = nil

local function lazy_load()
  if not get_config then
    get_config = require("docx-preview.config")
  end
  if not get_sanitizer then
    get_sanitizer = require("docx-preview.sanitizer")
  end
end

-- Get configured workspace dir or nil
function M.get_workspace_dir()
  lazy_load()
  local cfg = get_config.get()
  return cfg.workspace and cfg.workspace.dir or nil
end

-- Generate copy filename with optional timestamp
function M.get_copy_name(md_filepath)
  lazy_load()
  local cfg = get_config.get()

  local base_name = vim.fn.fnamemodify(md_filepath, ":t:r")
  local ext = vim.fn.fnamemodify(md_filepath, ":e")

  if cfg.workspace and cfg.workspace.timestamp_copies then
    local timestamp = os.date("%Y%m%d-%H%M%S")
    return base_name .. "-" .. timestamp .. "." .. ext
  else
    return base_name .. "." .. ext
  end
end

-- Check if filepath is inside workspace dir
function M.is_workspace_file(filepath)
  local ws_dir = M.get_workspace_dir()
  if not ws_dir then
    return false
  end

  local abs_filepath = vim.fn.fnamemodify(filepath, ":p")
  local abs_ws_dir = vim.fn.fnamemodify(ws_dir, ":p")

  -- Check if filepath starts with workspace dir
  return abs_filepath:sub(1, abs_ws_dir:len()) == abs_ws_dir
end

-- Copy source .md to workspace with sanitization
function M.copy(md_filepath)
  vim.validate({ md_filepath = { md_filepath, "string" } })

  lazy_load()
  local cfg = get_config.get()

  local ws_dir = M.get_workspace_dir()
  if not ws_dir then
    return { ok = false, error = "workspace.dir not configured" }
  end

  -- Ensure workspace dir exists
  if vim.fn.isdirectory(ws_dir) == 0 then
    vim.fn.mkdir(ws_dir, "p")
  end

  -- Read source content
  local lines = vim.fn.readfile(md_filepath)
  if type(lines) ~= "table" then
    return { ok = false, error = "Failed to read source file" }
  end
  local content = table.concat(lines, "\n")

  -- Sanitize content if configured
  if cfg.workspace and cfg.workspace.sanitize_wikilinks then
    content = get_sanitizer.sanitize(content, md_filepath)
  end

  -- Generate copy filename and path
  local copy_name = M.get_copy_name(md_filepath)
  local copy_path = ws_dir .. "/" .. copy_name

  -- Write sanitized copy
  local write_lines = vim.split(content, "\n")
  local write_result = vim.fn.writefile(write_lines, copy_path)

  if write_result ~= 0 then
    return { ok = false, error = "Failed to write workspace copy" }
  end

  -- Copy companion CSS if it exists next to source
  local source_dir = vim.fn.fnamemodify(md_filepath, ":p:h")
  local source_name = vim.fn.fnamemodify(md_filepath, ":t:r")
  local source_css = source_dir .. "/" .. source_name .. ".css"

  if vim.fn.filereadable(source_css) == 1 then
    local copy_css = ws_dir .. "/" .. copy_name:gsub("%.md$", ".css")
    local css_lines = vim.fn.readfile(source_css)
    if type(css_lines) == "table" then
      vim.fn.writefile(css_lines, copy_css)
    end
  end

  return { ok = true, path = copy_path }
end

-- Open file in vertical split
function M.open_split(filepath)
  vim.validate({ filepath = { filepath, "string" } })

  if vim.fn.filereadable(filepath) ~= 1 then
    vim.notify("docx-preview: File not found: " .. filepath, vim.log.levels.ERROR)
    return
  end

  vim.cmd("vsplit " .. filepath)
end

return M