local keymap = vim.keymap.set

-- Leaders: set before lazy.nvim so plugin keymaps use them.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Clipboard
keymap({ "n", "x" }, "<leader>y", [["+y]], { desc = "Yank to Clipboard" })
keymap({ "n", "x" }, "<leader>p", [["+p]], { desc = "Paste from Clipboard" })
keymap("n", "<leader>P", [["+P]], { desc = "Paste from Clipboard (Before)" })

-- Search
keymap("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Native undotree (0.12), added to 'runtimepath' on first use.
keymap("n", "<leader>u", function()
	vim.cmd.packadd("nvim.undotree")
	vim.cmd.Undotree()
end, { desc = "Undotree" })
