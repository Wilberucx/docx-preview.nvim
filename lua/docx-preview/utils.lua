local M = {}

local config = nil

local function get_config()
  if not config then
    config = require("docx-preview.config").get()
  end
  return config
end

function M.resolve_binary(name)
  vim.validate({ name = { name, "string" } })

  if name:sub(1, 1) == "/" or name:sub(1, 2) == "\\" or name:match("^%w+:") then
    return name
  end

  if vim.fn.executable(name) == 1 then
    return name
  end

  return name
end

function M.get_os()
  if vim.fn.has("unix") == 1 then
    if vim.fn.has("mac") == 1 then
      return "mac"
    end
    return "linux"
  elseif vim.fn.has("win32") == 1 then
    return "windows"
  end
  return "linux"
end

function M.get_open_cmd()
  local cfg = get_config()
  if cfg.browser and cfg.browser.open_cmd then
    return cfg.browser.open_cmd
  end

  local os = M.get_os()
  if os == "windows" then
    return "start"
  elseif os == "mac" then
    return "open"
  else
    return "xdg-open"
  end
end

function M.ensure_dir(path)
  vim.validate({ path = { path, "string" } })

  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

function M.get_cache_dir()
  return vim.fn.stdpath("cache") .. "/docx-preview"
end

local log_levels = {
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
}

function M.log(level, message)
  vim.validate({
    level = { level, "string" },
    message = { message, "string" },
  })

  local cfg = get_config()
  local current_level = log_levels[cfg.log.level] or log_levels.warn
  local msg_level = log_levels[level] or log_levels.info

  if msg_level >= current_level then
    vim.notify(string.format("[docx-preview] %s: %s", level:upper(), message), msg_level)
  end
end

function M.open_browser(url)
  vim.validate({ url = { url, "string" } })

  local open_cmd = M.get_open_cmd()
  M.log("debug", string.format("Opening URL: %s with command: %s", url, open_cmd))

  if type(open_cmd) == "function" then
    open_cmd(url)
  else
    if M.get_os() == "windows" then
      vim.fn.system({ open_cmd, url })
    else
      vim.fn.jobstart({ open_cmd, url }, { detach = true })
    end
  end
end

return M
