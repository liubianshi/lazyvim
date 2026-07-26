return {
  { -- ahmedkhalf/project.nvim: superior project management solution ---- {{{2
    "ahmedkhalf/project.nvim",
    opts = {
      detection_methods = { "pattern", "lsp" },
      patterns = {
        ".git",
        "_darcs",
        ".hg",
        ".bzr",
        ".svn",
        ".root",
        ".project",
        "R",
        ".obsidian",
        "Makefile",
        "package.json",
        "namespace",
        "VERSION",
        ".exercism",
      },
      silent_chdir = false,
      exclude_dirs = { "~", "/tmp", "~/Downloads" },
    },
    config = function(_, opts)
      require("project_nvim").setup(opts)
    end,
  },
}
