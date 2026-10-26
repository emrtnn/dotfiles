-- Language servers, formatters and linters, installed by mason.nvim into
-- stdpath("data")/mason.
--
-- Doom Emacs uses these same binaries: ~/.config/zsh/.zshenv puts
-- ~/.local/share/nvim/mason/bin on PATH, and ~/.config/doom/config.el adds it
-- to `exec-path'.
--
-- Not installed here, because they must match the system toolchain or are
-- compilers/runtimes rather than editor tools (see ~/dotfiles/packages.md):
--   clang (clangd, clang-format, clang-tidy), cppcheck, cmake    -> pacman
--   rustup (cargo, rustc, rustfmt, clippy, rust-analyzer)       -> pacman + rustup
--   zig, php, nodejs/npm, python                                -> pacman
--   nixd (not in mason's registry)                              -> AUR
--   foundry (forge fmt)                                         -> AUR foundry-bin
--
-- :Mason shows what is installed; :MasonToolsUpdate updates everything below;
-- :MasonToolsClean removes tools that are no longer listed.
local tools = {
	-- Python (The Astral Stack)
	"ruff",
	"basedpyright",
	"black", -- Doom's :lang python formatter

	-- Go (go from pacman); gore and gotests' REPL/test helpers for Doom
	"gopls",
	"gomodifytags",
	"gotests",

	-- Web: Biome lint/format + vtsls types; Prettier for Astro
	"biome",
	"vtsls",
	"typescript-language-server", -- Doom/lsp-mode's TS client (no vtsls client)
	"astro-language-server",
	"prettier",
	"yaml-language-server",
	-- vscode-langservers-extracted (jsonls here; Doom's web module also uses html/css)
	"json-lsp",
	"html-lsp",
	"css-lsp",
	"stylelint", -- Doom's :lang web CSS linter

	-- PHP: PHPactor language services + PHP-CS-Fixer formatting (php from pacman)
	"phpactor",
	"php-cs-fixer",

	-- Nix (The Modern Stack): nixd comes from the AUR
	"alejandra",
	"statix",
	"nixfmt", -- Doom's nix-format-buffer

	-- C/C++: clangd/clang-tidy come from pacman's clang; CMake formatted by
	-- gersemi (cmake-format is unmaintained) and linted by cmakelint
	"neocmakelsp",
	"cmakelint",
	"gersemi",

	-- Zig: zig from pacman; zls must match its version
	"zls",

	-- Solidity
	"solidity", -- solc
	"vscode-solidity-server", -- Includes Solhint; no separate linter process needed.

	-- Lua
	"lua-language-server",
	"stylua",

	-- Shell: bash-language-server runs ShellCheck itself; shfmt formats
	"bash-language-server",
	"shellcheck",
	"shfmt",

	-- Docker: language services + Dockerfile/ShellCheck best-practice checks
	"dockerfile-language-server",
	"docker-compose-language-service",
	"hadolint",
}

return {
	{
		"mason-org/mason.nvim",
		cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonLog" },
		init = function()
			-- Put mason's bin first on PATH without loading the plugin, so servers
			-- started by vim.lsp.enable() (lsp.lua), conform and nvim-lint find
			-- them from the first buffer on. Removes the copy .zshenv appends.
			local bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin")
			local path = vim.tbl_filter(function(dir)
				return dir ~= bin
			end, vim.split(vim.env.PATH or "", ":", { plain = true }))
			vim.env.PATH = table.concat({ bin, unpack(path) }, ":")
		end,
		---@module 'mason'
		---@type MasonSettings
		opts = {
			PATH = "skip", -- already done in init
		},
	},
	{
		-- Installs whatever in `tools` is missing, in the background, after the
		-- first draw. Nothing is updated implicitly: run :MasonToolsUpdate.
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		event = "VeryLazy",
		dependencies = { "mason-org/mason.nvim" },
		cmd = { "MasonToolsInstall", "MasonToolsUpdate", "MasonToolsClean" },
		opts = {
			ensure_installed = tools,
			-- Its own VimEnter hook has already fired when VeryLazy loads it, so
			-- the start-up check is triggered from config below.
			run_on_start = true,
			start_delay = 0,
		},
		config = function(_, opts)
			local installer = require("mason-tool-installer")
			installer.setup(opts)
			installer.run_on_start()
		end,
	},
}
