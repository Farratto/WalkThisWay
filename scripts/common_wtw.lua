-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals checkBetterGoldPurity hasEffectFindString removeEffectClause handleApplyHostCommands
-- luacheck: globals notifyApplyHostCommands getRootCommander getControllingClient removeEffectCaseInsensitive
-- luacheck: globals getEffectsByTypeWtW processConditional conditionalFail conditionalSuccess

OOB_MSGTYPE_APPLYHCMDS = "applyhcmds";
_sBetterGoldPurity = ''; --luacheck: ignore 111

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

-- luacheck: push ignore 561
function hasEffectFindString(rActor, sString, bWholeMatch, bCaseInsensitive, bStartsWith, bReturnString, bDebug)
	-- defaults: case sensitive, not starts with, not whole match, not returnString & not debug
	-- bWholeMatch, if true, overrides bStartsWith
	-- Debug.console("hasEffectFindString called");
	if not rActor or not sString then
		Debug.console("WalkThisWay.hasEffectFindString - not rActor or not sString");
		return;
	end
	local aEffects;
	local tEffectCompParams;
	local sClause = sString;

	if bCaseInsensitive then
		sClause = string.lower(sString);
		if bDebug then Debug.console("sClause = " .. tostring(sClause)) end
	end

	if EffectManagerBCE then
		tEffectCompParams = EffectManagerBCE.getEffectCompType(sClause);
		-- Debug.console("tEffectCompParams = " .. tostring(tEffectCompParams))
	end
	aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
	-- Debug.console("aEffects = " .. tostring(aEffects));

	-- Iterate through each effect
	for _, v in pairs(aEffects) do
		local nActive = DB.getValue(v, 'isactive', 0);
		-- Debug.console("nActive = " .. tostring(nActive));
		local bGo = false;

		if EffectManagerBCE then
			local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
				(not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
				(tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));
			-- Debug.console("bActive = " .. tostring(bActive));

			if (not EffectManagerADND and (nActive ~= 0 or bActive)) or
			  (EffectManagerADND and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or
			  (EffectManagerADND.isValidCheckEffect(rActor, v)))) then
				bGo = true;
				-- Debug.console("EffectManagerADND results bGo = " .. tostring(bGo));
			end
		else
			if nActive ~= 0 then
				bGo = true;
				-- Debug.console("not EffectManagerBCE & bGo = " .. tostring(bGo));
			end
		end
		if bDebug then Debug.console("bGo = " .. tostring(bGo)) end

		if bGo then
			local sLabel = DB.getValue(v, 'label', '');
			local sFinalLabel = sLabel;
			if bCaseInsensitive then
				sFinalLabel = string.lower(sLabel);
				if bDebug then Debug.console("CaseInsensitive sFinalLabel = " .. tostring(sFinalLabel)) end
			end
			if bStartsWith and not bWholeMatch then
				sFinalLabel = string.sub(sLabel, 1, #sString);
				if bDebug then Debug.console("StartsWith sFinalLabel = " .. tostring(sFinalLabel)) end
			end
			if bDebug then Debug.console("sFinalLabel = " .. tostring(sFinalLabel)) end

			-- Check for match
			if bWholeMatch or bStartsWith then
				if sFinalLabel == sClause then
					if bDebug then Debug.console("wholeMatch or StartsWith found, returning true") end
					if bReturnString then
						return sLabel;
					else
						return true;
					end
				end
				if bDebug then Debug.console("bWholeMatch but no match") end
			else
				if bDebug then Debug.console("sClause = " .. tostring(sClause)) end
				local aFind = string.find(sFinalLabel, sClause)
				if bDebug then Debug.console("aFind = " .. tostring(aFind)) end
				if aFind then
					if bDebug then Debug.console("partial match found, returning true") end
					if bReturnString then
						return sLabel;
					else
						return true;
					end
				end
				if bDebug then Debug.console("not bWholeMatch but no match") end
			end

		end
	end

	if bDebug then Debug.console("All findstrings checks failed - Default return false") end
	return false;
end
-- luacheck: pop

-- luacheck: push ignore 561
function removeEffectClause(rActor, sClause, rTarget, bTargetedOnly, bIgnoreEffectTargets)
	if not rActor or not sClause then
		return
		Debug.console("WalkThisWay.removeEffectClause - not rActor or not sClause")
	end

	local sLowerClause = sClause:lower();
	local aMatch = {};
	local aEffects;
	local tEffectCompParams;

	if EffectManagerBCE then
		tEffectCompParams = EffectManagerBCE.getEffectCompType(sClause);
	end
	if TurboManager then
		aEffects = TurboManager.getMatchedEffects(rActor, sClause);
	else
		aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
	end
	-- Debug.console("aEffects = " .. tostring(aEffects))

	-- Iterate through each effect
	for _, v in pairs(aEffects) do
		local nActive = DB.getValue(v, 'isactive', 0);
		-- Debug.console("nActive = " .. tostring(nActive))
		local bGo = false
		local bTargeted
		local rConditionalHelper

		if EffectManagerBCE then
			rConditionalHelper = {bProcessEffect = true, aORStack = {}, aELSEStack = {}, bTargeted = false};
			-- Debug.console("rConditionalHelper = " .. tostring(rConditionalHelper))

			local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
				(not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
				(tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));
			-- Debug.console("bActive = " .. tostring(bActive))

			if (not EffectManagerADND and (nActive ~= 0 or bActive)) or
			  (EffectManagerADND and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or
			  (EffectManagerADND.isValidCheckEffect(rActor, v) or (rTarget and EffectManagerADND.isValidCheckEffect(rTarget, v))))) then
				bGo = true
				rConditionalHelper.bTargeted = EffectManager.isTargetedEffect(v);
				-- Debug.console("rConditionalHelper = " .. tostring(rConditionalHelper))
			end
		else
			if nActive ~= 0 then
				bGo = true
				bTargeted = EffectManager.isTargetedEffect(v);
			end
		end
		-- Debug.console("bGo = " .. tostring(bGo))
		-- Debug.console("bTargeted = " .. tostring(bTargeted))

		if bGo then
			-- Parse each effect label
			local sLabel = DB.getValue(v, 'label', '');
			-- Debug.console("sLabel = " .. tostring(sLabel))
			local aEffectComps = EffectManager.parseEffect(sLabel);
			-- Debug.console("aEffectComps = " .. tostring(aEffectComps))

			-- Iterate through each effect component looking for a type match
			local nMatch = 0;
			for kEffectComp, sEffectComp in ipairs(aEffectComps) do
				local rEffectComp
				if EffectManager5E then
					rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
				elseif EffectManagerPFRPG2 then
					rEffectComp = EffectManagerPFRPG2.parseEffectComp(sEffectComp);
				else
					rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
				end
				-- Debug.console("rEffectComp = " .. tostring(rEffectComp))
				-- Handle conditionals
				if _sBetterGoldPurity == 'gold' then --luacheck: ignore 113
					EffectManager5EBCE.processConditional(rActor, rTarget, v, rEffectComp, rConditionalHelper);
					-- Check for match
					if rConditionalHelper.bProcessEffect and rEffectComp.original:lower() == sLowerClause then
						if rConditionalHelper.bTargeted and not bIgnoreEffectTargets then
							if EffectManager.isEffectTarget(v, rTarget) then
								nMatch = kEffectComp;
							end
						elseif not bTargetedOnly then
							nMatch = kEffectComp;
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
								nMatch = kEffectComp;
							end
						elseif not bTargetedOnly then
							nMatch = kEffectComp;
						end
					end
				end
				-- Debug.console("nMatch = " .. tostring(nMatch))
			end

			-- If matched, then remove Clause
			if nMatch > 0 then
				-- Debug.console("nActive = " .. tostring(nActive))
				if nActive == 2 then
					DB.setValue(v, 'isactive', 'number', 1);
				else
					table.insert(aMatch, v);
					-- Debug.console("aMatch = " .. tostring(aMatch))
					if Session.IsHost then
						local nodeEffect = v
						local nodeActor = DB.getChild(nodeEffect, "...");
						if not nodeActor then
							ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " ( ... )");
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

	if #aMatch > 0 then
		-- Debug.console("return true")
		return true;
	end
	-- Debug.console("return false")
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
		-- EffectManager.removeEffect(rNodeCT, msgOOB.sEffect);
		removeEffectCaseInsensitive(rNodeCT, msgOOB.sEffect);
	else
		ChatManager.SystemMessage("[ERROR] manager_combat_wtw:handleApplyHostCommands; Unsupported iAction("
			.. tostring(iAction) .. ")"
		);
	end
