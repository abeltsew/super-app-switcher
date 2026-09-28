-- Super+Tab replaces Omarchy's next/previous workspace shortcuts.
-- Load with dofile from ~/.config/hypr/bindings.lua; remove that line to undo.
local summon = "omarchy-shell shell summon abeltsew.super-app-switch "
local ipc = "omarchy-shell super-app-switch "
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + TAB", "Next app preview", summon .. "'{}'")
o.bind("SUPER + SHIFT + TAB", "Previous app preview", summon .. "'{\"direction\":\"previous\"}'")
for _, key in ipairs({ "Super_L", "Super_R" }) do
  o.bind("SUPER + " .. key, nil, ipc .. "accept", { release = true })
end
-- Isolate Super+click from the normal window-drag binding.
hl.define_submap("super-app-switch", function()
  o.bind("SUPER + TAB", "Next preview", ipc .. "next")
  o.bind("SUPER + SHIFT + TAB", "Previous preview", ipc .. "previous")
  -- W is handled by the focused QML overlay (auto-repeat is ignored).
  for _, key in ipairs({ "Super_L", "Super_R" }) do
    o.bind("SUPER + " .. key, nil, ipc .. "accept", { release = true })
  end
  for _, key in ipairs({ "ESCAPE", "SUPER + ESCAPE" }) do
    hl.bind(key, function()
      hl.dispatch(hl.dsp.submap("reset"))
      hl.exec_cmd(ipc .. "cancel")
    end)
  end
end)
