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
      require("rimels").setup(opts)
    end,
  },
  { -- "saghen/blink.cmp"
    "saghen/blink.cmp",
    dependencies = {
      "mikavilpas/blink-ripgrep.nvim",
    },
    build = "cargo build --release",
    opts = function()
      local border = require("util").border("▔", "bottom")
      local config = {
        enabled = function()
          local ft = vim.bo.filetype
          local filetypes = { "snacks_picker_input", "snacks_input" }
          if vim.tbl_contains(filetypes, ft) then
            return "force"
          else
            return true
          end
        end,
        fuzzy = {
          implementation = "prefer_rust_with_warning",
          sorts = {
            "exact",
            "score",
            "sort_text",
          },
        },
        snippets = {
          preset = "luasnip",
        },
        keymap = {
          preset = "default",
          ["<c-l>"] = {
            function(cmp)
              if cmp.snippet_active() then
                return cmp.accept()
              end
              if cmp.get_selected_item() then
                return cmp.accept_and_enter()
              end
              if cmp.is_visible() then
                local items = cmp.get_items()
                if not items or #items == 0 then
                  return
                end

                local first_snippet_number
                for i, item in ipairs(items) do
                  if item.source_id == "snippets" then
                    first_snippet_number = i
                    break
                  end
                end

                if first_snippet_number then
                  return cmp.accept({ index = first_snippet_number })
                end

                return
              end
            end,
            "fallback_to_mappings",
          },
          ["<Tab>"] = {
            "select_next",
            "fallback_to_mappings",
          },
          ["<S-Tab>"] = { "select_prev", "fallback_to_mappings" },
        },
        completion = {
          ghost_text = {
            enabled = true,
          },
          accept = {
            auto_brackets = {
              enabled = true,
            },
          },
          trigger = {
            prefetch_on_insert = false,
          },
          documentation = {
            window = { border = border },
            auto_show = true,
            auto_show_delay_ms = 200,
          },
          keyword = {
            range = "prefix",
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
        signature = {
          enabled = true,
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
          keymap = {
            preset = "cmdline",
            ["<cr>"] = {
              function(cmp)
                if cmp.is_menu_visible() and cmp.get_selected_item() then
                  if vim.fn.getcmdpos() > #vim.fn.getcmdline() then
                    return cmp.accept_and_enter()
                  else
                    return cmp.accept()
                  end
                end
                if cmp.is_menu_visible then
                  cmp.cancel()
                end
              end,
              "fallback",
            },
            ["<Left>"] = {
              function(cmp)
                if cmp.is_menu_visible() then
                  cmp.cancel()
                end
              end,
              "fallback",
            },
            ["<Right>"] = {
              function(cmp)
                if cmp.is_menu_visible() then
                  cmp.cancel()
                end
              end,
              "fallback",
            },
            ["<Up>"] = { "select_prev", "fallback" },
            ["<Down>"] = { "select_next", "fallback" },
          },
          completion = {
            ghost_text = { enabled = true },
            menu = {
              auto_show = true,
            },
            list = {
              selection = {
                preselect = false,
                auto_insert = true,
              },
            },
          },
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
          per_filetype = {
            codecompanion = { inherit_defaults = true, "codecompanion" },
            org = { inherit_defaults = true, "orgmode" },
            r = { inherit_defaults = true, "cmp_r" },
            stata = { inherit_defaults = true, "omni" },
            vim = { inherit_defaults = true, "cmdline" },
            snacks_picker_input = { "lsp" },
            snacks_input = { "lsp" },
            lua = { inherit_defaults = true, "lazydev" },
            markdown = {
              "obsidian",
              "obsidian_new",
              "obsidian_tags",
              "markdown",
              "lsp",
              "path",
              "snippets",
              "buffer",
              "ripgrep",
            },
          },
          default = { "lsp", "path", "snippets", "buffer", "ripgrep" },
          providers = {
            buffer = {
              enabled = function()
                return vim.bo.buftype ~= "prompt"
              end,
            },
            lazydev = {
              name = "LazyDev",
              enabled = function()
                return vim.bo.buftype ~= "prompt"
              end,
              module = "lazydev.integrations.blink",
              fallbacks = { "lsp" },
            },
            snippets = {
              enabled = function()
                return vim.bo.buftype ~= "prompt"
              end,
              opts = {
                use_show_condition = true,
                show_autosnippets = false,
              },
              min_keyword_length = 2,
            },
            orgmode = {
              name = "Orgmode",
              module = "orgmode.org.autocompletion.blink",
              fallbacks = { "buffer" },
            },
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
              override = {
                get_trigger_characters = function()
                  return { ".", "$", ":" }
                end,
              },
              async = true,
            },
            lsp = {
              enabled = true,
              transform_items = function(_, items)
                local transformed_items = vim.tbl_filter(function(item)
                  return item.kind ~= require("blink.cmp.types").CompletionItemKind.Text
                    or (item.source_id == "lsp" and vim.lsp.get_client_by_id(item.client_id).name == "rime_ls")
                end, items)
                -- the default transformer will do this
                for _, item in ipairs(transformed_items) do
                  if item.kind == require("blink.cmp.types").CompletionItemKind.Snippet then
                    item.score_offset = item.score_offset - 3
                  elseif
                    item.kind == require("blink.cmp.types").CompletionItemKind.Text
                    and item.source_id == "lsp"
                    and vim.lsp.get_client_by_id(item.client_id).name == "rime_ls"
                  then
                    item.score_offset = item.score_offset
                  end
                end
                -- you can define your own filter for rime item
                return transformed_items
              end,
            },
            markdown = {
              name = "RenderMarkdown",
              module = "render-markdown.integ.blink",
              fallbacks = { "lsp" },
            },
            path = {
              opts = {
                trailing_slash = false,
                get_cwd = function(_)
                  return vim.uv.cwd()
                end,
              },
            },
            ripgrep = {
              module = "blink-ripgrep",
              name = "Ripgrep",
              opts = {
                project_root_marker = { ".git", "NAMESPACE", ".root", "_metadata.yml" },
                backend = {
                  ripgrep = {
                    max_filesize = "200K",
                    project_root_fallback = false,
                  },
                },
              },
            },
          },
        },
      }
      return config
    end,
    config = function(_, opts)
      require("blink.cmp").setup(opts)
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
