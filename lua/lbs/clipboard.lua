-- 剪贴板 provider 决策。
--
-- The question this module answers is deliberately *not* "am I on the far end
-- of an SSH connection?".  That is a snapshot taken at login: SSH_TTY and
-- friends are injected once and then frozen into whatever session inherits
-- them.  Under a session-persistence multiplexer (zmx, tmux, screen) the same
-- session outlives the connection that created it, so the snapshot goes stale
-- -- attach from a different client and the variables still describe the *old*
-- client.  That staleness is the whole reason clipboard support here felt
-- intermittent.
--
-- So the decision is driven by reachability instead, and the two mistakes are
-- weighted asymmetrically:
--
--   * picking OSC 52 when the native path would also have worked costs almost
--     nothing -- kitty and friends handle OSC 52 locally just fine;
--   * picking the native path on a remote host silently copies into the
--     *remote* machine's clipboard, which the user can never reach.
--
-- Therefore anything short of positive evidence that a *local* clipboard is
-- reachable falls through to OSC 52.
--
-- 设置 vim.g.clipboard 命中 $VIMRUNTIME/autoload/provider/clipboard.vim
-- 的最高优先级分支，绕过工具存在性探测顺序——否则它会在轮到 OSC 52 之前
-- 先选中 lemonade / 转发的 $DISPLAY / tmux load-buffer。

local M = {}

-- Last payload handed to OSC 52, so paste can answer from memory instead of
-- querying the terminal (the OSC 52 read query blocks for up to 10s on
-- terminals that refuse to answer it -- see vim/ui/clipboard/osc52.lua).
local last_copy = nil

--- Signals feeding the decision, kept as one table so :ClipboardDiag can print
--- exactly what M.decide() saw.
--- @return table
local function collect()
  local env = vim.env
  local s = {
    ssh_tty = env.SSH_TTY,
    ssh_connection = env.SSH_CONNECTION,
    ssh_client = env.SSH_CLIENT,
    zmx_session = env.ZMX_SESSION,
    tmux = env.TMUX,
    sty = env.STY,
    term = env.TERM,
    wayland_display = env.WAYLAND_DISPLAY,
    display = env.DISPLAY,
    xdg_runtime_dir = env.XDG_RUNTIME_DIR,
  }

  s.multiplexer = (s.zmx_session and "zmx") or (s.tmux and "tmux") or (s.sty and "screen") or nil
  s.ssh_env = (s.ssh_tty or s.ssh_connection or s.ssh_client) ~= nil

  -- stdin's pty, e.g. /dev/pts/3.  Only meaningful when stdin really is a
  -- terminal -- it is a pipe under --headless or `cmd | nvim -` -- and only
  -- outside a multiplexer: a multiplexer always hands its child a freshly
  -- allocated pty, so a mismatch there proves nothing.
  local link = (vim.uv or vim.loop).fs_readlink("/proc/self/fd/0")
  s.tty = (link and link:match("^/dev/pts/%d+$")) and link or nil
  s.ssh_tty_stale = s.ssh_tty ~= nil and s.multiplexer == nil and s.tty ~= nil and s.ssh_tty ~= s.tty

  -- A Wayland compositor we can actually talk to: the socket must exist, not
  -- merely be named by the environment.
  s.wayland_socket = nil
  if s.wayland_display then
    local path = s.wayland_display:sub(1, 1) == "/" and s.wayland_display
      or (s.xdg_runtime_dir and string.format("%s/%s", s.xdg_runtime_dir, s.wayland_display))
    if path and (vim.uv or vim.loop).fs_stat(path) then
      s.wayland_socket = path
    end
  end

  -- A forwarded X display ("localhost:10.0", "host:10.0") is a tunnel back to
  -- the local machine, so it is *not* evidence of a local clipboard; a bare
  -- ":0" backed by its unix socket is.
  s.x_forwarded = s.display ~= nil and s.display:match("^[^:]+:") ~= nil
  s.x_socket = nil
  if s.display and not s.x_forwarded then
    local n = s.display:match("^:(%d+)")
    local path = n and string.format("/tmp/.X11-unix/X%s", n)
    if path and (vim.uv or vim.loop).fs_stat(path) then
      s.x_socket = path
    end
  end

  s.has_wl_copy = vim.fn.executable("wl-copy") == 1
  s.has_x_tool = vim.fn.executable("xsel") == 1 or vim.fn.executable("xclip") == 1

  s.local_clipboard = (s.wayland_socket ~= nil and s.has_wl_copy) or (s.x_socket ~= nil and s.has_x_tool)

  return s
end

--- @param s table signals from collect()
--- @return "native"|"osc52" mode, string reason
local function decide(s)
  if s.ssh_env then
    return "osc52",
      s.ssh_tty_stale and "SSH env present (stale SSH_TTY -- session outlived its client)" or "SSH env present"
  end
  if s.local_clipboard then
    return "native", string.format("local clipboard reachable via %s", s.wayland_socket or s.x_socket)
  end
  return "osc52", s.x_forwarded and "no local clipboard ($DISPLAY is forwarded)" or "no local clipboard reachable"
