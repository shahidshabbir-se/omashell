function indicatorWidth(widgetWidth, markWidth, widthHint, minimumWidth) {
  if (markWidth > 0) return Math.max(minimumWidth, Math.round(markWidth * 0.55))
  if (widthHint > 0) return Math.round(widthHint)
  return Math.max(minimumWidth, Math.round(widgetWidth * 0.55))
}

if (typeof module !== 'undefined') module.exports = { indicatorWidth: indicatorWidth }
