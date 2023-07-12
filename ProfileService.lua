local Service = {}
--//Services//--
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
--//End of "Services"//--



--//Misc.//--
local DataStore, BackupStore, MetadataStore = nil, nil, DataStoreService:GetDataStore("TESTINGMETADATAV0000")
--//End of "Misc."//--



--//Arrays//--
Service.Profiles = {}
local Cache = {}
local settings = {
	StoreName = "";
	Version = 0;
	Template = {};
	DebugPriority = (game:GetService("RunService"):IsStudio() and 0) or math.huge;
	ReadDataAccess = false;
	MergeOld = nil;
	CacheFrequency = 30;
}
local TemplateMetadata = {
	SessionCount = 1;
	LastLoaded = 0;
	LastUnloaded = 0;
	LastServer = 0;
	LastStoreName = settings.StoreName;
	LastVersion = settings.Version;
	LastPlaceId = game.PlaceId;
	Purged = false;
}
--//End of "Arrays"//--



--//Main Functions//--
local function GetPlayerFromAny(StartArg)
	if typeof(StartArg) == "Instance" then if StartArg.Parent == Players then return StartArg end; return Players:FindFirstChild(StartArg.Name);
	elseif typeof(StartArg) == "string" then return Players:FindFirstChild(StartArg); 
	else return Players:GetPlayerByUserId(StartArg); end;
end
local function GetUserIdFromAny(StartArg)
	if typeof(StartArg) == "Instance" then if StartArg.Parent == Players then local Player = StartArg return Player.UserId end; return (Players:FindFirstChild(StartArg.Name) and Players:FindFirstChild(StartArg.Name).UserId) or nil;
	elseif typeof(StartArg) == "string" then return Players:GetUserIdFromNameAsync(StartArg); 
	else return StartArg end;
end
local function Reconcile(Data, Template)
	if not Data then Data = {} end;
	for TemplateProperty, TemplateValue in pairs(Template) do
		if not Data[TemplateProperty] then Data[TemplateProperty] = TemplateValue end;
	end
	return Data;
end
local function PriorityMessage(Level: number, Message: string, Type) if Level < settings.DebugPriority then return end; Type(Message); end;
local function LoadData(Profile, UserId)
	UserId = tostring(GetUserIdFromAny(UserId))

	local function PrepareData(Data)
		if Data then Data = HttpService:JSONDecode(Data) else Data = {} end

		Data = Reconcile(Data, settings.Template)
		local function DeepSet(CurrentPtr, DataPtr)
			for CurrentPt, DataPt in pairs(DataPtr) do
				if DataPt then
					if typeof(DataPt) == "table" then CurrentPtr[CurrentPt] = {}; DeepSet(CurrentPtr[CurrentPt], DataPt); else CurrentPtr[CurrentPt] = DataPt; end

				end

			end

		end
		DeepSet(Profile.Data, Data)

		Profile.Signals.Loaded.Succeeded:Fire(Data)

	end

	local Data = Cache[UserId]
	if Data ~= nil then PrepareData(Data) return end;
	PriorityMessage(1, "Data was not in Cache!", print)

	local Success, Data = pcall(DataStore.GetAsync, DataStore, UserId)
	if Success and Data then PrepareData(Data) return end;
	PriorityMessage(math.huge, "Data did not load!", warn)

	local Success, Data = pcall(BackupStore.GetAsync, BackupStore, UserId)
	if Success and Data then PrepareData(Data) return end;
	PriorityMessage(math.huge, "Data did not load in backup!", warn)

	if (settings.MergeOld == nil or Profile.Metadata.LastPlaceId ~= game.PlaceId) and (Profile.Metadata.LastVersion == settings.Version and Profile.Metadata.LastStoreName == settings.StoreName) then Profile.Signals.Loaded.Failed:Fire() return end;
	local LastStore = DataStoreService:GetDataStore(Profile.Metadata.LastStoreName .. "+" .. Profile.Metadata.LastVersion)
	if settings.MergeOld ~= nil then LastStore = DataStoreService:GetDataStore(settings.MergeOld) end
	if settings.MergeOld ~= false then
		local Success, Data = pcall(LastStore.GetAsync, LastStore, UserId)
		if Success and Data then PrepareData(Data) return end;

	end
	PriorityMessage(1, "This is a new player!", warn)
	PrepareData({})
