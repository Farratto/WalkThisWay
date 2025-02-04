-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals getTokenPosition calcDistance updateDistTraveled processTurnStart getDistTraveled
-- luacheck: globals updateSpeedWindows updateOptionChange handleNewMap onHotKeyTravelDistance processTravelDist
-- luacheck: globals deleteTempTokens processTempTokens prepAsset addLayer deleteLayer getHighestSpeed
-- luacheck: globals returnTokenToLKGStep undoLastStep onMoveMM addStep fonMove enforceMove fonWheelHeightHelper
-- luacheck: globals onWheelHeightHelperMM _bSettingToken freplaceCombatantToken replaceCombatantTokenMM

fonMove = '';
fonWheelHeightHelper = '';
freplaceCombatantToken = '';
local _bSettingToken;

function onInit()
	if Session.IsHost then
		OptionsManager.registerOptionData({	sKey = 'move_on', sGroupRes = 'option_header_WtW', tCustom = {
			default = "on" }
		});
		OptionsManager.registerOptionData({	sKey = 'enforce_move', sGroupRes = 'option_header_WtW' });
		--OptionsManager.registerOptionData({ sKey = 'animated_move', sGroupRes = 'option_header_WtW' });
		OptionsManager.registerOptionData({ sKey = 'live_move', sGroupRes = 'option_header_WtW' });
		OptionsManager.registerOptionData({ sKey = 'difficult_move', sGroupRes = 'option_header_WtW' });
		OptionsManager.registerCallback('move_on', updateOptionChange);
		if OptionsManager.isOption('move_on', 'on') then
			CombatManager.setCustomTurnStart(processTurnStart);
			--DB.addHandler('combattracker.list.*.tokenrefnode', 'onUpdate', handleNewMap);
		end
	end
	fonMove = Token.onMove;
	Token.onMove = onMoveMM;
	freplaceCombatantToken = CombatManager.replaceCombatantToken;
	CombatManager.replaceCombatantToken = replaceCombatantTokenMM;
	fonWheelHeightHelper = TokenManager.onWheelHeightHelper; --client
	TokenManager.onWheelHeightHelper = onWheelHeightHelperMM; --client
	Interface.addKeyedEventHandler("onHotkeyActivated", "traveleddistance", onHotKeyTravelDistance); --client
end
function onClose()
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			OptionsManager.unregisterCallback('move_on', updateSpeedWindows);
			if OptionsManager.isOption('move_on', 'on') then
				--DB.removeHandler('combattracker.list.*.tokenrefnode', 'onUpdate', handleNewMap);
			end
		end
	end
end

function updateOptionChange() --client
	if OptionsManager.isOption('move_on', 'on') then
		CombatManager.setCustomTurnStart(processTurnStart);
		--DB.addHandler('combattracker.list.*.tokenrefnode', 'onUpdate', handleNewMap);
	else
		--DB.removeHandler('combattracker.list.*.tokenrefnode', 'onUpdate', handleNewMap);
	end
	updateSpeedWindows();
end

function updateSpeedWindows() --client
	local tSpeedWindows = Interface.getWindows('speed_window');
	for _,v in ipairs(tSpeedWindows) do
		v.speedwindowcontent.subwindow.headertraveled.update();
		v.speedwindowcontent.subwindow.traveled.update();
		v.sub_buttons.subwindow.reset.update();
		v.sub_buttons.subwindow.check.update();
	end
end

function replaceCombatantTokenMM(nodeCT, newTokenInstance)
	freplaceCombatantToken(nodeCT, newTokenInstance);

