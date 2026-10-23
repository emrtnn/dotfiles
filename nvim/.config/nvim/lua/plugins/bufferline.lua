return {
	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		keys = {
			{ "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
			{ "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
			{ "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", desc = "Delete Other Buffers" },
			{ "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
			{ "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
			{ "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
			{ "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
			{
				"<leader>bd",
				function()
					Snacks.bufdelete() -- keeps the window layout intact
				end,
				desc = "Delete This Buffer",
			},
		},
		opts = {
			-- Caelus: the current buffer is marked in the orange accent.
			highlights = {
				indicator_selected = { fg = "#ef934d" },
				buffer_selected = { fg = "#f4decd", bold = true, italic = false },
				modified_selected = { fg = "#ef934d" },
			},
			options = {
				-- Close buffers without closing their windows.
				close_command = function(n)
					Snacks.bufdelete(n)
				end,
				right_mouse_command = function(n)
					Snacks.bufdelete(n)
				end,
				indicator = {
					style = "icon",
				},
				buffer_close_icon = "󰅖",
				modified_icon = "● ",
				close_icon = " ",
				left_trunc_marker = " ",
				right_trunc_marker = " ",
				diagnostics = "nvim_lsp",
				color_icons = true,
				separator_style = "thin", -- "slant" | "slope" | "thick" | "thin"
			},
		},
	},
}
