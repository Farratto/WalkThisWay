-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

--luacheck: globals checkProne checkHideousLaughter setOptions processTurnStart
--luacheck: globals closeAllProneWindows openProneWindow closeProneWindow standUp delWTWdataChild
--luacheck: globals queryClient sendCloseWindowCmd handleProneQueryClient handleCloseProneQuery
--luacheck: globals sStoodUp sHoppedUp queryMovePossible

OOB_MSGTYPE_PRONEQUERY = 'pronequery';
OOB_MSGTYPE_CLOSEQUERY = 'closequery';
OOB_MSGTYPE_QUERYMOVEPOSS = 'query_move_poss';
OOB_MSGTYPE_MOVEPOSSRESPONSE = 'query_move_response';

local nMoved = 0;
--sStoodUp = 'Stood Up; SPEED: halved';
--sHoppedUp = 'Hopped up; SPEED: 5 dec';
sStoodUp = "Stood Up";
sHoppedUp = "Hopped up";

function onInit()
	setOptions();
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_PRONEQUERY, handleProneQueryClient);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSEQUERY, handleCloseProneQuery);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_QUERYMOVEPOSS, handleQueryMovePossible);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_MOVEPOSSRESPONSE, handleQueryMoveResponse);
	if Session.IsHost then
		CombatManager.setCustomTurnStart(processTurnStart);
		CombatManager.setCustomTurnEnd(closeAllProneWindows);
	end
end

function setOptions()
-- DEFAULT BEHAVIORS FOR OPTIONS: sType = "option_entry_cycler", on|off, default = off
--Farratto: Undocumented default option behaviors: bLocal = false, sGroupRes = "option_header_client"
	--Old 4th = ("option_label_" .. sKey)
	OptionsManager.registerOption2('WTWONDM', false, 'option_header_WtW', 'option_WtW_On_DM_Choice'
		, 'option_entry_cycler', {
			labels = 'option_val_off',
			values = 'off',
			baselabel = 'option_val_on',
			baseval = 'on',
			default = 'on'
		}
	);
end

function processTurnStart(nodeCT)
	if not checkProne(nodeCT) then return end

	local sOwner = WtWCommon.getControllingClient(nodeCT);
	if sOwner then
		queryClient(nodeCT, sOwner)
	else
		local sNodeCT = DB.getPath(nodeCT);
		openProneWindow(sNodeCT);
	end
end

function checkProne(nodeCT)
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

function delWTWdataChild(sChildNode)
	local nodeWtW = DB.findNode('WalkThisWay');
	if not nodeWtW then
		return true;
	end
	local nodePQ = DB.getChild(nodeWtW, sChildNode);
	if not nodePQ then
		return true;
	end
	return DB.deleteNode(nodePQ);
end

function closeAllProneWindows(nodeCT)
	local sOwner = WtWCommon.getControllingClient(nodeCT);
	if sOwner then
		sendCloseWindowCmd(nodeCT, sOwner);
	else
		closeProneWindow(nodeCT);
	end
end

