local flib_dictionary = require("__flib__.dictionary")

local dictionaries = require("scripts.database.dictionaries")
local researched = require("scripts.database.researched")
local gui = require("scripts.gui.main")

local by_version = {
  ["4.0.0"] = function()
    -- NUKE EVERYTHING
    global = {}
    -- Re-init
    flib_dictionary.on_init()
    dictionaries.on_init()
    researched.on_init()
    gui.on_init()
  end,
}

local migrations = {}

-- flib_migration was removed in flib 0.17; reimplemented here using helpers.compare_versions
migrations.on_configuration_changed = function(e)
  local changes = e.mod_changes and e.mod_changes[script.mod_name]
  if not changes or not changes.old_version then
    return
  end

  local versions = {}
  for version in pairs(by_version) do
    versions[#versions + 1] = version
  end
  table.sort(versions, function(a, b)
    return helpers.compare_versions(a, b) < 0
  end)

  for _, version in ipairs(versions) do
    if helpers.compare_versions(changes.old_version, version) < 0 then
      by_version[version]()
    end
  end
end

return migrations
