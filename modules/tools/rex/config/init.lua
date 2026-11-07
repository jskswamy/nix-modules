-- Rex configuration (~/.config/rex/init.lua)
-- Managed by nix-modules (tools.rex).
--
-- Carries the ctrl+a prefix keybindings from tmux, herdr, and Ghostty while
-- preserving Rex's native cmd+* shortcuts (including cmd+k for session.switch).

-- Prefix passthrough: ctrl+a > ctrl+a sends literal Ctrl-A (readline home).
rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- Splits & Panes
rex.bind("ctrl+a>v", "pane.split.right")
rex.bind("ctrl+a>shift+\\", "pane.split.right") -- ctrl+a > |
rex.bind("ctrl+a>shift+5", "pane.split.right") -- ctrl+a > %
rex.bind("ctrl+a>-", "pane.split.down")
rex.bind("ctrl+a>shift+'", "pane.split.down") -- ctrl+a > "
rex.bind("ctrl+a>enter", "pane.split.auto")
rex.bind("ctrl+a>shift+1", "pane.move_to_new_tab") -- ctrl+a > !
rex.bind("ctrl+a>shift+2", "pane.move_to_tab") -- ctrl+a > @
rex.bind("ctrl+a>shift+f", "pane.float") -- ctrl+a > F (float/dock current pane)
rex.bind("ctrl+a>m", "float_minimize_or_restore")
rex.bind("ctrl+a>shift+m", "float_minimize_all") -- ctrl+a > M
rex.bind("ctrl+a>y", "pane.copy_id")
rex.bind("ctrl+a>x", "pane.close")
rex.bind("ctrl+a>z", "pane.zoom")

-- Terminal Navigation, Search & Pickers
rex.bind("ctrl+a>/", "client.find.open")
rex.bind("ctrl+a>up", "client.prompt.previous")
rex.bind("ctrl+a>down", "client.prompt.next")
rex.bind("ctrl+a>shift+[", "client.prompt.previous") -- ctrl+a > {
rex.bind("ctrl+a>shift+]", "client.prompt.next") -- ctrl+a > }
rex.bind("ctrl+a>d", "pane.go_to_directory")
rex.bind("ctrl+a>i", "pane.insert_path")

-- Helpers for inspecting the active window, focused block, working directory,
-- floating layers, and parent tiled splits.
local function resolve_focused_context(ctx)
	local view = rex.session.view({})
	if not view or not view.windows then
		return nil, nil, nil
	end
	local active_win = nil
	for _, w in ipairs(view.windows) do
		if w.window_id == view.active_window_id then
			active_win = w
			break
		end
	end
	active_win = active_win or view.windows[1]
	local block_id = (active_win and active_win.focused_block_id) or (ctx and ctx.block_id)
	return view, active_win, block_id
end

local function focused_cwd(ctx)
	local _, _, block_id = resolve_focused_context(ctx)
	if not block_id then
		return nil
	end
	local ok, proc = pcall(rex.block.call, "com.superlogical.terminal", "process", {
		block_id = block_id,
	})
	if ok and proc then
		if proc.foreground and proc.foreground.cwd and proc.foreground.cwd ~= "" then
			return proc.foreground.cwd
		end
		if proc.ancestors and proc.ancestors[1] and proc.ancestors[1].cwd then
			return proc.ancestors[1].cwd
		end
		if proc.home and proc.home ~= "" then
			return proc.home
		end
	end
	return nil
end

local function focused_floating_layer(ctx)
	local view, _, block_id = resolve_focused_context(ctx)
	if not view or not block_id then
		return nil
	end
	for _, w in ipairs(view.windows) do
		for _, layer in ipairs(w.layers or {}) do
			if layer.kind == "floating" and layer.blocks then
				for _, b in ipairs(layer.blocks) do
					if b.block_id == block_id then
						return layer
					end
				end
			end
		end
	end
	return nil
end

local function first_block_in_node(node)
	if not node then
		return nil
	end
	if node.block_id then
		return node.block_id
	end
	if node.split then
		return first_block_in_node(node.split.before) or first_block_in_node(node.split.after)
	end
	return nil
end

local function find_parent_split(node, target_block_id)
	if not node or not node.split then
		return nil
	end
	local s = node.split
	local in_before = find_parent_split(s.before, target_block_id)
	if in_before then
		return in_before
	end
	local in_after = find_parent_split(s.after, target_block_id)
	if in_after then
		return in_after
	end
	if s.before and s.before.block_id == target_block_id then
		return {
			direction = s.direction,
			side = "before",
			before_block_id = target_block_id,
			after_block_id = first_block_in_node(s.after),
		}
	end
	if s.after and s.after.block_id == target_block_id then
		return {
			direction = s.direction,
			side = "after",
			before_block_id = first_block_in_node(s.before),
			after_block_id = target_block_id,
		}
	end
	return nil
end

local function focused_tiled_split(ctx)
	local _, active_win, block_id = resolve_focused_context(ctx)
	if not active_win or not block_id then
		return nil
	end
	for _, layer in ipairs(active_win.layers or {}) do
		if layer.kind == "tiled" and layer.layout then
			return find_parent_split(layer.layout, block_id)
		end
	end
	return nil
end

