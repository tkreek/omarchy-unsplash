-- Unsplash Wallpapers (tkreek.unsplash) keybindings.
-- Append to ~/.config/hypr/bindings.lua. Needs the CLI on PATH:
--   ~/.config/omarchy/plugins/tkreek.unsplash/bin/omarchy-unsplash link
o.bind("SUPER + ALT + W", "Unsplash panel", "omarchy-shell shell toggle tkreek.unsplash")
o.bind("SUPER + SHIFT + ALT + W", "Unsplash new wallpaper", "omarchy-unsplash new")
o.bind("SUPER + SHIFT + W", "Unsplash favorite wallpaper", "omarchy-unsplash toggle-fav")
