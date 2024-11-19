-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals clientGetOption checkProne checkHideousLaughter speedCalculator setPQvalue
-- luacheck: globals closeAllProneWindows openProneWindow closeProneWindow standUp delWTWdataChild
-- luacheck: globals queryClient sendCloseWindowCmd handleProneQueryClient handleCloseProneQuery hasRoot
-- luacheck: globals accommKnownExtsSpeed callSpeedCalcEffectUpdated openSpeedWindow getConversionFactor
-- luacheck: globals parseBaseSpeed onRecordTypeEventWtW reparseBaseSpeed reparseAllBaseSpeeds recalcAllSpeeds
-- luacheck: globals callSpeedCalcEffectDeleted setOptions updateDisplaySpeed handleSpeedWindowClient
-- luacheck: globals turnStartChecks handleUpdateDisplaySpeedClient registerPreference getPreference

OOB_MSGTYPE_PRONEQUERY = "pronequery";
OOB_MSGTYPE_CLOSEQUERY = "closequery";
OOB_MSGTYPE_SPEEDWINDOW = 'speedwindow';
OOB_MSGTYPE_UPDISPSPD = 'updatedisplayspeed';

local fonRecordTypeEvent = '';
local tClientPrefs = {};

function onInit()
	setOptions();

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_SPEEDWINDOW, handleSpeedWindowClient);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_UPDISPSPD, handleUpdateDisplaySpeedClient);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRONEQUERY, handleProneQueryClient);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSEQUERY, handleCloseProneQuery);

	if Session.IsHost then
		EffectManager.registerEffectCompType("SPEED", { bIgnoreTarget = true, bNoDUSE = true,
			bIgnoreOtherFilter = true, bIgnoreExpire = true
		});
			--known options: bIgnoreOtherFilter bIgnoreDisabledCheck bDamageFilter bConditionFilter bNoDUSE bIgnoreTarget
			--continued: bSpell bOneShot bIgnoreExpire
		DB.addHandler('combattracker.list.*.speed', 'onUpdate', reparseBaseSpeed);
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
		if not OptionsManager.isOption('WESC', 'off') then
			DB.addHandler('combattracker.list.*.effects.*.label', 'onUpdate', callSpeedCalcEffectUpdated);
			DB.addHandler('combattracker.list.*.effects','onChildDeleted', callSpeedCalcEffectDeleted);
		end
		CombatManager.setCustomTurnStart(turnStartChecks);
		CombatManager.setCustomTurnEnd(closeAllProneWindows);
	end
end

function onClose()
	if Session.IsHost then
		DB.removeHandler('combattracker.list.*.effects.*.label', 'onUpdate', callSpeedCalcEffectUpdated);
		DB.removeHandler('combattracker.list.*.effects','onChildDeleted',callSpeedCalcEffectDeleted);
		DB.removeHandler('combattracker.list.*.speed', 'onUpdate', reparseBaseSpeed);
		OptionsManager.unregisterCallback('DDCU', reparseAllBaseSpeeds);
		OptionsManager.unregisterCallback('WESC', recalcAllSpeeds);
		CombatRecordManager.onRecordTypeEvent = fonRecordTypeEvent; --luacheck: ignore 113
	end
	OptionsManager.unregisterCallback('DDLU', recalcAllSpeeds);
end

function setOptions()
-- DEFAULT BEHAVIORS FOR OPTIONS: sType = "option_entry_cycler", on|off, default = off
--Farratto: Undocumented default option behaviors: bLocal = false, sGroupRes = "option_header_client"
	--Old 4th = ("option_label_" .. sKey)
	if Session.IsHost then
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
		OptionsManager.registerOption2('WHOLEEFFECT', false, 'option_header_WtW', 'option_WtW_Delete_Whole', 'option_entry_cycler', {
			labels = 'option_val_on',
			values = 'on',
			baselabel = 'option_val_off',
			baseval = 'off',
			default = 'off'
		});
		OptionsManager.registerOption2('APCW', false, 'option_header_WtW', 'option_WtW_Allow_Player_Choice', 'option_entry_cycler', {
			labels = 'option_val_on',
			values = 'on',
			baselabel = 'option_val_off',
			baseval = 'off',
			default = 'off'
		});
		OptionsManager.registerCallback('DDCU', reparseAllBaseSpeeds);
		OptionsManager.registerCallback('WESC', recalcAllSpeeds);
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

	OptionsManager.registerCallback('DDLU', recalcAllSpeeds);