rex.action({
	name = "pane_new_floating",
	title = "New Floating Pane",
	category = "Pane",
	run = function(ctx)
		local cwd = focused_cwd(ctx)
		rex.session.new_layer({
			session_id = ctx.session_id,
			bounds = { 0.15, 0.15, 0.70, 0.70 },
			focus = true,
			layout = rex.layout.block({
				flavor = "com.superlogical.terminal.shell",
				label = "float",
				options = cwd and { cwd = cwd } or nil,
			}),
		})
	end,
})

rex.bind("ctrl+a>f", "pane_new_floating")

rex.action({
	name = "pane_or_float_resize",
	title = "Resize Pane or Floating Window",
	category = "Pane",
	repeats = true,
	args = {
		direction = "string",
		amount = "number?",
	},
	run = function(ctx, args)
		local amount = (args and args.amount) or 5
		local dir = args and args.direction
		local layer = focused_floating_layer(ctx)
		if layer and layer.bounds and #layer.blocks <= 1 then
			local step = amount / 100
			local x, y, w, h = layer.bounds[1], layer.bounds[2], layer.bounds[3], layer.bounds[4]
			local cx, cy = x + w / 2, y + h / 2
			local min_s, max_s = 0.20, 0.96
			if dir == "right" then
				w = math.min(max_s, w + step)
			elseif dir == "left" then
				w = math.max(min_s, w - step)
			elseif dir == "down" then
				h = math.min(max_s, h + step)
			elseif dir == "up" then
				h = math.max(min_s, h - step)
			end
			x = math.max(0, math.min(1 - w, cx - w / 2))
			y = math.max(0, math.min(1 - h, cy - h / 2))
			rex.session.resize_layer({
				session_id = ctx.session_id,
				layer_id = layer.layer_id,
				bounds = { x, y, w, h },
			})
			return
		end
		rex.client.queue("pane.resize", { direction = dir, amount = amount })
	end,
})

rex.action({
	name = "pane_or_float_move",
	title = "Move Pane or Nudge Floating Window",
	category = "Pane",
	repeats = true,
	args = {
		direction = "string",
		amount = "number?",
	},
	run = function(ctx, args)
		local amount = (args and args.amount) or 5
		local dir = args and args.direction
		local layer = focused_floating_layer(ctx)
		if layer and layer.bounds and #layer.blocks <= 1 then
			local step = amount / 100
			local x, y, w, h = layer.bounds[1], layer.bounds[2], layer.bounds[3], layer.bounds[4]
			if dir == "right" then
				x = math.min(1 - w, x + step)
			elseif dir == "left" then
				x = math.max(0, x - step)
			elseif dir == "down" then
				y = math.min(1 - h, y + step)
			elseif dir == "up" then
				y = math.max(0, y - step)
			end
			rex.session.resize_layer({
				session_id = ctx.session_id,
				layer_id = layer.layer_id,
				bounds = { x, y, w, h },
			})
			return
		end
		rex.client.queue("pane.move", { direction = dir })
	end,
})

rex.action({
	name = "pane_or_float_balance",
	title = "Balance Splits or Reset Floating Window",
	category = "Pane",
	run = function(ctx)
		local layer = focused_floating_layer(ctx)
		if layer and #layer.blocks <= 1 then
			rex.session.resize_layer({
				session_id = ctx.session_id,
				layer_id = layer.layer_id,
				bounds = { 0.15, 0.15, 0.70, 0.70 },
			})
			return
		end
		rex.client.queue("pane.balance")
	end,
})

-- Separate presets for floating windows (bounds = { x, y, w, h }) vs tiled
-- splits (focused pane share).
local floating_presets = {
	{
		key = "1",
		name = "top_left",
		title = "Corner · Top-Left",
		category = "Snap Corner",
		bounds = { 0.02, 0.04, 0.44, 0.44 },
	},
	{
		key = "2",
		name = "top_right",
		title = "Corner · Top-Right",
		category = "Snap Corner",
		bounds = { 0.54, 0.04, 0.44, 0.44 },
	},
	{
		key = "3",
		name = "bottom_left",
		title = "Corner · Bottom-Left",
		category = "Snap Corner",
		bounds = { 0.02, 0.52, 0.44, 0.44 },
	},
	{
		key = "4",
		name = "bottom_right",
		title = "Corner · Bottom-Right",
		category = "Snap Corner",
		bounds = { 0.54, 0.52, 0.44, 0.44 },
	},
	{
		key = "[",
		name = "left_drawer",
		title = "Drawer · Left (50%)",
		category = "Snap Drawer & Size",
		bounds = { 0.02, 0.04, 0.47, 0.92 },
	},
	{
		key = "]",
		name = "right_drawer",
		title = "Drawer · Right (50%)",
		category = "Snap Drawer & Size",
		bounds = { 0.51, 0.04, 0.47, 0.92 },
	},
	{
		key = "-",
		name = "bottom_drawer",
		title = "Drawer · Bottom",
		category = "Snap Drawer & Size",
		bounds = { 0.05, 0.54, 0.90, 0.43 },
	},
	{
		key = "c",
		name = "center",
		title = "Size · Center (70%)",
		category = "Snap Drawer & Size",
		bounds = { 0.15, 0.15, 0.70, 0.70 },
	},
	{
		key = "f",
		name = "large",
		title = "Size · Large (90%)",
		category = "Snap Drawer & Size",
		bounds = { 0.05, 0.05, 0.90, 0.90 },
	},
}

