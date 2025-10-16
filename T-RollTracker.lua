--[[
	T-RollTracker v1.18 RU Remaster for Turtle WoW
	Original author: Coth of Gilneas
	RU Remaster by: Misha (Wht Mst)
	GitHub: https://github.com/whtmst/T-RollTracker
	
	Based on RollTracker by Coth of Gilneas
	Considers any party/raid message that contains any one of:
		* Roll
		* RTS
		* RTU
	and an item link in one sentence to be the herald of a roll event.
	Last update:	1.18
	Tested for:		Turtle WoW
]]--

local RollArray
local RollCount
local AddNewRolls

function TRollTracker_OnLoad()
	-- Register events.
	this:RegisterEvent("CHAT_MSG_SYSTEM")
	this:RegisterEvent("CHAT_MSG_PARTY")
	this:RegisterEvent("CHAT_MSG_RAID")
	this:RegisterEvent("CHAT_MSG_RAID_LEADER")
	this:RegisterEvent("CHAT_MSG_RAID_WARNING")

	-- Setup slash commands.
	SlashCmdList["TROLLTRACKER"] = TRollTracker_OnSlashCommand
	SLASH_TROLLTRACKER1 = "/troll"
	SLASH_TROLLTRACKER2 = "/trolltracker"
	
	-- Register for dragging.  Left button moves, right button resizes.
	this:SetMinResize(175,250)
	this:RegisterForDrag("LeftButton", "RightButton")
	
	-- Initialize variables
	RollCount = 0
	RollArray = {}
	AddNewRolls = true
	RollInProgress = false
	RTitemname = ""
	TRollTracker_Options = {
	StayHidden = false,
	}
	
	TRollTracker_UpdateList()
end

function TRollTracker_UpdateList()
	local index
	local rolls
	local rollText
	
	rolls = TRollTracker_GetSortedRolls()
	TRollTracker_CheckTies(rolls)
	TRollTrackerFrameStatusText:SetText(TRollTracker_If(table.getn(rolls) == 1, "1 бросок", string.format("%d бросков",table.getn(rolls))))
	rollText = ""
	for index in rolls do
		rollText = string.format("|c%s%d|r: |c%s%s%s%s|r\n",
				TRollTracker_If(rolls[index].Tie, "ffffff00", "ffffffff"),
				rolls[index].Roll, 
				TRollTracker_If( (rolls[index].Low ~= 1 or rolls[index].High ~= 100) or (rolls[index].RollNumber > 1), "ffffcccc", "ffffffff"),
				rolls[index].Name, 
				TRollTracker_If(rolls[index].Low ~= 1 or rolls[index].High ~= 100, format(" (%d-%d)", rolls[index].Low, rolls[index].High), ""), 
				TRollTracker_If(rolls[index].RollNumber > 1, format(" [%d]", rolls[index].RollNumber), "")) .. rollText
	end
	TRollTrackerRollText:SetText(rollText)
	TRollTrackerFrameRollScrollFrame:UpdateScrollChildRect()
end

function TRollTracker_CheckTies(rolls)
	local index
	for index in rolls do
		rolls[index].Tie = false
		if rolls[index - 1] and rolls[index].Roll == rolls[index - 1].Roll then
			rolls[index].Tie = true
			rolls[index - 1].Tie = true
		end
	end	
end

function TRollTracker_OnSlashCommand(msg)
	if msg == "clear" then
		TRollTracker_ClearRolls()
	elseif msg == "hide" then
		TRollTracker_Options.StayHidden = true
		TRollTracker_HideRollWindow()
	elseif msg == "help" then
		TRollTracker_PrintHelp()
	elseif msg == "" then
		if TRollTrackerFrame:IsVisible() then
			TRollTracker_HideRollWindow()
		else
			TRollTracker_Options.StayHidden = false
			TRollTracker_ShowRollWindow()
		end
	else
		TRollTracker_PrintHelp()
	end
end

function TRollTracker_ShowRollWindow()
	if not TRollTracker_Options.StayHidden then
		ShowUIPanel(TRollTrackerFrame)
		TRollTracker_UpdateList()
	end
end

function TRollTracker_HideRollWindow()
	HideUIPanel(TRollTrackerFrame)
end

-- Process Start From Chat

function TRollTracker_OnEvent(event)
	if event == "CHAT_MSG_SYSTEM" then
		if RollInProgress then 
			TRollTracker_OnSystemMessage()
		end
	else
	local msg = arg1
	if not RollInProgress then
		if TRollTracker_isroll(msg) then
			RTitemname = string.sub(msg, string.find(msg, "[", 1, true) + 1, string.find(msg, "]", 1, true) - 1)
			TRollTracker_Print("Броски за " .. RTitemname .. " очищены.")
			local index
			for index in RollArray do
				RollArray[index].Selected = false
			end
			TRollTracker_UpdateList()
			RollInProgress = true
			TRollTracker_ShowRollWindow()	
		end
	end
	end
