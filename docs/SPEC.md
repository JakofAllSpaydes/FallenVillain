# FALL — Game Design & Technical Spec

Oct 7, 2026 · @Jack

## 1. Vision & pillars

FALL is a Roblox supervillain game about one feeling: launching so high the planet becomes a ball beneath you, hanging weightless for a few seconds, then falling back down faster than anything should move and hitting a town like a meteor. Every weapon is a form of falling. Every system makes the arc better. Nothing else exists.

Primary inspiration is Gustave Doré's Paradise Lost engraving of Satan cast out of Heaven: a winged figure above a small planet, stars above, clouds below, a shaft of light. Tone is monochrome, grand, quiet, a little menacing. You are the thing that falls from the sky and ruins cities. Skins (jetpacks, boosters, mech wings) can get sillier; the core tone doesn't move.

**Pillars (in priority order):**

1. **The arc is the game.** Burst, hang, fall, impact. Each phase has its own feel, sound, camera and silence. A feature that doesn't make the arc better is cut.
2. **Every attack is a form of falling.** The aimed dive is the punch. The landing is the smash. The laser only exists in the air and scales with altitude. Standing still is always the worst way to play.
3. **Juice is the product.** Shake, FOV, hitstop, ducking, trails, craters, chunks flying off buildings are first-class features with their own tuning tables.
4. **The sky is the map.** A small surface with towns to ruin; a tall sky to earn. Height is score, reward and leaderboard.
5. **Four inputs, deep.** Space, hold space, left click, right click. Learned in 10 seconds. The combo of apex → aimed dive → smash → laser sweep takes hours to master.
6. **Money comes from the sky.** Destruction pays, and destruction multiplies with impact speed and altitude. No pets, no gacha, no lobby.

**Not this game:** a standing-still laser sim, a shooter, a voxel destruction sandbox, a tycoon.

**Target:** Roblox, mobile-first, 12–16 player servers, sessions of 15–40 minutes.

**MVP scope (this doc):** one planet, one town cluster plus scattered destructibles, burst/hop/glide/aimed dive, smash shockwave, altitude-scaled laser, prefab chunk destruction, money from destruction, one upgrade track (Power), one skin swap (demon wings → jetpack) to prove the theme flex. Cut for MVP: rockets, planet transitions, rebirth, multiple stat trees, shards.

## 2. Core loop

Two nested loops. The inner loop is always available and always fun. The outer loop is rare and spectacular, and it ends in a town.

**Inner loop (every few seconds): Hop → Glide → Aimed dive → Smash.** Hop into a short glide, pick a target, hold to dive at it, hit it. Small impacts, small money, and every hop and every hit adds Burst charge. Players cross the map by flying, and they wreck things on the way.

**Outer loop (every 1–3 minutes): Charge → Burst → Hang → Fall → Impact → Rampage.**

| Phase | Player does | Duration | Payoff |
| --- | --- | --- | --- |
| Charge | Idle fills, hits fill faster; hold space to release | 20–90 s to fill, then player-chosen | Tension: ground cracks, light gathers |
| Burst | Release space | 0.3 s ignition, 3–8 s ascent | Cannon shot. World drops away. Planet appears |
| Hang | Admires, picks a target below | 2–6 s | The Doré frame. Silence. Curvature. Towns visible as lights |
| Fall | Hold left click to dive at the aim point; release to glide and re-aim; hold right click to laser | 6–25 s | Momentum, roar, the town rushing up |
| Impact | Nothing: hits where aimed | 0.5 s | Smash shockwave flattens everything in a radius set by speed. Combo starts |
| Rampage | Hop/dive/laser through the rubble while the combo timer runs | 5–15 s | Money multiplied by the combo and the impact altitude |

**What makes it a game:**

- **Height is the multiplier.** Every impact's money is multiplied by the altitude the dive started from. A mach-10 smash from the Edge band on a full town is the biggest number in the game, and it's free: no button, just the arc done well.
- **Combo.** Each destroyed object within 4 s of the last extends the combo. Multiplier 1× → 5× over 20 hits. The post-impact rampage is where skilled players double their earnings.
- **Aim is a choice.** Diving straight down is fastest. Steering to a better target costs speed. The swoop (release at speed) lets you re-aim without losing much.
- **The fall feeds the charge.** Hits, rings and thermals on the way down add charge. A good run means a faster next burst.
- **Height unlocks sky.** New altitude bands have new looks and bigger laser reach.

**Rules:** the player can never gain altitude in the air beyond small boosts. The laser does not fire on the ground above cutter strength. Apex is earned on the ground; power is spent from the sky.

## 3. Movement & combat spec

All values are starting points in studs and seconds. Every value lives in one `Tuning` ModuleScript, hot-reloadable in Studio. Default Roblox gravity is 196.2; we override it per state.

**Inputs:**

| Input | On ground | In air (after apex or hop) |
| --- | --- | --- |
| Space tap | Hop | Flap (tiny lift, costs glide energy) |
| Space hold | Charge Burst (if charge full) else charged Hop | nothing (reserved) |
| Left click / tap hold | Smash (weak ground pound, needs a small hop first) | **Aimed dive**: tuck and rocket toward the aim point, keep holding to dive harder |
| Left release | — | Swoop: wings open, speed converts to lift, re-aim |
| Right click / second thumb hold | Cutter: weak short laser for trees and signs | **Laser**: beam at the aim point, width and damage scale with altitude |
| Move / drag | Walk / orbit | Aim point moves on screen; glide steering follows aim |

Mobile: left half of screen is a virtual stick for aim, right half tap = hop, right half hold = dive, a single laser button bottom-right. Desktop: mouse aims.

**State table:**

| State | Entry | Gravity | Max speed | Steering | Exit |
| --- | --- | --- | --- | --- | --- |
| Grounded | Landed | 196 | 24 walk | Full | Hop, Charge |
| Charging | Hold space with full charge | rooted | 0 | None | Release → Burst; cancel if released before 0.4 s |
| Burst | Release from Charging | 0 for 0.3 s, then 60 | `350 + 45 × (Power−1)`, cap 1,400 | None for 0.5 s, then 15% drift | Vertical velocity ≤ 5 → Hang |
| Hang | Vertical velocity near 0 | 4 | 8 drift | Slow drift, aim cursor active | Timer (2–6 s) or left hold → Dive |
| Glide | Default after Hang or Hop apex | 40 | 90 forward, sink 12–30 | Full, follows aim | Left hold → Dive, land, Flap |
| Dive (aimed) | Left hold in air | 196 → 260 ramping over 2 s, plus thrust toward aim | 420 terminal | Steers toward aim point at 35°/s; cone widens the longer you hold | Release → Swoop; ground → Impact |
| Swoop | Left release from Dive above speed 150 | 40 | Carries dive speed, bleeds 35%/s | Full, strong pitch-up | Speed < 90 → Glide |
| Impact | Touch ground or structure from Dive | 196 | 0 | None | 0.4 s hitstop/recovery → Grounded, combo window open |
| Landing | Touch ground from Glide/Swoop | 196 | 0 | None | 0.8 s → Grounded |

