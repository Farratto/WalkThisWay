-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals clientGetOption checkProne checkHideousLaughter speedCalculator setPQvalue
-- luacheck: globals closeAllProneWindows openProneWindow closeProneWindow standUp delWTWdataChild
-- luacheck: globals queryClient sendCloseWindowCmd handleProneQueryClient handleCloseProneQuery hasRoot
-- luacheck: globals accommKnownExtsSpeed callSpeedCalcEffectUpdated openSpeedWindow getConversionFactor
-- luacheck: globals parseBaseSpeed onRecordTypeEventWtW reparseBaseSpeed reparseAllBaseSpeeds recalcAllSpeeds
-- luacheck: globals callSpeedCalcEffectDeleted setOptions updateDisplaySpeed handleSpeedWindowClient
-- luacheck: globals turnStartChecks registerPreference getPreference sendPrefRegistration handlePrefRegistration
-- luacheck: globals handlePrefChange checkFitness parseSpeedType

OOB_MSGTYPE_PRONEQUERY = "pronequery";
OOB_MSGTYPE_CLOSEQUERY = "closequery";
OOB_MSGTYPE_SPEEDWINDOW = 'speedwindow';
OOB_MSGTYPE_REGPREF = 'registerpreference';

local fonRecordTypeEvent = '';
local tClientPrefs = {};
local bLoopProt;
local nodeUbiquinated;

function onInit()
	setOptions();

	if Session.RulesetName == "5E" then
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_SPEEDWINDOW, handleSpeedWindowClient);
	end
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRONEQUERY, handleProneQueryClient);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSEQUERY, handleCloseProneQuery);

	if Session.IsHost then
		if Session.RulesetName == "5E" then
			EffectManager.registerEffectCompType("SPEED", { bIgnoreTarget = true, bNoDUSE = true,
				bIgnoreOtherFilter = true, bIgnoreExpire = true
			});
				--known options: bIgnoreOtherFilter bIgnoreDisabledCheck bDamageFilter bConditionFilter bNoDUSE bIgnoreTarget
				--continued: bSpell bOneShot bIgnoreExpire
			DB.addHandler('combattracker.list.*.speed', 'onUpdate', reparseBaseSpeed);
			DB.addHandler('combattracker.list.*.effects.*.label', 'onUpdate', callSpeedCalcEffectUpdated);
			DB.addHandler('combattracker.list.*.effects','onChildDeleted', callSpeedCalcEffectDeleted);
			--DB.addHandler("charsheet.*.inventorylist.*.carried", "onUpdate", checkFitness);
			--DB.addHandler("combattracker.list.*.inventorylist.*.carried", "onUpdate", checkFitness);
			fonRecordTypeEvent = CombatRecordManager.onRecordTypeEvent; --luacheck: ignore 111
			CombatRecordManager.onRecordTypeEvent = onRecordTypeEventWtW;
			if string.lower(Session.UserName) == 'farratto' then
				local nodeWTW = DB.createNode('WalkThisWay');
				DB.setPublic(nodeWTW, true);
				local nodeFrogToes = DB.getChild(nodeWTW, 'frogtoes');
				if not nodeFrogToes then
					DB.createChild(nodeWTW, 'frogtoes', 'number');
				end
				DB.setValue(nodeWTW, 'frogtoes', 'number', '1');
			end
			OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_REGPREF, handlePrefRegistration);
		end
		CombatManager.setCustomTurnStart(turnStartChecks);
		CombatManager.setCustomTurnEnd(closeAllProneWindows);
		reparseAllBaseSpeeds();
	else
		if Session.RulesetName == "5E" then
			local sPref = OptionsManager.getOption('DDLU');
			sendPrefRegistration(sPref);
		end
	end
end

