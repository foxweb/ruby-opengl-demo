#!/usr/bin/env ruby
# frozen_string_literal: true

# Rotating colorful 3D cube — Ruby + OpenGL (GLFW)
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

CAMERA_DIST_MIN  = 2.0
CAMERA_DIST_MAX  = 20.0
CAMERA_DIST_STEP = 4.0   # units per second (arrows)
CAMERA_YAW_STEP  = 90.0  # degrees per second (arrows)
ZOOM_SCROLL_STEP = 0.4
MOUSE_YAW_SENS   = 0.25  # degrees per pixel
SPEED_STEP       = 0.05  # 5% per +/- key press
RPS_AT_HALF      = 0.2   # revolutions/sec at 50% speed
RPS_AT_FULL      = 10.0  # revolutions/sec at 100% speed
# Relative tumble weights (largest axis defines "one revolution")
SPIN_WEIGHT_X    = 50.0
SPIN_WEIGHT_Y    = 35.0
SPIN_WEIGHT_Z    = 20.0

FACES = [
  { color: [1.0, 0.25, 0.25], verts: [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]] },         # front  red
  { color: [0.25, 1.0, 0.25], verts: [[-1, -1, -1], [-1, 1, -1], [1, 1, -1], [1, -1, -1]] },     # back   green
  { color: [0.25, 0.45, 1.0], verts: [[-1, 1, -1], [-1, 1, 1], [1, 1, 1], [1, 1, -1]] },         # top    blue
  { color: [1.0, 0.85, 0.15], verts: [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]] },     # bottom yellow
  { color: [1.0, 0.35, 0.9],  verts: [[1, -1, -1], [1, 1, -1], [1, 1, 1], [1, -1, 1]] },         # right  magenta
  { color: [0.15, 0.9, 0.95], verts: [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]] }      # left   cyan
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
  'D' => [0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E],
  'F' => [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
  'I' => [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E],
  'N' => [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11],
  'O' => [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E],
  'P' => [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
  'R' => [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
  'S' => [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E],
  'T' => [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
  'W' => [0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A],
  'Y' => [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04]
}.freeze

state = {
  rotating: true,
  speed: 0.5, # 0.0 .. 1.0 → 0% .. 100% (default 50% ≈ 0.2 rev/s)
  camera_dist: 5.0,
  camera_yaw: 0.0,
  angle_x: 0.0,
  angle_y: 0.0,
  angle_z: 0.0,
  dragging: false,
  last_mouse_x: 0.0,
  fps: 0.0,
  fps_frames: 0,
  fps_accum: 0.0
}

def draw_cube
  glBegin(GL_QUADS)
  FACES.each do |face|
    glColor3f(*face[:color])
    face[:verts].each { |x, y, z| glVertex3f(x, y, z) }
  end
  glEnd
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

  # Status text
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
  elsif [GLFW_KEY_EQUAL, GLFW_KEY_KP_ADD].include?(key) && (action == GLFW_PRESS || action == GLFW_REPEAT)
    state[:speed] = clamp(state[:speed] + SPEED_STEP, 0.0, 1.0)
  elsif [GLFW_KEY_MINUS, GLFW_KEY_KP_SUBTRACT].include?(key) && (action == GLFW_PRESS || action == GLFW_REPEAT)
    state[:speed] = clamp(state[:speed] - SPEED_STEP, 0.0, 1.0)
  end
end

scroll_callback = GLFW.create_callback(:GLFWscrollfun) do |_window, _xoffset, yoffset|
  state[:camera_dist] = clamp(
    state[:camera_dist] - yoffset * ZOOM_SCROLL_STEP,
    CAMERA_DIST_MIN,
    CAMERA_DIST_MAX
  )
end

mouse_button_callback = GLFW.create_callback(:GLFWmousebuttonfun) do |window, button, action, _mods|
  next unless button == GLFW_MOUSE_BUTTON_LEFT

  if action == GLFW_PRESS
    state[:dragging] = true
    x_ptr = ' ' * 8
    y_ptr = ' ' * 8
    glfwGetCursorPos(window, x_ptr, y_ptr)
    state[:last_mouse_x] = x_ptr.unpack1('D')
  elsif action == GLFW_RELEASE
    state[:dragging] = false
  end
end

cursor_pos_callback = GLFW.create_callback(:GLFWcursorposfun) do |_window, xpos, _ypos|
  if state[:dragging]
    dx = xpos - state[:last_mouse_x]
    state[:camera_yaw] = (state[:camera_yaw] + dx * MOUSE_YAW_SENS) % 360.0
    state[:last_mouse_x] = xpos
  end
end

abort 'Failed to initialize GLFW' if glfwInit.zero?

glfwWindowHint(GLFW_SAMPLES, 4)

window = glfwCreateWindow(WIDTH, HEIGHT, 'Ruby OpenGL — Rotating Cube', nil, nil)
abort 'Failed to create window' if window.nil?

glfwMakeContextCurrent(window)
glfwSetKeyCallback(window, key_callback)
glfwSetScrollCallback(window, scroll_callback)
glfwSetMouseButtonCallback(window, mouse_button_callback)
glfwSetCursorPosCallback(window, cursor_pos_callback)
glfwSwapInterval(1)

glEnable(GL_DEPTH_TEST)
glEnable(GL_MULTISAMPLE) if defined?(GL_MULTISAMPLE)
glClearColor(0.08, 0.08, 0.12, 1.0)

puts <<~HELP
  Controls:
    Space        — pause / resume cube rotation
    + / -        — rotation speed 0% .. 100% (also keypad)
    Up / Down    — zoom in / out (clamped)
    Left / Right — yaw camera (360° returns to the same view)
    Mouse drag   — yaw camera
    Scroll       — zoom
    Esc          — quit
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

  # Held arrow keys
  if glfwGetKey(window, GLFW_KEY_UP) == GLFW_PRESS
    state[:camera_dist] = clamp(state[:camera_dist] - CAMERA_DIST_STEP * dt, CAMERA_DIST_MIN, CAMERA_DIST_MAX)
  end
  if glfwGetKey(window, GLFW_KEY_DOWN) == GLFW_PRESS
    state[:camera_dist] = clamp(state[:camera_dist] + CAMERA_DIST_STEP * dt, CAMERA_DIST_MIN, CAMERA_DIST_MAX)
  end
  if glfwGetKey(window, GLFW_KEY_LEFT) == GLFW_PRESS
    state[:camera_yaw] = (state[:camera_yaw] - CAMERA_YAW_STEP * dt) % 360.0
  end
  if glfwGetKey(window, GLFW_KEY_RIGHT) == GLFW_PRESS
    state[:camera_yaw] = (state[:camera_yaw] + CAMERA_YAW_STEP * dt) % 360.0
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

  # Camera: yaw around its vertical axis, then move back.
  # After 360° yaw the cube is in front again.
  glRotatef(-state[:camera_yaw], 0.0, 1.0, 0.0)
  glTranslatef(0.0, 0.0, -state[:camera_dist])

  glRotatef(state[:angle_x], 1.0, 0.0, 0.0)
  glRotatef(state[:angle_y], 0.0, 1.0, 0.0)
  glRotatef(state[:angle_z], 0.0, 0.0, 1.0)

  draw_cube

  rot_label = state[:rotating] ? 'ON' : 'OFF'
  status = format(
    'FPS:%5.1f  |  ROT:%s  |  SPD:%3.0f%%  |  DIST:%.2f  |  YAW:%6.1f',
    state[:fps],
    rot_label,
    state[:speed] * 100.0,
    state[:camera_dist],
    state[:camera_yaw]
  )
  draw_status_bar(fb_w, fb_h, status, pixel_scale: pixel_scale)
  glfwSetWindowTitle(window, "Ruby OpenGL — #{status}")

  glfwSwapBuffers(window)
  glfwPollEvents
end

glfwDestroyWindow(window)
glfwTerminate
