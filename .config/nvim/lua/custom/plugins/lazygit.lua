vim.pack.add { "https://github.com/kdheepak/lazygit.nvim" }

vim.keymap.set('n', '<leader>gg', "<cmd>LazyGit<cr>", { desc = 'Lazy Git', silent = true })