end

function TRollTracker_isroll(msg)
	local validkey = {"^roll ", "^rtu ", "^rts ", " roll$", " rtu$", " rts$", " roll ", " rtu ", " rts "}
	if string.find(msg, "|Hitem:", 1, true) then
		for k, v in validkey do
			if string.find(string.lower(msg), v) then
			return true
			end
		end
	end
end

function TRollTracker_AnnounceWinner()
	local roll = TRollTracker_GetSortedRolls()
	local entry = table.getn(roll)
	if entry > 0 then
	local winner = roll[entry].Name
	local winroll = roll[entry].Roll
	if RTitemname ~= "" then
	RTitemname = " " .. RTitemname
	end
	local winmsg = winner .. " выигрывает" .. RTitemname .. " с броском " .. winroll .. "!"
		if GetNumRaidMembers() > 0 then
		SendChatMessage(winmsg, "RAID")
		elseif GetNumPartyMembers() > 0 then
		SendChatMessage(winmsg, "PARTY")
		else
		TRollTracker_Print(winmsg)
		end
	RollInProgress = false
	RTitemname = ""
	end
end

function TRollTracker_OnSystemMessage()
	local name, roll, low, high
	for name, roll, low, high in string.gfind(arg1, "([^%s]+) rolls (%d+) %((%d+)%-(%d+)%)$") do
		TRollTracker_OnRoll(name, tonumber(roll), tonumber(low), tonumber(high))
	end
	
end

function TRollTracker_OnRoll(name, roll, low, high)
	RollCount = RollCount + 1
	RollArray[RollCount] = {Name = name, Roll = roll, Low = low, High = high, Selected = true, RollNumber = 0, Tie=false}
	TRollTracker_ShowRollWindow()
end

function TRollTracker_GetSelected(array)
	local result = {}
	local index
	for index in array do
		if array[index].Selected then
			table.insert(result, array[index])
		end
	end
	return result
end

function TRollTracker_GetSortedRolls()
	local names = {}
	local selected = TRollTracker_GetSelected(RollArray)
	local index
	for index in selected do
		if names[selected[index].Name] then
			names[selected[index].Name] = names[selected[index].Name] + 1
			selected[index].RollNumber = names[selected[index].Name]
		else
			names[selected[index].Name] = 1
			selected[index].RollNumber = 1
		end
		if selected[index].Low ~= 1 or selected[index].High ~= 100 or selected[index].RollNumber > 1 then
			table.remove(selected, index)
			RollCount = RollCount - 1
		end
	end
	table.sort(selected, TRollTracker_CompareRolls)
	return selected
end

function TRollTracker_If(expr, a, b)
	if expr then 
		return a
	else
		return b
	end
end

function TRollTracker_ClearRolls()
	RollArray = {}
	TRollTracker_Print("Все броски очищены.")
	TRollTracker_UpdateList()
end

function TRollTracker_Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	end
end

function TRollTracker_PrintHelp()
	TRollTracker_Print("T-RollTracker от Misha (Wht Mst). Основан на RollTracker от Coth с сервера Gilneas.") 
	TRollTracker_Print("/troll                Показать/скрыть окно трекера бросков." ) 
	TRollTracker_Print("/troll hide           Скрыть окно трекера (отключает обнаружение бросков)." ) 
	TRollTracker_Print("/troll clear          Очистить все сохраненные броски." )
	TRollTracker_Print("/troll help           Показать эту справку." )
end

function TRollTracker_CompareRolls(a, b)
	return a.Roll < b.Roll
end

function TRollTracker_OnDragStart()
	if arg1 == "RightButton" then
		this:StartMoving() -- Used to be this:StartSizing("BOTTOMRIGHT") but disabled as no longer needed
	else
		this:StartMoving()
	end

end

function TRollTracker_OnDragStop()
	this:StopMovingOrSizing()
end

function TRollTracker_OnStartButtonClick()
	RollInProgress = true
	RTitemname = ""
	local index
	for index in RollArray do
		RollArray[index].Selected = false
	end
	TRollTracker_Print("Отслеживание бросков начато. Все броски очищены.")
	TRollTracker_UpdateList()
end

function TRollTracker_OnStopButtonClick()
	RollInProgress = false
	TRollTracker_Print("Отслеживание бросков остановлено.")
end

function TRollTracker_OnAnnounceButtonClick()
	TRollTracker_AnnounceWinner()
end

function TRollTracker_OnCloseButtonClick()
	TRollTracker_ClearRolls()
	RollInProgress = false
	TRollTracker_HideRollWindow()
end