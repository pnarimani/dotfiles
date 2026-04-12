local M = {}

M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
M.path_sep = package.config:sub(1, 1)

function M.normalize(path)
  if not path or path == "" then
    return path
  end

  return vim.fs.normalize(path)
end

function M.join(...)
  return vim.fs.joinpath(...)
end

function M.exists(path)
  return path ~= nil and vim.uv.fs_stat(path) ~= nil
end

function M.is_dir(path)
  local stat = path and vim.uv.fs_stat(path) or nil
  return stat and stat.type == "directory" or false
end

function M.current_file(bufnr)
  return M.normalize(vim.api.nvim_buf_get_name(bufnr or 0))
end

function M.cwd()
  return M.normalize(vim.uv.cwd())
end

local function find_marker_in_dir(dir, marker)
  if marker:sub(1, 2) == "*." then
    local matches = vim.fn.glob(vim.fs.joinpath(dir, marker), false, true)
    if #matches > 0 then
      return matches[1]
    end
    return nil
  end

  local candidate = vim.fs.joinpath(dir, marker)
  if vim.uv.fs_stat(candidate) then
    return candidate
  end
end

function M.find_root(path, markers)
  if not path or path == "" then
    return M.cwd()
  end

  local dir = M.normalize(path)
  if not M.is_dir(dir) then
    dir = vim.fs.dirname(dir)
  end

  while dir and dir ~= "" do
    for _, marker in ipairs(markers) do
      local found = find_marker_in_dir(dir, marker)
      if found then
        return dir, found
      end
    end

    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  return vim.fs.dirname(M.normalize(path))
end

function M.root_for(fname, kind)
  local markers_by_kind = {
    lua = {
      ".luarc.json",
      ".luarc.jsonc",
      ".stylua.toml",
      "stylua.toml",
      "selene.toml",
      "selene.yml",
      "init.lua",
      ".git",
    },
    go = {
      "go.work",
      "go.mod",
      ".git",
    },
    ts = {
      "tsconfig.json",
      "jsconfig.json",
      "package.json",
      ".git",
    },
    dart = {
      "pubspec.yaml",
      ".git",
    },
    cs = {
      "*.slnx",
      "*.sln",
      "*.csproj",
      "ProjectSettings/ProjectVersion.txt",
      ".git",
    },
    generic = {
      "go.work",
      "go.mod",
      "pubspec.yaml",
      "tsconfig.json",
      "jsconfig.json",
      "package.json",
      "*.slnx",
      "*.sln",
      "*.csproj",
      ".luarc.json",
      ".luarc.jsonc",
      "ProjectSettings/ProjectVersion.txt",
      ".git",
    },
  }

  local root = M.find_root(fname, markers_by_kind[kind] or markers_by_kind.generic)
  return M.normalize(root or M.cwd())
end

function M.current_root(bufnr)
  local file = M.current_file(bufnr)
  if not file or file == "" then
    return M.cwd()
  end

  local extension = vim.fn.fnamemodify(file, ":e")
  local filetype = vim.bo[bufnr or 0].filetype

  if filetype == "lua" or extension == "lua" then
    return M.root_for(file, "lua")
  end
  if filetype == "go" or extension == "go" then
    return M.root_for(file, "go")
  end
  if filetype == "dart" or extension == "dart" then
    return M.root_for(file, "dart")
  end
  if filetype == "cs" or extension == "cs" then
    return M.root_for(file, "cs")
  end
  if vim.tbl_contains({ "javascript", "javascriptreact", "typescript", "typescriptreact" }, filetype) then
    return M.root_for(file, "ts")
  end

  return M.root_for(file, "generic")
end

function M.executable(names)
  local candidates = type(names) == "table" and names or { names }
  local suffixes = M.is_windows and { "", ".cmd", ".exe", ".bat" } or { "" }

  for _, name in ipairs(candidates) do
    for _, suffix in ipairs(suffixes) do
      local candidate = name .. suffix
      if vim.fn.executable(candidate) == 1 then
        return candidate
      end
    end
  end
end

function M.plugin_dir(name)
  local ok, config = pcall(require, "lazy.core.config")
  if not ok then
    return nil
  end

  local plugin = config.plugins[name]
  return plugin and plugin.dir or nil
end

function M.run(cmd, opts)
  local result = vim.system(cmd, opts or {}):wait()
  if result.code ~= 0 then
    error(result.stderr ~= "" and result.stderr or result.stdout)
  end
  return result
end

return M
