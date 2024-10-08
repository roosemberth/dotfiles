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

local metals_config = require("metals").bare_config()
metals_config = {
  settings = {
    showImplicitArguments = true,
    excludedPackages = {
      "akka.actor.typed.javadsl",
      "com.github.swagger.akka.javadsl"
    },
    useGlobalExecutable = true,
  },
  on_attach = function(client, bufnr)
    on_generic_lsp_attach(client, bufnr)
    -- Required on metals
    vim.opt_global.shortmess:remove("F"):append("c")
    -- Scala-specific bindings
    vim.keymap.set('n', 'gds', vim.lsp.buf.document_symbol)
    vim.keymap.set('n', 'gws', vim.lsp.buf.workspace_symbol)
    vim.keymap.set('n', '<leader>ws', require'metals'.hover_worksheet)
  end,
}

local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  -- NOTE: You may or may not want java included here. You will need it if you
  -- want basic Java support but it may also conflict if you are using
  -- something like nvim-jdtls which also works on a java filetype autocmd.
  pattern = { "scala", "sbt", "sc" },
  callback = function()
    require("metals").initialize_or_attach(metals_config)
  end,
  group = nvim_metals_group,
})

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

require('spring_boot').setup({
  java_cmd = vim.g.java_path,
  ls_path = vim.g.spring_boot_tools_path .. '/language-server',
})

local nvim_jdtls_group = vim.api.nvim_create_augroup("nvim-jdtls", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "java" },
  callback = function()
    -- vim returns a copy of objects in the global namespace, thus their
    -- properties cannot be directly updated.
    local spring_boot_opts = vim.g.spring_boot
    spring_boot_opts.jdt_extensions_path = vim.g.spring_boot_tools_path .. "/jars"
    vim.g.spring_boot = spring_boot_opts

    require('jdtls').start_or_attach({
      cmd = {
        vim.g.jdtls_path,
        '--jvm-arg=-javaagent:' .. vim.g.lombok_path,
      },
      init_options = {
        bundles = require('spring_boot').java_extensions(),
        jdtls_plugins = {'spring-boot-tools'},
      },
      root_dir = vim.fs.root(0, {".git", "mvnw", "gradlew"}),
      on_attach = function(client, bufnr)
        on_generic_lsp_attach(client, bufnr)
        -- jdtls-specific bindings
        vim.keymap.set('n', '<leader>of', require'jdtls'.organize_imports)
      end,
    })
    require('spring_boot').init_lsp_commands()
  end,
  group = nvim_jdtls_group,
})
