local util = require("config.util")

local M = {}

local configured = false

local function unity_adapter()
  local plugin_dir = util.plugin_dir("vscode-unity-debug")
  if not plugin_dir then
    return nil
  end

  local binary = vim.fs.joinpath(plugin_dir, "bin", "UnityDebug.exe")
  if not util.exists(binary) then
    return nil
  end

  if util.is_windows then
    return {
      command = binary,
      args = {},
    }
  end

  local mono = util.executable("mono")
  if not mono then
    return nil
  end

  return {
    command = mono,
    args = { binary },
  }
end

local function setup_js_debug(dap)
  local cmd = util.executable("js-debug-adapter")
  if not cmd then
    return
  end

  local resolved = vim.fn.exepath(cmd)
  if resolved ~= "" then
    cmd = resolved
  end

  local function get_free_port()
    local tcp = assert(vim.uv.new_tcp(), "failed to create TCP handle")
    assert(tcp:bind("127.0.0.1", 0), "failed to bind free TCP port")
    local socket = tcp:getsockname()
    tcp:close()
    return socket.port
  end

  local function start_adapter(callback)
    local port = get_free_port()
    local stderr = vim.uv.new_pipe(false)

    local handle, pid_or_err = vim.uv.spawn(cmd, {
      args = { tostring(port), "127.0.0.1" },
      stdio = { nil, nil, stderr },
      detached = false,
    }, function()
      if stderr and not stderr:is_closing() then
        stderr:close()
      end
      if handle and not handle:is_closing() then
        handle:close()
      end
    end)

    if not handle then
      error("failed to launch js-debug-adapter: " .. tostring(pid_or_err))
    end

    stderr:read_start(function(err, chunk)
      if err then
        vim.schedule(function()
          vim.notify("js-debug-adapter stderr: " .. err, vim.log.levels.ERROR)
        end)
        return
      end

      if chunk and chunk ~= "" then
        vim.schedule(function()
          vim.notify(vim.trim(chunk), vim.log.levels.WARN, { title = "js-debug-adapter" })
        end)
      end
    end)

    local timer = assert(vim.uv.new_timer(), "failed to create JS adapter timer")
    local started = vim.uv.hrtime()

    local function finish(err)
      timer:stop()
      timer:close()
      if err then
        error(err)
      end

      callback({
        type = "server",
        host = "127.0.0.1",
        port = port,
      })
    end

    timer:start(100, 100, function()
      local client = vim.uv.new_tcp()
      client:connect("127.0.0.1", port, function(err)
        if not err then
          client:shutdown()
          client:close()
          vim.schedule(function()
            finish()
          end)
          return
        end

        client:close()
        if (vim.uv.hrtime() - started) / 1e6 > 10000 then
          vim.schedule(function()
            finish("js-debug-adapter did not start listening on port " .. port)
          end)
        end
      end)
    end)
  end

  for _, name in ipairs({ "pwa-node", "node-terminal", "pwa-chrome", "pwa-msedge" }) do
    dap.adapters[name] = start_adapter
  end

  for _, language in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
    dap.configurations[language] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch current file",
        program = "${file}",
        cwd = "${workspaceFolder}",
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach to Node process",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
      },
    }
  end
end

local function flutter_paths()
  local flutter = util.executable("flutter")
  if not flutter then
    return nil
  end

  local flutter_bin = vim.fn.resolve(vim.fn.exepath(flutter))
  if flutter_bin == "" then
    return nil
  end

  local flutter_sdk = vim.fn.fnamemodify(flutter_bin, ":h:h")
  local dart_sdk = vim.fs.joinpath(flutter_sdk, "bin", "cache", "dart-sdk")
  if not util.is_dir(dart_sdk) then
    dart_sdk = vim.fs.joinpath(flutter_sdk, "cache", "dart-sdk")
  end

  return {
    flutter_bin = flutter_bin,
    flutter_sdk = flutter_sdk,
    dart_sdk = dart_sdk,
  }
end

local function dart_program()
  local root = util.current_root(0)
  local flutter_main = vim.fs.joinpath(root, "lib", "main.dart")
  if util.exists(flutter_main) then
    return flutter_main
  end

  local root_name = vim.fn.fnamemodify(root, ":t")
  return vim.fs.joinpath(root, "bin", root_name .. ".dart")
