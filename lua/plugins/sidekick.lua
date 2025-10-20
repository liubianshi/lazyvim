return {
  "folke/sidekick.nvim",
  opts = {
    nes = {
      enabled = true,
      auto_fetch = true,
    },
  },
  keys = {
    { "<leader>ac", false },
    { "<leader>as", false },
    { "<leader>aa", false },
    {
      "<leader>af",
      function()
        require("sidekick.cli").send({ msg = "{file}" })
      end,
      desc = "Send File",
    },
    {
      "<leader>ad",
      function()
        require("sidekick.cli").close()
      end,
      desc = "Detach a CLI Session",
    },
    {
      "<leader>at",
      function()
        require("sidekick.cli").send({ msg = "{this}" })
      end,
      mode = { "x", "n" },
      desc = "Send This",
    },
    {
      "<leader>ag",
      function()
        require("sidekick.cli").toggle({ name = "gemini", focus = false })
      end,
      desc = "Sidekick Toggle Gemini",
    },
  },
}
