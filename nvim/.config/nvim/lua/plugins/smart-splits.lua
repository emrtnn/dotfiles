local function smart_splits(fn)
	return function()
		require("smart-splits")[fn]()
	end
end

return {
	{
		-- Ctrl+h/j/k/l moves and Alt+h/j/k/l resizes across Nvim splits and tmux
		-- panes (bindings in ~/.config/tmux/tmux.conf). Not keypress-loaded: tmux
		-- keeps those keys until the backend marks the pane with @pane-is-vim.
		-- VeryLazy does that right after the first draw, keeping the backend's
		-- synchronous `tmux` call off the startup path.
		"smart-splits-nvim/smart-splits.nvim",
		event = "VeryLazy",
		dependencies = {
			{ "smart-splits-nvim/backend-tmux", main = "smart-splits-backend-tmux" },
		},
		opts = {
			-- Outside tmux the backend does not detect, and only Nvim windows are used.
			mux = { backend = "smart-splits-backend-tmux" },
		},
		keys = {
			{ "<C-h>", smart_splits("move_cursor_left"), desc = "Go to Left Window/Pane" },
			{ "<C-j>", smart_splits("move_cursor_down"), desc = "Go to Lower Window/Pane" },
			{ "<C-k>", smart_splits("move_cursor_up"), desc = "Go to Upper Window/Pane" },
			{ "<C-l>", smart_splits("move_cursor_right"), desc = "Go to Right Window/Pane" },
			{ "<M-h>", smart_splits("resize_left"), desc = "Resize Left" },
			{ "<M-j>", smart_splits("resize_down"), desc = "Resize Down" },
			{ "<M-k>", smart_splits("resize_up"), desc = "Resize Up" },
			{ "<M-l>", smart_splits("resize_right"), desc = "Resize Right" },
		},
	},
}
