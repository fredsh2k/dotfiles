return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          args = { "--config", vim.fn.expand("~/.markdownlint-cli2.yaml"), "--" },
        },
      },
    },
  },
  -- Don't render markdown by default; toggle on demand with :RenderMarkdown toggle
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = { enabled = false },
  },
}
