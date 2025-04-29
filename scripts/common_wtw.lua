-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals checkBetterGoldPurity hasEffectFindString removeEffectClause handleApplyHostCommands
-- luacheck: globals notifyApplyHostCommands getRootCommander getControllingClient getEffectName cleanString
-- luacheck: globals getEffectsByTypeWtW processConditional conditionalFail conditionalSuccess hasExtension
-- luacheck: globals hasEffectClause hasRoot getEffectsBonusLightly getEffectsBonusByTypeLightly
-- luacheck: globals convNumToIdNodeName roundNumber getVisCtEntries handlePullMoveData
-- luacheck: globals getPreference registerPreference handlePrefChange requestPref handlePrefRegistration
-- luacheck: globals sendPrefRegistration onIdentityActivationWtW getConversionFactor getAllImageWindows

OOB_MSGTYPE_APPLYHCMDS = "applyhcmds";
OOB_MSGTYPE_REGPREF = 'regpreference';
OOB_MSGTYPE_REQPREF = 'request_preference';
local _sBetterGoldPurity = '';
local tExtensions = {};
local aExceptionTags = {'SHAREDMG', 'DMGMULT', 'HEALMULT', 'HEALEDMULT', 'ABSORB'};
local aExceptionDescriptors = {'steal', 'stealtemp'};
local tClientPrefs = {};
--local BceEffectManager;

local aEffectVarMap = {
	["sName"] = { sDBType = "string", sDBField = "label" },
	["nGMOnly"] = { sDBType = "number", sDBField = "isgmonly" },
	["sSource"] = { sDBType = "string", sDBField = "source_name", bClearOnUntargetedDrop = true },
	["sTarget"] = { sDBType = "string", bClearOnUntargetedDrop = true },
	["nDuration"] = { sDBType = "number", sDBField = "duration", vDBDefault = 1, sDisplay = "[D: %d]" },
	["nInit"] = { sDBType = "number", sDBField = "init", sSourceChangeSet = "initresult"
		, bClearOnUntargetedDrop = true
	},
	["sApply"] = { sDBType = "string", sDBField = "apply", sDisplay = "[%s]"},
	["sChangeState"] = { sDBType = "string", sDBField = "changestate" }
};

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYHCMDS, handleApplyHostCommands);
	if Session.RulesetName == "5E" then
		OptionsManager.registerOptionData({	sKey = 'DDLU', bLocal = true,
			tCustom = { labelsres = "option_val_tiles|option_val_meters", values = "tiles|m",
				baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
			}
		});
	else
		OptionsManager.registerOptionData({	sKey = 'DDLU', bLocal = true,
			tCustom = { labelsres = "option_val_meters", values = "m",
				baselabelres = "option_val_feet", baseval = "ft.", default = "ft."
			}
		});
	end
	OptionsManager.registerCallback('DDLU', handlePrefChange);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_REGPREF, handlePrefRegistration);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_REQPREF, sendPrefRegistration);
	if Session.IsHost then
		User.onIdentityActivation = onIdentityActivationWtW;
		--if BCEManager then BceEffectManager = BCEManager.getRulesetEffectManager() end
	end
end

function onTabletopInit()
	if CharacterListManagerBCE then
		_sBetterGoldPurity = checkBetterGoldPurity();
	end
end

-- Matches on the filname/foldername or on the name defined in the extension.xml
function hasExtension(sExtName)
	if not tExtensions[1] then tExtensions = Extension.getExtensions() end
	if not sExtName then return end
	for _,sExtension in ipairs(tExtensions) do
		if sExtension == sExtName then
			return true;
		end
	end
	return false;
end

