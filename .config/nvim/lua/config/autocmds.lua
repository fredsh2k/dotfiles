-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Force soft-wrap on every window enter. render-markdown.nvim and a few other
-- plugins set window-local `wrap = false` (see render-markdown/lib/compat.lua),
-- which survives until the window closes. This re-asserts our preference.
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
  group = vim.api.nvim_create_augroup("force_softwrap", { clear = true }),
  callback = function()
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.breakindent = true
  end,
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("puppet_filetype", { clear = true }),
  pattern = "*.pp",
  command = "setfiletype puppet",
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("open_dir_readme_explorer", { clear = true }),
  callback = function()
    if vim.fn.argc(-1) ~= 1 then
      return
    end

    local dir = vim.fn.argv(0, -1)
    if vim.fn.isdirectory(dir) ~= 1 then
      return
    end

    dir = vim.fn.fnamemodify(dir, ":p:h")
    vim.schedule(function()
      local readme = vim.fs.find(function(name)
        return name:lower():match("^readme") ~= nil
      end, { path = dir, type = "file", limit = 1 })[1]

      vim.cmd.tcd(vim.fn.fnameescape(dir))
      if readme then
        vim.cmd.edit(vim.fn.fnameescape(readme))
      end
      if not Snacks.picker.get({ source = "explorer" })[1] then
        Snacks.explorer({ cwd = dir })
      end
    end)
  end,
})
