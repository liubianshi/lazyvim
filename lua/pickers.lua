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

local function get_reference(picker)
  local cmd = { "bibref" }
  for _, item in ipairs(picker:selected({ fallback = true })) do
    table.insert(cmd, item.key)
  end
  picker:close()
  local job = vim.system(cmd, { text = true }):wait()
  if job.code == 0 and job.stdout ~= "" then
    local ref = job.stdout:gsub("\n+$", "")
    vim.fn.setreg("+", ref)
  end
end

M.fabric = function(opts)
  local mode = vim.api.nvim_get_mode().mode
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
        opts = opts or {}
        if mode == "v" or mode == "V" or mode == "\22" then
          opts.stdin = require("util").get_pipe_stdin({ mode = mode })
        end

        local cmd = { "fabric", "--pattern", item.text, "--stream" }
        local ok, progress = pcall(require, "fidget.progress")
        local progress_handle
        if ok then
          progress_handle = progress.handle.create({
            title = " Requesting Fabric (" .. item.text .. ")",
            message = "In progress...",
            lsp_client = {
              name = "Fabric",
            },
          })
          opts.handle = {
            name = "fidget",
            handle = progress_handle,
            on_exit = function(handle, status)
              if status == "success" then
                handle.message = "Completed"
              elseif status == "error" then
                handle.message = " Error"
              else
                handle.message = "󰜺 Cancelled"
              end
              handle:finish()
            end,
          }
        end

        if item.text == "translate" and not opts.stdin then
          table.insert(cmd, "-v=lang_code:en_US")
          require("util").pipe(cmd, opts)
        elseif item.text == "translate" then
          opts.stdin = require("util").join_strings_by_paragraph(opts.stdin)
          local head_chars = vim.trim(opts.stdin[1]):sub(1, 20)
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
            table.insert(cmd, "-v=lang_code:zh_cn")
          end
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
      end, picker:selected({ fallback = true }))
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
      yank_reference = get_reference,
    },
    win = {
      input = {
        keys = {
          ["<c-i>"] = { "bracket_citation", mode = { "i", "n" } },
          ["<c-x>y"] = { "yank_reference", mode = { "i", "n" } },
          ["yr"] = "yank_reference",
        },
      },
      liest = {
        keys = {
          ["yr"] = "yank_reference",
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
        end
        vim.system({ "mylib", "update", "--" .. key, value, item["md5_short"] }, { text = true }, function(obj)
          if obj.code == 0 then
            picker:find({ refresh = true })
            vim.notify(key .. " updated", vim.log.levels.INFO)
          else
            vim.notify("Failed to update " .. key .. ": " .. obj.code, vim.log.levels.ERROR)
          end
        end)
      end)
    end
  end
  local function yank(key)
    return function(picker)
      local items = picker:selected({ fallback = true })
      picker:close()
      local re
      if key == "key" then
        re = table.concat(
          vim.tbl_map(function(item)
            return "@" .. item.key
          end, items),
          "; "
        )
      else
        re = table.concat(
          vim.tbl_map(function(item)
            return item[key]
          end, items),
          " "
        )
      end
      vim.fn.setreg("+", re)
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
      yank_id = yank("md5_short"),
      yank_key = yank("key"),
      yank_reference = get_reference,
      delete_record = function(picker, item)
        vim.system({ "mylib", "delete", "-f", item["md5_short"] }, { text = true }, function(obj)
          if obj.code ~= 0 then
            vim.notify("Failed to delete record " .. item["md5_short"] .. ": " .. obj.code)
          else
            vim.notify("Delete recode " .. item["md5_short"])
            picker:find({ refresh = true })
          end
        end)
      end,
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
          ["yi"] = "yank_id",
          ["yk"] = "yank_key",
          ["yr"] = "yank_reference",
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
          ["dD"] = "delete_record",
          ["yi"] = "yank_id",
          ["yk"] = "yank_key",
          ["yr"] = "yank_reference",
        },
      },
    },
  })
end

