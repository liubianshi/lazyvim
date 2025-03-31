return {
  { -- Wansmer/treesj: Neovim plugin for splitting/joining blocks of code  {{{3
    "Wansmer/treesj",
    cmd = { "TSJToggle", "TSJSplit", "TSJJoin" },
    keys = {
      { "<leader>mj", "<cmd>TSJJoin<cr>", desc = "Join Code Block" },
      { "<leader>ms", "<cmd>TSJSplit<cr>", desc = "Split Code Block" },
      { "<leader>mm", "<cmd>TSJToggle<cr>", desc = "Join/Split Code Block" },
    },
    opts = {
      use_default_keymaps = false,
    },
  },
  { -- AckslD/nvim-FeMaco.lua: Fenced Markdown Code-block editing ----------- {{{3
    "AckslD/nvim-FeMaco.lua",
    cmd = "FeMaco",
    ft = { "markdown", "rmarkdown", "norg" },
    keys = {
      { "<localleader>o", "<cmd>FeMaco<cr>", desc = "FeMaco: Edit Code Block" },
    },
  },
}
