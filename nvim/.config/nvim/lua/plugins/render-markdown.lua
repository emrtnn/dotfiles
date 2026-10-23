return {
	{
		-- In-buffer markdown rendering on top of Nvim's treesitter highlighting.
		-- LSP hover floats are markdown too (buftype=nofile): rendered in every
		-- mode and without signs by its default overrides.
		"MeanderingProgrammer/render-markdown.nvim",
		ft = "markdown",
		dependencies = { "nvim-mini/mini.icons" },
		---@module 'render-markdown'
		---@type render.md.UserConfig
		opts = {},
	},
}
