---
name: godot-demo-reference
description: >
  Finds a working official example in godotengine/godot-demo-projects (master, Godot 4.7) for
  the system being built: third-person character, IK, navigation, particles, UI theming, input
  remapping, save and load, pause, graphics settings. Use when designing a new Godot system and a
  known-good reference would settle how nodes are wired. Not for API signatures
  (`godot-docs-reference`) and never as code to paste without adapting to this project.
---

# Godot demo reference

The official demo repository has small complete projects. Its `master` branch declares
`config/features=("4.7")`, the same version as this game, so node names and APIs match.

## Demos relevant to GOD OF GRIMERKA

| Need in this game | Demo folder |
|---|---|
| Third-person character controller, camera | `3d/platformer`, `3d/kinematic_character`, `3d/squash_the_creeps` |
| Hands on a weapon, look-at, bone modifiers | `3d/ik` |
| Enemy pathfinding around obstacles | `3d/navigation`, `3d/navigation_mesh_chunks` |
| Hit sparks, aura, snow | `3d/particles` |
| Lights, shadows, sky, tonemap, fog | `3d/lights_and_shadows`, `3d/sky_shaders`, `3d/tonemap_color_correction`, `3d/volumetric_fog` |
| Quality presets, anti-aliasing, scaling | `3d/graphics_settings`, `3d/antialiasing`, `viewport/3d_scaling` |
| Many enemies cheaply | `3d/occlusion_culling_mesh_lod`, `3d/visibility_ranges` |
| Ragdoll on death | `3d/ragdoll_physics` |
| Smooth motion at any frame rate | `3d/physics_interpolation` |
| Damage numbers, name tags in 3D | `3d/labels_and_texts`, `3d/waypoints` |
| HUD and menu layout, theme | `gui/control_gallery`, `gui/theming_override`, `gui/multiple_resolutions` |
| Key rebinding screen | `gui/input_mapping`, `misc/joypads` |
| Save and continue | `loading/runtime_save_load`, `loading/serialization` |
| Loading a chapter without a hitch | `loading/load_threaded`, `loading/scene_changer` |
| Pause menu | `misc/pause` |
| Music that follows the beat | `audio/bpm_sync`, `audio/rhythm_game`, `audio/audio_effects` |
| Screenshots and capture | `viewport/screen_capture` |
| Simple enemy state machine | `2d/finite_state_machine` |

## How to read a demo

Fetch only the folder you need, into a **scratch directory outside the repository**:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/godotengine/godot-demo-projects.git <scratch>/demos
git -C <scratch>/demos sparse-checkout set 3d/ik
```

Or read single files through the raw URL:
`https://raw.githubusercontent.com/godotengine/godot-demo-projects/master/<folder>/<file>`.

## Rules

- Never copy a demo into `godot/` or add it to the game's repository.
- Read the demo's `project.godot` first: if `config/features` no longer says 4.7, check the API
  against `godot-docs-reference` before relying on it.
- Adapt, do not paste: this game builds its scenes in code (`godot/scripts/*.gd`), while demos use
  `.tscn` scenes. Translate the node setup into the project's style.
- Demos are MIT-licensed; if a non-trivial piece is adapted, say so in the commit message.
