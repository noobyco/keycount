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
  property int keyCount: 0
  property double startedAt: 0
  property double speed: 0
  property string configPath: Quickshell.env("HOME") + "/.config/omarchy/keycount.json"
  property string statePath: Quickshell.env("HOME") + "/.config/omarchy/keycount-state.json"
  property string setupScript: Qt.resolvedUrl("keycount_setup.py").toString().replace("file://", "")
  property bool opened: false
  property bool configLoaded: false
  property bool setupOpen: false
  property string setupError: ""
  property var positionChoices: Model.positionOptions()

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function loadConfig(raw) {
    try {
      var configured = String(JSON.parse(String(raw || "{}")).position || "top-center")
      if (!Model.isPosition(configured)) return
      placement = configured
      configLoaded = true
      setupOpen = false
    }
    catch (error) {}
  }

  function saveState() {
    stateFile.setText(JSON.stringify(state) + "\n")
  }

  function registerKey() {
    var now = Date.now()
    if (!startedAt || now - startedAt > 2000) { startedAt = now; keyCount = 0 }
    keyCount += 1
    speed = Model.speedFor(keyCount, now - startedAt)
    if (speed > state.bestSpeed) {
      var result = Model.recordRun(state, speed, new Date().toISOString().slice(0, 10))
      state = result.state
      saveState()
    }
  }

  function toggle() { opened = !opened }

  function open(payloadJson) { opened = true }
  function close() { opened = false }

  function formattedBestDate() {
    if (!state.bestDate) return ""
    return Qt.formatDate(new Date(state.bestDate + "T00:00:00"), "d MMM yyyy", Qt.locale(Commons.I18n.formatLocale))
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
  FileView { id: stateFile; path: root.statePath; onLoaded: root.state = Model.readState(text()) }

  Process {
    id: bindingInstaller
    running: true
    command: ["python3", root.setupScript, "--ensure-binding"]
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

  Component.onCompleted: {
    firstRunTimer.start()
  }

  Process {
    id: input
    running: true
    command: ["python3", Qt.resolvedUrl("keycount_input.py").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var event = JSON.parse(line)
          if (event.toggle) root.toggle()
          root.registerKey()
        } catch (error) {}
      }
    }
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
    mask: Region { item: root.setupOpen ? setupCard : null }

    Rectangle {
      id: card
      visible: root.opened && !root.setupOpen
      width: content.implicitWidth + Style.space(32)
      height: Style.space(76)
      anchors.horizontalCenter: Model.position(root.placement).horizontal === "center" ? parent.horizontalCenter : undefined
      anchors.left: Model.position(root.placement).horizontal === "left" ? parent.left : undefined
      anchors.right: Model.position(root.placement).horizontal === "right" ? parent.right : undefined
      anchors.top: Model.position(root.placement).vertical === "top" ? parent.top : undefined
      anchors.verticalCenter: Model.position(root.placement).vertical === "center" ? parent.verticalCenter : undefined
      anchors.bottom: Model.position(root.placement).vertical === "bottom" ? parent.bottom : undefined
      anchors.margins: Style.space(24)
      radius: Style.cornerRadius
      color: Util.alpha(Commons.Color.popups.background, 0.96)
      border.color: Commons.Color.popups.border
      border.width: Style.space(1)

      Row {
        id: content
        anchors.centerIn: parent
        spacing: Style.space(18)
        Text { textFormat: Text.PlainText; text: Commons.I18n.formatNumber(Math.round(root.speed)) + " WPM"; color: Commons.Color.popups.text; font.pixelSize: Style.font.title; font.bold: true }
        Column {
          spacing: Style.space(2)
          Text { textFormat: Text.PlainText; text: strings.t("best").arg(Commons.I18n.formatNumber(Math.round(root.state.bestSpeed))); color: Commons.Color.popups.text; font.pixelSize: Style.font.caption; font.bold: true }
          Text { textFormat: Text.PlainText; text: root.state.bestDate ? strings.t("bestDateStreak").arg(root.formattedBestDate()).arg(Commons.I18n.formatNumber(root.state.streak)) : strings.t("noBest"); color: Commons.Color.popups.text; opacity: 0.72; font.pixelSize: Style.font.caption }
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