end
function handleNewMap(nodeCT, newTokenInstance)
	if not nodeCT or not Session.IsHost then
		Debug.console("MovementManager.handleNewMap - not nodeCT or not Session.IsHost");
		return;
	end
	if not newTokenInstance then newTokenInstance = CombatManager.getTokenFromCT(nodeCT) end
	if not newTokenInstance then
		Debug.console("MovementManager.handleNewMap - not newTokenInstance");
		return;
	end
	--local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	--if tokenCT then
		local sContainerCurrent = DB.getPath(newTokenInstance.getContainerNode());
		local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
		local tSteps = DB.getChildren(nodeCTWtW, 'steps');
		local nStep = -1;
		local sContainerLK;
		for sStep,nodeStep in pairs(tSteps) do
			local nStepCurrent = WtWCommon.convNumToIdNodeName(sStep);
			if nStepCurrent > nStep then
				sContainerLK = DB.getValue(nodeStep, 'sContainer');
				nStep = nStepCurrent;
			end
		end
		--if tokenrefnode ~= sContainerLK then
		if sContainerCurrent ~= sContainerLK then
			--processTravelDist(nodeCT, true, tokenCT, true);
			processTravelDist(nodeCT, true, newTokenInstance, true);
			if not nStep then
				Debug.console("MovementManager.handleNewMap - not nStep");
				nStep = 0;
			end
			--local xStart, yStart = tokenCT.getPosition();
			--local hStart = tokenCT.getHeight();
			local xStart, yStart = newTokenInstance.getPosition();
			local hStart = newTokenInstance.getHeight();
			--updateDistTraveled(nodeCT, 0, nil, xStart, yStart, tokenCT, hStart, nil, nStep, nil, nil, true);
			updateDistTraveled(nodeCT,0,nil,xStart,yStart,newTokenInstance,hStart,nil,nStep,nil,nil,true);
		end
	--else
	--	Debug.console("MovementManager.handleNewMap - not tokenCT");
	--end
end

--called by hitting button, step 1
function processTravelDist(nodeCT, bStep, tokenMap, bNewMap) --client
	if not nodeCT then
		Debug.console("MovementManager.processTravelDist - not nodeCT");
		return;
	end
	--host
	local nDist, sSuffix, xCurrent, yCurrent, tokenCT, hCurrent, nodeLastStep, nStep, xStart, yStart =
		getDistTraveled(nodeCT, tokenMap, bNewMap
	);
	--host
	if nDist then
		updateDistTraveled(nodeCT, nDist, sSuffix, xCurrent, yCurrent, tokenCT, hCurrent, nodeLastStep, nStep
			, xStart, yStart, bStep
		);
	else
		Debug.console("WalkThisWay.processTravelDist - not nDist");
	end
	return;
end

function onHotKeyTravelDistance(draginfo) --client
	local nodeCT = draginfo.getDatabaseNode();
	processTravelDist(nodeCT, true);
end

function getTokenPosition(nodeCT)
	if not nodeCT then
		Debug.console("MovementManager.getTokenPosition - not nodeCT");
	end
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	if not tokenCT then return end
	local x, y = tokenCT.getPosition();
	local h = tokenCT.getHeight();
	return x, y, h;
end

--called by getDistTraveled
function calcDistance(xStart, yStart, xCurrent, yCurrent, hStart, hCurrent)
	if not xStart or not yStart or not xCurrent or not yCurrent then
		Debug.console("MovementManager.calcDistance - not xStart or not yStart or not xCurrent or not yCurrent");
		return;
	end
	if not hStart then hStart = 0 end
	if not hCurrent then hCurrent = 0 end

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

	local nLinDist = math.abs(yDist - xDist);
	local nDiagDist;
	if xDist > yDist then
		nDiagDist = yDist;
	else
		nDiagDist = xDist;
	end
	local nDiagDistMult = nDiagDist * nDiagMult;
	local nDistTotal = nDiagDistMult + nLinDist;

	local nLinDistH = nDistTotal;
	local nDiagDistMultH = 0;
	if hDist ~= 0 then
		nLinDistH = math.abs(nDistTotal - hDist);
		local nDiagDistH;
		if nDistTotal > hDist then
			nDiagDistH = hDist;
		else
			nDiagDistH = nDistTotal;
		end
		nDiagDistMultH = nDiagDistH * nDiagMult;
	end
	local nDistTotalH = nDiagDistMultH + nLinDistH;

	local nDistTotalRound = nDistTotalH / GameSystem.getDistanceUnitsPerGrid();
	nDistTotalRound = math.ceil(nDistTotalRound);
	nDistTotalRound = nDistTotalRound / 2;

	return nDistTotalRound;
