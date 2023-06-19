
--SETTINGS--
--Visualize BSFC curve here: https://www.desmos.com/calculator/poapnuglk7
local quantity = 35 --Liters of maximum fuel (for gauge display only). To edit real value go into the "Handler" script
local minimumBSFC = 270 --g/kW/h fuel consumption. ~200-210 for a diesel vehicle. ~260-270 for a petrol vehicle. Look at the visualizer and if the lowest point doesn't match, lower this value more
local maximumBSFC = 360 --g/kW/h fuel consumption. ~220-230 for a diesel vehicle. ~310-360 for a petrol vehicle.
local startingPoint = 0.5 --A value between 0 and 1. Determines the low-end consumption and curve flatness
local curveFactor = 1.5 --Determines curve shape and peak positions
local fuelDensity = 0.749 --0.85 for diesel. 0.749 for petrol
local avgMPGTime = 60 --Shows average MPG over a given time (in seconds)
local AChassisKitVersion = 1 --0 for old. 1 for new. If you notice that there is no fuel consumption in neutral, that means that you have the old version
local studsPerMile = 6336 --A-Chassis kit default is 6336. If you assume 1 stud = 1 foot then 5280 should be used instead
---------------------------

-- Connection to Car GUI --
local gui = script.Parent
local gauge = script.Gauge
local car = gui.Car.Value
local event = car:WaitForChild('FuelEvent')
local rpm = gui.Values.RPM
local vel = gui.Values.Velocity
local hp = gui.Values.Horsepower
local throttle = gui.Values.Throttle
local IsOn = gui.IsOn
local tune = require(car['A-Chassis Tune'])
-------------------------------------------

--REALTIME--
local fuel = 0
local mpgData = {}
local lastEntry = 0
local delta = 0
-----------------------

--Gauge--
do
	gauge.Parent = gui
	gauge['1/4'].Text = (quantity * 0.25).. 'L'
	gauge['3/4'].Text = (quantity * 0.75).. 'L'
	gauge['1'].Text = quantity.. 'L'
end

local function lerp(a, b, c)
	return (b - a) * c + a
end

local function reverseLerp(current, min, max)
	return (current - min) / (max - min)
end

local function findSpecificBSFC()
	local s = lerp(minimumBSFC, maximumBSFC, startingPoint)
	local e = lerp(minimumBSFC, maximumBSFC, 1 - math.sin(math.pi * (rpm.Value / tune.Redline) ^ curveFactor))
	return lerp(s, e, rpm.Value / tune.Redline)
end

local function getAverage(t)
	local m, c = 0, 0
	for i = 1, #t do
		m = m + t[i][1]
		c = c + t[i][2]
	end
	local a = m / c
	if a == a then
		return a
	else
		return 0
	end
end

event:FireServer()
event.OnClientEvent:Connect(function(n)
	if not IsOn.Value and n > 0 then
		IsOn.Value = true
	end
	fuel = n * fuelDensity
end)

print('Fuel script by KapKing47 is loaded.')

while true do
	if IsOn.Value then
		local thp = hp.Value * throttle.Value
		local consumption = 0
		if thp == 0 and AChassisKitVersion == 0 then
			consumption = (tune.Horsepower * rpm.Value / tune.Redline) * 0.746 * findSpecificBSFC() / 1000 / 60 / 60
		elseif thp > 0 then
			consumption = thp * 0.746 * findSpecificBSFC() / 1000 / 60 / 60
		end
		local mS = vel.Value.Magnitude / studsPerMile
		local gS = consumption / fuelDensity / 3.785
		local mpg = mS / gS
		local current_fuel = fuel / (quantity * fuelDensity)
		if #mpgData == avgMPGTime then
			table.remove(mpgData, 1)
		end
		if (tick() - lastEntry) > 1 and mpg == mpg and mpg ~= 1 / 0 then
			mpgData[#mpgData + 1] = {mS; consumption}
			lastEntry = tick()
		end
		if current_fuel > 0 then 
			current_fuel2 = current_fuel - (current_fuel % 0.001)
		gauge.FuelTank.Text = (current_fuel2 * 100)..'%' else 
			gauge.FuelTank.Text = "0"
		end
	   
		if mpg > 0 then
			mpg = mpg - (mpg % 0.001)
		end
		gauge.MPG.Text = 'MPG: '.. mpg
		local avgMPG = getAverage(mpgData)
		if avgMPG > 0 then
			avgMPG = avgMPG - (avgMPG % 0.001)
		end
		gauge.AMPG.Text = 'Avg. MPG: '.. avgMPG
		event:FireServer(consumption * delta / fuelDensity)
	else
		gauge.MPG.Text = 'MPG: 0'
		gauge.AMPG.Text = 'Avg. MPG: 0'
	end
	if fuel <= 0 then IsOn.Value = false end
	gauge.Arrow.Rotation = lerp(115, -115, fuel / (quantity * fuelDensity)) * 0.2 + gauge.Arrow.Rotation * 0.8
	delta = wait()
end
