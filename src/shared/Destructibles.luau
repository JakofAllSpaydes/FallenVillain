--!strict
-- Destructible prefab catalog (spec §5), and how to tell a destructible apart in the world: a prefab is a Model
-- under workspace.World.Destructibles carrying the `Destructible` CollectionService tag and a `Prefab` attribute
-- naming its catalog entry. Its parts are its chunks. Anything without the tag bounces you (spec §15); tagged
-- things break instead (milestone 4).

local CollectionService = game:GetService("CollectionService")

export type Family = "wood" | "stone" | "glass" | "metal"

export type Entry = {
	Health: number,
	Chunks: number,
	Value: number,
	Families: { Family },
	PopChance: number?,
}

local Destructibles = {}

Destructibles.Tag = "Destructible"
Destructibles.PrefabAttribute = "Prefab"
Destructibles.FolderName = "Destructibles" -- under workspace.World; the server's radius queries filter to it

Destructibles.Catalog = {
	Tree = { Health = 1, Chunks = 2, Value = 5, Families = { "wood" } },
	Fence = { Health = 1, Chunks = 1, Value = 2, Families = { "wood" } },
	Rock = { Health = 2, Chunks = 3, Value = 8, Families = { "stone" } },
	Lamp = { Health = 1, Chunks = 1, Value = 4, Families = { "metal" } },
	Car = { Health = 2, Chunks = 3, Value = 25, Families = { "metal" }, PopChance = 0.2 },
	SmallHouse = { Health = 4, Chunks = 4, Value = 60, Families = { "wood" } },
	Shop = { Health = 6, Chunks = 5, Value = 120, Families = { "stone", "glass" } },
	Tower = { Health = 10, Chunks = 5, Value = 300, Families = { "stone", "glass" } },
	RadioMast = { Health = 8, Chunks = 4, Value = 200, Families = { "metal" } },
	-- Landmarks (milestone 5 review: bigger silhouettes with layers to smash through).
	Pyramid = { Health = 14, Chunks = 5, Value = 450, Families = { "stone" } },
	Obelisk = { Health = 10, Chunks = 4, Value = 350, Families = { "stone" } },
	Arch = { Health = 12, Chunks = 3, Value = 400, Families = { "stone" } },
	Monolith = { Health = 18, Chunks = 3, Value = 700, Families = { "stone" } },
	Skyscraper = { Health = 20, Chunks = 9, Value = 900, Families = { "stone", "glass" } },
	Silo = { Health = 5, Chunks = 2, Value = 90, Families = { "metal" } },
	Windmill = { Health = 6, Chunks = 6, Value = 150, Families = { "wood" } },
	Statue = { Health = 8, Chunks = 3, Value = 250, Families = { "stone" } },
	Dome = { Health = 16, Chunks = 6, Value = 600, Families = { "stone", "glass" } },
} :: { [string]: Entry }

-- The tagged model a part belongs to, or nil.
function Destructibles.modelOf(instance: Instance?): Model?
	local current: Instance? = instance
	while current do
		if current:IsA("Model") and CollectionService:HasTag(current, Destructibles.Tag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Destructibles.isDestructible(instance: Instance): boolean
	return Destructibles.modelOf(instance) ~= nil
end

-- Catalog entry for a tagged model (from its Prefab attribute), or nil for an unknown prefab.
function Destructibles.entryOf(model: Model): Entry?
	local name = model:GetAttribute(Destructibles.PrefabAttribute)
	return if type(name) == "string" then Destructibles.Catalog[name] else nil
end

function Destructibles.folder(): Folder?
	local world = workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild(Destructibles.FolderName)
	return if folder and folder:IsA("Folder") then folder else nil
end

return Destructibles
