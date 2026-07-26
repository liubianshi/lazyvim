local pick = require("snacks.picker").pick
local util = require("lbs.picker.util")

return function()
  local normal_mode = vim.fn.mode():find("^n")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], true)[1]
  local char_before_cursor = line:sub(cursor[2] + 1, cursor[2] + 1)
  local char_after_cursor = line:sub(cursor[2] + 2, cursor[2] + 2)
  local prefix = (cursor[2] ~= 0 and char_before_cursor ~= " ") and " " or ""
  local suffix = char_after_cursor ~= " " and " " or ""

  pick({
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = "bibtex2csv",
          args = { os.getenv("HOME") .. "/Documents/url_ref.bib" },
        }),
        ctx
      )
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
      yank_reference = util.get_reference,
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