**Aimed dive:** on left hold, the player tucks and gets a thrust toward the aim point: `thrust = 120 studs/s²` in the aim direction, plus the state gravity. Steering authority starts at ±25° and widens to ±60° after 1 s of hold, so a short tap-dive is a straight punch and a long hold lets you curve. Holding longer also increases terminal speed from 380 to 420 ("diving harder"). Impact strength = speed at contact. From a hop, a dive is short and weak (speed 100–180). From apex, it's the meteor.

**Smash (impact):** on Impact state entry, spawn a shockwave with `radius = 6 + speed / 8` studs (hop dive ≈ 20, terminal ≈ 58). Everything destructible in radius takes `damage = speed × 2`. Objects are flung outward with velocity proportional to proximity. The player takes 0.4 s of recovery (hitstop + kneel), then can hop or laser. Ground smash (left click on ground) = a 10-stud hop into an auto-dive, giving a weak smash with radius 14; it exists so the input always does something.

**Laser:** right hold in air. A beam from the character to the aim point, max range 1,200 studs. `width = 2 + altitude / 1,000` studs (2 at ground, 14 at Edge band), `damage per second = 40 + altitude / 40`. Costs laser energy: a 0–100 meter that refills only on the ground at 25/s, drains 30/s while firing. So one full apex gives about 3 s of god-laser. The beam sweeps with the aim; sweeping across a town is the move. On ground, the same input is the Cutter: width 1, damage 25/s, trees and signs only, no cost. Laser in air also slows the fall 30% while firing (wings spread to brace), so it's a trade against impact speed.

**Hop:** instant, 60 studs up at base, 120 charged (hold up to 0.4 s). Apex float of 0.35 s where gravity drops to 20. Chain-hopping within 0.2 s of landing adds 10% height per chain up to 3. Fills 4% Burst charge.

**Glide energy:** hidden 0–100 meter. Starts at 100 after apex or hop. Drains 6/s in glide, 0 in dive, refills 20 per ring, 10 per thermal. Below 20, sink rate doubles and wings strain. At 0, forced dive. Hard floor against infinite floating.

**Swoop:** on left release from Dive at speed `v`, upward velocity `v × 0.55` capped at 160, forward speed kept, cooldown 1.2 s. Lets you re-aim at a better target without losing the run. Total air gain per fall capped at 25% of burst height.

**Burst charge sources:** idle 1.2%/s (\~85 s to full), hop +4%, any destroyed object +2%, ring +12%, thermal +6%, impact +15% × (dive start height / max height). An engaged player bursts every 40–60 s; an idle one every 90 s.

**Burst altitude by Power:** with gravity 60 in Burst and 40 in Glide, velocity 350 (Power 1) reaches \~1,000 studs, 800 (Power 11) \~5,300, 1,400 (Power 25) \~16,000. Tune gravity, not velocity, to land on the bands in §5.

## 4. The arc, moment by moment (juice spec)

This section is the product. Each phase lists camera, VFX, SFX, animation, haptics and UI. All timing values are tunable; all effects are client-side unless marked (R) for replicated. Implement in the order listed within each phase; the first three items of each phase are the minimum for the phase to feel right.

### 4.1 Charge (hold on ground, charge full)

- **Animation:** character drops to one knee over 0.25 s, wings fold tight against the back, head bows. Idle breathing loop with slow 1.5 s cycle.
- **Ground:** circular crack decal spawns under the player at 0.3 s, grows from 4 to 14 studs radius over the hold. Pebble particles lift 1–3 studs and hover, slowly rotating (R, low count for others).
- **Light:** a PointLight at the chest ramps 0 → 8 brightness. Wing material emissive ramps 0 → 1. A thin vertical beam (Beam object, 0.5 stud wide) rises from the player, alpha 0 → 0.4, visible server-wide (R).
- **Camera:** FOV eases 70 → 62 over the hold (narrowing = focus). Subtle shake, amplitude 0.05 → 0.3 studs, frequency 20 Hz, ramping with hold time. Slight tilt down 3°.
- **Audio:** ambient ducks 40%. Low rising drone (sine sweep 60 → 180 Hz) over the hold. Sub-bass pulse every 0.5 s, tightening to 0.2 s. Wind fades out entirely.
- **Haptic (mobile):** light pulse every 0.5 s, tightening with the drone.
- **Post:** ColorCorrection saturation → −0.4, contrast +0.15. Vignette darkens edges 0 → 0.5.
- **UI:** no bar. The ground crack and light are the bar. Only a small "RELEASE" hint fades in after 1.5 s of hold, first 3 bursts only.
- **Cancel:** releasing before 0.4 s cancels cleanly with a 0.1 s exhale sound and effects reversing over 0.3 s.

### 4.2 Burst ignition (frames 0–18, \~0.3 s)

- **Frame 0:** input release. Time scale 0.15 for 0.12 s (freeze), then 1.0. All sound cuts to silence for those 0.12 s except a single sub-bass hit.
- **Frame 0:** full-screen white flash, alpha 0.9 → 0 over 0.25 s. Wings snap fully open in 2 frames.
- **Frame 0:** shockwave ring decal on ground, expands 0 → 60 studs radius over 0.6 s, alpha 0.8 → 0 (R). Ground crack decal shatters into 20–30 debris parts flung outward at 40–80 studs/s, lifetime 2 s, collisions off (R, reduced to 8 for other players).
- **Frame 0:** column of light: tall Beam from ground to 3,000 studs, width 4, alpha 0.7 → 0 over 3 s (R). This is the signal everyone else sees.
- **Frame 2:** camera recoil: kicks down 2 studs and back 3 studs over 0.08 s, then snaps to follow. Shake amplitude 1.2 studs, 35 Hz, decaying over 0.6 s.
- **Frame 2:** FOV snaps 62 → 105 over 0.15 s. Motion blur (BlurEffect) 0 → 12 over 0.1 s.
- **Frame 4:** audio: cannon crack (layered: transient click + 80 Hz boom + white-noise burst), then a long tearing-air riser. Sidechain everything else to it. Wind sound hits at full at frame 8.
- **Frame 4:** haptic: one heavy hit, then a 0.4 s rumble.
- **Frame 4:** dust and feather particle burst from the launch point, 200 particles, 1.5 s lifetime (R, 60 for others).
- **Frames 0–18:** character animation: a full-body extension, arms back, head up, wings in an upward V. Speed lines (BillboardGui or ParticleEmitter with stretched textures) spawn behind the character.

### 4.3 Ascent (0.3 s to apex)

