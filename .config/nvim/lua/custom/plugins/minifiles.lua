vim.pack.add({ 'https://github.com/nvim-mini/mini.files' })

require("mini.files").setup()

vim.keymap.set('n', '<leader>e', function() require("mini.files").open(vim.api.nvim_buf_get_name(0)) end, { desc = 'Mini Files', silent = true })
