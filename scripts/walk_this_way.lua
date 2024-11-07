-- Please see the LICENSE.txt file included with this distribution for
-- attribution and copyright information.
--
-- luacheck: globals clientGetOption checkProne checkHideousLaughter hasEffectFindString removeEffectClause
-- luacheck: globals closeAllProneWindows openProneWindow closeProneWindow standUp removeEffectCaseInsensitive
-- luacheck: globals queryClient sendCloseWindowCmd handleProneQueryClient handleCloseProneQuery proneWindow
-- luacheck: globals handleApplyHostCommands notifyApplyHostCommands getControllingClient getRootCommander
-- luacheck: globals setPQvalue delWTWdataChild checkBetterGoldPurity speedCalculator handleExhaustion
-- luacheck: globals handleItemTooHeavy addEffectWtW

-- OOB identifier for source local processing that supports commands that need host privilege to execute
OOB_MSGTYPE_APPLYHCMDS = "applyhcmds";
OOB_MSGTYPE_PRONEQUERY = "pronequery";
OOB_MSGTYPE_CLOSEQUERY = "closequery";
_sBetterGoldPurity = '' --luacheck: ignore 111

local faddEffectOriginal;

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
-- DEFAULT BEHAVIORS FOR OPTIONS: sType = "option_entry_cycler", on|off, default = off
--Farratto: Undocumented default option behaviors: bLocal = false, sGroupRes = "option_header_client", Old 4th = ("option_label_" .. sKey)
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
		-- Register OOB message for source local processing that supports commands that need host privilege to execute
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYHCMDS, handleApplyHostCommands);
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CLOSEQUERY, handleCloseProneQuery);
	end
	faddEffectOriginal = EffectManager.addEffect;
	EffectManager.addEffect = WalkThisWay.addEffectWtW;

	EffectManager.registerEffectCompType("SPEED", { bIgnoreTarget = true, bNoDUSE = true, bIgnoreOtherFilter = true, bIgnoreExpire = true });
		--known options: bIgnoreOtherFilter bIgnoreDisabledCheck bDamageFilter bConditionFilter bNoDUSE bIgnoreTarget
		--continued: bSpell bOneShot bIgnoreExpire

	if EffectManager5EBCE then
		_sBetterGoldPurity = checkBetterGoldPurity() --luacheck: ignore 111
	end
end

function onClose()
	EffectManager.addEffect = faddEffectOriginal;
end

function clientGetOption(sKey)
	if CampaignRegistry["Opt" .. sKey] then
		return CampaignRegistry["Opt" .. sKey];
	end
end

function addEffectWtW(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	faddEffectOriginal(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
	local nNewSpeed = speedCalculator(nodeCT, true);
	Debug.console("nNewSpeed = " .. tostring(nNewSpeed));
	if nNewSpeed then
		--DB.setValue(nodeCT, 'speed', 'string', tostring(nNewSpeed));
		local nodeCTWtW = DB.createChild(nodeCT, 'WalkThisWay');
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nNewSpeed));
	end
end