local tiled_presets = {
	{ key = "1", name = "25", title = "Split · 25%", share = 0.25 },
	{ key = "2", name = "33", title = "Split · 33%", share = 0.33 },
	{ key = "c", name = "50", title = "Split · 50% (Even)", share = 0.50 },
	{ key = "3", name = "67", title = "Split · 67%", share = 0.67 },
	{ key = "4", name = "75", title = "Split · 75%", share = 0.75 },
	{ key = "f", name = "85", title = "Split · 85% (Max)", share = 0.85 },
}

rex.action({
	name = "float_resize",
	title = "Resize Window",
	category = "Resize & Move",
	repeats = true,
	args = {
		direction = "string",
		amount = "number?",
	},
	run = function(ctx, args)
		rex.client.queue("pane_or_float_resize", args)
	end,
})

rex.action({
	name = "float_move",
	title = "Move Window",
	category = "Resize & Move",
	repeats = true,
	args = {
		direction = "string",
		amount = "number?",
	},
	run = function(ctx, args)
		rex.client.queue("pane_or_float_move", args)
	end,
})

rex.action({
	name = "float_reset",
	title = "Reset Default (70%)",
	category = "Resize & Move",
	run = function(ctx)
		local layer = focused_floating_layer(ctx)
		if layer then
			rex.session.resize_layer({
				session_id = ctx.session_id,
				layer_id = layer.layer_id,
				bounds = { 0.15, 0.15, 0.70, 0.70 },
			})
		end
		rex.client.queue("client.mode.exit_all")
	end,
})

for _, preset in ipairs(floating_presets) do
	local action_name = "float_snap_" .. preset.name
	rex.action({
		name = action_name,
		title = preset.title,
		category = preset.category,
		run = function(ctx)
			local layer = focused_floating_layer(ctx)
			if layer then
				rex.session.resize_layer({
					session_id = ctx.session_id,
					layer_id = layer.layer_id,
					bounds = preset.bounds,
				})
			end
			rex.client.queue("client.mode.exit_all")
		end,
	})
end

for _, preset in ipairs(tiled_presets) do
	local action_name = "split_size_" .. preset.name
	rex.action({
		name = action_name,
		title = preset.title,
		category = "Split Size",
		run = function(ctx)
			local split = focused_tiled_split(ctx)
			if split and split.before_block_id and split.after_block_id then
				local ratio = (split.side == "before") and preset.share or (1 - preset.share)
				rex.session.resize_pane({
					session_id = ctx.session_id,
					direction = split.direction,
					before_block_id = split.before_block_id,
					after_block_id = split.after_block_id,
					ratio = ratio,
				})
			end
			rex.client.queue("client.mode.exit_all")
		end,
	})
end

rex.action({
	name = "resize_mode_open",
	title = "Resize Mode",
	category = "Pane",
	run = function(ctx)
		rex.client.queue("client.mode.enter", { name = "resize" })
		if focused_floating_layer(ctx) then
			rex.client.queue("client.mode.enter", { name = "float" })
		else
			rex.client.queue("client.mode.enter", { name = "pane" })
		end
	end,
})

rex.bind("ctrl+a>0", "pane_or_float_balance")
rex.bind("ctrl+a>=", "pane_or_float_balance")

-- Pane Focus
rex.bind("ctrl+a>h", "pane.focus.left")
rex.bind("ctrl+a>j", "pane.focus.down")
rex.bind("ctrl+a>k", "pane.focus.up")
rex.bind("ctrl+a>l", "pane.focus.right")
rex.bind("ctrl+a>o", "pane.focus_next")
rex.bind("ctrl+a>tab", "pane.focus_next")
rex.bind("ctrl+a>'", "pane.focus_next")
rex.bind("ctrl+a>shift+tab", "pane.focus_previous")
rex.bind("ctrl+a>;", "pane.focus_previous")

-- One-shot Pane Resize (ctrl+a > H/J/K/L)
rex.bind("ctrl+a>shift+h", "pane_or_float_resize", { direction = "left", amount = 5 })
rex.bind("ctrl+a>shift+j", "pane_or_float_resize", { direction = "down", amount = 5 })
rex.bind("ctrl+a>shift+k", "pane_or_float_resize", { direction = "up", amount = 5 })
rex.bind("ctrl+a>shift+l", "pane_or_float_resize", { direction = "right", amount = 5 })

-- Context-Aware Modal Resize Mode (ctrl+a > r)
-- Pushes "resize" + "float" (renders badge as "resize › float") when a floating
-- window is focused, or "resize" + "pane" ("resize › pane") for a tiled pane.
rex.bind("ctrl+a>r", "resize_mode_open")

rex.mode("resize", { exclusive = true })
rex.bind("resize/escape", "client.mode.exit_all")

rex.mode("float", { exclusive = true })
rex.bind("float/h", "float_resize", { direction = "left", amount = 5 })
rex.bind("float/j", "float_resize", { direction = "down", amount = 5 })
rex.bind("float/k", "float_resize", { direction = "up", amount = 5 })
rex.bind("float/l", "float_resize", { direction = "right", amount = 5 })
rex.bind("float/left", "float_resize", { direction = "left", amount = 5 })
rex.bind("float/down", "float_resize", { direction = "down", amount = 5 })
rex.bind("float/up", "float_resize", { direction = "up", amount = 5 })
rex.bind("float/right", "float_resize", { direction = "right", amount = 5 })
rex.bind("float/shift+h", "float_move", { direction = "left", amount = 5 })
rex.bind("float/shift+j", "float_move", { direction = "down", amount = 5 })
rex.bind("float/shift+k", "float_move", { direction = "up", amount = 5 })
rex.bind("float/shift+l", "float_move", { direction = "right", amount = 5 })
rex.bind("float/0", "float_reset")
for _, preset in ipairs(floating_presets) do
	rex.bind("float/" .. preset.key, "float_snap_" .. preset.name)
