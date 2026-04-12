return {
  {
    "folke/snacks.nvim",
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      quickfile = { enabled = true },
      picker = {
        enabled = true,
        ui_select = true,
      },
      lazygit = {
        enabled = true,
      },
      indent = {
        enabled = true,
        indent = {
          char = "│",
        },
        scope = {
          enabled = true,
          char = "│",
        },
      },
      scope = {
        enabled = true,
        treesitter = {
          enabled = true,
          blocks = {
            enabled = true,
          },
        },
        keys = {
          textobject = {},
          jump = {
            ["[i"] = {
              min_size = 1,
              bottom = false,
              cursor = false,
              edge = true,
              desc = "Jump to scope start",
            },
            ["]i"] = {
              min_size = 1,
              bottom = true,
              cursor = false,
              edge = true,
              desc = "Jump to scope end",
            },
          },
        },
      },
    },
  },
}
