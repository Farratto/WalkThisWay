-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

--luacheck: globals fcheckDataBuild checkDataBuildWtW
--luacheck: globals getTextDataInLabel removeEffectsByClause getEffectNamesByText getCompsDataByPattern
--luacheck: globals getRootData getRootList tRootList populateRootList
--luacheck: globals getRootCommander getControllingClient getVisCtEntries getAllImageWindows hasExtension
--luacheck: globals getEffectName cleanString tidyUnits isSavageWorlds
--luacheck: globals clearTable printTable
--luacheck: globals convNumToIdNodeName roundNumber handlePullMoveData aEffectVarMap setConstants
--luacheck: globals getPreference registerPreference handlePrefChange requestPref handlePrefRegistration
--luacheck: globals sendPrefRegistration onIdentityActivationWtW getConversionFactor handleInvalidConvUnits
--luacheck: globals RIGHT_CLICK_TOKEN_SC RIGHT_CLICK_TOKEN_SPEED_TYPE onMenuSelectionToken restoreOtherRightClicks
--luacheck: globals notifyResetRightClick handleResetRightClick
--luacheck: globals processNewCTOwner onTokenRefUpdated onCTDelete
--luacheck: globals fonRecordTypeEvent onRecordTypeEventWtW catchDirtyCtUpdate setWtwDbOwner updateWtwDbOwner
--luacheck: globals restartWindows restartWindow handleWindowRestart
--luacheck: globals isMovementPossible reportError
--luacheck: globals getLimitingSpeed getSpeedTypes tSpeedTypes populateSpeedtypes t5ESpeedTypes tRulesetSpeedTypes
--luacheck: globals notifyEmpty handleNotifyEmpty cleanDatabase handleRemoveTag

--OOB_MSGTYPE_APPLYHCMDS = 'applyhcmds';
OOB_MSGTYPE_REGPREF = 'regpreference';
OOB_MSGTYPE_REQPREF = 'request_preference';
OOB_MSGTYPE_RESET_RIGHTCLICK = 'reset_right_click';
OOB_MSGTYPE_RESTART_WINDOW = 'restart_window'
OOB_MSGTYPE_NOTIFY_EMPTY = 'notify_empty';
local nodeWtW, nodeWtWList, sCTCombatantPath, sCTPath;
local tExtensions = {};
local tClientPrefs = {};
tSpeedTypes = {};
t5ESpeedTypes = {};
tRulesetSpeedTypes = {};
tRootList = {};

--top level
local RIGHT_CLICK_TOKEN_PRIORITY = 1;
RIGHT_CLICK_TOKEN_SC = 2;
--sub levels
local RIGHT_CLICK_TOKEN_WIN = 8;
local RIGHT_CLICK_TOKEN_RESTART = 7;
local RIGHT_CLICK_DASH = 6;
local RIGHT_CLICK_RUN = 5;
local RIGHT_CLICK_TOKEN_TELE_GO = 4;
RIGHT_CLICK_TOKEN_SPEED_TYPE = 3;
local RIGHT_CLICK_TOKEN_DIFF = 2;
	--subsublevel
	local RIGHT_CLICK_TOKEN_DIFF_ON = 8;
	local RIGHT_CLICK_TOKEN_DIFF_OFF = 7;
local RIGHT_CLICK_TOKEN_STEPPAGE = 2;
	--subsublevel
	local RIGHT_CLICK_TOKEN_STEP = 8;
	local RIGHT_CLICK_TOKEN_UNDO = 7;
	local RIGHT_CLICK_TOKEN_ADD_ONE = 6;
	local RIGHT_CLICK_TOKEN_REMOVE_ONE = 5;
local RIGHT_CLICK_TOKEN_GM = 1;
	--subsublevel
	local RIGHT_CLICK_TOKEN_CLEAR = 8
	local RIGHT_CLICK_TOKEN_NO_LIMIT = 7;
	local RIGHT_CLICK_TOKEN_LIMIT = 6;
	local RIGHT_CLICK_TOKEN_TELE_ON = 5;
	local RIGHT_CLICK_TOKEN_TELE_OFF = 4;

aEffectVarMap = {
	['sName'] = { sDBType = 'string', sDBField = 'label' },
	['nGMOnly'] = { sDBType = 'number', sDBField = 'isgmonly' },
	['sSource'] = { sDBType = 'string', sDBField = 'source_name', bClearOnUntargetedDrop = true },
	['sTarget'] = { sDBType = 'string', bClearOnUntargetedDrop = true },
	['nDuration'] = { sDBType = 'number', sDBField = 'duration', vDBDefault = 1, sDisplay = '[D: %d]' },
	['nInit'] = { sDBType = 'number', sDBField = 'init', sSourceChangeSet = 'initresult'
		, bClearOnUntargetedDrop = true
	},
	['sApply'] = { sDBType = 'string', sDBField = 'apply', sDisplay = '[%s]'},
	['sChangeState'] = { sDBType = 'string', sDBField = 'changestate' }
};

function onInit()
	--OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYHCMDS, handleApplyHostCommands);
	if isSavageWorlds() then
		OptionsManager.registerOptionData({	sKey = 'DDLU', bLocal = true,
			tCustom = { labelsres = "option_val_inches|option_val_meters", values = "tiles|m",
				baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
			}
		});
	else
		OptionsManager.registerOptionData({	sKey = 'DDLU', bLocal = true,
			tCustom = { labelsres = "option_val_tiles|option_val_meters", values = "tiles|m",
				baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
			}
		});
	--else
	--	OptionsManager.registerOptionData({	sKey = 'DDLU', bLocal = true,
	--		tCustom = { labelsres = "option_val_meters", values = "m",
	--			baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
	--		}
	--	});
	end
	OptionsManager.registerCallback('DDLU', handlePrefChange);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_REGPREF, handlePrefRegistration);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_REQPREF, sendPrefRegistration);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_RESET_RIGHTCLICK, handleResetRightClick);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_RESTART_WINDOW, handleWindowRestart);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_NOTIFY_EMPTY, handleNotifyEmpty);
	sCTPath = CombatManager.getTrackerPath();
	sCTCombatantPath = CombatManager.getTrackerCombatantPath();
	fcheckDataBuild = EffectQueryManager.checkDataBuild;
	EffectQueryManager.checkDataBuild = checkDataBuildWtW;
	DB.addHandler(sCTCombatantPath..'.tokenrefid', 'onUpdate', onTokenRefUpdated);
	populateSpeedtypes();
	populateRootList();
	if Session.IsHost then
		setConstants();
		User.onIdentityActivation = onIdentityActivationWtW;
		DB.addHandler(sCTCombatantPath..'.NPCowner','onUpdate', processNewCTOwner);
		DB.addHandler(sCTCombatantPath..'.link', 'onUpdate', catchDirtyCtUpdate);
		DB.addHandler('charsheet.*', 'onObserverUpdate', updateWtwDbOwner);
		CombatManager.setCustomPreDeleteCombatantHandler(onCTDelete);
		--fonRecordTypeEvent = CombatRecordManager.onRecordTypeEvent;
		--CombatRecordManager.onRecordTypeEvent = onRecordTypeEventWtW;
	else
		DB.addEventHandler('onDataLoaded', setConstants);
	end
end

function onTabletopInit()
	if Session.IsHost then
		for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
			setWtwDbOwner(nil, nodeCT);
		end
	end
end

function onClose()
	cleanDatabase();
end
--not all extension writers use the functions they are supposed to to remove CT entries.
--My onTokenRef catches those, but I still need to clean out the database of unused entries.
function cleanDatabase()
	if not Session.IsHost then return end

	local tNodesToDelete = {};
	for sNodeCtID, node in pairs(DB.getChildren(nodeWtWList)) do
		local nodeCT = DB.findNode(sCTPath..'.'..sNodeCtID);
		if not nodeCT then
			table.insert(tNodesToDelete, node);
		end
	end

	for sNodeName, nodeChild in pairs(DB.getChildren(nodeWtW, '.')) do
		if string.match(sNodeName, '^id%-%d%d%d%d%d$') then
			table.insert(tNodesToDelete, nodeChild);
		end
	end

	for _,node in pairs(tNodesToDelete) do
		DB.deleteChild(node, '.');
	end
end

function setConstants()
	if Session.IsHost then
		nodeWtW = DB.createNode('WalkThisWay');
		if not nodeWtW then
			reportError("WtWCommon.setConstants - Unrecoverable error - unable to create nodeWtW");
			return;
		end
		DB.setPublic(nodeWtW, true);
		nodeWtWList = DB.createChild(nodeWtW, 'ct_list');
		if not nodeWtWList then
			reportError("WtWCommon.setConstants - Unrecoverable error - unable to create nodeWtWList");
			return;
		end
	else
		nodeWtW = DB.findNode('WalkThisWay');
		if not nodeWtW then
			reportError("WtWCommon.setConstants - Unrecoverable error - unable to find nodeWtW");
			return;
		end
		nodeWtWList = DB.getChild(nodeWtW, 'ct_list');
		if not nodeWtWList then
			reportError("WtWCommon.setConstants - Unrecoverable error - unable to create nodeWtWList");
			return;
		end
	end
end

-- Matches on the filname/foldername or on the name defined in the extension.xml
function hasExtension(sExtName)
	if not tExtensions[1] then tExtensions = Extension.getExtensions() end
	if not sExtName then return end
	for _,sExtension in ipairs(tExtensions) do
		if sExtension == sExtName then return true end
	end
	return false;
end

function setWtwDbOwner(nodeCreature, nodeCT)
	if not nodeCreature then nodeCreature = ActorManager.getCreatureNode(nodeCT) end

	local bGo, sNPCowner;
	if not ActorManager.isPC(nodeCreature) then
		if Pets and Pets.isCohort(nodeCreature) then
			bGo = true;
		else
			if not nodeCT then nodeCT = ActorManager.getCTNode(nodeCreature) end
			sNPCowner = DB.getValue(nodeCT, 'NPCowner');
			if sNPCowner then bGo = true end
		end
	else
		bGo = true;
	end
	if bGo then
		local sOwner;
		if sNPCowner then
			sOwner = sNPCowner;
		else
			sOwner = DB.getOwner(nodeCreature);
		end
		if sOwner and sOwner ~= '' then
			if not nodeCT then nodeCT = ActorManager.getCTNode(nodeCreature) end
			local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
			DB.setOwner(nodeWtWCT, sOwner);
		end
	end
end
function updateWtwDbOwner(nodeChar)
	local nodeCT = ActorManager.getCTNode(nodeChar);
	if not nodeCT then return end
	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));

	local sOwner = DB.getOwner(nodeChar);
	local bOwnerCleared;
	if not sOwner or sOwner == '' then bOwnerCleared = true end
	if not bOwnerCleared then
		DB.setOwner(nodeWtWCT, sOwner);
	else
		DB.removeAllHolders(nodeWtWCT);
	end

	local bPets;
	if Pets and DB.getChildCount(nodeChar, 'cohorts') > 0 then bPets = true end
	for _,nodeCTLoop in ipairs(CombatManager.getAllCombatantNodes()) do
		local nodeWtWCTLoop = DB.createChild(nodeWtWList, DB.getName(nodeCTLoop));
		if bPets and Pets.isCohort(nodeCTLoop) and Pets.getCommanderNode(nodeCTLoop) == nodeChar then
			if bOwnerCleared then
				DB.removeAllHolders(nodeWtWCTLoop);
			else
				DB.setOwner(nodeWtWCTLoop, sOwner);
			end
		elseif not bOwnerCleared then
			if DB.getValue(nodeCTLoop, 'NPCowner', '') == sOwner then
				DB.setOwner(nodeWtWCTLoop, sOwner);
			end
		end
	end
