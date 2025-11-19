-- stylua: ignore start
return {
  name = "Source ...",
  builder = function(params)
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    local filepath = vim.fn.expand("%")
    local cmd_map = {
      python = { cmd = { "uv" },       args = { "run", filepath }},
      perl   = { cmd = { "perl" },     args = { filepath        }},
      sh     = { cmd = { "sh" },       args = { filepath        }},
      bash   = { cmd = { "bash" },     args = { filepath        }},
      stata  = { cmd = { "stata-mp" }, args = { "-b", filepath  }},
    }
    return cmd_map[filetype]
  end,
  condition = {
    filetype = { "perl", "sh", "bash", "python", "do" },
  },
}
