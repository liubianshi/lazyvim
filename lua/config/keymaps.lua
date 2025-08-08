-- stylua: ignore start

local keymap = require("util").keymap

-- Register ------------------------------------------------------------- {{{1
-- Change text without yanking it into a register.
keymap({ "c", '"_c', mode = { "n", "x" }, desc = "Change text without putting it into register" })

-- Navigation ----------------------------------------------------------- {{{1
-- Use display lines for vertical movement, which is more intuitive with wrapped lines.
keymap({ "j", "gj",  desc = "Display line downwards",          mode = { "n", "v" } })
keymap({ "k", "gk",  desc = "Display line upwards",            mode = { "n", "v" } })

-- Indent/un-indent visual selections and stay in visual mode.
keymap({ "<", "<gv", desc = "Shift selection line leftwards",  mode = "v"          })
keymap({ ">", ">gv", desc = "Shift selection line rightwords", mode = "v"          })

-- Buffer navigation
keymap({ "]b", "<cmd>bnext<cr>",       desc = "Next buffer"     })
keymap({ "[b", "<cmd>bprevious<cr>",   desc = "Previous buffer" })
keymap({ "]B", "<cmd>blast<cr>",       desc = "Last buffer"     })
keymap({ "[B", "<cmd>bfirst<cr>",      desc = "First buffer"    })

-- Tab navigation
keymap({ "]t", "<cmd>tabnext<cr>",     desc = "Next tab"        })
keymap({ "[t", "<cmd>tabprevious<cr>", desc = "Previous tab"    })
keymap({ "]T", "<cmd>tablast<cr>",     desc = "Last tab"        })
keymap({ "[T", "<cmd>tabfirst<cr>",    desc = "First tab"       })

-- In insert mode, wrap line before common punctuation.
keymap({ ";<enter>", '<esc>?\\v[,.:?")，。)，。：》”；？、」） ]<cr>:noh<cr>a<enter><esc>`^A', desc = "Wrap line before punctuation", mode = "i" })
keymap({ "<A-M>",    "<cmd>call utils#ShiftLine(line('.') + 1, col('.') - 1)<cr>",             desc = "Shift cursor To:", mode = "n"             })
keymap({ "<A-M>",    "<esc>:call utils#MoveCursorTo('')<cr>a",                                 desc = "Move cursor to:", mode = "i"              })
keymap({ "<A-m>",    "<cmd>call utils#MoveCursorTo()<cr>",                                     desc = "Move cursor To:", mode = { "n", "i" }     })

-- Visual mode pressing * or # searches for the current selection --------- {{{1
-- The command sequence gets the visual selection, escapes it for search,
-- and then performs the search.
keymap({ "*", ":<C-u>call utils#VisualSelection('', '')<CR>/<C-R>=@/<CR><CR>", desc = "Search for visual selection", mode = "v", })

-- Fold and add symbol -------------------------------------------------- {{{1
-- DRY principle: Use a loop to create similar keymaps.
for _, char in ipairs({ "-", "=", ".", "*" }) do
  -- Add fold markers with a separator line
  keymap({
    string.format("<leader>z%s", char),
    string.format('<cmd>call utils#AddFoldMark("%s")<cr>', char),
    desc = string.format("Add fold marker with '%s' separator", char)
  })
  -- Add a separator line
  keymap({
    string.format("<leader>a%s", char),
    string.format('<cmd>call utils#AddDash("%s")<cr>', char),
    desc = string.format("Add '%s' separator line", char)
  })
end

-- Add fold markers with levels
keymap({ "<leader>zf", "g_a <esc>3a{<esc>", desc = "Add Fold Marker" })
for i = 1, 3 do
  keymap({
    string.format("<leader>z%d", i),
    string.format("g_a <esc>3a{<esc>a%d<esc>", i),
    desc = string.format("Add Fold Marker level %d", i)
  })
end

-- diff ----------------------------------------------------------------- {{{1
-- which-key group for diff commands
keymap({ "<leader>d",  group = "Diff",                           icon = { icon = "",     hl = "WhichKeyIconOrange" } })
keymap({ "<leader>dl", "<cmd>diffget LOCAL<cr>:diffupdate<cr>",  desc = "Diffget Local"                               })
keymap({ "<leader>dr", "<cmd>diffget REMOTE<cr>:diffupdate<cr>", desc = "Diffget Remote",                             })

--- run ------------------------------------------------------------------ {{{1
keymap({ "<leader>o:", "<cmd>ToggleTerm<cr>",                    desc = "Open Terminal"                               })
keymap({ "<leader>ob", "<cmd>call utils#Status()<cr>",           desc = "Toggle Status Line"                          })
keymap({ "<leader>od", "<cmd>source $MYVIMRC<cr>",               desc = "Source VIMRC"                                })
keymap({
  "<leader>op",
  function()
    -- Change directory to the directory of the current file
    local current_file_path = vim.fn.expand("%:p:h")
    if vim.fn.isdirectory(current_file_path) == 1 then
      vim.cmd("cd " .. current_file_path)
      vim.notify("Changed directory to " .. current_file_path)
    end
  end,
  desc = "Change to Directory of Current File"
})
keymap({
  "<leader>oz",
  "<cmd>call utils#ToggleZenMode()<cr>",
  desc = "Toggle Zen Mode (diy)"
})
keymap({
  "<leader><enter>",
  "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>",
  desc = "Redraw / Clear hlsearch / Diff Update"
})

--- buffer --------------------------------------------------------------- {{{1
keymap({ "<leader>bD", "<cmd>Bclose!<cr>",        desc = "Delete Buffer (force)"      })
keymap({ "<leader>bp", "<cmd>bp<cr>",             desc = "Previous Buffer"            })
keymap({ "<leader>bn", "<cmd>bn<cr>",             desc = "Next Buffer"                })
keymap({ "<leader>bq", "<cmd>q<cr>",              desc = "Quit Buffer"                })
keymap({ "<leader>bQ", "<cmd>q!<cr>",             desc = "Quit Buffer (force)"        })
keymap({ "<leader>bl", "<cmd>BufferLinePick<cr>", desc = "Pick Buffer on BufferLine", })
keymap({ "<leader>bF", "<cmd>fclose<cr>",         desc = "Close Float buffer"         })

--- search -------------------------------------------------------------- {{{1
keymap({
  "<leader>og",
  function()
    vim.fn["utils#Extract_hl_group_link"]()
  end,
  desc = "Display Highlight Group",
})

--- insert special symbol ----------------------------------------------- {{{1
-- Mappings for inserting various symbols and Chinese punctuation in insert mode.
keymap({ "<localleader><space>", ";",                                  desc = "Semicolons: ;",                    mode = "i" })
keymap({ "<localleader>0",       "<C-v>u200b",                         desc = "Special Symbol: zero-width space", mode = "i" })
keymap({ "<localleader>)",       "<C-v>uFF08 <C-v>uFF09<C-o>F <c-o>x", desc = "Chinese Punctuation: （…）",       mode = "i" })
keymap({ "<localleader>]",       "<C-v>u300c <C-v>u300d<C-o>F <c-o>x", desc = "Chinese Punctuation: 「…」",       mode = "i" })
keymap({ "<localleader>}",       "<C-v>u201C <C-v>u201D<C-o>F <c-o>x", desc = "Chinese Punctuation: “…”",         mode = "i" })
keymap({ "<localleader>'",       "<C-v>u300c",                         desc = "Chinese Punctuation: 「",          mode = "i" })
keymap({ '<localleader>"',       "<C-v>u300d",                         desc = "Chinese Punctuation: 」",          mode = "i" })
keymap({ "<localleader>,",       "<C-v>uFF0C",                         desc = "Chinese Punctuation: ，",          mode = "i" })
keymap({ "<localleader>.",       "<C-v>u3002",                         desc = "Chinese Punctuation: 。",          mode = "i" })
keymap({ "<localleader>\\",      "<C-v>u3001",                         desc = "Chinese Punctuation: 、",          mode = "i" })
keymap({ "<localleader>:",       "<C-v>uff1a",                         desc = "Chinese Punctuation: ：",          mode = "i" })
keymap({ "<localleader>/",       "<C-v>uff1b",                         desc = "Chinese Punctuation: ；",          mode = "i" })
keymap({ "<localleader>_",       "<C-v>u2014<c-v>u2014",               desc = "Chinese Punctuation: ——",          mode = "i" })
keymap({ "<localleader>^",       "<C-v>u2026<c-v>u2026",               desc = "Chinese Punctuation: ……",          mode = "i" })
keymap({ "<localleader>?",       "<C-v>uff1f",                         desc = "Special Punctuation: ？",          mode = "i" })
keymap({ "<localleader>-",       "<C-v>u2014",                         desc = "Special Punctuation: —",           mode = "i" })

--- window manager ------------------------------------------------------ {{{1
keymap({ "w0",    "<cmd>88wincmd |<cr>",         desc = "Window: Suitable Width"           })
keymap({ "wt",    "<cmd>wincmd T<cr>",           desc = "Move Current Window to a New Tab" })
keymap({ "wo",    "<cmd>only<cr>",               desc = "Make current window the only one" })
keymap({ "wv",    "<c-w>v",                      desc = "Vertical Split Current Buffer"    })
keymap({ "ws",    "<c-w>s",                      desc = "Split Current Buffer"             })
keymap({ "wF",    "<cmd>fclose<cr>",             desc = "Close Float Buffer"               })
keymap({ "wh",    "<c-w>h",                      desc = "Move cursor to window left"       })
keymap({ "wj",    "<c-w>j",                      desc = "Move cursor to window below"      })
keymap({ "wk",    "<c-w>k",                      desc = "Move cursor to window above"      })
keymap({ "wl",    "<c-w>l",                      desc = "Move cursor to window right"      })
keymap({ "wH",    "<c-w>H",                      desc = "Move current window left"         })
keymap({ "wJ",    "<c-w>J",                      desc = "Move current window below"        })
keymap({ "wK",    "<c-w>K",                      desc = "Move current window above"        })
keymap({ "wL",    "<c-w>L",                      desc = "Move current window right"        })
keymap({ "wx",    "<c-w>x",                      desc = "Exchange window"                  })
keymap({ "wq",    "<c-w>q",                      desc = "Quit the current window"          })
keymap({ "w=",    "<c-w>=",                      desc = "Make Window size equally"         })
keymap({ "<c-j>", "<cmd>resize -2<cr>",          desc = "Decrease window height"           })
keymap({ "<c-k>", "<cmd>resize +2<cr>",          desc = "Increase window height"           })
keymap({ "<c-h>", "<cmd>vertical resize -2<cr>", desc = "Decrease window width"            })
keymap({ "<c-l>", "<cmd>vertical resize +2<cr>", desc = "Increase window width"            })
keymap({
  "wf",
  function()
    -- This requires a utility function to identify the highest z-index window (likely a float).
    -- Assumes `require("util.ui").get_highest_zindex_win()` exists.
    local popup_win_id = require("util.ui").get_highest_zindex_win()
    if popup_win_id then
      vim.fn.win_gotoid(popup_win_id)
    end
  end,
  desc = "Goto Float Buffer"
})

--- edit special files -------------------------------------------------- {{{1
-- Quick access to edit configuration files.
keymap({ "<leader>ev", "<cmd>Oil ~/.config/nvim/lua/plugins<cr>",                          desc = "Edit Neovim Plugins"   })
keymap({ "<leader>ek", "<cmd>edit ~/.config/nvim/lua/config/keymaps.lua<cr>",              desc = "Edit Neovim Keymaps"   })
keymap({ "<leader>ea", "<cmd>edit ~/.config/nvim/lua/config/autocmds.lua<cr>",             desc = "Edit Neovim Autocmds"  })
keymap({ "<leader>eo", "<cmd>edit ~/.config/nvim/lua/config/options.lua<cr>",              desc = "Edit Neovim Options"   })
keymap({ "<leader>ef", "<cmd>edit ~/.config/nvim/lua/global_functions.lua<cr>",            desc = "Edit Global Functions" })
keymap({ "<leader>er", "<cmd>edit ~/.Rprofile<cr>",                                        desc = "Edit R Profile"        })
keymap({ "<leader>es", "<cmd>edit ~/.config/stata/profile.do<cr>",                         desc = "Edit Stata profile"    })
keymap({ "<leader>ez", "<cmd>edit ~/.zshrc<cr>",                                           desc = "Edit .zshrc"           })
keymap({ "<leader>eZ", "<cmd>edit ~/useScript/usr.zshrc<cr>",                              desc = "Edit User .zshrc"      })
keymap({ "<leader>eu", "<cmd>edit ~/.config/nvim/UltiSnips<cr>",                           desc = "Edit Snippets"         })
keymap({ "<leader>et", "<cmd>edit +ToggleZenMode ~/Documents/Writing/plantodo.norg<cr>zt", desc = "Open Plan to Do"       })
keymap({ "<leader>eT", "<cmd>edit +$ ~/Documents/Writing/todo.norg<cr>zt",                 desc = "Open TODO list"        })
keymap({
  "<leader>ew",
  function()
    -- Assumes a `util` module with `get_daily_filepath` function exists.
    vim.cmd("edit " .. require("util").get_daily_filepath("md", "ReciteWords"))
  end,
  desc = "Open Daily English Notes"
})

--- Terminal ------------------------------------------------------------- {{{1
-- Mappings for toggleterm plugin.
keymap({ "<space><space>v", "<cmd>ToggleTerm direction=vertical<cr>",   desc = "Toggle Terminal (vertical)"   })
keymap({ "<space><space>s", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Toggle Terminal (horizontal)" })
keymap({ "<space><space>f", "<cmd>ToggleTerm direction=float<cr>",      desc = "Toggle Terminal (float)"      })
keymap({ "<space><space>t", "<cmd>ToggleTerm direction=tab<cr>",        desc = "Toggle Terminal (tab)"        })

-- Mappings to open a *new* terminal instance.
do
  local function new_term(direction)
    require("toggleterm.terminal").Terminal:new({ direction = direction }):toggle()
  end
  keymap({ "<space><space>V", function() new_term("vertical") end,   desc = "New Terminal (vertical)"   })
  keymap({ "<space><space>S", function() new_term("horizontal") end, desc = "New Terminal (horizontal)" })
  keymap({ "<space><space>F", function() new_term("float") end,      desc = "New Terminal (float)"      })
  keymap({ "<space><space>T", function() new_term("tab") end,        desc = "New Terminal (tab)"        })
end

-- Terminal mode mappings for easier navigation.
-- `<C-\\><C-n>` is the standard way to exit terminal mode.
if vim.fn.has("mac") == 1 then
  -- Mappings for macOS
  keymap({ "<c-space>", [[<C-\><C-n>]],       desc = "Exit terminal mode",          mode = "t" })
  keymap({ "<M-w>",     [[<C-\><C-n><C-w>]],  desc = "Terminal: wincmd prefix",     mode = "t" })
  keymap({ "∑",         [[<C-\><C-n><C-w>]],  desc = "Terminal: wincmd prefix",     mode = "t" })
  keymap({ "<M-h>",     [[<C-\><C-n><C-w>H]], desc = "Terminal: Move window left",  mode = "t" })
  keymap({ "˙",         [[<C-\><C-n><C-w>H]], desc = "Terminal: Move window left",  mode = "t" })
  keymap({ "<M-j>",     [[<C-\><C-n><C-w>J]], desc = "Terminal: Move window down",  mode = "t" })
  keymap({ "∆",         [[<C-\><C-n><C-w>J]], desc = "Terminal: Move window down",  mode = "t" })
  keymap({ "<M-k>",     [[<C-\><C-n><C-w>K]], desc = "Terminal: Move window up",    mode = "t" })
  keymap({ "˚",         [[<C-\><C-n><C-w>K]], desc = "Terminal: Move window up",    mode = "t" })
  keymap({ "<M-l>",     [[<C-\><C-n><C-w>L]], desc = "Terminal: Move window right", mode = "t" })
  keymap({ "¬",         [[<C-\><C-n><C-w>L]], desc = "Terminal: Move window right", mode = "t" })
else
  -- Mappings for other OS (Linux/Windows)
  keymap({ "<A-space>", [[<C-\><C-n>]],       desc = "Exit terminal mode",          mode = "t" })
  keymap({ "<A-w>",     [[<C-\><C-n><C-w>]],  desc = "Terminal: wincmd prefix",     mode = "t" })
  keymap({ "<A-h>",     [[<C-\><C-n><C-w>h]], desc = "Terminal: Move window left",  mode = "t" })
  keymap({ "<A-j>",     [[<C-\><C-n><C-w>j]], desc = "Terminal: Move window down",  mode = "t" })
  keymap({ "<A-k>",     [[<C-\><C-n><C-w>k]], desc = "Terminal: Move window up",    mode = "t" })
  keymap({ "<A-l>",     [[<C-\><C-n><C-w>l]], desc = "Terminal: Move window right", mode = "t" })
end
keymap({ ";j", [[<C-\><C-n>]], desc = "Exit terminal mode (alternative)", mode = "t" })

--- notifications ------------------------------------------------------- {{{1
keymap({ "<leader>hN", "<cmd>Redir Notifications<cr>", desc = "Redirect Notifications" })
keymap({ "<leader>hm", "<cmd>messages<cr>",            desc = "Display messages" })
keymap({ "<leader>hM", "<cmd>Redir messages<cr>",      desc = "Redirect messages" })

-- format --------------------------------------------------------------- {{{1
-- In insert mode, format the current paragraph and return to insert mode.
keymap({ "<localleader>w", "<esc>gqq}kA", desc = "Format Paragraph", mode = "i" })
keymap({ "<A-;>",          "<esc>gqq}kA", desc = "Format Paragraph", mode = "i" })

-- object --------------------------------------------------------------- {{{1
-- which-key groups for text objects
keymap({ "i", mode = { "x", "o" }, group = "Object: inner",  icon = { icon = "", hl = "WhichKeyIconOrange" } })
keymap({ "a", mode = { "x", "o" }, group = "Object: outter", icon = { icon = "", hl = "WhichKeyIconOrange" } })

-- Custom text objects
keymap({ "iB", "<cmd>call text_obj#Buffer()<cr>",         desc = "Object: Buffer",                     mode = { "x", "o" } })
keymap({ "iu", "<cmd>call text_obj#URL()<cr>",            desc = "Object: URL",                        mode = { "x", "o" } })
keymap({ "il", "^o$h",                                    desc = "Object: inner line",                 mode = "x" })
keymap({ "il", "<cmd>normal vil<cr>",                     desc = "Object: inner line",                 mode = "o" })
keymap({ "al", "^o$",                                     desc = "Object: around line (with \\n)",     mode = "x" })
keymap({ "al", "<cmd>normal val<cr>",                     desc = "Object: around line (with \\n)",     mode = "o" })
keymap({ "ic", "<cmd>call text_obj#MdCodeBlock('i')<cr>", desc = "Object: inner Markdown code block",  mode = { "o", "x" } })
keymap({ "ac", "<cmd>call text_obj#MdCodeBlock('a')<cr>", desc = "Object: around Markdown code block", mode = { "o", "x" } })

-- Translate ------------------------------------------------------------ {{{1
-- Helper to safely require the translate module
local function get_translate_module()
  local ok, trans = pcall(require, "translate")
  if not ok or not trans then
    vim.notify("Failed to load 'translate' module.", vim.log.levels.ERROR)
    return nil
  end
  return trans
end

keymap({
  "<F4>",
  function()
    local trans = get_translate_module()
    if not trans then
      return
    end

    if vim.api.nvim_get_mode().mode == "n" then
      if trans.toggle() == 0 then
        trans.translate_line()
      end
    else -- visual mode
      trans.translate_selection()
    end
  end,
  mode = { "n", "v" },
  desc = "Translate (toggle/line/selection)",
})

keymap({
  "L",
  function()
    local trans = get_translate_module()
    if trans then
      trans.trans_op()
    end
  end,
  desc = "Translate (operator)",
  mode = { "v", "n" }
})

keymap({
  "<localleader>l",
  function()
    local trans = get_translate_module()
    if trans then
      trans.replace_line()
    end
  end,
  desc = "Translate and replace line",
  mode = "i"
})

keymap({
  "LL",
  function()
    -- Assumes a `Snacks` module/plugin is available for user input.
    Snacks.input({ prompt = "Translate" }, function(value)
      if not value or value == "" then
        return
      end
      local trans = get_translate_module()
      if trans then
        trans.translate_content(value)
      end
    end)
  end,
  desc = "Translate (input)"
})

-- File manager --------------------------------------------------------- {{{1
keymap({ "<leader>fs", "<cmd>write<cr>",  desc = "Save File" })
keymap({ "<leader>fS", "<cmd>write!<cr>", desc = "Save File (force)" })

-- Picker --------------------------------------------------------------- {{{1
-- Assumes a 'pickers' module is available and configured.
local picker_ok, picker = pcall(require, "pickers")
if not picker_ok then
  vim.notify("Picker module not found, some keymaps will not work.", vim.log.levels.WARN)
  return -- Exit if pickers are essential and not found.
end

keymap({ "<leader>sP", picker.cliphist, desc = "System Clipboard History" })
keymap({ "<leader>hc", picker.cheat,           desc = "CheatSheet: TL;DR" })
keymap({ "<leader>fz", picker.fasd,            desc = "Jump with fasd" })
keymap({ "<leader>fq", picker.mylib,           desc = "Open my library file" })
keymap({ "<leader>hs", picker.stata_doc,       desc = "Stata help pages" })
keymap({
  "<leader>a/",
  picker.fabric,
  desc = "Fabric: use clipboard as input",
  mode = { "n", "v" },
  icon = { icon = "", hl = "WhichKeyIconOrange" },
})
keymap({
  "<leader>ic",
  function()
    require("pickers").citation()
  end,
  desc = "Insert Citation Keys"
})
keymap({
  "<localleader>ic",
  function()
    require("pickers").citation()
  end,
  desc = "Insert Citation Keys",
  mode = "i",
})