end
function catchDirtyCtUpdate(nodeLink)
	--if not PolymorphismManager or not ActorManager.isPC(rActor) then return end

	local nodeCT = DB.getParent(nodeLink);
	setWtwDbOwner(nil, nodeCT);
	if SpeedManager then
		SpeedManager.parseBaseSpeed(nodeCT, true);
		if OptionsManager.isOption('check_item_str', 'on') then
			SpeedManager.checkInvForHeavyItems(nodeCT);
		end
	end
end
function processNewCTOwner(nodeUpdated)
	local nodeCT = DB.getParent(nodeUpdated);
	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));

	local sNPCowner = DB.getValue(nodeCT, 'NPCowner');
	if sNPCowner then
		DB.setOwner(nodeWtWCT, sNPCowner);
	else
		DB.removeAllHolders(nodeWtWCT);
	end

	notifyResetRightClick(nodeCT);
end

--[[
function hasEffectFindString(rActor, sString, bCaseInsensitive, bReturnString, bReturnNode, bFindAll, bCheckGlobals)
	-- DEFAULTS: case sensitive, not returnString, & not debug
	-- when using bCaseInsensitive, make use of [^%] instead of %uppercase
	-- use sparingly.  Ignores conditionals and targetting
	if not rActor or not sString then
		reportError("WtWCommon.hasEffectFindString - not rActor or not sString");
		return;
	end

	local sClause = sString;
	if bCaseInsensitive then sClause = string.lower(sString) end

	local tEffectsLocs = {};
	table.insert(tEffectsLocs, DB.getChildList(ActorManager.getCTNode(rActor), 'effects'));
	if bCheckGlobals then
		table.insert(tEffectsLocs, DB.getChildList(DB.getChildList(CombatManager.getTrackerEffectParentPath())));
	end

	local tResults = {};
	for _,tEffectTable in pairs(tEffectsLocs) do
		-- Iterate through each effect
		for _, v in pairs(tEffectTable) do
			local bGo = false;
			local tResOne = {};

			local nActive = DB.getValue(v, 'isactive', 0);
			if nActive ~= 0 then bGo = true end

			if bGo then
				local sLabel = DB.getValue(v, 'label', '');
				local sFinalLabel = sLabel;
				sFinalLabel = StringManager.strip(sFinalLabel)
				if bCaseInsensitive then
					sFinalLabel = string.lower(sLabel);
				end

				-- Check for match
				local aFind = string.find(sFinalLabel, sClause)
				if aFind then
					if bFindAll then
						tResOne['label'] = sLabel;
						tResOne['node'] = v;
						table.insert(tResults, tResOne);
					else
						if bReturnString then
							if bReturnNode then
								return sLabel, v;
							else
								return sLabel;
							end
						else
							if bReturnNode then
								return v;
							else
								return true;
							end
						end
					end
				end
			end
		end
	end
	if tResults[1] then return tResults end

	return false;
end
]]
function getTextDataInLabel(rActor, sInput, tData, bPattern, bHasOnly)
	if not rActor or ((sInput or "") == "") then return nil end

	local tCheckData = EffectQueryManager.checkDataBuild(rActor, sInput, true, tData);

	for nIndex,tEffectData in pairs(tCheckData['tEffectsData']) do
		if bPattern then
			if string.match(tEffectData['sLabel'], sInput) then
				local tTemp = {};
				table.insert(tTemp, nIndex);
				table.insert(tCheckData['tMatch'], tTemp);
			end
		else
			if string.lower(tEffectData['sLabel']) == string.lower(sInput) then
				local tTemp = {};
				table.insert(tTemp, nIndex);
				table.insert(tCheckData['tMatch'], tTemp);
			end
		end
	end

	EffectQueryManager.checkDataFinalize(tCheckData);

	if bHasOnly then
		return EffectQueryManager.checkHasResults(tCheckData);
	else
		return EffectQueryManager.getCheckEffectResults(tCheckData);
	end
end

-- make pattern with assumption that all will be converted to lowercase
function removeEffectsByClause(rActor, sInput, tData, bPattern)
	if (sInput or "") == "" then return end

	local tCheckData = EffectQueryManager.checkActorData(rActor, sInput, true, tData);
	local tEffectsData = EffectQueryManager.getCheckEffectResults(tCheckData);

	local tEffectsUbiq = {};
	local tClausesUbiq = {};
	for _, tCompData in ipairs(EffectQueryManager.getCheckCompResults(tCheckData)) do
		if tCompData['kComp'] == 1 then
			local sLabel = StringManager.trim(EffectVarManager.getEffectVarFromNode(tCompData['node'], "sName", ""));
			if bPattern then
				if string.match(sLabel:lower(), sInput) then
					table.insert(tEffectsUbiq, tCompData['node']);
				end
			else
				if sLabel:lower() == StringManager.trim(sInput):lower() then
					table.insert(tEffectsUbiq, tCompData['node']);
				end
			end
		else
			if tClausesUbiq[tCompData['node']] then
				table.insert(tClausesUbiq[tCompData['node']], tCompData['kComp']);
			else
				tClausesUbiq[tCompData['node']] = {};
				table.insert(tClausesUbiq[tCompData['node']], tCompData['kComp']);
			end
		end
	end

	for _,tEffectData in ipairs(tEffectsData) do
		local bFoundNode;
		for _,nodeEffect in ipairs(tEffectsUbiq) do
			if tEffectData['node'] == nodeEffect then
				bFoundNode = true;
				break;
			end
		end

		if not bFoundNode then
			local tCompRebuild = {};
			for _, tComp in ipairs(tEffectData['tComps']) do
				local bFoundComp;
				if tClausesUbiq[tEffectData['node']] then
					for _, nComp in ipairs(tClausesUbiq[tEffectData['node']]) do
						if nComp == tComp['kComp'] then
							bFoundComp = true;
							break;
						end
					end
				end
				if not bFoundComp then table.insert(tCompRebuild, tComp['original']) end
			end
			local sNameNew = EffectManager.rebuildParsedEffect(tCompRebuild);
			EffectVarManager.setEffectVarToNode(tEffectData['node'], 'sName', sNameNew);
		end
	end

	for _,nodeEffect in ipairs(tEffectsUbiq) do
		EffectManager.removeEffectByNode(rActor, nodeEffect);
	end
end

-- when using pattern matching, make use of [^%] instead of %uppercase
-- luacheck: push ignore 561
--[[
function hasEffectClause(rActor, sClause, rTarget, bTargetedOnly, bIgnoreEffectTargets)
	local sLowerClause = sClause:lower();
	local aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');

	-- Iterate through each effect
	for _, v in pairs(aEffects) do
		local nActive = DB.getValue(v, 'isactive', 0);
		local bGo = false;
		local bTargeted;
		if nActive ~= 0 then
			bGo = true;
			bTargeted = EffectManager.isTargetedEffect(v);
		end

		if bGo then
			-- Parse each effect label
			local sLabel = DB.getValue(v, 'label', '');
			local aEffectComps = EffectManager.parseEffect(sLabel);

			-- Iterate through each effect component looking for a type match
			for _, sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
				-- Handle conditionals
				local sOriginalLower = string.lower(rEffectComp.original);
				if EffectManager5E then
					-- Handle conditionals
					if rEffectComp.type == "IF" then
						if not EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
							break;
						end
					elseif rEffectComp.type == "IFT" then
						if not rTarget then break end
						if not EffectManager5E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
							break;
						end
					end
				end
				-- Check for match
				if string.match(sOriginalLower, sLowerClause) then
					if bTargeted and not bIgnoreEffectTargets then
						if EffectManager.isEffectTarget(v, rTarget) then return true, sLabel, v end
					else
						if not bTargetedOnly then return true, sLabel, v end
					end
				end
			end
		end
	end
	return false;
end
]]
-- luacheck: pop
-- make pattern with assumption that all will be converted to lowercase
function getCompsDataByPattern(rActor, sInput, tData, bPattern, bHasOnly)
	if not bPattern then
		if bHasOnly then
			return EffectManager.hasText(rActor, sInput, tData);
		else
			return EffectManager.getCompsDataByText(rActor, sInput, tData);
		end
	end

	if not rActor or ((sInput or "") == "") then return nil end

	local tCheckData = EffectQueryManager.checkDataBuild(rActor, sInput, true, tData);
	--EffectQueryManager.checkDataEffects(tCheckData);
	for nEffect,tEffectData in ipairs(tCheckData['tEffectsData'] or {}) do
		tCheckData['nEffectCheck'] = nEffect;
		if GameManager.callFunction("onEffectCheckApply", tCheckData) then
			--EffectQueryManager.checkDataComps(tCheckData);
			EffectQueryManager.checkDataCompSetup(tCheckData);
			for nComp in ipairs(EffectManager.parseEffectComps(tEffectData)) do
				tCheckData['nCompCheck'] = nComp;
				if EffectQueryManager.checkDataCompConditional(tCheckData) then
					--if EffectQueryManager.checkDataCompApply(tCheckData) then
					local tCompData = tEffectData['tComps'][nComp];
					if tCompData then
						--return (tCompData['original']:lower() == tCheckData['sEffectTag']:lower());
						if string.match(StringManager.trim(string.lower(tCompData['original'])), sInput) then
							EffectQueryManager.checkDataCompOnMatch(tCheckData);
						end
					end
				end
			end
			EffectQueryManager.checkDataCompCleanup(tCheckData);
		end
	end
	tCheckData['nEffectCheck'] = nil;

	EffectQueryManager.checkDataFinalize(tCheckData);

	if bHasOnly then
		return EffectQueryManager.checkHasResults(tCheckData);
	else
		return EffectQueryManager.getCheckCompResults(tCheckData);
	end
end

