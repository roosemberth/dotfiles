vim.o.inccommand = 'nosplit'
vim.o.completeopt = 'menuone,noselect'

local lspconfig = require'lspconfig'

local on_attach = function(client, bufnr)
  local function bmap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function bset(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  -- Enable completion triggered by <c-x><c-o>
  bset('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  bmap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  bmap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  bmap('n', 'I', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  bmap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  bmap('n', 'K', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  bmap('n', '<leader>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  bmap('n', '<leader>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  bmap('n', '<leader>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  bmap('n', '<leader>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  bmap('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  bmap('n', '<leader>a', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  bmap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  bmap('n', '<leader>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  bmap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  bmap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  bmap('n', '<leader>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  bmap('n', '<leader>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)

  bset('omnifunc', 'v:lua.vim.lsp.omnifunc')
end

lspconfig.rls.setup {
  on_attach = on_attach,
  settings = {
    rust = {
      unstable_features = true,
      build_on_save = false,
      all_features = true,
    },
  },
}
