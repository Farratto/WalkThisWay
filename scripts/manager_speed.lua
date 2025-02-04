-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals speedCalculator handleExhaustion setAllCharSheetSpeeds setCharSheetSpeed
-- luacheck: globals accommKnownExtsSpeed callSpeedCalcEffectUpdated openSpeedWindow getConversionFactor
-- luacheck: globals parseBaseSpeed onRecordTypeEventWtW reparseBaseSpeed reparseAllBaseSpeeds recalcAllSpeeds
-- luacheck: globals callSpeedCalcEffectDeleted setOptions updateDisplaySpeed handleSpeedWindowClient
-- luacheck: globals turnStartChecks registerPreference getPreference sendPrefRegistration handlePrefRegistration
-- luacheck: globals handlePrefChange checkFitness parseSpeedType onTabletopInit

OOB_MSGTYPE_SPEEDWINDOW = 'speedwindow';
OOB_MSGTYPE_REGPREF = 'regpreference';

local fonRecordTypeEvent = '';
local tClientPrefs = {};
local bLoopProt;
local nodeUbiquinated;

function onInit()
	setOptions();

	if Session.RulesetName == "5E" then
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_SPEEDWINDOW, handleSpeedWindowClient);
	end

	if Session.IsHost then
		if Session.RulesetName == "5E" then
			EffectManager.registerEffectCompType("SPEED", { bIgnoreTarget = true, bNoDUSE = true,
				bIgnoreOtherFilter = true, bIgnoreExpire = true
			});
				--known options: bIgnoreOtherFilter bIgnoreDisabledCheck bDamageFilter bConditionFilter bNoDUSE
				--continued: bSpell bOneShot bIgnoreExpire bIgnoreTarget
			DB.addHandler('combattracker.list.*.speed', 'onUpdate', reparseBaseSpeed);
			DB.addHandler('combattracker.list.*.effects.*.label', 'onUpdate', callSpeedCalcEffectUpdated);
			DB.addHandler('combattracker.list.*.effects.*.isactive', 'onUpdate', callSpeedCalcEffectUpdated);
			DB.addHandler('combattracker.list.*.effects','onChildDeleted', callSpeedCalcEffectDeleted);
			DB.addHandler('charsheet.*.speed.total','onUpdate', setCharSheetSpeed);
			DB.addHandler('charsheet.*.speed.base','onUpdate', setCharSheetSpeed);
			--DB.addHandler('charsheet.*.speed.special','onUpdate', reparseBaseSpeed);
			--DB.addHandler("charsheet.*.inventorylist.*.carried", "onUpdate", checkFitness);
			--DB.addHandler("combattracker.list.*.inventorylist.*.carried", "onUpdate", checkFitness);
			fonRecordTypeEvent = CombatRecordManager.onRecordTypeEvent;
			CombatRecordManager.onRecordTypeEvent = onRecordTypeEventWtW;
			OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_REGPREF, handlePrefRegistration);
		end
		CombatManager.setCustomTurnStart(turnStartChecks);
	else
		if Session.RulesetName == "5E" then
			local sPref = OptionsManager.getOption('DDLU');
			sendPrefRegistration(sPref);
		end
	end
end

function onTabletopInit()
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			reparseAllBaseSpeeds();
			setAllCharSheetSpeeds();
			recalcAllSpeeds();
		end
	end
end

function onClose()
	if Session.RulesetName == "5E" then
		if Session.IsHost then
			DB.removeHandler('combattracker.list.*.effects.*.label', 'onUpdate', callSpeedCalcEffectUpdated);
			DB.removeHandler('combattracker.list.*.effects.*.isactive', 'onUpdate', callSpeedCalcEffectUpdated);
			DB.removeHandler('combattracker.list.*.effects','onChildDeleted',callSpeedCalcEffectDeleted);
			DB.removeHandler('combattracker.list.*.speed', 'onUpdate', reparseBaseSpeed);
			DB.removeHandler('charsheet.*.speed.total','onUpdate', setCharSheetSpeed);
			DB.removeHandler('charsheet.*.speed.base','onUpdate', setCharSheetSpeed);
			--DB.removeHandler('charsheet.*.speed.special','onUpdate', reparseBaseSpeed);
			--DB.removeHandler("charsheet.*.inventorylist.*.carried", "onUpdate", checkFitness);
			--DB.removeHandler("combattracker.list.*.inventorylist.*.carried", "onUpdate", checkFitness);
			OptionsManager.unregisterCallback('DDCU', reparseAllBaseSpeeds);
			OptionsManager.unregisterCallback('WESC', recalcAllSpeeds);
			CombatRecordManager.onRecordTypeEvent = fonRecordTypeEvent;
		end
		OptionsManager.unregisterCallback('DDLU', handlePrefChange);
	end
end

function setOptions()
-- DEFAULT BEHAVIORS FOR OPTIONS: sType = "option_entry_cycler", on|off, default = off
--Farratto: Undocumented default option behaviors: bLocal = false, sGroupRes = "option_header_client"
	--Old 4th = ("option_label_" .. sKey)
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			OptionsManager.registerOptionData({	sKey = 'WESC', sGroupRes = 'option_header_WtW', tCustom = { default = "on" } });
			OptionsManager.registerOptionData({	sKey = 'DDCU', sGroupRes = "option_header_WtW",
				tCustom = { labelsres = "option_val_tiles|option_val_meters", values = "tiles|m",
					baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
				}
			});
			OptionsManager.registerOptionData({	sKey = 'ADEC', sGroupRes = "option_header_WtW" });
			OptionsManager.registerCallback('DDCU', reparseAllBaseSpeeds);
			OptionsManager.registerCallback('WESC', recalcAllSpeeds);
		end
	end
	OptionsManager.registerOptionData({	sKey = 'AOSW', bLocal = true });
	OptionsManager.registerOptionData({	sKey = 'DDLU', bLocal = true,
		tCustom = { labelsres = "option_val_tiles|option_val_meters", values = "tiles|m",
			baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
		}
	});

	if Session.RulesetName == "5E" then
		OptionsManager.registerCallback('DDLU', handlePrefChange);
	end
