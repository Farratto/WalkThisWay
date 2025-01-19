-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals getTokenPosition calcDistance updateDistTraveled processTurnStart getDistTraveled
-- luacheck: globals updateSpeedWindows updateOptionChange handleNewMap onHotKeyTravelDistance processTravelDist
-- luacheck: globals deleteTempTokens processTempTokens prepAsset addLayer deleteLayer getHighestSpeed
-- luacheck: globals returnTokenToLKGStep undoLastStep
-- luacheck: globals addStep

--local tStartPosis = {};

function onInit()
	if Session.IsHost then
		OptionsManager.registerOptionData({	sKey = 'move_on', sGroupRes = 'option_header_WtW', tCustom = { default = "on" } });
		OptionsManager.registerOptionData({	sKey = 'enforce_move', sGroupRes = 'option_header_WtW' });
		--OptionsManager.registerOptionData({	sKey = 'animated_move', sGroupRes = 'option_header_WtW' });
		OptionsManager.registerCallback('move_on', updateOptionChange);
		if OptionsManager.isOption('move_on', 'on') then
			CombatManager.setCustomTurnStart(processTurnStart);
			DB.addHandler('combattracker.list.*.tokenrefid', 'onUpdate', handleNewMap);
		end
	end
	Interface.addKeyedEventHandler("onHotkeyActivated", "traveleddistance", onHotKeyTravelDistance);
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
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	if tokenCT then
		local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
		DB.createChild(nodeCTWtW, 'steps');
		local tSteps = DB.getChildren(nodeCTWtW, 'steps');
		local nodeLastStep;
		local nHighest = 0;
		for sId,nodeStep in pairs(tSteps) do
			local nId = WtWCommon.convNumToIdNodeName(sId);
			if nId > nHighest then
				nodeLastStep = nodeStep;
				nHighest = nId;
			end
		end
		local xStart, yStart = getTokenPosition(nodeCT);
		local hStart = tokenCT.getHeight();
		DB.setValue(nodeLastStep, 'x', 'number', xStart);
		DB.setValue(nodeLastStep, 'y', 'number', yStart);
		DB.setValue(nodeLastStep, 'h', 'number', hStart);
	end
end