function onClose()
	if Session.RulesetName == "5E" then
		if Session.IsHost then
			DB.removeHandler('combattracker.list.*.effects.*.label', 'onUpdate', callSpeedCalcEffectUpdated);
			DB.removeHandler('combattracker.list.*.effects','onChildDeleted',callSpeedCalcEffectDeleted);
			DB.removeHandler('combattracker.list.*.speed', 'onUpdate', reparseBaseSpeed);
			--DB.removeHandler("charsheet.*.inventorylist.*.carried", "onUpdate", checkFitness);
			--DB.removeHandler("combattracker.list.*.inventorylist.*.carried", "onUpdate", checkFitness);
			OptionsManager.unregisterCallback('DDCU', reparseAllBaseSpeeds);
			OptionsManager.unregisterCallback('WESC', recalcAllSpeeds);
			CombatRecordManager.onRecordTypeEvent = fonRecordTypeEvent; --luacheck: ignore 113
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
			OptionsManager.registerOption2('WTWON', false, 'option_header_WtW', 'option_WtW_On',
										'option_entry_cycler', {
				labels = 'option_val_off',
				values = 'off',
				baselabel = 'option_val_on',
				baseval = 'on',
				default = 'on'
			});
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
		OptionsManager.registerOption2('APCW', false, 'option_header_WtW', 'option_WtW_Allow_Player_Choice', 'option_entry_cycler', {
			labels = 'option_val_on',
			values = 'on',
			baselabel = 'option_val_off',
			baseval = 'off',
			default = 'off'
		});
	end
	OptionsManager.registerOptionData({	sKey = 'AOSW', bLocal = true });
	OptionsManager.registerOptionData({	sKey = 'DDLU', bLocal = true,
		tCustom = { labelsres = "option_val_tiles|option_val_meters", values = "tiles|m",
			baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
		}
	});
	if clientGetOption('APCW') == "on" then
		OptionsManager.registerOption2('WTWONPLR', true, "option_header_client", 'option_WtW_On_Player_Choice',
									   'option_entry_cycler', {
			labels = 'option_val_off',
			values = 'off',
			baselabel = 'option_val_on',
			baseval = 'on',
			default = 'on'
		});
	else
		OptionsManager.registerOption2('WTWONDM', false, "option_header_WtW", 'option_WtW_On_DM_Choice',
									   'option_entry_cycler', {
			labels = 'option_val_off',
			values = 'off',
			baselabel = 'option_val_on',
			baseval = 'on',
			default = 'on'
		});
	end

	if Session.RulesetName == "5E" then
		OptionsManager.registerCallback('DDLU', handlePrefChange);
	end
end

function onRecordTypeEventWtW(sRecordType, tCustom)
	fonRecordTypeEvent(sRecordType, tCustom); --luacheck: ignore 212 113
	if Session.IsHost then
		parseBaseSpeed(tCustom.nodeCT, true);
	end
end

function callSpeedCalcEffectUpdated(nodeEffectLabel)
	if bLoopProt then return end
	bLoopProt = true;
	if OptionsManager.isOption('WESC', 'off') then
		return;
	end
	local sNodeEffectLabel = DB.getValue(nodeEffectLabel);
	local nodeEffect = DB.getParent(nodeEffectLabel);
	local nodeCT = DB.getChild(nodeEffect, '...');
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

function clientGetOption(sKey)
	if CampaignRegistry["Opt" .. sKey] then
		return CampaignRegistry["Opt" .. sKey];
	end
end

