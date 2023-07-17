--//Services//--
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
--//End of "Services"//--



--//Misc.//--
local Container = ReplicatedStorage.Container
local ContainerEvents = Container.Events
local NotificationEvents = ContainerEvents.Notification
local ServerNotification, PlayerNotification = NotificationEvents.ServerNotification, NotificationEvents.PlayerNotification

local ScriptContainer = ServerScriptService.Container
local DataScripts = ScriptContainer.DataScripts
local ProfileService = require(DataScripts.ProfileService)

local GameEvents = ContainerEvents.Game
local Gravity = GameEvents.Gravity

local BadgeEvents = ContainerEvents.Badges
local BadgeGive = BadgeEvents.Give


local SFX = ReplicatedStorage.SFX
local RoundSounds = SFX.RoundSounds:GetChildren()


local Events = script:GetChildren()
local Plates = workspace.Plates

local Winner = nil
local AccurateGravity = workspace.Gravity

local Min = 2
--//End of "Misc."//--



--//Arrays//--
local AlivePlayers = {}
local EventsList = {}
--//End of "Arrays"//--



--//Main Functions//--
local function Lerp(a, b, t) return a + ((b - a) * t); end;
local function ResetWorkspaceSettings()
	workspace.Gravity = AccurateGravity
	
end

local function ResetGameInstance()
	for _, Folder in pairs(workspace.GameInstance:GetChildren()) do
		if Folder then Folder:ClearAllChildren() end
		
	end
	
end

local function ChooseEvent(PlayerSet: {}, Rating: number)
	local ChosenModule = nil
	while ChosenModule == nil do
		for EventIdx, Event in ipairs(Events) do
			local Choice = math.random(1, Event:GetAttribute("Bias"))
			if Choice == Event:GetAttribute("Bias") then ChosenModule = Event Event:SetAttribute("Bias", Event:GetAttribute("Bias") + 1) break end
			if Event:GetAttribute("Bias") >= 10 then Event:SetAttribute("Bias", 2) end -- Resets attributes
			
		end
		task.wait()
	end
	
	ServerNotification:FireAllClients(tostring(coroutine.running()) .. "-1",ChosenModule:GetAttribute("Message"),{.75 * (1/Rating), Enum.EasingStyle.Exponential}, {Resolution = 50}, 1.25 * (1/Rating) )
	task.wait(2.5)
	local Message = require(ChosenModule)(PlayerSet, Rating)
	if Rating < 3 then
		task.delay(3, ServerNotification.FireAllClients, ServerNotification, tostring(coroutine.running()) .. "-2",Message,{.75 * (1/Rating), Enum.EasingStyle.Exponential}, {Resolution = 50}, 2 * (1/Rating))
	end
	table.insert(EventsList, ChosenModule.Name)
	
end

local function GetAlive()
	local Characters = {}
	for _, Plate in pairs(workspace.Plates:GetChildren()) do
		if Plate and workspace:FindFirstChild(Plate.Name) and workspace[Plate.Name].Humanoid.Health > 0 then
			table.insert(Characters, Players[Plate.Name])

		end

	end

	return Characters
end

