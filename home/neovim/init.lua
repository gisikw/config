-------------------------------------------------------------------------------
-- BASE CONFIGURATION
-------------------------------------------------------------------------------
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.scrolloff = 10
vim.opt.updatetime = 250


vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

vim.opt.incsearch = true
vim.opt.termguicolors = true

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.mouse = ""
vim.opt.ttimeoutlen = 10

-------------------------------------------------------------------------------
-- KEYBINDINGS
-------------------------------------------------------------------------------

-- Make Ctrl+C a proper escape
vim.keymap.set('i', '<C-c>', '<Esc>')

-- Reload Neovim config
vim.keymap.set('n', '<leader>r', function()
  vim.cmd('source $MYVIMRC')
  vim.api.nvim_echo({{"Reloaded!", "None"}}, false, {})
  vim.defer_fn(function() vim.cmd('echon ""') end, 1000)
end)

-- Shh
vim.keymap.set('n','<space>', function()
  vim.cmd('noh')
  vim.cmd('echon ""')
end)

vim.keymap.set('n', '<leader>d', ':NvimTreeToggle<cr>')
vim.keymap.set('n', '<leader><leader>', '<cmd>b#<cr>')
vim.keymap.set('n', '<leader>-', ':bd<cr>')
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set("n", "<leader>v", function()
  local current = vim.diagnostic.config()
  local new = vim.tbl_deep_extend("force", current, {
    virtual_text = not current.virtual_text
  })
  vim.diagnostic.config(new)
end, { silent = true, noremap = true, desc = "Toggle virtual text diagnostics" })

-------------------------------------------------------------------------------
-- USE UNDO TEMPFILES
-------------------------------------------------------------------------------
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
local undo_dir = "/tmp/.nvim_undodir_" .. vim.fn.expand("$USER")
if not vim.loop.fs_stat(undo_dir) then
  vim.loop.fs_mkdir(undo_dir, tonumber("700", 8))
end
vim.opt.undodir = undo_dir
vim.opt.undofile = true

-------------------------------------------------------------------------------
-- OS-SPECIFIC CLIPBOARD SETTINGS
-------------------------------------------------------------------------------
if vim.fn.getenv("WAYLAND_DISPLAY") ~= vim.NIL then
  if vim.fn.executable("wl-copy") == 1 and vim.fn.executable("wl-paste") == 1 then
    vim.g.clipboard = {
      name = "wayland",
      copy = {
        ["*"] = "wl-copy --foreground --type text/plain"
      },
      paste = {
        ["*"] = "wl-paste --no-newline"
      },
      cache_enabled = 1,
    }
  else
    vim.notify("Wayland detected but wl-copy/paste not found", vim.log.levels.WARN)
  end
elseif vim.fn.getenv("DISPLAY") ~= vim.NIL then
    if vim.fn.executable("xclip") == 1 then
        vim.g.clipboard = {
            name = "xclip",
            copy = {
                ["*"] = "xclip -selection clipboard",
            },
            paste = {
                ["*"] = "xclip -selection clipboard -o",
            },
            cache_enabled = 1,
        }
    else
        vim.notify("X11 detected but xclip not found", vim.log.levels.WARN)
    end
end

