-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals clientGetOption checkProne checkHideousLaughter addEffectWtW speedCalculator setPQvalue
-- luacheck: globals closeAllProneWindows openProneWindow closeProneWindow standUp delWTWdataChild proneWindow
-- luacheck: globals queryClient sendCloseWindowCmd handleProneQueryClient handleCloseProneQuery hasRoot
-- luacheck: globals accommKnownExtsSpeed deleteEffectSpeedCalc openSpeedWindow getConversionFactor
-- luacheck: globals parseBaseSpeed

OOB_MSGTYPE_PRONEQUERY = "pronequery";
OOB_MSGTYPE_CLOSEQUERY = "closequery";

faddEffectOriginal = ''; --luacheck: ignore 111

function onInit()
-- DEFAULT BEHAVIORS FOR OPTIONS: sType = "option_entry_cycler", on|off, default = off
--Farratto: Undocumented default option behaviors: bLocal = false, sGroupRes = "option_header_client"
	--Old 4th = ("option_label_" .. sKey)
	OptionsManager.registerOptionData({	sKey = 'AOSW', bLocal = true });
	OptionsManager.registerOptionData({	sKey = 'DDCU', sGroupRes = "option_header_WtW",
		tCustom = { labelsres = "option_val_tiles|option_val_meters", values = "tiles|m",
			baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
		}
	});
	OptionsManager.registerOptionData({	sKey = 'DDLU', bLocal = true,
		tCustom = { labelsres = "option_val_tiles|option_val_meters", values = "tiles|m",
			baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
		}
	});
	OptionsManager.registerOption2('WTWON', false, 'option_header_WtW', 'option_WtW_On',
								   'option_entry_cycler', {
		labels = 'option_val_off',
		values = 'off',
		baselabel = 'option_val_on',
		baseval = 'on',
		default = 'on'
	});
	OptionsManager.registerOption2('WHOLEEFFECT', false, 'option_header_WtW', 'option_WtW_Delete_Whole',
								   'option_entry_cycler', {
		labels = 'option_val_on',
		values = 'on',
		baselabel = 'option_val_off',
		baseval = 'off',
		default = 'off'
	});
	OptionsManager.registerOption2('APCW', false, 'option_header_WtW', 'option_WtW_Allow_Player_Choice',
								   'option_entry_cycler', {
		labels = 'option_val_on',
		values = 'on',
		baselabel = 'option_val_off',
		baseval = 'off',
		default = 'off'
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
	if not OptionsManager.isOption('WTWON', 'off') then
		CombatManager.setCustomTurnStart(proneWindow);
		CombatManager.setCustomTurnEnd(closeAllProneWindows);
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRONEQUERY, handleProneQueryClient);
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSEQUERY, handleCloseProneQuery);
	end

	faddEffectOriginal = EffectManager.addEffect; --luacheck: ignore 111
	EffectManager.addEffect = addEffectWtW;

	EffectManager.registerEffectCompType("SPEED", { bIgnoreTarget = true, bNoDUSE = true, bIgnoreOtherFilter = true, bIgnoreExpire = true });
		--known options: bIgnoreOtherFilter bIgnoreDisabledCheck bDamageFilter bConditionFilter bNoDUSE bIgnoreTarget
		--continued: bSpell bOneShot bIgnoreExpire

    if Session.IsHost then
        --DB.addHandler('combattracker.list.*.effects.*.label', 'onUpdate', modSourceTurnHandler);
			--might need this.  try it later.  don't forget to uncomment in close as well.
        DB.addHandler('combattracker.list.*.effects.*.label', 'onDelete', deleteEffectSpeedCalc);
    end
end

function onClose()
	EffectManager.addEffect = faddEffectOriginal; --luacheck: ignore 113

    if Session.IsHost then
        --DB.removeHandler('combattracker.list.*.effects.*.label', 'onUpdate', modSourceTurnHandler);
        DB.removeHandler('combattracker.list.*.effects.*.label', 'onDelete', deleteEffectSpeedCalc);
    end

end

function deleteEffectSpeedCalc(nodeEffectLabel)
    local nodeEffect = DB.getParent(nodeEffectLabel);
    local nodeCT = DB.getChild(nodeEffect, '...');
	local nNewSpeed = speedCalculator(nodeCT);
	Debug.console("nNewSpeed = " .. tostring(nNewSpeed));
	if nNewSpeed then
		local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nNewSpeed));
	end
