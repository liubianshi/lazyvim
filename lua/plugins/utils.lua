return {
  { "kkharji/sqlite.lua", lazy = true },
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
  { -- ojroques/vim-oscyank: copy text through SSH with OSC52 ----------- {{{3
    "ojroques/vim-oscyank",
    cmd = { "OSCYankVisual" },
    config = true,
  },
}
