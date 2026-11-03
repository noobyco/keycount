function emptyState() {
  return { bestSpeed: 0, bestDate: "", streak: 0 }
}

function readState(raw) {
  try {
    var value = JSON.parse(String(raw || "{}"))
    return {
      bestSpeed: Math.max(0, Number(value.bestSpeed) || 0),
      bestDate: String(value.bestDate || ""),
      streak: Math.max(0, Math.floor(Number(value.streak) || 0))
    }
  } catch (error) {
    return emptyState()
  }
}

function recordRun(state, speed, date) {
  var next = readState(JSON.stringify(state))
  var value = Math.max(0, Number(speed) || 0)
  if (value > next.bestSpeed) {
    next.bestSpeed = value
    next.bestDate = String(date || "")
    next.streak += 1
    return { state: next, newBest: true }
  }
  return { state: next, newBest: false }
}

var RUN_PAUSE_MS = 2000

var UNSHIFTED = {
  10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0",
  20: "-", 21: "=", 24: "q", 25: "w", 26: "e", 27: "r", 28: "t", 29: "y", 30: "u", 31: "i",
  32: "o", 33: "p", 34: "[", 35: "]", 38: "a", 39: "s", 40: "d", 41: "f", 42: "g", 43: "h",
  44: "j", 45: "k", 46: "l", 47: ";", 48: "'", 49: "`", 51: "\\", 52: "z", 53: "x", 54: "c",
  55: "v", 56: "b", 57: "n", 58: "m", 59: ",", 60: ".", 61: "/", 65: " ",
  79: "7", 80: "8", 81: "9", 83: "4", 84: "5", 85: "6", 87: "1", 88: "2", 89: "3", 90: "0"
}

var SHIFTED = {
  10: "!", 11: "@", 12: "#", 13: "$", 14: "%", 15: "^", 16: "&", 17: "*", 18: "(", 19: ")",
  20: "_", 21: "+", 34: "{", 35: "}", 47: ":", 48: "\"", 49: "~", 51: "|", 59: "<", 60: ">", 61: "?"
}

var MODIFIER = { 37: "ctrl", 105: "ctrl", 50: "shift", 62: "shift", 64: "alt", 108: "alt", 133: "super", 134: "super" }

function speedFor(words, elapsedMs) {
  var minutes = Number(elapsedMs) / 60000
  return minutes > 0 ? (Number(words) || 0) / minutes : 0
}

function wordCount(text) {
  var matches = String(text || "").match(/[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*/g)
  return matches ? matches.length : 0
}

function emptyTyping() {
  return { shift: false, caps: false, ctrl: false, alt: false, superKey: false, text: "" }
}

function characterFor(code, shift, caps) {
  var base = UNSHIFTED[code]
  if (!base) return ""
  if (base >= "a" && base <= "z") return (shift !== caps) ? base.toUpperCase() : base
  if (shift && SHIFTED[code]) return SHIFTED[code]
  return base
}

function applyKey(state, code, pressed) {
  var current = state || emptyTyping()
  var next = {
    shift: current.shift, caps: current.caps, ctrl: current.ctrl, alt: current.alt,
    superKey: current.superKey, text: current.text
  }
  var key = Number(code)
  var down = Number(pressed) === 1
  var modifier = MODIFIER[key]
  if (modifier === "shift") { next.shift = down; return next }
  if (modifier === "ctrl") { next.ctrl = down; return next }
  if (modifier === "alt") { next.alt = down; return next }
  if (modifier === "super") { next.superKey = down; return next }
  if (key === 66) { if (down) next.caps = !next.caps; return next }
  if (!down || next.ctrl || next.alt || next.superKey) return next
  if (key === 22 || key === 119) {
    next.text = next.text.slice(0, -1)
    return next
  }
  var ch = characterFor(key, next.shift, next.caps)
  if (ch) next.text += ch
  return next
}

function textFromEvents(events) {
  var typing = emptyTyping()
  var list = Array.isArray(events) ? events : []
  for (var i = 0; i < list.length; i++) {
    var pair = list[i]
    if (!pair || pair.length < 2) continue
    typing = applyKey(typing, pair[0], pair[1])
  }
  return typing.text
}

function emptyRun() {
  return { text: "", startedAt: 0, updatedAt: 0, gen: 0 }
}

function noteText(run, text, now, gen) {
  var time = Number(now)
  var previous = run && run.updatedAt ? run : emptyRun()
  var generation = Number(gen) || 0
  var paused = !previous.updatedAt || time - previous.updatedAt > RUN_PAUSE_MS || generation !== previous.gen
  if (paused) return { text: String(text || ""), startedAt: time, updatedAt: time, gen: generation }
  return { text: String(text || ""), startedAt: previous.startedAt, updatedAt: time, gen: previous.gen }
}

function liveSpeed(run, now) {
  var current = run || emptyRun()
  var time = Number(now)
  if (!current.updatedAt || time - current.updatedAt > RUN_PAUSE_MS) return 0
  var words = wordCount(current.text)
  if (!words) return 0
  return speedFor(words, time - current.startedAt)
}

function qualifies(words, elapsedMs) {
  return (Number(words) || 0) >= 2 && Number(elapsedMs) >= 1000
}

function position(name) {
  var positions = {
    "center": { horizontal: "center", vertical: "center" },
    "left-center": { horizontal: "left", vertical: "center" },
    "right-center": { horizontal: "right", vertical: "center" },
    "top-center": { horizontal: "center", vertical: "top" },
    "bottom-center": { horizontal: "center", vertical: "bottom" },
    "top-right-edge": { horizontal: "right", vertical: "top" },
    "top-left-edge": { horizontal: "left", vertical: "top" },
    "bottom-right-edge": { horizontal: "right", vertical: "bottom" },
    "bottom-left-edge": { horizontal: "left", vertical: "bottom" }
  }
  return positions[String(name)] || positions["top-center"]
}

function isPosition(name) {
  return ["center", "left-center", "right-center", "top-center", "bottom-center",
    "top-right-edge", "top-left-edge", "bottom-right-edge", "bottom-left-edge"].indexOf(String(name)) !== -1
}

function positionOptions() {
  return [
    { value: "top-left-edge", label: "placement.topLeft" },
    { value: "top-center", label: "placement.topCenter" },
    { value: "top-right-edge", label: "placement.topRight" },
    { value: "left-center", label: "placement.leftCenter" },
    { value: "center", label: "placement.center" },
    { value: "right-center", label: "placement.rightCenter" },
    { value: "bottom-left-edge", label: "placement.bottomLeft" },
    { value: "bottom-center", label: "placement.bottomCenter" },
    { value: "bottom-right-edge", label: "placement.bottomRight" }
  ]
}

if (typeof module !== "undefined") {
  module.exports = {
    emptyState, readState, recordRun, speedFor, qualifies, wordCount, emptyTyping, applyKey,
    textFromEvents, emptyRun, noteText, liveSpeed, RUN_PAUSE_MS, position, isPosition, positionOptions
  }
}
