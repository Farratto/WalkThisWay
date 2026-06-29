-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

--luacheck: globals speedCalculator reportRootData setAllCharSheetSpeeds setCharSheetSpeed onLoginWtW
--luacheck: globals accommKnownExtsSpeed openSpeedWindow
--luacheck: globals callSpeedCalcEffectUpdated callSpeedCalcEffectDeleted onGlobalEffectUpdated onGlobalEffectDeleted
--luacheck: globals callSpeedCalcEffectDeleted setOptions updateDisplaySpeed handleSpeedWindowClient
--luacheck: globals parseSpeedType onTabletopInit recalcAllSpeeds handleSlash
--luacheck: globals handleCloseSpeedWindow closeSpeedWindow turnStartChecks onTurnEndWtW
--luacheck: globals parseBaseSpeed reparseBaseSpeed reparseAllBaseSpeeds reparseBaseSpeedSpecial
--luacheck: globals faddEffectByTable addEffectByTableWtW
--luacheck: globals fsetExhaustionLevel setExhaustionLevelWtW handleExhaustion
--luacheck: globals setConstants addDbHandlers
--luacheck: globals checkFitness recheckFitness checkInvForHeavyItems checkAllForHeavyItems undoItemTooHeavy
--luacheck: globals handleEncumbUpdated populateEncumbranceTable toggleEncumbTracking removeEffectTooHeavy
--luacheck: globals toggleCheckItemStr clearAllItemStrengthHandlers
--luacheck: globals getRoundingPref getRSDefaultGridSize convertAndRound getEffectUnits getDefaultEffectUnits

OOB_MSGTYPE_SPEEDWINDOW = 'speedwindow';
OOB_MSGTYPE_CLOSESPEEDWINDOW = 'close_speedwindow';

--local bLoopProt, nodeWtW, nodeWtWList, nodeLastHandled, nActiveLast, sLabelLast, sCTCombatantPath;
local nodeWtW, nodeWtWList, sCTCombatantPath, sEncLevelPath, sEncOption;
local tLevelEncumbTypes = {};
--tEncLevelSpeeds = {};

function onInit()
	setConstants();
	addDbHandlers();
	if Session.IsHost then
		getEffectUnits();
		Comm.registerSlashHandler('distunits', handleSlash, '[ft|m|tiles]')
		EffectManager.setTagOptions('SPEED', {bIgnoreTarget = true, bNoDUSE = true, bIgnoreExpire = true});
			--known options: bIgnoreOtherFilter bIgnoreDisabledCheck bDamageFilter bConditionFilter bNoDUSE
			--continued: bSpell bOneShot bIgnoreExpire bIgnoreTarget
		populateEncumbranceTable();
		User.onLogin = onLoginWtW;
		faddEffectByTable = EffectManager.addEffectByTable;
		EffectManager.addEffectByTable = addEffectByTableWtW;
		if ActorManager5E then
			fsetExhaustionLevel = ActorManager5E.setExhaustionLevel;
			ActorManager5E.setExhaustionLevel = setExhaustionLevelWtW;
		end
		CombatManager.setCustomTurnStart(turnStartChecks);
		CombatManager.setCustomTurnEnd(onTurnEndWtW);
	end

	setOptions();

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_SPEEDWINDOW, handleSpeedWindowClient);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSESPEEDWINDOW, handleCloseSpeedWindow);
end

function onTabletopInit()
	if Session.IsHost then
		reparseAllBaseSpeeds();
		setAllCharSheetSpeeds();
		recalcAllSpeeds();
		if OptionsManager.isOption('check_item_str', 'on') then checkAllForHeavyItems() end
	end
end

function setConstants()
	if Session.IsHost then
		nodeWtW = DB.createNode('WalkThisWay');
		if not nodeWtW then
			WtWCommon.reportError("SpeedManager.setConstants - Unrecoverable error - unable to create nodeWtW");
			return;
		end
		DB.setPublic(nodeWtW, true);
		nodeWtWList = DB.createChild(nodeWtW, 'ct_list');
		if not nodeWtWList then
			WtWCommon.reportError("SpeedManager.setConstants - Unrecoverable error - unable to create nodeWtWList");
			return;
		end
	else
		nodeWtW = DB.findNode('WalkThisWay');
		if not nodeWtW then
			WtWCommon.reportError("SpeedManager.setConstants - Unrecoverable error - unable to find nodeWtW");
			return;
		end
		nodeWtWList = DB.getChild(nodeWtW, 'ct_list');
		if not nodeWtWList then
			WtWCommon.reportError("SpeedManager.setConstants - Unrecoverable error - unable to create nodeWtWList");
			return;
		end
	end
end

function addDbHandlers()
	sCTCombatantPath = CombatManager.getTrackerCombatantPath();
	sEncLevelPath = GameManager.getRecordFieldMap('', 'enclevel');
		--charsheet.*.encumbrance.level

	if Session.IsHost then
		DB.addHandler(sCTCombatantPath..'.speed', 'onUpdate', reparseBaseSpeed);
		CombatManager.addAllCombatantEffectFieldChangeHandler(
			'isactive', 'onUpdate', callSpeedCalcEffectUpdated);
		CombatManager.addAllCombatantEffectFieldChangeHandler(
			'label', 'onUpdate', callSpeedCalcEffectUpdated);
		local sGlobalEffectPath = CombatManager.getTrackerEffectParentPath();
		DB.addHandler(sGlobalEffectPath..'.*.isactive', 'onUpdate', onGlobalEffectUpdated);
		DB.addHandler(sGlobalEffectPath..'.*.label', 'onUpdate', onGlobalEffectUpdated);
		DB.addHandler(sGlobalEffectPath, 'onChildDeleted', onGlobalEffectDeleted);
		--DB.addHandler(sCTCombatantPath..'.effects.*.isactive', 'onUpdate', callSpeedCalcEffectUpdated);
		--DB.addHandler(sCTCombatantPath..'.effects.*.label', 'onUpdate', callSpeedCalcEffectUpdated);
		DB.addHandler(sCTCombatantPath..'.effects', 'onChildDeleted', callSpeedCalcEffectDeleted);
		DB.addHandler('charsheet.*.speed.total','onUpdate', setCharSheetSpeed);
		DB.addHandler('charsheet.*.speed.special','onUpdate', reparseBaseSpeedSpecial);
		if Session.RulesetName ~= "5E" then
			DB.addHandler('charsheet.*.speed.final','onUpdate', setCharSheetSpeed);
		else
			DB.addHandler('charsheet.*.'..sEncLevelPath,'onUpdate', handleEncumbUpdated);
		end
	else
		DB.addEventHandler('onDataLoaded', setConstants);
	end
end

function onClose()
	if Session.IsHost and Session.RulesetName == "5E" then
		for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
			local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
			DB.deleteNode(DB.getChild(nodeWtWCT, 'handler_list'));
			DB.deleteNode(DB.getChild(nodeWtWCT, 'difficult_button'));
		end
	end
end

function setOptions()
-- DEFAULT BEHAVIORS FOR OPTIONS: sType = "option_entry_cycler", on|off, default = off
--Farratto: Undocumented default option behaviors: bLocal = false, sGroupRes = "option_header_client"
	--Old 4th = ("option_label_" .. sKey)
	OptionsManager.registerOptionData({	sKey = 'WESC', sGroupRes = 'option_header_WtW'
		, tCustom = { default = "on" }
	});
	if Session.IsHost then
		OptionsManager.registerOptionData({	sKey = 'ADEC', sGroupRes = 'option_header_WtW' });
		OptionsManager.registerCallback('WESC', recalcAllSpeeds);
		if Session.RulesetName == "5E" then
			OptionsManager.registerOptionData(
				{ sKey = 'check_item_str',
				sGroupRes = 'option_header_WtW',
				tCustom = { default = "on" }
				}
			);
			OptionsManager.registerCallback('check_item_str', toggleCheckItemStr);
			--[[
			OptionsManager.registerOptionData(
				{ sKey = 'encumbrance_tracking',
				sGroupRes = 'option_header_WtW',
				tCustom = { default = "on" }
				}
			);
			]]
			--OptionsManager.registerCallback('encumbrance_tracking', toggleEncumbTracking);
			OptionsManager.registerCallback('HREN', toggleEncumbTracking);
			sEncOption = OptionsManager.getOption('HREN');
			OptionsManager.registerOptionData({	sKey = 'speed_rounding', sGroupRes = 'option_header_WtW'
				, tCustom =
					{ labelsres = "option_val_grid|option_val_whole|option_val_tenth"
					, values = "grid|whole|tenth"
					, baselabelres = "option_val_hgrid"
					, baseval = "hgrid"
					, default = "hgrid"
					}
				}
			);
			OptionsManager.registerCallback('speed_rounding', recalcAllSpeeds);
		end
	end
	OptionsManager.registerOptionData({	sKey = 'AOSW', sGroupRes = 'option_header_WtW', bLocal = true });
	OptionsManager.registerOptionData({	sKey = 'ACSW', sGroupRes = 'option_header_WtW', bLocal = true });
end

function onLoginWtW(_, activated)
	if not activated then recalcAllSpeeds() end
end

function callSpeedCalcEffectUpdated(nodeEffectChild)
	--if bLoopProt or OptionsManager.isOption('WESC', 'off') then return end
	if OptionsManager.isOption('WESC', 'off') then return end

	local nodeEffect = DB.getParent(nodeEffectChild);
	--local nIsActive = DB.getValue(nodeEffect, 'isactive');
	local sNodeEffectLabel = DB.getValue(nodeEffect, 'label');
	--[[
	if nodeEffect == nodeLastHandled
		and nIsActive == nActiveLast
		and sNodeEffectLabel == sLabelLast
	then
		return;
	end
	]]

	local nodeCT = DB.getChild(nodeEffect, '...');

	--bLoopProt = true;
	if sNodeEffectLabel then
		if OptionsManager.isOption('check_item_str', 'on')
			and string.match(string.lower(sNodeEffectLabel), 'str:%s*%d')
		then
			recheckFitness(DB.getChild(nodeCT, 'abilities.strength.score'), nodeCT);
		end
	end
	if (DB.getName(nodeEffectChild) or '') == 'isactive'
		and string.match(string.lower(sNodeEffectLabel or ''), 'exhaustion')
	then
		handleExhaustion(ActorManager.resolveActor(nodeCT));
	end

	speedCalculator(nodeCT);
	--bLoopProt = false;

	--[[
	nodeLastHandled = nodeEffect;
	nActiveLast = nIsActive;
	sLabelLast = sNodeEffectLabel;
	]]
end
function callSpeedCalcEffectDeleted(nodeEffects, sNodeName) --luacheck: ignore 212
	--if bLoopProt or OptionsManager.isOption('WESC', 'off') then return end
	if OptionsManager.isOption('WESC', 'off') then return end
	local nodeCT = DB.getParent(nodeEffects)

	--bLoopProt = true;
	if OptionsManager.isOption('check_item_str', 'on') then
		recheckFitness(DB.getChild(nodeCT, 'abilities.strength.score'), nodeCT);
	end
	handleExhaustion(ActorManager.resolveActor(nodeCT));
	speedCalculator(nodeCT);
	--bLoopProt = false;
