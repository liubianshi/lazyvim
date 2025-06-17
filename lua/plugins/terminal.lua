return {
  { -- is0n/fm-nvim: Neovim plugin that lets you use your favorite terminal file managers {{{2
    "is0n/fm-nvim",
    cmd = { "Lf", "Nnn", "Neomutt", "Lazygit" },
    keys = {
      { "<leader>fo", "<cmd>Lf '%:p:h'<cr>", desc = "Open File with Lf" },
      -- { "<leader>fn", "<cmd>Nnn '%:p:h'<cr>", desc = "Open File with nnn" },
      -- { "<leader>gg", "<cmd>Lazygit<cr>", desc = "Open Lazy Git" },
    },
    config = function()
      local fm = require("fm-nvim")
      local ui = {
        -- Default UI (can be "split" or "float")
        default = "float",
        float = {
          -- Floating window border (see ':h nvim_open_win')
          border = "rounded",
          float_hl = "TelescopeNormal",
          border_hl = "TelescopeBorder",
          -- Floating Window Transparency (see ':h winblend')
          blend = 0,
          -- Num from 0 - 1 for measurements
          height = 0.7,
          width = 0.8,
          -- X and Y Axis of Window
          x = 0.5,
          y = 0.5,
        },
        split = {
          -- Direction of split
          direction = "topleft",
          -- Size of split
          size = 24,
        },
      }
      local cmds = {
        lf_cmd = "lf", -- eg: lf_cmd = "lf -command 'set hidden'"
        fm_cmd = "fm",
        nnn_cmd = "nnn",
        newsboat = "newsboat",
        fff_cmd = "fff",
        twf_cmd = "twf",
        fzf_cmd = "fzf", -- eg: fzf_cmd = "fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'"
        fzy_cmd = "find . | fzy",
        xplr_cmd = "xplr",
        vifm_cmd = "vifm",
        skim_cmd = "sk",
        broot_cmd = "broot",
        gitui_cmd = "gitui",
        ranger_cmd = "ranger",
        joshuto_cmd = "joshuto",
        lazygit_cmd = "lazygit",
        neomutt_cmd = "neomutt",
        taskwarrior_cmd = "taskwarrior-tui",
      }
      local mappings = {
        vert_split = "<C-v>",
        horz_split = "<C-h>",
        tabedit = "<C-t>",
        edit = "<C-e>",
        ESC = "<ESC>",
      }

      fm.setup({
        edit_cmd = "edit",
        on_close = {},
        on_open = {},
        ui = ui,
        cmds = cmds,
        mappings = mappings,
        -- Path to broot config
        broot_conf = vim.fn.stdpath("data") .. "/site/pack/packer/start/fm-nvim/assets/broot_conf.hjson",
      })
    end,
  },
  { -- typicode/bg.nvim: Automatically sync your terminal background ---- {{{2
    "typicode/bg.nvim",
    lazy = false,
  },
  { -- liubianshi/vimcmdline: Send code to command line interpreter ----- {{{2
    "liubianshi/vimcmdline",
    ft = { "stata", "sh", "bash", "perl" },
    dev = true,
  },
  { -- mikesmithgh/kitty-scrollback.nvim: Open kitty scrollback --------- {{{2
    "mikesmithgh/kitty-scrollback.nvim",
    enabled = true,
    lazy = true,
    cmd = {
      "KittyScrollbackGenerateKittens",
      "KittyScrollbackCheckHealth",
      "KittyScrollbackGenerateCommandLineEditing",
    },
    event = { "User KittyScrollbackLaunch" },
    version = "*", -- latest stable version, may have breaking changes if major version changed
    config = function()
      require("kitty-scrollback").setup()
    end,
  },
  { -- m00qek/baleia.nvim ----------------------------------------------- {{{2
    version = "*",
    config = function()
      vim.g.baleia = require("baleia").setup({})

      -- Command to colorize the current buffer
      vim.api.nvim_create_user_command("BaleiaColorize", function()
        vim.g.baleia.once(vim.api.nvim_get_current_buf())
      end, { bang = true })

      -- Command to show logs
      vim.api.nvim_create_user_command("BaleiaLogs", vim.g.baleia.logger.show, { bang = true })
    end,
    "m00qek/baleia.nvim",
  },
}
