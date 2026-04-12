local lazypath = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "lazy.nvim")

if not vim.uv.fs_stat(lazypath) then
  local result = vim.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  }):wait()

  if result.code ~= 0 then
    error(result.stderr ~= "" and result.stderr or "failed to clone lazy.nvim")
  end
end

vim.opt.rtp:prepend(lazypath)
