-- Define commands
local cmd = vim.api.nvim_create_user_command

cmd("Bclose", function(opts)
  local bang = opts.bang and "!" or ""
  vim.fn["utils#Bclose"](bang, opts.args)
end, { bang = true, complete = "buffer", nargs = "?", desc = "Close Buffer" })

cmd("Mylib", function(opts)
  vim.fn["mylib#run"](unpack(opts.fargs))
end, {
  nargs = "+",
  complete = "customlist,mylib#Complete",
  desc = "Mylib commands",
})

cmd("Perldoc", function(opts)
  vim.fn["perldoc#Perldoc"](string.format("%q", opts.args))
end, {
  nargs = "*",
  complete = "customlist,perldoc#PerldocComplete",
  desc = "Perl documents",
})

cmd("Redir", function(opts)
  vim.fn["utils#CaptureCommandOutput"](opts.args)
end, {
  complete = "command",
  nargs = 1,
  desc = "Capture output from a command to register @m",
})

cmd("Rdoc", function(opts)
  vim.fn["rdoc#Rdoc"](string.format("%q", opts.args))
end, {
  nargs = "*",
  complete = "customlist,rdoc#RLisObjs",
  desc = "R documents",
})

cmd("SR", function(opts)
  require("util").execute_async(string.format("sr %s &>/dev/null &", opts.args), {
    on_stdout = function() end,
    on_exit = function()
      vim.notify("Opened in external browser", vim.log.levels.INFO, { title = "SurfRaw" })
    end,
  })
end, {
  nargs = "*",
  desc = "Search with surfraw",
})

cmd("StataHelp", function(opts)
  local args = opts.fargs
  if args[1] == "pdf" then
    table.remove(args, 1)
    vim.fn["utils#StataGenHelpDocs"](args:concat(" "), "pdf")
  else
    vim.fn["utils#StataGenHelpDocs"](opts.args)
  end
end, { nargs = "*", desc = "Stata Help" })

cmd("ToggleZenMode", "call utils#ToggleZenMode()", { desc = "Toggle Zen Mode" })

cmd("CodeCompanionSave", function(opts)
  -- 保存CodeCompanion聊天记录的命令
  -- 参数：
  --   opts.fargs: 可选的文件名参数，如果不提供则从第一条用户消息生成文件名

  -- 获取当前缓冲区的聊天内容
  local success, chat = pcall(function()
    local codecompanion = require("codecompanion")
    return codecompanion.buf_get_chat(0)
  end)

  -- 检查是否在CodeCompanion聊天缓冲区
  if not success or chat == nil then
    vim.notify("CodeCompanionSave should only be called from CodeCompanion chat buffers", vim.log.levels.ERROR)
    return
  end

  -- 生成文件名
  local save_name
  if #opts.fargs == 0 then
    -- 如果没有提供文件名参数，则从第一条用户消息生成文件名
    for _, output in ipairs(chat.messages) do
      if output.role == "user" and output.content then
        -- 清理内容中的特殊字符和空格
        save_name = output
          .content
          :gsub("[/%\\%s]", "-") -- 替换路径分隔符和空格为-
          :gsub("[?？%p%s]*$", "") -- 去除末尾的标点和空格
          :sub(1, 100) -- 限制最大长度
          .. ".md"
        break
      end
    end
    if not save_name then
      vim.notify("CodeCompanionSave requires at least 1 arg to make a file name", vim.log.levels.ERROR)
      return
    end
  else
    -- 如果提供了文件名参数，则直接使用
    save_name = table.concat(opts.fargs, "-") .. ".md"
  end

  -- 设置保存路径
  local Path = require("plenary.path")
  local data_path = os.getenv("WRITING_LIB") or vim.fn.getcwd()
  local save_folder = Path:new(data_path, "cc_saves")

  -- 创建保存目录（如果不存在）
  if not save_folder:exists() then
    local success_mkdir, err = pcall(save_folder.mkdir, save_folder, { parents = true })
    if not success_mkdir then
      vim.notify("Failed to create save directory: " .. err, vim.log.levels.ERROR)
      return
    end
  end

  -- 保存文件
  local save_path = Path:new(save_folder, save_name)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local success_write, err = pcall(save_path.write, save_path, table.concat(lines, "\n"), "w")

  -- 显示保存结果
  if success_write then
    vim.notify(string.format("Chat saved to: %s", save_path:absolute()), vim.log.levels.INFO)
  else
    vim.notify("Failed to save chat: " .. err, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  desc = "Save CodeCompanion chat to markdown file",
})
