local addon_name, addon_table = ...
local db

local key_order = {
  timestamp = 0,
  event = 1,
  spellId = 2,
  name = 3,
}

local function dict_to_string(t)
  local function compare_keys(a, b)
    if key_order[a] and key_order[b] then
      return key_order[a] < key_order[b]
    elseif key_order[a] then
      return true
    elseif key_order[b] then
      return false
    else
      return a < b
    end
  end

  local function value_string(key, value)
    if type(value) == "table" then
      local str = ""
      for k, v in pairs(value) do
        if str ~= "" then
          str = str .. "; "
        end
        str = str .. value_string(key .. "[" .. k .. "]" , v)
      end
      return str
    else
      return tostring(key) .. "=" .. tostring(value)
    end
  end

  local str = ""
  local keys = {}
  for k, _ in pairs(t) do
    keys[#keys + 1] = k
  end
  sort(keys, compare_keys)

  for _, k in ipairs(keys) do
    local v = value_string(k, t[k])
    if v ~= "" then
      if str ~= "" then
        str = str .. "; "
      end
      str = str .. v
    end
  end

  return str
end

local function get_cursor_pos()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  return x / scale, y / scale
end

local function create_button_textures(button, colors)
  if colors == nil then
    colors = {
      SetNormalTexture = {0.2, 0.4, 0.8, 0.8},
      SetHighlightTexture = {0.4, 0.6, 1.0, 0.8},
    }
  end

  for f, c in pairs(colors) do
    if button[f] then
      local t = button:CreateTexture(nil, "BACKGROUND")
      t:SetAllPoints()
      t:SetColorTexture(unpack(c))
      button[f](button, t)
    end
  end
end

local function create_exit_button(parent, size, target)
  if not target then
    target = parent
  end

  local exit = CreateFrame("Button", nil, parent)
  exit:SetPoint("TOPRIGHT")
  exit:SetSize(size, size)
  local colors = {
    SetNormalTexture = {0.8, 0.2, 0.2, 0.8},
    SetHighlightTexture = {1.0, 0.4, 0.4, 0.8},
  }
  create_button_textures(exit, colors)

  local l1 = exit:CreateLine(nil, "ARTWORK")
  l1:SetColorTexture(0.8, 0.8, 0.8, 1)
  local l2 = exit:CreateLine(nil, "ARTWORK")
  l2:SetColorTexture(0.8, 0.8, 0.8, 1)

  local function set_symbol_offset(pushed)
    local x, y = 0, 0
    if pushed then
      x, y = 1, -1
    end
    l1:SetStartPoint("TOPLEFT", 8 + x, -8 + y)
    l1:SetEndPoint("BOTTOMRIGHT", -8 + x, 8 + y)
    l2:SetStartPoint("TOPRIGHT", -8 + x, -8 + y)
    l2:SetEndPoint("BOTTOMLEFT", 8 + x, 8 + y)
  end

  exit:SetScript("OnShow", function() set_symbol_offset(false) end)
  exit:SetScript("OnMouseDown", function() set_symbol_offset(true) end)
  exit:SetScript("OnMouseUp", function() set_symbol_offset(false) end)
  exit:SetScript("OnClick", function() target:Hide() end)

  return exit
end

local export = CreateFrame("Frame", nil, UIParent)
export:SetFrameStrata("TOOLTIP")
export:SetSize(800, 600)
export:SetPoint("CENTER")
export.texture = export:CreateTexture(nil, "BACKGROUND")
export.texture:SetAllPoints()
export.texture:SetColorTexture(0.0, 0.0, 0.0, 0.8)
export:EnableMouse(true)
export:Hide()

local export_exit = create_exit_button(export, 32)

local export_box = CreateFrame("EditBox", nil, export)
export_box:SetFontObject("GameFontHighlight")
export_box:SetMultiLine(true)
export_box:SetWidth(600)
export_box:SetScript("OnEscapePressed", function() export:Hide() end)
export_box:SetScript("OnHide", function() export_box:SetText("") end)
export_box:SetScript("OnChar", function() export_box:SetText(export.text) export_box:HighlightText() end)
export_box:SetScript("OnMouseUp", function() export_box:HighlightText() end)

local export_scroll = CreateFrame("ScrollFrame", nil, export)
export_scroll:SetPoint("BOTTOMLEFT")
export_scroll:SetPoint("TOPRIGHT", export_exit, "TOPLEFT")
export_scroll:SetScrollChild(export_box)

addon_table.log_frame = CreateFrame("Frame", nil, UIParent)
local lf = addon_table.log_frame
lf:SetFrameStrata("FULLSCREEN_DIALOG")
lf:SetPoint("CENTER")
lf:Hide()

local top = CreateFrame("Frame", nil, lf)
top:SetPoint("TOPLEFT")
top:SetPoint("TOPRIGHT")
top:SetHeight(64)
top.texture = top:CreateTexture(nil, "BACKGROUND")
top.texture:SetAllPoints()
top.texture:SetColorTexture(0.2, 0.2, 0.2, 0.8)
top.title = top:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
top.title:SetPoint("TOPLEFT", 8, -8)
top.timestamp = top:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
top.timestamp:SetPoint("TOPLEFT", top.title, "BOTTOMLEFT", 0, -8)
top.drag_frame = lf
local exit = create_exit_button(top, 32, lf)

local function drag_window(f)
  local x, y = get_cursor_pos()
  x = x - f.initial_drag_x
  y = y - f.initial_drag_y
  f.drag_frame:SetPoint("CENTER", x, y)
end

top:SetScript("OnMouseDown", function(self)
  local x, y = get_cursor_pos()
  local _, _, _, x0, y0 = self:GetParent():GetPoint()
  self.initial_drag_y = y - y0
  self.initial_drag_x = x - x0
  self:SetScript("OnUpdate", drag_window)
end)

top:SetScript("OnMouseUp", function(self)
  self:SetScript("OnUpdate", nil)
end)

local footer = CreateFrame("Frame", nil, lf)
footer:SetPoint("BOTTOMLEFT")
footer:SetPoint("BOTTOMRIGHT")
footer:SetHeight(24)
footer.texture = footer:CreateTexture(nil, "BACKGROUND")
footer.texture:SetAllPoints()
footer.texture:SetColorTexture(0.2, 0.2, 0.2, 0.8)
footer.version = footer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
footer.version:SetPoint("LEFT", 8, 0)
footer.version:SetText(format("%s v%s", addon_name, GetAddOnMetadata(addon_name, "Version")))

local function get_log_text(log)
  if not log or not log.events or #log.events == 0 then
    return
  end

  local text = "# Log Information\n"
  text = text .. "server_timestamp; time; wow_version; addon_version; player_name; zone; encounter_name; encounter_id; difficulty_id; group_size\n"
  text = text .. format("%s; %s; %s; %s; %s; %s; ", log.server_timestamp, log.time, log.wow_version or "Unknown Build", addon_table.addon_version or "Unknown Version", log.player_name or "Unknown Player", log.zone or "Unknown Zone")
  if log.encounter then
    text = text .. format("%s; %s; %s; %s\n", log.encounter.name, log.encounter.id, log.encounter.difficulty_id, log.encounter.group_size)
  else
    text = text .. "None; None; None; None\n"
  end

  if log.found_auras then
    local found = {}
    for spell_id, name in pairs(log.found_auras) do
      found[#found + 1] = spell_id
    end
    sort(found)
    if #found > 0 then
      text = text .. "\n# Hidden Auras Found\n"
      text = text .. "spell_name; spell_id\n"
      for _, spell_id in ipairs(found) do
        text = text .. format("%s; %d\n", log.found_auras[spell_id], spell_id)
      end
    end
  end

  text = text .. "\n# Hidden Aura Events\n"
  -- text = text .. "timestamp; event; spellId; name; icon; count; dispelType; duration; expirationTime; source; isStealable; nameplateShowPersonal; spellId; canApplyAura; isBossDebuff; castByPlayer; nameplateShowAll; timeMod; ...\n"
  for _, event in ipairs(log.events) do
    text = text .. dict_to_string(event) .. "\n"
  end

  return text
end

local function export_single_log()
  local text = get_log_text(lf.log)

  if text then
    export.text = text
    export:Show()
    export_box:SetText(export.text)
    export_box:HighlightText()
    export_box:SetFocus()
  end
end

local function export_related_logs()
  local current_log = lf.log
  if not current_log then
    return
  end

  local text
  for i, log in ipairs(db.logs) do
    local version_match = current_log.wow_version == log.wow_version
    local encounter_match = current_log.encounter and log.encounter and current_log.encounter.id == log.encounter.id
    if version_match and encounter_match then
      if not text then
        text = get_log_text(log)
      else
        local t = get_log_text(log)
        if t then
          text = text .. "\n" .. t
        end
      end
    end
  end

  if text then
    export.text = text
    export:Show()
    export_box:SetText(export.text)
    export_box:HighlightText()
    export_box:SetFocus()
  else
    export_single_log()
  end
end

local function create_text_button(text, callback)
  local button = CreateFrame("Button", nil, top)
  button:SetSize(128, top:GetHeight() - 16)
  create_button_textures(button)
  local font_string = button:CreateFontString(nil, "ARTWORK")
  font_string:SetFont("fonts/frizqt__.ttf", 14)
  font_string:SetPoint("CENTER")
  button:SetFontString(font_string)
  button:SetText(text)
  button:SetScript("OnClick", callback)
  return button
end

local single_export = create_text_button("Export Single", export_single_log)
single_export:SetPoint("TOPRIGHT", -40, -8)

local multi_export = create_text_button("Export Matching", export_related_logs)
multi_export:SetPoint("RIGHT", single_export, "LEFT", -8, 0)

local function set_line(frame, current)
  local rows, lines = frame.rows, frame.lines
  local first = 1
  local last = max(2, #lines - #rows + 1)
  frame.current = max(first, min(last, current))
  frame.progress = (frame.current - 1) / (last - 1)
  frame.slider:set_progress(frame.progress)
  for i, row in ipairs(rows) do
    local li = frame.current + i - 1
    local line = lines[li]
    if line then
      row:set_text(line.text)
      local c = (li % 2 + 1) * 0.3
      row.texture:SetColorTexture(c, c, c, 0.5)
      row.index = line.index
      if line.spell_id then
        row:set_spell(line.spell_id)
      else
        row:set_spell(nil)
      end
      row:Show()
    else
      row:Hide()
    end
  end
end

local function update_progress(frame, progress)
  local rows, lines = frame.rows, frame.lines
  local first = 1
  local last = max(1, #lines - #rows + 1)
  local current = first + floor(progress * (last - 1))
  frame:set_line(current)
end

local function scroll(frame, delta)
  local rows, lines = frame.rows, frame.lines
  local first = 1
  local last = max(1, #lines - #rows + 1)
  local current = max(first, min(last, frame.current - delta))
  frame:set_line(current)
end

local function set_row_text(row, text)
  if row.label then
    row.label:SetText(text)
  elseif row.fields and #row.fields > 0 then
    if type(text) == "table" then
      for i, t in ipairs(text) do
        if row.fields[i] then
          row.fields[i]:SetText(t)
        end
      end
    else
      row.fields[1]:SetText(text)
    end
  end
end

local function set_row_spell(row, spell_id)
  if spell_id then
    row:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:SetSpellByID(spell_id)
      GameTooltip:Show()
      self.show_tooltip = true
    end)
    row:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
      self.show_tooltip = false
    end)
  else
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    if row.show_tooltip then
      GameTooltip:Hide()
    end
  end
end

local function create_row(parent, prev, type, field_structure, header)
  local row = CreateFrame(type, nil, parent)
  local width
  row.set_text = set_row_text
  row.set_spell = set_row_spell
  row:SetHeight(24)
  if prev then
    row:SetPoint("TOP", prev, "BOTTOM")
  else
    row:SetPoint("TOP")
  end
  row:SetPoint("LEFT")
  if not parent.scrollbar or header then
    row:SetPoint("RIGHT")
  else
    row:SetPoint("RIGHT", parent.scrollbar, "LEFT")
  end
  row.texture = row:CreateTexture(nil, "BACKGROUND")
  row.texture:SetAllPoints()
  if not field_structure or not field_structure.fields then
    row.label = row:CreateFontString(nil, "ARTWORK", header and "GameFontNormalLeft" or "GameFontHighlightLeft")
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetPoint("RIGHT", -8, 0)
    row.label:SetWordWrap(false)
  else
    row.fields = {}
    local prev
    local margin = field_structure.margin or 0
    for _, f in ipairs(field_structure.fields) do
      _, w = unpack(f)
      local label = row:CreateFontString(nil, "ARTWORK", header and "GameFontNormalLeft" or "GameFontHighlightLeft")
      label:SetWordWrap(false)
      if not prev then
        label:SetPoint("LEFT", margin, 0)
      else
        label:SetPoint("LEFT", prev, "RIGHT", margin, 0)
      end
      if w then
        label:SetWidth(w - 16)
        if width == nil then
          width = margin
        end
        width = width + label:GetWidth() + margin
      else
        label:SetPoint("RIGHT", -8, 0)
      end
      prev = label
      row.fields[#row.fields + 1] = label
    end
  end
  if not header then
    parent.rows[#parent.rows + 1] = row
  end
  return row, width
end

local function set_slider_progress(s, progress)
  progress = min(1, max(0, progress))
  local bottom = s:GetHeight() - s:GetParent():GetHeight()
  local offset = progress * bottom
  s:SetPoint("TOP", 0, offset)
end

local function slider_update(s)
  local bottom = s:GetHeight() - s:GetParent():GetHeight()
  local _, y = get_cursor_pos()
  y = y - s.initial
  local offset = min(0, max(bottom, y))
  s.list:update_progress(offset / bottom)
end

local function create_list(rows, row_type, field_structure)
  local list = CreateFrame("Frame", nil, lf)
  local width, height = nil, 0
  list.texture = list:CreateTexture(nil, "BACKGROUND")
  list.texture:SetAllPoints()
  list.texture:SetColorTexture(0.5, 0.5, 0.5, 0.8)
  list.lines = {}
  list.rows = {}
  list.update_progress = update_progress
  list.set_line = set_line

  if field_structure and field_structure.fields then
    list.header, width = create_row(list, nil, "FRAME", field_structure, true)
    local names = {}
    for _, f in ipairs(field_structure.fields) do
      names[#names + 1] = f[1]
    end
    list.header:set_text(names)
    list.header.texture:SetColorTexture(0.0, 0.0, 0.0, 0.5)
    height = height + list.header:GetHeight()
  end

  local scrollbar = CreateFrame("Frame", nil, list)
  if not list.header then
    scrollbar:SetPoint("TOPRIGHT")
  else
    scrollbar:SetPoint("TOPRIGHT", list.header, "BOTTOMRIGHT")
  end
  scrollbar:SetPoint("BOTTOMRIGHT")
  scrollbar:SetWidth(16)
  scrollbar.texture = scrollbar:CreateTexture(nil, "BACKGROUND")
  scrollbar.texture:SetAllPoints()
  scrollbar.texture:SetColorTexture(0.1, 0.1, 0.1, 0.8)
  list.scrollbar = scrollbar

  local slider = CreateFrame("Frame", nil, scrollbar)
  slider:SetPoint("TOP")
  slider:SetPoint("LEFT")
  slider:SetPoint("RIGHT")
  slider:SetHeight(32)
  slider.texture = slider:CreateTexture(nil, "BACKGROUND")
  slider.texture:SetAllPoints()
  slider.texture:SetColorTexture(0.7, 0.7, 0.7, 0.8)
  slider.set_progress = set_slider_progress
  slider.list = list
  list.slider = slider

  slider:SetScript("OnMouseDown", function(self)
    local _, y = get_cursor_pos()
    local _, _, _, _, y0 = self:GetPoint()
    self.initial = y - y0
    self:SetScript("OnUpdate", slider_update)
  end)

  slider:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  list:SetScript("OnMouseWheel", scroll)

  local prev = list.header
  for i = 1, rows do
    prev, width = create_row(list, prev, row_type, field_structure)
    height = height + prev:GetHeight()
  end

  if width then
    width = width + scrollbar:GetWidth()
  end

  return list, width, height
end

local event_field_structure = {
  margin = 8,
  fields = {
    {"Timestamp",   85},
    {"Event",      190},
    {"Spell Name", 280},
    {"Spell ID",    70},
    {"Stack",       55},
    {"Duration",   100},
  },
}

local list_field_structure = {
  margin = 8,
  fields = {
    {"Event Logs"}
  },
}

local log_event_box, box_width, box_height = create_list(23, "FRAME", event_field_structure)
log_event_box:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
log_event_box:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT")
log_event_box:SetWidth(box_width)

local log_list = create_list(23, "BUTTON", list_field_structure)
log_list:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
log_list:SetPoint("BOTTOMRIGHT", log_event_box, "BOTTOMLEFT")
for _, row in ipairs(log_list.rows) do
  row:SetScript("OnClick", function(self) lf:select_log(self.index) end)
end

lf:SetSize(1024, top:GetHeight() + box_height + footer:GetHeight())

local function log_title(index, log)
  local text = tostring(index)
  if log.encounter then
    text = text .. ". " .. log.encounter.name
    local difficulty_name = GetDifficultyInfo(log.encounter.difficulty_id)
    if difficulty_name then
      text = text .. format(" [%s]", difficulty_name)
    end
  elseif log.zone then
    text = text .. ". " .. log.zone
  end

  return text
end

local function log_timestamp(log)
  local text = log.server_timestamp

  if log.wow_version then
    text = text .. format(" (%s)", log.wow_version)
  end

  return text
end

local function get_log_line(index, entry, start_time)
  local text = entry
  local timestamp = entry.timestamp
  local event = entry.event
  local name, spell_id
  local stack, remaining_duration = "", ""

  if event == "HIDDEN_AURA_REMOVED" then
    name = entry.name
    spell_id = entry.spellId
  elseif event == "HIDDEN_AURA_APPLIED" then
    name = entry.name or ""
    spell_id = entry.spellId or 0
    stack = entry.applications or 0
    local expire_time = entry.expirationTime
    if expire_time > 0 then
      local d = expire_time - start_time - timestamp
      local h = floor(d / 3600)
      local m = floor(d / 60 % 60)
      local s = floor(d % 60)
      if h > 0 then
        remaining_duration = format("%dh %dm %ds", h, m, s)
      elseif m > 0 then
        remaining_duration = format("%dm %ds", m, s)
      else
        remaining_duration = format("%ds", s)
      end
    end
  else
    return {index=index, text=dict_to_string(entry)}
  end

  if stack == 0 then
    stack = ""
  end

  return {index=index, text={format('%.2f', timestamp), event, name, spell_id, stack, remaining_duration}, spell_id=spell_id}
end

function lf:select_log(index)
  local log = db.logs[index]
  lf.log = log
  if not log then
    log_event_box.lines = {}
    log_event_box:set_line(1)
    top.title:Hide()
    top.timestamp:Hide()
    return
  end

  log_event_box.lines = {}
  for i, entry in ipairs(log.events) do
    log_event_box.lines[#log_event_box.lines + 1] = get_log_line(i, entry, log.time)
  end
  log_event_box:set_line(1)

  top.title:SetText(log_title(index, log))
  top.timestamp:SetText(log_timestamp(log))
  top.title:Show()
  top.timestamp:Show()
end

function lf.update_config()
  if not db then
    db = HiddenAuraLoggerDB
  end

  if not db then
    return
  end

  local index
  log_list.lines = {}
  for i = #db.logs, 1, -1 do
    local log = db.logs[i]
    if log.events and #log.events > 0 then
      log_list.lines[#log_list.lines + 1] = {index=i, text=log_title(i, log)}
    end
  end

  if log_list.lines[1] then
    lf:select_log(log_list.lines[1].index)
  else
    lf:select_log()
  end

  log_list:set_line(1)
end

lf:SetScript("OnShow", function(self)
  self:update_config()
  self:SetPoint("CENTER")
end)