-- luacheck: push ignore 561
function openProneWindow(nodeCT)
	if Session.IsHost and OptionsManager.isOption('WTWONDM', 'off') then return end

	local wProneQuery = Interface.openWindow('prone_query', DB.getPath(nodeCT));
	if wProneQuery then wProneQuery.bringToFront() end
	local tWindowsQuery = Interface.getWindows('prone_query');
	if tWindowsQuery[6] then
		local x = -75;
		local y = -75;
		for _,w in pairs(tWindowsQuery) do
			x = x + 75;
			y = y + 75;
			w.setPosition(x, y);
		end
	elseif tWindowsQuery[2] then
		local nWidth1, nHeight1, w1, w2, w3, w4, w5;
		local tDimensions = {};
		for k,w in pairs(tWindowsQuery) do
			if not nWidth1 then
				nWidth1, nHeight1 = w.getSize();
				local x, y = w.getPosition();
				w1 = w;
				local aDimension = {};
				aDimension['x'] = x;
				aDimension['y'] = y;
				table.insert(tDimensions, aDimension);
			else
				local x, y = w.getPosition();
				local aDimension = {};
				aDimension['x'] = x;
				aDimension['y'] = y;
				table.insert(tDimensions, aDimension);
			end
			if not w2 and k == 2 then w2 = w end
			if not w3 and k == 3 then w3 = w end
			if not w4 and k == 4 then w4 = w end
			if not w5 and k == 5 then w5 = w end
		end
		for k,v in ipairs(tDimensions) do
			local x = v.x;
			local y = v.y;
			for key,value in ipairs(tDimensions) do
				if key ~= k then
					local exe = value.x;
					local why = value.y;
					if exe == x and why == y then
						nMoved = nMoved + 1;
						if nMoved == 1 then
							local win;
							if key == 1 then win = w1 end
							if key == 2 then win = w2 end
							if key == 3 then win = w3 end
							if key == 4 then win = w4 end
							if key == 5 then win = w5 end
							win.setPosition(x - nWidth1, y);
						elseif nMoved == 2 then
							local win;
							if key == 1 then win = w1 end
							if key == 2 then win = w2 end
							if key == 3 then win = w3 end
							if key == 4 then win = w4 end
							if key == 5 then win = w5 end
							win.setPosition(x + nWidth1, y);
						elseif nMoved == 3 then
							local win;
							if key == 1 then win = w1 end
							if key == 2 then win = w2 end
							if key == 3 then win = w3 end
							if key == 4 then win = w4 end
							if key == 5 then win = w5 end
							win.setPosition(x, y + nHeight1);
						else
							local win;
							if key == 1 then win = w1 end
							if key == 2 then win = w2 end
							if key == 3 then win = w3 end
							if key == 4 then win = w4 end
							if key == 5 then win = w5 end
							win.setPosition(x, y - nHeight1);
						end
					end
				end
			end
		end
	end
end
--luacheck: pop

function closeProneWindow(nodeCT)
	local wProneQuery = Interface.findWindow('prone_query', DB.getPath(nodeCT));
	if wProneQuery then wProneQuery.close() end
	delWTWdataChild('proneQuery');
	nMoved = 0;
end

function standUp(nodeCT, bHostAuth, bAthlete, nDist)
	if not nodeCT then nodeCT = CombatManager.getActiveCT() end

	local bConsume;
	if Session.RulesetName == '5E' then
		if not bAthlete and ActorManager5E.hasRollFeat2024(nodeCT, 'Athlete') then bAthlete = true end
		if bAthlete then nDist = 5 end

		if not bHostAuth and MovementManager then
			if not Session.IsHost then
				queryMovePossible(nodeCT, bAthlete);
				return;
			end
			local bHasEnoughMovement;
			if bAthlete then
				bHasEnoughMovement = WtWCommon.isMovementPossible(nodeCT, nDist);
			else
				bHasEnoughMovement, nDist = WtWCommon.isMovementPossible(nodeCT, nil, 'half');
			end

			if bHasEnoughMovement == nil then return end
			if bHasEnoughMovement == false then
				local sOwner = WtWCommon.getControllingClient(nodeCT);
				ChatManager.Message("Not enough movement remaining.", sOwner, nodeCT);
				return;
			end

			bConsume = true;
			SpeedManager.tStoodUp[nodeCT] = true; --luacheck: ignore 142
		end
	end

	if bHostAuth then
		bConsume = true;
		SpeedManager.tStoodUp[nodeCT] = true; --luacheck: ignore 142
	end

	WtWCommon.removeEffectClause(nodeCT, "Prone");
	if Session.IsHost then
		if Session.RulesetName == "5E" then
			if bAthlete then
				EffectManager.addEffect("","",nodeCT,{sName = sHoppedUp,nDuration = 1,sChangeState = "rts"},"");
			else
				EffectManager.addEffect("","",nodeCT,{sName = sStoodUp,nDuration = 1,sChangeState = "rts" },"");
			end
		else
			EffectManager.addEffect("","",nodeCT,{sName = sStoodUp,nDuration = 1},"");
		end
	else
		if Session.RulesetName == "5E" then
			if bAthlete then
				WtWCommon.notifyApplyHostCommands(nodeCT,0,{sName = sHoppedUp,nDuration = 1,sChangeState = "rts"});
			else
				WtWCommon.notifyApplyHostCommands(nodeCT,0,{sName = sStoodUp,nDuration = 1,sChangeState = "rts"});
			end
		else
			WtWCommon.notifyApplyHostCommands(nodeCT,0,{sName = sStoodUp,nDuration = 1,sChangeState = "rts"});
		end
	end

	if bConsume then
		if bAthlete then
			MovementManager.consumeMovement(nodeCT, 'dist', nil, 5);
		else
			MovementManager.consumeMovement(nodeCT, 'dist', nil, nDist);
		end
	end
