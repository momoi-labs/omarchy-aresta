import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "MenuModel.js" as MenuModel
import "Calculator.js" as Calculator

Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // Plugin lifecycle hooks. The host calls open(payloadJson) after
  // `omarchy-shell shell summon omarchy.menu ...` and close() when hidden.
  property string pendingInitialMenu: "root"

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }

    if (payload.fontFamily) root.fontFamily = payload.fontFamily
    // A shell that started mid-update may never have read the shipped menu
    // whole; reading it again here keeps the menu from opening empty.
    if (root.defaultMenuItems.length === 0) defaultMenuFile.reload()

    if (payload.mode === "select" || payload.mode === "input") {
      root.openDmenu(payload)
    } else {
      root.openRoute(payload.initialMenu || payload.menu || "root")
    }
  }

  function close() {
    root.cancel()
  }

  function refresh() {
    defaultMenuFile.reload()
    userMenuFile.reload()
    languageFile.reload()
    menuCatalogFile.reload()
    return "ok"
  }

  function ping() { return "ok" }

  property string fontFamily: {
    if (root.dmenuActive) return Style.font.menuFamily
    var families = Qt.fontFamilies()
    var preferred = ["SF Pro Text", "SF Pro", "System Font", "Inter"]
    for (var i = 0; i < preferred.length; i++)
      if (families.indexOf(preferred[i]) !== -1) return preferred[i]
    return "sans-serif"
  }
  // JSONC menu definitions. The shell parses both at startup and merges
  // the user file on top of the defaults, so the keybind → IPC → visible
  // path doesn't have to shell out to bash + jq on every open.
  property string defaultMenuPath: omarchyPath + "/default/omarchy/omarchy-menu.jsonc"
  property string userMenuPath: Quickshell.env("HOME") + "/.config/omarchy/extensions/omarchy-menu.jsonc"
  // Display language for the shipped rows. The code lives in
  // ~/.config/omarchy/language (omarchy-language owns it); a missing file
  // means English. The catalog at default/i18n/<code>/menu.json is applied
  // to the default items before the user extension merges on top, so a
  // user's own rows and retitles always win.
  property string language: "en"
  property var menuCatalog: ({})
  readonly property string languagePath: Quickshell.env("OMARCHY_LANGUAGE_FILE") || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omarchy/language")
  property var defaultMenuItems: []
  property var userMenuItems: []
  // Whether each file has answered once, loaded or (the user's) missing. At
  // startup both arrive separately, and evaluating guards for the first alone
  // would run the whole batch twice; an open before then evaluates anyway.
  property bool defaultMenuSettled: false
  property bool userMenuSettled: false
  property bool opened: false
  property string mode: "menu"
  readonly property bool dmenuActive: mode === "select" || mode === "input"
  property string dmenuPrompt: ""
  property var dmenuOptions: []
  property bool dmenuMultiple: false
  property var dmenuSelected: []
  // What the last confirmed change applied; a failed change returns the checks here.
  property var dmenuSaved: []
  property string dmenuChangeKey: ""
  property var dmenuOnChange: []
  property string selectionFile: ""
  property string doneFile: ""
  property int dmenuWidth: 300
  property int dmenuMaxHeight: 0
  property bool requestActive: false
  property bool rowsLoaded: false
  property string activeMenu: "root"
  property string filterText: ""
  // Resets of filterText reach the search line; its edits come back through setFilter.
  onFilterTextChanged: if (filterInput.text !== filterText) filterInput.text = filterText
  property int selectedIndex: 0
  property bool cursorActive: false
  property int requestSerial: 0
  property int applySerial: 0
  property var items: ({})
  property var itemOrder: []
  property var navStack: []
  property var providersLoaded: ({})
  property var providerQueue: []
  property int providerRevision: 0

  // Shared application engine (entries, hidden filters, icons, launch,
  // removal), owned by the shell and also used by the standalone launcher.
  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
  property bool deleteConfirmOpen: false
  property var deleteTarget: null
  onOpenedChanged: if (!opened) { deleteConfirmOpen = false; deleteTarget = null }
  // Bound to the central [menu] section in shell.toml via Commons.Color.qml.
  // Each color already includes its alpha companion (composed in the
  // singleton), so consumers can drop them straight into a Rectangle.
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  readonly property bool lightCard: root.background.hslLightness > 0.5
  property color border: Util.alpha(Commons.Color.menu.text, root.dmenuActive ? 0.16 : (root.lightCard ? 0.1 : 0.12))
  property color scrim: "transparent"
  property color selectedBackground: Commons.Color.menu.selectedText
  property color selectedText: selectedBackground.hslLightness > 0.6 ? "#000000" : "#ffffff"
  readonly property var spotlightSettings: {
    var values = { spotlight_size: 100, spotlight_selection: "gray", spotlight_shortcuts: false }
    var lines = settingsFile.text().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(\w+)\s*=\s*(.*?)\s*$/)
      if (!match || !(match[1] in values)) continue
      if (typeof values[match[1]] === "boolean") {
        if (match[2] === "true" || match[2] === "false") values[match[1]] = match[2] === "true"
      } else if (typeof values[match[1]] === "string") {
        var text = match[2].match(/^"(.*)"$/)
        if (text) values[match[1]] = text[1]
      } else if (match[2] !== "" && !isNaN(Number(match[2]))) {
        values[match[1]] = Number(match[2])
      }
    }
    return values
  }
  readonly property real sizeScale: Math.max(80, Math.min(150, root.spotlightSettings.spotlight_size)) / 100
  readonly property bool showFooter: root.dmenuActive || root.spotlightSettings.spotlight_shortcuts
  readonly property bool grayRows: !root.dmenuActive && root.spotlightSettings.spotlight_selection !== "accent"
  readonly property color rowFill: root.grayRows ? Util.alpha(root.lightCard ? "#000000" : "#ffffff", root.lightCard ? 0.12 : 0.15) : root.selectedBackground
  readonly property color rowInk: root.grayRows ? root.foreground : root.selectedText
  readonly property int cornerRadius: root.dmenuActive ? 16 : root.px(25)
  readonly property real cornerPower: 3.4
  readonly property int rowRadius: root.dmenuActive ? 8 : root.px(14)
  property int contentMargin: root.dmenuActive ? Style.space(8) : root.px(8)
  property int headerHeight: root.dmenuActive ? Style.space(52) : root.px(56)
  readonly property int filterBarHeight: root.dmenuActive ? 0 : root.px(46)
  readonly property int footerHeight: root.dmenuActive ? Style.space(30) : (root.showFooter ? root.px(32) : 0)
  readonly property int chromeHeight: headerHeight + calcAreaHeight + filterBarHeight + footerHeight + (root.showFooter ? 2 : 1) + (mode === "input" ? 0 : contentMargin * 2)
  property int baseRowHeight: root.dmenuActive ? Math.max(Style.space(32), Style.font.heading + Style.spacing.rowPaddingX) : root.px(56)
  property int detailRowHeight: Math.max(Style.space(46), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property string calcResult: ""
  property bool calcFocused: false
  readonly property int calcCardHeight: root.px(60)
  readonly property int calcAreaHeight: root.calcResult ? root.calcCardHeight + root.contentMargin : 0
  // How much of the first hidden row stays visible at the fold — enough to
  // read as a cut-off row rather than a bottom border.
  property int rowPeek: Math.round(baseRowHeight * 0.55)
  property int rowSpacing: 0
  property int dividerHeight: root.dmenuActive ? Style.space(17) : root.px(17)
  property bool searchDivider: false
  property int layoutSerial: 0
  readonly property bool gridActive: !root.dmenuActive && root.activeMenu === "apps"
  readonly property int gridColumns: 6
  readonly property int gridCellHeight: root.px(96)
  property int cardWidth: Math.min(root.dmenuActive ? Style.space(root.dmenuWidth) : root.px(640), panel.width - Style.gapsOut * 2)
  property int visibleRowsHeight: root.dmenuActive ? dmenuRowListHeight(layoutSerial, displayModel.count, filterText) : (root.gridActive ? gridHeight(layoutSerial, displayModel.count) : rowListHeight(layoutSerial, displayModel.count, filterText, searchDivider))
  property int cardHeight: Math.min(chromeHeight + (mode === "input" ? 0 : visibleRowsHeight), panel.height - Style.gapsOut * 2)

  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/omarchy-cupertino/settings.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoadFailed: settingsRetry.restart()
  }

  Timer {
    id: settingsRetry
    interval: 2000
    onTriggered: settingsFile.reload()
  }

  function px(macPoints) {
    return Math.max(1, Math.round(Style.spaceReal(macPoints) * root.sizeScale))
  }

  readonly property var filters: {
    var revision = root.layoutSerial
    var out = []
    for (var i = 0; i < root.itemOrder.length && out.length < 9; i++) {
      var entry = root.item(root.itemOrder[i])
      if (!entry || entry.parent !== "root" || (entry.kind !== "menu" && !entry.provider) || !root.isVisible(entry)) continue
      out.push({ id: entry.id, label: entry.title || entry.label, icon: entry.icon || "" })
    }
    return out
  }
  readonly property var currentRow: {
    var revision = root.layoutSerial
    return !root.calcFocused && root.cursorActive && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count ? displayModel.get(root.selectedIndex) : null
  }

  function verbFor(row) {
    return row && row.kind === "action" ? "Run" : "Open"
  }
  readonly property string activeFilter: {
    var id = root.activeMenu
    var entry = root.item(id)
    while (entry && entry.parent && entry.parent !== "root") entry = root.item(entry.parent)
    return entry && entry.parent === "root" ? entry.id : ""
  }

  function applyFilter(index) {
    if (root.dmenuActive || index < 0 || index >= root.filters.length) return
    var id = root.filters[index].id
    root.navStack = []
    root.setActiveMenu(root.activeMenu === id ? "root" : id, false)
  }

  function gridHeight(_serial, _count) {
    var rows = Math.max(1, Math.ceil(displayModel.count / root.gridColumns))
    return Math.min(rows * root.gridCellHeight, Math.max(root.gridCellHeight, root.availableRowsHeight()))
  }

  function finishRequest(selection) {
    if (!root.requestActive || !root.doneFile) {
      root.opened = false
      return
    }

    var activeSelectionFile = root.selectionFile
    var activeDoneFile = root.doneFile
    root.requestActive = false
    root.selectionFile = ""
    root.doneFile = ""

    if (selection === null || selection === undefined) {
      resultProc.command = ["bash", "-c", ": > " + Util.shellQuote(activeDoneFile)]
    } else {
      resultProc.command = ["bash", "-c", "printf '%s\\n' " + Util.shellQuote(selection) + " > " + Util.shellQuote(activeSelectionFile) + "; : > " + Util.shellQuote(activeDoneFile)]
    }
    resultProc.running = true
  }

  function runAction(action) {
    var command = String(action || "")
    if (!command) return

    var summon = MenuModel.summonAction(command)
    if (summon && root.shell && root.shell.summon(summon.id, summon.payload)) return

    Util.execDetached(command)
  }

  // Menu rows only surface their detail while a search is narrowing them;
  // dmenu rows carry caller-supplied subtext that must always be visible.
  function rowHeightForDetail(detail) {
    return root.dmenuActive && detail ? root.detailRowHeight : root.baseRowHeight
  }

  // Height the card can devote to rows before running off the screen — or
  // past the frozen top edge once a search has pinned the card in place.
  // Uses panel.cardTop rather than effectiveCardTop: the centered top is
  // derived from the card height, which this value feeds.
  function availableRowsHeight() {
    var top = panel.cardTop >= 0 ? panel.cardTop : (root.dmenuActive ? Style.gapsOut : panel.centeredTop)
    var available = panel.height - top - Style.gapsOut - root.chromeHeight
    // The starting menu sets the ceiling along with the offset: drilling into
    // a longer submenu scrolls behind the fold instead of growing the card.
    if (root.dmenuActive && panel.maxRowsHeight >= 0) available = Math.min(available, panel.maxRowsHeight)
    if (!root.dmenuActive && !root.gridActive) available = Math.min(available, root.baseRowHeight * 7 + root.rowPeek)
    // A card that swallows the whole screen reads as a page, not a menu.
    return Math.min(available, Math.round(panel.height * 0.7))
  }

  // When every row fits, the list gets its full height. When they don't,
  // the card must end mid-row: a clipped row is what tells the eye there is
  // more below the fold, so never come out even on a row boundary.
  function foldedListHeight(totals, available) {
    var count = totals.length
    if (count === 0) return root.baseRowHeight
    if (totals[count - 1] <= available) return totals[count - 1]

    var peek = root.rowPeek
    var full = 0
    while (full < count && totals[full] <= available) full++
    while (full > 1 && totals[full - 1] + root.rowSpacing + peek > available) full--
    if (full < 1) return Math.max(available, root.baseRowHeight)

    return totals[full - 1] + root.rowSpacing + peek
  }

  function rowListHeight(_serial, _count, _filter, _divider) {
    if (displayModel.count === 0) return root.calcResult ? 0 : root.baseRowHeight

    var totals = []
    var total = 0
    var previousSection = ""

    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (i > 0) total += root.rowSpacing
      if (row.section === "drilldown" && previousSection !== "drilldown") total += root.dividerHeight
      total += root.rowHeightForDetail(row.detail)
      previousSection = row.section
      totals.push(total)
    }

    return foldedListHeight(totals, availableRowsHeight())
  }

  function dmenuRowListHeight(_serial, _count, _filter) {
    if (root.mode === "input") return 0
    if (displayModel.count === 0) return root.baseRowHeight

    var available = availableRowsHeight()
    if (root.dmenuMaxHeight > 0) available = Math.min(available, Style.space(root.dmenuMaxHeight))

    var totals = []
    var total = 0
    for (var i = 0; i < displayModel.count; i++) {
      if (i > 0) total += root.rowSpacing
      total += root.rowHeightForDetail(displayModel.get(i).detail)
      totals.push(total)
    }

    return foldedListHeight(totals, available)
  }

  function item(id) {
    return root.items[id] || null
  }

  // ------------------------------------------------------------------
  // JSONC → normalized item array. Mirrors the bash bin's jq pipeline so
  // the on-disk authoring format stays untouched.
  // ------------------------------------------------------------------

  function stripJsonc(raw) {
    return MenuModel.stripJsonc(raw)
  }

  function normalizeAliases(value) {
    return MenuModel.normalizeAliases(value)
  }

  function normalizeItem(id, raw) {
    return MenuModel.normalizeItem(id, raw)
  }

  function parseMenuJsonc(raw) {
    return MenuModel.parseMenuJsonc(raw)
  }

  function parseCatalog(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({})
    } catch (e) {
      return ({})
    }
  }

  function setLanguage(raw) {
    var code = String(raw || "").trim()
    if (!/^[a-z]{2,3}(-[A-Za-z]{2})?$/.test(code)) code = "en"
    if (root.language === code) return
    root.language = code
    menuCatalogFile.reload()
  }

  // Merge defaults + user extension. Later entries override earlier ones
  // on a per-key basis (so the user can tweak label/icon/action without
  // re-declaring the whole row).
  // Catalog-only rebuilds pass skipGuards: retitling rows cannot change any
  // when/checked answer, so re-running the guard batch would be pure waste.
  function rebuildItemsFromSources(skipGuards) {
    var translatedDefaults = MenuModel.applyTranslations(root.defaultMenuItems, root.menuCatalog)
    // The root row is injected by the merge (it has no JSONC entry), so its
    // "Go" label comes from the catalog's root entry; the merge only uses
    // it for the injected row, never over a user-supplied heading.
    var rootCatalog = root.menuCatalog.root
    var mergedMenu = MenuModel.mergeMenuSources(translatedDefaults, root.userMenuItems, rootCatalog && rootCatalog.label)
    root.providerRevision += 1
    root.providersLoaded = ({})
    root.providerQueue = []
    root.items = mergedMenu.items
    root.itemOrder = mergedMenu.itemOrder
    root.rowsLoaded = true
    if (!skipGuards && root.defaultMenuSettled && root.userMenuSettled) root.evaluateGuards()
    if (root.opened) {
      root.rebuildDisplay()
      if (!root.dmenuActive) {
        if (root.filterText.trim()) root.loadProvidersForSearch()
        else root.loadProviderForMenu(root.activeMenu)
      }
    }
  }

  // Each known provider is a tiny bash one-liner that enumerates a list and
  // emits one tab-delimited row per item: `label\tvalue\tcurrent`. The shell
  // turns those into menu items children of `menuId`. A `volatile` provider
  // re-runs every time its submenu is entered, so a font installed since the
  // shell started shows up without restarting it.
  readonly property var providers: ({
    "fonts": {
      script: "current=$(omarchy-font-current 2>/dev/null); omarchy-font-list 2>/dev/null | while read -r f; do [[ -z $f ]] && continue; printf '%s\\t%s\\t%s\\n' \"$f\" \"$f\" \"$current\"; done",
      icon: "",
      volatile: true,
      actionFor: function(value) { return "omarchy-font-set " + Util.shellQuote(value) }
    },
    "power-profiles": {
      script: "current=$(powerprofilesctl get 2>/dev/null); omarchy-powerprofiles-list 2>/dev/null | while read -r p; do [[ -z $p ]] && continue; printf '%s\\t%s\\t%s\\n' \"$p\" \"$p\" \"$current\"; done",
      icon: "\udb81\udc0b",
      // Profile names are powerprofilesctl ids; only the label is translated,
      // and the id stays searchable through searchTerms.
      labelFor: function(value) {
        if (value === "power-saver") return Commons.I18n.t("menu.powerProfilePowerSaver")
        if (value === "balanced") return Commons.I18n.t("menu.powerProfileBalanced")
        if (value === "performance") return Commons.I18n.t("menu.powerProfilePerformance")
        return value
      },
      actionFor: function(value) { return "omarchy-powerprofiles-set autodetect " + Util.shellQuote(value) }
    },
    // Kernel names are package names, the same in every language.
    "kernels": {
      script: "current=$(omarchy-kernel get 2>/dev/null); omarchy-kernel list 2>/dev/null | while read -r k; do [[ -z $k ]] && continue; printf '%s\\t%s\\t%s\\n' \"$k\" \"$k\" \"$current\"; done",
      icon: "\uf17c",
      volatile: true,
      actionFor: function(value) { return "omarchy-kernel set " + Util.shellQuote(value) }
    },
    // Rows carry a fourth field (the English name) so searching "danish"
    // finds the row labeled with its native name; mergeProviderRows turns
    // it into an alias.
    "languages": {
      script: "current=$(omarchy-language 2>/dev/null); omarchy-language list 2>/dev/null | while IFS=$'\\t' read -r name code english; do [[ -z $code ]] && continue; printf '%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$code\" \"$current\" \"$english\"; done",
      icon: "\uf1ab",
      volatile: true,
      actionFor: function(value) { return "omarchy-language " + Util.shellQuote(value) }
    }
  })

  function slugify(value) {
    return MenuModel.slugify(value)
  }

  // The apps provider is QML-native: rows come from the shared AppLibrary
  // (DesktopEntries) instead of a bash enumeration, so they carry image
  // icons, launch feedback, and uninstall support like the launcher.
  function mergeAppRows() {
    if (!root.appLibrary) return

    var rows = root.appLibrary.sortedEntries("")
    var appRows = []
    for (var j = 0; j < rows.length; j++) {
      var entry = rows[j].entry
      var appId = String(entry.id || "")
      if (!appId) continue
      var subtext = root.appLibrary.entrySubtext(entry)
      var aliases = subtext ? [subtext] : []
      try {
        if (entry.keywords && typeof entry.keywords.join === "function") aliases = aliases.concat(entry.keywords)
      } catch (e) { }
      appRows.push({
        id: "apps." + appId,
        parent: "apps",
        kind: "app",
        icon: "",
        appIcon: String(entry.icon || ""),
        appId: appId,
        label: root.appLibrary.entryName(entry),
        title: "",
        target: "",
        description: subtext,
        action: "",
        provider: "",
        aliases: aliases,
        searchTerms: [],
        when: "",
        checked: "",
        disabled: "",
        order: 0
      })
    }

    var merged = MenuModel.mergeAppRows(root.items, root.itemOrder, appRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return
    if (entry.provider === "apps") {
      root.providersLoaded[id] = true
      root.mergeAppRows()
      return
    }
    var spec = root.providers[entry.provider]
    if (!spec) return

    root.providersLoaded[id] = true
    providerProc.menuId = id
    providerProc.providerKey = entry.provider
    providerProc.revision = root.providerRevision
    providerProc.collected = ""
    providerProc.command = ["bash", "-lc", spec.script]
    providerProc.running = true
  }

  function mergeProviderRows(rows, menuId, providerKey) {
    var spec = root.providers[providerKey]
    if (!spec) return
    var lines = String(rows || "").split("\n")
    var providerRows = []
    var takenIds = ({})
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var parts = line.split("\t")
      var rawLabel = parts[0] || ""
      var label = spec.labelFor ? spec.labelFor(rawLabel) : rawLabel
      var value = parts[1] || parts[0] || ""
      var current = parts[2] || ""
      if (!label) continue
      // Distinct values can slugify alike — Fira Code and Fira-Code both give
      // fira-code — and a repeated id is dropped, which would silently lose a
      // row from the list. Nudge it until it is the row's own.
      var rowId = menuId + "." + root.slugify(value)
      while (takenIds[rowId]) rowId += "-"
      takenIds[rowId] = true

      providerRows.push({
        id: rowId,
        parent: menuId,
        kind: "action",
        icon: (value === current) ? "✓" : (spec.icon || ""),
        label: label,
        title: "",
        target: "",
        description: "",
        action: spec.actionFor(value),
        provider: "",
        aliases: [],
        searchTerms: (parts[3] ? [parts[3]] : []).concat(label !== rawLabel ? [rawLabel] : []),
        when: "",
        checked: "",
        disabled: "",
        order: 0
      })
    }
    var merged = MenuModel.swapProviderRows(root.items, root.itemOrder, menuId, providerRows)
    root.items = merged.items
    root.itemOrder = merged.itemOrder
    if (root.opened) root.rebuildDisplay()
  }

  function startNextProvider() {
    if (providerProc.running) return

    while (root.providerQueue.length > 0) {
      var id = root.providerQueue.shift()
      var entry = root.item(id)
      if (!entry || !entry.provider || root.providersLoaded[id]) continue

      root.startProviderForMenu(id)
      return
    }
  }

  // Entering a submenu is the one moment a volatile list is worth paying for
  // again: it may have been reshaped by the last pick from it. Search doesn't
  // invalidate, or every keystroke would restart the same enumeration.
  function invalidateVolatileProvider(id) {
    var entry = root.item(id)
    var spec = entry && entry.provider ? root.providers[entry.provider] : null
    if (spec && spec.volatile) root.providersLoaded[id] = false
  }

  function loadProviderForMenu(id) {
    var entry = root.item(id)
    if (!entry || !entry.provider || root.providersLoaded[id]) return

    // Native providers don't touch providerProc, so they never need to queue.
    if (entry.provider === "apps") {
      root.startProviderForMenu(id)
      return
    }

    if (providerProc.running) {
      if (root.providerQueue.indexOf(id) < 0) root.providerQueue = root.providerQueue.concat([id])
      return
    }

    root.startProviderForMenu(id)
  }

  function loadProvidersForSearch() {
    var active = root.item(root.activeMenu) ? root.activeMenu : "root"

    for (var i = 0; i < root.itemOrder.length; i++) {
      var entry = root.item(root.itemOrder[i])
      if (!entry || !entry.provider || root.providersLoaded[entry.id]) continue
      if (active !== "root" && entry.id !== active && !root.isDescendantOf(entry.id, active)) continue

      root.loadProviderForMenu(entry.id)
    }
  }

  function depthFor(id) {
    return MenuModel.depthFor(root.items, id)
  }

  function pathFor(id) {
    return MenuModel.pathFor(root.items, id)
  }

  function parentPathFor(id) {
    return MenuModel.parentPathFor(root.items, id)
  }

  function isDescendantOf(id, ancestorId) {
    return MenuModel.isDescendantOf(root.items, id, ancestorId)
  }

  function childCount(id) {
    return MenuModel.childCount(root.items, root.itemOrder, id)
  }

  // Guarded items are hidden when their `when:` evaluates false. Static
  // submenus are also hidden when none of their descendants are visible;
  // provider-backed menus stay visible because their rows load on demand.
  function isVisible(entry) {
    return MenuModel.isVisible(root.items, root.itemOrder, root.whenResults, entry)
  }

  // Label with the ✓ marker baked in when `checked:` or `disabled:` evaluated
  // truthy.
  function labelFor(entry) {
    return MenuModel.labelFor(entry, root.checkedResults, root.disabledResults)
  }

  function searchableToken(value) {
    return MenuModel.searchableToken(value)
  }

  function leafIdFor(id) {
    return MenuModel.leafIdFor(id)
  }

  function nameSearchText(entry) {
    return MenuModel.nameSearchText(entry)
  }

  function termInSearchWords(term, text) {
    return MenuModel.termInSearchWords(term, text)
  }

  function descriptionTextMatches(query, text) {
    return MenuModel.descriptionTextMatches(query, text)
  }

  // Rows whose `disabled:` evaluated truthy stay listed but dimmed, and the
  // cursor steps over them.
  function isDisabled(entry) {
    return MenuModel.isDisabled(root.disabledResults, entry)
  }

  // A disabled row earns its place in the submenu it belongs to, where the
  // list around it is the point. Search is a list of what you can do, so it
  // leaves them out.
  function matchesQuery(entry, query) {
    return MenuModel.matchesQuery(entry, query, root.isVisible(entry) && !root.isDisabled(entry))
  }

  function searchScore(entry, query) {
    return MenuModel.searchScore(root.items, entry, query)
  }

  function displayRow(entry, detail, score, section) {
    return MenuModel.displayRow(root.items, root.itemOrder, root.checkedResults, root.disabledResults, entry, detail, score, section)
  }

  function rowSelectable(index) {
    if (index < 0 || index >= displayModel.count) return false
    return !displayModel.get(index).disabled
  }

  // First selectable row at or past `from`, continuing in the direction of
  // travel and wrapping. -1 when every row is disabled, which leaves the menu
  // with no cursor at all rather than one parked on a row Enter won't run.
  function nextSelectable(from, direction) {
    var count = displayModel.count
    if (count === 0) return -1

    var step = direction < 0 ? -1 : 1
    var index = ((from % count) + count) % count
    for (var i = 0; i < count; i++) {
      if (root.rowSelectable(index)) return index
      index = (index + step + count) % count
    }

    return -1
  }

  // Park the cursor on a selectable row after the rows underneath it changed.
  // A menu with nothing selectable in it -- every app in it already installed
  // -- shows no cursor at all, and grows one the moment a row can take it.
  function settleCursor() {
    var target = root.nextSelectable(root.selectedIndex, 1)
    root.selectedIndex = target >= 0 ? target : 0
    root.cursorActive = target >= 0
  }

  function rebuildDmenuDisplay() {
    displayModel.clear()
    root.searchDivider = false

    if (root.mode === "input") {
      layoutSerial += 1
      return
    }

    if (root.dmenuMultiple && root.dmenuOnChange.length === 0) {
      displayModel.append({
        itemId: "dmenu.apply", disabled: false, kind: "dmenu", icon: "", iconFont: "",
        appIcon: "", appId: "", label: Commons.I18n.t("common.apply"), target: "",
        detail: Commons.I18n.tn("menu.selectedCount", root.dmenuSelected.length).arg(Commons.I18n.formatNumber(root.dmenuSelected.length)), path: "", childCount: 0,
        action: "", provider: "", score: -1, section: ""
      })
    }
    var query = root.filterText.trim().toLowerCase()
    for (var i = 0; i < root.dmenuOptions.length; i++) {
      // An option is "<label>", "<glyph>\t<label>", or
      // "<glyph>\t<label>\t<subtext>". The glyph never comes back with the
      // selection; the subtext renders under the label, filters alongside it,
      // and returns with the selection as a stable key for same-named rows.
      var parts = String(root.dmenuOptions[i] || "").split("\t")
      var icon = parts.length > 1 ? parts.shift() : ""
      var label = parts.shift() || ""
      var detail = parts.join("\t")
      if (query && label.toLowerCase().indexOf(query) < 0
          && detail.toLowerCase().indexOf(query) < 0) continue
      displayModel.append({
        itemId: "dmenu." + i,
        disabled: false,
        kind: "dmenu",
        icon: root.dmenuMultiple ? (root.dmenuSelected.indexOf(MenuModel.dmenuValue(root.dmenuOptions[i])) !== -1 ? "✓" : "○") : icon,
        iconFont: "",
        appIcon: "",
        appId: "",
        label: label,
        target: "",
        detail: detail,
        path: "",
        childCount: 0,
        action: "",
        provider: "",
        score: i,
        section: ""
      })
    }

    layoutSerial += 1

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  function updateDmenuChecks() {
    for (var i = 0; i < displayModel.count; i++) {
      var row = displayModel.get(i)
      if (row.itemId === "dmenu.apply") {
        displayModel.setProperty(i, "detail", Commons.I18n.tn("menu.selectedCount", root.dmenuSelected.length).arg(Commons.I18n.formatNumber(root.dmenuSelected.length)))
      } else if (row.kind === "dmenu") {
        var value = MenuModel.dmenuValue(root.dmenuOptions[Number(row.itemId.substring(6))])
        displayModel.setProperty(i, "icon", root.dmenuSelected.indexOf(value) !== -1 ? "✓" : "○")
      }
    }
  }

  function rebuildDisplay() {
    if (root.dmenuActive) {
      root.rebuildDmenuDisplay()
      return
    }

    displayModel.clear()

    if (!root.rowsLoaded) return

    var active = root.item(root.activeMenu) ? root.activeMenu : "root"
    root.activeMenu = active
    var rows = []
    var query = root.filterText.trim()
    root.searchDivider = false
    var calc = ""

    if (query) {
      var currentRows = []
      var drilldownRows = []

      for (var i = 0; i < root.itemOrder.length; i++) {
        var entry = root.item(root.itemOrder[i])
        if (!entry || entry.id === "root") continue
        if (!root.isDescendantOf(entry.id, active)) continue
        if (!root.matchesQuery(entry, query)) continue

        var detail = root.parentPathFor(entry.id)
        var row = root.displayRow(entry, detail, root.searchScore(entry, query))
        if (entry.parent === active) currentRows.push(row)
        else drilldownRows.push(row)
      }

      var searchSort = function(a, b) {
        if (a.score !== b.score) return a.score - b.score
        return a.path.localeCompare(b.path)
      }

      currentRows.sort(searchSort)
      drilldownRows.sort(searchSort)
      root.searchDivider = currentRows.length > 0 && drilldownRows.length > 0
      if (root.searchDivider) {
        for (var d = 0; d < drilldownRows.length; d++) drilldownRows[d].section = "drilldown"
      }
      rows = currentRows.concat(drilldownRows)
      var appRows = rows.filter(function(r) { return r.kind === "app" })
      for (var a = 0; a < appRows.length; a++) appRows[a].section = ""
      rows = appRows.concat(rows.filter(function(r) { return r.kind !== "app" }))
      root.searchDivider = rows.some(function(r) { return r.section === "drilldown" })
      calc = active === "root" ? Calculator.evaluate(query) : ""
    } else {
      for (var j = 0; j < root.itemOrder.length; j++) {
        var child = root.item(root.itemOrder[j])
        if (!child || child.parent !== active) continue
        if (!root.isVisible(child)) continue
        rows.push(root.displayRow(child, child.description, child.order))
      }

      // DesktopEntries can reorder its values when an application starts.
      // Keep the Apps menu alphabetical independently of provider refreshes.
      if (active === "apps") {
        rows.sort(function(a, b) {
          var aLabel = String(a.label || "").toLowerCase()
          var bLabel = String(b.label || "").toLowerCase()
          if (aLabel < bLabel) return -1
          if (aLabel > bLabel) return 1
          var aId = String(a.itemId || "")
          var bId = String(b.itemId || "")
          if (aId < bId) return -1
          if (aId > bId) return 1
          return 0
        })
      }
    }

    root.calcResult = calc
    if (!calc) root.calcFocused = false
    for (var k = 0; k < rows.length; k++) displayModel.append(rows[k])
    layoutSerial += 1

    root.settleCursor()

    Qt.callLater(function() {
      if (displayModel.count > 0) root.revealCursor()
    })
  }

  // Contain alone parks the cursor row flush with the viewport edge, hiding
  // the neighbor entirely and losing the fold affordance. Keep the next
  // hidden row peeking past the cursor in the direction of travel.
  function revealCursor() {
    if (displayModel.count === 0) return
    if (root.gridActive) {
      appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
      return
    }
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)

    var item = resultList.itemAtIndex(root.selectedIndex)
    if (!item) return

    var reach = root.rowPeek + root.rowSpacing
    if (root.selectedIndex < displayModel.count - 1) {
      var maxY = Math.max(resultList.originY, resultList.originY + resultList.contentHeight - resultList.height)
      var overhang = item.y + item.height + reach - (resultList.contentY + resultList.height)
      if (overhang > 0) resultList.contentY = Math.min(resultList.contentY + overhang, maxY)
    }
    if (root.selectedIndex > 0) {
      var underhang = resultList.contentY - (item.y - reach)
      if (underhang > 0) resultList.contentY = Math.max(resultList.contentY - underhang, resultList.originY)
    }
  }

  function select(delta) {
    if (root.calcFocused && delta < 0) return
    if (!root.calcFocused && root.calcResult && root.cursorActive && root.selectedIndex + delta < 0) {
      root.calcFocused = true
      return
    }
    if (displayModel.count === 0) return

    root.disarmPointer()
    if (root.calcFocused) {
      root.calcFocused = false
      delta = 1
      root.cursorActive = false
    }
    var from = cursorActive ? selectedIndex + delta : (delta < 0 ? displayModel.count - 1 : 0)
    var target = root.nextSelectable(from, delta)
    if (target < 0) return

    cursorActive = true
    selectedIndex = target
    revealCursor()
  }

  function moveInGrid(delta) {
    var target = root.selectedIndex + delta
    if (target < 0 || target >= displayModel.count) return
    root.disarmPointer()
    root.cursorActive = true
    root.selectedIndex = target
    root.revealCursor()
  }

  function setFilter(nextFilter) {
    panel.freezeCardTop()
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = root.mode !== "input"
    root.disarmPointer()
    if (!root.dmenuActive && root.filterText.trim()) root.loadProvidersForSearch()
    root.rebuildDisplay()
    root.calcFocused = root.calcResult !== ""
  }

  function setActiveMenu(id, pushHistory, fromPointer) {
    panel.freezeCardTop()
    if (!root.item(id)) id = "root"
    if (pushHistory && id !== root.activeMenu) root.navStack = root.navStack.concat([root.activeMenu])
    root.activeMenu = id
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    if (fromPointer) pointerGate.allowInitialSample()
    else root.disarmPointer()
    root.rebuildDisplay()
    root.invalidateVolatileProvider(id)
    root.loadProviderForMenu(id)
  }

  function goBack() {
    if (root.activeMenu === "root") return false

    if (root.navStack.length > 0) {
      var previous = root.navStack[root.navStack.length - 1]
      root.navStack = root.navStack.slice(0, root.navStack.length - 1)
      root.setActiveMenu(previous, false)
      return true
    }

    var active = root.item(root.activeMenu)
    root.setActiveMenu((active && active.parent) ? active.parent : "root", false)
    return true
  }

  function activateIndex(index, fromPointer) {
    if (root.deleteConfirmOpen) return
    if (root.dmenuActive) {
      if (root.mode === "input") {
        root.applyDmenuSelection(root.filterText)
        return
      }
      if (index < 0 || index >= displayModel.count) return
      var picked = displayModel.get(index)
      if (root.dmenuMultiple) {
        if (picked.itemId === "dmenu.apply") {
          root.applyDmenuSelection(JSON.stringify(MenuModel.dmenuSelections(root.dmenuOptions, root.dmenuSelected)))
        } else {
          var value = MenuModel.dmenuValue(root.dmenuOptions[Number(picked.itemId.substring(6))])
          var selected = MenuModel.toggleDmenuSelection(selectionProc.requestedSelection(), value)
          if (root.dmenuOnChange.length > 0) {
            selectionProc.enqueue(selected)
          } else {
            root.dmenuSelected = selected
            root.updateDmenuChecks()
          }
        }
      } else {
        root.applyDmenuSelection(picked.detail ? picked.label + "\t" + picked.detail : picked.label)
      }
      return
    }

    if (!root.rowSelectable(index)) return

    var row = displayModel.get(index)
    if (row.kind === "menu" || row.kind === "link") {
      root.setActiveMenu(row.target || row.itemId, true, fromPointer)
    } else if (row.kind === "app") {
      var appId = row.appId
      var label = row.label
      applySerial = requestSerial
      opened = false
      filterText = ""
      if (root.appLibrary) root.appLibrary.launch(appId, label)
    } else {
      root.applySelected(row.itemId, row.action)
    }
  }

  function copyCalc() {
    var result = root.calcResult
    root.applySerial = root.requestSerial
    root.opened = false
    root.filterText = ""
    Util.execArgv(["wl-copy", "--", result])
  }

  function requestDeleteSelected() {
    if (!root.cursorActive || root.selectedIndex < 0 || root.selectedIndex >= displayModel.count) return
    var row = displayModel.get(root.selectedIndex)
    if (!row || row.kind !== "app") return
    root.deleteTarget = { appId: row.appId, label: row.label }
    deleteConfirm.selectedIndex = 1
    root.deleteConfirmOpen = true
  }

  function cancelDelete() {
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    deleteConfirm.selectedIndex = 1
    root.disarmPointer()
    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }

  function confirmDelete() {
    var target = root.deleteTarget
    root.deleteConfirmOpen = false
    root.deleteTarget = null
    if (!target) return
    root.cancel()
    if (root.appLibrary) root.appLibrary.remove(target.appId, target.label)
  }

  function applyDmenuSelection(value) {
    applySerial = requestSerial
    opened = false
    filterText = ""
    root.finishRequest(value)
  }

  function applySelected(id, action) {
    if (!id) { cancel(); return }

    applySerial = requestSerial
    opened = false
    filterText = ""
    root.runAction(action)
  }

  function cancel() {
    if (root.dmenuActive) root.finishRequest(null)
    opened = false
    filterText = ""
  }

  function openExistingMenu(initialMenu) {
    requestSerial += 1
    mode = "menu"
    requestActive = false
    selectionFile = ""
    doneFile = ""
    activeMenu = root.item(initialMenu) ? initialMenu : "root"
    navStack = []
    filterText = ""
    selectedIndex = 0
    cursorActive = true
    root.disarmPointer()
    root.evaluateGuards()
    opened = true
    rebuildDisplay()
    invalidateVolatileProvider(activeMenu)
    loadProviderForMenu(activeMenu)
    // The shell may start before first-install packages have finished placing
    // their icons. Refresh here even when the desktop entry list did not change.
    if (root.appLibrary) root.appLibrary.refreshIcons()

    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }

  function openDmenu(payload) {
    requestSerial += 1
    mode = payload.mode === "input" ? "input" : "select"
    dmenuPrompt = String(payload.prompt || (mode === "input" ? Commons.I18n.t("menu.inputPrompt") : Commons.I18n.t("menu.selectPrompt")))
    dmenuOptions = Array.isArray(payload.options) ? payload.options : []
    dmenuMultiple = mode === "select" && payload.multiple === true
    dmenuOnChange = dmenuMultiple && Array.isArray(payload.onChange)
      && payload.onChange.every(function(arg) { return typeof arg === "string" }) ? payload.onChange : []
    dmenuChangeKey = String(payload.changeKey || JSON.stringify(dmenuOnChange))
    dmenuSelected = MenuModel.dmenuSelections(dmenuOptions, Array.isArray(payload.selected) ? payload.selected : [], dmenuOnChange.length > 0)
    dmenuSaved = dmenuSelected
    if (dmenuOnChange.length > 0)
      dmenuSelected = MenuModel.dmenuSelections(dmenuOptions, selectionProc.requestedSelection(), true)
    selectionFile = String(payload.selectionFile || "")
    doneFile = String(payload.doneFile || "")
    requestActive = !!doneFile
    dmenuWidth = Math.max(1, Number(payload.width || 300))
    dmenuMaxHeight = Math.max(0, Number(payload.maxHeight || 0))
    activeMenu = "root"
    navStack = []
    filterText = ""
    calcResult = ""
    calcFocused = false
    selectedIndex = 0
    cursorActive = mode !== "input"
    root.disarmPointer()
    opened = true
    rebuildDisplay()

    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }
  ListModel { id: displayModel }

  // ----------------------------------------------------------- route surface
  //
  // The menu is opened through the standard plugin lifecycle:
  // `omarchy-shell shell summon omarchy.menu '{"menu":"system"}'`.
  // Callers may pass a real id (`system`, `setup.power`) or an alias declared
  // in JSONC (`power`, `reminder-set`). Unknown strings fall through to the
  // id-as-route behavior so misspellings still attempt to open the literal id.
  function resolveRoute(input) {
    return MenuModel.resolveRoute(root.items, root.itemOrder, input)
  }

  function openRoute(initialMenu) {
    var id = root.resolveRoute(initialMenu)
    var entry = root.items[id]
    // If the resolved id is an action (i.e. the user invoked an alias for
    // a leaf, e.g. `omarchy menu summon screenrecord-stop`), run it directly
    // instead of opening an action with no children.
    if (entry && entry.kind === "action" && entry.action) {
      root.cancel()
      root.runAction(entry.action)
      return "ok"
    }
    // If it's a link (a redirect to another menu), follow the link.
    if (entry && entry.kind === "link" && entry.target) id = entry.target
    root.pendingInitialMenu = id
    root.openExistingMenu(id)
    return "ok"
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    if (!root.rowSelectable(index)) return
    root.calcFocused = false
    root.cursorActive = true
    root.selectedIndex = index
  }

  Process {
    id: providerProc
    property string menuId: ""
    property string providerKey: ""
    property string collected: ""
    property int revision: 0
    stdout: SplitParser {
      onRead: function(data) { providerProc.collected += data + "\n" }
    }
    onExited: {
      if (providerProc.revision === root.providerRevision) {
        root.mergeProviderRows(providerProc.collected, providerProc.menuId, providerProc.providerKey)
        if (root.filterText.trim()) root.loadProvidersForSearch()
      }
      root.startNextProvider()
    }
  }

  Process {
    id: selectionProc
    property int serial: 0
    property string changeKey: ""
    property var selected: []
    property var queue: []
    property string collected: ""

    function requestedSelection() {
      for (var i = queue.length - 1; i >= 0; i--) {
        if (queue[i].key === root.dmenuChangeKey) return queue[i].selected
      }
      if (running && changeKey === root.dmenuChangeKey) return selected
      return root.dmenuSelected
    }

    function enqueue(values) {
      var selected = MenuModel.dmenuSelections(root.dmenuOptions, values, true)
      queue = queue.concat([{
        serial: root.requestSerial, key: root.dmenuChangeKey, selected: selected,
        command: root.dmenuOnChange.concat([JSON.stringify(selected)])
      }])
      if (!running) startNext()
    }

    function startNext() {
      if (queue.length === 0) return
      var change = queue[0]
      queue = queue.slice(1)
      serial = change.serial
      changeKey = change.key
      selected = change.selected
      collected = ""
      command = change.command
      running = true
    }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: selectionProc.collected = text
    }
    onExited: function(exitCode) {
      if (changeKey === root.dmenuChangeKey && root.dmenuActive && root.dmenuOnChange.length > 0) {
        if (exitCode === 0) {
          var applied = selected
          if (collected.trim()) {
            try { applied = JSON.parse(collected) } catch (error) { applied = root.dmenuSelected }
          }
          if (Array.isArray(applied))
            root.dmenuSelected = MenuModel.dmenuSelections(root.dmenuOptions, applied, true)
          root.dmenuSaved = root.dmenuSelected
        } else {
          root.dmenuSelected = root.dmenuSaved
        }
        root.updateDmenuChecks()
      }
      startNext()
    }
  }

  Process {
    id: resultProc
    onExited: {
      if (root.applySerial === root.requestSerial)
        root.opened = false
    }
  }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.providersLoaded["apps"]) root.mergeAppRows()
    }
  }

  // The JSONC sources are watched so live edits to the default file (or the
  // user extension at ~/.config/omarchy/extensions/omarchy-menu.jsonc) take
  // effect without restarting the shell.
  FileView {
    id: defaultMenuFile
    path: root.defaultMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.defaultMenuItems = MenuModel.keepMenuRows(root.defaultMenuItems, text(), true); root.defaultMenuSettled = true; root.rebuildItemsFromSources() }
    // A user file that loaded first held its evaluation for this one.
    onLoadFailed: { root.defaultMenuSettled = true; if (root.userMenuSettled) root.evaluateGuards() }
    onFileChanged: reload()
  }

  FileView {
    id: userMenuFile
    path: root.userMenuPath
    watchChanges: true
    printErrors: false
    onLoaded: { root.userMenuItems = MenuModel.keepMenuRows(root.userMenuItems, text(), false); root.userMenuSettled = true; root.rebuildItemsFromSources() }
    onLoadFailed: { root.userMenuItems = []; root.userMenuSettled = true; root.rebuildItemsFromSources() }
    onFileChanged: reload()
  }

  // The language choice and its catalog are watched the same way, so
  // picking a language under Setup retitles the menu with no shell restart.
  FileView {
    id: languageFile
    path: root.languagePath
    watchChanges: true
    printErrors: false
    onLoaded: root.setLanguage(text())
    onLoadFailed: root.setLanguage("")
    onFileChanged: reload()
  }

  FileView {
    id: menuCatalogFile
    path: root.omarchyPath + "/default/i18n/" + root.language + "/menu.json"
    watchChanges: true
    printErrors: false
    onLoaded: { root.menuCatalog = root.parseCatalog(text()); root.rebuildItemsFromSources(true) }
    onLoadFailed: { root.menuCatalog = ({}); root.rebuildItemsFromSources(true) }
    onFileChanged: reload()
  }

  // ---------------------------------------------------------------- guards
  //
  // `when:` (visibility) and `checked:` (✓ marker) are bash expressions the
  // shell wasn't allowed to evaluate before the perf rewrite. Now the shell
  // batches them into one bash subprocess per (re)load so the open path
  // never has to wait on them.

  property var whenResults: ({})       // id → true|false (allow visibility)
  property var checkedResults: ({})    // id → true|false (show ✓)
  property var disabledResults: ({})   // id → true|false (dim, skip cursor)
  property bool guardsPending: false

  function evaluateGuards() {
    // Process ignores a command change while it is running, and `collected`
    // belongs to the run in flight, so a second evaluation cannot overwrite
    // the first: it would throw away the lines already read and never start.
    // The surviving tail then lands as the whole answer, and every id lost
    // with it goes back to showing, since a `when:` only hides on an explicit
    // false. Wait for the run in flight and evaluate once it lands instead.
    if (guardProc.running) {
      root.guardsPending = true
      return
    }
    root.guardsPending = false

    var script = MenuModel.guardScript(root.items)
    if (!script) {
      root.whenResults = ({})
      root.checkedResults = ({})
      root.disabledResults = ({})
      return
    }
    guardProc.collected = ""
    guardProc.command = ["bash", "-lc", script]
    guardProc.running = true
  }

  Process {
    id: guardProc
    property string collected: ""
    stdout: SplitParser {
      onRead: function(data) { guardProc.collected += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      // A batch that was killed rather than finished has only told us about
      // the rows it reached, and a row whose `when:` went unanswered shows.
      // Keep the last complete set rather than let a half-read one through.
      // A signal leaves the exit code at 0, so the status is what tells us.
      if (exitCode !== 0 || exitStatus !== 0) {
        if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
        return
      }

      var nextWhen = ({})
      var nextChecked = ({})
      var nextDisabled = ({})
      var lines = guardProc.collected.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line) continue
        var colon = line.lastIndexOf(":")
        if (colon < 0) continue
        var value = line.substring(colon + 1) === "1"
        var rest = line.substring(0, colon)
        var tagAt = rest.lastIndexOf(":")
        if (tagAt < 0) continue
        var id = rest.substring(0, tagAt)
        var tag = rest.substring(tagAt + 1)
        if (tag === "w") nextWhen[id] = value
        else if (tag === "c") nextChecked[id] = value
        else if (tag === "d") nextDisabled[id] = value
      }
      root.whenResults = nextWhen
      root.checkedResults = nextChecked
      root.disabledResults = nextDisabled
      if (root.opened) root.rebuildDisplay()
      // Run the evaluation that had to stand aside. Deferred by a turn so the
      // process is settled before its command is set again.
      if (root.guardsPending) Qt.callLater(function() { root.evaluateGuards() })
    }
  }
  OverlayWindow {
    id: panel
    shown: root.opened && root.rowsLoaded
    WlrLayershell.namespace: "omarchy-menu"

    // The card opens centered exactly as always. The first search keystroke
    // or submenu move freezes the top line where it currently sits — from
    // then on the card grows and shrinks downward instead of re-centering
    // on every resize, which made the menu jump around. The rows height is
    // frozen at the same moment, so the starting menu also caps how tall the
    // card may grow from there. Closing or changing screens unfreezes both.
    property int cardTop: -1
    property int maxRowsHeight: -1
    readonly property int centeredTop: root.dmenuActive ? Math.max(Style.gapsOut, Math.round((height - root.cardHeight) / 2)) : Math.max(Style.gapsOut, Math.round(height * 0.2))
    readonly property int effectiveCardTop: cardTop >= 0 ? cardTop : centeredTop
    function freezeCardTop() {
      if (shown && cardTop < 0) {
        cardTop = effectiveCardTop
        maxRowsHeight = root.visibleRowsHeight
      }
    }
    onShownChanged: if (!shown) { cardTop = -1; maxRowsHeight = -1 }
    onTargetScreenChanged: { cardTop = -1; maxRowsHeight = -1 }


    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.cancel()
    }

    Item {
      id: card
      width: root.cardWidth
      height: Math.min(root.cardHeight, panel.height - Style.gapsOut - panel.effectiveCardTop)
      anchors.horizontalCenter: parent.horizontalCenter
      y: panel.effectiveCardTop

      Squircle {
        anchors.fill: parent
        radius: root.cornerRadius
        power: root.cornerPower
        color: root.background
        borderColor: root.border
      }

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.deleteConfirmOpen ? 20 : 0

        // Focus is on filterInput, which forwards every key here first.
        Keys.onPressed: function(event) {
          if (root.deleteConfirmOpen) {
            // Swallow the rest too, or it would type into the search line behind the dialog.
            deleteConfirm.handleKey(event)
            event.accepted = true
            return
          }

          if (!root.dmenuActive && (event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            root.applyFilter(event.key - Qt.Key_1)
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            root.requestDeleteSelected()
            event.accepted = true
          } else if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.cancel()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (root.gridActive && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            root.moveInGrid((Util.readingKey(event) === Qt.Key_Left) ? -1 : 1)
            event.accepted = true
          } else if (root.gridActive && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            root.moveInGrid(event.key === Qt.Key_Up ? -root.gridColumns : root.gridColumns)
            event.accepted = true
          } else if ((event.key === Qt.Key_Backspace || Util.readingKey(event) === Qt.Key_Left) && !root.filterText) {
            root.goBack()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || Util.readingKey(event) === Qt.Key_Right) {
            if (root.dmenuActive) {
              if (root.mode === "input") root.applyDmenuSelection(root.filterText)
              else if (displayModel.count > 0) root.activateIndex(root.cursorActive ? root.selectedIndex : 0)
            } else if (root.calcFocused) root.copyCalc()
            else if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else root.settleCursor()
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: deleteConfirm

          anchors.fill: parent
          opened: root.deleteConfirmOpen
          z: 10
          message: Commons.I18n.t("common.uninstallConfirm").arg((root.deleteTarget && root.deleteTarget.label) || "")
          confirmText: Commons.I18n.t("common.uninstall")
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelDelete()
          onConfirmed: root.confirmDelete()
        }
      }

      Column {
        anchors.fill: parent
        spacing: 0

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            id: searchGlyph
            textFormat: Text.PlainText
            text: ""
            color: root.foreground
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: root.dmenuActive ? Style.font.heading : root.px(22)
            anchors.left: parent.left
            anchors.leftMargin: root.dmenuActive ? Style.space(18) : root.px(16)
            anchors.verticalCenter: parent.verticalCenter
          }

          Rectangle {
            id: chip
            readonly property var entry: root.item(root.activeMenu)
            visible: !root.dmenuActive && root.activeMenu !== "root" && !!entry
            width: visible ? chipRow.implicitWidth + Style.space(16) : 0
            height: root.dmenuActive ? Style.space(26) : root.px(28)
            radius: root.dmenuActive ? 7 : height / 2
            color: Util.alpha(root.foreground, 0.1)
            anchors.left: searchGlyph.right
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: chipRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                visible: text.length > 0
                text: chip.entry ? chip.entry.icon : ""
                color: root.foreground
                font.family: chip.entry && chip.entry.iconFont ? chip.entry.iconFont : root.fontFamily
                font.pixelSize: root.px(15)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: chip.entry ? (chip.entry.title || chip.entry.label) : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.px(15)
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          FilterInput {
            id: filterInput
            anchors.left: chip.visible ? chip.right : searchGlyph.right
            anchors.leftMargin: Style.space(10)
            anchors.right: fieldIcon.visible ? fieldIcon.left : parent.right
            anchors.rightMargin: root.dmenuActive ? Style.space(18) : root.px(16)
            anchors.verticalCenter: parent.verticalCenter
            keyHandler: keyCatcher
            // Input-method commits bypass key handling, so the dialog has to refuse them here.
            readOnly: root.deleteConfirmOpen
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.dmenuActive ? Math.round(Style.font.heading * 1.375) : root.px(26)
            onTextChanged: if (text !== root.filterText) root.setFilter(text)
          }

          Rectangle {
            readonly property real room: fieldIcon.x - x - root.px(8)
            visible: !root.dmenuActive && !root.calcResult && !!root.currentRow && root.filterText.length > 0 && width <= room
            x: filterInput.x + filterInput.contentWidth + root.px(8)
            anchors.verticalCenter: parent.verticalCenter
            width: openHint.implicitWidth + root.px(16)
            height: root.px(26)
            radius: height / 2
            color: Util.alpha(root.foreground, 0.08)

            Text {
              id: openHint
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "— " + root.verbFor(root.currentRow)
              color: root.foreground
              opacity: 0.55
              font.family: root.fontFamily
              font.pixelSize: root.px(15)
            }
          }

          Text {
            visible: !root.dmenuActive && !!root.calcResult
            x: filterInput.x + filterInput.contentWidth + root.px(14)
            width: Math.max(0, fieldIcon.x - x - root.px(8))
            anchors.verticalCenter: filterInput.verticalCenter
            textFormat: Text.PlainText
            text: "= " + root.calcResult
            color: root.foreground
            opacity: 0.45
            font.family: root.fontFamily
            font.pixelSize: filterInput.font.pixelSize
            elide: Text.ElideRight
          }

          Item {
            id: fieldIcon
            visible: !root.dmenuActive && root.filterText.length > 0 && (!!root.calcResult || !!root.currentRow)
            width: root.px(26)
            height: width
            anchors.right: parent.right
            anchors.rightMargin: root.px(16)
            anchors.verticalCenter: parent.verticalCenter

            Image {
              anchors.fill: parent
              visible: !root.calcResult && !!root.currentRow && root.currentRow.kind === "app"
              fillMode: Image.PreserveAspectFit
              sourceSize.width: width * Screen.devicePixelRatio
              sourceSize.height: height * Screen.devicePixelRatio
              source: visible && root.appLibrary ? root.appLibrary.iconSource(root.currentRow.appIcon) : ""
              asynchronous: true
            }

            Text {
              anchors.centerIn: parent
              visible: !!root.calcResult || (!!root.currentRow && root.currentRow.kind !== "app")
              textFormat: Text.PlainText
              text: root.calcResult ? "󰃬" : (root.currentRow ? root.currentRow.icon : "")
              color: root.foreground
              opacity: 0.55
              font.family: !root.calcResult && root.currentRow && root.currentRow.iconFont ? root.currentRow.iconFont : root.fontFamily
              font.pixelSize: root.px(22)
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: filterInput
            verticalAlignment: Text.AlignVCenter
            visible: !root.filterText && !filterInput.preeditText
            text: root.dmenuActive ? (root.dmenuPrompt + "…") : Commons.I18n.t("common.search")
            color: root.foreground
            opacity: 0.4
            font.family: root.fontFamily
            font.pixelSize: filterInput.font.pixelSize
            elide: Text.ElideRight
          }
        }

        Rectangle {
          x: root.dmenuActive ? 0 : root.px(16)
          width: parent.width - x * 2
          height: 1
          color: root.border
        }

        Item {
          width: parent.width
          height: root.calcAreaHeight
          visible: height > 0

          Rectangle {
            x: root.contentMargin
            y: root.contentMargin
            width: parent.width - root.contentMargin * 2
            height: root.calcCardHeight
            radius: root.px(15)
            color: Util.alpha(root.foreground, root.lightCard ? 0.04 : 0.06)
            border.width: 1
            border.color: Util.alpha(root.foreground, root.lightCard ? 0.1 : 0.12)

            Column {
              anchors.left: parent.left
              anchors.leftMargin: root.px(14)
              anchors.right: copyButton.left
              anchors.rightMargin: root.px(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: root.px(1)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.filterText.trim() + " ="
                color: root.foreground
                opacity: 0.55
                font.family: root.fontFamily
                font.pixelSize: root.px(13)
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.calcResult
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.px(18)
                font.weight: Font.Medium
                elide: Text.ElideRight
              }
            }

            Rectangle {
              id: copyButton
              width: root.px(32)
              height: width
              radius: width / 2
              anchors.right: parent.right
              anchors.rightMargin: root.px(14)
              anchors.verticalCenter: parent.verticalCenter
              color: Util.alpha(root.foreground, copyMouse.containsMouse ? 0.14 : 0.08)

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "󰆏"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.px(16)
              }

              MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyCalc()
              }
            }
          }
        }

        Item {
          width: parent.width
          height: root.filterBarHeight
          visible: !root.dmenuActive
          z: 2

          Row {
            id: filterRow
            anchors.left: parent.left
            anchors.leftMargin: root.px(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.px(8)

            Repeater {
              model: root.filters

              delegate: Rectangle {
                id: filterButton
                required property var modelData
                required property int index
                readonly property bool active: root.activeFilter === modelData.id

                width: root.px(32)
                height: width
                radius: width / 2
                color: active ? root.selectedBackground : Util.alpha(root.foreground, filterMouse.containsMouse ? 0.16 : 0.08)

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: filterButton.modelData.icon
                  color: filterButton.active ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.px(16)
                }

                MouseArea {
                  id: filterMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.applyFilter(filterButton.index)
                }

                Rectangle {
                  visible: filterMouse.containsMouse
                  anchors.top: parent.bottom
                  anchors.topMargin: root.px(6)
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: tipText.implicitWidth + root.px(16)
                  height: tipText.implicitHeight + root.px(8)
                  radius: root.px(6)
                  color: root.background
                  border.width: 1
                  border.color: root.border

                  Text {
                    id: tipText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: filterButton.modelData.label + " ⌃" + (filterButton.index + 1)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: root.px(13)
                  }
                }
              }
            }
          }

          Text {
            readonly property int shown: {
              for (var i = 0; i < root.filters.length; i++)
                if (root.filters[i].id === root.activeFilter) return i
              return -1
            }
            textFormat: Text.PlainText
            visible: shown >= 0 && shown < root.filters.length
            text: visible ? root.filters[shown].label + "  ⌃" + (shown + 1) : ""
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: root.px(15)
            anchors.left: filterRow.right
            anchors.leftMargin: root.px(12)
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Item {
          width: parent.width
          height: root.mode === "input" ? 0 : root.visibleRowsHeight + root.contentMargin * 2
          visible: root.mode !== "input"

          Item {
            anchors.fill: parent
            anchors.margins: root.contentMargin

            ListView {
              id: resultList
              anchors.fill: parent
              visible: !root.gridActive
              model: root.gridActive ? null : displayModel
              clip: true
              spacing: root.rowSpacing
              boundsBehavior: Flickable.StopAtBounds

              WheelHandler {
                target: null
                onWheel: function(event) {
                  var delta = event.pixelDelta.y || event.angleDelta.y / 120 * root.rowHeightForDetail("") * 3
                  var bottom = resultList.originY + Math.max(0, resultList.contentHeight - resultList.height)
                  resultList.contentY = Math.max(resultList.originY, Math.min(bottom, resultList.contentY - delta))
                  event.accepted = true
                }
              }

              section.property: "section"
              section.criteria: ViewSection.FullString
              section.delegate: Item {
                required property string section

                width: ListView.view.width
                height: section === "drilldown" ? root.dividerHeight : 0
                visible: section === "drilldown"

                Rectangle {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(4)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.spacing.hairline
                  color: Util.alpha(root.foreground, 0.2)
                }
              }

              delegate: Rectangle {
                id: row
                required property int index
                required property string itemId
                required property string kind
                required property string icon
                required property string iconFont
                required property string appIcon
                required property string appId
                required property string label
                required property string target
                required property string detail
                required property string path
                required property string action
                required property int childCount
                required property bool disabled

                readonly property bool hasCursor: !root.calcFocused && root.cursorActive && row.index === root.selectedIndex
                readonly property bool isApp: row.kind === "app"
                readonly property bool hasIcon: row.icon.length > 0 || row.isApp
                readonly property bool spot: !root.dmenuActive
                readonly property bool subtitle: row.spot && root.filterText.length > 0 && row.detail.length > 0
                readonly property color ink: row.hasCursor ? root.rowInk : root.foreground

                width: ListView.view.width
                height: root.rowHeightForDetail(row.detail)
                // Faded: the row is here to say the software is already
                // installed, not to be picked.
                opacity: row.disabled ? 0.4 : 1
                radius: root.rowRadius
                color: row.hasCursor ? root.rowFill : "transparent"

                Text {
                  id: iconText
                  textFormat: Text.PlainText
                  visible: row.hasIcon && !row.isApp
                  text: row.icon
                  color: row.ink
                  font.family: row.iconFont.length > 0 ? row.iconFont : root.fontFamily
                  font.pixelSize: row.spot ? root.px(20) : Style.font.heading
                  width: row.spot ? root.px(32) : Style.space(28)
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  anchors.left: parent.left
                  anchors.leftMargin: row.spot ? root.px(10) : Style.space(6)
                  y: row.spot ? (row.height - height) / 2 : contentColumn.y + labelText.y + (labelText.height - height) / 2
                }

                Image {
                  id: appIconImage
                  visible: row.isApp
                  width: row.spot ? root.px(32) : Style.space(22)
                  height: width
                  fillMode: Image.PreserveAspectFit
                  // Decode at physical pixels — a logical-size decode leaves
                  // PNG icons upscaled and blurry on HiDPI displays.
                  sourceSize.width: width * Screen.devicePixelRatio
                  sourceSize.height: height * Screen.devicePixelRatio
                  source: row.isApp && root.appLibrary ? root.appLibrary.iconSource(row.appIcon) : ""
                  asynchronous: true
                  anchors.left: parent.left
                  anchors.leftMargin: row.spot ? root.px(10) : Style.space(6) + (Style.space(28) - width) / 2
                  y: row.spot ? (row.height - height) / 2 : contentColumn.y + labelText.y + (labelText.height - height) / 2
                }

                Column {
                  id: contentColumn
                  anchors.left: row.hasIcon ? iconText.right : parent.left
                  anchors.leftMargin: row.hasIcon ? (row.spot ? root.px(10) : Style.space(8)) : (row.spot ? root.px(16) : Style.space(14))
                  anchors.right: openHintRow.visible ? openHintRow.left : trail.left
                  anchors.rightMargin: row.spot ? root.px(10) : Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: row.spot ? root.px(1) : Style.space(2)

                  Text {
                    id: labelText
                    textFormat: Text.PlainText
                    width: parent.width
                    text: row.label
                    color: row.ink
                    font.family: root.fontFamily
                    font.pixelSize: row.spot ? root.px(18) : Style.font.title
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    // A parent path's separator points along the reading direction.
                    text: Commons.I18n.rightToLeft ? row.detail.replace(/ › /g, " ‹ ") : row.detail
                    visible: row.subtitle
                    color: row.ink
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: root.px(15)
                    elide: Text.ElideLeft
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: row.detail
                    visible: root.dmenuActive && row.detail.length > 0
                    color: row.ink
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                }

                Row {
                  id: openHintRow
                  visible: row.spot && row.hasCursor
                  anchors.right: parent.right
                  anchors.rightMargin: root.px(12)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: root.px(6)

                  Text {
                    textFormat: Text.PlainText
                    text: root.verbFor(row)
                    color: row.ink
                    opacity: 0.7
                    font.family: root.fontFamily
                    font.pixelSize: root.px(13)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Rectangle {
                    width: Math.max(height, enterKey.implicitWidth + root.px(8))
                    height: root.px(20)
                    radius: root.px(5)
                    color: root.grayRows ? (root.lightCard ? "#ffffff" : Util.alpha("#ffffff", 0.12)) : Util.alpha(row.ink, 0.14)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      id: enterKey
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: "↵"
                      color: row.ink
                      opacity: root.grayRows && root.lightCard ? 0.6 : 1
                      font.family: root.fontFamily
                      font.pixelSize: root.px(13)
                    }
                  }
                }

                Text {
                  id: trail
                  textFormat: Text.PlainText
                  visible: !openHintRow.visible
                  width: row.spot ? root.px(14) : Style.space(14)
                  text: row.kind === "menu" || row.kind === "link" ? (Commons.I18n.rightToLeft ? "‹" : "›") : ""
                  color: row.ink
                  opacity: row.kind === "menu" || row.kind === "link" ? 0.45 : 0
                  font.family: root.fontFamily
                  font.pixelSize: row.spot ? root.px(18) : Style.font.heading
                  anchors.right: parent.right
                  anchors.rightMargin: row.spot ? root.px(10) : Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }

                MouseArea {
                  id: mouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: row.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                  onEntered: root.selectFromPointer(row.index, row, {
                    x: mouseArea.mouseX,
                    y: mouseArea.mouseY
                  })
                  onPositionChanged: function(mouse) {
                    root.selectFromPointer(row.index, row, mouse)
                  }
                  onClicked: {
                    if (row.disabled) return
                    root.cursorActive = true
                    root.selectedIndex = row.index
                    root.activateIndex(row.index, true)
                  }
                }
              }
            }

            Rectangle {
              visible: !root.dmenuActive && !root.gridActive && resultList.contentHeight > resultList.height + 1
              width: root.px(3)
              radius: width / 2
              x: resultList.width + (root.contentMargin - width) / 2
              y: resultList.visibleArea.yPosition * resultList.height
              height: resultList.visibleArea.heightRatio * resultList.height
              color: Util.alpha(root.foreground, 0.3)
            }

            GridView {
              id: appGrid
              anchors.fill: parent
              visible: root.gridActive
              model: root.gridActive ? displayModel : null
              clip: true
              cellWidth: Math.floor(width / root.gridColumns)
              cellHeight: root.gridCellHeight
              boundsBehavior: Flickable.StopAtBounds

              delegate: Item {
                id: cell
                required property int index
                required property string kind
                required property string icon
                required property string iconFont
                required property string appIcon
                required property string label
                required property bool disabled

                readonly property bool hasCursor: root.cursorActive && cell.index === root.selectedIndex

                width: GridView.view.cellWidth
                height: GridView.view.cellHeight
                opacity: cell.disabled ? 0.4 : 1

                Rectangle {
                  anchors.fill: parent
                  anchors.margins: root.px(3)
                  radius: root.rowRadius
                  color: cell.hasCursor ? root.rowFill : "transparent"
                }

                Image {
                  id: gridIcon
                  visible: cell.kind === "app"
                  width: root.px(48)
                  height: root.px(48)
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: width * Screen.devicePixelRatio
                  sourceSize.height: height * Screen.devicePixelRatio
                  source: cell.kind === "app" && root.appLibrary ? root.appLibrary.iconSource(cell.appIcon) : ""
                  asynchronous: true
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: parent.top
                  anchors.topMargin: root.px(10)
                }

                Text {
                  visible: cell.kind !== "app"
                  textFormat: Text.PlainText
                  text: cell.icon
                  color: cell.hasCursor ? root.rowInk : root.foreground
                  font.family: cell.iconFont.length > 0 ? cell.iconFont : root.fontFamily
                  font.pixelSize: root.px(28)
                  anchors.centerIn: gridIcon
                }

                Text {
                  textFormat: Text.PlainText
                  text: cell.label
                  width: parent.width - root.px(10)
                  horizontalAlignment: Text.AlignHCenter
                  color: cell.hasCursor ? root.rowInk : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.px(14)
                  elide: Text.ElideRight
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: gridIcon.bottom
                  anchors.topMargin: root.px(8)
                }

                MouseArea {
                  id: cellMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: cell.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                  onEntered: root.selectFromPointer(cell.index, cell, {
                    x: cellMouse.mouseX,
                    y: cellMouse.mouseY
                  })
                  onPositionChanged: function(mouse) {
                    root.selectFromPointer(cell.index, cell, mouse)
                  }
                  onClicked: {
                    if (cell.disabled) return
                    root.cursorActive = true
                    root.selectedIndex = cell.index
                    root.activateIndex(cell.index, true)
                  }
                }
              }
            }

            Column {
              anchors.centerIn: parent
              spacing: root.px(8)
              visible: displayModel.count === 0 && root.mode !== "input" && !root.calcResult

              Text {
                text: "󰈉"
                color: root.selectedBackground
                opacity: 0.8
                font.family: root.fontFamily
                font.pixelSize: root.px(28)
                horizontalAlignment: Text.AlignHCenter
                width: root.px(320)
              }

              Text {
                textFormat: Text.PlainText
                text: root.filterText ? Commons.I18n.t("common.noMatchesFor").arg(root.filterText) : Commons.I18n.t("menu.nothingHere")
                color: root.foreground
                opacity: 0.7
                font.family: root.fontFamily
                font.pixelSize: root.px(16)
                horizontalAlignment: Text.AlignHCenter
                width: root.px(320)
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          visible: root.showFooter
          color: root.border
        }

        Item {
          width: parent.width
          height: root.footerHeight
          visible: root.showFooter

          Row {
            id: footerRow
            readonly property var current: root.currentRow
            anchors.right: parent.right
            anchors.rightMargin: root.dmenuActive ? Style.space(16) : root.px(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.dmenuActive ? Style.space(16) : root.px(16)

            Repeater {
              model: [
                { show: !root.dmenuActive, text: "⌃1–9 filter" },
                { show: !root.dmenuActive && root.activeMenu !== "root" && !root.filterText, text: "⌫ back" },
                { show: true, text: "esc " + (root.filterText ? "clear" : "close") },
                { show: root.dmenuActive || root.calcFocused || !!footerRow.current, text: "↵ " + (root.dmenuActive ? "select" : (root.calcFocused ? "copy" : (footerRow.current && footerRow.current.kind === "action" ? "run" : "open"))) }
              ]

              delegate: Text {
                required property var modelData
                visible: modelData.show
                textFormat: Text.PlainText
                text: modelData.text
                color: root.foreground
                opacity: 0.5
                font.family: root.fontFamily
                font.pixelSize: root.dmenuActive ? Style.font.bodySmall : root.px(13)
              }
            }
          }
        }
      }
    }
  }
}