--[[
function notifyApplyHostCommands(nodeCT, iAction, rValues)
	local msgOOB = {};
	msgOOB['type'] = OOB_MSGTYPE_APPLYHCMDS;
	msgOOB['iAction'] = iAction;
	msgOOB['sNodeCT'] = DB.getPath(nodeCT);

	if Session.IsHost then
		handleApplyHostCommands(msgOOB);
		return;
	end

	if msgOOB['iAction'] == 0 then
		for k in pairs(rValues) do
			if aEffectVarMap[k] then
				if aEffectVarMap[k]['sDBType'] == 'number' then
					msgOOB[k] = rValues[k] or aEffectVarMap[k]['vDBDefault'] or 0;
				else
					msgOOB[k] = rValues[k] or aEffectVarMap[k]['vDBDefault'] or '';
				end
			end
		end
	elseif msgOOB['iAction'] == 1 then
		msgOOB['sEffect'] = rValues;
	end

	Comm.deliverOOBMessage(msgOOB);
end
function handleApplyHostCommands(msgOOB)
	if not Session.IsHost then return end

	local nodeCT = DB.findNode(msgOOB['sNodeCT']);
	local iAction = tonumber(msgOOB['iAction']);

	if iAction == 0 then --add an effect (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
		local rNewEffect = {};
		for k in pairs(msgOOB) do
			if aEffectVarMap[k] then
				if aEffectVarMap[k]['sDBType'] == 'number' then
					rNewEffect[k] = tonumber(msgOOB[k]) or 0;
				else
					rNewEffect[k] = msgOOB[k];
				end
			end
		end
		EffectManager.addEffect('', '', nodeCT, rNewEffect, true);
	elseif iAction == 1 then --remove effect
		EffectManager.removeEffect(nodeCT, msgOOB['sEffect']);
	else --iAction not found
		ChatManager.SystemMessage(
			"WtWCommon.handleApplyHostCommands - Unsupported iAction("..tostring(iAction)..")"
		);
	end
end
]]

--Returns nil for inactive identities and those owned by the GM
function getControllingClient(nodeCT)
	if not nodeCT then return nil end

	local rActor = ActorManager.resolveActor(nodeCT);
	local sPCNode, sNPCowner;
	if ActorManager.isPC(rActor) then
		sPCNode = ActorManager.getCreatureNodeName(rActor);
	else
		sNPCowner = DB.getValue(nodeCT, 'NPCowner', '');
		if sNPCowner == '' then
			if Pets and Pets.isCohort(rActor) then sPCNode = getRootCommander(rActor) end
		end
	end

	if sPCNode or sNPCowner then
		for _,value in pairs(User.getAllActiveIdentities()) do
			if sPCNode then
				if 'charsheet.' .. value == sPCNode then return User.getIdentityOwner(value) end
			end
			if sNPCowner then
				local sIDOwner = User.getIdentityOwner(value)
				if sIDOwner == sNPCowner then return sIDOwner end
			end
		end
	end
	return nil;
end
---For a given cohort actor, determine the root character node that owns it
function getRootCommander(rActor)
	local sRecord = ActorManager.getCreatureNodeName(rActor);
	local sRecordSansModule = StringManager.split(sRecord, "@")[1];
	local aRecordPathSansModule = StringManager.split(sRecordSansModule, ".");
	if aRecordPathSansModule[1] and aRecordPathSansModule[2] then
		return aRecordPathSansModule[1] .. "." .. aRecordPathSansModule[2];
	end
	return nil;
end

function getEffectName(nodeEffect, sLabel)
	if not sLabel and (not nodeEffect or type(nodeEffect) ~= 'databasenode') then return "" end
	if not sLabel then sLabel = DB.getValue(nodeEffect, 'label') end
	if not sLabel or sLabel == '' then return "" end
	local aClauses = StringManager.split(sLabel, ';');
	return cleanString(aClauses[1]);
end
function cleanString(s)
	if not s then return end
	local sReturn = StringManager.strip(s);
	sReturn = string.gsub(sReturn, '^%s+', '');
	sReturn = string.gsub(sReturn, '%s+$', '');
	return sReturn;
end

--rEffectComp = EffectManager.parseEffectCompSimple
	--rEffectComp.type = any alphanumeric at beginning (may start with @) and ending in colon without spacesSymbols
	--rEffectComp.mod = numbers after rEffectComp.type
	--rEffectComp.dice = dice table representing what appeared after rEffectComp.type
	--rEffectComp.sRemainder = everything not included in type, mod, and dice
	--rEffectComp.remainder = rEffectComp.sRemainder as a comma-separated table
	--rEffectComp.original = original clause
function checkDataBuildWtW(rActor, sEffectTag, bFullText, tData)
	local tTagOptions = EffectQueryManager.getTagOptions(sEffectTag);

	if not tData then
		tData = {};
		tData['bIncludeGlobal'] = true;
	elseif nil == tData['bIncludeGlobal'] or tData['bIncludeGlobal'] ~= false then
		tData['bIncludeGlobal'] = true;
	end

	local tCheckData = {
		rActor = ActorManager.resolveActor(rActor),
		rTarget = tData and tData.rTarget,
		bTargetedOnly = tData and tData.bTargetedOnly,
		tEffectsData = ActorEffectManager.getEffectsData(rActor, {
			bIncludeGlobal = tData['bIncludeGlobal'],--changed from always true
			bIgnoreDisabled = (tTagOptions and tTagOptions.bIgnoreDisabled),
		}),
		sEffectTag = sEffectTag,
		bFullText = bFullText,
		tTagOptions = tTagOptions,
		bIgnoreExpire = tData and tData.bIgnoreExpire,
		tEffectsIgnore = tData and tData.tEffectsIgnore,
		tFilters = EffectQueryManager.buildCheckFilter(tData and tData.tFilter),
		tActionTags = tData and tData.tActionTags,
		tMatch = {},
		tEffectResults = {},
		tCompResults = {},
		-- For conditional debugging
		-- For topmost check, use local tParent = tCheckData; while tParent.tParent do tParent = tParent.tParent; end
		tParent = tData and tData.tParent,
	};

	return tCheckData;
end

--this is going to ignore IF statements on rulesets not 5E due to processConditional pulled from BCEG
--potential replacement: EffectManager.getCompsDataByTag(rActor, sEffectTag, tData)
--[[
function getEffectsByTypeWtW(rActor, sEffectType, _, rFilterActor, bTargetedOnly, bCaseSensitive)
	if not rActor then
		reportError("WtWCommon.getEffectsByTypeWtW - not rActor");
		return;
	end
	local results = {};

	local aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');

	-- Iterate through effects
	for _, v in pairs(aEffects) do
		-- Check active
		local nActive = DB.getValue(v, 'isactive', 0);
		local rConditionalHelper = {bProcessEffect = true, aORStack = {}, aELSEStack = {}, bTargeted = false};
		if (not EffectManagerADND and nActive ~= 0) or
			(EffectManagerADND and ((EffectManagerADND.isValidCheckEffect(rActor, v) or --luacheck: ignore 143
					(rFilterActor and EffectManagerADND.isValidCheckEffect(rFilterActor, v))))) then --luacheck: ignore 143
			local sLabel = DB.getValue(v, 'label', '');
			-- IF COMPONENT WE ARE LOOKING FOR SUPPORTS TARGETS, THEN CHECK AGAINST OUR TARGET
			rConditionalHelper.bTargeted = EffectManager.isTargetedEffect(v);

			if not rConditionalHelper.bTargeted or (rFilterActor and EffectManager.isEffectTarget(v, rFilterActor)) then
				local aEffectComps = EffectManager.parseEffect(sLabel);
				-- Look for type/subtype match
				for _, sEffectComp in ipairs(aEffectComps) do
					local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
					processConditional(rActor, rFilterActor, v, rEffectComp, rConditionalHelper);

					if rConditionalHelper.bProcessEffect then
						local comp_match = false;
						-- Check for match
						local sEffectCompLower = string.lower(tostring(sEffectComp));

						local bPrelimMatch;
						if bCaseSensitive then
							if string.match(sEffectComp, '^' .. sEffectType) then
								bPrelimMatch = true;
							end
						else
							if string.match(sEffectCompLower, '^' .. string.lower(sEffectType)) then
								bPrelimMatch = true;
							end
						end
						if rEffectComp.type == sEffectType or rEffectComp.original == sEffectType or bPrelimMatch then
							-- Check effect targeting
							if bTargetedOnly and not rConditionalHelper.bTargeted then
								comp_match = false;
							else
								comp_match = true;
							end
						end

						-- Match!
						if comp_match then
							if nActive == 1 then
								if sLabel ~= '' then rEffectComp['label'] = sLabel end
								table.insert(results, rEffectComp);
							end
						end
					end
				end -- END EFFECT COMPONENT LOOP
			end -- END TARGET CHECK
		end -- END ACTIVE CHECK
	end -- END EFFECT LOOP
	-- RESULTS
	return results;
end
--this is from old BCEG.  It will ignore IF statements in rulesets not 5E.
function processConditional(rActor, rTarget, rEffect, rEffectComp, rConditionalHelper)
	local bOR = table.remove(rConditionalHelper.aORStack);

	if rEffectComp.original == 'OR' then
		if bOR and not rConditionalHelper.bProcessEffect then
			rConditionalHelper.bSkipIF = false;
			rConditionalHelper.bProcessEffect = true;
			if next(rConditionalHelper.aELSEStack) then
				table.remove(rConditionalHelper.aELSEStack);
			end
		elseif not bOR then
			rConditionalHelper.bSkipIF = true;
		end

	elseif rEffectComp.type == 'ELSE' then
		if next(rConditionalHelper.aELSEStack) then
			if rConditionalHelper.aELSEStack[1] == rEffectComp.mod then
				table.remove(rConditionalHelper.aELSEStack, 1);
				rConditionalHelper.bProcessEffect = true;
			else
				rConditionalHelper.bProcessEffect = false;
			end
		else
			rConditionalHelper.bProcessEffect = false;
		end
		rConditionalHelper.aORStack = {};
	elseif bOR and rEffectComp.original ~= 'OR' then
		rConditionalHelper.bSkipIF = true;
	end

	if not rConditionalHelper.bSkipIF and rConditionalHelper.bProcessEffect then
		-- Handle conditionals
		local bUntrueExt = hasExtension('IF_NOT_untrue_effects_berwind');
		local RulesetEffectManager;
		if EffectManager5E then
			RulesetEffectManager = EffectManager5E;

		--elseif EffectManagerPFRPG2 then
		--	RulesetEffectManager = EffectManagerPFRPG2;
		--elseif EffectManagerADND then
		--	RulesetEffectManager = EffectManagerADND;
		--elseif EffectManagerSFRPG then
		--	RulesetEffectManager = EffectManagerSFRPG;
		--elseif EffectManager35E then
		--	RulesetEffectManager = EffectManager35E;
		--elseif EffectManager4E then
		--	RulesetEffectManager = EffectManager4E;

		end
		if not RulesetEffectManager then return end
		if rEffectComp.type == 'IF' or (bUntrueExt and rEffectComp.type == 'IFN') then
			if not RulesetEffectManager.checkConditional(rActor, rEffect, rEffectComp.remainder) then
				conditionalFail(rConditionalHelper, rEffectComp);
			else
				conditionalSuccess(rConditionalHelper, rEffectComp);
			end
		elseif rEffectComp.type == 'IFT' or (bUntrueExt and rEffectComp.type == 'IFTN') then
			if not rTarget then
				rConditionalHelper.bProcessEffect = false
			else
				if not RulesetEffectManager.checkConditional(rTarget, rEffect, rEffectComp.remainder, rActor) then
					conditionalFail(rConditionalHelper, rEffectComp);
				else
					conditionalSuccess(rConditionalHelper, rEffectComp);
					rConditionalHelper.bTargeted = true;
				end
			end
		end
	end
	if rEffectComp.original ~= 'OR' then
		rConditionalHelper.bSkipIF = false;
	end
end
function conditionalFail(rConditionalHelper, rEffectComp)
	rConditionalHelper.bProcessEffect = false;
	if rEffectComp.mod > 0 then
		table.insert(rConditionalHelper.aELSEStack, rEffectComp.mod);
	end
	table.insert(rConditionalHelper.aORStack, true);
end
function conditionalSuccess(rConditionalHelper, rEffectComp)
	for i = #rConditionalHelper.aELSEStack, 1, -1 do
		if rConditionalHelper.aELSEStack[i] == rEffectComp.mod then
			table.remove(rConditionalHelper.aELSEStack, i);
		end
	end
	rConditionalHelper.bProcessEffect = true;
end
]]

-- luacheck: push ignore 561
--[[
function hasRoot(nodeCT)
	if Session.RulesetName ~= "5E" then
		if EffectManagerPFRPG2 then
			if hasEffectClause(nodeCT, "^Unconscious$", nil, false, true) then
				return true, false, 'Unconscious';
			elseif hasEffectClause(nodeCT, "^Dead$", nil, false, true) then
				return true, false, 'Dead';
			elseif hasEffectClause(nodeCT, "^Paralyzed$", nil, false, true) then
				return true, false, 'Paralyzed';
			elseif hasEffectClause(nodeCT, "^Dying$", nil, false, true) then
				return true, false, 'Dying';
			elseif hasEffectClause(nodeCT, "^Immobilized$", nil, false, true) then
				return true, false, 'Immobilized';
			elseif hasEffectClause(nodeCT, "^Petrified$", nil, false, true) then
				return true, false, 'Petrified';
			elseif hasEffectClause(nodeCT, "^Restrained$", nil, false, true) then
				return true, false, 'Restrained';
			elseif hasEffectClause(nodeCT, "^Grabbed$", nil, false, true) then
				return true, false, 'Grabbed';
			elseif hasEffectClause(nodeCT, "^Stunned$", nil, false, true) then
				return true, false, 'Stunned';
			else
				local bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*max%s*%(%s*0%s*%)$"
					, nil, false, true, true
				);
				if bHas then
					return true, false, getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*0%s*max$"
						, nil, false, true, true
					);
					if bHas then
						return true, false, getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "^Speed%s*:%s*0$"
							, nil, false, true, true
						);
						if bHas then
							return true, false, getEffectName(false, sLabel);
						else
							bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*none$"
								, nil, false, true, true
							);
							if bHas then
								return true, false, getEffectName(false, sLabel);
							else
								return false;
							end
						end
					end
				end
			end
		elseif Session.RulesetName == 'PFRPG' or Session.RulesetName == '3.5E' then
			if hasEffectClause(nodeCT, "^Unconscious$", nil, false, true) then
				return true, false, 'Unconscious';
			elseif hasEffectClause(nodeCT, "^Dead$", nil, false, true) then
				return true, false, 'Dead';
			elseif hasEffectClause(nodeCT, "^Paralyzed$", nil, false, true) then
				return true, false, 'Paralyzed';
			elseif hasEffectClause(nodeCT, "^Dying$", nil, false, true) then
				return true, false, 'Dying';
			elseif hasEffectClause(nodeCT, "^Cowering$", nil, false, true) then
				return true, false, 'Cowering';
			elseif hasEffectClause(nodeCT, "^Petrified$", nil, false, true) then
				return true, false, 'Petrified';
			elseif hasEffectClause(nodeCT, "^Dazed$", nil, false, true) then
				return true, false, 'Dazed';
			elseif hasEffectClause(nodeCT, "^Grappled$", nil, false, true) then
				return true, false, 'Grappled';
			elseif hasEffectClause(nodeCT, "^Stunned$", nil, false, true) then
				return true, false, 'Stunned';
			elseif hasEffectClause(nodeCT, "^Helpless$", nil, false, true) then
				return true, false, 'Helpless';
			elseif hasEffectClause(nodeCT, "^Pinned$", nil, false, true) then
				return true, false, 'Pinned';
			elseif hasEffectClause(nodeCT, "^Stable$", nil, false, true) then
				return true, false, 'Stable';
			else
				local bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*max%s*%(%s*0%s*%)$"
					, nil, false, true, true
				);
				if bHas then
					return true, false, getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*0%s*max$"
						, nil, false, true, true
					);
					if bHas then
						return true, false, getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "^Speed%s*:%s*0$"
							, nil, false, true, true
						);
						if bHas then
							return true, false, getEffectName(false, sLabel);
						else
							bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*none$"
								, nil, false, true, true
							);
							if bHas then
								return true, false, getEffectName(false, sLabel);
							else
								return false;
							end
						end
					end
				end
			end
		else
			if hasEffectClause(nodeCT, "^Unconscious$", nil, false, true) then
				return true, false, 'Unconscious';
			else
				local bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*max%s*%(%s*0%s*%)$"
					, nil, false, true, true
				);
				if bHas then
					return true, false, getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*0%s*max$"
						, nil, false, true, true
					);
					if bHas then
						return true, false, getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "^Speed%s*:%s*0$"
							, nil, false, true, true
						);
						if bHas then
							return true, false, getEffectName(false, sLabel);
						else
							bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*none$"
								, nil, false, true, true
							);
							if bHas then
								return true, false, getEffectName(false, sLabel);
							else
								return false;
							end
						end
					end
				end
			end
		end
	else
		local bReturn;
		local sEffectName;
		if hasEffectClause(nodeCT, "^Grappled$", nil, false, true) then
			bReturn = true;
			sEffectName = 'Grappled';
		elseif hasEffectClause(nodeCT, "^Paralyzed$", nil, false, true) then
			bReturn = true;
			sEffectName = 'Paralyzed';
		elseif hasEffectClause(nodeCT, "^Petrified$", nil, false, true) then
			bReturn = true;
			sEffectName = 'Petrified';
		elseif hasEffectClause(nodeCT, "^Restrained$", nil, false, true) then
			bReturn = true;
			sEffectName = 'Restrained';
		elseif hasEffectClause(nodeCT, "^Unconscious$", nil, false, true) then
			bReturn = true;
			sEffectName = 'Unconscious';
		elseif hasEffectClause(nodeCT, "^DEATH$", nil, false, true) then
			bReturn = true;
			sEffectName = 'DEATH';
		else
			local bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*max%s*%(%s*0%s*%)$"
				, nil, false, true, true
			);
			if bHas then
				bReturn = true;
				sEffectName = getEffectName(false, sLabel);
			else
				bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*0%s*max$"
					, nil, false, true, true
				);
				if bHas then
					bReturn = true;
					sEffectName = getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "^Speed%s*:%s*0$"
						, nil, false, true, true
					);
					if bHas then
						bReturn = true;
						sEffectName = getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*none$"
							, nil, false, true, true
						);
						if bHas then
							bReturn = true;
							sEffectName = getEffectName(false, sLabel);
						else
							return false;
						end
					end
				end
			end
		end
		if bReturn then
			if hasEffectClause(nodeCT,
				"^[Ss][Pp][Ee][Ee][Dd]%s*:%s*%d*%s*type%s*%(%s*[%l%u]*%s*%(%s*hover%s*%)%s*%)$"
			) then
				return true, true, sEffectName;
			else
				return true, false, sEffectName;
			end
		end
	end
