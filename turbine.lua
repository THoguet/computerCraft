-- Gist get => pastebin get t4RjeKsw gist

local turbine, monitor
local data = {}
local buttons = {}
local computerTerm = term.current()
local wButtons, wStats, wGraph
local seconds = false
local DUMPING = {
	IDLE = 0,
	DUMPING_EXCESS = 1,
	DUMPING = 2
}

local function round(val, decimal)
	if (decimal) then
		return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
	else
		return math.floor(val + 0.5)
	end
end

local function getPeripherals()
	turbine = peripheral.find("turbineValve")
	monitor = peripheral.find("monitor")
end

local function update_data()
	data = {
		turbine_dumpingMode = turbine.getDumpingMode(),
		turbine_energyStored = turbine.getEnergy(),
		turbine_energyStoredPercentage = turbine.getEnergyFilledPercentage(),
		turbine_flowRate = turbine.getFlowRate(),
		turbine_maxFlowRate = turbine.getMaxFlowRate(),
		turbine_steamInputRate = turbine.getLastSteamInputRate(),
		turbine_steamPercentage = turbine.getSteamFilledPercentage(),
		turbine_production = turbine.getProductionRate(),
		turbine_maxProduction = turbine.getMaxProduction(),
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

local function toggleDumping()
	turbine.setDumpingMode((DUMPING[data.turbine_dumpingMode] + 1) % 3)
end

local function updateButtons()
	if data.turbine_dumpingMode == "IDLE" then
		buttons["dumping"]["color"] = colors.green
		buttons["dumping"]["title"] = "IDLE"
	elseif data.turbine_dumpingMode == "DUMPING_EXCESS" then
		buttons["dumping"]["color"] = colors.yellow
		buttons["dumping"]["title"] = "DUMPING EXCESS"
	else
		buttons["dumping"]["color"] = colors.red
		buttons["dumping"]["title"] = "DUMPING"
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

local function convertBucket(quantity)
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

local function convertRF(quantity, rftick)
	-- quantity is in joule convert to RF
	quantity = quantity * 0.4
	if rftick == nil then
		rftick = true
	end
	local timeUnit = ''
	if rftick then
		if seconds then
			quantity = quantity / 20
			timeUnit = '/s'
		else
			timeUnit = '/t'
		end
	end
	if quantity > 10 ^ 15 then
		return string.format("%.2f PRF%s", quantity / 10 ^ 15, timeUnit)
	elseif quantity > 10 ^ 12 then
		return string.format("%.2f TRF%s", quantity / 10 ^ 12, timeUnit)
	elseif quantity > 10 ^ 9 then
		return string.format("%.2f GRF%s", quantity / 10 ^ 9, timeUnit)
	elseif quantity > 10 ^ 6 then
		return string.format("%.2f MRF%s", quantity / 10 ^ 6, timeUnit)
	elseif quantity > 1000 then
		return string.format("%.2f KRF%s", quantity / 1000, timeUnit)
	else
		return string.format("%.2f RF%s", quantity, timeUnit)
	end
end

local function drawStats()
	term.redirect(wStats)
	term.clear()
	term.setCursorPos(1, 1)
	colored(string.format("DUMPING MODE : %s", data.turbine_dumpingMode))
	lineBack()
	lineBack()
	colored(string.format("PRODUCTION : %s", convertRF(data.turbine_production)))
	lineBack()
	lineBack()
	writePercentage("PRODUCTION : ", data.turbine_production / data.turbine_maxProduction, 0.9, 0.5)
	colored(string.format("FLOW-RATE  : %s", convertBucket(data.turbine_flowRate)))
	lineBack()
	lineBack()
	writePercentage("FLOW-RATE : ", data.turbine_flowRate / data.turbine_maxFlowRate, 0.9, 0.5)
	colored(string.format("ENERGY STORED : %s", convertRF(data.turbine_energyStored, false)))
	lineBack()
	lineBack()
	writePercentage("ENERGY STORED : ", data.turbine_energyStoredPercentage, 0.9, 0.5)
	colored(string.format("STEAM INPUT : %s", convertBucket(data.turbine_steamInputRate)))
	lineBack()
	lineBack()
	writePercentage("STEAM STORED : ", data.turbine_steamPercentage, 0.9, 0.5)
	term.redirect(computerTerm)
end

local function drawGraphs()
	term.redirect(wGraph)
	local w, h = term.getSize()
	local nbGraph = 4
	local hGraph = round(h / (nbGraph + nbGraph / 2)) - 1
	local spaceBetween = round(hGraph / (nbGraph - 1)) + 2
	drawGraph("ENERGY STORED", 1, 1, w, hGraph, data.turbine_energyStoredPercentage, colors.gray, colors.yellow)
	drawGraph("FLOW RATE", 1, 1 + (hGraph + spaceBetween), w, hGraph, data.turbine_flowRate / data.turbine_maxFlowRate,
		colors.gray, colors.white)
	drawGraph("STEAM", 1, 1 + (hGraph + spaceBetween) * 2, w, hGraph, data.turbine_steamPercentage, colors.gray,
		colors.lightGray)
	drawGraph("PRODUCTION", 1, 1 + (hGraph + spaceBetween) * 3, w, hGraph,
		data.turbine_production / data.turbine_maxProduction, colors.gray, colors.green)
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
	term.clear()
	monitor.setTextScale(0.5)
	local w, h = monitor.getSize()
	update_data()
	wStats = makeSection("Infos", 1, 1, round(w / 3) - 1, round((h / 3) * 2) - 1, monitor)
	wButtons = makeSection("Buttons", 1, round((h / 3) * 2) + 1, round(w / 3) - 1, round(h / 3), monitor)
	wGraph = makeSection("Graphics", round(w / 3) + 1, 1, round(w / 3 * 2), h, monitor)
	w, h = wButtons.getSize()
	setButton("dumping", "Dumping Idle", toggleDumping, 1, 1, w, h, colors.green, colors.white)
	parallel.waitForAny(clickEvent, drawAll)
end

main()
