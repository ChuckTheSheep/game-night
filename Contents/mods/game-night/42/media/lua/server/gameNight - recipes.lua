require "recipecode"

Recipe.GameNight = {}

---@param items ArrayList
---@param result InventoryItem|InventoryContainer
---@param player IsoPlayer
function Recipe.GameNight.Unbox(items, result, player)

    local itemType = result:getType()
    local itemContainer = result:getInventory()
    local itemContainerDistribution = Distributions[1][itemType]

    print("a: itemContainerDistribution: ", itemContainerDistribution)

    if not itemContainerDistribution then return end

    print("b: itemContainerDistribution.rolls: ", itemContainerDistribution.rolls)

    if itemContainerDistribution.rolls <= 0 then return end

    print("c: good")

    for _=1, itemContainerDistribution.rolls do
        for k,item in pairs(itemContainerDistribution.items) do
            if type(item) == "string" then ItemPickerJava.tryAddItemToContainer(itemContainer, item, nil) end
        end
    end
end