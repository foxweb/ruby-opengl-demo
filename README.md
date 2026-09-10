# Ruby OpenGL — Rotating Cube

Короткая демо-программа: вращающийся цветной 3D-куб на Ruby + OpenGL через GLFW.

## Зависимости

- Ruby 3+
- [GLFW](https://www.glfw.org/) (`brew install glfw` на macOS)
- gem `opengl-bindings`

```bash
bundle install
# или:
gem install opengl-bindings
```

## Запуск

```bash
ruby cube.rb
```

Закрыть окно или нажать **Esc**.

## Что внутри

- окно GLFW 800×600
- immediate-mode OpenGL (`glBegin` / `GL_QUADS`)
- шесть граней куба разными цветами
- вращение вокруг X/Y/Z от `glfwGetTime`
