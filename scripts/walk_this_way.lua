-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.

-- luacheck: globals clientGetOption checkProne checkHideousLaughter addEffectWtW speedCalculator setPQvalue
-- luacheck: globals closeAllProneWindows openProneWindow closeProneWindow standUp delWTWdataChild proneWindow
-- luacheck: globals queryClient sendCloseWindowCmd handleProneQueryClient handleCloseProneQuery hasRoot
-- luacheck: globals accommKnownExtsSpeed

OOB_MSGTYPE_PRONEQUERY = "pronequery";
OOB_MSGTYPE_CLOSEQUERY = "closequery";

faddEffectOriginal = ''; --luacheck: ignore 111

function onInit()
-- DEFAULT BEHAVIORS FOR OPTIONS: sType = "option_entry_cycler", on|off, default = off
--Farratto: Undocumented default option behaviors: bLocal = false, sGroupRes = "option_header_client"
	--Old 4th = ("option_label_" .. sKey)
	OptionsManager.registerOptionData({	sKey = "AOSW", bLocal = true });
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
end

function onClose()
	EffectManager.addEffect = faddEffectOriginal; --luacheck: ignore 113
end

function clientGetOption(sKey)
	if CampaignRegistry["Opt" .. sKey] then
		return CampaignRegistry["Opt" .. sKey];
	end
end

function addEffectWtW(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	faddEffectOriginal(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg); --luacheck: ignore 113
	local nNewSpeed = speedCalculator(nodeCT, true);
	Debug.console("nNewSpeed = " .. tostring(nNewSpeed));
	if nNewSpeed then
		--DB.setValue(nodeCT, 'speed', 'string', tostring(nNewSpeed));
		local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nNewSpeed));
	end
end

--still needs to be called upon effect deletion
-- luacheck: push ignore 561
function speedCalculator(nodeCT, bDebug)
	if not nodeCT then
		Debug.console("WalkThisWay.speedCalculator - not nodeCT");
		return;
	end
	local rActor = ActorManager.resolveActor(nodeCT);

	if hasRoot(nodeCT) then
		return 'none';
	end

	if not rActor then
		Debug.console("WalkThisWay.speedCalculator - not rActor");
		return;
	end

	local tSpeedTypesNew = {};
