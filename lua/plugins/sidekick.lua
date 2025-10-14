return {
  "folke/sidekick.nvim",
  keys = {
    { "<leader>ac", false },
    { "<leader>as", false },
    {
      "<leader>af",
      function() require("sidekick.cli").send({ msg = "{file}" }) end,
      desc = "Send File",
    },
  },
}
