# Unsplash Wallpapers for Omarchy

A fresh [Unsplash](https://unsplash.com) wallpaper every day, right from the Omarchy bar.
Inspired by Unsplash's own Mac app.

- **Daily by default**: or hourly or weekly
- **Guided by keywords**: `mountains, fog, minimal`; one is picked at random each time.
  Leave blank for Unsplash's curated *Wallpapers* topic. Public collections work too.
- **Favorites**: one click saves the current wallpaper to `~/Pictures/Unsplash`;
  browse and re-apply them in Omarchy's image picker
- **History**: step back (and forward) through your last 30 wallpapers
- **Credits the photographer**, as Unsplash asks

## Install

```bash
omarchy plugin add https://github.com/tkreek/omarchy-unsplash --enable
```

Omarchy asks which part of the bar to put the icon in (left, center or right; right is
preselected). To move it later:

```bash
omarchy bar move tkreek.unsplash --section left   # left | center | right
```

Then click the 󰸉 icon in the bar. The first time, it asks for a free Unsplash access key:

1. Create an app at <https://unsplash.com/oauth/applications/new> (any name is fine)
2. Copy its **Access Key** and paste it into the popup

That's it. A wallpaper appears right away and a new one arrives each day.
Prefer the terminal? Run `~/.config/omarchy/plugins/tkreek.unsplash/bin/omarchy-unsplash setup`.

> **Why your own key?** Unsplash rate-limits each key (50 requests/hour on a new app).
> This plugin uses about two a day, so your own key never runs out, and nobody shares a
> key that could be revoked for everyone.

## Using it

| In the bar | |
|---|---|
| Left click | Popup: preview, credit, history, favorite, keywords, interval |
| Right click | New wallpaper now |
| Middle click | Favorite / unfavorite |
| Scroll | Step through recent wallpapers |

The plugin also ships a CLI. `omarchy-unsplash link` puts it on your `PATH`:

```bash
omarchy-unsplash new                  # new wallpaper now
omarchy-unsplash new northern lights  # one-off search
omarchy-unsplash prev | next          # history
omarchy-unsplash fav | unfav          # favorites
omarchy-unsplash favorites            # pick a favorite in the image picker
omarchy-unsplash keywords set "mountains, fog, minimal"
omarchy-unsplash collections add https://unsplash.com/collections/1065976/wallpapers
omarchy-unsplash interval weekly      # hourly | 3h | 12h | daily | weekly
omarchy-unsplash status
```

Optional keybindings and Omarchy menu entries are in [`extras/`](extras/).
Paste `extras/bindings.lua` into `~/.config/hypr/bindings.lua`:

| Keys | Action |
|---|---|
| `Super + Alt + W` | Open the Unsplash popup |
| `Super + Shift + Alt + W` | New wallpaper |
| `Super + Shift + W` | Favorite / unfavorite |

## Files

| Path | What |
|---|---|
| `~/.config/omarchy-unsplash/config.json` | Access key, keywords, collections, interval (mode 600) |
| `~/.local/state/omarchy-unsplash/state.json` | Current photo and history |
| `~/.local/share/omarchy-unsplash/photos/` | Recent downloads, pruned automatically |
| `~/Pictures/Unsplash/` | Favorites (`favorites_dir` in config to change) |

Other config options: `orientation` (`landscape`/`portrait`/`squarish`), `content_filter`
(`high`/`low`), `history_size`, `notify` (desktop notification on each scheduled wallpaper).

## How it works

`Service.qml` runs inside the Omarchy shell and calls `omarchy-unsplash tick` every
five minutes. The CLI decides whether a new photo is due, so missed days, suspend and
reboots just work. Failures back off for 15 minutes and never spam notifications. Photos
are downloaded at your largest monitor's resolution and applied with
`omarchy theme bg set`. Switching Omarchy themes restores that theme's background
until the next Unsplash wallpaper arrives.

## License

MIT. Photos are provided by Unsplash under the [Unsplash License](https://unsplash.com/license).
