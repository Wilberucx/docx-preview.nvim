local M = {}

local config = nil
local utils = nil

local state = {
  job = nil,
  pid = nil,
  running = false,
  url = nil,
}

local function get_config()
  if not config then
    config = require("docx-preview.config").get()
  end
  return config
end

local function get_utils()
  if not utils then
    utils = require("docx-preview.utils")
  end
  return utils
end

local function parse_ready_message(line)
  local ok, decoded = pcall(vim.json.decode, line)
  if ok and decoded and decoded.status == "ready" then
    return decoded.url
  end
  return nil
end

local function get_server_entrypoint()
  -- Try debug.getinfo first (always works)
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h:h")
  -- Fallback to lazy if not found
  if vim.fn.isdirectory(plugin_root) == 0 then
    plugin_root = vim.fn.stdpath("data") .. "/lazy/docx-preview.nvim"
  end
  return plugin_root .. "/server/src/index.ts"
end

function M.start()
  local cfg = get_config()
  local util = get_utils()

  if state.running and state.job then
    util.log("debug", "Server already running")
    return true
  end

  local server_entry = get_server_entrypoint()
  if vim.fn.filereadable(server_entry) == 0 then
    util.log("error", string.format("Server entrypoint not found: %s", server_entry))
    return false
  end

  util.ensure_dir(cfg.conversion.output_dir)

  local bun_path = util.resolve_binary(cfg.binaries.bun)

  local cmd = {
    bun_path,
    "run",
    server_entry,
    "--port",
    tostring(cfg.server.port),
    "--host",
    cfg.server.host,
    "--pandoc-bin",
    cfg.binaries.pandoc,
    "--output-dir",
    cfg.conversion.output_dir,
  }

  if cfg.conversion.reference_doc then
    table.insert(cmd, "--reference-doc")
    table.insert(cmd, cfg.conversion.reference_doc)
  end

  if cfg.mammoth.style_map_file then
    table.insert(cmd, "--style-map-file")
    table.insert(cmd, cfg.mammoth.style_map_file)
  end

  local ready_received = false
  local output_buffer = {}

  state.job = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if not data then
        return
      end

      for _, line in ipairs(data) do
        if line ~= "" then
          table.insert(output_buffer, line)

          if not ready_received then
            local url = parse_ready_message(line)
            if url then
              state.url = url
              state.running = true
              ready_received = true
              util.log("info", string.format("Server started at %s", url))
            end
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if not data then
        return
      end
      for _, line in ipairs(data) do
        if line ~= "" then
          util.log("warn", string.format("Server stderr: %s", line))
        end
      end
    end,
    on_exit = function(_, code, _)
      util.log("info", string.format("Server exited with code %d", code))
      state.running = false
      state.job = nil
      state.pid = nil
      state.url = nil
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })

  if state.job <= 0 then
    util.log("error", "Failed to start server job")
    return false
  end

  state.pid = vim.fn.jobpid(state.job)

  local timeout = 5000
  local interval = 100

  local ok = vim.wait(timeout, function()
    return state.running
  end, interval)

  if not ok then
    util.log("error", "Server startup timeout - no 'ready' message received")
    M.stop()
    return false
  end

  return true
end

function M.stop()
  if not state.job then
    return
  end

  local util = get_utils()

  local ok, _ = pcall(function()
    vim.fn.chansend(state.job, vim.json.encode({ cmd = "shutdown" }) .. "\n")
  end)

  if not ok then
    util.log("warn", "Failed to send shutdown command, forcing stop")
  end

  vim.fn.jobstop(state.job)

  state.job = nil
  state.pid = nil
  state.running = false
  state.url = nil

  util.log("info", "Server stopped")
end

function M.send_command(cmd)
  local util = get_utils()

  if not state.job or not state.running then
    util.log("warn", "Cannot send command: server not running")
    return false
  end

  local ok, err = pcall(function()
    vim.fn.chansend(state.job, vim.json.encode(cmd) .. "\n")
  end)

  if not ok then
    util.log("error", string.format("Failed to send command: %s", err))
    return false
  end

  return true
end

function M.is_running()
  return state.running
end

function M.get_url()
  return state.url
end

function M.get_stdin()
  -- Return the channel ID for stdin operations
  -- Use vim.fn.chansend with this ID to send commands
  return state.job
end

function M.get_pid()
  return state.pid
end

return M
