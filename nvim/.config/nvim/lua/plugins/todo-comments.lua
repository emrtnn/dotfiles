return {
	{
		"folke/todo-comments.nvim",
		-- Highlighting only: attach after the first draw (setup() covers the
		-- windows that are already open). Plenary is only needed by the
		-- :TodoQuickFix/:TodoTelescope search commands, which are unused here.
		event = "VeryLazy",
		opts = {},
		keys = {
			{
				"]t",
				function()
					require("todo-comments").jump_next()
				end,
				desc = "Next Todo Comment",
			},
			{
				"[t",
				function()
					require("todo-comments").jump_prev()
				end,
				desc = "Previous Todo Comment",
			},
			{
				"<leader>xt",
				function()
					Snacks.picker.todo_comments({ dirs = { vim.api.nvim_buf_get_name(0) }, title = "Buffer Todos" })
				end,
				desc = "Buffer Todos",
			},
			{
				"<leader>xT",
				function()
					Snacks.picker.todo_comments()
				end,
				desc = "Project Todos",
			},
		},
	},
}
