local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
local state_path = runtime_dir .. "/keycount-events.json"
local temporary_path = state_path .. ".tmp"
local events = {}
local generation = 1
local last_second = 0

local function is_modifier(code)
  return code == 37 or code == 105 or code == 50 or code == 62 or code == 64
    or code == 108 or code == 133 or code == 134 or code == 66
end

local function write_events()
  local parts = {}
  for index = 1, #events do
    parts[index] = string.format("[%d,%d]", events[index][1], events[index][2])
  end
  local handle = io.open(temporary_path, "w")
  if not handle then
    return
  end
  handle:write(string.format("{\"gen\":%d,\"ev\":[%s]}\n", generation, table.concat(parts, ",")))
  handle:close()
  os.rename(temporary_path, state_path)
end

hl.on("input.keyboard.key", function(key, timestamp, state)
  if state ~= 0 and state ~= 1 then
    return
  end
  local code = tonumber(key) or 0
  if state == 0 and not is_modifier(code) then
    return
  end

  local now = os.time()
  if last_second > 0 and now - last_second >= 2 then
    events = {}
    generation = generation + 1
  end
  last_second = now
  events[#events + 1] = { code, state }
  if #events > 4000 then
    events = { { code, state } }
    generation = generation + 1
  end
  write_events()
end)
