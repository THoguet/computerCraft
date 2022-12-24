local reactor, turbine, mon
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
	turbine = peripheral.find("turbineValve")
	mon     = peripheral.find("monitor")
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

		turbine_energy = turbine.getEnergyFilledPercentage(),

		-- reactor_on = true,

		-- reactor_burn_rate = 0.3,
		-- reactor_max_burn_rate = 1920,

		-- reactor_temp = 340,
		-- reactor_damage = 0,
		-- reactor_coolant = 0.98,
		-- reactor_waste = 0.05,
		-- reactor_fuel = 0.96,
		-- reactor_heatedCoolent = 0,

		-- turbine_energy = 0.5,
	}
end

local function setButton(name, title, func, x, y, w, h, color, textColor)
	buttons[name] = {}
	buttons[name]["title"] = title
	buttons[name]["func"] = func
	buttons[name]["active"] = false
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

local function drawButtons()
	term.redirect(wButtons)
	for name, dButton in pairs(buttons) do
		drawButton(dButton)
	end
	term.redirect(computerTerm)
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
		reactor.setInjectionRate(actualBurnRate + injRate)
	end
end

local function delInj()
	local actualBurnRate = reactor.getBurnRate()
	if (actualBurnRate - injRate >= 0) then
		reactor.setInjectionRate(actualBurnRate - injRate)
	end
end

local function updateButtons()
	update_data()
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

local function drawGraph(name, x, y, w, h, percentage, colorBg, color, periph)
	local x, y = periph.getSize()
	term.redirect(periph)
	if not (name == nil) then
		term.setCursorPos(x, y)
		print(name)
		x = x + 1
		y = y + 1
	end
	paintutils.drawFilledBox(x, y, x + w, y + h, colorBg)
	-- is graph veritcal ?
	if (w > h) then
		paintutils.drawFilledBox(x, y, round(x + w * percentage), y + h, color)
	else
		paintutils.drawFilledBox(x, y, x + w, round(y + h * percentage), color)
	end
	term.redirect(computerTerm)
end

local function toggleAuto()
	auto = not auto
end

local function autoInj()
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
end

local function startStop()
	update_data()
	if data.reactor_on then
		reactor.scram()
	else
		reactor.activate()
	end
end

local function main()
	getPeripherals()
	mon.setTextScale(0.5)
	local w, h = mon.getSize()
	print(w, h)
	wStats = makeSection("Infos", 1, 1, round(w / 3) - 1, round(h / 2) - 1, mon)
	wButtons = makeSection("Buttons", 1, round(h / 2) + 1, round(w / 3) - 1, round(h / 2), mon)
	wGraph = makeSection("Graphics", round(w / 3) + 1, 1, round(w / 3 * 2), h, mon)
	w, h = wButtons.getSize()
	local nbButtons = 4
	local hButton = round(h / (nbButtons + 1)) - 1
	local spaceBetween = round(hButton / (nbButtons - 1)) + 1
	print(h, hButton, spaceBetween)
	setButton("+inj", "+ Inj", addInj, 1, 1, w, hButton, colors.gray, colors.white)
	setButton("-inj", "- Inj", delInj, 1, 1 + hButton + spaceBetween, w, hButton, colors.gray, colors.white)
	setButton("auto", "Auto Inj", toggleAuto, 1, 1 + (spaceBetween + hButton) * 2, w, hButton, colors.gray, colors.white)
	setButton("startstop", "Start", startStop, 1, 1 + (spaceBetween + hButton) * 3, w, hButton, colors.green, colors.white)
	updateButtons()
	drawButtons()
end

main()
