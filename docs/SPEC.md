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
   - **Status: passed review Oct 7, 2026.** Changes from this spec made during review are in §15.
2. **Burst and arc.** Charging, Burst, Hang, altitude bands driving fog/lighting/stars, the shell and halo, cloud sheets. `CameraEffects` layers. `TimeScale`. The §4.1–4.4 juice for Charge, Ignition, Ascent, Hang (camera, post, placeholder sounds). Burst column replicated.
   - Done: a burst from Power 1 to Power 25 (via dev panel) reads as a cannon shot, the hang at 12,000 shows the ball, and the pull-back lands the god-ray on the character. Someone watching over your shoulder says "oh".
   - **Status: closed Oct 8, 2026.** The review reworked the controls, punch and Burst (§15). The look of the arc was built but its feel tuning moves into milestone 3, and the leftovers below carry forward.
   - Carried forward: stars (needs a star skybox asset), speed lines, heartbeat, the hang pad and breath, wing poses and animation, other players' Highlight and charge beam, the RELEASE hint, a microprofiler baseline, and sign-off on the halo tint, cloud opacity and the Burst height curve. Unscheduled: hang collectibles, storm towers, lightning and aurora, fake town lights on the shell, and whether anything should limit how often you Burst now that the meter is gone.
3. **The globe, then movement and punch polish.** First (3a) the world becomes a real globe (§15): gravity toward the center, the frame rolls with the planet, every state and the camera rebuilt on it, the Burst height curve raised. Then (3b) nail the feel, UX, juice and feedback of everything the player does today, before adding destruction: hop, chain hops, dive, swoop, glide, bounces, the punch and rocket jump, both charges and their tiers, the charge rings and HUD, camera effects, and sound. Includes the milestone 2 carry-overs that are about feel (speed lines, wing poses, the heartbeat, stars), §4.6 dive juice (speed stages, FOV from speed), procedural animation for every state, landing and impact debris, and a first real audio pass for movement.
   - Done (3a): walking, hopping, gliding and diving anywhere on the globe feels exactly like it did on the disc; a long flat punch circles the planet; a 30 s Burst shows the whole ball. **Status: 3a closed Oct 8, 2026** (decisions in §15). Done (3b): set at its start.
4. **Core loop.** The basics of attack → destroy → get paid, functional before pretty. Destructible catalog and tag, placeholder prefabs (town and forest built in Studio through MCP), destruction that the punch and the dive both cause: punch hits break what they touch, a dive into the ground or a structure is an Impact with the `Smash` radius query and the radial destruction wave with staggered breaks. Destructibles break instead of bouncing you (the other half of the bounce rule). Pooled chunks flung out, never blocking movement, and a simple rebuild timer. Cash: payout formula from §6, combo with the 4 s window, a cash readout and floating numbers, server-authoritative health and payout (session only; persistence later). Settle how a dive's smash works alongside the ground bounce. The laser is a candidate for this milestone or a later one; decide at its start.
   - Done: diving into the town from altitude breaks a visible wave of buildings, punching through small stuff feels good, cash climbs with the combo, and you want to go up again immediately.
   - **Status: closed Oct 8, 2026 as functional** (decisions in §15: the laser waits, damage is speed, no Impact state, the world is generated, contacts batched). The review's verdict on the feel: "still missing a ton of juice", so the "want to go up again" half of the criterion moves to milestone 5.
5. **Destruction polish.** §4.8 impact juice (hitstop, the silence, crater, dust wall), §4.12 material break effects and sounds, the smash preview and reticle magnet, and HUD and hint cleanup for the core loop.
   - Done (set Oct 8, 2026 from the milestone 4 review): the loop feels like an arcade. Every break and payout is announced on screen, the combo reads at a glance with its name, a punch looks like a punch, the big crashes feel big, and the "want to go straight back up" half of milestone 4's criterion holds.
   - **Status: started Oct 8, 2026.** First items from the review: arcade feedback (combo banner, toasts) and the flying punch pose (§15).

**After milestone 5: to be planned.** Still in scope from the original plan: the laser (if not in 4), full server authority and persistence (`PlayerData`, `Validation`), rebuild polish, other players' presence (`RemotePlayers`), the shrine, Power purchases and the Jetpack skin, leaderboards, onboarding (§8), mobile controls and quality tiers.

