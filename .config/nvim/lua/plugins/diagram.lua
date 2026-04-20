return {
  -- Render mermaid/plantuml/d2 diagrams inline via image.nvim
  {
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    ft = { "markdown", "norg" },
    opts = {
      renderer_options = {
        mermaid = {
          background = "transparent",
          theme = "dark",
          scale = 1,
        },
      },
    },
    keys = {
      {
        "<leader>cd",
        function()
          require("diagram").render()
        end,
        ft = { "markdown", "norg" },
        desc = "Render Diagrams",
      },
      {
        "<leader>cD",
        function()
          require("diagram").clear()
        end,
        ft = { "markdown", "norg" },
        desc = "Clear Diagrams",
      },
    },
  },
}
