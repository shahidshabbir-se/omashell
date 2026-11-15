import QtQuick
import qs.common
import qs.config
import qs.modules.bar.widgets.weather

                                                                              
                                                                                   
IconWidget {
  id: root

  glyph: WeatherService.glyph
                                                                     
  tooltip: WeatherService.locationName !== ""
    ? WeatherService.locationName + " · " + WeatherService.tempNumber + WeatherService.tempUnit
    : "Weather"
}
