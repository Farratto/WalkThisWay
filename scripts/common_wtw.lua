-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals checkBetterGoldPurity hasEffectFindString removeEffectClause handleApplyHostCommands
-- luacheck: globals notifyApplyHostCommands getRootCommander getControllingClient getEffectName cleanString
-- luacheck: globals getEffectsByTypeWtW processConditional conditionalFail conditionalSuccess hasExtension
-- luacheck: globals hasEffectClause hasRoot

OOB_MSGTYPE_APPLYHCMDS = "applyhcmds";
local _sBetterGoldPurity = '';
local tExtensions = {};
fhasCondition = ''; --luacheck: ignore 111
fhasEffect = ''; --luacheck: ignore 111

local aEffectVarMap = {
	["sName"] = { sDBType = "string", sDBField = "label" },
	["nGMOnly"] = { sDBType = "number", sDBField = "isgmonly" },
	["sSource"] = { sDBType = "string", sDBField = "source_name", bClearOnUntargetedDrop = true },
	["sTarget"] = { sDBType = "string", bClearOnUntargetedDrop = true },
	["nDuration"] = { sDBType = "number", sDBField = "duration", vDBDefault = 1, sDisplay = "[D: %d]" },
	["nInit"] = { sDBType = "number", sDBField = "init", sSourceChangeSet = "initresult", bClearOnUntargetedDrop = true },
	["sApply"] = { sDBType = "string", sDBField = "apply", sDisplay = "[%s]"},
	["sChangeState"] = { sDBType = "string", sDBField = "changestate" } -- added by Farratto
};

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYHCMDS, handleApplyHostCommands);

	if Session.RulesetName ~= "5E" then
		if EffectManagerPFRPG2 then
			fhasCondition = EffectManagerPFRPG2.hasEffectCondition; --luacheck: ignore 111
			fhasEffect = EffectManagerPFRPG2.hasEffect; --luacheck: ignore 111
		else
			fhasCondition = EffectManager.hasCondition; --luacheck: ignore 111
			fhasEffect = EffectManager.hasEffect; --luacheck: ignore 111
		end
	else
		fhasCondition = EffectManager5E.hasEffectCondition; --luacheck: ignore 111
		fhasEffect = EffectManager5E.hasEffect; --luacheck: ignore 111
	end
	if EffectManager5EBCE then
		_sBetterGoldPurity = checkBetterGoldPurity(); --luacheck: ignore 111
	end

	if Session.IsHost then
		tExtensions = Extension.getExtensions(); --luacheck: ignore 111
	end
end

-- Matches on the filname/foldername or on the name defined in the extension.xml
function hasExtension(sExtName)
	for _,sExtension in ipairs(tExtensions) do --luacheck: ignore 113
		if sExtension == sExtName then
			return true;
		end
	end
	return false;
end

function checkBetterGoldPurity()
	local tExtensions = Extension.getExtensions()
	local sReturn
	for _,sExtension in ipairs(tExtensions) do
		if sExtension == 'BetterCombatEffects' then
			sReturn = 'pyrite'
		end
		if sExtension == 'BetterCombatEffectsGold' then
			sReturn = 'gold'
		end
	end
	return sReturn
end

function hasEffectFindString(rActor, sString, bCaseInsensitive, bReturnString, bReturnNode, bFindAll)
	-- DEFAULTS: case sensitive, not returnString, & not debug
	-- when using bCaseInsensitive, make use of [^%] instead of %uppercase
	if not rActor or not sString then
		Debug.console("WtWCommon.hasEffectFindString - not rActor or not sString");
		return;
	end
	local aEffects;
	local tEffectCompParams;
	local sClause = sString;

	if bCaseInsensitive then
		sClause = string.lower(sString);
	end

	if EffectManagerBCE then
		tEffectCompParams = EffectManagerBCE.getEffectCompType(sClause);
	end
	aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');

	local tResults = {};
	-- Iterate through each effect
	for _, v in pairs(aEffects) do
		local nActive = DB.getValue(v, 'isactive', 0);
		local bGo = false;
		local tResOne = {};

		if EffectManagerBCE then
			local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
				(not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
				(tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));

			if (not EffectManagerADND and (nActive ~= 0 or bActive)) or
			  (EffectManagerADND and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or
			  (EffectManagerADND.isValidCheckEffect(rActor, v)))) then
				bGo = true;
			end
		else
			if nActive ~= 0 then
				bGo = true;
			end
		end

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
	if tResults[1] then return tResults end

	return false;
