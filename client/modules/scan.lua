VoiceScan = {}

local ROUTE <const> = 'proximity'

local filters <const> = {}
local members = {}
local pending = false

--- Whether every registered filter accepts a player as a recipient.
---@param serverId number The player server id.
---@param distance number The distance to the player, in meters.
---@param playerId number The local player index.
---@return boolean accepted Whether the player may receive the local voice.
local function passesFilters(serverId, distance, playerId)
  for _, filter in pairs(filters) do
    local ok <const>, accepted <const> = pcall(filter.handler, serverId, distance, playerId)

    if not ok or accepted == false then
      return false
    end
  end

  return true
end

--- Whether a player is close enough to receive the local voice, with the
--- hysteresis keeping a current recipient a little longer.
---@param serverId number The player server id.
---@param distanceSq number The squared distance to the player.
---@param enterSq number The squared range a newcomer must be within.
---@param leaveSq number The squared range a current recipient may drift to.
---@return boolean within Whether the player is within reach.
local function withinReach(serverId, distanceSq, enterSq, leaveSq)
  if members[serverId] then
    return distanceSq <= leaveSq
  end

  return distanceSq <= enterSq
end

--- Rebuilds the set of nearby players and hands it to routing, which only
--- applies what changed.
---@return nil
local function scan()
  pending = false

  if not VoiceMumble.isReady() then
    return
  end

  local proximity <const> = VoiceConfig.proximity
  local range <const> = VoiceProximity.getRange() * proximity.targetMargin
  local enterSq <const> = range * range
  local leaveSq <const> = (range + proximity.hysteresis) ^ 2
  local coords <const> = GetEntityCoords(PlayerPedId(), false)
  local players <const> = GetActivePlayers()
  local localPlayer <const> = PlayerId()
  local found <const> = {}

  VoiceListening.update(players, localPlayer)

  for i = 1, #players do
    local playerId <const> = players[i]

    if playerId ~= localPlayer then
      local serverId <const> = GetPlayerServerId(playerId)
      local delta <const> = coords - GetEntityCoords(GetPlayerPed(playerId), false)
      local distanceSq <const> = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z

      if withinReach(serverId, distanceSq, enterSq, leaveSq)
        and VoiceMumble.channelExists(serverId)
        and passesFilters(serverId, math.sqrt(distanceSq), playerId) then
        found[serverId] = true
      end
    end
  end

  members = found
  VoiceRouting.set(ROUTE, { channels = found }, Siku.name)
  VoiceRouting.enable(ROUTE, not VoiceRestrictions.isProximityRestricted())
end

--- Asks for a scan on the next frame instead of waiting for the interval,
--- after the range changed.
---@return nil
function VoiceScan.refresh()
  if pending then
    return
  end

  pending = true
  SetTimeout(0, scan)
end

--- Registers a filter deciding whether a nearby player may receive the
--- local voice. Returning false excludes them; an error excludes them too.
---@param name string The filter name, owned by the caller.
---@param handler function Receives (serverId, distance, playerId).
---@param owner? string The resource registering it, resolved when omitted.
---@return boolean registered Whether the filter was stored.
function VoiceScan.addFilter(name, handler, owner)
  if not VoiceIsName(name) then
    return VoiceRefuse('AddProximityFilter', 'name')
  end

  if not Siku.isCallable(handler) then
    return VoiceRefuse('AddProximityFilter', 'handler')
  end

  filters[name] = { handler = handler, owner = owner or VoiceResolveOwner() }
  VoiceScan.refresh()

  return true
end

--- Removes a filter.
---@param name string The filter name.
---@return boolean removed Whether the filter existed.
function VoiceScan.removeFilter(name)
  if not filters[name] then
    return false
  end

  filters[name] = nil
  VoiceScan.refresh()

  return true
end

--- Removes every filter a resource registered, when it stops.
---@param owner string The resource name.
---@return nil
function VoiceScan.clearOwner(owner)
  for name, filter in pairs(filters) do
    if filter.owner == owner then
      filters[name] = nil
    end
  end
end

--- The players currently receiving the local voice through proximity.
---@return table serverIds The server ids as keys.
function VoiceScan.getMembers()
  local copy <const> = {}

  for serverId in pairs(members) do
    copy[serverId] = true
  end

  return copy
end

--- Forgets every recipient, so the next scan starts from nothing.
---@return nil
function VoiceScan.reset()
  members = {}
end

Siku.timers.setInterval(VoiceConfig.proximity.scanInterval, scan)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= Siku.name then
    VoiceScan.clearOwner(resource)
  end
end)
