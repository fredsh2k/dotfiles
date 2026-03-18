return {
  "folke/persistence.nvim",
  opts = {
    dir = vim.fn.stdpath("state") .. "/sessions/",
    -- Don't auto-save sessions for ~/.copilot
    pre_save = function()
      local cwd = vim.fn.getcwd()
      if cwd:find(vim.fn.expand("~") .. "/.copilot", 1, true) then
        return false
      end
    end,
  },
}