--	local tSpeedEffects = EffectManager.getEffectsByType(rActor, 'SPEED');
--	local tSpeedEffects = EffectManager5E.getEffectsByType(rActor, 'SPEED', tRecognizedRmndrs);
--	local tSpeedEffects = WtWCommon.moddedGetEffectsByType5E(rActor, 'FGOP');
--	local tSpeedEffects = WtWCommon.moddedGetEffectsByType5E(rActor, 'OBSCURED');
--	local tSpeedEffects = WtWCommon.moddedGetEffectsByTypeCore(rActor, 'SPEED');
--	local tSpeedEffects = WtWCommon.hasEffectFindString(rActor, 'SPEED', false, true, false, true);
	local tSpeedEffects = getEffectsByTypeWtW(rActor, 'SPEED');
	if bDebug then Debug.console("tSpeedEffects = " .. tostring(tSpeedEffects)) end
	local effect1 = tSpeedEffects[1];
	if bDebug then Debug.console("effect1 = " .. tostring(effect1)) end
	local nHalved = 0;
	if WtWCommon.fhasCondition(rActor, "Prone") then
		nHalved = nHalved + 1
	end

	if not effect1 and (nHalved == 0) then
		if bDebug then Debug.console("not effect1") end
		return;
	end

	local sFGSpeed = DB.getValue(nodeCT, 'speed')
	if not sFGSpeed then
		return;
	end

	local tFGSpeed = {};
	local nFGSpeedCnt = 0
	for nMatch in string.gmatch(sFGSpeed, '%d+') do
		nFGSpeedCnt = nFGSpeedCnt + 1;
		tFGSpeed[nFGSpeedCnt] = nMatch;
	end
	local nFGSpeed = tonumber(tFGSpeed[1]); --this will go away when I support multiple speeds
	local nFGSpeedNew = nFGSpeed;
	local tFGSpdTxt = {};
	local nFGSpdTxtCnt = 0
	for sMatch in string.gmatch(sFGSpeed, '%d+') do
		nFGSpdTxtCnt = nFGSpdTxtCnt + 1;
		tFGSpeed[nFGSpdTxtCnt] = sMatch;
	end

	local nSpeedMod = 0;
	local nSpeedMax = nil;
	local nDoubled = 0;
	local tAccomSpeed = accommKnownExtsSpeed(nodeCT);
	if tAccomSpeed then
		if tAccomSpeed[nDoubled] then
			nDoubled = nDoubled + tAccomSpeed[nDoubled]
		end
		if tAccomSpeed[nHalved] then
			nHalved = nHalved + tAccomSpeed[nHalved]
		end
		if tAccomSpeed[nSpeedMax] then
			nSpeedMax = tAccomSpeed[nSpeedMax]
		end
		if tAccomSpeed[nSpeedMod] then
			nSpeedMod = nSpeedMod + tAccomSpeed[nSpeedMod]
		end
	end

	local nRebaseCount = 0;
	for _,rEffectComp in ipairs(tSpeedEffects) do
		if bDebug then Debug.console("rEffectComp = " .. tostring(rEffectComp)) end
		if bDebug then Debug.console("rEffectComp.remainder(1) = " .. tostring(rEffectComp.remainder[1])) end
		if bDebug then Debug.console("rEffectComp.dice(1) = " .. tostring(rEffectComp.dice[1])) end
		if bDebug then Debug.console("rEffectComp.dice(2) = " .. tostring(rEffectComp.dice[2])) end
		if bDebug then Debug.console("rEffectComp.mod = " .. tostring(rEffectComp.mod)) end
		if rEffectComp.dice[1] then
			Debug.console("WalkThisWay.speedCalculator - Syntax Error");
			return;
		end
		for _,v in pairs(rEffectComp.remainder) do
			if bDebug then Debug.console("v = " .. tostring(v)) end
			local tSplitSpeedRmndrs = StringManager.split(v, ",", true);
			if bDebug then Debug.console("tSplitSpeedRmndrs = " .. tostring(tSplitSpeedRmndrs)) end
			for _,v2 in ipairs(tSplitSpeedRmndrs) do
				if bDebug then Debug.console("v2 = " .. tostring(v2)) end
				table.insert(tSpeedTypesNew, v2);
			end
		end
		if rEffectComp.mod ~= 0 then
			if rEffectComp.mod > 0 then
				if tSpeedTypesNew[2] then
					Debug.console("WalkThisWay.speedCalculator - Syntax Error");
				elseif StringManager.startsWith(tSpeedTypesNew[1], 'type') then
					local sRmndrRemainder = tSpeedTypesNew[1]:gsub('^type%s*%(', '');
					sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
					if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
					local nLoc;
					local nCnt = 0;
					for k,v in tFGSpdTxt do
						nCnt = k;
						if v == sRmndrRemainder then
							nLoc = k;
						end
					end
					if not nLoc then
						table.insert(tFGSpdTxt, sRmndrRemainder)
						nLoc = nCnt + 1;
					end
				else
					if nRebaseCount > 0 then
						if nFGSpeedNew < nFGSpeed then
							if nFGSpeedNew > rEffectComp.mod then
								nFGSpeedNew = rEffectComp.mod;
							else
								if nFGSpeedNew < rEffectComp.mod then
									nFGSpeedNew = rEffectComp.mod;
								end
							end
						end
					else
						nFGSpeedNew = rEffectComp.mod;
					end
					if bDebug then Debug.console("nFGSpeedNew = " .. tostring(nFGSpeedNew)) end
					nRebaseCount = nRebaseCount + 1;
				end
			else
				if rEffectComp.mod < 0 then
					table.insert(tSpeedTypesNew, 'dec(' .. tostring(rEffectComp.mod) .. ')');
				end
			end
		end
	end

	local bDifficult = false;
	for _,sSpeedType in ipairs(tSpeedTypesNew) do
		sSpeedType = string.lower(sSpeedType);
		if bDebug then Debug.console("sSpeedType = " .. tostring(sSpeedType)) end
		if StringManager.startsWith(sSpeedType, 'max') then
			local sRmndrRemainder = sSpeedType:gsub('^max%s*%(', '');
			sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
			if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
			local nRmndrRemainder = tonumber(sRmndrRemainder);
			if nRmndrRemainder then
				if nSpeedMax then
					if nRmndrRemainder < nSpeedMax then
						nSpeedMax = math.floor(nRmndrRemainder);
						if bDebug then Debug.console("nSpeedMax = " .. tostring(nSpeedMax)) end
					end
				else
					nSpeedMax = math.floor(nRmndrRemainder);
					if bDebug then Debug.console("nSpeedMax = " .. tostring(nSpeedMax)) end
				end
			end
		end
		if sSpeedType == "difficult" then
			bDifficult = true;
			if bDebug then Debug.console("bDifficult = true") end
		end
		if (sSpeedType == "half" or sSpeedType == "halved") then
			nHalved = nHalved + 1;
		end
		if (sSpeedType == "double" or sSpeedType == "doubled") then
			nDoubled = nDoubled + 1;
		end
		if StringManager.startsWith(sSpeedType, 'type') then
			local sRmndrRemainder = sSpeedType:gsub('^type%s*%(', '');
			sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
			if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
			if StringManager.startsWith(sRmndrRemainder, '-') then
				local sRemoveType = string.sub(sRmndrRemainder, 2)
				local tCheckFGSpdTxtTable = tFGSpdTxt;
				for k,v in pairs(tCheckFGSpdTxtTable) do
					if v == sRemoveType then
						table.remove(tFGSpdTxt, k)
					end
				end
			else
				local bFound = false
				if tFGSpdTxt[1] then
					for _,v in ipairs(tFGSpdTxt) do
						if v == sRmndrRemainder then
							bFound = true
						end
					end
				end
				if not bFound then
					table.insert(tFGSpdTxt, sRmndrRemainder)
				end
			end
		end

