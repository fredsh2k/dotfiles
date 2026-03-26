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

    vim.o.autoread = true -- Auto-reload files edited by opencode

    vim.keymap.set("n", "<leader>oa", function() require("opencode").ask() end, { desc = "Ask opencode" })
    vim.keymap.set("x", "<leader>oa", function() require("opencode").ask("@this ") end, { desc = "Ask opencode about selection" })
    vim.keymap.set({ "n", "x" }, "<leader>op", function() return require("opencode").operator("@this ") end, { desc = "Send to opencode", expr = true })
    vim.keymap.set("n", "<leader>opl", function() return require("opencode").operator("@this ") .. "_" end, { desc = "Send line to opencode", expr = true })
  end,
}
