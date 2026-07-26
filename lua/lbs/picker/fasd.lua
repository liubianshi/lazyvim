local pick = require("snacks.picker").pick

return function()
  pick({
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = "fasd",
          args = { "-al" },
        }),
        ctx
      )
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
