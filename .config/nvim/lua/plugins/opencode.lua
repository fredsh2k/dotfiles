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
      -- No fixed port: auto-connects to the opencode instance whose CWD matches Neovim's CWD.
      server = {
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

    -- Resolve the file location eagerly so the actual path + line range appears in the
    -- prompt instead of the "@this" placeholder. Handles two cases:
    --   1. Inside a snacks picker (e.g. git diff, references): read from the current item.
    --   2. Regular buffer: use the current window's buffer + cursor/selection directly.
    local function ask_with_location()
      local location = ""

      -- Check if a snacks picker is active
      local pickers = require("snacks.picker").get()
      if #pickers > 0 then
        local picker = pickers[#pickers] -- use most recent
        local items = picker:selected({ fallback = true })
        local item = items and items[1]
        if item and item.file then
          location = require("opencode.context").format(item.file, {
            start_line = item.pos and item.pos[1] or nil,
            start_col = item.pos and item.pos[2] or nil,
          }) or ""
        end
      end

      -- Use the current window's buffer directly (avoids last_used_valid_win picking wrong buf)
      if location == "" then
        local buf = vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win())
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
        local filepath = vim.api.nvim_buf_get_name(buf)
        local is_file = buftype == "" and filepath ~= "" and vim.fn.isdirectory(filepath) == 0
        if is_file then
          local context = require("opencode.context").new()
          location = context:this() or ""
          require("opencode").ask(location .. " ", { context = context })
          return
        end
      end

      require("opencode").ask(location .. " ")
    end

    vim.keymap.set("n", "<leader>oa", ask_with_location, { desc = "Ask opencode" })
    vim.keymap.set("x", "<leader>oa", ask_with_location, { desc = "Ask opencode about selection" })
    vim.keymap.set({ "n", "x" }, "<leader>op", function() return require("opencode").operator("@this ") end, { desc = "Send to opencode", expr = true })
    vim.keymap.set("n", "<leader>opl", function() return require("opencode").operator("@this ") .. "_" end, { desc = "Send line to opencode", expr = true })
  end,
}