- **Camera:** FOV eases 105 → 85 over the ascent. Camera distance from character 12 → 20 studs. Camera pitch slowly tilts up 10° so the sky fills the frame. Shake decays to 0 by 60% of the ascent.
- **Trails:** two Trail objects on the wingtips, width 1.5, lifetime 1.2 s, white → transparent. A third trail at the feet, thinner.
- **Speed lines:** density proportional to speed. Gone by apex.
- **Audio:** wind at full intensity for the first second, then thins (low-pass filter sweeping 20 kHz → 2 kHz as speed drops). The riser resolves into a sustained chord as you slow. Heartbeat sample enters at 70% of ascent, slow, 50 bpm.
- **World:** fog color and sky lerp through altitude bands (§5). Clouds pass at speed. Sun rays (SunRays effect) intensity ramps 0 → 0.4 as you clear the cloud layer.
- **Other players:** your character at distance gets a glowing rim (Highlight object, fill transparency 1, outline on) so people on the ground watch you go.
- **Deceleration cue:** in the last 0.8 s before apex, wings slowly spread wider, trails fade, and a soft bell chime plays. The player should feel the slowdown coming and know the hang is next.

### 4.4 Hang (apex, 2–6 s)

- **Physics:** gravity 4. Player drifts. Small input nudges only.
- **Camera:** the slow pull-back. Over 1.5 s, camera distance 20 → 38 studs, FOV 85 → 70, pitch drops to −8° so the planet rises into the bottom third of the frame. Zero shake. Zero blur. Camera orbit allowed, slow.
- **Animation:** wings fully spread in a slow 2.5 s breathing cycle. Body goes limp-weightless, arms out, hair/cloth drift (use Roblox cloth physics via constraints or a scripted sway).
- **Audio:** everything out except: a faint sustained pad, the player's own slow breath, heartbeat at 40 bpm, and one soft chime on entry. Wind is gone. If at the top band, a faint high crystalline shimmer.
- **Post:** saturation returns to 0, contrast returns to 0, bloom +0.3, vignette 0.2. Stars are brighter here than anywhere else: skybox star layer alpha 1.0, each band below dims it.
- **Light:** a god-ray beam from the sun direction crosses the frame (SunRays 0.6). This is the shaft of light in the engraving. It should fall across the character.
- **Collectibles:** high-altitude feathers/shards drift here, slowly orbiting. Reachable with drift. Collecting plays a crystalline chime, no popup.
- **UI:** a single thin altitude readout fades in at top center at 50% alpha, e.g. "4,210". If it's a new record, it pulses once gold and a tiny "RECORD" text fades in for 1 s. Nothing else.
- **Exit:** timer end or dive input. On timer end, wings begin to fold over 0.4 s with a creak, and the player tips forward. On dive input, wings snap shut instantly and the tip is sharp.

### 4.5 Fall: Glide

- **Animation:** wings spread, body horizontal, head forward. Bank roll up to 30° on steering. Wings flex up on pitch-up, down on pitch-down.
- **Camera:** behind and above, distance 18, FOV 80. Lag behind the character by 0.12 s (spring, damping 0.6) so turns feel weighty. Roll with bank at 40% of bank angle.
- **Audio:** medium wind with gentle whoosh on banks. Wing fabric flutter layer. Music: a low, slow ambient layer.
- **Trails:** wingtip trails on, thin, gray.
- **Energy warning:** below 20 glide energy, wings begin a visible strain shake and a faint creak loops. Sink rate doubles. At 0, forced tuck with a snap and a short cry.
- **Feedback on ring pass:** ring flashes white, emits a sparkle burst, a rising two-note chime, +12% charge floats up briefly, small FOV bump +4 for 0.2 s, light haptic. Rings are 20 studs wide and glow brighter as you approach.
- **Thermal:** a visible column of rising particles (slow upward drifting motes, 30 studs wide). Entering it gives +60 up over 1 s, wings lift, a warm whoosh, screen edges brighten slightly.

### 4.6 Fall: Aimed dive

- **Aim cursor:** a small reticle at the aim point on screen, visible in Hang, Glide and Dive. It snaps lightly to destructibles within 30 studs of the ray hit (a soft magnet, not a lock). Over a building it brightens; over a town cluster it shows a faint circle previewing the smash radius at current speed. This preview is the player's main decision aid and must update every frame.
- **Animation:** wings tuck in 3 frames, fist forward, body arrow-straight, head down behind the fist. Faint vibration animation at high speed. Holding longer tightens the pose further (arms pull in, second fist joins).
- **Camera:** distance 10, FOV ramps 80 → 110 with speed. Shake 0 → 1.5 studs with speed, 30 Hz. Camera auto-centers behind the velocity vector; the aim cursor can drift ±15° from center.
- **Speed stages (studs/s):**
  - 100–200: wind rises, speed lines start, trails thicken.
  - 200–300: wind becomes a roar, low rumble, radial edge streaks, constant haptic rumble.
  - 300–380: high frequencies roll off, a ringing tone creeps in, heartbeat fast and loud. Orange rim glow at screen edges, orange Highlight outline on the character, embers streaming backward.
  - 380–420 (terminal): white-hot cone of particles ahead of the fist. Full radial blur. Screen pulses every 0.3 s. Sound is sub-bass and ringing. Chromatic-aberration fake with offset tinted streak frames. The smash preview circle on the ground is at full size and glowing.
- **Target approach:** when impact is within 1.5 s at current speed, a bass drop builds, the target gets a bloom spot, the horizon rises into frame, and any people/cars in the preview circle begin to react (cars honk, lights flicker). This is the "oh no" beat for the town.

### 4.7 Swoop (release from dive at speed)

- **Frame 0:** wings snap open with a canvas-crack sound, time scale 0.4 for 0.1 s.
- **Camera:** FOV snaps down 110 → 75 over 0.2 s (sudden drag), then eases to 80. Distance 10 → 18. A short upward camera swing that overshoots 5° and settles.
- **Animation:** full-body arch, wings catching air, arms back.
- **Audio:** whoosh with a pitch bend upward, wind pressure release, a resonant "thump" of air caught.
- **Trails:** both wingtip trails go bright white for 0.5 s.
- **Haptic:** one medium hit.

### 4.8 Impact & smash