end

--called by updateDistTraveled
function addStep(nodeCT, nDist, xCurrent, yCurrent, hCurrent, nStep, sContainer)
	if not nodeCT or not nStep then
		Debug.console("MovementManager.addStep - not nodeCT or not nStep");
		return;
	end
	local sStep = WtWCommon.convNumToIdNodeName(nStep);
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeSteps = DB.createChild(nodeCTWtW, 'steps');
	local nodeStep = DB.createChild(nodeSteps, sStep);
	DB.setValue(nodeStep, 'x', 'number', xCurrent);
	DB.setValue(nodeStep, 'y', 'number', yCurrent);
	DB.setValue(nodeStep, 'h', 'number', hCurrent);
	DB.setValue(nodeStep, 'sContainer', 'string', DB.getPath(sContainer));
	if nDist ~= 0 then DB.setValue(nodeStep, 'nDist', 'number', nDist) end
	return nodeStep;
end

--called by processTravelDist, processTurnStart, handleNewMap, undoLastStep, step 3
function updateDistTraveled(nodeCT, nDist, sSuffix, xCurrent, yCurrent, tokenCT, hCurrent, nodeStep, nStep
	, xStart, yStart, bStep
)
	if nDist then nDist = tonumber(nDist) end
	if not nodeCT or not nDist then
		Debug.console("MovementManager.updateDistTraveled - not nodeCT or not nDist");
		return;
	end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nTraveled = DB.getValue(nodeCTWtW, 'traveled_raw', 0) + nDist;
	if bStep then DB.setValue(nodeCTWtW, 'traveled_raw', 'number', nTraveled) end
	local nTraveledConv = nTraveled;

	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	local sOwner;
	local sPref;
	if nTraveled ~= 0 then
		sOwner = WtWCommon.getControllingClient(nodeCT);
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
		nTraveledConv = nConvFactor * nTraveled;

		--check if character is allowed to move this distance
		if OptionsManager.isOption('enforce_move', "on") and nDist > 0 then
			if getHighestSpeed(nodeCT) < nTraveledConv then
				returnTokenToLKGStep(nodeCT, tokenCT);
				return;
			else
				local nodePosi = DB.createChild(nodeCTWtW, 'latestPosi');
				DB.setValue(nodePosi, 'x', 'number', xCurrent);
				DB.setValue(nodePosi, 'y', 'number', yCurrent);
				DB.setValue(nodePosi, 'h', 'number', hCurrent);
			end
		end

		if not OptionsManager.isOption('live_move', 'on') and not bStep then return end
	end

	local nodeImage = tokenCT.getContainerNode();
	--create pointer to show travel
	if nDist >= 5 then
		local SourceX, SourceY, nAssetWidth, nAssetHeight, sPrefColor, nAssetAngle = prepAsset(
			tokenCT, xStart, yStart, sOwner, nodeCT, nStep, nodeImage
		);
		addLayer(nodeImage,SourceX,SourceY,nAssetWidth,nAssetHeight,sPrefColor,nAssetAngle,bStep);
	end

	local nodeNewStep;
	if bStep and nDist >= 0 then
		nodeNewStep = addStep(nodeCT, nDist, xCurrent, yCurrent, hCurrent, nStep, nodeImage)
	else
		nodeNewStep = nodeStep;
	end

	local sTraveled = "Start";
	if nTraveled ~= 0 then sTraveled = tostring(nTraveledConv).." "..sPref end
	if bStep then
		DB.setValue(nodeCTWtW, 'traveled', 'string', sTraveled);
		local widgetMoved = tokenCT.findWidget('moved');
		if widgetMoved then widgetMoved.destroy() end
	else
		local widgetMoved = tokenCT.findWidget('moved');
		if widgetMoved then
			widgetMoved.setText(sTraveled);
		else
			local tWidget = { name = 'moved', position = 'topcenter', frame = 'token_ordinal', frameoffset =
				'7,1,7,1', font = 'token_ordinal', text = sTraveled
			};
			local widgetMoved = tokenCT.addTextWidget(tWidget);
			widgetMoved.setMaxWidth(350);
		end
	end
	if bStep and nDist >= 0 then
		processTempTokens(nodeCT, nTraveledConv, nStep, sTraveled, xCurrent, yCurrent, tokenCT, hCurrent
			, sOwner, nodeNewStep, nodeImage
		);
	end