end

function clientGetOption(sKey)
	if CampaignRegistry["Opt" .. sKey] then
		return CampaignRegistry["Opt" .. sKey];
	end
end

function addEffectWtW(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	faddEffectOriginal(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg); --luacheck: ignore 113
	local nNewSpeed = speedCalculator(nodeCT);
	Debug.console("nNewSpeed = " .. tostring(nNewSpeed));
	if nNewSpeed then
		local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nNewSpeed));
	end
end

function getConversionFactor(sCurrentUnits, sDesiredUnits)
	if not sCurrentUnits or not sDesiredUnits or sCurrentUnits == sDesiredUnits then
		Debug.console('WalkThisWay.getConversionFactor - Internal Syntax error.');
		return;
	end
	local nReturn;
	if sCurrentUnits == 'ft.' then
		if sDesiredUnits == 'm' then
			nReturn = 1.5 / 5;
			return nReturn;
		elseif sDesiredUnits == 'tiles' then
			nReturn = 1 / 5;
			return nReturn;
		else
			Debug.console('WalkThisWay.getConversionFactor - Invalid units.');
			return;
		end
	elseif sCurrentUnits == 'm' then
		if sDesiredUnits == 'ft.' then
			nReturn = 5 / 1.5;
			return nReturn;
		elseif sDesiredUnits == 'tiles' then
			nReturn = 1 / 1.5;
			return nReturn;
		else
			Debug.console('WalkThisWay.getConversionFactor - Invalid units.');
			return;
		end
	elseif sCurrentUnits == 'tiles' then
		if sDesiredUnits == 'ft.' then
			nReturn = 5 / 1;
			return nReturn;
		elseif sDesiredUnits == 'm' then
			nReturn = 1.5 / 1;
			return nReturn;
		else
			Debug.console('WalkThisWay.getConversionFactor - Invalid units.');
			return;
		end
	else
		Debug.console('WalkThisWay.getConversionFactor - Invalid units.');
		return;
	end
end

