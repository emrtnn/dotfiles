return {
	{
		"saghen/blink.cmp",
		dependencies = {
			"saghen/blink.lib",
			"rafamadriz/friendly-snippets",
		},
		-- Not needed before typing. LSP servers get blink's capabilities from
		-- lsp.lua, so nothing has to load this early.
		event = { "InsertEnter", "CmdlineEnter" },
		build = function()
			require("blink.cmp").build():pwait(60000)
		end,

		---@module 'blink.cmp'
		---@type blink.cmp.Config
		opts = {
			keymap = { preset = "super-tab" },

			appearance = {
				nerd_font_variant = "mono",
			},

			-- Window borders follow 'winborder'.
			completion = {
				accept = { auto_brackets = { enabled = true } },
				menu = {
					draw = { treesitter = { "lsp" } },
				},
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
				},
			},

			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
				-- Lua only, so other filetypes never require (and load) lazydev.
				per_filetype = { lua = { inherit_defaults = true, "lazydev" } },
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						score_offset = 100, -- above LSP items for require()/vim.* completions
					},
				},
			},

			signature = { enabled = true },

			fuzzy = { implementation = "rust" },
		},
		opts_extend = { "sources.default" },
	},
}