end

function notifyApplyHostCommands(nodeCT, iAction, rValues)
	--Debug.console("manager_generic_actions:notifyApplyHostCommands called");

	local msgOOB = {};
	-- msgOOB.type
	--		OOB_MSGTYPE_APPLYHGACMDS
	-- msgOOB.sNodeCT - combat tracker entry to have the iAction applied - ex. combattracker.list.id-00010
	-- msgOOB.iAction
	--		0 - EffectManager.addEffect - add an effect
				-- (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
	--				 msgOOB[*] type,value - list of aEffectVarMap effects to add
	--		1 - EffectManager.removeEffect
	--				msgOOB.sEffect - text of effect to remove
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
		Debug.console("WalkThisWay.getRootCommander - rActor doesn't exist")
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
		Debug.console("WalkThisWay.getControllingClient - nodeCT doesn't exist")
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
					--return DB.getOwner(sPCNode);
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

function removeEffectCaseInsensitive(nodeCTEntry, sEffPatternToRemove)
	if not nodeCTEntry or ((sEffPatternToRemove or "") == "") then
		return;
	end

	local sLEffPatternToRemove = string.lower(sEffPatternToRemove)

	for _,nodeEffect in ipairs(DB.getChildList(nodeCTEntry, "effects")) do
		local sLgetValue = string.lower(DB.getValue(nodeEffect, "label", ""))
		if sLgetValue:match(sLEffPatternToRemove) then
			DB.deleteNode(nodeEffect);
			return;
		end
	end
end

function getEffectsByTypeWtW(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly, bCaseSensitive) --luacheck: ignore 212
	if not rActor then
		return;
	end
	local results = {};

	local aEffects;
	if TurboManager then
		aEffects = TurboManager.getMatchedEffects(rActor, sEffectType);
	else
		aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
	end

	-- Iterate through effects
	for _, v in pairs(aEffects) do
		-- Check active
		local nActive = DB.getValue(v, 'isactive', 0);
		local rConditionalHelper = {bProcessEffect = true, aORStack = {}, aELSEStack = {}, bTargeted = false};
		-- BCEManager.chat(v)
		if (not EffectManagerADND and nActive ~= 0) or
			(EffectManagerADND and ((EffectManagerADND.isValidCheckEffect(rActor, v) or
					(rFilterActor and EffectManagerADND.isValidCheckEffect(rFilterActor, v))))) then
			local sLabel = DB.getValue(v, 'label', '');
			-- IF COMPONENT WE ARE LOOKING FOR SUPPORTS TARGETS, THEN CHECK AGAINST OUR TARGET
			rConditionalHelper.bTargeted = EffectManager.isTargetedEffect(v);

			if not rConditionalHelper.bTargeted or EffectManager.isEffectTarget(v, rFilterActor) then
				local aEffectComps = EffectManager.parseEffect(sLabel);

				-- Look for type/subtype match
				for _, sEffectComp in ipairs(aEffectComps) do
					local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
					local rMatchTable = {};

					processConditional(rActor, rFilterActor, v, rEffectComp, rConditionalHelper);

					if rConditionalHelper.bProcessEffect then
						local comp_match = false;
						-- Check for match
						local sStartsWith = string.sub(sEffectComp, 1, #sEffectType);
						local sStartsWith = sStartsWith .. ':'

						local bPrelimMatch;
						if bCaseSensitive then
							if sStartsWith == sEffectType then
								bPrelimMatch = true;
							end
						else
							if string.lower(sStartsWith) == string.lower(sEffectType) then
								bPrelimMatch = true;
							end
						end
						if rEffectComp.type == sEffectType or rEffectComp.original == sEffectType or bPrelimMatch then
							-- Check effect targeting
							if bTargetedOnly and not rConditionalHelper.bTargeted then
								comp_match = false;
							else
								comp_match = true;
								--BCEManager.chat('Match')
							end
						end

						-- Match!
						if comp_match then
							--BCEManager.chat('Add: ', rEffectComp, sEffectType);
							if nActive == 1 then
								rMatchTable['clause'] = sEffectComp;
								rMatchTable['label'] = v;
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
        if rEffectComp.type == 'IF' or (EffectManagerUntrue and rEffectComp.type == 'IFN') then
            if not EffectManager5E.checkConditional(rActor, rEffect, rEffectComp.remainder) then
                conditionalFail(rConditionalHelper, rEffectComp);
            else
                conditionalSuccess(rConditionalHelper, rEffectComp);
            end
        elseif rEffectComp.type == 'IFT' or (EffectManagerUntrue and rEffectComp.type == 'IFTN') then
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