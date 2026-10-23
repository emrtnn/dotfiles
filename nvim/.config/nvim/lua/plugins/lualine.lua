return {
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = {
			options = {
				theme = "caelus",
				globalstatus = true,
				refresh = {
					-- Lualine's defaults plus Progress, so LSP progress updates live.
					events = {
						"WinEnter",
						"BufEnter",
						"BufWritePost",
						"SessionLoadPost",
						"FileChangedShellPost",
						"VimResized",
						"Filetype",
						"CursorMoved",
						"CursorMovedI",
						"ModeChanged",
						"Progress",
					},
				},
			},
			sections = {
				lualine_c = {
					{
						"filename",
						path = 1,
						shorting_target = 0,
						-- Show the parent directory plus the filename.
						fmt = function(filename)
							return filename:match("([^/]+/[^/]+)$") or filename
						end,
					},
				},
				lualine_x = {
					-- Native (0.12) progress summary, e.g. "45%(2)" while LSP servers work.
					function()
						return vim.ui.progress_status()
					end,
					"encoding",
					"fileformat",
					"filetype",
				},
			},
		},
	},
}
