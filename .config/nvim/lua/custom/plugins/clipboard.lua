-- sync system clipboard to vim clipboard
vim.api.nvim_create_autocmd("FocusGained", {
    callback = function()
        local loaded_content = vim.fn.getreg("+")
        if loaded_content ~= "" then
            vim.fn.setreg('"', loaded_content)
        end
    end,
})

-- sync vim clipboard to system clipboard
vim.api.nvim_create_autocmd("TextChanged", {
    callback = function()
        vim.schedule(function()
            local s = vim.fn.getreg('"')
            vim.system({ "echo", s, "| pbcopy" })
        end)
    end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.defer_fn(function()
            local now = vim.fn.getreg('"')
            vim.fn.setreg("+", now)
        end, 100)
    end,
})
