--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- OOB identifier for source local processing that supports commands that need host privilege to execute
OOB_MSGTYPE_APPLYHCMDS = "applyhcmds";
OOB_MSGTYPE_PRONEQUERY = "oobpronequery";
OOB_MSGTYPE_CLOSEQUERY = "oobclosequery";

-- Because OOB messages need everything broken apart into individual pieces this is the key variable used to do that.
-- Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua
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
    OptionsManager.registerOption2('WTWON', false, 'option_Walk_this_Way', 'option_WtW_On',
                                   'option_entry_cycler', {
        labels = 'option_val_off',
        values = 'off',
        baselabel = 'option_val_on',
        baseval = 'on',
        default = 'on'
    });
    OptionsManager.registerOption2('WHOLEEFFECT', false, 'option_Walk_this_Way', 'option_WtW_Delete_Whole',
                                   'option_entry_cycler', {
        labels = 'option_val_on',
        values = 'on',
        baselabel = 'option_val_off',
        baseval = 'off',
        default = 'off'
    });
    OptionsManager.registerOption2('APCW', false, 'option_Walk_this_Way', 'option_WtW_Allow_Player_Choice',
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
        OptionsManager.registerOption2('WTWONDM', false, "option_Walk_this_Way", 'option_WtW_On_DM_Choice',
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
	    -- Register OOB message for source local processing that supports commands that need host privilege to execute
	    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYHCMDS, handleApplyHostCommands);
	    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSEQUERY, handleCloseProneQuery);
	end
end

function clientGetOption(sKey)
	if CampaignRegistry["Opt" .. sKey] then
		return CampaignRegistry["Opt" .. sKey];
	end
end

function checkProne(sourceNodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
	    return;
	end
    if not sourceNodeCT then
        return;
    end

    local rCurrent = ActorManager.resolveActor(sourceNodeCT);
    -- local rCurrent = ActorManager.resolveActor(CombatManager.getActiveCT());
    local rSource = ActorManager.getCTNode(rCurrent)

	if EffectManager5EBCE then
        if not EffectManager5EBCE.moddedHasEffect(rSource, "Prone", nil, false, true) then
            return false
        elseif EffectManager5EBCE.moddedHasEffect(rSource, "Grappled", nil, false, true) then
            return false
        elseif EffectManager5EBCE.moddedHasEffect(rSource, "Paralyzed", nil, false, true) then
            return false
        elseif EffectManager5EBCE.moddedHasEffect(rSource, "Petrified", nil, false, true) then
            return false
        elseif EffectManager5EBCE.moddedHasEffect(rSource, "Restrained", nil, false, true) then
            return false
        elseif EffectManager5EBCE.moddedHasEffect(rSource, "Unconscious", nil, false, true) then
            return false
        -- elseif EffectManager5EBCE.moddedHasEffect(rSource, "SPEED: none") then
		    -- Doesn't work
        --     return false
        elseif EffectManager5EBCE.moddedHasEffect(rSource, "Tasha's Hideous Laughter") then
            return false
        elseif containsTextInEffect(rSource, "Unable to Stand") then
            return false
        elseif EffectManager5EBCE.moddedHasEffect(rSource, "NOSTAND") then
            return false
        else
            return true
        end
	else
        if not EffectManager5E.hasEffectCondition(rSource, "Prone") then
            return false
        elseif EffectManager5E.hasEffectCondition(rSource, "Grappled") then
            return false
        elseif EffectManager5E.hasEffectCondition(rSource, "Paralyzed") then
            return false
        elseif EffectManager5E.hasEffectCondition(rSource, "Petrified") then
            return false
        elseif EffectManager5E.hasEffectCondition(rSource, "Restrained") then
            return false
        elseif EffectManager5E.hasEffectCondition(rSource, "Unconscious") then
            return false
        -- elseif EffectManager5E.hasEffect(rSource, "SPEED: none") then
		    -- Doesn't work
        --     return false
        elseif EffectManager5E.hasEffect(rSource, "Tasha's Hideous Laughter") then
            return false
        elseif containsTextInEffect(rSource, "Unable to Stand") then
            return false
        elseif EffectManager5E.hasEffect(rSource, "NOSTAND") then
            return false
        else
            return true
        end
	end
end

function removeEffectClause(rActor, sClause, rTarget, bTargetedOnly, bIgnoreEffectTargets)
    if not rActor or not sClause then
	    return
		Debug.console("Walk This Way - removeEffectClause - not rActor or not sClause")
    end

    local sLowerClause = sClause:lower();
	local aMatch = {};
	local aEffects;
	local tEffectCompParams;

	if EffectManagerBCE then
	    tEffectCompParams = EffectManagerBCE.getEffectCompType(sClause);
        if TurboManager then
            aEffects = TurboManager.getMatchedEffects(rActor, sClause);
        end
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
                local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
                -- Debug.console("rEffectComp = " .. tostring(rEffectComp))
                -- Handle conditionals
                if EffectManager5EBCE then
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
                    -- Check for match
                    elseif rEffectComp.original:lower() == sLowerClause then
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
							ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sEffectNode .. ")");
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

