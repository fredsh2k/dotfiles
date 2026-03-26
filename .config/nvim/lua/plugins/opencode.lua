return {
  "nickjvandyke/opencode.nvim",
  version = "*",
  dependencies = {
    {
      ---@module "snacks"
      "folke/snacks.nvim",
      optional = true,
    },
  },
  init = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- opencode is managed by Zellij layouts (started with --port 0).
      -- Disable auto-start/stop/toggle since Zellij owns the pane.
      server = {
        port = 4096, -- fixed web server port, started manually via opencode-server alias
        start = false,
        stop = false,
        toggle = false,
      },
    }

    -- Override i_cr after init so the snacks win config can be modified via opts table directly.
    -- vim.g doesn't support mixed keys needed for snacks win opts (neovim#12544), so we patch here.
    vim.schedule(function()
      local config = require("opencode.config")
      config.opts.ask.snacks.win.keys.i_cr = {
        "<CR>",
        "confirm", -- skip cmp_accept so <CR> always submits immediately
        mode = { "i", "n" },
      }
    end)

    vim.o.autoread = true -- Auto-reload files edited by opencode

    -- Resolve @this eagerly so the actual file path + line range appears in the prompt
    -- instead of the literal "@this" placeholder. Works for both normal (cursor position)
    -- and visual (line range) modes, and for snacks git diff preview buffers.
    local function ask_with_location()
      local context = require("opencode.context").new()
      local location = context:this() or ""
      require("opencode").ask(location .. " ", { context = context })
    end

    vim.keymap.set("n", "<leader>oa", ask_with_location, { desc = "Ask opencode" })
    vim.keymap.set("x", "<leader>oa", ask_with_location, { desc = "Ask opencode about selection" })
    vim.keymap.set({ "n", "x" }, "<leader>op", function() return require("opencode").operator("@this ") end, { desc = "Send to opencode", expr = true })
    vim.keymap.set("n", "<leader>opl", function() return require("opencode").operator("@this ") .. "_" end, { desc = "Send line to opencode", expr = true })
  end,
}
