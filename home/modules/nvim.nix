# ---------------------------------------------------------------------------
# nvim.nix — Neovim operator workflow orchestration
#
# Configured for complete autonomous functionality without external dependencies.
# Python LSP and toolchains strictly interface via standard pathing or 'uv'.
# ---------------------------------------------------------------------------
{
  config,
  pkgs,
  flakeRoot ? null,
  hostName ? "coffin",
  nixosHostName ? "Aegis-Dualis",
  userName ? "malachi",
  ...
}: let
  configuredFlakeRoot =
    if flakeRoot == null
    then "${config.home.homeDirectory}/WHOcares"
    else flakeRoot;
in {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = true;
    withNodeJs = false;
    withRuby = false;

    extraPackages = with pkgs; [
      ripgrep
      fd
      bat
      tree-sitter
      uv

      # LSP servers
      nixd
      lua-language-server
      bash-language-server
      marksman
      yaml-language-server
      pyright
      taplo

      # Formatters and Linters
      alejandra
      stylua
      shfmt
      ruff
      statix
      deadnix
      shellcheck
    ];

    plugins = with pkgs.vimPlugins; [
      catppuccin-nvim
      plenary-nvim
      telescope-nvim
      telescope-fzf-native-nvim
      fzf-lua
      which-key-nvim
      gitsigns-nvim
      comment-nvim
      vim-fugitive
      nvim-treesitter.withAllGrammars
      indent-blankline-nvim
      toggleterm-nvim
      nvim-web-devicons
      oil-nvim
      harpoon
      undotree
      substitute-nvim
      render-markdown-nvim
      mini-nvim
      nvim-lspconfig
      blink-cmp
      lspkind-nvim
      conform-nvim
      nvim-autopairs
      lualine-nvim
      bufferline-nvim
      flash-nvim
      trouble-nvim
      todo-comments-nvim
      diffview-nvim
      fidget-nvim
      direnv-vim
      nvim-lint
    ];

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = "\\"
      local framework_root = "${configuredFlakeRoot}"

      -- Core settings
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.signcolumn = "yes"
      vim.opt.wrap = false
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.smartindent = true
      vim.opt.termguicolors = true
      vim.opt.clipboard = "unnamedplus"
      vim.opt.updatetime = 250
      vim.opt.timeoutlen = 400
      vim.opt.scrolloff = 8
      vim.opt.sidescrolloff = 8
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.undofile = true
      vim.opt.undodir = vim.fn.expand("~/.local/state/nvim/undo")
      vim.opt.splitbelow = true
      vim.opt.splitright = true
      vim.opt.cursorline = true
      vim.opt.list = true
      vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
      vim.opt.hlsearch = true
      vim.opt.incsearch = true
      vim.opt.inccommand = "split"

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "lua", "python" },
        callback = function()
          vim.opt_local.tabstop = 4
          vim.opt_local.shiftwidth = 4
        end,
      })

      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = false,
        integrations = {
          gitsigns = true, treesitter = true, telescope = true,
          which_key = true, indent_blankline = { enabled = true },
          render_markdown = true, mini = { enabled = true },
          native_lsp = {
            enabled = true,
            virtual_text = { errors = { "italic" }, hints = { "italic" }, warnings = { "italic" }, information = { "italic" } },
          },
        },
      })
      vim.cmd.colorscheme("catppuccin")

      require("ibl").setup({ indent = { char = "│" }, scope = { enabled = true } })
      require("gitsigns").setup()
      require("Comment").setup()
      require("fidget").setup({})
      require("diffview").setup({
        enhanced_diff_hl = true,
        view = { default = { layout = "diff2_horizontal" }, merge_tool = { layout = "diff3_mixed" } },
      })

      require("render-markdown").setup({ heading = { width = "full", sign = true }, code = { border = "thin", width = "block" }, checkbox = { enabled = true } })

      require("oil").setup({
        default_file_explorer = true,
        view_options = { show_hidden = true },
      })

      local harpoon = require("harpoon")
      harpoon:setup()
      vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Harpoon add" })
      vim.keymap.set("n", "<leader>e", function() harpoon.ui:toggle_quick_menu() end, { desc = "Harpoon menu" })

      require("telescope").setup({
        defaults = { file_ignore_patterns = { "%.git/", "node_modules/" } },
        pickers = { find_files = { hidden = true }, live_grep = { additional_args = { "--hidden" } } },
      })
      pcall(require("telescope").load_extension, "fzf")
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })

      require("substitute").setup({ highlight = true })
      vim.keymap.set("n", "gs", require("substitute").operator, { desc = "Substitute" })

      vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Undo tree" })

      require("toggleterm").setup({
        open_mapping = [[<C-\>]],
        direction = "float",
        float_opts = { border = "rounded" },
      })

      require("nvim-treesitter.configs").setup({
        ensure_installed = {},
        auto_install = false,
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })

      require("mini.ai").setup({})
      require("mini.surround").setup({})
      require("nvim-autopairs").setup({})

      require("lualine").setup({
        options = { theme = "catppuccin", globalstatus = true, component_separators = "│", section_separators = "" },
      })

      require("bufferline").setup({
        options = { mode = "buffers", diagnostics = "nvim_lsp", separator_style = "thin" },
      })

      require("flash").setup({})
      vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash jump" })

      require("trouble").setup({})
      require("todo-comments").setup({})

      vim.diagnostic.config({ virtual_text = { prefix = "●", spacing = 2 }, severity_sort = true, float = { border = "rounded" } })

      vim.lsp.config("nixd", { cmd = { "nixd" }, settings = { nixd = { formatting = { command = { "alejandra" } }, options = { nixos = { expr = '(builtins.getFlake "path:${flakeRoot}").nixosConfigurations."${nixosHostName}".options' }, home_manager = { expr = '(builtins.getFlake "path:${flakeRoot}").homeConfigurations."${userName}@${hostName}".options' } } } } })
      vim.lsp.config("lua_ls", { cmd = { "lua-language-server" }, settings = { Lua = { runtime = { version = "LuaJIT" }, diagnostics = { globals = { "vim" } }, workspace = { checkThirdParty = false }, telemetry = { enable = false } } } })
      vim.lsp.config("bashls", { cmd = { "bash-language-server", "start" } })
      vim.lsp.config("marksman", { cmd = { "marksman", "server" } })
      vim.lsp.config("yamlls", { cmd = { "yaml-language-server", "--stdio" } })
      vim.lsp.config("pyright", { cmd = { "pyright-langserver", "--stdio" } })
      vim.lsp.config("taplo", { cmd = { "taplo", "lsp", "stdio" } })
      vim.lsp.enable({ "nixd", "lua_ls", "bashls", "marksman", "yamlls", "pyright", "taplo" })

      require("blink.cmp").setup({ keymap = { preset = "default" }, signature = { enabled = true } })

      require("conform").setup({
        formatters_by_ft = { nix = { "alejandra" }, lua = { "stylua" }, sh = { "shfmt" }, bash = { "shfmt" }, zsh = { "shfmt" }, python = { "ruff_format" }, toml = { "taplo" } },
        format_on_save = { timeout_ms = 1500, lsp_format = "fallback" },
      })

      local lint = require("lint")
      lint.linters_by_ft = { nix = { "statix", "deadnix" }, sh = { "shellcheck" }, bash = { "shellcheck" } }
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, { callback = function() lint.try_lint() end })

      require("which-key").setup({ plugins = { spelling = { enabled = true } } })

      vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Write" })
      vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })
      vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", { desc = "Clear search hl" })
    '';
  };
}
