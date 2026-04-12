local util = require("config.util")

local M = {}

local configured = false
local flutter_configured = false
local roslyn_autocmds_configured = false
local roslyn_initialized_clients = {}

local function capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  caps.general.positionEncodings = { "utf-16" }
  caps = require("blink.cmp").get_lsp_capabilities(caps)
  return caps
end

local function on_attach(_, bufnr)
  vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
end

local function is_unity_root(root)
  return root and util.exists(util.join(root, "ProjectSettings", "ProjectVersion.txt"))
end

local function unity_project_contains_file(root, file)
  local projects = vim.fn.glob(util.join(root, "*.csproj"), false, true)
  for _, csproj in ipairs(projects) do
    for _, line in ipairs(vim.fn.readfile(csproj)) do
      local include = line:match('<Compile Include="([^"]+)"')
      if include then
        local normalized_include = include:gsub("\\", util.path_sep)
        local candidate = util.normalize(util.join(root, normalized_include))
        if candidate == file then
          return true
        end
      end
    end
  end
  return false
end

local function warn_missing_unity_project_file(bufnr, root)
  if vim.b[bufnr].unity_missing_csproj_warning then
    return
  end

  vim.b[bufnr].unity_missing_csproj_warning = true

  local file = util.current_file(bufnr)
  local relative = file
  local prefix = root .. util.path_sep
  if vim.startswith(file, prefix) then
    relative = file:sub(#prefix + 1)
  end

  vim.schedule(function()
    vim.notify(
      ("Unity project files are stale: %s is missing from the generated .csproj files. Regenerate project files to restore full C# project context."):format(relative),
      vim.log.levels.WARN,
      { title = "Neovim" }
    )
  end)
end

local function maybe_rebind_roslyn_unity_buffer(client, bufnr)
  if not client or not roslyn_initialized_clients[client.id] or not is_unity_root(client.config.root_dir) then
    return
  end

  if not vim.api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].filetype ~= "cs" then
    return
  end

  local rebound_key = "roslyn_unity_rebound_" .. client.id
  if vim.b[bufnr][rebound_key] then
    return
  end

  local file = util.current_file(bufnr)
  if not unity_project_contains_file(client.config.root_dir, file) then
    warn_missing_unity_project_file(bufnr, client.config.root_dir)
    return
  end

  vim.b[bufnr][rebound_key] = true
  vim.lsp.buf_detach_client(bufnr, client.id)
  vim.lsp.buf_attach_client(bufnr, client.id)
  require("roslyn.lsp.diagnostics").refresh(client)
end

local function reattach_roslyn_buffers(client)
  if not client then
    return
  end

  for _, bufnr in ipairs(vim.tbl_keys(client.attached_buffers)) do
    maybe_rebind_roslyn_unity_buffer(client, bufnr)
  end
end

local function setup_roslyn_autocmds()
  if roslyn_autocmds_configured then
    return
  end

  roslyn_autocmds_configured = true

  local group = vim.api.nvim_create_augroup("config.roslyn", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "RoslynInitialized",
    callback = function(args)
      local client_id = args.data and args.data.client_id
      if not client_id then
        return
      end

      roslyn_initialized_clients[client_id] = true

      vim.schedule(function()
        local client = vim.lsp.get_client_by_id(client_id)
        if client and client.name == "roslyn" then
          reattach_roslyn_buffers(client)
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client_id = args.data and args.data.client_id
      if not client_id then
        return
      end

      local client = vim.lsp.get_client_by_id(client_id)
      if not client or client.name ~= "roslyn" then
        return
      end

      vim.schedule(function()
        maybe_rebind_roslyn_unity_buffer(client, args.buf)
      end)
    end,
  })
end

local function default_config(root_kind)
  return {
    capabilities = capabilities(),
    on_attach = on_attach,
    root_dir = function(bufnr, on_dir)
      local fname = vim.api.nvim_buf_get_name(bufnr)
      on_dir(util.root_for(fname, root_kind))
    end,
  }
