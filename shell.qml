import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.bar.widgets.clock
import qs.modules.bar.widgets.weather
import qs.modules.bar.widgets.worldclock
import qs.modules.bar.widgets.bluetooth
import qs.modules.bar.widgets.network
import qs.modules.bar.widgets.audio
import qs.modules.bar.widgets.music
import qs.modules.bar.widgets.power
import qs.modules.clipboard
import qs.modules.display
import qs.modules.notifications
import qs.modules.visualizer
import qs.modules.volume
import qs.modules.wallpaper
import qs.config

ShellRoot {
  id: shell

                                                                                 
                                          
  readonly property var panelFor: ({
    clock: calendarPanel,
    weather: weatherPanel,
    worldclock: worldClockPanel,
    bluetooth: bluetoothPanel,
    network: networkPanel,
    audio: audioPanel,
    music: musicPanel,
    power: powerPanel,
    display: displayPanel,
    wallpaper: wallpaperPanel,
    notifications: notificationsPanel
  })

  function closeOverlays() {
    wifiSharePanel.close()
    speedTestPanel.close()
  }

  function closePanels() {
    closeOverlays()
    calendarPanel.close()
    weatherPanel.close()
    worldClockPanel.close()
    bluetoothPanel.close()
    networkPanel.close()
    audioPanel.close()
    musicPanel.close()
    powerPanel.close()
    clipboardMenu.close()
    displayPanel.dismiss()
    wallpaperPanel.close()
    notificationsPanel.close()
  }

  function showPanel(target, x) {
    if (target === powerPanel && !PowerService.present) return
    closeOverlays()
    if (target !== calendarPanel) calendarPanel.close()
    if (target !== weatherPanel) weatherPanel.close()
    if (target !== worldClockPanel) worldClockPanel.close()
    if (target !== bluetoothPanel) bluetoothPanel.close()
    if (target !== networkPanel) networkPanel.close()
    if (target !== audioPanel) audioPanel.close()
    if (target !== musicPanel) musicPanel.close()
    if (target !== powerPanel) powerPanel.close()
    clipboardMenu.close()
    if (target !== displayPanel) displayPanel.dismiss()
    if (target !== wallpaperPanel) wallpaperPanel.close()
    if (target !== notificationsPanel) notificationsPanel.close()
    // Centered overlays do not take a bar anchor.
    if (target.anchorX !== undefined) target.anchorX = x
    target.toggle()
  }

                                                    
  function showPanelFor(id, x) {
    var panel = panelFor[id]
    if (panel) showPanel(panel, x)
  }

  function panelAvailable(id) {
    if (id === "power") return PowerService.present
    if (id === "music") return MusicRuntime.hasCurrentPlayback
    return true
  }

  function switchPanelFrom(id, direction) {
    var configured = Config.bar.left.concat(Config.bar.centerBegin, Config.bar.center, Config.bar.centerEnd, Config.bar.right)
    var ids = []
    for (var i = 0; i < configured.length; i++)
      if (panelFor[configured[i]] && panelAvailable(configured[i]) && ids.indexOf(configured[i]) < 0) ids.push(configured[i])
    for (var key in panelFor)
      if (panelAvailable(key) && ids.indexOf(key) < 0) ids.push(key)
    if (ids.length < 2) return
    var index = ids.indexOf(id)
    if (index < 0) return
    var next = (index + (direction < 0 ? -1 : 1) + ids.length) % ids.length
    showPanelFor(ids[next], -1)
  }

                                                                               
                                                              
  readonly property string activeWidgetId: {
    for (var id in panelFor)
      if (panelFor[id].opened) return id
    return ""
  }

  Variants {
    model: Quickshell.screens

    delegate: Bar {
      required property var modelData
      screen: modelData
      activeId: shell.activeWidgetId
      panelOpen: shell.activeWidgetId !== ""

      onWidgetActivated: function(id, x) { shell.showPanelFor(id, x) }
      onBarClicked: shell.closePanels()
    }
  }

  CalendarPanel { id: calendarPanel }
  WeatherPanel { id: weatherPanel }
  WorldClockPanel { id: worldClockPanel }
  BluetoothPanel {
    id: bluetoothPanel
    onSwitchPanelRequested: function(direction) { shell.switchPanelFrom("bluetooth", direction) }
  }
  NetworkPanel {
    id: networkPanel
    onSwitchPanelRequested: function(direction) { shell.switchPanelFrom("network", direction) }
    onShareRequested: function(payload) { wifiSharePanel.open(payload) }
    onSpeedTestRequested: function(payload) { speedTestPanel.open(payload) }
  }
  AudioPanel {
    id: audioPanel
    onSwitchPanelRequested: function(direction) { shell.switchPanelFrom("audio", direction) }
  }
  MusicPanel { id: musicPanel }
  PowerPanel {
    id: powerPanel
    onSwitchPanelRequested: function(direction) { shell.switchPanelFrom("power", direction) }
  }
  NotificationsPanel {
    id: notificationsPanel
    onSwitchPanelRequested: function(direction) { shell.switchPanelFrom("notifications", direction) }
  }
  ClipboardMenu {
    id: clipboardMenu
    captureEnabled: Config.clipboardEnabled
  }
  DisplayPanel {
    id: displayPanel
    profilePath: Config.displayProfilePath
  }
  WallpaperPanel { id: wallpaperPanel; library: Config.wallpaperLibrary }
  WifiSharePanel { id: wifiSharePanel }
  SpeedTestPanel { id: speedTestPanel }
  Visualizer {}
  Volume {}
  ToastDeck {}

  function runShellTool(name, args) {
    var rootPath = Quickshell.env('OMASHELL_ROOT')
    var executable = rootPath ? rootPath + '/bin/' + name : name
    Quickshell.execDetached([executable].concat(args || []))
  }

  IpcHandler {
    target: "omashell"

    function toggleCalendar(): void { shell.showPanel(calendarPanel, -1) }
    function toggleWeather(): void { shell.showPanel(weatherPanel, -1) }
    function toggleWorldClock(): void { shell.showPanel(worldClockPanel, -1) }
    function toggleBluetooth(): void { shell.showPanel(bluetoothPanel, -1) }
    function toggleNetwork(): void { shell.showPanel(networkPanel, -1) }
    function toggleAudio(): void { shell.showPanel(audioPanel, -1) }
    function toggleMusic(): void { shell.showPanel(musicPanel, -1) }
    function togglePower(): void { shell.showPanel(powerPanel, -1) }
    function toggleClipboard(): void {
      if (!clipboardMenu.opened) shell.closePanels()
      clipboardMenu.toggle()
    }
    function toggleWallpaper(): void { shell.showPanel(wallpaperPanel, -1) }
    function toggleDisplay(): void { shell.showPanel(displayPanel, -1) }
    function toggleNotifications(): void { shell.showPanel(notificationsPanel, -1) }
    function toggleNotificationKeyboard(): void {
      if (NotificationService.keyboardMode) NotificationService.stopKeyboard()
      else NotificationService.startKeyboard()
    }
    function captureScreenshot(): void { shell.runShellTool('omashell-screenshot', []) }
    function openLatestScreenshot(): void { shell.runShellTool('omashell-open-screenshot', []) }
    function editLatestScreenshot(): void { shell.runShellTool('omashell-open-screenshot', ['--edit']) }
    function toggleDoNotDisturb(): void { NotificationService.toggleDnd() }
    function clearNotifications(): void { NotificationService.clear() }
    function dismissAllNotifications(): void { NotificationService.dismissAll() }
    function notificationsState(): string {
      return JSON.stringify({ live: NotificationService.live.length, history: NotificationService.history.length, dnd: NotificationService.dnd })
    }
    function toggleBatteryPercentage(): void { PowerService.togglePercentage() }
    function toggleWifiShare(): void {
      if (wifiSharePanel.opened) wifiSharePanel.close()
      else wifiSharePanel.open("{}")
    }
    function closeAll(): void { shell.closePanels() }
  }
}
