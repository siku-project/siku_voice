local PROXIMITY_STATE_KEY <const> = 'siku:state:voice'

--- Whether a session is online.
---@param sessionId any The player server id.
---@return boolean online Whether the player is connected.
local function isOnline(sessionId)
  return type(sessionId) == 'number' and GetPlayerName(tostring(sessionId)) ~= nil
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

--- Reads the voice state of a player as the server knows it.
---@param sessionId number The player server id.
---@return table? state { mode, range, muted, channel }, or nil when offline.
local function getPlayerVoice(sessionId)
  if not isOnline(sessionId) then
    return nil
  end

  local proximity <const> = Player(sessionId).state[PROXIMITY_STATE_KEY] or {}

  return {
    mode = proximity.mode,
    range = proximity.range,
    muted = VoiceMute.isMuted(sessionId),
    channel = VoiceChannels.getPlayerChannel(sessionId),
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

exports('SetPlayerProximityMode', setPlayerProximityMode)
exports('SetPlayerRangeOverride', setPlayerRangeOverride)
exports('ClearPlayerRangeOverride', clearPlayerRangeOverride)
exports('GetPlayerVoice', getPlayerVoice)
exports('MutePlayer', mutePlayer)
exports('UnmutePlayer', unmutePlayer)
exports('IsPlayerMuted', isPlayerMuted)
exports('GetPlayerChannel', getPlayerChannel)
exports('GetReservedChannelRange', getReservedChannelRange)
