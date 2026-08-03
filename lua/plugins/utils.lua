return {
  { "liubianshi/sqlite.lua", lazy = true },
  { -- lambdalisue/suda.vim: Read and write with sudo command ----------- {{{3
    "lambdalisue/suda.vim",
    cmd = { "SudaWrite", "SudaRead" },
  },
  { -- chentoast/marks.nvim: viewing and interacting with vim marks ----- {{{3
    "chentoast/marks.nvim",
    enabled = true,
    event = "VeryLazy",
    config = true,
  },
}
