<img src="assets/icon.svg" width="64" height="64" alt="">

# keycount

An Omarchy shell plugin that displays live typing speed, the personal best, its date, and the current best-beating streak.

## Install

Install the public repository with Omarchy.

```sh
omarchy plugin add https://github.com/noobyco/keycount.git --enable
```

Keycount uses Hyprland's Lua keyboard event callback. Installation writes a small user-owned module at `~/.config/hypr/keycount.lua` and reloads Hyprland. It does not read `/dev/input`, add the user to a Linux group, require a password, or require a logout.

Speed is the number of words typed during the current run, divided by the minutes in that run. A word is a run of letters or digits, so `don't` and `well-known` each count as one. Space, Enter, and punctuation separate words. Shift, Ctrl, Alt, Super, arrows, and shortcuts do not. The key labels follow the English (US) layout.

During installation, Omarchy adds and reloads the following shortcut in `~/.config/hypr/bindings.lua` if no equivalent Keycount panel binding already exists:

```lua
o.bind("SUPER + SHIFT + K", "Toggle Keycount", {
  panel = "io.github.noobyco.keycount"
})
```

The installer never executes plugin code, rewrites unrelated keybindings, or duplicates a manually-created equivalent binding.

## Placement

On the first enabled session, Keycount opens a theme-aware placement picker. Top Center is first and selected by default. The chosen position and typing statistics are saved together in `~/.config/omarchy/keycount.json`.

```json
{
  "position": "top-center",
  "bestSpeed": 72,
  "bestDate": "2026-11-03",
  "streak": 1
}
```

Supported values are `center`, `left-center`, `right-center`, `top-center`, `bottom-center`, `top-right-edge`, `top-left-edge`, `bottom-right-edge`, and `bottom-left-edge`.

The panel uses Omarchy's live `Commons.Color` and `Style` values, so it follows the active theme without a plugin-specific palette.

## Validate

Run these checks from the repository root before publishing changes.

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Keycount.qml
```

## Remove

```sh
python3 ~/.config/omarchy/plugins/io.github.noobyco.keycount/keycount_setup.py --remove-binding --remove-hyprland-bridge
omarchy plugin remove io.github.noobyco.keycount
```
