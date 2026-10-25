--- @type event_handler
local hotkey_warning_handler = {}

function hotkey_warning_handler.on_configuration_changed()
  -- Destroy any remaining hotkey warning windows.
  for _, player in pairs(game.players) do
    local hotkey_warning_window = player.gui.screen.rb_hotkey_warning_window
    if hotkey_warning_window then
      hotkey_warning_window.destroy()
    end
  end
end

return hotkey_warning_handler