end
]]
-- luacheck: pop
function getRootData(nodeCT)
	local tEffectNames = {};
	for _, sRoot in pairs(getRootList()) do
		getEffectNamesByText(nodeCT, sRoot, tEffectNames);
	end
	return tEffectNames;
end
function populateRootList()
	table.insert(tRootList, "Unconscious");
	table.insert(tRootList, "SPEED: max(0)");
	table.insert(tRootList, "SPEED: 0 max");
	table.insert(tRootList, "Speed: 0");
	table.insert(tRootList, "SPEED: none");
	table.insert(tRootList, "DEATH");
	table.insert(tRootList, "Dead");
	table.insert(tRootList, "Dying");
	table.insert(tRootList, "Grappled");
	table.insert(tRootList, "Paralyzed");
	table.insert(tRootList, "Petrified");

	if Session.RulesetName == '5E'
		or Session.RulesetName == 'PFRPG2'
		or Session.RulesetName == 'PFRPG' or Session.RulesetName == '3.5E'
	then
		table.insert(tRootList, "Restrained");
	end

	if Session.RulesetName == 'PFRPG2' then
		table.insert(tRootList, "Immobilized");
		table.insert(tRootList, "Grabbed");
		table.insert(tRootList, "Stunned");
		return;
	end

	if Session.RulesetName == 'PFRPG' or Session.RulesetName == '3.5E' then
		table.insert(tRootList, "Cowering");
		table.insert(tRootList, "Dazed");
		table.insert(tRootList, "Stunned");
		table.insert(tRootList, "Helpless");
		table.insert(tRootList, "Pinned");
	end
end
function getRootList(sRuleSet, b2024)
	if not sRuleSet then sRuleSet = Session.RulesetName end

	local tReturn = tRootList;
	if sRuleSet == '5E' then
		if b2024 == nil then b2024 = OptionsManager.isOption('GAVE', '2024') end
		if not b2024 then table.insert(tReturn, "STUNNED") end
	end

	return tReturn;
end

function getEffectNamesByText(rActor, sText, tEffectNames)
	local tEffectsData = EffectQueryManager.getEffectsDataByText(rActor, sText);
	if not tEffectsData then return false, {} end

	local bFound = false;
	if not tEffectNames then tEffectNames = {} end
	for _, tEffectData in ipairs(tEffectsData) do
		bFound = true;
		table.insert(tEffectNames, getEffectName(nil, tEffectData['sLabel']));
	end
	return bFound, tEffectNames;
end

function convNumToIdNodeName(nId)
	if not string.match(tostring(nId), '^id%-%d%d%d%d%d$') then
		nId = tostring(nId);
		local nZeros = 5 - #nId;
		local sId = 'id-'
		while nZeros > 0 do
			sId = sId..'0'
			nZeros = nZeros - 1;
		end
		return sId..nId;
	else
		local sReturn = string.match(nId, '%d+');
		local nReturn = tonumber(sReturn);
		if not nReturn then
			reportError("WtWCommon.convNumToIdNodeName - not nReturn");
		else
			return nReturn;
		end
	end
end

function roundNumber(nInput, nPlaces, sUpDown, nRoundBy)
	if not nRoundBy then nRoundBy = 1 end

	nInput = nInput / nRoundBy;

	--accommodation for negative numbers
	local nMultiplier = 1;
	if nInput < 0 then
		nMultiplier = -1;
		nInput = nMultiplier * nInput;
	end

	if not nPlaces then nPlaces = 0 end
	local nPlaceAdj = 10^nPlaces;
	nInput = nInput * nPlaceAdj;

	local nWhole, nDec;
	if sUpDown then
		if sUpDown == 'up' then
			nWhole = math.floor(nInput);
			if (nInput - nWhole) > 0.00000001 then nWhole = nWhole + 1 end
		elseif sUpDown == 'grid' then
			nWhole = math.floor(nInput);
			if (nInput - nWhole) >= 0.25 then nWhole = nWhole + 1 end
		elseif sUpDown == 'down' then
			nWhole = math.floor(nInput);
		end
	else
		nWhole = math.floor(nInput);
		nDec = nInput - nWhole;
	end

	if nDec and nDec >= 0.5 then
		nWhole = nWhole + 1;
	end

	return ((nMultiplier * nWhole) / nPlaceAdj) * nRoundBy;
