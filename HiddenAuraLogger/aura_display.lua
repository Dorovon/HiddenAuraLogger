local addon_name, addon_table = ...
local db

addon_table.display_frame = CreateFrame("Frame", nil, UIParent)
addon_table.display_frame:ClearAllPoints()
addon_table.display_frame:SetSize(1, 1)
addon_table.display_frame:Hide()

local function is_dynamic(f)
  if not f.dynamic then
    return false
  end

  return next(f.dynamic) ~= nil
end

local function update_icon_dynamic(f)
  local d = f.dynamic

  if d.new and GetTime() - d.new >= db.config.fade_time then
    d.new = nil
  end

  if d.expire_time or d.expired then
    local t

    if d.expire_time then
      t = d.expire_time - GetTime()
      if t <= 0 then
        f:expire()
        return
      end
    else
      t = GetTime() - d.expired
      if t >= db.config.fade_time then
        addon_table.display_frame:remove_icon(f)
        return
      end
    end

    local s
    local r = d.expired and floor or ceil
    if t > 3600 then
      s = format("%d h", r(t/3600))
    elseif t > 60 then
      s = format("%d m", r(t/60))
    else
      s = format("%d s", r(t))
    end

    f.duration:SetText(s)
    f.duration:Show()
  else
    f.duration:Hide()
  end

  local color
  if d.new then
    color = {0, 1, 0}
  elseif d.expired then
    color = {1, 0, 0}
  end

  if color then
    f:update_border(unpack(color))
  else
    f:update_border(0, 0, 0, 0)
  end

  if not is_dynamic(f) then
    f:SetScript("OnUpdate", nil)
  end
end

local function update_icon(f, instance_id)
  f.dynamic = {}
  local d = f.dynamic
  local size = db.config.icon_size

  d.new = GetTime()
  f:SetSize(size, size)
  f.instance_id = instance_id
  f.texture:SetDesaturated(false)

  local aura_table = addon_table.active_auras[instance_id]
  local name, icon, count, duration, expirationTime = aura_table.name, aura_table.icon, aura_table.applications, aura_table.duration, aura_table.expirationTime
  if not icon then
    icon = "Interface/Icons/INV_Misc_QuestionMark"
  end

  f.texture:SetTexture(icon)
  if count and count > 0 then
    f.stack:SetText(count)
    f.stack:Show()
  else
    f.stack:Hide()
  end

  if expirationTime and expirationTime > GetTime() then
    d.expire_time = expirationTime
  else
    d.expire_time = nil
  end

  if is_dynamic(f) then
    f:SetScript("OnUpdate", update_icon_dynamic)
  else
    f:SetScript("OnUpdate", nil)
    update_icon_dynamic(f)
  end
end

local function expire_icon(f)
  f.dynamic = {}
  local d = f.dynamic

  f.texture:SetDesaturated(true)
  d.expired = GetTime()
  f:SetScript("OnUpdate", update_icon_dynamic)
end

local function update_icon_border(f, ...)
  for _, b in pairs(f.border) do
    b:SetColorTexture(...)
  end
end

local function create_function()
  local f = CreateFrame("Frame", nil, addon_table.display_frame, "BackdropTemplate")
  f.update = update_icon
  f.expire = expire_icon
  f.update_border = update_icon_border

  -- dynamic information for the icon
  f.dynamic = {}

  -- initialize texture
  f.texture = f:CreateTexture(nil, "BACKGROUND")
  f.texture:SetAllPoints()
  f.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  -- initalize stack label
  f.stack = f:CreateFontString(nil, "ARTWORK")
  f.stack:SetFont("fonts/frizqt__.ttf", 18, "OUTLINE")
  f.stack:SetPoint("BOTTOMRIGHT")

  -- initalize duration label
  f.duration = f:CreateFontString(nil, "ARTWORK")
  f.duration:SetFont("fonts/frizqt__.ttf", 12, "OUTLINE")
  f.duration:SetPoint("TOP", f, "BOTTOM", 0 , -2)

  -- initialize the border
  local left = f:CreateTexture(nil, "BORDER")
  left:SetPoint("TOPLEFT")
  left:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 2, 0)
  local right = f:CreateTexture(nil, "BORDER")
  right:SetPoint("TOPRIGHT")
  right:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -2, 0)
  local top = f:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT")
  top:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, -2)
  local bottom = f:CreateTexture(nil, "BORDER")
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, 2)
  f.border = {left, right, top, bottom}

  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(self.spell_id)
    GameTooltip:Show()
  end)

  f:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return f
end

local function reset_function(_, f)
  f:Hide()
end

local icon_pool = CreateObjectPool(create_function, reset_function)
local icon_frames = {}

function addon_table.display_frame:update()
  -- TODO: This only needs to run once per frame after all auras have been added.
  local auras = {}
  for instance_id, icon in pairs(icon_frames) do
    auras[#auras + 1] = instance_id
  end
  sort(auras, function(a, b)
    if icon_frames[a].spell_id == icon_frames[b].spell_id then
      return a < b
    end
    return icon_frames[a].spell_id < icon_frames[b].spell_id
  end)
  local prev, prev_row
  local row = 0
  local icon_height = db.config.icon_size
  local icons_per_row = db.config.icons_per_row
  local row_pad, col_pad = db.config.row_padding, db.config.col_padding
  for i, instance_id in ipairs(auras) do
    local icon = icon_frames[instance_id]
    if i % icons_per_row == 1 then
      row = row + 1
    end
    icon:ClearAllPoints()
    if not prev or row ~= prev_row then
      icon:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(icon_height + row_pad) * (row - 1))
    else
      icon:SetPoint("LEFT", prev, "RIGHT", col_pad, 0)
    end
    icon:Show()
    prev, prev_row = icon, row
  end
end

function addon_table.display_frame:update_aura(instance_id)
  if not self:IsShown() then
    return
  end

  local icon = icon_frames[instance_id]
  if addon_table.active_auras[instance_id] then
    local should_update = false
    if not icon then
      icon = icon_pool:Acquire()
      icon_frames[instance_id] = icon
      icon.spell_id = addon_table.active_auras[instance_id].spellId
      self:update()
    end
    icon:update(instance_id)
  elseif icon then
    -- The aura is not active and the icon needs to be removed.
    icon:expire()
  end
end

function addon_table.display_frame:remove_aura(instance_id)
  if not self:IsShown() then
    return
  end

  local icon = icon_frames[instance_id]
  if icon then
    addon_table.display_frame:remove_icon(icon)
  end
end

function addon_table.display_frame:remove_icon(f)
  if f then
    if f.instance_id then
      icon_frames[f.instance_id] = nil
    end
    icon_pool:Release(f)
    self:update()
  end
end

function addon_table.display_frame.update_config()
  if not db then
    db = HiddenAuraLoggerDB
  end

  addon_table.display_frame:SetPoint("TOPLEFT", db.config.x_offset, db.config.y_offset)

  if addon_table.active_auras then
    for instance_id, _ in pairs(addon_table.active_auras) do
      addon_table.display_frame:update_aura(instance_id)
    end
    addon_table.display_frame:update()
  end
end

addon_table.display_frame:SetScript("OnShow", function(self) self:update_config() end)
