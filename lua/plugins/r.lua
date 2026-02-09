return {
  { -- R.nvim ----------------------------------------------------------- {{{2
    "liubianshi/R.nvim",
    enabled = true,
    dev = true,
    lazy = false,
    ft = { "r", "rmd", "quarto" },
    opts = function()
      local hook = {
        on_filetype = function()
          vim.api.nvim_create_user_command("RAdd", function(tbl)
            require("r.packages").update_compl_packages(tbl.fargs)
          end, { nargs = "+" })

          -- Setting box-related shortcuts
          require("r_box").set_keymap()

          -- Send command to R terminal
          vim.keymap.set("n", "<M-;>", function()
            vim.api.nvim_feedkeys(":RSend ", "n", false)
          end, {
            noremap = true,
            buffer = true,
            silent = true,
            desc = "Send script to R console",
          })

          -- vim.keymap.set("n", "<Enter>", "<Plug>RDSendLine", { buffer = true })
          vim.keymap.set("v", "<Enter>", "<Plug>RSendSelection", { buffer = true })
          vim.keymap.set(
            "n",
            "<localleader>rA",
            "<cmd>exec 'RAdd ' . expand('<cword>')<cr>",
            { buffer = true, desc = "Add package for completion" }
          )
          vim.keymap.set("v", "<localleader>rl", "<Plug>RSendSelection", {
            buffer = true,
            desc = "Send to R visually selected lines or part of a line",
          })

          -- Increase the width of which-key to handle the longer r-nvim descriptions
          local wk = require("which-key")
          -- Workaround from https://github.com/folke/which-key.nvim/issues/514#issuecomment-1987286901
          wk.add({
            { "<localleader>a", group = "all" },
            { "<localleader>b", group = "between marks" },
            { "<localleader>c", group = "chunks" },
            { "<localleader>f", group = "functions" },
            { "<localleader>g", group = "goto" },
            { "<localleader>k", group = "knit" },
            { "<localleader>p", group = "paragraph" },
            { "<localleader>q", group = "quarto" },
            { "<localleader>r", group = "r general" },
            { "<localleader>s", group = "split or send" },
            { "<localleader>t", group = "terminal" },
            { "<localleader>v", group = "view" },
          })
        end,
        after_config = function()
          if vim.o.syntax ~= "rbrowser" then
            vim.api.nvim_buf_set_keymap(0, "v", "<Enter>", "<Plug>RSendSelection", {})
          else
            vim.api.nvim_set_option_value("filetype", "rbrowser", { scope = "local" })
          end
        end,
        after_R_start = function()
          if require("r.config").get_option("R_app") ~= "radian" then
            require("r.term.builtin").highlight_term()
          end
          vim.opt_local.keywordprg = ":RHelp"
        end,
      }

      local opts = {
        -- R_app = "radian",
        R_args = { "--quiet", "--no-save" },
        hook = hook,
        Rout_more_colors = true,
        min_editor_width = 72,
        rconsole_width = 78,
        compl_method = "buffer",
        register_treesitter = true,
        objbr_openlist = true,
        objbr_place = "console,left",
        objbr_opendf = true,
        bracketed_paste = vim.fn.has("mac") and false or true,
        setwd = "nvim",
        open_pdf = "no",
        open_html = "no",
        pdfviewer = vim.fn.has("mac") == 0 and "zathura" or "open",
        synctex = false,
        listmethods = true,
        start_libs = vim.g.R_start_libs,
        quarto_preview_args = ', render = "html"',
        quarto_chunk_hl = {
          highlight = false,
          yaml_hl = true,
          virtual_title = true,
        },
        disable_cmds = {},
      }
      if opts.R_app == "radian" then
        opts.hl_term = false
        opts.Rout_more_colors = false
      end
      -- Check if the environment variable "R_AUTO_START" exists.
      -- If using fish shell, you could put in your config.fish:
      -- alias r "R_AUTO_START=true nvim"
      if vim.env.R_AUTO_START == "true" then
        opts.auto_start = 1
        opts.objbr_auto_start = true
      end

      return opts
    end,
    config = function(_, opts)
      vim.g.rout_follow_colorscheme = true
      require("r").setup(opts)
      require("r.pdf.generic").open = vim.ui.open
    end,
  },
  {
    "liubianshi/cmp-r",
    dev = true,
  },
}
