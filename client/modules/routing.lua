VoiceRouting = {}

local KINDS <const> = { players = true, channels = true }

local routes <const> = {}
local counts <const> = { players = {}, channels = {} }
local applied <const> = { players = {}, channels = {} }
local suspended = false

local pushers <const> = {
  players = {
    add = function(id)
      VoiceMumble.addTargetPlayer(id)
    end,
    remove = function(id)
      VoiceMumble.removeTargetPlayer(id)
    end,
  },
  channels = {
    add = function(id)
      VoiceMumble.addTargetChannel(id)
    end,
    remove = function(id)
      VoiceMumble.removeTargetChannel(id)
    end,
  },
}

--- Aligns one recipient on the engine with whether any enabled route still
--- names it, touching the engine only on an actual change.
---@param kind string 'players' or 'channels'.
---@param id number The recipient id.
---@return nil
local function sync(kind, id)
  local wanted <const> = not suspended and counts[kind][id] ~= nil
  local current <const> = applied[kind][id] == true

  if wanted == current then
    return
  end

  if wanted then
    pushers[kind].add(id)
    applied[kind][id] = true
    return
  end

  pushers[kind].remove(id)
  applied[kind][id] = nil
end

--- Counts one more enabled route naming a recipient.
---@param kind string 'players' or 'channels'.
---@param id number The recipient id.
---@return nil
local function retain(kind, id)
  counts[kind][id] = (counts[kind][id] or 0) + 1
  sync(kind, id)
end

--- Counts one enabled route less naming a recipient.
---@param kind string 'players' or 'channels'.
---@param id number The recipient id.
---@return nil
local function release(kind, id)
  local count <const> = (counts[kind][id] or 0) - 1

  counts[kind][id] = count > 0 and count or nil
  sync(kind, id)
end

--- Turns a list or a set of ids into a set, dropping what is not an id.
---@param value any A list { 1, 2 } or a set { [1] = true }.
---@return table set The ids as keys.
local function toSet(value)
  local set <const> = {}

  if type(value) ~= 'table' then
    return set
  end

  for key, entry in pairs(value) do
    local id <const> = VoiceToId(entry == true and key or entry)

    if id then
      set[id] = true
    end
  end

  return set
end

--- Gets a route, creating an empty enabled one when it is missing.
---@param name string The route name.
---@param owner? string The resource creating it.
---@return table route The route.
local function ensureRoute(name, owner)
  local route = routes[name]

  if not route then
    route = {
      enabled = true,
      players = {},
      channels = {},
      owner = owner or VoiceResolveOwner(),
    }
    routes[name] = route
  end

  return route
end

--- Replaces the recipients of one kind on a route, applying only the
--- difference to the engine.
---@param route table The route.
---@param kind string 'players' or 'channels'.
---@param wanted table The new set of ids.
---@return nil
local function replaceKind(route, kind, wanted)
  local current <const> = route[kind]

  for id in pairs(current) do
    if not wanted[id] then
      current[id] = nil

      if route.enabled then
        release(kind, id)
      end
    end
  end

  for id in pairs(wanted) do
    if not current[id] then
      current[id] = true

      if route.enabled then
        retain(kind, id)
      end
    end
  end
end

--- Sets the recipients of a route, replacing the previous ones. A missing
--- kind is left untouched.
---@param name string The route name, owned by the caller.
---@param recipients table { players?, channels? }, each a list or a set of ids.
---@param owner? string The resource setting it, resolved when omitted.
---@return boolean applied Whether the route was updated.
function VoiceRouting.set(name, recipients, owner)
  if not VoiceIsName(name) then
    return VoiceRefuse('SetRoute', 'name')
  end

  if type(recipients) ~= 'table' then
    return VoiceRefuse('SetRoute', 'recipients')
  end

  local route <const> = ensureRoute(name, owner)

  for kind in pairs(KINDS) do
    if recipients[kind] ~= nil then
      replaceKind(route, kind, toSet(recipients[kind]))
    end
  end

  return true
end

