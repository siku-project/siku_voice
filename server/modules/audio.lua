local NATIVE_MODE <const> = 'native'
local TRUE <const> = 'true'
local FALSE <const> = 'false'

local MODE_CONVARS <const> = {
  native = 'voice_useNativeAudio',
  ['2d'] = 'voice_use2dAudio',
  ['3d'] = 'voice_use3dAudio',
}

local SENDING_RANGE_CONVAR <const> = 'voice_useSendingRangeOnly'

--- Resolves the configured audio mode, falling back to native when the
--- name matches nothing the engine knows.
---@return string mode The audio mode.
local function resolveMode()
  local mode <const> = VoiceConfig.audio.mode

  if mode == 'default' or MODE_CONVARS[mode] then
    return mode
  end

  Siku.print.warn(T('audio_unknown_mode', tostring(mode)))

  return NATIVE_MODE
end

--- Replicates the audio choices of the config to every client: exactly one
--- rendering mode on, the others off.
---@return nil
function ApplyAudioSettings()
  local mode <const> = resolveMode()

  for name, convar in pairs(MODE_CONVARS) do
    SetConvarReplicated(convar, name == mode and TRUE or FALSE)
  end

  SetConvarReplicated(SENDING_RANGE_CONVAR, VoiceConfig.audio.sendingRangeOnly and TRUE or FALSE)

  Siku.print.debug(('Audio mode: %s'):format(mode))
end
