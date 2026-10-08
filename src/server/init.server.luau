--!strict
-- Server entry point.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DestructionAuthority = require(script.DestructionAuthority)
local Presence = require(script.Presence)
local WorldGen = require(script.WorldGen)

-- Characters collide with nothing (spec §7, §10, §15 3a): the movement controller handles the ground
-- analytically and walls by raycast, so physical contact only ever kicked or tunnelled bodies at speed.
-- Movement raycasts use this group to skip characters too.
local CHARACTER_GROUP = "Characters"
PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
PhysicsService:CollisionGroupSetCollidable(CHARACTER_GROUP, CHARACTER_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(CHARACTER_GROUP, "Default", false)
-- Movement and aim raycasts carry this group: they see the world (Default) but never any character. (A ray
-- in the Characters group would ignore every world part, since Characters don't collide with Default.)
local RAY_GROUP = "MovementRays"
PhysicsService:RegisterCollisionGroup(RAY_GROUP)
PhysicsService:CollisionGroupSetCollidable(RAY_GROUP, CHARACTER_GROUP, false)

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

Presence.start()
DestructionAuthority.start()
WorldGen.generate()
