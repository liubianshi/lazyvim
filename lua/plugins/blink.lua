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
    init = function()
      vim.system({
        vim.fn.executable("rime_ls") and "rime_ls" or vim.env.HOME .. "/.local/bin/rime_ls",
        "--listen",
        "127.0.0.1:9257",
      }, { detach = true })
    end,
    config = function(_, opts)
      require("rimels").setup(opts)
    end,
  },
  { -- "saghen/blink.cmp"
    "saghen/blink.cmp",
    build = "cargo build --release",
    opts = function(_, opts)
      local border = require("util").border("▔", "bottom")
      local config = {
        snippets = {
          preset = "luasnip",
        },
        keymap = {
          preset = "enter",
          ["<Tab>"] = { "snippet_forward", "select_next", "fallback" },
          ["<S-Tab>"] = { "snippet_backward", "select_prev", "fallback" },
        },
        completion = {
          accept = {
            auto_brackets = {
              enabled = true,
            },
          },
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
            selection = {
              preselect = false,
              auto_insert = true,
            },
          },
          menu = {
            border = border,
            auto_show = true,
            draw = {
              columns = { { "kind_icon" }, { "label", gap = 1 } },
              components = {
                label = {
                  text = function(ctx)
                    return require("colorful-menu").blink_components_text(ctx)
                  end,
                  highlight = function(ctx)
                    return require("colorful-menu").blink_components_highlight(ctx)
                  end,
                },
              },
            },
          },
        },
        appearance = {
          use_nvim_cmp_as_default = false,
          nerd_font_variant = "mono",
          kind_icons = {
            Text = "",
          },
        },
        cmdline = {
          enabled = true,
          sources = function()
            local type = vim.fn.getcmdtype()
            -- Search forward and backward
            if type == "/" or type == "?" then
              return { "buffer" }
            end
            -- Commands
            if type == ":" or type == "@" then
              return { "cmdline" }
            end
            return {}
          end,
        },
        sources = {
          compat = { "cmp_r" },
          per_filetype = {
            codecompanion = { "codecompanion", "lsp", "path", "snippets", "buffer" },
          },
          default = { "lazydev", "lsp", "path", "snippets", "buffer", "markdown" },
          providers = {
            lazydev = {
              fallbacks = { "lsp" },
            },
            cmp_r = {
              name = "cmp_r",
              module = "blink.compat.source",
              enabled = function()
                return vim.tbl_contains({ "r", "rmd", "quarto", "rdoc" }, vim.bo.filetype)
              end,
              fallbacks = { "lsp", "buffer" },
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
                    item.score_offset = item.score_offset - 3
                  end
                end
                -- you can define your own filter for rime item
                return items
              end,
            },
            markdown = {
              name = "RenderMarkdown",
              module = "render-markdown.integ.blink",
              fallbacks = { "lsp" },
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
  { -- xzbdmw/colorful-menu.nvim
    "xzbdmw/colorful-menu.nvim",
    config = true,
  },
}
