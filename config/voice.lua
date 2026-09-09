VoiceConfig = {
  --- Audio
  ---
  --- How the game renders the voices it receives. The server replicates
  --- these choices to every client at startup, so they live here rather
  --- than in server.cfg.
  audio = {
    --- Rendering mode.
    ---
    --- • 'native' (default): every voice becomes a game audio entity —
    ---   occlusion, reverberation and interiors apply, and audio effects
    ---   (radio, phone) become available. Recommended.
    --- • '2d': flat volume with a quadratic falloff, no spatialization.
    --- • '3d': positional audio relative to the camera. Deprecated by FiveM.
    --- • 'default': full volume inside the range, silence beyond it.
    mode = 'native',

    --- Whether a listener trusts only the range the talker transmits.
    ---
    --- Keeps a modified client from widening its own hearing range.
    sendingRangeOnly = true,

    --- Conversion applied to a range before it reaches the engine in native
    --- mode, where the value scales an attenuation curve instead of cutting
    --- at a distance. 0.4 makes a configured range of 7 audible up to
    --- roughly 7 meters in practice. Tune in game if voices carry too far
    --- or fade too early.
    nativeRangeFactor = 0.4,
  },

  --- Proximity
  ---
  --- The modes a player cycles through, and how the nearby players a voice
  --- is sent to are discovered.
  proximity = {
    --- The mode a player starts with. Must name one of the modes below.
    defaultMode = 'normal',

    --- The selectable modes, in cycling order. Each has a unique name, used
    --- by the API and as the translation key 'proximity_<name>', and a
    --- range in meters. Add, remove or reorder freely.
    modes = {
      { name = 'whisper', range = 3.0 },
      { name = 'normal', range = 7.0 },
      { name = 'shout', range = 15.0 },
    },

    --- How often (ms) nearby players are scanned.
    scanInterval = 300,

    --- Multiplier applied to the range when deciding who receives a voice.
    --- The engine still cuts by real distance: sending a little wider than
    --- the audible range only keeps the edges smooth.
    targetMargin = 1.25,

    --- Extra meters a player may drift beyond the scan range before being
    --- dropped as a recipient, so someone walking along the edge is not
    --- added and removed every tick.
    hysteresis = 2.0,
  },

  --- Keybinds
  ---
  --- Default keys, registered through the core so every player can rebind
  --- them in the game settings. Set one to false to register no keybind.
  keybinds = {
    --- Held to speak. The game push-to-talk setting still applies: a player
    --- on voice activation transmits without it.
    pushToTalk = 'N',

    --- Cycles through the proximity modes.
    cycleProximity = 'F11',
  },

  --- Indicator
  ---
  --- The ring drawn on the ground around the player when their range
  --- changes, sized to the real range in effect.
  indicator = {
    enabled = true,

    --- How long (ms) the ring stays visible, fades included.
    duration = 2000,

    --- Length (ms) of the fade in and of the fade out.
    fade = 350,

    --- 'thin' or 'thick'.
    style = 'thin',

    color = { r = 150, g = 205, b = 255 },

    --- Opacity at full visibility, 0 to 255.
    alpha = 140,
  },

  --- Effects
  ---
  --- Audio effects a voice can be rendered through, each backed by a game
  --- submix. They require the 'native' audio mode. Other resources ask for
  --- one by name when they render a voice, and may register more at runtime.
  ---
  --- Per effect:
  --- - radioFx: whether the game radio filter is applied.
  --- - parameters: radio filter parameters by name, integers or floats.
  --- - output: per speaker volumes, 0 to 1 (frontLeft, frontRight,
  ---   rearLeft, rearRight, channel5, channel6). Missing ones default to
  ---   1.0 for the front and 0.0 for the rear.
  effects = {
    radio = {
      radioFx = true,
      output = { frontLeft = 1.0, frontRight = 0.25 },
    },

    call = {
      radioFx = false,
      output = { frontLeft = 0.15, frontRight = 0.55 },
    },
  },

  --- Intervals
  ---
  --- How often (ms) the local talking state is read.
  intervals = {
    talking = 100,
  },

  --- Mute
  ---
  --- Server side mutes, applied by staff or by other resources.
  mute = {
    --- Duration (seconds) of a mute given without one.
    defaultDuration = 900,
  },

  --- The role that receives this resource's staff permissions at startup.
  ---
  --- Roles inherit down the primary chain, so naming a grade gives the
  --- permission to that grade and every one above it. Set it to false to be
  --- granted nothing and attach the permissions yourself.
  ---
  --- Default: 'admin'
  staffRole = 'admin',
}
