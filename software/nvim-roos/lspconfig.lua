vim.o.inccommand = 'nosplit'
vim.o.completeopt = 'menuone,noselect'

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

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local bufnr = args.buf
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
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
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function(ev)
    local bufopts = { noremap=true, silent=true, buffer=ev.buf }
    vim.keymap.set('n', '<leader>aa', function()
      vim.cmd.RustLsp('codeAction')
    end, bufopts)
    vim.keymap.set('n', 'K', function()
      vim.cmd.RustLsp({ 'hover', 'actions' })
    end, bufopts)
    vim.keymap.set('n', '<leader>rt', function()
      vim.cmd.RustLsp('testables')
    end, bufopts)
  end,
})

vim.lsp.config('hls', {
  settings = {
    haskell = {
      formattingProvider = "fourmolu",
    }
  }
})

vim.lsp.config('pylsp', {
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          ignore = {'W391'},
          maxLineLength = 80
        }
      }
    }
  }
})

vim.lsp.enable('clangd')
vim.lsp.enable('hls')
vim.lsp.enable('pylsp')
vim.lsp.enable('ts_ls')

-- LSP Status and progress
require("fidget").setup {
  text = {
    spinner = "dots"
  }
}
