vim.o.inccommand = 'nosplit'
vim.o.completeopt = 'menuone,noselect'

local lspconfig = require'lspconfig'

local opts = { noremap=true, silent=true }
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)
vim.keymap.set('n', '<leader>ada', vim.diagnostic.setqflist, opts)
vim.keymap.set('n', '<leader>ade', function()
  vim.diagnostic.setqflist({severity = "E"})
end, opts)
vim.keymap.set('n', '<leader>adw', function()
  vim.diagnostic.setqflist({severity = "W"})
end, opts)

local on_generic_lsp_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap=true, silent=true, buffer=bufnr }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
  vim.keymap.set('n', 'I', vim.lsp.buf.hover, bufopts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
  vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, bufopts)
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
  vim.keymap.set('n', '<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts)
  vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
  vim.keymap.set('n', '<leader>aa', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', '<leader>ar', vim.lsp.codelens.run, bufopts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
  vim.keymap.set('n', '<leader>f', function()
    vim.lsp.buf.format { async = true }
  end, bufopts)
end

-- lspconfig.rust_analyzer is configured by rust-tools.
local rt = require("rust-tools")
rt.setup({
  tools = {
    reload_workspace_from_cargo_toml = false,
  },
  server = {
    on_attach = function(client, bufnr)
      on_generic_lsp_attach(client, bufnr)
      local bufopts = { noremap=true, silent=true, buffer=bufnr }
      vim.keymap.set("n", "I", rt.hover_actions.hover_actions, bufopts)
      vim.keymap.set("n", "<Leader>aa", rt.code_action_group.code_action_group, bufopts)
      vim.cmd('packadd termdebug')
      vim.b.termdebugger = 'rust-gdb'
    end,
  },
})

lspconfig.hls.setup {
  on_attach = on_generic_lsp_attach,
  settings = {
    haskell = {
      formattingProvider = "fourmolu",
    }
  }
}

lspconfig.pylsp.setup {
  on_attach = on_generic_lsp_attach,
}

lspconfig.clangd.setup {
  on_attach = on_generic_lsp_attach,
}

vim.g.markdown_fenced_languages = {
  "ts=typescript"
}

lspconfig.tsserver.setup {
  on_attach = on_generic_lsp_attach,
}

-- LSP Status and progress
require("fidget").setup {
  text = {
    spinner = "dots"
  }
}
