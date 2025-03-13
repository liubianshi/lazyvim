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
  pick({
    finder = function(opts, ctx)
      return require("snacks.picker.source.proc").proc({
        opts,
        {
          cmd = "fasd",
          args = { "-al" },
        },
      }, ctx)
    end,
    transform = function(item)
      item.file = item.text
    end,
    preview = function(ctx)
      local file = ctx.item.text
      local ext = vim.fn.fnamemodify(file, ":e")
      local data_file = vim.tbl_contains({ "dta", "xlsx", "csv", "xls", "rdata", "tsv", "rds", "fst", "qf" }, ext)
      if data_file or vim.fn.isdirectory(file) == 1 then
        require("snacks.picker.preview").cmd({ "pistol", file }, ctx, {})
      else
        require("snacks.picker.preview").file(ctx)
      end
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

  pick({
    finder = function(opts, ctx)
      return require("snacks.picker.source.proc").proc({
        opts,
        {
          cmd = "bibtex2csv",
          args = { os.getenv("HOME") .. "/Documents/url_ref.bib" },
        },
      }, ctx)
    end,
    name = "bib_citation",
    transform = function(item)
      local fields = vim.split(item.text, "\t")
      item.author = fields[1]
      item.year = fields[2]
      item.title = fields[3]
      item.publish = fields[4]
      item.type = fields[5]
      item.key = fields[6]
    end,
    preview = function(ctx)
      local obj = vim.system({ "mylib", "get", "file_for_preview", "--", "@" .. ctx.item.key }, { text = true }):wait()
      if obj.code ~= 0 then
        return
      end
      ctx.item.file = vim.fn.trim(obj.stdout)
      require("snacks.picker.preview").file(ctx)
    end,
    format = function(item, _)
      local ret = {}
      local sep = { " ", virtual = true }
      if item.author ~= "" then
        table.insert(ret, { item.author, "SnacksPickerSpecial" })
        table.insert(ret, sep)
      end

      if item.year ~= "" then
        table.insert(ret, { "(" .. item.year .. ")", "SnacksPickerIndex" })
        table.insert(ret, sep)
      end

      if item.title ~= "" then
        table.insert(ret, { item.title, item.type == "article" and "SnacksPickerTitle" or "SnacksPickerRow" })
        table.insert(ret, sep)
      end

      if item.publish ~= "" then
        table.insert(ret, { "[" .. item.publish .. "]", "SnacksPickerRow" })
      end

      return ret
    end,
    title = "Bibtex Citation",
    confirm = function(picker, _)
      local keys = vim.tbl_map(function(ctx)
        return ctx.key:gsub("^%@", "")
      end, picker:selected())
      picker:close()
      local obj = vim.system({ "bibtex-cite", "-mode=pandoc" }, { text = true, stdin = keys }):wait(50)
      local r = obj.stdout
      vim.api.nvim_win_set_cursor(0, cursor)
      vim.api.nvim_put({ prefix .. r .. suffix }, "c", (normal_mode and cursor[2] ~= 0) or at_end_of_line(), true)
    end,
    actions = {
      bracket_citation = function(picker)
        local keys = vim.tbl_map(function(ctx)
          return ctx.key:gsub("^%@", "")
        end, picker:selected())
        picker:close()
        local obj = vim.system({ "bibtex-cite", "-mode=pandoc" }, { text = true, stdin = keys }):wait(50)
        local r = obj.stdout
        vim.api.nvim_win_set_cursor(0, cursor)
        vim.api.nvim_put(
          { prefix .. "[" .. r .. "]" .. suffix },
          "c",
          (normal_mode and cursor[2] ~= 0) or at_end_of_line(),
          true
        )
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-i>"] = { "bracket_citation", mode = { "i", "n" } },
        },
      },
      preview = {
        wo = {
          relativenumber = false,
          number = false,
        },
      },
    },
  })
end

return M
