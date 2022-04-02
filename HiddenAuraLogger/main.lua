local addon_name, addon_table = ...
local db
local slash_cmds = {}
local event_handlers = {}
local scanner = {}
local logger = {}
local event_frame = CreateFrame("Frame")
local options_frame = CreateFrame("Frame")
local player_guid = UnitGUID("player")

addon_table.addon_version = GetAddOnMetadata(addon_name, "Version")

local default_config = {
  -- Scanning
  min_spell_id = 1,
  max_spell_id = 380000,
  max_ms_per_frame = 3,
  ignore_player_spells = false,
  ignore_player_spells_in_encounter = true,
  only_encounter_spells = false,
  scan_for_unknown_spells = true,

  -- Aura UI
  icon_size = 32,
  icons_per_row = 16,
  row_padding = 16,
  col_padding = 4,
  fade_time = 5,
  x_offset = 4,
  y_offset = 520,
}

event_frame:RegisterEvent("PLAYER_LOGIN")
event_frame:RegisterEvent("UNIT_AURA")
event_frame:RegisterEvent("ENCOUNTER_START")
event_frame:RegisterEvent("ENCOUNTER_END")
event_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
event_frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
event_frame:SetScript("OnEvent", function(self, event, ...) event_handlers[event](...) end)

local function out(...)
  print(addon_name .. ":", ...)
end

local function format_out(s, ...)
  out(format(s, ...))
end

local function table_to_string(t)
  local str = ""

  for i = 1, #t do
    if i > 1 then
      str = str .. "; "
    end
    str = str .. tostring(t[i])
  end

  return str
end

local function tables_are_equal(t1, t2)
  if #t1 ~= #t2 then
    return false
  end

  for i = 1, #t1 do
    if t1[i] ~= t2[i] then
      return false
    end
  end

  return true
end