- **Impact frame:** time scale 0 for 0.08 s at hop speed, up to 0.18 s at terminal (hitstop scales with speed). White flash alpha 0.3 → 1.0 by speed. Shake amplitude = speed/100 studs, 40 Hz, decay 0.8 s. Haptic: one heavy hit.
- **Shockwave:** ring decal expands from 0 to the smash radius over 0.25 s, then a second, thinner ring to 1.6× radius over 0.5 s (R). Ground crater decal sized to radius. Dust wall rises along the ring edge (150 particles, R, 50 for others).
- **Destruction wave:** destructibles inside the radius do not all break on the same frame. They break in a radial sweep from the center outward at 200 studs/s so the player sees the wave travel through the town. Each break has its own crack sound and chunk burst (§4.11). This stagger is the single most important detail in the whole impact and must be implemented in milestone 2.
- **Chunks:** building chunks unanchor and are flung outward with velocity = 30 + (radius − distance) × 2, upward bias 0.4, random spin. Cars tumble. Trees snap at the base and fall away from center. Debris lifetime 4 s, fade over the last 1 s, pooled.
- **Camera:** after hitstop, a slow 0.5 s pull-back from distance 10 to 16 so the full radius is in frame, then returns.
- **Animation:** three-point landing, fist in the ground, wings mantled, held through the hitstop and 0.3 s after. Rise over 0.3 s into a ready stance. Recovery is short: the player should be hopping into the rubble immediately.
- **Audio:** impact boom scaled to speed, then a 0.6 s near-silence (everything ducked to 10%), then the destruction wave sounds arrive staggered (glass, concrete, wood, metal) as the wave travels. Ambient returns over 2 s under them. The silence before the crashes is the point.
- **Post:** 0.8 s of saturation −0.6, slow vignette fade.
- **Money feedback:** each destroyed object spawns a small rising number at its position in muted gold, and a running combo counter appears top-right only once combo ≥ 2 ("×2", "×3"...). Combo counter has a thin ring timer. When the combo ends, the total slides into the money readout with a soft chime. No popups.
- **Landing (no target, from Glide/Swoop):** the original quiet version: small crater, dust, 0.8 s stillness, ambient ducks and returns. Keep this; the contrast with Impact makes the smash feel bigger.
- **Charge feedback:** charge gained visibly flows into the wings as motes over 1 s.

### 4.9 Hop (inner loop)

- **Takeoff:** a small dust puff, a light whoosh, wings half-open. Squash 0.9 scale for 2 frames then stretch 1.1 for 3 frames.
- **Apex float:** 0.35 s of reduced gravity, wings fully open, a soft air-catch sound. Camera does nothing dramatic; the float is in the body.
- **Land:** 0.15 s squash, tiny dust, a soft thud. Chain hops get a slightly higher pitched thud each.
- **Rule:** hops must feel excellent on their own, in isolation, on a flat surface, with no VFX. If the hop isn't fun with sound off, fix the curve before adding effects.

### 4.10 Global rules for feel

- Every state change has an audio transient, a camera event, and an animation snap on the same frame. Never fade into a state; cut in, fade out.
- FOV is the speed meter. Shake is the danger meter. Audio low-pass is the altitude meter. Never show a speedometer.
- Silence is used three times per arc (ignition freeze, apex, post-landing). Protect it. No UI sounds during silence windows.
- All camera effects are additive layers on a base follow camera, each with its own decay, so they stack without fighting. Implement as a `CameraEffects` module with named layers: `shake`, `recoil`, `fovOffset`, `distanceOffset`, `tilt`, `roll`.

### 4.11 Laser

- **Ignition:** right hold. 0.15 s charge: the character's chest light brightens, a rising whine, the aim reticle expands into a circle the width of the beam. Then the beam snaps on with a crack.
- **Beam:** a Beam object from the chest to the aim hit point, width per §3, with an inner bright core and a wider soft outer glow. A small flare at the hit point. Scorch decal trails where the hit point moves across ground (pooled, 30 max, fade 6 s). At high altitude the beam is a visible column from the ground; other players see it (R, width-only, no decals for them).
- **Camera:** FOV +6 while firing, slight pull-back, a fine constant shake 0.2 studs at 60 Hz. Camera does not lock.
- **Audio:** sustained hum layered with a crackle; pitch rises with altitude. Sweeping fast across the ground adds a tearing sound. Each object destroyed under the beam adds its break sound.
- **Body:** wings spread to brace, fall slows 30%, arms forward. The fire pose should look effortful.
- **Energy out:** the beam sputters for 0.3 s (width flickers), then cuts with a low thunk. The energy bar is not shown; the sputter is the warning.
- **Ground (Cutter):** a thin beam, no camera effect, a small zap sound. It should feel like a tool, not a weapon.

### 4.12 Destruction feel

- **Materials:** four break families: wood (snap, splinters, brown chunks), stone/concrete (crack, dust, gray chunks), glass (shatter, bright shards, high ring), metal (crunch, sparks, dark chunks). Each has one sound set with 3 variations and one particle set.
- **Health reveal:** objects with health > 1 hit show cracks via a decal overlay at 50% health and a visible lean at 25%. Buildings crumble from the hit side first.
- **Chunk burst:** when an object breaks, 3–5 prefab chunks unanchor, plus 10–20 small particle debris. Chunks keep collisions off against players and on against the ground for 1.5 s, then off entirely, so they bounce once and settle without blocking movement.
- **Secondary chaos:** cars have a 20% chance to pop with a small secondary shockwave (radius 8) 0.5–1 s after breaking, which can chain into neighbors. Keep this; it makes rampages unpredictable.
- **Rebuild:** 75 s after a cluster is cleared, scaffolding ghosts fade in over 5 s, then the prefabs snap back with a soft rising chime. Players see the town come back and know it's time to go up again.
- **Combo timing:** 4 s window, each kill resets it. Counter ticks are a short rising arpeggio, one note per hit, resetting every 8 notes so it never gets shrill.
- **Budget:** at most 40 dynamic chunks alive per client; beyond that, new breaks spawn particles only. Other players' destruction shows chunks only within 300 studs.

## 5. World

One small planet for MVP. The playable surface is a flat disc with a visual sphere shell below it; gravity is normal Roblox downward gravity. The Doré shot comes from camera, fog and the shell mesh, not planetary physics. Planet transitions are out of scope but the structure is built so a second planet is a config file.

**Surface disc:** 1,200 studs diameter. Edge curves down over the last 100 studs into the shell so the horizon reads as a planet edge. Invisible wall 40 studs past the edge; falling off teleports back to the altar with a fade.

**Landmarks (slots, hand-placed):**

| Slot | What | Purpose |
| --- | --- | --- |
| Altar | Raised launch platform at center, spawn point, shop shrine beside it | Burst origin, hub |
| Town | 20–30 building prefabs, roads, 10–15 cars, lamps, signs, \~250 studs across, 350 studs from altar | The main target. Visible from apex as a cluster of lights |
| Hamlet | 6–8 small houses + fences, opposite side | Secondary target, quick money |
| Forest | 60–80 trees + rocks | Hop-dive fodder, cutter practice, filler between targets |
| Cliff | Elevated rock edge with a radio mast | High hop launch point, the mast is a tall single target |

**Destructible catalog (MVP):**

| Prefab | Health | Chunks | Value ($) | Family |
| --- | --- | --- | --- | --- |
| Tree | 1 | 2 | 5 | wood |
| Fence section | 1 | 1 | 2 | wood |
| Rock | 2 | 3 | 8 | stone |
| Lamp / sign | 1 | 1 | 4 | metal |
| Car | 2 | 3 | 25 | metal, 20% pop |
| Small house | 4 | 4 | 60 | wood |
| Shop (2-story) | 6 | 5 | 120 | stone + glass |
| Tower (4-story) | 10 | 5 | 300 | stone + glass |
| Radio mast | 8 | 4 | 200 | metal |

