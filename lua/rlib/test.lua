local M = {}

local function is_test_file(fname)
  return vim.fn.fnamemodify(fname, ":t"):lower():match("^test[-_]")
end

-- 获取包含指定缓冲区名的窗口编号
-- @param bufname 目标缓冲区名称
-- @return 窗口编号或 nil
local function get_winnr_with_bufname(bufname)
  for _, win in ipairs(vim.fn.getwininfo()) do
    if vim.fn.bufname(win.bufnr) == bufname then
      return win.winnr
    end
  end
  return nil
end

-- 测试文件转源文件路径
-- @param fname 测试文件名
-- @return 源文件路径或 nil
local function test_to_source_filepath(fname)
  local source_name = fname:gsub("^test[-_]", "", 1):gsub("-", "/")
  local r_file = "R/" .. source_name
  dd(r_file)
  return vim.fn.filereadable(r_file) == 1 and r_file or nil
end

-- 源文件转测试文件路径
-- @param fname 源文件名
-- @return 测试文件路径
function M.source_to_test_filepath(fname)
  fname = fname or vim.api.nvim_buf_get_name(0)
  fname = vim.fs.relpath(vim.fn.getcwd() .. "/R", fname)
  if not fname then
    return
  end

  local modifed_fname = fname:gsub("/", "-")
  local test_name = "tests/testthat/test_" .. modifed_fname
  return vim.fn.filewritable(test_name) == 1 and test_name or "tests/testthat/test-" .. modifed_fname
end

-- 初始化测试目录结构
local function init_test_files()
  vim.fn.mkdir("tests/testthat", "p")

  -- 生成测试入口文件
  local contents = { 'require("testthat")' }
  for _, file in ipairs(vim.fn.glob("R/*.[Rr]", false, true)) do
    table.insert(contents, 'source("' .. file .. '")')
  end
  table.insert(contents, 'test_dir("tests/testthat")')
  vim.fn.writefile(contents, "tests/testthat.R")
end

-- 打开对应的测试/源文件
-- @param cmd 窗口分割方式（默认 split）
function M.edit_test_file(cmd)
  cmd = cmd or "edit"
  local cwd = vim.fn.getcwd()
  local current_file = vim.fs.relpath(cwd, vim.fn.expand("%"))
  if not current_file then
    return
  end

  if is_test_file(current_file) then
    return M.edit_source_file(cmd, vim.fn.fnamemodify(current_file, ":t"))
  end

  local target_file = M.source_to_test_filepath(current_file)
  if not target_file then
    return
  end

  -- 仅当处理源文件且测试目录不存在时初始化
  if vim.fn.isdirectory("tests") == 0 then
    init_test_files()
  end

  if not vim.uv.fs_access(target_file, "R") then
    -- 创建对应测试文件模板
    local test_content = {
      string.format('here::i_am("%s")', target_file),
      'options(box.path = c(here::here(), Sys.getenv("R_BOX_LIBRARY")))',
      string.format('source(here::here("%s"), local = TRUE)', current_file),
      "",
      "library(testthat)",
    }
    vim.fn.writefile(test_content, target_file)
  end

  -- 智能窗口切换逻辑
  vim.fn.bufload(vim.fn.bufadd(target_file))
  local existing_winnr = get_winnr_with_bufname(target_file)
  if existing_winnr then
    vim.cmd(existing_winnr .. "wincmd w")
  else
    vim.cmd(cmd .. " " .. target_file)
  end
end

-- 测试当前文件
function M.test_file(fname)
  fname = fname or vim.fs.relpath(vim.fn.getcwd(), vim.fn.expand("%"))

  if not fname:lower():match("^r/.+%.r$") or is_test_file(fname) then
    return
  end
  local testfile = M.source_to_test_filepath(fname)
  vim.cmd.RSend(string.format([[testthat::test_file("%s")]], testfile))
end

-- 测试整个项目
function M.test_whole_program()
  if vim.uv.fs_access("NAMESPACE", "R") then
    vim.cmd("RSend devtools::test()")
  else
    vim.cmd('RSend system2("Rscript", "tests/testthat.R", wait = FALSE)')
  end
end

-- 当当前文件是测试文件时打开对应的源文件
-- @param cmd 窗口分割方式（默认 "split"）
function M.edit_source_file(cmd, current_file)
  cmd = cmd or "split"
  current_file = vim.fs.relpath(vim.fn.getcwd(), current_file or vim.fn.expand("%"))
  if not is_test_file(current_file) then
    return
  end

  local source_file = test_to_source_filepath(current_file)
  if not source_file then
    print("未找到对应的源文件: " .. current_file)
    return
  end

  -- 智能窗口切换逻辑
  vim.fn.bufload(vim.fn.bufadd(source_file))
  local existing_winnr = get_winnr_with_bufname(source_file)
  if existing_winnr then
    vim.cmd(existing_winnr .. "wincmd w")
  else
    vim.cmd(cmd .. " " .. source_file)
  end
end

return M
