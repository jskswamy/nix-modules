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
rex.bind("ctrl+a>f", "pane.float")
rex.bind("ctrl+a>m", "pane.minimize_floating")
rex.bind("ctrl+a>shift+m", "pane.minimize_all_floating") -- ctrl+a > M
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

-- Context-aware resize, move & balance: adjusts floating window bounds when a
-- floating pane is focused, and delegates to split resize/move/balance when tiled.
local function focused_floating_layer(ctx)
	local view = rex.session.view({})
	if not view or not view.windows then
		return nil
	end
	local block_id = ctx.block_id
	if not block_id then
		for _, w in ipairs(view.windows) do
			if w.window_id == view.active_window_id then
				block_id = w.focused_block_id
				break
			end
		end
	end
	if not block_id then
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

-- Modal Resize Mode (ctrl+a > r)
rex.mode("resize", { exclusive = true })
rex.bind("ctrl+a>r", "client.mode.enter", { name = "resize" })
rex.bind("resize/h", "pane_or_float_resize", { direction = "left", amount = 5 })
rex.bind("resize/j", "pane_or_float_resize", { direction = "down", amount = 5 })
rex.bind("resize/k", "pane_or_float_resize", { direction = "up", amount = 5 })
rex.bind("resize/l", "pane_or_float_resize", { direction = "right", amount = 5 })
rex.bind("resize/left", "pane_or_float_resize", { direction = "left", amount = 5 })
rex.bind("resize/down", "pane_or_float_resize", { direction = "down", amount = 5 })
rex.bind("resize/up", "pane_or_float_resize", { direction = "up", amount = 5 })
rex.bind("resize/right", "pane_or_float_resize", { direction = "right", amount = 5 })
rex.bind("resize/shift+h", "pane_or_float_move", { direction = "left", amount = 5 })
rex.bind("resize/shift+j", "pane_or_float_move", { direction = "down", amount = 5 })
rex.bind("resize/shift+k", "pane_or_float_move", { direction = "up", amount = 5 })
rex.bind("resize/shift+l", "pane_or_float_move", { direction = "right", amount = 5 })
rex.bind("resize/=", "pane_or_float_balance")
rex.bind("resize/0", "pane_or_float_balance")
rex.bind("resize/z", "pane.zoom")
rex.bind("resize/escape", "client.mode.exit")
rex.bind("resize/enter", "client.mode.exit")

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

-- Sidebar & App UI
rex.bind("ctrl+a>shift+;", "client.palette.toggle") -- ctrl+a > :
rex.bind("ctrl+a>shift+/", "client.sidebar.filter.focus") -- ctrl+a > ?
rex.bind("ctrl+a>\\", "client.sidebar.toggle")
rex.bind("ctrl+a>a", "client.sidebar.activity.toggle")
rex.bind("ctrl+a>`", "client.visibility.toggle")
rex.bind("ctrl+a>shift+r", "client.config.reload") -- ctrl+a > R
rex.bind("ctrl+a>s", "client.settings")
