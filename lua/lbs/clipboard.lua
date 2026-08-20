-- 剪贴板 provider 决策。
--
-- 本地会话保留 Neovim 自身的探测（wl-copy / xsel），现状已可用。
-- 远程会话（SSH，含 tmux 内外）显式指定 provider：
--   * copy  -> OSC 52，让 yank 落到本地机器的剪贴板；
--   * paste -> 无 tmux 时自实现短超时（默认 500ms）的 OSC 52 读查询，
--              不用内置 vim.ui.clipboard.osc52.paste（终端不应答时阻塞 1s+9s）；
--              tmux 内一律走 `tmux refresh-client -l`，因为 tmux >= 3.3 会用
--              自己的 paste buffer 应答 pane 内的直接查询，静默给出陈旧数据。
--              读取失败回退匿名寄存器 "；连续超时会禁用本会话的终端读取，
--              :ClipboardRetry 可恢复。
--
-- 设置 vim.g.clipboard 命中 $VIMRUNTIME/autoload/provider/clipboard.vim
-- 的最高优先级分支，绕过工具存在性探测顺序——否则它会在轮到 OSC 52 之前
-- 先选中 lemonade / 转发的 $DISPLAY / tmux load-buffer。

local M = {}

-- SSH_TTY 仅交互式会话设置；SSH_CONNECTION / SSH_CLIENT 覆盖其余情况。
local function is_remote()
  return (vim.env.SSH_TTY or vim.env.SSH_CONNECTION or vim.env.SSH_CLIENT) ~= nil
end

-- 终端读取的失败缓存，"+" 与 "*" 共享：失败发生在终端层面，分开只吃双倍超时。
local state = { failures = 0, disabled = false }

-- 成功路径耗时约等于 SSH RTT，超时值只在失败时消耗。终端的授权弹窗
-- （kitty read-clipboard-ask / ghostty ask）等不过这个超时，视为未配置。
local function timeout_ms()
  return vim.g.lbs_clipboard_read_timeout_ms or 500
end

-- 回退读匿名寄存器。返回 { lines, regtype }（而非裸 lines）以保住块选 yank
-- 的 regtype；见 clipboard.vim 的 get() 处理。
local function register_fallback()
  local info = vim.fn.getreginfo('"')
  return { info.regcontents or {}, info.regtype or "v" }
end

-- 禁用本会话的终端读取，并提示一次恢复方法。paste 可能在 textlock 下被
-- 调用，notify 统一 schedule。
local function disable(msg)
  if state.disabled then
    return
  end
  state.disabled = true
  vim.schedule(function()
    vim.notify(msg, vim.log.levels.WARN, { title = "Clipboard" })
  end)
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

function M.setup()
  if not is_remote() then
    return
  end

  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    return
  end

  vim.g.clipboard = {
    name = "OSC 52 (copy) / OSC 52 short-timeout read (paste)",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = paste_via_terminal("+"),
      ["*"] = paste_via_terminal("*"),
    },
  }

  vim.api.nvim_create_user_command("ClipboardRetry", function()
    M.enable_osc52_read()
    vim.notify("已重新启用终端剪贴板读取", vim.log.levels.INFO, { title = "Clipboard" })
  end, { desc = "Reset clipboard read failure cache (re-enable OSC 52 / tmux read)" })
end

return M
