return {
  { -- "liubianshi/cmp-lsp-rimels"
    "liubianshi/cmp-lsp-rimels",
    keys = { { "<localleader>f", mode = "i" } },
    branch = "blink.cmp",
    lazy = true,
    dev = true,
    priority = 100,
    opts = {
      keys = { start = ";f", stop = ";;", esc = ";j" },
      cmd = vim.lsp.rpc.connect("127.0.0.1", 9257),
      always_incomplete = false,
      schema_trigger_character = "&",
      cmp_keymaps = {
        disable = {
          space = false,
          numbers = false,
          enter = false,
          brackets = false,
          backspace = false,
        },
      },
    },
    config = function(_, opts)
      vim.system({ vim.env.HOME .. "/.local/bin/rime_ls", "--listen", "127.0.0.1:9257" }, { detach = true })
      require("rimels").setup(opts)
    end,
  },
  { -- "saghen/blink.cmp"
    "saghen/blink.cmp",
    build = "cargo build --release",
    opts = function(_, opts)
      local border = require("util").border("▔", "bottom")
      local config = {
        keymap = {
          preset = "none",
          ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
          ["<Tab>"] = { "select_next", "fallback" },
          ["<S-Tab>"] = { "select_prev", "fallback" },
          ["<C-p>"] = { "scroll_documentation_up", "fallback" },
          ["<C-n>"] = { "scroll_documentation_down", "fallback" },
          ["<C-e>"] = { "hide", "fallback" },
          ["<CR>"] = { "accept", "fallback" },
        },
        completion = {
          documentation = {
            window = { border = border },
            auto_show = true,
            auto_show_delay_ms = 200,
          },
          keyword = {
            range = "prefix",
            -- regex = "[_,:\\?!]\\|[A-Za-z0-9]",
          },
          list = {
            selection = function(ctx)
              return ctx.mode == "cmdline" and "auto_insert" or "preselect"
            end,
          },
          menu = {
            border = border,
            auto_show = true,
            draw = {
              treesitter = { "lsp" },
            },
          },
        },
        appearance = {
          use_nvim_cmp_as_default = true,
          nerd_font_variant = "mono",
          kind_icons = {
            Text = "",
          },
        },
        sources = {
          default = { "lazydev", "lsp", "path", "snippets", "buffer", "cmp_r" },
          providers = {
            cmp_r = {
              name = "cmp_r",
              module = "blink.compat.source",
              enabled = function()
                return vim.tbl_contains({ "r", "rmd", "quarto", "rdoc" }, vim.bo.filetype)
              end,
              opts = {
                trigger_characters = { " ", ":", "(", '"', "@", "$" },
                keyword_pattern = "[-`\\._@\\$:_[:digit:][:lower:][:upper:]]*",
              },
            },
            lsp = {
              enabled = true,
              transform_items = function(_, items)
                -- the default transformer will do this
                for _, item in ipairs(items) do
                  if item.kind == require("blink.cmp.types").CompletionItemKind.Snippet then
                    item.score_offset = item.score_offset - 3
                  end
                  if
                    item.kind == require("blink.cmp.types").CompletionItemKind.Text
                    and item.source_id == "lsp"
                    and vim.lsp.get_client_by_id(item.client_id).name == "rime_ls"
                  then
                    item.score_offset = 99
                  end
                end
                -- you can define your own filter for rime item
                return items
              end,
            },
          },
        },
      }
      return vim.tbl_deep_extend("force", opts, config)
    end,
  },
  { -- "saghen/blink.compat"
    "saghen/blink.compat",
    lazy = true,
    opts = {},
  },
}
