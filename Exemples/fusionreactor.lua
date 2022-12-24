--config
MinProcenttoBoost = 10 -- means min Tank amount vor max Inj Rate
MinProcentforLowMode = 75 -- means min Energycelllevel for produce over mrfneed
MRFBuffer = 0.1 -- for produce over mrfneed (for KRF = 0. ; MRF = 1)
xRC = 1 -- Amount of the Rotary-Condenstrator(Leave it on 1, if u dont use D-T-Fuel)

---===================================--Fusion-Reaktor-Proramm--v0.9.4 by Dispelnator--============================================

--Ty for using my Mekanism-Fusion-Reactor-Programm,
--Its my first Lua Program, so please tell me better Solutions of this Code.

--I need help with a Function to calc the current Tritium Production
--Means if tank on day < 50 then injection rate = tritium input then the tank goes over 75 %

--You need minimum ProjectRed and Mekanism(+Tools,Generators)+ draconicevolution (for flux and fluid gates) for this Program

--BundeledCable list:
--						 Red for Laser (fireup)
--						 Yellow for Alarm and Hohlraum-Insert
--						 Black 2 power laser via Tesseract/cubes...
--The fuel usage is Injection-Rate/2 => For INJ-RATE = 98 you need 49 mb Tritium and 49 mb Deuterium (per tick) => ca. 9.8 MRF
--For more Power u need Draconic Fluid-Gate and Rotary-Condenstrator*x and a Chemical Infuser (D-T-Fuel)
--1 Rotary-Condenstrator = max 256mb/t means  ca. + 25.6 MRF/t
--Actually u can use Draconic-Energy-Core for Energy Storage but Induction-Matrix from Mekanism is better.
--Actually u can use only Dynamic-Tanks but its the best one
--
--
--Everything around the monitor I have taken from Krakaen's Big-Reactor-Program and
--Thor_s_Crafter helped me with most buggs in the program
--Some Videos about their Big-Reactor-Programs:
--Krakaen		: https://www.youtube.com/watch?v=SbbT7ncyS2M
--Thor_s_Crafter: https://www.youtube.com/watch?v=XNlsU0tSHOc

---================================================ Edit at own Risk ===============================================================

FirstProcent = 0
SecondProcent = 0
k = 0.09961964844
InjRate = 0
DTFuelInjRate = 0
FuelInjRate = 0
MRFProduce = 0
amountTanks = 0
MRFLaser = 0
MRFMaxLaser = 0
MRFNeed = 0
Charge = 0
InjRate2 = 2
w = 0

currentChargeLevel = 1
currentInjRate = 1

local TType = ""
local EType = ""
local ChargeStatus = "UNCHARGED"
local ReactorStatus = "OFFLINE"

local TankLevel = false
local TankLevel1 = false
local TankLevel2 = false
local DraconicFluidGate = false
local DraconicFluxGate = false
local Auto = false
local ChargeOn = false
local FireUpOK = false
local refresh = true

local ChargeOnOffcolor = colors.green
local FireUpcolor = colors.green
local powerUpcolor = colors.green
local ChargeTextcolor = colors.red
local RectorTextcolor = colors.red

rs.setBundledOutput("back", 0)

-- tabels

local Tanktypes = { "dynamic_tank" }
local EnergyStoragetypesMekanism = { "Basic Energy Cube", "Advanced Energy Cube", "Elite Energy Cube",
	"Ultimate Energy Cube" }
local EnergyStoragetypesMekanismIM = { "Induction Matrix" }
local EnergyStoragetypesDraconic = { "draconic_rf_storage" }
local Tanks = {}

local button = {}
local filleds = {}
local boxes = {}
local lines = {}
local texts = {}

local FirstTankStats = {}
local SecondTankStats = {}

local GeneralBox = {}
local ReactorBox = {}
local TankBox = {}
local GraphicBox = {}

