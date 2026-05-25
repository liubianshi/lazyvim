local M                 = {}

local CITEKEY_CHARS     = "[%w_%-]"
local DEFAULT_FILETYPES = { "markdown", "quarto", "rmd", "rmarkdown" }

local preview           = { buf = -1, win = -1, citekey = nil }
local help_win          = { buf = -1, win = -1 }

-- Wrapper around vim.notify with a fixed "schola" title
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "schola" })
end

-- Close a floating window tracked by a state table {buf, win}
local function close_state(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = -1
  state.buf = -1
end

-- Return the citekey (no leading @) under the cursor, or nil
local function citekey_under_cursor()
  local line = vim.api.nvim_get_current_line()
  if line == "" then return nil end

  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- Walk left from cursor to find the @ that starts this citekey
  local anchor = col
  if line:sub(anchor, anchor) ~= "@" then
    while anchor > 1 and line:sub(anchor, anchor):match(CITEKEY_CHARS) do
      anchor = anchor - 1
    end
    if line:sub(anchor, anchor) ~= "@" then return nil end
  end

  local right = anchor + 1
  while right <= #line and line:sub(right, right):match(CITEKEY_CHARS) do
    right = right + 1
  end

  local key = line:sub(anchor + 1, right - 1)
  return key ~= "" and key or nil
end

-- Open a centered floating window with the given lines; returns buf, win
-- opts: lines, title, filetype, zindex
local function open_float(opts)
  local lines = opts.lines
  if lines[#lines] == "" then table.remove(lines) end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype   = opts.filetype or "markdown"
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].bufhidden  = "wipe"
  vim.bo[buf].modifiable = false

  local max_w            = math.floor(vim.o.columns * 0.8)
  local max_h            = math.floor(vim.o.lines * 0.75)
  local width            = 60
  for _, l in ipairs(lines) do
    width = math.max(width, math.min(vim.fn.strdisplaywidth(l) + 4, max_w))
  end
  local height              = math.max(5, math.min(#lines + 2, max_h))

  local win                 = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = height,
    row       = math.floor((vim.o.lines - height) / 2),
    col       = math.floor((vim.o.columns - width) / 2),
    style     = "minimal",
    border    = "rounded",
    title     = opts.title and (" " .. opts.title .. " ") or nil,
    title_pos = "center",
    zindex    = opts.zindex or 60,
  })
  vim.wo[win].wrap          = true
  vim.wo[win].linebreak     = true
  vim.wo[win].conceallevel  = 2
  vim.wo[win].concealcursor = "nvic"
  vim.wo[win].cursorline    = true
  return buf, win
end

-- Run `schola <args>` asynchronously; calls on_done(obj) on the main thread
local function run_schola(args, on_done)
  local cmd = { "schola" }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true }, function(obj)
    vim.schedule(function() on_done(obj) end)
  end)
end

-- Run schola and emit a success notification or an error notification
local function run_and_notify(args, success_msg)
  run_schola(args, function(obj)
    if obj.code == 0 then
      notify(success_msg)
    else
      local err = (obj.stderr ~= "" and obj.stderr) or obj.stdout or "unknown error"
      notify("schola failed: " .. err, vim.log.levels.ERROR)
    end
  end)
end

-- Prompt for text input; calls fn(input) only when input is non-empty
local function with_input(prompt, default, fn)
  vim.ui.input({ prompt = prompt, default = default or "" }, function(input)
    if input and input ~= "" then fn(input) end
  end)
end

-- Yes/No confirmation prompt; calls fn() only on "Yes"
local function with_confirm(prompt, fn)
  vim.ui.select({ "No", "Yes" }, { prompt = prompt }, function(choice)
    if choice == "Yes" then fn() end
  end)
end

-- Forward declarations (actions <-> show_help/refresh_preview are mutually recursive)
local actions, show_help, bind_actions, refresh_preview

