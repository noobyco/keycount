<img src="assets/icon.svg" width="64" height="64" alt="">

# keycount

An Omarchy shell plugin that displays live typing speed, the personal best, its date, and the current best-beating streak.

## Install

Install the public repository with Omarchy.

```sh
omarchy plugin add https://github.com/noobyco/keycount.git --enable
```

The helper reads keyboard press events from `/dev/input/by-path/*-event-kbd`. The user running Omarchy must have read access to those devices, usually through the `input` group. This is the plugin's only privileged boundary. It does not send, store, or transmit key content. It records only press timing and count.

Double-tap `K` to show or hide the overlay. This is enabled by default and does not consume either `K` press, so normal typing continues to work.

## Placement

Create `~/.config/omarchy/keycount.json` to choose a position. The default is `top-center`.

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
omarchy plugin remove io.github.noobyco.keycount
```
