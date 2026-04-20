-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable unused providers
vim.g.loaded_perl_provider = 0

-- Python provider (needed for Molten remote plugins)
-- Dedicated venv with pynvim + jupyter_client, independent of project venvs
vim.g.python3_host_prog = vim.fn.stdpath("data") .. "/python-provider/bin/python"

-- Show all markup characters (no concealing) globally,
-- but allow render-markdown.nvim to work in markdown files
vim.opt.conceallevel = 0
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "markdown.mdx" },
  callback = function()
    vim.opt_local.conceallevel = 2
  end,
})
