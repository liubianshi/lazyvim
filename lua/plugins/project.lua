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
      silent_chdir = false,
      exclude_dirs = { "~", "/tmp", "~/Downloads" },
    },
    config = function(_, opts)
      require("project_nvim").setup(opts)
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
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { -- neovim/nvim-lspconfig -------------------------------------------- {{{2
    "neovim/nvim-lspconfig",
    ft = { "lua", "perl", "markdown", "bash", "r", "python", "vim", "rmd", "hyprlang" },
    opts = function(_, opts)
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      keys[#keys + 1] = { "K", false }
      opts.servers = vim.tbl_deep_extend("force", opts.servers, {
        hyprls = {
          root_markers = { "hyprland.conf", "hyprland.d", ".git" },
        },
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
      })
    end,
  },
  { -- stevearc/overseer.nvim: task runner and joib management ---------- {{{2
    "stevearc/overseer.nvim",
    keys = {
      { "<leader>ot", "<cmd>OverseerRun<cr>", desc = "Overseer Run" },
      { "<leader>uo", "<cmd>OverseerToggle<cr>", desc = "Overseer Toggle" },
    },
    opts = {},
    config = function(opts)
      require("overseer").setup({
        templates = { "builtin", "mytasks.source", "r" },
      })
    end,
  },
  { -- Wansmer/symbol-usage.nvim ---------------------------------------- {{{2
    "Wansmer/symbol-usage.nvim",
    event = "BufReadPre", -- need run before LspAttach if you use nvim 0.9. On 0.10 use 'LspAttach'
    config = function()
      local function h(name)
        return vim.api.nvim_get_hl(0, { name = name })
      end

      -- hl-groups can have any name
      -- stylua: ignore start
      vim.api.nvim_set_hl(0, "SymbolUsageRounding", { fg = h("CursorLine").bg,                          italic = true })
      vim.api.nvim_set_hl(0, "SymbolUsageContent",  { fg = h("Comment").fg,    bg = h("CursorLine").bg, italic = true })
      vim.api.nvim_set_hl(0, "SymbolUsageRef",      { fg = h("Function").fg,   bg = h("CursorLine").bg, italic = true })
      vim.api.nvim_set_hl(0, "SymbolUsageDef",      { fg = h("Type").fg,       bg = h("CursorLine").bg, italic = true })
      vim.api.nvim_set_hl(0, "SymbolUsageImpl",     { fg = h("@keyword").fg,   bg = h("CursorLine").bg, italic = true })
      -- stylua: ignore end

      local function text_format(symbol)
        local res = {}

        local round_start = { "", "SymbolUsageRounding" }
        local round_end = { "", "SymbolUsageRounding" }

        -- Indicator that shows if there are any other symbols in the same line
        local stacked_functions_content = symbol.stacked_count > 0 and ("+%s"):format(symbol.stacked_count) or ""

        if symbol.references then
          local usage = symbol.references <= 1 and "usage" or "usages"
          local num = symbol.references == 0 and "no" or symbol.references
          table.insert(res, round_start)
          table.insert(res, { "󰌹 ", "SymbolUsageRef" })
          table.insert(res, { ("%s %s"):format(num, usage), "SymbolUsageContent" })
          table.insert(res, round_end)
        end

        if symbol.definition then
          if #res > 0 then
            table.insert(res, { " ", "NonText" })
          end
          table.insert(res, round_start)
          table.insert(res, { "󰳽 ", "SymbolUsageDef" })
          table.insert(res, { symbol.definition .. " defs", "SymbolUsageContent" })
          table.insert(res, round_end)
        end

        if symbol.implementation then
          if #res > 0 then
            table.insert(res, { " ", "NonText" })
          end
          table.insert(res, round_start)
          table.insert(res, { "󰡱 ", "SymbolUsageImpl" })
          table.insert(res, { symbol.implementation .. " impls", "SymbolUsageContent" })
          table.insert(res, round_end)
        end

        if stacked_functions_content ~= "" then
          if #res > 0 then
            table.insert(res, { " ", "NonText" })
          end
          table.insert(res, round_start)
          table.insert(res, { " ", "SymbolUsageImpl" })
          table.insert(res, { stacked_functions_content, "SymbolUsageContent" })
          table.insert(res, round_end)
        end

        return res
      end

      --- @diagnostic disable: missing-fields
      require("symbol-usage").setup({
        text_format = text_format,
        vt_position = "end_of_line",
      })
    end,
  },
}