Health is in "hits" from a hop-dive; a terminal smash does `speed × 2 = 840` damage, enough for everything in radius. A full town is worth roughly $3,500 base before multipliers.

**Planet shell:** sphere MeshPart radius 1,500 centered 1,480 below disc center, low-poly, monochrome terrain texture, plus a radius-1,560 transparent rim-lit atmosphere sphere. CanCollide false, anchored. From apex, the town reads as a bright cluster on the ball.

**Sky:** skybox with a dense star field, hidden by Atmosphere density at low altitude. One strong directional sun at \~35° so a god-ray crosses the apex frame.

**Altitude bands:** altitude drives every atmospheric parameter via a `SkyBands` module: a sorted band list, each with a target state for Atmosphere, Lighting, fog, star alpha and audio layers; the client lerps between adjacent bands each frame.

| Band | Altitude | Look | Sound | Content |
| --- | --- | --- | --- | --- |
| Surface | 0–300 | Normal fog, warm gray | Ground ambience | Towns, forest, hop play |
| Cloud deck | 300–1,200 | Thick cloud sheets, diffuse white | Muffled wind | First rings, thermals |
| Clear | 1,200–3,500 | Above clouds, sky deepening, first stars | Thin wind | Ring courses |
| Storm | 3,500–7,000 | Dark towers, lightning every 8–20 s | Thunder | Lightning thermals |
| Aurora | 7,000–11,000 | Aurora ribbons, near-black sky | Crystalline shimmer | Orbiting rings |
| Edge | 11,000–16,000 | Full curvature, halo, god-ray | Near silence, heartbeat | The Doré frame. Laser at max width |

**Planet config (for the AI gen pipeline later):** a planet is one JSON config (palette, terrain texture, cloud style, ring seed, landmark slot → prefab set, sky band overrides) plus a prefab set. MVP builds the structure and one config; variety is generated later by swapping prefab sets, not layouts.

**Performance:** shell and halo are two parts. Cloud deck is 6–10 flat mesh sheets with scrolling texture. Rings are 20–40 pooled parts. Destructibles are anchored prefabs until hit. Streaming enabled, 4,000-stud radius, shell persistent.

- Minute 1: first burst, reach cloud deck, first feathers.
- Minute 5: Power 2–3, break the cloud deck into Clear band, first rings.
- Minute 15: Power 5–6, Hang 1, first wing tier change.
- Session 1 end (\~30 min): Power 8–9, reaching Storm band.
- Session 2: Aurora band, Scorched wings.
- Session 3: Edge band, planet 1 completion, the Doré frame.

## 6. Economy & progression

One currency: **cash**. It comes from destruction, and destruction multiplies with how you arrived. Spent at the shrine by the altar.

**Payout formula per destroyed object:**

```
cash = value × altitudeMult × comboMult
altitudeMult = 1 + (diveStartAltitude / 2,000)      -- 1× from a hop, ~4× from Storm, ~7× from Edge
comboMult    = 1 + 0.2 × min(comboCount, 20)          -- caps at 5×
```

A terminal smash on the full town from the Edge band with a 20-hit combo pays roughly $3,500 × 7 × 5 ≈ $120,000. A hop-dive on a tree pays $5. The gap is the game.

Also: +$1 per 100 studs of max altitude on each landing (so even a run with no target pays a little), and rings add $20 × altitudeMult.

**MVP upgrade track: Power.** 25 levels, cost `100 × 1.4^level`, each level +45 burst velocity. Levels 1–3 should be affordable within the first 10 minutes. Four more stats (Hang, Grace, Weight, Charge) are specced in §3 and follow the same shape but are cut from MVP; add them once Power alone proves the loop.

**Skins (MVP: two):** Demon wings (default) and Jetpack. Purely cosmetic: same stats, different models, trails, burst column color and crater decal. Jetpack has a thruster flame instead of a wing spread at apex. Both shown at the shrine; Jetpack costs $5,000. The point is to prove the theme flexes without touching mechanics.

**Session pacing targets:**

- Minute 1: first burst, cloud deck, first town smash from \~1,000 studs, first combo.
- Minute 5: Power 2–3, Clear band, rings, a $5,000+ run.
- Minute 15: Power 5–6, Storm band, laser becomes a real weapon, Jetpack affordable.
- Session 1 end (\~30 min): Power 8–9, $50,000+ runs.
- Session 2–3: Aurora and Edge, the Doré frame, six-figure runs.

**Leaderboards:** global max altitude, global best single run, in-server live board at the shrine showing the highest player right now and the biggest run this server.

## 7. Multiplayer & social presence

Servers hold 14 players (configurable 10–20). The design goal is that every player can always see at least one other player doing something, without any explicit social system.

**Visibility by design:**

- **Burst columns.** Every burst spawns a server-wide light column at the launch point that lingers 3 s and a persistent faint marker at the altitude reached for 10 s. Anyone on the surface sees who's going up and how high.
- **Apex stars.** Players above 1,200 studs get a client-side Highlight with a bright outline, so a hanging player reads as a star from the ground. Tier color on the outline.
- **Trails persist.** Wingtip trails last 2.5 s for other players. You can follow someone's dive.
- **Small map.** 1,200-stud disc with 3–5 landmarks means natural clustering at the altar and feather field.
- **Hub shrine board.** Live "highest in the sky right now" name and altitude.

**Light contact mechanics (no griefing surface):**

- **Draft.** Flying within 8 studs behind another player's glide trail gives +15% speed and a soft harmonic chime. Encourages following and formation flying.
- **Dive-bomb.** Landing from Dive within 20 studs of another player gives *them* a camera shake and dust, and gives *you* +5% charge. Purely cosmetic for them. Encourages landing near people.
- **Shared thermals.** A thermal gets 20% stronger per player inside it, up to +60%. Encourages gathering.
- **Mirror burst.** If two players burst within 1 s of each other from within 30 studs, both get a shared shockwave and +10% height. Rare, delightful, and players will try to coordinate it.

No collision between players in the air. No damage. No chat-dependent features.

**Replication budget:** each remote player renders at most: 1 trail pair, 1 Highlight, 1 burst column, 1 landing dust burst (50 particles), no screen effects. All camera/post effects are local only. Remote effects beyond 1,500 studs are culled except the burst column and Highlight.

**Performance targets:** 60 fps on mid-range mobile (e.g. 2021 Android mid-tier) with 14 players and 4 simultaneous falls. Measure with the Studio microprofiler; the dive particle budget is the first thing to cut if it fails.

## 8. First 30 seconds & onboarding

The player must experience the full arc before they have made any decision. No lobby, no tutorial screen, no character customizer.

**Timeline:**