function initPeripherals()
	local peripheralList = peripheral.getNames()
	for i = 1, #peripheralList do
		-- Reactor
		if peripheral.getType(peripheralList[i]) == "Reactor Logic Adapter" then
			FReactor = peripheral.wrap(peripheralList[i])
		end
		-- Laser Amplifier
		if peripheral.getType(peripheralList[i]) == "Laser Amplifier" then
			LaserAmp = peripheral.wrap(peripheralList[i])
		end
		-- Fluid-Gate
		if peripheral.getType(peripheralList[i]) == "fluid_gate" then
			DTFuelInj = peripheral.wrap(peripheralList[i])
			DraconicFluidGate = true
		end
		-- Flux-Gate
		if peripheral.getType(peripheralList[i]) == "flux_gate" then
			FluxGate = peripheral.wrap(peripheralList[i])
			DraconicFluxGate = true
		end
		-- Energystorage
		for k, v in pairs(EnergyStoragetypesMekanism) do
			if peripheral.getType(peripheralList[i]) == v then
				RFStorage = peripheral.wrap(peripheralList[i])
				EType = "mekanism"
			end
		end
		for k, v in pairs(EnergyStoragetypesMekanismIM) do
			if peripheral.getType(peripheralList[i]) == v then
				RFStorage = peripheral.wrap(peripheralList[i])
				EType = "mekanismIM"
			end
		end
		for k, v in pairs(EnergyStoragetypesDraconic) do
			if peripheral.getType(peripheralList[i]) == v then
				RFStorage = peripheral.wrap(peripheralList[i])
				EType = "draconic"
			end
		end
		-- Monitor
		if peripheral.getType(peripheralList[i]) == "monitor" then
			mon = peripheral.wrap(peripheralList[i])
			TType = "TankInfo"
		end
		-- Tanks
		for k, v in pairs(Tanktypes) do
			if peripheral.getType(peripheralList[i]) == v then
				Tanks[amountTanks] = peripheral.wrap(peripheralList[i])
				amountTanks = amountTanks + 1
			end
		end
	end
	amountTanks = amountTanks - 1
end

initPeripherals()

term.redirect(mon)
mon.clear()
mon.setTextScale(0.5)
mon.setTextColor(colors.white)
mon.setBackgroundColor(colors.black)
mon.setCursorPos(1, 1)

MRFLaser = LaserAmp.getEnergy() / 2500000

if MRFLaser < 400 and ChargeOn == true then
	ChargeStatus = "CHARGING"
	ChargeOnOffcolor = colors.orange
	ChargeTextcolor = colors.orange
elseif MRFLaser < 400 and ChargeOn == false then
	ChargeStatus = "UNCHARGED"
	ChargeOnOffcolor = colors.green
	ChargeTextcolor = colors.red
else
	ChargeStatus = "CHARGED"
	ChargeOnOffcolor = colors.gray
	ChargeTextcolor = colors.green
end

function recalcInj()
	if DraconicFluidGate == true then
		DTFuelInj.setOverrideEnabled(true)
		DTFuelInjRate = DTFuelInj.getFlow()
		InjRateMax = xRC * 256 + 98
	else
		InjRateMax = 98
	end
	FuelInjRate = FReactor.getInjectionRate()

end

if DraconicFluxGate == true then
	FluxGate.setOverrideEnabled(true)
end

function clearTable()
	button = {}
end

-- All the things that make my buttons work

function setButton(name, title, func, xmin, ymin, xmax, ymax, elem, elem2, color)
	button[name] = {}
	button[name]["title"] = title
	button[name]["func"] = func
	button[name]["active"] = false
	button[name]["xmin"] = xmin
	button[name]["ymin"] = ymin
	button[name]["xmax"] = xmax
	button[name]["ymax"] = ymax
	button[name]["color"] = color
	button[name]["elem"] = elem
	button[name]["elem2"] = elem2
end

-- stuff and things for buttons

function fill(text, color, bData)
	mon.setBackgroundColor(color)
	mon.setTextColor(colors.white)
	local yspot = math.floor((bData["ymin"] + bData["ymax"]) / 2)
	local xspot = math.floor((bData["xmax"] - bData["xmin"] - string.len(bData["title"])) / 2) + 1
	for j = bData["ymin"], bData["ymax"] do
		mon.setCursorPos(bData["xmin"], j)
		if j == yspot then
			for k = 0, bData["xmax"] - bData["xmin"] - string.len(bData["title"]) + 1 do
				if k == xspot then
					mon.write(bData["title"])
				else
					mon.write(" ")
				end
			end
		else
			for i = bData["xmin"], bData["xmax"] do
				mon.write(" ")
			end
		end
	end
	mon.setBackgroundColor(colors.black)
end

-- stuff and things for buttons

function screen()
	local currColor
	for name, data in pairs(button) do
		local on = data["active"]
		currColor = data["color"]
		fill(name, currColor, data)
	end
end

-- stuff and things for buttons

function flash(name)
	screen()
end

-- magical handler for clicky clicks

function checkxy(x, y)
	for name, data in pairs(button) do
		if y >= data["ymin"] and y <= data["ymax"] then
			if x >= data["xmin"] and x <= data["xmax"] then
				data["func"](data["elem"], data["elem2"])
				flash(data['name'])
				return true
				--data["active"] = not data["active"]
				--print(name)
			end
		end
	end
	return false
end

