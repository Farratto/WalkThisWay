-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals getTokenPosition calcDistance updateDistTraveled processTurnStart getDistTraveled
-- luacheck: globals updateSpeedWindows updateOptionChange handleNewMap onHotKeyTravelDistance processTravelDist
-- luacheck: globals deleteTempTokens processTempTokens prepAsset addLayer deleteLayer getHighestSpeed
-- luacheck: globals returnTokenToLKGStep undoLastStep onMoveMM addStep fonMove enforceMove fonWheelHeightHelper
-- luacheck: globals onWheelHeightHelperMM _bSettingToken getGridPosi onTokenRefUpdated handleProcessTraveled
-- luacheck: globals handleUndoLastStep

OOB_MSGTYPE_PROCESS_TRAVELED = 'process_traveled';
OOB_MSGTYPE_UNDO_LASTSTEP = 'undo_laststep';
fonMove = '';
fonWheelHeightHelper = '';
local _bSettingToken;

function onInit()
	OptionsManager.registerOptionData({	sKey = 'move_on', sGroupRes = 'option_header_WtW', tCustom = {
		default = "on" }
	});
	if Session.IsHost then
		OptionsManager.registerOptionData({	sKey = 'enforce_move', sGroupRes = 'option_header_WtW' });
		--OptionsManager.registerOptionData({ sKey = 'animated_move', sGroupRes = 'option_header_WtW' });
		OptionsManager.registerOptionData({ sKey = 'live_move', sGroupRes = 'option_header_WtW' });
		OptionsManager.registerOptionData({ sKey = 'difficult_move', sGroupRes = 'option_header_WtW' });
		OptionsManager.registerCallback('move_on', updateOptionChange);
		if OptionsManager.isOption('move_on', 'on') then
			CombatManager.setCustomTurnStart(processTurnStart);
		end
		DB.addHandler('combattracker.list.*.tokenrefid', 'onUpdate', onTokenRefUpdated);
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PROCESS_TRAVELED, handleProcessTraveled);
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_UNDO_LASTSTEP, handleUndoLastStep);
		fonMove = Token.onMove;
		Token.onMove = onMoveMM;
	end
	fonWheelHeightHelper = TokenManager.onWheelHeightHelper; --client
	TokenManager.onWheelHeightHelper = onWheelHeightHelperMM; --client
	Interface.addKeyedEventHandler("onHotkeyActivated", "traveleddistance", onHotKeyTravelDistance); --client
end

function updateOptionChange()
	if OptionsManager.isOption('move_on', 'on') then
		CombatManager.setCustomTurnStart(processTurnStart);
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

function onTokenRefUpdated(nodeUpdated)
	if _bSettingToken then return end
	local nodeCT = DB.getParent(nodeUpdated);
	local newTokenInstance = Token.getToken(DB.getValue(nodeCT, 'tokenrefnode', ''), tonumber(DB.getValue(
		nodeCT, 'tokenrefid', 0
	)));
	if newTokenInstance then
		handleNewMap(nodeCT, newTokenInstance);
	--else
	--	Debug.console("MovementManager.onTokenRefUpdated - not newTokenInstance");
	end
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

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeLastStep = DB.createChild(nodeCTWtW, 'lastStep');
	local sContainerLK = DB.getValue(nodeLastStep, 'sContainer');
	local nStep = DB.getValue(nodeLastStep, 'nStep', -1);
	processTravelDist(nodeCT, true, newTokenInstance, sContainerLK);
	local xStart, yStart = newTokenInstance.getPosition();
	xStart, yStart = getGridPosi(xStart, yStart);
	local hStart = newTokenInstance.getHeight();
	updateDistTraveled(nodeCT,0,nil,xStart,yStart,newTokenInstance,hStart,nil,nStep+2,nil,nil,true);
end

