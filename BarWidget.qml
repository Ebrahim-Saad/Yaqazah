import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "esaad.yaqazah"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function refresh() { if (panelLoader.item) panelLoader.item.refresh() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: {
    injectPanel()
    refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "esaad.yaqazah"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { root.refresh() }
    function editLocation(): void {
      root.open()
      if (panelLoader.item) panelLoader.item.startEditingLocation()
    }
    function pickMethod(): void {
      root.open()
      if (panelLoader.item) panelLoader.item.openPicker = "method"
    }
    function setMethod(methodId: string): void {
      if (panelLoader.item) panelLoader.item.setMethod(methodId)
    }
    function setSchool(schoolId: string): void {
      if (panelLoader.item) panelLoader.item.setSchool(schoolId)
    }
    function setAutoLocation(): void {
      if (panelLoader.item) panelLoader.item.setLocationAuto()
    }
    function setManualLocation(city: string, country: string): void {
      if (panelLoader.item) panelLoader.item.setLocationManual(city, country)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: labelText.implicitWidth + scaledHorizontalMargin * 2
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    Text {
      id: labelText
      anchors.centerIn: parent
      text: panelLoader.item ? panelLoader.item.barLabel : "Prayer …"
      textFormat: Text.PlainText
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
    }
  }
}
