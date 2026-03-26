return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        git_diff = {
          win = {
            input = {
              keys = {
                ["l"] = { "confirm", mode = { "n", "i" } },
              },
            },
            list = {
              keys = {
                ["l"] = { "confirm", mode = { "n" } },
              },
            },
          },
          layout = {
            fullscreen = true,
            layout = {
              box = "horizontal",
              {
                box = "vertical",
                border = true,
                title = "{title} {live} {flags}",
                width = 0.3,
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              { win = "preview", title = "{preview}", border = true, width = 0.7 },
            },
          },
        },
      },
    },
  },
  keys = {
    {
      "<leader>gP",
      function()
        -- Try to get the PR base branch via gh cli, fall back to main/master
        local base = vim.fn.system("gh pr view --json baseRefName --jq .baseRefName 2>/dev/null"):gsub("\n", "")
        if base == "" then
          -- Not on a PR branch, fall back to main or master
          local main = vim.fn.system("git rev-parse --verify origin/main 2>/dev/null"):gsub("\n", "")
          base = main ~= "" and "main" or "master"
        end
        Snacks.picker.git_diff({ base = "origin/" .. base })
      end,
      desc = "Git Diff PR (vs base branch)",
    },
  },
}