function containsTextInEffect(rActor, sText)
    if not rActor or not sText then
	    return;
	end
	local sLText = string.lower(sText)
	local rSource = ActorManager.getCTNode(rActor)
    local sEffectString = EffectManager.getEffectsString(rSource)
	if not sEffectString then
	    return;
	end
	local sLEffectString = string.lower(sEffectString)
	if string.find(sLEffectString, sLText) then
	    return true;
	else
	    return false;
	end
end

function proneWindow(sourceNodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
	    return;
	end
    if not Session.IsHost then
	    return;
    end

    local rSource = ActorManager.resolveActor(sourceNodeCT);
	local sOwner = getControllingClient(rSource);

    if not checkProne(rSource) then
	    return;
	end

    if sOwner then
        queryClient(rSource)
        return;
    else
	    openProneWindow();
	end
end

function closeAllProneWindows(sourceNodeCT)
    closeProneWindow();
	local rSource = ActorManager.resolveActor(sourceNodeCT);
    if getControllingClient(rSource) then
	    sendCloseWindowCmd(rSource)
	end
end

function openProneWindow()
	if OptionsManager.isOption('WTWON', 'off') or OptionsManager.isOption('WTWONPLR', 'off') then
	    return;
	end
	if Session.IsHost and OptionsManager.isOption('WTWONDM', 'off') then
	    return;
	end
	-- local rCurrent = ActorManager.resolveActor(CombatManager.getActiveCT());
    -- local rSource = ActorManager.getCTNode(rCurrent)
    local datasource = ""
	-- Interface.openWindow('prone_query', datasource);
	Interface.openWindow('prone_query_small', datasource);
end

function closeProneWindow()
	-- local rCurrent = ActorManager.resolveActor(CombatManager.getActiveCT());
    -- local rSource = ActorManager.getCTNode(rCurrent)
    local datasource = ""
	-- local wChar = Interface.findWindow("prone_query", datasource);
	local wChar = Interface.findWindow("prone_query_small", datasource);
	if wChar then
		wChar.close();
	end
end

function standUp()
	if OptionsManager.isOption('WTWON', 'off') then
	    return;
	end
    local rCurrent = ActorManager.resolveActor(CombatManager.getActiveCT());
    local rSource = ActorManager.getCTNode(rCurrent)

	if not OptionsManager.isOption('WHOLEEFFECT', 'on') then
	    removeEffectClause(rSource, "Prone")
	end
	if Session.IsHost then
		if OptionsManager.isOption('WHOLEEFFECT', 'on') then
            removeEffectCaseInsensitive(rSource, "Prone");
		end
	    EffectManager.addEffect("", "", rSource, {
		    sName = Interface.getString("stood_up"), nDuration = 1, sChangeState = "rts"
		}, "");
	else
		if OptionsManager.isOption('WHOLEEFFECT', 'on') then
		    notifyApplyHostCommands(rSource, 1, "Prone");
        end
		notifyApplyHostCommands(rSource, 0, {
		    sName = Interface.getString("stood_up"), nDuration = 1, sChangeState = "rts"
		});
	end
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

function queryClient(rSource)
	if OptionsManager.isOption('WTWON', 'off') then
	    return;
	end
	local sOwner = getControllingClient(rSource);

	if sOwner then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_PRONEQUERY;
		msgOOB.sCTNodeID = ActorManager.getCTNodeName(rSource);
		Comm.deliverOOBMessage(msgOOB, sOwner);
	else
		ChatManager.SystemMessage(Interface.getString("msg_NotConnected"));
	end
end
function sendCloseWindowCmd(rSource)
	local sOwner = getControllingClient(rSource);

	if sOwner then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_CLOSEQUERY;
		msgOOB.sCTNodeID = ActorManager.getCTNodeName(rSource);
		Comm.deliverOOBMessage(msgOOB, sOwner);
	else
		ChatManager.SystemMessage(Interface.getString("msg_NotConnected"));
	end
end

function handleProneQueryClient(msgOOB)
	if OptionsManager.isOption('WTWON', 'off') then
	    return;
	end
	-- local sCTNodeID = msgOOB.sCTNodeID;
	-- local wMain = openProneWindow();
	openProneWindow();
end
function handleCloseProneQuery(msgOOB)
	-- local sCTNodeID = msgOOB.sCTNodeID;
	closeProneWindow()
end

-- OOB message triggered command to do anything we need to execute at the host for the first source die rolls
    -- (which are run locally).
-- msgOOB.type
--		OOB_MSGTYPE_APPLYHGACMDS
-- msgOOB.sNodeCT - combat tracker entry to have the iAction applied - ex. combattracker.list.id-00010
-- msgOOB.iAction
-- 		0 - EffectManager.addEffect - add an effect
    -- (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
--				 msgOOB[*] type,value - list of aEffectVarMap effects to add
--		1 - EffectManager.removeEffect
--				msgOOB.sEffect - text of effect to remove
function handleApplyHostCommands(msgOOB)
	-- Debug.console("manager_combat_wtw:handleApplyHostCommands called");
	-- Debug.console("manager_combat_wtw:handleApplyHostCommands; msgOOB = "
	--     .. tostring(msgOOB.type) .. "," .. tostring(msgOOB.iAction) .. "," .. tostring(msgOOB.sNodeCT)
	-- );

	-- get the combat tracker reference - ex. userdata for combattracker.list.id-00010
	local rNodeCT = DB.findNode(msgOOB.sNodeCT);
	--Debug.console(msgOOB.iAction .. " and " .. tostring(rNodeCT));

	-- OOB messages basically turn everything into text even when they are entered as numeric
	    -- this is translating it back to a number
	local iAction = tonumber(msgOOB.iAction);

	-- Requesting the add effect action on host
	if iAction == 0 then
		-- add an effect (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
		local rEffect = {};
		for k,v in pairs(msgOOB) do
			--Debug.console("manager_combat_wtw:handleApplyHostCommands; type = " .. tostring(k) .. ", value = " .. tostring(v));
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
		--Debug.console("manager_combat_wtw:handleApplyHostCommands; Unsupported iAction(" .. tostring(iAction) .. ")");
	end
end

-- function used to generate OOB message to process generic action commands on the Host
-- (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
	-- nodeCT - combat tracker entry to have the iAction applied - ex. combattracker.list.id-00010
	-- iAction
	-- 		0 - EffectManager.addEffect - add an effect
	            -- (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
	--				 rValues type,value - list of aEffectVarMap effects to add
	--		1 - EffectManager.removeEffect
	--				 rValue string - text of effect to remove
function notifyApplyHostCommands(nodeCT, iAction, rValues)
	--Debug.console("manager_generic_actions:notifyApplyHostCommands called");

	local msgOOB = {};
	-- msgOOB.type
	--		OOB_MSGTYPE_APPLYHGACMDS
	-- msgOOB.sNodeCT - combat tracker entry to have the iAction applied - ex. combattracker.list.id-00010
	-- msgOOB.iAction
	-- 		0 - EffectManager.addEffect - add an effect
	            -- (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
	--				 msgOOB[*] type,value - list of aEffectVarMap effects to add
	--		1 - EffectManager.removeEffect
	--				msgOOB.sEffect - text of effect to remove
	msgOOB.type = OOB_MSGTYPE_APPLYHCMDS;

	msgOOB.iAction = iAction;
	msgOOB.sNodeCT = DB.getPath(nodeCT);
	-- Debug.console("manager_combat_wtw:notifyApplyHostCommands; msgOOB = "
	--     .. tostring(msgOOB.type) .. "," .. tostring(msgOOB.iAction) .. "," .. tostring(msgOOB.sNodeCT)
	-- );
	if msgOOB.iAction == 0 then
		for k,v in pairs(rValues) do
			--Debug.console("manager_combat_wtw:notifyApplyHostCommands; type = " .. tostring(k) .. ", value = " .. tostring(v));
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
	-- deliver message to the host for processing on it (can't do a lot of updates to DB from clients)
	Comm.deliverOOBMessage(msgOOB, "");
end

---For a given actor, determines who the owning client is and if they are connected.
    ---Returns nil for inactive identities and those owned by the GM
---@param rActor table the actor who the owner needs to be determined for
---@return string|nil sOwner the controlling client if they are connected. otherwise returns nil
function getControllingClient(rActor)
    if RRActionManager then
	    return RRActionManager.getControllingClient(rActor);
	end
	local isControlled = false;
	local sNode = nil;
	if ActorManager.isPC(rActor) then
		sNode = ActorManager.getCreatureNodeName(rActor);
	else
		if FriendZone and FriendZone.isCohort(rActor) then
			sNode = getRootCommander(rActor);
		end
	end

	--There will be an active identity if the client is connected. If sNode is still nil, nothing will be found
	for _, value in pairs(User.getAllActiveIdentities()) do
		if "charsheet." .. value == sNode then
			isControlled = true;
		end
	end

	if isControlled then
		return DB.getOwner(sNode);
	else
		return nil;
	end
end

---For a given cohort actor, determine the root character node that owns it
---@param rActor table the actor we need the root commander for
---@return string|nil nodePath the root character node of the chain
function getRootCommander(rActor)
    if RRActionManager then
	    return RRActionManager.getRootCommander(rActor);
	end
	local sRecord = ActorManager.getCreatureNodeName(rActor);
	local sRecordSansModule = StringManager.split(sRecord, "@")[1];
	local aRecordPathSansModule = StringManager.split(sRecordSansModule, ".");
	if aRecordPathSansModule[1] and aRecordPathSansModule[2] then
		return aRecordPathSansModule[1] .. "." .. aRecordPathSansModule[2];
	end
	return nil;
end