--called by hitting button, step 1
function processTravelDist(nodeCT, bStep, tokenMap, sContainerLK, xCurrIn, yCurrIn)
	if not nodeCT then
		Debug.console("MovementManager.processTravelDist - not nodeCT");
		return;
	end
	if not Session.IsHost then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_PROCESS_TRAVELED;
		msgOOB.sCTNodeID = DB.getPath(nodeCT);
		if bStep ~= nil then msgOOB.sStepBool = tostring(bStep) end
		if sContainerLK then msgOOB.sContainer = sContainerLK end
		if xCurrIn then msgOOB.sX = tostring(xCurrIn) end
		if yCurrIn then msgOOB.sY = tostring(yCurrIn) end
		Comm.deliverOOBMessage(msgOOB, '');
		return;
	end

	local nDist, sSuffix, xCurrent, yCurrent, tokenCT, hCurrent, nodeLastStep, nStep, xStart, yStart =
		getDistTraveled(nodeCT, tokenMap, sContainerLK, xCurrIn, yCurrIn
	);
	if nDist then
		updateDistTraveled(nodeCT, nDist, sSuffix, xCurrent, yCurrent, tokenCT, hCurrent, nodeLastStep, nStep
			, xStart, yStart, bStep, sContainerLK
		);
	else
		Debug.console("WalkThisWay.processTravelDist - not nDist");
	end
	return;
end
function handleProcessTraveled(msgOOB)
	if not Session.IsHost then return end

	local bStep, sContainerLK, xCurrIn, yCurrIn;

	local nodeCT = DB.findNode(msgOOB.sCTNodeID);
	if msgOOB.sStepBool then
		if msgOOB.sStepBool == 'true' then bStep = true end
		if msgOOB.sStepBool == 'false' then bStep = false end
	end
	if msgOOB.sContainer then sContainerLK = msgOOB.sContainer end
	if msgOOB.sX then xCurrIn = msgOOB.sX end
	if msgOOB.sY then yCurrIn = msgOOB.sY end

	processTravelDist(nodeCT, bStep, nil, sContainerLK, xCurrIn, yCurrIn);
end

function onHotKeyTravelDistance(draginfo)
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
	x, y = getGridPosi(x, y);
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
	local nodeLastStep = DB.createChild(nodeCTWtW, 'lastStep');
	DB.setValue(nodeLastStep, 'nStep', 'number', nStep);
	DB.setValue(nodeStep, 'x', 'number', xCurrent);
	DB.setValue(nodeLastStep, 'x', 'number', xCurrent);
	DB.setValue(nodeStep, 'y', 'number', yCurrent);
	DB.setValue(nodeLastStep, 'y', 'number', yCurrent);
	DB.setValue(nodeStep, 'h', 'number', hCurrent);
	DB.setValue(nodeLastStep, 'h', 'number', hCurrent);
	DB.setValue(nodeStep, 'sContainer', 'string', DB.getPath(sContainer));
	DB.setValue(nodeLastStep, 'sContainer', 'string', DB.getPath(sContainer));
	DB.setValue(nodeStep, 'nDist', 'number', nDist);
	DB.setValue(nodeLastStep, 'nDist', 'number', nDist);

	return nodeStep;
end

