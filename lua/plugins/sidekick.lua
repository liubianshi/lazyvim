-- Neovim configuration for the sidekick.nvim plugin
-- This plugin provides AI-assisted coding features via CLI and NES (Note-taking or Session management)
local function get_sidekick_terminal_win()
  local ok, State = pcall(require, "sidekick.cli.state")
  if ok then
    for _, st in ipairs(State.get({ attached = true, terminal = true })) do
      local t = st.terminal
      if t and t:win_valid() then
        return t.win
      end
    end
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.b[buf].sidekick_cli ~= nil then
      return win
    end
  end
end

return {
  "folke/sidekick.nvim",
  opts = {
    mux = {
      enabled = true,
    },
    -- NES configuration: enables and auto-fetches notes or sessions
    nes = {
      enabled = false,
      auto_fetch = false,
      trigger = {
        events = { "TextChanged", "User SidekickNesDone" },
      },
      update_interval = 300,
      -- New: Enable error logging for better debugging
      log_errors = true,
    },
    tools = {
      claude = {
        cmd = { "claude", "--allow-dangerously-skip-permissions" },
      }
    },
    -- CLI configuration: defines prompts for interactions
    cli = {
      prompts = {
        -- Prompt template for adding comments to functions or lines
        comment = "Add comment to {function|line}",
        -- New: Prompt for explaining code
        explain = "Explain the following code: {this}",
        -- New: Prompt for refactoring code
        refactor = "Refactor this code for better readability: {this}",
        -- New: Prompt for debugging issues
        debug = "Debug and suggest fixes for this code: {this}",
        -- New: Prompt for generating tests
        test = "Generate unit tests for {function|this}",
      },
    },
  },
  keys = {
    -- stylua: ignore start
    -- Disable default keybindings for ac, as, aa
    { "<leader>ac", false },
    { "<leader>as", false },
    { "<leader>aa", false },

    -- Send the entire file to sidekick CLI
    { "<leader>af", function() require("sidekick.cli").send({ msg = "{file}" }) end,                   desc = "Sidekick: Send File", },
    -- Close the current CLI session
    { "<leader>ad", function() require("sidekick.cli").close() end,                                    desc = "Sidekick: Detach a CLI Session", },
    { "<leader>at", function() require("sidekick.cli").send({ msg = "{this}" }) end,                   mode = { "x", "n" },                     desc = "Sidekick: Send This", },
    { "<leader>ag", function() require("sidekick.cli").toggle({ name = "gemini", focus = false }) end, desc = "Sidekick: Toggle Gemini", },
    { "<leader>ac", function() require("sidekick.cli").toggle({ name = "claude", focus = false }) end, desc = "Sidekick: Toggle Gemini", },
    -- Open split buffer (anchored under sidekick CLI terminal) to write prompt
    {
      "<leader>ap",
      function()
        require("util.float_prompt").toggle("Sidekick", {
          filetype = "markdown",
          title_prefix = " 💬 ",
          pos = "split",
          anchor_win_fn = get_sidekick_terminal_win,
          on_submit = function(text) require("sidekick.cli").send({ msg = text }) end,
        })
      end,
      mode = { "n" },
      desc = "Sidekick: open split window for prompts",
    },
    -- Sidekick NES keybindings group
    { "<leader>an",  "",                                               desc = "+Sidekick NES" },
    -- Toggle NES on/off
    { "<leader>ant", function() require("sidekick.nes").toggle() end,  desc = "Sidekick NES: Toggle" },
    -- Clear NES content
    { "<leader>anc", function() require("sidekick.nes").clear() end,   desc = "Sidekick NES: Clear" },
    -- Enable NES
    { "<leader>ane", function() require("sidekick.nes").enable() end,  desc = "Sidekick NES: Enable" },
    -- Disable NES
    { "<leader>and", function() require("sidekick.nes").disable() end, desc = "Sidekick NES: Disable" },
    -- Update NES (likely fetch or refresh)
    { "<leader>anu", function() require("sidekick.nes").update() end,  desc = "Sidekick NES: Update" },
    -- stylua: ignore end
  },
}