| Time | What happens |
| --- | --- |
| 0 s | Spawn on the altar, charge at 100%, wings glowing. Camera does a slow 2 s push-in from above; the town is visible in the distance. One prompt: HOLD SPACE. |
| 2–4 s | Player holds. Charge effects. Hint becomes RELEASE after 1.5 s. |
| 4 s | Burst. Full ignition. |
| 4–9 s | Ascent to \~1,600 studs: above the clouds, first stars. |
| 9–12 s | Hang. The pull-back. The town is a cluster of lights below. The aim reticle fades in over it. Hint: HOLD CLICK TO DIVE. |
| 12–20 s | Aimed dive. The reticle magnet pulls toward the town. Smash preview circle grows on approach. Target-approach beat: cars honk. |
| 20–21 s | Impact on the town edge. Hitstop, shockwave, the destruction wave sweeps 4–6 buildings. Combo counter appears. Numbers rise. |
| 21–28 s | Hint: TAP TO HOP, then HOLD TO DIVE on a nearby car. Player hops into the rubble, chains two or three small smashes. Combo total slides into cash: \~$1,200. |
| 28–30 s | Hint: HOLD RIGHT CLICK. Laser cutter on a tree. Charge is at 45% and filling. Another player's burst column rises in the distance. |

**Onboarding rules:**