function getConversionFactor(sCurrentUnits, sDesiredUnits)
	if not sCurrentUnits or not sDesiredUnits or sCurrentUnits == sDesiredUnits then
		Debug.console('WalkThisWay.getConversionFactor - Internal Syntax error.');
		return 1;
	end
	local nReturn;
	if sCurrentUnits == 'ft.' then
		if sDesiredUnits == 'm' then
			return 0.3;
		elseif sDesiredUnits == 'tiles' then
			return 0.2;
		elseif sDesiredUnits == 'ft.' then
			return 1;
		else
			Debug.console('WalkThisWay.getConversionFactor - Invalid units.');
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
			Debug.console('WalkThisWay.getConversionFactor - Invalid units.');
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
			Debug.console('WalkThisWay.getConversionFactor - Invalid units.');
			return 1;
		end
	else
		Debug.console('WalkThisWay.getConversionFactor - Invalid units.');
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
		Debug.console("WalkThisWay.handlePrefRegistration - not isHost");
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
		Debug.console("WalkThisWay.registerPreference - not isHost");
		return;
	end
	if not sOwner then
		Debug.console("WalkThisWay.registerPreference - not sOwner");
		return;
	end
	if not sPref then
		Debug.console("WalkThisWay.registerPreference - not sPref");
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
		Debug.console("WalkThisWay.getPreference - not isHost");
		return;
	end
	if not sOwner then
		Debug.console("WalkThisWay.getPreference - not sOwner");
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
		Debug.console("WalkThisWay.speedCalculator - not nodeCT");
		return;
	end
	if not Session.IsHost then
		Debug.console("WalkThisWay.speedCalculator - not isHost");
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	--DB.setPublic(nodeCTWtW, true);
	local nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if not nodeFGSpeed then
		if bCalledFromParse then
			Debug.console("WalkThisWay.speedCalculator - Parsing base speed failed.");
			return;
		else
			parseBaseSpeed(nodeCT, false);
		end
		nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
		if not nodeFGSpeed then
			Debug.console("WalkThisWay.speedCalculator - Parsing base speed failed.");
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
		Debug.console("WalkThisWay.speedCalculator - not nBaseSpeed");
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
	local bHasRoot, bHasHover, sRootEffectName = hasRoot(nodeCT);
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
		local bReturn = updateDisplaySpeed(nodeCT, tRoot, nBaseSpeed, false, sPref, tEffectNames);
		return bReturn;
	end

	local rActor = ActorManager.resolveActor(nodeCT);
	if not rActor then
		Debug.console("WalkThisWay.speedCalculator - not rActor");
		return;
	end
	local tSpeedEffects = {};
	local nHalved = 0;
	local tAccomSpeed = {};
	local bProne = false;
	if not OptionsManager.isOption('WESC', 'off') then
		tSpeedEffects = WtWCommon.getEffectsByTypeWtW(rActor, 'SPEED%s*:');
		tAccomSpeed = accommKnownExtsSpeed(nodeCT);
		bProne = WtWCommon.fhasCondition(rActor, "Prone")
		if bProne then
			nHalved = nHalved + 1
			table.insert(tEffectNames, "Prone");
		end
	end

	local nSpeedMod = 0;
	local nSpeedMax = nil;
	local nDoubled = 0;
	if tAccomSpeed then
		if tAccomSpeed['nDoubled'] then
			nDoubled = nDoubled + tonumber(tAccomSpeed['nDoubled'])
		end
		if tAccomSpeed['nHalved'] then
			nHalved = nHalved + tonumber(tAccomSpeed['nHalved'])
		end
		if tAccomSpeed['nSpeedMax'] then
			nSpeedMax = tonumber(tAccomSpeed['nSpeedMax'])
		end
		if tAccomSpeed['nSpeedMod'] then
			nSpeedMod = nSpeedMod + tonumber(tAccomSpeed['nSpeedMod'])
		end
		if tAccomSpeed['tEffectNames'] then
			for _,sEffectName in ipairs(tAccomSpeed['tEffectNames']) do
				table.insert(tEffectNames, sEffectName);
			end
		end
	end

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
		local sSpdMatch = string.match(v.clause, '^[Ss][Pp][Ee][Ee][Dd]%s*:%s*');
		local sMinusSpeed = string.gsub(v.clause, sSpdMatch, '');
		--local sVClauseLower = string.lower(v.clause);
		--local sMinusSpeed = sVClauseLower:gsub('^speed%s-:%s*', '');
		local sMod = string.match(sMinusSpeed, '^%S+');
		local nMod = nil;
		if DiceManager.isDiceString(sMod) then
			nMod = tonumber(sMod);
			if not nMod then
				Debug.console("WalkThisWay.speedCalculator - dice not currently supported. Please request this feature in the forums.");
			end
			sRemainder = sMinusSpeed:gsub('^' .. tostring(sMod) .. '%s*', '');
		else
			sRemainder = sMinusSpeed;
		end
		if not sRemainder and not nMod then
			Debug.console("WalkThisWay.speedCalculator - Syntax Error 438");
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
					Debug.console("WalkThisWay.speedCalculator - Syntax Error. Try SPEED: max(5)");
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
				Debug.console("WalkThisWay.speedCalculator - Syntax error. Try SPEED: type(fly)");
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
							if nBaseSpeed >= nCurrentVel then bFaster = true end
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
					Debug.console("WalkThisWay.speedCalculator - Syntax Error 664");
				else
					local sRmndrRemainder = sRmndrLower:gsub('^inc%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					local nSpeedInc = tonumber(sRmndrRemainder);
					if not nSpeedInc then
						Debug.console("WalkThisWay.speedCalculator - Syntax Error 670")
					else
						nSpeedMod = nSpeedMod + nSpeedInc;
						table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
					end
				end
			else
				nSpeedMod = nSpeedMod + nMod;
				nMod = nil;
				table.insert(tEffectNames, WtWCommon.getEffectName(_,v.label));
			end
		end
		if StringManager.startsWith(sRmndrLower, 'dec') then
			bRecognizedRmndr = true;
			if string.match(sRmndrLower, '%)$') then
				if nMod then
					Debug.console("WalkThisWay.speedCalculator - Syntax Error 684");
				else
					local sRmndrRemainder = sRmndrLower:gsub('^dec%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					local nSpeedInc = tonumber(sRmndrRemainder);
					if not nSpeedInc then
						Debug.console("WalkThisWay.speedCalculator - Syntax Error 690")
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
			Debug.console("WalkThisWay.speedCalculator - Syntax Error 701")
		end
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

	for k,tSpdRcrd in ipairs(tFGSpeedNew) do
		local nFGSpeed = tSpdRcrd['velocity'];
		local nFGSpeedNew = nFGSpeed;
		local bFound;
		if not nFGSpeedNew then
			for _,v in ipairs(tFGSpeedNew) do
				if v.type == 'walk' or v.type == '' then
					nFGSpeedNew = v.velocity;
					nFGSpeedNew = tonumber(nFGSpeedNew);
					bFound = true;
				else
					if not nFGSpeedNew and bFound then
						nFGSpeedNew = v.velocity;
						nFGSpeedNew = tonumber(nFGSpeedNew);
						bFound = true;
					end
				end
			end
			if not nFGSpeedNew then nFGSpeedNew = tFGSpeedNew[1].velocity end
			nFGSpeedNew = tonumber(nFGSpeedNew);
			if not nFGSpeedNew then nFGSpeedNew = 30 end
		end
		if nRebase and nRebase > nFGSpeedNew then nFGSpeedNew = nRebase end

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
			tFGSpeedNew[k]['velocity'] = tostring(nSpeedFinal);
		end
	end

	local bReturn = updateDisplaySpeed(nodeCT, tFGSpeedNew, nBaseSpeed, bProne, sPref, tEffectNames);
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

function updateDisplaySpeed(nodeCT, tFGSpeedNew, nBaseSpeed, bProne, sPref, tEffectNames)
	if not Session.IsHost then
		Debug.console("WalkThisWay.updateDisplaySpeed - not isHost");
		return;
	end
	if not nodeCT then
		Debug.console("WalkThisWay.updateDisplaySpeed - not nodeCT");
		return;
	end
	if not tFGSpeedNew then
		Debug.console("WalkThisWay.updateDisplaySpeed - not tFGSpeedNew");
		return;
	end
	if not nBaseSpeed then
		Debug.console("WalkThisWay.updateDisplaySpeed - not nBaseSpeed");
		return;
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	--if Session.IsHost then DB.setPublic(nodeCTWtW, true) end
	if not sPref then
		sPref = OptionsManager.getOption('DDLU');
	end
	local sUnitsPrefer = sPref;
	local nConvFactor = 1;
	local sLngthUnits = DB.getValue(nodeCTWtW, 'units');
	if not sLngthUnits or sLngthUnits == '' then
		Debug.console("WalkThisWay.updateDisplaySpeed - units not in DB");
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

		--if bProne then
		--	sReturn = sVelWithUnits .. ' Crawl'
		--else
			if tSpdRcrd.type == '' or (string.match(tSpdRcrd.type, '^Walk')) then
				nCurrentSpeed = tSpdRcrd.velocity
				if bProne then
					sReturn = sVelWithUnits .. ' Crawl'
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
		--end
	end
	sReturn = StringManager.strip(sReturn);
	if sReturn and sReturn ~= '' then
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', sReturn);
		local rActor = ActorManager.resolveActor(nodeCT);
		if not rActor then
			Debug.console("WalkThisWay.updateDisplaySpeed - not rActor");
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
		if ActorManager.isPC(rActor) then
			local nodeChar = ActorManager.getCreatureNode(rActor);
			local nodeCharWtW = DB.createChild(nodeChar, 'WalkThisWay');
			--if Session.IsHost then DB.setPublic(nodeCharWtW, true) end
			nBonusSpeed = nCurrentSpeed - nBaseSpeed
			DB.setValue(nodeCharWtW, 'bonus', 'number', nBonusSpeed);
			DB.setValue(nodeCharWtW, 'base', 'number', nBaseSpeed);
			DB.setValue(nodeCharWtW, 'currentspeed', 'number', nCurrentSpeed);
			--local nodeCharMNM = DB.getChild(nodeChar, "MNMCharacterSheetEffectsDisplay");
			--if nodeCharMNM then
			--	DB.setValue(nodeCharMNM, 'BONUSSPEED', 'number', nBonusSpeed);
			--end
		end
		return true;
	else
		Debug.console("WalkThisWay.updateDisplaySpeed - no sReturn");
		return false;
	end
end

function reparseAllBaseSpeeds()
	if not Session.IsHost then
		Debug.console("WalkThisWay.reparseAllBaseSpeeds - not host");
		return;
	end
	for _,nodeCT in ipairs(CombatManager.getAllCombatantNodes()) do
		reparseBaseSpeed(false, nodeCT);
	end
end

function reparseBaseSpeed(nodeSpeed, nodeCT)
	if not Session.IsHost then
		Debug.console("WalkThisWay.reparseBaseSpeed - not host");
		return;
	end

	if not nodeCT then
		if nodeSpeed then
			nodeCT = DB.getParent(nodeSpeed);
		else
			Debug.console("WalkThisWay.reparseBaseSpeed - not nodeCT and not nodeSpeed");
			return;
		end
	end
	if not nodeCT then
		Debug.console("WalkThisWay.reparseBaseSpeed - not nodeCT");
		return;
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	--DB.setPublic(nodeCTWtW, true);
	local nodeHover = DB.getChild(nodeCTWtW, 'hover');
	if nodeHover then DB.deleteNode(nodeHover) end
	local nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if nodeFGSpeed then DB.deleteNode(nodeFGSpeed) end
	parseBaseSpeed(nodeCT, true);
end

function parseBaseSpeed(nodeCT, bCalc)
	if not nodeCT then
		Debug.console("WalkThisWay.parseBaseSpeed - not nodeCT");
		return;
	end
	if not Session.IsHost then
		Debug.console("WalkThisWay.parseBaseSpeed - not host");
		return;
	end

	local sFGSpeed = DB.getValue(nodeCT, 'speed')
	if not sFGSpeed then
		Debug.console("WalkThisWay.parseBaseSpeed - no base speed found");
		sFGSpeed = '30 ft.'
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	--DB.setPublic(nodeCTWtW, true);
	if not DB.getValue(nodeCTWtW, 'hover') then
		if string.match(string.lower(sFGSpeed), 'hover') then
			DB.setValue(nodeCTWtW, 'hover', 'number', 1);
		else
			DB.setValue(nodeCTWtW, 'hover', 'number', 0);
		end
	end

	local bReturn;
	local nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if not nodeFGSpeed then
		nodeFGSpeed = DB.createChild(nodeCTWtW, 'FGSpeed');
		local aSpdTypeSplit,_ = StringManager.split(sFGSpeed, ',;', true)
		local sFinalUnits = '';
		local sLngthUnits = '';
		local sStripPattern = '';
		local sUnitsGave = OptionsManager.getOption('DDCU');
		for _,sSpdTypeSplit in ipairs(aSpdTypeSplit) do
			local nodeSpeedRcrd = DB.createChild(nodeFGSpeed);
			local sVelocity = string.match(sSpdTypeSplit, '%d+');
			local sRemainder = string.gsub(sSpdTypeSplit, '%d+', '');
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
				local nVelocity = tonumber(sVelocity)
				if not nVelocity then
					Debug.console('WalkThisWay.parseBaseSpeed - parsing failed: not nVelocity');
					break;
				end
				nVelocity = nVelocity * nConvFactor;
				sVelocity = tostring(nVelocity);
			end
			DB.setValue(nodeSpeedRcrd, 'velocity', 'number', sVelocity);
			DB.setValue(nodeSpeedRcrd, 'type', 'string', sType);
		end
		DB.setValue(nodeCTWtW, 'units', 'string', sFinalUnits);
		bReturn = true;
	end
	if not DB.getValue(nodeCTWtW, 'currentSpeed') or bCalc then
		speedCalculator(nodeCT, true);
	end
	return bReturn;
end

function accommKnownExtsSpeed(nodeCT)
	local nDoubled = 0;
	local nHalved = 0;
	local nSpeedMax;
	local nSpeedMod = 0;
	local tReturn = {};
	local tEffectNames = {};
	if Session.RulesetName == "5E" then
		if EffectManager5E.hasEffectCondition(nodeCT, 'Dash') then
			nDoubled = nDoubled + 1
			table.insert(tEffectNames, "Dash");
		end
		--encumbrance
		if EffectManager5E.hasEffect(nodeCT, "Exceeds Maximum Carrying Capacity") then
			nSpeedMax = 5;
			table.insert(tEffectNames, "Exceeds Maximum Carrying Capacity");
		end
		if EffectManager5E.hasEffect(nodeCT, "Heavily Encumbered") then
			nSpeedMod = nSpeedMod - 20;
			table.insert(tEffectNames, "Heavily Encumbered");
		else
			if EffectManager5E.hasEffect(nodeCT, "Lightly Encumbered") or EffectManager5E.hasEffect(nodeCT, "Encumbered") then
				nSpeedMod = nSpeedMod - 10;
				table.insert(tEffectNames, "Lightly Encumbered");
			end
		end
		--exhaustion (speed 0 & DEATH checks are in hasRoot)
		--no longer need because Im replacing these now
		--if WtWCommon.hasEffectFindString(nodeCT, "^Exhausted; Speed Halved", false) then
		--	nHalved = nHalved + 1;
		--	table.insert(tEffectNames, "Exhaustion");
		--end
		--local sExhaustStack = WtWCommon.hasEffectFindString(nodeCT, "^Exhausted; Speed %-%d+ %(info only%)$", false, true);
		--if sExhaustStack then
		--	local sExhaustStack = sExhaustStack:gsub('^Exhausted; Speed %-', '');
		--	local sExhaustStack = sExhaustStack:gsub('%s*%(%s*info only%s*%)$', '');
		--	local nExhaustSpd = tonumber(sExhaustStack);
		--	if nExhaustSpd then
		--		nSpeedMod = nSpeedMod - nExhaustSpd;
		--		table.insert(tEffectNames, "Exhaustion");
		--	end
		--end
	end
	tReturn['tEffectNames'] = tEffectNames;

	local bReturn = false
	if nDoubled > 0 then
		if nHalved > 0 then
			local nDoubledOrigin = nDoubled;
			local NHalvedOrigin = nHalved;
			nDoubled = nDoubled - NHalvedOrigin;
			nHalved = nHalved - nDoubledOrigin;
		end
		if nDoubled > 0 then
			tReturn['nDoubled'] = nDoubled
			bReturn = true
		end
	end
	if nHalved > 0 then
		tReturn['nHalved'] = nHalved
		bReturn = true
	end
	if nSpeedMax then
		tReturn['nSpeedMax'] = nSpeedMax
		bReturn = true
	end
	if nSpeedMod ~= 0 then
		tReturn['nSpeedMod'] = nSpeedMod
		bReturn = true
	end

	if bReturn then
		return tReturn;
	else
		return;
	end
end

function hasRoot(nodeCT)
	if Session.RulesetName ~= "5E" then
		if EffectManagerPFRPG2 then
			if EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Unconscious") then
				return true, false, 'Unconscious';
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Dead") then
				return true, false, 'Dead';
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Paralyzed") then
				return true, false, 'Paralyzed';
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Dying") then
				return true, false, 'Dying';
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Immobilized") then
				return true, false, 'Immobilized';
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Petrified") then
				return true, false, 'Petrified';
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Restrained") then
				return true, false, 'Restrained';
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Grabbed") then
				return true, false, 'Grabbed';
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Stunned") then
				return true, false, 'Stunned';
			else
				local bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)"
					, true,	false, false, true
				);
				if bHas then
					return true, false, WtWCommon.getEffectName(_,sLabel);
				else
					bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max"
						, true,	false, false, true
					);
					if bHas then
						return true, false, WtWCommon.getEffectName(_,sLabel);
					else
						bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "Speed%s*:%s*0"
							, true,	false, false, true
						);
						if bHas then
							return true, false, WtWCommon.getEffectName(_,sLabel);
						else
							bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*none"
								, true,	false, false, true
							);
							if bHas then
								return true, false, WtWCommon.getEffectName(_,sLabel);
							else
								return false;
							end
						end
					end
				end
			end
		else
			if EffectManager.hasCondition(nodeCT, "Unconscious") then
				return true, false, 'Unconscious';
			else
				local bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)"
					, true,	false, false, true
				);
				if bHas then
					return true, false, WtWCommon.getEffectName(_,sLabel);
				else
					bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max"
						, true,	false, false, true
					);
					if bHas then
						return true, false, WtWCommon.getEffectName(_,sLabel);
					else
						bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "Speed%s*:%s*0"
							, true,	false, false, true
						);
						if bHas then
							return true, false, WtWCommon.getEffectName(_,sLabel);
						else
							bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*none"
								, true,	false, false, true
							);
							if bHas then
								return true, false, WtWCommon.getEffectName(_,sLabel);
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
		if EffectManager5E.hasEffectCondition(nodeCT, "Grappled") then
			bReturn = true;
			sEffectName = 'Grappled';
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Paralyzed") then
			bReturn = true;
			sEffectName = 'Paralyzed';
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Petrified") then
			bReturn = true;
			sEffectName = 'Petrified';
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Restrained") then
			bReturn = true;
			sEffectName = 'Restrained';
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Unconscious") then
			bReturn = true;
			sEffectName = 'Unconscious';
		elseif EffectManager5E.hasEffectCondition(nodeCT, "DEATH") then
			bReturn = true;
			sEffectName = 'DEATH';
		else
			local bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)"
				, true,	false, false, true
			);
			if bHas then
				bReturn = true;
				sEffectName = WtWCommon.getEffectName(_,sLabel);
			else
				bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max"
					, true,	false, false, true
				);
				if bHas then
					bReturn = true;
					sEffectName = WtWCommon.getEffectName(_,sLabel);
				else
					bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "Speed%s*:%s*0"
						, true,	false, false, true
					);
					if bHas then
						bReturn = true;
						sEffectName = WtWCommon.getEffectName(_,sLabel);
					else
						bHas, sLabel = WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*none"
							, true,	false, false, true
						);
						if bHas then
							bReturn = true;
							sEffectName = WtWCommon.getEffectName(_,sLabel);
						else
							return false;
						end
					end
				end
			end
		end
		if bReturn then
			if WtWCommon.hasEffectClause(nodeCT, "^[Ss][Pp][Ee][Ee][Dd]%s*:%s*%d*%s*type%s*%(%s*[%l%u]*%s*%(%s*hover%s*%)%s*%)$") then
				return true, true, sEffectName;
			else
				return true, false, sEffectName;
			end
		end
	end