--called by hitting button, step 1
function processTravelDist(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.processTravelDist - not nodeCT");
		return;
	end
	local nDist,sSuffix,xCurrent,yCurrent,tokenCT,hCurrent,nLayerID,nodeLastStep,nStep,xStart,yStart = getDistTraveled(nodeCT);
	if nDist then
		updateDistTraveled(nodeCT,nDist,sSuffix,xCurrent,yCurrent,tokenCT,hCurrent,nLayerID,nodeLastStep,nStep,xStart,yStart);
	else
		Debug.console("WalkThisWay.processTravelDist - not nDist");
	end
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

--called by getDistTraveled
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

	local nDistTotalRound = nDistTotalH / GameSystem.getDistanceUnitsPerGrid();
	nDistTotalRound = math.ceil(nDistTotalRound);
	nDistTotalRound = nDistTotalRound / 2;

	return nDistTotalRound;
end

--called by updateDistTraveled
function addStep(nodeCT, nDist, xCurrent, yCurrent, hCurrent, nLayerID)
	if not nodeCT then
		Debug.console("MovementManager.addStep - not nodeCT");
		return;
	end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeSteps = DB.createChild(nodeCTWtW, 'steps');
	local nodeStep = DB.createChild(nodeSteps);
	DB.setValue(nodeStep, 'x', 'number', xCurrent);
	DB.setValue(nodeStep, 'y', 'number', yCurrent);
	DB.setValue(nodeStep, 'h', 'number', hCurrent);
	if nDist ~= 0 then DB.setValue(nodeStep, 'nDist', 'number', nDist) end
	if nLayerID then DB.setValue(nodeStep, 'nLayerID', 'number', nLayerID) end
	return nodeStep;
end

--called by processTravelDist, processTurnStart, handleNewMap, undoLastStep, step 3
function updateDistTraveled(nodeCT,nDist,sSuffix,xCurrent,yCurrent,tokenCT,hCurrent,nLayerID,nodeStep,nStep,xStart,yStart)
	if nDist then nDist = tonumber(nDist) end
	if not nodeCT or not nDist then
		Debug.console("MovementManager.updateDistTraveled - not nodeCT or not nDist");
		return;
	end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nTraveled = DB.getValue(nodeCTWtW, 'traveled_raw', 0) + nDist;
	DB.setValue(nodeCTWtW, 'traveled_raw', 'number', nTraveled);

	local sOwner = WtWCommon.getControllingClient(nodeCT);
	local sPref;
	if sOwner then
		sPref = SpeedManager.getPreference(sOwner);
	else
		sPref = OptionsManager.getOption('DDLU');
	end
	if not sSuffix or sSuffix ~= sPref then
		if not sSuffix then	sSuffix = '' end
		local sSuffixLower = string.lower(sSuffix);
		if string.match(sSuffixLower, "^m%.?$") then
			sSuffix = "m"
		elseif string.match(sSuffixLower, "^tiles%.?$") then
			sSuffix = "tiles"
		else
			sSuffix = "ft.";
		end
	end
	local nConvFactor = SpeedManager.getConversionFactor(sSuffix, sPref);
	local nTraveledConv = nConvFactor * nTraveled;

	--check if character is allowed to move this distance
	if OptionsManager.isOption('enforce_move', "on") then
		if getHighestSpeed(nodeCT) < nTraveledConv then
			returnTokenToLKGStep(nodeCT, tokenCT);
			return;
		end
	end

	--create pointer to show travel
	local SourceX, SourceY, nAssetWidth, nAssetHeight, sPrefColor, nAssetAngle = prepAsset(
		tokenCT, xStart, yStart, nodeCT
	);
	local nodeImage = tokenCT.getContainerNode();
	local nLayerId = addLayer(nodeImage, SourceX, SourceY, nAssetWidth, nAssetHeight, sPrefColor, nAssetAngle);

	local nodeNewStep;
	if nDist >= 0 then
		nodeNewStep = addStep(nodeCT, nDist, xCurrent, yCurrent, hCurrent, nLayerID)
	else
		nodeNewStep = nodeStep;
	end

	local sTraveled = tostring(nTraveledConv).." "..sPref;
	DB.setValue(nodeCTWtW, 'traveled', 'string', sTraveled);
	if nStep == 0 or nDist < 0 then return end
	processTempTokens(nodeCT,nTraveledConv,nStep,sTraveled,xCurrent,yCurrent,tokenCT,hCurrent,sOwner,nodeNewStep);
end

--called by updateDistTraveled, step 4
function processTempTokens(nodeCT,nTraveledConv,nStep,sTraveled,xCurrent,yCurrent,tokenCT,hCurrent,sOwner,nodeStep)
	if not nodeCT then
		Debug.console("MovementManager.processTempTokens - not nodeCT");
		return;
	end
	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	local sProto = tokenCT.getPrototype();
	local nodeContainer = tokenCT.getContainerNode();
	if not xCurrent or not yCurrent then
		xCurrent, yCurrent = getTokenPosition(nodeCT);
	end
	if not hCurrent then hCurrent = tokenCT.getHeight() end

	--Create map indicator
	local tokenNew = Token.addToken(nodeContainer, sProto, xCurrent, yCurrent);
	tokenNew.setScale(0.5);
	tokenNew.setHeight(hCurrent);
	tokenNew.setPublicEdit(false);
	local sPrefColor;
	--if sOwner then
	--	sPrefColor = '50'..string.sub(User.getIdentityColor(sOwner), 3);
	--else
	--	sPrefColor = '50'..string.sub(User.getCurrentIdentityColors(), 3);
	--end
	--tokenNew.addUnderlay(0.5, sPrefColor);

	--add widget showing distance to new token
	if not sTraveled then
		local _,sImageDistSuffix = TokenManager.getImageGridUnits(tokenCT);
		sTraveled = tostring(nTraveledConv)..sImageDistSuffix;
	end
	local tWidget = { name = "moved", position = "topcenter", frame = 'token_ordinal', frameoffset = '7,1,7,1'
		, font = 'token_ordinal', text = sTraveled,
	};
	local widgetMoved = tokenNew.addTextWidget(tWidget);
	widgetMoved.setMaxWidth(350);

	local sName = ActorManager.getDisplayName(nodeCT);
	tokenNew.setName(sName.." - Step "..tostring(nStep)); --this becomes tooltip
	tokenNew.sendToBack();
	--Save token so we can delete it later
	DB.setValue(nodeStep, 'sContainer', 'string', DB.getPath(tokenNew.getContainerNode()));
	DB.setValue(nodeStep, 'nId', 'number', tokenNew.getId());
end

--called by getDistTraveled
function prepAsset(tokenMap, xStart, yStart, sOwner, nodeCT)
	local nSpacing = TokenManager.getTokenSpace(tokenMap);
	if not nSpacing then
		Debug.console("MovementManager.prepAsset - not nSpacing");
		nSpacing = 1;
	end
	local xFinish, yFinish = tokenMap.getPosition();
	local angleRad = math.atan2(yFinish - yStart, xFinish - xStart);
	local nAssetAngle = - math.deg(angleRad);
	local nGridSize = Image.getGridSize(tokenMap.getContainerNode());
	local nDistance = math.sqrt((xFinish- xStart)^2 + (yFinish - yStart)^2);
	local nAssetWidth = (nDistance / nGridSize) - nSpacing;
	nAssetHeight = 0.3;
	-- need to move offset based on diff between spacings
	local nMoveDist = nDistance / 2 + nSpacing / 2;
	-- Find new SourceX,SourceY based on spacing calc for center placement
	local SourceX = xStart + (nMoveDist * math.cos(angleRad));
	local SourceY = yStart + (nMoveDist * math.sin(angleRad));

	local sPrefColor;
	if sOwner then
		sPrefColor = 'C3'..string.sub(User.getIdentityColor(sOwner), 3);
	else
		sPrefColor = 'C3'..string.sub(User.getCurrentIdentityColors(), 3);
	end

	--store data to perhaps redraw at a later time
	if not nodeCT then nodeCT = CombatManager.getCTFromToken(tokenMap) end
	local sNodePathCT = DB.getPath(nodeCT);
	local nodeWTW = DB.createNode('WalkThisWay');
	DB.setPublic(nodeWTW, true);
	local nodeArrows = DB.createChild(nodeWTW, 'arrows');
	local nodeArrowId = DB.createChild(nodeArrows, sNodePathCT);
	local nodeArrow = DB.createChild(nodeArrowId);
	DB.setValue(nodeArrow, SourceX, 'number', SourceX);
	DB.setValue(nodeArrow, SourceY, 'number', SourceY);
	DB.setValue(nodeArrow, nAssetWidth, 'number', nAssetWidth);
	DB.setValue(nodeArrow, nAssetHeight, 'number', nAssetHeight);
	DB.setValue(nodeArrow, sPrefColor, 'string', sPrefColor);
	DB.setValue(nodeArrow, nAssetAngle, 'number', nAssetAngle);

	return SourceX, SourceY, nAssetWidth, nAssetHeight, sPrefColor, nAssetAngle;
end

--called by getDistTraveled
function addLayer(nodeImage, xStart, yStart, nWidth, nHeight, sColor, nAngle)
	if not Session.IsHost then
		Debug.console("MovementManager.addLayer - not isHost");
		return;
	end

	--local tAssets = Interface.getAssets('image', 'images/Extensions');
	local sAsset;
	--for _,v in ipairs(tAssets) do
	--	--grab desired asset
	--	Debug.console("v = "..tostring(v));
	--end

	if not OptionsManager.isOption('animated_move', 'on') then
		sAsset = 'images/Extensions/arrow_move.webp';
	else
		sAsset = 'images/Extensions/footprints_move.webm';
	end

	local sLayerName = 'Arrow Layer'
	local nLayerID = Image.getLayerByName(nodeImage, sLayerName);
	if not nLayerID then nLayerID = Image.addLayer(nodeImage, "paint", { name = sLayerName }) end

	Image.addLayerPaintStamp(nodeImage, nLayerID, {
		asset=sAsset, x=xStart, y=yStart, w=nWidth, h=nHeight, color=sColor, angle=nAngle
	});

	return nLayerID;
end

--called by deleteTempTokens, undoLastStep
function deleteLayer(nodeImage, nLayerID, sLayerName)
	if not Session.IsHost or not nodeImage or (not nLayerID and not sLayerName) then
		Debug.console("MovementManager.deleteLayer - not isHost or not required elements)");
		return;
	end
	if not nLayerID then nLayerID = Image.getLayerByName(nodeImage, sLayerName) end
	Image.deleteLayer(nodeImage, nLayerID);
end

--called by processTurnStart
function deleteTempTokens(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.deleteTempTokens - not nodeCT");
		return;
	end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local tNodesTempTokens = DB.getChildren(nodeCTWtW, 'steps');
	for _,nodeTempToken in pairs(tNodesTempTokens) do
		local sContainer = DB.getValue(nodeTempToken, 'sContainer', '');
		if sContainer then
			local nLayerID = DB.getValue(nodeTempToken, 'nLayerID');
			if nLayerID then deleteLayer(sContainer, nLayerID) end
			local nId = DB.getValue(nodeTempToken, 'nId', '');
			if nId then nId = tonumber(nId) end
			if nId then
				local nodeToken = Token.getToken(sContainer, nId);
				if nodeToken then
					nodeToken.delete();
				else
					Debug.console("MovementManager.deleteTempTokens - not nodeToken");
				end
			end
		else
			Debug.console("MovementManager.deleteTempTokens - not sContainer");
		end
	end
end

--called by setCustomTurnStart and updateOptionChange, step 0
function processTurnStart()
	if OptionsManager.isOption('move_on', 'off') then
		return;
	end
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		local tokenCT = CombatManager.getTokenFromCT(nodeCT);
		deleteTempTokens(nodeCT);
		local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
		local nodeSteps = DB.createChild(nodeCTWtW, 'steps');
		DB.deleteChildren(nodeSteps);
		if tokenCT then
			DB.setValue(nodeCTWtW, 'traveled_raw', 'number', 0);
			local xStart, yStart = getTokenPosition(nodeCT);
			local hStart = tokenCT.getHeight();
			updateDistTraveled(nodeCT, 0, nil, xStart, yStart, tokenCT, hStart, nil, nil, 0);
		end
	end
	local nodeWTW = DB.createNode('WalkThisWay');
	DB.setPublic(nodeWTW, true);
	DB.deleteChild(nodeWTW, 'arrows');
end

--called by processTravelDist, step 2
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
	local nImageDistUnits, sImageDistSuffix = TokenManager.getImageGridUnits(tokenCT);
	if sImageDistSuffix == "" then sImageDistSuffix = "ft." end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	DB.createChild(nodeCTWtW, 'steps');
	local tSteps = DB.getChildren(nodeCTWtW, 'steps');
	local nStep = 0;
	local nHighest = 0;
	local nodeLastStep;
	for sId,nodeStep in pairs(tSteps) do
		nStep = nStep + 1;
		local nId = WtWCommon.convNumToIdNodeName(sId);
		if nId > nHighest then
			nodeLastStep = nodeStep;
			nHighest = nId;
		end
	end
	if not nodeLastStep then
		return 0, sImageDistSuffix, xCurrent, yCurrent, tokenCT, hCurrent;
	end

	local xStart = DB.getValue(nodeLastStep, 'x', nil);
	local yStart = DB.getValue(nodeLastStep, 'y', nil);
	local hStart = DB.getValue(nodeLastStep, 'h', nil);
	local nDist = calcDistance(xStart, yStart, xCurrent, yCurrent, hStart, hCurrent);
	local nDistAdj = nDist * nImageDistUnits;

	return nDistAdj,sImageDistSuffix,xCurrent,yCurrent,tokenCT,hCurrent,nLayerId,nil,nStep,xStart,yStart;
end

--called by updateDistTraveled
function getHighestSpeed(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.getHighestSpeed - not nodeCT");
		return;
	end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nHighest = DB.getValue(nodeCTWtW, 'highest');
	if not nHighest then
		Debug.console("MovementManager.getHighestSpeed - not nHighest");
		local sCurrentSpeed = DB.getValue(nodeCTWtW, 'currentSpeed');
		if not sCurrentSpeed then
			Debug.console("MovementManager.getHighestSpeed - not sCurrentSpeed");
			return;
		end
		nHighest = 0;
		for nSpeed in string.gmatch(sCurrentSpeed, '%d+') do
			if nSpeed > nHighest then nHighest = nSpeed end
		end
	end
	return nHighest;
end

--called by updateDistTraveled
function returnTokenToLKGStep(nodeCT, tokenCT)
	if not nodeCT and not tokenCT then
		Debug.console("MovementManager.returnTokenToLKGStep - not nodeCT or not tokenCT");
		return;
	end
	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local tSteps = DB.getChildren(nodeCTWtW, 'steps');
	local nTraveled = 0;
	local x, y, h;
	local nHighest = 0;
	for sId,nodeStep in pairs(tSteps) do
		nTraveled = nTraveled + DB.getValue(nodeStep, 'nDist', 0);
		local nId = WtWCommon.convNumToIdNodeName(sId);
		if nId > nHighest then
			nHighest = nId;
			x = DB.getValue(nodeStep, 'x');
			y = DB.getValue(nodeStep, 'y');
			h = DB.getValue(nodeStep, 'h');
		end
	end
	DB.setValue(nodeCTWtW, 'traveled_raw', 'number', nTraveled);
	tokenCT.setPosition(x, y);
	tokenCT.setHeight(h);
end

--called by button
--need to make draginfo for the button
function undoLastStep(nodeCT)
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local tSteps = DB.getChildren(nodeCTWtW, 'steps');
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	local x, y, h, xLast, yLast, hLast, nodeToDelete, nLayerID, nLayerIdLast, nDistLast, nodeCurrent;
	local nStep = 0;
	local nHighest = 0;
	local nSecond = 0;
	for sId,nodeStep in pairs(tSteps) do
		nStep = nStep + 1;
		local nId = WtWCommon.convNumToIdNodeName(sId);
		if nId > nHighest then
			nSecond = nHighest;
			x = xLast;
			y = yLast;
			h = hLast;
			nLayerID = nLayerIdLast;
			nodeCurrent = nodeToDelete;

			nHighest = nId;
			nLayerIdLast = DB.getValue(nodeStep, 'nLayerID');
			nDistLast = DB.getValue(nodeStep, 'nDist');
			nodeToDelete = nodeStep;
			xLast = DB.getValue(nodeStep, 'x');
			yLast = DB.getValue(nodeStep, 'y');
			hLast = DB.getValue(nodeStep, 'h');
		end
		if nId < nHighest and nId > nSecond then
			nSecond = nId;
			x = DB.getValue(nodeStep, 'x');
			y = DB.getValue(nodeStep, 'y');
			h = DB.getValue(nodeStep, 'h');
			nLayerID = DB.getValue(nodeStep, 'nLayerID');
			nodeCurrent = nodeStep;
		end
	end
	if not nDistLast then return end
	tokenCT.setPosition(x, y);
	tokenCT.setHeight(h);

	local sContainer = DB.getValue(nodeToDelete, 'sContainer', '');
	if sContainer then
		if nLayerIdLast then deleteLayer(sContainer, nLayerIdLast) end
		local nId = DB.getValue(nodeToDelete, 'nId');
		if nId then
			local nodeToken = Token.getToken(sContainer, nId);
			if nodeToken then
				nodeToken.delete();
			else
				Debug.console("MovementManager.undoLastStep - not nodeToken");
			end
		else
			Debug.console("MovementManager.undoLastStep - not nId");
		end
	end
	DB.deleteNode(nodeToDelete);

	updateDistTraveled(nodeCT, - nDistLast, nil, x, y, tokenCT, h, nLayerID, nodeCurrent, nStep);
end