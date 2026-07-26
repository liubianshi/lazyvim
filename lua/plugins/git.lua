return {
  { -- sindrets/diffview.nvim: cycling through diffs for all modified files  {{{2
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: Open" },
      -- 不用 <leader>gh：那是 LazyVim gitsigns 的 hunks 组前缀，把完整动作压在
      -- 组前缀上会让每条 hunk 命令都等满 timeoutlen。
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: File History" },
    },
  },
}