M.clipcat = function()
  pick({
    finder = function(opts, ctx)
      return require("snacks.picker.source.proc").proc({
        opts,
        {
          cmd = "clipcatctl",
          args = { "list" },
          transform = function(item)
            local id, content = item.text:match("^([0-9a-f]+)%:%s(.+)$")
            if id and content then
              item.text = content
              setmetatable(item, {
                __index = function(_, k)
                  if k == "data" then
                    local data = vim.fn.system({ "clipcatctl", "get", id }):gsub("\\n", "\n")
                    rawset(item, "data", data)
                    if vim.v.shell_error ~= 0 then
                      error(data)
                    end
                    return data
                  elseif k == "preview" then
                    return {
                      text = item.data,
                      ft = "text",
                    }
                  end
                end,
              })
            else
              return false
            end
          end,
        },
      }, ctx)
    end,
    format = "text",
    preview = "preview",
    confirm = { "copy", "close" },
  })
end

M.roam = function()
  local ROAM_CACHE = table.concat({ os.getenv("HOME"), ".cache", "org_roam", "id_title.tsv" }, "/")
  local ROAM_LIB = table.concat({ os.getenv("HOME"), "Documents", "Writing", "roam" }, "/")
  vim.cmd.cd(ROAM_LIB)
  pick({
    finder = function(_, _)
      local file = assert(io.open(ROAM_CACHE, "r"))
      local items = {}
      for line in file:lines() do
        local field = vim.split(line, "\t")
        local item = { id = field[1], title = field[2], tags = field[3], file = field[4] }
        table.insert(items, item)
      end
      file:close()
      return items
    end,
    format = function(item)
      local ret = {}
      local sep = { " ", virtual = true }
      table.insert(ret, { item.title, "SnacksPickerRow" })
      table.insert(ret, sep)
      if item.tags and item.tags ~= "" then
        table.insert(ret, { item.tags, "SnacksPickerDirectory" })
        table.insert(ret, sep)
      end
      table.insert(ret, { item.file, "SnacksPickerSpecial" })
      table.insert(ret, sep)
      return ret
    end,
    actions = {
      confirm = function(picker, _, action)
        local item = picker:selected({ fallback = true })[1]
        picker:close()
        local line, file = vim.fn.system("roam_id_title -i " .. item.id):match("^%+(%d+)%s+(.*)$")
        vim.cmd.cd(ROAM_LIB)
        if action.name == "confirm" then
          vim.cmd.edit(file)
          vim.cmd.normal(line .. "G")
        else
          vim.cmd[action.name](file)
          vim.cmd.normal(line .. "G")
        end
      end,
      cite = function(picker, _)
        local item = picker:selected({ fallback = true })[1]
        picker:close()
        if not vim.fn["utils#IsPrintable_CharUnderCursor"]() then
          vim.cmd("normal! a ")
        end
        local buf = vim.fn.bufnr()
        local row_col = vim.api.nvim_win_get_cursor(0)
        local row = row_col[1] - 1
        local col = row_col[2] + 1
        local cite = string.format("[[%s]][[%s]]", "id:" .. item.id, item.title)
        dd(cite)
        vim.api.nvim_buf_set_text(buf, row, col, row, col, { cite })
        vim.cmd("normal! 3f]")
      end,
      new = function(picker)
        local current_buf = vim.api.nvim_get_current_buf()
        local lines = vim.api.nvim_buf_get_lines(current_buf, 0, 1, false)
        local input_text = lines[1]
        picker:close()
        vim.cmd([[normal l]])
        vim.fn["utils#RoamInsertNode"](input_text, "split")
        vim.cmd([[wincmd J]])
        vim.cmd([[res 8]])
      end,
    },
    preview = function(ctx)
      ctx.picker.opts.previewers.file.ft = "org"
      require("snacks.picker.preview").file(ctx)
    end,
    win = {
      input = {
        keys = {
          ["<c-x>n"] = { "new", mode = { "n", "i" } },
          ["<c-x>i"] = { "cite", mode = { "n", "i" } },
        },
      },
    },
  })
end

return M
