import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.ui.widgets

PanelWindow {
  id: root

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: Constants.barHeight
  color: Colors.background

  signal calendarToggleRequested(real anchorX)
  signal weatherToggleRequested(real anchorX)
  signal worldClockToggleRequested(real anchorX)

  Workspaces {
    id: workspacesWidget
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    screen: root.screen
  }


  Row {
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    spacing: 14


    Clock {
      id: clockWidget

      onCalendarToggleRequested:
        root.calendarToggleRequested(root.contentItem.mapFromItem(clockWidget, clockWidget.width / 2, 0).x)
    }

    Weather {
      id: weatherWidget

      onToggleRequested:
        root.weatherToggleRequested(root.contentItem.mapFromItem(weatherWidget, weatherWidget.width / 2, 0).x)
    }

    WorldClock {
      id: worldClockWidget

      onToggleRequested:
        root.worldClockToggleRequested(root.contentItem.mapFromItem(worldClockWidget, worldClockWidget.width / 2, 0).x)
    }
  }
}