end

-- luacheck: push ignore 561
function removeEffectClause(rActor, sClause, rTarget, bTargetedOnly, bIgnoreEffectTargets, bNoTurbo)
	if not rActor or not sClause then
		Debug.console("WtWCommon.removeEffectClause - not rActor or not sClause");
		return;
	end

	local sLowerClause = sClause:lower();
	local aMatch = {};
	local aEffects;
	local tEffectCompParams;

	if EffectManagerBCE then
		tEffectCompParams = EffectManagerBCE.getEffectCompType(sClause);
	end
	if TurboManager and not bNoTurbo then
		aEffects = TurboManager.getMatchedEffects(rActor, sClause);
	else
		aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
	end

	-- Iterate through each effect
	for _, v in pairs(aEffects) do
		local nActive = DB.getValue(v, 'isactive', 0);
		local bGo = false;
		local bTargeted;
		local rConditionalHelper;

		if EffectManagerBCE then
			rConditionalHelper = {bProcessEffect = true, aORStack = {}, aELSEStack = {}, bTargeted = false};

			local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
				(not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
				(tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));

			if (not EffectManagerADND and (nActive ~= 0 or bActive)) or
			  (EffectManagerADND and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or
			  (EffectManagerADND.isValidCheckEffect(rActor, v) or (rTarget and EffectManagerADND.isValidCheckEffect(rTarget, v))))) then
				bGo = true
				rConditionalHelper.bTargeted = EffectManager.isTargetedEffect(v);
			end
		else
			if nActive ~= 0 then
				bGo = true;
				bTargeted = EffectManager.isTargetedEffect(v);
			end
		end

		if bGo then
			-- Parse each effect label
			local sLabel = DB.getValue(v, 'label', '');
			local aEffectComps = EffectManager.parseEffect(sLabel);
			local nEffectComps = 0;

			-- Iterate through each effect component looking for a type match
			local tMatch = {};
			for kEffectComp, sEffectComp in ipairs(aEffectComps) do
				nEffectComps = nEffectComps + 1
				local rEffectComp
				if EffectManager5E then
					rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
				elseif EffectManagerPFRPG2 then
					rEffectComp = EffectManagerPFRPG2.parseEffectComp(sEffectComp);
				else
					rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
				end
				-- Handle conditionals
				if _sBetterGoldPurity == 'gold' then --luacheck: ignore 113
					EffectManager5EBCE.processConditional(rActor, rTarget, v, rEffectComp, rConditionalHelper);
					-- Check for match
					if rConditionalHelper.bProcessEffect and rEffectComp.original:lower() == sLowerClause then
						if rConditionalHelper.bTargeted and not bIgnoreEffectTargets then
							if EffectManager.isEffectTarget(v, rTarget) then
								table.insert(tMatch, 1, kEffectComp);
							end
						elseif not bTargetedOnly then
							table.insert(tMatch, 1, kEffectComp);
						end
					end
				else
					if EffectManager5E then
						-- Handle conditionals
						if rEffectComp.type == "IF" then
							if not EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
								break;
							end
						elseif rEffectComp.type == "IFT" then
							if not rTarget then
								break;
							end
							if not EffectManager5E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
								break;
							end
						end
					end
					-- Check for match
					if rEffectComp.original:lower() == sLowerClause then
						if bTargeted and not bIgnoreEffectTargets then
							if EffectManager.isEffectTarget(v, rTarget) then
								table.insert(tMatch, 1, kEffectComp);
							end
						elseif not bTargetedOnly then
							table.insert(tMatch, 1, kEffectComp);
						end
					end
				end
			end

			-- If matched, then remove Clause
			if tMatch[1] then
				if nEffectComps <= (#tMatch + 1) then
					table.insert(aMatch, v);
					if Session.IsHost then
						DB.deleteNode(v);
					else
						local nRepeats = #aEffectComps;
						while nRepeats > 0 do
							EffectManager.notifyExpire(v, nRepeats, true);
							nRepeats = nRepeats - 1
						end
					end
				elseif nActive == 2 then
					DB.setValue(v, 'isactive', 'number', 1);
				else
					for _,nMatch in ipairs(tMatch) do
						table.insert(aMatch, v);
						if Session.IsHost then
							local nodeEffect = v
							local nodeActor = DB.getChild(nodeEffect, "...");
							if not nodeActor then
								ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") ..
									" ( ... )"
								);
								return;
							end
							EffectManager.expireEffect(nodeActor, nodeEffect, tonumber(nMatch) or 0);
						else
							EffectManager.notifyExpire(v, nMatch, true);
						end
					end
				end
			end
		end
	end

	if #aMatch > 0 then
		return true;
	end
	return false;
