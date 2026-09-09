--- Whether the local voice is connected and routed.
---@return boolean connected Whether voice is operational.
local function isConnected()
  return VoiceSession.isConnected()
end

--- Whether the local player is transmitting voice.
---@return boolean talking Whether the microphone is live.
local function isTalking()
  return VoiceSession.isTalking()
end

--- Opens the microphone on behalf of a caller until it is released.
---@param owner string A key naming the caller.
---@return boolean held Whether the hold was stored.
local function holdTalk(owner)
  return VoiceTalk.hold(owner)
end

--- Releases a microphone hold.
---@param owner string The key it was held with.
---@return boolean released Whether the hold existed.
local function releaseTalk(owner)
  return VoiceTalk.release(owner)
end

--- Whether the microphone is being held open by a key or a resource.
---@return boolean held Whether a hold is active.
local function isTalkHeld()
  return VoiceTalk.isHeld()
end

--- Reads the proximity state.
---@return table state { mode, range, overridden, owner? }.
local function getProximity()
  return VoiceProximity.getState()
end

--- Lists the selectable proximity modes, in cycling order.
---@return table modes A list of { name, range, index }.
local function getProximityModes()
  return VoiceModes.list()
end

--- Selects a proximity mode.
---@param name string The mode name.
---@return boolean changed Whether the mode moved.
local function setProximityMode(name)
  return VoiceProximity.setMode(name)
end

--- Selects the next proximity mode.
---@return string mode The mode now selected.
local function cycleProximityMode()
  return VoiceProximity.cycleMode()
end

--- Sets a temporary range without touching the selected mode.
---@param owner string A key naming the caller.
---@param range number The range in meters.
---@param priority? number Wins over lower priorities.
---@return boolean applied Whether the override was stored.
local function setRangeOverride(owner, range, priority)
  return VoiceProximity.setOverride(owner, range, priority)
end

--- Removes a temporary range.
---@param owner string The key it was set with.
---@return boolean removed Whether an override existed.
local function clearRangeOverride(owner)
  return VoiceProximity.clearOverride(owner)
end

--- Shows the range ring around the player.
---@param range? number The radius in meters (default: the range in effect).
---@return nil
local function showRangeIndicator(range)
  VoiceIndicator.show(range)
end

--- Sets the recipients of a route.
---@param name string The route name.
---@param recipients table { players?, channels? }, each a list or a set of ids.
---@return boolean applied Whether the route was updated.
local function setRoute(name, recipients)
  return VoiceRouting.set(name, recipients)
end

--- Adds one recipient to a route.
---@param name string The route name.
---@param kind string 'players' or 'channels'.
---@param id number The recipient id.
---@return boolean added Whether the recipient is on the route.
local function addRouteRecipient(name, kind, id)
  return VoiceRouting.add(name, kind, id)
end

--- Removes one recipient from a route.
---@param name string The route name.
---@param kind string 'players' or 'channels'.
---@param id number The recipient id.
---@return boolean removed Whether the recipient was on the route.
local function removeRouteRecipient(name, kind, id)
  return VoiceRouting.remove(name, kind, id)
end

--- Enables or disables a route without forgetting its recipients.
---@param name string The route name.
---@param enabled boolean Whether the route contributes recipients.
---@return boolean changed Whether the state moved.
local function enableRoute(name, enabled)
  return VoiceRouting.enable(name, enabled)
end

--- Removes a route.
---@param name string The route name.
---@return boolean removed Whether the route existed.
local function clearRoute(name)
  return VoiceRouting.clear(name)
end

--- Reads a route.
---@param name string The route name.
---@return table? route { enabled, players, channels }, or nil.
local function getRoute(name)
  return VoiceRouting.get(name)
end

--- Sets how a remote player is heard, on a named layer.
---@param target number The player server id.
---@param layer string The layer name.
---@param options table { volume? (0 to 1), effect?, priority? }.
---@return boolean applied Whether the layer was stored.
local function setRendering(target, layer, options)
  return VoiceRendering.set(target, layer, options)
end

--- Removes one layer from a player, or every layer when none is named.
---@param target number The player server id.
---@param layer? string The layer name.
---@return boolean removed Whether anything was removed.
local function clearRendering(target, layer)
  if layer == nil then
    return VoiceRendering.clearPlayer(target)
  end

  return VoiceRendering.clear(target, layer)
end

--- Removes one layer from every player.
---@param layer string The layer name.
---@return number count How many players lost the layer.
local function clearRenderingLayer(layer)
  return VoiceRendering.clearLayer(layer)
end

--- Reads the layer set on a player.
---@param target number The player server id.
---@param layer string The layer name.
---@return table? layer { volume, effect, priority }, or nil.
local function getRendering(target, layer)
  return VoiceRendering.get(target, layer)
end

--- Registers an audio effect backed by a game submix.
---@param name string The effect name.
---@param definition table { radioFx?, parameters?, output? }.
---@return boolean registered Whether the effect is available.
local function registerEffect(name, definition)
  return VoiceEffects.register(name, definition)
end

--- Whether an effect is available on this client.
---@param name string The effect name.
---@return boolean available Whether the effect exists.
local function hasEffect(name)
  return VoiceEffects.has(name)
end

--- Registers a filter deciding whether a nearby player receives the voice.
---@param name string The filter name.
---@param handler function Receives (serverId, distance, playerId).
---@return boolean registered Whether the filter was stored.
local function addProximityFilter(name, handler)
  return VoiceScan.addFilter(name, handler)
end

--- Removes a proximity filter.
---@param name string The filter name.
---@return boolean removed Whether the filter existed.
local function removeProximityFilter(name)
  return VoiceScan.removeFilter(name)
end

exports('IsConnected', isConnected)
exports('IsTalking', isTalking)
exports('HoldTalk', holdTalk)
exports('ReleaseTalk', releaseTalk)
exports('IsTalkHeld', isTalkHeld)
exports('GetProximity', getProximity)
exports('GetProximityModes', getProximityModes)
exports('SetProximityMode', setProximityMode)
exports('CycleProximityMode', cycleProximityMode)
exports('SetRangeOverride', setRangeOverride)
exports('ClearRangeOverride', clearRangeOverride)
exports('ShowRangeIndicator', showRangeIndicator)
exports('SetRoute', setRoute)
exports('AddRouteRecipient', addRouteRecipient)
exports('RemoveRouteRecipient', removeRouteRecipient)
exports('EnableRoute', enableRoute)
exports('ClearRoute', clearRoute)
exports('GetRoute', getRoute)
exports('SetRendering', setRendering)
exports('ClearRendering', clearRendering)
exports('ClearRenderingLayer', clearRenderingLayer)
exports('GetRendering', getRendering)
exports('RegisterEffect', registerEffect)
exports('HasEffect', hasEffect)
exports('AddProximityFilter', addProximityFilter)
exports('RemoveProximityFilter', removeProximityFilter)