end

--- Answer from the last OSC 52 copy; fall back to the unnamed register so a
--- paste right after startup still yields something.  Returning
--- { lines, regtype } rather than bare lines preserves blockwise yanks; see the
--- get() handler in clipboard.vim.
local function paste_fallback()
  return function()
    if last_copy then
      return { last_copy.lines, last_copy.regtype }
    end
    local info = vim.fn.getreginfo('"')
    return { info.regcontents or {}, info.regtype or "v" }
  end
end

-- 无 tmux 路径：仿内置 vim.ui.clipboard.osc52.paste（$VIMRUNTIME 内），但只等
-- 单段短超时。返回 (status, text)，status 为 "ok" | "timeout" | "interrupt"。
local function read_via_osc52(reg)
  local contents = nil
  local id = vim.api.nvim_create_autocmd("TermResponse", {
    callback = function(ev)
      local encoded = ev.data.sequence:match("\027%]52;%w?;([A-Za-z0-9+/=]*)")
      if encoded then
        contents = vim.base64.decode(encoded)
        return true -- 匹配成功即自删 autocmd
      end
    end,
  })

  vim.api.nvim_ui_send(string.format("\027]52;%s;?\027\\", reg == "+" and "c" or "p"))

  local ok, res = vim.wait(timeout_ms(), function()
    return contents ~= nil
  end)
  if ok then
    return "ok", contents
  end

  -- 成功路径 autocmd 已自删；超时 / 中断路径须手动清理，pcall 防重复删除。
  pcall(vim.api.nvim_del_autocmd, id)
  return res == -2 and "interrupt" or "timeout"
end

-- 统一的 tmux 子进程调用；tmux 不存在时 vim.system 抛错，转成 nil。
local function tmux(args)
  local ok, proc = pcall(vim.system, vim.list_extend({ "tmux" }, args), { text = true })
  if not ok then
    return nil
  end
  return proc:wait(200)
end

-- 栈顶（最新）paste buffer 名；无 buffer 时为空串，tmux 调用失败为 nil。
local function top_buffer_name()
  local res = tmux({ "list-buffers", "-F", "#{buffer_name}" })
  if not res or res.code ~= 0 then
    return nil
  end
  return vim.split(res.stdout or "", "\n")[1] or ""
end

-- tmux 路径：refresh-client -l 让 tmux 向它的客户端终端发 OSC 52 读查询，
-- 应答存入一个新建的 paste buffer（压栈顶），故轮询「栈顶 buffer 名是否
-- 变化」而非固定 sleep（sleep 短了读到旧 buffer，长了每次白等）。
-- 已知局限：多客户端 attach 时 -l 查最近活跃客户端的剪贴板；轮询窗口内
-- 其他进程新建 buffer 存在竞态（指名 save-buffer 已消除一半，概率极低）。
-- -l 只读 clipboard（无 primary 之分），故忽略 reg，"+" 与 "*" 同内容。
-- 返回 (status, text)，status 为 "ok" | "timeout" | "interrupt" | "error"。
local function read_via_tmux()
  local before = top_buffer_name()
  if before == nil then
    return "error"
  end

  local res = tmux({ "refresh-client", "-l" })
  if not res or res.code ~= 0 then
    -- tmux < 3.2 没有 -l：硬错误，重试无意义。
    return "error"
  end

  local top
  local ok, res2 = vim.wait(timeout_ms(), function()
    local name = top_buffer_name()
    if name and name ~= "" and name ~= before then
      top = name
      return true
    end
    return false
  end, 50)
  if not ok then
    -- 终端授权弹窗迟到的应答无害：buffer 迟到入栈，下次 paste 会把它记为
    -- before 再发新查询。
    return res2 == -2 and "interrupt" or "timeout"
  end

  -- 指名读取（字节精确、避竞态）后即删，保证 buffer 栈不增长。
  local saved = tmux({ "save-buffer", "-b", top, "-" })
  tmux({ "delete-buffer", "-b", top })
  if not saved or saved.code ~= 0 then
    return "error"
  end
  return "ok", saved.stdout or ""
end

