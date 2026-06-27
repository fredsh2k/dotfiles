vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Native-first Neovim config. Learn stock commands before adding plugins.

-- Options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.confirm = true
vim.opt.undofile = true
vim.opt.completeopt = { "menu", "menuone", "popup", "noinsert" }
vim.opt.diffopt:append({ "algorithm:histogram", "indent-heuristic", "inline:word" })
vim.opt.grepprg = "rg --vimgrep --smart-case"
vim.opt.grepformat = "%f:%l:%c:%m"
vim.opt.conceallevel = 0

-- Providers
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- Native package manager.
vim.pack.add({
  { src = "https://github.com/echasnovski/mini.extra" },
  { src = "https://github.com/echasnovski/mini.files" },
  { src = "https://github.com/echasnovski/mini.icons" },
  { src = "https://github.com/echasnovski/mini.pick" },
  { src = "https://github.com/folke/which-key.nvim" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/projekt0n/github-nvim-theme" },
})

vim.cmd.colorscheme("github_dark_dimmed")

require("mini.extra").setup()
require("mini.icons").setup()
require("mini.files").setup({
  options = {
    use_as_default_explorer = false,
  },
})
require("mini.pick").setup()

require("which-key").setup({
  preset = "helix",
  delay = 300,
  filter = function(mapping)
    -- which-key flags the native comment operator (`gc`) as overlapping with
    -- the native line mapping (`gcc`). Keep both mappings, hide only the
    -- operator from which-key's health/tree output.
    return not (mapping.mode == "n" and mapping.lhs == "gc")
  end,
  icons = {
    mappings = true,
  },
})

local wk = require("which-key")

-- Helpers
local function project_root()
  return vim.fs.root(0, { ".git", "go.mod", "Cargo.toml", "Gemfile", "package.json", "tsconfig.json" })
    or vim.uv.cwd()
end

local function run_git(args)
  local cmd = { "git" }
  vim.list_extend(cmd, args)
  return vim.system(cmd, { text = true, cwd = project_root() }):wait()
end

local function default_base_branch()
  local candidates = {
    { "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" },
    { "rev-parse", "--verify", "--quiet", "origin/main" },
    { "rev-parse", "--verify", "--quiet", "origin/master" },
    { "rev-parse", "--verify", "--quiet", "main" },
    { "rev-parse", "--verify", "--quiet", "master" },
  }

  for _, args in ipairs(candidates) do
    local result = run_git(args)
    if result.code == 0 then
      local branch = vim.trim(result.stdout or "")
      if branch ~= "" then
        return (branch:gsub("^refs/remotes/", ""))
      end
      if args[#args] == "origin/main" or args[#args] == "origin/master" or args[#args] == "main" or args[#args] == "master" then
        return args[#args]
      end
    end
  end

  vim.notify("Could not find origin/main, origin/master, main, or master", vim.log.levels.ERROR)
end

require("gitsigns").setup({
  base = default_base_branch(),
  numhl = true,
  on_attach = function(bufnr)
    local gs = require("gitsigns")

    vim.keymap.set("n", "]c", function()
      if vim.wo.diff then
        vim.cmd("normal! ]c")
        return
      end
      gs.nav_hunk("next")
    end, { buffer = bufnr, desc = "Next git hunk" })

    vim.keymap.set("n", "[c", function()
      if vim.wo.diff then
        vim.cmd("normal! [c")
        return
      end
      gs.nav_hunk("prev")
    end, { buffer = bufnr, desc = "Previous git hunk" })

    vim.keymap.set("n", "<leader>gd", function()
      gs.diffthis(default_base_branch())
    end, { buffer = bufnr, desc = "Diff file vs base" })
    vim.keymap.set("n", "<leader>gp", gs.preview_hunk, { buffer = bufnr, desc = "Preview git hunk" })
    vim.keymap.set("n", "<leader>gb", gs.blame_line, { buffer = bufnr, desc = "Blame git line" })
    vim.keymap.set("n", "<leader>gq", gs.setqflist, { buffer = bufnr, desc = "Git hunks quickfix" })

  end,
})

local function quickfix_from_lines(lines, title)
  local items = vim.tbl_map(function(file)
    return { filename = file, lnum = 1, col = 1, text = file }
  end, lines)
  vim.fn.setqflist({}, " ", { title = title, items = items })
  vim.cmd.copen()
end

local function quickfix_from_vimgrep(lines, title)
  vim.fn.setqflist({}, " ", { title = title, lines = lines })
  vim.cmd.copen()
end

local function search_ruby_constant_definition(word)
  if not word:match("^%u") then
    return false
  end

  local pattern = "^\\s*(class|module)\\s+" .. word .. "\\b"
  local result = vim.system({ "rg", "--vimgrep", pattern }, { text = true, cwd = project_root() }):wait()
  local lines = vim.split(vim.trim(result.stdout or ""), "\n", { trimempty = true })
  if #lines == 1 then
    quickfix_from_vimgrep(lines, "Definition search: " .. word)
    vim.cmd.cfirst()
    vim.cmd.cclose()
    return true
  elseif #lines > 1 then
    quickfix_from_vimgrep(lines, "Definition search: " .. word)
    return true
  end

  return false
end

local function goto_definition_or_search()
  local word = vim.fn.expand("<cword>")
  if search_ruby_constant_definition(word) then
    return
  end

  local before = {
    buf = vim.api.nvim_get_current_buf(),
    pos = vim.api.nvim_win_get_cursor(0),
  }
  vim.lsp.buf.definition({
    on_list = function(options)
      if #options.items > 0 then
        vim.fn.setqflist({}, " ", options)
        vim.cmd.cfirst()
      end
    end,
  })

  vim.defer_fn(function()
    if vim.api.nvim_get_current_buf() ~= before.buf
      or vim.api.nvim_win_get_cursor(0)[1] ~= before.pos[1]
      or vim.api.nvim_win_get_cursor(0)[2] ~= before.pos[2]
    then
      return
    end

    if not search_ruby_constant_definition(word) then
      vim.notify("No definition found for " .. word, vim.log.levels.WARN)
    end
  end, 500)
end

local function pick_document_symbols()
  local pick = require("mini.pick")

  local jump_to_symbol = function(item)
    if not item then
      return
    end

    local win = pick.get_picker_state().windows.target
    if not vim.api.nvim_win_is_valid(win) then
      return
    end

    vim.api.nvim_win_call(win, function()
      vim.api.nvim_win_set_cursor(0, { item.lnum, math.max(item.col - 1, 0) })
      vim.cmd("normal! zvzt")
    end)
  end

  local move = function(delta)
    local matches = pick.get_picker_matches()
    if not matches or not matches.all_inds or not matches.current_ind then
      return
    end

    local position = 1
    for index, item_index in ipairs(matches.all_inds) do
      if item_index == matches.current_ind then
        position = index
        break
      end
    end

    local next_position = ((position + delta - 1) % #matches.all_inds) + 1
    pick.set_picker_match_inds({ matches.all_inds[next_position] }, "current")
    jump_to_symbol(pick.get_picker_matches().current)
  end

  vim.lsp.buf.document_symbol({
    on_list = function(options)
      if not options.items or #options.items == 0 then
        vim.notify("No document symbols", vim.log.levels.INFO)
        return
      end

      pick.start({
        source = {
          items = options.items,
          name = "Document symbols",
          choose = jump_to_symbol,
          show = function(buf_id, items)
            local lines = vim.tbl_map(function(item)
              return item.text
            end, items)
            vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
          end,
        },
        mappings = {
          symbol_down = {
            char = "<Down>",
            func = function()
              move(1)
            end,
          },
          symbol_up = {
            char = "<Up>",
            func = function()
              move(-1)
            end,
          },
        },
        window = {
          config = function()
            local width = math.max(math.floor(vim.o.columns * 0.45), 40)
            local height = math.max(math.floor(vim.o.lines * 0.25), 8)
            return {
              anchor = "SW",
              col = 0,
              row = vim.o.lines - vim.o.cmdheight - 1,
              width = math.min(width, vim.o.columns - 2),
              height = math.min(height, vim.o.lines - vim.o.cmdheight - 3),
            }
          end,
        },
      })
    end,
  })
end

local function github_origin_url()
  local result = run_git({ "remote", "get-url", "origin" })
  if result.code ~= 0 then
    vim.notify("Could not read git origin remote", vim.log.levels.WARN)
    return
  end

  local remote = vim.trim(result.stdout or "")
  local owner_repo = remote:match("^git@github%.com:(.+)%.git$")
    or remote:match("^git@github%.com:(.+)$")
    or remote:match("^https://github%.com/(.+)%.git$")
    or remote:match("^https://github%.com/(.+)$")
  if not owner_repo then
    vim.notify("Origin remote is not a GitHub URL", vim.log.levels.WARN)
    return
  end

  return "https://github.com/" .. owner_repo
end

local function current_file_relative_path()
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("Current buffer has no file", vim.log.levels.WARN)
    return
  end

  local root = vim.fs.normalize(project_root())
  file = vim.fs.normalize(file)
  if not vim.startswith(file, root .. "/") then
    vim.notify("Current file is outside project root", vim.log.levels.WARN)
    return
  end

  return file:sub(#root + 2)
end

local function yank_github_permalink(start_line, end_line)
  local origin = github_origin_url()
  local file = current_file_relative_path()
  local base = default_base_branch()
  if not origin or not file or not base then
    return
  end

  base = base:gsub("^origin/", "")
  local anchor = start_line == end_line and ("#L" .. start_line) or ("#L" .. start_line .. "-L" .. end_line)
  local url = origin .. "/blob/" .. base .. "/" .. file .. anchor
  vim.fn.setreg("+", url)
  vim.notify("Copied: " .. url)
end

local function git_changed_files(base)
  base = base or default_base_branch()
  if not base then
    return
  end
  local root = project_root()
  local result = run_git({ "diff", "--name-only", base .. "...HEAD" })
  if result.code ~= 0 then
    vim.notify(result.stderr, vim.log.levels.ERROR)
    return
  end

  local files = vim.split(vim.trim(result.stdout or ""), "\n", { trimempty = true })
  if #files == 0 then
    vim.notify("No changed files for " .. base .. "...HEAD", vim.log.levels.INFO)
    return
  end

  local pick = require("mini.pick")
  local choose = function(file)
    local path = vim.fs.joinpath(root, file)
    local win = pick.get_picker_state().windows.target
    if not vim.api.nvim_win_is_valid(win) then
      win = vim.api.nvim_get_current_win()
    end
    vim.api.nvim_win_call(win, function()
      vim.cmd.edit(vim.fn.fnameescape(path))
    end)
  end
  local preview = function(buf_id, file)
    local path = vim.fs.joinpath(root, file)
    local lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path, "", 200) or { "Unable to preview " .. file }
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    vim.bo[buf_id].filetype = vim.filetype.match({ filename = path }) or ""
  end

  pick.start({
    source = {
      items = files,
      name = "PR files: " .. base .. "...HEAD",
      cwd = root,
      choose = choose,
      preview = preview,
      show = pick.default_show,
    },
    mappings = {
      move_down = "<Down>",
      move_up = "<Up>",
    },
  })
end

local function git_pr_diff(base)
  base = base or default_base_branch()
  if not base then
    return
  end
  local result = run_git({ "diff", "--relative", base .. "...HEAD" })
  if result.code ~= 0 then
    vim.notify(result.stderr, vim.log.levels.ERROR)
    return
  end

  vim.cmd.tabnew()
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "diff"
  vim.api.nvim_buf_set_name(buf, "PR diff " .. base .. "...HEAD")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result.stdout, "\n"))
  vim.bo[buf].modifiable = false
end

local function pick_recent_project_files()
  local root = vim.fs.normalize(project_root())
  local items = {}
  local seen = {}

  local add_path = function(path)
    if path == "" then
      return
    end
    path = vim.fs.normalize(path)
    if seen[path] or vim.fn.filereadable(path) ~= 1 or not vim.startswith(path, root .. "/") then
      return
    end
    seen[path] = true
    table.insert(items, path:sub(#root + 2))
  end
  local show = function(buf_id, entries)
    local lines = {}
    local extmarks = {}
    for index, path in ipairs(entries) do
      local icon, hl = require("mini.icons").get("file", vim.fs.joinpath(root, path))
      lines[index] = icon .. "  " .. path
      extmarks[index] = { hl = hl, col = 0, end_col = #icon }
    end
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    for line, mark in ipairs(extmarks) do
      vim.api.nvim_buf_set_extmark(buf_id, vim.api.nvim_create_namespace("recent_files_icons"), line - 1, mark.col, {
        end_col = mark.end_col,
        hl_group = mark.hl,
      })
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
      add_path(vim.api.nvim_buf_get_name(buf))
    end
  end
  for _, path in ipairs(vim.v.oldfiles) do
    add_path(path)
  end

  if #items == 0 then
    vim.notify("No recent files in " .. root, vim.log.levels.INFO)
    return
  end

  require("mini.pick").start({
    source = {
      items = items,
      name = "Recent files",
      cwd = root,
      show = show,
    },
  })
end

local function toggle_explorer()
  local current = vim.api.nvim_buf_get_name(0)
  if current == "" or vim.startswith(current, "minifiles:") then
    current = project_root()
  end
  require("mini.files").open(current)
end

-- Keymaps: thin wrappers over native commands.
vim.keymap.set("n", "<leader>e", toggle_explorer, { desc = "Explorer" })
vim.keymap.set("n", "<leader>ff", function()
  require("mini.pick").builtin.files({ tool = "git" })
end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fr", pick_recent_project_files, { desc = "Recent files" })
vim.keymap.set("n", "<leader>fg", function()
  require("mini.pick").builtin.grep({ tool = "rg" }, { source = { cwd = project_root() } })
end, { desc = "Grep text" })
vim.keymap.set("n", "<leader>q", "<cmd>copen<cr>", { desc = "Quickfix", nowait = true })
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>", { desc = "Close quickfix" })
vim.keymap.set("n", "<leader>Q", "<cmd>confirm qall<cr>", { desc = "Quit all" })
vim.keymap.set("n", "<leader>sv", "<cmd>vsplit<cr>", { desc = "Vertical split" })
vim.keymap.set("n", "<leader>sh", "<cmd>split<cr>", { desc = "Horizontal split" })
vim.keymap.set("n", "<leader>yp", function()
  local path = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Yank relative path" })
vim.keymap.set("v", "<leader>yp", function()
  local path = vim.fn.fnamemodify(vim.fn.expand("%"), ":~:.")
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  local ref = start_line == end_line and (path .. "#L" .. start_line)
    or (path .. "#L" .. start_line .. "-L" .. end_line)
  vim.fn.setreg("+", ref)
  vim.notify("Copied: " .. ref)
end, { desc = "Yank path with lines" })
vim.keymap.set("n", "<leader>yg", function()
  yank_github_permalink(vim.fn.line("."), vim.fn.line("."))
end, { desc = "Yank GitHub permalink" })
vim.keymap.set("v", "<leader>yg", function()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  yank_github_permalink(start_line, end_line)
end, { desc = "Yank GitHub permalink" })

-- Git/PR review.
vim.keymap.set("n", "<leader>gf", function()
  git_changed_files()
end, { desc = "PR changed files" })
vim.keymap.set("n", "<leader>gc", "<cmd>cclose<cr>", { desc = "Close quickfix" })

wk.add({
  { "<leader>f", group = "find" },
  { "<leader>g", group = "git" },
  { "<leader>l", group = "lsp" },
  { "<leader>s", group = "splits" },
  { "<leader>y", group = "yank" },
})

-- Filetypes
vim.filetype.add({
  extension = {
    epp = "puppet",
    gotmpl = "gotmpl",
    pp = "puppet",
    tmpl = "gotmpl",
  },
  pattern = {
    [".*%.gohtml"] = "gotmpl",
  },
})

-- LSP: native configs. Install servers with Homebrew/project tooling.
vim.lsp.config("ruby_lsp", {
  cmd = { "ruby-lsp" },
  filetypes = { "ruby", "eruby" },
  root_markers = { "Gemfile", ".ruby-version", ".git" },
})

vim.lsp.config("gopls", {
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = { "go.work", "go.mod", ".git" },
})

vim.lsp.config("rust_analyzer", {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_markers = { "Cargo.toml", "rust-project.json", ".git" },
})

vim.lsp.config("ts_ls", {
  cmd = { "typescript-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
})

vim.lsp.config("puppet", {
  cmd = { "puppet-languageserver", "--stdio" },
  filetypes = { "puppet" },
  root_markers = { "Puppetfile", "environment.conf", ".puppet-lint.rc", ".git" },
})

vim.lsp.config("bashls", {
  cmd = { "bash-language-server", "start" },
  filetypes = { "sh", "bash", "zsh" },
  root_markers = { ".git" },
})

vim.lsp.enable({ "ruby_lsp", "gopls", "rust_analyzer", "ts_ls", "puppet", "bashls" })

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("user_lsp", { clear = true }),
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
    vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, { buffer = ev.buf, desc = "LSP format" })
    vim.keymap.set("n", "<leader>li", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
    end, { buffer = ev.buf, desc = "Toggle inlay hints" })
    vim.keymap.set("n", "gd", goto_definition_or_search, { buffer = ev.buf, desc = "Go to definition" })
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = ev.buf, desc = "Go to declaration" })
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { buffer = ev.buf, desc = "Go to implementation" })
    vim.keymap.set("n", "gO", function()
      pick_document_symbols()
    end, { buffer = ev.buf, desc = "Document symbols" })
    vim.keymap.set("n", "<leader>ls", function()
      require("mini.extra").pickers.lsp({ scope = "workspace_symbol_live" })
    end, { buffer = ev.buf, desc = "Workspace symbols" })
    wk.add({
      { "<leader>l", group = "lsp", buffer = ev.buf },
      { "<leader>lf", desc = "LSP format", buffer = ev.buf },
      { "<leader>li", desc = "Toggle inlay hints", buffer = ev.buf },
      { "<leader>ls", desc = "Workspace symbols", buffer = ev.buf },
    })
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("user_lsp_initial_buffers", { clear = true }),
  callback = function()
    -- Files passed on the command line can get their FileType before
    -- vim.lsp.enable() registers its auto-attach handler. Re-emit FileType once
    -- for existing real file buffers so native LSP attaches reliably.
    vim.schedule(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf)
          and vim.bo[buf].buftype == ""
          and vim.bo[buf].filetype ~= ""
          and vim.api.nvim_buf_get_name(buf) ~= ""
          and #vim.lsp.get_clients({ bufnr = buf }) == 0
        then
          vim.api.nvim_exec_autocmds("FileType", { buffer = buf, modeline = false })
        end
      end
    end)
  end,
})

-- Diagnostics
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

vim.keymap.set("n", "<leader>xx", vim.diagnostic.setqflist, { desc = "Diagnostics quickfix" })
vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Line diagnostic" })
wk.add({ { "<leader>x", group = "diagnostics" } })

-- Directory startup: keep tab-local cwd without opening a file or explorer.
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
    vim.cmd.tcd(vim.fn.fnameescape(dir))
  end,
})

-- Native command reminders:
--   LSP: K hover, gd definition, grr references, grn rename, gra action, gO symbols, :lsp, :checkhealth vim.lsp
--   Files: :find **/name, :edit path, :Explore/:Lexplore, :grep text, :copen, :cnext/:cprev
--   PRs: <leader>gf files, <leader>gd file diff, <leader>gp hunk preview, ]c/[c hunks
