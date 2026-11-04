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
rex.bind("ctrl+a>shift+1", "pane.move_to_new_tab") -- ctrl+a > !
rex.bind("ctrl+a>x", "pane.close")
rex.bind("ctrl+a>z", "pane.zoom")
rex.bind("ctrl+a>0", "pane.balance")
rex.bind("ctrl+a>=", "pane.balance")

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
rex.bind("ctrl+a>shift+h", "pane.resize", { direction = "left", amount = 5 })
rex.bind("ctrl+a>shift+j", "pane.resize", { direction = "down", amount = 5 })
rex.bind("ctrl+a>shift+k", "pane.resize", { direction = "up", amount = 5 })
rex.bind("ctrl+a>shift+l", "pane.resize", { direction = "right", amount = 5 })

-- Modal Resize Mode (ctrl+a > r)
rex.mode("resize", { exclusive = true })
rex.bind("ctrl+a>r", "client.mode.enter", { name = "resize" })
rex.bind("resize/h", "pane.resize", { direction = "left", amount = 5 })
rex.bind("resize/j", "pane.resize", { direction = "down", amount = 5 })
rex.bind("resize/k", "pane.resize", { direction = "up", amount = 5 })
rex.bind("resize/l", "pane.resize", { direction = "right", amount = 5 })
rex.bind("resize/left", "pane.resize", { direction = "left", amount = 5 })
rex.bind("resize/down", "pane.resize", { direction = "down", amount = 5 })
rex.bind("resize/up", "pane.resize", { direction = "up", amount = 5 })
rex.bind("resize/right", "pane.resize", { direction = "right", amount = 5 })
rex.bind("resize/=", "pane.balance")
rex.bind("resize/0", "pane.balance")
rex.bind("resize/escape", "client.mode.exit")
rex.bind("resize/enter", "client.mode.exit")

-- Tabs (Windows)
rex.bind("ctrl+a>c", "client.tab.new")
rex.bind("ctrl+a>n", "client.tab.next")
rex.bind("ctrl+a>p", "client.tab.previous")
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

-- Sidebar & App UI
rex.bind("ctrl+a>shift+;", "client.palette.toggle") -- ctrl+a > :
rex.bind("ctrl+a>\\", "client.sidebar.toggle")
rex.bind("ctrl+a>a", "client.sidebar.activity.toggle")
rex.bind("ctrl+a>`", "client.visibility.toggle")
rex.bind("ctrl+a>shift+r", "client.config.reload") -- ctrl+a > R
rex.bind("ctrl+a>s", "client.settings")
