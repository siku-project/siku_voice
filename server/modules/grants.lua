VoiceGrants = {}

local grants <const> = {}

--- Remembers something the server pushed onto a client on behalf of a
--- resource, with how to take it back, so it does not outlive that
--- resource.
---@param resource string The resource that asked.
---@param sessionId number The player server id.
---@param key string What was pushed, unique per player and resource.
---@param revoke function Takes it back.
---@return nil
function VoiceGrants.track(resource, sessionId, key, revoke)
  grants[resource] = grants[resource] or {}
  grants[resource][sessionId] = grants[resource][sessionId] or {}
  grants[resource][sessionId][key] = revoke
end

--- Forgets something a resource took back itself.
---@param resource string The resource that asked.
---@param sessionId number The player server id.
---@param key string What was pushed.
---@return nil
function VoiceGrants.untrack(resource, sessionId, key)
  local sessions <const> = grants[resource]

  if not sessions or not sessions[sessionId] then
    return
  end

  sessions[sessionId][key] = nil

  if not next(sessions[sessionId]) then
    sessions[sessionId] = nil
  end

  if not next(sessions) then
    grants[resource] = nil
  end
end

--- Forgets everything pushed onto a player, when they leave.
---@param sessionId number The player server id.
---@return nil
function VoiceGrants.forgetSession(sessionId)
  for resource, sessions in pairs(grants) do
    sessions[sessionId] = nil

    if not next(sessions) then
      grants[resource] = nil
    end
  end
end

AddEventHandler('onResourceStop', function(resource)
  local sessions <const> = grants[resource]

  if not sessions then
    return
  end

  grants[resource] = nil

  for sessionId, keys in pairs(sessions) do
    if GetPlayerName(tostring(sessionId)) then
      for _, revoke in pairs(keys) do
        revoke()
      end
    end
  end
end)