function checkBetterGoldPurity()
	local sReturn;
	if EffectConditionalManagerDnDBCE then
		sReturn = 'gold'
	elseif BCEDnDManager then
		sReturn = 'pyrite'
	end

	return sReturn;
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
				if _sBetterGoldPurity == 'gold' and Session.RulesetName == "5E" then --luacheck: ignore 113
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
function hasEffectClause(rActor, sClause, rTarget, bTargetedOnly, bIgnoreEffectTargets)
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
				-- Handle conditionals
				local sOriginalLower = string.lower(rEffectComp.original);
				if _sBetterGoldPurity == 'gold' and Session.RulesetName == "5E" then --luacheck: ignore 113
					EffectManager5EBCE.processConditional(rActor, rTarget, v, rEffectComp, rConditionalHelper);
					-- Check for match
					if rConditionalHelper.bProcessEffect and string.match(sOriginalLower, sLowerClause) then
						if rConditionalHelper.bTargeted and not bIgnoreEffectTargets then
							if EffectManager.isEffectTarget(v, rTarget) then
								return true, sLabel, v;
							end
						else
							if not bTargetedOnly then
								return true, sLabel, v;
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
					if string.match(sOriginalLower, sLowerClause) then
						if bTargeted and not bIgnoreEffectTargets then
							if EffectManager.isEffectTarget(v, rTarget) then
								--if bReturnLabel then
									return true, sLabel, v;
								--else
								--	return true, sLabel, v;
								--end
							end
						else
							if not bTargetedOnly then
								--if bReturnLabel then
									return true, sLabel, v;
								--else
								--	return true, sLabel, v;
								--end
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
	--if not rActor then
	--	Debug.console("WtWCommon.getRootCommander - rActor doesn't exist");
	--	return;
	--end
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
	--if not nodeCT then
	--	Debug.console("WtWCommon.getControllingClient - not nodeCT");
	--	return;
	--end
	local sPCNode;
	local rActor = ActorManager.resolveActor(nodeCT);
	local sNPCowner;
	if ActorManager.isPC(nodeCT) then
		sPCNode = ActorManager.getCreatureNodeName(rActor);
	else
		sNPCowner = DB.getValue(nodeCT, 'NPCowner', '');
		if sNPCowner == '' then
			if Pets and Pets.isCohort(rActor) then
				sPCNode = getRootCommander(rActor);
			--elseif FriendZone and FriendZone.isCohort(rActor) then
			--	sPCNode = getRootCommander(rActor);
			end
		end
	end

	if sPCNode or sNPCowner then
		for _, value in pairs(User.getAllActiveIdentities()) do
			if sPCNode then
				if 'charsheet.' .. value == sPCNode then
					return User.getIdentityOwner(value);
				end
			end
			if sNPCowner then
				local sIDOwner = User.getIdentityOwner(value)
				if sIDOwner == sNPCowner then
					return sIDOwner;
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

function getEffectsByTypeWtW(rActor, sEffectType, _, rFilterActor, bTargetedOnly, bCaseSensitive)
	if not rActor then
		Debug.console("WtWCommon.getEffectsByTypeWtW - not rActor");
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
		elseif EffectManagerPFRPG2 then
			RulesetEffectManager = EffectManagerPFRPG2;
		elseif EffectManagerADND then
			RulesetEffectManager = EffectManagerADND;
		elseif EffectManagerSFRPG then
			RulesetEffectManager = EffectManagerSFRPG;
		elseif EffectManager35E then
			RulesetEffectManager = EffectManager35E;
		elseif EffectManager4E then
			RulesetEffectManager = EffectManager4E;
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
					return true, false, WtWCommon.getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*0%s*max$"
						, nil, false, true, true
					);
					if bHas then
						return true, false, WtWCommon.getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "^Speed%s*:%s*0$"
							, nil, false, true, true
						);
						if bHas then
							return true, false, WtWCommon.getEffectName(false, sLabel);
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
					return true, false, WtWCommon.getEffectName(false, sLabel);
				else
					bHas, sLabel = hasEffectClause(nodeCT, "^SPEED%s*:%s*0%s*max$"
						, nil, false, true, true
					);
					if bHas then
						return true, false, WtWCommon.getEffectName(false, sLabel);
					else
						bHas, sLabel = hasEffectClause(nodeCT, "^Speed%s*:%s*0$"
							, nil, false, true, true
						);
						if bHas then
							return true, false, WtWCommon.getEffectName(false, sLabel);
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

