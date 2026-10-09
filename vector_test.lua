-- Vector Thruster Test: checks every computer control on a Create Propulsion
-- vector thruster (creative, FE or liquid), then drops into manual control.
-- Results are also saved to vector_test.log.

-- Leave nil to use the first vector thruster found
THRUSTER = nil


local TYPES = { "creative_vector_thruster", "vector_thruster", "liquid_vector_thruster" }

local name, kind
if THRUSTER then
  name = THRUSTER
  kind = peripheral.getType(THRUSTER)
else
  for _, n in ipairs(peripheral.getNames()) do
    for _, t in ipairs(TYPES) do
      if peripheral.hasType(n, t) then name, kind = n, t break end
    end
    if name then break end
  end
end
if not name then
  error("No vector thruster found. Put a wired modem on it (or place it next to the computer).", 0)
end
local t = peripheral.wrap(name)
local isCreative = kind == "creative_vector_thruster"

local log = fs.open("vector_test.log", "w")
local function out(s, colour)
  if colour and term.isColour() then term.setTextColour(colour) end
  print(s)
  term.setTextColour(colours.white)
  log.writeLine(s)
  log.flush()
end
local function pass(s) out("  OK   " .. s, colours.lime) end
local function fail(s) out("  FAIL " .. s, colours.red) end
local function info(s) out("  " .. s, colours.lightGrey) end
local function fmt(n) return string.format("%.3f", n) end

-- Wait until the nozzle has finished moving towards its target, or give up.
local function settle(maxTicks)
  local lastX, lastY
  for i = 1, maxTicks do
    sleep(0.05)
    local x, y = t.getVectorX(), t.getVectorY()
    if x == lastX and y == lastY then return i end
    lastX, lastY = x, y
  end
  return maxTicks
end

local function reset()
  t.setThrust(0)
  t.setVector(0, 0)
  if isCreative then t.clearThrustOutput() end
end

term.clear()
term.setCursorPos(1, 1)
out("Vector Thruster Test", colours.yellow)
out("Peripheral: " .. name .. " (" .. kind .. ")")
local methods = peripheral.getMethods(name)
table.sort(methods)
out("Methods (" .. #methods .. "): " .. table.concat(methods, ", "))
out("")

-- 1. Current state
out("1. Current state", colours.yellow)
info("vector " .. fmt(t.getVectorX()) .. ", " .. fmt(t.getVectorY()) ..
  "  target " .. fmt(t.getTargetVectorX()) .. ", " .. fmt(t.getTargetVectorY()))
info("thrust " .. t.getThrust() .. "/15  power " .. fmt(t.getPower()))
if isCreative then
  info("max creative output " .. fmt(t.getMaxThrustOutputPn()) ..
    "  custom output active: " .. tostring(t.isCustomThrustOutputActive()))
end

-- 2. Nozzle angle (thrust stays at 0, so the ship doesn't move)
out("2. Nozzle angle", colours.yellow)
t.setThrust(0)
t.setVector(1, 0)
local ticks = settle(60)
local x = t.getVectorX()
if math.abs(x - 1) < 0.02 then pass("X to +1 in " .. ticks .. " ticks") else fail("X to +1 ended at " .. fmt(x)) end
t.setVector(0, -1)
settle(60)
local y = t.getVectorY()
if math.abs(y + 1) < 0.02 then pass("Y to -1") else fail("Y to -1 ended at " .. fmt(y)) end
t.setVector(5, -5)
settle(60)
if t.getTargetVectorX() <= 1 and t.getTargetVectorY() >= -1 then
  pass("out-of-range values clamp to -1..1")
else
  fail("no clamping: target " .. fmt(t.getTargetVectorX()))
end
-- Step size: the angle is stored as a 0-15 signal per side
t.setVector(0.04, 0)
settle(60)
local small = t.getTargetVectorX()
t.setVector(0.05, 0)
settle(60)
local larger = t.getTargetVectorX()
info("setVector(0.04) -> " .. fmt(small) .. ", setVector(0.05) -> " .. fmt(larger))
info("so the angle moves in steps of 1/15 (about 2 degrees, max 30 degrees)")
t.setVector(0, 0)
settle(60)

-- 3. Throttle
out("3. Throttle", colours.yellow)
write("  Ship may move. Run throttle test? (y/n) ")
local answer = read()
log.writeLine("  Run throttle test? " .. answer)
if answer:lower() == "y" then
  for _, level in ipairs({ 0, 1, 8, 15 }) do
    t.setThrust(level)
    sleep(0.2)
    info("setThrust(" .. level .. ") -> getThrust " .. t.getThrust() .. ", getPower " .. fmt(t.getPower()))
  end
  t.setThrustNormalized(0.5)
  sleep(0.2)
  info("setThrustNormalized(0.5) -> getThrust " .. t.getThrust())
  t.setThrust(99)
  sleep(0.2)
  if t.getThrust() == 15 then pass("setThrust clamps to 0..15") else fail("setThrust(99) -> " .. t.getThrust()) end

  if isCreative then
    out("4. Creative thrust output", colours.yellow)
    local max = t.getMaxThrustOutputPn()
    t.setThrust(15)
    for _, frac in ipairs({ 0.1, 0.5, 1 }) do
      t.setThrustOutput(max * frac)
      sleep(0.2)
      info("setThrustOutput(" .. fmt(max * frac) .. ") -> active " .. tostring(t.isCustomThrustOutputActive()) ..
        ", power " .. fmt(t.getPower()))
    end
    t.clearThrustOutput()
    sleep(0.2)
    if not t.isCustomThrustOutputActive() then pass("clearThrustOutput returns to the value box setting") else fail("custom output still active") end
  end
  reset()
else
  info("skipped")
end

reset()
out("")
out("Done. Log saved to vector_test.log", colours.yellow)
out("")
log.close()

-- Manual control
print("Manual control: WASD = aim, Q/E = throttle -/+,")
print("R = reset, X = quit")
print("")
local vx, vy, thr = 0, 0, 0
local _, row = term.getCursorPos()
local function status()
  term.setCursorPos(1, row)
  term.clearLine()
  write(string.format("aim %5.2f %5.2f  now %5.2f %5.2f  thrust %2d/15  power %.2f",
    vx, vy, t.getVectorX(), t.getVectorY(), t.getThrust(), t.getPower()))
end

local timer = os.startTimer(0.1)
while true do
  local ev, p = os.pullEvent()
  if ev == "key" then
    if p == keys.a then vx = math.max(-1, vx - 1 / 15)
    elseif p == keys.d then vx = math.min(1, vx + 1 / 15)
    elseif p == keys.w then vy = math.max(-1, vy - 1 / 15)
    elseif p == keys.s then vy = math.min(1, vy + 1 / 15)
    elseif p == keys.q then thr = math.max(0, thr - 1)
    elseif p == keys.e then thr = math.min(15, thr + 1)
    elseif p == keys.r then vx, vy, thr = 0, 0, 0
    elseif p == keys.x then break
    end
    t.setVector(vx, vy)
    t.setThrust(thr)
  elseif ev == "timer" and p == timer then
    status()
    timer = os.startTimer(0.1)
  end
end

reset()
print("")
print("Thruster reset to 0.")
