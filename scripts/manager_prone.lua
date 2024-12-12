-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals clientGetOption checkProne checkHideousLaughter setPQvalue setOptions processTurnStart
-- luacheck: globals closeAllProneWindows openProneWindow closeProneWindow standUp delWTWdataChild
-- luacheck: globals queryClient sendCloseWindowCmd handleProneQueryClient handleCloseProneQuery

OOB_MSGTYPE_PRONEQUERY = "pronequery";
OOB_MSGTYPE_CLOSEQUERY = "closequery";

function onInit()
	setOptions();

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRONEQUERY, handleProneQueryClient);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSEQUERY, handleCloseProneQuery);

	if Session.IsHost then
		CombatManager.setCustomTurnStart(processTurnStart);
		CombatManager.setCustomTurnEnd(closeAllProneWindows);
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
		end
		OptionsManager.registerOption2('APCW', false, 'option_header_WtW', 'option_WtW_Allow_Player_Choice', 'option_entry_cycler', {
			labels = 'option_val_on',
			values = 'on',
			baselabel = 'option_val_off',
			baseval = 'off',
			default = 'off'
		});
	end
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
end

function clientGetOption(sKey)
	if CampaignRegistry["Opt" .. sKey] then
		return CampaignRegistry["Opt" .. sKey];
	end
end

function processTurnStart(nodeCT)
	local rSource = ActorManager.resolveActor(nodeCT);
	local sOwner = WtWCommon.getControllingClient(nodeCT);

	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	if not checkProne(rSource) then
		return;
	end
	if sOwner then
		queryClient(nodeCT)
	else
		if rSource.sName then
			setPQvalue(rSource.sName);
		end
		openProneWindow();
	end
end

function checkProne(nodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	if not nodeCT then
		Debug.console("ProneManager.checkProne - not nodeCT");
		return;
	end

	if Session.RulesetName ~= "5E" then
		if EffectManagerPFRPG2 then
			if not WtWCommon.hasEffectClause(nodeCT, "^Prone$", nil, false, true) then
				return false;
			elseif WtWCommon.hasRoot(nodeCT) then
				return false;
			elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", true) then
				return false;
			elseif WtWCommon.hasEffectClause(nodeCT, "^NOSTAND$", nil, false, true) then
				return false;
			else
				return true;
			end
		else
			if not WtWCommon.hasEffectClause(nodeCT, "^Prone$", nil, false, true) then
				return false;
			elseif WtWCommon.hasRoot(nodeCT) then
				return false;
			elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", true) then
				return false;
			elseif WtWCommon.hasEffectClause(nodeCT, "^NOSTAND$", nil, false, true) then
				return false;
			else
				return true;
			end
		end
	else
		if not WtWCommon.hasEffectClause(nodeCT, "^Prone", nil, false, true) then
			return false;
			elseif WtWCommon.hasRoot(nodeCT) then
				return false;
		elseif WtWCommon.hasEffectFindString(nodeCT, "Unable to Stand", true) then
			return false;
		elseif WtWCommon.hasEffectClause(nodeCT, "^NOSTAND$", nil, false, true) then
			return false;
		elseif checkHideousLaughter(nodeCT) then
			return false;
		else
			return true;
		end
	end
end

function checkHideousLaughter(rActor)
	if not rActor then
		Debug.console("ProneManager.checkHideousLaughter - not rActor");
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

	if WtWCommon.hasEffectClause(rActor, sClause, nil, false, true) then
		if not bClauseExceptFound or nMatch > 1 then
			return true;
		end
	end
	return false;
end

function setPQvalue(sName)
	local nodeWTW = DB.createNode('WalkThisWay');
	if Session.IsHost then DB.setPublic(nodeWTW, true) end
	local nodeNameField = DB.getChild(nodeWTW, 'name');
	if not nodeNameField then
		DB.createChild(nodeWTW, 'proneQuery', 'string');
	end
	DB.setValue(nodeWTW, 'name', 'string', sName);
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

function closeAllProneWindows(nodeCT)
	if not Session.IsHost then
		Debug.console('ProneManager.closeAllProneWindows - not IsHost');
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
		Debug.console('ProneManager.sendCloseWindowCmd - not IsHost');
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

function handleProneQueryClient()
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	openProneWindow();
end
function handleCloseProneQuery()
	closeProneWindow();
end