**After MVP (not in this doc's scope):** rockets, remaining stat tracks, more skins, planet 2 config and transition sequence, rebirth, the AI prefab/planet generation pipeline.

**Idea noted Oct 8, 2026, for after the core loop: planets in the sky instead of portals.** The other planets are visible in the distance, and you reach one by charging enough to break out of this planet's orbit: a Burst or punch past an escape speed lets go of the globe and a scripted transfer carries you to the next one. Guardrails around that moment: you can only leave toward a planet, never into empty space, and a failed escape falls back onto the globe. Not core loop. Performance notes for when it is planned: a distant planet is a low-poly ball plus halo (a few parts, no content), only the current planet's content streams, and the transfer is a cutscene-length flight during which the old planet unloads and the new one loads, so it never costs more than one world at a time.

**Working rules for the agent:**

- Tuning values go in `Tuning.luau`, never inline. If a number appears in code, move it.
- Every effect goes through `FeelTable`, never called directly from a state.
- When a feel test fails, change curves and timing before adding effects.
- Keep the three silences (ignition freeze, apex, post-impact). Any new sound that plays during them is a bug.
- Ask before cutting anything in §4; it's the product.

## 15. Decisions made during implementation

Changes to the spec above, agreed during milestone reviews. Where this section and an earlier section disagree, this section wins. Every value named here lives in `Tuning.luau`.

### Milestone 1 (movement core)

**Desktop camera is mouse-look.** The free cursor in §3, §4.6 and §11 (cursor drifts on screen, camera auto-centers behind the dive velocity, edge-of-screen orbit) was disorienting in playtest. Instead: the cursor is locked to the screen center with a dot reticle, and only the mouse (or right stick) turns the camera. The aim ray goes through the screen center; the dive heads at the crosshair. Glide and Swoop turn toward where the camera looks (A/D overrides). The camera sits `Camera.ShoulderOffset` to the right so the character never covers the crosshair. States only change follow distance. Mobile controls (§3) still need their own design in milestone 7.

**Hop is its own state** (`Hop`: rise → apex float → Glide). Takeoff is instant; holding space while rising raises the apex from `Hop.Height` toward `Hop.ChargedHeight`. The ground-smash hop dives straight from its apex with no float. Air control during a hop only adds speed along the input and never brakes, so strafing doesn't kill momentum.

**Landing can be cancelled by a hop**, otherwise the 0.2 s chain window could never be hit inside the 0.8 s Landing.

**Touchdown** is detected with a ray along the frame's fall distance instead of "vertical speed < −20", which glide sink rates never reach, and which also stops terminal dives tunnelling through the ground.

**Aimed dive** snaps its entry direction to the aim point (never above `Dive.MaxPitch` below the horizon), then steers within the widening cone from §3.

**Swoop is a pull-up arc.** Releasing a dive rotates the velocity upward at `Swoop.PullUpRate` while keeping speed, until the climb reaches the §3 lift target (`v × 0.55`, cap 160); then forward speed bleeds and gravity takes over. On near-vertical dives the pull-up heads toward the camera look. Swoop costs `Swoop.EnergyCost` glide energy and drains like Glide, so dive/swoop cycles can't float forever.

**Air-gain ceiling** (§3, 25% of the fall's peak) rounds climbs off with `Physics.CeilingDecel` instead of zeroing vertical speed.

**No flapping.** The glide is a glider, not wings: once airborne you only ever come down (apart from swoops and, later, thermals). The §3 "Space tap in air: Flap" input and its glide-energy cost are removed.

**Glide overspeed** above `Glide.ForwardSpeed` bleeds slowly (`Glide.OverspeedBleed`) unless the player pitches up, so boosts and chains carry.

**Movement tech** (hidden, from timing the existing inputs; total carried speed capped at `Tech.MaxCarrySpeed`):

| Tech | Input | Effect |
| --- | --- | --- |
| Perfect bunny hop | Hop within `Hop.ChainWindow` of landing or of starting a slide | Keeps landing speed plus `Tech.PerfectHopBonus` |
| Dive-slide (Swoop only since milestone 2; dives bounce) | Touch down from Dive or Swoop at under `Tech.SlideMaxAngle` with at least `Tech.SlideMinSpeed` | New `Slide` state: slide on the ground with friction; hop out keeps speed; off a ledge → Glide |
| Swoop skim | Swoop pull-up passes within `Tech.SkimHeight` of the ground | `+Tech.SkimBoost` speed and the arc levels off low instead of climbing |

They chain: dive → skim → slide → hop → dive. (The milestone 1 tap boost was replaced by the punch dash in milestone 2.) **Open for milestone 3:** §4.8 says any dive into the ground is an Impact. Proposed: steep dives smash, shallow ones do a small smash and then slide.

**World readability.** The disc has a two-scale grid (16 and 128 studs) and the player has a client-only blob shadow straight below (`GroundShadow`) that shrinks and fades with height, so height above the ground is always readable.

**Test tools.** F2 tuning panel (Studio only: sliders, "Print changes", drop-from-altitude buttons). F3 toggles the controls and tech cheat sheet, which shows in every build while `Dev.ShowControlsHud` is on (until milestone 7 onboarding hints replace it) and is updated with every new feature; in Studio it also has a live readout of state, speed, height and glide energy. The current movement state is also exposed as the local player's `MovementState` attribute.

**Engine note.** This Studio build no longer places `PlayerModule` in PlayerScripts, so movement input is read directly from the keyboard and gamepad (`Movement/Input.luau`); the Humanoid's default walking still works.

### Milestone 2 (burst and arc)

**Input map** (agreed at the start of milestone 2; replaces the §3 input table on desktop, and the §8 hints follow it):

| Input | On ground | In air |
| --- | --- | --- |
| Space tap | Hop (fires on release, within `Hop.TapTime`) | Dive (a tap dives for `Dive.MinHoldTime`) |
| Space hold | Charge a Burst, always; it stops you dead, and the hold sets the height | Dive; release to swoop |
| LMB tap or hold, release | Punch: a lunge; aimed steeply at the ground, a rocket jump | Punch: a dash at the crosshair; aimed steeply at a surface in reach, a rocket jump |
| RMB | Cutter (milestone 4) | Laser (milestone 4) |
| WASD, mouse | Walk, look | Steer, look |

Space is a tap-or-hold check in every ground state (Grounded, Landing, Slide; `Movement/JumpCheck.luau`), so a hop waits for the release (at most `Hop.TapTime`). A chain hop is judged by the press time. Holding past `Hop.TapTime` always enters Charging and zeroes your velocity: charging a Burst deliberately breaks the movement chain. The §3 charged hop is gone, and the hop is small: `Hop.Height` is a little over a default Roblox jump (review note: the 60-stud hop was a jump, not a hop). A hop only opens into a Glide with `Hop.GlideClearance` of air below its apex; otherwise it falls back like a jump, so you never glide along the floor. Chained hops add `Hop.ChainBonus` height and `Hop.ChainForwardBoost` forward speed each, and a fast hop touchdown can slide like a dive-slide. The §3 ground smash is gone; the ground punch replaces it. You can't hop in the air. Mobile keeps its own layout (milestone 7).

**Punch** (`Movement/Punch.luau`). Holding LMB charges for `Punch.ChargeTime` in any state and never locks movement: you can still hop, dive or charge a Burst. While it charges, walk, hop and glide speed take a small cut (`Punch.Charge*Mult`). Releasing always fires and cancels whatever you were doing, Charging and Burst included (review note):

- **Rocket jump** (like TF2; review note: it fired too easily): only when the aim is at least `Punch.RocketMinAngle` (45°) below level at a surface within `Punch.Reach` (60). It pushes you away along the opposite of the aim and still adds `Punch.RocketForwardShare` of the dash burst along your facing, so straight down pops you up and forward. A shallower aim is just the dash. It cancels the speed you were moving into the surface, bounces back `Punch.Reflect` of it, and adds `Punch.Impulse`, all scaled by power and by proximity, `MinProximity + (1 − MinProximity)(1 − clearance / Reach) ^ ProximityExponent`. Point blank is the sharp sweet spot; at the edge of Reach it is still a small bounce. From a ground state it is scaled by `Punch.GroundedMult` (a full ground punch is about 90 studs); timed off the end of a hop or a fall it launches hundreds of studs. Works off walls too.
- **Dash**: every other punch. Always a real burst toward the crosshair: it keeps the speed already going that way, trims sideways speed to `Punch.DashKeepSideways`, and adds `Punch.DashTapSpeed` (tap) up to `Punch.DashFullSpeed` (full charge), capped at `Punch.MaxDashSpeed`. Costs glide energy but never refuses. In the air it ends in Glide; from the ground a level lunge becomes a Slide and one aimed above `Punch.GroundLiftThreshold` takes off. This replaces the tap boost.

**Tricks added**: rocket jump, and jump punch (hop or dive while a punch charges, release near the ground).

**Burst and Hang.** `Hang.Time` is one value (the 2–6 s spread belonged to the cut Hang stat). Burst drift after `Burst.NoSteerTime` is a small fixed speed (`Burst.DriftSpeed`). Burst is exempt from the air-gain ceiling, and Hang starts the fall's ceiling at the apex. **The hold sets the Burst height** (review notes: the all-or-nothing meter felt stepwise, and short holds went far too high). `Burst.HoldHeights` maps seconds held to height, interpolated geometrically so it starts gentle and climbs harder: the shortest hold is about the old 60-stud hop, 1–3 s stays under the clouds, 5–10 s reaches them, 15–25 s clears them, 30–60 s reaches the upper atmosphere. `Burst.ceiling(Power)` caps it, so Power is the upgrade that unlocks the higher holds. The launch velocity is solved for the height. There is no cancel: any release Bursts, so §4.1's cancel and its exhale are gone. The §3 Burst charge meter and its sources (idle, hop, destruction, rings, thermals, impact) are removed. FeelTable entries marked `byCharge` (flash, shockwave, column, recoil, shake, FOV kick, blur, debris, dust) scale with `height / Burst.FeelFullHeight`, and Hang lasts `Hang.Time` scaled the same way (at least `Hang.MinTime`). Power is set from the F2 panel until the economy exists.

**FeelTable lives in `Tuning.Feel`**, so every effect value is also a live F2 slider. `Feel/Juice.luau` routes entries to `CameraEffects`, `Post`, `Audio`, `Vfx` and the altitude readout; every sink is a set of additive layers (`Feel/Layers.luau`). Events are the state entered, `Exit<State>`, the punch results (`Rocket`, `Dash`), `Bounce` and `RemoteBurst`.

**The bounce rule** (review note): anything that isn't destructible bounces you; destructibles don't (milestone 3 breaks them). Each air frame the controller looks along the velocity for a wall (a surface steeper than `Physics.MinGroundNormalY`) without the `Destructible` tag and reflects the velocity off it with `Physics.BounceRestitution`; the invisible wall past the disc edge bounces the same way. A Dive or Swoop that bounces off a wall becomes a Glide. A Dive that hits the ground faster than `Physics.MinGroundBounceSpeed` bounces off it too (review note: "any non-destructible surface bounces"), keeping its forward speed, so a shallow dive skips; other states land. This replaces the dive-slide; only Swoop touchdowns slide now. Milestone 3 decides how dive impacts smash alongside this.

**Burst sound.** Only Bursts held at least 5 s get the explosion (`minHeld` on the FeelTable entries); shorter ones play a hop sound (`maxHeld`).

**Inputs never cancel each other** (review note). Space and LMB holds are tracked on their own (`Movement/JumpCheck.luau`, `ctx.PunchHold`), so pressing or releasing one never loses the other, and only releases act. A punch out of Charging keeps the Space hold; land still holding and Charging resumes. Space held in the air charges up to `Hop.HoldTime` (so you can land with a full hop, or straight into Charging), but anything past that only charges on the ground, so a big Burst can't be banked in the air. Released in the air, the hold is spent.

**The punch charges without limit** (review note: the forward twin of the Burst). `Punch.HoldBoosts` maps seconds held to lunge speed, from a tap's jab to a one-minute map-crossing launch, geometric like `Burst.HoldHeights`. It charges in any state and nothing but releasing it spends it. `Punch.ChargeTime` is now the basic charge: it sets decay, rocket strength and energy cost, which stop growing after it. 

**Charge tiers.** `Punch.Tiers` and `Burst.Tiers` mark where a hold steps up: a rising chime (`PunchTier`, `BurstTier`), a ring colour step, and, for the punch, bigger release juice (`minHeld` entries on `Dash` and `Rocket`: shake, flash, shockwave, the explosion from 15 s, a hitstop from 30 s). A hum rises while the punch charges.

**Charge rings** (review notes: bigger, mobile-HUD style, and one ring per tier instead of one slow ring). Chunky outlined concentric rings (`UI/Arc.luau`, `UI/ChargeRings.luau`), a purely visual split of the hold time: one ring per tier, each filling from the previous tier to the next, so later rings take longer. Above the head (`UI/JumpWheel.luau`): the hop ring, then one per `Burst.Tiers` stretch, all gold once the Burst hits your Power's ceiling. Beside the crosshair (`UI/PunchWheel.luau`): one per `Punch.Tiers` stretch. Adding a tier adds a ring.

**Dives keep their momentum** (review note: entering a dive stalled you). Entering a Dive turns your whole speed toward the crosshair instead of keeping only the part already heading that way. A punch during a held dive adds to it (see below).

**Momentum only grows in the air** (review note; replaces the punch decay tried earlier). While airborne nothing pulls your speed back down: the dive has no terminal speed and keeps accelerating; a punch inherits your whole speed, turns it toward the crosshair and adds its lunge on top (during a held dive it re-aims the dive); swoops trade speed only for height; a glide keeps any speed above its cruise unless you pitch up to brake, and when it levels out of a fast fall the fall speed it sheds becomes forward speed (`Glide.FallToForward`). Only surfaces and landing take speed away. A bounce keeps the speed along the surface but throws you out at no more than `Physics.MaxBounceSpeed`, and for `Physics.BounceSteerPause` after a bounce a glide stops turning toward the look so it carries away from the wall. Everything earlier in this spec that assumes a 420 terminal (the §4.6 speed stages, §4.8 hitstop and flash scaling, the "terminal smash" damage and payouts in §5–§6, and the §13 speed check) needs new reference speeds; revisit them in milestones 3–5.

**Ground feel** (review notes: hard stops were jarring, and the movement was too slidey). Space on the ground is a hop up to `Hop.HoldTime` (1 s): a tap is `Hop.Height`, and holding longer before releasing raises it toward `Hop.ChargedHeight`, with momentum untouched. Only a hold past `Hop.HoldTime` starts Charging. Nothing freezes you any more: Charging and Landing are controller-driven ground states (`Movement/GroundHold.luau`) that bleed momentum off with `Charging.Damping` and `Landing.Damping` instead of stopping it. Only Dive and Swoop touchdowns slide, and `Tech.SlideFriction` is high so a slide is a short burst; hop landings and ground punches never slide. A ground dash punch lifts off with at least `Punch.GroundDashLift`, so gravity turns it into a hop. Gliding comes from chaining bursts in the air, not from hugging the ground.

**Volume.** All buses are scaled by `Audio.BusVolume` (0.25) until the audio pass; the review found the placeholder sounds far too loud.

**Camera effects and mouse-look.** Shake, tilt and roll are visual only: the aim ray uses the base rig, so the crosshair never wanders. The §4.4 "pitch drops to −8°" is not forced, since the player owns the pitch (see milestone 1); the pull-back is distance and FOV only.

**World.** The shell's center is 1,509 below the disc (not 1,480, which poked through the 8-stud disc). Shell and halo are Ball parts scaled by a SpecialMesh, since parts cap at 2,048 studs. The cloud deck is 8 placeholder sheets at 540–900 that use default streaming, so they stream out from the Edge band.

**Deferred from §4.1–4.4** (placeholders exist for the first three items of each phase): stars (the sky needs a star skybox asset; the Atmosphere only darkens it), speed lines, heartbeat, the hang pad and breath, collectibles, wing animation, other players' Highlight and charge beam (milestone 5), and the RELEASE hint (milestone 7). Sounds are engine built-ins until the audio pass.

### Milestone 3a (the globe)

**The world is a real globe** (review note at the start of milestone 3: "I want to feel like I can fly around the world", and a long flat punch should circle it like the Flash running around the Earth). This replaces §5's flat disc, visual shell, edge curve and invisible wall. `Planets/Planet1` gives `Radius` (2,500) and `Center` (the world origin, so the globe is symmetric around it and the altar sits on top at (0, 2,500, 0); the terrain can't be dragged in Studio, so the center lives in config and the world is placed around it). Towns, forest and cliff (milestone 4) are placed on the sphere.

- **Gravity points at the center.** `workspace.Gravity` is 0; every state integrates its own gravity along `ctx.Up` (away from the center at the player), as before along world Y. Altitude is distance from the center minus the radius. The `VectorForce` gravity cancel is gone.
- **The frame rolls with the planet.** Each frame the controller rotates the velocity, heading and body direction by the change in up since the last frame (parallel transport, `MathUtil.transport`), so whatever was level stays level as you move over the curve. Level flight follows the globe: a 60 s punch (1,200 studs/s) orbits it in about five seconds at the height it was fired from, a glide laps it in about seventy, and dives, swoops and hops are unchanged. Chosen over true ballistics (where speed throws you outward and a big flat punch arcs thousands of studs up instead of around) because the Flash feel was the point.
- **Every state is controller-driven**, the ground ones too. The Humanoid's walker only knows world-Y up, so `Grounded` now walks through `GroundHold` with momentum easing toward the input (`Walk.Response`); `PlatformStand` is always on and `AlignOrientation` keeps the body upright against the local up. The Humanoid remains for the rig, animation and replication. Walking off a ledge falls like a hop's descent.
- **Camera.** The rig's up is the player's up, and yaw is measured from a reference direction that is transported with the planet, so moving in a straight line never turns the view and there is no pole. Pitch is still the player's.
- **The surface is analytic** (`shared/Globe.luau`). Parts cap at 2,048 studs and the first 1,000-radius globe felt tiny (review note), so the radius is now 2,500 (lap ≈ 15,700 studs) and no part collides as the ground: every ground query (`Globe.raycast`) returns the nearer of a world raycast, for props and buildings, and the ray's intersection with the surface sphere. Ground states already hold the body at standing height, so nothing rests on physics; a body found inside the sphere is lifted to the surface. The radius is a plain config number.
- **World build (Studio).** The visible surface is a smooth-terrain shell (review note: a scaled mesh ball can't take a texture or material and read as "standing over nothing"): a 12-stud-thick Slate sphere written voxel by voxel (`FillBall` refuses extents this large) with its outer surface tuned to sit on the analytic sphere (voxel smoothing bulges about 1.2 studs outward). Terrain gives real material detail and lighting now and hills, craters and material painting later; it doesn't collide with the player, who stands on the analytic sphere. A plain gray scaled `Ball` sits just under it as a backdrop from orbit, the halo is a scaled transparent neon ball, and the cloud deck is 160 flat sheets laid tangent to the globe between `CloudAltitudeMin` and `CloudAltitudeMax`, spread evenly (Fibonacci sphere).
- **Punch range** (review note: "across the world"). `Punch.HoldBoosts` climbs much harder now: 80 on a tap, 260 at the first charge, 1,000 at 10 s, 2,800 at 25 s, 7,000 at 60 s (a lap in about two seconds). A ground dash never aims into the floor (it goes level or up; steep aims are the rocket jump) and lifts off with `Punch.GroundDashLiftShare` of the lunge (at least `GroundDashLift`), so a charged punch from the ground launches into a flight that follows the curve instead of a 0.4 s hop into a landing.
- **Test aid.** `Dev.ChargeSpeed` (2 while testing) multiplies how fast every hold charges: hop, Burst and punch.
- **Burst heights raised** (review note: the 30 s charge wasn't high enough). `Burst.HoldHeights` now reaches 600 at 5 s, 1,600 at 10 s, 4,000 at 20 s, 7,500 at 30 s and 18,000 at 60 s; above a globe the planet visibly shrinks under you, which the flat disc never did.
- **Dives land and slide; only punches bounce** (review note: "when I dive down I shouldn't bounce, I should slide a bit unless I bunny hop; only bounce if I'm punching"). A Dive touchdown keeps its level momentum as a `Slide` at any angle (a steep dive has little and just lands), and a hop inside the chain window carries it on. The ground bounce from milestone 2 now only fires when LMB is held at contact: punching into the ground throws you back up. Swoop touchdowns still slide only from a shallow angle.
- **Open:** the Sky band altitudes (§5) still assume the old scale; the surface grid is a projected placeholder; the shell's "fake town lights" idea is moot once towns sit on the globe.

### Milestone 3b (polish pass, part 1: animation, charge camera, speed and touchdown juice)

**Character animation** (`Feel/Anim.luau`; replaces the §10 "one AnimationController per state" plan and the §12 nine-clip asset list for now). R15 first, with R6 fallbacks, since players use both. Two layers:

- **Locomotion** is Roblox's own stock clips (`Tuning.Anim.Clips`: idle, walk, run, jump, fall, per rig), picked by state and ground speed and played through the Animator so they replicate. The default `Animate` script is disabled; the controller owns every state, so this module owns every clip.
- **Poses** are joint offsets in `Tuning.Poses`, written into each Motor6D's C0 on top of the playing clip, summed per joint with weights and eased (`Anim.Response`), snapping on state enters and punches (`SnapResponse`, §4.10). Joints are named abstractly (Root, Waist, Neck, shoulders, elbows, hips, knees) and mapped per rig; R6 has no waist, elbows or knees and skips them. Poses: jump-charge **squat** (a full-body crouch that deepens with the Space hold and holds at depth in Charging, with a tremble that grows with the Burst charge; this replaces §4.1's one-knee kneel), punch **wind-back** (upper body only, so it layers over walking: waist and root twist, punching arm pulled back with the elbow bent, guard arm up, deeper past the basic charge through the tiers, trembling at the top), the **punch** itself (a one-shot kicked on release that decays), takeoff **stretch** and touchdown **squash** scaled by landing speed (§4.9), **Burst** extension, **Hang** limp pose with a breathing sway, **Glide** wings-out with arm flex on bank, **Dive** arrow with the lead fist forward and the second fist joining over `DiveTightenTime`, plus a speed vibration, **Swoop** arch, **Slide** legs-forward. No wing mesh exists yet; wing poses wait for the skin.

**Charge camera** (`Feel/Drivers.luau`, `Tuning.Drive`). Both charges pull the camera in and narrow the FOV the longer you hold: the jump charge while Space is held on the ground (hop hold and Charging alike), the punch charge while LMB is held. Log-shaped over the whole hold curve so the first seconds move it most; both add if held together; eases back out on release. This replaces §4.1's FOV tween.

**Driven effects.** Per spec §11 the dive FOV is a per-frame function of speed, not a tween; `Drivers` now owns everything that follows live state each frame and adds to the FeelTable's layers through new driven layers on each sink: FOV by speed (the speed meter), shake by speed (the danger meter), a speed-driven rush loop over the state wind, speed lines streaming back off the body, embers and orange heat edges past `HeatStart` (the §4.6 300+ stage, re-referenced for a world with no terminal speed), a radial-blur stand-in in Dive, and the fist glow (a light and motes on the punching hand) while a punch charges. Pebbles lift off the ground crack while a Burst charges (§4.1).

**Touchdowns hit by speed** (FeelTable `Landing`, `Slide`, `Bounce`; the §4.8 impact juice scaled to a landing until the Impact state and destruction arrive in milestone 4). Entries can gate on the event's speed (`minSpeed`) and scale with it (`bySpeed`, up to `fullSpeed`; `durMin` for hitstop). A hop landing is a thud and a puff; a fast dive is a hitstop (0.08 to 0.18 s by speed), a flash, a desaturation dip, two shockwave rings, a crater, flying debris, a dust wall, an ambient duck and a camera pull-back. Bounces and ground punches scale the same way. Dive entry snaps the wings shut with an FOV kick; Swoop gets its §4.7 time dip, FOV drag and bright trails. Punch releases spawn sparks.

**Open:** the dive "oh no" target approach (§4.6), the heartbeat and hang breath (no assets), wing poses (no wing mesh), the RELEASE hint, and replicating poses to other players (milestone 5).

**Aesthetics pass (same day, review note: "the orange is a bit ugly"; take the juice to an industry standard rather than the bare minimum).**

- **Textures of our own.** Six white-on-alpha textures generated for the game and uploaded as image assets (ids in `Tuning.Vfx`): a soft radial vignette with a clear middle, a glow sprite, a soft ring, radial ground cracks, anime-style radial speed lines with a clear middle, and a soft streak. Everything is tinted in code, so one vignette serves as the black vignette and the warm heat rim. The generator script lives outside the repo (scratch); regenerate and re-upload rather than hand-edit.
- **Screen.** The four linear edge bands are gone. The vignette is the radial texture, kept square and oversized so it reads as a circle on any aspect ratio. The §4.6 "orange rim" is the same texture in pale amber at low alpha plus a warm ColorCorrection tint and embers, never a flat orange. Speed is read mostly through the screen-space speed-line overlay (two copies counter-rotating and flickering, clear centre), with the world streak particles kept sparse. The white flash is slightly warm.
- **Camera shake is trauma-style** (`Tuning.CameraShake`): the FeelTable amount is a trauma level, the camera applies trauma^1.6 split into a positional offset and a rotational wobble (roll, pitch, yaw) from smooth noise, so small hits whisper and big ones hit. Kicks have curves (`curve` on an entry: `quad`, `expo`, `spring`, `hold`): recoils spring back with one overshoot, flashes and shakes are expo (most of the hit in the first frames).
- **Ground effects are decals, not neon primitives.** Shockwaves are the soft ring on a flat part with expo-out growth that hangs and fades, in two layers (bright tight ring, wider faint one). The charge crack and the crater use the crack texture; a crater is a scorched soft disc under randomly rotated cracks. Impacts, bursts, punches and bounces get a 3D glow sprite that scales up and fades (`Flash3D`) and a dust wall rising from the shockwave's edge (`DustRing`, a cylinder-shell emitter). Debris spins and bounces once off the globe. Sparks are hot streaks (white → amber, pulled down). Trails use the streak texture, taper, and stream on their own above a speed. The fist glow is a sprite plus light plus motes.
- **Still placeholder:** sounds (engine built-ins), the character (no wings), the world. The next aesthetic step is an audio pass and wing meshes.

### Milestone 3b (part 2: bigger globe, mobile controls)

**The globe doubled again** (review note: 2,500 still felt small). `Planet1.Radius` is 5,000 (a lap is about 31,400 studs). The charge curves scale with it so the long holds mean the same thing on the bigger ball: `Punch.HoldBoosts` tops out at 14,000 (still a lap in about two seconds), `Burst.HoldHeights` at 36,000, and `Burst.VelocityPerPower` and `MaxVelocity` are raised so Power 25 still reaches the top of the curve. Holds under ten seconds are unchanged. The sky bands keep their altitudes (the atmosphere is thin against the planet); a full Burst now goes far past the Edge band, which just holds its look. **World rebuilt in Studio** for the new radius: the terrain shell (same 12-stud Slate band, written in 64-stud chunks), the backdrop ball and halo (`HaloRadius`) rescaled, the altar moved to (0, 5,000, 0), and the cloud deck regenerated with 640 sheets (four times the sheets for four times the surface, same sizes and look). The spawn no longer trusts the altar's height: it takes the altar's direction and looks down onto the analytic surface for its top (`World.SpawnProbe`), so a Studio altar at an old radius can't spawn the player inside the planet (which is what happened the first time the radius changed: a respawn loop at altitude −2,500).

**Milestone 3b closed Oct 8, 2026.** Its open items (dive "oh no" approach, heartbeat, hang breath, wing poses, RELEASE hint, audio pass) carry into milestone 5.

**Mobile controls** (`Movement/TouchControls.luau`; replaces the §3 mobile line, and brings "mobile controls" forward from the after-milestone-5 list so the game can be tested on a phone). Shown only on touch devices. A dynamic thumbstick on the left `Input.Touch.StickZone` of the screen moves; dragging anywhere else looks, with the same yaw and pitch the mouse drives (`Camera.TouchSensitivity`); two buttons sit bottom-right: JUMP (everything Space does: tap hops, hold charges a Burst, in the air dives, release swoops) and PUNCH (everything LMB does, held to charge). Each touch is tracked on its own, so the stick, the look drag and both buttons work at once. They feed the same input snapshot as the keyboard, so no state knows the difference. The cheat sheet swaps its keycaps for STICK, DRAG, JUMP and PUNCH, sits top-left clear of the stick, and folds with a tappable HIDE chip. Not yet: a quality tier (§11; the phone runs the full juice until it proves it can't), haptics (§4.1), and a laser or cutter button (milestone 4 adds the mechanic).

### Milestone 4 (core loop: attack, destroy, get paid)

**Done criterion** (set at the start, from §14): diving into the town from altitude breaks a visible wave of buildings, punching through small stuff feels good, cash climbs with the combo, and you want to go up again immediately. Functional before pretty: §4.8 and §4.12 polish (hitstop silence, material break sets, health reveal, car pops, scaffolding ghosts, the smash preview and reticle magnet) is milestone 5.

- **The laser waits** (decision at the start): the punch and the dive carry the loop; the laser and cutter come after milestone 5 with the rest of the "to be planned" list.
- **Damage is speed.** There is no terminal speed any more (milestone 2), so the §5 "hits" are re-based: a contact does `speed / Smash.SpeedPerHit` hits against the catalog's Health. A hop-dive is under two hits (trees, fences, lamps), a 600 dive flattens a tower. A dive into the ground or a structure smashes everything within `Impact.RadiusBase + speed / RadiusSpeedDivisor` (§10), with the damage falling off to `Smash.EdgeDamageShare` at the edge so a town crumbles from the hit side. Anything else flying into a destructible (glide, hop, swoop, a punch dash) hits just that object plus `Smash.ContactRadius` around the contact. Below `Smash.MinSpeed` nothing counts.
- **A dive smash is the touchdown, not a state.** No `Impact` state (§3, §10): a Dive touchdown reports a Smash at the contact point and then lands or slides exactly as milestone 3a decided; the §4.8 impact frame (hitstop, flash, shockwave, crater, debris) is already the speed-scaled touchdown juice. A dive into a destructible mid-air, or onto its roof, smashes there and keeps going: destructibles never stop you (the other half of the bounce rule), so you dive through the rubble into the ground. Each object counts once per `Smash.RehitTime` while you pass through it. This settles the milestone 1 open question.
- **Server authority** (`server/DestructionAuthority.luau`, §9, §13). The client collects its contacts (Smash: position, speed, fall peak, the object touched, the attack force; Hit: the same for one object) and sends them as one `Contacts` batch per frame, never dropping any (review note: with the first version's per-contact rate limits, a fast dive through a town only landed its first contact and "destruction stopped happening at speed"). The server budgets contacts per player (`Net.ContactBudgetPerSecond`, `MaxContactsPerBatch`, replacing the §13 Impact rate limit), checks each position against the replicated character (`Net.MaxPositionError`), the speed against `Net.MaxSpeed`, clamps the fall peak (`Net.MaxFallPeak`), queries the radius itself (`GetPartBoundsInRadius` filtered to `World.Destructibles`), applies damage, pays out and broadcasts `Broken(player, origin, radius, list)` where each object carries its wave delay (`distance / Impact.WaveSpeed`), its cash and the combo count, so every client plays the same radial wave. `Rebuilt(models)` follows after `Rebuild.Delay` per object (clusters later). Breaks are not predicted on the attacking client yet: the impact frame is local anyway, and in Studio the round trip is a frame.
- **Payout** (§6): `value × (1 + fallPeak / 2,000) × (1 + 0.2 × min(combo, 20))`, the combo window 4 s server-side. Cash is session-only on the server (`server/PlayerData.luau`) and mirrored as a `Cash` attribute on the Player.
- **Chunks** (`Feel/Destruction.luau`): a prefab's parts are its chunks. On a break the client hides the prefab (locally invisible and unqueryable, so rays pass through the rubble), fires the family's `Break` feel (sound, dust, sparks, debris particles), and flings up to the catalog's `Chunks` pooled client-only copies of its parts away from the smash centre at `30 + (radius − distance) × 2` with a 0.4 upward bias, random spin, one bounce off the globe and a fade (§4.8). The pool is `Chunks.Pool` (40, the §4.12 budget); past it, breaks are particles only. Other players' breaks show chunks only within `Chunks.RemoteRange`.
- **Cash feedback** (§4.8): `UI/CashReadout` top-left, counts up; `UI/FloatingNumbers` rising muted-gold numbers at each break; `UI/ComboCounter` top-right from ×2 with a thin timer bar, a pop and a rising arpeggio note per tick (FeelTable `ComboTick`, `pitchBySpeed`), holding the combo's total back from the readout until the window lapses (`ComboEnd` chime).
- **The world is generated per server** (review note: four hand-placed patches left 99% of the globe empty; the layout should be semi-random per server, the same for everyone in it, with intentional sections like a town or forest and things everywhere between). Studio builds only the prefab templates (`ServerStorage.Prefabs`: one Model per catalog entry, from primitives for now, each with the tag, the `Prefab` attribute and its chunk parts, plus the non-destructible `CliffRock`); `server/WorldGen.luau` clones them over the whole globe at server start from one seed (`Dev.WorldSeed`, or a new one per server, printed per §13): the first town always `WorldGen.FirstTownDistance` from the altar (the §8 first target), then towns, hamlets, forests and cliffs at random spots at least `SectionClear` apart, then `ScatterTrees` and `ScatterRocks` loose everywhere, clear of the altar and of town centres, with random scale. Sections keep their layouts (town: a 6 × 4 grid with towers in the middle, cars and lamps on the streets; hamlet: a ring of houses and fences; forest: 70 trees and 15 rocks; cliff: a raised rock with a mast). Around 4,300 models; streaming keeps a client to the cap within its radius. This replaces the §5 "hand-placed slots" and the CLAUDE.md rule that placed content is never generated at runtime: templates are Studio-built, placement is generated.
- **Momentum clears weak things; big buildings need the attack; collisions have weight** (review notes, in order: "I can't collide with any of them"; "I just bounce off buildings, I want to explode through them"; then "I should explode things even when I just crash through without punching, punching adds force, different buildings have different HP so my falling momentum clears trees but I bounce off big buildings unless I attack, and going through should cost momentum relative to how close I was to bouncing"). Below `Smash.MinSpeed` a destructible is a wall: air states bounce off it, ground states slide along it (`slideAlongWalls`, which also finally stops walking through any wall). Faster, a contact deals `speed / SpeedPerHit` hits times the attack force: `DiveMult` in a dive, `PunchMult` while LMB is held or within `PunchWindow` of a punch firing (so a punch is the attack that opens big buildings). Health is the catalog value times the prefab's size (a 3× tower takes 30 hits; its value scales the same). If the hit finishes the object you break through and lose `PassLoss × (health left / hits)` of your speed, so a tree barely slows a dive and a tower you only just cracked takes most of your momentum; otherwise it stands, keeps the damage (the next hit may finish it), and you bounce off it like a wall. The client predicts this from the damage it has dealt (reset on every server break and rebuild); the server applies the same formula, with the object touched taking the full hit and the force only clamped (`MaxForceMult`; validating it is anti-exploit work). **Retuned the same evening** (review note: "things still barely feel destructible; I expect destruction-simulator stuff, I punch the building and it explodes into pieces"): `SpeedPerHit` is 25 (a glide clears trees, a hop-dive a house, a 250 dive a tower), health grows with size only as `scale ^ HealthBySize` (0.5), a punch always finishes the object it touches and smashes `PunchRadiusScale` of a dive's radius around it, the punch window is 1 s so a dash reaches its target, and the chunk pool is 120 with a harder, higher burst.
- **Feedback scales with speed all the way up** (review note: crashing at mach 10 must feel more intense than at low speed). The touchdown and smash juice's ordinary layer now reaches full strength at 900 instead of 450, and a heavy layer grows from 600 to 2,000 on top (a longer freeze, a harder and longer shake, a third wide ring, a wall of debris, a deeper pull-back). Hits get their own impact frame past 250. Every `Broken` broadcast carries the contact speed, so chunks fly and spin harder with it (`Chunks.SpeedByContact`, `SpinByContact`) and the per-family break effects pile on extra dust, sparks and debris past 200.
- **Sizes vary** (review note: the current buildings are the smallest they should ever be; the biggest should be much taller, and trees taller overall). Every placement takes a uniform random scale from `WorldGen.Scale` per prefab: towers up to 3.2×, shops 2.3×, houses 1.9×, trees 1.1–2.6× on a taller template (22-stud trunk, 17-stud canopy), rocks to 2.2×. The town grid widened (`TownSpacing`, `TownStreet`) to fit the biggest buildings.
- **Trees and density** (review note: trees too small to hit, world still empty). Rocks are 30% bigger. Generation adds groves (`WorldGen.Groves` small clumps that squeeze between the big sections with `GroveClear`), and the counts are up to 10 towns, 14 hamlets, 30 forests of 100 trees, 160 groves, 8 cliffs and 6,000 loose trees with 1,500 rocks, about 13,000 prefabs. The tap dash lunge dropped from 80 to 45 (`Punch.HoldBoosts`).
- **Test aid:** F4 in Studio smashes the ground under the player at `Dev.TestSmashSpeed`.
- **Movement rays see the world again.** Found during the solidity fix: the movement and aim raycasts carried the `Characters` collision group, which the server makes non-collidable with `Default`, so every world part had been invisible to them since milestone 3a (nothing noticed because the globe had no walls). Rays now use their own `MovementRays` group, collidable with the world and never with characters.
- **Streaming note:** in Play Solo nearly all 4,500 models stream in, because the engine streams in opportunistically when memory allows and only streams out under pressure. Expected; the per-client budget on a phone is what to measure (§11).
- **Open:** a broken prefab that streams out and back in reappears intact on that client until its rebuild; the 20% car pop; cluster rebuild timing and scaffolding ghosts; the hitstop silence and staggered wave sounds; the aim magnet and smash preview; records and persistence.

### Milestone 5 (destruction polish)

**Arcade feedback** (review note at the milestone 4 review: "actual toasts when you get money or break stuff, the combo in the top centre with the number popping in and what the combo is called, like the driving arcade games"). Three pieces, all driven by the server's credits (`Feel/Destruction.Credited`, which now carries the prefab name):

- **Combo banner** (`UI/ComboBanner.luau`, replaces the top-right counter): top centre, a big "×N" that pops on every credit (a spring kick on a `UIScale`), the combo's name under it from `Ui.ComboNames` by count (NICE, SWEET, RAMPAGE, WRECKING BALL, DEMOLITION, CATACLYSM, GODFALL), stepping up with a bigger pop, a blink and a brighter chime (FeelTable `ComboTier`, pitch by tier), a thin bar timing the window, and when the window lapses the number becomes "+$total" and slides down into the cash readout (`ComboEnd`). The number warms from white toward hot orange as the tier climbs.
- **Toasts** (`UI/Toasts.luau`): a stack above the bottom centre, one card per object broken ("TOWER  +$1,069"), the name in its material family's colour, big (`Ui.ToastBigScale`) when it pays at least `Ui.ToastBigCash`; a new card pops in at the bottom and the rest ease up; each fades after `Ui.ToastTime`.
- **Cash readout** pops and flashes white whenever its total climbs.

**The flying punch** (review note: "when I release the punch I just look like I'm diving, not punching"). For `Smash.PunchWindow` after a release, in the air, a `Poses.PunchFlight` pose (lead fist straight out along the flight, the other arm pulled back, body straight and twisted into it, head up) holds for `Anim.PunchFlightHold` of the window then eases out, and while it is in it overrides the state's own pose by `Anim.PunchFlightOverride`, so a dash reads as a punch over a glide or a dive. The old 0.3 s `PunchOut` kick still gives the snap.

**Open for this milestone:** the §4.8 impact silence and staggered wave sounds, material break sound sets, health reveal, the smash preview and reticle magnet, hint cleanup, the 3b carry-overs (audio pass, wing meshes and poses, the dive "oh no" approach, heartbeat, hang breath, RELEASE hint), the car pop, cluster rebuild with scaffolding ghosts.

**Movement extends the combo** (review note: "doing movement tech or charging Bursts should count as a combo extender, so you can keep a combo between destructible areas"). While in Charging, Burst, Hang, Dive, Swoop or Slide (`Combo.ExtendStates`) the combo window keeps refilling, and a chain hop, a punch firing or a bounce refills it once; the window only runs down while walking, landing, hopping or gliding plainly. The client pings `ComboAlive` at most every `Combo.PingInterval` (`Combat/Smash.luau`); the server refills a window that is still open; the banner's bar visibly refills. Trusting the ping is anti-exploit work for later.

**Density and size, second push** (review note: "more density, bigger destructibles"). Towns are now random grids of `TownColsMin`–`Max` by `TownRowsMin`–`Max` (up to 70 lots) with towers nearest the centre by share; counts and scale ranges are up again (towers to 4.5×, trees 1.3–3.2×, 14 towns, 20 hamlets, 40 forests, 260 groves, 9,000 loose trees), about 20,000 prefabs.

**Combo rule corrected** (review note: "not while charging; on release, when you perform the Burst"): Charging left `Combo.ExtendStates`; entering Burst refills the window once and the Burst and Hang states keep it refilled, so a parked charge can't hold a combo forever.

**Haptics** (review request for the phone test; spec §4.1, §4.2, §4.6–4.8): `Feel/Haptics.luau` is a FeelTable sink (`haptic = "Rumble"` kicks, 0–1 on the large motor, `Haptics.SmallShare` on the small) driving every vibrating input the device reports (a gamepad, or the phone on touch). Entries on Burst (by charge), touchdowns and smashes (by speed), hits, bounces, dashes, rocket jumps, swoops, big breaks and combo tiers. The §4.1 charge pulse is still open.

**Polish pass, first batch** (from an independent review of §4 against the implementation; all built from existing sinks and engine sounds):

- **Big breaks break big**: objects worth `Smash.BigBreakValue` or more add `BreakBig` (flash sprite, ring, dust wall, boom, jolt, rumble) over their material break, and every family a prefab is made of plays (glass over stone), not one at random.
- **Hit flash**: chunks spawn white and settle to their colour over `Chunks.FlashTime`.
- **Hitstop freezes debris**: thrown debris and chunks integrate with the time scale, so the impact freeze holds them in the air.
- **The §4.8 silence**: touchdowns and smashes duck the Wind, Music and Ui buses hard for 0.7 s (hold curve) besides Ambient; Sfx stays open so the breaks arrive through it.
- **Camera roll punches**: the unused `roll` layer now springs on hits, bounces, dashes and the heavy touchdown layer, with a random sign (`randomSign` on an entry).
- **A musical combo**: `pitchSteps` on a sound entry is a semitone scale indexed by the event's speed, so the combo tick climbs a pentatonic scale and an octave per tier.
- **Banner alive**: the number tilts on alternating sides with each pop, the bar runs hot and blinks in the last `Ui.ComboWarnTime`, and the payoff flies to the cash readout (shrinking to `Ui.ComboFlyScale`), which pops in proportion to the total; big tiers add a second note, a blink and a lean-in (`ComboEnd` gated by tier).
- **Toast merging**: the same kind breaking again while its card is up counts up on that card ("TREE ×7 +$84") and re-pops.
- **Floating numbers with weight**: sized by cash (`Ui.FloatSizePerDecade`), popping in oversized, spread sideways, white-gold past `Ui.FloatBigCash`.
- **Car pop** (§4.12, visual only): a broken car may pop half a second later (`CarPop`); chain damage into neighbours needs a server roll and waits.
- **Break sound variety**: a wide per-sound pitch `Jitter` on the break sounds.
- Not taken yet from the review: a pooled Highlight flash on hits that don't break, size-pitched break sounds and distance falloff for others' breaks, the §4.6 terminal screen pulse.

**The Burst charge builds in the air** (review note: "infinitely charge the vertical Burst even in the air; it doesn't have to be grounded past the first circle"). `JumpCheck` no longer caps the air hold at `Hop.HoldTime`: the whole Space hold counts wherever you are, tier chimes fire in the air too, and a touchdown while still holding drops straight into Charging with all of it, so a long dive hold bounces straight back up as a big Burst. This replaces the milestone 2 rule that a big Burst can't be banked in the air; releasing in the air still spends the hold (the dive's swoop).

**The ground pound's AOE reads as its radius** (review note: the impact AOE should visibly grow with speed). The smash radius already grows with speed (`Impact.RadiusBase + speed / RadiusSpeedDivisor`); now the touchdown's two rings, the dust wall and the crater, and the heavy layer's third ring and dust wall, are multiples of that radius (`bySmashRadius` on an entry) instead of fixed sizes scaled by speed, so what you see is what broke. `Impact.RadiusSpeedDivisor` is the knob for both.

**Combo refill narrowed** (review note: holding the punch charge looked like it fed the combo): only Burst and Hang refill continuously (`Combo.ExtendStates`); entering Burst, Dive, Swoop or Slide refills once (`Combo.ExtendOnEnter`), as do a chain hop, a punch release and a bounce.

**Ground pounds starved by the query cap** (review note: "the ground pound doesn't seem to hit trees"): the server's radius query returned at most the engine's default 20 parts, so a big pound in a forest damaged a handful of trees. `Net.MaxOverlapParts` (600) raises the cap.

**Combo refill, final form** (review note: "on Burst or Hang trigger, sure it can refill, but no continuing action should keep refilling; it should fill a lot based on the release"): nothing continuous refills. A Burst release refills the window plus the flight it launches (ascent plus `Hang.Time`, capped at `Combo.BurstExtendMax`), sent as the ping's extra and clamped by the server; entering a dive, swoop or slide, a chain hop, a punch release and a bounce refill the plain window once.

**Landmarks** (review note: new destructible types with different silhouettes and layers to smash, like a huge tower or a pyramid). Six new catalog entries, each a Studio template of stacked parts so every layer flies: `Pyramid` (five stepped slabs), `Skyscraper` (eight alternating stone and glass floors and a spire), `Silo` (a cylinder and dome), `Windmill` (tower, hub and four blades), `Statue` (pedestal, body, head) and `Dome` (a glass dome on a stone ring with pillars). `WorldGen.Landmarks` places them alone with a ring of lamps (`LandmarkLampRing`, scaled); a town's centre lot is a skyscraper with `TownSkyscraperChance`, a hamlet's middle a windmill with `HamletWindmillChance`. Health, chunk count and value sit in `Destructibles.Catalog` (pyramid 14 hits for $450, skyscraper 20 for $900, dome 16 for $600).

**Cutting through clusters** (review note: charged attacks bounced off tree clusters, especially their tops; the longer the charge, the faster and harder it should cut, gradually, not a switch). Two causes. Round canopy tops counted as ground, so a fast glide or punch across a grove *landed* on each canopy and the landing damped its momentum; only dives were exempt. Now any touchdown on a destructible at `Smash.MinSpeed` or more is a contact (finish it and keep flying, or land on it if it holds). And the hit and structure-smash feel used the raw speed, so every tree in a cluster hit like a wall; both now play by *effort*, the speed scaled by how much the object resisted (`health left / hits`, 0 when it gave way easily, the full speed when it stood), the same factor that scales the speed lost (`Smash.PassLoss`). A charged punch therefore cuts through a grove with almost no feedback or loss and still slams into a tower.

**Tuning after the landmark review:** the pound radius is `12 + speed / 7` (was `6 + speed / 8`; it felt small at low charges), and landmarks are monuments: at least twice their template, pyramids and statues to 5×, skyscrapers and domes to 4× (`WorldGen.Scale`), while a town's centre skyscraper keeps its own `TownSkyscraperScale` so it fits its lot.

**A punch no longer finishes its target outright** (review note: landmarks and buildings fell to small punches). The punch is a force multiplier (`Smash.PunchMult`, 2.5×) and health decides, on the client and the server alike. With `SpeedPerHit` 25: a tap punch from a walk (~70) is 7 hits, enough for trees and houses; a shop needs a short charge, a tower a few seconds (420 lunge is 42 hits), a 4× skyscraper (40 hits) the same, and a ten-second punch (1,300) clears anything in its path.

**The punch pound** (review note: punching the ground should be the ground pound, or rather amplify it; the plain fall's pound was too strong; closeness should multiply the damage and radius the way it multiplies the rocket knockback, with the charge setting the base). A plain dive landing pounds at `DiveMult` 1 and `Impact.PlainPoundScale` (0.7) of the radius. A rocket punch (aimed steeply at a surface within reach) also pounds the surface it fires off: its strength is `(lunge + momentum) × closeness × Smash.PoundStrength`, the same proximity curve as the knockback, and that strength stands in for speed in the damage and radius formulas with the punch's force on top, so a tap at point blank is a firm thump and a charged punch into the ground is a crater. The pound plays the touchdown impact frame with full-size rings (`Pound`), the server uses the full radius for any punch-forced smash, and a punch held into a dive counts as punching for the landing too.
