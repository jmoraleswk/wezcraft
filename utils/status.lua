local M = {}

local state_by_window = {}

function M.set_status_message(window, message, ttl_seconds)
  if not window then
    return
  end

  local id = window:window_id()
  state_by_window[id] = {
    message = message,
    until_time = os.time() + (ttl_seconds or 3),
  }
end

function M.get_status_message(window)
  if not window then
    return nil
  end

  local id = window:window_id()
  local state = state_by_window[id]
  if not state then
    return nil
  end

  if os.time() >= state.until_time then
    state_by_window[id] = nil
    return nil
  end

  return state.message
end

return M
