-- Gist get => pastebin get t4RjeKsw gist

local reactor, monitor
local data = {}
local buttons = {}
local computerTerm = term.current()
local wButtons, wStats, wGraph, wInfos, wRules
local injRate = 0.1
local maxBurnRate
local last_reactor_heatedCoolent, last_reactor_coolant
local auto = false
local state, startAsked, stopAsked

local STATES = {
	READY = 1, -- Reactor is off and can be started
	RUNNING = 2, -- Reactor is running and all rules are met
	ESTOP = 3, -- Reactor is stopped due to rule(s) being violated
	UNKNOWN = 4, -- Reactor peripherals are missing
}
local function round(val, decimal)
	if (decimal) then
		return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
	else
		return math.floor(val + 0.5)
	end
end

local function getPeripherals()
	reactor = peripheral.find("fissionReactorLogicAdapter")
	monitor = peripheral.find("monitor")
end

local function update_data()
	data = {

		reactor_on = reactor.getStatus(),

		reactor_burn_rate = reactor.getBurnRate(),
		reactor_max_burn_rate = reactor.getMaxBurnRate(),

		reactor_temp = reactor.getTemperature(),
		reactor_damage = reactor.getDamagePercent(),
		reactor_coolant = reactor.getCoolantFilledPercentage(),
		reactor_waste = reactor.getWasteFilledPercentage(),
		reactor_fuel = reactor.getFuelFilledPercentage(),
		reactor_heatedCoolent = reactor.getHeatedCoolantFilledPercentage(),
	}
end

local function setButton(name, title, func, x, y, w, h, color, textColor)
	buttons[name] = {}
	buttons[name]["title"] = title
	buttons[name]["func"] = func
	buttons[name]["active"] = true
	buttons[name]["x"] = x
	buttons[name]["y"] = y
	buttons[name]["w"] = w
	buttons[name]["h"] = h
	buttons[name]["color"] = color
	buttons[name]["textColor"] = textColor
end

local function drawButton(dButton)
	paintutils.drawFilledBox(dButton["x"], dButton["y"], dButton["x"] + dButton["w"], dButton["y"] + dButton["h"],
		dButton["color"])
	local xTitleCentered = round((dButton["w"] - string.len(dButton["title"])) / 2)
	term.setCursorPos(dButton["x"] + xTitleCentered, dButton["y"] + round(dButton["h"] / 2))
	term.setTextColor(dButton["textColor"])
	term.write(dButton["title"])
end

local function colored(text, fg, bg)
	term.setTextColor(fg or colors.white)
	term.setBackgroundColor(bg or colors.black)
	term.write(text)
end

local function addInj()
	local actualBurnRate = reactor.getBurnRate()
	maxBurnRate = reactor.getMaxBurnRate()
	if (actualBurnRate + injRate <= maxBurnRate) then
		reactor.setBurnRate(actualBurnRate + injRate)
	end
end

local function delInj()
	local actualBurnRate = reactor.getBurnRate()
	if (actualBurnRate - injRate >= 0) then
		reactor.setBurnRate(actualBurnRate - injRate)
	end
end

local function updateButtons()
	buttons["+inj"]["active"] = true
	buttons["+inj"]["color"] = colors.green
	buttons["-inj"]["active"] = true
	buttons["-inj"]["color"] = colors.red
	buttons["auto"]["active"] = true
	buttons["auto"]["color"] = colors.orange
	if auto then
		buttons["+inj"]["active"] = false
		buttons["+inj"]["color"] = colors.gray
		buttons["-inj"]["active"] = false
		buttons["-inj"]["color"] = colors.gray
		buttons["auto"]["color"] = colors.green
		buttons["auto"]["active"] = true
	end
	if data.reactor_burn_rate == 0 then
		buttons["-inj"]["active"] = false
		buttons["-inj"]["color"] = colors.gray
	elseif data.reactor_burn_rate == data.reactor_max_burn_rate then
		buttons["+inj"]["active"] = false
		buttons["+inj"]["color"] = colors.gray
	end
	if state == STATES.ESTOP then
		buttons["startstop"]["title"] = "RESET"
		buttons["startstop"]["color"] = colors.yellow
		buttons["+inj"]["active"] = false
		buttons["+inj"]["color"] = colors.gray
		buttons["-inj"]["active"] = false
		buttons["-inj"]["color"] = colors.gray
		buttons["auto"]["active"] = false
		buttons["auto"]["color"] = colors.gray
	elseif data.reactor_on then
		buttons["startstop"]["title"] = "S.C.R.A.M."
		buttons["startstop"]["color"] = colors.red
	else
		buttons["startstop"]["title"] = "Power Up"
		buttons["startstop"]["color"] = colors.green
	end
