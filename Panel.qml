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

  property string currentPage: "main"   // "main" | "settings"

  readonly property var nextPrayer: report && report.next ? report.next : null
  readonly property var prayers: report && report.prayers ? report.prayers : []

  function cleanCountdown(cd) {
    if (!cd) return ""
    return String(cd).replace(/^in\s+/i, "").trim()
  }

  readonly property string rawCountdown: nextPrayer ? cleanCountdown(nextPrayer.countdown) : ""

  readonly property string currentBarFormatSetting: {
    var raw = root.settings && root.settings.barFormat !== undefined ? String(root.settings.barFormat).trim().toLowerCase() : "countdown"
    if (raw === "time" || raw === "clock") return "Time"
    if (raw === "smart" || raw === "hybrid" || raw === "auto") return "Smart"
    return "Countdown"
  }

  readonly property string currentSeparatorSetting: {
    var raw = root.settings && root.settings.barSeparator !== undefined ? String(root.settings.barSeparator).trim() : "dot"
    return raw !== "" ? raw : "dot"
  }

  readonly property bool isCustomSeparator: {
    var s = currentSeparatorSetting.toLowerCase()
    return s !== "dot" && s !== "dash" && s !== "pipe" && s !== "colon" && s !== "parens" && s !== "space"
  }

  function formatBarLabel(name, time) {
    if (!name) return ""
    if (!time) return name
    var sep = root.currentSeparatorSetting
    var lower = sep.toLowerCase()
    if (lower === "parens" || lower === "parentheses" || sep === "()") {
      return name + " (" + time + ")"
    } else if (lower === "brackets" || sep === "[]") {
      return name + " [" + time + "]"
    } else if (lower === "dot") {
      return name + " · " + time
    } else if (lower === "dash") {
      return name + " - " + time
    } else if (lower === "pipe") {
      return name + " | " + time
    } else if (lower === "colon") {
      return name + ": " + time
    } else if (lower === "space") {
      return name + " " + time
    } else {
      var literal = String(sep)
      if (literal === "·" || literal === "-" || literal === "|" || literal === "/" || literal === "~" || literal === "•") {
        return name + " " + literal + " " + time
      } else if (literal === ":") {
        return name + ": " + time
      } else {
        return name + (literal.indexOf(" ") !== -1 ? literal : (" " + literal + " ")) + time
      }
    }
  }

  readonly property bool isUnderOneHour: {
    if (!nextPrayer) return false
    if (nextPrayer.targetTimestamp !== undefined && nextPrayer.targetTimestamp > 0) {
      var diff = Number(nextPrayer.targetTimestamp) - Math.floor(Date.now() / 1000)
      return diff < 3600
    }
    if (nextPrayer.secondsLeft !== undefined && nextPrayer.secondsLeft !== null) {
      return Number(nextPrayer.secondsLeft) < 3600
    }
    if (nextPrayer.minutesLeft !== undefined && nextPrayer.minutesLeft !== null) {
      return Number(nextPrayer.minutesLeft) < 60
    }
    if (rawCountdown) {
      return rawCountdown.indexOf("h") === -1
    }
    return false
  }

  readonly property string currentTimeFormatSetting: {
    var raw = root.settings && root.settings.timeFormat !== undefined ? String(root.settings.timeFormat).trim().toLowerCase() : "24-hour"
    if (raw.indexOf("12") !== -1) return "12-hour"
    return "24-hour"
  }
  readonly property bool is12Hour: currentTimeFormatSetting === "12-hour"

  function formatClockTime(clockStr) {
    if (!clockStr) return ""
    var str = String(clockStr).trim()
    if (!root.is12Hour) {
      if (str.indexOf("AM") === -1 && str.indexOf("PM") === -1) return str
      var p = str.split(" ")
      var timePart = p[0].split(":")
      var hr = parseInt(timePart[0], 10)
      var mn = timePart[1] || "00"
      if (p[1] === "PM" && hr < 12) hr += 12
      if (p[1] === "AM" && hr === 12) hr = 0
      return (hr < 10 ? "0" + hr : "" + hr) + ":" + mn
    }
    if (str.indexOf("AM") !== -1 || str.indexOf("PM") !== -1) return str
    var parts = str.split(":")
    if (parts.length < 2) return str
    var h = parseInt(parts[0], 10)
    var m = parts[1]
    if (isNaN(h)) return str
    var ampm = h >= 12 ? "PM" : "AM"
    var h12 = h % 12
    if (h12 === 0) h12 = 12
    return h12 + ":" + m + " " + ampm
  }

  readonly property string barTimeText: {
    if (!nextPrayer) return ""
    if (currentBarFormatSetting === "Time") {
      return formatClockTime(nextPrayer.time)
    } else if (currentBarFormatSetting === "Smart") {
      return isUnderOneHour ? rawCountdown : formatClockTime(nextPrayer.time)
    } else {
      return rawCountdown
    }
  }

  readonly property string barLabel: nextPrayer
    ? formatBarLabel(nextPrayer.name, barTimeText)
    : (loading ? "Prayer …" : "Prayer unavailable")

  readonly property var separatorPresets: [
    { id: "dot", label: "·", name: "Dot" },
    { id: "dash", label: "-", name: "Dash" },
    { id: "pipe", label: "|", name: "Pipe" },
    { id: "colon", label: ":", name: "Colon" },
    { id: "parens", label: "( )", name: "Parens" },
    { id: "space", label: "␣", name: "Space" }
  ]

  readonly property var barFormatOptions: [
    {
      id: "Countdown",
      title: "Countdown",
      example: "(1h 30m)",
      description: "Always shows the remaining time countdown until the next prayer."
    },
    {
      id: "Time",
      title: "Prayer Time",
      example: root.is12Hour ? "(3:30 PM)" : "(15:30)",
      description: "Always shows the scheduled clock time of the next prayer."
    },
    {
      id: "Smart",
      title: "Smart Auto-switch",
      example: root.is12Hour ? "(3:30 PM → 45m)" : "(15:30 → 45m)",
      description: "Shows scheduled time until less than 1 hour remains, then switches to countdown."
    }
  ]

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
    { id: "Jordan", name: "Jordan", desc: "Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan" },
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
    args.push("--time-format", root.is12Hour ? "12h" : "24h")
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

  function openSettings() {
    root.cancelEditingLocation()
    root.openPicker = ""
    root.currentPage = "settings"
    if (flickable) flickable.contentY = 0
  }

  function closeSettings() {
    root.currentPage = "main"
    if (flickable) flickable.contentY = 0
  }

  function setBarFormat(formatId) {
    persistSettings({ barFormat: formatId })
  }

  function setBarSeparator(sepId) {
    persistSettings({ barSeparator: String(sepId || "").trim() || "dot" })
  }

  function setTimeFormat(formatId) {
    persistSettings({ timeFormat: formatId })
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
    root.currentPage = "main"
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
      currentPage = "main"
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

  Timer {
    id: dataKillTimer
    interval: 35000
    running: dataProc.running
    onTriggered: {
      if (dataProc.running) {
        dataProc.running = false
        root.loading = false
        if (root.report === null)
          root.errorText = "Prayer data request timed out."
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
    id: geocodeKillTimer
    interval: 35000
    running: geocodeProc.running
    onTriggered: {
      if (geocodeProc.running) {
        geocodeProc.running = false
        root.geocoding = false
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
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(activeHolder.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLocation || root.openPicker !== ""
      onActivateRequested: root.refresh()
      onCloseRequested: {
        if (root.currentPage === "settings") root.closeSettings()
        else if (root.editingLocation) root.cancelEditingLocation()
        else if (root.openPicker !== "") root.openPicker = ""
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refresh() }

      Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: activeHolder.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Item {
          id: activeHolder
          width: flickable.width
          implicitHeight: root.currentPage === "settings" ? settingsColumn.implicitHeight : contentColumn.implicitHeight

          Column {
            id: contentColumn
            visible: root.currentPage === "main"
            width: parent.width
            spacing: Style.space(12)

            // ---- Hero header ------------------------------------------------
            Item {
              width: parent.width
              implicitHeight: Math.max(settingsBtn.implicitHeight, heroLabels.implicitHeight, nextTime.implicitHeight)

              PanelActionButton {
                id: settingsBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰒓"
                tooltipText: "Settings"
                foreground: root.foreground
                hoverColor: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                size: Style.space(26)
                onClicked: root.openSettings()
              }

              Column {
                id: heroLabels
                anchors.left: settingsBtn.right
                anchors.leftMargin: Style.space(10)
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
                text: root.nextPrayer ? (root.nextPrayer.dayLabel + " · " + root.rawCountdown) : ""
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }

            Text {
              id: nextTime
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.nextPrayer ? root.formatClockTime(root.nextPrayer.time) : "—"
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
                  text: root.formatClockTime(parent.modelData.time)
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
                  placeholderText: "Filter 24 methods (e.g. Makkah, MWL, Egypt, Karachi)..."
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

        // ---- Settings View -----------------------------------------------
        Column {
          id: settingsColumn
          visible: root.currentPage === "settings"
          width: parent.width
          spacing: Style.space(12)

          // ---- Settings Header -------------------------------------------
          Item {
            width: parent.width
            implicitHeight: Math.max(backBtn.implicitHeight, settingsTitle.implicitHeight)

            PanelActionButton {
              id: backBtn
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰅁"
              tooltipText: "Back to prayers"
              foreground: root.foreground
              hoverColor: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              size: Style.space(26)
              onClicked: root.closeSettings()
            }

            Text {
              id: settingsTitle
              anchors.left: backBtn.right
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: "Settings"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Yaqazah"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Bar Widget Look Section -----------------------------------
          Column {
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "BAR WIDGET LOOK"
              foreground: root.foreground
            }

            Text {
              width: parent.width
              text: "Control how the next prayer is displayed in your top bar widget."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.barFormatOptions

              Rectangle {
                id: optCard
                required property var modelData
                required property int index
                width: parent.width
                implicitHeight: Math.max(Style.space(52), optCardCol.implicitHeight + Style.space(16))
                radius: Style.cornerRadius

                readonly property bool isSelected: root.currentBarFormatSetting === modelData.id
                readonly property bool isHovered: optCardMouse.containsMouse

                color: isSelected
                  ? Style.selectedFillFor(root.foreground, root.accent)
                  : (isHovered ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04))
                border.width: Style.spacing.hairline
                border.color: isSelected
                  ? root.accent
                  : (isHovered ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12))

                Row {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(10)

                  // Radio indicator circle
                  Rectangle {
                    width: Style.space(18)
                    height: Style.space(18)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: optCard.isSelected ? root.accent : "transparent"
                    border.width: Style.spacing.hairline
                    border.color: optCard.isSelected ? root.accent : (optCard.isHovered ? root.foreground : root.dim)

                    Text {
                      anchors.centerIn: parent
                      visible: optCard.isSelected
                      text: "󰄬"
                      color: Color.popups.background
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  Column {
                    id: optCardCol
                    width: parent.width - Style.space(28)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Row {
                      width: parent.width
                      spacing: Style.space(6)

                      Text {
                        text: optCard.modelData.title
                        color: optCard.isSelected ? root.accent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                      }

                      Text {
                        text: optCard.modelData.example
                        color: optCard.isSelected ? root.accent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: optCard.isSelected
                      }
                    }

                    Text {
                      width: parent.width
                      text: optCard.modelData.description
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }
                  }
                }

                MouseArea {
                  id: optCardMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  preventStealing: true
                  onClicked: root.setBarFormat(optCard.modelData.id)
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Bar Widget Separator Section -------------------------------
          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "BAR WIDGET SEPARATOR"
              foreground: root.foreground
            }

            Text {
              width: parent.width
              text: "Choose or customize the separator between prayer name and timer."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            // Grid of Presets
            Grid {
              width: parent.width
              columns: 3
              spacing: Style.space(6)

              Repeater {
                model: root.separatorPresets

                Rectangle {
                  id: sepBtn
                  required property var modelData
                  required property int index
                  width: Math.floor((parent.width - Style.space(12)) / 3)
                  height: Style.space(32)
                  radius: Style.cornerRadius

                  readonly property bool isSelected: root.currentSeparatorSetting.toLowerCase() === modelData.id
                  readonly property bool isHovered: sepMouse.containsMouse

                  color: isSelected
                    ? Style.selectedFillFor(root.foreground, root.accent)
                    : (isHovered ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04))
                  border.width: Style.spacing.hairline
                  border.color: isSelected
                    ? root.accent
                    : (isHovered ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12))

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(6)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: sepBtn.modelData.label
                      color: sepBtn.isSelected ? root.accent : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: sepBtn.modelData.name
                      color: sepBtn.isSelected ? root.accent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  MouseArea {
                    id: sepMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: {
                      root.setBarSeparator(sepBtn.modelData.id)
                      if (customSepInput) customSepInput.text = ""
                    }
                  }
                }
              }
            }

            // Custom separator input row
            Row {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: customSepInput
                width: parent.width - applySepBtn.width - Style.space(6)
                foreground: root.foreground
                accent: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                placeholderText: "Custom separator (e.g.  /  or  ~ )..."
                text: root.isCustomSeparator ? root.currentSeparatorSetting : ""
                onAccepted: {
                  if (text.trim() !== "") root.setBarSeparator(text)
                }
              }

              Rectangle {
                id: applySepBtn
                height: customSepInput.height
                width: Style.space(56)
                radius: Style.cornerRadius
                readonly property bool hot: applySepMouse.containsMouse
                color: hot ? Style.selectedFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                border.width: Style.spacing.hairline
                border.color: hot ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

                Text {
                  anchors.centerIn: parent
                  text: "Set"
                  color: parent.hot ? root.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                MouseArea {
                  id: applySepMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  preventStealing: true
                  onClicked: {
                    if (customSepInput.text.trim() !== "") root.setBarSeparator(customSepInput.text)
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Time System Section ----------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "TIME SYSTEM"
              foreground: root.foreground
            }

            Text {
              width: parent.width
              text: "Choose between 24-hour and 12-hour clock display."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: [
                  { id: "24-hour", title: "24-hour", example: "15:30" },
                  { id: "12-hour", title: "12-hour", example: "3:30 PM" }
                ]

                Rectangle {
                  id: timeSysBtn
                  required property var modelData
                  required property int index
                  width: Math.floor((parent.width - Style.space(8)) / 2)
                  height: Style.space(44)
                  radius: Style.cornerRadius

                  readonly property bool isSelected: root.currentTimeFormatSetting === modelData.id
                  readonly property bool isHovered: timeSysMouse.containsMouse

                  color: isSelected
                    ? Style.selectedFillFor(root.foreground, root.accent)
                    : (isHovered ? Style.hoverFillFor(root.foreground, root.accent) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04))
                  border.width: Style.spacing.hairline
                  border.color: isSelected
                    ? root.accent
                    : (isHovered ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12))

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(2)

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: timeSysBtn.modelData.title
                      color: timeSysBtn.isSelected ? root.accent : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: timeSysBtn.modelData.example
                      color: timeSysBtn.isSelected ? root.accent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  MouseArea {
                    id: timeSysMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: root.setTimeFormat(timeSysBtn.modelData.id)
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---- Notifications Row ------------------------------------------
          Item {
            width: parent.width
            implicitHeight: Math.max(notifLabels.implicitHeight, notifToggle.implicitHeight)

            Column {
              id: notifLabels
              anchors.left: parent.left
              anchors.right: notifToggle.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Prayer notifications"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                width: parent.width
                text: "Desktop alert when each prayer begins."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            ToggleSwitch {
              id: notifToggle
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: root.settings && root.settings.notificationsEnabled !== false
              foreground: root.foreground
              accent: root.accent
              onToggled: root.persistSettings({ notificationsEnabled: !checked })
            }
          }
        }
      }
    }
  }
}
}
