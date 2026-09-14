# Ruby OpenGL — Rotating Cube

A short demo: a colorful rotating 3D cube in Ruby + OpenGL via GLFW, with keyboard/mouse camera controls, textured faces, and an on-screen status bar.

## Dependencies

- Ruby 3+
- [GLFW](https://www.glfw.org/) (`brew install glfw` on macOS)
- gem `opengl-bindings`

```bash
bundle install
# or:
gem install opengl-bindings
```

## Run

```bash
ruby cube.rb
```

Close the window or press **Esc** to quit.

## Features

- GLFW window (800×600) with depth testing and multisampling
- Immediate-mode OpenGL cube (`glBegin` / `GL_QUADS`)
- Per-face solid colors **or** 2D textures (toggle)
- Continuous rotation around X/Y/Z (can be paused / speed-scaled)
- Interactive camera: zoom and yaw
- Status bar at the top of the viewport (also mirrored in the window title)

### Textures

Texture files live in `textures/` as binary PPM (P6) images:

| File | Name | Look |
| --- | --- | --- |
| `textures/brick.ppm` | BRICK | Brick masonry |
| `textures/checker.ppm` | CHECKER | Checkerboard |
| `textures/wood.ppm` | WOOD | Wood grain |
| `textures/tiles.ppm` | TILES | Ceramic tiles |

Default mode is textured (brick). Press **T** to switch back to flat colors.

### Controls

| Input | Action |
| --- | --- |
| **Space** | Pause / resume cube rotation |
| **T** | Toggle color / texture surface |
| **[ / ]** | Previous / next texture |
| **1 … 4** | Select texture by index (also enables texture mode) |
| **+ / −** | Rotation speed from 0% to 100% (main keyboard or keypad; steps of 5%). Default 50% ≈ 0.2 rev/s; 100% = 10 rev/s |
| **↑ / ↓** | Zoom in / out (clamped between distance 2 and 20) |
| **← / →** | Yaw the camera around its vertical axis; a full 360° returns the same view of the cube |
| **Left mouse drag** | Same yaw as the arrow keys |
| **Scroll wheel** | Zoom (same limits as ↑ / ↓) |
| **Esc** | Quit |

### Status bar

The top strip shows live values:

- **FPS** — frames per second (updated about twice per second)
- **ROT** — `ON` or `OFF` (whether the cube is spinning)
- **SPD** — rotation speed from `0%` to `100%` (50% ≈ 0.2 rev/s, 100% = 10 rev/s)
- **COLOR** or **TEX:name** — current surface mode / texture
- **DIST** — camera distance from the cube
- **YAW** — camera yaw angle in degrees