end

function getConversionFactor(sCurrentUnits, sDesiredUnits, bIRL)
	if sCurrentUnits == sDesiredUnits then return 1 end
	if sCurrentUnits == 'ft.' then
		if sDesiredUnits == 'm' then
			if not bIRL then
				return 0.3;
			else
				return 0.3048;
			end
		elseif sDesiredUnits == 'tiles' then
			if isSavageWorlds() then
				return 1 / 6;
			else
				return 0.2;
			end
		elseif sDesiredUnits == 'mi.' then
			return 1 / 5280;
		else
			return handleInvalidConvUnits(sDesiredUnits, false);
		end
	elseif sCurrentUnits == 'm' then
		if sDesiredUnits == 'ft.' then
			if not bIRL then
				return 1 / 0.3;
			else
				return 1 / 0.3048;
			end
		elseif sDesiredUnits == 'tiles' then
			if isSavageWorlds() then
				return 0.5;
			else
				return 1 / 1.5;
			end
		elseif sDesiredUnits == 'mi.' then
			return 1 / 1609.344;
		else
			return handleInvalidConvUnits(sDesiredUnits, false);
		end
	elseif sCurrentUnits == 'tiles' then
		if isSavageWorlds() then
			if sDesiredUnits == 'ft.' then
				return 6;
			elseif sDesiredUnits == 'm' then
				return 2;
			else
				return handleInvalidConvUnits(sDesiredUnits, false);
			end
		else
			if sDesiredUnits == 'ft.' then
				return 5;
			elseif sDesiredUnits == 'm' then
			if not bIRL then
					return 1.5;
				else
					return 1.524;
				end
			else
				return handleInvalidConvUnits(sDesiredUnits, false);
			end
		end
	elseif sCurrentUnits == 'mph' then
		if sDesiredUnits == 'ft.' then
			return 8.8;
		elseif sDesiredUnits == 'm' then
			return 2.68224;
		elseif sDesiredUnits == 'tiles' then
			if isSavageWorlds() then
				return 8.8 / 6;
			else
				return 1.76;
			end
		else
			return handleInvalidConvUnits(sDesiredUnits, false);
		end
	else
		return handleInvalidConvUnits(sCurrentUnits, true);
	end
end
function handleInvalidConvUnits(sUnits, bCurrentUnits)
	local sUnitWhich = 'desired';
	if bCurrentUnits then sUnitWhich = 'current' end

	reportError("WtWCommon.getConversionFactor - Invalid "..sUnitWhich.." units: "..tostring(sUnits));
	Debug.printstack();

	return 1;
end

function onIdentityActivationWtW(_, username, activated)
	if activated then requestPref(username) end
end
function requestPref(sUser)
	Comm.deliverOOBMessage({ type = OOB_MSGTYPE_REQPREF }, sUser);
end
function sendPrefRegistration(msgOOB) --luacheck: ignore 312
	msgOOB = {};
	msgOOB['type'] = OOB_MSGTYPE_REGPREF;
	msgOOB['sPref'] = OptionsManager.getOption('DDLU');
	msgOOB['sOwner'] = Session.UserName;
	Comm.deliverOOBMessage(msgOOB);
end
function handlePrefRegistration(msgOOB)
	if not Session.IsHost then return end

	registerPreference(msgOOB['sOwner'], msgOOB['sPref']);

	if SpeedManager then SpeedManager.recalcAllSpeeds(msgOOB.sOwner) end
end
function registerPreference(sOwner, sPref)
	for sOwnerKey in pairs(tClientPrefs) do
		if sOwnerKey == sOwner then
			tClientPrefs[sOwnerKey] = sPref;
			return;
		end
	end
	tClientPrefs[sOwner] = sPref;
end
function handlePrefChange(sOptionKey) --luacheck: ignore 212
	if Session.IsHost then
		if SpeedManager then SpeedManager.recalcAllSpeeds() end
	else
		sendPrefRegistration();
	end
end
function getPreference(nodeCT)
	if not Session.IsHost or not nodeCT then return OptionsManager.getOption('DDLU') end

	local sOwner = getControllingClient(nodeCT);
	if not sOwner then return OptionsManager.getOption('DDLU') end

	for sOwnerKey,sPref in pairs(tClientPrefs) do
		if sOwnerKey == sOwner then return sPref end
	end

	requestPref(sOwner);
	return OptionsManager.getOption('DDLU');
end

function isSavageWorlds()
	if Session.RulesetName == 'SavageWorlds'
		or Session.RulesetName == 'SWADE'
		or Session.RulesetName == 'SWD'
		or Session.RulesetName == 'SWPF'
	then
		return true;
	else
		return false;
	end
end

function getVisCtEntries()
	local sCTPath = CombatManager.CT_MAIN_PATH;
	local sWinClass = 'combattracker_host'
	if not Session.IsHost then sWinClass = 'combattracker_client' end

	local winCT = Interface.findWindow(sWinClass, sCTPath);
	if not winCT then
		winCT = Interface.openWindow(sWinClass, sCTPath);
		winCT.close();
	end

	local tNodes = {};
	for _,win in ipairs(winCT.list.getWindows(true)) do
		local nodeWin = win.getDatabaseNode();
		table.insert(tNodes, nodeWin);
	end
	return tNodes;
end

function getAllImageWindows()
	local tReturn = {};
	for _,win in ipairs(Interface.getWindows()) do
		if ImageManager.isImageWindow(win) then
			local winImage;
			if win.getImage then
				winImage = win;
			elseif win.sub.subwindow then
				winImage = win.sub.subwindow;
			end
			if winImage then table.insert(tReturn, winImage) end
		end
	end

	return tReturn;
end

function registerTokenRightClick(tokenCT, nodeCT, bNoMenu)
	if not tokenCT and not nodeCT then return end
	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	if not nodeCT then nodeCT = CombatManager.getCTFromToken(tokenCT) end
	if not tokenCT or not nodeCT then return end

	tokenCT.resetMenuItems();
	tokenCT.registerMenuItem('Step Counter', 'tool_shoe_false', RIGHT_CLICK_TOKEN_SC);
	if SpeedManager then
		tokenCT.registerMenuItem('Open Speed Window', 'restorewindow', RIGHT_CLICK_TOKEN_SC
			, RIGHT_CLICK_TOKEN_WIN
		);
		if Session.RulesetName == '5E' then
			tokenCT.registerMenuItem('Dash', 'tokenacceptmove', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_DASH
			);
		else
			tokenCT.registerMenuItem('Double Move', 'tokenacceptmove', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_DASH
			);
			if Session.RulesetName == '3.5E' or 'PFRPG' then
				tokenCT.registerMenuItem('Run', 'tokenacceptmove', RIGHT_CLICK_TOKEN_SC
					, RIGHT_CLICK_RUN
				);
			end
		end
	end
	if StepManager then
		local nodeWtWCT = DB.getChild(nodeWtWList, DB.getName(nodeCT));
		local nTeleAllowed = DB.getValue(nodeWtWCT, 'teleport_allowed', 2);
		tokenCT.registerMenuItem('Steppage', 'tool_shoe_false', RIGHT_CLICK_TOKEN_SC
			, RIGHT_CLICK_TOKEN_STEPPAGE
		);
		tokenCT.registerMenuItem('Create Step', 'radial_plus', RIGHT_CLICK_TOKEN_SC
			, RIGHT_CLICK_TOKEN_STEPPAGE , RIGHT_CLICK_TOKEN_STEP
		);
		tokenCT.registerMenuItem('Undo Last Step', 'return', RIGHT_CLICK_TOKEN_SC
			, RIGHT_CLICK_TOKEN_STEPPAGE , RIGHT_CLICK_TOKEN_UNDO
		);
		tokenCT.registerMenuItem('Add 1 Tile to Movement', 'num1', RIGHT_CLICK_TOKEN_SC
			, RIGHT_CLICK_TOKEN_STEPPAGE , RIGHT_CLICK_TOKEN_ADD_ONE
		);
		tokenCT.registerMenuItem('Remove 1 Tile from Movement', 'num1', RIGHT_CLICK_TOKEN_SC
			, RIGHT_CLICK_TOKEN_STEPPAGE , RIGHT_CLICK_TOKEN_REMOVE_ONE
		);
		if Session.IsHost
			or (Session.UserName == getControllingClient(nodeCT)
				and ((OptionsManager.isOption('allow_tele', 'on') and nTeleAllowed ~= 0) or nTeleAllowed == 1)
			)
		then
			tokenCT.registerMenuItem('Flag as Teleporting Now', 'tool_shoe_false', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_TELE_GO
			);
		end
		tokenCT.registerMenuItem('Return to Start', 'chatclear', RIGHT_CLICK_TOKEN_SC
			, RIGHT_CLICK_TOKEN_RESTART
		);
		if Session.IsHost then
			tokenCT.registerMenuItem('GM Tools', 'tool_shoe_false', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_GM
			);
			tokenCT.registerMenuItem('Clear Movement Data', 'chatclear', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_GM, RIGHT_CLICK_TOKEN_CLEAR
			);
			tokenCT.registerMenuItem('Allow Teleport', 'unlock', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_GM, RIGHT_CLICK_TOKEN_TELE_ON
			);
			tokenCT.registerMenuItem('Forbid Teleport', 'lock', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_GM, RIGHT_CLICK_TOKEN_TELE_OFF
			);
		end
		if SpeedManager then
			tokenCT.registerMenuItem('Open Speed Window', 'restorewindow', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_WIN
			);
			tokenCT.registerMenuItem('Speed Type', 'tool_shoe_false', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_SPEED_TYPE
			);
			tokenCT.registerMenuItem('Difficult Terrain', 'imageviewmenu', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_DIFF
			);
			tokenCT.registerMenuItem('On', 'imageviewmenu', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_DIFF, RIGHT_CLICK_TOKEN_DIFF_ON
			);
			tokenCT.registerMenuItem('Off', 'tool_shoe_false', RIGHT_CLICK_TOKEN_SC
				, RIGHT_CLICK_TOKEN_DIFF, RIGHT_CLICK_TOKEN_DIFF_OFF
			);
			if Session.IsHost then
				tokenCT.registerMenuItem('Allow to Exceed Movement Limit', 'unlock', RIGHT_CLICK_TOKEN_SC
					, RIGHT_CLICK_TOKEN_GM, RIGHT_CLICK_TOKEN_NO_LIMIT
				);
				tokenCT.registerMenuItem('Enforce Movement Limit', 'lock', RIGHT_CLICK_TOKEN_SC
					, RIGHT_CLICK_TOKEN_GM, RIGHT_CLICK_TOKEN_LIMIT
				);
			end
			local sLabels, _, sEmptyLabel = getSpeedTypes(nodeCT);
			StepManager.populateRightClickSpeedTypes(tokenCT, nodeCT, sLabels, sEmptyLabel);
		end
	end

	restoreOtherRightClicks(tokenCT, nodeCT);

	if not bNoMenu then tokenCT.onMenuSelection = onMenuSelectionToken end
