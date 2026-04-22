local M = {}

local augroup_id = nil

local get_config = nil
local get_server = nil

local function lazy_load()
  if not get_config then
    get_config = function()
      local config = require("docx-preview.config")
      return config.get()
    end
  end
  if not get_server then
    get_server = require("docx-preview.server")
  end
end

local function on_buf_write_post(bufnr)
  lazy_load()

  local cfg = get_config()

  if not cfg.autocmd.enabled then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if not filepath or filepath == "" then
    return
  end

  if not get_server.is_running() then
    return
  end

  get_server.send_command({
    cmd = "convert",
    file = filepath,
  })
end

function M.register()
  lazy_load()
  local cfg = get_config()

  if not cfg.autocmd.enabled then
    return
  end

  augroup_id = vim.api.nvim_create_augroup("docx-preview", { clear = true })

  -- Register ONE autocmd for each event (not per filetype)
  -- Check filetype inside callback (Opción B)
  for _, event in ipairs(cfg.autocmd.events) do
    vim.api.nvim_create_autocmd(event, {
      group = augroup_id,
      callback = function(args)
        -- Check if buffer filetype matches configured filetypes
        local buf_filetype = vim.bo[args.buf].filetype
        if not vim.tbl_contains(cfg.autocmd.filetypes, buf_filetype) then
          return
        end
        on_buf_write_post(args.buf)
      end,
      desc = "docx-preview: trigger conversion on " .. event,
    })
  end
end

function M.unregister()
  if augroup_id then
    pcall(vim.api.nvim_del_augroup_by_id, augroup_id)
    augroup_id = nil
  end
end

return M