end
function queryMovePossible(nodeCT, bAthlete)
	local msgOOB = {};
	msgOOB['type'] = OOB_MSGTYPE_QUERYMOVEPOSS;
	msgOOB['sCTNodeID'] = DB.getPath(nodeCT);
	msgOOB['sAthlete'] = tostring(bAthlete);
	Comm.deliverOOBMessage(msgOOB);
end
function handleQueryMovePossible(msgOOB)
	if not Session.IsHost then return end

	local nodeCT = DB.findNode(msgOOB['sCTNodeID']);
	local bHasEnoughMovement, nDist, bAthlete;
	if msgOOB['sAthlete'] == 'true' then
		bAthlete = true;
		bHasEnoughMovement = WtWCommon.isMovementPossible(nodeCT, 5);
	else
		bHasEnoughMovement, nDist = WtWCommon.isMovementPossible(nodeCT, nil, 'half');
	end

	if bHasEnoughMovement == nil then return end
	if bHasEnoughMovement == false then
		local sOwner = WtWCommon.getControllingClient(nodeCT);
		ChatManager.Message("Not enough movement remaining.", sOwner, nodeCT);
		return;
	end

	msgOOB['type'] = OOB_MSGTYPE_MOVEPOSSRESPONSE;
	msgOOB['sDist'] = tostring(nDist);
	msgOOB['sAthlete'] = tostring(bAthlete);
	Comm.deliverOOBMessage(msgOOB, WtWCommon.getControllingClient(nodeCT));
end
function handleQueryMoveResponse(msgOOB)
	local bAthlete;
	local nDist = tonumber(msgOOB['sDist']);
	if msgOOB['sAthlete'] == 'true' then bAthlete = true end

	standUp(DB.findNode(msgOOB['sCTNodeID']), true, bAthlete, nDist);
end

function queryClient(nodeCT, sOwner)
	if not sOwner then sOwner = WtWCommon.getControllingClient(nodeCT) end

	if sOwner then
		local msgOOB = {};
		msgOOB['type'] = OOB_MSGTYPE_PRONEQUERY;
		msgOOB['sCTNodeID'] = DB.getPath(nodeCT);
		Comm.deliverOOBMessage(msgOOB, sOwner);
	else
		ChatManager.SystemMessage(Interface.getString("msg_NotConnected"));
	end
end

function sendCloseWindowCmd(nodeCT, sOwner)
	if not Session.IsHost then
		Debug.console('ProneManager.sendCloseWindowCmd - not IsHost');
		return;
	end
	if not sOwner then sOwner = WtWCommon.getControllingClient(nodeCT) end
	if sOwner then
		local msgOOB = {};
		msgOOB.type = OOB_MSGTYPE_CLOSEQUERY;
		msgOOB.sCTNodeID = DB.getPath(nodeCT);
		Comm.deliverOOBMessage(msgOOB, sOwner);
	else
		ChatManager.SystemMessage(Interface.getString("msg_NotConnected"));
	end
end

function handleProneQueryClient(msgOOB)
	local nodeCT = DB.findNode(msgOOB.sCTNodeID);
	openProneWindow(nodeCT);
end
function handleCloseProneQuery(msgOOB)
	closeProneWindow(DB.findNode(msgOOB.sCTNodeID));
end