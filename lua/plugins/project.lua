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
      exclude_dirs = { "~", "/tmp", "/tmp/*", "~/Downloads" },
    },
    -- 模块名与仓库名不同，指明后由 lazy.nvim 自己调 setup(opts)
    main = "project_nvim",
  },
}
