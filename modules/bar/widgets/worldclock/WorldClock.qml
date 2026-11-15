import QtQuick
import qs.common
import qs.config
import qs.modules.bar.widgets.worldclock

                                                                               
IconWidget {
  id: root

  glyph: "\uDB80\uDDE7"
  tooltip: WorldClockService.homeCity !== ""
    ? "World clock · " + WorldClockService.homeCity
    : "World clock"
}
