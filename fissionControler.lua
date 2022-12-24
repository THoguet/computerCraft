local reactor, turbine, mon
local data = {}
buttons = {}
local computerTerm = term.current()
local wButtons

local function getPeripherals()
	rea     = peripheral.find("fissionReactorLogicAdapter")
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

		turbine_energy = turbine.getEnergyFilledPercentage(),
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

local function drawbutton(dButton)
	paintutils.drawFilledBox(dButton["x"], dButton["y"], dButton["x"] + dButton["w"], dButton["y"] + dButton["h"],
		dButton["color"])
	local xTitleCentered = math.floor((dButton["w"] - string.len(dButton["title"])) / 2)
	term.setCursorPos(dButton["x"] + xTitleCentered, dButton["y"] + math.floor(dButton["h"] / 2))
	term.setTextColor(dButton["textColor"])
	term.write(dButton["title"])
end

local function updateButtons()
	term.redirect(wButtons)
	for name, dButton in pairs(buttons) do
		drawbutton(dButton)
	end
	term.redirect(computerTerm)
end

local function colored(text, fg, bg)
	term.setTextColor(fg or colors.white)
	term.setBackgroundColor(bg or colors.black)
	term.write(text)
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
		paintutils.drawFilledBox(x, y, math.floor(x + w * percentage), y + h, color)
	else
		paintutils.drawFilledBox(x, y, x + w, math.floor(y + h * percentage), color)
	end
	term.redirect(computerTerm)
end

local function main()
	getPeripherals()
	local w, h = mon.getSize()
	wButtons = makeSection("Buttons", 1, 1, math.floor(w / 3), h, mon)
	w, h = wButtons.getSize()
	local hButton = math.floor(h / 4)
	local spaceBetween = math.ceil(hButton / 2)
	setButton("+ Inj", "+ Inj", nil, 1, 1, w, hButton, colors.green, colors.white)
	setButton("- Inj", "- Inj", nil, 1, 1 + hButton + spaceBetween, w, hButton, colors.red, colors.white)
	setButton("Auto", "Auto Inj", nil, 1, 1 + (spaceBetween + hButton) * 2, w, hButton, colors.orange, colors.white)
	updateButtons()
end

main()
