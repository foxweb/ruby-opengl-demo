# Ruby OpenGL — Rotating Cube

A short demo: a colorful rotating 3D cube in Ruby + OpenGL via GLFW, with keyboard/mouse camera controls and an on-screen status bar.

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
- Immediate-mode OpenGL cube (`glBegin` / `GL_QUADS`), one color per face
- Continuous rotation around X/Y/Z (can be paused)
- Interactive camera: zoom and yaw
- Status bar at the top of the viewport (also mirrored in the window title)

### Controls

| Input | Action |
| --- | --- |
| **Space** | Pause / resume cube rotation |
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
- **DIST** — camera distance from the cube
- **YAW** — camera yaw angle in degrees
