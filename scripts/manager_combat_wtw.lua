-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local aEffectVarMap = {
	["sName"] = { sDBType = "string", sDBField = "label" },
	["nGMOnly"] = { sDBType = "number", sDBField = "isgmonly" },
	["sSource"] = { sDBType = "string", sDBField = "source_name", bClearOnUntargetedDrop = true },
	["sTarget"] = { sDBType = "string", bClearOnUntargetedDrop = true },
	["nDuration"] = { sDBType = "number", sDBField = "duration", vDBDefault = 1, sDisplay = "[D: %d]" },
	["nInit"] = { sDBType = "number", sDBField = "init", sSourceChangeSet = "initresult", bClearOnUntargetedDrop = true },
	["sApply"] = { sDBType = "string", sDBField = "apply", sDisplay = "[%s]"}, -- added by Farratto
	["sChangeState"] = { sDBType = "string", sDBField = "changestate" } -- added by Farratto
};

function onInit()
    CombatManager.setCustomTurnStart(proneWindow);
    CombatManager.setCustomTurnEnd(closeProneWindow);
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
    local rSource = ActorManager.resolveActor(sourceNodeCT);
    if not checkProne(rSource) then
	    return;
	end
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
	if Session.IsHost then
		rCurrent = ActorManager.resolveActor(CombatManager.getActiveCT());
	else
		local sIdentity = User.getCurrentIdentity();
		if sIdentity then
			rCurrent = ActorManager.resolveActor(CombatManager.getCTFromNode("charsheet." .. sIdentity));
		end
	end
	rSource = ActorManager.getCTNode(rCurrent)
	

    EffectManager.removeCondition(rCurrent, "Prone");
	EffectManager.addEffect("", "", rSource, { sName = "Stood Up; SPEED: 0.5", nDuration = 1, sChangeState = "rts" }, "");
	-- notifyApplyHostGenericActionCommands(rTargetActorCT, 0, { sName = Interface.getString("char_help") .. "; GRANTADVATK", sApply ="roll", sSource = DB.getPath(rSourceActorCT), nDuration = 1, nInit = nInitiative, sChangeState = "srs" });
	
end