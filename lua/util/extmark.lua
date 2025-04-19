local api = vim.api
local set_extmark = api.nvim_buf_set_extmark
local del_extmark = api.nvim_buf_del_extmark
local function notify(info, level)
  vim.notify(info, vim.log.levels[level] or vim.log.levels.INFO, { title = "Extmark Toggle" })
end

--- Manages hiding and restoring Neovim extmarks within a specific namespace.
-- This module allows toggling the visibility of sets of extmarks (e.g., diagnostics,
-- inline virtual text) on a line-by-line basis. It achieves this by temporarily
-- replacing original extmarks with lightweight "tracking" extmarks and caching
-- the original extmark details.
local Marks = {}
Marks.__index = Marks

--- Type Definitions ---

---@alias Extmarks.Detail vim.api.keyset.extmark_details Contains details of an extmark: {id, row, col, opts}

---@class Marks An instance managing extmark visibility for a namespace.
---@field ns_id integer The ID of the main namespace managed by this instance.
---@field ns_track_id integer The ID of the namespace used for tracking hidden extmarks.
---@field track_name_prefix string Prefix used for cache keys and tracking mark names.
---@field track_sign string String of length 1-2 used to display track extmark in the sign column.
---@field marks table<string, Extmarks.Detail> Cache storing hidden extmark details. Keyed by buffer number, then by tracking mark name (e.g., `track_prefix .. track_mark_id`).
-- Static methods
---@field new fun(ns_id, opts?: {ns_track_prefix?: string, track_name_prefix?: string}): Marks Creates a new Marks instance.
---@field find_visible_extmarks fun(bufnr: integer, row_0: integer, ns_id: integer): Extmarks.Detail[] Finds visible extmarks in a namespace on a line.
-- Instance methods
---@field hide_extmark fun(self: Marks, bufnr: integer, extmark_details: Extmarks.Detail): boolean|nil Hide a single extmark
---@field restore_extmark fun(self: Marks, bufnr: integer, track_extmark: Extmarks.Detail, cached_extmark: Extmarks.Detail): boolean|nil Restores a single extmark based on its tracking mark and cached details.
---@field hide_extmarks fun(self: Marks, bufnr: integer, row: integer): boolean|nil Hides visible extmarks on a line. Returns true if any marks were hidden, false if none found, nil on failure during hiding.
---@field restore_extmarks fun(self: Marks, bufnr: integer, row: integer): boolean Restores hidden extmarks on a line. Returns true if tracking marks were found and processed, false otherwise.
---@field toggle_extmarks fun(self: Marks, opts?: {winid?: integer, bufnr?: integer, row?:integer}): true|nil Toggles extmark visibility on the specified line. Returns true on completion, nil on initial error.

--- Constructor ---

-- Creates a new Marks manager instance.
---@param ns_name string The namespace name (a new namespace will be created). Required.
---@param opts? {ns_track_prefix?: string, track_name_prefix?: string, track_sign?: string} Initialization options.
---@return Marks The new Marks instance.
function Marks.new(ns_name, opts)
  opts = opts or {}
  local self = setmetatable({}, Marks)

  -- Create the main namespace for the extmarks to be managed
  self.ns_id = api.nvim_get_namespaces()[ns_name] or api.nvim_create_namespace(ns_name)

  -- Create a separate namespace for the tracking extmarks
  local mark_prefix = opts.ns_track_prefix or ns_name .. "_track"
  self.ns_track_id = api.nvim_create_namespace(mark_prefix)

  -- Store other configuration options
  self.track_name_prefix = opts.track_name_prefix or "track"
  self.track_sign = opts.track_sign or "󰊿"

  -- Initialize the cache for hidden extmarks (tracking mark name -> details)
  self.marks = {}

  return self
end

--- Private Helper Methods ---

---Gets the cache for a specific buffer, creating it if it doesn't exist.
---Ensures that each buffer has its own isolated cache of hidden marks.
---@param self Marks The Marks instance.
---@return table<string, Extmarks.Detail> The cache table for the specified buffer.
local function _get_cache(self)
  if not self.marks then
    self.marks = {} -- Lazily initialize the cache for this buffer
  end
  return self.marks