- Hints are single short phrases, bottom center, fade after the action is done. Max one on screen. Gone after the third successful use of that input.
- The first dive is scripted only in reticle magnet strength (stronger on the first run so they can't miss the town); physics is real.
- The shrine is not introduced until the player has $300; it then gets a soft glow and a one-time arrow.
- First Power level costs $140; the first run pays \~$1,200 so the first upgrade is immediate and the second burst visibly goes higher.
- The town has rebuilt by the time the second burst lands.

**Retention hooks in the first session:** the first wing tier (Fledged) at Power 3 is reachable in \~8 minutes, and the camera lingers on the new wings when equipped. The first "RECORD" pulse happens on burst 2. The Storm band is visible from the Clear band as dark towers above, so the player knows there's more sky.

## 9. Technical architecture

Rojo project, Luau, client-authoritative movement with server validation. All feel runs on the client; the server owns currency, stats, altitude records and anti-exploit sanity checks. Use a lightweight signal/remote wrapper (Red, or a small in-house `Net` module), not a full framework.

**Project layout (Rojo):**

```
src/
  shared/
    Tuning.luau          -- every number in §3, §4, §6; one table, hot-reloadable
    SkyBands.luau        -- band table from §5
    Destructibles.luau   -- prefab catalog: health, chunks, value, family (§5)
    Planets/             -- one config module per planet (MVP: one)
    Types.luau           -- state enums, remote payload types
    Net.luau             -- typed remote wrapper
  client/
    Movement/
      Controller.luau    -- state machine, input, physics per state
      States/            -- Grounded, Charging, Burst, Hang, Glide, Dive, Swoop, Impact, Landing
      Aim.luau           -- aim ray, reticle magnet, smash preview radius
    Combat/
      Laser.luau         -- beam, energy, hit sweep, cutter mode
      Smash.luau         -- shockwave query + radial destruction wave timing
    Camera/
      CameraRig.luau     -- base follow camera
      CameraEffects.luau -- additive layers: shake, recoil, fovOffset, distanceOffset, tilt, roll
    Feel/
      Juice.luau         -- VFX/SFX/post per state event; reads Tuning
      Audio.luau         -- layered mixer, ducking, low-pass by altitude
      Post.luau          -- ColorCorrection, Blur, Bloom, SunRays, vignette
      TimeScale.luau     -- hitstop / slow-mo
      Destruction.luau   -- chunk spawn, fling, pool, material break FX
    World/
      AtmosphereDriver.luau -- lerps Lighting/Atmosphere/fog/stars by altitude
      RemotePlayers.luau    -- highlights, trails, burst columns, laser beams for others
      Collectibles.luau     -- rings/thermals pickup detection
    UI/
      Hints.luau, AltitudeReadout.luau, ComboCounter.luau, CashReadout.luau, ResultsStrip.luau, Shrine.luau
  server/
    PlayerData.luau      -- ProfileService or equivalent: cash, Power, skin, records
    Validation.luau      -- sanity checks on altitude, speed, hits, payouts
    DestructionAuthority.luau -- object health, who broke what, payout, rebuild timers
    Rings.luau           -- ring/thermal placement from planet seed
    Leaderboards.luau    -- OrderedDataStore, in-server board
    Presence.luau        -- broadcasts burst/impact/laser events to others
```

**Ownership rules:**

- The client owns the character's velocity and state. Movement is applied via `AssemblyLinearVelocity` with a `VectorForce` cancelling default gravity and applying the state's gravity, so each client has its own effective gravity.
- The server never simulates the arc. It receives: `BurstStarted(power)`, `ApexReached(altitude)`, `Impact(position, speed, diveStartAltitude)`, `LaserHit(objectIds, altitude, dt)`, `Landed(altitude, maxSpeed)`, `Pickup(id)`.
- **Destruction is server-authoritative for health and payout, client-predicted for feel.** On Impact the client immediately plays the shockwave and destruction wave for objects it believes are in radius. The server independently queries the radius from the reported position (clamped to within 40 studs of the replicated position), applies damage, computes payouts with the altitude and combo multipliers, and broadcasts the authoritative break list. If the client predicted a break the server denies, the object snaps back with no sound (rare, only under lag or cheating).
- The server validates: altitude ≤ theoretical max for Power × 1.15; speed ≤ terminal × 1.1; impact position within 40 studs of replicated position; laser hits within beam range and width for the reported altitude; combo timing within 4 s server-side. Failed checks are logged and ignored; no kicks at launch.
- Cash, Power, skin and records are server-authoritative. Shrine purchase is request/response.

**Event flow for one arc:** Controller enters a state → fires a local `StateChanged(from, to, payload)` signal → `Juice`, `CameraEffects`, `Audio`, `Post`, `UI` each subscribe and run their own effects for that transition → Controller fires the matching remote to the server at Burst, Apex, Land → server validates, updates data, and broadcasts a `Presence` event → other clients' `RemotePlayers` render the budgeted version.

**Tuning hot-reload:** in Studio, `Tuning.luau` is watched; a dev-only panel exposes every value as a slider with live effect. Half the work on this game is tuning, so this is built in milestone 1, not later.

**Fixed timestep:** movement runs in `RunService.PreSimulation` with `dt` clamped to 1/30 so a frame hitch never launches someone into orbit. Time scale (hitstop) is applied as a multiplier on `dt` inside the Controller and on `Tween`/animation speeds, never via `workspace` properties.

## 10. Movement implementation

&#91;embedded content: movement state machine · 8 states\]

The top row is the ground-to-apex path and runs once per outer loop; the bottom row is the fall, where the player moves freely between Glide, Dive and Swoop until touching ground. Swoop exits to Glide when speed drops below 90, so it is drawn on the fall row.

**Controller structure:** one `Controller` module holds the current state object, the shared physics context (character, root part, velocity, altitude, glide energy, charge) and the input snapshot. Each state is a module with `enter(ctx, payload)`, `update(ctx, dt)`, `exit(ctx)` and returns the next state name or nil from `update`. No state knows about VFX; it only fires `StateChanged`.

**Physics approach:** a `VectorForce` on the root part cancels Roblox gravity and applies the state's gravity from `Tuning`. Velocity is set directly each frame from the state's own integration (`v += g * dt`, then clamp, then steer). This gives exact control over curves and makes hitstop trivial (multiply `dt`). Humanoid is kept for animation and replication but `PlatformStand` is true in all air states so it doesn't fight the controller.

**Steering:** in Glide, the move vector maps to pitch (−35° to +25°) and yaw rate (90°/s), with roll derived from yaw for bank. In Dive, pitch is locked to −88° and yaw is clamped to a ±25° cone around the entry heading with 40°/s rate. Camera-relative on desktop; on mobile, steering is relative to the velocity direction so thumb-right always banks right.

**Ground detection:** a downward raycast from the root part each frame, 6 studs. Landing triggers when the ray hits and vertical velocity < −20. Hop uses the same ray for the chain window.

**Glide energy and charge** live in `ctx` and persist across states; only Hang resets glide energy and only Landing/Grounded consume charge.

**Animation:** one `AnimationController` per state with a looped base and transition clips. Wing open/close is a 3-frame clip triggered on state enter, never blended, so the snap in §4 is preserved.

**Edge cases to handle in milestone 1:** leaving the disc edge in any state → fade and teleport to altar; character death or reset → Grounded at altar with charge preserved; losing network ownership mid-fall → nothing visible (all local); another player's character touching you in air → ignored (collision groups).

**Aim (`Aim.luau`):** each frame, raycast from the camera through the screen aim point (mouse, or virtual stick offset on mobile) against ground and destructibles, max 2,000 studs. The hit is the aim point. Magnet: query destructibles within 30 studs of the hit; if any, blend the aim point 40% toward the nearest one's center (70% on the first run). Dive thrust direction = normalized (aimPoint − rootPosition), recomputed every frame so the dive tracks a moving aim. Smash preview radius = `6 + currentSpeed / 8`, drawn as a ground decal at the aim point.

**Impact vs Landing:** on ground contact, if the previous state was Dive, enter Impact; otherwise enter Landing. Impact also triggers on contact with a destructible's hitbox (a raycast 4 studs ahead of the velocity each frame in Dive), so diving into the side of a tower counts.

**Laser (`Laser.luau`):** while right is held in an air state, each frame: raycast from the chest to the aim point; the beam endpoint is the hit. Sweep: between frames, sample the segment from the last hit point to the current one every 4 studs and query destructibles within beam width at each sample, so a fast sweep doesn't skip objects. Accumulate damage per object locally for prediction and send `LaserHit` batched every 0.1 s.

## 11. Camera & rendering

**Camera rig:** `Camera.CameraType = Scriptable`. `CameraRig` computes a base position each `RenderStepped` from the character's root CFrame, a desired distance, a pitch/yaw from orbit input, and in Dive a forced yaw/pitch behind the velocity vector (spring, stiffness 8, damping 0.7 toward the velocity direction). `CameraEffects` adds named layers on top, each with an amplitude, a decay or duration, and a curve; layers are summed, not blended, so a burst recoil and a dive shake stack correctly. Layers: `shake` (per-axis noise, amplitude × frequency), `recoil` (one-shot offset with spring return), `fovOffset`, `distanceOffset`, `tilt` (pitch), `roll`. Each state in §4 sets target values for the base rig and triggers one-shot layers on enter.

**FOV:** base 70. All FOV changes in §4 are `fovOffset` layer targets tweened with Quad easing; the dive FOV is a per-frame function of speed, not a tween.

**Atmosphere driver:** on `Heartbeat`, read root Y, find the bracketing bands in `SkyBands`, compute `t`, and lerp `Lighting.FogStart/FogEnd/FogColor`, `Atmosphere.Density/Offset/Color/Haze`, `Lighting.Ambient/OutdoorAmbient`, `Sky` star visibility (via `Atmosphere.Density` and a star-layer skybox swap at the Clear band), `SunRays.Intensity`, `Bloom.Intensity`, and the audio low-pass target. Lerp with a 0.5 s smoothing so band edges never pop.

**Sphere shell:** two anchored MeshParts (terrain shell, halo). The halo uses `ForceField` or `Neon` with high transparency and a Fresnel-ish rim achieved by a second slightly smaller `Glass` sphere; test both in Studio and keep the one that reads as an atmosphere at 12,000 studs. The town's position on the shell is faked by a bright emissive decal cluster on the shell at the town's angular position so it reads from apex even when the real town is streamed out.

**Streaming:** `StreamingEnabled` on, target radius 4,000, min radius 1,000. Shell, halo, skybox, rings and the altar are `Persistent`. Destructible prefabs are default; chunks are client-only parts in `workspace.CurrentCamera` so they never replicate.

**Clouds:** 8 flat mesh sheets 600 studs across at the cloud deck, scrolling texture, `Transparency` 0.3, no collision, sorted so the player passes through visually. Storm towers are 6 tall cloud meshes. Aurora is 3 wide `Beam` objects between invisible attachments with a slow sway script.

**Mobile:** at `Quality < 5`, halve particle counts, drop the radial streak frames, disable the chromatic fake, cap chunks at 20. Target 60 fps on a 2021 mid-tier Android; measure with the microprofiler at 14 players and 4 simultaneous impacts.

## 12. VFX, SFX & UI implementation

**Juice orchestration:** `Juice.luau` subscribes to `StateChanged(from, to, payload)` and to combat events (`ImpactFired`, `ObjectBroke`, `LaserOn/Off`, `RingPassed`). Each event maps to a list of effect calls defined in a `FeelTable` module keyed by event name, so the whole of §4 is data: `{ event = "Burst", effects = { {fx="flash", alpha=0.9, dur=0.25}, {cam="recoil", down=2, back=3, dur=0.08}, {audio="burst_crack"}, ... } }`. Adding or tuning an effect never touches state code.

**Effect budget per client (hard caps enforced in `Juice`):** 400 live particles own player, 60 per remote player; 40 chunks own, 12 per remote; 30 scorch decals; 1 active Beam per laser; trails limited to 3 per character. When over budget, new effects degrade to the next cheaper tier (chunk → particle burst → nothing).

**Time scale:** `TimeScale.luau` holds a multiplier used by Controller `dt`, all `TweenService` tweens created through a wrapper, and `AnimationTrack.AdjustSpeed`. Hitstop = set multiplier to 0 for N frames via a stack so overlapping hitstops resolve correctly.

**Audio:** `Audio.luau` owns named buses (ambient, wind, music, sfx, ui) implemented as `SoundGroup`s with `Volume` tweened for ducking and an `EqualizerSoundEffect` on the wind/ambient buses for the altitude low-pass. Each §4 sound is a named entry with 1–3 variants and a pitch jitter range. Looping sounds (wind, laser hum, drone) are started once and have their `Volume`/`PlaybackSpeed` driven per frame from state and speed.

**Asset list (MVP):**

| Category | Assets |
| --- | --- |
| Character | 2 wing skins (demon, jetpack), 9 animations (idle, walk, charge, burst, hang, glide, dive, swoop, impact), wing open/close clips |
| Destructibles | 9 prefabs (§5), 4 chunk sets, 4 break particle sets, crack decals ×2 |
| World | disc terrain, altar, shrine, shell mesh, halo, 8 cloud sheets, 6 storm meshes, aurora, star skybox, ring, thermal |
| VFX | ground crack, shockwave ring ×2, crater, dust, debris, feathers/embers, speed-line texture, radial streak frame, light column beam, laser beam + flare, scorch decal |
| SFX | \~45 one-shots, 6 loops (wind, drone, laser, hum, heartbeat, pad) |
| UI | hint label, altitude readout, combo counter with ring timer, cash readout, results strip, shrine panel, reticle |

All initial assets can be placeholder (Roblox primitives, free sounds) as long as the timing and curves in §4 are implemented; swap art later.

**UI rules:** no HUD during Charge, Hang, or the first 0.6 s after Impact. Altitude readout only in Hang. Combo counter only at combo ≥ 2. Cash readout always on, small, top-left, animates on change. Hints are one word or phrase, max one at a time. All UI is `ScreenGui` with `IgnoreGuiInset`, scaled by `UIScale` for mobile.

## 13. Data, persistence & anti-exploit

**Profile (per player, ProfileService or equivalent with session locking):** `cash`, `power` (1–25), `skin` ("demon" | "jetpack"), `ownedSkins`, `bestAltitude`, `bestRun`, `totalDestroyed`, `settings` (shake 0–1, haptics on/off). Autosave every 60 s and on leave. A `schemaVersion` field with a migration table from day one.

**Leaderboards:** two `OrderedDataStore`s (altitude, best run), updated at most once per 30 s per player when their best improves. In-server board is a plain table broadcast on change.

**Validation thresholds (server, `Validation.luau`):** maxAltitude(power) = closed-form from §3 gravities × 1.15; maxSpeed = 420 × 1.1; impact position within 40 studs of replicated root; objects claimed broken must be within smash radius + 5 of the impact point or within laser width + 2 of a beam sample; combo window 4.5 s server-side (0.5 s grace); payout recomputed server-side, never trusted from the client. Events that fail are dropped and counted; 5 failures in 60 s flags the player in a log for review. No kicks in MVP.

**Rate limits:** `Impact` max 1 per 0.5 s, `LaserHit` max 10 per s, `BurstStarted` max 1 per 5 s, `Pickup` max 20 per s.

**Determinism for the AI gen pipeline:** planet config and prefab placement are seeded; the seed is logged per server so a layout can be reproduced for bug reports.

## 14. Build plan for Claude Code

In order. Each milestone has a done criterion that is a feel test in Studio, not a feature checklist. Do not start a milestone until the previous one's criterion passes; feel bugs compound.

**Setup notes:** Rojo project with the layout in §9, `Tuning.luau` first, a dev panel (`F2`) that lists every Tuning value as a slider and applies live. Use placeholder primitives for everything. Commit the microprofiler baseline before milestone 2.

1. **Movement core.** Controller state machine, all states except Impact/Laser, `VectorForce` gravity per state, aim ray, hop with float and chain, glide with energy, aimed dive with thrust and widening cone, swoop, landing. Base camera rig with the dive follow spring. No VFX, no audio.
   - Done: hopping and diving around a flat gray disc with no sound feels good for five minutes. The swoop re-aim is satisfying. Nothing jitters.
2. **Burst and arc.** Charging, Burst, Hang, altitude bands driving fog/lighting/stars, the shell and halo, cloud sheets. `CameraEffects` layers. `TimeScale`. The §4.1–4.4 juice for Charge, Ignition, Ascent, Hang (camera, post, placeholder sounds). Burst column replicated.
   - Done: a burst from Power 1 to Power 25 (via dev panel) reads as a cannon shot, the hang at 12,000 shows the ball, and the pull-back lands the god-ray on the character. Someone watching over your shoulder says "oh".
3. **Impact and destruction.** Destructible catalog, prefab loader, one town and the forest placed, Impact state, `Smash` radius query, radial destruction wave with staggered breaks, chunk pool and fling, material break FX, §4.6 and §4.8 juice, the smash preview circle, reticle magnet, Landing vs Impact split.
   - Done: a terminal dive into the town from 5,000 studs produces hitstop, silence, then a visible wave of crashes traveling outward, and you want to do it again immediately. Chunks never block movement. 14 simulated clients, 4 impacts, 60 fps on the mobile emulator.
4. **Laser and combat loop.** `Laser.luau` with sweep sampling, energy, altitude-scaled width, cutter mode, §4.11 juice, combo system with 4 s window, cash payout formula, floating numbers, combo counter, cash readout.
   - Done: apex → dive → smash → hop → laser sweep → combo total feels like one continuous action. Standing on the ground lasering is clearly worse than any air option.
5. **Server authority.** `DestructionAuthority`, `Validation`, `PlayerData` with ProfileService, remotes for burst/apex/impact/laser/land, rebuild timers, `Presence` broadcasts, `RemotePlayers` rendering (highlight, trails, column, laser beam, budgeted chunks).
   - Done: two Studio test clients see each other's bursts, impacts and lasers; a client that reports a fake altitude gets ignored; cash persists across rejoin.
6. **Economy and shrine.** Shrine UI, Power purchase, Jetpack skin purchase and swap (model, trail, column color, apex pose), leaderboards, results strip.
   - Done: a new player reaches Power 3 in about 8 minutes following §6 pacing, and the Jetpack swap changes the look of every phase without any mechanic change.
7. **Onboarding and polish.** §8 first-30-seconds script, hints, first-run magnet strength, audio pass replacing placeholders, mobile controls and `UIScale`, quality tiers, settings (shake, haptics).
   - Done: a fresh account on a phone experiences the full §8 timeline without a prompt being missed, and a 30-minute session hits the §6 pacing within ±30%.

**After MVP (not in this doc's scope):** rockets, remaining stat tracks, more skins, planet 2 config and transition sequence, rebirth, the AI prefab/planet generation pipeline.

**Working rules for the agent:**

- Tuning values go in `Tuning.luau`, never inline. If a number appears in code, move it.
- Every effect goes through `FeelTable`, never called directly from a state.
- When a feel test fails, change curves and timing before adding effects.
- Keep the three silences (ignition freeze, apex, post-impact). Any new sound that plays during them is a bug.
- Ask before cutting anything in §4; it's the product.
