# Ruby OpenGL — Maze + Medkits

A short demo: a colorful rotating 3D cube in Ruby + OpenGL via GLFW, with a small multi-room maze, collectible medkits, player health, textured surfaces, and an on-screen status bar.

## Dependencies

- Ruby 3+ ([RubyInstaller](https://rubyinstaller.org/) on Windows)
- [GLFW](https://www.glfw.org/)
  - **macOS:** `brew install glfw`
  - **Debian/Ubuntu:** `sudo apt install -y libglfw3`
  - **Windows:** download [GLFW pre-compiled binaries](https://www.glfw.org/download.html) and place `glfw3.dll` next to `cube.rb` (or on `PATH`). Alternatively with MSYS2: `pacman -S mingw-w64-x86_64-glfw`. OpenGL comes with the GPU drivers — no separate install.
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

- **Plus-shaped maze** of five connected rooms (center + N/S/E/W), brick walls and tiled floors
- Doorways between the center and each arm room; solid wall collision (including internal walls)
- Spinning textured cube in the **center** room (bounding-sphere collision — you cannot walk through it)
- **Medkits** — one per room; walk into one to collect it and restore health
- **Player HP** shown on the status bar (starts at 50 / 100; each medkit heals +25, capped at max)
- First-person walking camera (move freely through the maze)
- Per-face solid colors **or** 2D textures on the cube (toggle)
- Continuous rotation around X/Y/Z (can be paused / speed-scaled)
- Status bar at the top of the viewport (also mirrored in the window title)

### Maze layout

```
          [ North ]
              |
[ West ] — [Center] — [ East ]
              |
          [ South ]
```

You spawn in the center room, south of the cube. Door openings connect each arm to the center.

### Medkits & health

| Rule | Value |
| --- | --- |
| Starting HP | 50 / 100 |
| Medkit heal | +25 HP (capped at max) |
| Pickup | Walk within ~0.85 units of a medkit |
| Appearance | Small white box with a red cross (bobs slightly) |

Collecting a medkit removes it and prints a short message to the terminal (room name, HP change, kits remaining).

### Textures

Texture files live in `textures/` as binary PPM (P6) images:

| File | Name | Used for |
| --- | --- | --- |
| `textures/brick.ppm` | BRICK | Maze walls (also selectable on the cube) |
| `textures/floor_tiles.ppm` | FLOOR | Maze floors (square tiles) |
| `textures/checker.ppm` | CHECKER | Cube option |
| `textures/wood.ppm` | WOOD | Cube option |
| `textures/tiles.ppm` | TILES | Cube option |

Default cube mode is textured (brick). Press **T** to switch the cube back to flat colors. Maze materials stay fixed.

### Controls

| Input | Action |
| --- | --- |
| **W A S D** / **arrows** | Move relative to the camera (forward / strafe / back) |
| **Q / E** | Turn left / right |
| **Left mouse drag** | Look around (yaw + pitch) |
| Walk into medkit | Collect it and heal |
| **Space** | Pause / resume cube rotation |
| **T** | Toggle cube color / texture |
| **[ / ]** | Previous / next cube texture |
| **1 … 5** | Select cube texture by index (also enables texture mode) |
| **+ / −** | Rotation speed from 0% to 100% (steps of 5%). Default 50% ≈ 0.2 rev/s; 100% = 10 rev/s |
| **Esc** | Quit |

Movement is blocked by maze walls and the solid cube.

### Status bar

The top strip shows live values:

- **FPS** — frames per second (updated about twice per second)
- **HP** — current / max health
- **KIT** — medkits still left in the maze
- **ROT** — `ON` or `OFF` (whether the cube is spinning)
- **SPD** — rotation speed from `0%` to `100%` (50% ≈ 0.2 rev/s, 100% = 10 rev/s)
- **COLOR** or **TEX:name** — current cube surface mode / texture
- **POS** — walker position on the floor (`x,z`)
- **YAW** — look direction in degrees
