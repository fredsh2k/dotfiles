return {
  -- Image rendering via Kitty graphics protocol (supported by Ghostty)
  {
    "3rd/image.nvim",
    lazy = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      max_width = 100,
      max_height = 40,
      max_height_window_percentage = 60,
      max_width_window_percentage = 80,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    },
  },

  -- Molten: Jupyter in Neovim
  -- Remote plugin — must be on runtimepath at startup for rplugin.vim to work
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    lazy = false,
    build = ":UpdateRemotePlugins",
    dependencies = { "3rd/image.nvim" },
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_virt_lines = true
      vim.g.molten_virt_text_output = true
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      vim.g.molten_virt_text_max_lines = 100
      vim.g.molten_virt_lines_off_by_1 = true
      vim.g.molten_enter_output_behavior = "open_and_enter"
      vim.g.molten_copy_output = true
    end,
    config = function()
      -- Auto-detect project kernel from .venv, register if needed, then init
      vim.keymap.set("n", "<leader>ji", function()
        -- Skip if kernel already running for this buffer
        local status = vim.fn.MoltenStatusLineKernels()
        if status and status ~= "" then
          vim.notify("Kernel already running: " .. status, vim.log.levels.INFO)
          return
        end
        local dir = vim.fn.expand("%:p:h")
        local venv = nil
        while dir ~= "/" do
          local candidate = dir .. "/.venv/bin/python"
          if vim.fn.executable(candidate) == 1 then
            venv = candidate
            break
          end
          dir = vim.fn.fnamemodify(dir, ":h")
        end
        if venv then
          local name = vim.fn.fnamemodify(vim.fn.fnamemodify(venv, ":h:h:h"), ":t")
          vim.fn.system({
            venv, "-m", "ipykernel", "install", "--user", "--name", name,
            "--display-name", "Python (" .. name .. ")",
          })
          vim.cmd("MoltenInit " .. name)
        else
          vim.cmd("MoltenInit")
        end
      end, { desc = "Molten Init" })

      vim.keymap.set("n", "<leader>jc", function()
        local cur = vim.api.nvim_win_get_cursor(0)[1]
        local total = vim.api.nvim_buf_line_count(0)
        local start = cur
        for i = cur, 1, -1 do
          local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
          if line:match("^# %%%%") then
            start = i + 1
            break
          end
          if i == 1 then start = 1 end
        end
        local stop = total
        for i = cur + 1, total do
          local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
          if line:match("^# %%%%") then
            stop = i - 1
            break
          end
        end
        while stop > start and vim.api.nvim_buf_get_lines(0, stop - 1, stop, false)[1]:match("^%s*$") do
          stop = stop - 1
        end
        if start > stop then return end
        vim.fn.MoltenEvaluateRange(start, stop)
      end, { desc = "Molten Run Cell" })

      -- Run all cells
      vim.keymap.set("n", "<leader>ja", function()
        local total = vim.api.nvim_buf_line_count(0)
        local lines = vim.api.nvim_buf_get_lines(0, 0, total, false)
        local cells = {}
        local cell_start = nil
        for i, line in ipairs(lines) do
          if line:match("^# %%%%") and not line:match("^# %%%% %[markdown%]") then
            if cell_start then
              local cell_end = i - 1
              while cell_end > cell_start and lines[cell_end]:match("^%s*$") do
                cell_end = cell_end - 1
              end
              if cell_start <= cell_end then
                table.insert(cells, { cell_start, cell_end })
              end
            end
            cell_start = i + 1
          end
        end
        if cell_start then
          local cell_end = total
          while cell_end > cell_start and lines[cell_end]:match("^%s*$") do
            cell_end = cell_end - 1
          end
          if cell_start <= cell_end then
            table.insert(cells, { cell_start, cell_end })
          end
        end
        for _, cell in ipairs(cells) do
          vim.fn.MoltenEvaluateRange(cell[1], cell[2])
        end
        vim.notify("Ran " .. #cells .. " cells", vim.log.levels.INFO)
      end, { desc = "Molten Run All Cells" })

      vim.keymap.set("n", "<leader>jl", "<cmd>MoltenEvaluateLine<cr>", { desc = "Molten Eval Line" })
      vim.keymap.set("n", "<leader>je", "<cmd>MoltenEvaluateOperator<cr>", { desc = "Molten Eval Operator" })
      vim.keymap.set("n", "<leader>jr", "<cmd>MoltenReevaluateCell<cr>", { desc = "Molten Re-eval Cell" })
      vim.keymap.set("n", "<leader>jd", "<cmd>MoltenDelete<cr>", { desc = "Molten Delete Cell" })
      vim.keymap.set("n", "<leader>jh", "<cmd>MoltenHideOutput<cr>", { desc = "Molten Hide Output" })
      vim.keymap.set("n", "<leader>jw", ":noautocmd MoltenEnterOutput<cr>", { desc = "Molten Enter Output", silent = true })
      vim.keymap.set("n", "<leader>jb", "<cmd>MoltenOpenInBrowser<cr>", { desc = "Molten Open in Browser" })
      vim.keymap.set("v", "<leader>jv", ":<C-u>MoltenEvaluateVisual<cr>", { desc = "Molten Eval Visual" })

      -- Find the nearest image below the cursor in the current buffer
      local function find_nearest_image()
        local img_api = require("image")
        local images = img_api.get_images({ buffer = vim.api.nvim_get_current_buf() })
        if #images == 0 then return nil end
        local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
        local best, best_dist = nil, math.huge
        for _, img in ipairs(images) do
          local y = img.geometry and img.geometry.y or nil
          if y then
            local dist = math.abs(y - cursor_row)
            if dist < best_dist then
              best, best_dist = img, dist
            end
          end
        end
        return best
      end

      -- Copy nearest plot to macOS clipboard
      vim.keymap.set("n", "<leader>jy", function()
        local img = find_nearest_image()
        if not img or not img.path then
          vim.notify("No image found near cursor", vim.log.levels.WARN)
          return
        end
        vim.fn.system({ "osascript", "-e", 'set the clipboard to (read (POSIX file "' .. img.path .. '") as TIFF picture)' })
        vim.notify("Plot copied to clipboard", vim.log.levels.INFO)
      end, { desc = "Molten Copy Plot to Clipboard" })

      -- Save nearest plot to file's directory
      vim.keymap.set("n", "<leader>js", function()
        local img = find_nearest_image()
        if not img or not img.path then
          vim.notify("No image found near cursor", vim.log.levels.WARN)
          return
        end
        local dir = vim.fn.expand("%:p:h")
        local name = "plot_" .. os.date("%Y%m%d_%H%M%S") .. ".png"
        local dest = dir .. "/" .. name
        vim.fn.system({ "cp", img.path, dest })
        vim.notify("Saved: " .. name, vim.log.levels.INFO)
      end, { desc = "Molten Save Plot to File" })
    end,
  },
}