end

---Generate the name of track extmark
---@param bufnr integer The buffer number.
---@param track_id integer The track extmark id
---@return string
local function _generate_track_name(bufnr, track_id)
  return string.format("%s:%d:%d", Marks.track_name_praefix, bufnr, track_id)
end

--- Finds visible extmarks within a given namespace on a specific line.
--- This is a static method as it doesn't depend on instance state (`self`).
---@param bufnr integer The buffer number.
---@param row_0 integer The 0-indexed row number.
---@param ns_id integer The namespace ID to search within.
---@return Extmarks.Detail[] A list of extmark details found on the line. Returns an empty list on error or if none found.
function Marks.find_visible_extmarks(bufnr, row_0, ns_id)
  local ok, visible_extmarks = pcall(
    api.nvim_buf_get_extmarks,
    bufnr,
    ns_id,
    { row_0, 0 }, -- Start position: beginning of the line
    { row_0, -1 }, -- End position: end of the line (-1 signifies end of line)
    { details = true } -- Request details (id, row, col, opts)
  )
  if not ok then
    -- Log error if needed, but return empty list for graceful failure
    notify(
      string.format("Error finding extmarks in ns %s on line %s: %s", ns_id, (row_0 + 1), tostring(visible_extmarks)),
      "WARN"
    )
    return {}
  end
  return visible_extmarks
end

--- Core Logic Methods ---

--- Hides a single extmark:
--- 1. Caches its details using a deep copy.
--- 2. Deletes the original extmark from the main namespace (`self.ns_id`).
--- 3. Places a lightweight tracking extmark in the tracking namespace (`self.ns_track_id`) at the original start position.
---@param self Marks The Marks instance.
---@param bufnr integer The buffer number.
---@param extmark_details Extmarks.Detail The details of the extmark to hide.
---@return boolean True if the extmark was hidden successfully, false otherwise.
function Marks:hide_extmark(bufnr, extmark_details)
  local id, start_row_0, start_col_0, _ = unpack(extmark_details)

  -- Make a deep copy of the details *before* deleting the original extmark.
  -- This ensures we cache the correct state.
  local cached_extmark = vim.deepcopy(extmark_details)

  -- Delete the original extmark from the main namespace
  local del_ok, del_err = pcall(del_extmark, bufnr, self.ns_id, id)
  if not del_ok then
    notify("Error deleting extmark " .. id .. " from ns " .. self.ns_id .. ": " .. tostring(del_err), "ERROR")
    return false -- Failed to hide
  end

  -- Place a tracking extmark in the tracking namespace at the original start position.
  -- This mark acts as a placeholder to find hidden marks later.
  local set_track_ok, track_extmark_id_or_err =
    pcall(set_extmark, bufnr, self.ns_track_id, start_row_0, start_col_0, { sign_text = self.track_sign })
  if not set_track_ok then
    notify(
      "Error setting tracking extmark in ns " .. self.ns_track_id .. ": " .. tostring(track_extmark_id_or_err),
      "ERROR"
    )
    -- The original extmark was deleted, but tracking failed. This leaves an orphaned state.
    -- Consider potential recovery or more detailed logging if this becomes an issue.
    return false -- Report failure as the hiding process wasn't fully completed.
  end

  -- Store the cached details, using the tracking extmark's ID to create a unique key.
  local buffer_cache = _get_cache(self)
  local track_name = _generate_track_name(bufnr, track_extmark_id_or_err) -- Key based on tracking mark ID
  buffer_cache[track_name] = cached_extmark

  return true -- Successfully hidden and tracked
end

