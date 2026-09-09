VoiceProximity = {}

local STATE_KEY <const> = 'siku:state:voice'
local EVENT_CHANGED <const> = 'siku:voice:proximityChanged'
local HUD_RESOURCE <const> = 'siku_hud'
local STARTED <const> = 'started'
local DEFAULT_PRIORITY <const> = 0
local REASON_MODE <const> = 'mode'
local REASON_OVERRIDE <const> = 'override'
local REASON_RECONNECT <const> = 'reconnect'

local currentMode = VoiceModes.getDefault().name
local overrides <const> = {}
local sequence = 0

--- Picks the override in effect: the highest priority, and among equals
--- the one set last.
---@return table? override The winning override, or nil when none is set.
local function activeOverride()
  local winner = nil

  for _, override in pairs(overrides) do
    if not winner or override.priority > winner.priority or
      (override.priority == winner.priority and override.order > winner.order) then
      winner = override
    end
  end

  return winner
end

--- Converts a range in meters into what the engine expects for the active
--- audio mode.
---@param range number The range in meters.
---@return number value The engine value.
local function toEngineRange(range)
  if VoiceIsNativeAudio() then
    return range * VoiceConfig.audio.nativeRangeFactor
  end

  return range
end

--- Forwards the range in effect to the HUD when it is running.
---@param state table The proximity state.
---@return nil
local function updateHud(state)
  if GetResourceState(HUD_RESOURCE) ~= STARTED then
    return
  end

  pcall(function()
    exports[HUD_RESOURCE]:SetVoice({ mode = state.mode, range = state.range })
  end)
end

--- Applies the range in effect everywhere it matters: the engine, the
--- replicated state, the listeners and the on-screen feedback.
---@param reason string Why it changed: 'mode', 'override' or 'reconnect'.
---@return nil
local function publish(reason)
  local state <const> = VoiceProximity.getState()

  VoiceMumble.setProximity(toEngineRange(state.range))
  LocalPlayer.state:set(STATE_KEY, { mode = state.mode, range = state.range }, true)
  updateHud(state)

  if VoiceScan then
    VoiceScan.refresh()
  end

  if reason ~= REASON_RECONNECT and VoiceConfig.indicator.enabled then
    VoiceIndicator.show(state.range)
  end

  TriggerEvent(EVENT_CHANGED, state, reason)
end

--- The name of the mode the player selected.
---@return string mode The current mode name.
function VoiceProximity.getMode()
  return currentMode
end

--- The range in effect, in meters: the active override when there is one,
--- the selected mode otherwise.
---@return number range The range in meters.
function VoiceProximity.getRange()
  local override <const> = activeOverride()

  if override then
    return override.range
  end

  return VoiceModes.get(currentMode).range
end

--- The full proximity state.
---@return table state { mode, range, overridden, owner? }.
function VoiceProximity.getState()
  local override <const> = activeOverride()

  return {
    mode = currentMode,
    range = VoiceProximity.getRange(),
    overridden = override ~= nil,
    owner = override and override.owner or nil,
  }
end

--- Selects a mode by name.
---@param name string The mode name.
---@return boolean changed Whether the mode moved.
function VoiceProximity.setMode(name)
  local mode <const> = VoiceModes.get(name)

  if not mode then
    Siku.print.warn(T('mode_unknown', tostring(name)))
    return false
  end

  if mode.name == currentMode then
    return false
  end

  currentMode = mode.name
  publish(REASON_MODE)

  return true
end

--- Selects the mode following the current one, wrapping around.
---@return string mode The mode now selected.
function VoiceProximity.cycleMode()
  VoiceProximity.setMode(VoiceModes.getNext(currentMode).name)

  return currentMode
end

--- Sets a temporary range on behalf of a caller, leaving the selected mode
--- untouched. Setting it again with the same owner replaces it.
---@param owner string A key naming the caller, used to clear it later.
---@param range number The range in meters.
---@param priority? number Wins over lower priorities (default 0).
---@param resource? string The resource setting it, resolved when omitted.
---@return boolean applied Whether the override was stored.
function VoiceProximity.setOverride(owner, range, priority, resource)
  if not VoiceIsName(owner) then
    return VoiceRefuse('SetRangeOverride', 'owner')
  end

  if not VoiceIsPositiveNumber(range) then
    return VoiceRefuse('SetRangeOverride', 'range')
  end

  if priority ~= nil and type(priority) ~= 'number' then
    return VoiceRefuse('SetRangeOverride', 'priority')
  end

  sequence = sequence + 1
  overrides[owner] = {
    owner = owner,
    range = range + 0.0,
    priority = priority or DEFAULT_PRIORITY,
    order = sequence,
    resource = resource or VoiceResolveOwner(),
  }

  publish(REASON_OVERRIDE)

  return true
end

--- Removes the override a caller set.
---@param owner string The key it was set with.
---@return boolean removed Whether an override existed.
function VoiceProximity.clearOverride(owner)
  if not overrides[owner] then
    return false
  end

  overrides[owner] = nil
  publish(REASON_OVERRIDE)

  return true
end

--- Removes every override a resource set, when it stops.
---@param resource string The resource name.
---@return nil
function VoiceProximity.clearResource(resource)
  local removed = false

  for owner, override in pairs(overrides) do
    if override.resource == resource then
      overrides[owner] = nil
      removed = true
    end
  end

  if removed then
    publish(REASON_OVERRIDE)
  end
end

--- Pushes the range in effect again, after the engine forgot it across a
--- reconnection.
---@return nil
function VoiceProximity.reapply()
  publish(REASON_RECONNECT)
end

RegisterNetEvent('siku_voice:client:setProximityMode', function(name)
  VoiceProximity.setMode(name)
end)

RegisterNetEvent('siku_voice:client:setRangeOverride', function(owner, range, priority)
  VoiceProximity.setOverride(owner, range, priority, Siku.name)
end)

RegisterNetEvent('siku_voice:client:clearRangeOverride', function(owner)
  VoiceProximity.clearOverride(owner)
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= Siku.name then
    VoiceProximity.clearResource(resource)
  end
end)