end

local function drawButtons()
	term.redirect(wButtons)
	updateButtons()
	for name, dButton in pairs(buttons) do
		drawButton(dButton)
	end
	term.redirect(computerTerm)
end

local function makeSection(name, x, y, w, h, periph)
	term.redirect(periph)
	for row = 1, h do
		term.setCursorPos(x, y + row - 1)
		local char = (row == 1 or row == h) and "\127" or " "
		colored("\127" .. string.rep(char, w - 2) .. "\127", colors.gray)
	end

	term.setCursorPos(x + 2, y)
	colored(" " .. name .. " ")
	term.redirect(computerTerm)
	return window.create(periph, x + 2, y + 2, w - 4, h - 4)
end

local function drawGraph(name, x, y, w, h, percentage, colorBg, color)
	if not (name == nil) then
		term.setCursorPos(x, y)
		colored(name)
		y = y + 1
	end
	paintutils.drawFilledBox(x, y, x + w, y + h, colorBg)
	if percentage ~= 0 then
		-- is graph veritcal ?
		if (w > h) then
			paintutils.drawFilledBox(x, y, round((x + w) * percentage), y + h, color)
		else
			paintutils.drawFilledBox(x, y, x + w, round((y + h) * percentage), color)
		end
	end
end

local function toggleAuto()
	auto = not auto
end

local function autoInj()
	while true do
		if auto and data.reactor_on then
			update_data()
			last_reactor_heatedCoolent = last_reactor_heatedCoolent or data.reactor_heatedCoolent
			last_reactor_coolant = last_reactor_coolant or data.reactor_coolant
			if (data.reactor_heatedCoolent == 0) and (data.reactor_coolant > 0.9) then
				addInj()
			elseif (data.reactor_heatedCoolent > last_reactor_heatedCoolent) or (data.reactor_coolant < last_reactor_coolant) then
				delInj()
				last_reactor_heatedCoolent = data.reactor_heatedCoolent
				last_reactor_coolant = data.reactor_coolant
			else
				last_reactor_heatedCoolent = data.reactor_heatedCoolent
				last_reactor_coolant = data.reactor_coolant
			end
		end
		sleep(1)
	end
end

local function startStop()
	if state == STATES.ESTOP then
		state = STATES.READY
	elseif data.reactor_on then
		stopAsked = true
	else
		startAsked = true
	end
end

local function checkxy(x, y)
	local xWindow, yWindow = wButtons.getPosition()
	for name, dButton in pairs(buttons) do
		if y >= dButton["y"] + yWindow and y <= dButton["y"] + yWindow + dButton["h"] then
			if x >= dButton["x"] + xWindow and x <= dButton["x"] + xWindow + dButton["w"] then
				if dButton["active"] then
					dButton["func"]()
					return true
				else
					return false
				end
			end
		end
	end
	return false
end

local function clickEvent()
	while true do
		local myEvent = { os.pullEvent("monitor_touch") }
		checkxy(myEvent[3], myEvent[4])
	end
end

local function lineBack()
	local x, y = term.getCursorPos()
	term.setCursorPos(1, y + 1)
end

local function writeStatus()
	colored("STATUS         : ")
	if data.reactor_on then
		colored("ONLINE", colors.green)
	else
		colored("OFFLINE", colors.red)
	end
	lineBack()
	lineBack()
end

local function operation(value1, value2, invert)
	invert = invert or false
	value1 = value1 or 0
	value2 = value2 or 0
	if invert then
		return value1 < value2
	else
		return value1 > value2
	end
end

local function writePercentage(name, percentage, valueG, valueO, invert)
	percentage = round(percentage, 3) or 0
	colored(name .. " : ")
	if operation(percentage, valueG, invert) then
		term.setTextColor(colors.green)
	else if operation(percentage, valueO, invert) then
			term.setTextColor(colors.orange)
		else
			term.setTextColor(colors.red)
		end
	end
	term.write((percentage * 100) .. " %")
	term.setTextColor(colors.white)
	lineBack()
	lineBack()
