#!/usr/bin/env ruby
# frozen_string_literal: true

# Rotating colorful 3D cube in a small multi-room maze — Ruby + OpenGL (GLFW)
# Collect medkits to restore HP. First-person walk camera with wall + cube collision.
require 'opengl'
require 'glfw'

OpenGL.load_lib

glfw_lib =
  case RUBY_PLATFORM
  when /darwin/
    Dir['/opt/homebrew/lib/libglfw.dylib', '/usr/local/lib/libglfw.dylib'].find { |p| File.exist?(p) } ||
      'libglfw.dylib'
  when /mswin|mingw|cygwin/
    'glfw3.dll'
  else
    'libglfw.so.3'
  end

if File.absolute_path?(glfw_lib)
  GLFW.load_lib(File.basename(glfw_lib), File.dirname(glfw_lib))
else
  GLFW.load_lib(glfw_lib)
end

include OpenGL
include GLFW

WIDTH  = 800
HEIGHT = 600

CAMERA_MOVE_SPEED = 3.5   # units per second (walk)
CAMERA_TURN_SPEED = 90.0  # degrees per second (arrow keys)
CAMERA_EYE_HEIGHT = 1.6   # above the floor
MOUSE_LOOK_SENS   = 0.15  # degrees per pixel
PITCH_MIN         = -85.0
PITCH_MAX         = 85.0
PLAYER_MARGIN     = 0.35  # keep away from walls
PLAYER_RADIUS     = 0.30  # collision radius vs the cube
SPEED_STEP        = 0.05  # 5% per +/- key press
RPS_AT_HALF       = 0.2   # revolutions/sec at 50% speed
RPS_AT_FULL       = 10.0  # revolutions/sec at 100% speed
# Relative tumble weights (largest axis defines "one revolution")
SPIN_WEIGHT_X     = 50.0
SPIN_WEIGHT_Y     = 35.0
SPIN_WEIGHT_Z     = 20.0

FLOOR_Y     = -1.2
WALL_TOP    = 3.5
CUBE_SCALE  = 0.55
# Keep tumbling cube clear of the floor (bounding sphere = half_diag).
CUBE_RADIUS = CUBE_SCALE * Math.sqrt(3.0)
CUBE_CENTER_Y = FLOOR_Y + 0.35 + CUBE_RADIUS
# Solid collision uses the same bounding sphere (always blocks while tumbling).
CUBE_COLLISION_RADIUS = CUBE_RADIUS
WALL_TILE_V = 3.0
WALL_THICK  = 0.18
DOOR_HALF   = 1.25
# Plus-shaped maze: center room ±ARM_INNER, arms out to ARM_OUTER.
ARM_INNER   = 4.0
ARM_OUTER   = 12.0
FLOOR_UV_PER_UNIT = 0.5  # texture repeats per world unit
WALL_UV_PER_UNIT  = 0.5

# Player health
HP_START    = 50
HP_MAX      = 100
MEDKIT_HEAL = 25
MEDKIT_PICKUP_R = 0.85
MEDKIT_SIZE = 0.28

# Floor rectangles: [x0, x1, z0, z1] — five rooms in a plus.
FLOORS = [
  [-ARM_INNER, ARM_INNER, -ARM_INNER, ARM_INNER],   # center (cube)
  [-ARM_INNER, ARM_INNER, -ARM_OUTER, -ARM_INNER],  # north
  [-ARM_INNER, ARM_INNER, ARM_INNER, ARM_OUTER],    # south
  [ARM_INNER, ARM_OUTER, -ARM_INNER, ARM_INNER],    # east
  [-ARM_OUTER, -ARM_INNER, -ARM_INNER, ARM_INNER]   # west
].freeze

# Wall segments: horizontal (fixed z) or vertical (fixed x), with a door gap on the inner cross.
# type: :h => {z:, x0:, x1:}; type: :v => {x:, z0:, z1:}
WALL_SEGS = begin
  d = DOOR_HALF
  i = ARM_INNER
  o = ARM_OUTER
  [
    { type: :h, z: -o, x0: -i, x1: i },                 # north outer
    { type: :h, z:  o, x0: -i, x1: i },                 # south outer
    { type: :v, x: -o, z0: -i, z1: i },                 # west outer
    { type: :v, x:  o, z0: -i, z1: i },                 # east outer
    { type: :h, z: -i, x0: -o, x1: -d },                # north interface (left)
    { type: :h, z: -i, x0:  d, x1:  o },                # north interface (right)
    { type: :h, z:  i, x0: -o, x1: -d },                # south interface (left)
    { type: :h, z:  i, x0:  d, x1:  o },                # south interface (right)
    { type: :v, x: -i, z0: -o, z1: -d },                # west interface (north)
    { type: :v, x: -i, z0:  d, z1:  o },                # west interface (south)
    { type: :v, x:  i, z0: -o, z1: -d },                # east interface (north)
    { type: :v, x:  i, z0:  d, z1:  o }                 # east interface (south)
  ].freeze
