-- The rain pass (omk-rainpass) and Omarchy's idle screensaver window: true full screen (over the
-- bar), fully opaque, never taking focus for the pass. Omarchy's default window opacity
-- (0.985 / 0.96) is what made their black look dark grey.
o.window("org.omk.rainpass", {
  float = true, pin = true, no_focus = true, no_initial_focus = true, fullscreen = true,
  size = { "(monitor_w)", "(monitor_h)" }, move = { "(0)", "(0)" },
  border_size = 0, no_shadow = true, no_blur = true, no_anim = true,
  tag = "-default-opacity", opacity = "1.0 override 1.0 override",
})
o.window("org.omarchy.screensaver", { tag = "-default-opacity", opacity = "1.0 override 1.0 override" })
