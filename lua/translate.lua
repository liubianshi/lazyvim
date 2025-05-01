-- Default configuration options for the module.
local default_opts = {
  ns_name = "LBS_Translate", -- Namespace name used for extmarks.
  hl_group = "Comment", -- Highlight group applied to virtual text/lines.
}

-- Initializes the module's state and configuration.
-- Merges user-provided options with defaults and sets up necessary Neovim components.
--
---@param opts table|nil User-provided options to override the default settings.
---@return table The initialized module state, including merged options, extmark utility instance, and namespace ID.
local function init(opts)
  -- Merge user options with defaults. User options take precedence ("keep" strategy).
  -- If no user options are provided, use an empty table.
  local resolved_opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)

  -- Obtain or create the Neovim namespace for managing extmarks specific to this module.
  -- This function is idempotent: it returns the existing ID if the namespace already exists.
  local ns_id = vim.api.nvim_create_namespace(resolved_opts.ns_name)

  -- Instantiate the extmark utility helper with the determined namespace name.
  local extmark_util = require("util.extmark").new(resolved_opts.ns_name)

  -- Return the module's state table, containing configuration and utilities.
  return {
    opts = resolved_opts, -- Store the final, merged options.
    extmark = extmark_util, -- Store the initialized extmark utility instance.
    ns_id = ns_id, -- Store the namespace ID for later use.
  }
end

--- Prepends the indentation of a specific line to each line in a given table of strings.
---
--- This function retrieves the indentation level (number of leading spaces) from a
--- specified line number in the current buffer. It then prepends this amount of
--- whitespace to every string within the provided table (representing a paragraph).
--- If the specified line has no indentation or the input table is empty, the
--- original table is returned unchanged.
---
--- @param linenr number The 1-based line number in the current buffer to fetch the indentation from.
--- @param para table|nil A table where each element is a string representing a line of text. Defaults to an empty table if nil.
--- @return table A new table with each line prepended with the calculated indentation, or the original `para` table if no indentation is needed or `para` is empty.
local function indent_para(linenr, para)
  -- Ensure 'para' is a table; default to an empty table if it's nil.
  para = para or {}

  -- Retrieve the indentation level (number of spaces) of the target line.
  -- vim.fn.indent() returns the number of leading spaces.
  local indent_level = vim.fn.indent(linenr)

  -- Optimization: Return early if there's no indentation to add
  -- or if the input paragraph table is empty.
  if indent_level == 0 or #para == 0 then
    return para
  end

  -- Pre-calculate the indentation string (repeated spaces) for efficiency.
  -- Avoids recalculating string.rep inside the loop/map.
  local indent_str = string.rep(" ", indent_level)

  -- Apply the indentation string to the beginning of each line in the paragraph.
  -- vim.tbl_map creates a new table by applying the function to each element of 'para'.
  return vim.tbl_map(function(line)
    -- Concatenate the indentation string with the original line content.
    return indent_str .. line
  end, para)
end

local M = init()

--- Sets an extmark with inline virtual text in a buffer.
--- Merges provided options with defaults (`virt_text_pos = "inline"`,
--- `virt_text_repeat_linebreak = true`, `hl_mode = "combine"`) using
--- `vim.tbl_deep_extend("keep", ...)`, meaning existing keys in `opts` are preserved.
--- The `virt_text` option is always constructed and overwrites any provided value.
---
---@param buf integer Buffer handle (0 for current buffer).
---@param row integer 0-based line index for the mark.
---@param col integer 0-based column index for the mark.
---@param text string The virtual text content to display (wrapped in '[]').
---@param opts? table Additional options for `nvim_buf_set_extmark`. See `:h nvim_buf_set_extmark()`.
local function set_text_extmark(buf, row, col, text, opts)
  -- Ensure opts is a table if nil was passed.
  opts = opts or {}

  -- Define default settings for the extmark appearance and behavior.
  local default = {
    virt_text_pos = "inline",
    virt_text_repeat_linebreak = true,
    hl_mode = "combine",
  }

  local merged_opts = vim.tbl_deep_extend("keep", opts, default)

  -- Format the virtual text chunk with the specified highlight group.
  -- This structure is required by the API: { { text_chunk, hl_group }, ... }
  -- Assumes M.opts.hl_group is defined in the surrounding module scope.
  merged_opts.virt_text = { { string.format("[%s]", text), M.opts.hl_group } }

  -- Place the extmark using the Neovim API.
  -- Assumes M.ns_id (namespace ID) is defined in the surrounding module scope.
  vim.api.nvim_buf_set_extmark(buf, M.ns_id, row, col, merged_opts)
