# NCPD Patrol v0.3b

Start Shift spawns one NCPD partner automatically. No NPC targeting or model capture is required.

**[Download the ready-to-install v0.3b ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_v0.3b_Auto_Shift_Partner.zip)**

## Installation

1. Exit Cyberpunk 2077.
2. Download the installation ZIP linked above.
3. Extract it into the game installation folder containing `bin` and `r6`, replacing both existing NCPDPatrol Lua files.
4. Start the game, load a save and click **Start Shift** in **NCPD Patrol - v0.3b**, or use the existing duty hotkey.

Use the installation ZIP above to get the correct game-relative folder layout.

## Partner controls

- **Start Shift:** automatically call one NCPD partner.
- **Dismiss partner:** dismiss the partner for the current shift.
- **Spawn partner:** call a replacement manually while on duty.
- **End Shift:** dismiss the active or pending partner.

Repeated requests cannot create a second partner while one is active or pending. Duty state resets on game reload.

The default model is `Character.cvi_ncpd_police_ranged2_copperhead_ma`, matching the officer from the working v0.3a test. The follower AI, car controls and outfit handling are retained.

## Requirements for Cyberpunk 2077 2.5

- Cyber Engine Tweaks **1.38.0 or newer with support for patch 2.5**.
- Codeware **1.21.4**.
- RED4ext **1.31.0 or newer**.
- TweakXL for the bundled police Hella tweak.

## Validation

The user confirmed v0.3a spawning, following, vehicle entry, combat assistance, Dismiss and End Shift in game after updating CET. The v0.3b automatic shift changes passed simulated CET/Codeware lifecycle checks using LuaJIT 2.1. The v0.3b build has not yet been tested in game.

The source is in `bin/` and `r6/`; the installation archive is in `releases/`.

ZIP SHA-256: `ef5831167b3bbc27faf893fee594ee0da8d3786f492ad23c03061cf91334d12d`
