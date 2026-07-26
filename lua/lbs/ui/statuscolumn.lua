-- 自建 statuscolumn：折叠标记、git / diagnostic 符号、行号。
-- config/options.lua 的 opt.statuscolumn 指向本模块的 M.statuscolumn()。
local M = {}

---@alias Sign {name:string, text:string, texthl:string, priority:number}

-- getmarklist 逐行调用会吃掉 statuscolumn 约八成的单行开销（实测 0.0159ms，
-- 该函数其余部分合计才 0.0035ms），而一次重绘要把整个视口跑一遍。改成按 buffer
-- 缓存一张 lnum -> Sign 表，用短 TTL 失效：一次重绘（16ms 内）的所有行共用同一张表，
-- 新设的 mark 也能在下一帧显示。不用 changedtick 做键，因为 `ma` 不改 changedtick。
local MARK_TTL_NS = 50 * 1e6
local mark_cache = {} ---@type table<number, {t:number, map:table<number,Sign>}>

---@return Sign?
---@param buf number
---@param lnum number
function M.get_mark(buf, lnum)
  local now = vim.uv.hrtime()
  local cached = mark_cache[buf]
  if not cached or now - cached.t > MARK_TTL_NS then
    local map = {}
    local marks = vim.fn.getmarklist(buf)
    vim.list_extend(marks, vim.fn.getmarklist())
    for _, mark in ipairs(marks) do
      -- 同一行有多个 mark 时取先出现的那个，与改造前的 return-first 语义一致
      if mark.pos[1] == buf and mark.mark:match("[a-zA-Z]") and not map[mark.pos[2]] then
        map[mark.pos[2]] = { text = mark.mark:sub(2), texthl = "DiagnosticHint" }
      end
    end
    cached = { t = now, map = map }
    mark_cache[buf] = cached
    for b, entry in pairs(mark_cache) do
      if now - entry.t > MARK_TTL_NS and not vim.api.nvim_buf_is_valid(b) then
        mark_cache[b] = nil
      end
    end
  end
  return cached.map[lnum]
end

---@param sign? Sign
---@param len? number
function M.icon(sign, len)
  sign = sign or {}
  len = len or 2
  local text = vim.fn.strcharpart(sign.text or "", 0, len) ---@type string
  text = text .. string.rep(" ", len - vim.fn.strchars(text))
  return sign.texthl and ("%#" .. sign.texthl .. "#" .. text .. "%*") or text
end

-- Returns a list of regular and extmark signs sorted by priority (low to high)
---@return Sign[]
---@param buf number
---@param lnum number
function M.get_signs(buf, lnum)
  -- Get regular signs
  ---@type Sign[]
  local signs = {}

  -- Get extmark signs
  local extmarks = vim.api.nvim_buf_get_extmarks(
    buf,
    -1,
    { lnum - 1, 0 },
    { lnum - 1, -1 },
    { details = true, type = "sign" }
  )
  for _, extmark in pairs(extmarks) do
    signs[#signs + 1] = {
      name = extmark[4].sign_hl_group or extmark[4].sign_name or "",
      text = extmark[4].sign_text,
      texthl = extmark[4].sign_hl_group,
      priority = extmark[4].priority,
    }
  end

  -- Sort by priority
  table.sort(signs, function(a, b)
    return (a.priority or 0) < (b.priority or 0)
  end)

  return signs
end

-- fillchars 每行解析一次要 0.0026ms（`nvim_buf_get_extmarks` 的五倍）。按原始
-- 字符串比对来复用解析结果：比字符串远比重新解析便宜，且选项一改立刻跟上。
local fc_cache = { raw = false }
local function fillchars()
  local raw = vim.o.fillchars
  if raw ~= fc_cache.raw then
    local fc = vim.opt.fillchars:get()
    fc_cache = { raw = raw, foldopen = fc.foldopen, foldclose = fc.foldclose }
  end
  return fc_cache
end

-- Neovim 版本在会话中不会变，提到模块级只判一次。
local HAS_NVIM_011 = vim.fn.has("nvim-0.11") == 1

function M.statuscolumn()
  local win = vim.g.statusline_winid
  local buf = vim.api.nvim_win_get_buf(win)
  local is_file = vim.bo[buf].buftype == ""
  local show_signs = vim.wo[win].signcolumn ~= "no"

  local components = { "", "", "" } -- left, middle, right

  -- vim.g 取值要过一次 Vimscript dict 转换，读一次分给两个开关
  local sc_opts = vim.g.lbs_statuscolumn or {}
  local show_open_folds = sc_opts.folds_open
  local use_githl = sc_opts.folds_githl

  if show_signs then
    local signs = M.get_signs(buf, vim.v.lnum)

    ---@type Sign?,Sign?,Sign?
    local left, right, fold, githl
    for _, s in ipairs(signs) do
      if s.name and (s.name:find("GitSign") or s.name:find("MiniDiffSign")) then
        right = s
        if use_githl then
          githl = s["texthl"]
        end
      else
        left = s
      end
    end

    vim.api.nvim_win_call(win, function()
      if vim.fn.foldclosed(vim.v.lnum) >= 0 then
        fold = { text = fillchars().foldclose or "", texthl = githl or "Folded" }
      elseif show_open_folds and tostring(vim.treesitter.foldexpr(vim.v.lnum)):sub(1, 1) == ">" then
        fold = { text = fillchars().foldopen or "", texthl = githl } -- fold start
      end
    end)
    -- Left: mark or non-git sign
    components[3] = M.icon(M.get_mark(buf, vim.v.lnum) or left)
    -- Right: fold icon or git sign (only if file)
    components[2] = is_file and M.icon(fold or right) or ""
  end

  -- Numbers in Neovim are weird
  -- They show when either number or relativenumber is true
  local is_num = vim.wo[win].number
  local is_relnum = vim.wo[win].relativenumber
  if (is_num or is_relnum) and vim.v.virtnum == 0 then
    if HAS_NVIM_011 then
      components[1] = "%l" -- 0.11 handles both the current and other lines with %l
    else
      if vim.v.relnum == 0 then
        components[1] = is_num and "%l" or "%r" -- the current line
      else
        components[1] = is_relnum and "%r" or "%l" -- other lines
      end
    end
    components[1] = "%=" .. components[1] .. " " -- right align
  end

  if vim.v.virtnum ~= 0 then
    components[1] = "%= "
  end

  return table.concat(components, "")
end

return M
