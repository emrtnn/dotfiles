return {
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = "ConformInfo",
		keys = {
			{
				"<leader>cf",
				function()
					require("conform").format({ lsp_format = "fallback", timeout_ms = 3000 })
				end,
				mode = { "n", "x" },
				desc = "Format Buffer",
			},
			{
				"<leader>tf",
				function()
					if vim.g.disable_autoformat then
						vim.cmd("FormatEnable")
						vim.notify("Autoformat enabled", vim.log.levels.WARN)
					else
						vim.cmd("FormatDisable")
						vim.notify("Autoformat disabled", vim.log.levels.WARN)
					end
				end,
				desc = "Toggle Autoformat on Save",
			},
		},
		init = function()
			vim.api.nvim_create_user_command("FormatDisable", function(args)
				if args.bang then
					vim.b.disable_autoformat = true
				else
					vim.g.disable_autoformat = true
				end
			end, {
				desc = "Disable autoformat-on-save",
				bang = true,
			})

			vim.api.nvim_create_user_command("FormatEnable", function()
				vim.b.disable_autoformat = false
				vim.g.disable_autoformat = false
			end, {
				desc = "Re-enable autoformat-on-save",
			})
		end,
		opts = {
			default_format_opts = {
				timeout_ms = 3000,
				async = false,
				quiet = false,
				lsp_format = "fallback",
			},
			format_on_save = function(bufnr)
				if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
					return
				end
				return { timeout_ms = 2000, lsp_format = "fallback" }
			end,
			formatters_by_ft = {
				lua = { "stylua" },

				python = { "ruff_format", "ruff_fix", "ruff_organize_imports" },

				php = { "php_cs_fixer" },

				javascript = { "biome" },
				typescript = { "biome" },
				javascriptreact = { "biome" },
				typescriptreact = { "biome" },
				json = { "biome" },
				css = { "biome" },
				astro = { "prettier" },

				c = { "clang-format" },
				cpp = { "clang-format" },
				cmake = { "gersemi" },

				sh = { "shfmt" },
				bash = { "shfmt" },

				zig = { "zigfmt" },

				rust = { "rustfmt" },

				nix = { "alejandra" },

				solidity = { "forge_fmt" },
			},
			formatters = {
				["clang-format"] = {
					args = { "--style={BasedOnStyle: LLVM, PointerAlignment: Left}" },
				},
				-- 2-space indent (gersemi defaults to 4) unless the project has a
				-- .gersemirc; command-line flags would override it.
				gersemi = {
					prepend_args = function(_, ctx)
						if vim.fs.find(".gersemirc", { path = ctx.dirname, upward = true })[1] then
							return {}
						end
						return { "--indent", "2" }
					end,
				},
			},
		},
	},
}
