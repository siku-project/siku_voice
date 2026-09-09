VoiceMute = {}

local STATE_KEY <const> = 'siku:state:voiceMuted'
local EVENT_MUTED <const> = 'siku:voice:playerMuted'
local MUTE_PERMISSION <const> = 'voice.staff.mute'
local NOTIFICATION_RESOURCE <const> = 'siku_notification'
local STARTED <const> = 'started'
local CONSOLE <const> = 0
local MS_PER_SECOND <const> = 1000
local SECONDS_PER_MINUTE <const> = 60
local SECONDS_PER_HOUR <const> = 3600
local ROLES_POLL <const> = 500
local ROLES_TIMEOUT <const> = 60000

local mutes <const> = {}

--- Formats a duration in seconds for a person.
---@param seconds number The duration.
---@return string text The duration, such as '15m' or '2h'.
local function formatDuration(seconds)
  if seconds >= SECONDS_PER_HOUR and seconds % SECONDS_PER_HOUR == 0 then
    return ('%dh'):format(seconds // SECONDS_PER_HOUR)
  end

  if seconds >= SECONDS_PER_MINUTE and seconds % SECONDS_PER_MINUTE == 0 then
    return ('%dm'):format(seconds // SECONDS_PER_MINUTE)
  end

  return ('%ds'):format(seconds)
end

--- Sends a notification to a player when the notification resource runs.
---@param sessionId number The player server id.
---@param kind string The notification type.
---@param description string The text.
---@return nil
local function notify(sessionId, kind, description)
  if sessionId == CONSOLE then
    Siku.print.info(description)
    return
  end

  if GetResourceState(NOTIFICATION_RESOURCE) ~= STARTED then
    return
  end

  Siku.notification.show(sessionId, {
    type = kind,
    title = T('notify_muted_title'),
    description = description,
  })
end

--- Applies a mute state to the voice server and to the replicated state.
---@param sessionId number The player server id.
---@param muted boolean The new state.
---@return nil
local function applyMute(sessionId, muted)
  MumbleSetPlayerMuted(sessionId, muted)
  Player(sessionId).state:set(STATE_KEY, muted, true)
end

--- Whether a player is muted on the voice server.
---@param sessionId any The player server id.
---@return boolean muted Whether the player is muted.
function VoiceMute.isMuted(sessionId)
  if type(sessionId) ~= 'number' or not GetPlayerName(tostring(sessionId)) then
    return false
  end

  return mutes[sessionId] ~= nil
end

--- Mutes a player for a duration, replacing a running mute.
---@param sessionId number The player server id.
---@param duration? number Seconds (default: the configured duration).
---@param by? number The staff server id, or nil for a resource.
---@return boolean applied Whether the mute was set.
function VoiceMute.mute(sessionId, duration, by)
  if type(sessionId) ~= 'number' or not GetPlayerName(tostring(sessionId)) then
    return false
  end

  local seconds <const> = type(duration) == 'number' and duration > 0
    and math.floor(duration)
    or VoiceConfig.mute.defaultDuration
  local entry <const> = { expiresAt = GetGameTimer() + seconds * MS_PER_SECOND, by = by }

  mutes[sessionId] = entry
  applyMute(sessionId, true)
  notify(sessionId, 'warning', T('notify_muted', formatDuration(seconds)))
  TriggerEvent(EVENT_MUTED, sessionId, true, by, seconds)

  SetTimeout(seconds * MS_PER_SECOND, function()
    if mutes[sessionId] == entry then
      VoiceMute.unmute(sessionId)
    end
  end)

  return true
end

--- Unmutes a player.
---@param sessionId number The player server id.
---@param by? number The staff server id, or nil for a resource or expiry.
---@return boolean applied Whether a mute was lifted.
function VoiceMute.unmute(sessionId, by)
  if not mutes[sessionId] then
    return false
  end

  mutes[sessionId] = nil

  if GetPlayerName(tostring(sessionId)) then
    applyMute(sessionId, false)
    notify(sessionId, 'success', T('notify_unmuted'))
  end

  TriggerEvent(EVENT_MUTED, sessionId, false, by)

  return true
end

--- Forgets a mute when its player leaves.
---@param sessionId number The player server id.
---@return nil
function VoiceMute.forget(sessionId)
  mutes[sessionId] = nil
end

--- Whether the core has finished loading its roles.
---@return boolean ready Whether the roles are known.
local function areRolesReady()
  local roles <const> = Siku.permissions.getAllRoles()

  return type(roles) == 'table' and #roles > 0
end

--- Gives the configured role the mute permission, once the roles exist.
---@return nil
local function grantStaffPermission()
  local role <const> = VoiceConfig.staffRole

  if type(role) ~= 'string' or role == '' then
    return
  end

  local deadline <const> = GetGameTimer() + ROLES_TIMEOUT

  while not areRolesReady() do
    if GetGameTimer() >= deadline then
      return Siku.print.warn(T('staff_roles_unavailable', role))
    end

    Wait(ROLES_POLL)
  end

  if Siku.permissions.addPermissionToRole(role, MUTE_PERMISSION) then
    Siku.print.info(T('staff_permission_granted', MUTE_PERMISSION, role))
  end
end

Siku.command.register('voicemute', function(source, args)
  local seconds <const> = args.duration or VoiceConfig.mute.defaultDuration

  VoiceMute.mute(args.player, seconds, source ~= CONSOLE and source or nil)
  notify(source, 'success', T('notify_mute_applied', args.player, formatDuration(seconds)))
end, {
  permission = MUTE_PERMISSION,
  allowConsole = true,
  description = T('command_voicemute_description'),
  arguments = {
    { name = 'player', type = 'player', help = T('command_arg_player') },
    { name = 'duration', type = 'duration', optional = true, help = T('command_arg_duration'), min = 1 },
  },
})

Siku.command.register('voiceunmute', function(source, args)
  if not VoiceMute.unmute(args.player, source ~= CONSOLE and source or nil) then
    return notify(source, 'warning', T('notify_mute_not_muted', args.player))
  end

  notify(source, 'success', T('notify_mute_removed', args.player))
end, {
  permission = MUTE_PERMISSION,
  allowConsole = true,
  description = T('command_voiceunmute_description'),
  arguments = {
    { name = 'player', type = 'player', help = T('command_arg_player') },
  },
})

CreateThread(grantStaffPermission)
