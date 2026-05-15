-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable unused providers
vim.g.loaded_perl_provider = 0

-- Prevent LazyVim's ruby extras from wiring up Mason's rubocop LSP.
-- Heaven's .rubocop.yml requires rubocop-capybara which isn't in Mason's
-- isolated gem env, causing "cannot load such file -- rubocop-capybara" on
-- every file open. ruby-lsp surfaces rubocop diagnostics via the bundle's
-- own rubocop add-on instead.
vim.g.lazyvim_ruby_formatter = "none"

-- Python provider (needed for Molten remote plugins)
-- Dedicated venv with pynvim + jupyter_client, independent of project venvs
vim.g.python3_host_prog = vim.fn.stdpath("data") .. "/python-provider/bin/python"

-- Never conceal markup characters anywhere, including markdown.
-- We want to see raw `**bold**`, `_italic_`, `[link](url)` etc. as-is.
vim.opt.conceallevel = 0
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "markdown.mdx" },
  callback = function()
    vim.opt_local.conceallevel = 0
    vim.opt_local.concealcursor = ""
  end,
})

-- Soft-wrap long lines visually (file is unchanged on disk).
-- LazyVim already maps j/k to gj/gk so cursor moves by visual lines when wrapped.
vim.opt.wrap = true
vim.opt.linebreak = true -- break at word boundaries instead of mid-word
vim.opt.breakindent = true -- continuation lines keep the same indent