end
rex.bind("float/escape", "client.mode.exit_all")

rex.mode("pane", { exclusive = true })
rex.bind("pane/h", "pane.resize", { direction = "left", amount = 5 })
rex.bind("pane/j", "pane.resize", { direction = "down", amount = 5 })
rex.bind("pane/k", "pane.resize", { direction = "up", amount = 5 })
rex.bind("pane/l", "pane.resize", { direction = "right", amount = 5 })
rex.bind("pane/left", "pane.resize", { direction = "left", amount = 5 })
rex.bind("pane/down", "pane.resize", { direction = "down", amount = 5 })
rex.bind("pane/up", "pane.resize", { direction = "up", amount = 5 })
rex.bind("pane/right", "pane.resize", { direction = "right", amount = 5 })
rex.bind("pane/shift+h", "pane.move", { direction = "left" })
rex.bind("pane/shift+j", "pane.move", { direction = "down" })
rex.bind("pane/shift+k", "pane.move", { direction = "up" })
rex.bind("pane/shift+l", "pane.move", { direction = "right" })
rex.bind("pane/=", "pane.balance")
rex.bind("pane/z", "pane.zoom")
for _, preset in ipairs(tiled_presets) do
	rex.bind("pane/" .. preset.key, "split_size_" .. preset.name)
end
rex.bind("pane/escape", "client.mode.exit_all")

-- Tool Launcher Mode (ctrl+a > t)
-- Lowercase launches/toggles a floating overlay; uppercase (Shift+) opens a
-- positioned split in the focused pane's working directory.
local tool_specs = {
	{
		key = "g",
		name = "lazygit",
		title = "Lazygit",
		label = "lazygit",
		command = { "lazygit" },
		bounds = { 0.06, 0.06, 0.88, 0.88 },
		split = { direction = "horizontal", side = "after", ratio = 0.50 },
	},
	{
		key = "h",
		name = "hunk_diff",
		title = "Hunk Diff (Watch)",
		label = "hunk-diff",
		command = { "hunk", "diff", "--watch" },
		bounds = { 0.06, 0.06, 0.88, 0.88 },
		split = { direction = "horizontal", side = "after", ratio = 0.50 },
	},
	{
		key = "c",
		name = "hunk_show",
		title = "Hunk Show (HEAD)",
		label = "hunk-show",
		command = { "hunk", "show" },
		bounds = { 0.06, 0.06, 0.88, 0.88 },
		split = { direction = "horizontal", side = "after", ratio = 0.50 },
	},
	{
		key = "l",
		name = "tig",
		title = "Tig Log",
		label = "tig",
		command = { "tig" },
		bounds = { 0.06, 0.06, 0.88, 0.88 },
		split = { direction = "horizontal", side = "after", ratio = 0.50 },
	},
	{
		key = "v",
		name = "nvim",
		title = "Neovim",
		label = "nvim",
		command = { "nvim" },
		bounds = { 0.08, 0.08, 0.84, 0.84 },
		split = { direction = "horizontal", side = "after", ratio = 0.50 },
	},
	{
		key = "b",
		name = "btop",
		title = "Btop",
		label = "btop",
		command = { "btop" },
		bounds = { 0.38, 0.04, 0.60, 0.65 },
		split = { direction = "vertical", side = "after", ratio = 0.40 },
	},
	{
		key = "s",
		name = "shell",
		title = "Scratch Shell",
		label = "scratch",
		command = nil,
		bounds = { 0.15, 0.15, 0.70, 0.70 },
		split = { direction = "vertical", side = "after", ratio = 0.70 },
	},
}

local function build_tool_block(spec, cwd)
	local opts = {}
	if spec.command then
		opts.command = spec.command
	end
	if cwd then
		opts.cwd = cwd
	end
	return rex.layout.block({
		flavor = "com.superlogical.terminal.shell",
		label = spec.label,
		options = next(opts) and opts or nil,
	})
end

local focus_after_minimize

local function launch_tool_floating(ctx, spec)
	local _, active_win, focused_block_id = resolve_focused_context(ctx)
	if active_win then
		for _, layer in ipairs(active_win.layers or {}) do
			if layer.kind == "floating" and layer.blocks then
				for _, b in ipairs(layer.blocks) do
					if b.label == spec.label then
						if b.block_id == focused_block_id and layer.state ~= "minimized" then
							rex.session.set_layer_state({
								session_id = ctx.session_id,
								layer_id = layer.layer_id,
								state = "minimized",
							})
							focus_after_minimize(ctx)
						else
							rex.session.set_layer_state({
								session_id = ctx.session_id,
								layer_id = layer.layer_id,
								state = "normal",
								focus = true,
							})
						end
						return
					end
				end
			end
		end
	end
	local cwd = focused_cwd(ctx)
	rex.session.new_layer({
		session_id = ctx.session_id,
		bounds = spec.bounds,
		focus = true,
		layout = build_tool_block(spec, cwd),
	})
end

local function launch_tool_split(ctx, spec)
	if not spec.split then
		return
	end
	local cwd = focused_cwd(ctx)
	rex.session.new_split({
		session_id = ctx.session_id,
		direction = spec.split.direction,
		side = spec.split.side,
		ratio = spec.split.ratio,
		focus = true,
		layout = build_tool_block(spec, cwd),
	})