end

# One medkit per room (center offset so it is clear of the cube).
MEDKIT_SPAWNS = [
  { x: 2.6, z: 2.6, room: 'center' },
  { x: 0.0, z: -8.0, room: 'north' },
  { x: 0.0, z: 8.0, room: 'south' },
  { x: 8.0, z: 0.0, room: 'east' },
  { x: -8.0, z: 0.0, room: 'west' }
].freeze

FACES = [
  # front
  { color: [1.0, 0.25, 0.25],
    verts: [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]],
    uvs: [[0, 0], [1, 0], [1, 1], [0, 1]] },
  # back
  { color: [0.25, 1.0, 0.25],
    verts: [[-1, -1, -1], [-1, 1, -1], [1, 1, -1], [1, -1, -1]],
    uvs: [[1, 0], [1, 1], [0, 1], [0, 0]] },
  # top
  { color: [0.25, 0.45, 1.0],
    verts: [[-1, 1, -1], [-1, 1, 1], [1, 1, 1], [1, 1, -1]],
    uvs: [[0, 1], [0, 0], [1, 0], [1, 1]] },
  # bottom
  { color: [1.0, 0.85, 0.15],
    verts: [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]],
    uvs: [[0, 0], [1, 0], [1, 1], [0, 1]] },
  # right
  { color: [1.0, 0.35, 0.9],
    verts: [[1, -1, -1], [1, 1, -1], [1, 1, 1], [1, -1, 1]],
    uvs: [[1, 0], [1, 1], [0, 1], [0, 0]] },
  # left
  { color: [0.15, 0.9, 0.95],
    verts: [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]],
    uvs: [[0, 0], [1, 0], [1, 1], [0, 1]] }
].freeze

TEXTURE_DIR = File.join(__dir__, 'textures')
TEXTURES = [
  { name: 'BRICK',   file: 'brick.ppm' },
  { name: 'CHECKER', file: 'checker.ppm' },
  { name: 'WOOD',    file: 'wood.ppm' },
  { name: 'TILES',   file: 'tiles.ppm' },
  { name: 'FLOOR',   file: 'floor_tiles.ppm' }
].freeze

STATUS_BAR_H = 28