-- Toggle a floating help window listing all keymaps
show_help = function()
  if help_win.win and vim.api.nvim_win_is_valid(help_win.win) then
    close_state(help_win)
    return
  end
  local lines = { "# Schola actions", "" }
  for _, a in ipairs(actions) do
    table.insert(lines, string.format("- `%-5s`  %s", a.key, a.desc))
  end
  local buf, win = open_float({
    lines    = lines,
    title    = "Schola Help",
    filetype = "markdown",
    zindex   = 70,
  })
  help_win.buf, help_win.win = buf, win
  local close = function() close_state(help_win) end
  for _, k in ipairs({ "q", "<Esc>", "g?", "<CR>" }) do
    vim.keymap.set("n", k, close, { buffer = buf, nowait = true, silent = true })
  end
end

-- Pipe `schola util show <citekey>` through glow in a floating terminal.
-- NO_COLOR=1 strips schola's ANSI so glow gets pure markdown and owns all colouring.
local function open_glow_preview(citekey)
  close_state(preview)

  local width                               = math.floor(vim.o.columns * 0.85)
  local height                              = math.floor(vim.o.lines * 0.8)

  local buf                                 = vim.api.nvim_create_buf(false, true)
  local win                                 = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = height,
    row       = math.floor((vim.o.lines - height) / 2),
    col       = math.floor((vim.o.columns - width) / 2),
    style     = "minimal",
    border    = "rounded",
    title     = " @" .. citekey .. " ",
    title_pos = "center",
    zindex    = 60,
  })
  vim.wo[win].wrap                          = false
  vim.wo[win].cursorline                    = false
  vim.wo[win].sidescrolloff                 = 4

  preview.buf, preview.win, preview.citekey = buf, win, citekey
  bind_actions(buf, citekey)

  local shell_cmd = string.format(
    "NO_COLOR=1 schola util show %s | glow -s auto -w %d -",
    vim.fn.shellescape(citekey), width - 2
  )
  vim.fn.jobstart({ "sh", "-c", shell_cmd }, {
    term = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if not (preview.buf == buf and vim.api.nvim_buf_is_valid(buf)) then return end
        vim.bo[buf].bufhidden = "wipe"
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
        end
        if code ~= 0 then
          notify("schola | glow exited " .. code, vim.log.levels.WARN)
        end
        bind_actions(buf, citekey)
      end)
    end,
  })
end

-- Show a citation preview: glow floating terminal if available, plain float otherwise
refresh_preview = function(citekey)
  if vim.fn.executable("glow") == 1 then
    open_glow_preview(citekey)
    return
  end

  notify("Loading @" .. citekey .. " ...")
  run_schola({ "util", "show", citekey }, function(obj)
    if obj.code ~= 0 then
      local err = (obj.stderr ~= "" and obj.stderr) or "no output"
      notify(("util show %s: %s"):format(citekey, err), vim.log.levels.ERROR)
      return
    end
    close_state(preview)
    local buf, win = open_float({
      lines    = vim.split(obj.stdout or "", "\n"),
      title    = "@" .. citekey,
      filetype = "markdown",
    })
    preview.buf, preview.win, preview.citekey = buf, win, citekey
    bind_actions(buf, citekey)
  end)
end

