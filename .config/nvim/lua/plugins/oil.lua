return {
  {
    "stevearc/oil.nvim",
    lazy = false,
    dependencies = { "nvim-mini/mini.icons" },
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
      delete_to_trash = false,
      skip_confirm_for_simple_edits = true,
      prompt_save_on_select_new_entry = true,
      lsp_file_methods = {
        enabled = true,
      },
      view_options = {
        show_hidden = true,
      },
      win_options = {
        signcolumn = "yes",
      },
    },
  },
}
