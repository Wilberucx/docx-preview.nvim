local M = {}

local get_config = nil
local get_utils = nil
local get_style = nil
local get_workspace = nil

local function lazy_load()
  if not get_config then
    get_config = require("docx-preview.config").get()
  end
  if not get_utils then
    get_utils = require("docx-preview.utils")
  end
  if not get_style then
    get_style = require("docx-preview.style")
  end
  if not get_workspace then
    get_workspace = require("docx-preview.workspace")
  end
end

-- Resolve export source: copy to workspace if needed
local function resolve_export_source(md_filepath)
  local ws = get_workspace
  local cfg = get_config.get()

  -- If workspace not configured, use source directly
  if not cfg.workspace or not cfg.workspace.dir then
    return { ok = true, path = md_filepath }
  end

  -- If already a workspace file, use directly
  if ws.is_workspace_file(md_filepath) then
    return { ok = true, path = md_filepath }
  end

  -- Copy to workspace
  return ws.copy(md_filepath)
end

-- Convert markdown file path to output path with new extension
local function get_output_path(md_filepath, new_ext)
  local cfg = get_config.get()
  local md_dir = vim.fn.fnamemodify(md_filepath, ":p:h")
  local md_name = vim.fn.fnamemodify(md_filepath, ":t:r")

  local output_dir = cfg.export and cfg.export.output_dir or nil
  if not output_dir then
    output_dir = md_dir
  end

  return output_dir .. "/" .. md_name .. "." .. new_ext
end

-- Check if a binary is available
local function has_binary(name)
  return vim.fn.executable(name) == 1
end

-- Export to HTML
-- pandoc md → standalone HTML with embedded CSS
function M.to_html(md_filepath, css_filepath)
  vim.validate({ md_filepath = { md_filepath, "string" } })

  lazy_load()
  local cfg = get_config.get()
  local utils = get_utils

  local output_path = get_output_path(md_filepath, "html")

  local pandoc_bin = cfg.binaries and cfg.binaries.pandoc or "pandoc"
  local args = {
    md_filepath,
    "--standalone",
    "--embed-resources",
  }

  -- Add CSS if provided
  if css_filepath and vim.fn.filereadable(css_filepath) == 1 then
    table.insert(args, "--css=" .. css_filepath)
  end

  table.insert(args, "-o")
  table.insert(args, output_path)

  local job = vim.fn.jobstart({
    pandoc_bin,
    unpack(args),
  }, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify("docx-preview: Exported HTML to " .. output_path, vim.log.levels.INFO)

        -- Open after export if configured
        if cfg.export and cfg.export.open_after_export then
          M.open_output(output_path)
        end
      else
        vim.notify("docx-preview: HTML export failed (exit code " .. exit_code .. ")",
          vim.log.levels.ERROR)
      end
    end,
  })

  return true
end

-- Detect available PDF engine
local function detect_pdf_engine()
  local cfg = get_config.get()
  local engines = (cfg.export and cfg.export.pdf_engines) or { "wkhtmltopdf", "weasyprint", "pdflatex" }

  for _, engine in ipairs(engines) do
    if has_binary(engine) then
      return engine
    end
  end

  return nil
end

