local parser_for_filetype = {
  bash = "bash",
  css = "css",
  cs = "c_sharp",
  dart = "dart",
  go = "go",
  gomod = "gomod",
  gosum = "gosum",
  gowork = "gowork",
  help = "vimdoc",
  html = "html",
  javascript = "javascript",
  javascriptreact = "tsx",
  json = "json",
  lua = "lua",
  markdown = "markdown",
  query = "query",
  sh = "bash",
  typescript = "typescript",
  typescriptreact = "tsx",
  vim = "vim",
  yaml = "yaml",
}

local parser_dependencies = {
  javascript = { "ecma", "jsx" },
  markdown = { "markdown_inline" },
  tsx = { "ecma", "jsx", "typescript" },
  typescript = { "ecma" },
}

local function parser_installed(parser)
  return #vim.api.nvim_get_runtime_file(("parser/%s.*"):format(parser), false) > 0
end

local function is_real_file_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if not vim.bo[bufnr].buflisted or vim.bo[bufnr].buftype ~= "" then
    return false
  end

  return vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function setup_on_demand_installer()
  local manager = require("tree-sitter-manager")
  local queued = {}
  local queue = {}
  local waiters = {}
  local running = false

  local function start_waiters(parser)
    local parser_waiters = waiters[parser]
    if not parser_waiters then
      return
    end

    waiters[parser] = nil

    for bufnr in pairs(parser_waiters) do
      if is_real_file_buffer(bufnr) then
        pcall(vim.treesitter.start, bufnr, parser)
      end
    end
  end

  local function install_next()
    if running then
      return
    end

    local parser = table.remove(queue, 1)
    if not parser then
      return
    end

    if parser_installed(parser) then
      queued[parser] = nil
      start_waiters(parser)
      install_next()
      return
    end

    running = true
    manager._install_single(parser, function()
      queued[parser] = nil
      running = false

      if parser_installed(parser) then
        start_waiters(parser)
      end

      install_next()
    end)
  end

  local function enqueue(parser)
    if queued[parser] then
      return
    end

    if parser_installed(parser) then
      start_waiters(parser)
      return
    end

    queued[parser] = true
    queue[#queue + 1] = parser
  end

  local function add_with_dependencies(parser)
    for _, dependency in ipairs(parser_dependencies[parser] or {}) do
      add_with_dependencies(dependency)
    end

    enqueue(parser)
  end

  local function ensure_parser(bufnr)
    if not is_real_file_buffer(bufnr) then
      return
    end

    local parser = parser_for_filetype[vim.bo[bufnr].filetype]
    if not parser then
      return
    end

    waiters[parser] = waiters[parser] or {}
    waiters[parser][bufnr] = true

    if parser_installed(parser) then
      start_waiters(parser)
      return
    end

    add_with_dependencies(parser)
    install_next()
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("config.treesitter_install", { clear = true }),
    pattern = vim.tbl_keys(parser_for_filetype),
    callback = function(args)
      ensure_parser(args.buf)
    end,
  })

  vim.schedule(function()
    ensure_parser(0)
  end)
end

return {
  {
    "romus204/tree-sitter-manager.nvim",
    event = { "BufReadPost", "BufNewFile" },
    cmd = "TSManager",
    opts = {},
    config = function(_, opts)
      require("tree-sitter-manager").setup(opts)
      vim.treesitter.language.register("c_sharp", "cs")
      setup_on_demand_installer()
    end,
  },
}