-- Draw function : put's all the beautiful magic in the screen

function draw()

	for key, value in pairs(filleds) do
		paintutils.drawFilledBox(value[1], value[2], value[3], value[4], value[5])
	end

	for key, value in pairs(boxes) do
		paintutils.drawBox(value[1], value[2], value[3], value[4], value[5])
	end

	for key, value in pairs(lines) do
		paintutils.drawLine(value[1], value[2], value[3], value[4], value[5])
	end

	for key, value in pairs(texts) do
		mon.setCursorPos(value[1], value[2])
		mon.setTextColor(value[4])
		mon.setBackgroundColor(value[5])
		mon.write(value[3])
	end
	screen()
	resetDraw()
end

-- Resets the elements to draw to only draw the neccessity

function resetDraw()
	filleds = {}
	boxes = {}
	lines = {}
	texts = {}
end

-- Handles all the clicks for the buttons

function clickEvent()
	local myEvent = { os.pullEvent("monitor_touch") }
	checkxy(myEvent[3], myEvent[4])
end

-- Power up the reactor (M&N are a good source of food right?)

function powerUp(m, n)
	if FReactor.isIgnited() == false then
		Auto = true
		ChargeOn = true
		powerUpcolor = colors.green
		calcLaserAmplifier()
	else
		powerUpcolor = colors.gray
	end
end

-- Turns Fusion-Reactor off

function powerDown(m, n)
	Power = false
	ChargeOn = false
	Auto = false
	rs.setBundledOutput("back", 0)
	calcInjRate()
end

