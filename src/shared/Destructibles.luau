--!strict
-- Destructible prefab catalog (spec §5), and how to tell a destructible apart in the world: its model (or the
-- part itself) carries the `Destructible` CollectionService tag. Anything without it bounces you (spec §15).

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
} :: { [string]: Entry }

function Destructibles.isDestructible(instance: Instance): boolean
	if CollectionService:HasTag(instance, Destructibles.Tag) then
		return true
	end
	local model = instance:FindFirstAncestorWhichIsA("Model")
	return model ~= nil and CollectionService:HasTag(model, Destructibles.Tag)
end

return Destructibles
