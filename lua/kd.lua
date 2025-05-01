local M = {}

local function trim(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

--- Parses the output of the 'kd' command and formats it into a target buffer.
--
-- This function executes the 'kd' command with specified arguments, parses the output
-- line by line according to predefined patterns for word definitions, phonetic transcriptions,
-- parts of speech, examples, etc., formats the output as Markdown, and writes it to a
-- target buffer. It also applies syntax highlighting to parts of speech (e.g., "n.", "v.").
--
---@param kd_args string A sequence table of string arguments to pass to the 'kd' command.
---@param target_bufnr? (integer) The buffer number where the formatted output should be written.
---@return integer|nil The buffer number
function M.parse_kd_output(kd_args, target_bufnr)
  -- 1. Ensure a target buffer exists
  if target_bufnr == nil then
    -- Create a new buffer if none was provided
    target_bufnr = vim.api.nvim_create_buf(false, false)
  end

  -- 2. Construct and run the 'kd' command
  -- Build the command array, starting with "kd"
  local cmd = vim.split("kd " .. kd_args, "%s+")

  -- Execute the command synchronously, capturing output
  -- Wait up to 100 milliseconds for the command to complete
  local result = vim.system(cmd, { text = true }):wait(100)

  -- Handle command execution errors
  if not result or result.code ~= 0 then
    local error_msg = ("Error running %s (code %d): %s"):format(
      table.concat(cmd, " "), -- Original arguments for the message
      result.code or -1, -- Exit code
      result.stderr or result.stdout or "Unknown error" -- Error output or stdout if stderr is empty
    )
    vim.notify(error_msg, vim.log.levels.ERROR)
    return
  end

  -- Store the successful command output
  local kd_output = result.stdout or ""
  if kd_output == "" or kd_output:match("^Not found") then
    return
  end

	-- 3. Define Lua patterns for parsing the 'kd' output
	-- These patterns identify different parts of the dictionary entry.
  -- stylua: ignore start
	local pat_symbol_example = [==[\v^\s*≫\s*(.*)]==]
	local pat_word_nature    = [==[\v^([A-Za-z][^\s]*\.)\s+(.*)]==] -- Part of speech (e.g., "n.", "v.") followed by definition
	local pat_sep            = [==[\v^\s*[—⸺]+\s*$]==] -- Separator line (em-dash or double em-dash)
	local pat_numbered       = [==[\v^(\d+\.)\s+([(\[][^)]+[)\]])\s+(.*)]==] -- Numbered definition item (e.g., "1. ")
	local pat_header         = [==[\v^\s*(\w+%(\s\w+)*)\s*(\[[^\]]*\])?\s*$]==] -- Header line: Captures the word and optional phonetic transcription
	local pat_stars_level    = [==[\v^(⭐+\s+)?([A-Z0-9+]+%(\s[A-Z0-9+]+)*)\s*$]==] -- Stars/Levels line: Captures optional star ratings and level codes (e.g., "CET4", "GRE")
  -- stylua: ignore end

  -- 4. Process the 'kd' output line by line
  local output_lines = { "<!-- start_anki word -->" } -- Stores the formatted lines for the buffer
  local extmark_positions = {} -- Stores positions for highlighting parts of speech
  local word = nil -- Stores the main word being defined
  local phonetic = nil -- Stores the phonetic transcription, if found
  local other_definitions = false
  local match = vim.fn.matchlist

  -- Iterate through each line of the kd command's output
  for _, line in ipairs(vim.split(kd_output or "", "\n", {})) do
    local trimmed_line = trim(line)

    -- Skip processing completely empty lines
    if #trimmed_line == 0 then
      goto continue
    end

    -- State: Haven't found the header (word and phonetics) yet
    if not word then
      local match_header = match(trimmed_line, pat_header)
      if match_header and #match_header > 0 then -- Found the header line
        word = match_header[2] -- Store the trimmed word (already trimmed by pattern)
        phonetic = match_header[3] -- Store the trimmed phonetic transcription

        -- Add Markdown header for the word
        table.insert(output_lines, "## " .. word)
        table.insert(output_lines, "") -- Add spacing

        -- Add phonetic transcription if present
        if phonetic and phonetic ~= "" then
          table.insert(output_lines, "- " .. phonetic)
          table.insert(output_lines, "")
        end
      end
      goto continue
    end

    -- State: Header found, processing definition details
    -- Check for separator line
    if #match(trimmed_line, pat_sep) > 0 then
      -- Ignore separator lines (could optionally add "---")
      table.insert(output_lines, "------") -- Add spacing
      goto continue
    end

    -- Check for stars/level line (process before word nature)
    -- Ensure consistent star emoji (replace legacy ★ if needed)
    local match_star = match(trimmed_line:gsub("★", "⭐"), pat_stars_level)
    if #match_star > 0 then
      trimmed_line = "- " .. trimmed_line:gsub("★", "⭐")
      table.insert(output_lines, "") -- Add spacing before levels
      table.insert(output_lines, trimmed_line)

      local line_idx = #output_lines - 1
      table.insert(
        extmark_positions,
        { line = line_idx, start_col = 0, end_col = #trimmed_line, hl_group = "SnacksPickerPrompt" }
      )
      goto continue
    end

    local match_word_nature = match(trimmed_line, pat_word_nature)
    if #match_word_nature > 0 then
      local nature = match_word_nature[2]
      local remainder = match_word_nature[3]

      -- Format as a list item with bold nature
      local formatted_line = "- **" .. nature .. "** " .. remainder
      table.insert(output_lines, formatted_line)
      -- Calculate position for extmark highlighting (0-based line index, byte-based columns)
      local line_idx = #output_lines - 1
      local start_col = #"- **" -- Start column after markdown formatting
      local end_col = start_col + #nature -- End column after the nature text
      table.insert(extmark_positions, {
        line = line_idx,
        start_col = start_col,
        end_col = end_col,
        hl_group = "SnacksPickerSpecial",
      })
      goto continue
    end

    -- Check for example line
    local match_symbol_example = match(trimmed_line, pat_symbol_example)
    if #match_symbol_example > 0 then
      local example_text = (other_definitions and "  - " or "- ") .. match_symbol_example[2]
      table.insert(output_lines, example_text)
      -- Format as an indented list item
      local offset = 1
      local line_idx = #output_lines - 1
      while true do
        local match_re = vim.fn.matchstrpos(example_text, "\\c" .. word, offset)
        if match_re[1] == "" or match_re[2] == -1 or match_re[3] == -1 then
          break
        end
        offset = (match_re[3] > offset) and match_re[3] or offset + 1

        table.insert(
          extmark_positions,
          { line = line_idx, start_col = match_re[2], end_col = match_re[3], hl_group = "SnacksPickerSelected" }
        )
      end
      goto continue
    end

    -- Check for numbered definition line
    local match_numbered = match(trimmed_line, pat_numbered)
    if #match_numbered > 0 then
      other_definitions = true
      -- Add numbered lines directly (they are already formatted)
      local number = match_numbered[2]
      local nature = match_numbered[3]
      local remainder = match_numbered[4]
      table.insert(output_lines, string.format("%s %s %s", number, nature, remainder)) -- Use original line to preserve indentation

      local line_idx = #output_lines - 1
      local number_start = 0
      local nubmer_end = #number
      table.insert(
        extmark_positions,
        { line = line_idx, start_col = number_start, end_col = nubmer_end, hl_group = "SnacksPickerIdx" }
      )

      local nature_start = nubmer_end + 1
      local nature_end = nature_start + #nature
      table.insert(
        extmark_positions,
        { line = line_idx, start_col = nature_start, end_col = nature_end, hl_group = "SnacksPickerLabel" }
      )

      local remainder_start = nature_end + 1
      local remainder_end = remainder_start + #remainder
      table.insert(
        extmark_positions,
        { line = line_idx, start_col = remainder_start, end_col = remainder_end, hl_group = "SnacksPickerRow" }
      )
      goto continue
    end

    -- Format as a standard list item
    table.insert(output_lines, "- " .. trimmed_line)

    ::continue:: -- Label for skipping line processing via goto
  end

  table.insert(output_lines, "<!-- end_anki -->")
  -- 5. Update the target buffer content
  -- Make the buffer modifiable, set the content, and filetype
  vim.api.nvim_set_option_value("modifiable", true, { buf = target_bufnr })
  -- Replace entire buffer content efficiently
  vim.api.nvim_buf_set_lines(target_bufnr, 0, -1, false, output_lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = target_bufnr })
  -- Reset modified status and make buffer non-modifiable again
  vim.api.nvim_set_option_value("modified", false, { buf = target_bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = target_bufnr })

  -- 6. Apply syntax highlighting using extmarks for 'nature' (part of speech)
  local ns = "kd_parser_nature_highlight" -- Unique namespace for these extmarks
  local ns_id = vim.api.nvim_create_namespace(ns)
  local buf_line_numbers = vim.api.nvim_buf_line_count(target_bufnr)

  -- Clear any previous extmarks from this namespace in the target buffer
  vim.api.nvim_buf_clear_namespace(target_bufnr, ns_id, 0, -1)
  vim.api.nvim_buf_set_extmark(target_bufnr, ns_id, 0, 0, { conceal_lines = "" })
  vim.api.nvim_buf_set_extmark(target_bufnr, ns_id, buf_line_numbers - 1, 0, { conceal_lines = "" })

  -- Apply new extmarks based on the calculated positions
  for _, extmark in ipairs(extmark_positions) do
    -- Check if the line index is still valid within the buffer boundaries
    if extmark.line < buf_line_numbers then
      vim.api.nvim_buf_set_extmark(target_bufnr, ns_id, extmark.line, extmark.start_col, {
        end_col = extmark.end_col,
        hl_group = extmark.hl_group,
      })
    else
      -- Warn if a calculated position is outside the final buffer content
      vim.notify(("Warning: Line index %d for highlighting is out of bounds"):format(extmark.line), vim.log.levels.WARN)
    end
  end

  return target_bufnr
