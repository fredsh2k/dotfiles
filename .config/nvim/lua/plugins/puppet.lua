return {
  {
    "LazyVim/LazyVim",
    init = function()
      vim.filetype.add({
        extension = {
          pp = "puppet",
        },
      })
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "puppet-editor-services" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        puppet = {
          cmd = {
            "/Users/fsherman/.rbenv/versions/3.4.6/bin/ruby",
            "/Users/fsherman/.local/share/nvim/mason/packages/puppet-editor-services/libexec/puppet-languageserver",
            "--stdio",
            "--debug=/Users/fsherman/.local/state/nvim/puppet-languageserver.log",
            "--puppet-settings=--confdir,/Users/fsherman/Code/GitHub/puppet,--environment,production,--modulepath,/Users/fsherman/Code/GitHub/puppet/modules:/Users/fsherman/Code/GitHub/puppet/module_src",
          },
          root_markers = { "Puppetfile", "environment.conf", ".puppet-lint.rc", ".git" },
          settings = {
            puppet = {
              editorService = {
                puppet = {
                  modulePath = table.concat({
                    "/Users/fsherman/Code/GitHub/puppet/modules",
                    "/Users/fsherman/Code/GitHub/puppet/module_src",
                  }, ":"),
                },
              },
            },
          },
        },
      },
    },
  },
}
