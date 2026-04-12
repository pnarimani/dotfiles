return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
      integrations = {
        cmp = false,
        lspconfig = true,
      },
    },
  },
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    cmd = "Mason",
    opts = {
      PATH = "prepend",
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      },
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event = "VeryLazy",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "delve",
        "js-debug-adapter",
        "lua-language-server",
        "netcoredbg",
        "roslyn",
        "vtsls",
      },
      run_on_start = true,
      start_delay = 0,
      debounce_hours = 24,
    },
  },
  {
    "seblyng/roslyn.nvim",
    lazy = true,
    ft = "cs",
  },
  {
    "nvim-flutter/flutter-tools.nvim",
    ft = "dart",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("config.lsp").setup_flutter()
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "folke/lazydev.nvim",
      "williamboman/mason.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "seblyng/roslyn.nvim",
      "nvim-flutter/flutter-tools.nvim",
    },
    config = function()
      require("config.lsp").setup()
    end,
  },
}
