function focusDispatchArgs(workspaceId) {
  var id = Number(workspaceId)
  if (!Number.isInteger(id) || id < 1) return []
  return ['dispatch', 'hl.dsp.focus({ workspace = "' + id + '" })']
}

if (typeof module !== 'undefined') module.exports = { focusDispatchArgs: focusDispatchArgs }