end
-- luacheck: pop

-- luacheck: push ignore 561
function hasEffectClause(rActor, sClause, rTarget, bTargetedOnly, bIgnoreEffectTargets, bReturnLabel)
	-- when using pattern matching, make use of [^%] instead of %uppercase
	if not rActor or not sClause then
		Debug.console("WtWCommon.hasEffectClause - not rActor or not sClause");
		return;
	end

	local sLowerClause = sClause:lower();
	local tEffectCompParams;

	if EffectManagerBCE then
		tEffectCompParams = EffectManagerBCE.getEffectCompType(sClause);
	end
	local aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');

	-- Iterate through each effect
	for _, v in pairs(aEffects) do
		local nActive = DB.getValue(v, 'isactive', 0);
		local bGo = false;
		local bTargeted;
		local rConditionalHelper;

		if EffectManagerBCE then
			rConditionalHelper = {bProcessEffect = true, aORStack = {}, aELSEStack = {}, bTargeted = false};

			local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
				(not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
				(tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));

			if (not EffectManagerADND and (nActive ~= 0 or bActive)) or
			  (EffectManagerADND and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or
			  (EffectManagerADND.isValidCheckEffect(rActor, v) or (rTarget and EffectManagerADND.isValidCheckEffect(rTarget, v))))) then
				bGo = true;
				rConditionalHelper.bTargeted = EffectManager.isTargetedEffect(v);
			end
		else
			if nActive ~= 0 then
				bGo = true;
				bTargeted = EffectManager.isTargetedEffect(v);
			end
		end

		if bGo then
			-- Parse each effect label
			local sLabel = DB.getValue(v, 'label', '');
			local aEffectComps = EffectManager.parseEffect(sLabel);

			-- Iterate through each effect component looking for a type match
			for _, sEffectComp in ipairs(aEffectComps) do
				local rEffectComp;
				if EffectManager5E then
					rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
				elseif EffectManagerPFRPG2 then
					rEffectComp = EffectManagerPFRPG2.parseEffectComp(sEffectComp);
				else
					rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
				end
				local sOriginalLower = string.lower(rEffectComp.original);
				-- Handle conditionals
				if _sBetterGoldPurity == 'gold' then --luacheck: ignore 113
					EffectManager5EBCE.processConditional(rActor, rTarget, v, rEffectComp, rConditionalHelper);
					-- Check for match
					if rConditionalHelper.bProcessEffect and string.match(sOriginalLower, sLowerClause) then
						if rConditionalHelper.bTargeted and not bIgnoreEffectTargets then
							if EffectManager.isEffectTarget(v, rTarget) then
								if bReturnLabel then
									return true, sLabel
								else
									return true;
								end
							end
						elseif not bTargetedOnly then
							if bReturnLabel then
								return true, sLabel
							else
								return true;
							end
						end
					end
				else
					if EffectManager5E then
						-- Handle conditionals
						if rEffectComp.type == "IF" then
							if not EffectManager5E.checkConditional(rActor, v, rEffectComp.remainder) then
								break;
							end
						elseif rEffectComp.type == "IFT" then
							if not rTarget then
								break;
							end
							if not EffectManager5E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
								break;
							end
						end
					end
					-- Check for match
					local sOriginalLower = string.lower(rEffectComp.original);
					if string.match(sOriginalLower, sLowerClause) then
						if bTargeted and not bIgnoreEffectTargets then
							if EffectManager.isEffectTarget(v, rTarget) then
								if bReturnLabel then
									return true, sLabel
								else
									return true;
								end
							end
						elseif not bTargetedOnly then
							if bReturnLabel then
								return true, sLabel
							else
								return true;
							end
						end
					end
				end
			end
		end
	end
	return false;
