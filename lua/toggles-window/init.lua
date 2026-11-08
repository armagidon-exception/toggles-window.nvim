---@module "toggles-window"
---@module "snacks"

local M = {}

---@type toggles-window.Config
local default_config = {
	icons = {
		enabled_icon = " ",
		disabled_icon = " ",
	},
	max_height = 20,
	max_width = 50,
	title = "Toggles",
	border = "single",
	expose_toggles = {},
}

M.config = default_config
M.ns = vim.api.nvim_create_namespace "snacks_toggles_ns"
M.augroup = vim.api.nvim_create_augroup("snacks_toggles_augroup", { clear = true })
M.win = nil

vim.api.nvim_set_hl(0, "TogglesWindowEnabled", { fg = "green" })
vim.api.nvim_set_hl(0, "TogglesWindowDisabled", { fg = "red" })

local function enumerate_pairs(table)
	local count = 0
	local n, s = pairs(table)

	local function iter(inv, key)
		count = count + 1
		local nk = n(inv, key)
		return nk, table[nk], count
	end

	return iter, s
end

---@param opts toggles-window.Config
---@param win toggles-window.win
---@param toggle snacks.toggle.Class
---@param line integer
---@param init? boolean
local function render_line(opts, win, toggle, line, init)
	init = init or false
	vim.bo[win.buf].modifiable = true
	local ext_marks = vim.api.nvim_buf_get_extmarks(win.buf, M.ns, { line - 1, 0 }, { line - 1, -1 }, {
		overlap = true,
		type = "virt_text",
	})

	for i = 1, #ext_marks do
		vim.api.nvim_buf_del_extmark(win.buf, M.ns, ext_marks[i][1])
	end

	if init and line > 1 then
		vim.api.nvim_buf_set_lines(win.buf, line - 1, line - 1, true, { "" })
	end

	local icon, hl_group
	local toggle_state = vim.api.nvim_win_call(win.current_win, function()
		return toggle:get()
	end)
	if toggle_state then
		icon = opts.icons.enabled_icon
		hl_group = "TogglesWindowEnabled"
	else
		icon = opts.icons.disabled_icon
		hl_group = "TogglesWindowDisabled"
	end

	vim.api.nvim_buf_set_lines(win.buf, line - 1, line, true, { toggle.opts.name })

	win.lines_to_toggles[line] = toggle

	vim.api.nvim_buf_set_extmark(win.buf, M.ns, line - 1, 0, {
		virt_text = { { icon .. " ", hl_group } },
		virt_text_pos = "inline",
	})

	vim.bo[win.buf].modifiable = false
end

---@param opts toggles-window.Config
---@return toggles-window.win?
local function create_window(opts)
	local toggles = Snacks.toggle.toggles
	local toggles_count = vim.tbl_count(toggles)
	---@type toggles-window.win
	local win_data = {
		lines_to_toggles = {},
		ext_marks = {},
		buf = 0,
		win = 0,
		current_win = 0,
	}

	local disabled_icon_width = vim.fn.strdisplaywidth(opts.icons.disabled_icon) + 1
	local enabled_icon_width = vim.fn.strdisplaywidth(opts.icons.enabled_icon) + 1
	local max_icon_width = math.max(disabled_icon_width, enabled_icon_width)

	local max_toggle_name = 0
	for _, toggle in pairs(toggles) do
		max_toggle_name = math.max(max_toggle_name, vim.fn.strdisplaywidth(toggle.opts.name) + max_icon_width)
	end

	if not max_toggle_name then
		vim.notify("No toggles are exposed!", vim.log.levels.WARN)
		return
	end

	win_data.current_win = vim.api.nvim_get_current_win()

	win_data.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[win_data.buf].modifiable = false
	win_data.win = vim.api.nvim_open_win(win_data.buf, true, {
		relative = "editor",
		anchor = "SE",
		row = vim.o.lines - 1,
		col = vim.o.columns - 1,
		focusable = true,
		height = math.min(toggles_count, opts.max_height),
		width = math.min(max_toggle_name, opts.max_width),
		style = "minimal",
		title = { { opts.title } },
		title_pos = "center",
		zindex = 200,
		border = "single",
	})
	vim.wo[win_data.win].winfixbuf = true

	for _, toggle, line in enumerate_pairs(toggles) do
		---@cast toggle snacks.toggle.Class
		render_line(opts, win_data, toggle, line, true)
	end

	vim.keymap.set("n", "<CR>", function()
		local line = vim.fn.line "."
		local toggle = win_data.lines_to_toggles[line]

		vim.api.nvim_win_call(win_data.current_win, function()
			toggle:toggle()
		end)
		render_line(opts, win_data, toggle, line)
	end, { buf = win_data.buf })

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win_data.win, true)
	end, { buf = win_data.buf })

	vim.api.nvim_create_autocmd("WinLeave", {
		group = M.augroup,
		buf = win_data.buf,
		callback = function(event)
			if event.buf == win_data.buf then
				M.hide()
			end
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = M.augroup,
		buf = win_data.buf,
		callback = function()
			local cfg = vim.api.nvim_win_get_config(win_data.win)
			cfg.row = vim.o.lines - 1
			cfg.col = vim.o.columns - 1
			vim.api.nvim_win_set_config(win_data.win, cfg)
		end,
	})

	return win_data
end

function M.shown()
	return M.win ~= nil
end

function M.toggle()
	if M.shown() then
		M.hide()
	else
		M.show()
	end
end

function M.show()
	if not M.shown() then
		M.win = create_window(M.config)
	end
end

function M.hide()
	if M.shown() then
		vim.api.nvim_win_close(M.win.win, true)
		vim.api.nvim_clear_autocmds { group = M.augroup }
		M.win = nil
	end
end

---@param opts toggles-window.Config
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	for i = 1, #M.config.expose_toggles do
		local toggle = assert(M.config.expose_toggles[i], "Exposed toggle cannot be null")
		assert(
			type(toggle) == "string" or type(toggle) == "function",
			"Exposed toggle must be snacks toggle or a toggle provider"
		)
		if type(toggle) == "string" then
			Snacks.toggle.get(toggle)
		else
			toggle()
		end
	end
end

return M
