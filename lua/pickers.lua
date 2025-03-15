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
    actions = {
      confirm = function(picker, item)
        picker:close()
        local cmd = { "fabric", "--pattern", item.text, "--stream" }
        if item.text == "translate" then
          table.insert(cmd, "-v=lang_code:zh_cn")
        end

        require("util").pipe(cmd, opts)
      end,
    },
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
        ctx.preview:set_title(vim.fn.fnamemodify(file, ":t"))
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

M.cheat = function()
  local command = vim.env.HOME .. "/useScript/bin/help"
  pick({
    finder = function(opts, ctx)
      return require("snacks.picker.source.proc").proc({
        opts,
        {
          cmd = command,
          args = { "-l" },
        },
      }, ctx)
    end,
    transform = function(item)
      local fields = vim.split(item.text, "%s+")
      item.text = fields[1]
      item.tags = fields[2]
    end,
    format = function(item)
      local ret = {}
      local sep = { " ", virtual = true }
      table.insert(ret, { item.text, "SnacksPickerIconFunction" })
      table.insert(ret, sep)
      table.insert(ret, { item.tags, "SnacksPickerIconClass" })
      table.insert(ret, sep)
      return ret
    end,
    preview = function(ctx)
      require("snacks.picker.preview").cmd({ command, ctx.item.text }, ctx, {})
      ctx.preview:set_title(vim.fn.fnamemodify(ctx.item.text, ":t"))
    end,
    win = {
      list = {
        keys = {
          ["r"] = "rename",
        },
      },
    },
    actions = {
      ["rename"] = function(picker, item, _)
        Snacks.input.input({ prompt = "Enter newname:", default = item.text }, function(newname)
          if not newname then
            return
          end
          vim.system({ command, "-r", newname, item.text }, { text = true }, function(obj)
            if obj.code == 0 then
              picker:find({ refresh = true })
            else
              vim.notify("Failed to rename `" .. item.text .. "` to `" .. newname .. "`: " .. obj.code)
            end
          end)
        end)
      end,
      ["confirm"] = function(picker, _, action)
        local items = picker:selected({ fallback = true })
        if #items == 0 then
          return
        end
        picker:close()
        local target_files = vim.tbl_map(function(item)
          return vim.fn.system("help -p '" .. item.text .. "' 2>/dev/null")
        end, items)
        local cmd = action["cmd"] or "edit"
        for _, file in ipairs(target_files) do
          vim.cmd[cmd](file)
        end
      end,
    },
    name = "Cheat",
    title = "Cheat: TL;DR",
  })
end

M.mylib = function()
  local function update(key)
    return function(picker, item)
      local default = item[key]
      if key == "author" then
        default = item["author_full"]
      end
      require("snacks.input").input({
        prompt = "Update " .. key .. ": ",
        default = default,
      }, function(value)
        if key == "tag" then
          value = "-r " .. value
          vim.system({ "mylib", "update", "--" .. key, value, "--", item["md5_short"] }, { text = true }, function(obj)
            if obj.code == 0 then
              picker:find({ refresh = true })
            else
              vim.notify("Failed to update " .. key .. ": " .. obj.code)
            end
          end)
        end
      end)
    end
  end

  pick({
    finder = function(opts, ctx)
      return require("snacks.picker.source.proc").proc({
        opts,
        {
          cmd = "mylib",
          args = { "list", "--json" },
        },
      }, ctx)
    end,
    transform = function(item)
      local fields = vim.json.decode(item.text)
      for key, value in pairs(fields) do
        item[key] = value ~= vim.NIL and value or ""
      end
      item.text = table.concat({ item.tag, item.year, item.author, item.title }, " ")
      item.filelist = vim.deepcopy(item.file)
      if item.filelist and item.filelist["file_for_preview"] ~= vim.NIL then
        item.file = item.filelist["file_for_preview"]
      else
        item.file = ""
      end
    end,
    format = function(item)
      local ret = {}
      local sep = { " ", virtual = true }

      -- author
      if item.author and item.author ~= "" and item.author ~= "佚名" and item.author ~= "unknown" then
        table.insert(ret, { item.author, "SnacksPickerSpecial" })
        table.insert(ret, sep)
      end

      -- year
      if item.year and item.year ~= "" then
        table.insert(ret, { item.year, "SnacksPickerIndex" })
        table.insert(ret, sep)
      end

      -- tags
      if item.tag and item.tag ~= "" then
        local tags = vim.split(item.tag, ":")
        for _, tag in ipairs(tags) do
          table.insert(ret, { tag, "SnacksPickerDirectory" })
          table.insert(ret, sep)
        end
      end

      -- title
      if item.title and item.title ~= "" then
        table.insert(ret, { item.title, "SnacksPickerRow" })
        table.insert(ret, sep)
      end

      return ret
    end,
    actions = {
      update_tag = update("tag"),
      update_title = update("title"),
      update_category = update("category"),
      update_rate = update("rate"),
      update_file = update("file"),
      update_author = update("author"),
      update_keywords = update("keywords"),
    },
    win = {
      input = {
        keys = {
          ["ut"] = "update_tag",
          ["uh"] = "update_title",
          ["uc"] = "update_category",
          ["ur"] = "update_rate",
          ["ua"] = "update_author",
          ["uk"] = "update_keywords",
        },
      },
      list = {
        keys = {
          ["ut"] = "update_tag",
          ["uh"] = "update_title",
          ["uc"] = "update_category",
          ["ur"] = "update_rate",
          ["ua"] = "update_author",
          ["uk"] = "update_keywords",
        },
      },
    },
  })
end

return M
