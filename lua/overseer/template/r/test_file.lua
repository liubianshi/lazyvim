return {
  name = "test current file",
  builder = function()
    local test_file = require("rlib.test").source_to_test_filepath(vim.fn.expand("%"))
    local cwd = vim.v.cwd or vim.fn.getcwd()
    return {
      cmd = { "Rscript" },
      args = {
        "--no-init-file",
        "--no-save",
        "--no-restore",
        "-e",
        string.format([[setwd("%s"); testthat::test_file("%s")]], cwd, test_file),
      },
      name = "R: test current file",
      cwd = cwd,
      components = {
        { "open_output", on_complete = "always", focus = true },
        "default",
      },
      tags = { require("overseer").TAG.TEST },
    }
  end,
  condition = {
    callback = function()
      local cwd = vim.v.cwd or vim.fn.getcwd()
      if not vim.fn.isdirectory(cwd .. "/R") then
        return false
      end

      local fname = vim.fn.expand("%")
      local frelname = vim.fs.relpath(cwd, fname) or fname

      if frelname:lower():match("^r/.+%.r$") and not vim.fn.fnamemodify(frelname, ":t"):match("^test[-_]") then
        return true
      end
      return false
    end,
  },
}
