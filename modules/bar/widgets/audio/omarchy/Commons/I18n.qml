pragma Singleton
import QtQuick

// English-only text helpers for the copied audio UI. No locale discovery or
// translation catalogs are loaded in this shell.
QtObject {
    readonly property string language: "en"
    readonly property bool rightToLeft: false

    function t(key, english) { return english === undefined ? String(key) : String(english) }
    function tn(key, count) { return t(key) }
    function formatNumber(value) { return String(value) }
}