end

function onRecordTypeEventWtW(sRecordType, tCustom)
	fonRecordTypeEvent(sRecordType, tCustom);
	if Session.IsHost then
		parseBaseSpeed(tCustom.nodeCT, true);
	end
end

function callSpeedCalcEffectUpdated(nodeEffectChild)
	if bLoopProt then return end
	bLoopProt = true;
	if OptionsManager.isOption('WESC', 'off') then
		bLoopProt = false;
		return;
	end
	local nodeEffect = DB.getParent(nodeEffectChild);
	local nodeEffectLabel = DB.getChild(nodeEffect, 'label');
	local sNodeEffectLabel;
	if nodeEffectLabel then sNodeEffectLabel = DB.getValue(nodeEffect, 'label', '') end
	local nodeEffects = DB.getParent(nodeEffect);
	local nodeCT = DB.getParent(nodeEffects);
	if TurboManager then TurboManager.registerEffect(nodeEffect, nodeEffectLabel) end
	handleExhaustion(nodeCT, sNodeEffectLabel, nodeEffect);
	speedCalculator(nodeCT);
	bLoopProt = false;
end
function callSpeedCalcEffectDeleted(nodeEffects)
	if bLoopProt then return end
	bLoopProt = true;
	if OptionsManager.isOption('WESC', 'off') then
		return;
	end
	local nodeCT = DB.getParent(nodeEffects)
	handleExhaustion(nodeCT);
	speedCalculator(nodeCT);
	bLoopProt = false;
end

function getConversionFactor(sCurrentUnits, sDesiredUnits)
	if not sCurrentUnits or not sDesiredUnits then
		Debug.console('SpeedManager.getConversionFactor - not sCurrentUnits or not sDesiredUnits');
		return 1;
	end
	if sCurrentUnits == sDesiredUnits then return 1 end
	local nReturn;
	if sCurrentUnits == 'ft.' then
		if sDesiredUnits == 'm' then
			return 0.3;
		elseif sDesiredUnits == 'tiles' then
			return 0.2;
		elseif sDesiredUnits == 'ft.' then
			return 1;
		else
			Debug.console('SpeedManager.getConversionFactor - Invalid units.');
			return 1;
		end
	elseif sCurrentUnits == 'm' then
		if sDesiredUnits == 'ft.' then
			nReturn = 5 / 1.5;
			return nReturn;
		elseif sDesiredUnits == 'tiles' then
			nReturn = 1 / 1.5;
			return nReturn;
		elseif sDesiredUnits == 'm' then
			return 1;
		else
			Debug.console('SpeedManager.getConversionFactor - Invalid units.');
			return 1;
		end
	elseif sCurrentUnits == 'tiles' then
		if sDesiredUnits == 'ft.' then
			return 5;
		elseif sDesiredUnits == 'm' then
			return 1.5;
		elseif sDesiredUnits == 'tiles' then
			return 1;
		else
			Debug.console('SpeedManager.getConversionFactor - Invalid units.');
			return 1;
		end
	else
		Debug.console('SpeedManager.getConversionFactor - Invalid units.');
		return 1;
	end
end

function sendPrefRegistration(sPref, bRecalc)
	local sOwner = Session.UserName;
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_REGPREF;
	msgOOB.sPref = sPref;
	msgOOB.sOwner = sOwner;
	if bRecalc then
		msgOOB.nRecalc = '1'
	else
		msgOOB.nRecalc = '0'
	end
	Comm.deliverOOBMessage(msgOOB, sOwner);
end
function handlePrefRegistration(msgOOB)
	if not Session.IsHost then
		Debug.console("SpeedManager.handlePrefRegistration - not isHost");
		return;
	end
	registerPreference(msgOOB.sOwner, msgOOB.sPref);
	if msgOOB.nRecalc == '1' then
		recalcAllSpeeds();
	end
end

function handlePrefChange(sOptionKey)
	if Session.IsHost then
		recalcAllSpeeds();
	else
		local sPref = OptionsManager.getOption(sOptionKey);
		sendPrefRegistration(sPref, true);
	end
end
function registerPreference(sOwner, sPref)
	if not Session.IsHost then
		Debug.console("SpeedManager.registerPreference - not isHost");
		return;
	end
	if not sOwner then
		Debug.console("SpeedManager.registerPreference - not sOwner");
		return;
	end
	if not sPref then
		Debug.console("SpeedManager.registerPreference - not sPref");
		return;
	end
	for k,_ in pairs(tClientPrefs) do
		if k == sOwner then
			tClientPrefs[k] = sPref;
			return true;
		end
	end
	tClientPrefs[sOwner] = sPref;
	return true;
end

function getPreference(sOwner)
	if not Session.IsHost then
		Debug.console("SpeedManager.getPreference - not isHost");
		return;
	end
	if not sOwner then
		Debug.console("SpeedManager.getPreference - not sOwner");
		return;
	end
	for k,v in pairs(tClientPrefs) do
		if k == sOwner then
			return v;
		end
	end
	return false;
end

function recalcAllSpeeds()
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		speedCalculator(nodeCT);
	end
end

