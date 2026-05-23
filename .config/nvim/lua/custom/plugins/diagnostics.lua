-- Workspace-aware diagnostic navigation.
--
-- Neovim's vim.diagnostic.jump() navigates within the current buffer only,
-- but gopls can publish diagnostics for files that are not currently open.
-- This mapping jumps to the next ERROR diagnostic across all known buffers.

local function jump_next_global_error()
  local errors = vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.ERROR })
  if #errors == 0 then
    vim.notify('No error diagnostics found', vim.log.levels.INFO)
    return
  end

  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  local cur_path = vim.api.nvim_buf_get_name(cur_buf)
  local cur_lnum = cur_pos[1] - 1
  local cur_col = cur_pos[2]

  table.sort(errors, function(a, b)
    local a_path = vim.api.nvim_buf_get_name(a.bufnr)
    local b_path = vim.api.nvim_buf_get_name(b.bufnr)
    if a_path ~= b_path then
      return a_path < b_path
    end
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)

  local target
  for _, diagnostic in ipairs(errors) do
    local d_path = vim.api.nvim_buf_get_name(diagnostic.bufnr)
    local is_after = d_path > cur_path or (d_path == cur_path and (diagnostic.lnum > cur_lnum or (diagnostic.lnum == cur_lnum and diagnostic.col > cur_col)))
    if is_after then
      target = diagnostic
      break
    end
  end

  local destination = target or errors[1]

  if destination.bufnr ~= vim.api.nvim_get_current_buf() then
    vim.api.nvim_set_current_buf(destination.bufnr)
  end

  vim.api.nvim_win_set_cursor(0, { destination.lnum + 1, destination.col })
  vim.cmd 'normal! zv'
  vim.diagnostic.open_float {
    bufnr = destination.bufnr,
    scope = 'cursor',
    focus = false,
  }
end

vim.keymap.set('n', '<leader>q', jump_next_global_error, {
  desc = 'Next [E]rror diagnostic (workspace)',
})