end
-- luacheck: pop

function handleApplyHostCommands(msgOOB)
	local rNodeCT = DB.findNode(msgOOB.sNodeCT);
	local iAction = tonumber(msgOOB.iAction);

	-- Requesting the add effect action on host
	if iAction == 0 then
		-- add an effect (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
		local rEffect = {};
		for k,_ in pairs(msgOOB) do
			if aEffectVarMap[k] then
				if aEffectVarMap[k].sDBType == "number" then
					rEffect[k] = tonumber(msgOOB[k]) or 0;
				else
					rEffect[k] = msgOOB[k];
				end
			end
		end
		EffectManager.addEffect("", "", rNodeCT, rEffect, true);

	-- Requesting the remove effect action on host
	elseif iAction == 1 then
		-- remove an effect
		EffectManager.removeEffect(rNodeCT, msgOOB.sEffect);
		--removeEffectCaseInsensitive(rNodeCT, msgOOB.sEffect);
	else
		ChatManager.SystemMessage("[ERROR] manager_combat_wtw:handleApplyHostCommands; Unsupported iAction("
			.. tostring(iAction) .. ")"
		);
	end
end

function notifyApplyHostCommands(nodeCT, iAction, rValues)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYHCMDS;
	msgOOB.iAction = iAction;
	msgOOB.sNodeCT = DB.getPath(nodeCT);

	if msgOOB.iAction == 0 then
		for k,_ in pairs(rValues) do
			if aEffectVarMap[k] then
				if aEffectVarMap[k].sDBType == "number" then
					msgOOB[k] = rValues[k] or aEffectVarMap[k].vDBDefault or 0;
				else
					msgOOB[k] = rValues[k] or aEffectVarMap[k].vDBDefault or "";
				end
			end
		end
	elseif msgOOB.iAction == 1 then
		msgOOB.sEffect = rValues;
	end
	Comm.deliverOOBMessage(msgOOB, "");
end

---For a given cohort actor, determine the root character node that owns it
function getRootCommander(rActor)
	if not rActor then
		Debug.console("WtWCommon.getRootCommander - rActor doesn't exist")
		return
	end
	local sRecord = ActorManager.getCreatureNodeName(rActor);
	local sRecordSansModule = StringManager.split(sRecord, "@")[1];
	local aRecordPathSansModule = StringManager.split(sRecordSansModule, ".");
	if aRecordPathSansModule[1] and aRecordPathSansModule[2] then
		return aRecordPathSansModule[1] .. "." .. aRecordPathSansModule[2];
	end
	return nil;
end

--Returns nil for inactive identities and those owned by the GM
function getControllingClient(nodeCT)
	if not nodeCT then
		Debug.console("WtWCommon.getControllingClient - nodeCT doesn't exist")
		return
	end
	local sPCNode = nil;
	local rActor = ActorManager.resolveActor(nodeCT);
	local sNPCowner
	if ActorManager.isPC(rActor) then
		sPCNode = ActorManager.getCreatureNodeName(rActor);
	else
		sNPCowner = DB.getValue(nodeCT, "NPCowner", "");
		if sNPCowner == "" then
			if Pets and Pets.isCohort(rActor) then
				sPCNode = getRootCommander(rActor);
			else
				if FriendZone and FriendZone.isCohort(rActor) then
					sPCNode = getRootCommander(rActor);
				end
			end
		end
	end

	if sPCNode or sNPCowner then
		for _, value in pairs(User.getAllActiveIdentities()) do
			if sPCNode then
				if "charsheet." .. value == sPCNode then
					return User.getIdentityOwner(value)
				end
			end
			if sNPCowner then
				local sIDOwner = User.getIdentityOwner(value)
				if sIDOwner == sNPCowner then
					return sIDOwner
				end
			end
		end
	end
	return nil;
end

function cleanString(s)
	if not s then return end
	local sReturn = StringManager.strip(s);
	sReturn = string.gsub(sReturn, '^%s+', '');
	sReturn = string.gsub(sReturn, '%s+$', '');
	return sReturn;
end

function getEffectName(nodeEffect, sLabel)
	if not nodeEffect and not sLabel then return end
	if not sLabel then sLabel = DB.getValue(nodeEffect, 'label') end
	if not sLabel or sLabel == '' then return end
	local aClauses = StringManager.split(sLabel, ';');
	return cleanString(aClauses[1]);
end

--note: if using caseInsensitivity, use all uppercase for literal character matches.
function getEffectsByTypeWtW(rActor, sEffectType, _, rFilterActor, bTargetedOnly, bCaseSensitive)
	if not rActor then
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
			(EffectManagerADND and ((EffectManagerADND.isValidCheckEffect(rActor, v) or
					(rFilterActor and EffectManagerADND.isValidCheckEffect(rFilterActor, v))))) then
			local sLabel = DB.getValue(v, 'label', '');
			-- IF COMPONENT WE ARE LOOKING FOR SUPPORTS TARGETS, THEN CHECK AGAINST OUR TARGET
			rConditionalHelper.bTargeted = EffectManager.isTargetedEffect(v);

			if not rConditionalHelper.bTargeted or (rFilterActor and EffectManager.isEffectTarget(v, rFilterActor)) then
				local aEffectComps = EffectManager.parseEffect(sLabel);

				-- Look for type/subtype match
				for _, sEffectComp in ipairs(aEffectComps) do
					local rEffectComp;
					if EffectManager5E then
						rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
					elseif EffectManagerPFRPG2 then
						rEffectComp = EffectManagerPFRPG2.parseEffectComp(sEffectComp);
					else
						rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
					end
					local rMatchTable = {};

					processConditional(rActor, rFilterActor, v, rEffectComp, rConditionalHelper);

					if rConditionalHelper.bProcessEffect then
						local comp_match = false;
						-- Check for match
						local sEffectCompUpper = string.upper(tostring(sEffectComp));

						local bPrelimMatch;
						if bCaseSensitive then
							if string.match(sEffectComp, '^' .. sEffectType) then
								bPrelimMatch = true;
							end
						else
							if string.match(sEffectCompUpper, '^' .. sEffectType) then
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
								rMatchTable['clause'] = sEffectComp;
								if sLabel ~= '' then rMatchTable['label'] = sLabel end
								table.insert(results, rMatchTable);
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
		if rEffectComp.type == 'IF' or (bUntrueExt and rEffectComp.type == 'IFN') then
			if not EffectManager5E.checkConditional(rActor, rEffect, rEffectComp.remainder) then
				conditionalFail(rConditionalHelper, rEffectComp);
			else
				conditionalSuccess(rConditionalHelper, rEffectComp);
			end
		elseif rEffectComp.type == 'IFT' or (bUntrueExt and rEffectComp.type == 'IFTN') then
			if not rTarget then
				rConditionalHelper.bProcessEffect = false
			else
				if not EffectManager5E.checkConditional(rTarget, rEffect, rEffectComp.remainder, rActor) then
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
				local bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)"
					, nil, false, true, true
				);
				if bHas then
					return true, false, WtWCommon.getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max"
						, nil, false, true, true
					);
					if bHas then
						return true, false, WtWCommon.getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "Speed%s*:%s*0"
							, nil, false, true, true
						);
						if bHas then
							return true, false, WtWCommon.getEffectName(false, sLabel);
						else
							bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*none"
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
			if EffectManager.hasCondition(nodeCT, "Unconscious") then
				return true, false, 'Unconscious';
			else
				local bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)"
					, nil, false, true, true
				);
				if bHas then
					return true, false, getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max"
						, nil, false, true, true
					);
					if bHas then
						return true, false, getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "Speed%s*:%s*0"
							, nil, false, true, true
						);
						if bHas then
							return true, false, getEffectName(false, sLabel);
						else
							bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*none"
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
			local bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*max%s*%(%s*0%s*%)"
				, nil, false, true, true
			);
			if bHas then
				bReturn = true;
				sEffectName = getEffectName(false, sLabel);
			else
				bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*0%s*max"
					, nil, false, true, true
				);
				if bHas then
					bReturn = true;
					sEffectName = getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "Speed%s*:%s*0"
						, nil, false, true, true
					);
					if bHas then
						bReturn = true;
						sEffectName = getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "SPEED%s*:%s*none"
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
