local create_autocmd = vim.api.nvim_create_autocmd

-- Highlight line on yank
create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.on_yank({
			higroup = "IncSearch",
			timeout = 300,
		})
	end,
})

-- Silence diagnostics in buffers with merge conflict markers. Parsers and
-- linters choke on them and flood the buffer with errors and virtual lines.
-- search() scans in C and stops at the first hit, instead of copying every
-- line into Lua on each TextChanged. Matches Git and Jujutsu markers.
local function has_conflict_markers(buf)
	return vim.api.nvim_buf_call(buf, function()
		return vim.fn.search([[^\(<<<<<<<\|>>>>>>>\) ]], "nw") > 0
	end)
end

create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave", "TextChanged" }, {
	group = vim.api.nvim_create_augroup("UserConflictDiagnostics", { clear = true }),
	callback = function(event)
		local buf = event.buf
		if vim.bo[buf].buftype ~= "" then
			return
		end
		local conflicted = has_conflict_markers(buf)
		if conflicted == (vim.b[buf].has_conflicts or false) then
			return
		end
		vim.b[buf].has_conflicts = conflicted
		vim.diagnostic.enable(not conflicted, { bufnr = buf })
		if conflicted then
			vim.notify("Conflict markers found: diagnostics disabled for this buffer", vim.log.levels.INFO)
		end
	end,
})

-- Go to the last known cursor position when reopening a file
create_autocmd("BufReadPost", {
	callback = function(event)
		local exclude = { "gitcommit" }
		local buf = event.buf
		if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].last_loc_restored then
			return
		end
		vim.b[buf].last_loc_restored = true
		local mark = vim.api.nvim_buf_get_mark(buf, '"')
		local lcount = vim.api.nvim_buf_line_count(buf)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})