--still needs to be called upon effect deletion
-- luacheck: push ignore 561
function speedCalculator(nodeCT, bDebug)
	if not nodeCT then
		Debug.console("WalkThisWay.speedCalculator - not nodeCT");
		return;
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if not nodeFGSpeed then
		parseBaseSpeed(nodeCT)
	end
	nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if not nodeFGSpeed then
		Debug.console("WalkThisWay.speedCalculator - Parsing base speed failed.");
		return;
	end

	local nHover = DB.getValue(nodeCTWtW, 'hover')
	local sLngthUnits = DB.getValue(nodeCTWtW, 'units')
	if hasRoot(nodeCT) then
		if bDebug then Debug.console("root found") end
		local sReturn = '0 ' .. sLngthUnits;
		if nHover == 1 then
			sReturn = sReturn .. ' (hover)';
		end
		return sReturn;
	else
		if bDebug then Debug.console("no root found") end
	end

	local rActor = ActorManager.resolveActor(nodeCT);
	if not rActor then
		Debug.console("WalkThisWay.speedCalculator - not rActor");
		return;
	end
	local tSpeedEffects = WtWCommon.getEffectsByTypeWtW(rActor, 'SPEED%s*:');
	if bDebug then Debug.console("tSpeedEffects[1] = " .. tostring(tSpeedEffects[1])) end
	local nHalved = 0;
	if WtWCommon.fhasCondition(rActor, "Prone") then
		nHalved = nHalved + 1
	end

	local nSpeedMod = 0;
	local nSpeedMax = nil;
	local nDoubled = 0;
	local tAccomSpeed = accommKnownExtsSpeed(nodeCT);
	if tAccomSpeed then
		if bDebug then Debug.console("accomodations detected") end
		if tAccomSpeed['nDoubled'] then
			nDoubled = nDoubled + tonumber(tAccomSpeed['nDoubled'])
			if bDebug then Debug.console("nDoubled = (" .. tostring(nDoubled) .. ')') end
		end
		if tAccomSpeed['nHalved'] then
			nHalved = nHalved + tonumber(tAccomSpeed['nHalved'])
			if bDebug then Debug.console("nHalved = (" .. tostring(nHalved) .. ')') end
		end
		if tAccomSpeed['nSpeedMax'] then
			nSpeedMax = tonumber(tAccomSpeed['nSpeedMax'])
			if bDebug then Debug.console("nSpeedMax = (" .. tostring(nSpeedMax) .. ')') end
		end
		if tAccomSpeed['nSpeedMod'] then
			if bDebug then Debug.console("tAccomSpeed['nSpeedMod'] = (" .. tostring(tAccomSpeed['nSpeedMod']) .. ')') end
			nSpeedMod = nSpeedMod + tonumber(tAccomSpeed['nSpeedMod'])
			if bDebug then Debug.console("nSpeedMod = (" .. tostring(nSpeedMod) .. ')') end
		end
	else
		if bDebug then Debug.console("accomodations not detected") end
	end


	local tFGSpeedNodes = DB.getChildren(nodeCTWtW, 'FGSpeed');
	local tFGSpeedNew = {};
	-- PLACEMARKER --

	
	local bDifficult = false;
	local tRebase = {};
	for _,v in ipairs(tSpeedEffects) do
		local sRemainder;
		local bRecognizedRmndr = false;
		local sVClauseLower = string.lower(v.clause);
		--WtW parsing
		local sMinusSpeed = sVClauseLower:gsub('^speed%s-:%s*', '');
		if bDebug then Debug.console("sMinusSpeed = (" .. tostring(sMinusSpeed) .. ')') end
		local sMod = string.match(sMinusSpeed, '^%-?%d+');
		if bDebug then Debug.console("sMod = " .. tostring(sMod)) end
		local nMod = tonumber(sMod);
		if nMod then
			sRemainder = sMinusSpeed:gsub('^' .. tostring(sMod) .. '%s*', '');
			if bDebug then Debug.console("sRemainder = " .. tostring(sRemainder)) end
			if string.match(sRemainder, '^d%d+') then
				Debug.console("WalkThisWay.speedCalculator - dice not currently supported. Please request this feature in the forums.");
			end
		else
			sRemainder = sMinusSpeed;
			if bDebug then Debug.console("sRemainder = " .. tostring(sRemainder)) end
		end
		if not sRemainder and not nMod then
			Debug.console("WalkThisWay.speedCalculator - Syntax Error");
		end

		--start matching
		if StringManager.startsWith(sRemainder, 'max') then
			bRecognizedRmndr = true;
			local nMaxMod;
			if string.match(sRemainder, '%)$') then
				local sRmndrRemainder = sRemainder:gsub('^max%s*%(', '');
				sRmndrRemainder = sRmndrRemainder:gsub('%s*%)$', '');
				if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
				local nRmndrRemainder = tonumber(sRmndrRemainder);
				if nRmndrRemainder then
					nMaxMod = nRmndrRemainder
				else
					Debug.console("WalkThisWay.speedCalculator - Syntax Error. Try SPEED: max(5)");
				end
				if nMod then
					sRemainder = ''
				end
			else
				nMaxMod = nMod
				nMod = nil
			end
			if nSpeedMax then
				if nMaxMod < nSpeedMax then
					nSpeedMax = math.floor(nMaxMod);
					if bDebug then Debug.console("nSpeedMax = " .. tostring(nSpeedMax)) end
				end
			else
				nSpeedMax = math.floor(nMaxMod);
				if bDebug then Debug.console("nSpeedMax = " .. tostring(nSpeedMax)) end
			end
		end
		if sRemainder == "difficult" then
			bRecognizedRmndr = true;
			bDifficult = true;
			if bDebug then Debug.console("bDifficult = true") end
		end
		if (sRemainder == "half" or sRemainder == "halved") then
			bRecognizedRmndr = true;
			nHalved = nHalved + 1;
		end
		if (sRemainder == "double" or sRemainder == "doubled") then
			bRecognizedRmndr = true;
			nDoubled = nDoubled + 1;
		end
		if StringManager.startsWith(sRemainder, 'type') then
			bRecognizedRmndr = true;
			if not string.match(sRemainder, '%)$') then
				Debug.console("WalkThisWay.speedCalculator - Syntax error. Try SPEED: type(fly)");
			else
				local sType = nil;
				if nMod then
					if nMod <= 0 then
						Debug.console("WalkThisWay.speedCalculator - Syntax Error");
					else
						local sRmndrRemainder = sRemainder:gsub('^type%s*%(', '');
						sType = sRmndrRemainder:gsub('%)$', '');
						if bDebug then Debug.console("sType = " .. tostring(sType)) end
						local sTypeLower = string.lower(sType);
						local sTypeFly = string.match(sTypeLower, 'fly')
						local sTypeHover = string.match(sTypeLower, 'hover')
						local bFound = false;
						for _,v in ipairs(tFGSpeedNew) do
							local vTypeLower = string.lower(v.type);
							if sTypeFly then
								if string.match(vTypeLower, 'fly') then
									bFound = true;
									if (nHover == 1) or sTypeHover then
										v.type = 'Fly (hover)'
									end
								end
							else
								if vTypeLower == sTypeLower then
									bFound = true;
								end
							end
							if bFound then v.velocity = nMod end
						end
						if not bFound then
							local tSpdRcrd = {};
							tSpdRcrd['type'] = sType;
							tSpdRcrd['velocity'] = nMod;
							table.insert(tFGSpeedNew, tSpdRcrd);
						end
					end
					nMod = nil;
				else
					if not sType then
						local sRmndrRemainder = sRemainder:gsub('^type%s*%(', '');
						sType = sRmndrRemainder:gsub('%s*%)$', '');
						if bDebug then Debug.console("sType = " .. tostring(sType)) end
					end
					if string.match(sType, '^%-') then
						local sRemoveType = string.sub(sType, 2)
						if bDebug then Debug.console("sRemoveType = " .. tostring(sRemoveType)) end
						local sRemoveTypeLower = string.lower(sRemoveType);
						local tCheckFGSpdTable = tFGSpeedNew;
						for k,v in ipairs(tCheckFGSpdTable) do
							local vTypeLower = string.lower(v.type);
							if vTypeLower == sRemoveTypeLower then
								table.remove(tFGSpeedNew, k)
							end
						end
					else
						if bDebug then Debug.console("no minus found in sType") end
						local sTypeLower = string.lower(sType);
						local bFound = false
						for _,v in ipairs(tFGSpeedNew) do
							local vTypeLower = string.lower(v.type);
							if vTypeLower == sTypeLower then
								bFound = true
							end
						end
						if not bFound then
							local tSpdRcrd = {}
							tSpdRcrd['type'] = sType;
							table.insert(tFGSpeedNew, tSpdRcrd)
						end
					end
				end
			end
		end
		if StringManager.startsWith(sRemainder, 'inc') then
			bRecognizedRmndr = true;
			if string.match(sRemainder, '%)$') then
				if nMod then
					Debug.console("WalkThisWay.speedCalculator - Syntax Error");
				else
					local sRmndrRemainder = sRemainder:gsub('^inc%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
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
		if StringManager.startsWith(sRemainder, 'dec') then
			bRecognizedRmndr = true;
			if string.match(sRemainder, '%)$') then
				if nMod then
					Debug.console("WalkThisWay.speedCalculator - Syntax Error");
				else
					local sRmndrRemainder = sRemainder:gsub('^dec%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
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
		if not bRecognizedRmndr and sRemainder ~= '' then
			Debug.console("WalkThisWay.speedCalculator - Syntax Error")
		end
		if nMod then
			local sNMod = tostring(nMod)
			if string.match(sNMod, '^%-') then
				if bDebug then Debug.console("dec detected") end
				nSpeedMod = nSpeedMod + nMod;
			else
				table.insert(tRebase, nMod)
			end
		end
	end

	if bDebug then Debug.console("nSpeedMod = " .. tostring(nSpeedMod)) end

	if bDifficult then nHalved = nHalved + 1 end
	if nDoubled > 0 then
		if nHalved > 0 then
			if bDebug then Debug.console("nDoubled & nHalved") end
			local nDoubledOrigin = nDoubled;
			local NHalvedOrigin = nHalved;
			nDoubled = nDoubled - NHalvedOrigin;
			nHalved = nHalved - nDoubledOrigin;
		end
	end

	for k,tSpdRcrd in ipairs(tFGSpeedNew) do
		local nFGSpeed = tSpdRcrd['velocity'];
		local nFGSpeedNew = nFGSpeed;
		if not nFGSpeedNew then
			for _,v in ipairs(tFGSpeedNew) do
				if v.type == 'walk' or v.type == '' then
					nFGSpeedNew = v.velocity
				end
			end
			if not nFGSpeedNew then nFGSpeedNew = tFGSpeedNew[1].velocity end
		end
		for k,v in ipairs(tRebase) do
			if k > 1 then
				if (nFGSpeedNew < nFGSpeed) or (v < nFGSpeed) then
					if v < nFGSpeedNew then
						nFGSpeedNew = v;
					end
				else
					if v > nFGSpeedNew then
						nFGSpeedNew = v;
					end
				end
			else
				nFGSpeedNew = v;
			end
			if bDebug then Debug.console("nFGSpeedNew = " .. tostring(nFGSpeedNew)) end
		end
		if bDebug then Debug.console("nFGSpeedNew = " .. tostring(nFGSpeedNew)) end

		local nSpeedFinal = nFGSpeedNew + nSpeedMod;
		if bDebug then Debug.console("nSpeedFinal = " .. tostring(nSpeedFinal)) end
		if nSpeedFinal < 0 then
			tFGSpeedNew[k].velocity = '0'
		else
			local nDoubledLocal = nDoubled
			local nHalvedLocal = nHalved
			while nDoubledLocal > 0 do
				if bDebug then Debug.console("nDoubledLocal > 0") end
				nSpeedFinal = nSpeedFinal * 2;
				nDoubledLocal = nDoubledLocal - 1;
			end
			while nHalvedLocal > 0 do
				if bDebug then Debug.console("nHalvedLocal > 0") end
				nSpeedFinal = nSpeedFinal / 2;
				nHalvedLocal = nHalvedLocal - 1;
			end
			--nSpeedFinal = math.floor(nSpeedFinal);
			if bDebug then Debug.console("nSpeedFinal = " .. tostring(nSpeedFinal)) end
			if bDebug then Debug.console("nSpeedMax = " .. tostring(nSpeedMax)) end
			if nSpeedMax then
				if nSpeedFinal > nSpeedMax then
					nSpeedFinal = nSpeedMax;
				end
			end
			tFGSpeedNew[k].velocity = tostring(nSpeedFinal);
		end
	end

	local sUnitsPrefer = OptionsManager.getOption('DDLU');
	local nConvFactor = 1;
	if sLngthUnits ~= sUnitsPrefer then
		nConvFactor = getConversionFactor(sLngthUnits, sUnitsPrefer);
		if not nConvFactor then
			nConvFactor = 1;
		end
	end
	local sReturn;
	for k,tSpdRcrd in ipairs(tFGSpeedNew) do
		tSpdRcrd.velocity = tSpdRcrd.velocity * nConvFactor
		if sUnitsPrefer == 'ft.' then
			tSpdRcrd.velocity = tSpdRcrd.velocity / 5;
			tSpdRcrd.velocity = math.floor(tSpdRcrd.velocity);
			tSpdRcrd.velocity = tSpdRcrd.velocity * 5;
		else
			if sUnitsPrefer ~= 'm' then
				tSpdRcrd.velocity = math.floor(tSpdRcrd.velocity);
			end
		end

		local sVelWithUnits = tostring(tSpdRcrd.velocity) .. ' ' .. sUnitsPrefer
		if tSpdRcrd.type == '' or tSpdRcrd.type == 'walk' then
			if k == 1 then
				sReturn = sVelWithUnits
			else
				sReturn = sVelWithUnits .. '; ' .. sReturn
			end
		else
			local sQualifier = string.match(tSpdRcrd.type, '%s*%(%s*%g*%s*%)%s*$');
			if sQualifier then
				local sTypeSansQual = string.gsub(tSpdRcrd.type, '%s*%(%s*%g*%s*%)%s*$', '');
				sReturn = sReturn .. '; ' .. sTypeSansQual .. ' ' .. sVelWithUnits .. ' ' .. sQualifier
			else
				sReturn = sReturn .. '; ' .. tSpdRcrd.type .. ' ' .. sVelWithUnits
			end
		end
	end
	sReturn = StringManager.strip(sReturn)
	return sReturn;
end
-- luacheck: pop

--option handler to re-run this if changing DDCU
function parseBaseSpeed(nodeCT)
	if not nodeCT then
		Debug.console("WalkThisWay.parseBaseSpeed - not nodeCT");
		return;
	end
	if not Session.IsHost then
		Debug.console("WalkThisWay.parseBaseSpeed - not host");
		return;
	end

	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	if not DB.getValue(nodeCTWtW, 'hover') then
		if string.match(string.lower(sFGSpeed), 'hover') then
			DB.setValue(nodeCTWtW, 'hover', 'number', 1);
		else
			DB.setValue(nodeCTWtW, 'hover', 'number', 0);
		end
	end

	local nodeFGSpeed = DB.getChild(nodeCTWtW, 'FGSpeed');
	if not nodeFGSpeed then
		local sFGSpeed = DB.getValue(nodeCT, 'speed')
		if not sFGSpeed then
			Debug.console("WalkThisWay.speedCalculator - no base speed found");
			sFGSpeed = '30 ft.'
		end
		nodeFGSpeed = DB.createChild(nodeCTWtW, 'FGSpeed');
		local aSpdTypeSplit,_ = StringManager.split(sFGSpeed, ',;', true)
		local sLngthUnits = '';
		local sUnitsGave = OptionsManager.getOption('DDCU');
		for _,sSpdTypeSplit in ipairs(aSpdTypeSplit) do
			local nodeSpeedRcrd = DB.createChild(nodeFGSpeed);
			local sVelocity = string.match(sSpdTypeSplit, '%d+');
			local sRemainder = string.gsub(sSpdTypeSplit, '%d+', '');
			local sType;
			local sStripPattern;
			if sLngthUnits == '' then
				sLngthUnits = string.match(sSpdTypeSplit, '%a%a?%.');
				if not sLngthUnits then sLngthUnits = sUnitsGave end
			end
			sStripPattern = string.gsub(sLngthUnits, '%.', '');
			sStripPattern = sStripPattern .. '%.';
			sType = string.gsub(sRemainder, sStripPattern, '');
			sType = StringManager.strip(sType);
			if sType == '' then sType = 'walk' end
			DB.setValue(nodeSpeedRcrd, 'velocity', 'number', sVelocity);
			DB.setValue(nodeSpeedRcrd, 'type', 'string', sType);
		end
		if sLngthUnits == 'ft' then sLngthUnits = 'ft.' end
		if sLngthUnits == 'm.' then sLngthUnits = 'm' end
		local bConverted = false;
		if sLngthUnits ~= sUnitsGave then
			local nConvFactor = getConversionFactor(sLngthUnits, sUnitsGave);
			if nConvFactor then
				for _,v in ipairs(tFGSpeed) do
					v.velocity = v.velocity * nConvFactor;
				end
				bConverted = true;
			end
		end
		if bConverted then
			sLngthUnits = sUnitsGave;
		end
		DB.setValue(nodeCTWtW, 'units', 'string', sLngthUnits);
		return true;
	end
	return;
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
		if WtWCommon.hasEffectFindString(nodeCT, "Exhausted; Speed Halved", false, false, true) then
			nHalved = nHalved + 1;
		end
		local sExhaustStack = WtWCommon.hasEffectFindString(nodeCT, "Exhausted; Speed %-%d+ %(info only%)", false, false, false, true);
		Debug.console("sExhaustStack = " .. tostring(sExhaustStack))
		if sExhaustStack then
			local sExhaustStack = sExhaustStack:gsub('^Exhausted; Speed %-', '');
			Debug.console("sExhaustStack = " .. tostring(sExhaustStack))
			local sExhaustStack = sExhaustStack:gsub('%s*%(%s*info only%s*%)$', '');
			Debug.console("sExhaustStack = " .. tostring(sExhaustStack))
			local nExhaustSpd = tonumber(sExhaustStack);
			if nExhaustSpd then
				nSpeedMod = nSpeedMod - nExhaustSpd;
			end
		end
	end

	local bReturn = false
	if nDoubled > 0 then
		if nHalved > 0 then
			--Debug.console("nDoubled & nHalved")
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
				return true
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Dead") then
				return true
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Paralyzed") then
				return true
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Dying") then
				return true
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Immobilized") then
				return true
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Petrified") then
				return true
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Restrained") then
				return true
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Grabbed") then
				return true
			elseif EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Stunned") then
				return true
			elseif WtWCommon.hasEffectFindString(nodeCT, "SPEED%s*:?%s*none", false, true) then
				return true
			else
				return false
			end
		else
			if EffectManager.hasCondition(nodeCT, "Unconscious") then
				return true
			elseif WtWCommon.hasEffectFindString(nodeCT, "SPEED%s*:?%s*none", false, true) then
				return true
			else
				return false
			end
		end
	else
		if EffectManager5E.hasEffectCondition(nodeCT, "Grappled") then
			return true
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Paralyzed") then
			return true
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Petrified") then
			return true
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Restrained") then
			return true
		elseif EffectManager5E.hasEffectCondition(nodeCT, "Unconscious") then
			return true
		elseif EffectManager5E.hasEffectCondition(nodeCT, "DEATH") then
			return true
		elseif WtWCommon.hasEffectFindString(nodeCT, "Speed%s*:?%s*0", false, true) then
			return true
		elseif WtWCommon.hasEffectFindString(nodeCT, "SPEED%s*:?%s*none", false, true) then
			return true
		else
			return false
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
	--called by updated inventory
	--root.charsheet.id-00002.inventorylist.id-00001
		--carried = 2 --means equipped
		--<strength type="string">Str 13</strength>
	--root.combattracker.list.id-00003.inventorylist.id-00001
		--carried = 2 --means equipped
		--<strength type="string">Str 13</strength>
--end

function checkProne(nodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	if not nodeCT then
		return;
	end

	--local rCurrent = ActorManager.resolveActor(nodeCT);
	--local rSource = ActorManager.getCTNode(rCurrent);

	if Session.RulesetName ~= "5E" then
		if EffectManagerPFRPG2 then
			if not EffectManagerPFRPG2.hasEffectCondition(nodeCT, "Prone") then
				return false
			elseif hasRoot(nodeCT) then
				return false
			elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", false, true) then
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
			elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", false, true) then
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
		elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", false, true) then
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
		Debug.console("WalkThisWay.checkHideousLaughter - not rActor")
		return
	end
	local bClauseExceptFound = false;
	local nMatch = 0;
	local sClause = "Tasha's Hideous Laughter"
		-- should return true, but only if it's not clause1
	local sClause1 = "Tasha's Hideous Laughter; Prone"
		-- should return false, but only if none of the other trues are present
		-- and also if the only sClause is the one contained within sClause1
	local sClause2 = "Tasha's Hideous Laughter (C); Prone; Incapacitated"
		-- should return true, regardless of other clauses
		-- starts with clause
		-- Team Twohy with ongoing save extension
	local sClause3 = "Tasha's Hideous Laughter; Incapacitated"
		-- should return true, regardless of other clauses
		-- whole clause
		-- Team Twohy without ongoing save extension
--	local sClause4 = "Tasha's Hideous Laughter (C)"
		-- should return false, if all other clauses are not found
		-- whole clause
		-- Team Twohy without ongoing save extension
		-- lucky here. This one is a last check anyway, and it doesn't hit with any of the others.
	local sClause5 = "Tasha's Hideous Laughter; (C)"
		-- should return false, if clauses 0, 2, or 3 are not present
		-- should behave same as clause1
		-- whole clause
		-- 5eAE with self concentration

	if WtWCommon.hasEffectFindString(rActor, sClause3, true) then
		-- Debug.console("sClause3 found, returning true")
		return true
	end

	if WtWCommon.hasEffectFindString(rActor, sClause2, false, false, true) then
		-- Debug.console("sClause2 found, returning true")
		return true
	end

	local hasClause1 = WtWCommon.hasEffectFindString(rActor, sClause1, true)
	local hasClause5 = WtWCommon.hasEffectFindString(rActor, sClause5, true)
	if hasClause1 or hasClause5 then
		bClauseExceptFound = true
		nMatch = nMatch + 1
		-- Debug.console("bClauseExceptFound & nMatch = " .. tostring(nMatch))
	elseif WtWCommon.hasEffectFindString(rActor, sClause, false, true) then
		nMatch = nMatch + 1
		-- Debug.console("has sClause & nMatch = " .. tostring(nMatch))
	end
	if hasClause1 and hasClause5 then
		nMatch = nMatch - 1
		-- Debug.console("Both found & nMatch = " .. tostring(nMatch))
	end

	if EffectManager5E.hasEffect(rActor, sClause) then
		if not bClauseExceptFound or nMatch > 1 then
			-- Debug.console("EffectManager5E & last check positive ... returning true")
			return true;
		end
	end
	-- Debug.console("All hideouslaughter checks failed - Default return false")
	return false;
end

function setPQvalue(sName)
	local nodeWTW = DB.createNode('WalkThisWay');
--	DB.setPublic(nodeWTW, true) --appears to be the default
	local nodePQ = DB.getChild(nodeWTW, 'proneQuery')
	if not nodePQ then
		nodePQ = DB.createChild(nodeWTW, 'proneQuery', 'string');
	end
	local sMessage = tostring(sName) .. ' is prone.'
	DB.setValue(nodeWTW, 'proneQuery', 'string', sMessage)
	return nodePQ
end

function delWTWdataChild(sChildNode)
	local nodeWTW = DB.findNode('WalkThisWay');
	if not nodeWTW then
		return true
	end
	local nodePQ = DB.getChild(nodeWTW, sChildNode)
	if not nodePQ then
		return true
	end
	return DB.deleteNode(nodePQ)
end

function openSpeedWindow(nodeCT)
	local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
	local rActor = ActorManager.resolveActor(nodeCT);
	DB.setValue(nodeCTWtW, 'actorname', 'string', tostring(rActor.sName));
	local sCurrentSpeed = DB.getValue(nodeCTWtW, 'currentSpeed');
	if not sCurrentSpeed then
		local nFGSpeed = DB.getValue(nodeCT, 'speed');
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nFGSpeed));
	end
	Interface.openWindow('speed_window', nodeCTWtW);
end

function proneWindow(nodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	if not Session.IsHost then
		return;
	end

	local rSource = ActorManager.resolveActor(nodeCT);
	local sOwner = WtWCommon.getControllingClient(nodeCT);

	if OptionsManager.isOption('AOSW', 'on') then
		openSpeedWindow(nodeCT)
	end

	if not checkProne(rSource) then
		return;
	end

	if sOwner then
		queryClient(nodeCT)
		return;
	else
		if rSource.sName then
			setPQvalue(rSource.sName)
		end
		openProneWindow();
	end
end

function closeAllProneWindows(nodeCT)
	closeProneWindow();
	if WtWCommon.getControllingClient(nodeCT) then
		sendCloseWindowCmd(nodeCT)
	end
end

function openProneWindow()
	if OptionsManager.isOption('WTWON', 'off') or OptionsManager.isOption('WTWONPLR', 'off') then
		return;
	end
	if Session.IsHost and OptionsManager.isOption('WTWONDM', 'off') then
		return;
	end
	local datasource = 'WalkThisWay'
	if Session.RulesetName == '5E' then
		Interface.openWindow('prone_query_small', datasource);
	elseif Session.RulesetName == "PFRPG2" then
		Interface.openWindow('prone_query_pfrpg2', datasource);
	else
		Interface.openWindow('prone_query_not5e', datasource);
	end
end

function closeProneWindow()
	local datasource = 'WalkThisWay'
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
	delWTWdataChild('proneQuery')
end

function standUp()
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	local rCurrent = ActorManager.resolveActor(CombatManager.getActiveCT());
	local rSource = ActorManager.getCTNode(rCurrent);
	local sFGSpeed = DB.getValue(rSource, 'speed');

	local tFGSpeed = {};
	local nFGSpeedCnt = 0
	for nMatch in string.gmatch(sFGSpeed, '%d+') do
		nFGSpeedCnt = nFGSpeedCnt + 1;
		tFGSpeed[nFGSpeedCnt] = nMatch;
	end
	local nFGSpeed;
	local nHalfBase;
	if not sFGSpeed or (nFGSpeedCnt > 1) then
		nHalfBase = 'halfbase';
	else
		nFGSpeed = tonumber(tFGSpeed[1]);
		nHalfBase = math.floor(nFGSpeed / 2);
	end
	local sStoodUp = 'Stood Up; SPEED: change(-' .. tostring(nHalfBase) .. ')';

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
			setPQvalue(rSource.sName)
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

function handleProneQueryClient(msgOOB) -- luacheck: ignore 212
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	openProneWindow();
end
function handleCloseProneQuery(msgOOB) -- luacheck: ignore 212
	closeProneWindow()
end