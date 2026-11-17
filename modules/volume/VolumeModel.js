function iconFor(percent, muted) {
  if (muted || percent <= 0) return ''
  if (percent <= 33) return ''
  if (percent <= 66) return ''
  return ''
}

function state(volume, muted) {
  var n = Number(volume)
  var percent = isFinite(n) ? Math.max(0, Math.min(100, Math.round(n * 100))) : 0
  return {
    percent: percent,
    progress: Math.min(1, percent / 100),
    icon: iconFor(percent, muted),
    label: percent + '%'
  }
}

// Switching or discovering a sink establishes a baseline, not a volume event.
function observe(previous, sink, volume, muted) {
  if (!sink) return { sink: null, volume: 0, muted: false, changed: false }
  var nextVolume = Number(volume)
  if (!isFinite(nextVolume)) nextVolume = 0
  var nextMuted = !!muted
  return {
    sink: sink,
    volume: nextVolume,
    muted: nextMuted,
    changed: !!previous && previous.sink === sink &&
      (previous.volume !== nextVolume || previous.muted !== nextMuted)
  }
}

if (typeof module !== 'undefined') module.exports = { iconFor, state, observe }
