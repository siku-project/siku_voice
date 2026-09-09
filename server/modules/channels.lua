VoiceChannels = {}

local MAX_CLIENTS_CONVAR <const> = 'sv_maxClients'
local DEFAULT_MAX_CLIENTS <const> = 32
local FIRST_CHANNEL <const> = 1

local maxClients <const> = GetConvarInt(MAX_CLIENTS_CONVAR, DEFAULT_MAX_CLIENTS)

--- The channel range reserved for players: one channel per slot, numbered
--- by server id. Anything built later on top of voice allocates above it.
---@return number first The first reserved channel.
---@return number last The last reserved channel.
function VoiceChannels.getReservedRange()
  return FIRST_CHANNEL, maxClients
end

--- Whether a channel number belongs to the player range.
---@param channel any The channel number.
---@return boolean reserved Whether a player owns it.
function VoiceChannels.isPlayerChannel(channel)
  return math.type(channel) == 'integer' and channel >= FIRST_CHANNEL and channel <= maxClients
end

--- The personal channel of a session, which is its server id.
---@param sessionId any The player server id.
---@return number? channel The channel number, or nil outside the range.
function VoiceChannels.getPlayerChannel(sessionId)
  if not VoiceChannels.isPlayerChannel(sessionId) then
    return nil
  end

  return sessionId
end

--- Creates the personal channel of a session on the voice server before
--- the client asks for it, so it exists the moment anyone targets it. A
--- channel that already exists is left alone.
---@param sessionId number The player server id.
---@return boolean created Whether the channel is in the reserved range.
function VoiceChannels.ensurePlayerChannel(sessionId)
  local channel <const> = VoiceChannels.getPlayerChannel(sessionId)

  if not channel then
    Siku.print.warn(T('channel_out_of_range', sessionId, maxClients))
    return false
  end

  MumbleCreateChannel(channel)

  return true
end
