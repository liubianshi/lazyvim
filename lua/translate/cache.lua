--- Raw-translation cache backed by SQLite (liubianshi/sqlite.lua).
---
--- Stores the *raw* engine output keyed by a sha256 of
--- `engine \31 target_lang \31 source`. The cache never expires; callers force
--- a refresh by skipping `get` and letting `put` overwrite (upsert).
---
--- If sqlite.lua cannot be loaded or the database fails to open, the module
--- gracefully degrades to a process-local in-memory table so translation keeps
--- working (just without persistence).
local config = require("translate.config")

local M = {}

-- ASCII unit separator: a byte that will never appear in normal text, used to
-- join the key fields before hashing so distinct fields cannot collide.
local SEP = "\31"

-- Lazily-initialised backing state.
local state = {
  inited = false, -- has ensure_init run?
  enabled = false, -- is the SQLite backend usable?
  tbl = nil, -- the sqlite.tbl instance (nil when degraded)
  db = nil, -- the sqlite db handle
  mem = {}, -- in-memory fallback: hash -> result string
}

--- Build the primary-key hash for a cache entry.
---@param engine string
---@param lang string|nil
---@param source string
---@return string
local function hash_key(engine, lang, source)
  return vim.fn.sha256(engine .. SEP .. (lang or "") .. SEP .. source)
end

--- Collapse all runs of whitespace to a single space and trim. Used to compare
--- a (line-wrapped) buffer paragraph against an unwrapped cached `result` /
--- `source`, since wrapping only changes where whitespace falls.
---@param s string
---@return string
function M.normalize(s)
  return (vim.trim(s or ""):gsub("%s+", " "))
end

--- Open the SQLite database on first use. Any failure flips `enabled = false`
--- and we fall back to the in-memory table.
local function ensure_init()
  if state.inited then
    return
  end
  state.inited = true

  local cache_opts = (config.options and config.options.cache) or {}
  if cache_opts.enabled == false then
    state.enabled = false
    return
  end

  local ok_db, sqlite = pcall(require, "sqlite.db")
  local ok_tbl, sqlite_tbl = pcall(require, "sqlite.tbl")
  if not ok_db or not ok_tbl then
    state.enabled = false
    return
  end

  local path = cache_opts.path or (vim.fn.stdpath("data") .. "/translate/cache.db")
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")

  local ok_open, err = pcall(function()
    local translations = sqlite_tbl("translations", {
      hash = { "text", primary = true, required = true },
      engine = "text",
      target_lang = "text",
      source = "text",
      result = "text",
      created_at = "integer", -- os.time(); recorded only, never used to expire.
    })
    state.db = sqlite({
      uri = path,
      translations = translations,
      opts = { keep_open = false, lazy = true },
    })
    state.tbl = state.db.translations
  end)

  if not ok_open or not state.tbl then
    vim.schedule(function()
      vim.notify(
        "translate.cache: SQLite unavailable, using in-memory cache\n" .. tostring(err),
        vim.log.levels.WARN
      )
    end)
    state.enabled = false
    state.tbl = nil
    return
  end

  state.enabled = true
end

--- Look up a cached raw translation.
---@param engine string "deepl"|"fabric"
---@param lang string|nil target language code
---@param source string the original text to translate
---@return string|nil result the raw translation, or nil on miss
function M.get(engine, lang, source)
  ensure_init()
  local key = hash_key(engine, lang, source)
  if state.enabled and state.tbl then
    local ok, row = pcall(function()
      return state.tbl:where({ hash = key })
    end)
    if ok and row and row.result then
      return row.result
    end
    return nil
  end
  return state.mem[key]
end

--- Upsert a raw translation. When the SQLite write fails we degrade silently to
--- the in-memory table for this entry.
---@param engine string
---@param lang string|nil
---@param source string
---@param result string
function M.put(engine, lang, source, result)
  ensure_init()
  local key = hash_key(engine, lang, source)
  if state.enabled and state.tbl then
    local ok = pcall(function()
      if state.tbl:where({ hash = key }) then
        state.tbl:update({
          where = { hash = key },
          set = { result = result, created_at = os.time() },
        })
      else
        state.tbl:insert({
          hash = key,
          engine = engine,
          target_lang = lang,
          source = source,
          result = result,
          created_at = os.time(),
        })
      end
    end)
    if ok then
      return
    end
  end
  state.mem[key] = result
end

--- Drop a single cache entry.
---@param engine string
---@param lang string|nil
---@param source string
function M.invalidate(engine, lang, source)
  ensure_init()
  local key = hash_key(engine, lang, source)
  if state.enabled and state.tbl then
    pcall(function()
      state.tbl:remove({ hash = key })
    end)
  end
  state.mem[key] = nil
end

--- Clear the whole cache.
function M.clear()
  ensure_init()
  if state.enabled and state.tbl then
    pcall(function()
      state.tbl:remove()
    end)
  end
  state.mem = {}
end

--- Reverse lookup: given a translated text, find the original source that
--- produced it (whitespace-insensitive match against cached `result`). Enables
--- "undo translation" across sessions. Returns nil when degraded to memory
--- (the in-memory fallback only stores result by hash, so source is lost).
---@param result_text string the (possibly line-wrapped) translated text
---@return string|nil source the original text, or nil if not found
function M.find_source(result_text)
  ensure_init()
  if not (state.enabled and state.tbl) then
    return nil
  end
  local target = M.normalize(result_text)
  local ok, rows = pcall(function()
    return state.tbl:get()
  end)
  if not ok or not rows then
    return nil
  end
  for _, row in ipairs(rows) do
    if row.result and M.normalize(row.result) == target then
      return row.source
    end
  end
  return nil
end

--- Number of cached rows (for diagnostics / verification).
---@return integer
function M.count()
  ensure_init()
  if state.enabled and state.tbl then
    local ok, n = pcall(function()
      return state.tbl:count()
    end)
    if ok then
      return n
    end
    return 0
  end
  return vim.tbl_count(state.mem)
end

return M
