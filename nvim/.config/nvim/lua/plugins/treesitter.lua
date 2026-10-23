return {
	{
		"nvim-treesitter/nvim-treesitter",
		version = false,
		build = ":TSUpdate",
		lazy = false, -- the main branch does not support lazy-loading
		config = function()
			local treesitter = require("nvim-treesitter")
			local parsers = {
				"astro",
				"bash",
				"c",
				"cpp",
				"css",
				"cmake",
				"diff",
				"dockerfile",
				"git_rebase",
				"gitcommit",
				"html",
				"javascript",
				"jsdoc",
				"json",
				"lua",
				"luadoc",
				"luap",
				"make",
				"markdown",
				"markdown_inline",
				"nix",
				"php",
				"php_only",
				"python",
				"query",
				"regex",
				"rust",
				"solidity",
				"toml",
				"typescript",
				"tsx",
				"vim",
				"vimdoc",
				"xml",
				"yaml",
				"zig",
				"zsh",
			}

			-- Highlighting, indentation and folds for buffers with a parser. Fold
			-- level, text and fillchars are global (options.lua); vim.wo[0][0] sets
			-- the method for this buffer only (like :setlocal).
			local function enable(buf)
				local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
				if not lang or not vim.treesitter.language.add(lang) then
					return
				end

				vim.treesitter.start(buf, lang)
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				if vim.api.nvim_get_current_buf() == buf then
					vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
					vim.wo[0][0].foldmethod = "expr"
				end
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
				callback = function(event)
					enable(event.buf)
				end,
			})

			-- Only install what is missing rather than re-checking every parser on
			-- each startup; reattach to open buffers once new parsers are built.
			local installed = treesitter.get_installed("parsers")
			local missing = vim.tbl_filter(function(parser)
				return not vim.list_contains(installed, parser)
			end, parsers)
			if #missing > 0 then
				treesitter.install(missing):await(function()
					vim.schedule(function()
						for _, win in ipairs(vim.api.nvim_list_wins()) do
							vim.api.nvim_win_call(win, function()
								enable(vim.api.nvim_win_get_buf(win))
							end)
						end
					end)
				end)
			end
		end,
	},
	{
		-- Ships the textobjects queries mini.ai uses, plus function/class motions.
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		event = "VeryLazy",
		init = function()
			vim.g.no_plugin_maps = true
		end,
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = { lookahead = true },
				move = { set_jumps = true },
			})

			local map = vim.keymap.set

			-- Select: af/if/ac/ic/ao/io come from mini.ai, which only reads the
			-- "textobjects" query. The scope object needs the "locals" query.
			map({ "x", "o" }, "as", function()
				require("nvim-treesitter-textobjects.select").select_textobject("@local.scope", "locals")
			end, { desc = "Select language scope" })

			-- Move
			local move = require("nvim-treesitter-textobjects.move")

			map({ "n", "x", "o" }, "]f", function()
				move.goto_next_start("@function.outer")
			end, { desc = "Next function start" })

			map({ "n", "x", "o" }, "[f", function()
				move.goto_previous_start("@function.outer")
			end, { desc = "Previous function start" })

			map({ "n", "x", "o" }, "]F", function()
				move.goto_next_end("@function.outer")
			end, { desc = "Next function end" })

			map({ "n", "x", "o" }, "[F", function()
				move.goto_previous_end("@function.outer")
			end, { desc = "Previous function end" })

			map({ "n", "x", "o" }, "]C", function()
				move.goto_next_end("@class.outer")
			end, { desc = "Next class end" })

			map({ "n", "x", "o" }, "[C", function()
				move.goto_previous_end("@class.outer")
			end, { desc = "Previous class end" })
		end,
	},
}