end
local function SaveData(Data, UserId)
	Data = HttpService:JSONEncode(Data)
	UserId = tostring(GetUserIdFromAny(UserId))
	local function Transformer(OldData) return (Data ~= nil and Data) or OldData end;
	local Success, Err = true, nil

	local SuccessMain, ErrMain = pcall(DataStore.UpdateAsync, DataStore, UserId, Transformer)
	if not Success then if Success then Success = false; Err = ErrMain; end;  PriorityMessage(3, ErrMain, warn) end;

	local SuccessBackup, ErrBackup = pcall(BackupStore.UpdateAsync, BackupStore, UserId, Transformer)
	if not SuccessBackup then if Success then Success = false; Err = ErrBackup; end; PriorityMessage(3, ErrBackup, warn) end;

	return Success, Err
end
local function AttemptCache() for UserId, Data in pairs(Cache) do if SaveData(Data, UserId) then Cache[UserId] = nil end end; end;

--//End of "Main Functions"//--



--//Main//--
function Service:Purge(UserId) 
	UserId = tostring(GetUserIdFromAny(UserId))
	local Success, Err = pcall(DataStore.RemoveAsync, DataStore, UserId)
	if not Success then PriorityMessage(math.huge, Err, warn) return end; -- Debug.
	local Success, Err = pcall(BackupStore.RemoveAsync, BackupStore, UserId)
	if not Success then PriorityMessage(math.huge, Err, warn) return end; -- Debug.

	local Player = GetPlayerFromAny(UserId)
	if not Player then PriorityMessage(1, "Player doesn't exist on purge, player will not be kicked.", print) return end;

	local Profile = self.Profiles[Player]
	if not Profile then PriorityMessage(1, "Profile doesn't exist on purge, purged signal will not be fired.", print) return end;
	if not Profile.Signals.Purged then PriorityMessage(1, "Signal doesn't exist on purge, purged signal will not be fired.", print) return end;

	Profile.Signals.Purged:Fire()
	Profile.Metadata.Purged = true
	pcall(MetadataStore.UpdateAsync, MetadataStore, UserId, function(...) return Reconcile(Profile.Metadata, TemplateMetadata) or ... end)

end

function Service.Initialize(Settings: {[string]: any})
	for Property, Value in pairs(Settings) do settings[Property] = Value end
	DataStore = DataStoreService:GetDataStore(settings.StoreName .. "+" .. settings.Version)
	BackupStore = DataStoreService:GetDataStore(settings.StoreName .. "+" .. settings.Version .. "_Backup")