--- Restores a single extmark based on its tracking mark and cached details.
--- 1. Reads the current position of the tracking mark.
--- 2. Re-creates the original extmark at the tracking mark's *current* position, adjusting the end position based on original dimensions relative to the original start position.
--- 3. Deletes the tracking extmark and removes the cache entry *after* successful restoration.
---@param self Marks The Marks instance.
---@param bufnr integer The buffer number.
---@param track_extmark Extmarks.Detail The details of the *tracking* extmark (provides current position).
---@param cached_extmark Extmarks.Detail The *cached* details of the original extmark (provides original opts and dimensions).
---@return boolean True if restored successfully, false otherwise.
function Marks:restore_extmark(bufnr, track_extmark, cached_extmark)
  local track_id, current_row, current_col, _ = unpack(track_extmark)

  -- Delete track extmark
  pcall(del_extmark, bufnr, self.ns_track_id, track_id)
  local buffer_cache = _get_cache(self) -- Get buffer-specific cache
  local track_name = _generate_track_name(bufnr, track_id)
  buffer_cache[track_name] = nil

  local original_id, original_start_row, original_start_col, original_opts = unpack(cached_extmark)
  original_opts = original_opts or {}

  -- Create a deep copy of the original options to modify for restoration.
  -- Avoid modifying the cached data directly.
  local opts_to_restore = vim.deepcopy(original_opts)
  opts_to_restore.ns_id = nil -- Cannot reuse the old ID; Neovim assigns a new one.

  -- Adjust the end position relative to the new start position (current_row_0, current_col_0).
  -- This preserves the original span of the extmark.
  if opts_to_restore.end_row then
    local row_diff = opts_to_restore.end_row - original_start_row
    opts_to_restore.end_row = current_row + row_diff
  end

  if opts_to_restore.end_col then
    local new_end_col
    -- Check if it was a single-line extmark originally (not spanning multiple lines).
    if opts_to_restore.end_col ~= -1 and original_opts.end_row and original_opts.end_row == original_start_row then
      -- Calculate end column based on original length relative to the new start column.
      local col_diff = original_opts.end_col - original_start_col
      new_end_col = current_col + col_diff
    else
      -- For multi-line extmarks or those ending at EOL (`end_col` might be -1 or a specific column),
      -- keep the original end column value. The `end_row` adjustment handles the vertical shift.
      new_end_col = original_opts.end_col
    end
    opts_to_restore.end_col = new_end_col
  end

  -- Recreate the original extmark in the main namespace at the tracking mark's current position.
  local set_ok, set_err_or_new_id = pcall(
    set_extmark,
    bufnr,
    self.ns_id, -- Restore to the main namespace
    current_row,
    current_col,
    opts_to_restore
  )

  if not set_ok then
    notify("Error restoring extmark (original ID: " .. original_id .. "): " .. tostring(set_err_or_new_id), "ERROR")
    -- Do NOT delete the tracking mark or cache entry yet, as restoration failed.
    -- The caller (`restore_extmarks`) might handle cleanup, or it could be retried.
    return false
  end

  return true
end

--- Public API Methods ---

--- Hides all managed extmarks (from `self.ns_id`) found on a specific line.
--- Iterates through visible extmarks on the line and attempts to hide each one using `hide_extmark`.
---@param self Marks The Marks instance.
---@param bufnr integer The buffer number.
---@param row integer The 1-based row number.
---@return boolean True if at least one extmark was successfully hidden, false otherwise.
function Marks:hide_extmarks(bufnr, row)
  local row_0 = row - 1 -- Convert to 0-based index for API calls
  local visible_marks_to_hide = self.find_visible_extmarks(bufnr, row_0, self.ns_id)

  if #visible_marks_to_hide == 0 then
    return false -- No extmarks found in the managed namespace on this line
  end

  local hidden_count = 0
  for _, extmark_details in ipairs(visible_marks_to_hide) do
    -- Attempt to hide each extmark individually.
    -- `hide_extmark` handles caching, deleting original, and placing tracker.
    if self:hide_extmark(bufnr, extmark_details) then
      hidden_count = hidden_count + 1
    else
      -- Error was already logged/notified within `hide_extmark`
      -- Optional additional warning:
      notify("Failed attempt to hide extmark " .. extmark_details[1] .. " on line " .. row, "WARN")
    end
  end

  return true
end

