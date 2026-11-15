import QtQuick
import qs.config
import qs.common

PanelShell {
  id: root

  layerNamespace: "omashell-calendar"
  cardWidth: 560
  spacing: 8

  property date now: new Date()
  property date today: new Date()
  readonly property string todayKey: dateKey(today.getFullYear(), today.getMonth(), today.getDate())
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  property int pendingMonthOffset: 0
  property int monthTransitionDirection: 1
  readonly property int monthSlideDistance: 22
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()
  readonly property date viewDate: new Date(viewYear, viewMonth, 1, 12)
  readonly property var weeks: monthGrid(viewYear, viewMonth, todayKey)
  readonly property real yearDone: yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int yearDonePercent: Math.round(yearDone * 100)

  readonly property var weekdays: [1, 2, 3, 4, 5, 6, 0]
  readonly property var weekdayLabels: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
  readonly property var monthNames: [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]

  readonly property string heroDateText: monthNames[today.getMonth()] + " " + today.getDate()
  readonly property string monthYearLabel: (monthNames[viewMonth] + " " + viewDate.getFullYear()).toUpperCase()

  onOpenedChanged: if (opened) refresh()

  function refresh() {
    now = new Date()
    today = now
                                                                    
                                                             
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
  }

  function pad2(value) {
    var n = Number(value)
    return (n < 10 ? "0" : "") + n
  }

  function dateKey(year, month, day) {
    return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
  }

  function isoWeek(year, month, day) {
    var date = new Date(Date.UTC(year, month, day))
    var weekday = date.getUTCDay() || 7
    date.setUTCDate(date.getUTCDate() + 4 - weekday)
    var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
    return Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7)
  }

  function monthGrid(year, month, todayKey) {
    var leading = (new Date(Date.UTC(year, month, 1)).getUTCDay() - 1 + 7) % 7
    var cursor = new Date(Date.UTC(year, month, 1 - leading))
    var today = String(todayKey || "")
    var weeks = []

    for (var w = 0; w < 6; w++) {
      var days = []
      var thursday = null

      for (var d = 0; d < 7; d++) {
        var cellYear = cursor.getUTCFullYear()
        var cellMonth = cursor.getUTCMonth()
        var cellDay = cursor.getUTCDate()
        var weekday = cursor.getUTCDay()
        var key = dateKey(cellYear, cellMonth, cellDay)

        if (weekday === 4) thursday = { year: cellYear, month: cellMonth, day: cellDay }

        days.push({
          key: key,
          day: cellDay,
          weekday: weekday,
          inMonth: cellMonth === month && cellYear === year,
          weekend: weekday === 0 || weekday === 6,
          today: key === today
        })

        cursor.setUTCDate(cursor.getUTCDate() + 1)
      }

      var anchor = thursday || days[0]
      weeks.push({ week: isoWeek(anchor.year, anchor.month, anchor.day), days: days })
    }

    return weeks
  }

  function daysInYear(year) {
    return Math.round((Date.UTC(year + 1, 0, 1) - Date.UTC(year, 0, 1)) / 86400000)
  }

  function yearProgress(year, month, day) {
    var total = daysInYear(year)
    if (total <= 0) return 0
    var done = Math.round((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / 86400000)
    return Math.max(0, Math.min(1, done / total))
  }

  function stepMonth(delta) {
    beginMonthTransition(delta)
  }

  function beginMonthTransition(delta) {
    if (delta === 0 || monthTransition.running) return
    pendingMonthOffset = delta
    monthTransitionDirection = delta < 0 ? -1 : 1
    monthTransition.start()
  }

  function goToToday() {
    var delta = (today.getFullYear() - viewYear) * 12 + (today.getMonth() - viewMonth)
    if (delta === 0) return
    if (!opened) {
      viewYear = today.getFullYear()
      viewMonth = today.getMonth()
      return
    }
    beginMonthTransition(delta)
  }

  property Timer midnightTimer: Timer {
    interval: 60000
    running: true
    repeat: true

    onTriggered: {
      var current = new Date()
      root.now = current

      var nextKey = root.dateKey(current.getFullYear(), current.getMonth(), current.getDate())
      if (nextKey === root.todayKey) return

      var followToday = root.viewingCurrentMonth
      root.today = current
      if (followToday) root.goToToday()
    }
  }

  Item {
    width: parent.width
    height: heroRow.height

    Row {
      id: heroRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 22

      Text {
        anchors.baseline: heroDate.baseline
        text: "\uDB80\uDCED"
        textFormat: Text.PlainText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: 48
      }

      Text {
        id: heroDate
        text: root.heroDateText
        textFormat: Text.PlainText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: 52
        font.bold: true
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: !root.viewingCurrentMonth
      hoverEnabled: enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.goToToday()
    }
  }

  Item {
    width: parent.width
    height: yearBlock.y + yearBlock.height

    Item {
      id: yearBlock
      y: 6
      anchors.horizontalCenter: parent.horizontalCenter
      width: gridColumn.width
      height: Math.max(yearLabel.implicitHeight, 10)

      Text {
        id: yearLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.today.getFullYear()
        textFormat: Text.PlainText
        color: Qt.darker(Colors.foreground, 1.5)
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBodySmall
        font.letterSpacing: 1
      }

      Text {
        id: yearPercent
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.yearDonePercent + "%"
        textFormat: Text.PlainText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBodySmall
      }

      Rectangle {
        anchors.left: yearLabel.right
        anchors.right: yearPercent.left
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: Constants.cornerRadius > 0 ? height / 2 : 0
        color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.12)

        Rectangle {
          width: Math.round(parent.width * root.yearDone)
          height: parent.height
          radius: parent.radius
          color: Colors.foreground

          Behavior on width {
            NumberAnimation {
              duration: root.duration(160)
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }
  }

  Item {
    id: gridArea
    opacity: 1
    width: parent.width
    height: gridColumn.y + gridColumn.height

    transform: Translate {
      id: gridShift
    }

    WheelHandler {
      onWheel: function(event) {
        if (event.angleDelta.y === 0) return
        root.stepMonth(event.angleDelta.y > 0 ? -1 : 1)
      }
    }

    Column {
      id: gridColumn
      y: 18
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 3

      Row {
        id: headerRow
        spacing: Constants.cellSpacing

        Text {
          width: Constants.weekColumnWidth
          height: 16
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: "W"
          textFormat: Text.PlainText
          color: Qt.darker(Colors.foreground, 1.9)
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontCaption
          font.letterSpacing: 1
          font.bold: true
        }

        Item {
          width: Constants.gutterWidth
          height: 16
        }

        Repeater {
          model: root.weekdays

          Text {
            required property int modelData
            width: Constants.cellWidth
            height: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.weekdayLabels[modelData]
            textFormat: Text.PlainText
            color: Qt.darker(Colors.foreground, 1.5)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontCaption
            font.letterSpacing: 1
            font.bold: true
          }
        }
      }

      Repeater {
        model: root.weeks

        Row {
          required property var modelData
          spacing: Constants.cellSpacing

          Text {
            width: Constants.weekColumnWidth
            height: Constants.cellHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: modelData.week
            textFormat: Text.PlainText
            color: Qt.darker(Colors.foreground, 1.9)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontCaption
          }

          Item {
            width: Constants.gutterWidth
            height: Constants.cellHeight
          }

          Repeater {
            model: modelData.days

            Rectangle {
              required property var modelData

              width: Constants.cellWidth
              height: Constants.cellHeight
              radius: Constants.cornerRadius
              color: "transparent"
              border.width: modelData.today ? 1 : 0
              border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.4)

              Text {
                anchors.centerIn: parent
                text: modelData.day
                textFormat: Text.PlainText
                color: modelData.inMonth
                  ? (modelData.weekend ? Qt.darker(Colors.foreground, 1.45) : Colors.foreground)
                  : Qt.darker(Colors.foreground, 2.2)
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontBody
                font.bold: modelData.today
              }
            }
          }
        }
      }
    }

    Rectangle {
      readonly property real gutterOffset: Constants.weekColumnWidth + Constants.cellSpacing + Math.round((Constants.gutterWidth - width) / 2)
      x: gridColumn.x + gutterOffset
      y: gridColumn.y + headerRow.height + gridColumn.spacing
      width: 1
      height: gridColumn.height - headerRow.height - gridColumn.spacing
      color: Colors.foreground
      opacity: 0.1
    }
  }

  Item {
    width: parent.width
    height: monthNav.height

    Item {
      id: monthNav
      anchors.horizontalCenter: parent.horizontalCenter
      width: gridColumn.width
      height: monthLabel.implicitHeight + 10

      Text {
        id: monthLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 130
        opacity: 1
        transform: Translate {
          id: monthLabelShift
        }
        horizontalAlignment: Text.AlignHCenter
        text: root.monthYearLabel
        textFormat: Text.PlainText
        color: Qt.darker(Colors.foreground, 1.4)
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBody
        font.letterSpacing: 1
      }

      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: -8
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: Constants.cornerRadius
        color: previousMouse.containsMouse
          ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08)
          : "transparent"

        Behavior on color {
          ColorAnimation {
            duration: root.duration(60)
            easing.type: Easing.InOutQuad
          }
        }

        Text {
          anchors.centerIn: parent
          text: "\uDB80\uDD41"
          textFormat: Text.PlainText
          color: Colors.foreground
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontTitle
        }

        MouseArea {
          id: previousMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.stepMonth(-1)
        }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: -8
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: Constants.cornerRadius
        color: nextMouse.containsMouse
          ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08)
          : "transparent"

        Behavior on color {
          ColorAnimation {
            duration: root.duration(60)
            easing.type: Easing.InOutQuad
          }
        }

        Text {
          anchors.centerIn: parent
          text: "\uDB80\uDD42"
          textFormat: Text.PlainText
          color: Colors.foreground
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontTitle
        }

        MouseArea {
          id: nextMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.stepMonth(1)
        }
      }
    }
  }

                                                                              
                                                                               
                                                                             
  property SequentialAnimation monthTransition: SequentialAnimation {

    ParallelAnimation {
      NumberAnimation {
        target: monthLabelShift
        property: "x"
        to: -root.monthTransitionDirection * root.monthSlideDistance
        duration: root.duration(120)
        easing.type: Easing.InCubic
      }

      NumberAnimation {
        target: gridShift
        property: "x"
        to: -root.monthTransitionDirection * root.monthSlideDistance
        duration: root.duration(120)
        easing.type: Easing.InCubic
      }

      NumberAnimation {
        target: monthLabel
        property: "opacity"
        to: 0
        duration: root.duration(120)
        easing.type: Easing.InCubic
      }

      NumberAnimation {
        target: gridArea
        property: "opacity"
        to: 0
        duration: root.duration(120)
        easing.type: Easing.InCubic
      }
    }

    ScriptAction {
      script: {
        var target = new Date(Date.UTC(root.viewYear, root.viewMonth + root.pendingMonthOffset, 1))
        root.viewYear = target.getUTCFullYear()
        root.viewMonth = target.getUTCMonth()
        monthLabelShift.x = root.monthTransitionDirection * root.monthSlideDistance
        gridShift.x = root.monthTransitionDirection * root.monthSlideDistance
      }
    }

    ParallelAnimation {
      NumberAnimation {
        target: monthLabelShift
        property: "x"
        to: 0
        duration: root.duration(180)
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: gridShift
        property: "x"
        to: 0
        duration: root.duration(180)
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: monthLabel
        property: "opacity"
        to: 1
        duration: root.duration(180)
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: gridArea
        property: "opacity"
        to: 1
        duration: root.duration(180)
        easing.type: Easing.OutCubic
      }
    }
  }
}