-------------------------------------------------------------------------------
-- PLUGINS
-------------------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system(
    { "git", "clone", "--filter=blob:none", 
      "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    "hrsh7th/nvim-cmp",
    {
      "nvim-telescope/telescope.nvim",
      config = function()
        require('telescope').setup {
          defaults = {
            file_ignore_patterns = { "node_modules", "target" }
          }
        }
        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>t", builtin.find_files)
        vim.keymap.set("n", "<leader>a", builtin.live_grep)
      end
    },
    {
      "loctvl842/monokai-pro.nvim",
      config = function()
        require("monokai-pro").setup()
        vim.cmd.colorscheme("monokai-pro-machine")
      end
    },
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require('lualine').setup {
          options = {
            icons_enabled = true,
            theme = 'auto',
            component_separators = { left = '', right = ''},
            section_separators = { left = '', right = ''},
            disabled_filetypes = {
              statusline = {},
              winbar = {},
            },
            ignore_focus = {},
            always_divide_middle = true,
            always_show_tabline = true,
            globalstatus = false,
            refresh = {
              statusline = 100,
              tabline = 100,
              winbar = 100,
            }
          },
          sections = {
            lualine_a = {'mode'},
            lualine_b = {'branch', 'diff', 'diagnostics'},
            lualine_c = {'filename'},
            lualine_x = {'filetype'},
            lualine_y = {'progress'},
            lualine_z = {'location'}
          },
          inactive_sections = {
            lualine_a = {},
            lualine_b = {},
            lualine_c = {'filename'},
            lualine_x = {'filetype', 'location'},
            lualine_y = {},
            lualine_z = {}
          },
          tabline = {},
          winbar = {},
          inactive_winbar = {},
          extensions = {}
        }
      end
    },
    {
      "nvim-tree/nvim-tree.lua",
      dependencies = {
        "nvim-tree/nvim-web-devicons",
      },
      config = function()
        require("nvim-tree").setup {
          on_attach = function(bufnr)
            local api = require("nvim-tree.api")
            api.config.mappings.default_on_attach(bufnr)
            vim.keymap.set("n", "-", api.node.open.horizontal, { buffer = bufnr })
            vim.keymap.set("n", "|", api.node.open.vertical, { buffer = bufnr })
          end,
          actions = {
            open_file = {
              quit_on_open = true
            }
          },
          diagnostics = {
            enable = true,
            show_on_dirs = true,
            icons = {
              hint = "",
              info = "",
              warning = "",
              error = "",
            },
          },
        }
      end,
    },
    {
      'nvim-treesitter/nvim-treesitter',
      build = ':TSUpdate',
      main = 'nvim-treesitter.configs',
      opts = {
        ensure_installed = { 'lua' },
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = { 'ruby' },
        },
        indent = { enable = true, disable = { 'ruby' } },
      },
    },
    {
      'neovim/nvim-lspconfig',
      dependencies = {
        { 'williamboman/mason.nvim', config = true },
        'williamboman/mason-lspconfig.nvim',
        { 'j-hui/fidget.nvim', opts = {} },
        'hrsh7th/cmp-nvim-lsp',
      },
      config = function()
        require("mason").setup()
        require("mason-lspconfig").setup({
          ensure_installed = { "rust_analyzer", "ts_ls", "ruby_lsp", "nextls", "tailwindcss" },
        })

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = vim.tbl_deep_extend(
          'force', 
          capabilities, 
          require('cmp_nvim_lsp').default_capabilities()
        )
        
        local lspconfig = require("lspconfig")
        require("mason-lspconfig").setup_handlers({
          function(server_name)
            lspconfig[server_name].setup({
              capabilities = capabilities
            }) 
          end,
        })

        lspconfig.gleam.setup({})

        vim.opt.signcolumn = "yes"
        local signs = { ERROR = "", WARN = "", INFO = "", HINT = "" }
        for type, icon in pairs(signs) do
          local hl = "DiagnosticSign" .. type:sub(1, 1) .. type:sub(2):lower()
          vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
        end
        vim.diagnostic.config({ 
          virtual_text = {
            prefix = ""
          },
          float = {
            max_width = 80,
            wrap = true
          },
          signs = true,
        })
        vim.diagnostic.enable() 

        vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
          vim.lsp.handlers.hover, {
            border = "rounded",
          }
        )

        -- Hover tooltips that dismiss
        vim.keymap.set("n", "K", function()
          vim.lsp.buf.hover()

          local group = vim.api.nvim_create_augroup(
            "HoverClose", 
            { clear = true }
          )
          vim.api.nvim_create_autocmd("CursorMoved", {
            group = group,
            callback = function()
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                local config = vim.api.nvim_win_get_config(win)
                if config.relative ~= "" then
                  vim.api.nvim_win_close(win, true)
                end
              end

              vim.api.nvim_del_augroup_by_name("HoverClose")
            end,
          })
	end)

        -- Format before save
        vim.api.nvim_create_autocmd("BufWritePre", {
          callback = function()
            vim.lsp.buf.format({ async = false })
          end
        })
      end,
    },
    {
      "hrsh7th/nvim-cmp",
      dependencies = {
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-path',
      },
      config = function()
        local cmp = require("cmp")
        cmp.setup({
          mapping = cmp.mapping.preset.insert({
            ['<C-n>'] = cmp.mapping.select_next_item(), -- Navigate suggestions
            ['<C-p>'] = cmp.mapping.select_prev_item(),
            ['<CR>'] = cmp.mapping.confirm({ select = false }), -- Confirm selection
            ['<Tab>'] = cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              else
                fallback()
              end
            end, { 'i', 's' }),
          }),
          sources = cmp.config.sources({
            { name = 'nvim_lsp' },
            { name = 'buffer' },
            { name = 'path' },
          }),
        })
      end,
    },
    {
      "nvimdev/indentmini.nvim",
      config = function()
        require("indentmini").setup({ char = "┋" })
        vim.api.nvim_set_hl(0, "IndentLine", { ctermfg = 252, ctermbg = "NONE", fg = "#545f62", bg = "NONE" })
        vim.api.nvim_set_hl(0, "IndentLineCurrent", { ctermfg = 252, ctermbg = "NONE", fg = "#b8c4c3", bg = "NONE" })
      end,
    },
  },
  checker = { 
    enabled = true,
    notify = false,
  },
  install = {
    missing = true,
  },
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("lazy").update({ show = false })
  end,
})

