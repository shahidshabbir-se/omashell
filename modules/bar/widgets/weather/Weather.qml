import QtQuick
import qs.common
import qs.config
import qs.modules.bar.widgets.weather

// Weather icon. Only state: the glyph, the hover text and the on/in-use flag.
// Canvas, icon slot, mark width, press feedback and centring come from IconWidget.
IconWidget {
  id: root

  glyph: WeatherService.glyph
  // Reads either way round: the service may not have a location yet.
  tooltip: WeatherService.locationName !== ""
    ? WeatherService.locationName + " · " + WeatherService.tempNumber + WeatherService.tempUnit
    : "Weather"
}