# 5x7 bitmap font (bit0 = left). Space and unsupported chars are blank.
FONT_5X7 = {
  ' ' => [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
  '-' => [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00],
  '.' => [0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C],
  ':' => [0x00, 0x0C, 0x0C, 0x00, 0x0C, 0x0C, 0x00],
  '|' => [0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
  '%' => [0x19, 0x1A, 0x04, 0x04, 0x0B, 0x13, 0x00],
  '/' => [0x01, 0x02, 0x04, 0x04, 0x08, 0x10, 0x00],
  '0' => [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
  '1' => [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
  '2' => [0x0E, 0x11, 0x01, 0x06, 0x08, 0x10, 0x1F],
  '3' => [0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E],
  '4' => [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
  '5' => [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
  '6' => [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
  '7' => [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
  '8' => [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
  '9' => [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
  'A' => [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
  'B' => [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
  'C' => [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E],
  'D' => [0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E],
  'E' => [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F],
  'F' => [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
  'G' => [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F],
  'H' => [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
  'I' => [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
  'K' => [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
  'L' => [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
  'M' => [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11],
  'N' => [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11],
  'O' => [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
  'P' => [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
  'R' => [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
  'S' => [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E],
  'T' => [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
  'U' => [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
  'W' => [0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A],
  'X' => [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
  'Y' => [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04]
}.freeze

state = {
  rotating: true,
  speed: 0.5, # 0.0 .. 1.0 → 0% .. 100% (default 50% ≈ 0.2 rev/s)
  use_texture: true,
  texture_index: 0,
  texture_ids: [],
  # First-person walker (spawn in center room, south of the cube)
  cam_x: 0.0,
  cam_z: 3.0,
  cam_yaw: 0.0,
  cam_pitch: -8.0,
  hp: HP_START,
  max_hp: HP_MAX,
  medkits: MEDKIT_SPAWNS.map { |m| m.merge(collected: false) },
  angle_x: 0.0,
  angle_y: 0.0,
  angle_z: 0.0,
  dragging: false,
  last_mouse_x: 0.0,
  last_mouse_y: 0.0,
  fps: 0.0,
  fps_frames: 0,
  fps_accum: 0.0
}

def load_ppm(path)
  data = File.binread(path)
  m = data.match(/\AP6\s+(?:#[^\n]*\n\s*)*(\d+)\s+(?:#[^\n]*\n\s*)*(\d+)\s+(?:#[^\n]*\n\s*)*(\d+)\s/)
  raise "Bad PPM header: #{path}" unless m

  width = m[1].to_i
  height = m[2].to_i
  maxval = m[3].to_i
  raise "Unsupported PPM maxval #{maxval} in #{path}" unless maxval == 255

  pixels = data.byteslice(m.end(0), width * height * 3)
  raise "Truncated PPM: #{path}" if pixels.nil? || pixels.bytesize < width * height * 3

  # Flip vertically for OpenGL (origin at bottom-left)
  row = width * 3
  flipped = +''
  (0...height).reverse_each { |y| flipped << pixels.byteslice(y * row, row) }
  [width, height, flipped]
end

def create_texture_from_ppm(path)
  width, height, pixels = load_ppm(path)
  id_buf = '    '
  glGenTextures(1, id_buf)
  tex_id = id_buf.unpack1('L')

  glBindTexture(GL_TEXTURE_2D, tex_id)
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, pixels)
  glBindTexture(GL_TEXTURE_2D, 0)
  tex_id
end

def load_all_textures
  TEXTURES.map do |tex|
    path = File.join(TEXTURE_DIR, tex[:file])
    abort "Missing texture: #{path}" unless File.file?(path)
    { name: tex[:name], id: create_texture_from_ppm(path) }
  end
end

def draw_cube(use_texture:, texture_id:)
  if use_texture
    glEnable(GL_TEXTURE_2D)
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE)
    glBindTexture(GL_TEXTURE_2D, texture_id)
    glColor3f(1.0, 1.0, 1.0)
  else
    glDisable(GL_TEXTURE_2D)
  end

  glBegin(GL_QUADS)
  FACES.each do |face|
    glColor3f(*face[:color]) unless use_texture
    face[:verts].each_with_index do |(x, y, z), i|
      u, v = face[:uvs][i]
      glTexCoord2f(u, v) if use_texture
      glVertex3f(x, y, z)
    end
  end
  glEnd

  if use_texture
    glBindTexture(GL_TEXTURE_2D, 0)
    glDisable(GL_TEXTURE_2D)
  end
end

def draw_textured_quad(texture_id, corners)
  # corners: [[x,y,z,u,v], ...] CCW, facing the camera / room interior
  glEnable(GL_TEXTURE_2D)
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE)
  glBindTexture(GL_TEXTURE_2D, texture_id)
  glColor3f(1.0, 1.0, 1.0)
  glBegin(GL_QUADS)
  corners.each do |x, y, z, u, v|
    glTexCoord2f(u, v)
    glVertex3f(x, y, z)
  end
  glEnd
  glBindTexture(GL_TEXTURE_2D, 0)
  glDisable(GL_TEXTURE_2D)
end

def draw_floor_rect(tiles_tex, x0, x1, z0, z1)
  fy = FLOOR_Y
  u0 = 0.0
  v0 = 0.0
  u1 = (x1 - x0) * FLOOR_UV_PER_UNIT
  v1 = (z1 - z0) * FLOOR_UV_PER_UNIT
  draw_textured_quad(tiles_tex, [
    [x0, fy, z0, u0, v0],
    [x1, fy, z0, u1, v0],
    [x1, fy, z1, u1, v1],
    [x0, fy, z1, u0, v1]
  ])
end

# Wall along X at fixed z (faces toward +Z if flip is false).
def draw_wall_h(brick_tex, z, x0, x1, face_positive_z:)
  fy = FLOOR_Y
  top = WALL_TOP
  wu = (x1 - x0).abs * WALL_UV_PER_UNIT
  wv = WALL_TILE_V
  if face_positive_z
    draw_textured_quad(brick_tex, [
      [x0, fy,  z, 0.0, 0.0],
      [x1, fy,  z, wu,  0.0],
      [x1, top, z, wu,  wv],
      [x0, top, z, 0.0, wv]
    ])
  else
    draw_textured_quad(brick_tex, [
      [x1, fy,  z, 0.0, 0.0],
      [x0, fy,  z, wu,  0.0],
      [x0, top, z, wu,  wv],
      [x1, top, z, 0.0, wv]
    ])
  end
end

# Wall along Z at fixed x (faces toward +X if flip is false).
def draw_wall_v(brick_tex, x, z0, z1, face_positive_x:)
  fy = FLOOR_Y
  top = WALL_TOP
  wu = (z1 - z0).abs * WALL_UV_PER_UNIT
  wv = WALL_TILE_V
  if face_positive_x
    draw_textured_quad(brick_tex, [
      [x, fy,  z1, 0.0, 0.0],
      [x, fy,  z0, wu,  0.0],
      [x, top, z0, wu,  wv],
      [x, top, z1, 0.0, wv]
    ])
  else
    draw_textured_quad(brick_tex, [
      [x, fy,  z0, 0.0, 0.0],
      [x, fy,  z1, wu,  0.0],
      [x, top, z1, wu,  wv],
      [x, top, z0, 0.0, wv]
    ])
  end
end

def draw_maze(brick_tex, tiles_tex)
  FLOORS.each { |x0, x1, z0, z1| draw_floor_rect(tiles_tex, x0, x1, z0, z1) }

  t = WALL_THICK * 0.5
  WALL_SEGS.each do |seg|
    case seg[:type]
    when :h
      draw_wall_h(brick_tex, seg[:z] + t, seg[:x0], seg[:x1], face_positive_z: true)
      draw_wall_h(brick_tex, seg[:z] - t, seg[:x0], seg[:x1], face_positive_z: false)
    when :v
      draw_wall_v(brick_tex, seg[:x] + t, seg[:z0], seg[:z1], face_positive_x: true)
      draw_wall_v(brick_tex, seg[:x] - t, seg[:z0], seg[:z1], face_positive_x: false)
    end
  end
end

def wall_aabbs
  t = WALL_THICK * 0.5
  WALL_SEGS.map do |seg|
    case seg[:type]
    when :h
      { min_x: [seg[:x0], seg[:x1]].min, max_x: [seg[:x0], seg[:x1]].max,
        min_z: seg[:z] - t, max_z: seg[:z] + t }
    when :v
      { min_x: seg[:x] - t, max_x: seg[:x] + t,
        min_z: [seg[:z0], seg[:z1]].min, max_z: [seg[:z0], seg[:z1]].max }
    end
  end
end

WALL_AABBS = wall_aabbs.freeze

def draw_box(x0, y0, z0, x1, y1, z1, r, g, b)
  glColor3f(r, g, b)
  glBegin(GL_QUADS)
  # +Z
  glVertex3f(x0, y0, z1); glVertex3f(x1, y0, z1); glVertex3f(x1, y1, z1); glVertex3f(x0, y1, z1)
  # -Z
  glVertex3f(x1, y0, z0); glVertex3f(x0, y0, z0); glVertex3f(x0, y1, z0); glVertex3f(x1, y1, z0)
  # +Y
  glVertex3f(x0, y1, z1); glVertex3f(x1, y1, z1); glVertex3f(x1, y1, z0); glVertex3f(x0, y1, z0)
  # -Y
  glVertex3f(x0, y0, z0); glVertex3f(x1, y0, z0); glVertex3f(x1, y0, z1); glVertex3f(x0, y0, z1)
  # +X
  glVertex3f(x1, y0, z1); glVertex3f(x1, y0, z0); glVertex3f(x1, y1, z0); glVertex3f(x1, y1, z1)
  # -X
  glVertex3f(x0, y0, z0); glVertex3f(x0, y0, z1); glVertex3f(x0, y1, z1); glVertex3f(x0, y1, z0)
  glEnd
end

def draw_medkit(x, z, time)
  bob = 0.06 * Math.sin(time * 3.0 + x + z)
  y = FLOOR_Y + 0.45 + bob
  s = MEDKIT_SIZE
  glDisable(GL_TEXTURE_2D)
  # White kit body
  draw_box(x - s, y - s * 0.55, z - s * 0.7, x + s, y + s * 0.55, z + s * 0.7, 0.95, 0.95, 0.98)
  # Red cross
  arm = s * 0.22
  span = s * 0.72
  draw_box(x - arm, y - s * 0.15, z - span, x + arm, y + s * 0.75, z + span, 0.9, 0.12, 0.12)
  draw_box(x - span, y - s * 0.15, z - arm, x + span, y + s * 0.75, z + arm, 0.9, 0.12, 0.12)
end

def draw_medkits(medkits, time)
  medkits.each do |m|
    next if m[:collected]

    draw_medkit(m[:x], m[:z], time)
  end
end

def texture_named(textures, name)
  tex = textures.find { |t| t[:name] == name }
  abort "Texture not loaded: #{name}" if tex.nil?
  tex[:id]
end

def reshape(width, height)
  height = 1 if height < 1
  aspect = width.to_f / height

  glViewport(0, 0, width, height)
  glMatrixMode(GL_PROJECTION)
  glLoadIdentity

  # Manual perspective matrix (no GLU dependency)
  fovy = 45.0 * Math::PI / 180.0
  f = 1.0 / Math.tan(fovy / 2.0)
  near = 0.1
  far = 100.0
  m = [
    f / aspect, 0, 0, 0,
    0, f, 0, 0,
    0, 0, (far + near) / (near - far), -1,
    0, 0, (2 * far * near) / (near - far), 0
  ].pack('F16')
  glLoadMatrixf(m)
  glMatrixMode(GL_MODELVIEW)
end

def clamp(value, min_v, max_v)
  [[value, min_v].max, max_v].min
end

# Circle (player) vs axis-aligned wall boxes.
def resolve_wall_collisions(x, z)
  r = PLAYER_MARGIN
  WALL_AABBS.each do |w|
    cx = clamp(x, w[:min_x], w[:max_x])
    cz = clamp(z, w[:min_z], w[:max_z])
    dx = x - cx
    dz = z - cz
    dist2 = dx * dx + dz * dz
    next if dist2 >= r * r

    if dist2 < 1.0e-12
      # Inside the box: push out along the shallowest axis.
      left = x - w[:min_x]
      right = w[:max_x] - x
      near = z - w[:min_z]
      far = w[:max_z] - z
      m = [left, right, near, far].min
      if m == left
        x = w[:min_x] - r
      elsif m == right
        x = w[:max_x] + r
      elsif m == near
        z = w[:min_z] - r
      else
        z = w[:max_z] + r
      end
    else
      dist = Math.sqrt(dist2)
      scale = r / dist
      x = cx + dx * scale
      z = cz + dz * scale
    end
  end
  [x, z]
end

# Push the player out of the cube's solid volume (XZ circle ≈ bounding sphere).
def resolve_cube_collision(x, z)
  dx = x
  dz = z
  dist = Math.sqrt(dx * dx + dz * dz)
  min_dist = PLAYER_RADIUS + CUBE_COLLISION_RADIUS
  return [x, z] if dist >= min_dist

  if dist < 1.0e-6
    return [0.0, min_dist]
  end

  scale = min_dist / dist
  [dx * scale, dz * scale]
end

def try_collect_medkits(state)
  state[:medkits].each do |m|
    next if m[:collected]

    dx = state[:cam_x] - m[:x]
    dz = state[:cam_z] - m[:z]
    next if (dx * dx + dz * dz) > MEDKIT_PICKUP_R * MEDKIT_PICKUP_R

    m[:collected] = true
    before = state[:hp]
    state[:hp] = [state[:hp] + MEDKIT_HEAL, state[:max_hp]].min
    left = state[:medkits].count { |k| !k[:collected] }
    puts format(
      'Medkit (%s): HP %d -> %d/%d  (%d remaining)',
      m[:room], before, state[:hp], state[:max_hp], left
    )
  end
end

# Camera-local basis on the XZ plane.
# yaw = 0 → look down -Z; yaw+ → turn right (toward +X).
def cam_forward(yaw_deg)
  rad = yaw_deg * Math::PI / 180.0
  [Math.sin(rad), -Math.cos(rad)]
end

def cam_right(yaw_deg)
  rad = yaw_deg * Math::PI / 180.0
  [Math.cos(rad), Math.sin(rad)]
end

# Map UI speed 0..1 to revolutions/sec: 50% → 0.2, 100% → 10 (piecewise linear).
def speed_to_rps(speed)
  speed = clamp(speed, 0.0, 1.0)
  if speed <= 0.5
    RPS_AT_HALF * (speed / 0.5)
  else
    RPS_AT_HALF + (RPS_AT_FULL - RPS_AT_HALF) * ((speed - 0.5) / 0.5)
  end
end

def draw_char_5x7(px, py, char, scale)
  rows = FONT_5X7[char] || FONT_5X7[' ']
  rows.each_with_index do |bits, row|
    5.times do |col|
      next if (bits & (1 << (4 - col))).zero?

      x0 = px + col * scale
      y0 = py + (6 - row) * scale
      x1 = x0 + scale
      y1 = y0 + scale
      glVertex2f(x0, y0)
      glVertex2f(x1, y0)
      glVertex2f(x1, y1)
      glVertex2f(x0, y1)
    end
  end
end

def draw_text_5x7(x, y, text, scale: 2)
  advance = 6 * scale
  text.upcase.each_char.with_index do |char, i|
    draw_char_5x7(x + i * advance, y, char, scale)
  end
end

def draw_status_bar(width, height, text, pixel_scale: 1.0)
  scale = [pixel_scale.round, 1].max
  bar_h = STATUS_BAR_H * scale
  glyph = 2 * scale
  top = height
  bottom = height - bar_h

  glMatrixMode(GL_PROJECTION)
  glPushMatrix
  glLoadIdentity
  glOrtho(0.0, width.to_f, 0.0, height.to_f, -1.0, 1.0)

  glMatrixMode(GL_MODELVIEW)
  glPushMatrix
  glLoadIdentity

  glDisable(GL_DEPTH_TEST)
  glDisable(GL_TEXTURE_2D)

  # Background strip
  glColor3f(0.05, 0.05, 0.08)
  glBegin(GL_QUADS)
  glVertex2f(0.0, bottom)
  glVertex2f(width.to_f, bottom)
  glVertex2f(width.to_f, top)
  glVertex2f(0.0, top)
  glEnd

  # Accent line under the bar
  glColor3f(0.35, 0.55, 1.0)
  glBegin(GL_QUADS)
  glVertex2f(0.0, bottom)
  glVertex2f(width.to_f, bottom)
  glVertex2f(width.to_f, bottom + 2 * scale)
  glVertex2f(0.0, bottom + 2 * scale)
  glEnd

  # Status text (no texturing)
  glDisable(GL_TEXTURE_2D)
  glColor3f(0.92, 0.94, 1.0)
  glBegin(GL_QUADS)
  draw_text_5x7(8 * scale, bottom + 7 * scale, text, scale: glyph)
  glEnd

  glEnable(GL_DEPTH_TEST)

  glMatrixMode(GL_PROJECTION)
  glPopMatrix
  glMatrixMode(GL_MODELVIEW)
  glPopMatrix
end

key_callback = GLFW.create_callback(:GLFWkeyfun) do |window, key, _scancode, action, _mods|
  if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS
    glfwSetWindowShouldClose(window, 1)
  elsif key == GLFW_KEY_SPACE && action == GLFW_PRESS
    state[:rotating] = !state[:rotating]
    puts state[:rotating] ? 'Rotation resumed' : 'Rotation paused'
  elsif key == GLFW_KEY_T && action == GLFW_PRESS
    state[:use_texture] = !state[:use_texture]
    puts state[:use_texture] ? 'Surface: texture' : 'Surface: color'
  elsif key == GLFW_KEY_RIGHT_BRACKET && action == GLFW_PRESS && !state[:texture_ids].empty?
    state[:texture_index] = (state[:texture_index] + 1) % state[:texture_ids].size
    puts "Texture: #{state[:texture_ids][state[:texture_index]][:name]}"
  elsif key == GLFW_KEY_LEFT_BRACKET && action == GLFW_PRESS && !state[:texture_ids].empty?
    state[:texture_index] = (state[:texture_index] - 1) % state[:texture_ids].size
    puts "Texture: #{state[:texture_ids][state[:texture_index]][:name]}"
  elsif key >= GLFW_KEY_1 && key <= GLFW_KEY_5 && action == GLFW_PRESS && !state[:texture_ids].empty?
    idx = key - GLFW_KEY_1
    if idx < state[:texture_ids].size
      state[:texture_index] = idx
      state[:use_texture] = true
      puts "Texture: #{state[:texture_ids][idx][:name]}"
    end
  elsif [GLFW_KEY_EQUAL, GLFW_KEY_KP_ADD].include?(key) && (action == GLFW_PRESS || action == GLFW_REPEAT)
    state[:speed] = clamp(state[:speed] + SPEED_STEP, 0.0, 1.0)
  elsif [GLFW_KEY_MINUS, GLFW_KEY_KP_SUBTRACT].include?(key) && (action == GLFW_PRESS || action == GLFW_REPEAT)
    state[:speed] = clamp(state[:speed] - SPEED_STEP, 0.0, 1.0)
  end
end

mouse_button_callback = GLFW.create_callback(:GLFWmousebuttonfun) do |window, button, action, _mods|
  next unless button == GLFW_MOUSE_BUTTON_LEFT

  if action == GLFW_PRESS
    state[:dragging] = true
    x_ptr = ' ' * 8
    y_ptr = ' ' * 8
    glfwGetCursorPos(window, x_ptr, y_ptr)
    state[:last_mouse_x] = x_ptr.unpack1('D')
    state[:last_mouse_y] = y_ptr.unpack1('D')
  elsif action == GLFW_RELEASE
    state[:dragging] = false
  end
end

cursor_pos_callback = GLFW.create_callback(:GLFWcursorposfun) do |_window, xpos, ypos|
  if state[:dragging]
    dx = xpos - state[:last_mouse_x]
    dy = ypos - state[:last_mouse_y]
    state[:cam_yaw] = (state[:cam_yaw] + dx * MOUSE_LOOK_SENS) % 360.0
    state[:cam_pitch] = clamp(state[:cam_pitch] - dy * MOUSE_LOOK_SENS, PITCH_MIN, PITCH_MAX)
    state[:last_mouse_x] = xpos
    state[:last_mouse_y] = ypos
  end
end

abort 'Failed to initialize GLFW' if glfwInit.zero?

glfwWindowHint(GLFW_SAMPLES, 4)

window = glfwCreateWindow(WIDTH, HEIGHT, 'Ruby OpenGL — Maze + Medkits', nil, nil)
abort 'Failed to create window' if window.nil?

glfwMakeContextCurrent(window)
glfwSetKeyCallback(window, key_callback)
glfwSetMouseButtonCallback(window, mouse_button_callback)
glfwSetCursorPosCallback(window, cursor_pos_callback)
glfwSwapInterval(1)

glEnable(GL_DEPTH_TEST)
glEnable(GL_MULTISAMPLE) if defined?(GL_MULTISAMPLE)
glClearColor(0.12, 0.11, 0.10, 1.0)

state[:texture_ids] = load_all_textures
puts "Loaded textures: #{state[:texture_ids].map { |t| t[:name] }.join(', ')}"
puts "Maze: 5 rooms (plus layout). Medkits: #{state[:medkits].size}. HP: #{state[:hp]}/#{state[:max_hp]}"

puts <<~HELP
  Controls:
    WASD / arrows — move relative to camera (forward/back/strafe)
    Q / E         — turn left / right
    Mouse drag    — look around (yaw + pitch)
    Walk into a medkit (white box + red cross) to heal +#{MEDKIT_HEAL} HP
    Space         — pause / resume cube rotation
    T             — toggle cube color / texture
    [ / ]         — previous / next texture
    1..5          — select texture (enables texture mode)
    + / -         — rotation speed 0% .. 100% (also keypad)
    Esc           — quit
HELP

last_time = glfwGetTime
fb_w = WIDTH
fb_h = HEIGHT

until glfwWindowShouldClose(window) != 0
  now = glfwGetTime
  dt = now - last_time
  last_time = now

  state[:fps_frames] += 1
  state[:fps_accum] += dt
  if state[:fps_accum] >= 0.5
    state[:fps] = state[:fps_frames] / state[:fps_accum]
    state[:fps_frames] = 0
    state[:fps_accum] = 0.0
  end

  # Move in camera space, then map into the room with the camera basis.
  # local_f: +1 = forward (where the camera looks), local_r: +1 = strafe right.
  local_f = 0.0
  local_r = 0.0
  local_f += 1.0 if glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS || glfwGetKey(window, GLFW_KEY_UP) == GLFW_PRESS
  local_f -= 1.0 if glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS || glfwGetKey(window, GLFW_KEY_DOWN) == GLFW_PRESS
  local_r -= 1.0 if glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS || glfwGetKey(window, GLFW_KEY_LEFT) == GLFW_PRESS
  local_r += 1.0 if glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS || glfwGetKey(window, GLFW_KEY_RIGHT) == GLFW_PRESS

  if local_f != 0.0 || local_r != 0.0
    fx, fz = cam_forward(state[:cam_yaw])
    rx, rz = cam_right(state[:cam_yaw])
    move_x = local_f * fx + local_r * rx
    move_z = local_f * fz + local_r * rz
    len = Math.sqrt(move_x * move_x + move_z * move_z)
    if len > 0.0
      step = CAMERA_MOVE_SPEED * dt / len
      # Axis-separated slides so doorways and corners feel less sticky.
      nx = state[:cam_x] + move_x * step
      nz = state[:cam_z]
      nx, nz = resolve_wall_collisions(nx, nz)
      nx, nz = resolve_cube_collision(nx, nz)
      nx2 = nx
      nz2 = nz + move_z * step
      nx2, nz2 = resolve_wall_collisions(nx2, nz2)
      nx2, nz2 = resolve_cube_collision(nx2, nz2)
      state[:cam_x] = nx2
      state[:cam_z] = nz2
    end
  end

  # Keep solid even when standing still (e.g. after spawn nudge).
  state[:cam_x], state[:cam_z] = resolve_wall_collisions(state[:cam_x], state[:cam_z])
  state[:cam_x], state[:cam_z] = resolve_cube_collision(state[:cam_x], state[:cam_z])

  try_collect_medkits(state)
  # Optional keyboard turn (camera-centric); mouse look is primary.
  if glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS
    state[:cam_yaw] = (state[:cam_yaw] - CAMERA_TURN_SPEED * dt) % 360.0
  end
  if glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS
    state[:cam_yaw] = (state[:cam_yaw] + CAMERA_TURN_SPEED * dt) % 360.0
  end

  if state[:rotating]
    rps = speed_to_rps(state[:speed])
    # Scale tumble so the primary axis (X) completes `rps` revolutions per second.
    deg_per_sec = rps * 360.0
    scale = deg_per_sec / SPIN_WEIGHT_X
    state[:angle_x] += SPIN_WEIGHT_X * scale * dt
    state[:angle_y] += SPIN_WEIGHT_Y * scale * dt
    state[:angle_z] += SPIN_WEIGHT_Z * scale * dt
  end

  w_ptr = ' ' * 8
  h_ptr = ' ' * 8
  glfwGetFramebufferSize(window, w_ptr, h_ptr)
  fb_w = w_ptr.unpack1('L')
  fb_h = h_ptr.unpack1('L')
  reshape(fb_w, fb_h)

  win_w_ptr = ' ' * 8
  win_h_ptr = ' ' * 8
  glfwGetWindowSize(window, win_w_ptr, win_h_ptr)
  win_w = [win_w_ptr.unpack1('L'), 1].max
  pixel_scale = fb_w.to_f / win_w

  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
  glLoadIdentity

  # First-person view: inverse of camera T(pos) * Ry(-yaw) * Rx(pitch)
  # so that +yaw turns right and matches cam_forward / cam_right above.
  eye_y = FLOOR_Y + CAMERA_EYE_HEIGHT
  glRotatef(-state[:cam_pitch], 1.0, 0.0, 0.0)
  glRotatef(state[:cam_yaw], 0.0, 1.0, 0.0)
  glTranslatef(-state[:cam_x], -eye_y, -state[:cam_z])

  brick_id = texture_named(state[:texture_ids], 'BRICK')
  tiles_id = texture_named(state[:texture_ids], 'FLOOR')
  draw_maze(brick_id, tiles_id)
  draw_medkits(state[:medkits], now)

  glPushMatrix
  glTranslatef(0.0, CUBE_CENTER_Y, 0.0)
  glRotatef(state[:angle_x], 1.0, 0.0, 0.0)
  glRotatef(state[:angle_y], 0.0, 1.0, 0.0)
  glRotatef(state[:angle_z], 0.0, 0.0, 1.0)
  glScalef(CUBE_SCALE, CUBE_SCALE, CUBE_SCALE)

  tex = state[:texture_ids][state[:texture_index]]
  draw_cube(use_texture: state[:use_texture], texture_id: tex[:id])
  glPopMatrix

  rot_label = state[:rotating] ? 'ON' : 'OFF'
  mode_label = state[:use_texture] ? "TEX:#{tex[:name]}" : 'COLOR'
  kits_left = state[:medkits].count { |m| !m[:collected] }
  status = format(
    'FPS:%5.1f  |  HP:%d/%d  |  KIT:%d  |  ROT:%s  |  SPD:%3.0f%%  |  %s  |  POS:%.1f,%.1f  |  YAW:%5.0f',
    state[:fps],
    state[:hp],
    state[:max_hp],
    kits_left,
    rot_label,
    state[:speed] * 100.0,
    mode_label,
    state[:cam_x],
    state[:cam_z],
    state[:cam_yaw]
  )
  draw_status_bar(fb_w, fb_h, status, pixel_scale: pixel_scale)
  glfwSetWindowTitle(window, "Ruby OpenGL — #{status}")

  glfwSwapBuffers(window)
  glfwPollEvents
end

glfwDestroyWindow(window)
glfwTerminate
