-- Lualine theme for colors/caelus.lua: the mode block carries the color,
-- the rest of the line stays on the sunken bar surface.
local c = {
	bg = "#0f0f0f",
	bar = "#141514",
	raised = "#272a28",
	muted = "#888e7b",
	fg = "#d9cdb5",
	orange = "#ef934d",
	yellow = "#efbf71",
	green = "#72ca68",
	blue = "#71b4d6",
	magenta = "#e28dc6",
	red = "#f16e65",
}

local function mode(color)
	return {
		a = { fg = c.bg, bg = color, gui = "bold" },
		b = { fg = color, bg = c.raised },
		c = { fg = c.fg, bg = c.bar },
	}
end

return {
	normal = mode(c.orange),
	insert = mode(c.green),
	visual = mode(c.magenta),
	replace = mode(c.red),
	command = mode(c.yellow),
	terminal = mode(c.blue),
	inactive = {
		a = { fg = c.muted, bg = c.bar },
		b = { fg = c.muted, bg = c.bar },
		c = { fg = c.muted, bg = c.bar },
	},
}
