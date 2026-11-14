pragma Singleton

import QtQuick
import Quickshell.Bluetooth

Item {
    id: root

    width: 0
    height: 0
    visible: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    property bool panelOpen: false
    property var discoveryAdapter: null
    property int stopAttempts: 0

    function startDiscovery() {
        if (!panelOpen || !adapter || !adapter.enabled || adapter.discovering) return
        discoveryAdapter = adapter
        adapter.discovering = true
    }

    function stopDiscovery() {
        if (!discoveryAdapter || adapter !== discoveryAdapter) return
        if (adapter.discovering && stopAttempts < 3) {
            stopAttempts++
            adapter.discovering = false
        } else if (!adapter.discovering || stopAttempts >= 3) {
            discoveryAdapter = null
        }
    }

    onPanelOpenChanged: {
        stopAttempts = 0
        if (panelOpen) startDiscovery()
    }
    onAdapterChanged: {
        if (discoveryAdapter && discoveryAdapter !== adapter) {
            discoveryAdapter.discovering = false
            discoveryAdapter = null
        }
        if (panelOpen) startDiscovery()
    }
    Connections {
        target: root.adapter
        function onDiscoveringChanged() {
            if (!root.adapter.discovering && !root.panelOpen)
                root.discoveryAdapter = null
        }
        function onEnabledChanged() {
            if (root.panelOpen) root.startDiscovery()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.panelOpen && root.adapter !== null && root.adapter.enabled && !root.adapter.discovering
        onTriggered: root.startDiscovery()
    }

    Timer {
        interval: 1000
        repeat: true
        running: !root.panelOpen && root.discoveryAdapter !== null && root.adapter === root.discoveryAdapter && root.adapter.discovering
        onTriggered: root.stopDiscovery()
    }
}