-- these have been modded to not 'touch' the effects' isActive status
function getEffectsBonusLightly(rActor, aEffectType, bModOnly, aFilter, rFilterActor, bTargetedOnly)
	if not rActor or not aEffectType then
		Debug.console("WtWCommon.getEffectsBonusLightly - not rActor or not aEffectType");
		if bModOnly then
			return 0, 0;
		end
		return {}, 0, 0;
	end

	-- MAKE BONUS TYPE INTO TABLE, IF NEEDED
	if type(aEffectType) ~= 'table' then
		aEffectType = {aEffectType};
	end

	-- START WITH AN EMPTY MODIFIER TOTAL
	local aTotalDice = {};
	local nTotalMod = 0;
	local nTotalPercent = 0;
	local bMax = false;
	local nEffectCount = 0;

	-- ITERATE THROUGH EACH BONUS TYPE
	local masterbonuses = {};
	local masterpenalties = {};
	for _, v in pairs(aEffectType) do
		-- GET THE MODIFIERS FOR THIS MODIFIER TYPE
		local effbonusbytype,nEffectSubCount = getEffectsBonusByTypeLightly(rActor, v, true, aFilter, rFilterActor
			, bTargetedOnly
		);

		-- ITERATE THROUGH THE MODIFIERS
		for k2, v2 in pairs(effbonusbytype) do
			-- IF MODIFIER TYPE IS UNTYPED, THEN APPEND TO TOTAL MODIFIER
			-- (SUPPORTS DICE)
			if k2 == '' or StringManager.contains(DataCommon.dmgtypes, k2) or k2 == 'all' then
				for _, v3 in pairs(v2.dice) do
					table.insert(aTotalDice, v3);
				end
				nTotalMod = nTotalMod + v2.mod;
				nTotalPercent = nTotalPercent + v2.nPercent;

				-- OTHERWISE, WE HAVE A NON-ENERGY MODIFIER TYPE, WHICH MEANS WE NEED TO INTEGRATE
				-- (IGNORE DICE, ONLY TAKE BIGGEST BONUS AND/OR PENALTY FOR EACH MODIFIER TYPE)
			else
				if v2.mod >= 0 then
					masterbonuses[k2].mod = math.max(v2.mod, masterbonuses[k2].mod or 0);
				elseif v2.mod < 0 then
					masterpenalties[k2].mod = math.min(v2.mod, masterpenalties[k2].mod or 0);
				end
				if v2.percent >= 0 then
					masterbonuses[k2].nPercent = math.max(v2.percent, masterbonuses[k2].nPercent or 0);
				elseif v2.percent < 0 then
					masterpenalties[k2].nPercent = math.min(v2.percent, masterpenalties[k2].nPercent or 0);
				end
			end
			if v2.bMax then
				bMax = true;
			end
		end

		-- ADD TO EFFECT COUNT
		nEffectCount = nEffectCount + nEffectSubCount;
	end

	-- ADD INTEGRATED BONUSES AND PENALTIES FOR NON-ENERGY TYPED MODIFIERS
	for _, v in pairs(masterbonuses) do
		nTotalMod = nTotalMod + v.mod;
		nTotalPercent = nTotalPercent + v.nPercent;
	end
	for _, v in pairs(masterpenalties) do
		nTotalMod = nTotalMod + v.mod;
		nTotalPercent = nTotalPercent + v.nPercent;
	end
	if bModOnly then
		return nTotalMod, nEffectCount, nTotalPercent;
	end
	return aTotalDice, nTotalMod, nEffectCount, nTotalPercent, bMax;
