-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals getTokenPosition calcDistance updateDistTraveled processTurnStart getDistTraveled setStartPosi
-- luacheck: globals updateSpeedWindows updateOptionChange handleNewMap onHotKeyTravelDistance processTravelDist

local tStartPosis = {};

function onInit()
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			OptionsManager.registerOptionData({	sKey = 'move_on', sGroupRes = 'option_header_WtW', tCustom = { default = "on" } });
			OptionsManager.registerCallback('move_on', updateOptionChange);
			if OptionsManager.isOption('move_on', 'on') then
				CombatManager.setCustomTurnStart(processTurnStart);
				DB.addHandler('combattracker.list.*.tokenrefid', 'onUpdate', handleNewMap);
			end
		end
	end
	Interface.addKeyedEventHandler("onHotkeyActivated", "traveleddistance", MovementManager.onHotKeyTravelDistance);
end
function onClose()
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			OptionsManager.unregisterCallback('move_on', updateSpeedWindows);
			if OptionsManager.isOption('move_on', 'on') then
				DB.removeHandler('combattracker.list.*.tokenrefid', 'onUpdate', handleNewMap);
			end
		end
	end
end

function updateOptionChange()
	if OptionsManager.isOption('move_on', 'on') then
		CombatManager.setCustomTurnStart(processTurnStart);
		DB.addHandler('combattracker.list.*.tokenrefid', 'onUpdate', handleNewMap);
	else
		DB.removeHandler('combattracker.list.*.tokenrefid', 'onUpdate', handleNewMap);
	end
	updateSpeedWindows();
end

function updateSpeedWindows()
	local tSpeedWindows = Interface.getWindows('speed_window');
	for _,v in ipairs(tSpeedWindows) do
		v.speedwindowcontent.subwindow.headertraveled.update();
		v.speedwindowcontent.subwindow.traveled.update();
		v.sub_buttons.subwindow.reset.update();
		v.sub_buttons.subwindow.check.update();
	end
end

function handleNewMap(tokenrefnode)
	local nodeCT = DB.getParent(tokenrefnode);
	setStartPosi(nodeCT);
end

function processTravelDist(nodeCT)
	local nDist,sSuffix = getDistTraveled(nodeCT);
	if nDist then
		updateDistTraveled(nodeCT, nDist, true, sSuffix);
	else
		Debug.console("WalkThisWay.speed.xml - button_check_dist - not nDist");
	end
	setStartPosi(nodeCT);
end

function onHotKeyTravelDistance(draginfo)
	local nodeCT = draginfo.getDatabaseNode();
	processTravelDist(nodeCT);
end

