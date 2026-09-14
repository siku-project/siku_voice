local PROXIMITY_STATE_KEY <const> = 'siku:state:voice'
local RESTRICTIONS_STATE_KEY <const> = 'siku:state:voiceRestrictions'
local LISTENING_STATE_KEY <const> = 'siku:state:voiceListening'
local SCOPE_ALL <const> = 'all'
local GRANT_RESTRICTION <const> = 'restriction:'
local GRANT_LISTENING <const> = 'listening:'

--- Whether a session is online.
---@param sessionId any The player server id.
---@return boolean online Whether the player is connected.
local function isOnline(sessionId)
  return type(sessionId) == 'number' and GetPlayerName(tostring(sessionId)) ~= nil
end

--- Whether a value is a non-empty string.
---@param value any The value to test.
---@return boolean valid Whether the value is a usable name.
local function isName(value)
  return type(value) == 'string' and value ~= ''
end

--- Whether a scopes argument has a shape the client accepts.
---@param scopes any Nothing, one name or a list of names.
---@return boolean valid Whether the client will take it.
local function areScopes(scopes)
  if scopes == nil or isName(scopes) then
    return true
  end

  if type(scopes) ~= 'table' or #scopes == 0 then
    return false
  end

  for _, name in ipairs(scopes) do
    if not isName(name) then
      return false
    end
  end

  return true
end

--- The resource calling into the API, or this one.
---@return string resource The resource name.
local function caller()
  return GetInvokingResource() or Siku.name
end

--- The closed scopes of a player as their client replicated them.
---@param sessionId number The player server id.
---@return table restrictions { [scope] = { reasons } }, empty when none.
local function readRestrictions(sessionId)
  local state <const> = Player(sessionId).state[RESTRICTIONS_STATE_KEY]

  if type(state) ~= 'table' then
    return {}
  end

  return state
end

--- Selects the proximity mode of a player.
---@param sessionId number The player server id.
---@param mode string The mode name.
---@return boolean sent Whether the request reached the client.
local function setPlayerProximityMode(sessionId, mode)
  if not isOnline(sessionId) or not VoiceModes.get(mode) then
    return false
  end

  TriggerClientEvent('siku_voice:client:setProximityMode', sessionId, mode)

  return true
end

--- Sets a temporary range on a player, on behalf of a caller.
---@param sessionId number The player server id.
---@param owner string A key naming the caller.
---@param range number The range in meters.
---@param priority? number Wins over lower priorities.
---@return boolean sent Whether the request reached the client.
local function setPlayerRangeOverride(sessionId, owner, range, priority)
  if not isOnline(sessionId) or type(owner) ~= 'string' or owner == '' then
    return false
  end

  if type(range) ~= 'number' or range <= 0 then
    return false
  end

  TriggerClientEvent('siku_voice:client:setRangeOverride', sessionId, owner, range, priority)

  return true
end

--- Removes a temporary range from a player.
---@param sessionId number The player server id.
---@param owner string The key it was set with.
---@return boolean sent Whether the request reached the client.
local function clearPlayerRangeOverride(sessionId, owner)
  if not isOnline(sessionId) or type(owner) ~= 'string' then
    return false
  end

  TriggerClientEvent('siku_voice:client:clearRangeOverride', sessionId, owner)

  return true
end

--- Closes one or more scopes of a player's voice for a reason, on behalf
--- of the calling resource. Lifted on its own when that resource stops.
---@param sessionId number The player server id.
---@param reason string A key naming why, such as 'dead'.
---@param scopes? string|table One scope, a list, or nothing for every scope.
---@return boolean sent Whether the request reached the client.
local function setPlayerRestriction(sessionId, reason, scopes)
  if not isOnline(sessionId) or not isName(reason) or not areScopes(scopes) then
    return false
  end

  TriggerClientEvent('siku_voice:client:setRestriction', sessionId, reason, scopes)
  VoiceGrants.track(caller(), sessionId, GRANT_RESTRICTION .. reason, function()
    TriggerClientEvent('siku_voice:client:clearRestriction', sessionId, reason)
  end)

  return true
end

--- Lifts a restriction from a player.
---@param sessionId number The player server id.
---@param reason string The key it was set with.
---@return boolean sent Whether the request reached the client.
local function clearPlayerRestriction(sessionId, reason)
  if not isOnline(sessionId) or not isName(reason) then
    return false
  end

  TriggerClientEvent('siku_voice:client:clearRestriction', sessionId, reason)
  VoiceGrants.untrack(caller(), sessionId, GRANT_RESTRICTION .. reason)

  return true
end

