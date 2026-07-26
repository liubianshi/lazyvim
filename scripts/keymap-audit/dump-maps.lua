-- 导出运行时真实映射表（全局 + 代表性 filetype 的 buffer-local）。
--
-- 必须在「有 UI」的会话里跑，用伪终端触发：
--   MAPDUMP=out.tsv script -qec "nvim -c 'autocmd User VeryLazy ++once \
--     lua vim.defer_fn(function() vim.cmd[[luafile ~/.cache/nvim-audit/dump-maps.lua]] end, 3000)'" /dev/null
--
-- 不要用 `nvim --headless` + 手动 exec_autocmds("User","VeryLazy") 代替：
-- 那会让 which-key 的 setup 早于 config/keymaps.lua 执行，而 wk.add() 只入队、
-- 队列仅在 setup 时 flush 一次，于是 keymaps.lua 的全部映射静默丢失，
-- 导出结果对该文件完全是盲的。
local out = {}

for _, mode in ipairs({ "n", "i", "v", "x", "o", "t", "c", "s" }) do
  for _, k in ipairs(vim.api.nvim_get_keymap(mode)) do
    out[#out + 1] = ("G\t%s\t%s\t%s"):format(mode, k.lhs, k.desc or "")
  end
end

for _, ft in ipairs({ "r", "quarto", "rmd", "markdown", "norg", "lua" }) do
  pcall(function()
    vim.cmd("enew")
    vim.bo.filetype = ft -- 赋值本身即触发 FileType，无需再 exec_autocmds
    for _, mode in ipairs({ "n", "i", "v", "x", "o" }) do
      for _, k in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
        out[#out + 1] = ("B:%s\t%s\t%s\t%s"):format(ft, mode, k.lhs, k.desc or "")
      end
    end
  end)
end

-- 去重：nvim_get_keymap("v") 会把同时注册于 visual/select 的映射返回两次
local seen, uniq = {}, {}
for _, line in ipairs(out) do
  if not seen[line] then seen[line] = true; uniq[#uniq + 1] = line end
end
out = uniq
table.sort(out)
vim.fn.writefile(out, vim.env.MAPDUMP or "maps.tsv")
vim.cmd("qa!")
