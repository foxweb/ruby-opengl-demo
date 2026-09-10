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

FACES = [
  { color: [1.0, 0.25, 0.25], verts: [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]] },         # front  red
  { color: [0.25, 1.0, 0.25], verts: [[-1, -1, -1], [-1, 1, -1], [1, 1, -1], [1, -1, -1]] },     # back   green
  { color: [0.25, 0.45, 1.0], verts: [[-1, 1, -1], [-1, 1, 1], [1, 1, 1], [1, 1, -1]] },         # top    blue
  { color: [1.0, 0.85, 0.15], verts: [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]] },     # bottom yellow
  { color: [1.0, 0.35, 0.9],  verts: [[1, -1, -1], [1, 1, -1], [1, 1, 1], [1, -1, 1]] },         # right  magenta
  { color: [0.15, 0.9, 0.95], verts: [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]] }      # left   cyan
].freeze

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

key_callback = GLFW.create_callback(:GLFWkeyfun) do |window, key, _scancode, action, _mods|
  glfwSetWindowShouldClose(window, 1) if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS
end

abort 'Failed to initialize GLFW' if glfwInit.zero?

glfwWindowHint(GLFW_SAMPLES, 4)

window = glfwCreateWindow(WIDTH, HEIGHT, 'Ruby OpenGL — Rotating Cube', nil, nil)
abort 'Failed to create window' if window.nil?

glfwMakeContextCurrent(window)
glfwSetKeyCallback(window, key_callback)
glfwSwapInterval(1)

glEnable(GL_DEPTH_TEST)
glEnable(GL_MULTISAMPLE) if defined?(GL_MULTISAMPLE)
glClearColor(0.08, 0.08, 0.12, 1.0)

puts 'Rotating cube demo. Press ESC or close the window to exit.'

until glfwWindowShouldClose(window) != 0
  w_ptr = ' ' * 8
  h_ptr = ' ' * 8
  glfwGetFramebufferSize(window, w_ptr, h_ptr)
  reshape(w_ptr.unpack1('L'), h_ptr.unpack1('L'))

  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
  glLoadIdentity
  glTranslatef(0.0, 0.0, -5.0)

  t = glfwGetTime
  glRotatef(t * 50.0, 1.0, 0.0, 0.0)
  glRotatef(t * 35.0, 0.0, 1.0, 0.0)
  glRotatef(t * 20.0, 0.0, 0.0, 1.0)

  draw_cube

  glfwSwapBuffers(window)
  glfwPollEvents
end

glfwDestroyWindow(window)
glfwTerminate
