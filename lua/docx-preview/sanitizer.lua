local M = {}

-- Sanitizer transforms Obsidian-specific syntax to standard Markdown
-- Each transformation is a separate private function for easy testing

-- 1. Wikilinks with alias: [[Note|Alias]] → [Alias](Note)
local function sanitize_wikilink_with_alias(content)
  local result = content:gsub("%[%[([^%]|]+)|([^%]]+)%]%]", function(link_text, alias)
    return string.format("[%s](%s)", alias, link_text)
  end)
  return result
end

-- 2. Wikilinks plain: [[Note]] → Note (plain text, not a link)
local function sanitize_wikilink_plain(content)
  -- Match [[text]] but NOT [[text|alias]] (already handled above)
  local result = content:gsub("%[%[([^%[%]]+)%]%]", function(link_text)
    return link_text
  end)
  return result
end

-- 3. Image embeds: ![[image.png]] → ![](resolved_path)
-- Resolution: look in same dir as source, then vault root
local function sanitize_image_embed(content, source_filepath)
  local source_dir = vim.fn.fnamemodify(source_filepath, ":p:h")
  local base_dir = vim.fn.fnamemodify(source_dir, ":p:h:h")

  local result = content:gsub("!%[%[([^%]]+)%]%]", function(image_path)
    image_path = vim.fn.trim(image_path)

    -- Try same directory as source
    local full_path = source_dir .. "/" .. image_path
    if vim.fn.filereadable(full_path) == 1 then
      return "![](" .. full_path .. ")"
    end

    -- Try vault root
    full_path = base_dir .. "/" .. image_path
    if vim.fn.filereadable(full_path) == 1 then
      return "![](" .. full_path .. ")"
    end

    -- Not found - warn and leave as-is
    vim.notify("docx-preview: Image not found: " .. image_path, vim.log.levels.WARN)
    return "![](" .. image_path .. ")"
  end)

  return result
end

-- 4. Callouts (Obsidian): > [!NOTE] ... → > **Note:** ... (blockquote)
local function sanitize_callout(content)
  local result = content:gsub(">%s*%[!NOTE%]%s*\n", "> **Note:**\n")

  result = result:gsub(">%s*%[!TIP%]%s*\n", "> **Tip:**\n")
  result = result:gsub(">%s*%[!WARNING%]%s*\n", "> **Warning:**\n")
  result = result:gsub(">%s*%[!IMPORTANT%]%s*\n", "> **Important:**\n")
  result = result:gsub(">%s*%[!INFO%]%s*\n", "> **Info:**\n")
  result = result:gsub(">%s*%[!CAUTION%]%s*\n", "> **Caution:**\n")
  result = result:gsub(">%s*%[!EXAMPLE%]%s*\n", "> **Example:**\n")

  -- Generic callout: > [!任意类型]
  result = result:gsub(">%s*%[!([A-Za-z]+)%]%s*\n", "> **%1:**\n")

  return result
end

-- 5. Tags: #tag → (removed silently)
local function sanitize_tag(content)
  -- Match #tag that is NOT inside brackets or parens (to avoid removing URLs)
  local result = content:gsub("([^%[%(%/])#([a-zA-Z][a-zA-Z0-9_-]+)", function(prefix, tag)
    return prefix .. ""
  end)
  return result
end

-- 6. Frontmatter: ---\n...\n--- → (removed completely)
local function sanitize_frontmatter(content)
  -- Check if file starts with ---
  local first_line = content:match("^([^\n]+)")
  if first_line and first_line:match("^%-%-%-$") then
    -- Find closing ---
    local _, end_pos = content:find("\n%-%-%-\n")
    if end_pos then
      return content:sub(end_pos + 1)
    end
  end
  return content
end

-- Main sanitize function
-- Returns sanitized content ready for Pandoc
function M.sanitize(content, source_filepath)
  vim.validate({
    content = { content, "string" },
    source_filepath = { source_filepath, "string" },
  })

  -- Make a copy to avoid mutating the original
  local result = content

  -- Apply transformations in order
  result = sanitize_wikilink_with_alias(result)
  result = sanitize_wikilink_plain(result)
  result = sanitize_image_embed(result, source_filepath)
  result = sanitize_callout(result)
  result = sanitize_tag(result)
  result = sanitize_frontmatter(result)

  return result
end

return M