function addDrawBoxes()
	local w, h = mon.getSize()
	Factor = math.floor((w / 100) * 2)

	GeneralBox["startX"] = 2
	GeneralBox["startY"] = 3
	GeneralBox["endX"] = ((w - (Factor * 2)) / 3) - Factor
	GeneralBox["endY"] = (((h - (Factor * 2)) / 3 + 1) / 4) * 3
	GeneralBox["height"] = GeneralBox["endY"] - GeneralBox["startY"] - (Factor * 2) - 2
	GeneralBox["width"] = GeneralBox["endX"] - GeneralBox["startX"] - (Factor * 2) - 2
	GeneralBox["inX"] = GeneralBox["startX"] + Factor + 1
	GeneralBox["inY"] = GeneralBox["startY"] + Factor + 1

	table.insert(boxes, { GeneralBox["startX"], GeneralBox["startY"], GeneralBox["endX"], GeneralBox["endY"], colors.gray })
	name = "LASER"
	table.insert(lines,
		{ GeneralBox["startX"] + Factor, GeneralBox["startY"], GeneralBox["startX"] + (Factor * 2) + #name + 1,
			GeneralBox["startY"], colors.black })
	table.insert(texts, { GeneralBox["startX"] + (Factor * 2), GeneralBox["startY"], name, colors.white, colors.black })

	TankBox["startX"] = GeneralBox["startX"]
	TankBox["startY"] = (h - Factor) - ((GeneralBox["endY"] - GeneralBox["startY"]) / 3) * 2
	TankBox["endX"] = GeneralBox["endX"]
	TankBox["endY"] = h - 1
	TankBox["height"] = TankBox["endY"] - TankBox["startY"] - (Factor * 2) - 2
	TankBox["width"] = TankBox["endX"] - TankBox["startX"] - (Factor * 2) - 2
	TankBox["inX"] = TankBox["startX"] + Factor + 1
	TankBox["inY"] = TankBox["startY"] + Factor + 1

	table.insert(boxes, { TankBox["startX"], TankBox["startY"], TankBox["endX"], TankBox["endY"], colors.gray })
	name = "TANKS"
	table.insert(lines,
		{ TankBox["startX"] + Factor, TankBox["startY"], TankBox["startX"] + (Factor * 2) + #name + 1, TankBox["startY"],
			colors.black })
	table.insert(texts, { TankBox["startX"] + (Factor * 2), TankBox["startY"], name, colors.white, colors.black })

	ReactorBox["startX"] = GeneralBox["startX"]
	ReactorBox["startY"] = GeneralBox["endY"] + Factor
	ReactorBox["endX"] = GeneralBox["endX"]
	ReactorBox["endY"] = TankBox["startY"] - Factor
	ReactorBox["height"] = ReactorBox["endY"] - ReactorBox["startY"] - (Factor * 2) - 2
	ReactorBox["width"] = ReactorBox["endX"] - ReactorBox["startX"] - (Factor * 2) - 2
	ReactorBox["inX"] = ReactorBox["startX"] + Factor + 1
	ReactorBox["inY"] = ReactorBox["startY"] + Factor + 1

	table.insert(boxes, { ReactorBox["startX"], ReactorBox["startY"], ReactorBox["endX"], ReactorBox["endY"], colors.gray })
	name = "REACTOR"
	table.insert(lines,
		{ ReactorBox["startX"] + Factor, ReactorBox["startY"], ReactorBox["startX"] + (Factor * 2) + #name + 1,
			ReactorBox["startY"], colors.black })
	table.insert(texts, { ReactorBox["startX"] + (Factor * 2), ReactorBox["startY"], name, colors.white, colors.black })

	GraphicBox["startX"] = GeneralBox["endX"] + Factor
	GraphicBox["startY"] = GeneralBox["startY"]
	GraphicBox["endX"] = w - 2
	GraphicBox["endY"] = TankBox["endY"]
	GraphicBox["height"] = GraphicBox["endY"] - GraphicBox["startY"] - (Factor * 2) - 2
	GraphicBox["width"] = GraphicBox["endX"] - GraphicBox["startX"] - (Factor * 2) - 2
	GraphicBox["inX"] = GraphicBox["startX"] + Factor
	GraphicBox["inY"] = GraphicBox["startY"] + 2
	GraphicBox["sectionHeight"] = math.floor(GraphicBox["height"] / 6)

	table.insert(boxes, { GraphicBox["startX"], GraphicBox["startY"], GraphicBox["endX"], GraphicBox["endY"], colors.gray })
	name = "GRAPHICS/BUTTONS"
	table.insert(lines,
		{ GraphicBox["startX"] + Factor, GraphicBox["startY"], GraphicBox["startX"] + (Factor * 2) + #name + 1,
			GraphicBox["startY"], colors.black })
	table.insert(texts, { GraphicBox["startX"] + (Factor * 2), GraphicBox["startY"], name, colors.white, colors.black })

	name = "FUSION-PLANT"
	table.insert(texts, { (w / 2) - (#name / 2), 1, name, colors.white, colors.black })

	local names = {}
	names[1] = "CHARGE LEVEL"
	names[2] = "INJECTION RATE"
	names[3] = "ENERGY STORED"

	for i = 1, 5, 1 do
		table.insert(texts,
			{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 1, names[i], colors.white,
				colors.black })
		table.insert(filleds,
			{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
				GraphicBox["inX"] + GraphicBox["width"] - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i,
				colors.lightGray })
	end

	refresh = true
	while refresh do
		recalcInj()
		if FReactor.isIgnited() == false then
			powerUpcolor = colors.green
			FireUpcolor = colors.green
			ReactorStatus = "OFFLINE"
			RectorTextcolor = colors.red
		else
			powerUpcolor = colors.gray
			FireUpcolor = colors.gray
			ReactorStatus = "ONLINE"
			RectorTextcolor = colors.green
		end

		setButton("CHARG", "CHARGE", ChargeOnOff, GraphicBox["inX"] + Factor, GraphicBox["inY"] + 1,
			GraphicBox["inX"] + (GraphicBox["width"] / 4 - 1), GraphicBox["inY"] + 3, 0, 0, ChargeOnOffcolor)
		setButton("START INJ", "START INJ", FireUp, GraphicBox["inX"] + (GraphicBox["width"] / 4 + Factor - 1),
			GraphicBox["inY"] + 1, GraphicBox["inX"] + ((GraphicBox["width"] / 4) * 2 - 1), GraphicBox["inY"] + 3, 0, 0,
			FireUpcolor)
		setButton("AUTO-CHARGE", "AUTO-CHARGE", powerUp, GraphicBox["inX"] + ((GraphicBox["width"] / 4) * 2 + Factor - 1),
			GraphicBox["inY"] + 1, GraphicBox["inX"] + ((GraphicBox["width"] / 4) * 3 - 1), GraphicBox["inY"] + 3, 0, 0,
			powerUpcolor)
		setButton("SHUT-DOWN", "SHUT-DOWN", powerDown, GraphicBox["inX"] + ((GraphicBox["width"] / 4) * 3 + Factor - 1),
			GraphicBox["inY"] + 1, GraphicBox["inX"] + (GraphicBox["width"] - 1), GraphicBox["inY"] + 3, 0, 0, colors.red)

		if FireUpOK == true then
			sleep(10)
			rs.setBundledOutput("back", colors.subtract(rs.getBundledOutput("back"), colors.yellow))
			if FReactor.isIgnited() == false then
				rs.setBundledOutput("back", colors.red, 1)
				sleep(1)
				rs.setBundledOutput("back", 0, colors.red)
			end
			FireUpOK = false
		end

		if (FirstProcent < 25 and FirstProcent >= MinProcenttoBoost) or
			(SecondProcent < 25 and SecondProcent >= MinProcenttoBoost) then
			for w = 0, 0 do
				TankLevel = false
				TankLevel1 = false
				TankLevel2 = true
			end
		elseif (FirstProcent >= 25 and FirstProcent <= 75) or (SecondProcent >= 25 and SecondProcent <= 75) then
			for w = 0, 0 do
				TankLevel = false
				TankLevel1 = true
				TankLevel2 = false
			end
		elseif (FirstProcent > 75 and SecondProcent > 75) then
			for w = 0, 0 do
				TankLevel = true
				TankLevel1 = false
				TankLevel2 = false
			end
		elseif (FirstProcent < MinProcenttoBoost or SecondProcent < MinProcenttoBoost) then
			for w = 0, 0 do
				TankLevel = false
				TankLevel1 = false
				TankLevel2 = false
			end
		end
		parallel.waitForAny(refreshStats, loop, clickEvent)
	end

end

function loop()
	while true do
		calcInjRate()
	end
end

function refreshStats()
	calcInjRate()
	calcLaserAmplifier()

	-- Laser Visualisierung

	local i = 1

	local infotoAdd = "STATUS: "
	local infotoAdd1 = "CHARGE-LEVEL: "

	if currentChargeLevel ~= MRFLaser then
		currentChargeLevel = MRFLaser

		if MRFLaser > 400 then
			MRFLaserT = 400
		else
			MRFLaserT = MRFLaser
		end

		MRFLaserText = math.floor((MRFLaserT / 400) * 100)

		table.insert(lines,
			{ GeneralBox["inX"], GeneralBox["inY"], GeneralBox["inX"] + GeneralBox["width"], GeneralBox["inY"], colors.black })
		table.insert(texts, { GeneralBox["inX"] + 1, GeneralBox["inY"] - 1, infotoAdd, colors.white, colors.black })
		table.insert(texts,
			{ GeneralBox["inX"] + 1 + #infotoAdd, GeneralBox["inY"] - 1, ChargeStatus .. "   ", ChargeTextcolor, colors.black })
		table.insert(texts,
			{ GeneralBox["inX"] + 1, GeneralBox["inY"] + Factor - 1, infotoAdd1 .. MRFLaserText .. "%   ", colors.white,
				colors.black })
		table.insert(filleds,
			{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
				GraphicBox["inX"] + GraphicBox["width"] - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i,
				colors.lightGray })

		width = math.floor((GraphicBox["width"] / 400) * MRFLaserT)
		table.insert(filleds,
			{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
				GraphicBox["inX"] + width - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i, colors.green })

	end

	-- Reactor Visualisierung

	local i = 2

	local infotoAdd = "STATUS: "
	local infotoAdd1 = "INJ-RATE: "
	local infotoAdd2 = "PLASMA-HEAT: "
	local infotoAdd3 = "CASE-HEAT: "
	local infotoAdd4 = "ENERGY/T: "
	local infotoAdd5 = "ENERGYSTORAGE: "
	local infotoAdd6 = "WATER: "
	local infotoAdd7 = "STEAM: "

	if InjRateText > (xRC * 256 + 98) then
		InjRateT = (xRC * 256 + 98)
	else
		InjRateT = InjRateText
	end

	table.insert(lines,
		{ ReactorBox["inX"], ReactorBox["inY"], ReactorBox["inX"] + ReactorBox["width"], ReactorBox["inY"], colors.black })
	table.insert(texts, { ReactorBox["inX"] + 1, ReactorBox["inY"] - 1, infotoAdd, colors.white, colors.black })
	table.insert(texts,
		{ ReactorBox["inX"] + 1 + #infotoAdd, ReactorBox["inY"] - 1, ReactorStatus .. " ", RectorTextcolor, colors.black })
	table.insert(texts,
		{ ReactorBox["inX"] + 1, ReactorBox["inY"] + Factor - 1, infotoAdd1 .. InjRateT .. "    ", colors.white, colors.black })
	table.insert(texts,
		{ ReactorBox["inX"] + 1, ReactorBox["inY"] + 2 * Factor - 1, infotoAdd2 .. PlasmaHeat .. " GK ", colors.white,
			colors.black })
	table.insert(texts,
		{ ReactorBox["inX"] + 1, ReactorBox["inY"] + 3 * Factor - 1, infotoAdd3 .. CaseHeat .. " GK ", colors.white,
			colors.black })
	table.insert(texts,
		{ ReactorBox["inX"] + 1, ReactorBox["inY"] + 4 * Factor - 1, infotoAdd4 .. RFOutputT .. " MRF/t   ", colors.white,
			colors.black })
	table.insert(texts,
		{ ReactorBox["inX"] + 1, ReactorBox["inY"] + 5 * Factor - 1, infotoAdd5 .. RFStoragePercent .. "%  ", colors.white,
			colors.black })
	table.insert(texts,
		{ ReactorBox["inX"] + 1, ReactorBox["inY"] + 6 * Factor - 1, infotoAdd6 .. "--- ", colors.white, colors.black })
	table.insert(texts,
		{ ReactorBox["inX"] + 1, ReactorBox["inY"] + 7 * Factor - 1, infotoAdd7 .. "--- ", colors.white, colors.black })

	table.insert(filleds,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
			GraphicBox["inX"] + GraphicBox["width"] - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i,
			colors.lightGray })
	width = math.floor((GraphicBox["width"] / InjRateMax) * InjRateT)
	table.insert(filleds,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
			GraphicBox["inX"] + width - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i, colors.green })

	local i = 3

	table.insert(filleds,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
			GraphicBox["inX"] + GraphicBox["width"] - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i,
			colors.lightGray })
	width = math.floor(GraphicBox["width"] * (RFStoragePercent / 100))
	table.insert(filleds,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
			GraphicBox["inX"] + width - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i, colors.green })

	-- Tank Visualisierung

	local i = 4

	local infotoAdd = " : "

	table.insert(lines, { TankBox["inX"], TankBox["inY"], TankBox["inX"] + TankBox["width"], TankBox["inY"], colors.black })
	table.insert(texts,
		{ TankBox["inX"] + 1, TankBox["inY"] - 1, FirstTankText .. infotoAdd .. FirstProcent .. "% ", colors.white,
			colors.black })
	table.insert(texts,
		{ TankBox["inX"] + 1, TankBox["inY"] + Factor - 1, SecondTankText .. infotoAdd .. SecondProcent .. "% ", colors.white,
			colors.black })

	table.insert(texts,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 1, FirstTankName,
			colors.white, colors.black })
	table.insert(filleds,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
			GraphicBox["inX"] + GraphicBox["width"] - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i,
			colors.lightGray })
	width = math.floor(GraphicBox["width"] * (FirstProcent / 100))
	table.insert(filleds,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
			GraphicBox["inX"] + width - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i, FirstTankcolor })

	local i = 5

	table.insert(texts,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 1, SecondTankName,
			colors.white, colors.black })
	table.insert(filleds,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
			GraphicBox["inX"] + GraphicBox["width"] - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i,
			colors.lightGray })
	width = math.floor(GraphicBox["width"] * (SecondProcent / 100))
	table.insert(filleds,
		{ GraphicBox["inX"] + Factor, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * i) + i + 2,
			GraphicBox["inX"] + width - 1, GraphicBox["inY"] + (GraphicBox["sectionHeight"] * (i + 1)) + i, SecondTankcolor })

	draw()
	sleep(1)
