local pick = require("snacks.picker").pick

return function()
  pick({
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = ",sh",
          args = { "-l" },
        }),
        ctx
      )
    end,
    transform = function(item)
      local fields = vim.split(item.text, "%s+")
      item.key, item.file = unpack(fields)
      item.filename = vim.fn.fnamemodify(item.file, ":t")
      item.dirname = vim.fn.fnamemodify(item.file, ":h")
    end,
    format = function(item)
      local ret = {}
      local sep = { " ", virtual = true }
      if item.key and item.key ~= "" then
        table.insert(ret, { item.key, "SnacksPickerSpecial" })
        table.insert(ret, sep)
      end
      if item.filename and item.filename ~= "" then
        table.insert(ret, { item.filename, "SnacksPickerRow" })
        table.insert(ret, sep)
      end
      if item.dirname and item.dirname ~= "" then
        table.insert(ret, { item.dirname, "SnacksPickerComment" })
      end
      return ret
    end,
    preview = function(ctx)
      local orig_file = ctx.item.file
      ctx.item.file = vim.fn.system(",sh -v -r " .. ctx.item.file)
      require("snacks.picker.preview").file(ctx)
      ctx.item.file = orig_file
      ctx.preview:set_title(ctx.item.key)
    end,
    actions = {
      confirm = function(picker, _, action)
        local item = picker:selected({ fallback = true })[1]
        picker:close()
        local file = vim.fn.system(",sh -v -r " .. item.file)
        local command = item.key
        if action.name == "confirm" then
          vim.cmd.edit(file)
        else
          vim.cmd[action.name](file)
        end
        vim.cmd('file `="[' .. command .. ']"`')
        vim.cmd([[
          setlocal bufhidden=delete
          setlocal buftype=nofile
          setlocal noswapfile
          setlocal nobuflisted
          setlocal nomodifiable
          setlocal nocursorline
          setlocal nocursorcolumn
        ]])
        vim.keymap.set("n", "q", "<cmd>quit<cr>", { buffer = true })
      end,
    },
  })
end