end

function M.setup()
  if configured then
    return
  end

  configured = true

  vim.lsp.config("lua_ls", vim.tbl_deep_extend("force", default_config("lua"), {
    settings = {
      Lua = {
        completion = {
          callSnippet = "Replace",
        },
        diagnostics = {
          globals = { "vim" },
        },
        format = {
          enable = true,
        },
        hint = {
          enable = true,
        },
        runtime = {
          version = "LuaJIT",
        },
        telemetry = {
          enable = false,
        },
        workspace = {
          checkThirdParty = false,
        },
      },
    },
  }))
  vim.lsp.enable("lua_ls")

  vim.lsp.config("gopls", vim.tbl_deep_extend("force", default_config("go"), {
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
        },
        completeUnimported = true,
        gofumpt = true,
        staticcheck = true,
        usePlaceholders = true,
      },
    },
  }))
  vim.lsp.enable("gopls")

  vim.lsp.config("vtsls", vim.tbl_deep_extend("force", default_config("ts"), {
    single_file_support = false,
    settings = {
      vtsls = {
        autoUseWorkspaceTsdk = true,
        enableMoveToFileCodeAction = true,
      },
      javascript = {
        updateImportsOnFileMove = {
          enabled = "always",
        },
      },
      typescript = {
        updateImportsOnFileMove = {
          enabled = "always",
        },
      },
    },
  }))
  vim.lsp.enable("vtsls")

  vim.lsp.config("roslyn", {
    capabilities = capabilities(),
    on_attach = on_attach,
    settings = {
      ["csharp|background_analysis"] = {
        dotnet_analyzer_diagnostics_scope = "fullSolution",
        dotnet_compiler_diagnostics_scope = "fullSolution",
      },
      ["csharp|code_lens"] = {
        dotnet_enable_references_code_lens = true,
        dotnet_enable_tests_code_lens = true,
      },
      ["csharp|completion"] = {
        dotnet_show_completion_items_from_unimported_namespaces = true,
        dotnet_show_name_completion_suggestions = true,
      },
      ["csharp|formatting"] = {
        dotnet_organize_imports_on_format = true,
      },
      ["csharp|inlay_hints"] = {
        csharp_enable_inlay_hints_for_implicit_object_creation = true,
        csharp_enable_inlay_hints_for_implicit_variable_types = false,
        csharp_enable_inlay_hints_for_lambda_parameter_types = true,
        csharp_enable_inlay_hints_for_types = true,
        dotnet_enable_inlay_hints_for_object_creation_parameters = true,
        dotnet_enable_inlay_hints_for_other_parameters = true,
        dotnet_enable_inlay_hints_for_parameters = true,
      },
      ["csharp|symbol_search"] = {
        dotnet_search_reference_assemblies = true,
      },
    },
  })

  setup_roslyn_autocmds()

  require("roslyn").setup({
    broad_search = true,
    lock_target = false,
    silent = true,
    choose_target = function(targets)
      table.sort(targets)
      for _, target in ipairs(targets) do
        if target:match("%.slnx?$") then
          return target
        end
      end
      return targets[1]
    end,
  })
end

function M.setup_flutter()
  if flutter_configured then
    return
  end

  flutter_configured = true

  require("flutter-tools").setup({
    debugger = {
      enabled = true,
      evaluate_to_string_in_debug_views = true,
    },
    root_patterns = { "pubspec.yaml", ".git" },
    widget_guides = {
      enabled = false,
    },
    dev_tools = {
      autostart = false,
      auto_open_browser = false,
    },
    outline = {
      auto_open = false,
    },
    closing_tags = {
      enabled = true,
      prefix = ">",
      highlight = "Comment",
    },
    lsp = {
      on_attach = on_attach,
      capabilities = capabilities(),
      settings = {
        showTodos = true,
        completeFunctionCalls = true,
        renameFilesWithClasses = "prompt",
      },
    },
  })
end

return M
