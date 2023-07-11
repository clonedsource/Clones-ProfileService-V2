--//Services//--
local Players = game:GetService("Players")
local ProfileService = require(script.Parent.ProfileService)
--//End of "Services"//--



--//Misc.//--

--//End of "Misc."//--



--//Arrays//--

--//End of "Arrays"//--



--//Main Functions//--

--//End of "Main Functions"//--



--//Main//--
function PlayerAdded(Player)
	local Profile = ProfileService.New(Player)
	Profile.Signals.Loaded.Succeeded.Event:Connect(function(...)
		print(...)
		Profile.Data("Increment", "Money", 100)
		print(Profile.Data)
	end)
	
	
end
--//End of "Main"//--



--//Connections//--
ProfileService.Initialize({
	StoreName = "Testing";
	Version = 1;
	Template = {Cars = {}, CurrentCar = "", Money = 0,CarColor = Color3.new(1,0,0)};
	ReadDataAccess = game.ReplicatedStorage;
})
Players.PlayerAdded:Connect(PlayerAdded)
--//End of "Connections"//--