end

--called by updateDistTraveled, step 4
function processTempTokens(nodeCT,nTraveledConv,nStep,sTraveled,xCurrent,yCurrent,tokenCT,hCurrent,sOwner,nodeStep,nodeContainer)
	if not nodeCT then
		Debug.console("MovementManager.processTempTokens - not nodeCT");
		return;
	end
	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	local sProto = tokenCT.getPrototype();
	if not nodeContainer then nodeContainer = tokenCT.getContainerNode() end
	if not xCurrent or not yCurrent then
		xCurrent, yCurrent, hCurrent = getTokenPosition(nodeCT);
	end
	if not hCurrent then hCurrent = tokenCT.getHeight() end

	--Create map indicator
	local tokenNew = Token.addToken(nodeContainer, sProto, xCurrent, yCurrent);
	tokenNew.setScale(0.5);
	tokenNew.setHeight(hCurrent);
	tokenNew.setPublicEdit(false);
	--local sPrefColor;
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
	if sTraveled == 'Start' then
		tokenNew.setName(sName.." - Start"); --this becomes tooltip
	else
		tokenNew.setName(sName.." - Step "..tostring(nStep)); --this becomes tooltip
	end
	tokenNew.sendToBack();
	--Save token so we can delete it later
	local sContainer = DB.getValue(nodeStep, 'sContainer');
	if not sContainer then
		DB.setValue(nodeStep, 'sContainer', 'string', DB.getPath(tokenNew.getContainerNode()));
	end
	DB.setValue(nodeStep, 'nId', 'number', tokenNew.getId());
end

--called by getDistTraveled
function prepAsset(tokenMap, xStart, yStart, sOwner, nodeCT, nStep, nodeImage)
	local nSpacing = TokenManager.getTokenSpace(tokenMap);
	if not nSpacing then
		Debug.console("MovementManager.prepAsset - not nSpacing");
		nSpacing = 1;
	end
	nSpacing = nSpacing * 0.6;
	local xFinish, yFinish = tokenMap.getPosition();
	local angleRad = math.atan2(yFinish - yStart, xFinish - xStart);
	local nAssetAngle = - math.deg(angleRad);
	local nGridSize = Image.getGridSize(tokenMap.getContainerNode());
	local nDistance = math.sqrt((xFinish- xStart)^2 + (yFinish - yStart)^2);
	local nAssetWidth = (nDistance / nGridSize) - nSpacing;
	local nAssetHeight = 0.3;
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
	if not nodeImage then nodeImage = tokenMap.getContainerNode() end
	local sContainer = DB.getPath(nodeImage);
	--local sNodePathCT = DB.getPath(nodeCT);
	local sNodeNameCT = DB.getName(nodeCT);
	local nodeWTW = DB.createNode('WalkThisWay');
	DB.setPublic(nodeWTW, true);
	local nodeArrows = DB.createChild(nodeWTW, 'arrows');
	local nodeArrowId = DB.createChild(nodeArrows, sNodeNameCT);
	local nodeArrow = DB.createChild(nodeArrowId, WtWCommon.convNumToIdNodeName(nStep));
	DB.setValue(nodeArrow, 'SourceX', 'number', SourceX);
	DB.setValue(nodeArrow, 'SourceY', 'number', SourceY);
	DB.setValue(nodeArrow, 'nAssetWidth', 'number', nAssetWidth);
	DB.setValue(nodeArrow, 'nAssetHeight', 'number', nAssetHeight);
	DB.setValue(nodeArrow, 'sPrefColor', 'string', sPrefColor);
	DB.setValue(nodeArrow, 'nAssetAngle', 'number', nAssetAngle);
	DB.setValue(nodeArrow, 'sContainer', 'string', sContainer);

	return SourceX, SourceY, nAssetWidth, nAssetHeight, sPrefColor, nAssetAngle;
