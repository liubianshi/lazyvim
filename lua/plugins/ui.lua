return {
  { -- Bekaboo/dropbar.nvim
    "Bekaboo/dropbar.nvim",
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  { -- folke/noice.nvim
    "folke/noice.nvim",
    cmd = { "NoiceEnable" },
    keys = {
      {
        "<leader>hn",
        "<cmd>NoiceFzf<cr>",
        desc = "Noice: Search Notifications",
      },
      {
        "<c-f>",
        function()
          require("noice.lsp").signature()
        end,
        mode = "i",
        desc = "Noice: Show lsp documents",
      },
    },
    opts = {
      lsp = {
        signature = {
          enabled = true,
          auto_open = {
            trigger = false,
          },
        },
        -- overrid e markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        progress = { enabled = false }, -- forbidden rime-ls info
      },
      -- you can enable a preset for easier configuration
      presets = {
        bottom_search = false, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = false, -- long messages will be sent to a split
        inc_rename = true, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = true, -- add a border to hover docs and signature help
      },
      messages = {
        enabled = true,
        view = "notify",
        view_error = "notify", -- view for errors
        view_warn = "notify", -- view for warnings
        view_history = "messages", -- view for :messages
        view_search = "virtualtext",
      },
      popupmenu = {
        enabled = true,
        -- backend = "nui",
      },
      cmdline = {
        opts = {
          position = {
            row = "90%", -- 将行位置设置为 100%，即底部
            col = "50%", -- 将列位置设置为 50%，即居中
          },
          win_options = {
            winhighlight = {
              FloatBorder = "NoiceCmdlinePopupBorder",
            },
          },
        },
        format = {
          search_down = {
            kind = "search",
            pattern = "^/",
            icon = " ",
            lang = "regex",
            opts = {
              -- position = {
              --   row = "100%", -- 将行位置设置为 100%，即底部
              --   col = "50%", -- 将列位置设置为 50%，即居中
              -- },
            },
          },
          search_up = {
            opts = {
              -- position = {
              --   row = "100%", -- 将行位置设置为 100%，即底部
              --   col = "50%", -- 将列位置设置为 50%，即居中
              -- },
            },
            kind = "search",
            pattern = "^%?",
            icon = " ",
            lang = "regex",
          },
        },
      },
      routes = {
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%[>?%d+/>?%d+%]$" }, -- search count
              { find = "%d+L, %d+B$" }, -- search count
              { find = '%.newsboat%" %d+L' },
              { find = "more lines$" },
              { find = "Pattern not found:" },
            },
          },
          opts = { skip = true },
        },
        {
          filter = {
            any = {
              { find = "multiple different client offset_encodings" },
            },
          },
          opts = { skip = true },
        },

        {
          view = "vsplit",
          filter = { min_height = 20, event = "msg_show" },
        },
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
            },
          },
          view = "mini",
        },
        -- {
        --   filter = {
        --     event = "msg_show",
        --     kind = {"echo", "echomsg"},
        --     any = {
        --       {find = "<Enter>"}
        --     }
        --   },
        --   view = "confirm" ,
        -- },
        {
          filter = {
            event = "lsp",
            any = {
              { find = "rime_ls", kind = { "progress" } },
              { find = "Use an initialized rime instance" },
            },
          },
          opts = { skip = true },
        },
      },
    },
  },
  { -- vim-voom/VOoM: vim Outliner of Markups
    "vim-voom/VOoM",
    cmd = "Voom",
    keys = {
      { "<leader>v", "<cmd>Voom<cr>", desc = "VOom: Show Outliner" },
    },
    init = function()
      vim.g.voom_ft_modes = {
        markdown = "pandoc",
        rmd = "pandoc",
        quarto = "pandoc",
        rnoweb = "latex",
        pandoc = "pandoc",
        norg = "org",
      }
      vim.g.voom_tree_width = 30
      vim.g.voom_tree_placement = "right"
    end,
  },
  { "echasnovski/mini.pairs", enabled = false },
  { -- windwp/nvim-autopairs: autopair tools
    "windwp/nvim-autopairs",
    opts = {
      disable_filetype = { "TelescopePrompt" },
      disable_in_macro = true, -- disable when recording or executing a macro
      disable_in_visualblock = true, -- disable when insert after visual block mode
      disable_in_replace_mode = true,
      ignored_next_char = [=[[%w%%%'%[%"%.]]=],
      enable_moveright = true,
      enable_afterquote = true, -- add bracket pairs after quote
      enable_check_bracket_line = true, --- check bracket in same line
      enable_bracket_in_quote = true, --
      check_ts = false,
      map_cr = true,
      map_bs = true, -- map the <BS> key
      map_c_h = false, -- Map the <C-h> key to delete a pair
      map_c_w = false, -- map <c-w> to delete a pair if possible
    },
    config = function(_, opts)
      require("nvim-autopairs").setup(opts)

      local Rule = require("nvim-autopairs.rule")
      local npairs = require("nvim-autopairs")
      npairs.add_rules({
        Rule("`", "`", "-stata"),
        --TODO:nvim 的补全似乎有点问题，即会将光标后面的字符也纳入考虑
        Rule("[", "]", "markdown"):replace_endpair(function(opts)
          if require("util").in_obsidian_vault(opts.bufnr) then
            return ""
          else
            return "]"
          end
        end),
        Rule('"', '"', "-vim"),
        Rule("`", "'", "stata"),
        Rule("$", "$", "markdown"),
      })
    end,
  },
  { -- Make your nvim window separators colorful ------------------------ {{{3
    "nvim-zh/colorful-winsep.nvim",
    event = { "WinNew" },
    config = function()
      require("colorful-winsep").setup({
        no_exec_files = {
          "packer",
          "TelescopePrompt",
          "mason",
          "CompetiTest",
          "NvimTree",
          "aerial",
          "neo-tree",
        },
        symbols = { "─", "│", "┌", "┐", "└", "┘" },
      })
    end,
  },
  { -- stevearc/aerial.nvim: Neovim plugin for a code outline window ------ {{{2
    "stevearc/aerial.nvim",
    config = function()
      require("aerial").setup({
        backends = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
        on_attach = function(bufnr)
          -- Jump forwards/backwards with '{' and '}'
          vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
          vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
        end,
      })
    end,
    keys = {
      { "<localleader>v", "<cmd>AerialToggle!<CR>", desc = "Toggle aerial" },
    },
    cmd = { "AerialToggle" },
  },
  { -- kevinhwang91/nvim-hlslens: Hlsearch Lens for Neovim -------------- {{{3
    "kevinhwang91/nvim-hlslens",
    event = { "SearchWrapped", "CursorMoved" },
    keys = {
      {
        "n",
        "<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>",
        silent = true,
      },
      {
        "N",
        "<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>",
        silent = true,
      },
      { "*", "*<Cmd>lua require('hlslens').start()<CR>" },
      { "#", "#<Cmd>lua require('hlslens').start()<CR>", noremap = true },
      { "g*", "g*<Cmd>lua require('hlslens').start()<CR>", noremap = true },
      { "g#", "g#<Cmd>lua require('hlslens').start()<CR>", noremap = true },
    },
    config = true,
  },
}