local function handle_slash_cmd(message)
  local words = {}
  local cmd

  for word in string.gmatch(message, '%S+') do
    if cmd == nil then
      cmd = slash_cmds[word]
      if cmd == nil then
        format_out("Invalid slash command \"%s\"", word)
        return
      end
    else
      words[#words + 1] = word
    end
  end

  if cmd then
    cmd(unpack(words))
  else
    InterfaceOptionsFrame_Show()
    InterfaceOptionsFrame_OpenToCategory(addon_name)
  end
end

SLASH_HIDDENAURALOGGER1 = "/hiddenauralogger"
SLASH_HIDDENAURALOGGER2 = "/hal"
SlashCmdList["HIDDENAURALOGGER"] = function(message) handle_slash_cmd(message) end

local function toggle_aura_display()
  addon_table.display_frame:SetShown( not addon_table.display_frame:IsShown() )
  format_out("Aura Display is now %s.", addon_table.display_frame:IsShown() and "shown" or "hidden")
end
slash_cmds['ui'] = toggle_aura_display

local function toggle_log_display()
  addon_table.log_frame:SetShown(not addon_table.log_frame:IsShown())
  format_out("Log Display is now %s.", addon_table.log_frame:IsShown() and "shown" or "hidden")
end
slash_cmds['log'] = toggle_log_display
slash_cmds['logs'] = toggle_log_display

local function reset_config()
  out("Options have been reset.")
  db.config = {}

  for k, v in pairs(default_config) do
    db.config[k] = v
  end

  -- Hack to get all of the options to update their displayed values.
  if options_frame:IsShown() then
    options_frame:Hide()
    options_frame:Show()
  end
end
slash_cmds['reset'] = reset_config

local function clear_all_logs()
  db.logs = nil
  logger:init()
  scanner:run()
  out("All logs have been deleted.")
  addon_table.log_frame.update_config()
end
slash_cmds['clear'] = clear_all_logs

local function create_options()
  local y_offset = 0
  local x_offset = 16

  local function add_column()
    y_offset = 0
    x_offset = x_offset + 320
  end

  local function add_section(name)
    local label = options_frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", x_offset, y_offset - 16)
    label:SetText(name)
    y_offset = y_offset - 48
  end

  local function add_check_box(name, option, callback)
    local function reset_value(f)
      f:SetChecked(db.config[f.option])
      if callback then
        callback()
      end
    end

    local function set_value(f)
      db.config[f.option] = f:GetChecked()
      if callback then
        callback()
      end
    end

    local f = CreateFrame("CheckButton", nil, options_frame, "ChatConfigCheckButtonTemplate")
    f.option = option
    f:SetScript("OnShow", reset_value)
    f:SetScript("OnClick", set_value)
    f:SetPoint("TOPLEFT", x_offset, y_offset)
    f:SetSize(24, 24)
    f:SetMovable(false)
    reset_value(f)
    y_offset = y_offset - 24

    local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", f, "RIGHT", 4, 0)
    label:SetText(name)
  end

  -- TODO: These edit boxes should be more user friendly when entering values.
  -- Currently, you have to press enter to save the value, which is not intuitive.
  local function add_edit_box(name, option, callback)
    local function reset_value(f)
      f:SetNumber(db.config[f.option])
      f:SetCursorPosition(0)
      if callback then
        callback()
      end
    end

    local function set_value(f)
      local value = math.max(math.min(f:GetNumber(), f.option_max), f.option_min)
      db.config[f.option] = value
      f:ClearFocus()
      if callback then
        callback()
      end
    end

    local f = CreateFrame("EditBox", nil, options_frame, "InputBoxTemplate")
    f.option, f.option_min, f.option_max = unpack(option)
    f:SetScript("OnEditFocusLost", reset_value)
    f:SetScript("OnShow", reset_value)
    f:SetScript("OnEnterPressed", set_value)
    f:SetPoint("TOPLEFT", x_offset, y_offset)
    f:SetSize(64, 16)
    f:SetMovable(false)
    f:SetAutoFocus(false)
    f:SetNumeric()
    reset_value(f)
    y_offset = y_offset - 24

    local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", f, "RIGHT", 4, 0)
    label:SetText(name)
  end

  if not db.config then
    db.config = {}
  end

  for k, v in pairs(default_config) do
    if db.config[k] == nil then
      db.config[k] = v
    end
  end

  add_section("Scanning")
  add_edit_box("Minimum Spell ID", {"min_spell_id", 1, 999999})
  add_edit_box("Maximum Spell ID", {"max_spell_id", 1, 999999})
  add_edit_box("Maximum Milliseconds per Frame", {"max_ms_per_frame", 0, 30})
  -- add_check_box("Only Encounter Spells", "only_encounter_spells", scanner.update_config)
  add_check_box("Ignore Player Spells", "ignore_player_spells", scanner.update_config)
  add_check_box("Ignore Player Spells in Encounter", "ignore_player_spells_in_encounter", scanner.update_config)
  add_check_box("Scan for Unknown Spells", "scan_for_unknown_spells")

  add_column()
  add_section("Aura Display")
  add_edit_box("Icon Size", {"icon_size", 0, 512}, addon_table.display_frame.update_config)
  add_edit_box("Icons per Row", {"icons_per_row", 1, 128}, addon_table.display_frame.update_config)
  add_edit_box("Row Padding", {"row_padding", -10000, 10000}, addon_table.display_frame.update_config)
  add_edit_box("Column Padding", {"col_padding", -10000, 10000}, addon_table.display_frame.update_config)
  add_edit_box("Icon Fade Time", {"fade_time", 0, 300}, addon_table.display_frame.update_config)
  add_edit_box("X Offset", {"x_offset", -10000, 10000}, addon_table.display_frame.update_config)
  add_edit_box("Y Offset", {"y_offset", -10000, 10000}, addon_table.display_frame.update_config)

  options_frame.name = addon_name
  InterfaceOptions_AddCategory(options_frame)
end

function event_handlers.PLAYER_LOGIN()
  if not HiddenAuraLoggerDB then
    HiddenAuraLoggerDB = {}
  end

  db = HiddenAuraLoggerDB

  create_options()
  scanner:reset()
  logger:init()

  -- Start the scanner to get an initial set of auras.
  scanner:run()
end

function event_handlers.ZONE_CHANGED_NEW_AREA()
  -- Do not start start a new log if an encounter is in progress.
  if scanner.encounter_id then
    return
  end

  -- TODO: According to online documentation, the zone may not have updated yet when this event fires.
  logger:init()
end

function event_handlers.UNIT_AURA(unit)
  if unit ~= "player" then
    return
  end

  -- Start the scanner to search for any hidden auras that have changed.
  scanner:run()
end

function event_handlers.COMBAT_LOG_EVENT_UNFILTERED()
  local _, event, _, _, _, _, _, dest_guid, _, _, _, spell_id = CombatLogGetCurrentEventInfo()

  if dest_guid == player_guid and event:sub(1, 10) == "SPELL_AURA" and not scanner.cleu_auras[spell_id] then
    -- If there was a combat log event for this aura, this addon will begin to ignore it.
    scanner.cleu_auras[spell_id] = true
    if addon_table.active_auras[spell_id] then
      addon_table.active_auras[spell_id] = nil
      addon_table.display_frame:remove_aura(spell_id)
    end
  end
end

function event_handlers.ENCOUNTER_START(encounter_id, encounter_name, difficulty_id, group_size)
  logger:init({
    id = encounter_id,
    name = encounter_name,
    difficulty_id = difficulty_id,
    group_size = group_size,
  })

  scanner.encounter_id = encounter_id
  scanner.encounter_auras = {}

  if addon_table.encounter_spells[encounter_id] then
    for spell_id, _ in pairs(addon_table.encounter_spells[encounter_id]) do
      scanner.encounter_auras[#scanner.encounter_auras + 1] = spell_id
    end
  end

  scanner:run()
end

function event_handlers.ENCOUNTER_END()
  logger:init()
  scanner.encounter_id = nil
  scanner.encounter_auras = {}
end

function logger:init(encounter)
  local c = C_DateAndTime.GetCurrentCalendarTime()

  if not db.logs then
    db.logs = {}
  end

  local player_name, _ = UnitName("player")
  db.logs[#db.logs + 1] = {
    server_timestamp = format("%d-%02d-%02d %02d:%02d", c.year, c.month, c.monthDay, c.hour, c.minute),
    time = GetTime(),
    events = {},
    wow_version = format("%s.%s", GetBuildInfo()),
    zone = GetZoneText() or "Unknown Zone",
    player_name = player_name,
  }

  if encounter then
    db.logs[#db.logs].encounter = encounter
  end

  self.log = db.logs[#db.logs]
end

function logger:write(str)
  self.log.events[#self.log.events + 1] = format("%.3f; %s", GetTime() - self.log.time, str)
end

function logger:found_aura(spell_id, name)
  if not self.log.found_auras then
    self.log.found_auras = {}
  end

  self.log.found_auras[spell_id] = name
end

function scanner:reset()
  self.spell_id = db.config.min_spell_id
  self.known_index = 0
  self.encounter_index = 0
  self.known_aura_lookup = {}
  self.known_auras = {}
  self.encounter_auras = {}
  self.encounter_id = nil
  self.cleu_auras = {}
  addon_table.active_auras = {}
  self:stop()
end

function scanner:run()
  self.spell_id_finish = 0
  self.known_index_finish = 0
  self.encounter_index_finish = 0

  if self.known_index == 0 then
    self.known_index = #self.known_auras
  end

  if self.encounter_index == 0 then
    self.encounter_index = #self.encounter_auras
  end

  -- this is for throttling how quickly events are scanned
  event_frame:SetScript("OnUpdate", function() self:scan() end)
end

function scanner:stop()
  event_frame:SetScript("OnUpdate", nil)
end

function scanner:check_aura(spell_id)
  -- Skip auras that appear in combat log events. The goal of this
  -- addon is to collect data for any auras that do not appear in
  -- combat logs. There may be some hidden auras that do appear in
  -- the combat log and there may be some visible auras that do not
  -- appear in the combat log.
  if self.cleu_auras[spell_id] then
    return
  end

  if (db.config.ignore_player_spells or db.config.ignore_player_spells_in_encounter and self.encounter_id) and addon_table:is_player_spell(spell_id) then
    return
  end

  if db.config.only_encounter_spells and not addon_table:is_encounter_spell(self.encounter_id, spell_id) then
    return
  end

  local values = {GetPlayerAuraBySpellID(spell_id)}

  -- If GetPlayerAuraBySpellID returned something, then this aura is active.
  if #values > 0 then
    -- If the aura was not already active, it was either just applied or we are detecting it for the first time here.
    if not addon_table.active_auras[spell_id] then
      addon_table.active_auras[spell_id] = values
      addon_table.display_frame:update_aura(spell_id)
      logger:write(format("%s; %s", self.known_aura_lookup[spell_id] and "HIDDEN_AURA_APPLIED" or "HIDDEN_AURA_FOUND", table_to_string(values)))
      if not self.known_aura_lookup[spell_id] then
        logger:found_aura(spell_id, values[1])
        self.known_aura_lookup[spell_id] = true
        self.known_auras[#self.known_auras + 1] = spell_id
      end
    -- If the aura was active, check if anything about it changed (i.e., was the aura refreshed?).
    elseif not tables_are_equal(addon_table.active_auras[spell_id], values) then
      addon_table.active_auras[spell_id] = values
      addon_table.display_frame:update_aura(spell_id)
      logger:write(format("HIDDEN_AURA_UPDATED; %s", table_to_string(values)))
    end
  -- If the aura was active, then it just faded from the player.
  elseif addon_table.active_auras[spell_id] then
    logger:write(format("HIDDEN_AURA_REMOVED; %s; %d", addon_table.active_auras[spell_id][1], spell_id))
    addon_table.active_auras[spell_id] = nil
    addon_table.display_frame:update_aura(spell_id)
  end
end

function scanner:increment(key, finish, min, max)
  if self[finish] == 0 then
    self[finish] = self[key]
  end

  self[key] = (self[key] - min + 1) % (max + 1 - min) + min
end

function scanner:out_of_time()
  -- Only continue if debugprofilestop() is in [self.start_time, self.stop_time).
  -- Otherwise, either all allotted time was used or someone ran debugprofilestart(),
  -- in which case we exit early because it is no longer easy to know how much time was used.
  local t = debugprofilestop()
  return t >= self.stop_time or t < self.start_time
end

function scanner:check_range(key, finish, min, max, spell_table, ignore_func)
  if max < min then
    return
  end

  while self[key] ~= self[finish] and not self:out_of_time() do
    local spell_id = spell_table and spell_table[self[key]] or self[key]

    if not ignore_func or not ignore_func(spell_id) then
      self:check_aura(spell_id)
    end

    self:increment(key, finish, min, max)
  end
end

function scanner:scan()
  -- Because we are interested in checking potentially hundreds of thousands
  -- of possible auras each time a UNIT_AURA event fires, we need to throttle
  -- the number of auras that can be checked each frame to limit CPU usage.
  self.start_time = debugprofilestop()
  self.stop_time = self.start_time + db.config.max_ms_per_frame

  -- First, check auras that have been detected on the player before. This ensures
  -- that the log is very responsive when reporting changes about these auras.
  self:check_range("known_index", "known_index_finish", 1, #self.known_auras, self.known_auras)

  -- Next, check encounter spells if given for the active encounter.
  self:check_range("encounter_index", "encounter_index_finish", 1, #self.encounter_auras, self.encounter_auras,
    -- ignore_func to skip spells that were checked above in self.known_auras
    function(s) return self.known_aura_lookup[s] end)

  if db.config.scan_for_unknown_spells then
    -- Check all other auras in range for new hidden auras.
    self:check_range("spell_id", "spell_id_finish", db.config.min_spell_id, db.config.max_spell_id, nil,
      -- ignore_func to skip spells that were checked above in self.known_auras and self.encounter_auras
      function(s) return self.known_aura_lookup[self.spell_id] or addon_table:is_encounter_spell(self.encounter_id, self.spell_id) end)

    -- Stop after a full loop through all spells with no new UNIT_AURA events.
    if self.spell_id == self.spell_id_finish then
      self:stop()
    end
  else
    -- If we are not looking for unknown spells, stop after all known and encounter spells have been checked.
    if self.known_index == self.known_index_finish and self.encounter_index == self.encounter_index_finish then
      self:stop()
    end
  end
end

function scanner.update_config()
  if not addon_table.active_auras then
    return
  end

  if not db then
    db = HiddenAuraLoggerDB
  end

  for spell_id, _ in pairs(addon_table.active_auras) do
    if (db.config.ignore_player_spells or db.config.ignore_player_spells_in_encounter and scanner.encounter_id) and addon_table:is_player_spell(spell_id) then
      addon_table.active_auras[spell_id] = nil
      addon_table.display_frame:remove_aura(spell_id)
    end

    if db.config.only_encounter_spells and not addon_table:is_encounter_spell(scanner.encounter_id, spell_id) then
      addon_table.active_auras[spell_id] = nil
      addon_table.display_frame:remove_aura(spell_id)
    end
  end

  -- Start the scanner to search for any hidden auras that have changed.
  scanner:run()
end
