local main_gui = require("scripts.gui.main")

local allowed_types = {
  LuaEntityPrototype = true,
  LuaEquipmentPrototype = true,
  LuaFluidPrototype = true,
  LuaItemPrototype = true,
  LuaRecipePrototype = true,
  LuaTilePrototype = true,
}

local remote_interface = {}

--- Open the given page in Recipe Book.
--- @param player_index uint
--- @param prototype LuaEntityPrototype|LuaEquipmentPrototype|LuaFluidPrototype|LuaItemPrototype|LuaRecipePrototype|LuaTilePrototype
--- @return boolean success
function remote_interface.open_page(player_index, prototype)
  if not player_index then
    error("Recipe Book remote interface was not passed a player_index.")
  end
  if type(player_index) ~= "number" then
    error("Recipe Book remote interface was passed an invalid player index.")
  end
  if not prototype then
    error("Recipe Book remote interface was not passed a prototype.")
  end
  if not prototype.valid then
    error("Recipe Book remote interface was passed an invalid prototype object.")
  end
  if not allowed_types[prototype.object_name] then
    error("Recipe Book remote interface was passed an invalid prototype type.")
  end
  local player_gui = main_gui.get_or_create(player_index)
  if player_gui then
    player_gui:show_page(prototype)
  end
  return true
end

--- Returns the current remote interface version.
--- Mods should check against this version before calling `open_page` and abort if the version is incorrect.
--- @return uint
function remote_interface.version()
  return 5
end

remote.add_interface("RecipeBook", remote_interface)