end

-- Calcs MRFProduce

function calcMRFProduce()
	if EType == "mekanism" then
		local MRFNeed = RFStorage.getOutput() / 2500000
		RFStoraged = RFStorage.getEnergy() / 2500000
		RFMaxStorage = RFStorage.getMaxEnergy() / 2500000
		RFStoragePercent = math.floor(RFStoraged / RFMaxStorage * 100)
		if RFStoragePercent > MinProcentforLowMode then
			MRFProduce = MRFNeed + MRFBuffer -- LowRF Mode but everytime over RFOutput
		else
			MRFProduce = RFMaxStorage -- MaxRF Mode
		end
	end
	if EType == "mekanismIM" then
		local MRFNeed = RFStorage.getOutput() / 2500000
		RFStoraged = RFStorage.getEnergy() / 2500000
		RFMaxStorage = RFStorage.getMaxEnergy() / 2500000
		RFMaxTransfer = RFStorage.getTransferCap() / 2500000
		RFStoragePercent = math.floor(RFStoraged / RFMaxStorage * 100)
		if RFStoragePercent > MinProcentforLowMode then
			MRFProduce = MRFNeed + MRFBuffer -- LowRF Mode but everytime over RFOutput
		else
			MRFProduce = RFMaxTransfer -- MaxRF Mode
		end
	end
	if EType == "draconic" then
		RFStoraged = RFStorage.getEnergyStored() / 1000000
		RFMaxStorage = RFStorage.getMaxEnergyStored() / 1000000
		RFStoragePercent = math.floor(RFStoraged / RFMaxStorage * 100)
		local MRFNeed = RFMaxStorage - RFStoraged
		MRFProduce = MRFNeed + MRFBuffer
	end
