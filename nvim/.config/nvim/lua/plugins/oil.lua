return {
	{
		"stevearc/oil.nvim",
		-- Loaded on demand. Oil takes over directory buffers from a BufAdd
		-- autocmd, so `init` makes sure it is loaded before one is created:
		-- right away when Nvim starts on a directory, otherwise on the first
		-- directory buffer. Oil also sends LSP willRenameFiles/didRenameFiles
		-- itself (lsp_file_methods), so moves update imports.
		cmd = "Oil",
		keys = {
			{ "<leader>e", "<cmd>Oil<cr>", desc = "Open Oil" },
		},
		init = function()
			local function is_dir(path)
				return path ~= "" and vim.fn.isdirectory(path) == 1
			end

			for _, arg in ipairs(vim.fn.argv()) do
				if is_dir(arg) then
					require("oil")
					return
				end
			end

			vim.api.nvim_create_autocmd("BufAdd", {
				group = vim.api.nvim_create_augroup("UserOilLazy", { clear = true }),
				desc = "Load Oil for the first directory buffer",
				callback = function(event)
					if package.loaded.oil then
						return true
					end
					if is_dir(event.file) then
						require("oil")
						-- Oil's own BufAdd autocmd did not exist yet when this event fired.
						vim.api.nvim_exec_autocmds("BufAdd", { group = "Oil", buffer = event.buf })
						return true
					end
				end,
			})
		end,
		---@module 'oil'
		---@type oil.SetupOpts
		opts = {
			columns = {
				"icon",
				{ "size", highlight = "Special", align = "right" },
			},
			skip_confirm_for_simple_edits = true,
		},
		dependencies = { "nvim-mini/mini.icons" },
	},
}