end
function onGlobalEffectUpdated(nodeEffectChild)
	--if bLoopProt or OptionsManager.isOption('WESC', 'off') then return end
	if OptionsManager.isOption('WESC', 'off') then return end

	local nodeEffect = DB.getParent(nodeEffectChild);
	local sNodeEffectLabel = DB.getValue(nodeEffect, 'label');

	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		if sNodeEffectLabel
			and OptionsManager.isOption('check_item_str', 'on')
			and string.match(string.lower(sNodeEffectLabel), 'str:%s*%d')
		then
			recheckFitness(DB.getChild(nodeCT, 'abilities.strength.score'), nodeCT);
		end
		if (DB.getName(nodeEffectChild) or '') == 'isactive'
			and string.match(string.lower(sNodeEffectLabel or ''), 'exhaustion')
		then
			handleExhaustion(ActorManager.resolveActor(nodeCT));
		end
		speedCalculator(nodeCT);
	end
end
function onGlobalEffectDeleted(nodeEffects, sNodeName) --luacheck: ignore 212
	--if bLoopProt or OptionsManager.isOption('WESC', 'off') then return end
	if OptionsManager.isOption('WESC', 'off') then return end

	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		if OptionsManager.isOption('check_item_str', 'on') then
			recheckFitness(DB.getChild(nodeCT, 'abilities.strength.score'), nodeCT);
		end
		handleExhaustion(ActorManager.resolveActor(nodeCT));
		speedCalculator(nodeCT);
	end
end

function recalcAllSpeeds(sOwner)
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		if sOwner and sOwner ~= 'WESC' then
			if sOwner == WtWCommon.getControllingClient(nodeCT) then
				if StepManager then StepManager.setConvFactor(nodeCT) end
				speedCalculator(nodeCT);
			end
		else
			if StepManager then StepManager.setConvFactor(nodeCT) end
			speedCalculator(nodeCT);
		end
	end
end