end

-- Stats of Tanks

function calcTankStats()
	local FirstTankInfo = Tanks[0].getTankInfo()
	local SecondTankInfo = Tanks[1].getTankInfo()
	if FirstTankInfo[1]["contents"] == nil then
		FirstTankText = "NO FLUID     "
		FirstTankName = "NO FLUID         "
		FirstTankLiquid = "NO FLUID     "
		FirstAmount = 0
		FirstProcent = 0
		FirstTankcolor = colors.lightGray
	else
		FirstTankStats = FirstTankInfo[1]
		local FirstCapacity = FirstTankStats["capacity"]
		FirstTankName = FirstTankStats["contents"]["rawName"]
		FirstTankLiquid = FirstTankStats["contents"]["name"]
		FirstAmount = FirstTankStats["contents"]["amount"]
		FirstProcent = math.floor(FirstAmount / FirstCapacity * 100)
	end

	if SecondTankInfo[1]["contents"] == nil then
		SecondTankText = "NO FLUID     "
		SecondTankName = "NO FLUID         "
		SecondTankLiquid = "NO FLUID     "
		SecondAmount = 0
		SecondProcent = 0
		SecondTankcolor = colors.lightGray
	else
		SecondTankStats = SecondTankInfo[1]
		local SecondCapacity = SecondTankStats["capacity"]
		SecondTankName = SecondTankStats["contents"]["rawName"]
		SecondTankLiquid = SecondTankStats["contents"]["name"]
		SecondAmount = SecondTankStats["contents"]["amount"]
		SecondProcent = math.floor(SecondAmount / SecondCapacity * 100)
	end

	if FirstTankName == "Liquid Tritium" or SecondTankName == "Liquid Deuterium" then
		FirstTankcolor = colors.cyan
		FirstTankText = "L.TRITIUM    "
		SecondTankcolor = colors.red
		SecondTankText = "L.DEUTERIUM  "
	elseif FirstTankName == "Liquid Deuterium" or SecondTankName == "Liquid Tritium" then
		FirstTankcolor = colors.red
		FirstTankText = "L.DEUTERIUM  "
		SecondTankcolor = colors.cyan
		SecondTankText = "L.TRITIUM    "
	end

	if FirstTankName == "NO FLUID         " then
		FirstTankText = "NO FLUID     "
		FirstTankcolor = colors.lightGray
	elseif SecondTankName == "NO FLUID         " then
		SecondTankText = "NO FLUID     "
		SecondTankcolor = colors.lightGray
	end