-- paste 方向入口。失败语义：
--   超时        -> 计失败，连续 2 次禁用本会话终端读取并提示一次；
--   硬错误      -> 立即禁用（tmux 缺 -l 等，重试无意义）；
--   Ctrl-C 中断 -> 不计失败，直接回退；
--   成功但空串  -> 计成功（终端可达），内容回退匿名寄存器。
local function paste_via_terminal(reg)
  return function()
    if state.disabled or #vim.api.nvim_list_uis() == 0 then
      return register_fallback()
    end

    local status, text
    if (vim.env.TMUX or "") ~= "" then
      status, text = read_via_tmux()
    else
      status, text = read_via_osc52(reg)
    end

    if status == "ok" then
      state.failures = 0
      if text == "" then
        return register_fallback()
      end
      -- 返回裸 lines：clipboard.vim 的 get() 只在 paste 返回裸列表且与上次
      -- copy 缓存相等时才恢复缓存的 regtype（保住 yy -> p 的 linewise 回环）；
      -- 返回 { lines, "v" } 会让整行粘贴退化成 charwise。
      return vim.split(text, "\n")
    end

    if status == "timeout" then
      state.failures = state.failures + 1
      if state.failures >= 2 then
        disable(
          "OSC 52 剪贴板读取连续超时，本会话改用匿名寄存器。"
            .. "请允许终端读剪贴板（kitty 的 clipboard_control 加 read-clipboard，"
            .. "ghostty 设 clipboard-read = allow），再 :ClipboardRetry 重试。"
        )
      end
    elseif status == "error" then
      disable(
        "tmux 剪贴板读取不可用（需 tmux >= 3.2 的 refresh-client -l 且 set-clipboard on），"
          .. "本会话改用匿名寄存器。修复后 :ClipboardRetry 重试。"
      )
    end
    return register_fallback()
  end
end

-- 重置失败缓存，恢复终端读取（:ClipboardRetry 的实现）。
function M.enable_osc52_read()
  state.failures = 0
  state.disabled = false
end

--- @param reg string
local function copy_osc52(reg)
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    return nil
  end
  local send = osc52.copy(reg)
  return function(lines, regtype)
    last_copy = { lines = lines, regtype = regtype or "v" }
    send(lines, regtype)
  end
end

--- Install (or clear) vim.g.clipboard for the given mode.
--- @param mode "native"|"osc52"
local function apply(mode)
  if mode == "native" then
    vim.g.clipboard = nil
  else
    local plus, star = copy_osc52("+"), copy_osc52("*")
    if not plus then
      return false
    end
    vim.g.clipboard = {
      name = "OSC 52 (copy) / cached register (paste)",
      copy = { ["+"] = plus, ["*"] = star },
      paste = { ["+"] = paste_fallback(), ["*"] = paste_fallback() },
    }
  end
  -- Re-run the provider bootstrap so a mid-session switch takes effect.
  vim.cmd("runtime autoload/provider/clipboard.vim")
  return true
end

--- Resolve the effective mode, honouring the g: override.
--- @return "native"|"osc52" mode, string reason, table signals
function M.resolve()
  local s = collect()
  local override = vim.g.lbs_clipboard_mode
  if override == "native" or override == "osc52" then
    return override, "forced via g:lbs_clipboard_mode", s
  end
  local mode, reason = decide(s)
  return mode, reason, s
end

--- @param mode "auto"|"native"|"osc52"
function M.set_mode(mode)
  vim.g.lbs_clipboard_mode = mode ~= "auto" and mode or nil
  local effective, reason = M.resolve()
  apply(effective)
  vim.notify(string.format("clipboard: %s (%s)", effective, reason), vim.log.levels.INFO)
end

function M.diagnose()
  local mode, reason, s = M.resolve()
  local lines = {
    string.format("effective mode : %s", mode),
    string.format("reason         : %s", reason),
    string.format("g:lbs_clipboard_mode : %s", tostring(vim.g.lbs_clipboard_mode or "auto")),
    "",
    string.format("multiplexer    : %s", s.multiplexer or "none"),
    string.format("TERM           : %s", s.term or "-"),
    string.format("stdin tty      : %s", s.tty or "-"),
    string.format("SSH_TTY        : %s%s", s.ssh_tty or "-", s.ssh_tty_stale and "   <- STALE" or ""),
    string.format("SSH_CONNECTION : %s", s.ssh_connection or "-"),
    "",
    string.format(
      "WAYLAND_DISPLAY: %s  socket=%s  wl-copy=%s",
      s.wayland_display or "-",
      s.wayland_socket or "unreachable",
      tostring(s.has_wl_copy)
    ),
    string.format(
      "DISPLAY        : %s  socket=%s  xsel/xclip=%s%s",
      s.display or "-",
      s.x_socket or "unreachable",
      tostring(s.has_x_tool),
      s.x_forwarded and "  (forwarded)" or ""
    ),
    "",
    string.format("provider       : %s", vim.g.clipboard and vim.g.clipboard.name or "nvim builtin probe"),
    string.format("cached copy    : %s", last_copy and string.format("%d line(s)", #last_copy.lines) or "none"),
  }
  vim.api.nvim_echo({ { table.concat(lines, "\n") } }, false, {})
end

function M.setup()
  local mode = M.resolve()
  apply(mode)

  vim.api.nvim_create_user_command("ClipboardMode", function(opts)
    M.set_mode(opts.args ~= "" and opts.args or "auto")
  end, {
    nargs = "?",
    complete = function()
      return { "auto", "native", "osc52" }
    end,
    desc = "Switch the clipboard provider (auto|native|osc52)",
  })

  vim.api.nvim_create_user_command("ClipboardDiag", function()
    M.diagnose()
  end, { desc = "Show how the clipboard provider was chosen" })
end

return M
