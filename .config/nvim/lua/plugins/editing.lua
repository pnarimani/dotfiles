local lowercase = {}

for code = string.byte("a"), string.byte("z") do
  lowercase[#lowercase + 1] = string.char(code)
end

return {
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = "VeryLazy",
  },
  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    config = function()
      local gen_spec = require("mini.ai").gen_spec
      require("mini.ai").setup({
        n_lines = 500,
        search_method = "cover_or_next",
        custom_textobjects = {
          f = gen_spec.treesitter({
            a = "@function.outer",
            i = "@function.inner",
          }),
        },
      })
    end,
  },
  {
    "Wansmer/treesj",
    cmd = { "TSJJoin", "TSJSplit", "TSJToggle" },
    opts = {
      use_default_keymaps = false,
      max_join_length = 120,
    },
  },
  {
    "unblevable/quick-scope",
    event = "VeryLazy",
    init = function()
      vim.g.qs_accepted_chars = lowercase
      vim.g.qs_filetype_blacklist = {
        "dap-repl",
        "lazy",
        "mason",
        "oil",
        "snacks_picker_input",
        "trouble",
      }
      vim.g.qs_buftype_blacklist = {
        "nofile",
        "terminal",
      }
    end,
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      disable_filetype = { "TelescopePrompt", "snacks_picker_input" },
      map_cr = true,
      map_bs = true,
    },
  },
}