local function PlayerHandler(Player: Player)
	Player:SetAttribute("RoundSynergy", 0)
	local Plate = workspace.Plates[Player.Name]
	local Character = Player.Character
	
	local Profile = ProfileService.Profiles[Player]
	if Profile then
		Character.Humanoid:SetAttribute("NormalMaxHealth", Lerp(82,118, math.abs(50 - math.clamp(Profile.Data.Synergy, -50, 50))/100))
		Character.Humanoid.MaxHealth = Character.Humanoid:GetAttribute("NormalMaxHealth")
		Character.Humanoid.Health = Character.Humanoid:GetAttribute("NormalMaxHealth")
		for _, Cosmetic in pairs(Profile.Data.CurrentCosmetics) do
			local ReplicatedCosmetic = Container.Misc.Cosmetics:FindFirstChild(Cosmetic)
			if Cosmetic and ReplicatedCosmetic then
				if ReplicatedCosmetic.ClassName == "Texture" then
					for _, Face in pairs(Enum.NormalId:GetEnumItems()) do
						local NewCosmetic = ReplicatedCosmetic:Clone()
						NewCosmetic.Parent = Plate
						NewCosmetic.Face = Face
						NewCosmetic.Name ..= "-" .. tostring(Face)
						
					end
				else
					local ClonedCosmetic = ReplicatedCosmetic:Clone()
					ClonedCosmetic.Parent = Plate 
					
				end
				
			end
			
		end
		
	end

	Character.Humanoid.Died:Wait()
	table.remove(AlivePlayers,table.find(AlivePlayers, Player))
	if AlivePlayers[1] then
		Winner = AlivePlayers[1].Name
		
	end
	
	if Character:FindFirstChild("Torso") then
		for _, Obj in pairs(Character.Torso:GetChildren()) do
			if Obj and Obj.ClassName == "StringValue" and Obj.Name:find("Bind_") then workspace[Obj.Value].Humanoid.Health = 0; end;
		end
		
	end
	
	Gravity:FireClient(Player, workspace.Gravity)
	ServerNotification:FireAllClients(tostring(coroutine.running()) .. "-1",Player.Name .. " has fallen.",{.75, Enum.EasingStyle.Exponential}, {Resolution = 50}, 1.25)

	TweenService:Create(Plate, TweenInfo.new(3, Enum.EasingStyle.Linear), {
		Position = Plate.Position - Vector3.new(0,3,0);
		Transparency = 1;
	}):Play()
	task.wait(3)
	
	Plate:Destroy()

end

local function UpdateSynergy(Player)
	if not Player then return; end;
	if not Player:GetAttribute("RoundSynergy") then return; end;
	local Profile = ProfileService.Profiles[Player] if not Profile then return; end;
	Profile.Data("Increment", "Synergy", Player:GetAttribute("RoundSynergy"))
	
	PlayerNotification:FireClient(Player, "Your synergy has changed.", 3)

end