-- luacheck: push ignore 561
function speedCalculator(nodeCT, bCalledFromParse, bDifficultButton)
	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
	local nodeFGSpeed = DB.getChild(nodeWtWCT, 'FGSpeed');
	if not nodeFGSpeed then
		if bCalledFromParse then
			WtWCommon.reportError("SpeedManager.speedCalculator - bCalledFromParse");
			return;
		else
			parseBaseSpeed(nodeCT, false);
		end
		nodeFGSpeed = DB.getChild(nodeWtWCT, 'FGSpeed');
		if not nodeFGSpeed then
			WtWCommon.reportError("SpeedManager.speedCalculator - not nodeFGSpeed");
			return;
		end
	end

	local nBaseSpeed;
	local tFGSpeedNew = {};
	local bNoBase = true;
	for _,v in pairs(DB.getChildren(nodeWtWCT, 'FGSpeed')) do
		local tSpdRcrd = {};
		tSpdRcrd['velocity'] = DB.getValue(v, 'velocity');
		tSpdRcrd['type'] = DB.getValue(v, 'type');
		table.insert(tFGSpeedNew, tSpdRcrd);
		if tSpdRcrd['type'] == '' or string.lower(tSpdRcrd['type']) == 'walk' then
			nBaseSpeed = tSpdRcrd['velocity'];
			bNoBase = false;
		end
		if not nBaseSpeed then nBaseSpeed = tSpdRcrd['velocity'] end
	end
	nBaseSpeed = tonumber(nBaseSpeed);
	if not nBaseSpeed then
		WtWCommon.reportError("SpeedManager.speedCalculator - not nBaseSpeed for "..DB.getValue(nodeCT, 'name', ''));
		nBaseSpeed = 30;
	end

	local sPref = WtWCommon.getPreference(nodeCT);

	local rActor = ActorManager.resolveActor(nodeCT);
	if not rActor then
		WtWCommon.reportError("SpeedManager.speedCalculator - not rActor for "..DB.getValue(nodeCT, 'name', ''));
		return;
	end
	local tSpeedEffects = {};
	local nHalved = 0;
	local tAccomSpeed = {};
	local bProne = false;
	local nHover = DB.getValue(nodeWtWCT, 'hover')
	local tEffectNames = {};
	if not OptionsManager.isOption('WESC', 'off') then
		local tRootData = WtWCommon.getRootData(nodeCT);
		if tRootData and tRootData[1] then
			for _,sRootEffectName in ipairs(tRootData) do
				table.insert(tEffectNames, sRootEffectName);
			end
			local tRoot = reportRootData(nodeCT, nHover);
			return updateDisplaySpeed(nodeCT,tRoot,nBaseSpeed,false,sPref,tEffectNames,0,bNoBase,'Walk');
		end
		--tSpeedEffects = WtWCommon.getEffectsByTypeWtW(rActor, 'SPEED:');
		tSpeedEffects = EffectManager.getCompsDataByTag(rActor, 'SPEED');
		tAccomSpeed = accommKnownExtsSpeed(nodeCT);
		--bProne = WtWCommon.hasEffectClause(rActor, "^Prone$", nil, false, true)
		--if bProne then table.insert(tEffectNames, "Prone") end
		WtWCommon.getEffectNamesByText(rActor, "Prone", tEffectNames);
	end

	local nSpeedMod = 0;
	local nDash = 0;
	local nSpeedMax, nSpeedMaxMax;
	local nHalvedStone = nHalved;
	if tAccomSpeed then
		if tAccomSpeed['nSpeedRoot'] then
			local tRoot = reportRootData(nodeCT, nHover);
			table.insert(tEffectNames, tAccomSpeed['nSpeedRoot']);
			return updateDisplaySpeed(nodeCT,tRoot,nBaseSpeed,false,sPref,tEffectNames,0,bNoBase,'Walk');
		end
		if tAccomSpeed['nDash'] then
			nDash = tAccomSpeed['nDash'];
		end
		if tAccomSpeed['nSpeedMax'] then
			nSpeedMax = tonumber(tAccomSpeed['nSpeedMax']);
			nSpeedMaxMax = nSpeedMax;
		end
		if tAccomSpeed['nSpeedMod'] then
			nSpeedMod = nSpeedMod + tonumber(tAccomSpeed['nSpeedMod']);
		end
		if tAccomSpeed['nHalved'] then
			nHalved = nHalved + tAccomSpeed['nHalved'];
			nHalvedStone = nHalved;
		end
		if tAccomSpeed['tEffectNames'] then
			for _,sEffectName in ipairs(tAccomSpeed['tEffectNames']) do
				table.insert(tEffectNames, sEffectName);
			end
		end
	end

	local nDoubled = 0;
	local nTripled = 0;
	local nDecs = 0;
	local nExtra = 0;
	local tRebase = {};
	local tBannedTypes = {};
	local tModdedTypes = {};
	local tDecMods = {};
	local tFreeNames = {};
	local bDifficultEffect, nRecheck, sRecheckLabel, bFree, bSwimming;
	for _,v in ipairs(tSpeedEffects) do
		--[[
		local sRemainder;
		local sSpdMatch = string.match(v.original, '^[Ss][Pp][Ee][Ee][Dd]%s*:%s*');
		local sMinusSpeed = string.gsub(v.original, sSpdMatch, '');
		local sMod = string.match(sMinusSpeed, '^%S+');
		local nMod = nil;
		if DiceManager.isDiceString(sMod) then
			nMod = tonumber(sMod);
			if not nMod then
				WtWCommon.reportError("SpeedManager.speedCalculator - dice not currently supported. Please request this feature in the forums.");
			end
			sRemainder = sMinusSpeed:gsub('^' .. tostring(sMod) .. '%s*', '');
		else
			sRemainder = sMinusSpeed;
		end
		if not sRemainder and not nMod then
			WtWCommon.reportError("SpeedManager.speedCalculator - Syntax Error 438");
		end
		]]
		if v['original'] == "SPEED:" then
			WtWCommon.reportError("Walk this Way - Syntax Error. Please consult forums.", true)
		end
		if v['dice'][1] then
			WtWCommon.reportError("Walk this Way does not currently support dice expressions.  Please request this feature in the forums.", true);
		end

		local sMod;
		local nMod = v['mod'];
		if nMod == 0 and string.match(string.upper(v['original']), '^SPEED:%s*[^0]') then nMod = nil end
		if nMod then sMod = tostring(nMod) end
		local sRemainder = v['sRemainder'];
		local sEffectName = WtWCommon.getEffectName(v['node']);

		local sRmndrLower = string.lower(sRemainder);
		local bRecognizedRmndr = false;
		--start matching
		--StringManager.startsWith does use patterns
		if StringManager.startsWith(sRmndrLower, 'free') then
			bFree = true;
			bRecognizedRmndr = true;
			table.insert(tEffectNames, sEffectName);
		end
		if StringManager.startsWith(sRmndrLower, 'max') then
			bRecognizedRmndr = true;
			local nMaxMod;
			if string.match(sRmndrLower, '%)$') then
				local sRmndrRemainder = sRmndrLower:gsub('^max%s*%(', '');
				sRmndrRemainder = sRmndrRemainder:gsub('%s*%)$', '');
				local nRmndrRemainder = tonumber(sRmndrRemainder);
				if nRmndrRemainder then
					nMaxMod = nRmndrRemainder
				else
					WtWCommon.reportError("Walk This Way - Syntax Error. Try SPEED: max(5)", true);
				end
				if nMod then
					sRemainder = ''
					sRmndrLower = ''
				end
			else
				nMaxMod = nMod
				nMod = nil
			end
			if nSpeedMax then
				if nMaxMod < nSpeedMax then
					nSpeedMax = nMaxMod;
					table.insert(tEffectNames, sEffectName);
					table.insert(tFreeNames, sEffectName);
				end
			else
				nSpeedMax = nMaxMod;
				table.insert(tEffectNames, sEffectName);
				table.insert(tFreeNames, sEffectName);
			end
		end
		if sRmndrLower == "difficult" then
			bRecognizedRmndr = true;
			bDifficultEffect = true;
			table.insert(tEffectNames, sEffectName);
			table.insert(tFreeNames, sEffectName);
		end
		if (sRmndrLower == "half" or sRmndrLower == "halved") then
			bRecognizedRmndr = true;
			nHalved = nHalved + 1;
			table.insert(tEffectNames, sEffectName);
			if not string.match(sEffectName, '^Exhausted$') then
				table.insert(tFreeNames, sEffectName);
			else
				nHalvedStone = nHalvedStone + 1;
			end
		end
		if (sRmndrLower == "double" or sRmndrLower == "doubled") then
			bRecognizedRmndr = true;
			nDoubled = nDoubled + 1;
			table.insert(tEffectNames, sEffectName);
		end
		if (sRmndrLower == "triple" or sRmndrLower == "tripled") then
			bRecognizedRmndr = true;
			nTripled = nTripled + 1;
			table.insert(tEffectNames, sEffectName);
		end
		if sRmndrLower == 'extra' then
			bRecognizedRmndr = true;
			if not nMod then
				WtWCommon.reportError("Walk This Way - Syntax error. Try SPEED: 4 extra", true);
			else
				nExtra = nExtra + nMod;
				table.insert(tEffectNames, sEffectName);
				table.insert(tFreeNames, sEffectName);
			end
		end
		if sRmndrLower == 'swimming' then
			bRecognizedRmndr = true;
			bSwimming = true;
			table.insert(tEffectNames, sEffectName);
		end
		if not bProne and StringManager.startsWith(sRmndrLower, 'type') then
			bRecognizedRmndr = true;
			local sStrip = string.match(sRemainder, '^%s*[Tt][Yy][Pp][Ee]%s*%(%s*');
			if not string.match(sRmndrLower, '%)$') then
				WtWCommon.reportError("Walk This Way - Syntax error. Try SPEED: type(fly)", true);
			elseif sStrip then
				sStrip = string.gsub(sStrip, '%(', '%%(');
				local sRmndrRemainder = sRemainder:gsub(sStrip, '');
				local sType = sRmndrRemainder:gsub('%s*%)$', '');
				local bRemoveType;
				if string.match(sType, '^%-') then
					bRemoveType = true;
					sType = string.sub(sType, 2);
				end
				sType = StringManager.capitalizeAll(sType);
				local sTypeLower = string.lower(sType);
				local nFound, bExactMatch, sQualifier, sTypeFly, sTypeHover, sTypeSpider, bMatchSpider =
					parseSpeedType(sType, tFGSpeedNew, true);

				if nMod then
					if nMod <= 0 or string.sub(sMod, 1, 1) == '+' then
						if nFound then
							if sTypeFly or (sTypeSpider and bMatchSpider) then
								tFGSpeedNew[nFound]['mod'] = nMod;
								table.insert(tEffectNames, sEffectName);
								if nMod < 0 then
									local rModdedType = {};
									rModdedType['type'] = tFGSpeedNew[nFound]['type'];
									rModdedType['mod'] = nMod;
									rModdedType['name'] = sEffectName;
									table.insert(tDecMods, rModdedType);
								end
							else
								if not sTypeHover and not sTypeSpider then
									tFGSpeedNew[nFound]['mod'] = nMod;
									table.insert(tEffectNames, sEffectName);
									if nMod < 0 then
										local rModdedType = {};
										rModdedType['type'] = tFGSpeedNew[nFound]['type'];
										rModdedType['mod'] = nMod;
										rModdedType['name'] = sEffectName;
										table.insert(tDecMods, rModdedType);
									end
								end
							end
						else
							local rModdedType = {};
							rModdedType['type'] = sType;
							rModdedType['mod'] = nMod;
							rModdedType['name'] = sEffectName;
							table.insert(tModdedTypes, rModdedType);
							if nMod < 0 then table.insert(tDecMods, rModdedType) end
						end
					else
						local bBanned;
						if tBannedTypes[1] then
							for _,value in ipairs(tBannedTypes) do
								if string.match(sTypeLower, string.lower(value.type)) then
									local _,_,_,sLocFly,sLocHover = parseSpeedType(value.type, tFGSpeedNew, false);
									if sLocHover and not sLocFly and sTypeHover then
										if sTypeFly then
											sType = string.gsub(sType, '%s*%(%s*[Hh][Oo][Vv][Ee][Rr]%s*%)%s*', '');
											table.insert(tEffectNames, sEffectName);
										end
									end
									bBanned = true;
									table.insert(tEffectNames, WtWCommon.getEffectName(_,value.name));
								end
							end
						end
						if tModdedTypes[1] then
							for _,value in ipairs(tModdedTypes) do
								if string.match(sTypeLower, string.lower(value.type)) then
									local _,_,_, sLocFly, _, sLocSpider = parseSpeedType(value.type, tFGSpeedNew,
									false);
									if sLocFly or (sLocSpider and bMatchSpider) then
										nMod = nMod + value.mod;
										table.insert(tEffectNames, sEffectName);
										table.insert(tEffectNames, WtWCommon.getEffectName(_,value.name));
									else
										if not sTypeHover and not sTypeSpider then
											nMod = nMod + value.mod;
											table.insert(tEffectNames, sEffectName);
											table.insert(tEffectNames, WtWCommon.getEffectName(_,value.name));
										end
									end
								end
							end
						end
						if nFound and not bBanned then
							local bFaster;
							local nCurrentVel = tonumber(tFGSpeedNew[nFound]['velocity']);
							if nCurrentVel then
								if nMod >= nCurrentVel then bFaster = true end
							else
								bFaster = true;
							end
							if not bExactMatch then
								if sQualifier then
									if bFaster then table.remove(tFGSpeedNew, nFound) end
									nFound = false;
								else
									if sTypeFly then
										if (nHover == 1) or sTypeHover then
											tFGSpeedNew[nFound]['type'] = 'Fly (hover)'
										end
									elseif sTypeSpider and not bMatchSpider then
										tFGSpeedNew[nFound]['type'] = 'Spider Climb'
									else
										nFound = false;
									end
								end
							end
							if nFound and bFaster then
								tFGSpeedNew[nFound]['velocity'] = nMod
								table.insert(tEffectNames, sEffectName);
							end
						end
						if not nFound and not bBanned then
							local tSpdRcrd = {};
							tSpdRcrd['type'] = sType;
							tSpdRcrd['velocity'] = nMod;
							table.insert(tFGSpeedNew, tSpdRcrd);
							table.insert(tEffectNames, sEffectName);
						end
					end
					nMod = nil;
				else
					if bRemoveType then
						if nFound then
							if sTypeHover and not sTypeFly then
								local sNewType = string.gsub(tFGSpeedNew[nFound]['type'], '%s*[Ff][Ll][Yy]%s*', '');
								tFGSpeedNew[nFound]['type'] = sNewType;
								table.insert(tEffectNames, sEffectName);
							elseif sTypeSpider and not bMatchSpider then --luacheck: ignore 542
								--do nothing;
							else
								table.remove(tFGSpeedNew, nFound);
								table.insert(tEffectNames, sEffectName);
							end
						else
							local rBannedType = {};
							rBannedType['type'] = sType;
							rBannedType['name'] = sEffectName;
							table.insert(tBannedTypes, rBannedType);
						end
					else
						local bBanned;
						if tBannedTypes[1] then
							for _,value in ipairs(tBannedTypes) do
								if string.match(sTypeLower, string.lower(value.type)) then
									local _,_,_,sLocFly,sLocHover = parseSpeedType(value.type, tFGSpeedNew, false);
									if sLocHover and not sLocFly and sTypeHover then
										if sTypeFly then
											sType = string.gsub(sType, '%s*%(%s*[Hh][Oo][Vv][Ee][Rr]%s*%)%s*', '');
											table.insert(tEffectNames, sEffectName);
										end
									end
									bBanned = true;
									table.insert(tEffectNames, WtWCommon.getEffectName(_,value.name));
								end
							end
						end
						if tModdedTypes[1] then
							for _,value in ipairs(tModdedTypes) do
								if string.match(sTypeLower, string.lower(value.type)) then
									local _,_,_, sLocFly, _, sLocSpider = parseSpeedType(value.type, tFGSpeedNew, false);
									if sLocFly or (sLocSpider and bMatchSpider) then
										tFGSpeedNew[nFound]['mod'] = value.mod;
										table.insert(tEffectNames, WtWCommon.getEffectName(_,value.name));
									else
										if not sTypeHover and not sTypeSpider then
											tFGSpeedNew[nFound]['mod'] = value.mod;
											table.insert(tEffectNames, WtWCommon.getEffectName(_,value.name));
										end
									end
								end
							end
						end
						if nFound and not bBanned then
							local bFaster;
							local nCurrentVel = tonumber(tFGSpeedNew[nFound]['velocity']);
							if not nCurrentVel then bFaster = true end
							if nCurrentVel and (nBaseSpeed >= nCurrentVel) then bFaster = true end
							if not bExactMatch then
								if sQualifier then
									if bFaster then
										table.remove(tFGSpeedNew, nFound);
										table.insert(tEffectNames, sEffectName);
									else
										nRecheck = nFound;
										sRecheckLabel = sEffectName;
									end
									nFound = false;
								else
									if sTypeFly then
										if (nHover == 1) or sTypeHover then
											tFGSpeedNew[nFound]['type'] = 'Fly (hover)'
											table.insert(tEffectNames, sEffectName);
										end
									elseif sTypeSpider and not bMatchSpider then
										tFGSpeedNew[nFound]['type'] = 'Spider Climb'
										table.insert(tEffectNames, sEffectName);
									else
										nFound = false;
									end
								end
							end
						end
						if not nFound and not bBanned then
							local tSpdRcrd = {}
							tSpdRcrd['type'] = sType;
							table.insert(tFGSpeedNew, tSpdRcrd)
							table.insert(tEffectNames, sEffectName);
						end
					end
				end
			end
		else
			if bProne and StringManager.startsWith(sRmndrLower, 'type') then
				bRecognizedRmndr = true;
				nMod = nil;
			end
		end
		if StringManager.startsWith(sRmndrLower, 'inc') then
			bRecognizedRmndr = true;
			if string.match(sRmndrLower, '%)$') then
				if nMod then
					WtWCommon.reportError("SpeedManager.speedCalculator - Syntax Error 664");
				else
					local sRmndrRemainder = sRmndrLower:gsub('^inc%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					local nSpeedInc = tonumber(sRmndrRemainder);
					if not nSpeedInc then
						WtWCommon.reportError("SpeedManager.speedCalculator - Syntax Error 670")
					else
						nSpeedMod = nSpeedMod + nSpeedInc;
						table.insert(tEffectNames, sEffectName);
					end
				end
			else
				if nMod then
					nSpeedMod = nSpeedMod + nMod;
					nMod = nil;
					table.insert(tEffectNames, sEffectName);
				end
			end
		end
		if StringManager.startsWith(sRmndrLower, 'dec') then
			bRecognizedRmndr = true;
			if string.match(sRmndrLower, '%)$') then
				if nMod then
					WtWCommon.reportError("SpeedManager.speedCalculator - Syntax Error 684");
				else
					local sRmndrRemainder = sRmndrLower:gsub('^dec%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					local nSpeedInc = tonumber(sRmndrRemainder);
					if not nSpeedInc then
						WtWCommon.reportError("SpeedManager.speedCalculator - Syntax Error 690")
					else
						nSpeedMod = nSpeedMod - nSpeedInc;
						table.insert(tEffectNames, sEffectName);
						if not string.match(sEffectName, '^Exhausted$')
							and not string.match(sEffectName, '^Item Too Heavy$')
						then
							nDecs = nDecs + nSpeedInc;
							table.insert(tFreeNames, sEffectName);
						end
					end
				end
			else
				if not nMod then
					WtWCommon.reportError("Walk This Way - Syntax Error - use SPEED: 5 dec or SPEED: dec(5)", true);
				else
					nSpeedMod = nSpeedMod - nMod;
					nDecs = nDecs + nMod;
					table.insert(tFreeNames, sEffectName);
					nMod = nil;
					table.insert(tEffectNames, sEffectName);
				end
			end
		end
		if not bRecognizedRmndr and sRmndrLower ~= '' then
			WtWCommon.reportError("Walk This Way - Syntax Error - "..tostring(sRmndrLower)
				.." is not a recognized command. Try inc, dec, max, doubled, halved, difficult, or type. Otherwise try the forums.",
				true
			);
		else
			if nMod and sRmndrLower == '' then
				local sNMod = tostring(nMod)
				if string.match(sNMod, '^%-') then
					nSpeedMod = nSpeedMod + nMod;
					nDecs = nDecs - nMod;
					table.insert(tFreeNames, sEffectName);
				else
					table.insert(tRebase, nMod)
				end
				table.insert(tEffectNames, sEffectName);
			end
		end
	end

	local nRebase;
	for k,v in ipairs(tRebase) do
		local nV = tonumber(v);
		if nV then
			if k > 1 then
				if nRebase < nV then nRebase = nV end
			else
				nRebase = nV;
			end
		end
	end
	if nRecheck and nRebase and nRebase >= tFGSpeedNew[nRecheck]['velocity'] then
		table.remove(tFGSpeedNew, nRebase);
		if sRecheckLabel then table.insert(tEffectNames, sRecheckLabel) end
	end

	local bDifficult;
	if bFree then
		bDifficult = false;
		nExtra = 0;
		nHalved = nHalvedStone;
		nSpeedMod = nSpeedMod + nDecs;
		if tDecMods[1] then
			for _,tMod in ipairs(tDecMods) do
				for _,tSpdRcrd in ipairs(tFGSpeedNew) do
					if tSpdRcrd['type'] == tMod['type'] then
						tSpdRcrd['velocity'] = tSpdRcrd['velocity'] - tMod['mod'];
						table.insert(tFreeNames, tMod['name']);
					end
				end
			end
		end
		local tEffectNamesCopy = tEffectNames;
		if tFreeNames[1] then
			for _,sEffectNameRem in ipairs(tFreeNames) do
				for k,sEffectName in ipairs(tEffectNamesCopy) do
					if sEffectNameRem == sEffectName then
						table.remove(tEffectNames, k);
						break;
					end
				end
			end
		end
	end

	if nDoubled > 0 then
		if nHalved > 0 then
			local nDoubledOrigin = nDoubled;
			local nHalvedOrigin = nHalved;
			nDoubled = nDoubled - nHalvedOrigin;
			nHalved = nHalved - nDoubledOrigin;
		end
	end

	local nHighest = 0;
	local sHighestType, bCharger;
	if ActorManager5E then
		bCharger = (OptionsManager.isOption('GAVE', '2024') and ActorManager5E.hasRollFeat2024(nodeCT, 'Charger'));
	end
	for k,tSpdRcrd in ipairs(tFGSpeedNew) do
		local nFGSpeed = tSpdRcrd['velocity'];
		local nFGSpeedNew = nFGSpeed;
		local bFound;
		local nWalkSpeed;
		if not nFGSpeedNew then
			for _,v in ipairs(tFGSpeedNew) do
				if v.type == 'walk' or v.type == '' then
					nWalkSpeed = v.velocity;
					nWalkSpeed = tonumber(nWalkSpeed);
					bFound = true;
				else
					if not nWalkSpeed and bFound then
						nWalkSpeed = v.velocity;
						nWalkSpeed = tonumber(nWalkSpeed);
						bFound = true;
					end
				end
			end
			if not nWalkSpeed then nWalkSpeed = tFGSpeedNew[1].velocity end
			nWalkSpeed = tonumber(nWalkSpeed);
			if nWalkSpeed then
				tFGSpeedNew[k]['velocity'] = tostring(nWalkSpeed);
			else
				nFGSpeedNew = 30;
				WtWCommon.reportError("SpeedManager.speedCalculator - not nWalkSpeed.");
			end
		end
		if nFGSpeedNew then
			if nRebase and (nRebase > nFGSpeedNew) then nFGSpeedNew = nRebase end

			local nLocalSpdMod = nSpeedMod
			if tSpdRcrd.mod then nLocalSpdMod = nLocalSpdMod + tSpdRcrd.mod end
			local nSpeedFinal = nFGSpeedNew + nLocalSpdMod;
			if nSpeedFinal <= 0 then
				tFGSpeedNew[k]['velocity'] = '0'
				if string.match(string.lower(tFGSpeedNew[k]['type']), 'hover') then
					tFGSpeedNew[k]['type'] = '(hover)'
				end
			else
				local nDoubledLocal = nDoubled
				local nHalvedLocal = nHalved
				local nTripledLocal = nTripled
				while nDoubledLocal > 0 do
					nSpeedFinal = nSpeedFinal * 2;
					nDoubledLocal = nDoubledLocal - 1;
				end
				while nHalvedLocal > 0 do
					nSpeedFinal = nSpeedFinal / 2;
					nHalvedLocal = nHalvedLocal - 1;
				end
				while nTripledLocal > 0 do
					nSpeedFinal = nSpeedFinal * 3;
					nTripledLocal = nTripledLocal - 1;
				end
				if nSpeedMax then
					if not bFree then
						nSpeedMaxMax = nSpeedMax;
					end
					if nSpeedMaxMax and nSpeedFinal > nSpeedMaxMax then
						nSpeedFinal = nSpeedMaxMax;
					end
				end
				local nSpdFnlFnl = nSpeedFinal;
				if bCharger then nSpeedFinal = nSpeedFinal + 10 end
				local nDashType = nDash;
				while nDashType > 0 do
					nSpdFnlFnl = nSpdFnlFnl + nSpeedFinal;
					nDashType = nDashType - 1;
				end
				tFGSpeedNew[k]['velocity'] = tostring(nSpdFnlFnl);
			end
		end
		local nVel = tonumber(tFGSpeedNew[k]['velocity']);
		if nVel and nVel > nHighest then
			nHighest = nVel;
			sHighestType = tFGSpeedNew[k]['type'];
		elseif nVel == nHighest and sHighestType and sHighestType ~= 'Walk' then
			if tFGSpeedNew[k]['type'] == 'Walk' then
				sHighestType = tFGSpeedNew[k]['type'];
			elseif string.match(tFGSpeedNew[k]['type'], 'Fly') then
				sHighestType = tFGSpeedNew[k]['type'];
			end
		end
	end

	if bDifficult == nil then
		if bDifficultButton ~= nil then
			bDifficult = bDifficultButton;
			if bDifficultButton then
				DB.setValue(nodeWtWCT, 'difficult', 'number', 1);
				DB.setValue(nodeWtWCT, 'difficult_button', 'string', 'button');
			else
				DB.setValue(nodeWtWCT, 'difficult', 'number', 0);
				DB.setValue(nodeWtWCT, 'difficult_button', 'string', 'button');
			end
		else
			if bDifficultEffect then
				DB.setValue(nodeWtWCT, 'difficult', 'number', 1);
				DB.setValue(nodeWtWCT, 'difficult_button', 'string', 'effect');
				bDifficult = true;
			else
				local sDifficultSource = DB.getValue(nodeWtWCT, 'difficult_button', '');
				if sDifficultSource ~= 'button' then
					DB.setValue(nodeWtWCT, 'difficult', 'number', 0);
					DB.setValue(nodeWtWCT, 'difficult_button', 'string', 'effect');
					bDifficult = bDifficultEffect;
				end
			end
		end
	else
		if bDifficult == false then
			DB.setValue(nodeWtWCT, 'difficult', 'number', 0);
			DB.setValue(nodeWtWCT, 'difficult_button', 'string', 'effect');
		else
			DB.setValue(nodeWtWCT, 'difficult', 'number', 1);
			DB.setValue(nodeWtWCT, 'difficult_button', 'string', 'effect');
		end
	end

	return updateDisplaySpeed(nodeCT, tFGSpeedNew, nBaseSpeed, bProne, sPref, tEffectNames, nHighest, bNoBase
		, sHighestType, bDifficult, nExtra, bSwimming
	);
end
-- luacheck: pop

function reportRootData(nodeCT, nHover)
	--local bHasRoot, bHasHover, sRootEffectName = WtWCommon.hasRoot(nodeCT);
	local sHoverPattern = '^speed:%s*%d*%s*type%s*%(%s*[^-][%l%u]*%s*%(%s*hover%s*%)%s*%)$'
	local bHover = WtWCommon.getCompsDataByPattern(nodeCT, sHoverPattern, nil, true, true);
	local tRoot = {};
	local tSpdRcrd = {};
	tSpdRcrd['velocity'] = '0';
	if nHover == 1 or bHover then
		tSpdRcrd['type'] = 'Walk (hover)';
	else
		tSpdRcrd['type'] = 'Walk';
	end
	table.insert(tRoot, tSpdRcrd);
	return tRoot;
end

function parseSpeedType(sType, tFGSpeedNew, bMatch)
	local sTypeLower = string.lower(sType);
	local sMatch = string.gsub(sTypeLower, '%(', '%%(');
	sMatch = string.gsub(sMatch, '%)', '%%)');
	local sSTypeLowerStripped = string.gsub(sTypeLower, '%s*[%(%)]%s*', '[%(%)]');
	local sTypeFly = string.match(sTypeLower, 'fly')
	local sTypeHover = string.match(sTypeLower, 'hover')
	local sTypeSpider = string.match(sTypeLower, 'spider climb')
	local nFound;
	local bMatchSpider = false;
	local bExactMatch = false;
	local sQualifier;
	--local sQualifierSimplified;
	if bMatch then
		for k,value in ipairs(tFGSpeedNew) do
			local vTypeLower = string.lower(value.type);
			local sVQualifier = string.match(value.type, '%(%s*%S*%s*%)%s*$');
			local sVQualifierSimplified;
			if sVQualifier then
				sVQualifierSimplified = string.gsub(sVQualifier, '%s*[%(%)]%s*', '[%(%)]');
				sVQualifierSimplified = string.lower(sVQualifierSimplified);
				if sVQualifierSimplified == '(hover)' then
					sVQualifier = false;
					--sVQualifierSimplified = false;
				end
			end
			local sVTypeLowerStripped = string.gsub(vTypeLower, '%s*[%(%)]%s*', '[%(%)]');
			if sTypeFly then
				if string.match(vTypeLower, 'fly') then
					nFound = k;
				end
				if sTypeHover then
					if string.match(vTypeLower, 'hover') then
						nFound = k;
					end
				end
			elseif sTypeSpider then
				if string.match(vTypeLower, 'climb') then
					nFound = k;
					if string.match(vTypeLower, 'spider climb') then
						bMatchSpider = true;
					end
				end
			end
			if string.match(vTypeLower, sMatch) then
				nFound = k;
				if sVTypeLowerStripped == sSTypeLowerStripped then
					bExactMatch = true;
				end
			end
			if nFound then
				sQualifier = sVQualifier;
				--sQualifierSimplified = sVQualifierSimplified;
			end
		end
	end
	return nFound, bExactMatch, sQualifier, sTypeFly, sTypeHover, sTypeSpider, bMatchSpider;
end

-- luacheck: push ignore 561
function updateDisplaySpeed(nodeCT, tFGSpeedNew, nBaseSpeed, bProne, sUnitsPrefer, tEffectNames, nHighest, bNoBase
	, sHighestType, bDifficult, nExtra, bSwimming
)
	if not Session.IsHost or not nodeCT or not tFGSpeedNew or not nBaseSpeed then
		WtWCommon.reportError("SpeedManager.updateDisplaySpeed - not isHost or not nodeCT or not tFGSpeedNew or not nBaseSpeed");
		return;
	end

	if not sUnitsPrefer then sUnitsPrefer = OptionsManager.getOption('DDLU') end
	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
	--[[
	local sLngthUnits = DB.getValue(nodeWtWCT, 'units');
	if not sLngthUnits or sLngthUnits == '' then
		WtWCommon.reportError("SpeedManager.updateDisplaySpeed - units not in DB for "..DB.getValue(nodeCT, 'name', ''));
		sLngthUnits = getEffectUnits();
	end
	]]
	local sEffectUnits = getEffectUnits();

	local sMarker = "";
	if bSwimming then sMarker = "; swimming" end
	if bDifficult then sMarker = sMarker.."; difficult" end
	if nExtra and nExtra ~= 0 then sMarker = sMarker.."; Extra: "..tostring(nExtra) end
	if sMarker ~= "" then
		sMarker = sMarker.."*";
	elseif tEffectNames[1] then
		sMarker = "*";
	end

	local nConvFactor = 1;
	--if sLngthUnits ~= sUnitsPrefer then
	--	nConvFactor = WtWCommon.getConversionFactor(sLngthUnits, sUnitsPrefer);
	if sEffectUnits ~= sUnitsPrefer then
		nConvFactor = WtWCommon.getConversionFactor(sEffectUnits, sUnitsPrefer);
	end
	local nRoundingPref = getRoundingPref(sUnitsPrefer);
	nBaseSpeed = nBaseSpeed * nConvFactor;
	local nCurrentSpeed = nBaseSpeed;
	local nBonusSpeed, bCurrentFound;
	local sReturn = "";

	for k,tSpdRcrd in ipairs(tFGSpeedNew) do
		tSpdRcrd['velocity'] = tSpdRcrd['velocity'] * nConvFactor
		tSpdRcrd['velocity'] = WtWCommon.roundNumber(tSpdRcrd['velocity'], 0, 'down', nRoundingPref);
		--[[
		if sUnitsPrefer == 'ft.' then
			tSpdRcrd['velocity'] = tSpdRcrd['velocity'] / 2.5;
			tSpdRcrd['velocity'] = math.floor(tSpdRcrd['velocity']);
			tSpdRcrd['velocity'] = tSpdRcrd['velocity'] * 2.5;
		elseif sUnitsPrefer == 'tiles' then
			tSpdRcrd['velocity'] = tSpdRcrd['velocity'] / 0.5;
			tSpdRcrd['velocity'] = math.floor(tSpdRcrd['velocity']);
			tSpdRcrd['velocity'] = tSpdRcrd['velocity'] * 0.5;
		else
			if sUnitsPrefer == 'm' then
				tSpdRcrd['velocity'] = tSpdRcrd['velocity'] / 0.75;
				tSpdRcrd['velocity'] = math.floor(tSpdRcrd['velocity']);
				tSpdRcrd['velocity'] = tSpdRcrd['velocity'] * 0.75;
			end
		end
		]]

		local sVelWithUnits = tostring(tSpdRcrd['velocity']) .. ' ' .. sUnitsPrefer;

		if bNoBase and not bCurrentFound then
			nCurrentSpeed = tSpdRcrd['velocity'];
			bCurrentFound = true;
		end
		if tSpdRcrd.type == '' or (string.match(tSpdRcrd.type, '^Walk')) then
			nCurrentSpeed = tSpdRcrd['velocity'];
			if bProne then
				sReturn = "Crawl " .. sVelWithUnits;
				break;
			end
			local sQualifier = string.match(tSpdRcrd.type, '%s*%(%s*%S*%s*%)%s*$');
			if sQualifier then
				if k == 1 then
					sReturn = sVelWithUnits .. ' ' .. sQualifier;
				else
					sReturn = sVelWithUnits .. ' ' .. sQualifier .. ', ' .. sReturn;
				end
			else
				if k == 1 then
					sReturn = sVelWithUnits;
				else
					sReturn = sVelWithUnits .. ', ' .. sReturn;
				end
			end
		else
			local sQualifier = string.match(tSpdRcrd.type, '%s*%(%s*%S*%s*%)%s*$');
			if sQualifier then
				local sTypeSansQual = string.gsub(tSpdRcrd.type, '%s*%(%s*%S*%s*%)%s*$', '');
				if k == 1 then
					sReturn = sTypeSansQual .. ' ' .. sVelWithUnits .. ' ' .. sQualifier;
				else
					sReturn = sReturn ..', '..sTypeSansQual..' '..sVelWithUnits..' '..sQualifier;
				end
			else
				if k == 1 then
					sReturn = tSpdRcrd.type .. ' ' .. sVelWithUnits;
				else
					sReturn = sReturn .. ', ' .. tSpdRcrd.type .. ' ' .. sVelWithUnits;
				end
			end
		end
	end
	if bProne and not string.match(sReturn, 'Crawl') then
		sReturn = 'Crawl '..tostring(nHighest * nConvFactor)..' '..sUnitsPrefer;
	end
	if string.match(sReturn, 'Crawl') then
		DB.setValue(nodeWtWCT, 'highest', 'number', nHighest * nConvFactor);
		DB.setValue(nodeWtWCT, 'highest_type', 'string', 'Crawl');
	else
		DB.setValue(nodeWtWCT, 'highest', 'number', nHighest * nConvFactor);
		DB.setValue(nodeWtWCT, 'highest_type', 'string', sHighestType);
	end
	if sReturn == "" then sReturn = "0 "..sUnitsPrefer end
	sReturn = sReturn .. sMarker;
	sReturn = StringManager.strip(sReturn);
	if sReturn and sReturn ~= '' then
		local sSpeedWtWPrev = DB.getValue(nodeCT, 'speed_wtw', '');
		local sCurSpeedPrev = DB.getValue(nodeWtWCT, 'currentSpeed', '');
		if sSpeedWtWPrev ~= sReturn then DB.setValue(nodeCT, 'speed_wtw', 'string', sReturn) end
		if sCurSpeedPrev ~= sReturn then DB.setValue(nodeWtWCT, 'currentSpeed', 'string', sReturn) end
		if sSpeedWtWPrev == sReturn then return false end
		local rActor = ActorManager.resolveActor(nodeCT);
		if not rActor then
			WtWCommon.reportError("SpeedManager.updateDisplaySpeed - not rActor");
			return;
		end
		local nodeEffectNames = DB.getChild(nodeWtWCT, 'effectNames');
		if nodeEffectNames then
			DB.deleteChildren(nodeEffectNames);
		else
			nodeEffectNames = DB.createChild(nodeWtWCT, 'effectNames');
		end
		if tEffectNames then
			for _,sEffectName in ipairs(tEffectNames) do
				local nodeEffectNameID = DB.createChild(nodeEffectNames);
				DB.setValue(nodeEffectNameID, 'name', 'string', sEffectName);
			end
		end
		local nodeChar = ActorManager.getCreatureNode(rActor);
		if not nodeChar then
			WtWCommon.reportError("SpeedManager.updateDisplaySpeed - not nodeChar");
			return;
		end
		local nodeCharWtW = DB.createChild(nodeChar, 'WalkThisWay');
		nBonusSpeed = nCurrentSpeed - nBaseSpeed
		DB.setValue(nodeCharWtW, 'bonus', 'number', nBonusSpeed);
		DB.setValue(nodeCharWtW, 'currentspeed', 'number', nCurrentSpeed);
		return true;
	else
		WtWCommon.reportError("SpeedManager.updateDisplaySpeed - no sReturn");
		return false;
	end
end
-- luacheck: pop

function reparseAllBaseSpeeds()
	if not Session.IsHost then
		WtWCommon.reportError("SpeedManager.reparseAllBaseSpeeds - not host");
		return;
	end
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		reparseBaseSpeed(false, nodeCT);
	end
end

function reparseBaseSpeedSpecial(nodeupdated)
	local nodeChar = DB.getChild(nodeupdated, '...');
	local nodeCT = CombatManager.getCTFromNode(nodeChar);

	reparseBaseSpeed(DB.getChild(nodeCT, 'speed'), nodeCT)
end
function reparseBaseSpeed(nodeSpeed, nodeCT)
	if not Session.IsHost then return end

	if not nodeCT then
		if nodeSpeed then
			nodeCT = DB.getParent(nodeSpeed);
		else
			WtWCommon.reportError("SpeedManager.reparseBaseSpeed - not nodeCT and not nodeSpeed");
			return;
		end
	end
	if not nodeCT then
		WtWCommon.reportError("SpeedManager.reparseBaseSpeed - not nodeCT");
		return;
	end

	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
	local nodeHover = DB.createChild(nodeWtWCT, 'hover');
	if nodeHover then DB.deleteNode(nodeHover) end
	local nodeFGSpeed = DB.getChild(nodeWtWCT, 'FGSpeed');
	if nodeFGSpeed then DB.deleteNode(nodeFGSpeed) end
	parseBaseSpeed(nodeCT, true);
end

-- luacheck: push ignore 561
function parseBaseSpeed(nodeCT, bCalc)
	if not Session.IsHost or not nodeCT then
		WtWCommon.reportError("SpeedManager.parseBaseSpeed - not nodeCT or not host");
		return;
	end

	local sEffectUnits = getEffectUnits();

	--dont forget some creatures dont have a speed, like objects
	local sFGSpeed = DB.getValue(nodeCT, 'speed');
	if not sFGSpeed or sFGSpeed == '' then sFGSpeed = '0' end

	if ActorManager.isPC(nodeCT) then
		local nodeChar = ActorManager.getCreatureNode(nodeCT);
		local nodeSpeed = DB.getChild(nodeChar, 'speed');
		if sFGSpeed == '0' then setCharSheetSpeed(nil, nodeChar, nodeSpeed) end
		local nodeFGSpeedSpecial = DB.getValue(nodeSpeed, 'special', '');
		if nodeFGSpeedSpecial ~= '' then sFGSpeed = sFGSpeed .. '; ' .. nodeFGSpeedSpecial end
	end

	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
	if not DB.getValue(nodeWtWCT, 'hover') then
		if string.match(string.lower(sFGSpeed), 'hover') then
			DB.setValue(nodeWtWCT, 'hover', 'number', 1);
		else
			DB.setValue(nodeWtWCT, 'hover', 'number', 0);
		end
	end

	local nodeFGSpeed = DB.getChild(nodeWtWCT, 'FGSpeed');
	if not nodeFGSpeed then
		nodeFGSpeed = DB.createChild(nodeWtWCT, 'FGSpeed');
		local aSpdTypeSplit = StringManager.splitByPattern(sFGSpeed, '[,;]', true)
		--local sFinalUnits = '';
		--local sLngthUnits = '';
		local sStripPattern = '';
		local sMphAdd, sLngthUnits, sUnitsBase;
		for _,sSpdTypeSplit in ipairs(aSpdTypeSplit) do
			local nodeSpeedRcrd = DB.createChild(nodeFGSpeed);
			local sVelocity = string.match(sSpdTypeSplit, '%d+');
			if not sVelocity then
				for _,node in pairs(DB.getChildren(nodeWtWCT, 'FGSpeed')) do
					if DB.getValue(node, 'type') == 'Walk' then
						sVelocity = DB.getValue(node, 'velocity');
					end
				end
				if not sVelocity then sVelocity = '0' end
			end
			local sRemainder = string.gsub(sSpdTypeSplit, '%d+', '', 1);
			local sMph = string.match(sSpdTypeSplit, '%d+%s+mph');
			if sMph then
				sMphAdd = string.match(sSpdTypeSplit, '%(%s*%d+%s+mph%s*%)');
				if sMphAdd then
					sMphAdd = string.gsub(sMphAdd, '%(', '');
					sMphAdd = string.gsub(sMphAdd, '%)', '');
					sMphAdd = '%('..sMphAdd..'%)';
				end
			end
			local sType;
			--local bConverted = false;
			--local nConvFactor = 1;
			--if sLngthUnits == '' then
			if not sLngthUnits then
				local aUnitsSplit = StringManager.splitByPattern(sSpdTypeSplit, '%s+', true)
				--local bFound = false;
				for _,word in ipairs(aUnitsSplit) do


					--[[
					if not bFound then
						if string.match(string.lower(word), '^ft%.?$')
							or string.match(string.lower(word), '^feet$')
						then
							bFound = true;
						elseif string.match(string.lower(word), '^m%.?$') then
							bFound = true;
						else
							if string.match(string.lower(word), '^tiles%.?$') then
								bFound = true;
							end
						end
						if bFound then sLngthUnits = word end
					]]
					if not sLngthUnits then
						if string.match(string.lower(word), '^ft%.?$') or string.match(string.lower(word), '^feet$')
							or string.match(string.lower(word), '^m%.?$')
							or string.match(string.lower(word), '^tiles%.?$')
							or string.match(string.lower(word), '^in%.?$') or string.match(string.lower(word), '^inches$')
						then
							--bFound = true;
							sLngthUnits = word;
						end
					end
				end
				--if not bFound then
				if not sLngthUnits then
					if sMph then
						sLngthUnits = 'mph';
					else
						sLngthUnits = sEffectUnits;
					end
				end
				sUnitsBase = WtWCommon.tidyUnits(sLngthUnits);
				--[[
				sFinalUnits = sLngthUnits;
				sFinalUnits = WtWCommon.tidyUnits(sFinalUnits);
				if sFinalUnits ~= sEffectUnits then
					nConvFactor = WtWCommon.getConversionFactor(sFinalUnits, sEffectUnits);
					sFinalUnits = sEffectUnits;
					bConverted = true;
				end
				]]
				if string.match(sLngthUnits, '%.') then
					sStripPattern = string.gsub(sLngthUnits, '%.', '');
					sStripPattern = sStripPattern .. '%.';
				end
				if sStripPattern == '' then sStripPattern = sLngthUnits end
			end
			if sMphAdd then
				sRemainder = string.gsub(sRemainder, sMphAdd, '');
			end
			sType = string.gsub(sRemainder, sStripPattern, '');
			sType = StringManager.strip(sType);
			sType = StringManager.capitalize(sType);
			if sType == '' then sType = 'Walk' end

			local nVelocity = tonumber(sVelocity);
			--nVelocity = roundNearestHalfTile(nVelocity, false, sFinalUnits);
			nVelocity = convertAndRound(nVelocity, sUnitsBase, sEffectUnits);

			--[[
			if bConverted and nVelocity then
				nVelocity = nVelocity * nConvFactor;
				if sLngthUnits == 'mph' then
					nVelocity = roundMph(nVelocity, sFinalUnits);
				end
			end
			]]
			sVelocity = tostring(nVelocity);
			DB.setValue(nodeSpeedRcrd, 'velocity', 'number', sVelocity);
			DB.setValue(nodeSpeedRcrd, 'type', 'string', sType);
		end
		--DB.setValue(nodeWtWCT, 'units', 'string', sFinalUnits);
	end
	if not DB.getValue(nodeCT, 'speed_wtw') or bCalc then speedCalculator(nodeCT, true) end
end
-- luacheck: pop

function setAllCharSheetSpeeds()
	if not Session.IsHost then
		WtWCommon.reportError("SpeedManager.setAllCharSheetSpeeds - not host");
		return;
	end
	local nodeCharSheets = DB.createNode('charsheet');
	local tNodeChars = DB.getChildList(nodeCharSheets);
	for _,nodeChar in ipairs(tNodeChars) do
		setCharSheetSpeed(nil, nodeChar);
	end
end
function setCharSheetSpeed(nodeUpdated, nodeChar, nodeSpeed)
	if (not nodeUpdated and not nodeChar) or not Session.IsHost then
		WtWCommon.reportError("SpeedManager.setCharSheetSpeed - not host or (not nodeUpdated and not nodeChar)");
		return;
	end

	if not nodeChar then
		if not nodeSpeed then nodeSpeed = DB.getParent(nodeUpdated) end
		nodeChar = DB.getParent(nodeSpeed);
	end
	if not nodeSpeed then nodeSpeed = DB.getChild(nodeChar, 'speed') end

	local nSpeedSet;
	if Session.RulesetName == "5E" then
		nSpeedSet = DB.getValue(nodeSpeed, 'total');
	else
		nSpeedSet = DB.getValue(nodeSpeed, 'final');
		if not nSpeedSet then nSpeedSet = DB.getValue(nodeSpeed, 'total') end
	end
	if not nSpeedSet then
		WtWCommon.reportError("Walk this Way cannot find the PC speed field for this ruleset.", true)
		return;
	end

	local nodeCT = CombatManager.getCTFromNode(nodeChar);
	local bCtSpeed = true;
	if nodeCT then
		--make sure CT speed is set
		local sSpeedCT = DB.getValue(nodeCT, 'speed');
		if not sSpeedCT or sSpeedCT == '' then
			bCtSpeed = false;
		end
	end

	--local sUnitPref = WtWCommon.getPreference(nodeCT);
	--local nConvFactor = WtWCommon.getConversionFactor(getEffectUnits(), sUnitPref);
	--nSpeedSet = WtWCommon.roundNumber(nSpeedSet * nConvFactor, 0, 'down', getRoundingPref(sUnitPref));
	--local nConvFactor = WtWCommon.getConversionFactor(sEffectUnits, WtWCommon.getPreference(nodeCT));
	--local nRoundConv = WtWCommon.getConversionFactor(sEffectUnits, 'tiles') * 2;
	--local nRounded = nSpeedSet * nRoundConv;
	--nRounded = math.floor(nRounded);
	--nRounded = nRounded / nRoundConv
	--nSpeedSet = nRounded * nConvFactor;
	nSpeedSet = convertAndRound(nSpeedSet, getEffectUnits(), WtWCommon.getPreference(nodeCT));

	local nodeCharWtW = DB.createChild(nodeChar, 'WalkThisWay');
	DB.setValue(nodeCharWtW, 'base', 'number', nSpeedSet);
	if not bCtSpeed then DB.setValue(nodeCT, 'speed', 'string', tostring(nSpeedSet)) end
end

function accommKnownExtsSpeed(nodeCT)
	local tReturn = {};
	local tEffectNames = {};
	local bReturn = false;
	if Session.RulesetName == "5E" then
		--local aDashFx = WtWCommon.getEffectsByTypeWtW(nodeCT, 'Dash$');
		local _,aDashFx = WtWCommon.getEffectNamesByText(nodeCT, "Dash");
		tReturn['nDash'] = 0;
		--for _ in ipairs(aDashFx) do
		for _,sEffectName in ipairs(aDashFx) do
			tReturn['nDash'] = tReturn['nDash'] + 1
			bReturn = true;
			--table.insert(tEffectNames, "Dash");
			table.insert(tEffectNames, sEffectName);
		end
		--forPay extension currently does encumbrance by teamTwoey (author: MatteKure)
		--https://forge.fantasygrounds.com/shop/items/1606/view
		--extension retired sometime around June 2026 due to ruleset absorbing the non-speed functionality
		--if OptionsManager.isOption('encumbrance_tracking', 'on') then
			local nodeChar = ActorManager.getCreatureNode(nodeCT);
			local nEncLevel = DB.getValue(nodeChar, sEncLevelPath, 0);
			if nEncLevel > 0 then
				bReturn = true;
				if nEncLevel == 1 then
					tReturn['nSpeedMod'] = -10;
				elseif nEncLevel == 2 then
					tReturn['nSpeedMod'] = -20;
				elseif nEncLevel == 3 then
					tReturn['nSpeedMax'] = 5;
				elseif nEncLevel > 3 then
					tReturn['nSpeedRoot'] = tLevelEncumbTypes[nEncLevel];
				end
				table.insert(tEffectNames ,tLevelEncumbTypes[nEncLevel])
			end
		--end
	elseif Session.RulesetName == 'PFRPG' or Session.RulesetName == '3.5E' then
		--if WtWCommon.hasEffectClause(nodeCT, "^Exhausted$", nil, false, true) then
		if WtWCommon.getEffectNamesByText(nodeCT, "Exhausted", tEffectNames) then
			tReturn['nHalved'] = 1;
			bReturn = true;
		--elseif WtWCommon.hasEffectClause(nodeCT, "^Entangled$", nil, false, true) then
		elseif WtWCommon.getEffectNamesByText(nodeCT, "Entangled", tEffectNames) then
			tReturn['nHalved'] = 1;
			bReturn = true;
		end
	end
	tReturn['tEffectNames'] = tEffectNames;

	if bReturn then
		return tReturn;
	else
		return;
	end
end

function handleEncumbUpdated(nodeLevelUpdated, bDontRecalc)
	--if not OptionsManager.isOption('encumbrance_tracking', 'on')
	if OptionsManager.isOption('HREN', 'off')
		or not nodeLevelUpdated or type(nodeLevelUpdated) ~= 'databasenode'
	then
		return;
	end
	local nodeCT = ActorManager.getCTNode(DB.getChild(nodeLevelUpdated, '...'));
	if not nodeCT then return end

	local nLevel = DB.getValue(nodeLevelUpdated, '.', 0);
	if nLevel > 4 then nLevel = 4 end
	if not bDontRecalc and nLevel == 0 then
		WtWCommon.reportError("is no longer Encumbered.", true, nil, nodeCT);
		speedCalculator(nodeCT);
		return;
	end

	if not tLevelEncumbTypes[nLevel] then populateEncumbranceTable() end

	if tLevelEncumbTypes[nLevel] then
		WtWCommon.reportError("is "..tLevelEncumbTypes[nLevel]..".", true, nil, nodeCT);
		if not bDontRecalc then speedCalculator(nodeCT) end
	end
end
function populateEncumbranceTable()
		--nLevel = 0 means not encumbered or encumbrance option disabled
	tLevelEncumbTypes[1] = "Encumbered";
		--nLevel = 1 means lightly encumbered or above first threshold (variant only)
	tLevelEncumbTypes[2] = "Heavily Encumbered";
		--nLevel = 2 means heavily encumbered or above second threshold (variant only)
	tLevelEncumbTypes[3] = "Exceeding Carrying capacity";
		--nLevel = 3 means can't carry or above third threshold (encumbrance must be on)
	tLevelEncumbTypes[4] = "Exceeding Drag capacity";
		--nLevel = 4 means can't drag or above fourth threshold (encumbrance must be on)
end
function toggleEncumbTracking(sOption) --luacheck: ignore 212
	local sEncOptionNew = OptionsManager.getOption('HREN');
	if sEncOptionNew == 'off' then
		WtWCommon.reportError("Encumbrance Tracking disabled.", true);
	elseif sEncOption == 'off' then
		WtWCommon.reportError("Encumbrance Tracking enabled.", true);
	end

	for _,nodeCTLcl in ipairs(CombatManager.getAllCombatantNodes()) do
		speedCalculator(nodeCTLcl);
	end

	sEncOption = sEncOptionNew;
end

function setExhaustionLevelWtW(rActor, ...)
	local rReturn = fsetExhaustionLevel(rActor, ...);

	handleExhaustion(rActor);

	return rReturn;
end
function handleExhaustion(rActor)
	if Session.RulesetName ~= "5E" then return end

	if not rActor or not rActor['sCTNode'] then
		WtWCommon.reportError("SpeedManager.handleExhaustion - not rActor or not sCTNode");
		return;
	end
	local nodeCT = DB.findNode(rActor['sCTNode'])
	if not nodeCT then
		WtWCommon.reportError("SpeedManager.handleExhaustion - not nodeCT");
		return;
	end

	local sNewEffect, nSpeedAdjust, bExhausted;
	local nExhaustMod = ActorManager5E.getExhaustionLevel(rActor);
	if nExhaustMod > 5 then
		if OptionsManager.isOption('ADEC', 'on') then
			sNewEffect = "Exhausted; DEATH; DESTROY";
		else
			sNewEffect = "Exhausted; DEAD";
		end
	elseif nExhaustMod < 1 then
		bExhausted = false;
	elseif (EffectsManagerExhausted and EffectsManagerExhausted.is2024()) --luacheck: ignore 113
		or (not EffectsManagerExhausted	and OptionsManager.isOption('GAVE', '2024')) --luacheck: ignore 113
	then
		nSpeedAdjust = nExhaustMod * 5;
		sNewEffect = "Exhausted; SPEED: dec(" .. nSpeedAdjust .. ")";
	elseif nExhaustMod > 4 then
		--sNewEffect = "Exhausted; SPEED: max(0); MAXHP: 0.5";
		sNewEffect = "Exhausted; SPEED: max(0)";
	elseif nExhaustMod > 3 then
		--sNewEffect = "Exhausted; SPEED: halved; MAXHP: 0.5";
		sNewEffect = "Exhausted; SPEED: halved";
	elseif nExhaustMod > 1 then
		sNewEffect = "Exhausted; SPEED: halved";
	else
		bExhausted = false;
	end

	--local tOldEffects = WtWCommon.hasEffectFindString(nodeCT, "^Exhausted; ", false, false, false, true);
	local tOldEffects = WtWCommon.getTextDataInLabel(nodeCT, "^Exhausted; ", nil, true);
	if bExhausted == false and tOldEffects and tOldEffects[1] then
		for _,v in ipairs(tOldEffects) do
			--EffectManager.expireEffect(nodeCT, v['node'], 0);
			EffectManager.removeEffect(nodeCT, v['node']);
		end
	end

	if sNewEffect then
		--local tOldEffects = WtWCommon.hasEffectFindString(nodeCT, "^Exhausted; ", false, false, false, true);
		local tOldEffects = WtWCommon.getTextDataInLabel(nodeCT, "^Exhausted; ", nil, true);
		if tOldEffects and tOldEffects[1] then
			local nFound;
			for k,v in ipairs(tOldEffects) do
				if v['label'] == sNewEffect then nFound = k end
			end
			if nFound then
				for k,v in ipairs(tOldEffects) do
					if k ~= nFound then
						--EffectManager.expireEffect(nodeCT, v['node'], 0);
						EffectManager.removeEffect(nodeCT, v['node']);
					end
				end
			else
				for k,v in ipairs(tOldEffects) do
					if k > 1 then
						--EffectManager.expireEffect(nodeCT, v['node'], 0);
						EffectManager.removeEffect(nodeCT, v['node']);
					else
						DB.setValue(tOldEffects[1]['node'], 'label', 'string', sNewEffect);
					end
				end
			end
		else
			--EffectManager.addEffect("", "", nodeCT, { sName = sNewEffect, nDuration = 0 }, true);
			EffectManager.addEffectByTable(nodeCT, { sName = sNewEffect, nDuration = 0 });
		end
	end
end

function addEffectByTableWtW(vActor, rEffect, ...)
	if rEffect and rEffect['sName'] then
		local sMatch = string.match(rEffect['sName'], "^Exhausted; ");
		if sMatch then
			if string.match(rEffect['sName'], "^Exhausted; Speed ")
				or string.match(rEffect['sName'], "^Exhausted; DEATH$")
			then
				return nil;
			end
		end
	end

	return faddEffectByTable(vActor, rEffect, ...);
end

function checkFitness(nodeUpdated, bRecheck)
	local nodeCT, nodeChar;
	if string.match(DB.getPath(nodeUpdated), '^charsheet%.') then
		nodeChar = DB.getChild(nodeUpdated, '....');
		nodeCT = CombatManager.getCTFromNode(nodeChar);
		if not nodeCT then return end
	else
		nodeCT = DB.getChild(nodeUpdated, '....');
	end

	local nodeItem = DB.getParent(nodeUpdated);
	local sItemNodePath = DB.getPath(nodeItem);
	if not bRecheck and DB.getValue(nodeUpdated, '.', 0) ~= 2 then
		undoItemTooHeavy(nodeCT, sItemNodePath);
		return;
	end

	if not bRecheck and nodeChar and OptionsManager.isOption('GAVE', '2014')
		and string.match(string.lower(DB.getValue(nodeChar, 'race', '')), 'dwarf')
		and string.lower(DB.getValue(nodeItem, 'subtype', '')) == 'heavy armor'
	then
		undoItemTooHeavy(nodeCT, sItemNodePath);
		return;
	end

	local sStrField = DB.getValue(nodeItem, 'strength');
	if not sStrField then
		undoItemTooHeavy(nodeCT, sItemNodePath);
		return;
	end
	local sStrReq = string.gsub(string.lower(sStrField), '%s*strength%s*', '');
	local sStrReq = string.gsub(sStrReq, '%s*str%s*', '');
	if sStrReq == sStrField then
		undoItemTooHeavy(nodeCT, sItemNodePath);
		return;
	end
	local nStrReq = tonumber(sStrReq);
	if not nStrReq then
		undoItemTooHeavy(nodeCT, sItemNodePath);
		return;
	end
	local nStr = DB.getValue(nodeCT, 'abilities.strength.score');
	if not nStr then return end
	--local nStr = nStr + EffectManager5E.getEffectsBonus(nodeCT, 'STR', true);
	local nStr = nStr + EffectManager.getBonusMod(nodeCT, 'STR');

	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
	local nodeHandlerList = DB.createChild(nodeWtWCT, 'handler_list');
	if nStr < nStrReq then
		local nIdentified = DB.getValue(nodeItem, 'isidentified', 1);
		local sItemName;
		if nIdentified == 1 then
			sItemName = DB.getValue(nodeItem, 'name');
		end
		if not sItemName then
			sItemName = DB.getValue(nodeItem, 'nonid_name', Interface.getString('library_recordtype_empty_nonid_item'));
		end
		local sLabel = 'Item Too Heavy; SPEED: dec(10); '..sItemName;
		local bFound;
		for _,nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
			local nodeItemRef = DB.getChild(nodeEffect, 'itemref');
			if nodeItemRef and DB.getValue(nodeItemRef, '.') == sItemNodePath then
				bFound = true;
				break;
			end
		end
		if not bFound then
			--EffectManager.addEffect('', '', nodeCT, { sName = sLabel, nDuration = 0 }, '');
			EffectManager.addEffectByTable(nodeCT, { sName = sLabel, nDuration = 0 });
			for _,nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
				local nodeItemRef = DB.getChild(nodeEffect, 'itemref');
				if DB.getValue(nodeEffect, 'label') == sLabel and not nodeItemRef then
					DB.setValue(nodeEffect, 'itemref', 'string', sItemNodePath);
				end
			end
		end
	else
		undoItemTooHeavy(nodeCT, sItemNodePath, nodeHandlerList);
	end

	local bFound;
	for _,node in pairs(DB.getChildren(nodeHandlerList, '.')) do
		if DB.getValue(node, 'node', '') == sItemNodePath then
			bFound = true;
			break;
		end
	end
	if not bFound then
		local nodeHandlerItem = DB.createChild(nodeHandlerList);
		DB.setValue(nodeHandlerItem, 'node', 'string', sItemNodePath);
	end
end
function recheckFitness(nodeUpdated, nodeCT)
	if not nodeCT then nodeCT = DB.getChild(nodeUpdated, '....') end
	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
	local tFitnesslist = {}
	for _,nodeItemPathId in pairs(DB.getChildren(nodeWtWCT, 'handler_list')) do
		local nodeItem = DB.findNode(DB.getValue(nodeItemPathId, 'node'));
		table.insert(tFitnesslist, DB.getChild(nodeItem, 'carried'));
	end
	for _,nodeCarried in ipairs(tFitnesslist) do
		checkFitness(nodeCarried, true);
	end
end
function checkInvForHeavyItems(nodeCT)
	local nodeChar = nodeCT;
	if ActorManager.isPC(nodeCT) then nodeChar = ActorManager.getCreatureNode(nodeCT) end

	for _,nodeItem in pairs(DB.getChildren(nodeChar, 'inventorylist')) do
		checkFitness(DB.getChild(nodeItem, 'carried'));
	end
end
function checkAllForHeavyItems()
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		checkInvForHeavyItems(nodeCT);
	end
	DB.addHandler('charsheet.*.inventorylist.*.carried', 'onUpdate', checkFitness);
	DB.addHandler(sCTCombatantPath..'.inventorylist.*.carried', 'onUpdate', checkFitness);
	DB.addHandler(sCTCombatantPath..'.abilities.strength.score', 'onUpdate', recheckFitness);
end
function removeEffectTooHeavy(nodeCT, sItemNodePath)
	local nodeMarkedForDeletion;
	local nodeEffects = DB.getChild(nodeCT, 'effects');
	for _,nodeEffect in pairs(DB.getChildren(nodeEffects, '.')) do
		local nodeItemRef = DB.getChild(nodeEffect, 'itemref');
		if nodeItemRef and DB.getValue(nodeItemRef, '.', '') == sItemNodePath then
			nodeMarkedForDeletion = nodeEffect;
			break;
		end
	end

	--if nodeMarkedForDeletion then DB.deleteNode(nodeMarkedForDeletion) end
	if nodeMarkedForDeletion then EffectManager.removeEffect(nodeCT, nodeMarkedForDeletion) end
end
function undoItemTooHeavy(nodeCT, sItemNodePath, nodeHandlerList)
	if not nodeHandlerList then
		local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
		nodeHandlerList = DB.createChild(nodeWtWCT, 'handler_list');
	end
	local tMarkedForDeletion = {};
	for _,node in pairs(DB.getChildren(nodeHandlerList, '.')) do
		if DB.getValue(node, 'node') == sItemNodePath then
			table.insert(tMarkedForDeletion, node);
		end
	end
	for _,nodeToDelete in ipairs(tMarkedForDeletion) do
		DB.deleteNode(nodeToDelete);
	end

	removeEffectTooHeavy(nodeCT, sItemNodePath);
end
function toggleCheckItemStr()
	if OptionsManager.isOption('check_item_str', 'on') then
		checkAllForHeavyItems();
	else
		clearAllItemStrengthHandlers();
	end
end
function clearAllItemStrengthHandlers()
	DB.removeHandler('charsheet.*.inventorylist.*.carried', 'onUpdate', checkFitness);
	DB.removeHandler(sCTCombatantPath..'.inventorylist.*.carried', 'onUpdate', checkFitness);
	DB.removeHandler(sCTCombatantPath..'.abilities.strength.score', 'onUpdate', recheckFitness);
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
		local nodeHandlerList = DB.createChild(nodeWtWCT, 'handler_list');
		DB.deleteNode(nodeHandlerList);

		local tNodesMarkedForDeletion = {};
		for _,nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
			local nodeItemRef = DB.getChild(nodeEffect, 'itemref');
			if nodeItemRef then table.insert(tNodesMarkedForDeletion, nodeEffect) end
		end
		for _,nodeToBeDeleted in ipairs(tNodesMarkedForDeletion) do
			--DB.deleteNode(nodeToBeDeleted);
			EffectManager.removeEffect(nodeCT, nodeToBeDeleted);
		end
	end
end

function openSpeedWindow(nodeCT)
	local nodeWtWCT = DB.createChild(nodeWtWList, DB.getName(nodeCT));
	if not nodeWtWCT then return end

	if Session.IsHost then
		DB.setValue(nodeWtWCT, 'name', 'string', DB.getValue(nodeCT, 'name', ''));
	else
		if ActorManager.isPC(nodeCT) or DB.getValue(nodeCT, 'isidentified', 0) == 1 then
			DB.setValue(nodeWtWCT, 'name', 'string', DB.getValue(nodeCT, 'name', ''));
		else
			DB.setValue(nodeWtWCT, 'name', 'string', DB.getValue(nodeCT, 'nonid_name', ''));
		end
	end

	local wSpeed = Interface.findWindow('speed_window', nodeWtWCT);
	if wSpeed then
		wSpeed.bringToFront();
	else
		Interface.openWindow('speed_window', nodeWtWCT);
	end
end
function closeSpeedWindow(nodeCT)
	local sNodeName = DB.getName(nodeCT);
	if not sNodeName then return end
	local nodeWtWCT = DB.getChild(nodeWtWList, sNodeName);
	if not nodeWtWCT then return end

	local wSpeed = Interface.findWindow('speed_window', nodeWtWCT);
	if wSpeed then wSpeed.close() end
end

function turnStartChecks(nodeCT)
	--[[
	--if nodeUbiquinated then
	for _,nodeUbiquinated in pairs(tUbiquinatedNodes) do
		if type(nodeUbiquinated) == 'databasenode' then
			--EffectManager.expireEffect(nodeCT, nodeUbiquinated, 0);
			EffectManager.removeEffect(nodeCT, nodeUbiquinated)
		end
		--nodeUbiquinated = nil;
	end
	tUbiquinatedNodes = {};
	]]

	--[[
	if not EffectManagerBCE then
		for _,nodeCtTemp in ipairs(CombatManager.getAllCombatantNodes()) do
			local tDashFx = WtWCommon.hasEffectFindString(nodeCtTemp, '^Dash$', true, false, true, true);
			if tDashFx then
				for _,tEffect in ipairs(tDashFx) do
					if DB.getValue(tEffect['node'], 'duration', 1) == 1 then
						--EffectManager.expireEffect(nodeCT, tEffect['node'], 0);
						EffectManager.removeEffect(nodeCT, tEffect['node'])
					end
				end
			end
		end
	end
	]]

	local sOwner = WtWCommon.getControllingClient(nodeCT);
	if sOwner then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_SPEEDWINDOW;
		msgOOB.sCTNodeID = DB.getPath(nodeCT);
		Comm.deliverOOBMessage(msgOOB, sOwner);
	else
		if OptionsManager.isOption('AOSW', 'on') then openSpeedWindow(nodeCT) end
	end
end
function onTurnEndWtW(nodeCT, bForce, bSkipDash)
	local sOwner = WtWCommon.getControllingClient(nodeCT);
	if sOwner then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_CLOSESPEEDWINDOW;
		msgOOB.sCTNodeID = DB.getPath(nodeCT);
		if bForce then msgOOB.sForce = 'true' end
		Comm.deliverOOBMessage(msgOOB, sOwner);
	else
		if not bForce and OptionsManager.isOption('ACSW', 'on') then closeSpeedWindow(nodeCT) end
	end

	if bSkipDash then return end
	local nCount = 0;
	for _,nodeCTTemp in pairs(CombatManager.getAllCombatantNodes()) do
		if nCount > 1 then
			WtWCommon.removeEffectsByClause(nodeCTTemp, "Dash", { bIncludeGlobal = false });
		else
			WtWCommon.removeEffectsByClause(nodeCTTemp, "Dash", { bIncludeGlobal = true });
		end
		nCount = nCount + 1;
	end
end
function handleSpeedWindowClient(msgOOB)
	if OptionsManager.isOption('AOSW', 'on') then openSpeedWindow(msgOOB.sCTNodeID) end
end
function handleCloseSpeedWindow(msgOOB)
	if OptionsManager.isOption('ACSW', 'on') or msgOOB.sForce == 'true' then
		closeSpeedWindow(msgOOB.sCTNodeID);
	end
end

function handleSlash(_, sParams)
	if not Session.IsHost then return end

	local sUnitsClean = WtWCommon.tidyUnits(sParams);
	if not sUnitsClean then
		WtWCommon.reportError("Only three options are supported: ft, m, or tiles. Request additional options on the forum.", true, false);
		return;
	end

	DB.setValue(nodeWtW, 'effectUnits', 'string', sUnitsClean);
	reparseAllBaseSpeeds();
end

--[[
function roundMph(number, sUnitsPrefer)
	if number then tonumber(number) end
	if not number then
		WtWCommon.reportError("SpeedManager.roundMph - not number");
		return number;
	end
	if not sUnitsPrefer then sUnitsPrefer = 'ft.' end
	if sUnitsPrefer == 'ft.' then
		number = number / 2.5;
		number = WtWCommon.roundNumber(number);
		number = number * 2.5;
	elseif sUnitsPrefer == 'tiles' then
		number = number / 0.5;
		number = WtWCommon.roundNumber(number);
		number = number * 0.5;
	else
		if sUnitsPrefer == 'm' then
			number = number / 0.75;
			number = WtWCommon.roundNumber(number);
			number = number * 0.75;
		end
	end
	return number;
end
function roundNearestHalfTile(nSpeed, bUp, sUnits)
	if not sUnits then sUnits = DB.getValue(nodeWtW, 'effectUnits') end

	local nRoundFactor = WtWCommon.getConversionFactor(sUnits, 'tiles') * 2;
	local nSpeedRounded = nSpeed * nRoundFactor;
	if bUp then
		nSpeedRounded = math.ceil(nSpeedRounded);
	else
		nSpeedRounded = math.floor(nSpeedRounded);
	end
	return nSpeedRounded / nRoundFactor
end
]]

function convertAndRound(nSpeed, sUnitsCurrent, sUnitsPrefer)
	local nConvFactor = WtWCommon.getConversionFactor(sUnitsCurrent, sUnitsPrefer);
	return WtWCommon.roundNumber(nSpeed * nConvFactor, 0, 'down', getRoundingPref(sUnitsPrefer));
end

function getRoundingPref(sUnitsPrefer, nRSDefaultGridSize)
	local sSpeedRounding = OptionsManager.getOption('speed_rounding');
	if string.match(sSpeedRounding, 'grid$') then
		if not nRSDefaultGridSize then nRSDefaultGridSize = getRSDefaultGridSize() end
		if not sUnitsPrefer then sUnitsPrefer = OptionsManager.getOption('DDLU') end
		nRSDefaultGridSize = nRSDefaultGridSize * WtWCommon.getConversionFactor('ft.', sUnitsPrefer);
	end

	if sSpeedRounding == 'grid' then
		return nRSDefaultGridSize;
	elseif sSpeedRounding == 'hgrid' then
		return nRSDefaultGridSize / 2;
	elseif sSpeedRounding == 'whole' then
		return 1;
	elseif sSpeedRounding == 'tenth' then
		return 0.1;
	else
		return 5;
	end
end
function getRSDefaultGridSize()
	if WtWCommon.isSavageWorlds() then
		return 6;
	else
		return 5;
	end
end

function getEffectUnits()
	local sReturn = DB.getValue(nodeWtW, 'effectUnits');
	if not sReturn then sReturn = getDefaultEffectUnits(true) end
	return sReturn;
end
function getDefaultEffectUnits(bWrite)
	if WtWCommon.isSavageWorlds() then
		if bWrite then DB.setValue(nodeWtW, 'effectUnits', 'string', 'tiles') end
		return 'tiles';
	else
		if bWrite then DB.setValue(nodeWtW, 'effectUnits', 'string', 'ft.') end
		return 'ft.';
	end
end