-------------------------------------------------------------------------------
-- MACRO UTILITY
-------------------------------------------------------------------------------
_G.TermFloatingCmd = function(cmd)
  local buf_name = "macro term"
  local existing_buf = vim.fn.bufnr(buf_name)

  -- Delete existing buffer if it exists
  if existing_buf ~= -1 then
    vim.api.nvim_buf_delete(existing_buf, { force = true })
  end

  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, buf_name)

  -- Create a floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    col = math.floor(vim.o.columns * 0.1),
    row = math.floor(vim.o.lines * 0.1),
    style = "minimal",
    border = "rounded",
  })

  vim.fn.termopen(cmd)
  vim.bo[buf].buftype = "terminal"
  vim.cmd.colorscheme("base16-primer-dark")
  vim.cmd("startinsert")

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = buf,
    callback = function()
      vim.opt_local.number = true
      vim.opt_local.relativenumber = true
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true),
        "n", 
        false
      )
    end,
  })

  vim.api.nvim_buf_set_keymap(
    buf, "n", "q", "<Cmd>close<CR>", { noremap = true, silent = true }
  )
end

vim.api.nvim_command(
  'command! -nargs=* TermFloatingCmd lua _G.TermFloatingCmd(<q-args>)'
)

_G.run_leader_cmd = function(num)
  local cmd_var = "leader_" .. tostring(num)
  if vim.g[cmd_var] == nil then
    -- Prompt for a new command if one isn't set
    local success, user_input = pcall(vim.fn.input, "Temp cmd: ")

    if not success or user_input == "" then return end
    vim.g[cmd_var] = 
      "TermFloatingCmd " .. user_input:gsub('%%', vim.fn.expand('%'))
  end
  vim.cmd(vim.g[cmd_var])
end

-- Clear all temporary commands
_G.clear_leader_cmds = function()
  for i = 1, 10 do
    local cmd_var = "leader_" .. tostring(i)
    vim.g[cmd_var] = nil
  end
  print("Cleared all temp commands")
end

-- Keybindings for <leader>1-9 to run the temporary commands
for i = 1, 10 do
  local key = i % 10
  vim.api.nvim_set_keymap(
    'n',
    '<leader>' .. tostring(key), 
    string.format(':lua _G.run_leader_cmd(%d)<CR>', i), 
    { noremap = true, silent = true }
  )
end

vim.api.nvim_set_keymap('n', '<leader>`', ':lua _G.clear_leader_cmds()<CR>', 
                        { noremap = true, silent = true })