-- luacheck: push ignore 561
function speedCalculator(nodeCT, bCalledFromParse)
	if not nodeCT then
		Debug.console("SpeedManager.speedCalculator - not nodeCT");
		return;
	end
	if not Session.IsHost then
		Debug.console("SpeedManager.speedCalculator - not isHost");
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if not nodeFGSpeed then
		if bCalledFromParse then
			Debug.console("SpeedManager.speedCalculator - bCalledFromParse");
			return;
		else
			parseBaseSpeed(nodeCT, false);
		end
		nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
		if not nodeFGSpeed then
			Debug.console("SpeedManager.speedCalculator - not nodeFGSpeed");
			return;
		end
	end

	local nBaseSpeed;
	local tFGSpeedNew = {};
	for _,v in pairs(DB.getChildren(nodeCTWtW, 'FGSpeed')) do
		local tSpdRcrd = {};
		tSpdRcrd['velocity'] = DB.getValue(v, 'velocity');
		tSpdRcrd['type'] = DB.getValue(v, 'type');
		table.insert(tFGSpeedNew, tSpdRcrd);
		if tSpdRcrd['type'] == '' or string.lower(tSpdRcrd['type']) == 'walk' then
			nBaseSpeed = tSpdRcrd['velocity']
		end
	end
	nBaseSpeed = tonumber(nBaseSpeed);
	if not nBaseSpeed then
		Debug.console("SpeedManager.speedCalculator - not nBaseSpeed");
		nBaseSpeed = 30;
	end

	local sOwner = WtWCommon.getControllingClient(nodeCT);
	local sPref;
	if sOwner then
		sPref = getPreference(sOwner);
	else
		sPref = OptionsManager.getOption('DDLU');
	end

	local nHover = DB.getValue(nodeCTWtW, 'hover')
	local bHasRoot, bHasHover, sRootEffectName = WtWCommon.hasRoot(nodeCT);
	local tEffectNames = {};
	if sRootEffectName then table.insert(tEffectNames, sRootEffectName) end
	if bHasRoot then
		local tRoot = {};
		local tSpdRcrd = {};
		tSpdRcrd['velocity'] = '0';
		if nHover == 1 or bHasHover then
			tSpdRcrd['type'] = 'Walk (hover)';
		else
			tSpdRcrd['type'] = 'Walk';
		end
		table.insert(tRoot, tSpdRcrd);
		local bReturn = updateDisplaySpeed(nodeCT, tRoot, nBaseSpeed, false, sPref, tEffectNames, 0);
		return bReturn;
	end

	local rActor = ActorManager.resolveActor(nodeCT);
	if not rActor then
		Debug.console("SpeedManager.speedCalculator - not rActor");
		return;
	end
	local tSpeedEffects = {};
	local nHalved = 0;
	local tAccomSpeed = {};
	local bProne = false;
	if not OptionsManager.isOption('WESC', 'off') then
		tSpeedEffects = WtWCommon.getEffectsByTypeWtW(rActor, 'SPEED%s*:');
		tAccomSpeed = accommKnownExtsSpeed(nodeCT);
		bProne = WtWCommon.hasEffectClause(rActor, "^Prone$", nil, false, true)
		if bProne then
			nHalved = nHalved + 1
			table.insert(tEffectNames, "Prone");
		end
	end

	local nSpeedMod = 0;
	local nSpeedMax = nil;
	local nDash = 0;
	if tAccomSpeed then
		nDash = tAccomSpeed['nDash'];
		if tAccomSpeed['nSpeedMax'] then
			nSpeedMax = tonumber(tAccomSpeed['nSpeedMax']);
		end
		if tAccomSpeed['nSpeedMod'] then
			nSpeedMod = nSpeedMod + tonumber(tAccomSpeed['nSpeedMod']);
		end
		if tAccomSpeed['tEffectNames'] then
			for _,sEffectName in ipairs(tAccomSpeed['tEffectNames']) do
				table.insert(tEffectNames, sEffectName);
			end
		end
	end

	local nDoubled = 0;
	local bDifficult = false;
	local tRebase = {};
	local nRecheck;
	local sRecheckLabel;
	local tBannedTypes = {};
	local tModdedTypes = {};
	for _,v in ipairs(tSpeedEffects) do
		--WtW parsing
		local sRemainder;
		local bRecognizedRmndr = false;
		local sSpdMatch = string.match(v.original, '^[Ss][Pp][Ee][Ee][Dd]%s*:%s*');
		local sMinusSpeed = string.gsub(v.original, sSpdMatch, '');
		--local sVClauseLower = string.lower(v.original);
		--local sMinusSpeed = sVClauseLower:gsub('^speed%s-:%s*', '');
		local sMod = string.match(sMinusSpeed, '^%S+');
		local nMod = nil;
		if DiceManager.isDiceString(sMod) then
			nMod = tonumber(sMod);
			if not nMod then
				Debug.console("SpeedManager.speedCalculator - dice not currently supported. Please request this feature in the forums.");
			end
			sRemainder = sMinusSpeed:gsub('^' .. tostring(sMod) .. '%s*', '');
		else
			sRemainder = sMinusSpeed;
		end
		if not sRemainder and not nMod then
			Debug.console("SpeedManager.speedCalculator - Syntax Error 438");
		end
		local sRmndrLower = string.lower(sRemainder);

		--start matching
		if StringManager.startsWith(sRmndrLower, 'max') then
			bRecognizedRmndr = true;
			local nMaxMod;
			if string.match(sRmndrLower, '%)$') then
				local sRmndrRemainder = sRmndrLower:gsub('^max%s*%(', '');
				sRmndrRemainder = sRmndrRemainder:gsub('%s*%)$', '');
				local nRmndrRemainder = tonumber(sRmndrRemainder);
				if nRmndrRemainder then
					nMaxMod = nRmndrRemainder
					table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
				else
					Debug.console("SpeedManager.speedCalculator - Syntax Error. Try SPEED: max(5)");
				end
				if nMod then
					sRemainder = ''
					sRmndrLower = ''
				end
			else
				nMaxMod = nMod
				nMod = nil
				table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
			end
			if nSpeedMax then
				if nMaxMod < nSpeedMax then
					nSpeedMax = nMaxMod;
					table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
				end
			else
				nSpeedMax = nMaxMod;
				table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
			end
		end
		if sRmndrLower == "difficult" then
			bRecognizedRmndr = true;
			bDifficult = true;
			table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
		end
		if (sRmndrLower == "half" or sRmndrLower == "halved") then
			bRecognizedRmndr = true;
			nHalved = nHalved + 1;
			table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
		end
		if (sRmndrLower == "double" or sRmndrLower == "doubled") then
			bRecognizedRmndr = true;
			nDoubled = nDoubled + 1;
			table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
		end
		if not bProne and StringManager.startsWith(sRmndrLower, 'type') then
			bRecognizedRmndr = true;
			if not string.match(sRmndrLower, '%)$') then
				Debug.console("SpeedManager.speedCalculator - Syntax error. Try SPEED: type(fly)");
			else
				local sStrip = string.match(sRemainder, '^%s*[Tt][Yy][Pp][Ee]%s*%(%s*')
				sStrip = string.gsub(sStrip, '%(', '%%(');
				local sRmndrRemainder = sRemainder:gsub(sStrip, '');
				local sType = sRmndrRemainder:gsub('%s*%)$', '');
				local bRemoveType;
				if string.match(sType, '^%-') then
					bRemoveType = true;
					sType = string.sub(sType, 2)
				end
				local sTypeLower = string.lower(sType);
				local nFound, bExactMatch, sQualifier, sTypeFly, sTypeHover, sTypeSpider, bMatchSpider =
					parseSpeedType(sType, tFGSpeedNew, true);

				if nMod then
					if nMod <= 0 or string.sub(sMod, 1, 1) == '+' then
						if nFound then
							if sTypeFly or (sTypeSpider and bMatchSpider) then
								tFGSpeedNew[nFound]['mod'] = nMod;
								table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
							else
								if not sTypeHover and not sTypeSpider then
									tFGSpeedNew[nFound]['mod'] = nMod;
									table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
								end
							end
						else
							local rModdedType = {};
							rModdedType['type'] = sType;
							rModdedType['mod'] = nMod;
							rModdedType['name'] = WtWCommon.getEffectName(_,v.label);
							table.insert(tModdedTypes, rModdedType);
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
											table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
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
										table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
										table.insert(tEffectNames, WtWCommon.getEffectName(_,value.name));
									else
										if not sTypeHover and not sTypeSpider then
											nMod = nMod + value.mod;
											table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
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
									if bFaster then
										table.remove(tFGSpeedNew, nFound);
										table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
									end
									nFound = false;
								else
									if sTypeFly then
										if (nHover == 1) or sTypeHover then
											tFGSpeedNew[nFound]['type'] = 'Fly (hover)'
											table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
										end
									elseif sTypeSpider and not bMatchSpider then
										tFGSpeedNew[nFound]['type'] = 'Spider Climb'
										table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
									else
										nFound = false;
									end
								end
							end
							if nFound and bFaster then
								tFGSpeedNew[nFound]['velocity'] = nMod
								table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
							end
						end
						if not nFound and not bBanned then
							local tSpdRcrd = {};
							tSpdRcrd['type'] = sType;
							tSpdRcrd['velocity'] = nMod;
							table.insert(tFGSpeedNew, tSpdRcrd);
							table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
						end
					end
					nMod = nil;
				else
					if bRemoveType then
						if nFound then
							if sTypeHover and not sTypeFly then
								local sNewType = string.gsub(tFGSpeedNew[nFound]['type'], '%s*[Ff][Ll][Yy]%s*', '');
								tFGSpeedNew[nFound]['type'] = sNewType;
								table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
							elseif sTypeSpider and not bMatchSpider then --luacheck: ignore 542
								--do nothing;
							else
								table.remove(tFGSpeedNew, nFound);
								table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
							end
						else
							local rBannedType = {};
							rBannedType['type'] = sType;
							rBannedType['name'] = WtWCommon.getEffectName(_,v.label);
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
											table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
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
										table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
									else
										nRecheck = nFound;
										sRecheckLabel = WtWCommon.getEffectName(_,v.label);
									end
									nFound = false;
								else
									if sTypeFly then
										if (nHover == 1) or sTypeHover then
											tFGSpeedNew[nFound]['type'] = 'Fly (hover)'
											table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
										end
									elseif sTypeSpider and not bMatchSpider then
										tFGSpeedNew[nFound]['type'] = 'Spider Climb'
										table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
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
							table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
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
					Debug.console("SpeedManager.speedCalculator - Syntax Error 664");
				else
					local sRmndrRemainder = sRmndrLower:gsub('^inc%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					local nSpeedInc = tonumber(sRmndrRemainder);
					if not nSpeedInc then
						Debug.console("SpeedManager.speedCalculator - Syntax Error 670")
					else
						nSpeedMod = nSpeedMod + nSpeedInc;
						table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
					end
				end
			else
				if nMod then
					nSpeedMod = nSpeedMod + nMod;
					nMod = nil;
					table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
				end
			end
		end
		if StringManager.startsWith(sRmndrLower, 'dec') then
			bRecognizedRmndr = true;
			if string.match(sRmndrLower, '%)$') then
				if nMod then
					Debug.console("SpeedManager.speedCalculator - Syntax Error 684");
				else
					local sRmndrRemainder = sRmndrLower:gsub('^dec%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					local nSpeedInc = tonumber(sRmndrRemainder);
					if not nSpeedInc then
						Debug.console("SpeedManager.speedCalculator - Syntax Error 690")
					else
						nSpeedMod = nSpeedMod - nSpeedInc;
						table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
					end
				end
			else
				nSpeedMod = nSpeedMod - nMod;
				nMod = nil;
				table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
			end
		end
		if not bRecognizedRmndr and sRmndrLower ~= '' then
			Debug.console("SpeedManager.speedCalculator - Syntax Error - "..tostring(sRmndrLower)..
				" is not a recognized command.  Use inc, dec, max, doubled, halved, difficult, or type.  See the README or forum for more specifics about syntax."
			);
		else
			if nMod then
				local sNMod = tostring(nMod)
				if string.match(sNMod, '^%-') then
					nSpeedMod = nSpeedMod + nMod;
				else
					table.insert(tRebase, nMod)
				end
				table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
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

	if nDoubled > 0 then
		if nHalved > 0 then
			local nDoubledOrigin = nDoubled;
			local NHalvedOrigin = nHalved;
			nDoubled = nDoubled - NHalvedOrigin;
			nHalved = nHalved - nDoubledOrigin;
		end
	end

	local nHighest = 0;
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
				Debug.console("SpeedManager.speedCalculator - not nWalkSpeed.");
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
				local sTypeLower = string.lower(tSpdRcrd.type);
				local nDoubledLocal = nDoubled
				local nHalvedLocal = nHalved
				if (not string.match(sTypeLower, 'fly')) and (not string.match(sTypeLower, 'hover')) then
					if bDifficult then nHalvedLocal = nHalvedLocal + 1 end
				end
				while nDoubledLocal > 0 do
					nSpeedFinal = nSpeedFinal * 2;
					nDoubledLocal = nDoubledLocal - 1;
				end
				while nHalvedLocal > 0 do
					nSpeedFinal = nSpeedFinal / 2;
					nHalvedLocal = nHalvedLocal - 1;
				end
				if nSpeedMax then
					if nSpeedFinal > nSpeedMax then
						nSpeedFinal = nSpeedMax;
					end
				end
				local nSpdFnlFnl = nSpeedFinal;
				local nDashType = nDash;
				while nDashType > 0 do
					nSpdFnlFnl = nSpdFnlFnl + nSpeedFinal;
					nDashType = nDashType - 1;
				end
				tFGSpeedNew[k]['velocity'] = tostring(nSpdFnlFnl);
			end
		end
		local nVel = tonumber(tFGSpeedNew[k]['velocity']);
		if nVel and nVel > nHighest then nHighest = nVel end
	end

	local bReturn = updateDisplaySpeed(nodeCT, tFGSpeedNew, nBaseSpeed, bProne, sPref, tEffectNames, nHighest);
	return bReturn;
end
-- luacheck: pop

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

function updateDisplaySpeed(nodeCT, tFGSpeedNew, nBaseSpeed, bProne, sPref, tEffectNames, nHighest)
	if not Session.IsHost then
		Debug.console("SpeedManager.updateDisplaySpeed - not isHost");
		return;
	end
	if not nodeCT then
		Debug.console("SpeedManager.updateDisplaySpeed - not nodeCT");
		return;
	end
	if not tFGSpeedNew then
		Debug.console("SpeedManager.updateDisplaySpeed - not tFGSpeedNew");
		return;
	end
	if not nBaseSpeed then
		Debug.console("SpeedManager.updateDisplaySpeed - not nBaseSpeed");
		return;
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	if not sPref then
		sPref = OptionsManager.getOption('DDLU');
	end
	local sUnitsPrefer = sPref;
	local nConvFactor = 1;
	local sLngthUnits = DB.getValue(nodeCTWtW, 'units');
	if not sLngthUnits or sLngthUnits == '' then
		Debug.console("SpeedManager.updateDisplaySpeed - units not in DB");
		sLngthUnits = OptionsManager.getOption('DDCU');
	end
	if sLngthUnits ~= sUnitsPrefer then
		nConvFactor = getConversionFactor(sLngthUnits, sUnitsPrefer);
		if not nConvFactor then
			nConvFactor = 1;
		end
	end
	nBaseSpeed = nBaseSpeed * nConvFactor;
	local sReturn = '';
	local nBonusSpeed;
	local nCurrentSpeed = nBaseSpeed;
	for k,tSpdRcrd in ipairs(tFGSpeedNew) do
		tSpdRcrd.velocity = tSpdRcrd.velocity * nConvFactor
		if sUnitsPrefer == 'ft.' then
			tSpdRcrd.velocity = tSpdRcrd.velocity / 2.5;
			tSpdRcrd.velocity = math.floor(tSpdRcrd.velocity);
			tSpdRcrd.velocity = tSpdRcrd.velocity * 2.5;
		elseif sUnitsPrefer == 'tiles' then
			tSpdRcrd.velocity = tSpdRcrd.velocity / 0.5;
			tSpdRcrd.velocity = math.floor(tSpdRcrd.velocity);
			tSpdRcrd.velocity = tSpdRcrd.velocity * 0.5;
		else
			if sUnitsPrefer == 'm' then
				tSpdRcrd.velocity = tSpdRcrd.velocity / 0.75;
				tSpdRcrd.velocity = math.floor(tSpdRcrd.velocity);
				tSpdRcrd.velocity = tSpdRcrd.velocity * 0.75;
			end
		end

		local sVelWithUnits = tostring(tSpdRcrd.velocity) .. ' ' .. sUnitsPrefer

		if tSpdRcrd.type == '' or (string.match(tSpdRcrd.type, '^Walk')) then
			nCurrentSpeed = tSpdRcrd.velocity
			if bProne then
				sReturn = "Crawl " .. sVelWithUnits;
				break;
			end
			local sQualifier = string.match(tSpdRcrd.type, '%s*%(%s*%S*%s*%)%s*$');
			if sQualifier then
				if k == 1 then
					sReturn = sVelWithUnits .. ' ' .. sQualifier
				else
					sReturn = sVelWithUnits .. ' ' .. sQualifier .. ', ' .. sReturn
				end
			else
				if k == 1 then
					sReturn = sVelWithUnits
				else
					sReturn = sVelWithUnits .. ', ' .. sReturn
				end
			end
		else
			local sQualifier = string.match(tSpdRcrd.type, '%s*%(%s*%S*%s*%)%s*$');
			if sQualifier then
				local sTypeSansQual = string.gsub(tSpdRcrd.type, '%s*%(%s*%S*%s*%)%s*$', '');
				if k == 1 then
					sReturn = sTypeSansQual .. ' ' .. sVelWithUnits .. ' ' .. sQualifier
				else
					sReturn = sReturn .. ', ' .. sTypeSansQual .. ' ' .. sVelWithUnits .. ' ' .. sQualifier
				end
			else
				if k == 1 then
					sReturn = tSpdRcrd.type .. ' ' .. sVelWithUnits
				else
					sReturn = sReturn .. ', ' .. tSpdRcrd.type .. ' ' .. sVelWithUnits
				end
			end
		end
	end
	DB.setValue(nodeCTWtW, 'highest', 'number', nHighest * nConvFactor);
	sReturn = StringManager.strip(sReturn);
	if sReturn and sReturn ~= '' then
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', sReturn);
		local rActor = ActorManager.resolveActor(nodeCT);
		if not rActor then
			Debug.console("SpeedManager.updateDisplaySpeed - not rActor");
			return;
		end
		local nodeEffectNames = DB.getChild(nodeCTWtW, 'effectNames');
		if nodeEffectNames then
			DB.deleteChildren(nodeEffectNames);
		else
			nodeEffectNames = DB.createChild(nodeCTWtW, 'effectNames');
		end
		if tEffectNames then
			for _,sEffectName in ipairs(tEffectNames) do
				local nodeEffectNameID = DB.createChild(nodeEffectNames);
				DB.setValue(nodeEffectNameID, 'name', 'string', sEffectName);
			end
		end
		local nodeChar = ActorManager.getCreatureNode(rActor);
		local nodeCharWtW = DB.createChild(nodeChar, 'WalkThisWay');
		nBonusSpeed = nCurrentSpeed - nBaseSpeed
		DB.setValue(nodeCharWtW, 'bonus', 'number', nBonusSpeed);
		DB.setValue(nodeCharWtW, 'currentspeed', 'number', nCurrentSpeed);
		--if ActorManager.isPC(rActor) then
		--	DB.setValue(nodeCharWtW, 'base', 'number', nBaseSpeed);
		--end
		return true;
	else
		Debug.console("SpeedManager.updateDisplaySpeed - no sReturn");
		return false;
	end
end

function reparseAllBaseSpeeds()
	if not Session.IsHost then
		Debug.console("SpeedManager.reparseAllBaseSpeeds - not host");
		return;
	end
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		reparseBaseSpeed(false, nodeCT);
	end
end

function reparseBaseSpeed(nodeSpeed, nodeCT)
	if not Session.IsHost then
		Debug.console("SpeedManager.reparseBaseSpeed - not host");
		return;
	end

	if not nodeCT then
		if nodeSpeed then
			nodeCT = DB.getParent(nodeSpeed);
		else
			Debug.console("SpeedManager.reparseBaseSpeed - not nodeCT and not nodeSpeed");
			return;
		end
	end
	if not nodeCT then
		Debug.console("SpeedManager.reparseBaseSpeed - not nodeCT");
		return;
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeHover = DB.getChild(nodeCTWtW, 'hover');
	if nodeHover then DB.deleteNode(nodeHover) end
	local nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if nodeFGSpeed then DB.deleteNode(nodeFGSpeed) end
	parseBaseSpeed(nodeCT, true);
end

function parseBaseSpeed(nodeCT, bCalc)
	if not nodeCT or not Session.IsHost then
		Debug.printstack();
		Debug.console("SpeedManager.parseBaseSpeed - not nodeCT or not host");
		return;
	end

	local sFGSpeed = DB.getValue(nodeCT, 'speed', '0')
	local bNoBaseSpeed;
	if sFGSpeed == '0' then
		bNoBaseSpeed = true;
		--sFGSpeed = '30 ft.'
	end

	if ActorManager.isPC(nodeCT) then
		local nodeChar = ActorManager.getCreatureNode(nodeCT);
		local nodeSpeed = DB.getChild(nodeChar, 'speed');
		if bNoBaseSpeed then
			Debug.console("SpeedManager.setCharSheetSpeed - bNoBaseSpeed");
			local nodeCharWtW = DB.createChild(nodeChar, 'WalkThisWay');
			local nCharWtWSpeedBase = DB.getValue(nodeCharWtW, 'base', 0);
			if nCharWtWSpeedBase == 0 then setCharSheetSpeed(nil, nodeChar, nodeSpeed) end
			local nCharWtWSpeedBase = DB.getValue(nodeCharWtW, 'base', 0);
			if nCharWtWSpeedBase == 0 then
				Debug.console("SpeedManager.parseBaseSpeed - nCharWtWSpeedBase is still 0, defaulting to 30 ft");
				sFGSpeed = '30 ft.';
			end
		end
		local nodeFGSpeedSpecial = DB.getValue(nodeSpeed, 'special');
		if nodeFGSpeedSpecial and nodeFGSpeedSpecial ~= '' then
			sFGSpeed = sFGSpeed .. '; ' .. nodeFGSpeedSpecial;
		end
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	if not DB.getValue(nodeCTWtW, 'hover') then
		if string.match(string.lower(sFGSpeed), 'hover') then
			DB.setValue(nodeCTWtW, 'hover', 'number', 1);
		else
			DB.setValue(nodeCTWtW, 'hover', 'number', 0);
		end
	end

	--local bReturn;
	local nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if not nodeFGSpeed then
		nodeFGSpeed = DB.createChild(nodeCTWtW, 'FGSpeed');
		--local aSpdTypeSplit,_ = StringManager.split(sFGSpeed, ',;', true)
		local aSpdTypeSplit = StringManager.split(sFGSpeed, ',;', true)
		local sFinalUnits = '';
		local sLngthUnits = '';
		local sStripPattern = '';
		local sUnitsGave = OptionsManager.getOption('DDCU');
		for _,sSpdTypeSplit in ipairs(aSpdTypeSplit) do
			local nodeSpeedRcrd = DB.createChild(nodeFGSpeed);
			local sVelocity = string.match(sSpdTypeSplit, '%d+');
			local sRemainder = string.gsub(sSpdTypeSplit, '%d+', '', 1);
			local sType;
			local bConverted = false;
			local nConvFactor = 1;
			if sLngthUnits == '' then
				local aUnitsSplit,_ = StringManager.split(sSpdTypeSplit, '%s+', true)
				local bFound = false;
				for _,word in ipairs(aUnitsSplit) do
					if not bFound then
						if string.match(string.lower(word), '^ft%.?$') then
							bFound = true;
						elseif string.match(string.lower(word), '^m%.?$') then
							bFound = true;
						else
							if string.match(string.lower(word), '^tiles%.?$') then
								bFound = true;
							end
						end
						if bFound then sLngthUnits = word end
					end
				end
				if not bFound then sLngthUnits = sUnitsGave end
				sFinalUnits = sLngthUnits
				if string.lower(sFinalUnits) == 'ft' or string.lower(sFinalUnits) == 'ft.' then
					sFinalUnits = 'ft.';
				end
				if string.lower(sFinalUnits) == 'm.' or string.lower(sFinalUnits) == 'm' then
					sFinalUnits = 'm';
				end
				if string.lower(sFinalUnits) == 'tiles.' or string.lower(sFinalUnits) == 'tiles' then
					sFinalUnits = 'tiles';
				end
				if sFinalUnits ~= sUnitsGave then
					nConvFactor = getConversionFactor(sFinalUnits, sUnitsGave);
					sFinalUnits = sUnitsGave;
					bConverted = true;
				end
				if string.match(sLngthUnits, '%.') then
					sStripPattern = string.gsub(sLngthUnits, '%.', '');
					sStripPattern = sStripPattern .. '%.';
				end
				if sStripPattern == '' then sStripPattern = sLngthUnits end
			end
			sType,_ = string.gsub(sRemainder, sStripPattern, '');
			sType = StringManager.strip(sType);
			sType = StringManager.capitalize(sType);
			if sType == '' then sType = 'Walk' end
			if bConverted then
				local nVelocity = tonumber(sVelocity);
				if not nVelocity then
					Debug.console('SpeedManager.parseBaseSpeed - parsing failed: not nVelocity');
					break;
				end
				nVelocity = nVelocity * nConvFactor;
				sVelocity = tostring(nVelocity);
			end
			DB.setValue(nodeSpeedRcrd, 'velocity', 'number', sVelocity);
			DB.setValue(nodeSpeedRcrd, 'type', 'string', sType);
		end
		DB.setValue(nodeCTWtW, 'units', 'string', sFinalUnits);
		--bReturn = true;
	end
	if not DB.getValue(nodeCTWtW, 'currentSpeed') or bCalc then
		speedCalculator(nodeCT, true);
	end
	--return bReturn;
end

function setAllCharSheetSpeeds()
	if not Session.IsHost then
		Debug.console("SpeedManager.setAllCharSheetSpeeds - not host");
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
		Debug.console("SpeedManager.setCharSheetSpeed - not host or (not nodeUpdated and not nodeChar)");
		return;
	end

	if not nodeChar then
		if not nodeSpeed then nodeSpeed = DB.getParent(nodeUpdated) end
		nodeChar = DB.getParent(nodeSpeed);
	end
	if not nodeSpeed then nodeSpeed = DB.getChild(nodeChar, 'speed') end
	local nTotalSpeed = DB.getValue(nodeSpeed, 'total', 0);
	local nBaseSpeed;
	local nSpeedSet;

	if nTotalSpeed == 0 then
		nBaseSpeed = DB.getValue(nodeSpeed, 'base', 0);
		if nBaseSpeed == 0 then
			nSpeedSet = 30;
			Debug.console("SpeedManager.setCharSheetSpeed - nTotalSpeed and nBaseSpeed are 0");
		else
			nSpeedSet = nBaseSpeed;
		end
	else
		nSpeedSet = nTotalSpeed;
	end

	local nodeCharWtW = DB.createChild(nodeChar, 'WalkThisWay');
	local nBaseWtW = DB.getValue(nodeCharWtW, 'base', 0);
	if nBaseWtW == 0 or nBaseWtW ~= nSpeedSet then
		DB.setValue(nodeCharWtW, 'base', 'number', nSpeedSet);
	end
end

function accommKnownExtsSpeed(nodeCT)
	local nSpeedMod = 0;
	local tReturn = {};
	local tEffectNames = {};
	local bReturn = false;
	if Session.RulesetName == "5E" then
		local aDashFx = WtWCommon.getEffectsByTypeWtW(nodeCT, 'Dash$');
		tReturn['nDash'] = 0;
		for _,_ in ipairs(aDashFx) do
			tReturn['nDash'] = tReturn['nDash'] + 1
			bReturn = true;
			table.insert(tEffectNames, "Dash");
		end
		--encumbrance
		if WtWCommon.hasEffectClause(nodeCT, "^Exceeds Maximum Carrying Capacity$", nil, false, true) then
			tReturn['nSpeedMax'] = 5;
			bReturn = true;
			table.insert(tEffectNames, "Exceeds Maximum Carrying Capacity");
		end
		if WtWCommon.hasEffectClause(nodeCT, "^Heavily Encumbered$", nil, false, true) then
			nSpeedMod = nSpeedMod - 20;
			table.insert(tEffectNames, "Heavily Encumbered");
		else
			if WtWCommon.hasEffectClause(nodeCT, "^Lightly Encumbered$", nil, false, true) or
				WtWCommon.hasEffectClause(nodeCT, "^Encumbered$", nil, false, true
			) then
				nSpeedMod = nSpeedMod - 10;
				table.insert(tEffectNames, "Lightly Encumbered");
			end
		end
	end
	tReturn['tEffectNames'] = tEffectNames;

	if nSpeedMod ~= 0 then
		tReturn['nSpeedMod'] = nSpeedMod;
		bReturn = true;
	end

	if bReturn then
		return tReturn;
	else
		return;
	end
end

function handleExhaustion(nodeCT, nodeEffectLabel, nodeEffect)
	if not nodeCT then
		Debug.console("SpeedManager.handleExhaustion - not nodeCT");
		return;
	end
	if nodeEffectLabel then
		local sMatch = string.match(string.lower(nodeEffectLabel), '^%s*exhausted%s*;%s*');
		if sMatch then
			if string.match(nodeEffectLabel, "^Exhausted; Speed ") or string.match(
				nodeEffectLabel, "^Exhausted; DEATH$")
			then nodeUbiquinated = nodeEffect end
			return;
		end
	end

	local sNewEffect;
	local nSpeedAdjust;
	local nExhaustMod,_ = WtWCommon.getEffectsBonusLightly(nodeCT, { "EXHAUSTION" }, true);
	local bShowMsg = true;
	local bExhausted;
	if nExhaustMod > 5 then
		if OptionsManager.isOption('ADEC', 'on') then
			sNewEffect = "Exhausted; DEATH; DESTROY";
		else
			sNewEffect = "Exhausted; DEAD";
		end
	elseif nExhaustMod < 1 then
		bExhausted = false;
	elseif OptionsManager.isOption("GAVE", "2024") then
		nSpeedAdjust = nExhaustMod * 5;
		sNewEffect = "Exhausted; SPEED: dec(" .. nSpeedAdjust .. ")";
	elseif nExhaustMod > 4 then
		sNewEffect = "Exhausted; SPEED: max(0); MAXHP: 0.5";
	elseif nExhaustMod > 3 then
		sNewEffect = "Exhausted; SPEED: halved; MAXHP: 0.5";
	elseif nExhaustMod > 1 then
		sNewEffect = "Exhausted; SPEED: halved";
	else
		bExhausted = false;
	end

	local tOldEffects = WtWCommon.hasEffectFindString(nodeCT, '^%s*exhausted%s*;%s*', true, false, false, true);
	if bExhausted == false and tOldEffects and tOldEffects[1] then
		for _,v in ipairs(tOldEffects) do
			DB.deleteNode(v['node']);
		end
	end

	if sNewEffect then
		if tOldEffects and tOldEffects[1] then
			local nFound;
			for k,v in ipairs(tOldEffects) do
				if v['label'] == sNewEffect then nFound = k end
			end
			if nFound then
				for k,v in ipairs(tOldEffects) do
					if k ~= nFound then DB.deleteNode(v['node']) end
				end
			else
				for k,v in ipairs(tOldEffects) do
					if k > 1 then
						DB.deleteNode(v['node']);
					else
						DB.setValue(tOldEffects[1]['node'], 'label', 'string', sNewEffect);
					end
				end
			end
		else
			EffectManager.addEffect("", "", nodeCT, { sName = sNewEffect }, bShowMsg);
		end
	end
end

--forPay extension currently does this by teamTwoey (author: MatteKure)
--https://forge.fantasygrounds.com/shop/items/1606/view
--function handleEncumbrance(nodeCT)
	--charsheet.id-00000.encumbrance
		--holder = "Farratto"
		--load = current carried weight in a number
		--max = max carried weight in a number
	--combattracker.list.id-00000.encumbrance
		--SAA
	--variant encumbrance rules:
		--encumbered condition: -10 speed
		--heavily encumbered: -20 speed
	--standard encumbrance rules:
		--excedes carrying capacity
			--SPEED: <= 5 ft.
--end

function checkFitness()
	--make option to turn this functionality off to save resources
	--called by updated inventory
	--root.charsheet.id-00002.inventorylist.id-00001
		--carried = 2 --means equipped
		--<strength type="string">Str 13</strength>
	--root.combattracker.list.id-00003.inventorylist.id-00001
		--carried = 2 --means equipped
		--<strength type="string">Str 13</strength>
	--in traits, speed: your speed is not reduced by wearing heavy armor.
		--2024 dwarf
	--check if item has str requirement, return if no
	--add handler to watch str
	--add handler to DB to remove onClose
	--add buff that is like ITEM too heavy, make sure check for identified tag
end

function openSpeedWindow(nodeCT)
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	if Session.IsHost then DB.setPublic(nodeCTWtW, true) end
	local rActor = ActorManager.resolveActor(nodeCT);
	DB.setValue(nodeCTWtW, 'name', 'string', tostring(rActor.sName));
	local sCurrentSpeed = DB.getValue(nodeCTWtW, 'currentSpeed');
	if not sCurrentSpeed then
		local nFGSpeed = DB.getValue(nodeCT, 'speed');
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nFGSpeed));
	end

	local wSpeed = Interface.findWindow('speed_window', nodeCTWtW);
	if wSpeed then
		wSpeed.bringToFront();
	else
		Interface.openWindow('speed_window', nodeCTWtW);
	end
end

function turnStartChecks(nodeCT)
	local sOwner = WtWCommon.getControllingClient(nodeCT);

	if Session.RulesetName == "5E" then
		if nodeUbiquinated then
			DB.deleteNode(nodeUbiquinated);
			nodeUbiquinated = nil;
		end
		if sOwner then
			local msgOOB = {};
			msgOOB.type = OOB_MSGTYPE_SPEEDWINDOW;
			msgOOB.sCTNodeID = DB.getPath(nodeCT);
			Comm.deliverOOBMessage(msgOOB, sOwner);
		else
			if OptionsManager.isOption('AOSW', 'on') then
				openSpeedWindow(nodeCT);
			end
		end
	end
end

function handleSpeedWindowClient(msgOOB)
	if OptionsManager.isOption('AOSW', 'on') then
		openSpeedWindow(msgOOB.sCTNodeID);
	end
end