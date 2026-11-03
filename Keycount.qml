import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "keycount_model.js" as Model

Item {
  id: root

  property var state: Model.emptyState()
  property string placement: "top-center"
  property var run: Model.emptyRun()
  property double speed: 0
  property string configPath: Quickshell.env("HOME") + "/.config/omarchy/keycount.json"
  property string eventPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/keycount-events.json"
  property string setupScript: Qt.resolvedUrl("keycount_setup.py").toString().replace("file://", "")
  property bool opened: false
  property bool configLoaded: false
  property bool setupOpen: false
  property bool layoutMenuOpen: false
  property string setupError: ""
  property var positionChoices: Model.positionOptions()

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function loadConfig(raw) {
    try {
      var config = JSON.parse(String(raw || "{}"))
      state = Model.readState(JSON.stringify(config))
      var configured = String(config.position || "")
      if (!Model.isPosition(configured)) return
      placement = configured
      configLoaded = true
      setupOpen = false
    }
    catch (error) {}
  }

  function saveConfig() {
    configFile.setText(JSON.stringify({
      position: placement,
      bestSpeed: state.bestSpeed,
      bestDate: state.bestDate,
      streak: state.streak
    }) + "\n")
  }

  function refreshSpeed(now) {
    speed = Model.liveSpeed(run, now)
  }

  function considerBest(now) {
    var words = Model.wordCount(run.text)
    var elapsed = run.startedAt ? now - run.startedAt : 0
    if (Model.qualifies(words, elapsed) && speed > state.bestSpeed) {
      var result = Model.recordRun(state, speed, new Date().toISOString().slice(0, 10))
      state = result.state
      saveConfig()
    }
  }

  function loadTyping(raw) {
    try {
      var payload = JSON.parse(String(raw || "{}"))
      if (!Array.isArray(payload.ev)) return
      var now = Date.now()
      run = Model.noteText(run, Model.textFromEvents(payload.ev), now, Number(payload.gen) || 0)
      refreshSpeed(now)
      considerBest(now)
    }
    catch (error) {}
  }

  function toggle() {
    opened = !opened
    if (!opened) layoutMenuOpen = false
    if (opened) refreshSpeed(Date.now())
  }



  function open(payloadJson) { opened = true; refreshSpeed(Date.now()) }
  function close() { opened = false; layoutMenuOpen = false }

  function choosePlacement(value) {
    placement = value
    layoutMenuOpen = false
    savePlacement()
  }

  function formattedBestDate() {
    if (!state.bestDate) return ""
    var date = new Date(state.bestDate + "T00:00:00")
    if (isNaN(date.getTime())) return ""
    return date.toLocaleDateString(Qt.locale(Commons.I18n.formatLocale), "d MMM yyyy")
  }

  function savePlacement() {
    setupError = ""
    placementWriter.command = ["python3", setupScript, "--placement", placement]
    placementWriter.running = true
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    onLoaded: root.loadConfig(text())
    onFileChanged: reload()
  }

  FileView {
    id: eventFile
    path: root.eventPath
    watchChanges: true
    onLoaded: root.loadTyping(text())
    onFileChanged: reload()
  }

  Process {
    id: bindingInstaller
    running: true
    command: ["python3", root.setupScript, "--ensure-binding"]
  }

  Process {
    id: bridgeInstaller
    running: true
    command: ["python3", root.setupScript, "--ensure-hyprland-bridge"]
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line).trim() === "changed") bridgeReloader.running = true
      }
    }
    stderr: SplitParser {
      onRead: function(line) { console.warn("keycount:", line) }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("keycount bridge install failed:", exitCode)
    }
  }

  Process {
    id: bridgeReloader
    command: ["hyprctl", "reload"]
  }

  Process {
    id: placementWriter
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.configLoaded = true
        root.setupOpen = false
        configFile.reload()
      } else {
        root.setupError = strings.t("setup.saveFailed")
      }
    }
  }

  Timer {
    id: firstRunTimer
    interval: 250
    onTriggered: if (!root.configLoaded) root.setupOpen = true
  }

  Timer {
    interval: 200
    repeat: true
    running: root.opened
    onTriggered: root.refreshSpeed(Date.now())
  }

  Component.onCompleted: {
    firstRunTimer.start()
  }

  PanelWindow {
    id: panel
    visible: root.opened || root.setupOpen
    screen: Quickshell.screens.length ? Quickshell.screens[0] : null
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.setupOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: root.setupOpen ? setupCard : (root.opened ? card : null) }

    Rectangle {
      id: card
      visible: root.opened && !root.setupOpen
      width: (root.layoutMenuOpen ? Style.space(420) : speedRow.implicitWidth) + Style.space(32)
      height: content.implicitHeight + Style.space(24)
      x: {
        var edge = Style.space(24)
        var horizontal = Model.position(root.placement).horizontal
        if (horizontal === "left") return edge
        if (horizontal === "right") return Math.max(edge, parent.width - width - edge)
        return Math.max(0, (parent.width - width) / 2)
      }
      y: {
        var edge = Style.space(24)
        var vertical = Model.position(root.placement).vertical
        if (vertical === "top") return edge
        if (vertical === "bottom") return Math.max(edge, parent.height - height - edge)
        return Math.max(0, (parent.height - height) / 2)
      }
      radius: Style.cornerRadius
      color: Util.alpha(Commons.Color.popups.background, 0.96)
      border.color: Commons.Color.popups.border
      border.width: Style.space(1)

      Column {
        id: content
        width: parent.width - Style.space(32)
        anchors.centerIn: parent
        spacing: Style.space(10)

        Button {
          width: parent.width
          text: strings.t("layout.change")
          bordered: true
          fontSize: Style.font.caption
          selected: root.layoutMenuOpen
          onClicked: root.layoutMenuOpen = !root.layoutMenuOpen
        }

        Grid {
          id: layoutMenu
          visible: root.layoutMenuOpen
          columns: 3
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: root.positionChoices
            delegate: Button {
              required property var modelData
              width: (parent.width - parent.spacing * 2) / 3
              text: strings.t(modelData.label)
              selected: root.placement === modelData.value
              bordered: true
              fontSize: Style.font.caption
              onClicked: root.choosePlacement(modelData.value)
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.layoutMenuOpen && root.setupError !== ""
          width: parent.width
          text: root.setupError
          color: Commons.Color.urgent
          wrapMode: Text.WordWrap
          font.pixelSize: Style.font.caption
        }

        Row {
          id: speedRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(18)
          Text { textFormat: Text.PlainText; text: Commons.I18n.formatNumber(Math.round(root.speed)) + " WPM"; color: Commons.Color.popups.text; font.pixelSize: Style.font.title; font.bold: true }
          Column {
            spacing: Style.space(2)
            Text { textFormat: Text.PlainText; text: strings.t("best").arg(Commons.I18n.formatNumber(Math.round(root.state.bestSpeed))); color: Commons.Color.popups.text; font.pixelSize: Style.font.caption; font.bold: true }
            Text { textFormat: Text.PlainText; text: root.state.bestDate ? strings.t("bestDateStreak").arg(root.formattedBestDate()).arg(Commons.I18n.formatNumber(root.state.streak)) : strings.t("noBest"); color: Commons.Color.popups.text; opacity: 0.72; font.pixelSize: Style.font.caption }
          }
        }
      }
    }

    Rectangle {
      id: setupCard
      visible: root.setupOpen
      width: Style.space(500)
      height: setupContent.implicitHeight + Style.space(40)
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: Commons.Color.popups.background
      border.color: Commons.Color.popups.border
      border.width: Style.space(1)

      Column {
        id: setupContent
        width: parent.width - Style.space(40)
        anchors.centerIn: parent
        spacing: Style.space(12)

        Text {
          textFormat: Text.PlainText
          text: strings.t("setup.title")
          color: Commons.Color.popups.text
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: strings.t("setup.body")
          color: Commons.Color.popups.text
          opacity: 0.75
          wrapMode: Text.WordWrap
        }

        Grid {
          columns: 3
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: root.positionChoices
            delegate: Button {
              required property var modelData
              width: (parent.width - parent.spacing * 2) / 3
              text: strings.t(modelData.label)
              selected: root.placement === modelData.value
              bordered: true
              onClicked: root.placement = modelData.value
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: root.setupError !== ""
          text: root.setupError
          color: Commons.Color.urgent
          wrapMode: Text.WordWrap
        }

        Button {
          width: parent.width
          text: strings.t("setup.save")
          selected: true
          onClicked: root.savePlacement()
        }
      }
    }
  }
}
