return {
  {
    "nvim-mini/mini.icons",
    lazy = true,
    opts = {},
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
      "TmuxNavigatorProcessList",
    },
    keys = {
      { "<C-h>", "<Cmd><C-U>TmuxNavigateLeft<CR>", mode = "n", desc = "Navigate left" },
      { "<C-j>", "<Cmd><C-U>TmuxNavigateDown<CR>", mode = "n", desc = "Navigate down" },
      { "<C-k>", "<Cmd><C-U>TmuxNavigateUp<CR>", mode = "n", desc = "Navigate up" },
      { "<C-l>", "<Cmd><C-U>TmuxNavigateRight<CR>", mode = "n", desc = "Navigate right" },
      { "<C-\\>", "<Cmd><C-U>TmuxNavigatePrevious<CR>", mode = "n", desc = "Navigate previous" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.add({
        { "<leader>g", group = "git" },
        { "<leader>r", group = "refactor" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "debug" },
        { "<leader>x", group = "lists" },
      })
    end,
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      auto_refresh = true,
      focus = false,
      follow = true,
    },
  },
}