--- Restores hidden extmarks whose tracking marks are found on the specified line.
--- Finds tracking marks, retrieves cached details, attempts restoration via `restore_extmark`,
--- and cleans up tracking marks/cache entries for processed marks (successful or failed).
---@param self Marks The Marks instance.
---@param bufnr integer The buffer number.
---@param row integer The 1-based row number.
---@return boolean True if any tracking marks were found and processed on the line (regardless of success), false if no tracking marks were found initially.
function Marks:restore_extmarks(bufnr, row)
  local row_0 = row - 1 -- Convert to 0-based index
  -- Find tracking extmarks (placeholders for hidden marks) on the target line.
  local track_extmarks = self.find_visible_extmarks(bufnr, row_0, self.ns_track_id)

  if #track_extmarks == 0 then
    return false -- No tracking marks found, nothing to restore
  end

  local restored_count = 0
  local buffer_cache = _get_cache(self) -- Get buffer-specific cache

  for _, track_extmark in ipairs(track_extmarks) do
    restored_count = restored_count + 1
    local track_id = track_extmark[1] -- ID of the tracking extmark
    local track_name = _generate_track_name(bufnr, track_id) -- Key used for caching original extmark details
    local cached_extmark = buffer_cache[track_name] -- Retrieve cached details using the key

    if cached_extmark then
      -- Found cached details, attempt to restore the original extmark.
      -- `restore_extmark` handles restoration, cache cleanup, and track mark deletion on success.
      local restore_success = self:restore_extmark(bufnr, track_extmark, cached_extmark)
      if restore_success then
        restored_count = restored_count + 1
      else
        -- Restore failed (error logged in `restore_extmark`).
        notify(
          "Failed restoration for track mark " .. track_id .. " on line " .. row .. ". Cleaning up tracker.",
          "WARN"
        )
      end
    else
      -- Orphaned tracking mark: Found a tracking mark but no corresponding cache entry.
      -- This indicates an inconsistent state, likely due to a previous error.
      notify("Found orphaned tracking extmark (ID: " .. track_id .. ") on line " .. row .. ". Removing.", "WARN")
      pcall(del_extmark, bufnr, self.ns_track_id, track_id)
    end
  end

  -- Return true because we found and processed tracking marks, even if some restorations failed.
  -- Return false only signifies that *no* tracking marks were present on the line initially.
  return true -- Indicates processing occurred.
end

--- Toggles the visibility of managed extmarks on the current cursor line.
--- If visible extmarks (in `self.ns_id`) exist on the line, they are hidden.
--- Otherwise, if hidden extmarks (tracked by `self.ns_track_id`) exist on the line, they are restored.
---@param self Marks The Marks instance.
---@param opts? {winid?: integer, bufnr?: integer, row?:integer}
---@return integer|nil
function Marks:toggle_extmarks(opts)
  opts = opts or {}
  local bufnr, cursor_row
  local RE = { PASS = 0, HIDE = 1, RESTORE = 2 }
  if not opts.bufnr or not opts.row then
    local winid = opts.winid or api.nvim_get_current_win()
    bufnr = api.nvim_win_get_buf(winid)
    cursor_row = api.nvim_win_get_cursor(winid)[1]
  else
    bufnr, cursor_row = opts.bufnr, opts.row
  end

  if not bufnr or bufnr <= 0 then
    notify("Invalid buffer.", "ERROR")
    return
  end -- Ensure valid buffer

  if not cursor_row then
    notify("Invalid Row.", "ERROR")
    return
  end

  -- Priority 1: Check for visible extmarks in the main namespace and try to HIDE them.
  -- We use `find_visible_extmarks` first to avoid unnecessary notifications from `hide_extmarks` if nothing is there.
  if self:hide_extmarks(bufnr, cursor_row) then
    return RE.HIDE
  end

  -- Priority 2: No visible marks found, check for hidden (tracking) marks and try to RESTORE them.
  local restored = self:restore_extmarks(bufnr, cursor_row)
  return restored and RE.RESTORE or RE.PASS
end

return Marks
