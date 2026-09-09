VoiceMumble = {}

local TARGET <const> = 1
local CHANNEL_TARGET <const> = 0
local JOIN_POLL <const> = 100
local JOIN_TIMEOUT <const> = 5000
local RESET_VOLUME <const> = -1.0
local NO_SUBMIX <const> = -1

local serverId <const> = GetPlayerServerId(PlayerId())
local ready = false

--- The server id of the local player, which is also their personal
--- channel number.
---@return number serverId The local server id.
function VoiceMumble.getServerId()
  return serverId
end

--- Whether the local client sits in its personal channel with its voice
--- target armed, the only state in which routing calls reach the engine.
---@return boolean ready Whether voice routing is operational.
function VoiceMumble.isReady()
  return ready
end

--- Marks routing as operational or not. Owned by the session lifecycle.
---@param value boolean The new readiness.
---@return nil
function VoiceMumble.setReady(value)
  ready = value == true
end

--- Whether the game is connected to the voice server at all.
---@return boolean connected Whether the Mumble session is up.
function VoiceMumble.isConnected()
  return MumbleIsConnected()
end

--- Joins the personal channel and waits for the engine to confirm it. The
--- join is asynchronous, so the request is repeated until the channel the
--- engine reports matches, or the wait runs out.
---@return boolean joined Whether the channel was confirmed.
function VoiceMumble.joinPersonalChannel()
  local deadline <const> = GetGameTimer() + JOIN_TIMEOUT

  MumbleSetVoiceChannel(serverId)

  while MumbleGetVoiceChannelFromServerId(serverId) ~= serverId do
    if not MumbleIsConnected() or GetGameTimer() >= deadline then
      return false
    end

    Wait(JOIN_POLL)
    MumbleSetVoiceChannel(serverId)
  end

  return true
end

--- Empties the voice target and makes it the active one, so every recipient
--- comes from what routing adds afterwards.
---@return nil
function VoiceMumble.resetTarget()
  MumbleClearVoiceTarget(TARGET)
  MumbleSetVoiceTarget(TARGET)
end

--- Adds a channel to the voice target.
---@param channel number The channel number.
---@return nil
function VoiceMumble.addTargetChannel(channel)
  if ready then
    MumbleAddVoiceTargetChannel(TARGET, channel)
  end
end

--- Removes a channel from the voice target.
---@param channel number The channel number.
---@return nil
function VoiceMumble.removeTargetChannel(channel)
  if ready then
    MumbleRemoveVoiceTargetChannel(TARGET, channel)
  end
end

--- Adds a player to the voice target.
---@param target number The player server id.
---@return nil
function VoiceMumble.addTargetPlayer(target)
  if ready then
    MumbleAddVoiceTargetPlayerByServerId(TARGET, target)
  end
end

--- Removes a player from the voice target.
---@param target number The player server id.
---@return nil
function VoiceMumble.removeTargetPlayer(target)
  if ready then
    MumbleRemoveVoiceTargetPlayerByServerId(TARGET, target)
  end
end

--- Whether the engine knows a channel, which is what makes it targetable.
---@param channel number The channel number.
---@return boolean exists Whether the channel exists on the voice server.
function VoiceMumble.channelExists(channel)
  return MumbleDoesChannelExist(channel)
end

--- Sets how far the local voice is sent and heard, in engine units.
---@param range number The range handed to the engine.
---@return nil
function VoiceMumble.setProximity(range)
  MumbleSetTalkerProximity(range + 0.0)
end

--- Forces the volume a remote player is heard at, bypassing distance, or
--- hands them back to proximity.
---@param target number The player server id.
---@param volume number? The volume, 0 to 1, or nil to reset.
---@return nil
function VoiceMumble.setVolume(target, volume)
  MumbleSetVolumeOverrideByServerId(target, volume or RESET_VOLUME)
end

--- Routes a remote player through a submix, or back to the plain output.
---@param target number The player server id.
---@param submix number? The submix id, or nil to reset.
---@return nil
function VoiceMumble.setSubmix(target, submix)
  MumbleSetSubmixForServerId(target, submix or NO_SUBMIX)
end

--- Whether the local player is transmitting voice right now.
---@return boolean talking Whether the microphone is live.
function VoiceMumble.isTalking()
  local value <const> = MumbleIsPlayerTalking(PlayerId())

  return value == true or value == 1
end

--- Gives the engine back its default behaviour: speech aimed at the current
--- channel, and the root channel everyone shares. Used when the resource
--- stops, so voice keeps working without it.
---@return nil
function VoiceMumble.release()
  ready = false

  if not MumbleIsConnected() then
    return
  end

  MumbleClearVoiceTarget(TARGET)
  MumbleSetVoiceTarget(CHANNEL_TARGET)
  MumbleClearVoiceChannel()
end