end

function onRecordTypeEventWtW(sRecordType, tCustom)
	fonRecordTypeEvent(sRecordType, tCustom); --luacheck: ignore 212 113
	if Session.IsHost then
		parseBaseSpeed(tCustom.nodeCT, true);
	end
end

function callSpeedCalcEffectUpdated(nodeEffectLabel)
	if OptionsManager.isOption('WESC', 'off') then
		return;
	end
	local nodeEffect = DB.getParent(nodeEffectLabel);
	local nodeCT = DB.getChild(nodeEffect, '...');
	speedCalculator(nodeCT);
end
function callSpeedCalcEffectDeleted(nodeEffects)
	if OptionsManager.isOption('WESC', 'off') then
		return;
	end
	local nodeCT = DB.getParent(nodeEffects)
	speedCalculator(nodeCT);
end

function clientGetOption(sKey)
	if CampaignRegistry["Opt" .. sKey] then
		return CampaignRegistry["Opt" .. sKey];
	end
end

--function addEffectWtW(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
--	faddEffectOriginal(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg); --luacheck: ignore 113
--	speedCalculator(nodeCT);
--end

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

	local nHover = DB.getValue(nodeCTWtW, 'hover')
	local bHasRoot, bHasHover = hasRoot(nodeCT);
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
		local bReturn = updateDisplaySpeed(nodeCT, tRoot, nBaseSpeed);
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
	end

	local bDifficult = false;
	local tRebase = {};
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
			Debug.console("WalkThisWay.speedCalculator - Syntax Error");
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
			end
			if nSpeedMax then
				if nMaxMod < nSpeedMax then
					nSpeedMax = nMaxMod;
				end
			else
				nSpeedMax = nMaxMod;
			end
		end
		if sRmndrLower == "difficult" then
			bRecognizedRmndr = true;
			bDifficult = true;
		end
		if (sRmndrLower == "half" or sRmndrLower == "halved") then
			bRecognizedRmndr = true;
			nHalved = nHalved + 1;
		end
		if (sRmndrLower == "double" or sRmndrLower == "doubled") then
			bRecognizedRmndr = true;
			nDoubled = nDoubled + 1;
		end
		if not bProne and StringManager.startsWith(sRmndrLower, 'type') then
			bRecognizedRmndr = true;
			if not string.match(sRmndrLower, '%)$') then
				Debug.console("WalkThisWay.speedCalculator - Syntax error. Try SPEED: type(fly)");
			else
				--local sType = nil;
				local sStrip = string.match(sRemainder, '^[Tt][Yy][Pp][Ee]%s*%(')
				sStrip = string.gsub(sStrip, '%(', '%%(');
				local sRmndrRemainder = sRemainder:gsub(sStrip, '');
				--local sRmndrRemainder = sRmndrLower:gsub('^type%s*%(', '');
				local sType = sRmndrRemainder:gsub('%)$', '');
				local sTypeLower = string.lower(sType);
				local sTypeFly = string.match(sTypeLower, 'fly')
				local sTypeHover = string.match(sTypeLower, 'hover')
				local nFound;
				for k,value in ipairs(tFGSpeedNew) do
					local vTypeLower = string.lower(value.type);
					if sTypeFly then
						if string.match(vTypeLower, 'fly') then
							nFound = k;
							if (nHover == 1) or sTypeHover then
								value.type = 'Fly (hover)'
							end
						end
					else
						if vTypeLower == sTypeLower then
							nFound = k;
						end
					end
				end

				if nMod then
					if nMod <= 0 or string.sub(sMod, 1, 1) == '+' then
						if nFound then
							tFGSpeedNew[nFound]['mod'] = nMod;
						else
							local tSpdRcrd = {};
							tSpdRcrd['type'] = sType;
							tSpdRcrd['mod'] = nMod;
							table.insert(tFGSpeedNew, tSpdRcrd);
						end
					else
						if nFound then
							local nCurrentVel = tonumber(tFGSpeedNew[nFound]['velocity']);
							if nCurrentVel then
								if nMod > nCurrentVel then tFGSpeedNew[nFound]['velocity'] = nMod end
							else
								tFGSpeedNew[nFound]['velocity'] = nMod
							end
						else
							local tSpdRcrd = {};
							tSpdRcrd['type'] = sType;
							tSpdRcrd['velocity'] = nMod;
							table.insert(tFGSpeedNew, tSpdRcrd);
						end
					end
					nMod = nil;
				else
					if string.match(sTypeLower, '^%-') then
						local sRemoveType = string.sub(sTypeLower, 2)
						--local sRemoveTypeLower = string.lower(sRemoveType);
						local tCheckFGSpdTable = tFGSpeedNew;
						for k,value in ipairs(tCheckFGSpdTable) do
							local vTypeLower = string.lower(value.type);
							if vTypeLower == sRemoveType then
								table.remove(tFGSpeedNew, k)
							end
						end
					else
						--local sTypeLower = string.lower(sType);
						--local bFound = false
						--for _,value in ipairs(tFGSpeedNew) do
						--	local vTypeLower = string.lower(value.type);
						--	if vTypeLower == sTypeLower then
						--		bFound = true
						--	end
						--end
						if not nFound then
							local tSpdRcrd = {}
							tSpdRcrd['type'] = sType;
							table.insert(tFGSpeedNew, tSpdRcrd)
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
					Debug.console("WalkThisWay.speedCalculator - Syntax Error");
				else
					local sRmndrRemainder = sRmndrLower:gsub('^inc%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					local nSpeedInc = tonumber(sRmndrRemainder);
					if not nSpeedInc then
						Debug.console("WalkThisWay.speedCalculator - Syntax Error")
					else
						nSpeedMod = nSpeedMod + nSpeedInc;
					end
				end
			else
				nSpeedMod = nSpeedMod + nMod;
				nMod = nil;
			end
		end
		if StringManager.startsWith(sRmndrLower, 'dec') then
			bRecognizedRmndr = true;
			if string.match(sRmndrLower, '%)$') then
				if nMod then
					Debug.console("WalkThisWay.speedCalculator - Syntax Error");
				else
					local sRmndrRemainder = sRmndrLower:gsub('^dec%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					local nSpeedInc = tonumber(sRmndrRemainder);
					if not nSpeedInc then
						Debug.console("WalkThisWay.speedCalculator - Syntax Error")
					else
						nSpeedMod = nSpeedMod - nSpeedInc;
					end
				end
			else
				nSpeedMod = nSpeedMod - nMod;
				nMod = nil;
			end
		end
		if not bRecognizedRmndr and sRmndrLower ~= '' then
			Debug.console("WalkThisWay.speedCalculator - Syntax Error")
		end
		if nMod then
			local sNMod = tostring(nMod)
			if string.match(sNMod, '^%-') then
				nSpeedMod = nSpeedMod + nMod;
			else
				table.insert(tRebase, nMod)
			end
		end
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
			--if not nFGSpeed then nFGSpeed = nFGSpeedNew end
		end
		for key,v in ipairs(tRebase) do
			if key > 1 then
				if v > nFGSpeedNew then nFGSpeedNew = v end
			else
				nFGSpeedNew = v;
			end
		end

		local nLocalSpdMod = nSpeedMod
		if tSpdRcrd.mod then nLocalSpdMod = nLocalSpdMod + tSpdRcrd.mod end
		--local nSpeedFinal = nFGSpeedNew + nSpeedMod;
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

	local sOwner = WtWCommon.getControllingClient(nodeCT);
	local sPref;
	if sOwner then
		sPref = getPreference(sOwner);
	else
		sPref = OptionsManager.getOption('DDLU');
	end

	local bReturn = updateDisplaySpeed(nodeCT, tFGSpeedNew, nBaseSpeed, bProne, sPref);
	return bReturn;
end
-- luacheck: pop

function handleUpdateDisplaySpeedClient(msgOOB)
	updateDisplaySpeed(msgOOB['nodeCT'], msgOOB.tFGSpeedNew, msgOOB.nBaseSpeed, msgOOB.bProne);
end

function updateDisplaySpeed(nodeCT, tFGSpeedNew, nBaseSpeed, bProne, sPref)
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

		if bProne then
			sReturn = sVelWithUnits .. ' Crawl'
		else
			if tSpdRcrd.type == '' or (string.match(tSpdRcrd.type, '^Walk')) then
				nCurrentSpeed = tSpdRcrd.velocity
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
	end
	sReturn = StringManager.strip(sReturn);
	if sReturn and sReturn ~= '' then
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', sReturn);
		local rActor = ActorManager.resolveActor(nodeCT);
		if not rActor then
			Debug.console("WalkThisWay.updateDisplaySpeed - not rActor");
			return;
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
	local tReturn = {}
	if Session.RulesetName == "5E" then
		if EffectManager5E.hasEffectCondition(nodeCT, 'Dash') then
			nDoubled = nDoubled + 1
		end
		--encumbrance
		if EffectManager5E.hasEffect(nodeCT, "Exceeds Maximum Carrying Capacity") then
			nSpeedMax = 5;
		end
		if EffectManager5E.hasEffect(nodeCT, "Heavily Encumbered") then
			nSpeedMod = nSpeedMod - 20;
		else
			if EffectManager5E.hasEffect(nodeCT, "Lightly Encumbered") or EffectManager5E.hasEffect(nodeCT, "Encumbered") then
				nSpeedMod = nSpeedMod - 10;
			end
		end
		--exhaustion (speed 0 & DEATH checks are in hasRoot)
		if WtWCommon.hasEffectFindString(nodeCT, "^Exhausted; Speed Halved", false) then
			nHalved = nHalved + 1;
		end
		local sExhaustStack = WtWCommon.hasEffectFindString(nodeCT, "^Exhausted; Speed %-%d+ %(info only%)$", false, true);
		if sExhaustStack then
			local sExhaustStack = sExhaustStack:gsub('^Exhausted; Speed %-', '');
			local sExhaustStack = sExhaustStack:gsub('%s*%(%s*info only%s*%)$', '');
			local nExhaustSpd = tonumber(sExhaustStack);
			if nExhaustSpd then
				nSpeedMod = nSpeedMod - nExhaustSpd;
			end
		end
	end

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
				return true;
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Dead") then
				return true;
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Paralyzed") then
				return true;
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Dying") then
				return true;
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Immobilized") then
				return true;
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Petrified") then
				return true;
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Restrained") then
				return true;
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Grabbed") then
				return true;
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Stunned") then
				return true;
			elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)", true) then
				return true;
			elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max", true) then
				return true;
			elseif WtWCommon.hasEffectClause(nodeCT, "Speed%s*:%s*0", true) then
				return true;
			elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*none", true) then
				return true;
			else
				return false;
			end
		else
			if EffectManager.hasCondition(nodeCT, "Unconscious") then
				return true;
			elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)", true) then
				return true;
			elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max", true) then
				return true;
			elseif WtWCommon.hasEffectClause(nodeCT, "Speed%s*:%s*0", true) then
				return true;
			elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*none", true) then
				return true;
			else
				return false;
			end
		end
	else
		local bReturn;
		if EffectManager5E.hasEffectCondition(nodeCT, "Grappled") then
			bReturn = true;
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Paralyzed") then
			bReturn = true;
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Petrified") then
			bReturn = true;
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Restrained") then
			bReturn = true;
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Unconscious") then
			bReturn = true;
		elseif EffectManager5E.hasEffectCondition(nodeCT, "DEATH") then
			bReturn = true;
		elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max", true) then
			bReturn = true;
		elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)", true) then
			bReturn = true;
		elseif WtWCommon.hasEffectClause(nodeCT, "Speed%s*:?%s*0", true) then
			bReturn = true;
		elseif WtWCommon.hasEffectClause(nodeCT, "SPEED%s*:%s*none", true) then
			bReturn = true;
		else
			return false;
		end
		if bReturn then
			if WtWCommon.hasEffectClause(nodeCT, "^[Ss][Pp][Ee][Ee][Dd]%s*:%s*%d*%s*type%s*%(%s*[%l%u]*%s*%(%s*hover%s*%)%s*%)$") then
				return true, true;
			else
				return true, false;
			end
		end
	end