end

--- Translates a word using an external command and displays it in a floating window.
---
--- Optionally appends the translation result to a specified file.
---
--- @param word string? The word to translate. Defaults to the word under the cursor.
--- @param output_file_path string? The path to a file where the translation result should be appended.
--- @return string[]|nil, table|nil Returns a table of lines containing the translation result
---                                 and the window object if successful, otherwise nil, nil.
function M.translate_word(word, output_file_path)
  -- Default to the word under the cursor if not provided
  word = word or vim.fn.expand("<cword>")
  if not word or word == "" then
    vim.notify("No word specified or found under cursor.", vim.log.levels.WARN)
    return nil, nil
  end

  local kd_buf = M.parse_kd_output(word)
  if not kd_buf then
    return
  end

  local border = "rounded"
  local win_height = math.min(vim.api.nvim_buf_line_count(kd_buf) + (border == "none" and 0 or 1), 15)
  local win_width = 70

  -- Get current window height and cursor position (1-based)
  local nvim_height = vim.api.nvim_win_get_height(0)
  local current_row = vim.fn.winline()
  local current_col = vim.fn.wincol() - 1

  -- Adjust window row position to prevent going off-screen at the bottom.
  -- If the window would extend beyond the Neovim screen height,
  -- position it above the current line instead.
  if nvim_height - current_row < win_height then
    -- Position window above the cursor line
    current_row = current_row - win_height - (border == "none" and 1 or 3)
    -- Ensure the row is at least 1 (top of the screen)
    if current_row < 1 then
      current_row = 1
    end
  end

  -- Create the floating window using the snacks.win library
  local win = require("snacks.win").new({
    border = border,
    backdrop = false, -- No backdrop behind the window
    relative = "win", -- Position relative to the editor grid
    row = current_row, -- Calculated window row
    col = current_col, -- Window column (aligned with cursor)
    width = win_width, -- Window width
    height = win_height, -- Window height
    buf = kd_buf,
    bo = { -- Buffer options for the floating window
      filetype = "markdown", -- Set syntax highlighting to markdown
      buftype = "nofile", -- Buffer is not related to a file
      swapfile = false, -- Disable swap file for this temporary buffer
    },
    wo = { -- Window options for the floating window
      signcolumn = "yes:1", -- Show sign column (adjust width if needed, e.g., "yes:2")
      wrap = true, -- Enable line wrapping
      linebreak = true, -- Break lines at word boundaries without inserting characters
      breakindent = true,
    },
  })

  local translation_lines = win:lines()
  if #translation_lines < 3 then
    return nil, nil
  end
  -- Display the created floating window
  win:show()
  vim.api.nvim_win_set_cursor(win.win, { 2, 0 })

  -- Append the result to the specified output file if a path is provided
  if output_file_path then
    local can_write = false
    -- Check if the target file exists
    local stat = vim.uv.fs_stat(output_file_path)

    if stat then -- File exists, check if it's writable
      if vim.uv.fs_access(output_file_path, "W") then
        can_write = true
      else
        vim.notify("Output file exists but is not writable: " .. output_file_path, vim.log.levels.ERROR)
      end
    else -- File does not exist, check if the parent directory is writable
      local dir = vim.fn.fnamemodify(output_file_path, ":h")
      -- Handle case where the path is just a filename in the current directory
      if dir == "" then
        dir = "."
      end
      if vim.uv.fs_access(dir, "W") then
        can_write = true -- Directory is writable, so the file can be created
      else
        vim.notify("Cannot write to directory for output file: " .. dir, vim.log.levels.ERROR)
      end
    end

    -- Proceed with writing only if determined possible
    if can_write then
      -- Append the translation lines to the file (creates the file if it doesn't exist)
      -- vim.fn.writefile returns 0 on success, -1 on failure
      local success_code = vim.fn.writefile(translation_lines, output_file_path, "a")
      if success_code ~= 0 then
        vim.notify("Failed to write to output file: " .. output_file_path, vim.log.levels.ERROR)
      end
    end
  end

  -- Return the table of translation lines and the window object
  return translation_lines, win
end

return M
