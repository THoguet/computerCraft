-- Gist get => pastebin get t4RjeKsw gist

local reactor, monitor
local data = {}
local buttons = {}
local computerTerm = term.current()
local wButtons, wStats, wGraph
local controlRodRate = 1
local controlRodPercentage
local auto = false
local path = "/moni/auto"
local seconds = false
MAXTEMP = 2000

local function round(val, decimal)
	if (decimal) then
		return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
	else
		return math.floor(val + 0.5)
	end
end

local function getPeripherals()
	reactor = peripheral.find("BiggerReactors_Reactor")
	monitor = peripheral.find("monitor")
end

local function update_data()
	data = {
		reactor_on = reactor.active(),

		reactor_stack_temp = reactor.stackTemperature(),
		reactor_ambient_temp = reactor.ambientTemperature(),
		reactor_casing_temp = reactor.casingTemperature(),
		reactor_fuel_temp = reactor.fuelTemperature(),


		reactor_fuel = reactor.fuelTank().fuel(),
		reactor_fuelCapacity = reactor.fuelTank().capacity(),
		reactor_fuelBurnedLastTick = reactor.fuelTank().burnedLastTick(),
		reactor_waste = reactor.fuelTank().waste(),

		reactor_batteryCapacity = reactor.battery().capacity(),
		reactor_batteryStored = reactor.battery().stored(),
		reactor_batteryProducedLastTick = reactor.battery().producedLastTick(),
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

local function addControl()
	if (controlRodPercentage + controlRodRate < 100) then
		reactor.setAllControlRodLevels(controlRodPercentage + controlRodRate)
		controlRodPercentage = controlRodPercentage + controlRodRate
	end
end

local function delControl()
	if (controlRodPercentage - controlRodRate > 0) then
		reactor.setAllControlRodLevels(controlRodPercentage - controlRodRate)
		controlRodPercentage = controlRodPercentage - controlRodRate
	end
end

local function updateButtons()
	buttons["+rod"]["active"] = true
	buttons["+rod"]["color"] = colors.green
	buttons["-rod"]["active"] = true
	buttons["-rod"]["color"] = colors.red
	buttons["auto"]["active"] = true
	buttons["auto"]["color"] = colors.orange
	buttons["startstop"]["active"] = true
	if data.reactor_on then
		buttons["startstop"]["title"] = "STOP"
		buttons["startstop"]["color"] = colors.red
	else
		buttons["startstop"]["title"] = "Power Up"
		buttons["startstop"]["color"] = colors.green
	end
	if auto then
		buttons["+rod"]["active"] = false
		buttons["+rod"]["color"] = colors.gray
		buttons["-rod"]["active"] = false
		buttons["-rod"]["color"] = colors.gray
		buttons["auto"]["color"] = colors.green
		buttons["auto"]["active"] = true
		buttons["startstop"]["color"] = colors.gray
		buttons["startstop"]["active"] = false
	end
	if controlRodPercentage == 0 then
		buttons["-rod"]["active"] = false
		buttons["-rod"]["color"] = colors.gray
	elseif controlRodPercentage == 100 then
		buttons["+rod"]["active"] = false
		buttons["+rod"]["color"] = colors.gray
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
	local file = fs.open(path, "w")
	file.write(auto)
	file.close()
end

local function autoRod()
	while true do
		if auto then
			update_data()
			local batteryFilledPercentage = data.reactor_batteryStored / data.reactor_batteryCapacity
			if batteryFilledPercentage > 0.995 then
				reactor.setActive(false)
			else
				reactor.setActive(true)
				local rounded = round(batteryFilledPercentage * 100, 1)
				reactor.setAllControlRodLevels(rounded)
				controlRodPercentage = rounded
			end
		end
		sleep(1)
	end
end

local function startStop()
	reactor.setActive(not data.reactor_on)
end

local function checkxy(x, y)
	local xStats, yStats = wStats.getPosition()
	local widthStats, heightStats = wStats.getSize()
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
	if y >= yStats and y <= yStats + heightStats then
		if x >= xStats and x <= xStats + widthStats then
			seconds = not seconds
			return true
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

local function convertMilliBucketBucket(quantity)
	local timeUnit = 't'
	if seconds then
		quantity = quantity / 20
		timeUnit = 's'
	end
	if quantity > 1000 then
		return string.format("%.2f B/%s", quantity / 1000, timeUnit)
	else
		return string.format("%.2f mB/%s", quantity, timeUnit)
	end
end

local function convertRF(quantity)
	local timeUnit = 't'
	if seconds then
		quantity = quantity / 20
		timeUnit = 's'
	end
	if quantity > 1000000 then
		return string.format("%.2f MRF/%s", quantity / 1000000, timeUnit)
	elseif quantity > 1000 then
		return string.format("%.2f kRF/%s", quantity / 1000, timeUnit)
	else
		return string.format("%.2f RF/%s", quantity, timeUnit)
	end
end

local function drawStats()
	term.redirect(wStats)
	term.clear()
	term.setCursorPos(1, 1)
	writeStatus()
	colored(string.format("PROD ENERGY    : %s", convertRF(data.reactor_batteryProducedLastTick)))
	lineBack()
	lineBack()
	colored(string.format("FUEL           : %s", convertMilliBucketBucket(data.reactor_fuelBurnedLastTick)))
	lineBack()
	lineBack()
	writePercentage("BATTERY       ", data.reactor_batteryStored / data.reactor_batteryCapacity, 0.5, 0.3)
	writePercentage("RODS          ", controlRodPercentage / 100, 0.5, 0.3)
	writePercentage("FUEL          ", data.reactor_fuel / data.reactor_fuelCapacity, 0.5, 0.2)
	writePercentage("WASTE         ", data.reactor_waste / data.reactor_fuelCapacity, 0.1, 0.3, true)
	term.redirect(computerTerm)
end

local function drawGraphs()
	term.redirect(wGraph)
	local w, h = term.getSize()
	local nbGraph = 6
	local hGraph = round(h / (nbGraph + 3)) - 1
	local spaceBetween = round(hGraph / (nbGraph - 1)) + 2
	drawGraph("CASING TEMP", 1, 1, w, hGraph, data.reactor_casing_temp / MAXTEMP, colors.gray, colors.red)
	drawGraph("FUEL TEMP", 1, 1 + (hGraph + spaceBetween), w, hGraph, data.reactor_fuel_temp / MAXTEMP, colors.gray,
		colors.pink)
	drawGraph("RODS", 1, 1 + (hGraph + spaceBetween) * 2, w, hGraph, controlRodPercentage / 100, colors.gray,
		colors.lightGray)
	drawGraph("BATTERY", 1, 1 + (hGraph + spaceBetween) * 3, w, hGraph,
		data.reactor_batteryStored / data.reactor_batteryCapacity, colors.gray, colors.yellow)
	drawGraph("FUEL", 1, 1 + (hGraph + spaceBetween) * 4, w, hGraph, data.reactor_fuel / data.reactor_fuelCapacity,
		colors.gray, colors.purple)
	drawGraph("WASTE", 1, 1 + (hGraph + spaceBetween) * 5, w, hGraph, data.reactor_waste / data.reactor_fuelCapacity,
		colors.gray, colors.brown)
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

local stringtoboolean = { ["true"] = true, ["false"] = false }

local function main()
	if fs.exists(path) then
		local file = fs.open(path, "r")
		local tmp = file.readAll()
		file.close()
		auto = stringtoboolean[tmp]
	end
	getPeripherals()
	term.clear()
	monitor.setTextScale(0.5)
	local w, h = monitor.getSize()
	update_data()
	reactor.setAllControlRodLevels(100)
	controlRodPercentage = 100
	wStats = makeSection("Infos", 1, 1, round(w / 3) - 1, round(h / 2) - 1, monitor)
	wButtons = makeSection("Buttons", 1, round(h / 2) + 1, round(w / 3) - 1, round(h / 2), monitor)
	wGraph = makeSection("Graphics", round(w / 3) + 1, 1, round(w / 3 * 2), h, monitor)
	w, h = wButtons.getSize()
	local nbButtons = 4
	local hButton = round(h / (nbButtons + 1)) - 1
	local spaceBetween = round(hButton / (nbButtons - 1)) + 1
	setButton("+rod", "+ Rods", addControl, 1, 1, w, hButton, colors.gray, colors.white)
	setButton("-rod", "- Rods", delControl, 1, 1 + hButton + spaceBetween, w, hButton, colors.gray, colors.white)
	setButton("auto", "Auto Rods", toggleAuto, 1, 1 + (spaceBetween + hButton) * 2, w, hButton, colors.gray, colors.white)
	setButton("startstop", "Start", startStop, 1, 1 + (spaceBetween + hButton) * 3, w, hButton, colors.green, colors.white)
	parallel.waitForAny(autoRod, clickEvent, drawAll)
end

main()
