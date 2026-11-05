local M = {}

local function set_options(buf)
  vim.bo[buf].cindent = false
  vim.bo[buf].smartindent = false
  vim.bo[buf].formatprg = "mdwrap --tonewsboat"
  vim.bo[buf].formatexpr = ""
  vim.bo[buf].formatoptions = vim.bo[buf].formatoptions:gsub("q", "")

  local win = vim.api.nvim_get_current_buf() == buf and vim.api.nvim_get_current_win() or vim.fn.bufwinid(buf)
  if win ~= -1 then
    vim.wo[win].wrap = false
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].scrolloff = 10
  end
end

local function clean_article(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local changed = false
  for index, line in ipairs(lines) do
    local cleaned = line
    if cleaned:match("^%s+$") then
      cleaned = ""
    else
      while cleaned:sub(1, #"　") == "　" do
        cleaned = cleaned:sub(#"　" + 1)
      end
    end
    if cleaned ~= line then
      lines[index] = cleaned
      changed = true
    end
  end
  if changed then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
end

local function set_keymaps(buf)
  local links = require("newsboat.links")
  local notes = require("newsboat.notes")
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
  end

  map("n", "q", "<cmd>wq<cr>", "Save and close article")
  map("n", "<localleader>s", "<cmd>Mylib new<cr>", "Create mylib entry")
  map("n", "<localleader>e", "<cmd>Mylib edit<cr>", "Edit mylib entry")
  map("n", "<localleader>n", "<cmd>Mylib note<cr>", "Open mylib note")
  map("n", "<localleader>O", "<cmd>Urlopen<cr>", "Open article URL")
  map("n", "<localleader>o", function()
    vim.cmd('normal! "+yiu')
    vim.fn["utils#OpenUrl"](vim.fn.getreg("+"), "in")
  end, "Open URL inside article")
  map("x", "<localleader>y", function()
    vim.cmd('normal! "+y')
    notes.send_clipboard("quiet", buf)
  end, "Copy selection to mylib note")
  map("x", "N", function()
    vim.cmd('normal! "+y')
    notes.send_clipboard("split", buf)
  end, "Copy selection and open mylib note")
  map("n", "<localleader>y", function()
    vim.cmd('normal! vip"+y')
    notes.send_clipboard("quiet", buf)
  end, "Copy paragraph to mylib note")
  map("n", "<localleader>q", "<cmd>Bclose<cr>", "Close article buffer")
  map("n", "<Enter>", function()
    links.open_under_cursor(buf)
  end, "Open newsboat link")
  map("n", "<S-Enter>", function()
    notes.send_link_citation(-1, buf)
  end, "Cite newsboat link")
  map("n", "<localleader>t", function()
    require("lbs.ui.popup").mylib_tag()
  end, "Edit mylib tags")
  map("n", "#", function()
    links.open(vim.v.count1, buf)
  end, "Open numbered newsboat link")
end

function M.setup(_) end

function M.on_attach(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  set_options(buf)
  set_keymaps(buf)
  if vim.b[buf].newsboat_attached then
    return
  end
  vim.b[buf].newsboat_attached = true

  local links = require("newsboat.links")
  links.generate(buf)
  vim.api.nvim_buf_call(buf, function()
    vim.fn["utils#Fetch_urls"]()
  end)
  links.cache_snapshot(buf)
  clean_article(buf)
  vim.api.nvim_buf_call(buf, function()
    vim.fn["utils#ToggleZenMode"]()
  end)
end

return M