end

function handleExhaustion(nodeCT, nodeEffectLabel, nodeEffect)
	if not nodeCT then
		Debug.console("WalkThisWay.handleExhaustion - not nodeCT");
		return;
	end
	if nodeEffectLabel then
		local sMatch = string.match(string.lower(nodeEffectLabel), '^%s*exhausted%s*;%s*');
		if sMatch then
			if string.match(nodeEffectLabel, "^Exhausted; Speed ") or string.match(
				nodeEffectLabel, "^Exhausted; DEATH?")
			then nodeUbiquinated = nodeEffect end
			return;
		end
	end
	if (OptionsManager.isOption('VERBOSE_EXHAUSTION', "mnm") or OptionsManager.isOption('VERBOSE_EXHAUSTION',
		"verbose")) and not OptionsManager.isOption("GAVE", "2024"
	) then return end

	local sNewEffect;
	local nSpeedAdjust;
	local nExhaustMod,_ = EffectManager5E.getEffectsBonus(nodeCT, { "EXHAUSTION" }, true);
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

function checkProne(nodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	if not nodeCT then
		Debug.console("WalkThisWay.checkProne - not nodeCT");
		return;
	end

	if Session.RulesetName ~= "5E" then
		if EffectManagerPFRPG2 then
			if not EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Prone") then
				return false
			elseif hasRoot(nodeCT) then
				return false
			elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", true) then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "NOSTAND") then
				return false
			else
				return true
			end
		else
			if not EffectManager.hasCondition(nodeCT, "Prone") then
				return false
			elseif hasRoot(nodeCT) then
				return false
			elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", true) then
				return false
			elseif EffectManager.hasCondition(nodeCT, "NOSTAND") then
				return false
			else
				return true
			end
		end
	else
		if not EffectManager5E.hasEffectCondition(nodeCT, "Prone") then
			return false
			elseif hasRoot(nodeCT) then
				return false
		elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", true) then
			return false
		elseif EffectManager5E.hasEffect(nodeCT, "NOSTAND") then
			return false
		elseif checkHideousLaughter(nodeCT) then
			return false
		else
			return true
		end
	end
end

function checkHideousLaughter(rActor)
	if not rActor then
		Debug.console("WalkThisWay.checkHideousLaughter - not rActor");
		return;
	end
	local bClauseExceptFound = false;
	local nMatch = 0;
	local sClause = "Tasha's Hideous Laughter";
		-- should return true, but only if it's not clause1
	local sClause1 = "^Tasha's Hideous Laughter; Prone$";
		-- should return false, but only if none of the other trues are present
		-- and also if the only sClause is the one contained within sClause1
	local sClause2 = "^Tasha's Hideous Laughter %(C%); Prone; Incapacitated";
		-- should return true, regardless of other clauses
		-- starts with clause
		-- Team Twohy with ongoing save extension
	local sClause3 = "^Tasha's Hideous Laughter; Incapacitated$";
		-- should return true, regardless of other clauses
		-- whole clause
		-- Team Twohy without ongoing save extension
	--local sClause4 = "Tasha's Hideous Laughter (C)";
		-- should return false, if all other clauses are not found
		-- whole clause
		-- Team Twohy without ongoing save extension
		-- lucky here. This one is a last check anyway, and it doesn't hit with any of the others.
	local sClause5 = "^Tasha's Hideous Laughter; %(C%)$";
		-- should return false, if clauses 0, 2, or 3 are not present
		-- should behave same as clause1
		-- whole clause
		-- 5eAE with self concentration

	if WtWCommon.hasEffectFindString(rActor, sClause3) then
		return true;
	end

	if WtWCommon.hasEffectFindString(rActor, sClause2, false) then
		return true;
	end

	local hasClause1 = WtWCommon.hasEffectFindString(rActor, sClause1);
	local hasClause5 = WtWCommon.hasEffectFindString(rActor, sClause5);
	if hasClause1 or hasClause5 then
		bClauseExceptFound = true;
		nMatch = nMatch + 1;
	elseif WtWCommon.hasEffectFindString(rActor, sClause, true) then
		nMatch = nMatch + 1;
	end
	if hasClause1 and hasClause5 then
		nMatch = nMatch - 1;
	end

	if EffectManager5E.hasEffect(rActor, sClause) then
		if not bClauseExceptFound or nMatch > 1 then
			return true;
		end
	end
	return false;
end

function setPQvalue(sName)
	local nodeWTW = DB.createNode('WalkThisWay');
	if Session.IsHost then DB.setPublic(nodeWTW, true) end
	local nodePQ = DB.getChild(nodeWTW, 'proneQuery');
	if not nodePQ then
		nodePQ = DB.createChild(nodeWTW, 'proneQuery', 'string');
		--DB.setPublic(nodeWTW, true); --I think it takes public status from parent node
	end
	local sMessage = tostring(sName) .. ' is prone.';
	DB.setValue(nodeWTW, 'proneQuery', 'string', sMessage);
	return nodePQ;
end

function delWTWdataChild(sChildNode)
	local nodeWTW = DB.findNode('WalkThisWay');
	if not nodeWTW then
		return true;
	end
	local nodePQ = DB.getChild(nodeWTW, sChildNode);
	if not nodePQ then
		return true;
	end
	return DB.deleteNode(nodePQ);
end

function openSpeedWindow(nodeCT)
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	if Session.IsHost then DB.setPublic(nodeCTWtW, true) end
	local rActor = ActorManager.resolveActor(nodeCT);
	DB.setValue(nodeCTWtW, 'actorname', 'string', tostring(rActor.sName));
	local sCurrentSpeed = DB.getValue(nodeCTWtW, 'currentSpeed');
	if not sCurrentSpeed then
		local nFGSpeed = DB.getValue(nodeCT, 'speed');
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nFGSpeed));
	end
	Interface.openWindow('speed_window', nodeCTWtW);