end

local function drawStats()
	term.redirect(wStats)
	term.clear()
	term.setCursorPos(1, 1)
	writeStatus()
	writePercentage("DAMAGE        ", data.reactor_damage / 100, 0.05, 0.25, true)
	writePercentage("INJ-RATE      ", data.reactor_burn_rate / data.reactor_max_burn_rate, 0.8, 0.9, true)
	writePercentage("COOLANT       ", data.reactor_coolant, 0.9, 0.7)
	writePercentage("HEATED COOLANT", data.reactor_heatedCoolent, 0.1, 0.5, true)
	writePercentage("FUEL          ", data.reactor_fuel, 0.5, 0.2)
	writePercentage("WASTE         ", data.reactor_waste, 0.1, 0.3, true)
	term.redirect(computerTerm)
end

local function drawGraphs()
	term.redirect(wGraph)
	local w, h = term.getSize()
	local nbGraph = 6
	local hGraph = round(h / (nbGraph + 3)) - 1
	local spaceBetween = round(hGraph / (nbGraph - 1)) + 2
	drawGraph("DAMAGE", 1, 1, w, hGraph, data.reactor_damage / 100, colors.gray, colors.red)
	drawGraph("INJ-RATE", 1, 1 + (hGraph + spaceBetween), w, hGraph, data.reactor_burn_rate / data.reactor_max_burn_rate,
		colors.gray, colors.pink)
	drawGraph("COOLANT", 1, 1 + (hGraph + spaceBetween) * 2, w, hGraph, data.reactor_coolant, colors.gray, colors.blue)
	drawGraph("HEATED COOLANT", 1, 1 + (hGraph + spaceBetween) * 3, w, hGraph, data.reactor_heatedCoolent, colors.gray,
		colors.orange)
	drawGraph("FUEL", 1, 1 + (hGraph + spaceBetween) * 4, w, hGraph, data.reactor_fuel, colors.gray, colors.purple)
	drawGraph("WASTE", 1, 1 + (hGraph + spaceBetween) * 5, w, hGraph, data.reactor_waste, colors.gray, colors.brown)
	term.redirect(computerTerm)
end

local function drawAll()
	while true do
		update_data()
		drawStats()
		drawButtons()
		drawGraphs()
		sleep(0.1)
	end
end

local rules = {}

local function add_rule(name, fn)
	table.insert(rules, function()
		local ok, rule_met, value = pcall(fn)
		if ok then
			return rule_met, string.format("%s (%s)", name, value)
		else
			return false, name
		end
	end)
end

add_rule("REACTOR TEMPERATURE   <= 745K", function()
	local value = string.format("%3dK", math.ceil(data.reactor_temp))
	return data.reactor_temp <= 745, value
end)

add_rule("REACTOR DAMAGE        <=  10%", function()
	local value = string.format("%3d%%", math.ceil(data.reactor_damage))
	return data.reactor_damage / 100 <= 0.10, value
end)

add_rule("REACTOR COOLANT LEVEL >=  80%", function()
	local value = string.format("%3d%%", math.floor(data.reactor_coolant * 100))
	return data.reactor_coolant >= 0.80, value
end)

add_rule("REACTOR HCOOLANT LEVEL<=  95%", function()
	local value = string.format("%3d%%", math.floor(data.reactor_heatedCoolent * 100))
	return data.reactor_heatedCoolent <= 0.95, value
end)

add_rule("REACTOR WASTE LEVEL   <=  90%", function()
	local value = string.format("%3d%%", math.ceil(data.reactor_waste * 100))
	return data.reactor_waste <= 0.90, value
end)

local function all_rules_met()
	for i, rule in ipairs(rules) do
		if not rule() then
			return false
		end
	end
	-- Allow manual emergency stop with SCRAM button
	return state ~= STATES.RUNNING or data.reactor_on
end