--- Adds one recipient to a route.
---@param name string The route name.
---@param kind string 'players' or 'channels'.
---@param id number The recipient id.
---@param owner? string The resource adding it, resolved when omitted.
---@return boolean added Whether the recipient is now on the route.
function VoiceRouting.add(name, kind, id, owner)
  if not VoiceIsName(name) then
    return VoiceRefuse('AddRouteRecipient', 'name')
  end

  if not KINDS[kind] then
    return VoiceRefuse('AddRouteRecipient', 'kind')
  end

  local recipient <const> = VoiceToId(id)

  if not recipient then
    return VoiceRefuse('AddRouteRecipient', 'id')
  end

  local route <const> = ensureRoute(name, owner)

  if route[kind][recipient] then
    return true
  end

  route[kind][recipient] = true

  if route.enabled then
    retain(kind, recipient)
  end

  return true
end

--- Removes one recipient from a route.
---@param name string The route name.
---@param kind string 'players' or 'channels'.
---@param id number The recipient id.
---@return boolean removed Whether the recipient was on the route.
function VoiceRouting.remove(name, kind, id)
  local route <const> = routes[name]
  local recipient <const> = VoiceToId(id)

  if not route or not KINDS[kind] or not recipient or not route[kind][recipient] then
    return false
  end

  route[kind][recipient] = nil

  if route.enabled then
    release(kind, recipient)
  end

  return true
end

--- Enables or disables a route without forgetting its recipients: a radio
--- keeps its members and only routes while its key is held.
---@param name string The route name.
---@param enabled boolean Whether the route contributes recipients.
---@return boolean changed Whether the state moved.
function VoiceRouting.enable(name, enabled)
  local route <const> = routes[name]
  local wanted <const> = enabled == true

  if not route or route.enabled == wanted then
    return false
  end

  route.enabled = wanted

  local step <const> = wanted and retain or release

  for kind in pairs(KINDS) do
    for id in pairs(route[kind]) do
      step(kind, id)
    end
  end

  return true
end

--- Removes a route and every recipient it contributed.
---@param name string The route name.
---@return boolean removed Whether the route existed.
function VoiceRouting.clear(name)
  local route <const> = routes[name]

  if not route then
    return false
  end

  VoiceRouting.enable(name, false)
  routes[name] = nil

  return true
end

--- Removes every route a resource set, when it stops.
---@param owner string The resource name.
---@return nil
function VoiceRouting.clearOwner(owner)
  for name, route in pairs(routes) do
    if route.owner == owner then
      VoiceRouting.clear(name)
    end
  end
end

--- Reads a route.
---@param name string The route name.
---@return table? route A copy { enabled, players, channels }, or nil.
function VoiceRouting.get(name)
  local route <const> = routes[name]

  if not route then
    return nil
  end

  local copy <const> = { enabled = route.enabled, players = {}, channels = {} }

  for kind in pairs(KINDS) do
    for id in pairs(route[kind]) do
      copy[kind][id] = true
    end
  end

  return copy
end

--- Lists the route names.
---@return table names The route names, sorted.
function VoiceRouting.list()
  local names <const> = {}

  for name in pairs(routes) do
    names[#names + 1] = name
  end

  table.sort(names)

  return names
end

--- Whether a recipient currently receives the local voice.
---@param kind string 'players' or 'channels'.
---@param id number The recipient id.
---@return boolean targeted Whether an enabled route names it.
function VoiceRouting.isRecipient(kind, id)
  return KINDS[kind] ~= nil and counts[kind][id] ~= nil
end

--- Withholds every recipient from the engine, or hands them all back,
--- without touching the routes: a restricted player keeps their routes
--- and gets them back the moment the restriction lifts.
---@param value boolean Whether the routes are withheld.
---@return boolean changed Whether the state moved.
function VoiceRouting.suspend(value)
  local wanted <const> = value == true

  if wanted == suspended then
    return false
  end

  suspended = wanted

  for kind in pairs(KINDS) do
    for id in pairs(counts[kind]) do
      sync(kind, id)
    end
  end

  return true
end

--- Whether the routes are withheld from the engine.
---@return boolean suspended Whether nothing receives the local voice.
function VoiceRouting.isSuspended()
  return suspended
end

--- Pushes every recipient again, after the engine emptied its target
--- across a reconnection.
---@return nil
function VoiceRouting.reapply()
  for kind in pairs(KINDS) do
    for id in pairs(applied[kind]) do
      applied[kind][id] = nil
    end

    for id in pairs(counts[kind]) do
      sync(kind, id)
    end
  end
end

AddEventHandler('onResourceStop', function(resource)
  if resource ~= Siku.name then
    VoiceRouting.clearOwner(resource)
  end
end)