end
function restoreOtherRightClicks(tokenCT, nodeCT)
	if not tokenCT and not nodeCT then return end
	if not tokenCT then tokenCT = CombatManager.getTokenFromCT(nodeCT) end
	if not tokenCT then return end

	if hasExtension('B9_SpellTokens') then
		tokenCT.registerMenuItem(Interface.getString('tokentogglepriority'), 'tokentogglepriority'
			, RIGHT_CLICK_TOKEN_PRIORITY
		);
	end
end
-- luacheck: push ignore 561
function onMenuSelectionToken(token, nSelection, nSub, nSubSub)
	local nodeCT = CombatManager.getCTFromToken(token);
	if not nodeCT then
		token.resetMenuItems();
		restoreOtherRightClicks(token);
		token.onMenuSelection = onMenuSelectionToken;
		return;
	end
	if not Session.IsHost then
		local sOwner = getControllingClient(nodeCT);
		if not sOwner or sOwner ~= Session.UserName then
			token.resetMenuItems();
			restoreOtherRightClicks(token);
			token.onMenuSelection = onMenuSelectionToken;
			return;
		end
	end

	if nSub == RIGHT_CLICK_TOKEN_WIN then
		SpeedManager.openSpeedWindow(nodeCT);
	elseif nSub == RIGHT_CLICK_TOKEN_STEPPAGE then
		if nSubSub == RIGHT_CLICK_TOKEN_ADD_ONE then
			if OptionsManager.isOption('SC_enabled', 'off') then
				ChatManager.Message("Step Counter usage: Movement tracking currently disabled.");
				return;
			end
			StepManager.addOneTile(nodeCT, token, 1);
		elseif nSubSub == RIGHT_CLICK_TOKEN_REMOVE_ONE then
			if OptionsManager.isOption('SC_enabled', 'off') then
				ChatManager.Message("Step Counter usage: Movement tracking currently disabled.");
				return;
			end
			StepManager.addOneTile(nodeCT, token, -1);
		elseif nSubSub == RIGHT_CLICK_TOKEN_STEP then
			if OptionsManager.isOption('SC_enabled', 'off') then
				ChatManager.Message("Step Counter usage: Movement tracking currently disabled.");
				return;
			end
			StepManager.processTravelDist(nodeCT, true, token);
		elseif nSubSub == RIGHT_CLICK_TOKEN_UNDO then
			if OptionsManager.isOption('SC_enabled', 'off') then
				ChatManager.Message("Step Counter usage: Movement tracking currently disabled.");
				return;
			end
			StepManager.undoLastStep(nodeCT, false, token);
		end
	elseif nSub == RIGHT_CLICK_DASH then
		local rValues = { sName = 'Double Move; SPEED: doubled', nDuration = 1, sChangeState = 'rts' };
		if Session.RulesetName == "5E" then
			rValues = { sName = 'Dash; STACK', nDuration = 1, sChangeState = 'rts' };
		end
		--[[if Session.IsHost then
			EffectManager.addEffect('', '', nodeCT, rValues, true);
		else
			notifyApplyHostCommands(nodeCT, 0, rValues);
		end]]
		EffectManager.addEffectByTable(nodeCT, rValues)
	elseif nSub == RIGHT_CLICK_RUN then
		local nodeChar = nodeCT;
		if ActorManager.isPC(nodeCT) then nodeChar = ActorManager.getCreatureNode(nodeCT) end

		local rValues = { sName = 'Run; SPEED: doubled; SPEED: doubled', nDuration = 1, sChangeState = 'rts' };

		local bFound;
		for _,nodeItem in pairs(DB.getChildren(nodeChar, 'inventorylist')) do
			if DB.getValue(nodeItem, 'carried', 0) == 2
				and string.lower(DB.getValue(nodeItem, 'subtype', '')) == 'heavy armor'
				or (string.lower(DB.getValue(nodeItem, 'type', '')) == 'armor'
					and string.lower(DB.getValue(nodeItem, 'subtype', '')) == 'heavy'
					)
			then
				bFound = true;
			end
		end
		if bFound then rValues = { sName = 'Run; SPEED: tripled', nDuration = 1, sChangeState = 'rts' } end

		EffectManager.addEffectByTable(nodeCT, rValues)
	elseif nSub == RIGHT_CLICK_TOKEN_TELE_GO then
		if OptionsManager.isOption('SC_enabled', 'off') then
			ChatManager.Message("Step Counter usage: Movement tracking currently disabled.");
			return;
		end
		local nodeWtWCT = DB.getChild(nodeWtWList, DB.getName(nodeCT));
		local nTeleAllowed = DB.getValue(nodeWtWCT, 'teleport_allowed', 2);
		if (OptionsManager.isOption('allow_tele', 'on') and nTeleAllowed ~= 0)
			or Session.IsHost
			or nTeleAllowed == 1
		then
			StepManager.processTravelDist(nodeCT, true, token);
			StepManager.propagateTextWidget(token, "Tele Start", nil, 'dist_label_large', -13);
			DB.setValue(nodeWtWCT, 'teleport', 'number', 1);
		else
			reportError("That creature is not permitted to teleport.", true, false);
		end
	elseif nSub == RIGHT_CLICK_TOKEN_RESTART then
		if OptionsManager.isOption('SC_enabled', 'off') then
			reportError("Step Counter usage: Movement tracking currently disabled.", true, false);
			return;
		end
		for nodeCTTmp,tokenTmp in pairs(StepManager.getMoreTargets(nodeCT, token)) do
			StepManager.returnToStart(nodeCTTmp, tokenTmp);
		end
	elseif nSub == RIGHT_CLICK_TOKEN_DIFF then
		if Session.IsHost then
			StepManager.processManualDifficult(nodeCT, nSubSub == RIGHT_CLICK_TOKEN_DIFF_ON);
		else
			local msgOOB = {};
			msgOOB.type = StepManager.OOB_MSGTYPE_NOTIFY_MANUAL_DIFFICULT;
			msgOOB.sCTNodeID = DB.getPath(nodeCT);
			if nSub == RIGHT_CLICK_TOKEN_DIFF_ON then
				msgOOB.sDifficult = '1';
			else
				msgOOB.sDifficult = '0';
			end
			Comm.deliverOOBMessage(msgOOB, '');
		end
	elseif nSub == RIGHT_CLICK_TOKEN_SPEED_TYPE then
		local nodeWtWCT = DB.getChild(nodeWtWList, DB.getName(nodeCT));
		local sSpeedType = DB.getValue(nodeWtWCT, 'speed_type');
		local sDefaultSpeedType = DB.getValue(nodeWtWCT, 'speed_type_default');
		local sValues = DB.getValue(nodeWtWCT, 'speed_type_values');
		for nK, sLabel in pairs(StepManager.tTypesToNumbers) do
			local sLabelLower = string.lower(sLabel);
			if nSubSub == nK then
				local bDefault;
				local sValue = string.match(sDefaultSpeedType, '^'..sLabelLower);
				if sValue then
					if not sSpeedType then return end
					bDefault = true;
					DB.deleteChild(nodeWtWCT, 'speed_type');
					restartWindows('speed_window', nodeWtWCT, nodeCT, Session.UserName);
				end
				if not sValue then sValue = string.match(sValues, '^'..sLabelLower..'%s+%(.*%)') end
				if not sValue then sValue = string.match(sValues, '^'..sLabelLower) end
				if not sValue then
					sValue = string.match(sValues, '|'..sLabelLower);
					if not sValue then
						registerTokenRightClick(token, nodeCT, true);
						reportError("WtWCommon.onMenuSelectionToken - not sValue");
						return;
					end
					sValue = string.gsub(sValue, '^|', '');
					sValue = string.gsub(sValue, '|.*$', '');
				end
				if sSpeedType and sSpeedType == sValue then return end
				local bGoLabel = StepManager.determineGoSpeedChange(nodeCT);
				if not bDefault then DB.setValue(nodeWtWCT, 'speed_type', 'string', sValue) end
				local tokenNew = StepManager.updateProto(nodeCT, nodeWtWCT, token, sValue);
				if bGoLabel then
					StepManager.processTravelDist(nodeCT, false, tokenNew, nil, nil, nil, nil, nil, true);
				end
				StepManager.updateSpeedWindow(nodeCT, sValue, nodeWtWCT)
				return;
			end
		end
	elseif nSub == RIGHT_CLICK_TOKEN_GM then
		local nodeWtWCT = DB.getChild(nodeWtWList, DB.getName(nodeCT));
		if nSubSub == RIGHT_CLICK_TOKEN_CLEAR then
			for nodeCTTmp,tokenTmp in pairs(StepManager.getMoreTargets(nodeCT, token)) do
				StepManager.resetCreatureForOne(nodeCTTmp,tokenTmp);
			end
		elseif nSubSub == RIGHT_CLICK_TOKEN_NO_LIMIT then
			DB.setValue(nodeWtWCT, 'limit_movement', 'number', 0);
		elseif nSubSub == RIGHT_CLICK_TOKEN_LIMIT then
			DB.setValue(nodeWtWCT, 'limit_movement', 'number', 1);
		elseif nSubSub == RIGHT_CLICK_TOKEN_TELE_ON then
			DB.setValue(nodeWtWCT, 'teleport_allowed', 'number', 1);
			notifyResetRightClick(nodeCT);
		elseif nSubSub == RIGHT_CLICK_TOKEN_TELE_OFF then
			DB.setValue(nodeWtWCT, 'teleport_allowed', 'number', 0);
			notifyResetRightClick(nodeCT);
		end
	end

	if nSelection == RIGHT_CLICK_TOKEN_PRIORITY then
		local cImage = ImageManager.getImageControl(token);
		if cImage then cImage.togglePriority(token) end
	end
end
-- luacheck: pop

function notifyResetRightClick(nodeCT, sOwner)
	if not sOwner then sOwner = getControllingClient(nodeCT) end
	if sOwner then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_RESET_RIGHTCLICK;
		msgOOB.sCTNodeID = DB.getPath(nodeCT);
		Comm.deliverOOBMessage(msgOOB, sOwner);
	end
end
function handleResetRightClick(msgOOB)
	registerTokenRightClick(nil, DB.findNode(msgOOB.sCTNodeID), true);
end

function onTokenRefUpdated(nodeUpdated)
	local nodeCT = DB.getParent(nodeUpdated);
	if Session.IsHost then
		registerTokenRightClick(nil, nodeCT);
	else
		local sOwner = getControllingClient(nodeCT);
		if sOwner and sOwner == Session.UserName then registerTokenRightClick(nil, nodeCT) end
		return;
	end

	if StepManager then StepManager.onTokenRefUpdated(nodeUpdated, nodeCT) end
