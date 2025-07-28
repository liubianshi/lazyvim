---@diagnostic disable: missing-fields

-- lua/ref_link.lua - A plugin to create reference-style links in Markdown.

local M = {}

-- The next available reference link ID.
local next_id = 1

---
-- Finds the last non-blank line in the current buffer.
-- This is much faster than iterating through lines in Lua as it uses
-- Vim's built-in search functionality.
--
-- @return number The line number of the last non-blank line, or 0 if the buffer is empty.
--
local function find_last_non_blank_line()
  -- Search backwards ('b') for any non-whitespace character ('\S')
  -- without moving the cursor ('n') or wrapping around the file ('W').
  return vim.fn.search('\\S', 'bnW')
end

---
-- Scans the buffer to find the highest existing reference ID and sets the next ID accordingly.
-- NOTE: This reads the entire buffer into memory, which may be slow for very large files.
--
function M.initialize_id()
  local highest_id = 0
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for _, line in ipairs(lines) do
    -- Match patterns like [^1]: http://... or [1]: http://...
    for id_str in line:gmatch('^%[%^?(%d+)%]:') do
      local id = tonumber(id_str)
      if id and id > highest_id then
        highest_id = id
      end
    end
  end
  next_id = highest_id + 1
end

---
-- Creates and inserts a Markdown reference-style link.
-- Appends the link definition to the end of the file and inserts the reference at the cursor.
--
-- @param url string The URL for the reference.
--
function M.create_reference_link(url)
  if not url or url == '' then
    vim.notify("URL cannot be empty.", vim.log.levels.WARN)
    return
  end

  local id = next_id
  local link_def = string.format('[^%d]: %s', id, url)
  local link_ref = string.format('[^%d]', id)

  local last_line = find_last_non_blank_line()

  if last_line > 0 then
    -- Buffer has content, append the definition after the last non-blank line,
    -- preceded by a blank line for separation.
    vim.api.nvim_buf_set_lines(0, last_line, last_line, false, { '', link_def })
  else
    -- Buffer is empty or contains only whitespace, just add the definition at the start.
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { link_def })
  end

  -- Insert the link reference text at the cursor position.
  vim.api.nvim_put({ link_ref }, 'c', true, true)

  next_id = next_id + 1
end

---
-- Prompts the user for a URL and then creates the reference link.
-- This function initializes the ID counter before prompting.
--
function M.prompt_and_create_link()
  M.initialize_id()
  vim.ui.input({ prompt = 'URL: ' }, function(url)
    -- Check if user provided a URL (i.e., didn't cancel the prompt)
    if url then
      M.create_reference_link(url)
    end
  end)
end

---
-- Sets up the plugin commands and keymaps.
--
function M.setup()
  -- Create a :RefLink user command that takes a URL as an argument.
  vim.api.nvim_create_user_command('RefLink', function(opts)
    M.initialize_id()
    M.create_reference_link(opts.args)
  end, { nargs = 1, desc = 'Create a Markdown reference link from a URL' })

  -- Create a normal mode keymap to trigger the URL prompt.
  vim.keymap.set('n', '<leader>rl', M.prompt_and_create_link, {
    noremap = true,
    silent = true,
    desc = 'Create a Markdown reference link (prompts for URL)',
  })
end

return M
