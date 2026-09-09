VoiceRendering = {}

local DEFAULT_PRIORITY <const> = 0

local layers <const> = {}
local applied <const> = {}
local sequence = 0

--- Picks the layer that decides how a player is heard: the highest
--- priority, and among equals the one set last.
---@param playerLayers table The layers of one player.
---@return table? layer The winning layer, or nil when none is left.
local function resolve(playerLayers)
  local winner = nil

  for _, layer in pairs(playerLayers) do
    if not winner or layer.priority > winner.priority or
      (layer.priority == winner.priority and layer.order > winner.order) then
      winner = layer
    end
  end

  return winner
end

--- Pushes the resolved rendering of a player to the engine, touching only
--- what changed since the last push.
---@param target number The player server id.
---@return nil
local function apply(target)
  local winner <const> = layers[target] and resolve(layers[target]) or nil
  local current <const> = applied[target] or {}
  local volume <const> = winner and winner.volume or nil
  local submix <const> = winner and winner.effect and VoiceEffects.get(winner.effect) or nil

  if current.volume ~= volume then
    VoiceMumble.setVolume(target, volume)
  end

  if current.submix ~= submix then
    VoiceMumble.setSubmix(target, submix)
  end

  if not winner then
    applied[target] = nil
    return
  end

  applied[target] = { volume = volume, submix = submix }
end

--- Checks the options a layer is set with.
---@param options any The raw options.
---@return string? fault The invalid field name, or nil when valid.
local function validateOptions(options)
  if type(options) ~= 'table' then
    return 'options'
  end

  if options.volume ~= nil and (type(options.volume) ~= 'number' or options.volume < 0 or options.volume > 1) then
    return 'volume'
  end

  if options.effect ~= nil and not VoiceIsName(options.effect) then
    return 'effect'
  end

  if options.priority ~= nil and type(options.priority) ~= 'number' then
    return 'priority'
  end

  return nil
end

--- Sets how a remote player is heard, on a named layer. A layer carries a
--- flat volume, an effect, or both; the highest priority layer wins.
---@param target number The player server id.
---@param layer string The layer name, owned by the caller.
---@param options table { volume? (0 to 1), effect? (name), priority? }.
---@param owner? string The resource setting it, resolved when omitted.
---@return boolean applied Whether the layer was stored.
function VoiceRendering.set(target, layer, options, owner)
  local player <const> = VoiceToId(target)

  if not player then
    return VoiceRefuse('SetRendering', 'target')
  end

  if not VoiceIsName(layer) then
    return VoiceRefuse('SetRendering', 'layer')
  end

  local fault <const> = validateOptions(options)

  if fault then
    return VoiceRefuse('SetRendering', fault)
  end

  if options.effect and not VoiceEffects.has(options.effect) then
    Siku.print.warn(T('effect_unknown', options.effect))
  end

  sequence = sequence + 1
  layers[player] = layers[player] or {}
  layers[player][layer] = {
    volume = options.volume and options.volume + 0.0 or nil,
    effect = options.effect,
    priority = options.priority or DEFAULT_PRIORITY,
    order = sequence,
    owner = owner or VoiceResolveOwner(),
  }

  apply(player)

  return true
end

--- Removes one layer from a player.
---@param target number The player server id.
---@param layer string The layer name.
---@return boolean removed Whether the layer existed.
function VoiceRendering.clear(target, layer)
  local playerLayers <const> = layers[target]

  if not playerLayers or not playerLayers[layer] then
    return false
  end

  playerLayers[layer] = nil

  if not next(playerLayers) then
    layers[target] = nil
  end

  apply(target)

  return true
end

--- Removes every layer from a player.
---@param target number The player server id.
---@return boolean removed Whether the player had any layer.
function VoiceRendering.clearPlayer(target)
  if not layers[target] then
    return false
  end

  layers[target] = nil
  apply(target)

  return true
end

--- Removes one layer from every player.
---@param layer string The layer name.
---@return number count How many players lost the layer.
function VoiceRendering.clearLayer(layer)
  local count = 0

  for target in pairs(layers) do
    if VoiceRendering.clear(target, layer) then
      count = count + 1
    end
  end

  return count
end

--- Removes every layer a resource set, when it stops.
---@param owner string The resource name.
---@return nil
function VoiceRendering.clearOwner(owner)
  for target, playerLayers in pairs(layers) do
    for name, layer in pairs(playerLayers) do
      if layer.owner == owner then
        VoiceRendering.clear(target, name)
      end
    end
  end
end

--- Reads the layer set on a player.
---@param target number The player server id.
---@param layer string The layer name.
---@return table? layer A copy { volume, effect, priority }, or nil.
function VoiceRendering.get(target, layer)
  local entry <const> = layers[target] and layers[target][layer] or nil

  if not entry then
    return nil
  end

  return { volume = entry.volume, effect = entry.effect, priority = entry.priority }
end

--- Pushes every layer again, after the engine forgot them across a
--- reconnection.
---@return nil
function VoiceRendering.reapply()
  for target in pairs(applied) do
    applied[target] = nil
  end

  for target in pairs(layers) do
    apply(target)
  end
end

--- Hands every rendered player back to the engine defaults, keeping the
--- layers so a later reapply restores them.
---@return nil
function VoiceRendering.reset()
  for target in pairs(applied) do
    VoiceMumble.setVolume(target, nil)
    VoiceMumble.setSubmix(target, nil)
    applied[target] = nil
  end
end

RegisterNetEvent('onPlayerDropped', function(target)
  local player <const> = VoiceToId(target)

  if player then
    VoiceRendering.clearPlayer(player)
  end
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= Siku.name then
    VoiceRendering.clearOwner(resource)
  end
end)
