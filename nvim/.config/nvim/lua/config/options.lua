local opt = vim.opt

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split" -- preview :substitute matches in a split

-- Undo
opt.undofile = true

-- Indentation (buffers with a treesitter parser use its indentexpr)
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.shiftround = true

-- UI & Scrolling
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.smoothscroll = true
opt.wrap = false
opt.signcolumn = "yes"
opt.laststatus = 3
opt.showmode = false
opt.guicursor = "i:block-blinkwait0-blinkon400-blinkoff250"
opt.winborder = "rounded" -- default border for every float (LSP, diagnostics, plugins)

-- Folds: all open by default, and a closed fold keeps the line's own
-- highlighting. Indent folds (computed in C) everywhere; buffers with a
-- treesitter parser switch to syntax-aware folds (see treesitter.lua). A
-- global treesitter foldexpr would cost a Lua call per line in every buffer.
opt.foldmethod = "indent"
opt.foldtext = ""
opt.foldlevelstart = 99
opt.fillchars:append({ fold = " " })

-- Windows
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen" -- keep text in place when splits open/close
opt.jumpoptions:append("view") -- restore the view (not just the cursor) on jumps

-- Misc
opt.autowrite = true
opt.confirm = true
opt.updatetime = 200
opt.timeoutlen = 300
opt.virtualedit = "block"
