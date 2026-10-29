-- 剪贴板 provider 决策。
--
-- The question this module answers is deliberately *not* "am I on the far end
-- of an SSH connection?".  That is a snapshot taken at login: SSH_TTY and
-- friends are injected once and then frozen into whatever session inherits
-- them.  Under a session-persistence multiplexer (herdr, zmx, tmux, screen) the same
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
-- A reachable display socket belongs to this host, not necessarily the attached
-- client. Herdr panes retain the server's environment across client attaches,
-- so send their copies through Herdr even when a host display is reachable.
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
    herdr_env = env.HERDR_ENV,
    herdr_pane_id = env.HERDR_PANE_ID,
    term_program = env.TERM_PROGRAM,
    zmx_session = env.ZMX_SESSION,
    tmux = env.TMUX,
    sty = env.STY,
    term = env.TERM,
    wayland_display = env.WAYLAND_DISPLAY,
    display = env.DISPLAY,
    xdg_runtime_dir = env.XDG_RUNTIME_DIR,
  }

  s.multiplexer = ((s.herdr_env == "1" or (s.herdr_pane_id or "") ~= "" or s.term_program == "herdr") and "herdr")
    or (s.zmx_session and "zmx")
    or (s.tmux and "tmux")
    or (s.sty and "screen")
    or nil
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
  if s.multiplexer == "herdr" then
    return "osc52", "persistent herdr session (attached client may be remote)"
  end
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

--- @param reg string
local function copy_osc52(reg)
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    return nil
  end
  local send = osc52.copy(reg)
  return function(lines, regtype)
    last_copy = { lines = lines, regtype = regtype or "v" }
    send(lines)
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
  vim.g.loaded_clipboard_provider = nil
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
    string.format("TERM_PROGRAM   : %s", s.term_program or "-"),
    string.format("HERDR_ENV      : %s", s.herdr_env or "-"),
    string.format("HERDR_PANE_ID  : %s", s.herdr_pane_id or "-"),
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
