local util = require("config.util")

return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      panel = {
        enabled = false,
      },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 30,
        hide_during_completion = true,
        keymap = {
          accept = false,
          accept_word = false,
          accept_line = false,
          next = false,
          prev = false,
          dismiss = false,
          toggle_auto_trigger = false,
        },
      },
      filetypes = {
        ["*"] = false,
        cs = true,
        dart = true,
        go = true,
        javascript = true,
        javascriptreact = true,
        lua = true,
        markdown = false,
        typescript = true,
        typescriptreact = true,
      },
      logger = {
        file_log_level = vim.log.levels.OFF,
        print_log_level = vim.log.levels.WARN,
        trace_lsp = "off",
      },
      copilot_node_command = util.executable({ "node", "nodejs" }) or "node",
      disable_limit_reached_message = true,
      root_dir = function()
        return util.current_root(0)
      end,
      should_attach = function(bufnr, bufname)
        if not vim.bo[bufnr].buflisted then
          return false
        end

        if vim.bo[bufnr].buftype ~= "" then
          return false
        end

        if vim.bo[bufnr].filetype == "markdown" then
          return false
        end

        if bufname:match("%.env") then
          return false
        end

        return true
      end,
      server_opts_overrides = {
        offset_encoding = "utf-16",
      },
    },
    config = function(_, opts)
      require("copilot").setup(opts)

      vim.api.nvim_create_autocmd("User", {
        pattern = "BlinkCmpMenuOpen",
        callback = function()
          vim.b.copilot_suggestion_hidden = true
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "BlinkCmpMenuClose",
        callback = function()
          vim.b.copilot_suggestion_hidden = false
        end,
      })
    end,
  },
  {
    "giuxtaposition/blink-cmp-copilot",
    lazy = true,
    dependencies = { "zbirenbaum/copilot.lua" },
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "giuxtaposition/blink-cmp-copilot",
    },
    opts = {
      keymap = {
        preset = "none",
        ["<C-n>"] = { "show_and_insert", "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-e>"] = { "cancel", "fallback" },
        ["<C-y>"] = { "accept", "fallback" },
        ["<Tab>"] = { "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },
      appearance = {
        kind_icons = {
          Copilot = "",
          Text = "󰉿",
          Method = "󰊕",
          Function = "󰊕",
          Constructor = "󰒓",
          Field = "󰜢",
          Variable = "󰆦",
          Property = "󰖷",
          Class = "󱡠",
          Interface = "󱡠",
          Struct = "󱡠",
          Module = "󰅩",
          Unit = "󰪚",
          Value = "󰦨",
          Enum = "󰦨",
          EnumMember = "󰦨",
          Keyword = "󰻾",
          Constant = "󰏿",
          Snippet = "󱄽",
          Color = "󰏘",
          File = "󰈔",
          Reference = "󰬲",
          Folder = "󰉋",
          Event = "󱐋",
          Operator = "󰪚",
          TypeParameter = "󰬛",
        },
      },
      completion = {
        ghost_text = {
          enabled = false,
        },
        list = {
          selection = {
            auto_insert = false,
            preselect = false,
          },
        },
      },
      sources = {
        default = { "lsp", "copilot" },
        per_filetype = {
          markdown = { "markdown_buffer" },
        },
        providers = {
          lsp = {
            fallbacks = {},
          },
          buffer = {
            enabled = false,
          },
          path = {
            enabled = false,
          },
          snippets = {
            enabled = false,
          },
          copilot = {
            name = "Copilot",
            module = "blink-cmp-copilot",
            async = true,
            score_offset = 100,
          },
          markdown_buffer = {
            name = "Buffer",
            module = "blink.cmp.sources.buffer",
            opts = {
              get_bufnrs = function()
                return { vim.api.nvim_get_current_buf() }
              end,
            },
          },
        },
      },
      cmdline = {
        enabled = true,
      },
      snippets = {
        preset = "default",
      },
      signature = {
        enabled = true,
      },
    },
  },
}
