import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Power
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: PowerProfileService.mistletoePerformanceMode ? "rocket" : "rocket-off"
  tooltipText: "Mistletoe Performance Mode"
  hot: PowerProfileService.mistletoePerformanceMode
  onClicked: PowerProfileService.toggleMistletoePerformance()
}