end

function onCTDelete(nodeCT)
	if SpeedManager then
		SpeedManager.closeSpeedWindow(nodeCT);
		SpeedManager.onTurnEndWtW(nodeCT, true, true);
	end

	local sNodeName = DB.getName(nodeCT);
	if not sNodeName then return end
	DB.deleteChild(nodeWtWList, sNodeName);
end

function onRecordTypeEventWtW(sRecordType, tCustom, ...)
	local bResult = fonRecordTypeEvent(sRecordType, tCustom, ...);

	local nodeCT;
	if tCustom['nodeCT'] then
		nodeCT = tCustom['nodeCT'];
	elseif tCustom['nodeBattleEntry'] then
		nodeCT = ActorManager.getCTNode(tCustom['nodeBattleEntry']);
	elseif tCustom['nodeRecord'] then
		nodeCT = ActorManager.getCTNode(tCustom['nodeRecord']);
	else
		tCustom['nodeRecord'] = DB.findNode(tCustom['sRecord']);
		nodeCT = ActorManager.getCTNode(tCustom['nodeRecord']);
	end
	local sNodeCTName;
	if nodeCT then
		sNodeCTName = DB.getName(nodeCT);
	else
		return bResult;
	end
	if sNodeCTName then
		DB.deleteChild(nodeWtWList, sNodeCTName);
	else
		reportError("WtWCommon.onRecordTypeEventWtW - not sNodeCTName");
		return bResult;
	end

	if SpeedManager then SpeedManager.parseBaseSpeed(nodeCT, true) end

	if StepManager then
		if not tCustom['nodeRecord'] then
			tCustom['nodeRecord'] = DB.findNode(tCustom['sRecord']);
		end
		setWtwDbOwner(tCustom['nodeRecord'], nodeCT);
	end

	if SpeedManager and OptionsManager.isOption('check_item_str', 'on') then
		SpeedManager.checkInvForHeavyItems(nodeCT);
	end

	return bResult;
end

function restartWindows(sWinClass, nodeSource, nodeCT, sOwner)
	if not sWinClass then
		reportError("WtWCommon.restartWindows - not sWinClass");
		return;
	end

	local msgOOB = {};
	if not Session.IsHost then
		restartWindow(sWinClass, nodeSource);

		msgOOB['type'] = OOB_MSGTYPE_RESTART_WINDOW;
		msgOOB['sWinClass'] = sWinClass;
		msgOOB['sNodePath'] = DB.getPath(nodeSource);
		msgOOB['sHostTarget'] = 'true';
		Comm.deliverOOBMessage(msgOOB); --tell host to restart it's window too
		return;
	end

	restartWindow(sWinClass, nodeSource); --Host Window

	if not sOwner then --client Window
		if not nodeCT then nodeCT = DB.findNode(sCTPath..'.'..DB.getName(nodeSource)) end
		sOwner = getControllingClient(nodeCT);
		if not sOwner then
			restartWindow(sWinClass, nodeSource);
			return;
		end
	end

	msgOOB['type'] = OOB_MSGTYPE_RESTART_WINDOW;
	msgOOB['sWinClass'] = sWinClass;
	msgOOB['sNodePath'] = DB.getPath(nodeSource);
	Comm.deliverOOBMessage(msgOOB, sOwner);
end
function handleWindowRestart(msgOOB)
	if not msgOOB then
		reportError("WtWCommon.handleWindowRestart - not msgOOB");
		return;
	end
	if not Session.IsHost and msgOOB['sHostTarget'] == 'true' then return end

	restartWindow(msgOOB['sWinClass'], DB.findNode(msgOOB['sNodePath']));
end
function restartWindow(sWinClass, nodeSource)
	if not sWinClass then
		reportError("WtWCommon.restartWindow - not sWinClass");
		return;
	end

	local win = Interface.findWindow(sWinClass, nodeSource);
	if win then
		win.close();
		Interface.openWindow(sWinClass, nodeSource);
	end
end

function isMovementPossible(nodeCT, nDist, sDist, tokenCT, nCurrMaxSpeed, nodeWtWCT)
	if not SpeedManager or (not nodeCT and not tokenCT) then
		reportError("WtWCommon.isMovementPossible - not SpeedManager or not nodeCT and not tokenCT");
		return;
	end
	if nDist and nDist == 0 then return true end

	if not nodeWtWCT then nodeWtWCT = DB.getChild(nodeWtWList, DB.getName(nodeCT)) end
	if not nCurrMaxSpeed then nCurrMaxSpeed = getLimitingSpeed(nodeCT, nodeWtWCT) end

	if sDist then
		if nDist or sDist ~= 'half' then
			reportError("WtWCommon.isMovementPossible - sDist invalid");
			return;
		end
		nDist = roundNumber(nCurrMaxSpeed / 2, 0, 'down');
	end

	local nTraveled = DB.getValue(nodeWtWCT, 'traveled_raw', 0);

	if nTraveled + nDist > nCurrMaxSpeed then return false, nDist end

	return true, nDist
end

function getLimitingSpeed(nodeCT, nodeWtWCT)
	if not nodeWtWCT then nodeWtWCT = DB.getChild(nodeWtWList, DB.getName(nodeCT)) end
	local sCurrentSpeed = DB.getValue(nodeCT, 'speed_wtw');
	local sLimitingSpeedType = DB.getValue(nodeWtWCT, 'speed_type', '');
	local bEmptyVal, sEmptyLabel;
	if sLimitingSpeedType == '' then --window not opened or value is default
		bEmptyVal = true;
		sEmptyLabel = DB.getValue(nodeWtWCT, 'speed_type_default');
		if sEmptyLabel and sEmptyLabel ~= '' then
			sLimitingSpeedType = sEmptyLabel;
		else
			getSpeedTypes(nodeCT, nodeWtWCT);
			if string.match(sCurrentSpeed, 'Crawl') then
				sLimitingSpeedType = 'crawl';
			else
				if OptionsManager.getOption('speed_type_limiter') == 'highest' then
					sLimitingSpeedType = string.lower(DB.getValue(nodeWtWCT, 'highest_type'));
				else
					sLimitingSpeedType = 'walk';
				end
			end
		end
	end

	--[[if sCurrentSpeed == '' then
		for _,nodeSpeedType in pairs(DB.getChildren(nodeWtWCT, 'FGSpeed')) do
			if string.lower(DB.getValue(nodeSpeedType, 'type', '')) == sLimitingSpeedType then
				local nVel = DB.getValue(nodeSpeedType, 'velocity');
				if bEmptyVal and nVel and nVel == 0 and OptionsManager.getOption('speed_type_limiter') ~= 'highest'
				then
					sLimitingSpeedType = string.lower(DB.getValue(nodeWtWCT, 'highest_type'));
					for _,nodeSpeedTypeNew in pairs(DB.getChildren(nodeWtWCT, 'FGSpeed')) do
						if string.lower(DB.getValue(nodeSpeedTypeNew, 'type', '')) == sLimitingSpeedType then
							return DB.getValue(nodeSpeedTypeNew, 'velocity'), sLimitingSpeedType;
						end
					end
					reportError("WtWCommon.getLimitingSpeed - sLimitingSpeedTypeNew not found");
					return nil, sLimitingSpeedType;
				end
				return nVel, sLimitingSpeedType;
			end
		end
		for _,sSpeedType in ipairs(tSpeedTypes) do
			if sLimitingSpeedType == string.lower(sSpeedType) then
				for _,nodeSpeedType in pairs(DB.getChildren(nodeWtWCT, 'FGSpeed')) do
					if string.lower(DB.getValue(nodeSpeedType, 'type', '')) == 'walk' then
						local nVel = DB.getValue(nodeSpeedType, 'velocity');
						return nVel, sLimitingSpeedType;
					end
				end
			end
		end
		reportError("WtWCommon.getLimitingSpeed - sLimitingSpeedType not found");
		return nil, sLimitingSpeedType;
	end]]

	local sLimitingSpeed;
	if sLimitingSpeedType == 'walk' then
		--sLimitingSpeed = string.gsub(sCurrentSpeed, '%s+%D+.*$', '');
		sLimitingSpeed = string.match(sCurrentSpeed, '%d+');
	else
		local sCurrentSpeedLower = string.lower(sCurrentSpeed);
		local sParenthesis = string.match(sLimitingSpeedType, '%(.*%)');
		if sParenthesis then
			local sLimitSpdSansParenth = string.gsub(sLimitingSpeedType, '%s*%(.*%)%s*', '');
			for _,sSpdTypeSplit in ipairs(StringManager.splitByPattern(sCurrentSpeedLower, '[,;]', true)) do
				if string.match(sSpdTypeSplit, '%(.*%)') == sParenthesis then
					local sSpdTypeSplitSansParenth = string.gsub(sLimitingSpeedType, '%s*%(.*%)%s*', '');
					if sLimitSpdSansParenth == sSpdTypeSplitSansParenth then
						sLimitingSpeed = string.match(sSpdTypeSplit, '%d+');
					end
				end
			end
			if not sLimitingSpeed then sLimitingSpeed = string.match(sCurrentSpeed, '%d+') end
			if not sLimitingSpeed then sLimitingSpeed = '30' end
			sLimitingSpeed = string.match(sLimitingSpeed, '%d+');
		else
			sCurrentSpeedLower = string.gsub(sCurrentSpeedLower, ';?%s*swimming%*?%s*', '');
			sLimitingSpeed = string.gsub(sCurrentSpeedLower, '^.*'..sLimitingSpeedType, '');
			sLimitingSpeed = string.match(sLimitingSpeed, '%d+');
		end
	end
	local nLimitingSpeed = tonumber(sLimitingSpeed);

	if bEmptyVal and nLimitingSpeed and nLimitingSpeed == 0
		and OptionsManager.getOption('speed_type_limiter') ~= 'highest'
	then
		sLimitingSpeedType = string.lower(DB.getValue(nodeWtWCT, 'highest_type'));
		if sLimitingSpeedType == 'walk' then
			sLimitingSpeed = string.gsub(sCurrentSpeed, '%s+%D+.*$', '');
		else
			local sCurrentSpeedLower = string.lower(sCurrentSpeed);
			local sParenthesis = string.match(sLimitingSpeedType, '%(.*%)');
			if sParenthesis then
				local sLimitSpdSansParenth = string.gsub(sLimitingSpeedType, '%s*%(.*%)%s*', '');
				for _,sSpdTypeSplit in ipairs(StringManager.splitByPattern(sCurrentSpeedLower, '[,;]', true)) do
					if string.match(sSpdTypeSplit, '%(.*%)') == sParenthesis then
						local sSpdTypeSplitSansParenth = string.gsub(sLimitingSpeedType, '%s*%(.*%)%s*', '');
						if sLimitSpdSansParenth == sSpdTypeSplitSansParenth then
							sLimitingSpeed = string.match(sSpdTypeSplit, '%d+');
						end
					end
				end
				sLimitingSpeed = string.match(sLimitingSpeed, '%d+');
			else
				sCurrentSpeedLower = string.gsub(sCurrentSpeedLower, ';?%s*swimming%*?%s*', '');
				sLimitingSpeed = string.gsub(sCurrentSpeedLower, '^.*'..sLimitingSpeedType, '');
				sLimitingSpeed = string.match(sLimitingSpeed, '%d+');
			end
		end
		return tonumber(sLimitingSpeed), sLimitingSpeedType;
	end

	return nLimitingSpeed, sLimitingSpeedType;
