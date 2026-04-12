local util = require("config.util")

local function build_unity_debug(plugin)
  util.run({ "git", "submodule", "update", "--init", "--recursive" }, { cwd = plugin.dir })

  local msbuild = util.executable("msbuild")
  if msbuild then
    util.run({
      msbuild,
      "UnityDebug/UnityDebug.csproj",
      "/restore",
      "/p:Configuration=Release",
    }, { cwd = plugin.dir })
    return
  end

  if util.executable("dotnet") then
    util.run({
      "dotnet",
      "msbuild",
      "UnityDebug/UnityDebug.csproj",
      "/restore",
      "/p:Configuration=Release",
    }, { cwd = plugin.dir })
    return
  end

  error("Unity debugger build requires msbuild or dotnet msbuild")
end

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
        "nvim-neotest/nvim-nio",
        "rcarriga/nvim-dap-ui",
        "theHamsta/nvim-dap-virtual-text",
        "leoluz/nvim-dap-go",
        "jbyuki/one-small-step-for-vimkind",
        {
          "Unity-Technologies/vscode-unity-debug",
        name = "vscode-unity-debug",
        build = build_unity_debug,
      },
    },
    config = function()
      require("config.dap").setup()
    end,
  },
}
