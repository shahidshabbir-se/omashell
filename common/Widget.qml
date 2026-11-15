import QtQuick

                                                                                
                                        
  
                                                                                  
                                                                                 
                                                                              
                                                                            
                                                
Item {
  id: root

                                                                                 
  property string widgetId: ""

                                                               
                                                                            
  property var settings: ({})

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return (value === undefined || value === null) ? fallback : value
  }
}
