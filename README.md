# siku_voice

A modern, high-performance voice system for the SIKU ecosystem — providing proximity voice, communication channels, calls, radio integration, audio effects, and a clean API for immersive FiveM roleplay experiences. Built for reliability, extensibility, and seamless integration across SIKU resources.

![Version](https://img.shields.io/badge/version-1.0.2-4785bd)
![FiveM](https://img.shields.io/badge/fx__version-cerulean-4785bd)
![Lua](https://img.shields.io/badge/Lua-5.4-4785bd)

## Features

- **Voice foundation, not a feature pack** — proximity, routing, rendering, effects and state are the primitives; radio, phone calls, megaphones and staff tools are built on top by their own resources.
- **Two responsibilities, kept apart** — *who receives* a voice is decided by routes composed into a single engine voice target; *how* a voice is heard by each listener is decided by rendering layers (flat volume, effect). Neither knows about the other.
- **Proximity modes** — whisper, normal and shout out of the box; modes, ranges, order and default are configuration. Any resource can apply a temporary range of any value, with a priority, without creating a mode.
- **Ground range indicator** — a ring sized to the real range in effect appears briefly whenever the range changes, mode or override alike.
- **Diff-based routing** — nearby players are scanned on the client and only the players entering or leaving the range touch the engine. No target is ever rebuilt from scratch, no message reaches the voice server while nothing moves. A hysteresis keeps edge walkers stable.
- **Deterministic channels** — every player owns the channel numbered by their server id, created server-side the moment they join. Channels 1 to `sv_maxClients` are reserved to players; everything built later allocates above.
- **Effects registry** — game submixes declared in configuration or registered at runtime (radio filter, per-speaker output), referenced by name from rendering layers.
- **Lifecycle-proof** — connection, reconnection, resource restart and stop all restore or release the engine state: personal channel, voice target, range, routes and rendering layers.
- **Server authority where it matters** — mutes, audio mode, channel reservation and remote proximity control live server-side and rely on the core RBAC, commands, notifications and state bags.
- **Restrictions by reason** — a dead, cuffed or drowning player has their voice closed by the resource that knows why, on the scopes that matter (`proximity`, `radio`, `call`, anything, or all of them). Reasons stack: a scope opens again only when every reason closing it is gone, and no resource needs to know about the others.
- **Listening** — staff watching a scene hear every player in scope whatever the distance, on request or automatically in the game spectator mode, without being heard themselves.
- **Ownership-aware cleanup** — routes, rendering layers, range overrides, proximity filters, restrictions and listening requests remember the resource that set them and vanish when it stops, on the client and on the server alike.

## Dependencies

| Resource | Required | Purpose |
|---|---|---|
| [`siku_core`](https://github.com/siku-project/siku_core) | Yes | Framework core: SDK, keybinds, timers, locale, commands, permissions, notifications. |
| OneSync | Yes | Server ids, state bags and the built-in Mumble voice server. |

Optional: [`siku_hud`](https://github.com/siku-project/siku_hud) receives the mode and range through its `SetVoice` export when it runs.

## Installation

Pure Lua — nothing to build. Download the latest [release](https://github.com/siku-project/siku_voice/releases) or clone the repository into your resources folder.

### server.cfg

```cfg
ensure siku_core
ensure siku_voice
```

No other voice resource (pma-voice, mumble-voip, etc.) may run alongside.

## Configuration

All options live in `config/` and are documented inline.

| File | Options |
|---|---|
| `config/voice.lua` | `audio` (rendering `mode`, `sendingRangeOnly`, `nativeRangeFactor`), `proximity` (`defaultMode`, `modes`, `scanInterval`, `targetMargin`, `hysteresis`), `keybinds` (`pushToTalk`, `cycleProximity`), `indicator` (`enabled`, `duration`, `fade`, `style`, `color`, `alpha`), `listening` (`followSpectate`), `effects` (named submixes), `intervals`, `mute` (`defaultDuration`), `staffRole` |
| `config/translation.lua` | `language` (`fr` / `en`) |

### Keybinds

| Key | Action |
|---|---|
| `N` | Push to talk: held to speak. The game push-to-talk setting still applies, a player on voice activation transmits without it. |
| `F11` | Cycles the proximity mode. |

Defaults live in `config/voice.lua` (`keybinds`), every player can rebind them in the game settings, and setting one to `false` registers none.

### Commands

Granted automatically to the configured `staffRole`:

| Command | Permission | Purpose |
|---|---|---|
| `/voicemute <player> [duration]` | `voice.staff.mute` | Mutes a player on the voice server, for the given duration or the configured default. |
| `/voiceunmute <player>` | `voice.staff.mute` | Lifts a mute. |

## How it works

```
                 ┌──────────── who receives ────────────┐   ┌───── how it is heard ─────┐
 proximity scan ─┤ route 'proximity' (channels)         │   │ layer 'call'  volume 0.6  │
 phone (later) ──┤ route 'call'      (players)          ├──►│ layer 'radio' effect radio│
 radio (later) ──┤ route 'radio'     (players, enabled  │   │ …resolved per player,     │
                 │                    while the key is  │   │ highest priority wins     │
                 └─ composed into ONE voice target ─────┘   └───────────────────────────┘
```

- Every player sits in `Game Channel <server id>` and speaks through voice target 1.
- A **route** is a named set of recipients (player ids and/or channel numbers). Enabled routes are merged with reference counting; the engine only hears about a recipient the first time a route names it and the last time one drops it.
- The **proximity** route is fed by a scan of the players in scope every `scanInterval` ms: within `range × targetMargin` to enter, `+ hysteresis` to leave, only players whose channel already exists, filtered by any registered proximity filter. The engine still cuts by the real distance every packet, so the target only needs to be a superset.
- A **rendering layer** tells the local client how to hear one remote player: a flat volume that bypasses distance, an effect, or both. Several layers may stack on a player; the highest priority (then the latest) wins, and removing the last one hands the player back to plain proximity.
- An **effect** is a game submix. Effects need the `native` audio mode, which is the default.
- A **restriction** closes one or more scopes of the local voice for a named reason. `proximity` withholds the proximity route, `all` withholds every route and the microphone hold; any other scope (`radio`, `call`, one of your own) is only recorded, replicated and answered by `IsRestricted`, for the resource owning that scope to honour. Reasons are keys: `dead` set by a status resource and `cuffed` set by an inventory resource close `radio` independently, and the radio opens again only once both are cleared.
- **Listening** adds the channel of every player in scope to what the local client hears, whatever the distance. Every client also sends into its own channel, which is what makes it audible to a listener without changing who it talks to. Listening is requested by owner, ends with the last one, and follows the game spectator mode when `listening.followSpectate` is on.

## API

### Client exports

| Export | Arguments | Purpose |
|---|---|---|
| `IsConnected` | — | Whether voice is operational (connected and routed). |
| `IsTalking` | — | Whether the local microphone is live. |
| `HoldTalk` / `ReleaseTalk` | `owner` | Opens the microphone on behalf of a caller until released; several callers may hold it, it closes with the last one. A radio key uses this instead of touching the game controls. |
| `IsTalkHeld` | — | Whether a key or a resource holds the microphone open. |
| `GetProximity` | — | `{ mode, range, overridden, owner? }`. |
| `GetProximityModes` | — | The selectable modes in cycling order. |
| `SetProximityMode` | `name` | Selects a mode. |
| `CycleProximityMode` | — | Selects the next mode, returns its name. |
| `SetRangeOverride` | `owner, range, priority?` | Applies a temporary range in meters. Same owner replaces; highest priority wins. |
| `ClearRangeOverride` | `owner` | Removes a temporary range. |
| `ShowRangeIndicator` | `range?` | Shows the ground ring, sized to the range in effect by default. |
| `SetRoute` | `name, { players?, channels? }` | Replaces the recipients of a route (lists or sets of ids). A missing kind is left untouched. |
| `AddRouteRecipient` / `RemoveRouteRecipient` | `name, kind, id` | Incremental membership; `kind` is `'players'` or `'channels'`. |
| `EnableRoute` | `name, enabled` | Toggles a route without forgetting its recipients. |
| `ClearRoute` / `GetRoute` | `name` | Removes or reads a route. |
| `SetRendering` | `serverId, layer, { volume?, effect?, priority? }` | Sets how a remote player is heard. `volume` is 0 to 1 and bypasses distance. |
| `ClearRendering` | `serverId, layer?` | Removes one layer, or every layer of a player. |
| `ClearRenderingLayer` | `layer` | Removes one layer from every player. |
| `GetRendering` | `serverId, layer` | Reads a layer. |
| `RegisterEffect` | `name, { radioFx?, parameters?, output? }` | Registers a submix-backed effect. |
| `HasEffect` | `name` | Whether an effect is available. |
| `AddProximityFilter` / `RemoveProximityFilter` | `name, handler` / `name` | A filter receiving `(serverId, distance, playerId)`; returning `false` excludes the player from proximity. |
| `SetRestriction` | `reason, scopes?` | Closes scopes for a reason: one scope, a list, or nothing for every scope. Same reason replaces. |
| `ClearRestriction` | `reason` | Lifts a restriction. |
| `IsRestricted` | `scope` | `restricted, reasons`; a restriction on every scope closes any scope asked for. |
| `GetRestrictions` | — | `{ [scope] = { reasons } }`. |
| `StartListening` / `StopListening` | `owner` | Hears every player in scope whatever the distance, until the last owner stops. |
| `IsListening` | — | Whether listening is on. |

```lua
-- A megaphone: wider range while the item is used
exports.siku_voice:SetRangeOverride('megaphone', 40.0, 10)
exports.siku_voice:ClearRangeOverride('megaphone')

-- A phone call between two players (the phone owns the signalling)
exports.siku_voice:SetRoute('call', { players = { otherId } })
exports.siku_voice:SetRendering(otherId, 'call', { volume = 0.6, effect = 'call' })
-- hang up
exports.siku_voice:ClearRoute('call')
exports.siku_voice:ClearRendering(otherId, 'call')

-- A radio: members always known, routed only while the key is held
exports.siku_voice:SetRoute('radio', { players = members })
exports.siku_voice:EnableRoute('radio', false)
-- radio key pressed / released
exports.siku_voice:EnableRoute('radio', true)
exports.siku_voice:HoldTalk('radio')
exports.siku_voice:ReleaseTalk('radio')
exports.siku_voice:EnableRoute('radio', false)
-- a member starts transmitting: hear them flat, through the radio filter
exports.siku_voice:SetRendering(memberId, 'radio', { volume = 0.35, effect = 'radio', priority = 5 })
-- before opening the radio: honour whatever closed it
local restricted, reasons = exports.siku_voice:IsRestricted('radio')

-- A status resource: a dead player cannot speak anywhere
exports.siku_voice:SetRestriction('dead')
exports.siku_voice:ClearRestriction('dead')

-- An inventory: cuffed hands hold neither a radio nor a phone
exports.siku_voice:SetRestriction('cuffed', { 'radio', 'call' })

-- A staff tool: hear the scene being watched
exports.siku_voice:StartListening('spectate')
exports.siku_voice:StopListening('spectate')
```

### Server exports

| Export | Arguments | Purpose |
|---|---|---|
| `SetPlayerProximityMode` | `sessionId, mode` | Selects a mode on a player. |
| `SetPlayerRangeOverride` / `ClearPlayerRangeOverride` | `sessionId, owner, range, priority?` / `sessionId, owner` | Temporary range on a player. |
| `SetPlayerRestriction` / `ClearPlayerRestriction` | `sessionId, reason, scopes?` / `sessionId, reason` | Restriction on a player, lifted on its own when the calling resource stops. |
| `IsPlayerRestricted` | `sessionId, scope` | `restricted, reasons`, as the client replicated them. |
| `GetPlayerRestrictions` | `sessionId` | `{ [scope] = { reasons } }`. |
| `SetPlayerListening` | `sessionId, owner, enabled` | Listening on a player, withdrawn on its own when the calling resource stops. |
| `GetPlayerVoice` | `sessionId` | `{ mode, range, muted, channel, restrictions, listening }`. |
| `MutePlayer` / `UnmutePlayer` / `IsPlayerMuted` | `sessionId, duration?` / `sessionId` / `sessionId` | Server-side mute, in seconds. |
| `GetPlayerChannel` | `sessionId` | The personal channel of a player. |
| `GetReservedChannelRange` | — | `first, last` of the player range. |

### Events

Local events, for resources observing the voice state:

| Event | Side | Arguments | When |
|---|---|---|---|
| `siku:voice:connected` | client | — | The client is in its channel with its target armed (also after a reconnection or a restart). |
| `siku:voice:disconnected` | client | — | The voice server went away. |
| `siku:voice:proximityChanged` | client | `state, reason` | The range in effect changed; `reason` is `'mode'`, `'override'` or `'reconnect'`. |
| `siku:voice:talkingChanged` | client | `talking` | The local microphone went live or quiet. |
| `siku:voice:restrictionsChanged` | client | `restrictions` | A restriction was set or lifted; `{ [scope] = { reasons } }`. |
| `siku:voice:listeningChanged` | client | `listening` | Listening started or ended. |
| `siku:voice:playerMuted` | server | `sessionId, muted, by?, duration?` | A mute was set or lifted. |

### State bags

| Key | Owner | Value |
|---|---|---|
| `siku:state:voice` | client | `{ mode, range }` of the player, replicated. |
| `siku:state:voiceMuted` | server | Whether the player is muted. |
| `siku:state:voiceRestrictions` | client | `{ [scope] = { reasons } }` while any restriction is set, `false` otherwise. |
| `siku:state:voiceListening` | client | Whether the player hears every player in scope. |

## Structure

```
siku_voice/
├── client/modules/    # support, mumble, effects, rendering, routing, restrictions, proximity, listening, scan, indicator, session, talk, keybinds, api
├── server/modules/    # channels, audio, mute, grants, lifecycle, api
├── shared/modules/    # proximity modes registry
├── config/            # behavior, language
└── translations/      # fr / en
```

`client/modules/mumble.lua` is the only file touching the Mumble natives.

## Credits

Part of the [SIKU project](https://github.com/siku-project) — © Siku Studio.