end

rex.mode("launch", { exclusive = true })
rex.bind("ctrl+a>t", "client.mode.enter", { name = "launch", once = true })
for _, spec in ipairs(tool_specs) do
	local float_action = "tool_float_" .. spec.name
	local split_action = "tool_split_" .. spec.name
	rex.action({
		name = float_action,
		title = "Float · " .. spec.title,
		category = "Float Overlay",
		run = function(ctx)
			launch_tool_floating(ctx, spec)
		end,
	})
	rex.action({
		name = split_action,
		title = "Split · " .. spec.title,
		category = "Split Pane",
		run = function(ctx)
			launch_tool_split(ctx, spec)
		end,
	})
	rex.bind("launch/" .. spec.key, float_action)
	rex.bind("launch/shift+" .. spec.key, split_action)
end
rex.bind("launch/escape", "client.mode.exit")

-- Smart Floating Minimize & Multi-Window Maximize Picker (ctrl+a > m)
-- - Inside a visible floating window: minimizes that floating window.
-- - On a tiled pane with 1 minimized floating window: maximizes it immediately.
-- - On a tiled pane with 2+ minimized floating windows in the current tab:
--   opens a floating fzf picker that queries Rex for minimized windows via JSON + jq.
local function find_executable(name)
	local home = os.getenv("HOME") or ""
	local user = os.getenv("USER") or ""
	local candidates = {
		"/etc/profiles/per-user/" .. user .. "/bin/" .. name,
		home .. "/.nix-profile/bin/" .. name,
		home .. "/.local/bin/" .. name,
		"/opt/homebrew/bin/" .. name,
		"/run/current-system/sw/bin/" .. name,
	}
	for _, path in ipairs(candidates) do
		local f = io.open(path, "rb")
		if f then
			f:close()
			return path
		end
	end
	return name
end

local function collect_floating_layers(ctx)
	local _, active_win = resolve_focused_context(ctx)
	local minimized = {}
	local visible = {}
	if not active_win then
		return minimized, visible
	end
	for _, layer in ipairs(active_win.layers or {}) do
		if layer.kind == "floating" then
			local b = layer.blocks and layer.blocks[1]
			local lbl = (b and b.label) or "float"
			if lbl ~= "float-picker" then
				local info = {
					layer_id = layer.layer_id,
					label = lbl,
				}
				if layer.state == "minimized" then
					table.insert(minimized, info)
				else
					table.insert(visible, info)
				end
			end
		end
	end
	return minimized, visible
end

local function close_maximize_picker(ctx)
	local _, active_win = resolve_focused_context(ctx)
	if not active_win then
		return
	end
	for _, layer in ipairs(active_win.layers or {}) do
		if layer.kind == "floating" and layer.blocks then
			for _, b in ipairs(layer.blocks) do
				if b.label == "float-picker" then
					pcall(rex.session.close_layer, {
						session_id = ctx.session_id,
						layer_id = layer.layer_id,
					})
					break
				end
			end
		end
	end
end

focus_after_minimize = function(ctx)
	local _, active_win = resolve_focused_context(ctx)
	if not active_win then
		return
	end
	local target_block_id = nil
	for _, layer in ipairs(active_win.layers or {}) do
		if layer.kind == "floating" and layer.state ~= "minimized" and layer.blocks and layer.blocks[1] then
			if layer.blocks[1].label ~= "float-picker" then
				target_block_id = layer.blocks[1].block_id
			end
		end
	end
	if not target_block_id then
		for _, layer in ipairs(active_win.layers or {}) do
			if layer.kind == "tiled" and layer.blocks and layer.blocks[1] then
				target_block_id = layer.blocks[1].block_id
				break
			end
		end
	end
	if target_block_id then
		pcall(rex.session.focus_block, {
			session_id = ctx.session_id,
			block_id = target_block_id,
		})
	end
end

local function tool_path_env()
	local home = os.getenv("HOME") or ""
	local user = os.getenv("USER") or ""
	return table.concat({
		home .. "/.local/bin",
		"/etc/profiles/per-user/" .. user .. "/bin",
		home .. "/.nix-profile/bin",
		"/run/current-system/sw/bin",
		"/opt/homebrew/bin",
		"/usr/bin",
		"/bin",
	}, ":")
end