-- Export to PDF
-- Priority: wkhtmltopdf → weasyprint → pandoc native (LaTeX)
function M.to_pdf(md_filepath, css_filepath)
  vim.validate({ md_filepath = { md_filepath, "string" } })

  lazy_load()
  local cfg = get_config.get()
  local utils = get_utils

  local engine = detect_pdf_engine()

  if not engine then
    vim.notify("docx-preview: No PDF engine found. Install wkhtmltopdf, weasyprint, or pdflatex.",
      vim.log.levels.ERROR)
    return false
  end

  local output_path = get_output_path(md_filepath, "pdf")
  local pandoc_bin = cfg.binaries and cfg.binaries.pandoc or "pandoc"

  if engine == "wkhtmltopdf" then
    -- First convert MD to HTML, then use wkhtmltopdf
    local html_path = get_output_path(md_filepath, "html")
    local html_args = {
      md_filepath,
      "--standalone",
      "--embed-resources",
    }
    if css_filepath and vim.fn.filereadable(css_filepath) == 1 then
      table.insert(html_args, "--css=" .. css_filepath)
    end
    table.insert(html_args, "-o")
    table.insert(html_args, html_path)

    -- Convert to HTML first
    vim.fn.jobstart({
      pandoc_bin,
      unpack(html_args),
    }, {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          -- Then convert HTML to PDF with wkhtmltopdf
          vim.fn.jobstart({
            "wkhtmltopdf",
            "--page-size", "A4",
            html_path,
            output_path,
          }, {
            on_exit = function(_, pdf_exit)
              if pdf_exit == 0 then
                -- Clean up temp HTML
                vim.fn.delete(html_path)
                vim.notify("docx-preview: Exported PDF to " .. output_path,
                  vim.log.levels.INFO)

                if cfg.export and cfg.export.open_after_export then
                  M.open_output(output_path)
                end
              else
                vim.notify("docx-preview: PDF export failed with wkhtmltopdf",
                  vim.log.levels.ERROR)
              end
            end,
          })
        else
          vim.notify("docx-preview: HTML conversion failed for PDF",
            vim.log.levels.ERROR)
        end
      end,
    })

  elseif engine == "weasyprint" then
    -- First convert MD to HTML, then use weasyprint
    local html_path = get_output_path(md_filepath, "html")
    local html_args = {
      md_filepath,
      "--standalone",
      "--embed-resources",
    }
    if css_filepath and vim.fn.filereadable(css_filepath) == 1 then
      table.insert(html_args, "--css=" .. css_filepath)
    end
    table.insert(html_args, "-o")
    table.insert(html_args, html_path)

    -- Convert to HTML first
    vim.fn.jobstart({
      pandoc_bin,
      unpack(html_args),
    }, {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          -- Then convert HTML to PDF with weasyprint
          vim.fn.jobstart({
            "weasyprint",
            html_path,
            output_path,
          }, {
            on_exit = function(_, pdf_exit)
              if pdf_exit == 0 then
                -- Clean up temp HTML
                vim.fn.delete(html_path)
                vim.notify("docx-preview: Exported PDF to " .. output_path,
                  vim.log.levels.INFO)

                if cfg.export and cfg.export.open_after_export then
                  M.open_output(output_path)
                end
              else
                vim.notify("docx-preview: PDF export failed with weasyprint",
                  vim.log.levels.ERROR)
              end
            end,
          })
        else
          vim.notify("docx-preview: HTML conversion failed for PDF",
            vim.log.levels.ERROR)
        end
      end,
    })

  else
    -- Fallback: use pandoc native (LaTeX)
    local args = {
      md_filepath,
      "-o",
      output_path,
    }

    vim.fn.jobstart({
      pandoc_bin,
      unpack(args),
    }, {
      on_exit = function(_, exit_code)
        if exit_code == 0 then
          vim.notify("docx-preview: Exported PDF to " .. output_path, vim.log.levels.INFO)

          if cfg.export and cfg.export.open_after_export then
            M.open_output(output_path)
          end
        else
          vim.notify("docx-preview: PDF export failed (exit code " .. exit_code .. ")",
            vim.log.levels.ERROR)
        end
      end,
    })
  end

  return true
end

-- Export to DOCX
-- pandoc md → .docx using reference_doc from config if set
function M.to_docx(md_filepath)
  vim.validate({ md_filepath = { md_filepath, "string" } })

  lazy_load()
  local cfg = get_config.get()
  local utils = get_utils

  local output_path = get_output_path(md_filepath, "docx")
  local pandoc_bin = cfg.binaries and cfg.binaries.pandoc or "pandoc"
  local args = {
    md_filepath,
    "-o",
    output_path,
  }

  -- Add reference doc if configured
  local reference_doc = cfg.conversion and cfg.conversion.reference_doc
  if reference_doc and vim.fn.filereadable(reference_doc) == 1 then
    table.insert(args, "--reference-doc=" .. reference_doc)
  end

  vim.fn.jobstart({
    pandoc_bin,
    unpack(args),
  }, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify("docx-preview: Exported DOCX to " .. output_path,
          vim.log.levels.INFO)

        if cfg.export and cfg.export.open_after_export then
          M.open_output(output_path)
        end
      else
        vim.notify("docx-preview: DOCX export failed (exit code " .. exit_code .. ")",
          vim.log.levels.ERROR)
      end
    end,
  })

  return true
end

-- Open output file using system default
function M.open_output(filepath)
  vim.validate({ filepath = { filepath, "string" } })

  if vim.fn.filereadable(filepath) ~= 1 then
    vim.notify("docx-preview: File not found: " .. filepath, vim.log.levels.ERROR)
    return false
  end

  local open_cmd = get_utils.get_open_cmd()
  local os = get_utils.get_os()

  if os == "windows" then
    vim.fn.system({ open_cmd, filepath })
  else
    vim.fn.jobstart({ open_cmd, filepath }, { detach = true })
  end

  return true
end

-- Main export function that auto-detects companion CSS
function M.export(md_filepath, format)
  vim.validate({
    md_filepath = { md_filepath, "string" },
    format = { format, "string" },
  })

  -- Resolve workspace source
  local source = resolve_export_source(md_filepath)
  if not source.ok then
    vim.notify("docx-preview: " .. source.error, vim.log.levels.ERROR)
    return false
  end

  local export_path = source.path
  local css_path = get_style.get_companion_css(export_path)

  if format == "html" then
    return M.to_html(export_path, css_path)
  elseif format == "pdf" then
    return M.to_pdf(export_path, css_path)
  elseif format == "docx" then
    return M.to_docx(export_path)
  else
    vim.notify("docx-preview: Unknown export format: " .. format, vim.log.levels.ERROR)
    return false
  end
end

return M