end
-- luacheck: push ignore 561
function getEffectsBonusByTypeLightly(rActor, aEffectType, bAddEmptyBonus, aFilter, rFilterActor, bTargetedOnly)
	if not rActor or not aEffectType then
		Debug.console("WtWCommon.getEffectsBonusByTypeLightly - not rActor or not aEffectType");
		return {}, 0;
	end

	-- MAKE BONUS TYPE INTO TABLE, IF NEEDED
	if type(aEffectType) ~= 'table' then
		aEffectType = {aEffectType};
	end

	-- PER EFFECT TYPE VARIABLES
	local results = {};
	local bonuses = {};
	local penalties = {};
	local nEffectCount = 0;

	for _, v in pairs(aEffectType) do
		-- LOOK FOR EFFECTS THAT MATCH BONUSTYPE
		local aEffectsByType = getEffectsByTypeWtW(rActor, v, aFilter, rFilterActor, bTargetedOnly);

		-- ITERATE THROUGH EFFECTS THAT MATCHED
		for _, v2 in pairs(aEffectsByType) do
			if not v2.nPercent then
				v2.nPercent = 0;
			end
			-- LOOK FOR ENERGY OR BONUS TYPES
			local dmg_type = nil;
			local mod_type = nil;
			for _, v3 in pairs(v2.remainder) do
				if StringManager.contains(DataCommon.dmgtypes, v3) or StringManager.contains(DataCommon.conditions
					, v3) or v3 == 'all'
				then
					dmg_type = v3;
					break;
				else
					if StringManager.contains(DataCommon.bonustypes, v3) then
						mod_type = v3;
						break;
					end
				end
			end
			if v2.mod % 1 ~= 0 then
				local rEffectComp = EffectManager.parseEffectCompSimple(v2.original);
				local bSkip = false;
				if not StringManager.contains(aExceptionTags, rEffectComp.type) then
					for _, sDescriptor in ipairs(rEffectComp.remainder) do
						if StringManager.contains(aExceptionDescriptors, sDescriptor) then
							bSkip = true;
							break
						end
					end
					if not bSkip then
						v2.nPercent = v2.mod;
						v2.mod = 0;
					end
				end
			end

			-- IF MODIFIER TYPE IS UNTYPED, THEN APPEND MODIFIERS
			-- (SUPPORTS DICE)
			if dmg_type or not mod_type then
				-- ADD EFFECT RESULTS
				local new_key = dmg_type or '';
				local new_results = results[new_key] or {dice = {}, mod = 0, remainder = {}, nPercent = 0};

				-- BUILD THE NEW RESULT
				for _, v3 in pairs(v2.dice) do
					table.insert(new_results.dice, v3);
				end
				if bAddEmptyBonus then
					new_results.mod = new_results.mod + v2.mod;
					new_results.nPercent = new_results.nPercent + v2.nPercent;
				else
					new_results.mod = math.max(new_results.mod, v2.mod);
					new_results.nPercent = math.max(new_results.nPercent, v2.nPercent);
				end
				for _, v3 in pairs(v2.remainder) do
					table.insert(new_results.remainder, v3);
				end
				new_results.bMax = v2.bMax;
				-- SET THE NEW DICE RESULTS BASED ON ENERGY TYPE
				results[new_key] = new_results;

				-- OTHERWISE, TRACK BONUSES AND PENALTIES BY MODIFIER TYPE
				-- (IGNORE DICE, ONLY TAKE BIGGEST BONUS AND/OR PENALTY FOR EACH MODIFIER TYPE)
			else
				local bStackable = StringManager.contains(DataCommon.stackablebonustypes, mod_type);
				if v2.mod >= 0 then
					bonuses[mod_type].bMax = v2.bMax;
					if bStackable then
						bonuses[mod_type].mod = (bonuses[mod_type] or 0) + v2.mod;
						bonuses[mod_type].nPercent = (bonuses[mod_type] or 0) + v2.nPercent;
					else
						bonuses[mod_type].mod = math.max(v2.mod, bonuses[mod_type].mod or 0);
						bonuses[mod_type].nPercent = math.max(v2.nPercent, bonuses[mod_type].nPercent or 0);
					end
				elseif v2.mod < 0 then
					penalties[mod_type].bMax = v2.bMax;
					if bStackable then
						penalties[mod_type].mod = (penalties[mod_type] or 0) + v2.mod;
						penalties[mod_type].nPercent = (penalties[mod_type] or 0) + v2.nPercent;
					else
						penalties[mod_type].mod = math.min(v2.mod, penalties[mod_type].mod or 0);
						penalties[mod_type].nPercent = math.min(v2.nPercent, penalties[mod_type].nPercent or 0);
					end
				end

			end

			-- INCREMENT EFFECT COUNT
			nEffectCount = nEffectCount + 1;
		end
	end

	-- COMBINE BONUSES AND PENALTIES FOR NON-ENERGY TYPED MODIFIERS
	for k2, v2 in pairs(bonuses) do
		if not v2.nPercent then
			v2.nPercent = 0;
		end
		results[k2].bMax = v2.bMax
		if results[k2] then
			results[k2].mod = results[k2].mod + v2.mod;
			results[k2].nPercent = results[k2].nPercent + v2.nPercent;
		else
			results[k2] = {dice = {}, mod = v2.mod, remainder = {}, v2.nPercent};
		end
	end
	for k2, v2 in pairs(penalties) do
		if not v2.nPercent then
			v2.nPercent = 0;
		end
		results[k2].bMax = v2.bMax
		if results[k2] then
			results[k2].mod = results[k2].mod + v2.mod;
			results[k2].nPercent = results[k2].nPercent + v2.nPercent;
		else
			results[k2] = {dice = {}, mod = v2.mod, remainder = {}, nPercent = v2.nPercent};
		end
	end
	return results, nEffectCount;
end
-- luacheck: pop

function convNumToIdNodeName(nId)
	if not nId then
		Debug.console("WtWCommon.convNumToIdNodeName - not nId");
		return;
	end
	if not string.match(tostring(nId), '^id%-%d%d%d%d%d$') then
		nId = tonumber(nId);
		if not nId then
			Debug.console("MovementManager.convNumToIdNodeName - not nId")
			return;
		end
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
			Debug.console("WtWCommon.convNumToIdNodeName - not nReturn");
		else
			return nReturn;
		end
	end
end