end

function turnStartChecks(nodeCT)
	if not Session.IsHost then
		Debug.console('WalkThisWay.turnStartchecks - not IsHost');
		return;
	end
	local rSource = ActorManager.resolveActor(nodeCT);
	local sOwner = WtWCommon.getControllingClient(nodeCT);

	if Session.RulesetName == "5E" then
		if nodeUbiquinated then
			DB.deleteNode(nodeUbiquinated);
			nodeUbiquinated = nil;
		end
		if sOwner then
			local msgOOB = {};
			msgOOB.type = OOB_MSGTYPE_SPEEDWINDOW;
			msgOOB.sCTNodeID = ActorManager.getCTNodeName(rSource);
			Comm.deliverOOBMessage(msgOOB, sOwner);
		else
			if OptionsManager.isOption('AOSW', 'on') then
				openSpeedWindow(nodeCT);
			end
		end
	end

	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	if not checkProne(rSource) then
		return;
	end
	if sOwner then
		queryClient(nodeCT)
		return;
	else
		if rSource.sName then
			setPQvalue(rSource.sName);
		end
		openProneWindow();
	end
end

function closeAllProneWindows(nodeCT)
	if not Session.IsHost then
		Debug.console('WalkThisWay.closeAllProneWindows - not IsHost');
		return;
	end
	closeProneWindow();
	if WtWCommon.getControllingClient(nodeCT) then
		sendCloseWindowCmd(nodeCT);
	end
