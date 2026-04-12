local actions = require("config.actions")
local dap = require("config.dap")

local map = vim.keymap.set

map("n", "gd", actions.goto_definition, { desc = "Go to definition", silent = true })
map("n", "gD", actions.goto_type_definition, { desc = "Go to type definition", silent = true })
map("n", "gi", actions.goto_implementation, { desc = "Go to implementation", silent = true })
map("n", "gr", actions.find_references, { desc = "Find usages", silent = true, nowait = true })
map("n", "gb", actions.goto_base, { desc = "Go to base definition", silent = true })
map("n", "K", actions.hover, { desc = "Hover", silent = true })
map("i", "<C-k>", actions.signature_help, { desc = "Signature help", silent = true })

map("n", "<leader>re", actions.code_action_menu, { desc = "Refactor menu", silent = true })
map("n", "<leader>rr", actions.code_action_menu, { desc = "Refactor menu", silent = true })
map("n", "<leader>rn", actions.rename, { desc = "Rename symbol", silent = true })
map("n", "<leader>f", actions.format_and_fix, { desc = "Format and fix", silent = true })
map({ "n", "x" }, "<leader>d", [["_d]], { desc = "Delete to blackhole", silent = true })

map("n", "<leader>sf", actions.find_files, { desc = "Search files", silent = true })
map("n", "<leader>sg", actions.live_grep, { desc = "Live grep", silent = true })
map("n", "<leader>ss", actions.workspace_symbols, { desc = "Workspace symbols", silent = true })
map("n", "<leader>sd", actions.document_symbols, { desc = "Document symbols", silent = true })
map("n", "<leader>sr", actions.recent_files, { desc = "Recent files", silent = true })

map("n", "<leader>gg", actions.open_lazygit, { desc = "LazyGit", silent = true })
map("n", "<leader>gl", actions.open_lazygit_log, { desc = "LazyGit log", silent = true })
map("n", "<leader>q", actions.next_workspace_error, { desc = "Next workspace error", silent = true })
map("n", "]d", actions.next_file_error, { desc = "Next file error", silent = true })
map("n", "[d", actions.prev_file_error, { desc = "Previous file error", silent = true })

map("n", "-", "<Cmd>Oil<CR>", { desc = "Open parent directory", silent = true })
map("n", "<leader>e", function()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.uv.cwd()
  end
  vim.cmd(("Oil %s"):format(vim.fn.fnameescape(dir)))
end, { desc = "Open explorer", silent = true })

map("n", "<leader>j", function()
  require("treesj").toggle()
end, { desc = "Toggle split/join", silent = true })

map("n", "<leader>J", function()
  require("treesj").toggle({
    split = { recursive = true },
    join = { recursive = true },
  })
end, { desc = "Recursive split/join", silent = true })

map("n", "<leader>xx", "<Cmd>Trouble diagnostics toggle<CR>", { desc = "Workspace diagnostics", silent = true })
map("n", "<leader>xX", "<Cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Buffer diagnostics", silent = true })
map("n", "<leader>xq", "<Cmd>Trouble qflist toggle<CR>", { desc = "Quickfix list", silent = true })

map("n", "<leader>tc", dap.continue, { desc = "Debug continue", silent = true })
map("n", "<leader>tb", dap.toggle_breakpoint, { desc = "Toggle breakpoint", silent = true })
map("n", "<leader>tB", dap.conditional_breakpoint, { desc = "Conditional breakpoint", silent = true })
map("n", "<leader>tp", dap.pick_configuration, { desc = "Pick debug target", silent = true })
map("n", "<leader>ti", dap.step_into, { desc = "Step into", silent = true })
map("n", "<leader>to", dap.step_over, { desc = "Step over", silent = true })
map("n", "<leader>tO", dap.step_out, { desc = "Step out", silent = true })
map("n", "<leader>tr", dap.toggle_repl, { desc = "Toggle REPL", silent = true })
map("n", "<leader>tu", dap.toggle_ui, { desc = "Toggle debug UI", silent = true })
map("n", "<leader>tt", dap.terminate, { desc = "Terminate debug session", silent = true })
map("n", "<leader>ts", dap.launch_osv, { desc = "Launch Lua debug server", silent = true })
map("n", "<leader>td", dap.debug_nearest_go_test, { desc = "Debug nearest Go test", silent = true })

map("i", "<Tab>", actions.accept_copilot, { desc = "Accept Copilot", silent = true })