--		for _,nSpdTypeValue in ipairs(tFGSpeed) do --still need to replace variables with nSpdTypeValue

		if StringManager.startsWith(sSpeedType, 'inc') then
			local sRmndrRemainder = sSpeedType:gsub('^inc%s*%(', '');
			sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
			if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
			local nSpeedInc = tonumber(sRmndrRemainder);
			if not nSpeedInc then
				Debug.console("WalkThisWay.speedCalculator - Syntax Error")
			else
				nSpeedMod = nSpeedMod + nSpeedInc;
			end
		end
		if StringManager.startsWith(sSpeedType, 'dec') then
			local sRmndrRemainder = sSpeedType:gsub('^dec%s*%(', '');
			sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
			if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
			local nSpeedDec = tonumber(sRmndrRemainder);
			if not nSpeedDec then
				Debug.console("WalkThisWay.speedCalculator - Syntax Error")
			else
				nSpeedMod = nSpeedMod - nSpeedDec;
			end
		end

--		end
	end

	if bDebug then Debug.console("nFGSpeedNew = " .. tostring(nFGSpeedNew)) end
	if bDebug then Debug.console("nSpeedMod = " .. tostring(nSpeedMod)) end
	local nSpeedFinal = nFGSpeedNew + nSpeedMod;
	if bDebug then Debug.console("nSpeedFinal = " .. tostring(nSpeedFinal)) end
	if nDoubled > 0 then
		if nHalved > 0 then
			if bDebug then Debug.console("nDoubled & nHalved") end
			nDoubled = nDoubled - nHalved;
			nHalved = nHalved - nDoubled;
		end
		while nDoubled > 0 do
			if bDebug then Debug.console("nDoubled > 0") end
			nSpeedFinal = nSpeedFinal * 2;
			nDoubled = nDoubled - 1;
		end
	end
	if nHalved > 0 then
		while nHalved > 0 do
			if bDebug then Debug.console("nHalved > 0") end
			nSpeedFinal = math.floor(nSpeedFinal / 2);
			nHalved = nHalved - 1;
		end
	end
	if bDifficult then
		nSpeedFinal = math.floor(nSpeedFinal / 2);
	end
	nSpeedFinal = tonumber(nSpeedFinal);
	nSpeedFinal = math.floor(nSpeedFinal);
	if bDebug then Debug.console("nSpeedFinal = " .. tostring(nSpeedFinal)) end
	if bDebug then Debug.console("nSpeedMax = " .. tostring(nSpeedMax)) end
	if nSpeedMax then
		if nSpeedFinal > nSpeedMax then
			nSpeedFinal = nSpeedMax;
		end
	end

	if not nSpeedFinal then
		if bDebug then Debug.console("WalkThisWay.speedCalculator - nSpeedFinal is not a number") end
		return;
	end
	if nSpeedFinal < 0 then
		nSpeedFinal = 0;
	end
	local sReturn = tostring(nSpeedFinal)
	for _,sSpdTxt in ipairs(tFGSpdTxt) do
		sReturn = sReturn .. ' ' .. sSpdTxt
	end
	return sReturn;
