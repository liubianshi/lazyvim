--- Translation engines: deepl (phrases) and fabric (paragraphs).
---
--- Both return the *raw* engine output. Results are cached (see cache.lua):
--- a `cache.get` on the main thread short-circuits the network call, and a
--- `cache.put` persists fresh output. Cache reads/writes that touch `vim.fn.*`
--- or SQLite must run on the main thread, so the writes live inside the
--- `vim.schedule` callbacks (libuv callbacks run in a fast-event context).
local config = require("translate.config")
local cache = require("translate.cache")
local format = require("translate.format")

local M = {}

--- Pick the target language from the source text: CJK source => translate to
--- English (en_US); otherwise => Chinese (zh_CN). Matches the legacy heuristic
--- that only inspects the first 20 characters of the first line.
---@param text string
---@return string lang_code "en_US" or "zh_CN"
local function detect_lang(text)
  local head_chars = vim.trim(text or ""):sub(1, 20)
  for _, char in ipairs(vim.fn.split(head_chars, "\\zs")) do
    if is_cjk_character(char) then
      return "en_US"
    end
  end
  return "zh_CN"
end

--- Translate a short phrase with deepl.
---@param content string
---@param callback fun(text: string|nil)
---@param opts? {force?: boolean}
function M.translate_phrase(content, callback, opts)
  if not content or #content == 0 then
    return
  end
  opts = opts or {}
  local lang = detect_lang(content)

  if not opts.force then
    local cached = cache.get("deepl", lang, content)
    if cached then
      vim.schedule(function()
        callback(cached)
      end)
      return
    end
  end

  local cmd = vim.list_extend(vim.deepcopy(config.options.engines.deepl), { content })
  vim.system(cmd, { text = true }, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        vim.notify("Failed to translate " .. content .. "\n" .. (obj.stderr or ""), vim.log.levels.ERROR)
      end)
      return
    end
    local result = vim.split(vim.trim(obj.stdout), "\n")[2]
    vim.schedule(function()
      if result then
        cache.put("deepl", lang, content, result)
      end
      callback(result)
    end)
  end)
end

--- Translate a paragraph (or single line) with fabric.
---@param content string[] Content to be translated.
---@param opts {textwidth?: integer, indent?: integer, wrap?: boolean, force?: boolean, callback: fun(lines: string[])}
function M.translate_paragraph(content, opts)
  if not content or #content == 0 then
    return
  end
  opts = vim.tbl_extend("keep", opts, { wrap = true, textwidth = 80, indent = 0, force = false })

  local source = table.concat(content, "\n")
  local lang = detect_lang(content[1] or "")

  -- Turn raw engine output into the final (optionally wrapped) lines, then hand
  -- them to the caller. Always runs on the main thread (inside vim.schedule).
  local function finish(raw)
    local raw_lines = vim.split(vim.trim(raw), "\n")
    local lines = raw_lines
    if opts.wrap then
      lines = format.wrap(raw_lines, { width = opts.textwidth - opts.indent })
    end
    opts.callback(lines)
  end

  -- Cache hit: skip the network entirely.
  if not opts.force then
    local cached = cache.get("fabric", lang, source)
    if cached then
      vim.schedule(function()
        finish(cached)
      end)
      return
    end
  end

  local cmd = vim.deepcopy(config.options.engines.fabric)
  if lang == "en_US" then
    table.insert(cmd, "-v=lang_code:en_US")
  else
    table.insert(cmd, "-v=lang_code:zh_CN")
  end

  local ok, progress = pcall(require, "fidget.progress")
  local progress_handle
  if ok then
    progress_handle = progress.handle.create({
      title = " Requesting Fabric (Translate)",
      message = "In progress...",
      lsp_client = { name = "Fabric" },
    })
  end

  vim.system(cmd, { stdin = content }, function(obj_trans)
    vim.schedule(function()
      if progress_handle then
        progress_handle.message = obj_trans.code == 0 and "Translate Complete" or " Failed to translate with fabric"
        progress_handle:finish()
      end
      if obj_trans.code ~= 0 then
        return
      end
      local raw = vim.trim(obj_trans.stdout)
      cache.put("fabric", lang, source, raw)
      finish(raw)
    end)
  end)
end

return M
