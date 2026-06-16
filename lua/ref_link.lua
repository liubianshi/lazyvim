-- lua/ref_link.lua
-- Markdown reference-style link helpers.
--
-- A faithful Lua port of the former `autoload/ref_link.vim`:
--   * `M.get_id(url)` finds or creates a `[n]: url` definition under a
--     `<!-- Links -->` section at the end of the buffer.
--   * `M.add()` turns the text under the cursor (or a freshly fetched URL)
--     into a reference link.

local M = {}

-- Pattern matching `[123]: some-url`, capturing id and url (trailing space trimmed).
local LINK_PATTERN = "^%[(%d+)%]:%s+(.-)%s*$"

---
-- Finds an existing reference link for `url` or creates a new one.
--
-- Searches for a `<!-- Links -->` section at the end of the buffer. If the
-- section exists, it scans for the URL: when found, the existing ID is
-- returned; otherwise a new definition with the next free ID is appended.
-- If the section is missing, it is created together with the first link.
--
-- @param url string The URL to find or add.
-- @return string The link ID (e.g. "1", "2").
function M.get_id(url)
  -- Search for the marker without moving the cursor and without wrapping.
  local marker_line = vim.fn.search("^<!-- Links -->$", "nW")

  -- No link section yet: create it and add the first link.
  if marker_line == 0 then
    vim.fn.append(vim.fn.line("$"), { "", "<!-- Links -->", "[1]: " .. url })
    return "1"
  end

  -- Read every line after the marker for efficient scanning.
  local link_lines = vim.fn.getbufline("%", marker_line + 1, "$")
  local max_id = 0
  local url_lower = url:lower()

  for _, line in ipairs(link_lines) do
    local id_str, current_url = line:match(LINK_PATTERN)
    if id_str then
      -- URL already present: reuse its ID (case-insensitive compare).
      if current_url:lower() == url_lower then
        return id_str
      end

      -- Track the highest ID to derive the next one.
      local id = tonumber(id_str) or 0
      if id > max_id then
        max_id = id
      end
    end
  end

  -- URL not found: append it with a fresh ID.
  local new_id = max_id + 1
  vim.fn.append(vim.fn.line("$"), "[" .. new_id .. "]: " .. url)
  return tostring(new_id)
end

---
-- Adds a Markdown reference-style link at the cursor position.
--
-- The URL is taken from the system clipboard (`+` register); if it is not a
-- URL, the user is prompted. When the cursor sits inside `[some text]`, the
-- reference ID is appended -> `[some text][id]`. Otherwise a bare
-- `[id][id]` placeholder is inserted.
function M.add()
  -- Attempt to read a URL from the system clipboard.
  local url = vim.trim(vim.fn.getreg("+"))

  -- Fall back to prompting when the clipboard is not a URL.
  if not url:lower():match("^https?://") then
    url = vim.trim(vim.fn.input("Input URL: "))
    vim.cmd('echo ""') -- clear the command line
    if url == "" then
      return
    end
  end

  local linkid = M.get_id(url)

  -- Detect surrounding `[...]` text via the existing Vimscript helper.
  local title = vim.fn["utils#GetContentBetween"]("[", "]")

  if title == "" then
    -- No enclosing text: insert a `[id][id]` placeholder at the cursor.
    local link_text = string.format("[%s][%s]", linkid, linkid)
    vim.api.nvim_put({ link_text }, "c", true, true)
  else
    -- Text like `[some text]` exists: append the ID after the closing bracket.
    if vim.fn.search("]", "W") ~= 0 then
      vim.cmd("normal! a[" .. linkid .. "]")
    end
  end
end

return M
