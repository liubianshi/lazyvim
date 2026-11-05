local M = {}

local function url_dict(buf)
  return vim.b[buf].newsboat_url_dict or {}
end

function M.generate(buf)
  if vim.b[buf].newsboat_url_dict then
    return vim.b[buf].newsboat_url_dict
  end

  local dict = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local id, url, kind = line:match("^%s*%[(%d+)%]%s*:%s+(%S+)%s+%(([^)]+)%)%s*$")
    if id then
      dict[id] = { url = url, type = kind }
    end
  end

  if next(dict) then
    vim.b[buf].newsboat_url_dict = dict
  end
  return dict
end

local function link_id_at(text, offset)
  local from = 1
  while true do
    local first, last, content = text:find("%[([^%]]*)%]", from)
    if not first then
      return nil, false
    end
    if offset >= first and offset <= last then
      return content:match("^(%d+)$") or content:match("%(link #(%d+)%)"), true
    end
    from = last + 1
  end
end

function M.under_cursor(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local line = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1] or ""
  local id, matched = link_id_at(line, cursor[2] + 1)
  if not matched then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local offset = cursor[2] + 1
    for line_number = 1, cursor[1] - 1 do
      offset = offset + #lines[line_number] + 1
    end
    id = link_id_at(table.concat(lines, "\n"), offset)
  end

  local link = id and url_dict(buf)[id] or nil
  if not link then
    require("lbs.image").clear({ win = win })
  end
  return link
end

function M.open_under_cursor(buf)
  local link = M.under_cursor(buf)
  if link then
    vim.fn["utils#OpenUrl"](link, "in")
  end
end

function M.open(count, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local link = url_dict(buf)[tostring(count)]
  if not link then
    vim.notify("No newsboat link numbered " .. tostring(count), vim.log.levels.WARN)
    return
  end

  vim.notify(link.url)
  local _, err = vim.ui.open(link.url)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end

function M.cache_snapshot(buf)
  if vim.b[buf].newsboat_link_cached or not vim.b[buf].newsboat_url_dict then
    return
  end

  local urls = {}
  for _, link in pairs(vim.b[buf].newsboat_url_dict) do
    urls[#urls + 1] = link.url .. "\t" .. link.type
  end
  local tmpfile = vim.fn.tempname()
  vim.fn.writefile(urls, tmpfile)
  vim.b[buf].newsboat_link_cached = true

  local ok, err = pcall(vim.system, { "cache_url_snapshot", tmpfile }, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify("Link snapshot cached")
      else
        vim.notify(vim.trim(result.stderr or "Failed to cache link snapshot"), vim.log.levels.ERROR)
      end
      vim.uv.fs_unlink(tmpfile)
    end)
  end)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
    vim.uv.fs_unlink(tmpfile)
  end
end

return M
