local Marks = {}
Marks.__index = Marks
local api = vim.api

---@alias Extmarks.Detail vim.api.keyset.extmark_details

---@class Marks.Option
---@field ns_name string: The namespace name (a new namespace will be created). Required if ns_id is not provided.
---@field ns_track_prefix? string: Prefix for internal tracking marks. Defaults to "_extmark_hide_".
---@field default_hl_group? string: Default highlight group for restored extmarks if original had none. Defaults to "Comment".

-- Creates a new Marks manager instance.
--- @param opts Marks.Option
--- @return (table): The Marks instance.
function Marks.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Marks)

  self.ns_id = api.nvim_create_namespace(opts.ns_name)
  self.mark_prefix = opts.ns_track_prefix or opts.ns_name .. "_track"
  self.ns_track_id = api.nvim_create_namespace(opts.ns_track_prefix)
  self.default_hl_group = opts.default_hl_group or "Comment"
  self.marks = {}

  -- Use a more unique augroup name based on the namespace ID
  local augroup_name = "LbsMarksCleanup_" .. self.ns_id
  local augroup_id = api.nvim_create_augroup(augroup_name, { clear = true })

  api.nvim_create_autocmd("BufWipeOut", {
    group = augroup_id,
    pattern = "*", -- Apply to all buffers; callback checks if cache exists for the buffer
    callback = function(args)
      -- args.buf contains the buffer number being wiped out
      local bufnr = args.buf
      if bufnr and self.marks[bufnr] then
        -- Clear cache for the wiped buffer to prevent memory leaks
        self.marks[bufnr] = nil
        -- vim.notify("Cleared extmark cache for wiped buffer: " .. bufnr, vim.log.levels.DEBUG)
      end
    end,
    desc = "Clean extmark toggle cache on buffer wipeout for namespace " .. self.ns_id,
  })

  return self
end

---Gets the cache for a specific buffer, creating it if it doesn't exist.
---@param bufnr (integer): The buffer number.
---@return table: The cache table for the buffer.
function Marks:get_buffer_cache(bufnr)
  if not self.marks[bufnr] then
    self.marks[bufnr] = {}
  end
  return self.marks[bufnr]
end

---Finds visible extmarks within the managed namespace on a specific line.
---@param bufnr integer: The buffer number.
---@param row_0 integer: The 0-indexed row number.
---@param ns_id integer: the namespace id
---@return Extmarks.Detail[]
function Marks.find_visible_extmarks(bufnr, row_0, ns_id)
  local ok, visible_extmarks = pcall(
    api.nvim_buf_get_extmarks,
    bufnr,
    ns_id,
    { row_0, 0 }, -- Start of the line
    { row_0, -1 }, -- End of the line
    { details = true } -- Include extmark options
  )
  if not ok then
    return {}
  end
  return visible_extmarks
end

---Hides a single extmark: places a tracking mark, caches details, deletes the extmark.
---@param bufnr integer: The buffer number.
---@param extmark_details Extmarks.Detail
---@return boolean: true if hidden successfully, false otherwise.
function Marks:hide_extmark(bufnr, extmark_details)
  local id, start_row_0, start_col_0, _ = unpack(extmark_details)

  -- Set the tracking mark (API uses 1-based row, 0-based col)
  -- Use pcall as buffer/mark operations can fail
  local set_track_extmark_ok, track_extmark_id =
    pcall(api.nvim_buf_set_extmark, bufnr, self.ns_track_id, start_row_0, start_col_0, {})
  if not set_track_extmark_ok then
    vim.notify("Error setting tracking extmark: " .. track_extmark_id, vim.log.levels.ERROR)
    return false
  end

  local buffer_cache = self:get_buffer_cache(bufnr)
  local track_name = "track_" .. track_extmark_id

  -- Store necessary details for restoration, making a deep copy of opts
  buffer_cache[track_name] = vim.deepcopy(extmark_details)

  -- Delete the original extmark
  local del_ok, del_err = pcall(api.nvim_buf_del_extmark, bufnr, self.ns_id, id)
  if not del_ok then
    vim.notify("Error deleting extmark " .. id .. ": " .. del_err, vim.log.levels.ERROR)
    -- Clean up the tracking mark if extmark deletion fails
    pcall(api.nvim_buf_del_extmark, bufnr, self.ns_track_id, track_extmark_id)
    buffer_cache[track_name] = nil
    return false
  end

  return true
