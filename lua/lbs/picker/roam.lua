local pick = require("snacks.picker").pick

return function()
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