--called by processTravelDist, processTurnStart, handleNewMap, undoLastStep, step 3
--luacheck: push ignore 561
function updateDistTraveled(nodeCT, nDist, sSuffix, xCurrent, yCurrent, tokenCT, hCurrent, nodeStep, nStep
	, xStart, yStart, bStep, sContainerLK, bUndo
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
		sPref = DB.getValue(nodeCTWtW, 'units');
		local nConvFactor = DB.getValue(nodeCTWtW, 'conv_factor');
		if not sPref or not nConvFactor then
			sOwner = WtWCommon.getControllingClient(nodeCT);
			if sOwner then
				sPref = SpeedManager.getPreference(sOwner);
			else
				sPref = OptionsManager.getOption('DDLU');
			end
			if sSuffix == '' then sSuffix = 'ft.' end
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
			nConvFactor = SpeedManager.getConversionFactor(sSuffix, sPref);
		end
		nTraveledConv = nConvFactor * nTraveled;

		--check if character is allowed to move this distance
		if OptionsManager.isOption('enforce_move', "on") and not bUndo and nDist > 0 then
			if getHighestSpeed(nodeCT) < nTraveledConv then
				returnTokenToLKGStep(nodeCT, tokenCT);
				return;
			end
		end

		if not OptionsManager.isOption('live_move', 'on') and not bStep then return end
	end
	local nodePosi = DB.createChild(nodeCTWtW, 'latestPosi');
	DB.setValue(nodePosi, 'x', 'number', xCurrent);
	DB.setValue(nodePosi, 'y', 'number', yCurrent);
	DB.setValue(nodePosi, 'h', 'number', hCurrent);

	if not sContainerLK then sContainerLK = tokenCT.getContainerNode() end
	if nDist >= 0 and not bUndo then
		--local SourceX, SourceY, nAssetWidth, nAssetHeight, sPrefColor, nAssetAngle;
		local SourceX, SourceY, nAssetWidth, nAssetHeight, nAssetAngle;
		if (bStep and nDist >= 5) or nDist >= 7.5 then
			--SourceX, SourceY, nAssetWidth, nAssetHeight, sPrefColor, nAssetAngle = prepAsset(
			SourceX, SourceY, nAssetWidth, nAssetHeight, nAssetAngle = prepAsset(
				--tokenCT, xStart, yStart, sOwner, nodeCT, nStep, sContainerLK, xCurrent, yCurrent, bStep
				tokenCT, xStart, yStart, nodeCT, nStep, sContainerLK, xCurrent, yCurrent, bStep
			);
		end
		--addLayer(sContainerLK,SourceX,SourceY,nAssetWidth,nAssetHeight,sPrefColor,nAssetAngle,bStep);
		addLayer(sContainerLK, SourceX, SourceY, nAssetWidth, nAssetHeight, nAssetAngle);
	end

	local nodeNewStep;
	if bStep and nDist >= 0 and not bUndo then
		nodeNewStep = addStep(nodeCT, nDist, xCurrent, yCurrent, hCurrent, nStep, sContainerLK)
	else
		nodeNewStep = nodeStep;
	end

	local sTraveled = "Start";
	if nTraveled ~= 0 then sTraveled = tostring(nTraveledConv).." "..sPref end
	if bStep then
		DB.setValue(nodeCTWtW, 'traveled', 'string', sTraveled);
		--local widgetMoved = tokenCT.findWidget('moved');
		--if widgetMoved then widgetMoved.destroy() end
		WtWCommon.propagateTextWidget(tokenCT, nil, 'moved', true);
	else
		--local widgetMoved = tokenCT.findWidget('moved');
		--if widgetMoved then
		--	widgetMoved.setText(sTraveled);
		--else
		--	local tWidget = { name = 'moved', position = 'topcenter', frame = 'token_ordinal', frameoffset =
		--		'7,1,7,1', font = 'token_ordinal', text = sTraveled
		--	};
		--	local widgetMoved = tokenCT.addTextWidget(tWidget);
		--	widgetMoved.setMaxWidth(350);
		--end
		WtWCommon.propagateTextWidget(tokenCT, sTraveled, 'moved');
	end
	if bStep and nDist >= 0 and not bUndo then
		processTempTokens(nodeCT, nTraveledConv, nStep, sTraveled, xCurrent, yCurrent, tokenCT, hCurrent
			, nodeNewStep, sContainerLK
		);
	end
end
--luacheck: pop

--called by updateDistTraveled, step 4
--function processTempTokens(nodeCT,nTraveledConv,nStep,sTraveled,xCurrent,yCurrent,tokenCT,hCurrent,sOwner,nodeStep,nodeContainer)
function processTempTokens(nodeCT, nTraveledConv, nStep, sTraveled, xCurrent, yCurrent, tokenCT, hCurrent
	, nodeStep,nodeContainer
)
	if not nodeCT then
		Debug.console("MovementManager.processTempTokens - not nodeCT");
		return;
	end
	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	local sProto = tokenCT.getPrototype();
	if not nodeContainer then nodeContainer = tokenCT.getContainerNode() end
	if not xCurrent or not yCurrent then
		xCurrent, yCurrent = tokenCT.getPosition();
		xCurrent, yCurrent = getGridPosi(xCurrent, yCurrent);
	end
	if not hCurrent then hCurrent = tokenCT.getHeight() end

	--Create map indicator
	local tokenNew = Token.addToken(nodeContainer, sProto, xCurrent, yCurrent);
	tokenNew.setScale(0.5);
	tokenNew.setHeight(hCurrent);

	--add widget showing distance to new token
	if not sTraveled then
		local _,sImageDistSuffix = TokenManager.getImageGridUnits(tokenCT);
		sTraveled = tostring(nTraveledConv)..sImageDistSuffix;
	end
	--local tWidget = { name = "moved", position = "topcenter", frame = 'token_ordinal', frameoffset = '7,1,7,1'
	--	, font = 'token_ordinal', text = sTraveled,
	--};
	--local widgetMoved = tokenNew.addTextWidget(tWidget);
	--widgetMoved.setMaxWidth(350);
	WtWCommon.propagateTextWidget(tokenNew, sTraveled, 'moved');

	local sName = ActorManager.getDisplayName(nodeCT);
	if sTraveled == 'Start' then
		tokenNew.setName(sName.." - Start"); --this becomes tooltip
	else
		tokenNew.setName(sName.." - Step "..tostring(nStep)); --this becomes tooltip
	end
	tokenNew.sendToBack();
	tokenNew.setPublicEdit(false);
	tokenCT.bringToFront();

	--Save token so we can delete it later
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeLastStep = DB.createChild(nodeCTWtW, 'lastStep');
	local nId = tokenNew.getId();
	DB.setValue(nodeStep, 'sContainer', 'string', DB.getPath(nodeContainer));
	DB.setValue(nodeStep, 'nId', 'number', nId);
	DB.setValue(nodeLastStep, 'nId', 'number', nId);
end

--called by getDistTraveled
--function prepAsset(tokenMap, xStart, yStart, sOwner, nodeCT, nStep, nodeImage, xFinish, yFinish, bStep)
function prepAsset(tokenMap, xStart, yStart, nodeCT, nStep, nodeImage, xFinish, yFinish, bStep)
	--local nSpacing = TokenManager.getTokenSpace(tokenMap);
	local nSpacing = 1;
	if not nSpacing then
		Debug.console("MovementManager.prepAsset - not nSpacing");
		nSpacing = 1;
	end
	if bStep then
		nSpacing = nSpacing * 0.6;
	else
		nSpacing = nSpacing * 0.8;
	end

	if not xFinish or not yFinish then
		xFinish, yFinish = tokenMap.getPosition();
		xFinish, yFinish = getGridPosi(xFinish, yFinish);
	end
	local angleRad = math.atan2(yFinish - yStart, xFinish - xStart);
	local nAssetAngle = - math.deg(angleRad);
	local nGridSize = Image.getGridSize(tokenMap.getContainerNode());
	local nDistance = math.sqrt((xFinish- xStart)^2 + (yFinish - yStart)^2);
	local nAssetWidth = (nDistance / nGridSize) - nSpacing;
	local nAssetHeight = 0.3;
	-- need to move offset based on diff between spacings
	local nMoveDist = nDistance / 2 + nSpacing / 2;
	-- Find new SourceX,SourceY based on spacing calc for center placement
	local SourceX;
	local SourceY;
	if bStep then
		SourceX = xStart + ((nMoveDist - 0.3) * math.cos(angleRad));
		SourceY = yStart + ((nMoveDist - 0.3) * math.sin(angleRad));
	else
		SourceX = xStart + ((nMoveDist - 1.7) * math.cos(angleRad));
		SourceY = yStart + ((nMoveDist - 1.7) * math.sin(angleRad));
	end

	--local sPrefColor = 'C3000000';
	--if sOwner then
	--	sPrefColor = 'C3'..string.sub(User.getIdentityColor(sOwner), 3);
	--else
	--	sPrefColor = 'C3'..string.sub(User.getCurrentIdentityColors(), 3);
	--end

	--store data to perhaps redraw or delete at a later time
	if not nodeImage then nodeImage = tokenMap.getContainerNode() end
	local sContainer = DB.getPath(nodeImage);
	local nodeWTW = DB.createNode('WalkThisWay');
	DB.setPublic(nodeWTW, true);
	local nodeArrows = DB.createChild(nodeWTW, 'arrows');
	local nodeArrow;
	if bStep then
		if not nodeCT then nodeCT = CombatManager.getCTFromToken(tokenMap) end
		local nodeArrowId = DB.createChild(nodeArrows, DB.getName(nodeCT));
		nodeArrow = DB.createChild(nodeArrowId, WtWCommon.convNumToIdNodeName(nStep));
		DB.setValue(nodeArrow, 'SourceX', 'number', SourceX);
		DB.setValue(nodeArrow, 'SourceY', 'number', SourceY);
		DB.setValue(nodeArrow, 'nAssetWidth', 'number', nAssetWidth);
		DB.setValue(nodeArrow, 'nAssetHeight', 'number', nAssetHeight);
		--DB.setValue(nodeArrow, 'sPrefColor', 'string', sPrefColor);
		DB.setValue(nodeArrow, 'nAssetAngle', 'number', nAssetAngle);
	else
		local nodeArrowId = DB.createChild(nodeArrows, 'temp');
		nodeArrow = DB.createChild(nodeArrowId, 'temp');
	end
	DB.setValue(nodeArrow, 'sContainer', 'string', sContainer);

	--return SourceX, SourceY, nAssetWidth, nAssetHeight, sPrefColor, nAssetAngle;
	return SourceX, SourceY, nAssetWidth, nAssetHeight, nAssetAngle;
end

--called by updateDistTraveled and undoLastStep
--function addLayer(nodeImage, xStart, yStart, nWidth, nHeight, sColor, nAngle, bStep)
function addLayer(nodeImage, xStart, yStart, nWidth, nHeight, nAngle)
	if not Session.IsHost then
		Debug.console("MovementManager.addLayer - not isHost");
		return;
	end

	--local sAsset = 'images/Extensions/arrow_move_highres.webp';
	local sAsset = 'images/Extensions/arrow_move.webp';
	local sColor = 'C3000000'
	local nLayerID;

	if not OptionsManager.isOption('live_move', 'off') then
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
					--local sPrefColor = DB.getValue(nodeArrow, 'sPrefColor');
					local nAssetAngle = DB.getValue(nodeArrow, 'nAssetAngle');
					if SourceX and SourceY and nAssetWidth and nAssetHeight and nAssetAngle then
						if not nLayerID then
							nLayerID = Image.addLayer(nodeImage, 'paint', { name = 'Arrow Layer' });
						end
						Image.addLayerPaintStamp(nodeImage, nLayerID, {	asset=sAsset, x=SourceX, y=SourceY
							--, w=nAssetWidth, h=nAssetHeight, color=sPrefColor, angle=nAssetAngle
							, w=nAssetWidth, h=nAssetHeight, color=sColor, angle=nAssetAngle
						});
					end
				end
			end
		end
	end

	if not nLayerID then nLayerID = Image.getLayerByName(nodeImage, 'Arrow Layer') end
	if not nLayerID then nLayerID = Image.addLayer(nodeImage, 'paint', { name = 'Arrow Layer' }) end
	if xStart then
		Image.addLayerPaintStamp(nodeImage, nLayerID, {
			asset=sAsset, x=xStart, y=yStart, w=nWidth, h=nHeight, color=sColor, angle=nAngle
		});
	end

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
					--Debug.console("sContainer = "..sContainer..". nId = "..tostring(nId));
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
			local sPref;
			local sOwner = WtWCommon.getControllingClient(nodeCT);
			if sOwner then
				sPref = SpeedManager.getPreference(sOwner);
			else
				sPref = OptionsManager.getOption('DDLU');
			end
			local _,sSuffix = TokenManager.getImageGridUnits(tokenCT);
			if sSuffix == '' then sSuffix = 'ft.' end
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
			DB.setValue(nodeCTWtW, 'units', 'string', sPref);
			DB.setValue(nodeCTWtW, 'conv_factor', 'number', nConvFactor);
			DB.setValue(nodeCTWtW, 'traveled_raw', 'number', 0);
			local xStart, yStart, hStart = getTokenPosition(nodeCT);
			updateDistTraveled(nodeCT, 0, nil, xStart, yStart, tokenCT, hStart, nil, 0, nil, nil, true);
		end
	end

	local nodeWTW = DB.createNode('WalkThisWay');
	DB.setPublic(nodeWTW, true);
	local nodeArrows = DB.createChild(nodeWTW, 'arrows');
	local tNodesCTIds = DB.getChildren(nodeWTW, 'arrows');
	for sCTId,_ in pairs(tNodesCTIds) do
		local tNodesArrows = DB.getChildren(nodeArrows, sCTId);
		for _,nodeArrow in pairs(tNodesArrows) do
			local sContainer = DB.getValue(nodeArrow, 'sContainer');
			if sContainer then deleteLayer(sContainer, nil, 'Arrow Layer') end
		end
	end
	DB.deleteChild(nodeWTW, 'arrows');
end

--called by processTravelDist, step 2
function getDistTraveled(nodeCT, tokenCT, sContainerLK, xCurrent, yCurrent)
	if not nodeCT then
		Debug.console("MovementManager.getDistTraveled - not nodeCT");
	end
	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	if not tokenCT then
		Debug.console("MovementManager.getDistTraveled - not tokenCT");
		return;
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local hCurrent;
	if sContainerLK then
		local nodePosi = DB.createChild(nodeCTWtW, 'latestPosi');
		xCurrent = DB.getValue(nodePosi, 'x');
		yCurrent = DB.getValue(nodePosi, 'y');
		hCurrent = DB.getValue(nodePosi, 'h');
	else
		if not xCurrent or not yCurrent then
			xCurrent, yCurrent = tokenCT.getPosition();
			xCurrent, yCurrent = getGridPosi(xCurrent, yCurrent);
		end
		hCurrent = tokenCT.getHeight();
	end

	local nImageDistUnits, sImageDistSuffix = TokenManager.getImageGridUnits(tokenCT);
	--if sImageDistSuffix == "" then sImageDistSuffix = "ft." end

	local nodeLastStep = DB.createChild(nodeCTWtW, 'lastStep');
	if not nodeLastStep then
		return 0, sImageDistSuffix, xCurrent, yCurrent, tokenCT, hCurrent, nil, 0;
	end
	local nStep = DB.getValue(nodeLastStep, 'nStep', -1) + 1;

	local xStart = DB.getValue(nodeLastStep, 'x');
	local yStart = DB.getValue(nodeLastStep, 'y');
	local hStart = DB.getValue(nodeLastStep, 'h');
	local nDist = calcDistance(xStart, yStart, xCurrent, yCurrent, hStart, hCurrent);
	local nDistAdj;
	if not nDist then
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

function handleUndoLastStep(msgOOB)
	if not Session.IsHost then return end

	local nodeCT = DB.findNode(msgOOB.sCTNodeID);

	undoLastStep(nodeCT);
end
--called by button
--need to make draginfo for the button
function undoLastStep(nodeCT)
	if not Session.IsHost then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_UNDO_LASTSTEP;
		msgOOB.sCTNodeID = DB.getPath(nodeCT);
		Comm.deliverOOBMessage(msgOOB, '');
		return;
	end
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local tSteps = DB.getChildren(nodeCTWtW, 'steps');
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	local nodeToDelete, nodeCurrent, nDist, nDistLast;
	local nHighest = -1;
	local nSecond = -1;
	for sStep,nodeStep in pairs(tSteps) do
		local nStepCurrent = WtWCommon.convNumToIdNodeName(sStep);
		if nStepCurrent > nHighest then
			nSecond = nHighest;
			nodeCurrent = nodeToDelete;
			nDist = nDistLast;

			nHighest = nStepCurrent
			nDistLast = DB.getValue(nodeStep, 'nDist');
			nodeToDelete = nodeStep;
		end
		if (nStepCurrent < nHighest and nStepCurrent > nSecond) then
			nSecond = nStepCurrent;
			nodeCurrent = nodeStep;
		end
	end
	if not nDistLast or nHighest == 0 then
		Debug.console("MovementManager.undoLastStep - not nDistLast or nHighest is 0");
		return;
	end
	local x = DB.getValue(nodeCurrent, 'x');
	local y = DB.getValue(nodeCurrent, 'y');
	local h = DB.getValue(nodeCurrent, 'h');
	local sContainerNewLast = DB.getValue(nodeCurrent, 'sContainer');

	--delete tokenstep
	local sContainer = DB.getValue(nodeToDelete, 'sContainer');
	--if sContainer then
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
	--else
	--	Debug.console("MovementManager.undoLastStep - not sContainer");
	--end
	DB.deleteNode(nodeToDelete);

	--move token back to last step
	local tokenNew;
	_bSettingToken = true;
	if sContainer == sContainerNewLast then
		tokenCT.setPosition(x, y);
		tokenNew = tokenCT;
	else
		local sProto = tokenCT.getPrototype();
		tokenNew = Token.addToken(sContainerNewLast, sProto, x, y);
		CombatManager.replaceCombatantToken(nodeCT, tokenNew);
	end
	tokenNew.setHeight(h);
	_bSettingToken = false;

	--replace nodeLastStep here
	local nodeLastStep = DB.createChild(nodeCTWtW, 'lastStep');
	DB.setValue(nodeLastStep, 'nStep', 'number', nSecond);
	DB.setValue(nodeLastStep, 'x', 'number', x);
	DB.setValue(nodeLastStep, 'y', 'number', y);
	DB.setValue(nodeLastStep, 'h', 'number', h);
	DB.setValue(nodeLastStep, 'sContainer', 'string', sContainerNewLast);
	DB.setValue(nodeLastStep, 'nDist', 'number', nDist);
	DB.setValue(nodeLastStep, 'nId', 'number', DB.getValue(nodeCurrent, 'nId'));

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
				--local sPrefColor = DB.getValue(nodeArrow, 'sPrefColor');
				local nAssetAngle = DB.getValue(nodeArrow, 'nAssetAngle');
				if SourceX and SourceY and nAssetWidth and nAssetHeight and nAssetAngle then
					--addLayer(sNodeImage,SourceX,SourceY,nAssetWidth,nAssetHeight,sPrefColor,nAssetAngle);
					addLayer(sNodeImage,SourceX,SourceY,nAssetWidth,nAssetHeight,nAssetAngle);
				end
			end
		end
	end

	updateDistTraveled(nodeCT, - nDistLast, nil, x, y, tokenNew, h, nodeCurrent, nSecond, nil, nil, true
		, sContainerNewLast, true
	);
end

--called anytime a token is moved
function onMoveMM(target)
	if not Session.IsHost or _bSettingToken or Input.isShiftPressed() or (not OptionsManager.isOption('live_move'
		, 'on') and not OptionsManager.isOption('enforce_move', "on")
	) then
		return;
	end
	local nodeCT = CombatManager.getCTFromToken(target);
	if not nodeCT then return end

	--determine grid space
	local xCurrent, yCurrent = target.getPosition();
	if xCurrent and yCurrent then
		xCurrent, yCurrent = getGridPosi(xCurrent, yCurrent);
	else
		return;
	end
	--if we haven't moved far enough to be in a new grid space, stop processing
	local nodeLoc = DB.createChild(nodeCT, 'gridLoc');
	local xPrev = DB.getValue(nodeLoc, 'x', 0);
	local yPrev = DB.getValue(nodeLoc, 'y', 0);
	if xPrev == xCurrent and yPrev == yCurrent then
		return;
	else --if we are in a new grid space, record that space for next time
		DB.setValue(nodeLoc, 'x', 'number', xCurrent);
		DB.setValue(nodeLoc, 'y', 'number', yCurrent);
	end

	if OptionsManager.isOption('difficult_move', 'on') then
		if WtWCommon.hasEffectClause(nodeCT, '^SPEED%s*:%s*difficult') then

		else

		end
	end

	processTravelDist(nodeCT, false, target, nil, xCurrent, yCurrent);
end

--called when token height is adjusted
function onWheelHeightHelperMM(tokenCT, notches) --client
	fonWheelHeightHelper(tokenCT, notches);
	if _bSettingToken or (not OptionsManager.isOption('live_move', 'on') and not OptionsManager.isOption(
		'enforce_move', "on")
	) then
		return;
	end

	local nodeCT = CombatManager.getCTFromToken(tokenCT);
	if not nodeCT then return end

	processTravelDist(nodeCT, false, tokenCT);
end

function getGridPosi(xIn, yIn)
	if not xIn or not yIn then
		Debug.console("MovementManager.getGridPosi - not xIn or not yIn");
		return;
	end
	--xIn = tonumber(xIn);
	--yIn = tonumber(yIn);
	--if not xIn or not yIn then
	--	Debug.console("MovementManager.getGridPosi - xIn or yIn not number");
	--	return;
	--end
	local x = xIn / 5;
	x = WtWCommon.roundNumber(x);
	x = x * 5;
	local y = yIn / 5;
	y = WtWCommon.roundNumber(y);
	y = y * 5;
	return x, y;
end