end

---Restores a single extmark based on its tracking mark name and cached details.
---@param bufnr integer: The buffer number.
---@param track_extmark Extmarks.Detail
---@param cached_extmark Extmarks.Detail: The cached extmark
---@return (boolean): true if restored successfully, false otherwise. Cache entry should be cleaned by caller on failure.
function Marks:restore_extmark(bufnr, track_extmark, cached_extmark)
  local _, current_row_0, current_col_0, _ = unpack(track_extmark)

  -- Make a deep copy of options to restore to avoid modifying the cache directly
  local _, start_row_0, start_col_0, extmark_opts = unpack(cached_extmark)
  extmark_opts = extmark_opts or {}
  local opts_to_restore = vim.deepcopy(extmark_opts)
  opts_to_restore.id = nil

  -- Calculate the new end position based on the original dimensions relative
  -- to the new start position
  if extmark_opts.end_row then
    local row_diff = (extmark_opts.end_row or start_row_0) - start_row_0
    local new_end_row_0 = current_row_0 + row_diff
    opts_to_restore.end_row = new_end_row_0
  end

  if extmark_opts.end_col then
    local new_end_col_0
    if extmark_opts.end_col ~= -1 and extmark_opts.end_row and extmark_opts.end_row == start_row_0 then
      -- Single line extmark: calculate end column based on original length relative to new start column
      local col_diff = extmark_opts.end_col - start_col_0
      new_end_col_0 = current_col_0 + col_diff
    else
      new_end_col_0 = extmark_opts.end_col
    end
    opts_to_restore.end_col = new_end_col_0
  end

  -- Recreate the extmark at the new position
  local set_ok, set_err =
    pcall(api.nvim_buf_set_extmark, bufnr, self.ns_id, current_row_0, current_col_0, opts_to_restore)
  if not set_ok then
    vim.notify("Error restoring extmark: " .. tostring(set_err), vim.log.levels.ERROR)
    -- Don't delete the tracking mark yet, as restore failed. Caller handles cache cleanup.
    return false
  end

  -- Caller is responsible for removing the entry from the buffer_cache upon success.
  return true
end

---@param bufnr integer
---@param row integer -- 1-based row
---@return boolean
function Marks:hide_extmarks(bufnr, row)
  local row_0 = row - 1 -- API functions use 0-based row indices
  local visible_marks_to_hide = self.find_visible_extmarks(bufnr, row_0, self.ns_id)
  if #visible_marks_to_hide == 0 then
    return false -- No extmarks found in the namespace on this line
  end

  local hidden_count = 0
  for _, extmark_details in ipairs(visible_marks_to_hide) do
    -- Attempt to hide each extmark individually
    -- hide_extmark handles setting the tracking mark, caching, and deleting the original
    if self:hide_extmark(bufnr, extmark_details) then
      hidden_count = hidden_count + 1
    else
      -- Error was logged/notified within hide_extmark
      vim.notify(
        "Failed to hide extmark " .. extmark_details[1] .. "on line" .. row .. ".",
        vim.log.levels.WARN,
        { title = "Extmark Toggle" }
      )
    end
  end

  if hidden_count > 0 then
    vim.notify(
      "Hid " .. hidden_count .. " extmark(s) on line " .. row .. ".",
      vim.log.levels.INFO,
      { title = "Extmark Toggle" }
    )
    return true -- Indicate that hiding occurred
  end

  return false -- No extmarks were successfully hidden (either none found or all hides failed)
end

