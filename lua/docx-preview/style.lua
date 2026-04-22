local M = {}

local get_config = nil

local function lazy_load()
  if not get_config then
    get_config = require("docx-preview.config").get()
  end
end

-- Get the plugin's templates directory
local function get_templates_dir()
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h:h")
  return plugin_root .. "/lua/docx-preview/templates"
end

-- Get companion CSS path for a given markdown file
-- Returns path to .css if exists alongside .md, else nil
function M.get_companion_css(md_filepath)
  vim.validate({ md_filepath = { md_filepath, "string" } })

  local md_dir = vim.fn.fnamemodify(md_filepath, ":p:h")
  local md_name = vim.fn.fnamemodify(md_filepath, ":t:r")
  local css_path = md_dir .. "/" .. md_name .. ".css"

  if vim.fn.filereadable(css_path) == 1 then
    return css_path
  end

  return nil
end

-- Generate a new companion CSS file from the template
-- Returns: boolean (true on success, false if file exists)
function M.generate(md_filepath)
  vim.validate({ md_filepath = { md_filepath, "string" } })

  local md_dir = vim.fn.fnamemodify(md_filepath, ":p:h")
  local md_name = vim.fn.fnamemodify(md_filepath, ":t:r")
  local css_path = md_dir .. "/" .. md_name .. ".css"

  -- Check if file already exists
  if vim.fn.filereadable(css_path) == 1 then
    vim.notify("docx-preview: Companion CSS already exists at " .. css_path .. ". Delete it first or use :DocxStyleOpen to edit.",
      vim.log.levels.WARN)
    return false
  end

  -- Read template
  local templates_dir = get_templates_dir()
  local template_path = templates_dir .. "/default.css"

  if vim.fn.filereadable(template_path) ~= 1 then
    vim.notify("docx-preview: Default CSS template not found at " .. template_path, vim.log.levels.ERROR)
    return false
  end

  local template_content = vim.fn.readfile(template_path)
  if type(template_content) == "table" then
    template_content = table.concat(template_content, "\n")
  end

  -- Write to user's directory
  local lines = vim.split(template_content, "\n")
  local write_result = vim.fn.writefile(lines, css_path)

  if write_result == 0 then
    vim.notify("docx-preview: Generated companion CSS at " .. css_path, vim.log.levels.INFO)
    return true
  else
    vim.notify("docx-preview: Failed to write CSS file", vim.log.levels.ERROR)
    return false
  end
end

-- Open companion CSS in a vertical split
-- If .css doesn't exist, prompts user to generate it first
function M.open_split(md_filepath)
  vim.validate({ md_filepath = { md_filepath, "string" } })

  local css_path = M.get_companion_css(md_filepath)

  if not css_path then
    vim.notify("docx-preview: No companion CSS found. Generate one first with :DocxStyleNew",
      vim.log.levels.WARN)
    local confirm = vim.fn.input("Generate companion CSS? (y/n): ")
    if confirm:lower() == "y" then
      local ok = M.generate(md_filepath)
      if ok then
        css_path = M.get_companion_css(md_filepath)
      else
        return
      end
    else
      return
    end
  end

  if css_path then
    vim.cmd("vsplit " .. css_path)
  end
end

return M