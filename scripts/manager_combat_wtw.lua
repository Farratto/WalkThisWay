-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

OOB_MSGTYPE_APPLYHCMDS = "applyhcmds"; -- OOB identifier for source local processing that supports commands that need host privilege to execute
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
    CombatManager.setCustomTurnStart(proneWindow);
    CombatManager.setCustomTurnEnd(closeAllProneWindows);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRONEQUERY, handleProneQueryClient);
	-- Register OOB message for source local processing that supports commands that need host privilege to execute
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYHCMDS, handleApplyHostCommands);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSEQUERY, handleCloseProneQuery);
end

function checkProne(sourceNodeCT)
    if not sourceNodeCT then
    	Debug.console("WtW Debug - sourceNodeCT is nil")
        return;
    end

    local rSource = ActorManager.resolveActor(sourceNodeCT);
    if not EffectManager.hasCondition(rSource, "Prone") then
	    return false
	elseif EffectManager.hasCondition(rSource, "Grappled") then
	    return false
	elseif EffectManager.hasCondition(rSource, "Paralyzed") then
	    return false
	elseif EffectManager.hasCondition(rSource, "Petrified") then
	    return false
	elseif EffectManager.hasCondition(rSource, "Restrained") then
	    return false
	elseif EffectManager.hasCondition(rSource, "Unconscious") then
	    return false
	elseif EffectManager5E.hasEffect(rSource, "SPEED: 0") then
	    return false
    else
	    return true
    end
end

function proneWindow(sourceNodeCT)
    if not Session.IsHost then
	    return;
    end

    local rSource = ActorManager.resolveActor(sourceNodeCT);
	local sOwner = getControllingClient(rSource);
	
    if not checkProne(rSource) then
	    return;
	end

	local rCurrent = nil;
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
	-- Interface.openWindow('prone_query', "");
	Interface.openWindow('prone_query_small', "");
end

function closeProneWindow()
	-- local wChar = Interface.findWindow("prone_query", "");
	local wChar = Interface.findWindow("prone_query_small", "");
	if wChar then
		wChar.close();
	end
end

function standUp()
	local rCurrent = nil;
	rCurrent = ActorManager.resolveActor(CombatManager.getActiveCT());
   	local rSource = ActorManager.getCTNode(rCurrent)

	if Session.IsHost then
        EffectManager.removeCondition(rCurrent, "Prone");
	    EffectManager.addEffect("", "", rSource, { sName = Interface.getString("stood_up"), nDuration = 1, sChangeState = "rts" }, "");
	else
		-- local sIdentity = User.getCurrentIdentity();
		-- if sIdentity then
		--  	rCurrent = ActorManager.resolveActor(CombatManager.getCTFromNode("charsheet." .. sIdentity));
		-- end
		notifyApplyHostCommands(rSource, 1, "Prone");
		notifyApplyHostCommands(rSource, 0, { sName = Interface.getString("stood_up"), nDuration = 1, sChangeState = "rts" });
	end
end

function queryClient(rSource)
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
	local sCTNodeID = msgOOB.sCTNodeID;
	-- local bMakeRoll = msgOOB.bMakeRoll == "true";
	local wMain = openProneWindow();
	-- local bActioned = false;
end
function handleCloseProneQuery(msgOOB)
	local sCTNodeID = msgOOB.sCTNodeID;
	-- local bMakeRoll = msgOOB.bMakeRoll == "true";
	closeProneWindow()
end

-- OOB message triggered command to do anything we need to execute at the host for the first source die rolls (which are run locally). 
-- msgOOB.type
--		OOB_MSGTYPE_APPLYHGACMDS
-- msgOOB.sNodeCT - combat tracker entry to have the iAction applied - ex. combattracker.list.id-00010
-- msgOOB.iAction
-- 		0 - EffectManager.addEffect - add an effect (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
--				 msgOOB[*] type,value - list of aEffectVarMap effects to add
--		1 - EffectManager.removeEffect
--				msgOOB.sEffect - text of effect to remove
function handleApplyHostCommands(msgOOB)
	--Debug.console("manager_combat_wtw:handleApplyHostCommands called");	
	--Debug.console("manager_combat_wtw:handleApplyHostCommands; msgOOB = " .. tostring(msgOOB.type) .. "," .. tostring(msgOOB.iAction) .. "," .. tostring(msgOOB.sNodeCT));	
	
	-- get the combat tracker reference - ex. userdata for combattracker.list.id-00010
	local rNodeCT = DB.findNode(msgOOB.sNodeCT);
	--Debug.console(msgOOB.iAction .. " and " .. tostring(rNodeCT));
	
	-- OOB messages basically turn everything into text even when they are entered as numeric - this is translating it back to a number
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
		EffectManager.removeEffect(rNodeCT, msgOOB.sEffect);
	else
		ChatManager.SystemMessage("[ERROR] manager_combat_wtw:handleApplyHostCommands; Unsupported iAction(" .. tostring(iAction) .. ")");	
		--Debug.console("manager_combat_wtw:handleApplyHostCommands; Unsupported iAction(" .. tostring(iAction) .. ")");	
	end
end

-- function used to generate OOB message to process generic action commands on the Host
-- (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
	-- nodeCT - combat tracker entry to have the iAction applied - ex. combattracker.list.id-00010
	-- iAction
	-- 		0 - EffectManager.addEffect - add an effect (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
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
	-- 		0 - EffectManager.addEffect - add an effect (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
	--				 msgOOB[*] type,value - list of aEffectVarMap effects to add
	--		1 - EffectManager.removeEffect
	--				msgOOB.sEffect - text of effect to remove
	msgOOB.type = OOB_MSGTYPE_APPLYHCMDS;
	
	msgOOB.iAction = iAction;
	msgOOB.sNodeCT = DB.getPath(nodeCT);
	--Debug.console("manager_combat_wtw:notifyApplyHostCommands; msgOOB = " .. tostring(msgOOB.type) .. "," .. tostring(msgOOB.iAction) .. "," .. tostring(msgOOB.sNodeCT));	
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

---For a given actor, determines who the owning client is and if they are connected. Returns nil for inactive identities and those owned by the GM
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
