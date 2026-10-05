import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// Bar face of the Unsplash wallpaper plugin. The engine lives in Service.qml
// (one per shell); this widget is one per monitor and only renders + relays.
//
//   left click    popup: preview, credit, history, favorite, keywords, interval
//   right click   new photo now
//   middle click  favorite / unfavorite
//   scroll        step through recent wallpapers
BarWidget {
  id: root
  moduleName: "tkreek.unsplash"

  readonly property var svc: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("tkreek.unsplash") : null
  readonly property bool ready: svc !== null && svc !== undefined
  readonly property var photo: ready ? svc.current : null
  readonly property bool busy: ready && svc.busy
  readonly property bool hasKey: ready && svc.hasKey
  readonly property bool isFavorite: !!(photo && photo.favorite)

  readonly property color accent: Color.accent
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Always the same glyph; busy shows as dimming, favorites only in the popup.
  readonly property string icon: "󰸉"

  readonly property string tooltip: {
    if (!ready) return "Unsplash"
    if (!hasKey) return "Unsplash: click to set up"
    if (busy) return "Fetching a new wallpaper…"
    if (!photo) return "Unsplash: right-click for a wallpaper"
    return "Photo by " + photo.author + " on Unsplash" + (isFavorite ? " · favorite" : "")
      + "\nRight-click: new · Middle-click: favorite · Scroll: history"
  }

  property bool popupOpen: false

  // Shape contract the shell expects from a bar widget with a panel; this is
  // what makes `omarchy-shell shell toggle tkreek.unsplash` work.
  readonly property bool opened: popupOpen
  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function togglePanel() { popupOpen = !popupOpen }

  function keywordsText() {
    return ready ? svc.keywords.join(", ") : ""
  }

  // Normalised so "a,b" and "a, b" compare equal to what's saved.
  function normaliseKeywords(text) {
    return String(text || "").split(",").map(function(k) { return k.trim() })
      .filter(function(k) { return k !== "" }).sort().join(", ")
  }
  readonly property bool keywordsDirty: ready && normaliseKeywords(keywordsField.text) !== normaliseKeywords(keywordsText())

  // Saves the keyword field (if changed) and fetches a matching wallpaper.
  function applyKeywords() {
    if (!ready) return
    if (keywordsDirty) svc.setKeywords(keywordsField.text)
    else svc.newPhoto()
    keywordsField.focus = false
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    foreground: root.bar ? root.bar.barForeground : Color.foreground
    dimmed: root.busy || (root.ready && !root.hasKey)
    useActiveColor: false
    tooltipText: root.tooltip

    onPressed: function(b) {
      if (!root.ready) return
      if (b === Qt.RightButton) root.svc.newPhoto()
      else if (b === Qt.MiddleButton) root.svc.toggleFavorite()
      else root.togglePanel()
    }
    onWheelMoved: function(delta) {
      if (!root.ready) return
      if (delta > 0) { if (root.svc.canGoBack) root.svc.previous() }
      else if (root.svc.canGoForward) root.svc.next()
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      // ---------------------------------------------------------- setup (no key)
      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: root.ready && !root.hasKey

        Text {
          width: parent.width
          text: "UNSPLASH WALLPAPERS"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 2
        }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "A fresh wallpaper from Unsplash every day. To get started, create a free "
            + "Unsplash app (about two minutes) and paste its Access Key below."
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        Button {
          iconText: "󰏌"
          text: "Get a free access key"
          foreground: root.fg
          accent: root.accent
          bordered: true
          onClicked: root.svc.openKeySignup()
        }
        Row {
          width: parent.width
          spacing: Style.space(6)
          TextField {
            id: keyField
            width: parent.width - saveKey.width - parent.spacing
            placeholderText: "Paste access key"
            foreground: root.fg
            accent: root.accent
            font.family: root.fontFamily
            onAccepted: root.svc.setKey(text)
            Keys.onEscapePressed: root.close()
          }
          Button {
            id: saveKey
            text: "Save"
            foreground: root.fg
            accent: root.accent
            bordered: true
            enabled: keyField.text.trim() !== "" && !root.busy
            opacity: enabled ? 1 : 0.4
            onClicked: root.svc.setKey(keyField.text)
          }
        }
      }

      // ---------------------------------------------------------- preview
      ClippingRectangle {
        visible: root.hasKey
        width: parent.width
        height: Math.round(width * 9 / 16)
        radius: Style.space(6)
        color: root.photo && root.photo.color ? root.photo.color : Util.alpha(root.fg, 0.08)

        Image {
          id: preview
          anchors.fill: parent
          source: root.photo && root.photo.file ? "file://" + root.photo.file : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: Math.round(parent.width * 2)
          opacity: status === Image.Ready ? (root.busy ? 0.45 : 1) : 0
          Behavior on opacity { NumberAnimation { duration: 250 } }
        }

        Text {
          anchors.centerIn: parent
          visible: root.busy || !root.photo
          text: root.busy ? "Fetching…" : "Right-click the bar icon or press 󰑐 for a wallpaper"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          anchors.fill: parent
          enabled: !!root.photo
          cursorShape: Qt.PointingHandCursor
          onClicked: root.svc.openPhoto()
        }
      }

      // ---------------------------------------------------------- credit
      Column {
        visible: root.hasKey && !!root.photo
        width: parent.width
        spacing: Style.space(2)

        Text {
          width: parent.width
          visible: text !== ""
          text: root.photo && root.photo.description
            ? root.photo.description.charAt(0).toUpperCase() + root.photo.description.slice(1) : ""
          elide: Text.ElideRight
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
        Text {
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.StyledText
          linkColor: root.accent
          text: root.photo
            ? "Photo by <a href=\"" + root.photo.author_url + "\">" + root.photo.author + "</a> on "
              + "<a href=\"https://unsplash.com/?utm_source=omarchy_unsplash&utm_medium=referral\">Unsplash</a>"
              + (root.photo.location ? " · " + root.photo.location : "")
            : ""
          color: Util.alpha(root.fg, 0.7)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          onLinkActivated: function(link) { root.svc.openUrl(link) }
          HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
      }

      // ---------------------------------------------------------- transport
      Row {
        visible: root.hasKey
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰅁"
          tooltipText: "Previous wallpaper"
          foreground: root.fg
          accent: root.accent
          bordered: true
          enabled: root.ready && root.svc.canGoBack && !root.busy
          opacity: enabled ? 1 : 0.4
          onClicked: root.svc.previous()
        }
        Button {
          iconText: root.isFavorite ? "󰋑" : "󰋕"
          text: root.isFavorite ? "Saved" : "Favorite"
          foreground: root.fg
          accent: root.accent
          bordered: true
          selected: root.isFavorite
          enabled: !!root.photo && !root.busy
          opacity: enabled ? 1 : 0.4
          onClicked: root.svc.toggleFavorite()
        }
        Button {
          iconText: "󰑐"
          text: "New"
          tooltipText: "Fetch a new wallpaper now"
          foreground: root.fg
          accent: root.accent
          bordered: true
          iconSpinning: root.busy
          enabled: !root.busy
          // Unsaved keywords in the field count: apply them first.
          onClicked: root.applyKeywords()
        }
        Button {
          iconText: "󰅂"
          tooltipText: "Next wallpaper"
          foreground: root.fg
          accent: root.accent
          bordered: true
          enabled: root.ready && root.svc.canGoForward && !root.busy
          opacity: enabled ? 1 : 0.4
          onClicked: root.svc.next()
        }
      }

      // ---------------------------------------------------------- messages
      Text {
        width: parent.width
        visible: text !== ""
        wrapMode: Text.WordWrap
        text: !root.ready ? "" : (root.svc.message !== "" ? root.svc.message
          : (root.hasKey ? root.svc.errorText : ""))
        color: root.ready && (root.svc.messageIsError || root.svc.lastError !== "") ? Color.urgent : Util.alpha(root.fg, 0.7)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      PanelSeparator { visible: root.hasKey; width: parent.width; foreground: root.fg }

      // ---------------------------------------------------------- keywords
      PanelSectionHeader { visible: root.hasKey; text: "Keywords"; foreground: root.fg; fontFamily: root.fontFamily }

      Row {
        visible: root.hasKey
        width: parent.width
        spacing: Style.space(6)

        TextField {
          id: keywordsField
          width: parent.width - applyKeywords.width - parent.spacing
          placeholderText: "mountains, fog, minimal…"
          foreground: root.fg
          accent: root.accent
          font.family: root.fontFamily
          text: root.keywordsText()
          onAccepted: root.applyKeywords()
          Keys.onEscapePressed: { text = root.keywordsText(); root.close() }
          // Re-sync from config when not being edited.
          Connections {
            target: root.svc
            function onConfigChanged() { if (!keywordsField.activeFocus) keywordsField.text = root.keywordsText() }
          }
        }
        Button {
          id: applyKeywords
          text: "Apply"
          tooltipText: "Save keywords and fetch a matching wallpaper"
          foreground: root.fg
          accent: root.accent
          bordered: true
          selected: root.keywordsDirty
          enabled: root.keywordsDirty && !root.busy
          opacity: enabled ? 1 : 0.4
          onClicked: root.applyKeywords()
        }
      }
      Text {
        visible: root.hasKey
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Comma separated; one is picked at random each time. Leave blank for Unsplash's wallpaper picks."
        color: Util.alpha(root.fg, 0.55)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      // ---------------------------------------------------------- interval
      PanelSectionHeader { visible: root.hasKey; text: "New wallpaper"; foreground: root.fg; fontFamily: root.fontFamily }

      ButtonGroup {
        visible: root.hasKey
        options: [
          { value: "hourly", label: "Hourly" },
          { value: "daily", label: "Daily" },
          { value: "weekly", label: "Weekly" }
        ]
        value: root.ready ? root.svc.interval : "daily"
        foreground: root.fg
        accent: root.accent
        fontFamily: root.fontFamily
        focusable: false
        onChanged: function(v) { root.svc.setChangeInterval(v) }
      }

      PanelSeparator { visible: root.hasKey; width: parent.width; foreground: root.fg }

      // Two equal halves spanning the full width, so both edges line up
      // with the rest of the popup.
      Row {
        id: footer
        visible: root.hasKey
        width: parent.width
        spacing: Style.space(6)
        readonly property real half: (width - spacing) / 2
        Button {
          width: footer.half
          iconText: "󰋑"
          text: "Favorites"
          tooltipText: "Browse saved favorites"
          foreground: root.fg
          accent: root.accent
          bordered: true
          onClicked: { root.close(); root.svc.openFavorites() }
        }
        Button {
          width: footer.half
          iconText: "󰏌"
          text: "Unsplash"
          tooltipText: "Open this photo on unsplash.com"
          foreground: root.fg
          accent: root.accent
          bordered: true
          enabled: !!root.photo
          opacity: enabled ? 1 : 0.4
          onClicked: root.svc.openPhoto()
        }
      }
    }
  }
}