end

function openProneWindow()
	if OptionsManager.isOption('WTWON', 'off') or OptionsManager.isOption('WTWONPLR', 'off') then
		return;
	end
	if Session.IsHost and OptionsManager.isOption('WTWONDM', 'off') then
		return;
	end
	local datasource = 'WalkThisWay';
	if Session.RulesetName == '5E' then
		Interface.openWindow('prone_query_small', datasource);
	elseif Session.RulesetName == "PFRPG2" then
		Interface.openWindow('prone_query_pfrpg2', datasource);
	else
		Interface.openWindow('prone_query_not5e', datasource);
	end
end

function closeProneWindow()
	local datasource = 'WalkThisWay';
	local wChar = Interface.findWindow("prone_query_small", datasource);
	local wCoreChar = Interface.findWindow("prone_query_not5e", datasource);
	local wPFChar = Interface.findWindow("prone_query_pfrpg2", datasource);
	if wChar then
		wChar.close();
	end
	if wCoreChar then
		wCoreChar.close();
	end
	if wPFChar then
		wPFChar.close();
	end
	delWTWdataChild('proneQuery');
end

function standUp()
	local rCurrent = ActorManager.resolveActor(CombatManager.getActiveCT());
	local rSource = ActorManager.getCTNode(rCurrent);

	local sStoodUp = 'Stood Up; SPEED: halved';

	WtWCommon.removeEffectClause(rSource, "Prone");
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			EffectManager.addEffect("", "", rSource, {
				sName = sStoodUp, nDuration = 1, sChangeState = "rts" }, "");
		else
			EffectManager.addEffect("", "", rSource, {
				sName = 'Stood Up', nDuration = 1 }, "");
		end
	else
		if Session.RulesetName == "5E" then
			WtWCommon.notifyApplyHostCommands(rSource, 0, {
				sName = sStoodUp, nDuration = 1, sChangeState = "rts" });
		else
			WtWCommon.notifyApplyHostCommands(rSource, 0, {
				sName = 'Stood Up', nDuration = 1, sChangeState = "rts" });
		end
	end
