vim.pack.add({ 'https://github.com/nvim-mini/mini.files' })

require("mini.files").setup()

vim.keymap.set('n', '<leader>e', require("mini.files").open, { desc = 'Mini Files', silent = true })
