local flib_bounding_box = require("__flib__.bounding-box")
local flib_format = require("__flib__.format")
local flib_math = require("__flib__.math")

--- @class Util
local util = {}

util.crafting_machine = {
  ["assembling-machine"] = true,
  ["character"] = true,
  ["furnace"] = true,
  ["rocket-silo"] = true,
}

--- @param player LuaPlayer
--- @param text LocalisedString
function util.flying_text(player, text)
  player.create_local_flying_text({
    text = text,
    create_at_cursor = true,
  })
  player.play_sound({ path = "utility/cannot_build" })
end

--- @param num number
--- @return string
function util.format_number(num)
  return flib_format.number(flib_math.round(num, 0.01))
end

function util.get_natural_entities()
  return prototypes.get_entity_filtered({
    --- @diagnostic disable-next-line unused-fields
    { filter = "type", type = "resource" },
    --- @diagnostic disable-next-line unused-fields
    { filter = "type", type = "fish" },
    --- @diagnostic disable-next-line unused-fields
    { filter = "type", type = "tree" },
    --- @diagnostic disable-next-line unused-fields
    { filter = "type", type = "simple-entity" },
  })
end

--- @param prototype GenericPrototype
--- @return string path
--- @return string type
function util.get_path(prototype)
  local type = util.object_name_to_type[prototype.object_name]
  return type .. "/" .. prototype.name, type
end

--- @param obj DatabaseID
--- @return GenericPrototype
function util.get_prototype(obj)
  return prototypes[obj.type][obj.name]
end

--- @param prototype GenericPrototype
--- @return DatabaseID
function util.get_id(prototype)
  local type = util.object_name_to_type[prototype.object_name]
  return { type = type, name = prototype.name }
end

util.object_name_to_type = {
  LuaEntity = "entity",
  LuaEntityPrototype = "entity",
  LuaEquipmentPrototype = "equipment",
  LuaFluidPrototype = "fluid",
  LuaItemPrototype = "item",
  LuaRecipePrototype = "recipe",
  LuaRecipe = "recipe",
  LuaTechnologyPrototype = "technology",
  LuaTechnology = "technology",
  LuaTilePrototype = "tile",
}

util.show_hidden_enabled = settings.startup["rb-enable-show-hidden"].value --[[@as boolean]]

--- @param prototype GenericPrototype
function util.should_include(prototype)
  return util.show_hidden_enabled or (not prototype.hidden and not prototype.hidden_in_factoriopedia)
end

--- @return DatabaseID[]
function util.unique_id_array()
  local hash = {}

  return setmetatable({}, {
    --- @param self DatabaseID[]
    --- @param index integer
    --- @param value DatabaseID
    __newindex = function(self, index, value)
      if not value then
        return
      end
      local key = value.type .. "/" .. value.name
      if hash[key] then
        return
      end
      hash[key] = true
      rawset(self, index, value)
    end,
  })
end

--- @param prototype GenericPrototype
--- @return LuaItemGroup
function util.get_group(prototype)
  if prototype.object_name == "LuaEquipmentPrototype" then
    return prototypes.item_group["combat"]
  end
  return prototype.group
end

--- @param prototype GenericPrototype
--- @return LuaItemSubGroup
function util.get_subgroup(prototype)
  if prototype.object_name == "LuaEquipmentPrototype" then
    return prototypes.item_subgroup["rb-uncategorized-equipment"]
  end
  return prototype.subgroup
end

--- @param player LuaPlayer
--- @param entity LuaEntityPrototype
--- @param recipe LuaRecipePrototype
function util.create_blueprint(player, entity, recipe)
  local cursor_stack = player.cursor_stack
  if not cursor_stack then
    return
  end

  if not player.clear_cursor() then
    return
  end

  -- Other mods could have done wacky things to the cursor stack
  if not cursor_stack or not cursor_stack.valid then
    return
  end

  local collision_box = entity.collision_box
  local height = flib_bounding_box.height(collision_box)
  local width = flib_bounding_box.width(collision_box)

  cursor_stack.set_stack({ name = "blueprint", count = 1 })
  cursor_stack.set_blueprint_entities({
    {
      entity_number = 1,
      name = entity.name,
      position = {
        -- Entities with an even number of tiles to a side need to be set at -0.5 instead of 0
        math.ceil(width) % 2 == 0 and -0.5 or 0,
        math.ceil(height) % 2 == 0 and -0.5 or 0,
      },
      recipe = recipe.name,
    },
  })

  player.add_to_clipboard(cursor_stack)
  player.activate_paste()
end

return util