end
-- luacheck: push ignore 561
function getSpeedTypes(nodeCT, nodeWtWCT)
	if not nodeCT or type(nodeCT) ~= 'databasenode' then return end
	if not nodeWtWCT then nodeWtWCT = DB.getChild(nodeWtWList, DB.getName(nodeCT)) end
	if not nodeWtWCT then
		reportError("WtWCommon.getSpeedTypes - not nodeWtWCT");
		return;
	end

	local sEmptyLabel = 'Walk';
	local sSpeedTypeSelection = OptionsManager.getOption('speed_type_limiter');
	if sSpeedTypeSelection == 'highest' then
		sEmptyLabel = DB.getValue(nodeWtWCT, 'highest_type');
	end

	local sLabels, sValues, bCanWalk, bCrawl;
	local sCurrentSpeed = DB.getValue(nodeCT, 'speed_wtw');
	if sCurrentSpeed then
		for _,sSpeedSplit in pairs(StringManager.splitByPattern(sCurrentSpeed, '[,;]', true)) do
			local sWalkVel = string.match(sSpeedSplit, '^%d+');
			local sSpeedType;
			if sWalkVel then
				sSpeedType = 'Walk';
				bCanWalk = true;
				local nWalkVel = tonumber(sWalkVel);
				if nWalkVel and nWalkVel == 0 and sEmptyLabel == 'Walk' then
					sSpeedTypeSelection = 'highest';
					sEmptyLabel = DB.getValue(nodeWtWCT, 'highest_type');
				end
			else
				local sSpeedSplitLower = string.lower(sSpeedSplit);
				if not string.match(sSpeedSplitLower, '^swimming%**$') and not string.match(sSpeedSplitLower
					, '^difficult%**$') and not string.match(sSpeedSplitLower, '^extra%s*:')
				then
					sSpeedType = string.match(sSpeedSplit, '^%D+');
					if sSpeedType then
						sSpeedType = string.gsub(sSpeedType, '%s+$', '');
						sSpeedType = string.gsub(sSpeedType, '%*$', '');
					else
						sSpeedType = 'Walk'
					end
					local sParenthetic = string.match(sSpeedSplit, '%(.*%)');
					if sParenthetic then sSpeedType = sSpeedType..' '..sParenthetic end
					if sSpeedType == 'Walk' then
						bCanWalk = true;
						sWalkVel = string.match(sSpeedSplit, '%d+');
						local nWalkVel;
						if sWalkVel then
							nWalkVel = tonumber(sWalkVel);
							if nWalkVel and nWalkVel == 0 and sEmptyLabel == 'Walk' then
								sSpeedTypeSelection = 'highest';
								sEmptyLabel = DB.getValue(nodeWtWCT, 'highest_type');
							end
						end
					end
					if sSpeedType == 'Crawl' then
						bCrawl = true;
					else
						bCrawl = false;
					end
				end
			end
			if sSpeedType and sSpeedType ~= sEmptyLabel then
				if not sLabels then
					sLabels = sSpeedType;
				else
					sLabels = sLabels..'|'..sSpeedType;
				end
			end
		end
	else
		for _,nodeSpeedType in pairs(DB.getChildren(nodeWtWCT, 'FGSpeed')) do
			local sSpeedType = DB.getValue(nodeSpeedType, 'type');
			if sSpeedType then
				if sSpeedType == 'Walk' then
					bCanWalk = true;
					local nWalkVel = DB.getValue(nodeSpeedType, 'velocity');
					if nWalkVel and nWalkVel == 0 and sEmptyLabel == 'Walk' then
						sSpeedTypeSelection = 'highest';
						sEmptyLabel = DB.getValue(nodeWtWCT, 'highest_type');
					end
				end
				if sSpeedType ~= sEmptyLabel then
					if not sLabels then
						sLabels = sSpeedType;
					else
						sLabels = sLabels..'|'..sSpeedType;
					end
				end
			end
		end
	end

	for _,sSpeedtype in ipairs(tSpeedTypes) do
		if sSpeedtype ~= sEmptyLabel then
			if sLabels then
				if not string.match(sLabels, sSpeedtype) then
					sLabels = sLabels..'|'..sSpeedtype;
				end
			else
				sLabels = sSpeedtype;
			end
		end
	end

	if bCrawl then
		sLabels = '';
		sEmptyLabel = 'Crawl';
	elseif not bCanWalk and sSpeedTypeSelection == 'walk' then
		sEmptyLabel = DB.getValue(nodeWtWCT, 'highest_type', '');
		sLabels = string.gsub(sLabels, sEmptyLabel, '');
		sLabels = string.gsub(sLabels, '||', '|');
		sLabels = string.gsub(sLabels, '|$', '');
	end

	sValues = string.lower(sLabels);
	notifyEmpty(nodeCT, string.lower(sEmptyLabel), sValues);

	return sLabels, sValues, sEmptyLabel;
end
-- luacheck: pop
function notifyEmpty(nodeCT, sEmptyLabel, sValues)
	if Session.IsHost then
		local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
		DB.setValue(nodeWtWCT, 'speed_type_default', 'string', sEmptyLabel);
		DB.setValue(nodeWtWCT, 'speed_type_values', 'string', sValues);
	else
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_NOTIFY_EMPTY;
		msgOOB.sCTNodeID = DB.getPath(nodeCT);
		msgOOB.sEmptyLabel = sEmptyLabel;
		msgOOB.sValues = sValues;
		Comm.deliverOOBMessage(msgOOB, '');
	end
end
function handleNotifyEmpty(msgOOB)
	if not Session.IsHost then return end

	local sNodeCTName = DB.getName(DB.findNode(msgOOB.sCTNodeID));
	if not sNodeCTName then return end

	local nodeWtWCT = DB.createChild(nodeWtWList, sNodeCTName);
	DB.setValue(nodeWtWCT, 'speed_type_default', 'string', msgOOB.sEmptyLabel);
	DB.setValue(nodeWtWCT, 'speed_type_values', 'string', msgOOB.sValues);
end

function populateSpeedtypes()
	table.insert(t5ESpeedTypes, 'Swim');
	table.insert(t5ESpeedTypes, 'Climb');
	tRulesetSpeedTypes['5E'] = t5ESpeedTypes;

	for sRuleset,tRulesetSpeeds in pairs(tRulesetSpeedTypes) do --luacheck: ignore 313
		sRuleset = Session.RulesetName; --remove once multiple rulesets are supported
		if Session.RulesetName == sRuleset then
			for _,sSpeedType in ipairs(tRulesetSpeeds) do
				table.insert(tSpeedTypes, sSpeedType);
			end
		end
	end
end

function tidyUnits(sUnitsGave)
	if not sUnitsGave then sUnitsGave = "" end
	local sUnitsGave = string.lower(sUnitsGave);
	if sUnitsGave == "'" or sUnitsGave == "ft" or sUnitsGave == "ft." or sUnitsGave == "feet" then
		return "ft.";
	elseif sUnitsGave == "m." or sUnitsGave == "m" or sUnitsGave == "meter" or sUnitsGave == "meters" then
		return "m";
	elseif sUnitsGave == "tiles" or sUnitsGave == "in." or sUnitsGave == "in" or sUnitsGave == "inches" then
		return "tiles";
	elseif sUnitsGave == "miles per hour" or sUnitsGave == "mph" then
		return "mph";
	elseif sUnitsGave == "" then
		if isSavageWorlds() then
			return "tiles";
		else
			return "ft.";
		end
	else
		ChatManager.Message("WtWCommon.tidyUnits - Unsupported units, please request this unit in the forum. Treating as feet.");
		return "ft.";
	end
end

function clearTable(tToBeCleared)
	for key in pairs(tToBeCleared) do
		tToBeCleared[key] = nil;
	end
end

--https://gist.github.com/revolucas/dd1ecccfca32d558fddf70ddb39eb8a6
--slight modifications
function printTable(t)
	local print = reportError;
	local sTab = "   " --original is "\t"

	if type(t) ~= 'table' then
		print("not table = "..tostring(t)..".");
		return false;
	end

	-- to make output beautiful
	local function tab(amt)
		local str = ""
		for i=1,amt do --luacheck: ignore 213
			str = str .. sTab
		end
		return str
	end

	local cache, stack, output = {},{},{}
	local depth = 1
	local output_str = "{\n"

	while true do
		local size = 0
		for _ in pairs(t) do
			size = size + 1
		end

		local cur_index = 1
		for k,v in pairs(t) do
			if (cache[t] == nil) or (cur_index >= cache[t]) then

				if (string.find(output_str,"}",output_str:len())) then
					output_str = output_str .. ",\n"
				elseif not (string.find(output_str,"\n",output_str:len())) then
					output_str = output_str .. "\n"
				end

				-- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
				table.insert(output,output_str)
				output_str = ""

				local key
				if (type(k) == "number" or type(k) == "boolean") then
					key = "["..tostring(k).."]"
				else
					key = "['"..tostring(k).."']"
				end

				if (type(v) == "number" or type(v) == "boolean") then
					output_str = output_str .. tab(depth) .. key .. " = "..tostring(v)
				elseif (type(v) == "table") then
					output_str = output_str .. tab(depth) .. key .. " = {\n"
					table.insert(stack,t)
					table.insert(stack,v)
					cache[t] = cur_index+1
					break
				elseif type(v) == 'databasenode' then
					output_str = output_str .. tab(depth) .. key .. " = node: "..DB.getPath(v)
				else
					output_str = output_str .. tab(depth) .. key .. " = '"..tostring(v).."'"
				end

				if (cur_index == size) then
					output_str = output_str .. "\n" .. tab(depth-1) .. "}"
				else
					output_str = output_str .. ","
				end
			else
				-- close the table
				if (cur_index == size) then
					output_str = output_str .. "\n" .. tab(depth-1) .. "}"
				end
			end

			cur_index = cur_index + 1
		end

		if (#stack > 0) then
			t = stack[#stack]
			stack[#stack] = nil
			depth = cache[t] == nil and depth + 1 or depth - 1
		else
			break
		end
	end

	-- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
	table.insert(output,output_str)
	output_str = table.concat(output)

	print(output_str);
	return true;
end

function reportError(sMsg, bChatWindow, bBroadcast, nodeCT)
	if not sMsg or sMsg == '' then return end

	if not bChatWindow then
		Debug.console(sMsg);
		return;
	end

	if bBroadcast == nil and nodeCT and WtWCommon.getControllingClient(nodeCT) then bBroadcast = true end

	ChatManager.sendMessage(sMsg, { text = sMsg, secret = not bBroadcast, rActor = nodeCT, icon = 'WtW_icon' });
end