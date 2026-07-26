local M = {}

-- 状态存储：记录每个 buffer 在离开插入模式前的输入法状态
local im_state = {}

-- 手动启用/禁用的 buffer 列表
local enabled_buffers = {}

-- 配置选项
M.config = {
  debug = false, -- 是否启用 debug 日志
  -- 自动启用的 buftype 列表
  auto_enable_buftypes = { "terminal", "prompt" },
}

-- 全局 autocmd 是否已初始化
local initialized = false

-- Debug 日志函数
local function debug_log(msg, ...)
  if M.config.debug then
    local formatted = string.format(msg, ...)
    vim.notify("[IM-Switch] " .. formatted, vim.log.levels.INFO)
  end
end

-- 检查是否为中文输入法
-- fcitx5-remote 返回 1=未激活(英文), 2=激活(中文)
local function is_chinese_im()
  local handle = io.popen("fcitx5-remote 2>/dev/null")
  if not handle then
    debug_log("无法执行 fcitx5-remote 命令")
    return false
  end
  local result = handle:read("*a")
  handle:close()

  local status = result:match("%d+")
  debug_log("当前输入法状态: %s (2=中文, 1=英文)", status or "未知")

  return status == "2"
end

-- 切换到英文输入法
local function switch_to_en()
  debug_log("切换到英文输入法")
  vim.system({ "fcitx5-remote", "-c" }, { detach = true })
end

-- 切换到中文输入法
local function switch_to_zh()
  debug_log("切换到中文输入法")
  vim.system({ "fcitx5-remote", "-o" }, { detach = true })
end

-- 检查 buffer 是否应该启用输入法切换
local function should_enable(bufnr)
  -- 检查是否手动启用
  if enabled_buffers[bufnr] then
    debug_log("Buffer %d: 手动启用", bufnr)
    return true
  end

  -- 检查是否符合自动启用条件
  local buftype = vim.bo[bufnr].buftype
  local is_auto = vim.tbl_contains(M.config.auto_enable_buftypes, buftype)
  debug_log("Buffer %d: buftype=%s, 自动启用=%s", bufnr, buftype, is_auto and "是" or "否")
  return is_auto
end

-- 处理离开插入/终端模式
local function on_leave_insert(bufnr)
  if not should_enable(bufnr) then
    return
  end

  debug_log("Buffer %d: 离开插入/终端模式", bufnr)
  local is_zh = is_chinese_im()
  im_state[bufnr] = is_zh
  debug_log("Buffer %d: 保存输入法状态 = %s", bufnr, is_zh and "中文" or "英文")
  switch_to_en()
end

-- 处理进入插入/终端模式
local function on_enter_insert(bufnr)
  if not should_enable(bufnr) then
    return
  end

  debug_log("Buffer %d: 进入插入/终端模式", bufnr)
  local saved_state = im_state[bufnr]
  debug_log(
    "Buffer %d: 之前保存的状态 = %s",
    bufnr,
    saved_state == nil and "无" or (saved_state and "中文" or "英文")
  )

  if saved_state then
    switch_to_zh()
  else
    debug_log("Buffer %d: 保持英文输入法", bufnr)
  end
end

-- 初始化全局 autocmd
function M.setup()
  if initialized then
    debug_log("已经初始化过，跳过")
    return
  end

  debug_log("初始化输入法自动切换模块")

  local group = vim.api.nvim_create_augroup("LBS_IM_Switch", { clear = true })

  -- 普通 buffer：监听 InsertLeave/InsertEnter
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    desc = "IM Switch: Save state on leaving insert mode",
    callback = function(ev)
      on_leave_insert(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    desc = "IM Switch: Restore state on entering insert mode",
    callback = function(ev)
      on_enter_insert(ev.buf)
    end,
  })

  -- 终端 buffer：监听 TermLeave/TermEnter
  vim.api.nvim_create_autocmd("TermLeave", {
    group = group,
    desc = "IM Switch: Save state on leaving terminal mode",
    callback = function(ev)
      on_leave_insert(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("TermEnter", {
    group = group,
    desc = "IM Switch: Restore state on entering terminal mode",
    callback = function(ev)
      on_enter_insert(ev.buf)
    end,
  })

  -- 清理：buffer 删除时清理状态
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    desc = "IM Switch: Clean up on buffer delete",
    callback = function(ev)
      if im_state[ev.buf] or enabled_buffers[ev.buf] then
        debug_log("Buffer %d: 删除，清理状态", ev.buf)
        im_state[ev.buf] = nil
        enabled_buffers[ev.buf] = nil
        switch_to_en()
      end
    end,
  })

  initialized = true
  debug_log("输入法自动切换模块初始化完成")
end

-- 手动启用指定 buffer
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  enabled_buffers[bufnr] = true
  debug_log("Buffer %d: 手动启用输入法切换", bufnr)
end

-- 手动禁用指定 buffer
function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  enabled_buffers[bufnr] = nil
  im_state[bufnr] = nil
  debug_log("Buffer %d: 禁用输入法切换", bufnr)
end

-- 检查是否应该自动启用
function M.should_auto_enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local buftype = vim.bo[bufnr].buftype
  return vim.tbl_contains(M.config.auto_enable_buftypes, buftype)
end

-- 切换 debug 模式
function M.toggle_debug()
  M.config.debug = not M.config.debug
  vim.notify(
    string.format("[IM-Switch] Debug 模式: %s", M.config.debug and "开启" or "关闭"),
    vim.log.levels.INFO
  )
end

-- 显示当前状态
function M.status()
  local bufnr = vim.api.nvim_get_current_buf()
  local buftype = vim.bo[bufnr].buftype
  local saved_state = im_state[bufnr]
  local current_im = is_chinese_im()
  local is_enabled = should_enable(bufnr)
  local is_manual = enabled_buffers[bufnr] or false
  local should_auto = M.should_auto_enable(bufnr)

  -- 统计启用的 buffer 数量
  local enabled_count = 0
  for _ in pairs(enabled_buffers) do
    enabled_count = enabled_count + 1
  end

  local status = {
    debug = M.config.debug,
    initialized = initialized,
    enabled_buffers_count = enabled_count,
    current_buffer = {
      id = bufnr,
      type = buftype == "" and "normal" or buftype,
      auto_enable_matched = should_auto,
      manually_enabled = is_manual,
      actually_enabled = is_enabled,
    },
    input_method = {
      current = current_im and "chinese" or "english",
      saved_state = saved_state == nil and "none" or (saved_state and "chinese" or "english"),
    },
    config = {
      auto_enable_buftypes = M.config.auto_enable_buftypes,
    },
  }

  vim.notify(vim.inspect(status), vim.log.levels.INFO, { title = "IM-Switch Status" })
  return status
end

return M