end

--called by updateDistTraveled and undoLastStep
function addLayer(nodeImage, xStart, yStart, nWidth, nHeight, sColor, nAngle, bStep)
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

	--if not OptionsManager.isOption('animated_move', 'on') then
		sAsset = 'images/Extensions/arrow_move.webp';
	--else
	--	sAsset = 'images/Extensions/footprints_move.webm';
	--end

	local nLayerID;

	if not bStep then
		local nodeWTW = DB.createNode('WalkThisWay');
		DB.setPublic(nodeWTW, true);
		local nodeArrows = DB.createChild(nodeWTW, 'arrows');
		deleteLayer(nodeImage, nil, 'Arrow Layer');
		local tArrowsIds = DB.getChildren(nodeWTW, 'arrows');
		local sNodePathImage = DB.getPath(nodeImage);
		for sNodeName in pairs(tArrowsIds) do
			local tArrows = DB.getChildren(nodeArrows, sNodeName);
			for _,nodeArrow in pairs(tArrows) do
				local sNodeImage = DB.getValue(nodeArrow, 'sContainer');
				if sNodeImage == sNodePathImage then
					local SourceX = DB.getValue(nodeArrow, 'SourceX');
					local SourceY = DB.getValue(nodeArrow, 'SourceY');
					local nAssetWidth = DB.getValue(nodeArrow, 'nAssetWidth');
					local nAssetHeight = DB.getValue(nodeArrow, 'nAssetHeight');
					local sPrefColor = DB.getValue(nodeArrow, 'sPrefColor');
					local nAssetAngle = DB.getValue(nodeArrow, 'nAssetAngle');
					if SourceX and SourceY and nAssetWidth and nAssetHeight and nAssetAngle then
						if not nLayerID then
							nLayerID = Image.addLayer(nodeImage, 'paint', { name = 'Arrow Layer' });
						end
						Image.addLayerPaintStamp(nodeImage, nLayerID, {	asset=sAsset, x=SourceX, y=SourceY
							, w=nAssetWidth, h=nAssetHeight, color=sPrefColor, angle=nAssetAngle
						});
					end
				end
			end
		end
	end

	if not nLayerID then nLayerID = Image.getLayerByName(nodeImage, 'Arrow Layer') end
	if not nLayerID then nLayerID = Image.addLayer(nodeImage, 'paint', { name = 'Arrow Layer' }) end
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
	if nLayerID then Image.deleteLayer(nodeImage, nLayerID) end
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
		local sContainer = DB.getValue(nodeTempToken, 'sContainer');
		if sContainer then
			deleteLayer(sContainer, nil, 'Arrow Layer');
			local nId = DB.getValue(nodeTempToken, 'nId');
			if nId then
				local nodeToken = Token.getToken(sContainer, nId);
				if nodeToken then
					nodeToken.delete();
				else
					Debug.console("MovementManager.deleteTempTokens - not nodeToken");
					Debug.console("sContainer = "..sContainer..". nId = "..tostring(nId));
				end
			end
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
			local xStart, yStart, hStart = getTokenPosition(nodeCT);
			--local hStart = tokenCT.getHeight();
			updateDistTraveled(nodeCT, 0, nil, xStart, yStart, tokenCT, hStart, nil, 0, nil, nil, true);
		end
	end
	local nodeWTW = DB.createNode('WalkThisWay');
	DB.setPublic(nodeWTW, true);
	DB.deleteChild(nodeWTW, 'arrows');
