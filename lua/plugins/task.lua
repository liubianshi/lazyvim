return {
  { -- stevearc/overseer.nvim: task runner and job management ----------- {{{2
    "stevearc/overseer.nvim",
    keys = {
      {
        "<leader>or",
        function()
          local overseer = require("overseer")
          local tasks = overseer.list_tasks({ recent_first = true })
          if #tasks == 0 then
            vim.cmd("OverseerRun")
          else
            overseer.run_action(tasks[1], "restart")
          end
        end,
        desc = "Rerun Last Task",
        mode = "n",
      },
    },
    opts = {
      templates = { "builtin", "mytasks.source", "r", "mytasks.taskfile" },
    },
  },
}