end

function queryClient(nodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	local sOwner = WtWCommon.getControllingClient(nodeCT);
	local rSource = ActorManager.resolveActor(nodeCT);

	if sOwner then
		if rSource.sName then
			setPQvalue(rSource.sName);
		end
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_PRONEQUERY;
		msgOOB.sCTNodeID = ActorManager.getCTNodeName(rSource);
		Comm.deliverOOBMessage(msgOOB, sOwner);
	else
		ChatManager.SystemMessage(Interface.getString("msg_NotConnected"));
	end
end

function sendCloseWindowCmd(nodeCT)
	if not Session.IsHost then
		Debug.console('WalkThisWay.sendCloseWindowCmd - not IsHost');
		return;
	end
	local sOwner = WtWCommon.getControllingClient(nodeCT);
	if sOwner then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_CLOSEQUERY;
		msgOOB.sCTNodeID = nodeCT;
		Comm.deliverOOBMessage(msgOOB, sOwner);
	else
		ChatManager.SystemMessage(Interface.getString("msg_NotConnected"));
	end
end

function handleSpeedWindowClient(msgOOB)
	if OptionsManager.isOption('AOSW', 'on') then
		openSpeedWindow(msgOOB.sCTNodeID);
	end
end
function handleProneQueryClient()
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	openProneWindow();
end
function handleCloseProneQuery()
	closeProneWindow();
end