-- Action table: drives both bind_actions keymaps and the help listing.
-- fn(citekey) is the signature; close actions simply ignore the argument.
actions = {
  { key = "g?",    desc = "Show this help",  fn = show_help },
  { key = "q",     desc = "Close preview",   fn = function() close_state(preview) end },
  { key = "<Esc>", desc = "Close preview",   fn = function() close_state(preview) end },
  { key = "R",     desc = "Refresh preview", fn = refresh_preview },
  {
    key = "y",
    desc = "Yank @citekey to system clipboard",
    fn = function(ck)
      vim.fn.setreg("+", "@" .. ck)
      notify("Yanked @" .. ck)
    end,
  },
  {
    key = "Y",
    desc = "Yank bare citekey to system clipboard",
    fn = function(ck)
      vim.fn.setreg("+", ck)
      notify("Yanked " .. ck)
    end,
  },
  {
    key = "i",
    desc = "Switch to detailed YAML view (query refs)",
    fn = function(ck)
      run_schola({ "query", "refs", "--uid", ck }, function(obj)
        if obj.code ~= 0 then
          notify("query refs failed: " .. (obj.stderr or "?"), vim.log.levels.ERROR)
          return
        end
        close_state(preview)
        local buf, win = open_float({
          lines    = vim.split(obj.stdout or "", "\n"),
          title    = "@" .. ck .. "  (refs)",
          filetype = "yaml",
        })
        preview.buf, preview.win, preview.citekey = buf, win, ck
        bind_actions(buf, ck)
      end)
    end,
  },
  {
    key = "s",
    desc = "Sync ref with personal library",
    fn = function(ck) run_and_notify({ "ref", "sync", ck }, "Synced @" .. ck) end,
  },
  {
    key = "a",
    desc = "Annotate (append a note to refs.yaml)",
    fn = function(ck)
      with_input("Note for @" .. ck .. ": ", nil, function(note)
        run_and_notify({ "ref", "annotate", ck, "--note", note }, "Annotated @" .. ck)
      end)
    end,
  },
  {
    key = "r",
    desc = "Read fulltext with a purpose (LLM, opens terminal)",
    fn = function(ck)
      with_input("Purpose for ref read @" .. ck .. ": ", nil, function(purpose)
        close_state(preview)
        vim.cmd(("botright 15split | terminal schola ref read %s --purpose %s"):format(
          vim.fn.shellescape(ck), vim.fn.shellescape(purpose)
        ))
      end)
    end,
  },
  {
    key = "D",
    desc = "Remove ref from refs.yaml (asks to confirm)",
    fn = function(ck)
      with_confirm("Delete @" .. ck .. " from refs.yaml?", function()
        run_and_notify({ "ref", "remove", ck, "--write" }, "Removed @" .. ck)
      end)
    end,
  },
}

-- Bind all actions to buf, forwarding citekey as the first argument
bind_actions = function(buf, citekey)
  for _, a in ipairs(actions) do
    vim.keymap.set("n", a.key, function() a.fn(citekey) end, {
      buffer = buf,
      nowait = true,
      silent = true,
      desc   = "schola: " .. a.desc,
    })
  end
end

-- Return true if any attached LSP client advertises textDocument/hover
local function buffer_has_lsp_hover(bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method("textDocument/hover") then return true end
  end
  return false
end

-- K-like entry point: schola citation → LSP hover → native K fallback.
-- `:normal! K` (bang) skips our own mapping, invoking Vim's built-in K.
function M.show_under_cursor()
  local citekey = citekey_under_cursor()
  if citekey then
    refresh_preview(citekey)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if buffer_has_lsp_hover(bufnr) then
    vim.lsp.buf.hover()
    return
  end

  local ok, err = pcall(vim.cmd, "normal! K")
  if not ok then notify(err, vim.log.levels.WARN) end
end

-- Plugin entry point; opts.keymap (default "K"), opts.filetypes (default markdown/quarto/rmd)
function M.setup(opts)
  opts            = opts or {}
  local keymap    = opts.keymap or "K"
  local filetypes = opts.filetypes or DEFAULT_FILETYPES

  if vim.fn.executable("schola") == 0 then return end

  local function install(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    if not vim.tbl_contains(filetypes, vim.bo[bufnr].filetype) then return end
    vim.keymap.set("n", keymap, M.show_under_cursor, {
      buffer = bufnr,
      desc   = "Schola: preview citation (fallback: LSP hover → keywordprg)",
    })
  end

  local group = vim.api.nvim_create_augroup("LBS_Schola", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group    = group,
    pattern  = filetypes,
    callback = function(ev) install(ev.buf) end,
  })

  -- Re-install after LspAttach so LazyVim's K = vim.lsp.buf.hover doesn't win.
  -- vim.schedule defers until after all synchronous LspAttach handlers have run.
  vim.api.nvim_create_autocmd("LspAttach", {
    group    = group,
    callback = function(ev)
      vim.schedule(function() install(ev.buf) end)
    end,
  })
end

return M
