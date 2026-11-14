pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "Model.js" as Model

Scope {
    id: root

    readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: findWifiDevice()
    readonly property var wiredDevice: findDevice(DeviceType.Wired)
    readonly property var connectedWifiNetwork: findConnectedWifiNetwork()
    readonly property string kind: {
        if (wiredDevice && wiredDevice.connected) return "ethernet"
        if (connectedWifiNetwork) return "wifi"
        if (wifiDevice && wifiDevice.connected) return "wifi"
        return "disconnected"
    }
    readonly property int signalStrength: kind === "wifi" && connectedWifiNetwork
        ? Math.round((connectedWifiNetwork.signalStrength || 0) * 100) : -1
    readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager
    readonly property bool connectivityChecksEnabled: networkManagerAvailable
        && Networking.canCheckConnectivity && Networking.connectivityCheckEnabled
    readonly property string connectivity: Model.connectivityState(kind, Networking.connectivity, {
        Portal: NetworkConnectivity.Portal,
        Limited: NetworkConnectivity.Limited,
        Full: NetworkConnectivity.Full,
        None: NetworkConnectivity.None
    }, connectivityChecksEnabled)
    readonly property bool wifiEnabled: Networking.backend === NetworkBackendType.NetworkManager && Networking.wifiEnabled
    property var scannerDevice: null
    property var dnsPopupOwners: []
    readonly property int dnsVisiblePopupCount: dnsPopupOwners.length
    property string dnsProvider: ""
    property string dnsPendingProvider: ""
    property string dnsError: ""
    property string dnsConnectionUuid: ""
    property string dnsStatusInterface: ""
    property string dnsQueryInterface: ""
    property string dnsProfileQueryUuid: ""
    property string dnsActionInterface: ""
    readonly property string dnsInterface: wiredDevice && wiredDevice.connected ? wiredDevice.name
        : (wifiDevice && wifiDevice.connected ? wifiDevice.name : "")
    readonly property bool dnsBusy: dnsPendingProvider !== ""
    readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]

    function registerDnsPopup(owner) {
        if (!owner || dnsPopupOwners.indexOf(owner) !== -1) return
        dnsPopupOwners = dnsPopupOwners.concat([owner])
        refreshDnsStatus()
    }

    function unregisterDnsPopup(owner) {
        var index = dnsPopupOwners.indexOf(owner)
        if (index === -1) return
        var owners = dnsPopupOwners.slice()
        owners.splice(index, 1)
        dnsPopupOwners = owners
        if (dnsPopupOwners.length === 0) refreshDnsStatus()
    }

    function refreshDnsStatus() {
        var iface = dnsInterface
        if (iface !== dnsStatusInterface) {
            dnsStatusInterface = iface
            dnsConnectionUuid = ""
            dnsProfileQueryUuid = ""
            dnsProvider = ""
        }
        if (!iface || dnsVisiblePopupCount === 0) {
            dnsRefreshRetry.stop()
            return
        }
        if (dnsUuidProc.running || dnsProfileProc.running) {
            dnsRefreshRetry.restart()
            return
        }
        dnsRefreshRetry.stop()
        dnsQueryInterface = iface
        dnsUuidProc.command = ["nmcli", "-g", "GENERAL.CON-UUID", "device", "show", iface]
        dnsUuidProc.running = true
    }

    function refreshActiveDnsProfile() {
        dnsConnectionUuid = ""
        dnsProfileQueryUuid = ""
        dnsProvider = ""
        refreshDnsStatus()
    }

    function clearDnsError() { dnsError = "" }

    function updateDnsConnectionUuid(raw) {
        if (dnsQueryInterface !== dnsInterface) return
        var uuid = String(raw || "").trim()
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uuid)) {
            dnsConnectionUuid = ""
            dnsProvider = ""
            return
        }
        dnsConnectionUuid = uuid
        if (dnsProfileProc.running) return
        dnsProfileQueryUuid = uuid
        dnsProfileProc.command = ["nmcli", "-g", "ipv4.ignore-auto-dns,ipv4.dns,ipv6.ignore-auto-dns,ipv6.dns", "connection", "show", uuid]
        dnsProfileProc.running = true
    }

    function updateDnsProfile(raw) {
        if (dnsProfileQueryUuid !== dnsConnectionUuid) return
        var provider = Model.dnsProviderFromProfile(raw)
        if (provider !== "") dnsProvider = provider
    }

    // This shortcut changes only the active profile; use global policy if all saved profiles need the same DNS.
    function setDns(provider, customServers) {
        if (dnsBusy || !dnsConnectionUuid) return
        var ipv4Dns = ""
        var ipv6Dns = ""
        if (provider === "Cloudflare") {
            ipv4Dns = "1.1.1.1,1.0.0.1"
            ipv6Dns = "2606:4700:4700::1111,2606:4700:4700::1001"
        } else if (provider === "Google") {
            ipv4Dns = "8.8.8.8,8.8.4.4"
            ipv6Dns = "2001:4860:4860::8888,2001:4860:4860::8844"
        } else if (provider === "Custom") {
            var servers = String(customServers || "").trim().split(/[\s,]+/)
            if (servers.length === 1 && servers[0] === "") {
                dnsError = "Enter one or more DNS server IP addresses."
                return
            }
            var ipv4 = []
            var ipv6 = []
            for (var i = 0; i < servers.length; i++) {
                if (!/^[0-9a-f:.]+$/i.test(servers[i]) || !/[.:]/.test(servers[i])) {
                    dnsError = "Use IPv4 or IPv6 addresses separated by spaces or commas."
                    return
                }
                if (servers[i].indexOf(":") !== -1) ipv6.push(servers[i])
                else ipv4.push(servers[i])
            }
            ipv4Dns = ipv4.join(",")
            ipv6Dns = ipv6.join(",")
        } else if (provider !== "DHCP") return

        var command = ["sudo", "-n", "nmcli", "connection", "modify", "uuid", dnsConnectionUuid]
        if (provider === "DHCP")
            command.push("ipv4.ignore-auto-dns", "no", "ipv4.dns", "", "ipv6.ignore-auto-dns", "no", "ipv6.dns", "")
        else
            command.push("ipv4.ignore-auto-dns", "yes", "ipv4.dns", ipv4Dns, "ipv6.ignore-auto-dns", "yes", "ipv6.dns", ipv6Dns)

        dnsError = ""
        dnsPendingProvider = provider
        dnsActionInterface = dnsInterface
        dnsModifyProc.command = command
        dnsModifyProc.running = true
    }

    function finishDns(success, errorText) {
        if (success) {
            dnsProvider = dnsPendingProvider
            dnsError = ""
        } else {
            dnsError = String(errorText || "").trim() || "Could not apply DNS settings."
            refreshDnsStatus()
        }
        dnsPendingProvider = ""
    }

    Process {
        id: dnsUuidProc
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateDnsConnectionUuid(text) }
    }
    Process {
        id: dnsProfileProc
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateDnsProfile(text) }
    }
    Process {
        id: dnsModifyProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: dnsModifyStderr; waitForEnd: true }
        onExited: function(exitCode) {
            if (exitCode !== 0) { root.finishDns(false, dnsModifyStderr.text); return }
            dnsReapplyProc.command = ["sudo", "-n", "nmcli", "device", "reapply", root.dnsActionInterface]
            dnsReapplyProc.running = true
        }
    }
    Process {
        id: dnsReapplyProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: dnsReapplyStderr; waitForEnd: true }
        onExited: function(exitCode) {
            root.finishDns(exitCode === 0, dnsReapplyStderr.text)
            if (exitCode === 0) root.refreshDnsStatus()
        }
    }
    Timer {
        id: dnsPoll
        interval: 5000
        repeat: true
        running: root.dnsVisiblePopupCount > 0
        onTriggered: root.refreshDnsStatus()
    }
    Timer {
        id: dnsRefreshRetry
        interval: 100
        repeat: false
        onTriggered: root.refreshDnsStatus()
    }

    function findWifiDevice() {
        var devices = networkDevices || []
        var fallback = null
        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            if (!device || device.type !== DeviceType.Wifi) continue
            if (device.connected) return device
            if (!fallback) fallback = device
        }
        return fallback
    }

    function findDevice(type) {
        var devices = networkDevices || []
        var fallback = null
        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            if (!device || device.type !== type) continue
            if (device.connected) return device
            if (!fallback) fallback = device
        }
        return fallback
    }

    function findConnectedWifiNetwork() {
        var networks = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
        for (var i = 0; i < networks.length; i++)
            if (networks[i] && networks[i].connected) return networks[i]
        return null
    }

    // Disabling the native scanner hides unsaved networks, so it belongs to the shell, not a popup.
    function syncScanner() {
        var nextDevice = wifiEnabled ? wifiDevice : null
        if (scannerDevice && scannerDevice !== nextDevice)
            scannerDevice.scannerEnabled = false
        scannerDevice = nextDevice
        if (scannerDevice)
            scannerDevice.scannerEnabled = true
    }

    onWifiDeviceChanged: syncScanner()
    onWifiEnabledChanged: syncScanner()
    onDnsInterfaceChanged: refreshDnsStatus()
    Component.onCompleted: syncScanner()
    Component.onDestruction: {
        if (scannerDevice) scannerDevice.scannerEnabled = false
    }
}
