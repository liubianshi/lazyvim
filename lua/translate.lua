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
---@param opts {textwidth?: integer, indent?: integer, wrap?: boolean, callback: fun(lines: string[])}
---@return nil
function M.translate_paragraph(content, opts)
  if not content or #content == 0 then
    return
  end

  local cmd = {
    "fabric-ai",
    "--pattern",
    "translate",
    "-m=gpt-4.1-mini",
    "--stream",
  }

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

  opts = vim.tbl_extend("keep", opts, { wrap = true, textwidth = 80, indent = 0 })

  vim.system(cmd, { stdin = content }, function(obj_trans)
    if progress_handle then
      if obj_trans.code ~= 0 then
        progress_handle.message = " Faild to translate with fabric"
        progress_handle:finish()
      else
        progress_handle.message = "Translate Complete"
      end
    end

    if opts.wrap then
      if progress_handle then
        progress_handle.message = "Starting formatting..."
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
    else
      if progress_handle then
        progress_handle:finish()
      end
      local translated_lines = vim.split(vim.trim(obj_trans.stdout), "\n")
      vim.schedule(function()
        opts.callback(translated_lines)
      end)
    end
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

function M.translate_content(content, callback)
  content = content or require("util").get_visual_selection()
  if type(content) == "string" then
    if content:find("%S") then
      content = { content }
    end
  end
  if not content or #content == 0 then
    return
  end

  if callback then
    M.translate_paragraph(content, { wrap = false, callback = callback })
    return
  end

  local save_path = require("util").get_daily_filepath("md", "ReciteWords")
  if #content == 1 and #vim.split(content[1], "%s+") <= 3 then
    require("kd").translate_word(content[1], save_path)
  else
    M.translate_sentence(content, save_path)
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
    M.translate_content()
  end
end

function M.toggle()
  return M.extmark:toggle_extmarks()
end

--- Saves or appends translated content to a specified file.
---
--- Checks for file/directory writability before attempting to write.
--- Notifies the user of success or failure.
---
--- @param output_file_path string The path to the output file.
--- @param content string|string[] The content to write to the file.
--- @param append boolean If true, content will be appended; otherwise, the file will be overwritten.
local function save_translate_output(output_file_path, content, append)
  -- Determine the file open mode: "a" for append, "w" for write (overwrite)
  local flag = append and "a" or "w"
  local can_write = false -- Flag to track if writing to the file is permissible

  -- Check if the target file exists using libuv's stat function
  local stat = vim.uv.fs_stat(output_file_path)

  if stat then -- File exists
    -- Check if the existing file is writable
    if vim.uv.fs_access(output_file_path, "W") then
      can_write = true
    else
      vim.notify("Output file exists but is not writable: " .. output_file_path, vim.log.levels.ERROR)
    end
  else -- File does not exist
    -- Get the parent directory of the intended output file
    local dir = vim.fn.fnamemodify(output_file_path, ":h")
    -- Handle case where output_file_path is just a filename (implies current directory)
    if dir == "" then
      dir = "." -- Use "." to represent the current directory
    end
    -- Check if the parent directory is writable (so a new file can be created)
    if vim.uv.fs_access(dir, "W") then
      can_write = true -- Directory is writable, so the file can be created
    else
      vim.notify("Cannot write to directory for output file: " .. dir, vim.log.levels.ERROR)
    end
  end

  -- Proceed with writing only if determined possible
  if can_write then
    -- Write or append the content to the file
    -- vim.fn.writefile returns 0 on success, -1 on failure
    local success_code = vim.fn.writefile(content, output_file_path, flag)
    if success_code ~= 0 then
      vim.notify("Failed to write to output file: " .. output_file_path, vim.log.levels.ERROR)
    else
      -- Optional: Notify user on successful write operation
      local action = append and "Appended" or "Wrote"
      vim.notify(action .. " translation to " .. output_file_path, vim.log.levels.INFO)
    end
  end
end

local function create_float_win(opts)
  opts = vim.tbl_extend("keep", opts or {}, { win_height = 15, win_width = 70 })

  local mode = vim.api.nvim_get_mode().mode
  local current_win_line = vim.fn.winline()
  local current_win_col = vim.fn.wincol()

  local start_line, start_col, end_line, end_col = current_win_line, current_win_col, current_win_line, current_win_col
  if mode == "v" or mode == "V" or mode == "\22" then
    local coord = require("util").get_visual_coordinate()
    if not coord then
      return
    end

    local current_line = vim.fn.line(".")
    local line_offset = current_line - current_win_line
    start_line, end_line = coord[1] - line_offset, coord[3] - line_offset

    local current_col = vim.fn.col(".")
    local col_offset = current_col - current_win_col
    start_col, end_col = coord[2] - col_offset, coord[4] - col_offset
  end

  local current_win_height = vim.api.nvim_win_get_height(0)

  local ln, col
  if current_win_height - end_line < opts.win_height then
    ln = math.max(start_line - opts.win_height - 1, 1)
    col = start_col
  else
    ln, col = end_line, end_col
  end

  -- Create the floating window using the snacks.win library
  local win = require("snacks.win").new({
    border = "rounded",
    backdrop = false, -- No backdrop behind the window
    relative = "win", -- Position relative to the editor grid
    buf = opts.buf,
    row = ln, -- Calculated window row
    col = col, -- Window column (aligned with cursor)
    width = opts.win_width, -- Window width
    height = opts.win_height, -- Window height
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

  return win
end

function M.translate_sentence(content, output_file_path)
  local grouped_content, _ = require("util").join_strings_by_paragraph(content)

  -- Line width of the translated line
  local textwidth = vim.bo.textwidth
  if not textwidth or textwidth == 0 then
    textwidth = math.min(
      math.min(unpack(vim.tbl_map(function(l)
        return vim.fn.strdisplaywidth(l)
      end, content))),
      78
    )
  end

  M.translate_paragraph(grouped_content, {
    textwidth = textwidth,
    indent = 0,
    callback = function(lines)
      if not lines or #lines < 1 then
        return
      end
      local grouped_lines, _ = require("util").join_strings_by_paragraph(lines)

      local output_lines, extmarks = {}, {}
      vim.list_extend(output_lines, { "<!-- start_anki trans -->", "---", "" })
      vim.list_extend(output_lines, grouped_content)
      vim.list_extend(output_lines, { "", ". . .", "" })
      for i = 0, #output_lines - 1 do
        table.insert(extmarks, { line = i, col = 0, opts = { conceal_lines = "" } })
      end
      local start_line = #output_lines + 1
      vim.list_extend(output_lines, grouped_lines)
      vim.list_extend(output_lines, { "<!-- end_anki -->", "" })
      table.insert(extmarks, { line = #output_lines - 2, col = 0, opts = { conceal_lines = "" } })
      table.insert(extmarks, { line = #output_lines - 1, col = 0, opts = { conceal_lines = "" } })

      local win = create_float_win({
        win_height = math.min(15, #lines),
        win_width = math.min(70, math.ceil(0.75 * vim.fn.winwidth(0))),
      })
      if not win or not win.buf then
        return
      end

      vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, output_lines)
      vim.api.nvim_set_option_value("filetype", "markdown", { buf = win.buf })
      -- Reset modified status and make buffer non-modifiable again
      vim.api.nvim_set_option_value("modified", false, { buf = win.buf })
      vim.api.nvim_set_option_value("modifiable", false, { buf = win.buf })

      -- 6. Apply syntax highlighting using extmarks for 'nature' (part of speech)
      local ns = "trans_sentence_highlight" -- Unique namespace for these extmarks
      local ns_id = vim.api.nvim_create_namespace(ns)
      vim.api.nvim_buf_clear_namespace(win.buf, ns_id, 0, -1)
      for _, e in ipairs(extmarks) do
        vim.api.nvim_buf_set_extmark(win.buf, ns_id, e.line, e.col, e.opts)
      end

      -- Display the created floating window
      win:show()
      vim.api.nvim_win_set_cursor(win.win, { start_line, 0 })

      if output_file_path then
        save_translate_output(output_file_path, output_lines, true)
      end
    end,
  })
end

function M.replace_line()
  vim.cmd.stopinsert()
  local winnr = vim.api.nvim_get_current_win()
  local row = vim.api.nvim_win_get_cursor(winnr)[1]
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)

  if not current_line or #current_line == 0 or not current_line[1]:find("%S") then
    return
  end

  local match_s, _, match = current_line[1]:find("%=([^=]+)$")
  local pre_content = match_s and current_line[1]:sub(1, match_s - 1) or current_line[1]:match("^%s+")
  local content = match_s and match or current_line[1]

  if not content:find("%S") then
    return
  end
  content = content:gsub("%s+$", ""):gsub("^%s+", "")

  M.translate_paragraph({ content }, {
    wrap = false,
    callback = function(results)
      if not results or #results == 0 then
        return
      end

      local translated_content = table.concat(results, " ")
      vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { (pre_content or "") .. translated_content })
    end,
  })
end

return M
