-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals getTokenPosition calcDistance updateDistTraveled processTurnStart getDistTraveled setStartPosi
-- luacheck: globals updateSpeedWindows

local tStartPosis = {};

function onInit()
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			OptionsManager.registerOptionData({	sKey = 'move_on', sGroupRes = 'option_header_WtW', tCustom = { default = "on" } });
			OptionsManager.registerCallback('move_on', updateSpeedWindows);
			CombatManager.setCustomTurnStart(processTurnStart);
		end
	end
end
function onClose()
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			OptionsManager.unregisterCallback('move_on', updateSpeedWindows);
		end
	end
end

function updateSpeedWindows()
	local tSpeedWindows = Interface.getWindows('speed_window');
	for _,v in ipairs(tSpeedWindows) do
		v.speedwindowcontent.headertraveled.update();
		v.speedwindowcontent.traveled.update();
		v.speedwindowcontent.sub_buttons.reset.update();
		v.speedwindowcontent.sub_buttons.check.update();
	end
end

function getTokenPosition(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.getTokenPosition - not nodeCT");
	end
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	if not tokenCT then
		Debug.console("MovementManager.getTokenPosition - not tokenCT");
	else
		return tokenCT.getPosition();
	end
end

function calcDistance(xStart, yStart, xCurrent, yCurrent)
	if not xStart or not yStart or not xCurrent or not yCurrent then
		Debug.console("MovementManager.calcDistance - 18 - not xStart or not yStart or not xCurrent or not yCurrent");
		return;
	end
	xStart = tonumber(xStart);
	yStart = tonumber(yStart);
	xCurrent = tonumber(xCurrent);
	yCurrent = tonumber(yCurrent);
	if not xStart or not yStart or not xCurrent or not yCurrent then
		Debug.console("MovementManager.calcDistance - 27 - not xStart or not yStart or not xCurrent or not yCurrent");
		return;
	end
	local xDist = math.abs(xCurrent - xStart);
	local yDist = math.abs(yCurrent - yStart);

	local sPref = OptionsManager.getOption('HRDD');
	local nDiagMult;
	if sPref == 'raw' then
		nDiagMult = math.sqrt(2);
	elseif sPref == 'variant' then
		nDiagMult = 1.5;
	else
		nDiagMult = 1;
	end

	local nDiagDistRemainder = math.abs(yDist - xDist);
	local nDiagDistX = xDist - nDiagDistRemainder;
	local nDiagDistY = yDist - nDiagDistRemainder;
	local nDiagDist;
	local nLinDist;
	if nDiagDistX > nDiagDistY then
		nDiagDist = nDiagDistX;
		nLinDist = nDiagDistX - nDiagDistRemainder;
	elseif nDiagDistX < nDiagDistY then
		nDiagDist = nDiagDistY;
		nLinDist = nDiagDistY - nDiagDistRemainder;
	else
		nDiagDist = nDiagDistX;
		nLinDist = 0;
	end
	local nDiagDistMult = nDiagDist * nDiagMult;
	local nDistTotal = nDiagDistMult + nLinDist;
	local nDistTotalRound = nDistTotal * 2;
	nDistTotalRound = math.ceil(nDistTotalRound);
	nDistTotalRound = nDistTotalRound / 2;
	return nDistTotalRound;
end

function updateDistTraveled(nodeCT, nDist, bAdd)
	if nDist then nDist = tonumber(nDist) end
	if not nodeCT or not nDist then
		Debug.console("MovementManager.updateDistCovered - not nodeCT or not nDist");
	end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeTraveled = DB.createChild(nodeCTWtW, 'traveled', 'string');
	local sTravelCurrent = DB.getValue(nodeTraveled);
	local nTravelCurrent;
	if sTravelCurrent then tonumber(nTravelCurrent) end
	if not nTravelCurrent or not bAdd then
		nTravelCurrent = 0;
	end
	local nTraveled = nTravelCurrent + nDist;
	local sTraveled = tostring(nTraveled);
	DB.setValue(nodeCTWtW, 'traveled', 'string', sTraveled);
end

function processTurnStart(_)
	tStartPosis = {};
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		local tPosi = {};
		local xStart, yStart = getTokenPosition(nodeCT);
		tPosi['x'] = xStart;
		tPosi['y'] = yStart;
		tPosi['nodeCT'] = nodeCT;
		table.insert(tStartPosis, tPosi);
		updateDistTraveled(nodeCT, 0);
	end
end

function getDistTraveled(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.getDistTraveled - not nodeCT");
	end
	local xCurrent, yCurrent = getTokenPosition(nodeCT);
	local xStart;
	local yStart;
	for _,v in ipairs(tStartPosis) do
		if v.nodeCT == nodeCT then
			xStart = v.x;
			yStart = v.y;
		end
	end
	local nDist = calcDistance(xStart, yStart, xCurrent, yCurrent);
	return nDist;
end

function setStartPosi(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.setStartPosi - not nodeCT");
	end
	local bFound;
	for _,v in ipairs(tStartPosis) do
		if v.nodeCT == nodeCT then
			bFound = true;
			local xStart, yStart = getTokenPosition(nodeCT);
			v.x = xStart;
			v.y = yStart;
		end
	end
	if not bFound then
		local tPosi = {};
		local xStart, yStart = getTokenPosition(nodeCT);
		tPosi['x'] = xStart;
		tPosi['y'] = yStart;
		tPosi['nodeCT'] = nodeCT;
		table.insert(tStartPosis, tPosi);
	end
end