--!strict
-- Server entry point.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _Net = require(ReplicatedStorage.Shared.Net)

-- Characters never collide with each other (spec §7, §10); movement raycasts use this group to skip them too.
local CHARACTER_GROUP = "Characters"
PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
PhysicsService:CollisionGroupSetCollidable(CHARACTER_GROUP, CHARACTER_GROUP, false)

local function assignGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = CHARACTER_GROUP
	end
end

local function onCharacter(character: Model)
	for _, descendant in character:GetDescendants() do
		assignGroup(descendant)
	end
	character.DescendantAdded:Connect(assignGroup)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
