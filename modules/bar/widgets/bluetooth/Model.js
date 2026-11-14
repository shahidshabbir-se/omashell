function deviceLabel(device) {
    return String(device && (device.name || device.deviceName) || "").trim()
}

function isAddressLike(value) {
    return /^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(String(value || "").trim())
}

function isUuidLike(value) {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(value || "").trim())
}

function deviceRows(devices, discovering, pendingPairAddress) {
    var connected = []
    var paired = []
    var available = []
    var values = devices || []

    for (var i = 0; i < values.length; i++) {
        var device = values[i]
        var label = deviceLabel(device)
        if (!device || !label || isAddressLike(label) || isUuidLike(label)) continue

        var pending = !!pendingPairAddress && device.address === pendingPairAddress
        var row = {
            kind: "device",
            address: device.address || "",
            label: label,
            // Pairing opens a transport link before authentication finishes.
            connected: !!device.connected && !device.pairing && !pending,
            known: !!(device.paired || device.bonded || device.trusted),
            pairing: !!device.pairing,
            state: device.state,
            batteryAvailable: !!device.batteryAvailable,
            battery: device.battery !== undefined ? device.battery : 0
        }
        if (row.connected) connected.push(row)
        else if (row.known) paired.push(row)
        else if (discovering || row.pairing || pending) available.push(row)
    }

    var rows = []
    function appendSection(title, devices) {
        if (!devices.length) return
        devices.sort(function(a, b) { return a.label.localeCompare(b.label) })
        rows.push({ kind: "header", label: title })
        for (var i = 0; i < devices.length; i++) rows.push(devices[i])
    }
    appendSection("CONNECTED", connected)
    appendSection("PAIRED", paired)
    appendSection("AVAILABLE", available)
    return rows
}

if (typeof module !== "undefined")
    module.exports = { deviceLabel: deviceLabel, deviceRows: deviceRows }
