local xC, yC, zC, currentDir
local nbBlocs, nbFuel
local sizeLine, toDoLine
MAXBLOCS = 960
MAXFUEL = 64

local direction = {
	NORTH = function() -- X ++
		xC = xC + 1
	end,
	SOUTH = function() -- X --
		xC = xC - 1
	end,
	EAST = function() -- Y ++
		yC = yC + 1
	end,
	WEST = function() -- Y --
		yC = yC - 1
	end,
}

local function goUp()
	assert(turtle.up())
	zC = zC + 1
end

local function goDown()
	assert(turtle.down())
	zC = zC - 1
end

local function turnRight()
	if (currentDir == direction.NORTH) then
		currentDir = direction.EAST
	elseif (currentDir == direction.EAST) then
		currentDir = direction.SOUTH
	elseif (currentDir == direction.SOUTH) then
		currentDir = direction.WEST
	else
		currentDir = direction.NORTH
	end
	turtle.turnRight()
end

local function turnLeft()
	if (currentDir == direction.NORTH) then
		currentDir = direction.WEST
	elseif (currentDir == direction.WEST) then
		currentDir = direction.SOUTH
	elseif (currentDir == direction.SOUTH) then
		currentDir = direction.EAST
	else
		currentDir = direction.NORTH
	end
	turtle.turnLeft()
end

local function turnDir(dir)
	while currentDir ~= dir do
		turnRight()
	end
end

local function forward()
	if not turtle.forward() then
		goUp()
		forward()
	end
	currentDir()
end

local function gotoCoo(x, y, z, startZ)
	if startZ then
		while zC ~= z do
			if zC < z then
				goUp()
			else
				goDown()
			end
		end
	end
	while yC ~= y do
		if yC < y then
			turnDir(direction.EAST)
			forward()
		else
			turnDir(direction.WEST)
			forward()
		end
	end
	while xC ~= x do
		if xC < x then
			turnDir(direction.NORTH)
			forward()
		else
			turnDir(direction.SOUTH)
			forward()
		end
	end
	if not startZ then
		while zC ~= z do
			if zC < z then
				goUp()
			else
				goDown()
			end
		end
	end
end

local function setSlotBloc()
	local i = 1
	local is_fuel, isEmpty, reason = true, false, false
	while is_fuel or isEmpty do
		turtle.select(i)
		is_fuel, reason = turtle.refuel(0)
		isEmpty = turtle.getItemCount() == 0
		i = i + 1
	end
end

local function setSlotFuel()
	local i = 1
	local is_fuel, reason = false, false
	while not is_fuel do
		turtle.select(i)
		is_fuel, reason = turtle.refuel(0)
		i = i + 1
	end
end

local function reFuel()
	pcall(setSlotFuel)
	while (nbFuel > 0) and (turtle.getFuelLevel() < turtle.getFuelLimit()) do
		turtle.refuel(1)
		nbFuel = nbFuel - 1
	end
end

local function refill()
	local saveX, saveY, saveZ, saveDir = xC, yC, zC, currentDir
	gotoCoo(0, 0, 0, false)
	turnDir(direction.NORTH)
	reFuel()
	turtle.suck(MAXFUEL - nbFuel)
	nbFuel = MAXFUEL
	reFuel()
	turtle.suck(MAXFUEL - nbFuel)
	nbFuel = MAXFUEL
	turnRight()
	forward()
	turnLeft()
	while nbBlocs < MAXBLOCS do
		if nbBlocs + 64 <= MAXBLOCS then
			turtle.suck(64)
			nbBlocs = nbBlocs + 64
		else
			turtle.suck(MAXBLOCS - nbBlocs)
			nbBlocs = MAXBLOCS
		end
	end
	gotoCoo(saveX, saveY, saveZ, true)
	turnDir(saveDir)
end

local function placeBlock()
	if nbBlocs <= 0 then
		refill()
	end
	if nbBlocs % 64 == 0 then
		setSlotBloc()
	end
	if turtle.placeUp() then
		nbBlocs = nbBlocs - 1
	end
end

local function checkFuel()
	if (turtle.getFuelLevel() <= turtle.getFuelLimit() / 2) then
		if nbFuel > 0 then
			reFuel()
			checkFuel()
		else
			refill()
		end
	end
end

local function fill()
	local nbLine = 0
	while true do
		while nbLine < 2 do
			while toDoLine > 0 do
				checkFuel()
				placeBlock()
				forward()
				toDoLine = toDoLine - 1
			end
			turnLeft()
			toDoLine = sizeLine
			nbLine = nbLine + 1
		end
		sizeLine = sizeLine + 1
		nbLine = 0
	end
end

local function main()
	xC, yC, zC, currentDir = 0, 0, 0, direction.NORTH
	nbFuel, nbBlocs = 0, 0
	refill()
	goUp()
	goUp()
	sizeLine, toDoLine = 1, 1
	fill()
end

main()
