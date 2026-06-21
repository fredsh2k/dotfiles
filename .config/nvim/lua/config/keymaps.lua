-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

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
  local ref
  if start_line == end_line then
    ref = path .. "#L" .. start_line
  else
    ref = path .. "#L" .. start_line .. "-L" .. end_line
  end
  vim.fn.setreg("+", ref)
  vim.notify("Copied: " .. ref)
end, { desc = "Yank path with lines" })

vim.keymap.set("n", "<leader>yP", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path)
end, { desc = "Yank absolute path" })

vim.keymap.set("n", "<leader>fa", function()
  Snacks.picker.files({ hidden = true, ignored = true })
end, { desc = "Find files (all, incl. hidden/ignored)" })

local code_repos_cache = vim.fn.stdpath("cache") .. "/code-repos.txt"

local function repo_items(lines)
  local seen = {}
  local items = {}
  for _, git_dir in ipairs(lines) do
    local repo = git_dir:gsub("/%.git/?$", "")
    if repo ~= "" and not seen[repo] then
      seen[repo] = true
      local name = vim.fn.fnamemodify(repo, ":~:.")
      items[#items + 1] = {
        repo = repo,
        text = name,
        label = name,
      }
    end
  end

  table.sort(items, function(a, b)
    return a.label < b.label
  end)

  return items
end

local function refresh_code_repos(on_done)
  local code_dir = vim.fn.expand("~/Code")
  vim.system({ "fd", "--hidden", "--type", "directory", "^\\.git$", code_dir }, { text = true }, function(result)
    local lines = vim.split(vim.trim(result.stdout or ""), "\n", { trimempty = true })
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("Could not scan repos under " .. code_dir, vim.log.levels.ERROR)
        return
      end
      vim.fn.writefile(lines, code_repos_cache)
      if on_done then
        on_done(repo_items(lines))
      end
    end)
  end)
end

local function pick_code_repo(title, on_confirm)
  local function pick(items)
    if #items == 0 then
      vim.notify("Scanning repos under ~/Code...")
      refresh_code_repos(pick)
      return
    end

    Snacks.picker({
      title = title,
      items = items,
      preview = "none",
      layout = {
        hidden = { "preview" },
        layout = {
          width = 0.35,
          min_width = 30,
          max_width = 70,
          height = 0.35,
          min_height = 8,
        },
      },
      format = function(item)
        return { { item.label } }
      end,
      confirm = function(picker, item)
        local repo = item and item.repo
        picker:close()
        if repo then
          vim.schedule(function()
            on_confirm(repo)
          end)
        end
      end,
    })
  end

  local cached = vim.fn.filereadable(code_repos_cache) == 1 and vim.fn.readfile(code_repos_cache) or {}
  pick(repo_items(cached))
  refresh_code_repos()
end

refresh_code_repos()

pcall(vim.keymap.del, "n", "<leader><tab>f")
pcall(vim.keymap.del, "n", "<leader><tab>l")
pcall(vim.keymap.del, "n", "<leader><tab><tab>")
pcall(vim.keymap.del, "n", "<leader><tab>n")
pcall(vim.keymap.del, "n", "<leader><tab>[")
pcall(vim.keymap.del, "n", "<leader><tab>]")
pcall(vim.keymap.del, "n", "<leader><tab>o")
pcall(vim.keymap.del, "n", "<leader><tab>r")
pcall(vim.keymap.del, "n", "<leader><tab>c")

vim.keymap.set("n", "<leader><tab>n", function()
  pick_code_repo("New Tab", function(repo)
    local readme = vim.fs.find(function(name)
      return name:lower():match("^readme") ~= nil
    end, { path = repo, type = "file", limit = 1 })[1]

    vim.cmd.tabnew()
    vim.cmd.tcd(vim.fn.fnameescape(repo))
    vim.api.nvim_tabpage_set_var(0, "name", vim.fn.fnamemodify(repo, ":t"))
    if readme then
      vim.cmd.edit(vim.fn.fnameescape(readme))
    end
    Snacks.explorer({ cwd = repo })
  end)
end, { desc = "New Repo Tab" })

local function find_tab()
  local tabs = vim.api.nvim_list_tabpages()
  table.sort(tabs, function(a, b)
    return vim.api.nvim_tabpage_get_number(a) < vim.api.nvim_tabpage_get_number(b)
  end)

  local items = vim.tbl_map(function(tabpage)
    local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
    local ok, custom_name = pcall(vim.api.nvim_tabpage_get_var, tabpage, "name")
    local cwd = vim.fn.getcwd(-1, tabnr)
    local name = ok and custom_name or vim.fn.fnamemodify(cwd, ":t")
    local win = vim.api.nvim_tabpage_get_win(tabpage)
    local buf = vim.api.nvim_win_get_buf(win)
    local file = vim.api.nvim_buf_get_name(buf)
    file = file ~= "" and vim.fn.fnamemodify(file, ":~:.") or "[No Name]"

    return {
      tabnr = tabnr,
      current = tabpage == vim.api.nvim_get_current_tabpage(),
      text = string.format("%d %s %s %s", tabnr, name, cwd, file),
      label = string.format("%s%d  %s  %s", tabpage == vim.api.nvim_get_current_tabpage() and "*" or " ", tabnr, name, file),
    }
  end, tabs)

  Snacks.picker({
    title = "Tabs",
    items = items,
    preview = "none",
    formatters = {
      selected = {
        unselected = false,
      },
    },
    win = {
      input = {
        keys = {
          ["<Tab>"] = { "list_down", mode = { "i", "n" } },
          ["<S-Tab>"] = { "list_up", mode = { "i", "n" } },
          ["<c-a>"] = { "", mode = { "i", "n" } },
        },
      },
      list = {
        keys = {
          ["<Tab>"] = "list_down",
          ["<S-Tab>"] = "list_up",
          ["<c-a>"] = "",
        },
      },
    },
    layout = {
      hidden = { "preview" },
      layout = {
        width = 0.25,
        min_width = 20,
        max_width = 40,
        height = 0.2,
        min_height = 3,
      },
    },
    format = function(item)
      return { { item.label } }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.cmd.tabnext(item.tabnr)
      end
    end,
  })
end

vim.keymap.set("n", "<leader><tab><tab>", "<cmd>tabnext<cr>", { desc = "Next Tab" })
vim.keymap.set("n", "<leader><tab>f", find_tab, { desc = "Find Tab" })
