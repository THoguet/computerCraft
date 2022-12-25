local reactor, monitor
local data = {}
local buttons = {}
local computerTerm = term.current()
local wButtons, wStats, wGraph
local injRate = 0.1
local maxBurnRate
local last_reactor_heatedCoolent
local auto = false

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
	buttons["auto"]["color"] = colors.orange
	if auto then
		buttons["+inj"]["active"] = false
		buttons["+inj"]["color"] = colors.gray
		buttons["-inj"]["active"] = false
		buttons["-inj"]["color"] = colors.gray
		buttons["auto"]["color"] = colors.green
	end
	if data.reactor_burn_rate == 0 then
		buttons["-inj"]["active"] = false
		buttons["-inj"]["color"] = colors.gray
	elseif data.reactor_burn_rate == data.reactor_max_burn_rate then
		buttons["+inj"]["active"] = false
		buttons["+inj"]["color"] = colors.gray
	end
	if data.reactor_on then
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
		if auto then
			update_data()
			last_reactor_heatedCoolent = last_reactor_heatedCoolent or data.reactor_heatedCoolent
			if data.reactor_heatedCoolent == 0 then
				addInj()
			elseif data.reactor_heatedCoolent > last_reactor_heatedCoolent then
				delInj()
				last_reactor_heatedCoolent = data.reactor_heatedCoolent
			else
				last_reactor_heatedCoolent = data.reactor_heatedCoolent
			end
		end
		sleep(1)
	end
end

local function startStop()
	if data.reactor_on then
		reactor.scram()
	else
		reactor.activate()
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
	drawGraph("DAMAGE", 1, 1, w, hGraph, data.reactor_damage, colors.gray, colors.red)
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

local function main()
	getPeripherals()
	monitor.setTextScale(0.5)
	local w, h = monitor.getSize()
	update_data()
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
	parallel.waitForAny(autoInj, clickEvent, drawAll)
end

main()
