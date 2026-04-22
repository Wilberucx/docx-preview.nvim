local M = {}

local config = nil
local server = nil
local autocmd = nil
local commands = nil
local utils = nil
local style = nil
local export = nil
local workspace = nil

local function lazy_load()
  if not config then
    config = require("docx-preview.config")
  end
  if not server then
    server = require("docx-preview.server")
  end
  if not autocmd then
    autocmd = require("docx-preview.autocmd")
  end
  if not commands then
    commands = require("docx-preview.commands")
  end
  if not utils then
    utils = require("docx-preview.utils")
  end
  if not style then
    style = require("docx-preview.style")
  end
  if not export then
    export = require("docx-preview.export")
  end
  if not workspace then
    workspace = require("docx-preview.workspace")
  end
end

function M.setup(opts)
  lazy_load()
  
  config.setup(opts or {})
  
  local cfg = config.get()
  utils.ensure_dir(cfg.conversion.output_dir)
  
  commands.register()
  
  autocmd.register()
  
  if cfg.server.autostart then
    vim.defer_fn(function()
      local ok, err = server.start()
      if not ok then
        vim.notify("docx-preview: Auto-start failed: " .. (err or "unknown error"), vim.log.levels.WARN)
      end
    end, 100)
  end
end

function M.open()
  lazy_load()
  commands.open()
end

function M.close()
  lazy_load()
  commands.close()
end

function M.toggle()
  lazy_load()
  commands.toggle()
end

function M.status()
  lazy_load()
  commands.status()
end

-- Style module API
function M.get_companion_css(md_filepath)
  lazy_load()
  return style.get_companion_css(md_filepath)
end

function M.generate_style(md_filepath)
  lazy_load()
  return style.generate(md_filepath)
end

function M.open_style_split(md_filepath)
  lazy_load()
  return style.open_split(md_filepath)
end

-- Export module API
function M.export_html(md_filepath, css_filepath)
  lazy_load()
  return export.to_html(md_filepath, css_filepath)
end

function M.export_pdf(md_filepath, css_filepath)
  lazy_load()
  return export.to_pdf(md_filepath, css_filepath)
end

function M.export_docx(md_filepath)
  lazy_load()
  return export.to_docx(md_filepath)
end

function M.open_output(filepath)
  lazy_load()
  return export.open_output(filepath)
end

function M.export(md_filepath, format)
  lazy_load()
  return export.export(md_filepath, format)
end

-- Workspace module API
function M.get_workspace_dir()
  lazy_load()
  return workspace.get_workspace_dir()
end

function M.is_workspace_file(filepath)
  lazy_load()
  return workspace.is_workspace_file(filepath)
end

function M.copy_to_workspace(md_filepath)
  lazy_load()
  return workspace.copy(md_filepath)
end

function M.open_workspace_split(filepath)
  lazy_load()
  return workspace.open_split(filepath)
end

return M
