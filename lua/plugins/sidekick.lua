return {
  "folke/sidekick.nvim",
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
      "<leader>ag",
      function()
        require("sidekick.cli").toggle({ name = "gemini", focus = false })
      end,
      desc = "Sidekick Toggle Gemini",
    },
  },
}
