return {
  {
    "romus204/tree-sitter-manager.nvim",
    event = { "BufReadPost", "BufNewFile" },
    cmd = "TSManager",
    opts = {
      ensure_installed = {
        "bash",
        "c_sharp",
        "css",
        "dart",
        "go",
        "gomod",
        "gosum",
        "gowork",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "query",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
      },
    },
    config = function(_, opts)
      require("tree-sitter-manager").setup(opts)
      vim.treesitter.language.register("c_sharp", "cs")
    end,
  },
}
