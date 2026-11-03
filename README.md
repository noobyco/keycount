<img src="assets/icon.svg" width="64" height="64" alt="">

# keycount

An Omarchy shell plugin that displays live typing speed, the personal best, its date, and the current best-beating streak.

## Install

Install the public repository with Omarchy.

```sh
omarchy plugin add https://github.com/noobyco/keycount.git --enable
```

The helper reads keyboard press events from `/dev/input/by-path/*-event-kbd`. The user running Omarchy must have read access to those devices, usually through the `input` group. This is the plugin's only privileged boundary. It does not send, store, or transmit key content. It records only press timing and count.

When the plugin first starts, it adds the following tagged entry to `~/.config/hypr/bindings.lua` if it is not already present:

```lua
o.bind("SUPER + SHIFT + K", "Toggle Keycount", {
  panel = "io.github.noobyco.keycount"
})
```

The installer never rewrites or removes unrelated keybindings. The binding is detected by plugin ID, so a manually-created equivalent binding is not duplicated.

## Placement

On the first enabled session, Keycount opens a theme-aware placement picker. Top Center is first and selected by default. The chosen position is saved in `~/.config/omarchy/keycount.json`.

```json
{"position": "top-center"}
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
python3 ~/.config/omarchy/plugins/io.github.noobyco.keycount/keycount_setup.py --remove-binding
omarchy plugin remove io.github.noobyco.keycount
```