--- Whether a scope of a player's voice is closed, and why.
---@param sessionId number The player server id.
---@param scope string The scope name, such as 'proximity', 'radio' or 'call'.
---@return boolean restricted Whether the scope is closed.
---@return table reasons The reasons closing it.
local function isPlayerRestricted(sessionId, scope)
  local reasons <const> = {}

  if not isOnline(sessionId) or not isName(scope) then
    return false, reasons
  end

  local restrictions <const> = readRestrictions(sessionId)
  local sources <const> = { restrictions[SCOPE_ALL] or {}, scope ~= SCOPE_ALL and restrictions[scope] or {} }

  for _, list in ipairs(sources) do
    for i = 1, #list do
      reasons[#reasons + 1] = list[i]
    end
  end

  return #reasons > 0, reasons
end

--- Every closed scope of a player's voice with the reasons closing it.
---@param sessionId number The player server id.
---@return table restrictions { [scope] = { reasons } }, empty when none or offline.
local function getPlayerRestrictions(sessionId)
  if not isOnline(sessionId) then
    return {}
  end

  return readRestrictions(sessionId)
end

--- Makes a player hear every player in scope whatever the distance, or
--- stops it, on behalf of the calling resource. Withdrawn on its own when
--- that resource stops.
---@param sessionId number The player server id.
---@param owner string A key naming the caller.
---@param enabled boolean Whether the player listens.
---@return boolean sent Whether the request reached the client.
local function setPlayerListening(sessionId, owner, enabled)
  if not isOnline(sessionId) or not isName(owner) then
    return false
  end

  local wanted <const> = enabled == true

  TriggerClientEvent('siku_voice:client:setListening', sessionId, owner, wanted)

  if wanted then
    VoiceGrants.track(caller(), sessionId, GRANT_LISTENING .. owner, function()
      TriggerClientEvent('siku_voice:client:setListening', sessionId, owner, false)
    end)
  else
    VoiceGrants.untrack(caller(), sessionId, GRANT_LISTENING .. owner)
  end

  return true
end

--- Reads the voice state of a player as the server knows it.
---@param sessionId number The player server id.
---@return table? state { mode, range, muted, channel, restrictions, listening }, or nil when offline.
local function getPlayerVoice(sessionId)
  if not isOnline(sessionId) then
    return nil
  end

  local state <const> = Player(sessionId).state
  local proximity <const> = state[PROXIMITY_STATE_KEY] or {}

  return {
    mode = proximity.mode,
    range = proximity.range,
    muted = VoiceMute.isMuted(sessionId),
    channel = VoiceChannels.getPlayerChannel(sessionId),
    restrictions = readRestrictions(sessionId),
    listening = state[LISTENING_STATE_KEY] == true,
  }
end

--- Mutes a player on the voice server.
---@param sessionId number The player server id.
---@param duration? number Seconds (default: the configured duration).
---@return boolean applied Whether the mute was set.
local function mutePlayer(sessionId, duration)
  return VoiceMute.mute(sessionId, duration)
end

--- Unmutes a player.
---@param sessionId number The player server id.
---@return boolean applied Whether a mute was lifted.
local function unmutePlayer(sessionId)
  return VoiceMute.unmute(sessionId)
end

--- Whether a player is muted.
---@param sessionId number The player server id.
---@return boolean muted Whether the player is muted.
local function isPlayerMuted(sessionId)
  return VoiceMute.isMuted(sessionId)
end

--- The personal channel of a player.
---@param sessionId number The player server id.
---@return number? channel The channel number, or nil.
local function getPlayerChannel(sessionId)
  return VoiceChannels.getPlayerChannel(sessionId)
end

--- The channel range reserved for players.
---@return number first The first reserved channel.
---@return number last The last reserved channel.
local function getReservedChannelRange()
  return VoiceChannels.getReservedRange()
end

--- The voice server the clients are told to use.
---@return table server { external, address?, port? }.
local function getVoiceServer()
  local endpoint <const> = VoiceEndpoint.get()

  return {
    external = endpoint ~= false,
    address = endpoint and endpoint.address or nil,
    port = endpoint and endpoint.port or nil,
  }
end

exports('SetPlayerProximityMode', setPlayerProximityMode)
exports('SetPlayerRangeOverride', setPlayerRangeOverride)
exports('ClearPlayerRangeOverride', clearPlayerRangeOverride)
exports('SetPlayerRestriction', setPlayerRestriction)
exports('ClearPlayerRestriction', clearPlayerRestriction)
exports('IsPlayerRestricted', isPlayerRestricted)
exports('GetPlayerRestrictions', getPlayerRestrictions)
exports('SetPlayerListening', setPlayerListening)
exports('GetPlayerVoice', getPlayerVoice)
exports('MutePlayer', mutePlayer)
exports('UnmutePlayer', unmutePlayer)
exports('IsPlayerMuted', isPlayerMuted)
exports('GetPlayerChannel', getPlayerChannel)
exports('GetReservedChannelRange', getReservedChannelRange)
exports('GetVoiceServer', getVoiceServer)