end

local function setup_dart(dap)
  local paths = flutter_paths()
  if not paths then
    return
  end

  dap.adapters.dart = {
    type = "executable",
    command = paths.flutter_bin,
    args = { "debug-adapter" },
  }

  if util.is_windows then
    dap.adapters.dart.options = {
      detached = false,
    }
  end

  dap.configurations.dart = {
    {
      type = "dart",
      request = "launch",
      name = "Launch flutter",
      dartSdkPath = paths.dart_sdk,
      flutterSdkPath = paths.flutter_sdk,
      program = dart_program,
    },
    {
      type = "dart",
      request = "attach",
      name = "Connect flutter",
      dartSdkPath = paths.dart_sdk,
      flutterSdkPath = paths.flutter_sdk,
      program = dart_program,
    },
  }
end

local function setup_coreclr(dap)
  local netcoredbg = util.executable("netcoredbg")
  if not netcoredbg then
    return
  end

  dap.adapters.coreclr = {
    type = "executable",
    command = netcoredbg,
    args = { "--interpreter=vscode" },
  }

  dap.configurations.cs = {
    {
      type = "coreclr",
      request = "launch",
      name = "Launch .NET dll",
      program = function()
        local root = util.current_root(0)
        return vim.fn.input("Path to dll: ", root .. util.path_sep, "file")
      end,
      cwd = "${workspaceFolder}",
    },
    {
      type = "coreclr",
      request = "attach",
      name = "Attach to .NET process",
      processId = require("dap.utils").pick_process,
    },
  }

  local unity = unity_adapter()
  if unity then
    dap.adapters.unity = {
      type = "executable",
      command = unity.command,
      args = unity.args,
    }

    table.insert(dap.configurations.cs, 1, {
      type = "unity",
      request = "launch",
      name = "Unity Editor",
      path = "Library/EditorInstance.json",
    })
  end
end

local function setup_lua(dap)
  dap.adapters.nlua = function(callback, config)
    callback({
      type = "server",
      host = config.host or "127.0.0.1",
      port = config.port or 8086,
    })
  end

  dap.configurations.lua = {
    {
      type = "nlua",
      request = "attach",
      name = "Attach to running Neovim",
      host = "127.0.0.1",
      port = function()
        return tonumber(vim.fn.input("OSV port: ", "8086"))
      end,
    },
  }
end

function M.setup()
  if configured then
    return
  end

  configured = true

  local dap = require("dap")
  local dapui = require("dapui")

  require("nvim-dap-virtual-text").setup({
    commented = true,
  })

  dapui.setup({})

  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end

  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end

  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end

  setup_js_debug(dap)
  setup_dart(dap)
  setup_coreclr(dap)
  setup_lua(dap)

  require("dap-go").setup({
    delve = {
      detached = not util.is_windows,
    },
    dap_configurations = {
      {
        type = "go",
        name = "Attach remote",
        mode = "remote",
        request = "attach",
      },
    },
  })
end

function M.continue()
  require("dap").continue()
end

function M.toggle_breakpoint()
  require("dap").toggle_breakpoint()
end

function M.conditional_breakpoint()
  require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
end

function M.step_into()
  require("dap").step_into()
end

function M.step_over()
  require("dap").step_over()
end

function M.step_out()
  require("dap").step_out()
end

function M.toggle_repl()
  require("dap").repl.toggle()
end

function M.toggle_ui()
  require("dapui").toggle()
end

function M.terminate()
  require("dap").terminate()
end

function M.launch_osv()
  require("osv").launch({ port = 8086 })
end

function M.debug_nearest_go_test()
  if vim.bo.filetype ~= "go" then
    vim.notify("Go test debugging is only available in Go buffers", vim.log.levels.WARN)
    return
  end

  require("dap-go").debug_test()
end

function M.pick_configuration()
  local dap = require("dap")
  local configs = dap.configurations[vim.bo.filetype] or {}

  if #configs == 0 then
    vim.notify("No debug configurations for " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end

  vim.ui.select(configs, {
    prompt = "Select debug target",
    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if choice then
      dap.run(choice)
    end
  end)
end

return M