end

--called by processTravelDist, step 2
function getDistTraveled(nodeCT, tokenCT, bNewMap)
	if not nodeCT then
		Debug.console("MovementManager.getDistTraveled - not nodeCT");
	end
	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	if not tokenCT then
		Debug.console("MovementManager.getDistTraveled - not tokenCT");
		return;
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local xCurrent, yCurrent, hCurrent;
	if bNewMap then
		local nodePosi = DB.createChild(nodeCTWtW, 'latestPosi');
		xCurrent = DB.getValue(nodePosi, 'x');
		yCurrent = DB.getValue(nodePosi, 'y');
		hCurrent = DB.getValue(nodePosi, 'h');
	else
		xCurrent, yCurrent, hCurrent = getTokenPosition(nodeCT);
		--local hCurrent = tokenCT.getHeight();
	end

	local nImageDistUnits, sImageDistSuffix = TokenManager.getImageGridUnits(tokenCT);
	if sImageDistSuffix == "" then sImageDistSuffix = "ft." end

	DB.createChild(nodeCTWtW, 'steps');
	local tSteps = DB.getChildren(nodeCTWtW, 'steps');
	local nStep = -1;
	local nodeLastStep;
	for sStep,nodeStep in pairs(tSteps) do
		local nStepCurrent = WtWCommon.convNumToIdNodeName(sStep);
		if nStepCurrent > nStep then
			nodeLastStep = nodeStep;
			nStep = nStepCurrent;
		end
	end
	nStep = nStep + 1;
	if not nodeLastStep then
		return 0, sImageDistSuffix, xCurrent, yCurrent, tokenCT, hCurrent, nil, nStep;
	end

	local xStart = DB.getValue(nodeLastStep, 'x', nil);
	local yStart = DB.getValue(nodeLastStep, 'y', nil);
	local hStart = DB.getValue(nodeLastStep, 'h', nil);
	local nDist = calcDistance(xStart, yStart, xCurrent, yCurrent, hStart, hCurrent);
	local nDistAdj;
	if not nDist then
		Debug.console("MovementManager.getDistTraveled - not nDist");
		nDistAdj = 0;
	else
		nDistAdj = nDist * nImageDistUnits;
	end

	return nDistAdj,sImageDistSuffix,xCurrent,yCurrent,tokenCT,hCurrent,nil,nStep,xStart,yStart;
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
	local nodePosi = DB.createChild(nodeCTWtW, 'latestPosi');
	local x = DB.getValue(nodePosi, 'x');
	local y = DB.getValue(nodePosi, 'y');
	local h = DB.getValue(nodePosi, 'h');

	_bSettingToken = true;
	tokenCT.setPosition(x, y);
	tokenCT.setHeight(h);
	_bSettingToken = false;
end

