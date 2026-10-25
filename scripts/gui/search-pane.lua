local flib_dictionary = require("__flib__.dictionary")
local flib_format = require("__flib__.format")
local flib_gui = require("__flib__.gui")
local researched = require("scripts.database.researched")
local search_tree = require("scripts.database.search-tree")
local util = require("scripts.util")

--- @param context MainGuiContext
--- @return SearchTree
local function get_search_tree(context)
  if context.search_materials_only then
    return search_tree.materials
  elseif context.grouping_mode == "all" then
    return search_tree.all
  elseif context.grouping_mode == "exclude-recipes" then
    return search_tree.separate_recipes
  else -- "none"
    return search_tree.plain
  end
end

--- @class SearchPane.Results
--- @field first_group_with_hits string
--- @field hits integer
--- @field groups table<string, SearchPane.GroupResults>

--- @class SearchPane.GroupResults
--- @field filter_hits integer
--- @field query_hits integer
--- @field results table<SpritePath, SearchPane.Result>

--- @class SearchPane.Result
--- @field group string
--- @field subgroup string
--- @field is_hidden boolean
--- @field is_researched boolean
--- @field prototype GenericPrototype
--- @field path SpritePath

--- @class SearchPane
--- @field textfield LuaGuiElement
--- @field count_label LuaGuiElement
--- @field group_buttons table<string, LuaGuiElement>
--- @field results_pane LuaGuiElement
--- @field dictionary_warning LuaGuiElement
--- @field context MainGuiContext
--- @field results SearchPane.Results?
--- @field query string
--- @field selected_group string
--- @field selected_result SpritePath?
local search_pane = {}
local mt = { __index = search_pane }
script.register_metatable("search_pane", mt)

--- @type function?
search_pane.on_result_clicked = nil

--- @param parent LuaGuiElement
--- @param context MainGuiContext
function search_pane.build(parent, context)
  -- TODO: Respect "lists everywhere" setting and make a list instead of a grid.
  local outer = parent.add({
    type = "frame",
    name = "filter_outer_frame",
    style = "inside_deep_frame",
    direction = "vertical",
    index = 1,
  })

  local subheader = outer.add({ type = "frame", style = "subheader_frame" })
  subheader.style.horizontally_stretchable = true

  local textfield = subheader.add({
    type = "textfield",
    name = "search_textfield",
    lose_focus_on_confirm = true,
    clear_and_focus_on_right_click = true,
    tooltip = { "gui.flib-search-instruction" },
    tags = flib_gui.format_handlers({ [defines.events.on_gui_text_changed] = search_pane.on_query_changed }),
  })
  textfield.add({
    type = "label",
    name = "placeholder",
    caption = { "gui.rb-search-placeholder" },
    ignored_by_interaction = true,
  }).style.font_color =
    { 0, 0, 0, 0.6 }
  subheader.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
  local count_label = subheader.add({ type = "label" })
  count_label.style.right_padding = 8

  local dictionary_warning = outer.add({
    type = "frame",
    name = "filter_warning_frame",
    style = "negative_subheader_frame",
    visible = false,
  })
  dictionary_warning.style.bottom_margin = 0
  dictionary_warning.style.horizontally_stretchable = true
  dictionary_warning.add({
    type = "label",
    style = "bold_label",
    caption = { "gui.rb-localised-search-unavailable" },
  }).style.left_margin =
    8

  local groups_table = outer.add({ type = "table", style = "rb_filter_group_button_table", column_count = 6 })

  local results_pane = outer
    .add({ type = "frame", style = "rb_filter_frame" })
    .add({ type = "frame", style = "rb_filter_deep_frame" })
    .add({ type = "scroll-pane", style = "rb_filter_scroll_pane", vertical_scroll_policy = "always" })

  local tree = get_search_tree(context)

  --- @type table<string, LuaGuiElement>
  local group_buttons = {}
  for group_name in pairs(tree.groups) do
    group_buttons[group_name] = groups_table.add({
      type = "sprite-button",
      name = group_name,
      style = "rb_filter_group_button_tab",
      sprite = "item-group/" .. group_name,
      elem_tooltip = { type = "item-group", name = group_name },
      tags = flib_gui.format_handlers({ [defines.events.on_gui_click] = search_pane.on_group_clicked }),
    })
  end

  --- @type SearchPane
  local self = {
    textfield = textfield,
    count_label = count_label,
    group_buttons = group_buttons,
    results_pane = results_pane,
    dictionary_warning = dictionary_warning,
    context = context,
    query = "",
    selected_group = next(group_buttons) --[[@as string]],
  }
  setmetatable(self, mt)
  self:update()
  return self
end