---@param bufnr integer
---@param row integer -- 1-based row
---@return boolean
function Marks:restore_extmarks(bufnr, row)
  -- Find tracking extmarks placed by hide_extmarks on the target line
  local track_extmarks = self.find_visible_extmarks(bufnr, row - 1, self.ns_track_id)
  if #track_extmarks == 0 then
    -- No tracking marks found on this line, nothing to restore
    return false
  end

  local restored_count = 0
  local cache_keys_to_delete = {}
  local buffer_cache = self:get_buffer_cache(bufnr) -- Get buffer-specific cache

  for _, track_extmark in ipairs(track_extmarks) do
    local track_id = track_extmark[1] -- ID of the tracking extmark
    local track_name = "track_" .. track_id -- Key used for caching original extmark details
    local cached_extmark = buffer_cache[track_name] -- Retrieve cached details

    if cached_extmark then
      -- Attempt to restore the original extmark using cached details and current track position
      local restore_result = self:restore_extmark(bufnr, track_extmark, cached_extmark)
      if restore_result then
        -- Successfully restored: Delete the tracking extmark
        pcall(api.nvim_buf_del_extmark, bufnr, self.ns_track_id, track_id)
        -- Mark the cache entry for deletion
        table.insert(cache_keys_to_delete, track_name)
        restored_count = restored_count + 1
      else
        -- Restore failed (e.g., invalid position after edits):
        -- Still delete the tracking mark as it's no longer valid/restorable.
        pcall(api.nvim_buf_del_extmark, bufnr, self.ns_track_id, track_id)
        -- Mark the cache entry for deletion
        table.insert(cache_keys_to_delete, track_name)
        vim.notify(
          "Failed to restore extmark (original ID: "
            .. tostring(cached_extmark[1])
            .. ") on line "
            .. row
            .. ". Removing tracking mark.",
          vim.log.levels.WARN,
          { title = "Extmark Toggle" }
        )
      end
    else
      -- Orphaned tracking mark (no corresponding cache entry found):
      -- This indicates an inconsistent state, possibly due to manual cache manipulation
      -- or an error during hiding. Clean up the orphaned tracking mark.
      pcall(api.nvim_buf_del_extmark, bufnr, self.ns_track_id, track_id)
      vim.notify(
        "Found orphaned tracking extmark (ID: " .. track_id .. ") on line " .. row .. ". Removing.",
        vim.log.levels.WARN,
        { title = "Extmark Toggle" }
      )
      -- No cache entry to delete in this case.
    end
  end

  -- Clean up cache entries for successfully restored or failed extmarks
  if #cache_keys_to_delete > 0 then
    for _, key in ipairs(cache_keys_to_delete) do
      buffer_cache[key] = nil -- Remove entry from cache
    end
    -- vim.notify("Cleaned " .. #cache_keys_to_delete .. " cache entries.", vim.log.levels.DEBUG)
  end

  -- Notify about successful restorations only if any occurred
  if restored_count > 0 then
    vim.notify(
      "Restored " .. restored_count .. " extmark(s) on line " .. row .. ".",
      vim.log.levels.INFO,
      { title = "Extmark Toggle" }
    )
  end

  -- Return true if any tracking marks were processed (even if restoration failed)
  -- Return false only if no tracking marks were found initially.
  return true
end

-- Toggles the visibility of extmarks (managed by this instance) on the current cursor line.
-- If visible extmarks exist on the line, they are hidden.
-- If no visible extmarks exist, any hidden extmarks whose tracking mark is on the line are restored.
function Marks:toggle_extmarks_under_cursor_line()
  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)
  if not bufnr or bufnr <= 0 then
    return
  end -- Ensure valid buffer

  local cursor_pos = api.nvim_win_get_cursor(winid)
  local cursor_row = cursor_pos[1]

  -- 1. Try to HIDE visible extmarks at cursor line
  if Marks:hide_extmarks(bufnr, cursor_row) then
    return
  end

  -- 2. Try to RESTORE hidden extmarks whose tracking mark is on the current line
  Marks:restore_extmarks(bufnr, cursor_row)
end

return Marks
