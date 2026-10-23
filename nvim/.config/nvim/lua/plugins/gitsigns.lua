return {
	{
		"lewis6991/gitsigns.nvim",
		-- Signs are computed asynchronously anyway, so load after the first draw;
		-- setup() attaches to every buffer that is already open.
		event = "VeryLazy",
		opts = {
			-- Keymaps attached only to git-tracked buffers
			on_attach = function(buffer)
				local gs = require("gitsigns")

				local function map(mode, l, r, desc)
					vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
				end

				local function lines()
					return { vim.fn.line("."), vim.fn.line("v") }
				end

				-- Navigation
				map("n", "]h", function()
					gs.nav_hunk("next")
				end, "Next Git Hunk")
				map("n", "[h", function()
					gs.nav_hunk("prev")
				end, "Previous Git Hunk")

				-- Actions. stage_hunk toggles: on an already staged hunk it unstages it.
				map("n", "<leader>ghs", gs.stage_hunk, "Stage/Unstage Hunk")
				map("n", "<leader>ghr", gs.reset_hunk, "Reset Hunk")
				map("x", "<leader>ghs", function()
					gs.stage_hunk(lines())
				end, "Stage/Unstage Lines")
				map("x", "<leader>ghr", function()
					gs.reset_hunk(lines())
				end, "Reset Lines")
				map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
				map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
				map("n", "<leader>ghp", gs.preview_hunk, "Preview Hunk")
				map("n", "<leader>ghb", function()
					gs.blame_line({ full = true })
				end, "Blame Line")
				map("n", "<leader>ghd", gs.diffthis, "Diff This")
				map("n", "<leader>ghD", function()
					gs.diffthis("~")
				end, "Diff Project (~)")
			end,
		},
	},
}