end
function Service.New(Player: Player)

	local ReadAccessPort = nil
	task.spawn(function()
		if not settings.ReadDataAccess then return end;
		if settings.ReadDataAccess:FindFirstChild(Player.Name) then return end;
		ReadAccessPort = Instance.new("Folder")
		ReadAccessPort.Name = Player.Name
		ReadAccessPort.Parent = settings.ReadDataAccess

	end)

	local Profile = {
		Data = nil;
		Signals = {
			Loaded = {Succeeded = Instance.new("BindableEvent"), Failed = Instance.new("BindableEvent")},
			Corruption = Instance.new("BindableEvent"),
			Purged = Instance.new("BindableEvent"),
			ListenToRelease = Instance.new("BindableEvent"),
		};
		ReadAccess = (ReadAccessPort ~= nil and ReadAccessPort) or nil,
		Metadata = table.clone(TemplateMetadata);
	}
	local Success, Data = pcall(MetadataStore.GetAsync, MetadataStore, Player.UserId)
	Data = HttpService:JSONDecode(Data)
	Profile.Metadata = Reconcile(Data, TemplateMetadata)

	print(Profile.Metadata)
	function Profile:Release()
		Profile.Metadata.LastUnloaded = tick()
		Profile.Metadata.LastServer = game.JobId or "StudioServer"
		Profile.Metadata.LastStoreName = settings.StoreName
		Profile.Metadata.LastVersion = settings.Version

		PriorityMessage(1, "Profile of " .. Player.Name .. " released!", print)
		PriorityMessage(1, Profile.Metadata.LastVersion, print)
		PriorityMessage(1, settings.Version, print)
		PriorityMessage(1, Profile.Metadata, print)

		local EncodedMetadata = HttpService:JSONEncode(Profile.Metadata)
		pcall(MetadataStore.UpdateAsync, MetadataStore, Player.UserId, function(OldMetadata) return (EncodedMetadata ~= nil and EncodedMetadata) or OldMetadata end)

		Profile.Signals.ListenToRelease:Fire()

		local function ThoroughDestroy(Table)
			for _, Signal in pairs(Table) do
				if Signal then
					if typeof(Signal) == "table" then ThoroughDestroy(Signal) 
					else Signal:Destroy()
					end;

				end

			end

		end
		ThoroughDestroy(Profile.Signals)
		if SaveData(Profile.Data, Player.UserId) then return end;

		Cache[Player.UserId] = Profile.Data
		Service.Profiles[Player] = nil
		gcinfo()
	end
	if Profile.ReadAccess then 
		local function DataMeta(BaseFolder)
			return {
				__newindex = function(self, index, data)
					if not rawget(self, index) then
						local Type = nil
						if typeof(data) == "string" then Type = "StringValue"
						elseif typeof(data) == "number" then Type = "NumberValue"
						elseif typeof(data) == "Instance" then Type = "ObjectValue"
						elseif typeof(data) == "Color3" then Type = "Color3Value"
						elseif typeof(data) == "BrickColor" then Type = "BrickColorValue"
						elseif typeof(data) == "CFrame" then Type = "CFrameValue"
						elseif typeof(data) == "Vector3" then Type = "Vector3Value"
						elseif typeof(data) == "boolean" then Type = "BoolValue"	
						elseif typeof(data) == "table" then Type = "Folder"
						end

						local NewInstance = Instance.new(Type)
						NewInstance.Name = index
						NewInstance.Parent = BaseFolder

						if Type == "Folder" then rawset(self, index,  setmetatable({}, DataMeta(NewInstance))); return end;
						NewInstance.Value = data

					end;
					rawset(self, index, data);

				end,
				__call = function(self, transform_type: string, index, data)
					if rawget(self, index) then 
						if transform_type:lower() == "increment" then rawset(self, index, rawget(self, index) + data) BaseFolder:FindFirstChild(index).Value = rawget(self, index);
						elseif transform_type:lower() == "set" then 
							if data == "__REMOVE__" then 
								if BaseFolder:FindFirstChild(index) then BaseFolder:FindFirstChild(index):Destroy() end
								rawset(self, index, nil) 
								return 
							end; 
							rawset(self, index, data)
							BaseFolder:FindFirstChild(index).Value = rawget(self, index) 
						end
					else
						if data == "__REMOVE__" then return end;
						local Type = nil
						if typeof(data) == "string" then Type = "StringValue"
						elseif typeof(data) == "number" then Type = "NumberValue"
						elseif typeof(data) == "Instance" then Type = "ObjectValue"
						elseif typeof(data) == "Color3" then Type = "Color3Value"
						elseif typeof(data) == "BrickColor" then Type = "BrickColorValue"
						elseif typeof(data) == "CFrame" then Type = "CFrameValue"
						elseif typeof(data) == "Vector3" then Type = "Vector3Value"
						elseif typeof(data) == "boolean" then Type = "BoolValue"	
						elseif typeof(data) == "table" then Type = "Folder"
						end

						local NewInstance = Instance.new(Type)
						NewInstance.Name = index
						NewInstance.Parent = BaseFolder

						if Type == "Folder" then rawset(self, index,  setmetatable({}, DataMeta(NewInstance))); return end;
						NewInstance.Value = data
						rawset(self, index, data);
					end;

				end,
			}
		end
		Profile.Data = setmetatable({}, DataMeta(Profile.ReadAccess))

	else
		Profile.Data = {}

	end

	task.spawn(LoadData, Profile, GetUserIdFromAny(Player))

	Player.AncestryChanged:Once(function() Profile:Release() end)
	Service.Profiles[Player] = Profile
	return Profile
end
function CacheMain()
	while task.wait(settings.CacheFrequency) do
		for _, Player in pairs(Players:GetChildren()) do
			if Player and Service.Profiles[Player] and not Cache[Player.UserId] then
				Cache[Player.UserId] = Service.Profiles[Player].Data

			end

		end
		task.spawn(AttemptCache)

	end

end

--//End of "Main"//--



--//Connections//--
task.spawn(CacheMain)
game:BindToClose(AttemptCache)
return Service
--//End of "Connections"//--
