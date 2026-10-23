return {
	{
		"dmtrKovalenko/fff.nvim",
		-- The plugin manages its own lazy-loading internally, so we tell lazy.nvim to load it immediately
		lazy = false,

		-- When lazy.nvim clones the repo, download the prebuilt Rust binary
		-- (or build it with cargo, from rustup).
		build = function()
			-- downloads a prebuilt binary or falls back to cargo build
			require("fff.download").download_or_build_binary()
		end,
		opts = {
			debug = {
				enabled = false,
				show_scores = false,
			},
			git = {
				status_text_color = true,
			},
			hl = {
				cursor = "FFFCursorLine",
			},
		},
		keys = {
			{
				"<leader>ff",
				function()
					require("fff").find_files()
				end,
				desc = "Find files",
			},
			{
				"<leader>f/",
				function()
					require("fff").live_grep({
						grep = { modes = { "fuzzy", "plain", "regex" } },
					})
				end,
				desc = "Live fuzzy grep",
			},
			{
				"<leader>fc",
				function()
					require("fff").live_grep({ query = vim.fn.expand("<cword>") })
				end,
				desc = "Search current word",
			},
		},
	},
}
