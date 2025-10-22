-- Neovim configuration for the sidekick.nvim plugin
-- This plugin provides AI-assisted coding features via CLI and NES (likely Note-taking or similar)
return {
  "folke/sidekick.nvim",
  opts = {
    -- NES configuration: enables and auto-fetches notes or sessions
    nes = {
      enabled = true,
      auto_fetch = true,
    },
    -- CLI configuration: defines prompts for interactions
    cli = {
      prompts = {
        -- Prompt template for adding comments to functions or lines
        comment = "Add comment to {function|line}",
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
    { "<leader>af", function() require("sidekick.cli").send({ msg = "{file}" }) end,                       desc = "Sidekick: Send File",            },
    -- Close the current CLI session
    { "<leader>ad", function() require("sidekick.cli").close() end,                                        desc = "Sidekick: Detach a CLI Session", },
    -- Send selected text or current line to sidekick CLI
    { "<leader>at", function() require("sidekick.cli").send({ msg = "{this}" }) end, mode = { "x",  "n" }, desc = "Sidekick: Send This", },
    -- Toggle the Gemini AI integration (focus false means don't focus window)
    { "<leader>ag", function() require("sidekick.cli").toggle({ name = "gemini", focus = false }) end,     desc = "Sidekick: Toggle Gemini", },

    -- Sidekick NES keybindings group
    { "<leader>an", "",                                                desc = "+Sidekick NES"         },
    -- Toggle NES on/off
    { "<leader>ant", function() require("sidekick.nes").toggle() end,  desc = "Sidekick NES: toggle"  },
    -- Clear NES content
    { "<leader>anc", function() require("sidekick.nes").clear() end,   desc = "Sidekick NES: clear"   },
    -- Enable NES
    { "<leader>ane", function() require("sidekick.nes").enable() end,  desc = "Sidekick NES: enable"  },
    -- Disable NES
    { "<leader>and", function() require("sidekick.nes").disable() end, desc = "Sidekick NES: disable" },
    -- Update NES (likely fetch or refresh)
    { "<leader>anu", function() require("sidekick.nes").update() end,  desc = "Sidekick NES: update"  },
    -- stylua: ignore end
  },
}
