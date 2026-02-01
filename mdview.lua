-- 基础 UI 优化
vim.opt.relativenumber = false
vim.opt.number = false
vim.opt.laststatus = 0
vim.opt.showmode = false
vim.opt.signcolumn = "no"
vim.opt.wrap = true
vim.opt.breakindent = true -- 核心：开启折行缩进

-- 针对 Pager 模式的快捷键
vim.keymap.set("n", "q", ":q!<CR>", { silent = true })
vim.keymap.set("n", "<Space>", "<PageDown>", { silent = true })

-- 处理管道输入和文件识别
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    callback = function()
        -- 如果是从管道读入（文件名为空），或者是 .md 文件
        if vim.fn.expand("%") == "" or vim.fn.expand("%:e") == "md" then
            vim.opt_local.filetype = "markdown"
            vim.opt_local.buftype = "nofile" -- 不产生交换文件
            vim.opt_local.bufhidden = "hide"
            vim.opt_local.swapfile = false
        end
    end,
})

