local M = {}

local function notify_missing_library()
  vim.notify("Need save html file to lib first")
end

local function run(command)
  local ok, result = pcall(vim.system, command, { text = true })
  if not ok then
    vim.notify(result, vim.log.levels.ERROR)
    return nil
  end
  result = result:wait()
  if result.code ~= 0 then
    vim.notify(vim.trim(result.stderr or "Command failed: " .. command[1]), vim.log.levels.ERROR)
    return nil
  end
  return vim.trim(result.stdout or "")
end

local function note_extension(note)
  if not note or note == "" then
    return ""
  end
  return vim.fn.fnamemodify(note, ":e"):lower()
end

local function resolve_note(buf)
  vim.cmd("Mylib note quiet")
  local note = vim.b[buf].mylib_note
  return note, note_extension(note)
end

local function link_citation(buf)
  local link = require("newsboat.links").under_cursor(buf)
  if not link then
    return nil
  end

  local note, extension = resolve_note(buf)
  if not note or note == "" then
    return nil
  end

  if link.type == "image" then
    local image = run({ "linkhandler", "-t", "image", "-V", link.url })
    if not image or image == "" then
      return nil
    end

    local name = vim.fs.basename(image)
    local subdir = vim.fs.basename(vim.fs.dirname(image))
    local target_dir = vim.fs.dirname(note) .. "/img/" .. subdir
    local target = target_dir .. "/" .. name
    if vim.fn.filereadable(target) == 0 then
      vim.fn.mkdir(target_dir, "p")
      if not run({ "link", image, target }) then
        return nil
      end
    end

    local label = vim.fn.input("Please Input image title: ")
    if extension == "org" then
      if label ~= "" then
        label = "[" .. label .. "]"
      end
      return "[[./img/" .. subdir .. "/" .. name .. "]" .. label .. "]"
    elseif extension == "md" then
      local path = "img/" .. subdir .. "/" .. name
      return label ~= "" and ("![[" .. path .. "|" .. label .. "]]") or ("![[" .. path .. "]]")
    end
  elseif extension == "org" or extension == "md" then
    return run({ "url_cite", extension == "org" and "org" or "markdown", link.url })
  end
end

function M.send_content(content, line, method, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  line = line or -1
  method = method or ""
  if not vim.b[buf].mylib_key then
    notify_missing_library()
    return false
  end
  if not content or not content:match("%S") then
    return false
  end

  content = "\n" .. vim.trim(content)
  local current_buf = vim.api.nvim_get_current_buf()
  local note = resolve_note(buf)
  local note_buf = note and vim.fn.bufnr(note) or -1

  if method:lower() == "quiet" then
    if note_buf <= 0 then
      return false
    end
    vim.fn.appendbufline(note, "$", vim.split(content, "\n", { plain = true, trimempty = false }))
    vim.cmd(note_buf .. "," .. note_buf .. "bufdo write")
    vim.cmd("buffer " .. current_buf)
    return true
  end

  vim.fn["mylib#run"]("note", method)
  if line == -1 then
    vim.cmd("normal! Gzt")
  else
    vim.cmd("normal! " .. line .. "Gzt")
  end

  local original = vim.fn.getreg("+")
  vim.fn.setreg("+", "\n" .. content)
  vim.cmd('normal! $"+p')
  if vim.fn.getreg("+"):match("%s*#%+begin_") then
    vim.fn.search([[\v^\s*#\+begin_]])
    vim.fn["text_obj#OrgCodeBlock"]("i")
    vim.cmd("normal! gvgq")
    vim.cmd("normal! 2j")
  else
    vim.cmd("normal! " .. #vim.split(vim.fn.getreg("+"), "\n", { plain = true }) .. "j")
  end
  vim.fn.setreg("+", original)
  vim.cmd(note_buf .. "," .. note_buf .. "bufdo write")
  return true
end

function M.send_clipboard(method, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  method = method or "quiet"
  if not vim.b[buf].mylib_key then
    notify_missing_library()
    return
  end

  local clipboard = vim.fn.getreg("+")
  if clipboard == "" then
    return
  end

  local content = vim.trim(clipboard)
  local _, extension = resolve_note(buf)
  if extension == "org" then
    content = "#+begin_quote\n" .. content .. "\n#+end_quote\n"
  elseif extension == "md" or extension == "norg" then
    local lines = {}
    for _, line in ipairs(vim.split(content, "\n", { plain = true })) do
      lines[#lines + 1] = "> " .. line
    end
    content = table.concat(lines, "\n")
  end

  local marked = "〚" .. clipboard .. "〛"
  marked = marked:gsub("(%s+)〛$", "〛%1")
  vim.fn.setreg("+", marked)
  vim.cmd('normal! gv"+p')
  if not M.send_content(content, -1, method, buf) then
    vim.cmd("normal! u")
  end
end

function M.send_link_citation(line, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.b[buf].mylib_key then
    notify_missing_library()
    return
  end
  local content = link_citation(buf)
  if content then
    M.send_content(content, line or -1, "quiet", buf)
  end
end

return M