end
-- luacheck: pop

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
		if EffectManager5E.hasEffect(nodeCT, "Speed=5") or EffectManager5E.hasEffect(nodeCT, "Exceeds Maximum Carrying Capacity") then
			nSpeedMax = 5;
		end
		if EffectManager5E.hasEffect(nodeCT, "Heavily Encumbered") or EffectManager5E.hasEffect(nodeCT, "Speed-20") then
			nSpeedMod = nSpeedMod - 20;
		else
			if EffectManager5E.hasEffect(nodeCT, "Lightly Encumbered") or EffectManager5E.hasEffect(nodeCT, "Encumbered") or
				EffectManager5E.hasEffect(nodeCT, "Speed-10")
			then
				nSpeedMod = nSpeedMod - 10;
			end
		end
		--exhaustion (speed 0 & DEATH checks are in hasRoot)
		if WtWCommon.hasEffectFindString(nodeCT, "Speed Halved", false, true, true) then
			nHalved = nHalved + 1;
		end
		local sExhaustStack = WtWCommon.hasEffectFindString(nodeCT, "Speed -", false, true, true, true);
		if sExhaustStack then
			local sExhaustStack = sExhaustStack:gsub('^[Speed -]%d+', '');
			sExhaustStack = sExhaustStack:gsub('^%d+', '');
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
			nDoubled = nDoubled - nHalved;
			nHalved = nHalved - nDoubled;
		end
		if nDoubled > 0 then
			tReturn[nDoubled] = nDoubled
			bReturn = true
		end
	end
	if nHalved > 0 then
		tReturn[nHalved] = nHalved
		bReturn = true
	end
	if nSpeedMax then
		tReturn[nSpeedMax] = nSpeedMax
		bReturn = true
	end
	if nSpeedMod ~= 0 then
		tReturn[nSpeedMod] = nSpeedMod
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
			elseif WtWCommon.hasEffectFindString(nodeCT, "Speed%s-0", false, true, true) then
				return true
			else
				return false
			end
		else
			if EffectManager.hasCondition(nodeCT, "Unconscious") then
				return true
			elseif WtWCommon.hasEffectFindString(nodeCT, "Speed%s-0", false, true, true) then
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
		elseif WtWCommon.hasEffectFindString(nodeCT, "Speed%s-0", false, true, true) then
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

function proneWindow(sourceNodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	if not Session.IsHost then
		return;
	end

	local rSource = ActorManager.resolveActor(sourceNodeCT);
	local sOwner = WtWCommon.getControllingClient(sourceNodeCT);

	if OptionsManager.isOption('AOSW', 'on') then
		local nodeCTWtW = DB.createChild(sourceNodeCT, 'WalkThisWay');
		DB.setValue(nodeCTWtW, 'actorname', 'string', tostring(rSource.sName));
		local sCurrentSpeed = DB.getValue(nodeCTWtW, 'currentSpeed');
		if not sCurrentSpeed then
			local nFGSpeed = DB.getValue(sourceNodeCT, 'speed');
			DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nFGSpeed));
		end
		Interface.openWindow('speed_window', nodeCTWtW)
	end

	if not checkProne(rSource) then
		return;
	end

	if sOwner then
		queryClient(sourceNodeCT)
		return;
	else
		if rSource.sName then
			setPQvalue(rSource.sName)
		end
		openProneWindow();
	end
end

function closeAllProneWindows(sourceNodeCT)
	closeProneWindow();
	if WtWCommon.getControllingClient(sourceNodeCT) then
		sendCloseWindowCmd(sourceNodeCT)
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