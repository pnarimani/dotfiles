local util = require("config.util")

local M = {}

local severity_error = vim.diagnostic.severity.ERROR

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "nvim" })
end

local function diagnostics_sort(a, b)
  local left = util.normalize(vim.api.nvim_buf_get_name(a.bufnr))
  local right = util.normalize(vim.api.nvim_buf_get_name(b.bufnr))

  if left == right then
    if a.lnum == b.lnum then
      return a.col < b.col
    end
    return a.lnum < b.lnum
  end

  return left < right
end

local function workspace_errors()
  local root = util.current_root(0)
  local items = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = util.normalize(vim.api.nvim_buf_get_name(bufnr))
      if name and name ~= "" and vim.startswith(name, root) then
        for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { severity = severity_error })) do
          items[#items + 1] = {
            bufnr = bufnr,
            lnum = diagnostic.lnum,
            col = diagnostic.col,
          }
        end
      end
    end
  end

  table.sort(items, diagnostics_sort)
  return items
end

local function jump_to_diagnostic(target)
  vim.api.nvim_win_set_buf(0, target.bufnr)
  vim.api.nvim_win_set_cursor(0, { target.lnum + 1, target.col })
end

local function next_workspace_error_target()
  local current = {
    bufnr = vim.api.nvim_get_current_buf(),
    lnum = vim.api.nvim_win_get_cursor(0)[1] - 1,
    col = vim.api.nvim_win_get_cursor(0)[2],
  }
  local items = workspace_errors()

  if #items == 0 then
    return nil
  end

  for _, item in ipairs(items) do
    if item.bufnr == current.bufnr then
      if item.lnum > current.lnum or (item.lnum == current.lnum and item.col > current.col) then
        return item
      end
    elseif diagnostics_sort(current, item) then
      return item
    end
  end

  return items[1]
end

local function code_action_params(kind)
  local params = vim.lsp.util.make_range_params(0)
  params.context = {
    diagnostics = vim.diagnostic.get(0),
    only = { kind },
  }
  return params
end

local function apply_code_action(client, action, bufnr)
  local resolved = action

  if not resolved.edit and not resolved.command and client:supports_method("codeAction/resolve") then
    local response = client:request_sync("codeAction/resolve", action, 1500, bufnr)
    if response and response.result then
      resolved = response.result
    end
  end

  if resolved.edit then
    vim.lsp.util.apply_workspace_edit(resolved.edit, client.offset_encoding)
  end

  local command = resolved.command
  if type(command) == "string" then
    command = {
      title = resolved.title,
      command = command,
      arguments = resolved.arguments,
    }
  end

  if command and client:supports_method("workspace/executeCommand") then
    client:request_sync("workspace/executeCommand", command, 1500, bufnr)
  end
end

local function apply_first_actions(kind)
  local responses = vim.lsp.buf_request_sync(0, "textDocument/codeAction", code_action_params(kind), 1500)
  if not responses then
    return
  end

  for client_id, response in pairs(responses) do
    local actions = response.result or {}
    local client = vim.lsp.get_client_by_id(client_id)
    if client then
      for _, action in ipairs(actions) do
        if not action.disabled then
          apply_code_action(client, action, 0)
          break
        end
      end
    end
  end
end

local function require_snacks()
  return require("snacks")
end

function M.goto_definition()
  require_snacks().picker.lsp_definitions({ include_current = false })
end

function M.goto_type_definition()
  require_snacks().picker.lsp_type_definitions({ include_current = false })
end

function M.goto_implementation()
  require_snacks().picker.lsp_implementations({ include_current = false })
end

function M.find_references()
  require_snacks().picker.lsp_references({ include_declaration = false })
end

function M.document_symbols()
  require_snacks().picker.lsp_symbols()
end

function M.workspace_symbols()
  require_snacks().picker.lsp_workspace_symbols()
end

function M.find_files()
  require_snacks().picker.files()
end

function M.live_grep()
  require_snacks().picker.grep()
end

function M.recent_files()
  require_snacks().picker.recent()
end

function M.open_lazygit()
  require_snacks().lazygit.open()
end

function M.open_lazygit_log()
  require_snacks().lazygit.log()
end

function M.code_action_menu()
  vim.lsp.buf.code_action()
end

function M.rename()
  vim.lsp.buf.rename()
end

function M.hover()
  vim.lsp.buf.hover()
end

function M.signature_help()
  vim.lsp.buf.signature_help()
end

function M.next_file_error()
  vim.diagnostic.jump({ count = 1, severity = severity_error, float = false })
end

function M.prev_file_error()
  vim.diagnostic.jump({ count = -1, severity = severity_error, float = false })
end

function M.next_workspace_error()
  local target = next_workspace_error_target()
  if not target then
    notify("No workspace errors", vim.log.levels.WARN)
    return
  end

  jump_to_diagnostic(target)
end

function M.goto_base()
  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params(bufnr)
  local fallback = function()
    require_snacks().picker.lsp_declarations({ include_current = false })
  end

  vim.lsp.buf_request_all(bufnr, "textDocument/prepareTypeHierarchy", params, function(results)
    local prepared = {}

    for client_id, response in pairs(results or {}) do
      local items = response.result or {}
      for _, item in ipairs(items) do
        prepared[#prepared + 1] = {
          client_id = client_id,
          item = item,
        }
      end
    end

    if #prepared == 0 then
      fallback()
      return
    end

    local pending = 0
    local choices = {}
    local seen = {}

    local function finish()
      if next(choices) == nil then
        fallback()
        return
      end

      table.sort(choices, function(a, b)
        return a.label < b.label
      end)

      if #choices == 1 then
        vim.lsp.util.jump_to_location(choices[1].location, choices[1].encoding, true)
        return
      end

      vim.ui.select(choices, {
        prompt = "Select base definition",
        format_item = function(choice)
          return choice.label
        end,
      }, function(choice)
        if choice then
          vim.lsp.util.jump_to_location(choice.location, choice.encoding, true)
        end
      end)
    end

    for _, entry in ipairs(prepared) do
      local client = vim.lsp.get_client_by_id(entry.client_id)
      if client and client:supports_method("typeHierarchy/supertypes") then
        pending = pending + 1
        client:request("typeHierarchy/supertypes", { item = entry.item }, function(err, result)
          pending = pending - 1

          if not err and result then
            for _, supertype in ipairs(result) do
              local location = {
                uri = supertype.uri,
                range = supertype.selectionRange or supertype.range,
              }
              local key = ("%s:%d:%d"):format(
                location.uri,
                location.range.start.line,
                location.range.start.character
              )
              if not seen[key] then
                local file = vim.uri_to_fname(location.uri)
                seen[key] = true
                choices[#choices + 1] = {
                  label = ("%s:%d"):format(vim.fn.fnamemodify(file, ":~:."), location.range.start.line + 1),
                  location = location,
                  encoding = client.offset_encoding,
                }
              end
            end
          end

          if pending == 0 then
            finish()
          end
        end, bufnr)
      end
    end

    if pending == 0 then
      fallback()
    end
  end)
end

function M.format_and_fix()
  for _, kind in ipairs({
    "source.fixAll",
    "source.organizeImports",
    "source.sortImports",
  }) do
    apply_first_actions(kind)
  end

  vim.lsp.buf.format({
    async = false,
    timeout_ms = 3000,
  })
end

function M.accept_copilot()
  local ok, suggestion = pcall(require, "copilot.suggestion")
  if not ok then
    return
  end

  if suggestion.is_visible() then
    suggestion.accept()
  end
end

return M