function getTokenPosition(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.getTokenPosition - not nodeCT");
	end
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	if tokenCT then return tokenCT.getPosition() end
end

function calcDistance(xStart, yStart, xCurrent, yCurrent, hStart, hCurrent)
	if not xStart or not yStart or not xCurrent or not yCurrent then
		Debug.console("MovementManager.calcDistance - 18 - not xStart or not yStart or not xCurrent or not yCurrent");
		return;
	end
	if not hStart then hStart = 0 end
	if not hCurrent then hCurrent = 0 end
	xStart = tonumber(xStart);
	yStart = tonumber(yStart);
	hStart = tonumber(hStart);
	xCurrent = tonumber(xCurrent);
	yCurrent = tonumber(yCurrent);
	hCurrent = tonumber(hCurrent);
	if not xStart or not yStart or not xCurrent or not yCurrent or not hCurrent or not hStart then
		Debug.console("MovementManager.calcDistance - not Start or not Current");
		return;
	end
	local xDist = math.abs(xCurrent - xStart);
	local yDist = math.abs(yCurrent - yStart);
	local hDist = math.abs(hCurrent - hStart);

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
		nLinDist = nDiagDistRemainder - nDiagDistX;
	elseif nDiagDistX < nDiagDistY then
		nDiagDist = nDiagDistY;
		nLinDist = nDiagDistRemainder - nDiagDistY;
	else
		nDiagDist = nDiagDistX;
		nLinDist = 0;
	end
	local nDiagDistMult = nDiagDist * nDiagMult;
	local nDistTotal = nDiagDistMult + nLinDist;

	local nDiagDistRemainderH = nDistTotal - hDist;
	local nDiagDistH;
	if nDiagDistRemainderH >= 0 then
		nDiagDistH = hDist;
	else
		nDiagDistH = nDistTotal;
		nDiagDistRemainderH = math.abs(nDiagDistRemainderH);
	end
	local nDiagDistMultH = nDiagDistH * nDiagMult;
	local nDistTotalH = nDiagDistMultH + nDiagDistRemainderH;

	local nDistTotalRound = nDistTotalH / 5;
	nDistTotalRound = math.ceil(nDistTotalRound);
	nDistTotalRound = nDistTotalRound / 2;

	return nDistTotalRound;
end

function updateDistTraveled(nodeCT, nDist, bAdd, sSuffix)
	if nDist then nDist = tonumber(nDist) end
	if not nodeCT or not nDist then
		Debug.console("MovementManager.updateDistTraveled - not nodeCT or not nDist");
		return;
	end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeTraveled = DB.createChild(nodeCTWtW, 'traveled', 'string');
	local sTravelCurrent = DB.getValue(nodeTraveled);
	local nTravelCurrent;
	if sTravelCurrent then
		nTravelCurrent = string.match(sTravelCurrent, '^%d+');
		nTravelCurrent = tonumber(nTravelCurrent)
	end
	if not nTravelCurrent or not bAdd then
		nTravelCurrent = 0;
	end
	local nTraveled = nTravelCurrent + nDist;
	if not sSuffix then
		sSuffix = '';
	else
		if sSuffix == "'" then sSuffix = "ft." end
	end
	local sTraveled = tostring(nTraveled).." "..sSuffix;
	DB.setValue(nodeCTWtW, 'traveled', 'string', sTraveled);
end

function processTurnStart(_)
	if OptionsManager.isOption('move_on', 'off') then
		return;
	end
	tStartPosis = {};
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		local tokenCT = CombatManager.getTokenFromCT(nodeCT);
		if tokenCT then
			local tPosi = {};
			local xStart, yStart = getTokenPosition(nodeCT);
			local hStart = tokenCT.getHeight();
			tPosi['x'] = xStart;
			tPosi['y'] = yStart;
			tPosi['h'] = hStart;
			tPosi['nodeCT'] = nodeCT;
			table.insert(tStartPosis, tPosi);
			updateDistTraveled(nodeCT, 0);
		end
	end
end

function getDistTraveled(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.getDistTraveled - not nodeCT");
	end
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	if not tokenCT then
		Debug.console("MovementManager.getDistTraveled - not nodeCT");
		return;
	end
	local xCurrent, yCurrent = getTokenPosition(nodeCT);
	local hCurrent = tokenCT.getHeight();
	local xStart;
	local yStart;
	local hStart;
	for _,v in ipairs(tStartPosis) do
		if v.nodeCT == nodeCT then
			xStart = v.x;
			yStart = v.y;
			hStart = v.h;
		end
	end
	local nodeContainer = tokenCT.getContainerNode();
	local nImageDistUnits = Image.getDistanceBaseUnits(nodeContainer);
	local sImageDistSuffix = Image.getDistanceSuffix(nodeContainer);
	local nDist = calcDistance(xStart, yStart, xCurrent, yCurrent, hStart, hCurrent);
	local nDistAdj = nDist * nImageDistUnits;
	return nDistAdj, sImageDistSuffix;
end

function setStartPosi(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.setStartPosi - not nodeCT");
	end
	local bFound;
	for _,v in ipairs(tStartPosis) do
		if v.nodeCT == nodeCT then
			bFound = true;
			local tokenCT = CombatManager.getTokenFromCT(nodeCT);
			if tokenCT then
				local xStart, yStart = getTokenPosition(nodeCT);
				local hStart = tokenCT.getHeight();
				v.x = xStart;
				v.y = yStart;
				v.h = hStart;
			end
		end
	end
	if not bFound then
		local tokenCT = CombatManager.getTokenFromCT(nodeCT);
		if tokenCT then
			local tPosi = {};
			local xStart, yStart = getTokenPosition(nodeCT);
			local hStart = tokenCT.getHeight();
			tPosi['x'] = xStart;
			tPosi['y'] = yStart;
			tPosi['h'] = hStart;
			tPosi['nodeCT'] = nodeCT;
			table.insert(tStartPosis, tPosi);
		end
	end
end