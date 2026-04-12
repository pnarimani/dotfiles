local group = vim.api.nvim_create_augroup("user_config", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities.inlayHintProvider then
      pcall(vim.lsp.inlay_hint.enable, true, { bufnr = args.buf })
    end
  end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = function()
    vim.api.nvim_set_hl(0, "CopilotSuggestion", { fg = "#89ddff" })
    vim.api.nvim_set_hl(0, "CopilotAnnotation", { fg = "#89ddff" })
  end,
})