--called by button
--need to make draginfo for the button
function undoLastStep(nodeCT)
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local tSteps = DB.getChildren(nodeCTWtW, 'steps');
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	local x, y, h, xLast, yLast, hLast, nodeToDelete, nDistLast, nodeCurrent;
	local nHighest = -1;
	local nSecond = -1;
	for sStep,nodeStep in pairs(tSteps) do
		local nStepCurrent = WtWCommon.convNumToIdNodeName(sStep);
		if nStepCurrent > nHighest then
			nSecond = nHighest;
			x = xLast;
			y = yLast;
			h = hLast;
			nodeCurrent = nodeToDelete;

			nHighest = nStepCurrent
			nDistLast = DB.getValue(nodeStep, 'nDist');
			nodeToDelete = nodeStep;
			xLast = DB.getValue(nodeStep, 'x');
			yLast = DB.getValue(nodeStep, 'y');
			hLast = DB.getValue(nodeStep, 'h');
		end
		if (nStepCurrent < nHighest and nStepCurrent > nSecond) then
			nSecond = nStepCurrent;
			x = DB.getValue(nodeStep, 'x');
			y = DB.getValue(nodeStep, 'y');
			h = DB.getValue(nodeStep, 'h');
			nodeCurrent = nodeStep;
		end
	end
	if not nDistLast then return end

	_bSettingToken = true;
	tokenCT.setPosition(x, y);
	tokenCT.setHeight(h);
	_bSettingToken = false;

	local sContainer = DB.getValue(nodeToDelete, 'sContainer');
	if sContainer then
		local nId = DB.getValue(nodeToDelete, 'nId');
		if nId then
			local nodeToken = Token.getToken(sContainer, nId);
			if nodeToken then
				nodeToken.delete();
			else
				Debug.console("MovementManager.undoLastStep - not nodeToken");
			end
		end
	else
		Debug.console("MovementManager.undoLastStep - not sContainer");
	end
	DB.deleteNode(nodeToDelete);

	local sNodeNameCT = DB.getName(nodeCT);
	local nodeWTW = DB.createNode('WalkThisWay');
	DB.setPublic(nodeWTW, true);
	local nodeArrows = DB.createChild(nodeWTW, 'arrows');
	local nodeArrowId = DB.createChild(nodeArrows, sNodeNameCT);
	DB.deleteChild(nodeArrowId, WtWCommon.convNumToIdNodeName(nHighest));
	deleteLayer(sContainer, nil, 'Arrow Layer');
	local tArrowsIds = DB.getChildren(nodeWTW, 'arrows');
	for sNodeName in pairs(tArrowsIds) do
		local tArrows = DB.getChildren(nodeArrows, sNodeName);
		for _,nodeArrow in pairs(tArrows) do
			local sNodeImage = DB.getValue(nodeArrow, 'sContainer');
			if sNodeImage == sContainer then
				local SourceX = DB.getValue(nodeArrow, 'SourceX');
				local SourceY = DB.getValue(nodeArrow, 'SourceY');
				local nAssetWidth = DB.getValue(nodeArrow, 'nAssetWidth');
				local nAssetHeight = DB.getValue(nodeArrow, 'nAssetHeight');
				local sPrefColor = DB.getValue(nodeArrow, 'sPrefColor');
				local nAssetAngle = DB.getValue(nodeArrow, 'nAssetAngle');
				if SourceX and SourceY and nAssetWidth and nAssetHeight and nAssetAngle then
					addLayer(sNodeImage,SourceX,SourceY,nAssetWidth,nAssetHeight,sPrefColor,nAssetAngle);
				end
			end
		end
	end

	updateDistTraveled(nodeCT, - nDistLast, nil, x, y, tokenCT, h, nodeCurrent, nSecond, nil, nil, true);
end

--called anytime a token is moved
function onMoveMM(target)
	if _bSettingToken or Input.isShiftPressed() or (not OptionsManager.isOption('live_move', 'on') and
		not OptionsManager.isOption('enforce_move', "on")
	) then
		return;
	end
	local nodeCT = CombatManager.getCTFromToken(target);
	if not nodeCT then return end

	if OptionsManager.isOption('difficult_move', 'on') then
		if WtWCommon.hasEffectClause(nodeCT, '^SPEED%s*:%s*difficult') then

		else

		end
	end

	processTravelDist(nodeCT, false, target);
end

--called when token height is adjusted
function onWheelHeightHelperMM(tokenCT, notches) --client
	fonWheelHeightHelper(tokenCT, notches);
	if _bSettingToken or (not OptionsManager.isOption('live_move', 'on') and not OptionsManager.isOption('enforce_move', "on")) then
		return;
	end

	local nodeCT = CombatManager.getCTFromToken(tokenCT);
	if not nodeCT then return end

	processTravelDist(nodeCT, false, tokenCT); --host
end