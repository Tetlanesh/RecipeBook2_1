-- TODO: Make custom dictionary module that allows me to build the dictionaries in the root scope

local flib_dictionary = require("__flib__.dictionary")

local search_tree = require("scripts.database.search-tree")
local util = require("scripts.util")

local function add_description(prototype)
  if not util.should_include(prototype) then
    return
  end
  local path = util.get_path(prototype)
  flib_dictionary.add(
    "description",
    path,
    { "?", prototype.factoriopedia_description, prototype.localised_description } --- @diagnostic disable-line:assign-type-mismatch
  )
end

local function rebuild()
  flib_dictionary.new("search")
  for _, group in pairs(search_tree.plain.groups) do
    for _, subgroup in pairs(group) do
      for _, prototype in pairs(subgroup) do
        local prototype_path = util.get_path(prototype)
        flib_dictionary.add("search", prototype_path, { "?", prototype.localised_name, prototype_path }) --- @diagnostic disable-line:assign-type-mismatch
      end
    end
  end

  flib_dictionary.new("description")
  for _, entity in pairs(prototypes.entity) do
    add_description(entity)
  end
  for _, equipment in pairs(prototypes.equipment) do
    add_description(equipment)
  end
  for _, fluid in pairs(prototypes.fluid) do
    add_description(fluid)
  end
  for _, item in pairs(prototypes.item) do
    add_description(item)
  end
  for _, recipe in pairs(prototypes.recipe) do
    add_description(recipe)
  end
  for _, tile in pairs(prototypes.tile) do
    add_description(tile)
  end
end

local M = {}

M.on_init = rebuild
M.on_configuration_changed = rebuild

return M
