VoiceRestrictions = {}

local STATE_KEY <const> = 'siku:state:voiceRestrictions'
local EVENT_CHANGED <const> = 'siku:voice:restrictionsChanged'
local SCOPE_ALL <const> = 'all'
local SCOPE_PROXIMITY <const> = 'proximity'

local restrictions <const> = {}
local blocked = {}

--- Reads the scopes a restriction is set with: nothing for every scope, one
--- name, or a list of names.
---@param value any The raw scopes.
---@return table? scopes The scopes as keys, or nil when the value is unusable.
local function toScopes(value)
  if value == nil then
    return { [SCOPE_ALL] = true }
  end

  if VoiceIsName(value) then
    return { [value] = true }
  end

  if type(value) ~= 'table' then
    return nil
  end

  local scopes <const> = {}

  for _, name in ipairs(value) do
    if not VoiceIsName(name) then
      return nil
    end

    scopes[name] = true
  end

  if not next(scopes) then
    return nil
  end

  return scopes
end

--- Rebuilds the view consumers read: every scope with the sorted reasons
--- closing it.
---@return nil
local function rebuild()
  blocked = {}

  for reason, restriction in pairs(restrictions) do
    for scope in pairs(restriction.scopes) do
      blocked[scope] = blocked[scope] or {}
      blocked[scope][#blocked[scope] + 1] = reason
    end
  end

  for _, reasons in pairs(blocked) do
    table.sort(reasons)
  end
end

--- Applies the restrictions everywhere they matter: the replicated state,
--- the routes, the microphone, the proximity route and the listeners.
---@return nil
local function publish()
  rebuild()

  LocalPlayer.state:set(STATE_KEY, next(blocked) ~= nil and blocked or false, true)
  VoiceRouting.suspend(VoiceRestrictions.isRestricted(SCOPE_ALL))
  VoiceTalk.refresh()
  VoiceScan.refresh()
  TriggerEvent(EVENT_CHANGED, VoiceRestrictions.getAll())
end

--- Whether a scope is closed, and by which reasons. A restriction set on
--- every scope closes any scope asked for.
---@param scope any The scope name, such as 'proximity', 'radio' or 'call'.
---@return boolean restricted Whether the scope is closed.
---@return table reasons The reasons closing it, sorted.
function VoiceRestrictions.isRestricted(scope)
  local reasons <const> = {}

  if not VoiceIsName(scope) then
    return false, reasons
  end

  local sources <const> = { blocked[SCOPE_ALL] or {}, scope ~= SCOPE_ALL and blocked[scope] or {} }

  for _, list in ipairs(sources) do
    for i = 1, #list do
      reasons[#reasons + 1] = list[i]
    end
  end

  return #reasons > 0, reasons
end

--- Whether the local voice is fully closed.
---@return boolean restricted Whether a restriction covers every scope.
function VoiceRestrictions.isFullyRestricted()
  return blocked[SCOPE_ALL] ~= nil
end

--- Whether the proximity route is closed.
---@return boolean restricted Whether nearby players stop receiving the voice.
function VoiceRestrictions.isProximityRestricted()
  return (VoiceRestrictions.isRestricted(SCOPE_PROXIMITY))
end

--- Every closed scope with the reasons closing it.
---@return table restrictions { [scope] = { reasons } }, empty when none.
function VoiceRestrictions.getAll()
  local copy <const> = {}

  for scope, reasons in pairs(blocked) do
    copy[scope] = { table.unpack(reasons) }
  end

  return copy
end

--- Closes one or more scopes on behalf of a reason, such as 'dead' or
--- 'cuffed'. Setting the same reason again replaces its scopes. A scope is
--- open again only once every reason closing it is cleared.
---@param reason string A key naming why, owned by the caller.
---@param scopes? string|table One scope, a list of scopes, or nothing for every scope.
---@param resource? string The resource setting it, resolved when omitted.
---@return boolean applied Whether the restriction was stored.
function VoiceRestrictions.set(reason, scopes, resource)
  if not VoiceIsName(reason) then
    return VoiceRefuse('SetRestriction', 'reason')
  end

  local set <const> = toScopes(scopes)

  if not set then
    return VoiceRefuse('SetRestriction', 'scopes')
  end

  restrictions[reason] = { scopes = set, resource = resource or VoiceResolveOwner() }
  publish()

  return true
end

--- Lifts a restriction.
---@param reason string The key it was set with.
---@return boolean removed Whether the restriction existed.
function VoiceRestrictions.clear(reason)
  if not restrictions[reason] then
    return false
  end

  restrictions[reason] = nil
  publish()

  return true
end

--- Lifts every restriction a resource set, when it stops.
---@param resource string The resource name.
---@return nil
function VoiceRestrictions.clearOwner(resource)
  local removed = false

  for reason, restriction in pairs(restrictions) do
    if restriction.resource == resource then
      restrictions[reason] = nil
      removed = true
    end
  end

  if removed then
    publish()
  end
end

RegisterNetEvent('siku_voice:client:setRestriction', function(reason, scopes)
  VoiceRestrictions.set(reason, scopes, Siku.name)
end)

RegisterNetEvent('siku_voice:client:clearRestriction', function(reason)
  VoiceRestrictions.clear(reason)
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= Siku.name then
    VoiceRestrictions.clearOwner(resource)
  end
end)
