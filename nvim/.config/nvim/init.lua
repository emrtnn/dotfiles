-- Imports
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Local colorscheme (colors/caelus.lua); applied before plugins so they derive
-- their highlights from it.
vim.cmd.colorscheme("caelus")

-- lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
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
		{ import = "plugins" },
	},
	defaults = {
		-- Every spec declares its own trigger (event/ft/keys/cmd) or opts out
		-- with lazy = false explicitly.
		lazy = false,
		-- Track the latest commit; lazy-lock.json pins what is installed.
		version = false,
	},
	install = { colorscheme = { "caelus", "habamax" } },
	rocks = { enabled = false }, -- no plugin here needs luarocks
	checker = {
		enabled = true, -- check for plugin updates periodically
		notify = false,
	},
	performance = {
		rtp = {
			-- Runtime plugins that are never used here.
			disabled_plugins = {
				"gzip",
				"netrwPlugin", -- Oil is the file explorer
				"rplugin", -- no remote (Python/Node) plugins
				"tarPlugin",
				"tutor",
				"zipPlugin",
			},
		},
	},
})

-- Native :DiffTool (0.12). Only defines a command and a VimEnter hook that
-- opens it for `nvim -d <dir> <dir>`, so loading it at startup is free.
vim.cmd.packadd("nvim.difftool")
