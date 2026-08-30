{ pkgs, ... }:

{
	programs.neovim = {
		enable = true;
		defaultEditor = true;
		viAlias = true;
		vimAlias = true;
		vimdiffAlias = true;

		extraPackages = with pkgs; [
			fd
			gcc
			nil
			ripgrep
			wl-clipboard
		];

		plugins = with pkgs.vimPlugins; [
			# Syntax highlighting and language awareness.
			nvim-treesitter.withAllGrammars

			# Nix language server and completion.
			nvim-lspconfig
			nvim-cmp
			cmp-nvim-lsp
			cmp-buffer
			cmp-path

			# Fast file, text, and symbol search.
			plenary-nvim
			nvim-web-devicons
			telescope-nvim
			telescope-fzf-native-nvim

			# Editing and interface improvements.
			gitsigns-nvim
			lualine-nvim
			which-key-nvim
			nvim-autopairs
			comment-nvim
			indent-blankline-nvim
			tokyonight-nvim
		];

		extraLuaConfig = ''
			vim.g.mapleader = " "
			vim.g.maplocalleader = " "

			-- Line numbers: absolute on the current line, relative elsewhere.
			vim.opt.number = true
			vim.opt.relativenumber = true

			vim.opt.termguicolors = true
			vim.opt.cursorline = true
			vim.opt.signcolumn = "yes"
			vim.opt.scrolloff = 8
			vim.opt.sidescrolloff = 8
			vim.opt.wrap = false
			vim.opt.mouse = "a"
			vim.opt.clipboard = "unnamedplus"
			vim.opt.completeopt = { "menu", "menuone", "noselect" }
			vim.opt.ignorecase = true
			vim.opt.smartcase = true
			vim.opt.splitbelow = true
			vim.opt.splitright = true
			vim.opt.undofile = true
			vim.opt.updatetime = 250
			vim.opt.timeoutlen = 400

			-- Use tabs for indentation and display each tab as four columns.
			vim.opt.expandtab = false
			vim.opt.tabstop = 4
			vim.opt.shiftwidth = 4
			vim.opt.softtabstop = 4
			vim.opt.smartindent = true

			vim.cmd.colorscheme("tokyonight-night")

			require("lualine").setup({
				options = {
					theme = "auto",
					globalstatus = true,
				},
			})

			require("gitsigns").setup()
			require("which-key").setup()
			require("nvim-autopairs").setup()
			require("Comment").setup()
			require("ibl").setup({
				scope = { enabled = true },
			})

			local telescope = require("telescope")
			telescope.setup({
				defaults = {
					file_ignore_patterns = { ".git/", "result" },
				},
			})
			pcall(telescope.load_extension, "fzf")

			-- Use Neovim's built-in Tree-sitter support for installed parsers.
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(args)
					pcall(vim.treesitter.start, args.buf)
				end,
			})

			local cmp = require("cmp")
			cmp.setup({
				mapping = cmp.mapping.preset.insert({
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<Tab>"] = cmp.mapping.select_next_item(),
					["<S-Tab>"] = cmp.mapping.select_prev_item(),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "path" },
				}, {
					{ name = "buffer" },
				}),
			})

			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			vim.lsp.config("nil_ls", {
				cmd = { "nil" },
				filetypes = { "nix" },
				root_markers = { "flake.nix", ".git" },
				capabilities = capabilities,
			})
			vim.lsp.enable("nil_ls")

			local map = vim.keymap.set
			map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
			map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Search text" })
			map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
			map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Search help" })
			map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic" })
			map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
			map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
			map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
			map("n", "gr", vim.lsp.buf.references, { desc = "Show references" })
			map("n", "K", vim.lsp.buf.hover, { desc = "Show documentation" })
			map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
			map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
			map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
			map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
		'';
	};
}