local function update_info()
	local prev_term = term.redirect(wInfos)

	term.clear()
	term.setCursorPos(1, 1)

	if state == STATES.UNKNOWN then
		colored("ERROR RETRIEVING DATA", colors.red)
		return
	end

	colored("REACTOR: ")
	colored(data.reactor_on and "ON " or "OFF", data.reactor_on and colors.green or colors.red)
	colored("  R. LIMIT: ")
	colored(string.format("%4.1f", data.reactor_burn_rate), colors.blue)
	colored("/", colors.lightGray)
	colored(string.format("%4.1f", data.reactor_max_burn_rate), colors.blue)

	term.setCursorPos(1, 3)

	colored("STATUS: ")
	if state == STATES.READY then
		colored("READY, press TURN ON to start", colors.blue)
	elseif state == STATES.RUNNING then
		colored("RUNNING, press S.C.R.A.M. to stop", colors.green)
	elseif state == STATES.ESTOP and not all_rules_met() then
		colored("EMERGENCY STOP, safety rules violated", colors.red)
	elseif state == STATES.ESTOP then
		colored("EMERGENCY STOP, press RESET", colors.red)
	end -- STATES.UNKNOWN cases handled above

	term.redirect(prev_term)
end

local estop_reasons = {}

local function update_rules()
	local prev_term = term.redirect(wRules)

	term.clear()

	if state ~= STATES.ESTOP then
		estop_reasons = {}
	end

	for i, rule in ipairs(rules) do
		local ok, text = rule()
		term.setCursorPos(1, i)
		if ok and not estop_reasons[i] then
			colored("[  OK  ] ", colors.green)
			colored(text, colors.lightGray)
		else
			colored("[ FAIL ] ", colors.red)
			colored(text, colors.red)
			estop_reasons[i] = true
		end
	end

	term.redirect(prev_term)
end

local function updateSafetyLoop()
	while true do
		if data.reactor_on == nil then
			-- Reactor is not connected
			state = STATES.UNKNOWN
		elseif not state then
			-- Program just started, get current state from lever
			state = STATES.READY
		elseif (state == STATES.READY and startAsked) or (state == STATES.READY and reactor.getStatus()) then
			-- READY -> RUNNING
			state = STATES.RUNNING
			-- Activate reactor
			pcall(reactor.activate)
			startAsked = false
			data.reactor_on = true
		elseif (state == STATES.RUNNING and stopAsked) or (state == STATES.RUNNING and not reactor.getStatus()) then
			-- RUNNING -> READY
			state = STATES.READY
			pcall(reactor.scram)
			stopAsked = false
			data.reactor_on = false
		end
		-- Always enter ESTOP if safety rules are not met
		if state ~= STATES.UNKNOWN and not all_rules_met() then
			state = STATES.ESTOP
		end

		-- SCRAM reactor if not running
		if state ~= STATES.RUNNING and reactor then
			pcall(reactor.scram)
		end

		-- Update info and rules windows
		pcall(update_info)
		pcall(update_rules)
		sleep(1)
	end
end

local function main()
	getPeripherals()
	term.clear()
	local width = term.getSize()
	monitor.setTextScale(0.5)
	local w, h = monitor.getSize()
	update_data()
	wInfos = makeSection("INFORMATION", 2, 2, width - 2, 7, computerTerm)
	wRules = makeSection("SAFETY RULES", 2, 10, width - 2, 9, computerTerm)
	wStats = makeSection("Infos", 1, 1, round(w / 3) - 1, round(h / 2) - 1, monitor)
	wButtons = makeSection("Buttons", 1, round(h / 2) + 1, round(w / 3) - 1, round(h / 2), monitor)
	wGraph = makeSection("Graphics", round(w / 3) + 1, 1, round(w / 3 * 2), h, monitor)
	w, h = wButtons.getSize()
	local nbButtons = 4
	local hButton = round(h / (nbButtons + 1)) - 1
	local spaceBetween = round(hButton / (nbButtons - 1)) + 1
	setButton("+inj", "+ Inj", addInj, 1, 1, w, hButton, colors.gray, colors.white)
	setButton("-inj", "- Inj", delInj, 1, 1 + hButton + spaceBetween, w, hButton, colors.gray, colors.white)
	setButton("auto", "Auto Inj", toggleAuto, 1, 1 + (spaceBetween + hButton) * 2, w, hButton, colors.gray, colors.white)
	setButton("startstop", "Start", startStop, 1, 1 + (spaceBetween + hButton) * 3, w, hButton, colors.green, colors.white)
	parallel.waitForAny(autoInj, clickEvent, drawAll, updateSafetyLoop)
end

main()