end

---@param buf integer buffer number, 0 for current buffer
---@param row integer Line where to place the mark, 0-based
---@param lines string[] virtual lines to add
---@param opts? vim.api.keyset.set_extmark
local function set_line_extmark(buf, row, lines, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    virt_lines_leftcol = false,
  })
  opts.virt_lines = vim.tbl_map(function(line)
    return { { line, M.opts.hl_group } }
  end, lines)
  vim.api.nvim_buf_set_extmark(buf, M.ns_id, row, 0, opts)
end

---@param content string
---@param callback function
function M.translate_phrase(content, callback)
  if not content or #content == 0 then
    return
  end
  local cmd = { "deepl", content }
  vim.system(cmd, { text = true }, function(obj)
    if obj.code ~= 0 then
      vim.notify("Failed to translate " .. content .. "\n" .. obj.stderr, "error")
      return
    end
    local result = vim.split(vim.trim(obj.stdout), "\n")[2]
    vim.schedule(function()
      callback(result)
    end)
  end)
end

---@param content string[] Content to be translated
---@param opts {textwidth: integer, indent: integer, callback: fun(lines: string[])}
---@return string[]|nil
function M.translate_paragraph(content, opts)
  if not content or #content == 0 then
    return
  end

  local cmd = { "fabric-ai", "--pattern", "translate", "-m=gemini-2.5-flash-preview-04-17-nothink", "--stream" }

  local head_chars = vim.trim(content[1]):sub(1, 20)
  local is_cjk = false
  for _, char in ipairs(vim.fn.split(head_chars, "\\zs")) do
    if is_cjk_character(char) then
      is_cjk = true
      break
    end
  end
  if is_cjk then
    table.insert(cmd, "-v=lang_code:en_US")
  else
    table.insert(cmd, "-v=lang_code:zh_CN")
  end

  local ok, progress = pcall(require, "fidget.progress")
  local progress_handle
  if ok then
    progress_handle = progress.handle.create({
      title = " Requesting Fabric (Translate)",
      message = "In progress...",
      lsp_client = {
        name = "Fabric",
      },
    })
  end

  vim.system(cmd, { stdin = content }, function(obj_trans)
    if progress_handle then
      if obj_trans.code ~= 0 then
        progress_handle.message = " Faild to translate with fabric"
        progress_handle:finish()
      else
        progress_handle.message = "Translate Complete"
        progress_handle.message = "Starting formatting..."
      end
    end

    vim.system(
      { "mdwrap", "--line-width=" .. (opts.textwidth - opts.indent) },
      { stdin = vim.split(obj_trans.stdout, "\n") },
      function(obj_format)
        if progress_handle then
          progress_handle.message = obj_format.code == 0 and "Completed" or " Failed to formatting"
          progress_handle:finish()
        end
        local translated_lines = vim.split(vim.trim(obj_format.stdout), "\n")
        vim.schedule(function()
          opts.callback(translated_lines)
        end)
      end
    )
  end)
end

---@param buf? integer buf number
---@param line? integer line number (1-based)
function M.translate_line(buf, line)
  buf = buf or vim.api.nvim_get_current_buf()
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  -- Get the content of the line. Note: API uses 0-based indexing.
  local content_lines = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)
  if not content_lines or #content_lines == 0 then
    vim.notify("Error: Could not get content for line " .. line .. " in buffer " .. buf, vim.log.levels.ERROR)
    return -- Return early if content is empty/invalid
  end
  local content = content_lines[1] -- We requested exactly one line

  -- Get the indentation of the line in the target buffer
  local indent_num = vim.api.nvim_buf_call(buf, function()
    local indent_num = 0
    if line > 0 and line <= vim.api.nvim_buf_line_count(0) then -- Use 0 for current buffer in this context
      indent_num = math.max(vim.fn.indent(line), 0)
    end
    return indent_num
  end)

  -- Determine the target text width
  local textwidth = vim.bo[buf].textwidth
  if not textwidth or textwidth <= 0 then
    -- Calculate width based on content, ensuring content is not nil
    local display_width = math.max(vim.fn.strdisplaywidth(content or ""), 0)
    textwidth = math.min(display_width, 78) -- Fallback width capped at 78
  end

  -- Call the translate_paragraph function with the single line content (as a table)
  M.translate_paragraph({ content }, {
    textwidth = textwidth,
    indent = indent_num, -- Guaranteed non-negative now
    callback = function(translated_lines)
      if not translated_lines or #translated_lines == 0 then
        return -- Nothing to display
      end
      -- Map the translated lines, adding indentation and trimming whitespace
      local prepared_lines = vim.tbl_map(function(l)
        -- Ensure l is a string before trimming
        local trimmed_line = vim.trim(l or "")
        return string.rep(" ", indent_num) .. trimmed_line
      end, translated_lines)

      -- Set the extmark only if there are prepared lines
      if #prepared_lines > 0 then
        -- Add extmark relative to the original line (0-based index)
        set_line_extmark(buf, line - 1, prepared_lines)
      end
    end,
  })
