return {
  { -- ahmedkhalf/project.nvim: superior project management solution ---- {{{3
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
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      silent_chdir = true,
    },
    config = function()
      require("project_nvim").setup()
    end,
  },
  { -- rachartier/tiny-inline-diagnostic.nvim --------------------------- {{{3
    "rachartier/tiny-inline-diagnostic.nvim",
    init = vim.diagnostic.config({ virtual_text = false }),
    event = "VeryLazy",
    config = true,
  },
  { -- sindrets/diffview.nvim: cycling through diffs for all modified files  {{{3
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "DiffviewOpen" },
      { "<leader>gh", "<cmd>DiffviewFileHistory<cr>", desc = "DiffviewOpen" },
    },
  },
  { "williamboman/mason.nvim", enabled = false },
  { "williamboman/mason-lspconfig.nvim", enabled = false },
  { -- neovim/nvim-lspconfig -------------------------------------------- {{{2
    "neovim/nvim-lspconfig",
    ft = { "lua", "perl", "markdown", "bash", "r", "python", "vim", "rmd" },
    opts = {
      servers = {
        bashls = {
          cmd = { "bash-language-server", "start" },
          filetpyes = { "sh" },
          root_dir = require("lspconfig.util").root_pattern(".git", ".root", ".project"),
          single_file_support = true,
        },
        r_language_server = {
          cmd = {
            "R",
            "--slave",
            -- "--default-packages=" .. vim.g.R_start_libs,
            "-e",
            "languageserver::run()",
          },
          root_dir = require("lspconfig.util").root_pattern(".git", "NAMESPACE", "R", ".root", ".project"),
          single_file_support = true,
        },
        vimls = {},
        perlnavigator = {
          cmd = { "perlnavigator" },
          single_file_support = true,
          settings = {
            perlnavigator = {
              perlPath = "perl",
              enableWarnings = true,
              perltidyProfile = "",
              perlcriticProfile = "",
              perlcriticEnabled = true,
            },
          },
        },
        lua_ls = {
          single_file_support = true,
          settings = {
            Lua = {
              workspace = {
                checkThirdParty = false,
              },
              codeLens = {
                enable = true,
              },
              completion = {
                callSnippet = "Replace",
              },
            },
          },
        },
        markdown_oxide = {
          cmd = {
            vim.fn.executable("markdown-oxide") == 1 and "markdown-oxide"
              or vim.env.HOME .. "/.cargo/bin/markdown-oxide",
          },
          filetype = { "markdown", "rmd", "rmarkdown", "quarto" },
          root_dir = require("lspconfig.util").root_pattern(".obsidian", ".git"),
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
            },
          },
          single_file_support = false,
          on_attach = function(client, _) -- _ bufnr
            client.handlers["textDocument/publishDiagnostics"] = function() end
          end,
        },
      },
    },
  },
  { -- stevearc/overseer.nvim: task runner and joib management ---------- {{{2
    "stevearc/overseer.nvim",
    opts = {},
    config = function(opts)
      require("overseer").setup({
        templates = { "builtin", "mytasks.source" },
      })
    end,
  },
}
