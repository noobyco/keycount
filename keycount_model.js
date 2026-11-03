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

function speedFor(keys, elapsedMs) {
  var minutes = Number(elapsedMs) / 60000
  return minutes > 0 ? (Number(keys) || 0) / 5 / minutes : 0
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

if (typeof module !== "undefined") {
  module.exports = { emptyState, readState, recordRun, speedFor, position, isPosition }
}