end

--still needs to be called.	 check how rhagelstrom calls his
--add option to turn off destroy
function handleExhaustion(nodeCT)
	--copied with slight mods from CombatManager2.onTurnStart.	don't know why it doesn't work
	local nExhaustMod,_ = EffectManager5E.getEffectsBonus(nodeCT, { "EXHAUSTION" }, true);
	local bShowMsg = true;
	if nExhaustMod > 5 then
		EffectManager.addEffect("", "", nodeCT, { sName = 'Exhausted; DEATH; DESTROY' }, '');
	end
	if OptionsManager.isOption("GAVE", "2024") then
		if nExhaustMod > 0 then
			local nSpeedAdjust = nExhaustMod * 5;
			EffectManager.addEffect("", "", nodeCT, { sName = "Exhausted; Speed: dec(" .. nSpeedAdjust .. ")" }, bShowMsg);
		end
	else
		if nExhaustMod > 4 then
			EffectManager.addEffect("", "", nodeCT, { sName = "Exhausted; Speed: max(0), MAXHP: 0.5" }, bShowMsg);
		elseif nExhaustMod > 3 then
			EffectManager.addEffect("", "", nodeCT, { sName = "Exhausted; Speed: halved, MAXHP: 0.5" }, bShowMsg);
		elseif nExhaustMod > 1 then
			EffectManager.addEffect("", "", nodeCT, { sName = "Exhausted; Speed: halved" }, bShowMsg);
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
	--5e: auto encumbrance
		--Exceeds Maximum Carrying Capacity; Speed=5
		--Heavily Encumbered; Speed-20; DISCHK: strength,dexterity,constitution; DISATK; DISSAV: strength,dexterity,constitution
		--Lightly Encumbered; Speed-10
--end

--function handleItemTooHeavy(nodeCT)
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
--end

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
--	local sClause4 = "Tasha's Hideous Laughter (C)";
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

	if not OptionsManager.isOption('WHOLEEFFECT', 'on') then
		WtWCommon.removeEffectClause(rSource, "Prone");
	end
	if Session.IsHost then
		if OptionsManager.isOption('WHOLEEFFECT', 'on') then
			WtWCommon.removeEffectCaseInsensitive(rSource, "Prone");
		end
		if Session.RulesetName == "5E" then
			EffectManager.addEffect("", "", rSource, {
				sName = sStoodUp, nDuration = 1, sChangeState = "rts" }, "");
		else
			EffectManager.addEffect("", "", rSource, {
				sName = 'Stood Up', nDuration = 1 }, "");
		end
	else
		if OptionsManager.isOption('WHOLEEFFECT', 'on') then
			WtWCommon.notifyApplyHostCommands(rSource, 1, "Prone");
		end
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