local function launch_maximize_picker(ctx)
	close_maximize_picker(ctx)
	local path_env = tool_path_env()
	local view = rex.session.view({})
	local session_id = (ctx and ctx.session_id) or (view and view.session_id) or ""
	local script = [[
target=$(
  rex -s "$REX_SESSION" do -e '
    local v = rex.session.view({})
    local home = os.getenv("HOME") or ""
    local out = {}
    for _, w in ipairs((v and v.windows) or {}) do
      if w.window_id == v.active_window_id then
        for _, l in ipairs(w.layers or {}) do
          if l.kind == "floating" and l.state == "minimized" and l.blocks and l.blocks[1] then
            local b = l.blocks[1]
            local lbl = b.label or "float"
            if lbl ~= "float-picker" then
              local ok_t, t = pcall(rex.block.call, "com.superlogical.terminal", "title", { block_id = b.block_id })
              local ok_p, p = pcall(rex.block.call, "com.superlogical.terminal", "process", { block_id = b.block_id })
              local fg = (ok_p and p and p.foreground) or {}
              local cwd = fg.cwd or ""
              if home ~= "" and cwd:sub(1, #home) == home then
                cwd = "~" .. cwd:sub(#home + 1)
              end
              local win_title = (ok_t and t and t.title and t.title ~= "") and t.title or nil
              local proc_name = fg.name or lbl
              table.insert(out, {
                layer_id = l.layer_id,
                block_id = b.block_id,
                label = lbl,
                title = win_title or (cwd ~= "" and (proc_name .. " — " .. cwd) or proc_name),
              })
            end
          end
        end
      end
    end
    return out
  ' --json \
  | jq -r '
      (group_by(.title + "|" + .label) | map(select(length > 1) | .[0].title + "|" + .[0].label)) as $dups |
      reduce to_entries[] as $item (
        { seen: {}, rows: [] };
        ($item.value.title + "|" + $item.value.label) as $key |
        (.seen[$key] = ((.seen[$key] // 0) + 1)) |
        .seen[$key] as $n |
        ($item.value.title + "  [" + $item.value.label + "]" + (if ($dups | index($key)) then " #" + ($n | tostring) else "" end)) as $disp |
        .rows += ["\($item.key + 1)  \($disp)\t\($item.value.layer_id)\t\($item.value.block_id)"]
      ) | .rows[], "a  All Windows\tALL\t"
    ' \
  | fzf --reverse --ansi --delimiter='	' --with-nth=1 --header='Maximize Floating Window' --prompt='Maximize > ' --height=100% --border=none --preview='[ -n {3} ] && rex capture -b {3}' --preview-window='right:55%:wrap' \
  | cut -f2
)
if [ "$target" = "ALL" ]; then
  rex -s "$REX_SESSION" do maximize_all_floating >/dev/null 2>&1
elif [ -n "$target" ]; then
  rex -s "$REX_SESSION" do -e '
    rex.session.set_layer_state({ layer_id = rex.args.target, state = "normal", focus = true })
    local v = rex.session.view({})
    for _, w in ipairs((v and v.windows) or {}) do
      for _, l in ipairs(w.layers or {}) do
        if l.kind == "floating" and l.blocks and l.blocks[1] and l.blocks[1].label == "float-picker" then
          pcall(rex.session.close_layer, { layer_id = l.layer_id })
        end
      end
    end
  ' target="$target" >/dev/null 2>&1
else
  rex -s "$REX_SESSION" do -e '
    local v = rex.session.view({})
    for _, w in ipairs((v and v.windows) or {}) do
      for _, l in ipairs(w.layers or {}) do
        if l.kind == "floating" and l.blocks and l.blocks[1] and l.blocks[1].label == "float-picker" then
          pcall(rex.session.close_layer, { layer_id = l.layer_id })
        end
      end
    end
  ' >/dev/null 2>&1
fi
]]
	rex.session.new_layer({
		session_id = ctx.session_id,
		bounds = { 0.15, 0.20, 0.70, 0.55 },
		focus = true,
		layout = rex.layout.block({
			flavor = "com.superlogical.terminal.shell",
			label = "float-picker",
			options = {
				command = {
					"/usr/bin/env",
					"PATH=" .. path_env,
					"REX_SESSION=" .. tostring(session_id),
					"/bin/sh",
					"-c",
					script,
				},
				shell = "none",
			},
		}),
	})
end

-- Doc Reader (ctrl+a > e)
-- Scans the focused pane's scrollback for paths (newest first), resolving
-- relative paths and bare filenames from the pane cwd up to its git repo root
-- and parent org directory (or ~/source/<host>/<org>), streaming hits into fzf
-- with a full-width list and bottom preview. Markdown opens in glow, text in
-- bat, and everything else with the system opener.
-- shortcut: extension-suffixed paths only, so a path with spaces is missed.
local doc_reader_script = [=[
cwd=${SRC_CWD:-$HOME}
repo=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || repo=$cwd
case $repo in
  "$HOME"/source/*/*/*)
    rest=${repo#"$HOME/source/"}
    host=${rest%%/*}
    rest=${rest#*/}
    org="$HOME/source/$host/${rest%%/*}"
    ;;
  *)
    org=$(dirname "$repo")
    if [ "$org" = "$HOME" ] || [ "$org" = / ]; then
      org=$repo
    fi
    ;;
esac
fd_exact() {
  command -v fd >/dev/null 2>&1 || return 1
  found=
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    tail=${hit%/"$1"}
    if [ "$tail/$1" = "$hit" ] && [ -f "$hit" ]; then
      printf '%s\n' "$hit"
      found=1
    fi
  done <<EOF
$(fd -H -I -E .git -E node_modules -E vendor -t f -p -F -s -a -- "/$1" "$2" 2>/dev/null)
EOF
  [ -n "$found" ]
}
resolve() {
  p=$1
  case $p in
    [~]/*) p="$HOME/${p#??}" ;;
  esac
  case $p in
    /*)
      [ -f "$p" ] && printf '%s\n' "$p"
      return
      ;;
    ./*) p=${p#??} ;;
  esac
  dir=$cwd
  while [ -n "$dir" ] && [ "$dir" != / ]; do
    if [ -f "$dir/$p" ]; then
      printf '%s\n' "$dir/$p"
      return
    fi
    [ "$dir" = "$org" ] || [ "$dir" = "$HOME" ] && break
    next=$(dirname "$dir")
    [ "$next" = "$dir" ] && break
    dir=$next
  done
  fd_exact "$p" "$repo" && return
  [ "$org" != "$repo" ] && fd_exact "$p" "$org"
}
pick=$(
  rex -s "$REX_SESSION" capture -b "$SRC_BLOCK" --unwrap \
  | grep -oE '[A-Za-z0-9_./~+@-]+\.(md|html|png|jpe?g|svg|pdf|txt)' \
  | awk '{ l[NR] = $0 } END { for (i = NR; i > 0; i--) if (!s[l[i]]++) print l[i] }' \
  | while IFS= read -r p; do
      resolve "$p"
    done \
  | awk '!s[$0]++ { print; fflush() }' \
  | fzf --reverse --height=100% --border=none --prompt='Open doc > ' \
      --preview='bat --color=always --style=plain {}' --preview-window='down:65%:wrap'
)
if [ -n "$pick" ]; then
  case $pick in
    *.md) glow -p "$pick" ;;
    *.txt) bat --paging=always "$pick" ;;
    *) open "$pick" ;;
  esac
fi
rex -s "$REX_SESSION" do -e '
  local v = rex.session.view({})
  for _, w in ipairs((v and v.windows) or {}) do
    for _, l in ipairs(w.layers or {}) do
      if l.kind == "floating" and l.blocks and l.blocks[1] and l.blocks[1].label == "doc-reader" then
        pcall(rex.session.close_layer, { layer_id = l.layer_id })
      end
    end
  end
' >/dev/null 2>&1
]=]

rex.action({
	name = "doc_reader",
	title = "Open Doc From Output",
	category = "Float Overlay",
	run = function(ctx)
		local _, _, src_block = resolve_focused_context(ctx)
		rex.session.new_layer({
			session_id = ctx.session_id,
			bounds = { 0.04, 0.04, 0.92, 0.92 },
			focus = true,
			layout = rex.layout.block({
				flavor = "com.superlogical.terminal.shell",
				label = "doc-reader",
				options = {
					command = {
						"/usr/bin/env",
						"PATH=" .. tool_path_env(),
						"REX_SESSION=" .. tostring(ctx.session_id),
						"SRC_BLOCK=" .. tostring(src_block or ""),
						"SRC_CWD=" .. (focused_cwd(ctx) or os.getenv("HOME") or ""),
						"/bin/sh",
						"-c",
						doc_reader_script,
					},
					shell = "none",
				},
			}),
		})
	end,
})

rex.bind("ctrl+a>e", "doc_reader")

rex.action({
	name = "float_minimize_or_restore",
	title = "Minimize or Maximize Floating Window",
	category = "Pane",
	run = function(ctx)
		local focused_float = focused_floating_layer(ctx)
		if focused_float and focused_float.state ~= "minimized" then
			local b = focused_float.blocks and focused_float.blocks[1]
			if b and b.label == "float-picker" then
				rex.session.close_layer({
					session_id = ctx.session_id,
					layer_id = focused_float.layer_id,
				})
				focus_after_minimize(ctx)
				return
			end
			rex.session.set_layer_state({
				session_id = ctx.session_id,
				layer_id = focused_float.layer_id,
				state = "minimized",
			})
			focus_after_minimize(ctx)
			return
		end

		local minimized, visible = collect_floating_layers(ctx)
		if #minimized == 1 then
			rex.session.set_layer_state({
				session_id = ctx.session_id,
				layer_id = minimized[1].layer_id,
				state = "normal",
				focus = true,
			})
			return
		elseif #minimized > 1 then
			launch_maximize_picker(ctx)
			return
		elseif #visible > 0 then
			rex.session.set_layer_state({
				session_id = ctx.session_id,
				layer_id = visible[#visible].layer_id,
				state = "minimized",
			})
			focus_after_minimize(ctx)
		end
	end,
})

rex.action({
	name = "float_minimize_all",
	title = "Minimize All Floating Windows",
	category = "Pane",
	run = function(ctx)
		close_maximize_picker(ctx)
		local _, visible = collect_floating_layers(ctx)
		for _, item in ipairs(visible) do
			rex.session.set_layer_state({
				session_id = ctx.session_id,
				layer_id = item.layer_id,
				state = "minimized",
			})
		end
		focus_after_minimize(ctx)
	end,
})

rex.action({
	name = "maximize_all_floating",
	title = "Maximize All Floating Windows",
	category = "Pane",
	run = function(ctx)
		local minimized = collect_floating_layers(ctx)
		for i, item in ipairs(minimized) do
			rex.session.set_layer_state({
				session_id = ctx.session_id,
				layer_id = item.layer_id,
				state = "normal",
				focus = (i == #minimized),
			})
		end
		close_maximize_picker(ctx)
	end,
})

-- Tabs (Windows)
rex.bind("ctrl+a>c", "client.tab.new")
rex.bind("ctrl+a>n", "client.tab.next")
rex.bind("ctrl+a>p", "client.tab.previous")
rex.bind("ctrl+a>shift+,", "client.tab.move.backward") -- ctrl+a > <
rex.bind("ctrl+a>shift+.", "client.tab.move.forward") -- ctrl+a > >
rex.bind("ctrl+a>,", "client.tab.rename")
rex.bind("ctrl+a>shift+t", "client.tab.rename") -- ctrl+a > T
rex.bind("ctrl+a>shift+x", "client.tab.close") -- ctrl+a > X
rex.bind("ctrl+a>shift+7", "client.tab.close") -- ctrl+a > &
for i = 1, 9 do
	rex.bind("ctrl+a>" .. i, "client.tab.goto", { index = i })
end

-- Sessions
rex.bind("ctrl+a>w", "session.switch")
rex.bind("ctrl+a>g", "session.switch")
rex.bind("ctrl+a>shift+n", "session.new") -- ctrl+a > N
rex.bind("ctrl+a>shift+w", "session.rename") -- ctrl+a > W
rex.bind("ctrl+a>shift+4", "session.rename") -- ctrl+a > $
rex.bind("ctrl+a>shift+d", "session.close") -- ctrl+a > D
rex.bind("ctrl+a>]", "session.next")
rex.bind("ctrl+a>shift+0", "session.next") -- ctrl+a > )
rex.bind("ctrl+a>[", "session.previous")
rex.bind("ctrl+a>shift+9", "session.previous") -- ctrl+a > (
rex.bind("ctrl+a>u", "session.open_on_web")
rex.bind("ctrl+a>shift+s", "client.host.switch") -- ctrl+a > S

-- Nexo Project, Agent & Previous-Session Switcher

local function nexo_argv(ctx, subcmd, tab)
	local home = os.getenv("HOME") or ""
	local user = os.getenv("USER") or ""
	local nexo_bin = find_executable("nexo")
	local path_env = table.concat({
		home .. "/.local/bin",
		"/etc/profiles/per-user/" .. user .. "/bin",
		home .. "/.nix-profile/bin",
		"/run/current-system/sw/bin",
		"/opt/homebrew/bin",
		"/usr/bin",
		"/bin",
	}, ":")

	local view = rex.session.view({})
	local client_id = (ctx and ctx.client_id) or ""
	local session_id = (ctx and ctx.session_id) or (view and view.session_id) or ""
	local block_id = (ctx and ctx.block_id) or ""
	if block_id == "" and view and view.windows then
		for _, w in ipairs(view.windows) do
			if w.window_id == view.active_window_id then
				block_id = w.focused_block_id or ""
				break
			end
		end
	end

	local argv = { "/usr/bin/env" }
	if client_id ~= "" then
		argv[#argv + 1] = "REX_CLIENT=" .. tostring(client_id)
	end
	if session_id ~= "" then
		argv[#argv + 1] = "REX_SESSION=" .. tostring(session_id)
	end
	if block_id ~= "" and subcmd ~= "tui" then
		argv[#argv + 1] = "REX_BLOCK=" .. tostring(block_id)
	end
	argv[#argv + 1] = "PATH=" .. path_env
	argv[#argv + 1] = nexo_bin
	argv[#argv + 1] = "--backend=rex"
	argv[#argv + 1] = subcmd
	if tab then
		argv[#argv + 1] = tab
	end
	return argv
end

local function launch_nexo(ctx, tab)
	local view = rex.session.view({})
	if view and view.windows then
		for _, w in ipairs(view.windows) do
			if w.window_id == view.active_window_id then
				for _, layer in ipairs(w.layers or {}) do
					if layer.kind == "floating" and layer.blocks then
						for _, b in ipairs(layer.blocks) do
							if b.label == "nexo" then
								rex.session.close_layer({ layer_id = layer.layer_id })
								break
							end
						end
					end
				end
			end
		end
	end

	return rex.session.new_layer({
		bounds = { 0.1, 0.1, 0.8, 0.8 },
		focus = true,
		layout = rex.layout.block({
			flavor = "com.superlogical.terminal.shell",
			label = "nexo",
			options = {
				command = nexo_argv(ctx, "tui", tab),
				shell = "none",
			},
		}),
	})
end

rex.action({
	name = "nexo_projects",
	title = "Nexo: Open Projects Picker",
	category = "Session",
	run = function(ctx)
		return launch_nexo(ctx, "projects")
	end,
})

rex.action({
	name = "nexo_agents",
	title = "Nexo: Open Agents Picker",
	category = "Session",
	run = function(ctx)
		return launch_nexo(ctx, "agents")
	end,
})

rex.action({
	name = "nexo_previous",
	title = "Nexo: Switch to Previous Session",
	category = "Session",
	run = function(ctx)
		local r, err = rex.exec(nexo_argv(ctx, "previous", nil), { timeout = 5 })
		if not r then
			error(err, 0)
		end
		if not r.ok then
			error(r.stderr, 0)
		end
	end,
})

-- Prefix bindings (ctrl+a)
rex.bind("ctrl+a>shift+p", "nexo_projects") -- ctrl+a > P
rex.bind("ctrl+a>shift+a", "nexo_agents") -- ctrl+a > A
rex.bind("ctrl+a>b", "nexo_previous")
rex.bind("ctrl+a>backspace", "nexo_previous")

-- Native macOS GUI bindings
rex.bind("shift+cmd+k", "nexo_projects")
rex.bind("shift+cmd+a", "nexo_agents")
rex.bind("shift+cmd+l", "nexo_previous")

-- Sidebar & App UI
rex.bind("ctrl+a>shift+;", "client.palette.toggle") -- ctrl+a > :
rex.bind("ctrl+a>shift+/", "client.sidebar.filter.focus") -- ctrl+a > ?
rex.bind("ctrl+a>\\", "client.sidebar.toggle")
rex.bind("ctrl+a>a", "client.sidebar.activity.toggle")
rex.bind("cmd+escape", "client.visibility.toggle") -- single chord so it works from other apps
rex.bind("ctrl+a>shift+r", "client.config.reload") -- ctrl+a > R
rex.bind("ctrl+a>s", "client.settings")
