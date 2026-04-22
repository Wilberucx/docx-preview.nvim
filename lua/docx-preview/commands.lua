local M = {}

local get_server = nil
local get_utils = nil
local get_config = nil
local get_autocmd = nil
local get_style = nil
local get_export = nil
local get_workspace = nil

local function lazy_load()
  if not get_server then
    get_server = require("docx-preview.server")
  end
  if not get_utils then
    get_utils = require("docx-preview.utils")
  end
  if not get_config then
    get_config = require("docx-preview.config")
  end
  if not get_autocmd then
    get_autocmd = require("docx-preview.autocmd")
  end
  if not get_style then
    get_style = require("docx-preview.style")
  end
  if not get_export then
    get_export = require("docx-preview.export")
  end
  if not get_workspace then
    get_workspace = require("docx-preview.workspace")
  end
end

local is_open = false

-- Get current buffer's markdown filepath
local function get_current_md_filepath()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

  if ft ~= "markdown" then
    vim.notify("docx-preview: Current buffer is not a markdown file", vim.log.levels.ERROR)
    return nil
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not filepath or filepath == "" then
    vim.notify("docx-preview: Buffer has no filepath", vim.log.levels.ERROR)
    return nil
  end

  return filepath
end

function M.open()
  lazy_load()
  local cfg = get_config.get()
  local utils = get_utils
  local server = get_server
  local style = get_style
  
  local filepath = get_current_md_filepath()
  if not filepath then
    return
  end

  if not server.is_running() then
    local ok, err = server.start()
    if not ok then
      vim.notify("docx-preview: Failed to start server: " .. (err or "unknown error"), vim.log.levels.ERROR)
      return
    end
  end
  
  local url = server.get_url()
  utils.open_browser(url)
  
  is_open = true

  -- Handle CSS companion automatically
  local css_path = style.get_companion_css(filepath)
  if not css_path then
    style.generate(filepath)
    css_path = style.get_companion_css(filepath)
  end

  -- Immediately convert so the browser doesn't say "waiting for content"
  server.send_command({
    cmd = "convert",
    file = filepath,
    cssFile = css_path,
  })

  if css_path then
    -- Check if it's already open in a window
    local bufnr = vim.fn.bufnr(css_path)
    local winnr = vim.fn.bufwinnr(bufnr)
    if winnr == -1 then
      vim.cmd("vsplit " .. vim.fn.fnameescape(css_path))
    end
  end
end

function M.close()
  lazy_load()
  local server = get_server
  local utils = get_utils
  
  server.stop()
  
  is_open = false
end

function M.toggle()
  if is_open then
    M.close()
  else
    M.open()
  end
end

function M.status()
  lazy_load()
  local server = get_server
  local cfg = get_config.get()

  if server.is_running() then
    local url = server.get_url()
    vim.notify("docx-preview: Running at " .. url, vim.log.levels.INFO)
  else
    vim.notify("docx-preview: Not running", vim.log.levels.INFO)
  end
end



-- Style commands
function M.style_new()
  lazy_load()
  local filepath = get_current_md_filepath()
  if not filepath then
    return
  end

  local ok = get_style.generate(filepath)
  if ok then
    vim.notify("docx-preview: Generated companion CSS", vim.log.levels.INFO)
  end
end

function M.style_open()
  lazy_load()
  local filepath = get_current_md_filepath()
  if not filepath then
    return
  end

  get_style.open_split(filepath)
end

-- Export commands
function M.export_html()
  lazy_load()
  local filepath = get_current_md_filepath()
  if not filepath then
    return
  end

  get_export.export(filepath, "html")
end

function M.export_pdf()
  lazy_load()
  local filepath = get_current_md_filepath()
  if not filepath then
    return
  end

  get_export.export(filepath, "pdf")
end

function M.export_docx()
  lazy_load()
  local filepath = get_current_md_filepath()
  if not filepath then
    return
  end

  get_export.export(filepath, "docx")
end

-- Print command - sends print command to server
function M.print()
  lazy_load()
  local server = get_server

  if not server.is_running() then
    vim.notify("docx-preview: Server not running. Start preview first.", vim.log.levels.ERROR)
    return
  end

  local url = server.get_url()
  get_utils.open_browser(url)

  -- Send print command to server
  local job = server.get_stdin()
  if job then
    vim.fn.chansend(job, vim.json.encode({ cmd = "print" }) .. "\n")
    vim.notify("docx-preview: Print command sent. Use browser print dialog.", vim.log.levels.INFO)
  else
    vim.notify("docx-preview: Cannot send print command to server", vim.log.levels.ERROR)
  end
end

-- Workspace commands
function M.workspace_copy()
  lazy_load()
  local filepath = get_current_md_filepath()
  if not filepath then
    return
  end

  local result = get_workspace.copy(filepath)
  if not result.ok then
    vim.notify("docx-preview: " .. result.error, vim.log.levels.ERROR)
    return
  end

  vim.notify("docx-preview: Copied to " .. result.path, vim.log.levels.INFO)

  local cfg = get_config.get()
  if cfg.workspace and cfg.workspace.open_after_copy then
    get_workspace.open_split(result.path)
  end
end

function M.workspace_open()
  lazy_load()
  local ws_dir = get_workspace.get_workspace_dir()
  if not ws_dir then
    vim.notify("docx-preview: workspace.dir not configured", vim.log.levels.ERROR)
    return
  end

  -- Open workspace dir in file explorer
  vim.cmd("edit " .. ws_dir)
end

function M.register()
  vim.api.nvim_create_user_command("DocxPreviewOpen", function()
    M.open()
  end, {
    desc = "Open docx preview",
  })
  
  vim.api.nvim_create_user_command("DocxPreviewClose", function()
    M.close()
  end, {
    desc = "Close docx preview",
  })
  
  vim.api.nvim_create_user_command("DocxPreviewToggle", function()
    M.toggle()
  end, {
    desc = "Toggle docx preview",
  })
  
  vim.api.nvim_create_user_command("DocxPreviewStatus", function()
    M.status()
  end, {
    desc = "Show docx preview status",
  })

  -- Style commands
  vim.api.nvim_create_user_command("DocxStyleNew", function()
    M.style_new()
  end, {
    desc = "Generate companion CSS for current markdown file",
  })

  vim.api.nvim_create_user_command("DocxStyleOpen", function()
    M.style_open()
  end, {
    desc = "Open companion CSS in split",
  })

  -- Export commands
  vim.api.nvim_create_user_command("DocxExportHtml", function()
    M.export_html()
  end, {
    desc = "Export current file to HTML",
  })

  vim.api.nvim_create_user_command("DocxExportPdf", function()
    M.export_pdf()
  end, {
    desc = "Export current file to PDF",
  })

  vim.api.nvim_create_user_command("DocxExportDocx", function()
    M.export_docx()
  end, {
    desc = "Export current file to DOCX",
  })

  -- Print command
  vim.api.nvim_create_user_command("DocxPreviewPrint", function()
    M.print()
  end, {
    desc = "Print current document via browser",
  })

  -- Workspace commands
  vim.api.nvim_create_user_command("DocxWorkspaceCopy", function()
    M.workspace_copy()
  end, {
    desc = "Copy current file to workspace",
  })

  vim.api.nvim_create_user_command("DocxWorkspaceOpen", function()
    M.workspace_open()
  end, {
    desc = "Open workspace directory",
  })
end

return M
