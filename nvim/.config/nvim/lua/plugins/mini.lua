return {
	{
		"nvim-mini/mini.icons",
		version = false,
		lazy = true,
		opts = {},
		init = function()
			-- Serve nvim-web-devicons from mini.icons for plugins that expect it
			-- (lualine, bufferline). mini.icons loads on the first require.
			package.preload["nvim-web-devicons"] = function()
				require("mini.icons").mock_nvim_web_devicons()
				return package.loaded["nvim-web-devicons"]
			end
		end,
	},
	{
		"nvim-mini/mini.pairs",
		version = false,
		event = "InsertEnter",
		opts = {
			modes = { insert = true, command = false, terminal = false },
			skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
			skip_ts = { "string" },
			skip_unbalanced = true,
			markdown = true,
		},
	},
	{
		"nvim-mini/mini.ai",
		version = false,
		event = "VeryLazy",
		-- Its treesitter textobjects read the queries shipped by this plugin.
		dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
		opts = function()
			local ai = require("mini.ai")
			return {
				n_lines = 500,
				-- Keep Nvim's native visual `an`/`in` incremental selection (0.12)
				-- and `al`/`il` (0.13) free.
				mappings = {
					around_next = "aN",
					inside_next = "iN",
					around_last = "aL",
					inside_last = "iL",
				},
				custom_textobjects = {
					f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
					c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
					o = ai.gen_spec.treesitter({
						a = { "@block.outer", "@conditional.outer", "@loop.outer" },
						i = { "@block.inner", "@conditional.inner", "@loop.inner" },
					}),
					u = ai.gen_spec.function_call(), -- function call ("usage"), mini.ai's default `f`
					g = function() -- whole buffer
						local last = vim.fn.line("$")
						return {
							from = { line = 1, col = 1 },
							to = { line = last, col = math.max(vim.fn.getline(last):len(), 1) },
						}
					end,
				},
			}
		end,
	},
	{
		"nvim-mini/mini.indentscope",
		version = false,
		-- Purely visual: draw after the first screen update.
		event = "VeryLazy",
		opts = {
			symbol = "│",
			options = { try_as_border = true },
		},
		init = function()
			local group = vim.api.nvim_create_augroup("UserIndentscopeDisable", { clear = true })
			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				pattern = { "help", "lazy", "oil", "snacks_*" },
				callback = function()
					vim.b.miniindentscope_disable = true
				end,
			})
			-- The dashboard's filetype is applied without a FileType event.
			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "SnacksDashboardOpened",
				callback = function(event)
					vim.b[event.buf].miniindentscope_disable = true
				end,
			})
		end,
	},
	{
		"nvim-mini/mini.surround",
		version = false,
		keys = {
			{ "gsa", mode = { "n", "x" }, desc = "Add surrounding" },
			{ "gsd", desc = "Delete surrounding" },
			{ "gsf", desc = "Find surrounding (right)" },
			{ "gsF", desc = "Find surrounding (left)" },
			{ "gsh", desc = "Highlight surrounding" },
			{ "gsr", desc = "Replace surrounding" },
			{ "gsn", desc = "Update surrounding search lines" },
		},
		opts = {
			mappings = {
				add = "gsa",
				delete = "gsd",
				find = "gsf",
				find_left = "gsF",
				highlight = "gsh",
				replace = "gsr",
				update_n_lines = "gsn",
			},
		},
	},
}
