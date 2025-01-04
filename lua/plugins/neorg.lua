return {
  "nvim-neorg/neorg",
  version = "*",
  ft = { "norg" },
  cmd = { "Neorg" },
  keys = {
    {
      "<leader>ej",
      "<cmd>Neorg journal today<cr>",
      desc = "Open today's journal",
    },
  },
  config = function()
    -- register keybinds ---------------------------------------------------- {{{1
    local status_ok, wk = pcall(require, "which-key")
    if status_ok then
      wk.add({
        { "<localleader>i", group = "Insert" },
        { "<localleader>l", group = "List" },
        { "<localleader>m", group = "Move" },
        { "<localleader>n", group = "Note" },
        { "<localleader>s", group = "search node" },
        { "<localleader>t", group = "Task" },
      })
    end

    local image_render_exist = function()
      PlugExist("image.nvim")
    end

    local get_modules = function()
      local modules = {
        ["core.defaults"] = {},
        ["core.esupports.hop"] = {},
        ["core.esupports.indent"] = {},
        ["core.esupports.metagen"] = {},
        ["core.keybinds"] = {
          config = {
            default_keybinds = true,
          },
        },
        ["core.summary"] = {},
        ["core.completion"] = {
          config = {
            engine = "nvim-cmp",
          },
        },
        ["core.export"] = {},
        ["core.export.markdown"] = {
          config = {
            extension = "md",
            extensions = "all",
            ["metadata"] = {
              ["end"] = "---",
              ["start"] = "---",
            },
          },
        },
        ["core.journal"] = {
          config = {
            journal_folder = "norg-journal",
            workspace = "journal",
          },
        },
        ["core.concealer"] = {
          config = {
            icons = {
              heading = {
                icons = { "󰉫", "󰉬", "󰉭", "󰉮", "󰉯", "󰉰" },
              },
              ordered = {
                icons = { "1", "A", "a", "⑴", "Ⓐ", "ⓐ" },
              },
              list = {
                -- icons = { "", "", "󰻂", "", "󱥸", "" },
                icons = { "󰻂", "󰻂", "󰻂", "󰻂", "󰻂", "󰻂" },
              },
            },
          },
        },
        ["core.dirman"] = {
          config = {
            workspaces = {
              lbs = "~/Documents/Writing/Norg",
              journal = "~/Documents/Writing/journal",
              meeting = "~/Documents/Writing/meeting",
            },
          },
        },
      }

      if image_render_exist() then
        modules["core.latex.renderer"] = {
          renderer = "core.integrations.image",
          render_on_enter = true,
          dpi = 600,
          scale = 0.5,
        }
      end
      return modules
    end

    -- setup ---------------------------------------------------------------- {{{1
    require("neorg").setup({
      load = get_modules(),
    })

    --- keybinds ------------------------------------------------------------ {{{1
    local kmap = function(key, cmd, opts)
      opts = vim.tbl_extend("keep", opts or {}, {
        silent = true,
        noremap = true,
        buffer = true,
      })
      local mode = opts.mode or "n"
      opts.mode = nil
      vim.keymap.set(mode, key, cmd, opts)
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("LBS_Neorg_Keymaps", { clear = true }),
      pattern = "norg",
      callback = function()
        kmap("<localleader>sH", "<cmd>Neorg toc qflist<cr>", { desc = "Search Headings through qflist" })
        kmap(
          "<localleader>o",
          "<cmd>Neorg keybind all core.looking-glass.magnify-code-block<cr>",
          { desc = "Edit Code Chunk" }
        )
        kmap("<localleader>S", "<cmd>Neorg generate-workspace-summary<cr>", { desc = "Display Summary" })
        kmap("<localleader>nj", "<cmd>Neorg journal today<cr>", { desc = "Open today's journal" })
        kmap("<localleader>ni", "<cmd>Neorg index<cr>", { desc = "Return to Index Page" })
        kmap(
          "<cr>",
          "<Plug>(neorg.esupports.hop.hop-link)",
          { mode = "n", desc = "hop to the destination of the link under the cursor" }
        )
      end,
    })
  end,
}
