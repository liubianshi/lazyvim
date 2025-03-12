local M = {}
local Picker = require("snacks.picker")
local pick = Picker.pick

local function get_folders(path)
  local folders = {}
  local entries = vim.fn.readdir(path)

  for _, entry in ipairs(entries) do
    local full_path = path .. "/" .. entry
    if vim.fn.isdirectory(full_path) == 1 then
      table.insert(folders, entry)
    end
  end

  return folders
end

local function pick_cmd_result(picker_opts)
  local git_root = Snacks.git.get_root()
  local function finder(opts, ctx)
    return require("snacks.picker.source.proc").proc({
      opts,
      {
        cmd = picker_opts.cmd,
        args = picker_opts.args,
        transform = picker_opts.transform or function(item)
          item.file = item.text
        end,
      },
    }, ctx)
  end

  local opts = {
    source = picker_opts.name,
    finder = finder,
    preview = picker_opts.preview,
    title = picker_opts.title,
  }
  if picker_opts.confirm then
    opts.confirm = picker_opts.confirm
  end
  Snacks.picker.pick(opts)
end

M.fabric = function(opts)
  local pattern_dir = os.getenv("HOME") .. "/.config/fabric/patterns"
  local patterns = {}
  local pattern_names = get_folders(pattern_dir)

  local pattern_desc_file = pattern_dir .. "/pattern_explanations.md"
  local file_fh = io.open(pattern_desc_file, "r")
  if not file_fh then
    return nil, "Failed to open file"
  end
  local pattern_desc = {}
  for line in file_fh:lines() do
    if line:match("^%d+") then
      local key = line:match("^%d+%.%s+%*%*([^%*]+)%*%*")
      local value = line:match(":%s*(.+)$")
      if key and value then
        pattern_desc[key] = value
      end
    end
  end
  file_fh:close()

  for _, pattern in ipairs(pattern_names) do
    table.insert(patterns, { text = pattern, cwd = pattern_dir, file = pattern .. "/system.md" })
  end

  pick({
    items = patterns,
    format = function(item, _)
      local ret = {}
      ret[#ret + 1] = { item.text, "SnacksPickerDirectory" }
      ret[#ret + 1] = { ": ", virtual = true }
      local desc = pattern_desc[item.text] or pattern_desc[item.text:gsub("analyze", "analyse")] or ""
      ret[#ret + 1] = { desc, "SnacksPickerDesc" }
      ret[#ret + 1] = { " ", virtual = true }
      return ret
    end,
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      local cmd = { "fabric", "--pattern", item.text, "--stream" }
      if item.text == "translate" then
        table.insert(cmd, "-v=lang_code:zh_cn")
      end

      require("util").pipe(cmd, opts)
    end,
  })
end

M.fasd = function()
  pick_cmd_result({
    cmd = "fasd",
    args = { "-al" },
    preview = function(ctx)
      require("snacks.picker.preview").cmd({ "pistol", ctx.item.text }, ctx, {})
    end,
    name = "path_fasd",
    title = "FASD: files and directories",
  })
end

M.citation = function()
  local normal_mode = vim.fn.mode():find("^n")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], true)[1]
  local char_before_cursor = line:sub(cursor[2] + 1, cursor[2] + 1)
  local char_after_cursor = line:sub(cursor[2] + 2, cursor[2] + 2)
  local prefix = (cursor[2] ~= 0 and char_before_cursor ~= " ") and " " or ""
  local suffix = char_after_cursor ~= " " and " " or ""

  pick_cmd_result({
    cmd = "bibtex-ls",
    args = { os.getenv("HOME") .. "/Documents/url_ref.bib" },
    name = "bib_citation",
    title = "Bibtex Citation",
  })
end

return M
