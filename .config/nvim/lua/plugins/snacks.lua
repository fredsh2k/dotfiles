return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
        },
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
}
