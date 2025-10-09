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
    vim.fn["utils#StataGenHelpDocs"](table.concat(args, " "), "pdf")
  else
    vim.fn["utils#StataGenHelpDocs"](opts.args)
  end
end, { nargs = "*", desc = "Stata Help" })

cmd("ToggleZenMode", "call utils#ToggleZenMode()", { desc = "Toggle Zen Mode" })

local function parse_fabric_args(args)
  local handle_method = "new"
  local file_name_fields = {}

  for _, arg in ipairs(args) do
    if arg == "--replace" or arg == "-r" then
      handle_method = "replace"
    elseif arg == "--add" or arg == "-a" then
      handle_method = "add"
    else
      table.insert(file_name_fields, arg)
    end
  end

  return handle_method, file_name_fields
end

local function FabricComplete(argLead, _, _)
  local options = { "-a", "--add", "-r", "--replace" }
  if string.len(argLead) > 0 then
    return vim.tbl_filter(function(o)
      return o:sub(1, string.len(argLead)) == argLead
    end, options)
  else
    return {}
  end
end

cmd("Fabric", function(opts)
  local winid = vim.api.nvim_get_current_win()
  local bufid = vim.api.nvim_win_get_buf(winid)
  local fabric_opts = { win = {} }

  -- 如果命令后带有 `!` 或在可视模式下调用，则使用缓冲区内容作为输入源
  if opts.bang or opts.range > 0 then
    fabric_opts = vim.tbl_extend("force", fabric_opts, {
      buf = bufid,
      line1 = opts.line1,
      line2 = opts.line2,
    })
  end

  local handle_method, file_name_fields = parse_fabric_args(opts.fargs)

  if handle_method == "new" then
    -- 如果提供了文件名参数，则构造文件路径
    if opts.args ~= "" then
      local writing_lib = os.getenv("WRITING_LIB")
      local base_path = writing_lib or (os.getenv("HOME") .. "/Documents/Writing")
      fabric_opts.file = base_path .. "/fabric/" .. table.concat(file_name_fields, "-") .. ".md"
    end
  else
    -- 根据 --replace 或 --add 选项配置窗口参数
    local win_opts = { id = winid }
    if handle_method == "replace" then
      win_opts.line1 = opts.line1
      win_opts.line2 = opts.line2
    elseif handle_method == "add" then
      win_opts.line1 = opts.line2 + 1
      win_opts.line2 = opts.line2 + 1
    else
      vim.notify("Invalid handle method: " .. handle_method, vim.log.levels.ERROR)
      return
    end
    fabric_opts.win = vim.tbl_deep_extend("force", fabric_opts.win, win_opts)
  end

  require("pickers").fabric(fabric_opts)
end, {
  desc = "Fabric: Choose pattern",
  bang = true,
  complete = FabricComplete,
  nargs = "*",
  range = true,
})