function roundNumber(nInput, nPlaces, sUpDown)
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
		elseif sUpDown == 'down' then
			nWhole = math.floor(nInput);
		end
	else
		nWhole = math.floor(nInput);
		nDec = nInput - nWhole;
	end

	if nDec and nDec >= 0.5 then
		return (nMultiplier * (nWhole + 1)) / nPlaceAdj;
	end

	return (nMultiplier * nWhole) / nPlaceAdj;
end

function getConversionFactor(sCurrentUnits, sDesiredUnits)
	if not sCurrentUnits or not sDesiredUnits then
		Debug.console('WtWCommon.getConversionFactor - not sCurrentUnits or not sDesiredUnits');
		return 1;
	end
	if sCurrentUnits == sDesiredUnits then return 1 end
	if sCurrentUnits == 'ft.' then
		if sDesiredUnits == 'm' then
			return 0.3048;
		elseif sDesiredUnits == 'tiles' then
			--if Session.RulesetName == "5E" then
				return 0.2;
			--end
		elseif sDesiredUnits == 'mi.' then
			return 1 / 5280;
		else
			Debug.console('WtWCommon.getConversionFactor - Invalid units.');
			return 1;
		end
	elseif sCurrentUnits == 'm' then
		if sDesiredUnits == 'ft.' then
			return 1 / 0.3048;
		elseif sDesiredUnits == 'tiles' then
			--if Session.RulesetName == "5E" then
				return 1 / 1.5;
			--end
		elseif sDesiredUnits == 'mi.' then
			return 1 / 1609.344;
		else
			Debug.console('WtWCommon.getConversionFactor - Invalid units.');
			return 1;
		end
	elseif sCurrentUnits == 'tiles' then
		--if Session.RulesetName == "5E" then
			if sDesiredUnits == 'ft.' then
				return 5;
			elseif sDesiredUnits == 'm' then
				return 1.5;
			else
				Debug.console('WtWCommon.getConversionFactor - Invalid units.');
				return 1;
			end
		--end
	elseif sCurrentUnits == 'mph' then
		if sDesiredUnits == 'ft.' then
			return 8.8;
		elseif sDesiredUnits == 'm' then
			return 2.68224;
		elseif sDesiredUnits == 'tiles' then
			--if Session.RulesetName == "5E" then
				return 1.76;
			--end
		else
			Debug.console('WtWCommon.getConversionFactor - Invalid units.');
			return 1;
		end
	else
		Debug.console('WtWCommon.getConversionFactor - Invalid units.');
		return 1;
	end
end
function onIdentityActivationWtW(_, username, activated)
	if activated then requestPref(username) end

	if MovementManager then
		MovementManager.recordStepData();
	--	Comm.deliverOOBMessage({ type = OOB_MSGTYPE_CMD_PULL_MOVE_DATA }, username);
	end
end
function sendPrefRegistration(msgOOB, sPref) --luacheck: ignore 312
	local sOwner = Session.UserName;
	msgOOB = {};
	msgOOB['type'] = OOB_MSGTYPE_REGPREF;
	if not sPref then sPref = OptionsManager.getOption('DDLU') end
	msgOOB['sPref'] = sPref;
	msgOOB['sOwner'] = sOwner;
	Comm.deliverOOBMessage(msgOOB);
end
function handlePrefRegistration(msgOOB)
	if not Session.IsHost then return end

	registerPreference(msgOOB.sOwner, msgOOB.sPref);
	if SpeedManager then SpeedManager.recalcAllSpeeds(msgOOB.sOwner) end
end
function requestPref(sUser)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_REQPREF;
	Comm.deliverOOBMessage(msgOOB, sUser);
end
function handlePrefChange(sOptionKey)
	if Session.IsHost then
		if SpeedManager then SpeedManager.recalcAllSpeeds() end
	else
		sendPrefRegistration(nil, OptionsManager.getOption(sOptionKey));
	end
end
function registerPreference(sOwner, sPref)
	for k,_ in pairs(tClientPrefs) do
		if k == sOwner then
			tClientPrefs[k] = sPref;
			return;
		end
	end
	tClientPrefs[sOwner] = sPref;
end
function getPreference(sOwner)
	if not sOwner then return OptionsManager.getOption('DDLU') end

	for k,v in pairs(tClientPrefs) do
		if k == sOwner then
			return v;
		end
	end
	return nil;
end

function getVisCtEntries()
	local winCT = Interface.findWindow('combattracker_host', 'combattracker');
	if not winCT then
		winCT = Interface.openWindow('combattracker_host', 'combattracker');
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