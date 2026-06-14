# ---------------------------------------------------------------------------
# nvim.nix — Neovim for operator workflow (notes, logs, configs, light dev)
#
# Focus: recon output, engagement notes, Nix/Lua/Bash config edits, loot
# triage. LSP/completion/formatting added (native vim.lsp, no mason — all
# servers come from extraPackages, fully reproducible).
#
# Fixes applied vs prior revision:
#   - require("comment") -> require("Comment")   (module is case-sensitive;
#     comment-nvim == numToStr/Comment.nvim, lua/Comment/init.lua)
#   - removed require("undotree").setup()        (pkgs.vimPlugins.undotree ==
#     mbbill/vim-undotree, vimscript-only, no lua module — setup() throws
#     "module 'undotree' not found" on every startup)
#   - treesitter: auto_install = false            (Nix-managed parsers via
#     withAllGrammars; runtime auto-install would try to write into the
#     read-only /nix/store plugin dir and fail)
# ---------------------------------------------------------------------------
{
  pkgs,
  flakeRoot ? "/home/malachi/WHOcares!",
  hostName ? "coffin",
  nixosHostName ? "Aegis-Dualis",
  userName ? "malachi",
  ...
}: {
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

      # ── LSP servers (native vim.lsp, no mason) ───────────────────────────
      nixd # Nix — config/flake editing (primary workload)
      lua-language-server # Lua — nixvim/neovim config bodies
      bash-language-server # zsh/bash scripts (zsh.nix initContent, awesome-tools.nix)
      marksman # Markdown — engagement notes / reports
      yaml-language-server # k8s/compose/ansible-style yaml
      pyright # Python — netexec/recon scripting
      taplo # TOML LSP (Cargo.toml, pyproject.toml)

      # ── Formatters (conform.nvim) ────────────────────────────────────────
      alejandra # Nix formatter — matches WHYcare flake style
      stylua # Lua
      shfmt # Shell
      ruff # Python lint+format (replaces black+isort+flake8)
      taplo # also provides `taplo format`
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

      # ── LSP / completion / formatting ────────────────────────────────────
      nvim-lspconfig # ships default server configs for vim.lsp.config
      blink-cmp # completion engine
      lspkind-nvim # icons in completion menu
      conform-nvim # format-on-save dispatcher
      nvim-autopairs

      # ── UX additions ──────────────────────────────────────────────────────
      lualine-nvim
      bufferline-nvim
      flash-nvim # fast motion / search-jump
      trouble-nvim # diagnostics/quickfix list
      todo-comments-nvim
    ];

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = "\\"

      -- ── Core UX ───────────────────────────────────────────────────────────
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

      -- 4-space indent for Lua/Python; 2-space stays default elsewhere.
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
          gitsigns = true,
          treesitter = true,
          telescope = true,
          which_key = true,
          indent_blankline = { enabled = true },
          render_markdown = true,
          native_lsp = {
            enabled = true,
            virtual_text = {
              errors = { "italic" },
              hints = { "italic" },
              warnings = { "italic" },
              information = { "italic" },
            },
          },
          mini = { enabled = true },
        },
      })
      vim.cmd.colorscheme("catppuccin")

      require("ibl").setup({
        indent = { char = "│" },
        scope = { enabled = true },
      })

      require("gitsigns").setup()
      require("Comment").setup()

      -- ── Markdown / engagement notes ───────────────────────────────────────
      require("render-markdown").setup({
        heading = { width = "full", sign = true },
        code = { border = "thin", width = "block" },
        checkbox = { enabled = true },
      })

      -- ── File navigation (loot, recon dirs) ────────────────────────────────
      require("oil").setup({
        default_file_explorer = true,
        view_options = { show_hidden = true },
        keymaps = {
          ["g?"] = "actions.show_help",
          ["<CR>"] = "actions.select",
          ["<C-v>"] = "actions.select_vsplit",
          ["<C-s>"] = "actions.select_split",
          ["<C-t>"] = "actions.select_tab",
          ["<C-p>"] = "actions.preview",
          ["-"] = "actions.parent",
          ["_"] = "actions.open_cwd",
          ["`"] = "actions.cd",
          ["~"] = "actions.tcd",
          ["gs"] = "actions.change_sort",
          ["gx"] = "actions.open_external",
        },
      })

      -- ── Harpoon quick-jump files (targets, notes, configs) ────────────────
      local harpoon = require("harpoon")
      harpoon:setup()
      vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Harpoon add" })
      vim.keymap.set("n", "<leader>e", function() harpoon.ui:toggle_quick_menu() end, { desc = "Harpoon menu" })
      for i = 1, 4 do
        vim.keymap.set("n", "<leader>" .. i, function() harpoon:list():select(i) end, { desc = "Harpoon " .. i })
      end

      -- ── Search (recon output, logs, creds — ripgrep backend) ──────────────
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "%.git/", "node_modules/" },
          mappings = {
            i = { ["<C-u>"] = false },
          },
        },
        pickers = {
          find_files = { hidden = true },
          live_grep = { additional_args = { "--hidden" } },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
          },
        },
      })
      pcall(require("telescope").load_extension, "fzf")
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help" })
      vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
      vim.keymap.set("n", "<leader>fc", builtin.grep_string, { desc = "Grep word" })
      vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })

      -- ── Substitute (quick IOC / string swaps in logs) ─────────────────────
      require("substitute").setup({ highlight = true })
      vim.keymap.set("n", "gs", require("substitute").operator, { desc = "Substitute" })
      vim.keymap.set("n", "gss", require("substitute").line, { desc = "Substitute line" })
      vim.keymap.set("n", "gsw", require("substitute").word, { desc = "Substitute word" })

      -- mbbill/vim-undotree — vimscript plugin, no lua setup() call.
      vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Undo tree" })

      -- ── Embedded terminals (run tools without leaving nvim) ─────────────────
      require("toggleterm").setup({
        open_mapping = [[<C-\>]],
        direction = "float",
        float_opts = { border = "rounded" },
        size = function(term)
          if term.direction == "horizontal" then return 15 end
          if term.direction == "vertical" then return vim.o.columns * 0.4 end
        end,
      })
      local Terminal = require("toggleterm.terminal").Terminal
      local function term_cmd(cmd, opts)
        opts = opts or {}
        return function()
          Terminal:new(vim.tbl_extend("force", {
            cmd = cmd,
            dir = "git",
            hidden = true,
            on_open = function(t) t:toggle() end,
          }, opts)):toggle()
        end
      end
      vim.keymap.set("n", "<leader>tt", term_cmd("lazygit"), { desc = "Lazygit" })
      vim.keymap.set("n", "<leader>tb", term_cmd("btop"), { desc = "btop" })
      vim.keymap.set("n", "<leader>ty", term_cmd("yazi"), { desc = "Yazi" })

      -- ── Treesitter (log/json/yaml/bash for triage) ────────────────────────
      require("nvim-treesitter.configs").setup({
        ensure_installed = {}, -- withAllGrammars already provides every parser
        auto_install = false,  -- never touch the read-only /nix/store plugin dir
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })

      require("mini.ai").setup({})
      require("mini.surround").setup({})

      -- ── Autopairs ─────────────────────────────────────────────────────────
      require("nvim-autopairs").setup({})

      -- ── Statusline / bufferline ───────────────────────────────────────────
      require("lualine").setup({
        options = {
          theme = "catppuccin",
          globalstatus = true,
          component_separators = "│",
          section_separators = "",
        },
        sections = {
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "diagnostics", "encoding", "filetype" },
        },
      })

      require("bufferline").setup({
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
          separator_style = "thin",
          offsets = {
            { filetype = "oil", text = "File Explorer", highlight = "Directory", text_align = "left" },
          },
        },
      })
      vim.keymap.set("n", "<S-l>", ":BufferLineCycleNext<CR>", { desc = "Next buffer" })
      vim.keymap.set("n", "<S-h>", ":BufferLineCyclePrev<CR>", { desc = "Prev buffer" })
      vim.keymap.set("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete buffer" })

      -- ── Flash (fast labelled jumps — replaces f/t hunting in long lines) ──
      require("flash").setup({})
      vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash jump" })
      vim.keymap.set({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash treesitter" })

      -- ── Trouble (diagnostics / quickfix triage) ───────────────────────────
      require("trouble").setup({})
      vim.keymap.set("n", "<leader>xx", ":Trouble diagnostics toggle<CR>", { desc = "Diagnostics" })
      vim.keymap.set("n", "<leader>xq", ":Trouble qflist toggle<CR>", { desc = "Quickfix" })

      -- ── TODO / FIXME / NOTE highlighting (audit trails in recon notes) ────
      require("todo-comments").setup({})
      vim.keymap.set("n", "]t", function() require("todo-comments").jump_next() end, { desc = "Next TODO" })
      vim.keymap.set("n", "[t", function() require("todo-comments").jump_prev() end, { desc = "Prev TODO" })

      -- ════════════════════════════════════════════════════════════════════
      -- LSP — native vim.lsp.config/vim.lsp.enable (Neovim 0.11+).
      -- All servers come from extraPackages → on $PATH, no mason/auto-install.
      -- ════════════════════════════════════════════════════════════════════
      vim.diagnostic.config({
        virtual_text = { prefix = "●", spacing = 2 },
        severity_sort = true,
        float = { border = "rounded" },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "✘",
            [vim.diagnostic.severity.WARN]  = "▲",
            [vim.diagnostic.severity.HINT]  = "⚑",
            [vim.diagnostic.severity.INFO]  = "»",
          },
        },
      })

      -- nixd: format via alejandra, eval against the WHYcare flake for
      -- accurate option completion/hover when editing flake-local modules.
      vim.lsp.config("nixd", {
        cmd = { "nixd" },
        settings = {
          nixd = {
            formatting = { command = { "alejandra" } },
            options = {
              nixos.expr = '(builtins.getFlake "path:${flakeRoot}").nixosConfigurations."${nixosHostName}".options',
              home_manager.expr = '(builtins.getFlake "path:${flakeRoot}").homeConfigurations."${userName}@${hostName}".options',
            },
          },
        },
      })

      vim.lsp.config("lua_ls", {
        cmd = { "lua-language-server" },
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.config("bashls", { cmd = { "bash-language-server", "start" } })
      vim.lsp.config("marksman", { cmd = { "marksman", "server" } })
      vim.lsp.config("yamlls", { cmd = { "yaml-language-server", "--stdio" } })
      vim.lsp.config("pyright", { cmd = { "pyright-langserver", "--stdio" } })
      vim.lsp.config("taplo", { cmd = { "taplo", "lsp", "stdio" } })

      vim.lsp.enable({ "nixd", "lua_ls", "bashls", "marksman", "yamlls", "pyright", "taplo" })

      -- LSP keymaps — buffer-local, attached only where a server is active.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local opts = function(desc) return { buffer = bufnr, desc = desc } end
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts("Goto definition"))
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts("Goto declaration"))
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts("References"))
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts("Implementation"))
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts("Hover"))
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts("Rename"))
          vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))
          vim.keymap.set("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, opts("Format"))
          vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, opts("Prev diagnostic"))
          vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, opts("Next diagnostic"))
        end,
      })

      -- ── Completion (blink.cmp) ─────────────────────────────────────────────
      require("blink.cmp").setup({
        keymap = { preset = "default" },
        appearance = {
          nerd_font_variant = "mono",
        },
        completion = {
          documentation = { auto_show = true, auto_show_delay_ms = 200 },
          menu = {
            draw = {
              treesitter = { "lsp" },
            },
          },
        },
        sources = {
          default = { "lsp", "path", "buffer" },
        },
        signature = { enabled = true },
      })

      -- ── Formatting on save (conform.nvim) ──────────────────────────────────
      require("conform").setup({
        formatters_by_ft = {
          nix = { "alejandra" },
          lua = { "stylua" },
          sh = { "shfmt" },
          bash = { "shfmt" },
          zsh = { "shfmt" },
          python = { "ruff_format" },
          toml = { "taplo" },
        },
        format_on_save = {
          timeout_ms = 1500,
          lsp_format = "fallback",
        },
      })
      vim.keymap.set({ "n", "v" }, "<leader>f", function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end, { desc = "Format buffer" })

      require("which-key").setup({
        plugins = { spelling = { enabled = true } },
      })
      require("which-key").add({
        { "<leader>f", group = "Find/Format" },
        { "<leader>t", group = "Terminal" },
        { "<leader>g", group = "Git" },
        { "<leader>c", group = "Code/LSP" },
        { "<leader>x", group = "Diagnostics" },
        { "<leader>b", group = "Buffers" },
        { "<leader>1", group = "Harpoon" },
      })

      -- ── Operator defaults ─────────────────────────────────────────────────
      vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Write" })
      vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })
      vim.keymap.set("n", "<leader>x", ":x<CR>", { desc = "Save & quit" })
      vim.keymap.set("n", "<leader>o", ":Oil<CR>", { desc = "Oil file tree" })
      vim.keymap.set("n", "<leader>cd", ":lcd %:h<CR>", { desc = "Cd to file dir" })
      vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", { desc = "Clear search hl" })
    '';
  };
}