end

-- Calcs and Sets Inj Rate

function calcInjRate()
	recalcInj()
	calcMRFProduce()
	calcTankStats()
	InjRate1 = math.ceil(RFMaxTransfer / k)
	InjRate2 = math.ceil(MRFProduce / k)

	if Power == true then

		if TankLevel2 == true then
			InjRate = math.floor(InjRateMax / 4)
		elseif TankLevel1 == true then
			InjRate = math.floor(InjRateMax / 4) * 3
		elseif TankLevel == true then
			InjRate = InjRate2
		end
		if InjRate > InjRate1 then
			InjRate = InjRate1
		end
		if (TankLevel == false and TankLevel1 == false and TankLevel2 == false) or InjRate < 2 then
			InjRate = 2
		end
		if DraconicFluidGate == true then -- if Fluidgate ispresent then D-T-Fuel => main Fuel
			calcDTFuelInjRate()
			DTFuelInj.setFlowOverride(DTFuelInjRate)
			InjRateMax = (xRC * 256 + 98)
		else -- else normal
			calcFuelInjRate()
			InjRateMax = 98
		end
	elseif Power == false then
		if DraconicFluidGate == true then -- if Fluidgate ispresent 0
			DTFuelInj.setFlowOverride(0)
			FuelInjRate = 0
		else -- else FuelInjRate = 0
			FuelInjRate = 0
		end
	end

	InjRateText = FuelInjRate + DTFuelInjRate
	FReactor.setInjectionRate(FuelInjRate)
	RFOutputT = round((FReactor.getProducing() / 2500000), 1)
	PlasmaHeat = round((FReactor.getPlasmaHeat() / 1000000000), 1)
	CaseHeat = round((FReactor.getCaseHeat() / 1000000000), 1)
	sleep(1)
end

-- Calcs DTFuelInjRate (max= 256 mb/t because its maximum of one rotary Conden )

function calcDTFuelInjRate()
	if InjRate > (xRC * 256) then
		calcFuelInjRate()
		DTFuelInjRate = (xRC * 256)
	else
		FuelInjRate = 0
		DTFuelInjRate = InjRate
	end
