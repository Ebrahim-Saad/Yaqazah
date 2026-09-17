import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// THESIS: Awaken from the digital trance with a calm, precise Islamic timetable and spiritual companion.
// OWN-WORLD: Omarchy popup colors, typography, spacing, borders, and monochrome Yaqazah mark.
// STORY: Glance at the next prayer, stay mindful across long computer sessions, and track the daily Islamic schedule.
// FIRST VIEWPORT: Next-prayer header, location/date rail, six aligned schedule rows, interactive controls, method footer.
// FORM: Theme-native operational companion; yaqazah-v1.
Panel {
  id: root
  moduleName: "esaad.yaqazah"
  ipcTarget: "esaad.yaqazah"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color accent: Style.selectedStateColor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string scriptPath: Qt.resolvedUrl("yaqazah.py").toString().replace(/^file:\/\//, "") || (home + "/.config/omarchy/plugins/esaad.yaqazah/yaqazah.py")

  property var report: null
  property string errorText: ""
  property bool loading: false
  property int iconRevision: 0
  property bool refreshPending: false

  // Interactive UI state
  property bool editingLocation: false
  property string openPicker: ""       // "" | "method"
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string geocodePendingQuery: ""
  property string geocodeActiveQuery: ""
  property bool geocoding: false
  property string methodFilter: ""

  readonly property var nextPrayer: report && report.next ? report.next : null
  readonly property var prayers: report && report.prayers ? report.prayers : []
  readonly property string barLabel: nextPrayer
    ? nextPrayer.name + " · " + nextPrayer.countdown
    : (loading ? "Prayer …" : "Prayer unavailable")
  readonly property string themedIconSource: report && report.iconPath
    ? "file://" + report.iconPath + "?v=" + iconRevision
    : Qt.resolvedUrl("assets/yaqazah.svg")

  readonly property string currentMethodSetting: root.settings && root.settings.calculationMethod !== undefined ? String(root.settings.calculationMethod) : "Auto"
  readonly property string currentSchoolSetting: root.settings && root.settings.asrSchool !== undefined ? String(root.settings.asrSchool) : "Shafi"
  readonly property string currentLocationMode: root.settings && root.settings.locationMode !== undefined ? String(root.settings.locationMode) : "Auto"
  readonly property string currentManualCity: root.settings && root.settings.manualCity !== undefined ? String(root.settings.manualCity) : ""
  readonly property string currentManualCountry: root.settings && root.settings.manualCountry !== undefined ? String(root.settings.manualCountry) : ""

  readonly property string currentMethodShortName: {
    if (currentMethodSetting === "Auto") {
      return report && report.method ? "Auto (" + report.method.label + ")" : "Auto"
    }
    return currentMethodSetting
  }

  readonly property var methodChoices: [
    { id: "Auto", name: "Auto (Recommended)", desc: "Automatically recommended based on country" },
    { id: "MWL", name: "Muslim World League (MWL)", desc: "Europe, Far East, parts of US" },
    { id: "ISNA", name: "Islamic Society of North America", desc: "North America (US & Canada)" },
    { id: "Egypt", name: "Egyptian Authority of Survey", desc: "Egypt, Africa, Middle East" },
    { id: "Makkah", name: "Umm Al-Qura University, Makkah", desc: "Saudi Arabia and Arabian Peninsula" },
    { id: "Karachi", name: "Univ. of Islamic Sciences, Karachi", desc: "Pakistan, India, Bangladesh" },
    { id: "Tehran", name: "Institute of Geophysics, Univ. of Tehran", desc: "Iran and Shia communities" },
    { id: "Gulf", name: "Gulf Region", desc: "Gulf countries (fixed Isha angle)" },
    { id: "Kuwait", name: "Kuwait", desc: "Kuwait Ministry of Awqaf" },
    { id: "Qatar", name: "Qatar", desc: "Qatar Ministry of Awqaf" },
    { id: "Singapore", name: "Singapore (MUIS)", desc: "Majlis Ugama Islam Singapura" },
    { id: "France", name: "France (UOIF)", desc: "Union des Organisations Islamiques de France" },
    { id: "Turkey", name: "Turkey (Diyanet)", desc: "Diyanet İşleri Başkanlığı" },
    { id: "Russia", name: "Russia", desc: "Spiritual Administration of Muslims of Russia" },
    { id: "Moonsighting", name: "Moonsighting Committee Worldwide", desc: "UK, US, international" },
    { id: "Dubai", name: "Dubai", desc: "United Arab Emirates" },
    { id: "JAKIM", name: "Malaysia (JAKIM)", desc: "Jabatan Kemajuan Islam Malaysia" },
    { id: "Tunisia", name: "Tunisia", desc: "Ministry of Religious Affairs, Tunisia" },
    { id: "Algeria", name: "Algeria", desc: "Ministry of Religious Affairs, Algeria" },
    { id: "Kemenag", name: "Indonesia (Kemenag)", desc: "Kementerian Agama Republik Indonesia" },
    { id: "Morocco", name: "Morocco", desc: "Ministry of Habous, Morocco" },
    { id: "Portugal", name: "Portugal", desc: "Comunidade Islâmica de Lisboa" },
    { id: "Jafari", name: "Shia Ithna-Ashari (Jafari)", desc: "Leva Research Institute, Qum" }
  ]

  function filteredMethods() {
    var q = methodFilter.trim().toLowerCase()
    if (!q) return methodChoices
    var out = []
    for (var i = 0; i < methodChoices.length; i++) {
      var m = methodChoices[i]
      if (m.name.toLowerCase().indexOf(q) !== -1 || m.id.toLowerCase().indexOf(q) !== -1 || m.desc.toLowerCase().indexOf(q) !== -1) {
        out.push(m)
      }
    }
    return out
  }

  function settingArgs() {
    var s = root.settings || ({})
    var args = ["python3", root.scriptPath]
    args.push("--location-mode", String(s.locationMode || "Auto").toLowerCase())
    args.push("--city", String(s.manualCity || ""))
    args.push("--country", String(s.manualCountry || ""))
    args.push("--method", String(s.calculationMethod || "Auto"))
    args.push("--school", String(s.asrSchool || "Shafi"))
    if (s.notificationsEnabled !== false) args.push("--notify")
    return args
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
    root.refresh()
  }

  function setLocationAuto() {
    persistSettings({
      locationMode: "Auto",
      manualCity: "",
      manualCountry: ""
    })
    cancelEditingLocation()
  }

  function setLocationManual(city, country) {
    persistSettings({
      locationMode: "Manual",
      manualCity: String(city || "").trim(),
      manualCountry: String(country || "").trim()
    })
    cancelEditingLocation()
  }

  function setMethod(methodId) {
    persistSettings({ calculationMethod: methodId })
    root.openPicker = ""
    root.methodFilter = ""
  }

  function setSchool(schoolId) {
    persistSettings({ asrSchool: schoolId })
  }

  function startEditingLocation() {
    root.openPicker = ""
    root.editingLocation = true
    root.locationSuggestions = []
    root.suggestionIndex = 0
    Qt.callLater(function() {
      if (locationInput) {
        locationInput.text = root.currentLocationMode.toLowerCase() === "manual" ? root.currentManualCity : ""
        locationInput.forceActiveFocus()
        locationInput.selectAll()
      }
    })
  }

  function cancelEditingLocation() {
    root.editingLocation = false
    root.locationSuggestions = []
    root.geocodePendingQuery = ""
    root.geocodeActiveQuery = ""
    root.geocoding = false
    geocodeDebounce.stop()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function commitManualInput() {
    var text = locationInput ? locationInput.text.trim() : ""
    if (root.locationSuggestions.length > 0 && root.suggestionIndex >= 0 && root.suggestionIndex < root.locationSuggestions.length) {
      commitSuggestion(root.locationSuggestions[root.suggestionIndex])
      return
    }
    if (text) {
      var comma = text.indexOf(",")
      var cCity = comma !== -1 ? text.substring(0, comma).trim() : text
      var cCountry = comma !== -1 ? text.substring(comma + 1).trim() : ""
      setLocationManual(cCity, cCountry)
    } else {
      cancelEditingLocation()
    }
  }

  function commitSuggestion(item) {
    if (!item) return
    setLocationManual(item.name, item.country || item.countryCode || "")
  }

  function requestGeocode() {
    var query = locationInput ? locationInput.text.trim() : ""
    if (query.length < 2) {
      root.locationSuggestions = []
      return
    }
    root.geocodePendingQuery = query
    if (!geocodeProc.running) startGeocode()
  }

  function startGeocode() {
    root.geocodeActiveQuery = root.geocodePendingQuery
    root.geocoding = true
    geocodeProc.command = ["python3", root.scriptPath, "--search-city", root.geocodeActiveQuery]
    geocodeProc.running = true
  }

  function refresh() {
    if (dataProc.running) {
      refreshPending = true
      return
    }
    loading = report === null
    dataProc.command = settingArgs()
    dataProc.running = true
  }

  function open() {
    root.controller.show()
    root.refresh()
  }

  function close() {
    root.editingLocation = false
    root.openPicker = ""
    root.controller.hide()
  }

  function toggle() { root.opened ? root.close() : root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  onOpenedChanged: {
    if (!opened) {
      editingLocation = false
      openPicker = ""
    }
  }

  Process {
    id: dataProc
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0 && root.report === null && root.errorText === "")
        root.errorText = "Prayer data could not be loaded. Check your connection or location settings."
      if (root.refreshPending) {
        root.refreshPending = false
        Qt.callLater(root.refresh)
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          var parsed = JSON.parse(raw)
          if (parsed.ok === false) {
            root.errorText = String(parsed.error || "Prayer data is unavailable.")
            return
          }
          root.report = parsed
          root.errorText = ""
          root.iconRevision++
        } catch (e) {
          root.errorText = "Yaqazah returned an unreadable response."
        }
      }
    }
  }

  Process {
    id: geocodeProc
    onExited: function(exitCode) {
      root.geocoding = false
      if (root.editingLocation && root.geocodePendingQuery !== "" && root.geocodePendingQuery !== root.geocodeActiveQuery) {
        Qt.callLater(root.startGeocode)
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          var parsed = JSON.parse(raw)
          if (parsed.ok && Array.isArray(parsed.results)) {
            root.locationSuggestions = parsed.results
            root.suggestionIndex = 0
          } else {
            root.locationSuggestions = []
          }
        } catch (e) {
          root.locationSuggestions = []
        }
      }
    }
  }

  Timer {
    id: geocodeDebounce
    interval: 300
    onTriggered: root.requestGeocode()
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLocation || root.openPicker !== ""
      onActivateRequested: root.refresh()
      onCloseRequested: {
        if (root.editingLocation) root.cancelEditingLocation()
        else if (root.openPicker !== "") root.openPicker = ""
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refresh() }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.space(12)

          // ---- Hero header ------------------------------------------------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroLabels.implicitHeight, nextTime.implicitHeight)

            Column {
              id: heroLabels
              anchors.left: parent.left
              anchors.right: nextTime.left
              anchors.rightMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: root.nextPrayer ? root.nextPrayer.name : (root.loading ? "Finding prayer times" : "Prayer times unavailable")
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.nextPrayer ? (root.nextPrayer.dayLabel + " · " + root.nextPrayer.countdown) : ""
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }

            Text {
              id: nextTime
              width: Style.space(68)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.nextPrayer ? root.nextPrayer.time : "—"
              textFormat: Text.PlainText
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              horizontalAlignment: Text.AlignRight
            }
          }

          // ---- Location & Date rail (Clickable to change location) ---------
          Item {
            visible: (!root.editingLocation) && (!!root.report || root.loading)
            width: parent.width
            implicitHeight: Math.max(locPill.height, dateText.implicitHeight)

            Rectangle {
              id: locPill
              anchors.left: parent.left
              anchors.right: dateText.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(26)
              radius: Style.cornerRadius
              color: locMouse.containsMouse
                ? Style.hoverFillFor(root.foreground, root.accent)
                : "transparent"

              Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: locMouse.containsMouse ? Style.space(6) : 0
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰍎"
                  color: locMouse.containsMouse ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.report ? root.report.location.label : (root.loading ? "Detecting location…" : "Set location")
                  textFormat: Text.PlainText
                  color: locMouse.containsMouse ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, locPill.width - Style.space(36))
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰏫"
                  color: root.dim
                  visible: locMouse.containsMouse
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                id: locMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onClicked: root.startEditingLocation()
              }
            }

            Text {
              id: dateText
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.report ? root.report.hijri : ""
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // ---- Inline Location Editor Drawer ------------------------------
          Column {
            visible: root.editingLocation
            width: parent.width
            spacing: Style.space(6)

            Rectangle {
              width: parent.width
              implicitHeight: editCol.implicitHeight + Style.space(14)
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: Style.spacing.hairline
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

              Column {
                id: editCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(7)
                spacing: Style.space(7)

                Item {
                  width: parent.width
                  height: Style.space(24)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Rectangle {
                      height: Style.space(24)
                      width: autoBtnText.implicitWidth + Style.space(14)
                      radius: Style.cornerRadius
                      readonly property bool isAuto: root.currentLocationMode.toLowerCase() === "auto"
                      color: isAuto
                        ? Style.selectedFillFor(root.foreground, root.accent)
                        : (autoMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
                      border.width: Style.spacing.hairline
                      border.color: isAuto ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)

                      Text {
                        id: autoBtnText
                        anchors.centerIn: parent
                        text: "󰑐 Auto (IP)"
                        color: parent.isAuto ? root.accent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: parent.isAuto
                      }

                      MouseArea {
                        id: autoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: root.setLocationAuto()
                      }
                    }

                    Rectangle {
                      height: Style.space(24)
                      width: manualBtnText.implicitWidth + Style.space(14)
                      radius: Style.cornerRadius
                      readonly property bool isManual: root.currentLocationMode.toLowerCase() === "manual"
                      color: isManual
                        ? Style.selectedFillFor(root.foreground, root.accent)
                        : (manualMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
                      border.width: Style.spacing.hairline
                      border.color: isManual ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)

                      Text {
                        id: manualBtnText
                        anchors.centerIn: parent
                        text: "󰍎 Manual City"
                        color: parent.isManual ? root.accent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: parent.isManual
                      }

                      MouseArea {
                        id: manualMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: {
                          if (locationInput) {
                            locationInput.forceActiveFocus()
                            locationInput.selectAll()
                          }
                        }
                      }
                    }
                  }

                  Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(22)
                    width: Style.space(22)
                    radius: Style.cornerRadius
                    color: closeLocMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

                    Text {
                      anchors.centerIn: parent
                      text: "󰅖"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: closeLocMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      preventStealing: true
                      onClicked: root.cancelEditingLocation()
                    }
                  }
                }

                TextField {
                  id: locationInput
                  width: parent.width
                  foreground: root.foreground
                  accent: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  placeholderText: "Search city (e.g. London, Istanbul, Cairo)..."

                  onTextChanged: if (root.editingLocation) geocodeDebounce.restart()

                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                      root.cancelEditingLocation()
                      event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                      root.commitManualInput()
                      event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                      if (root.suggestionIndex < root.locationSuggestions.length - 1) root.suggestionIndex++
                      event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                      if (root.suggestionIndex > 0) root.suggestionIndex--
                      event.accepted = true
                    }
                  }
                }

                Text {
                  visible: root.geocoding
                  text: "Searching cities…"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.italic: true
                }

                Column {
                  visible: root.locationSuggestions.length > 0
                  width: parent.width
                  spacing: Style.space(2)

                  Repeater {
                    model: root.locationSuggestions

                    Rectangle {
                      required property var modelData
                      required property int index
                      width: parent.width
                      height: Style.space(30)
                      radius: Style.cornerRadius
                      color: index === root.suggestionIndex
                        ? Style.selectedFillFor(root.foreground, root.accent)
                        : (sugMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(8)
                        spacing: Style.space(8)

                        Text {
                          text: "󰍎"
                          color: parent.parent.index === root.suggestionIndex ? root.accent : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                          text: parent.parent.modelData.name
                          color: parent.parent.index === root.suggestionIndex ? root.accent : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          font.bold: true
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                          text: parent.parent.modelData.label !== parent.parent.modelData.name ? parent.parent.modelData.label : ""
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                          anchors.verticalCenter: parent.verticalCenter
                          width: Math.max(0, parent.width - Style.space(140))
                        }
                      }

                      MouseArea {
                        id: sugMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onEntered: root.suggestionIndex = parent.index
                        onClicked: {
                          root.suggestionIndex = parent.index
                          root.commitSuggestion(parent.modelData)
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Timetable schedule rows ------------------------------------
          Column {
            visible: root.prayers.length > 0
            width: parent.width
            spacing: Style.space(3)

            Repeater {
              model: root.prayers

              Rectangle {
                required property var modelData
                width: parent.width
                height: Style.space(40)
                radius: Style.cornerRadius
                color: modelData.status === "next"
                  ? Style.selectedFillFor(root.foreground, Color.accent)
                  : "transparent"

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(100)
                  text: parent.modelData.name
                  textFormat: Text.PlainText
                  color: parent.modelData.key === "sunrise" ? root.dim : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: parent.modelData.status === "next"
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.verticalCenter: parent.verticalCenter
                  text: parent.modelData.time
                  textFormat: Text.PlainText
                  color: parent.modelData.status === "next" ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(116)
                  horizontalAlignment: Text.AlignRight
                  text: parent.modelData.relative
                  textFormat: Text.PlainText
                  color: parent.modelData.status === "next" ? root.foreground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }
          }

          Text {
            visible: root.errorText !== ""
            width: parent.width
            topPadding: Style.space(18)
            bottomPadding: Style.space(18)
            text: root.errorText
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          // ---- Inline Method Picker Drawer --------------------------------
          Column {
            visible: root.openPicker === "method"
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { foreground: root.foreground }

            Rectangle {
              width: parent.width
              implicitHeight: methodPickerCol.implicitHeight + Style.space(14)
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: Style.spacing.hairline
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

              Column {
                id: methodPickerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(7)
                spacing: Style.space(7)

                Item {
                  width: parent.width
                  height: Style.space(22)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Select Calculation Method"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(20)
                    width: Style.space(20)
                    radius: Style.cornerRadius
                    color: closeMethodMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

                    Text {
                      anchors.centerIn: parent
                      text: "󰅖"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: closeMethodMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      preventStealing: true
                      onClicked: { root.openPicker = ""; root.methodFilter = "" }
                    }
                  }
                }

                TextField {
                  id: methodSearchInput
                  width: parent.width
                  foreground: root.foreground
                  accent: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  placeholderText: "Filter 23 methods (e.g. Makkah, MWL, Egypt, Karachi)..."
                  onTextChanged: root.methodFilter = text
                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                      root.openPicker = ""
                      root.methodFilter = ""
                      event.accepted = true
                    }
                  }
                }

                Flickable {
                  width: parent.width
                  height: Math.min(methodListCol.implicitHeight, Style.space(160))
                  contentWidth: width
                  contentHeight: methodListCol.implicitHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds

                  Column {
                    id: methodListCol
                    width: parent.width
                    spacing: Style.space(2)

                    Repeater {
                      model: root.filteredMethods()

                      Rectangle {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: Style.space(34)
                        radius: Style.cornerRadius
                        readonly property bool isSelected: root.currentMethodSetting === modelData.id
                        color: isSelected
                          ? Style.selectedFillFor(root.foreground, root.accent)
                          : (mItemMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")

                        Row {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(8)
                          anchors.rightMargin: Style.space(8)
                          spacing: Style.space(8)

                          Text {
                            text: parent.parent.isSelected ? "󰄬" : "  "
                            color: root.accent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                          }

                          Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Style.space(36)
                            spacing: Style.space(1)

                            Text {
                              width: parent.width
                              text: parent.parent.parent.modelData.name
                              color: parent.parent.parent.isSelected ? root.accent : root.foreground
                              font.family: root.fontFamily
                              font.pixelSize: Style.font.bodySmall
                              font.bold: parent.parent.parent.isSelected
                              elide: Text.ElideRight
                            }

                            Text {
                              width: parent.width
                              text: parent.parent.parent.modelData.desc
                              color: root.dim
                              font.family: root.fontFamily
                              font.pixelSize: Style.font.caption
                              elide: Text.ElideRight
                            }
                          }
                        }

                        MouseArea {
                          id: mItemMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          preventStealing: true
                          onClicked: root.setMethod(parent.modelData.id)
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { visible: !!root.report; foreground: root.foreground }

          // ---- Sleek Controls Footer (Method, Asr School, Location badge) -
          Item {
            visible: !!root.report
            width: parent.width
            height: Style.space(24)

            // Left: Method trigger link + separator + Asr segmented toggle
            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              // Method clickable selector
              Rectangle {
                id: methodLink
                height: Style.space(24)
                width: methodLinkRow.implicitWidth + Style.space(12)
                radius: Style.cornerRadius
                color: root.openPicker === "method"
                  ? Style.selectedFillFor(root.foreground, root.accent)
                  : (methodLinkMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
                border.width: root.openPicker === "method" ? Style.spacing.hairline : 0
                border.color: root.accent
                anchors.verticalCenter: parent.verticalCenter

                Row {
                  id: methodLinkRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentMethodShortName
                    color: root.openPicker === "method" ? root.accent : (methodLinkMouse.containsMouse ? root.foreground : root.dim)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: root.openPicker === "method"
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, Style.space(130))
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.openPicker === "method" ? "󰅃" : "󰅀"
                    color: root.openPicker === "method" ? root.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: methodLinkMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  preventStealing: true
                  onClicked: {
                    root.methodFilter = ""
                    root.openPicker = (root.openPicker === "method" ? "" : "method")
                    if (root.openPicker === "method") {
                      root.cancelEditingLocation()
                      Qt.callLater(function() { if (methodSearchInput) methodSearchInput.forceActiveFocus() })
                    }
                  }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "·"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              // Asr School compact segmented pill
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Rectangle {
                  id: shafiPill
                  height: Style.space(22)
                  width: shafiLabel.implicitWidth + Style.space(12)
                  radius: Style.cornerRadius
                  readonly property bool isSelected: root.currentSchoolSetting === "Shafi"
                  color: isSelected
                    ? Style.selectedFillFor(root.foreground, root.accent)
                    : (shafiMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
                  border.width: isSelected ? Style.spacing.hairline : 0
                  border.color: root.accent

                  Text {
                    id: shafiLabel
                    anchors.centerIn: parent
                    text: "Shafi"
                    color: parent.isSelected ? root.accent : (shafiMouse.containsMouse ? root.foreground : root.dim)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: parent.isSelected
                  }

                  MouseArea {
                    id: shafiMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: root.setSchool("Shafi")
                  }
                }

                Rectangle {
                  id: hanafiPill
                  height: Style.space(22)
                  width: hanafiLabel.implicitWidth + Style.space(12)
                  radius: Style.cornerRadius
                  readonly property bool isSelected: root.currentSchoolSetting === "Hanafi"
                  color: isSelected
                    ? Style.selectedFillFor(root.foreground, root.accent)
                    : (hanafiMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
                  border.width: isSelected ? Style.spacing.hairline : 0
                  border.color: root.accent

                  Text {
                    id: hanafiLabel
                    anchors.centerIn: parent
                    text: "Hanafi"
                    color: parent.isSelected ? root.accent : (hanafiMouse.containsMouse ? root.foreground : root.dim)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: parent.isSelected
                  }

                  MouseArea {
                    id: hanafiMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: root.setSchool("Hanafi")
                  }
                }
              }
            }

            // Right: Location mode badge
            Rectangle {
              id: sourceBadge
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(20)
              width: sourceText.implicitWidth + Style.space(10)
              radius: Style.space(3)
              color: srcMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: Style.spacing.hairline
              border.color: srcMouse.containsMouse ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

              Text {
                id: sourceText
                anchors.centerIn: parent
                text: root.report
                  ? ((root.report.stale || root.report.location.stale)
                    ? "CACHED"
                    : (root.report.location.source === "auto" ? "AUTO" : "MANUAL"))
                  : ""
                textFormat: Text.PlainText
                color: srcMouse.containsMouse ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 0.8
              }

              MouseArea {
                id: srcMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onClicked: root.startEditingLocation()
              }
            }
          }
        }
      }
    }
  }
}
