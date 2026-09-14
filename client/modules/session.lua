VoiceSession = {}

local EVENT_CONNECTED <const> = 'siku:voice:connected'
local EVENT_DISCONNECTED <const> = 'siku:voice:disconnected'
local EVENT_TALKING <const> = 'siku:voice:talkingChanged'
local JOIN_RETRY_DELAY <const> = 1000
local SELF_ROUTE <const> = 'self'

local generation = 0
local talking = false

--- Brings the client into its personal channel and restores every piece of
--- voice state the engine lost. Each attempt carries a generation, so an
--- attempt overtaken by a newer connection event stops quietly.
---@return nil
local function initialize()
  generation = generation + 1

  local attempt <const> = generation

  VoiceMumble.setReady(false)
  VoiceScan.reset()

  while not VoiceMumble.joinPersonalChannel() do
    if attempt ~= generation or not VoiceMumble.isConnected() then
      return
    end

    Siku.print.warn(T('channel_join_failed', VoiceMumble.getServerId()))
    Wait(JOIN_RETRY_DELAY)
  end

  if attempt ~= generation then
    return
  end

  VoiceMumble.resetTarget()
  VoiceMumble.setReady(true)
  VoiceEffects.ensureConfigured()
  VoiceRouting.set(SELF_ROUTE, { channels = { VoiceMumble.getServerId() } }, Siku.name)
  VoiceProximity.reapply()
  VoiceRouting.reapply()
  VoiceRendering.reapply()
  VoiceListening.reapply()

  Siku.print.debug(('Voice ready on channel %d'):format(VoiceMumble.getServerId()))
  TriggerEvent(EVENT_CONNECTED)
end

--- Reads the microphone state and reports a change.
---@return nil
local function watchTalking()
  local now <const> = VoiceMumble.isReady() and VoiceMumble.isTalking()

  if now == talking then
    return
  end

  talking = now
  TriggerEvent(EVENT_TALKING, talking)
end

--- Whether the local voice is fully operational.
---@return boolean connected Whether routing reaches the voice server.
function VoiceSession.isConnected()
  return VoiceMumble.isConnected() and VoiceMumble.isReady()
end

--- Whether the local player is transmitting voice right now.
---@return boolean talking Whether the microphone is live.
function VoiceSession.isTalking()
  return talking
end

AddEventHandler('mumbleConnected', function(address, reconnecting)
  Siku.print.debug(('Voice server %s (%s)'):format(
    reconnecting and 'reconnected' or 'connected',
    VoiceEndpoint.describe(tostring(address))
  ))
  CreateThread(initialize)
end)

AddEventHandler('mumbleDisconnected', function(address)
  generation = generation + 1
  VoiceMumble.setReady(false)
  Siku.print.debug(('Voice server disconnected (%s)'):format(VoiceEndpoint.describe(tostring(address))))
  TriggerEvent(EVENT_DISCONNECTED)
end)

AddEventHandler('onClientResourceStart', function(resource)
  if resource == Siku.name and VoiceMumble.isConnected() then
    CreateThread(initialize)
  end
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= Siku.name then
    return
  end

  generation = generation + 1
  VoiceIndicator.hide()
  VoiceRendering.reset()
  VoiceMumble.release()
end)

Siku.timers.setInterval(VoiceConfig.intervals.talking, watchTalking)
