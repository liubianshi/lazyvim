local config = require("hlterm").get_config()

local function source_lines(lines)
  local f = config.tmp_dir .. "/lines.do"
  vim.fn.writefile(lines, f)
  require("hlterm").send_cmd("stata", "do " .. f)
end

require("hlterm").set_ft_opts("stata", {
  nl = "\n",
  app = "stata-mp",
  quit_cmd = "exit, clear",
  source_fun = source_lines,
  send_empty = false,
  syntax = {
    match = {
      { "Input", "^\\s*[>.] .*" },
      { "Error", "^r\\(.*\\)" },
    },
    keyword = {},
  },
})

vim.api.nvim_buf_set_keymap(0, "n", config.mappings.start, "<Cmd>lua require('hlterm').start_app('stata')<CR>", {})