function search_pane:update_results()
  local profiler = helpers.create_profiler()

  local to_lower_func = helpers.compare_versions(helpers.game_version, "2.0.67") >= 0 and helpers.multilingual_to_lower
    or string.lower

  local show_hidden = self.context.show_hidden
  local show_unresearched = self.context.show_unresearched
  local query = to_lower_func(self.query)
  local force_index = self.context.player.force.index
  local search_strings = flib_dictionary.get(self.context.player.index, "search") or {}

  self.dictionary_warning.visible = next(search_strings) == nil

  self.textfield.placeholder.visible = #query == 0

  local tree = get_search_tree(self.context)

  --- @type SearchPane.Results
  local results = {
    first_group_with_hits = "",
    hits = 0,
    groups = {},
  }

  for group_name, group in pairs(tree.groups) do
    --- @type SearchPane.GroupResults
    local group_results = {
      filter_hits = 0,
      query_hits = 0,
      results = {},
    }
    results.groups[group_name] = group_results

    for subgroup_name, subgroup in pairs(group) do
      for _, prototype in pairs(subgroup) do
        local is_hidden = prototype.hidden or prototype.hidden_in_factoriopedia
        local is_researched = researched.is(prototype, force_index)
        local filters_match = (show_hidden or not is_hidden) and (show_unresearched or is_researched)
        if not filters_match then
          goto continue
        end

        group_results.filter_hits = group_results.filter_hits + 1

        local path = util.get_path(prototype)

        local query_match = #query == 0
        if not query_match then
          local comp = search_strings[path] or string.gsub(path, "-", " ")
          query_match = string.find(to_lower_func(comp), query, 1, true) ~= nil
        end
        if not query_match then
          goto continue
        end

        group_results.query_hits = group_results.query_hits + 1

        group_results.results[path] = {
          button = nil,
          group = group_name,
          subgroup = subgroup_name,
          is_hidden = is_hidden,
          is_researched = is_researched,
          prototype = prototype,
          path = path,
        }

        ::continue::
      end
    end

    results.hits = results.hits + group_results.query_hits
    if group_results.query_hits > 0 and results.first_group_with_hits == "" then
      results.first_group_with_hits = group_name
    end
  end

  self.results = results

  profiler.stop()
  log({ "", "Update Results ", profiler })
end

function search_pane:update_gui()
  local profiler = helpers.create_profiler()

  local results = self.results
  if not results then
    return
  end

  local selected_group = self.selected_group

  if selected_group == "" or results.groups[selected_group].query_hits == 0 then
    selected_group = results.first_group_with_hits
  end

  self.count_label.caption = { "gui.rb-count-results", flib_format.number(results.hits) }

  local group_buttons = self.group_buttons
  for group_name, group_results in pairs(results.groups) do
    local button = group_buttons[group_name]
    button.visible = group_results.filter_hits > 0
    button.enabled = group_results.query_hits > 0
    button.toggled = selected_group == group_name
    button.tooltip = { "gui.rb-count-results", flib_format.number(group_results.query_hits) }
  end

  local results_pane = self.results_pane
  results_pane.clear()

  if results.hits == 0 then
    local no_results_frame = results_pane.add({
      type = "frame",
      name = "filter_no_results_label",
      style = "negative_subheader_frame",
    })
    no_results_frame.style.horizontally_stretchable = true
    no_results_frame.add({
      type = "label",
      style = "rb_subheader_bold_label",
      caption = { "", "[img=warning-white] ", { "gui.nothing-found" } },
    })
  end

  local group_results = results.groups[selected_group]
  if not group_results then
    return
  end

  local selected_result = self.selected_result

  --- @type string?
  local current_subgroup
  --- @type LuaGuiElement?
  local current_table
  for result_path, result in pairs(group_results.results) do
    if result.subgroup ~= current_subgroup then
      current_table = results_pane.add({ type = "table", style = "slot_table", column_count = 10 })
      current_subgroup = result.subgroup
    end
    --- @cast current_table -?

    local style = "flib_slot_button_default"
    if result.is_hidden then
      style = "flib_slot_button_grey"
    elseif not result.is_researched then
      style = "flib_slot_button_red"
    end
    local result_id = util.get_id(result.prototype)
    local button = current_table.add({
      type = "sprite-button",
      style = style,
      sprite = result_path,
      elem_tooltip = result_id --[[@as ElemID]],
      tooltip = { "", { "gui.rb-control-hint" }, "\n", { "gui.rb-pipette-control-hint" } },
      toggled = result_path == selected_result,
      tags = flib_gui.format_handlers({
        [defines.events.on_gui_click] = search_pane.on_result_clicked,
      }, { rb_id = result_id }),
    })
    if result_path == selected_result then
      results_pane.scroll_to_element(button)
    end
  end

  profiler.stop()
  log({ "", "Update GUI elements ", profiler })
end

function search_pane:update()
  self:update_results()
  self:update_gui()
end

--- @param prototype GenericPrototype?
function search_pane:select_result(prototype)
  if not prototype then
    self.selected_result = nil
    return
  end
  self.selected_result = util.get_path(prototype)
  local group_name = prototype.group.name
  local tree = get_search_tree(self.context)
  if tree.groups[group_name] then
    self.selected_group = prototype.group.name
  end
  self:update_gui()
end

function search_pane:focus_search()
  self.textfield.select_all()
  self.textfield.focus()
end

--- @private
--- @param e EventData.on_gui_text_changed
function search_pane:on_query_changed(e)
  self.query = e.text
  self:update()
end

--- @private
--- @param e EventData.on_gui_text_changed
function search_pane:on_group_clicked(e)
  self.selected_group = e.element.name
  self:update_gui()
end

flib_gui.add_handlers(search_pane, function(e, handler)
  local main = storage.guis[e.player_index]
  if not main or not main.window.valid then
    return
  end
  handler(main.search_pane, e)
end, "search_pane")

return search_pane