local function ChoosePlate()
	local Plate = nil
	while Plate == nil do
		local AllPlates = workspace.Plates:GetChildren()
		local RanPlate = AllPlates[math.random(1, #AllPlates)]
		if RanPlate.Name == "Plate" then Plate = RanPlate end
		task.wait()
	end
	return Plate
end

local function NewAlive()
	local Characters = {}
	AlivePlayers = Players:GetChildren()
	for _, Player in pairs(Players:GetChildren()) do
		local Character = Player.Character or workspace:FindFirstChild(Player.Name)
		if Player and Character and not Character:GetAttribute("AFK") and Character.Humanoid.Health > 0 then
			local GivenPlate = ChoosePlate()
			
			--Player.Character:Destroy()
			Player:LoadCharacter()
			--Player.Character:SetAttribute("Divine", true)
			if not Player.Character then Player.CharacterAdded:Wait() end
			
			task.spawn(UpdateSynergy, Player)
			table.insert(Characters, Character)
			GivenPlate.Name = Player.Name
			Player.Character:MoveTo(GivenPlate.Position)
			task.spawn(PlayerHandler, Player)
			
		end
		
	end
	
	for _, Plate in pairs(workspace.Plates:GetChildren()) do
		if Plate and Plate.Name == "Plate" then Plate:Destroy() end
	end
	
	return Characters
end

local function PlayRoundSound()
	local Sound = RoundSounds[math.random(1, #RoundSounds)]:Clone()
	Sound.Parent = workspace
	Sound.PlayOnRemove = true
	Sound:Destroy()
	
end

local function GiveTokens()
	local function GivePlayer(Player)
		local Profile = ProfileService.Profiles[Player]
		if not Profile then print("MISSING PROFILE!") Player:LoadCharacter() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) return end;
		if not Profile.Data then print("MISSING DATA!!!") return end;
		if not Profile.Data.Tokens then print("MISSING TOKENS!!!") return end;
		PlayerNotification:FireClient(Player, "You've gained a token for surviving an event.", 3); 
		Profile.Data("Increment", "Tokens", 1)
		
	end
	
	for _, Player in pairs(GetAlive()) do
		if Player then 
			task.spawn(GivePlayer, Player)
			
		end
		
	end
	
end
local function GiveBadge(PlayerTable, Id)
	for _, Player in pairs(PlayerTable) do
		if Player then BadgeGive:Fire(Player.UserId, Id); end;
		
	end
	
end
--//End of "Main Functions"//--



--//Main//--
function Main()
	Plates.Parent = game
	
	table.sort(Events, function(A, B) return A:GetAttribute("Bias") < B:GetAttribute("Bias") end)
	task.wait(2)
	
	while true do
		if #game.Players:GetChildren() < Min then
			ServerNotification:FireAllClients(tostring(coroutine.running()) .. "-1","Minimum of 2 Players Required!",{.85, Enum.EasingStyle.Exponential}, {Resolution = 50}, math.huge)
			repeat task.wait(1) until #game.Players:GetChildren() >= Min
			
		end
		
		
		
		local firstTick = tick()
		ServerNotification:FireAllClients(tostring(coroutine.running()) .. "-2","New Round Begins Shortly.",{.85, Enum.EasingStyle.Exponential}, {Resolution = 50}, 1.8)

		task.wait(3)
		
		
		if workspace:FindFirstChild("Plates") then workspace.Plates:Destroy() end
		Plates:Clone().Parent = workspace
		Winner = nil

		local ValidCharacters = NewAlive()
		for _, Character in pairs(ValidCharacters) do
			Character:MoveTo(workspace.Plates[Character.Name].Position)

		end

		local Rate = 16
		local Rating = 1
		
		EventsList = {}
		local function EventDistance(Event1: string, Event2: string)
			if not table.find(EventsList, Event1) then return math.huge end;
			local Event1Idx = table.find(EventsList, Event1)
			if not table.find(EventsList, Event2) then return math.huge end;
			local Event2Idx = table.find(EventsList, Event2)
			return math.abs(Event1Idx - Event2Idx)
		end
		while #GetAlive() >= Min do
			if Rating < math.clamp(math.floor(((tick()-firstTick)/120)), 1, 5) then
				ServerNotification:FireAllClients(tostring(coroutine.running()) .. "-3","The difficulty is now " .. math.clamp(math.floor(((tick()-firstTick)/10)), 1, 5) .. "!",{.85, Enum.EasingStyle.Exponential}, {Resolution = 50}, 1.8)
				Rating = math.clamp(math.floor(((tick()-firstTick)/120)), 1, 5)
				task.wait(3.5)
			end
			
			PlayRoundSound()
			GiveTokens()
			
			task.spawn(ChooseEvent, GetAlive(), math.clamp(math.floor(((tick()-firstTick)/120)), 1, 5))
			if EventDistance("PlateNature","PlateDryer") == 1 then GiveBadge(Players:GetChildren(), 2148326848) end -- Demeters Karma Badge.
			task.wait(Rate * (1/Rating))
			
			
		end
		
		if game.Players:FindFirstChild(Winner) then
			local Profile = ProfileService.Profiles[game.Players:FindFirstChild(Winner)]
			if Profile then
				Profile.Data("Increment", "Wins", 1)
			end
			
		end
		
		if GetAlive()[1] then Players[GetAlive()[1].Name]:LoadCharacter() end;
		
		task.spawn(ResetGameInstance)
		task.spawn(ResetWorkspaceSettings)
		
		ServerNotification:FireAllClients(tostring(coroutine.running()) .. "-4", ((Winner ~= nil and Winner) or "") .. " won this match after " .. math.floor((tick()-firstTick)/60) .. " minute(s)!",{.85, Enum.EasingStyle.Exponential}, {Resolution = 50}, 1.8)
		
		task.wait(4)
		ServerNotification:FireAllClients(tostring(coroutine.running()) .. "-5", "Intermission",{.85, Enum.EasingStyle.Exponential}, {Resolution = 50}, math.huge)
		task.wait(25)
		
	end
	
end
function PlayerRemoving(Player)
	if not workspace:FindFirstChild("Plates") then return end;
	if not workspace.Plates:FindFirstChild(Player.Name) then return end;
	workspace.Plates:FindFirstChild(Player.Name):Destroy();
	
end
--//End of "Main"//--



--//Connections//--
task.spawn(Main)
Players.PlayerRemoving:Connect(PlayerRemoving)
--//End of "Connections"//--
