VoiceListening = {}

local STATE_KEY <const> = 'siku:state:voiceListening'
local EVENT_CHANGED <const> = 'siku:voice:listeningChanged'
local SPECTATE_OWNER <const> = 'spectate'

local listeners <const> = {}
local channels = {}
local active = false

--- Starts hearing one player, or remembers to retry when their channel
--- does not exist on the voice server yet.
---@param serverId number The player server id.
---@return nil
local function follow(serverId)
  if not VoiceMumble.channelExists(serverId) then
    channels[serverId] = false
    return
  end

  VoiceMumble.addListenChannel(serverId)
  channels[serverId] = true
end

--- Stops hearing one player.
---@param serverId number The player server id.
---@return nil
local function unfollow(serverId)
  if channels[serverId] then
    VoiceMumble.removeListenChannel(serverId)
  end

  channels[serverId] = nil
end

--- Stops hearing everyone.
---@return nil
local function unfollowAll()
  for serverId in pairs(channels) do
    unfollow(serverId)
  end
end

--- Turns listening on or off depending on whether any owner still asks
--- for it, and tells the world when it moves.
---@return nil
local function sync()
  local wanted <const> = next(listeners) ~= nil

  if wanted == active then
    return
  end

  active = wanted

  if not active then
    unfollowAll()
  end

  LocalPlayer.state:set(STATE_KEY, active, true)
  TriggerEvent(EVENT_CHANGED, active)
end

--- Follows the game spectator mode when the config asks for it.
---@return nil
local function followSpectate()
  if not VoiceConfig.listening.followSpectate then
    return
  end

  local spectating <const> = NetworkIsInSpectatorMode()

  if spectating and not listeners[SPECTATE_OWNER] then
    VoiceListening.start(SPECTATE_OWNER, Siku.name)
  elseif not spectating and listeners[SPECTATE_OWNER] then
    VoiceListening.stop(SPECTATE_OWNER)
  end
end

--- Whether the local client hears every player in scope, whatever the
--- distance.
---@return boolean listening Whether listening is on.
function VoiceListening.isActive()
  return active
end

--- Starts hearing every player in scope on behalf of a caller, until it
--- stops. Several callers may ask at once; it ends with the last one.
---@param owner string A key naming the caller.
---@param resource? string The resource asking, resolved when omitted.
---@return boolean started Whether the request was stored.
function VoiceListening.start(owner, resource)
  if not VoiceIsName(owner) then
    return VoiceRefuse('StartListening', 'owner')
  end

  listeners[owner] = resource or VoiceResolveOwner()
  sync()

  return true
end

--- Withdraws a request.
---@param owner string The key it was started with.
---@return boolean stopped Whether the request existed.
function VoiceListening.stop(owner)
  if not listeners[owner] then
    return false
  end

  listeners[owner] = nil
  sync()

  return true
end

--- Withdraws every request a resource made, when it stops.
---@param resource string The resource name.
---@return nil
function VoiceListening.clearOwner(resource)
  for owner, holder in pairs(listeners) do
    if holder == resource then
      listeners[owner] = nil
    end
  end

  sync()
end

--- Aligns the heard channels with the players in scope. Run by the
--- proximity scan, which already walks them.
---@param players table The active player indexes.
---@param localPlayer number The local player index.
---@return nil
function VoiceListening.update(players, localPlayer)
  followSpectate()

  if not active or not VoiceMumble.isReady() then
    return
  end

  local wanted <const> = {}

  for i = 1, #players do
    local playerId <const> = players[i]

    if playerId ~= localPlayer then
      local serverId <const> = GetPlayerServerId(playerId)

      wanted[serverId] = true

      if channels[serverId] ~= true then
        follow(serverId)
      end
    end
  end

  for serverId in pairs(channels) do
    if not wanted[serverId] then
      unfollow(serverId)
    end
  end
end

--- Forgets which channels are heard, after the engine dropped them across
--- a reconnection; the next update follows them again.
---@return nil
function VoiceListening.reapply()
  channels = {}
end

RegisterNetEvent('siku_voice:client:setListening', function(owner, enabled)
  if enabled then
    VoiceListening.start(owner, Siku.name)
  else
    VoiceListening.stop(owner)
  end
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= Siku.name then
    VoiceListening.clearOwner(resource)
    return
  end

  unfollowAll()
end)
