local pick = require("snacks.picker").pick

return function()
  local command = vim.env.HOME .. "/useScript/bin/help"
  pick({
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = command,
          args = { "-l" },
        }),
        ctx
      )
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