-- luacheck: push ignore 561
function speedCalculator(nodeCT, bDebug)
	if not nodeCT then
		Debug.console("WalkThisWay.speedCalculator - not nodeCT");
		return;
	end
	local rActor = ActorManager.resolveActor(nodeCT);
	if not rActor then
		Debug.console("WalkThisWay.speedCalculator - not rActor");
		return;
	end
	local nFGSpeed = DB.getValue(nodeCT, 'speed')
	if not nFGSpeed then
		Debug.console("WalkThisWay.speedCalculator - not nFGSpeed");
		nFGSpeed = 30;
	end

	local tSpeedTypesNew = {};
	local tSpeedEffects = EffectManager.getEffectsByType(rActor, 'SPEED');
	local effect1 = tSpeedEffects[1];
	if bDebug then Debug.console("effect1 = " .. tostring(effect1)) end
	if not effect1 then
		if bDebug then Debug.console("not effect1") end
		return;
	end
	if bDebug then Debug.console("tSpeedEffects = " .. tostring(tSpeedEffects)) end
	for _,rEffectComp in ipairs(tSpeedEffects) do
		if bDebug then Debug.console("rEffectComp = " .. tostring(rEffectComp)) end
		for _,v in ipairs(rEffectComp.remainder) do
			if bDebug then Debug.console("v = " .. tostring(v)) end
			local tSplitSpeedTypes = StringManager.split(v, ",", true);
			if bDebug then Debug.console("tSplitSpeedTypes = " .. tostring(tSplitSpeedTypes)) end
			for _,v2 in ipairs(tSplitSpeedTypes) do
				if bDebug then Debug.console("v2 = " .. tostring(v2)) end
				table.insert(tSpeedTypesNew, v2);
			end
		end
	end

	local nSpeedMod = 0;
	local bDifficult = false;
	local nHalved = 0;
	local nFGSpeedNew = nFGSpeed;
	local nRebaseCount = 0;
	local nSpeedMax;
	for _,sSpeedType in ipairs(tSpeedTypesNew) do
		sSpeedType = string.lower(sSpeedType);
		if bDebug then Debug.console("sSpeedType = " .. tostring(sSpeedType)) end
		local sInfoOnly = string.sub(sSpeedType, -11);
		if bDebug then Debug.console("sInfoOnly = " .. tostring(sInfoOnly)) end
		if sInfoOnly == '(info only)' then
			sSpeedType = string.sub(sSpeedType, 1, -11);
			if bDebug then Debug.console("sSpeedType = " .. tostring(sSpeedType)) end
		end
		if sSpeedType == "none" then
			return '0';
		end
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
		if StringManager.startsWith(sSpeedType, 'rebase') then
			local sRmndrRemainder = sSpeedType:gsub('^rebase%s*%(', '');
			sRmndrRemainder = sRmndrRemainder:gsub('%)$', '');
			if bDebug then Debug.console("sRmndrRemainder = " .. tostring(sRmndrRemainder)) end
			local nRmndrRemainder = tonumber(sRmndrRemainder);
			if nRmndrRemainder then
				if nRebaseCount > 0 then
					if nFGSpeedNew < nFGSpeed then
						if nFGSpeedNew > nRmndrRemainder then
							nFGSpeedNew = nRmndrRemainder;
						else
							if nFGSpeedNew < nRmndrRemainder then
								nFGSpeedNew = nRmndrRemainder;
							end
						end
					end
				else
					nFGSpeedNew = nRmndrRemainder;
				end
				if bDebug then Debug.console("nFGSpeedNew = " .. tostring(nFGSpeedNew)) end
			end
			nRebaseCount = nRebaseCount + 1;
		end
		if (sSpeedType == "halfbase" or sSpeedType == "-halfbase") then
			if bDebug then Debug.console("sSpeedType = halfbase") end
			nSpeedMod = nSpeedMod - math.floor(nFGSpeed / 2);
		end
		if (sSpeedType == "half" or sSpeedType == "halved" or tonumber(sSpeedType) == 0.5) then
			nHalved = nHalved + 1;
		end
		if sSpeedType == "difficult" then
			bDifficult = true;
			if bDebug then Debug.console("bDifficult = true") end
		end
		local sFirstChar = string.sub(sSpeedType, 1, 1);
		if bDebug then Debug.console("sFirstChar = " .. tostring(sFirstChar)) end
		local sSecondAndOn;
		if not (sFirstChar == "+" or sFirstChar == "-") then
			local nSpeedType = tonumber(sSpeedType);
			if nSpeedType then
				nFGSpeedNew = nSpeedType;
			else
				if sSpeedType == "base" then
					if sFirstChar == "+" then
						nSpeedMod = nSpeedMod + nFGSpeed;
					else
						nSpeedMod = nSpeedMod - nFGSpeed;
					end
				end
				if sSpeedType == "halfbase" then
					if sFirstChar == "+" then
						nSpeedMod = nSpeedMod + math.floor(nFGSpeed / 2);
					end
				end
			end
		else
			sSecondAndOn = string.sub(sSpeedType, 2, #sSpeedType);
			local nSecondAndOn = tonumber(sSecondAndOn);
			if nSecondAndOn then
				if sFirstChar == "+" then
					nSpeedMod = nSpeedMod + nSecondAndOn;
				else
					nSpeedMod = nSpeedMod - nSecondAndOn;
				end
			end
		end
	end

	--accomidations for 5e auto encumbrance
	if EffectManager5E.hasEffect(nodeCT, "Speed=5") or EffectManager5E.hasEffect(nodeCT, "Exceeds Maximum Carrying Capacity") then
		nSpeedMax = 5;
	end
	if EffectManager5E.hasEffect(nodeCT, "Heavily Encumbered") or EffectManager5E.hasEffect(nodeCT, "Speed-20") then
		nSpeedMod = nSpeedMod - 20;
	end
	if EffectManager5E.hasEffect(nodeCT, "Lightly Encumbered") or EffectManager5E.hasEffect(nodeCT, "Encumbered") or
	EffectManager5E.hasEffect(nodeCT, "Speed-10") then
		nSpeedMod = nSpeedMod - 10;
	end

	if bDebug then Debug.console("nFGSpeedNew = " .. tostring(nFGSpeedNew)) end
	if bDebug then Debug.console("nSpeedMod = " .. tostring(nSpeedMod)) end
	local nSpeedFinal = nFGSpeedNew + nSpeedMod;
	if bDebug then Debug.console("nSpeedFinal = " .. tostring(nSpeedFinal)) end
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
		return '30';
	end
	if nSpeedFinal < 0 then
		return '0';
	end
	return tostring(nSpeedFinal);
end
-- luacheck: pop

--still needs to be called.	 check how rhagelstrom calls his
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
			EffectManager.addEffect("", "", nodeCT, { sName = "Exhausted; Speed: -" .. nSpeedAdjust }, bShowMsg);
		end
	else
		if nExhaustMod > 4 then
			EffectManager.addEffect("", "", nodeCT, { sName = "Exhausted; Speed: 0, MAXHP: 0.5" }, bShowMsg);
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

function checkProne(sourceNodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	if not sourceNodeCT then
		return;
	end

	local rCurrent = ActorManager.resolveActor(sourceNodeCT);
	local rSource = ActorManager.getCTNode(rCurrent);

	if Session.RulesetName ~= "5E" then
		if EffectManagerPFRPG2 then
			if not EffectManagerPFRPG2.hasEffectCondition(rSource, "Prone") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Unconscious") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Dead") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Paralyzed") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Dying") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Immobilized") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Petrified") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Restrained") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Grabbed") then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "Stunned") then
				return false
			elseif hasEffectFindString(rSource, "SPEED%s-:%s-none") then
				return false
			elseif hasEffectFindString(rSource, "Unable to Stand", false, true) then
				return false
			elseif EffectManagerPFRPG2.hasEffectCondition(rSource, "NOSTAND") then
				return false
			else
				return true
			end
		end
		if not EffectManager.hasCondition(rSource, "Prone") then
			return false
		elseif EffectManager.hasCondition(rSource, "Unconscious") then
			return false
		elseif hasEffectFindString(rSource, "SPEED%s-:%s-none") then
			return false
		elseif hasEffectFindString(rSource, "Unable to Stand", false, true) then
			return false
		elseif EffectManager.hasCondition(rSource, "NOSTAND") then
			return false
		else
			return true
		end
	end

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
	elseif hasEffectFindString(rSource, "SPEED%s-:%s-none") then
		return false
	elseif hasEffectFindString(rSource, "Unable to Stand", false, true) then
		return false
	elseif EffectManager5E.hasEffect(rSource, "NOSTAND") then
		return false
	elseif checkHideousLaughter(rSource) then
		return false
	else
		return true
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

	if hasEffectFindString(rActor, sClause3, true) then
		-- Debug.console("sClause3 found, returning true")
		return true
	end

	if hasEffectFindString(rActor, sClause2, false, false, true) then
		-- Debug.console("sClause2 found, returning true")
		return true
	end

	local hasClause1 = hasEffectFindString(rActor, sClause1, true)
	local hasClause5 = hasEffectFindString(rActor, sClause5, true)
	if hasClause1 or hasClause5 then
		bClauseExceptFound = true
		nMatch = nMatch + 1
		-- Debug.console("bClauseExceptFound & nMatch = " .. tostring(nMatch))
	elseif hasEffectFindString(rActor, sClause, false, true) then
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

