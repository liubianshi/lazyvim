-- Template consumed by the new-plugin-spec skill.
-- The skill replaces these sentinels at render time:
--   "PLACEHOLDER_AUTHOR_REPO"   → "<github-author>/<repo-name>"
--   "PLACEHOLDER_MODULE_NAME"   → the require() name
--   the entire `event = "VeryLazy",` line → user's chosen lazy trigger
return {
  {
    "PLACEHOLDER_AUTHOR_REPO",
    event = "VeryLazy",
    dependencies = {},
    opts = {},
    keys = {
      -- { "<leader>x", function() require("PLACEHOLDER_MODULE_NAME").action() end, desc = "..." },
    },
    config = function(_, opts)
      require("PLACEHOLDER_MODULE_NAME").setup(opts)
    end,
  },
}
