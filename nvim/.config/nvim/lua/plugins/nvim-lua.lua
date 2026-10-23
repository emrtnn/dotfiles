return {
	{
		"folke/lazydev.nvim",
		ft = "lua",
		cmd = "LazyDev",
		opts = {
			library = {
				-- luv type definitions ship with lua-language-server ("${3rd}").
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				-- Snacks global used in keymaps.
				{ path = "snacks.nvim", words = { "Snacks" } },
			},
		},
	},
}