-- luacheck: push ignore 561
function hasEffectFindString(rActor, sString, bWholeMatch, bCaseInsensitive, bStartsWith, bDebug)
	-- defaults: case sensitive, not starts with, not whole match, & not debug
	-- bWholeMatch, if true, overrides bStartsWith
	-- Debug.console("hasEffectFindString called")
	if not rActor or not sString then
		Debug.console("WalkThisWay.hasEffectFindString - not rActor or not sString")
		return
	end
	local aEffects;
	local tEffectCompParams;
	local sClause = sString

	if bCaseInsensitive then
		sClause = string.lower(sString)
		if bDebug then Debug.console("sClause = " .. tostring(sClause)) end
	end

	if EffectManagerBCE then
		tEffectCompParams = EffectManagerBCE.getEffectCompType(sClause);
		-- Debug.console("tEffectCompParams = " .. tostring(tEffectCompParams))
	end
	aEffects = DB.getChildList(ActorManager.getCTNode(rActor), 'effects');
	-- Debug.console("aEffects = " .. tostring(aEffects))

	-- Iterate through each effect
	for _, v in pairs(aEffects) do
		local nActive = DB.getValue(v, 'isactive', 0);
		-- Debug.console("nActive = " .. tostring(nActive))
		local bGo = false

		if EffectManagerBCE then
			local bActive = (tEffectCompParams.bIgnoreExpire and (nActive == 1)) or
				(not tEffectCompParams.bIgnoreExpire and (nActive ~= 0)) or
				(tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0));
			-- Debug.console("bActive = " .. tostring(bActive))

			if (not EffectManagerADND and (nActive ~= 0 or bActive)) or
			  (EffectManagerADND and ((tEffectCompParams.bIgnoreDisabledCheck and (nActive == 0)) or
			  (EffectManagerADND.isValidCheckEffect(rActor, v)))) then
				bGo = true
				-- Debug.console("EffectManagerADND results bGo = " .. tostring(bGo))
			end
		else
			if nActive ~= 0 then
				bGo = true
				-- Debug.console("not EffectManagerBCE & bGo = " .. tostring(bGo))
			end
		end
		if bDebug then Debug.console("bGo = " .. tostring(bGo)) end

		if bGo then
			local sLabel = DB.getValue(v, 'label', '');
			local sFinalLabel = sLabel
			if bCaseInsensitive then
				sFinalLabel = string.lower(sLabel)
				if bDebug then Debug.console("CaseInsensitive sFinalLabel = " .. tostring(sFinalLabel)) end
			end
			if bStartsWith and not bWholeMatch then
				sFinalLabel = string.sub(sLabel, 1, #sString)
				if bDebug then Debug.console("StartsWith sFinalLabel = " .. tostring(sFinalLabel)) end
			end
			if bDebug then Debug.console("sFinalLabel = " .. tostring(sFinalLabel)) end

			-- Check for match
			if bWholeMatch or bStartsWith then
				if sFinalLabel == sClause then
					if bDebug then Debug.console("wholeMatch or StartsWith found, returning true") end
					return true
				end
				if bDebug then Debug.console("bWholeMatch but no match") end
			else
				if bDebug then Debug.console("sClause = " .. tostring(sClause)) end
				local aFind = string.find(sFinalLabel, sClause)
				if bDebug then Debug.console("aFind = " .. tostring(aFind)) end
				if aFind then
					if bDebug then Debug.console("partial match found, returning true") end
					return true
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
	local sOwner = getControllingClient(sourceNodeCT);

	--here temporarily
	local nodeCTWtW = DB.createChild(sourceNodeCT, 'WalkThisWay');
	DB.setValue(nodeCTWtW, 'actorname', 'string', tostring(rSource.sName));
	local sCurrentSpeed = DB.getValue(nodeCTWtW, 'currentSpeed');
	if not sCurrentSpeed then
		local nFGSpeed = DB.getValue(sourceNodeCT, 'speed');
		DB.setValue(nodeCTWtW, 'currentSpeed', 'string', tostring(nFGSpeed));
	end
	Interface.openWindow('speed_window', nodeCTWtW)

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
	if getControllingClient(sourceNodeCT) then
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
	local rSource = ActorManager.getCTNode(rCurrent)

	if not OptionsManager.isOption('WHOLEEFFECT', 'on') then
		removeEffectClause(rSource, "Prone")
	end
	if Session.IsHost then
		if OptionsManager.isOption('WHOLEEFFECT', 'on') then
			removeEffectCaseInsensitive(rSource, "Prone");
		end
		if Session.RulesetName == "5E" then
			EffectManager.addEffect("", "", rSource, {
				sName = Interface.getString("stood_up"), nDuration = 1, sChangeState = "rts"
			}, "");
		end
	else
		if OptionsManager.isOption('WHOLEEFFECT', 'on') then
			notifyApplyHostCommands(rSource, 1, "Prone");
		end
		if Session.RulesetName == "5E" then
			notifyApplyHostCommands(rSource, 0, {
				sName = Interface.getString("stood_up"), nDuration = 1, sChangeState = "rts"
			});
		end
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

function queryClient(nodeCT)
	if OptionsManager.isOption('WTWON', 'off') then
		return;
	end
	local sOwner = getControllingClient(nodeCT);
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
	local sOwner = getControllingClient(nodeCT);

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

-- OOB message triggered command to do anything we need to execute at the host for the first source die rolls
	-- (which are run locally).
-- msgOOB.type
--		OOB_MSGTYPE_APPLYHGACMDS
-- msgOOB.sNodeCT - combat tracker entry to have the iAction applied - ex. combattracker.list.id-00010
-- msgOOB.iAction
--		0 - EffectManager.addEffect - add an effect
	-- (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
--				 msgOOB[*] type,value - list of aEffectVarMap effects to add
--		1 - EffectManager.removeEffect
--				msgOOB.sEffect - text of effect to remove
function handleApplyHostCommands(msgOOB)
	-- Debug.console("manager_combat_wtw:handleApplyHostCommands called");
	-- Debug.console("manager_combat_wtw:handleApplyHostCommands; msgOOB = "
	--	 .. tostring(msgOOB.type) .. "," .. tostring(msgOOB.iAction) .. "," .. tostring(msgOOB.sNodeCT)
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
		for k,_ in pairs(msgOOB) do
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
	--		0 - EffectManager.addEffect - add an effect
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
	--		0 - EffectManager.addEffect - add an effect
				-- (Did same logic for OOB encode/decode as found in CoreRPG\scripts\manager_effect.lua)
	--				 msgOOB[*] type,value - list of aEffectVarMap effects to add
	--		1 - EffectManager.removeEffect
	--				msgOOB.sEffect - text of effect to remove
	msgOOB.type = OOB_MSGTYPE_APPLYHCMDS;

	msgOOB.iAction = iAction;
	msgOOB.sNodeCT = DB.getPath(nodeCT);
	-- Debug.console("manager_combat_wtw:notifyApplyHostCommands; msgOOB = "
	--	 .. tostring(msgOOB.type) .. "," .. tostring(msgOOB.iAction) .. "," .. tostring(msgOOB.sNodeCT)
	-- );
	if msgOOB.iAction == 0 then
		for k,_ in pairs(rValues) do
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