end

-- Calcs InjRate for Fusion-Reactor

function calcFuelInjRate()
	if DraconicFluidGate == true then
		FuelInjRate = InjRate - (xRC * 256)
	else
		DTFuelInjRate = 0
		FuelInjRate = InjRate
	end
	if FuelInjRate % 2 == 1 then -- Its possible to set InjRate Of Fusion-Reactor to 7, 9, 11, ... in Fusion-Reactor-GUI not possible!!! Maybe Bug??
		FuelInjRate = FuelInjRate + 1
	end
	if FuelInjRate > 98 then -- Its possible to set InjRate Of Fusion-Reactor over 98!!! Maybe Bug??? (For CheatMode set FuelInjRate = 354 for 1,56 GRF!!!)
		FuelInjRate = 98
	end
end

-- Laser Amplifier

function calcLaserAmplifier()
	MRFMaxLaser = LaserAmp.getMaxEnergy() / 2500000
	MRFLaser = LaserAmp.getEnergy() / 2500000
	if MRFLaser < 400 and ChargeOn == true then
		Charge = 10000000
		ChargeStatus = "CHARGING"
		ChargeOnOffcolor = colors.orange
		ChargeTextcolor = colors.orange
	elseif MRFLaser < 400 and ChargeOn == false then
		Charge = 0
		ChargeStatus = "UNCHARGED"
		ChargeOnOffcolor = colors.green
		ChargeTextcolor = colors.red
	else
		Charge = 0
		ChargeStatus = "CHARGED"
		ChargeOnOffcolor = colors.gray
		ChargeTextcolor = colors.green
	end
	if DraconicFluxGate == true then
		ChargeLaser = FluxGate.setFlowOverride(Charge)
	elseif MRFLaser < 400 and DraconicFluxGate == false then
		rs.setBundledOutput("back", colors.combine(rs.getBundledOutput("back"), colors.black))
	end
	if MRFLaser >= 400 then
		if Auto == true then
			if DraconicFluidGate == true then -- if Fluidgate ispresent = 2
				DTFuelInj.setFlowOverride(2)
				FReactor.setInjectionRate(0)
			else -- else FuelInjRate = 2
				FReactor.setInjectionRate(2)
			end
			FireUp()
		elseif MRFLaser >= 400 and Auto == false and DraconicFluxGate == true then
			FluxGate.setFlowOverride(0)
			rs.setBundledOutput("back", colors.subtract(rs.getBundledOutput("back"), colors.black))
		end
	end
end

-- Alarm + Hohlraum insert

function FireUp()
	if FReactor.isIgnited() == false then
		Auto = false
		Power = true
		FireUpOK = true
		rs.setBundledOutput("back", colors.combine(rs.getBundledOutput("back"), colors.yellow))
		FireUpcolor = colors.green
		calcInjRate()
	else
		FireUpcolor = colors.gray
	end
end

function ChargeOnOff()
	ChargeOn = true
	calcLaserAmplifier()
end

--============================================================
-- add comma to separate thousands
-- From Lua-users.org/wiki/FormattingNumbers
--
--
function comma_value(amount)
	local formatted = amount
	while true do
		formatted, zz = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (zz == 0) then
			break
		end
	end
	return formatted
end

---============================================================
-- rounds a number to the nearest decimal places
-- From Lua-users.org/wiki/FormattingNumbers
--
--
function round(val, decimal)
	if (decimal) then
		return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
	else
		return math.floor(val + 0.5)
	end
end

--===================================================================
-- given a numeric value formats output with comma to separate thousands
-- and rounded to given decimal places
-- From Lua-users.org/wiki/FormattingNumbers
--
function format_num(amount, decimal, prefix, neg_prefix)
	local str_amount, formatted, famount, remain

	decimal = decimal or 2 -- default 2 decimal places
	neg_prefix = neg_prefix or "-" -- default negative sign

	famount = math.abs(round(amount, decimal))
	famount = math.floor(famount)

	remain = round(math.abs(amount) - famount, decimal)

	-- comma to separate the thousands
	formatted = comma_value(famount)

	-- attach the decimal portion
	if (decimal > 0) then
		remain = string.sub(tostring(remain), 3)
		formatted = formatted .. "." .. remain ..
			string.rep("0", decimal - string.len(remain))
	end

	-- attach prefix string e.g '$'
	formatted = (prefix or "") .. formatted

	-- if value is negative then format accordingly
	if (amount < 0) then
		if (neg_prefix == "()") then
			formatted = "(" .. formatted .. ")"
		else
			formatted = neg_prefix .. formatted
		end
	end

	return formatted
end

addDrawBoxes()
