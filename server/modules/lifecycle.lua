local MUTED_STATE_KEY <const> = 'siku:state:voiceMuted'

--- Prepares the voice side of a session: its personal channel on the voice
--- server and its replicated state.
---@param sessionId number The player server id.
---@return nil
local function prepareSession(sessionId)
  VoiceChannels.ensurePlayerChannel(sessionId)
  Player(sessionId).state:set(MUTED_STATE_KEY, VoiceMute.isMuted(sessionId), true)
end

--- Prepares every session already in the world, after a restart.
---@return nil
function RestoreConnectedSessions()
  for _, id in ipairs(GetPlayers()) do
    local sessionId <const> = tonumber(id)

    if sessionId then
      prepareSession(sessionId)
    end
  end
end

AddEventHandler('playerJoining', function()
  prepareSession(source)
end)

AddEventHandler('playerDropped', function()
  VoiceMute.forget(source)
  VoiceGrants.forgetSession(source)
end)
