-- Only analyzers that no language server already runs. Biome (web), ShellCheck
-- (bashls), Ruff, Clippy, clang-tidy, Solhint and Zig diagnostics all come
-- from their respective language servers.
local linters_by_ft = {
	c = { "cppcheck" },
	cpp = { "cppcheck" },
	cmake = { "cmakelint" },
	nix = { "statix" },
	dockerfile = { "hadolint" },
}

return {
	{
		"mfussenegger/nvim-lint",
		-- Loaded only for filetypes that actually have a linter.
		ft = vim.tbl_keys(linters_by_ft),
		keys = {
			{
				"<leader>cl",
				function()
					require("lint").try_lint()
				end,
				desc = "Lint current buffer",
			},
		},
		config = function()
			local lint = require("lint")
			lint.linters_by_ft = linters_by_ft

			local function lint_buffer(opts)
				if vim.bo.buftype == "" and not vim.b.has_conflicts then
					lint.try_lint(nil, opts)
				end
			end

			local group = vim.api.nvim_create_augroup("nvim-lint", { clear = true })

			-- Run every analyzer when the on-disk contents are current.
			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
				group = group,
				callback = function()
					lint_buffer()
				end,
			})

			-- Between writes, only run analyzers which explicitly support stdin.
			vim.api.nvim_create_autocmd("InsertLeave", {
				group = group,
				callback = function()
					lint_buffer({ filter = "stdin" })
				end,
			})

			-- The plugin is loaded by the FileType event of a buffer whose
			-- BufReadPost has already run, so lint that buffer once here.
			local initial_buffer = vim.api.nvim_get_current_buf()
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(initial_buffer) then
					return
				end
				vim.api.nvim_buf_call(initial_buffer, function()
					if vim.fn.filereadable(vim.api.nvim_buf_get_name(0)) == 1 then
						lint_buffer()
					else
						lint_buffer({ filter = "stdin" })
					end
				end)
			end)
		end,
	},
}