end

function M.translate_selection()
  local winid = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(winid)
  local visual_coordiate = require("util").get_visual_coordinate()
  local content = require("util").get_visual_selection()
  local mode = vim.api.nvim_get_mode()
  if not visual_coordiate or not content or #content == 0 then
    return
  end
  local srow, _, erow, ecol = unpack(visual_coordiate)

  if mode == "v" then
    M.translate_phrase(content[1], function(text)
      set_text_extmark(buf, erow - 1, ecol, text)
    end)
  else
    local grouped_content, paragraph_range = require("util").join_strings_by_paragraph(content)
    table.insert(grouped_content, "")

    --  Where the paragraph ends
    local paragraph_end = vim.tbl_map(function(range)
      return range.finish + srow - 1
    end, paragraph_range or {})

    -- Line width of the translated line
    local textwidth = vim.bo[buf].textwidth
    if not textwidth or textwidth == 0 then
      textwidth = math.min(
        math.min(unpack(vim.tbl_map(function(l)
          return vim.fn.strdisplaywidth(l)
        end, content))),
        78
      )
    end

    -- Number of indented characters for the translated line
    local indent_num = vim.api.nvim_buf_call(buf, function()
      return vim.fn.indent(paragraph_end[#paragraph_end])
    end)

    -- Perform paragraph translation and insert the translated line into the
    -- buffer where the original text is located in the form of extmark
    M.translate_paragraph(grouped_content, {
      textwidth = textwidth,
      indent = indent_num or 0,
      callback = function(lines)
        local para = {}
        local para_id = 1
        for _, line in ipairs(lines) do
          local trimmed_line = vim.trim(line or "")
          if #trimmed_line > 0 then
            table.insert(para, trimmed_line)
          else
            set_line_extmark(buf, paragraph_end[para_id] - 1, indent_para(paragraph_end[para_id], para))
            para_id = para_id + 1
            para = {}
          end
        end
        if #para > 0 then
          set_line_extmark(buf, paragraph_end[para_id] - 1, indent_para(paragraph_end[para_id], para))
        end
      end,
    })
  end
end

function M.trans_op(type)
  local commands = {
    line = "'[V']",
    char = "`[v`]",
    block = "`[\\<C-V>`]",
  }
  if not type or #type == 0 then
    vim.opt.opfunc = "v:lua.require'translate'.trans_op"
    vim.api.nvim_feedkeys("g@", "m", false)
  else
    vim.cmd.normal(commands[type])
    M.run()
  end
end

function M.toggle()
  return M.extmark:toggle_extmarks()
end

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
	local pat_numbered       = [==[\v^(\d+\.)\s+(\([^)]+\))\s+(.*)]==] -- Numbered definition item (e.g., "1. ")
	local pat_header         = [==[\v^\s*(\w+%(\s\w+)*)\s*(\[[^\]]*\])?\s*$]==] -- Header line: Captures the word and optional phonetic transcription
	local pat_stars_level    = [==[\v^(⭐+\s+)?([A-Z0-9+]+%(\s[A-Z0-9+]+)*)\s*$]==] -- Stars/Levels line: Captures optional star ratings and level codes (e.g., "CET4", "GRE")
  -- stylua: ignore end

  -- 4. Process the 'kd' output line by line
  local output_lines = { "<!-- start_anki word -->" } -- Stores the formatted lines for the buffer
  local extmark_positions = {} -- Stores positions for highlighting parts of speech
  local word = nil -- Stores the main word being defined
  local phonetic = nil -- Stores the phonetic transcription, if found
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
          table.insert(output_lines, phonetic)
          table.insert(output_lines, "") -- Add spacing
        end
      end
      goto continue
    end

    -- State: Header found, processing definition details
    -- Check for separator line
    if #match(trimmed_line, pat_sep) > 0 then
      -- Ignore separator lines (could optionally add "---")
      goto continue
    end

    -- Check for stars/level line (process before word nature)
    -- Ensure consistent star emoji (replace legacy ★ if needed)
    local match_star = match(trimmed_line:gsub("★", "⭐"), pat_stars_level)
    if #match_star > 0 then
      trimmed_line = trimmed_line:gsub("★", "⭐")
      table.insert(output_lines, "") -- Add spacing before levels
      table.insert(output_lines, trimmed_line)

      local line_idx = #output_lines - 1
      table.insert(
        extmark_positions,
        { line = line_idx, start_col = 0, end_col = #trimmed_line, hl_group = "SnacksPickerPrompt" }
      )
      table.insert(output_lines, "") -- Add spacing after levels
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
      local example_text = match_symbol_example[2]
      -- Format as an indented list item
      table.insert(output_lines, "    - " .. example_text)
      goto continue
    end

    -- Check for numbered definition line
    local match_numbered = match(trimmed_line, pat_numbered)
    if #match_numbered > 0 then
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

  -- Clear any previous extmarks from this namespace in the target buffer
  vim.api.nvim_buf_clear_namespace(target_bufnr, ns_id, 0, -1)

  -- Apply new extmarks based on the calculated positions
  for _, extmark in ipairs(extmark_positions) do
    -- Check if the line index is still valid within the buffer boundaries
    if extmark.line < vim.api.nvim_buf_line_count(target_bufnr) then
      vim.api.nvim_buf_set_extmark(target_bufnr, ns_id, extmark.line, extmark.start_col, {
        end_col = extmark.end_col,
        hl_group = extmark.hl_group,
      })
    else
      -- Warn if a calculated position is outside the final buffer content
      vim.notify(("Warning: Line index %d for highlighting is out of bounds"):format(extmark.line), vim.log.levels.WARN)
    end
  end

  -- Notify the user of successful completion
  vim.notify(("Parsed '%s' output into buffer %d"):format(table.concat(cmd, " "), target_bufnr), vim.log.levels.INFO)

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

  local win_height = 15
  local win_width = 70

  -- Get current window height and cursor position (1-based)
  local nvim_height = vim.api.nvim_win_get_height(0)
  local current_row = vim.fn.winline()
  local current_col = vim.fn.wincol()

  -- Adjust window row position to prevent going off-screen at the bottom.
  -- If the window would extend beyond the Neovim screen height,
  -- position it above the current line instead.
  if nvim_height - current_row < win_height then
    -- Position window above the cursor line
    current_row = current_row - win_height - 1
    -- Ensure the row is at least 1 (top of the screen)
    if current_row < 1 then
      current_row = 1
    end
  end

  -- Create the floating window using the snacks.win library
  local win = require("snacks.win").new({
    border = "rounded",
    backdrop = false, -- No backdrop behind the window
    relative = "win", -- Position relative to the editor grid
    row = current_row, -- Calculated window row
    col = current_col, -- Window column (aligned with cursor)
    width = win_width, -- Window width
    height = win_height, -- Window height
    bo = { -- Buffer options for the floating window
      -- filetype = "markdown", -- Set syntax highlighting to markdown
      buftype = "nofile", -- Buffer is not related to a file
      swapfile = false, -- Disable swap file for this temporary buffer
    },
    wo = { -- Window options for the floating window
      signcolumn = "yes:1", -- Show sign column (adjust width if needed, e.g., "yes:2")
      wrap = true, -- Enable line wrapping
      linebreak = true, -- Break lines at word boundaries without inserting characters
      -- Optional: Conceal markdown syntax for a cleaner appearance
      -- conceallevel = 2,
      -- concealcursor = "nv", -- Reveal concealed text under cursor in normal/visual modes
    },
  })

  local kd_buf = M.parse_kd_output(word, win.buf)
  if not kd_buf then
    return
  end

  local translation_lines = win:lines()
  if #translation_lines < 3 then
    return nil, nil
  end
  -- Display the created floating window
  win:show()

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
      else
        -- Optional: Notify user on successful write operation
        vim.notify("Appended translation to " .. output_file_path, vim.log.levels.INFO)
      end
    end
  end

  -- Return the table of translation lines and the window object
  return translation_lines, win
end

return M
