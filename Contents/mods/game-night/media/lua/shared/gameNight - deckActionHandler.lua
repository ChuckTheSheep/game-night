local gamePieceAndBoardHandler = require "gameNight - gamePieceAndBoardHandler"
--require "gameNight - deckSearchUI"
--require "gameNight - window"

local deckActionHandler = {}
deckActionHandler.staticDeckActions = {dealCard=true, dealCards=true}


deckActionHandler.deckCatalogues = {}
deckActionHandler.altDetails = {} --altNames, altIcons

function deckActionHandler.addDeck(itemType, cardIcons, altNames, altIcons)
    deckActionHandler.deckCatalogues[itemType] = cardIcons

    if altNames or altIcons then
        deckActionHandler.altDetails[itemType] = {}
        if altNames then deckActionHandler.altDetails[itemType].altNames = altNames end
        if altIcons then deckActionHandler.altDetails[itemType].altIcons = altIcons end
    end
end


function deckActionHandler.fetchAltName(card, deckItem)
    local itemType = deckItem:getType()
    if not deckActionHandler.altDetails[itemType] then return card end
    local altNames = deckActionHandler.altDetails[itemType].altNames

    local altName = altNames and altNames[card]
    return ((altName and (getTextOrNull("IGUI_"..altName) or altName)) or card)
end


function deckActionHandler.fetchAltIcon(card, deckItem)
    local itemType = deckItem:getType()
    if not deckActionHandler.altDetails[itemType] then return card end
    local altIcons = deckActionHandler.altDetails[itemType].altIcons

    local altIcon = altIcons and altIcons[card] or card
    return altIcon
end


function deckActionHandler.isDeckItem(deckItem)
    local deckData = deckItem:getModData()["gameNight_cardDeck"]
    if deckData and #deckData>0 then return true end
    return false
end


---@param deckItem InventoryItem
function deckActionHandler.getDeckStates(deckItem)
    local deckData = deckItem:getModData()["gameNight_cardDeck"]
    if not deckData then return end

    local cardFlipStates = deckItem:getModData()["gameNight_cardFlipped"]

    return deckData, cardFlipStates
end


deckActionHandler.cardWeight = 0.003
---@param deckItem InventoryItem
function deckActionHandler.handleDetails(deckItem)
    local deckStates, flippedStates = deckActionHandler.getDeckStates(deckItem)
    if not deckStates or not flippedStates then return end

    if #deckStates <= 0 then return end
    local itemType = deckItem:getType()
    local fullType = deckItem:getFullType()

    deckItem:setActualWeight(deckActionHandler.cardWeight*#deckStates)
    deckItem:getTags():add("gameNight")

    ---@type Texture
    local texture

    local special = gamePieceAndBoardHandler.specials[fullType]
    local category = special and special.category or (#deckStates>1 and "Deck" or "Card")
    deckItem:setDisplayCategory(category)

    deckItem:getModData()["gameNight_sound"] = special and special.moveSound or "cardFlip"

    local name_suffix = #deckStates>1 and " ["..#deckStates.."]" or ""

    if flippedStates[#deckStates] ~= true then

        local tooltip = getTextOrNull("Tooltip_"..deckStates[#deckStates])
        if tooltip then deckItem:setTooltip(tooltip) end

        local cardName = deckStates[#deckStates]

        local nameOfCard = deckActionHandler.fetchAltName(cardName, deckItem)
        deckItem:setName(nameOfCard..name_suffix)

        local cardFaceType = special and special.cardFaceType or itemType

        local textureToUse = deckActionHandler.fetchAltIcon(cardName, deckItem)
        texture = getTexture("media/textures/Item_"..cardFaceType.."/"..textureToUse..".png")

        deckItem:getModData()["gameNight_textureInPlay"] = texture

    else
        local textureID = #deckStates>1 and "deck" or "card"

        local tooltip = getTextOrNull("Tooltip_"..itemType)
        if tooltip then deckItem:setTooltip(tooltip) end

        local itemName = #deckStates<=1 and getTextOrNull("IGUI_"..deckItem:getType()) or getItemNameFromFullType(deckItem:getFullType())
        deckItem:setName(itemName..name_suffix)

        texture = getTexture("media/textures/Item_"..itemType.."/"..textureID..".png")
        deckItem:getModData()["gameNight_textureInPlay"] = getTexture("media/textures/Item_"..itemType.."/FlippedInPlay.png")
    end

    if texture then deckItem:setTexture(texture) end

end


---@param drawnCard string
---@param deckItem InventoryItem
function deckActionHandler.generateCard(drawnCard, deckItem, flipped, locations)
    --sq=sq, offsets={x=wiX,y=wiY,z=wiZ}, container=container
    local newCard = InventoryItemFactory.CreateItem(deckItem:getType())
    if newCard then

        if type(drawnCard)~="table" then drawnCard = {drawnCard} end
        if type(flipped)~="table" then flipped = {flipped} end

        newCard:getModData()["gameNight_cardDeck"] = drawnCard
        newCard:getModData()["gameNight_cardFlipped"] = flipped

        ---@type IsoObject|IsoWorldInventoryObject
        local worldItem = locations and locations.worldItem or deckItem:getWorldItem()
        local wiX = (locations and locations.offsets and locations.offsets.x) or (worldItem and (worldItem:getWorldPosX()-worldItem:getX())) or 0
        local wiY = (locations and locations.offsets and locations.offsets.y) or (worldItem and (worldItem:getWorldPosY()-worldItem:getY())) or 0
        local wiZ = (locations and locations.offsets and locations.offsets.z) or (worldItem and (worldItem:getWorldPosZ()-worldItem:getZ())) or 0

        ---@type IsoGridSquare
        local sq = (locations and locations.sq) or (worldItem and worldItem:getSquare())
        if sq then
            sq:AddWorldInventoryItem(newCard, wiX, wiY, wiZ)
        else
            ---@type ItemContainer
            local container = (locations and locations.container) or deckItem:getContainer()
            if container then container:AddItem(newCard) end
        end

        deckActionHandler.handleDetails(deckItem)
        deckActionHandler.handleDetails(newCard)

        local newCardWorldItem = newCard:getWorldItem()
        if newCardWorldItem then
            newCardWorldItem:getModData().gameNightCoolDown = getTimestampMs()+750
            newCardWorldItem:transmitModData()
        end
        
        return newCard
    end
end


function deckActionHandler._flipSpecificCard(deckItem, flipIndex)
    local deckStates, currentFlipStates = deckActionHandler.getDeckStates(deckItem)
    if not deckStates then return end
    deckItem:getModData()["gameNight_cardFlipped"][flipIndex] = not currentFlipStates[flipIndex]
end
function deckActionHandler.flipSpecificCard(deckItem, player, index)
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItem, {deckActionHandler._flipSpecificCard, deckItem, index}, deckActionHandler.handleDetails)
    gamePieceAndBoardHandler.playSound(deckItem, player)
end


function deckActionHandler._flipCard(deckItem)
    local deckStates, currentFlipStates = deckActionHandler.getDeckStates(deckItem)
    if not deckStates then return end

    local handleFlippedDeck = {}
    local handleFlippedStates = {}

    for n=#deckStates, 1, -1 do
        table.insert(handleFlippedDeck, deckStates[n])
        table.insert(handleFlippedStates, (not currentFlipStates[n]))
    end

    deckItem:getModData()["gameNight_cardDeck"] = handleFlippedDeck
    deckItem:getModData()["gameNight_cardFlipped"] = handleFlippedStates
end
function deckActionHandler.flipCard(deckItem, player)
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItem, {deckActionHandler._flipCard, deckItem}, deckActionHandler.handleDetails)
    gamePieceAndBoardHandler.playSound(deckItem, player)
end




function deckActionHandler._mergeDecks(deckItemA, deckItemB, index, player)
    if  deckItemA:getType() ~= deckItemB:getType() then return end

    local deckB, flippedB = deckActionHandler.getDeckStates(deckItemB)
    if not deckB then return end

    local deckA, flippedA = deckActionHandler.getDeckStates(deckItemA)
    if not deckA then return end

    index = index and math.max(index,1) or 1

    for i=1, #deckA do
        table.insert(deckB, index, deckA[i])
        table.insert(flippedB, index, flippedA[i])
    end

    gamePieceAndBoardHandler.safelyRemoveGamePiece(deckItemA)
end
---@param deckItemA InventoryItem
---@param deckItemB InventoryItem
function deckActionHandler.mergeDecks(deckItemA, deckItemB, player, index)
    if (deckItemA:getType() ~= deckItemB:getType()) or (deckItemA == deckItemB) then return end
    gamePieceAndBoardHandler.pickupGamePiece(player, deckItemA, true)
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItemB, {deckActionHandler._mergeDecks, deckItemA, deckItemB, index, player}, deckActionHandler.handleDetails)
    gamePieceAndBoardHandler.playSound(deckItemB, player)
end


---@param player IsoPlayer|IsoGameCharacter
function deckActionHandler._drawCards(num, deckItem, player, locations, faceUp)
    local deckStates, currentFlipStates = deckActionHandler.getDeckStates(deckItem)
    if not deckStates then return end

    local draw = #deckStates
    num = math.min(num, draw)

    local drawnCards = {}
    local drawnFlippedStates = {}
    for i=num, 1, -1 do
        local topCard = #deckStates
        local drawnCard, drawnFlip = deckStates[topCard], currentFlipStates[topCard]
        deckStates[topCard] = nil
        if currentFlipStates then currentFlipStates[topCard] = nil end
        table.insert(drawnCards, drawnCard)
        local flipState = drawnFlip
        if faceUp then flipState = false end
        table.insert(drawnFlippedStates, flipState)
    end
    local newCard = deckActionHandler.generateCard(drawnCards, deckItem, drawnFlippedStates, locations)
    if newCard then
        gamePieceAndBoardHandler.playSound(deckItem, player)
        deckActionHandler.processDrawnCard(deckItem, player, newCard)
    end

    return newCard
end


function deckActionHandler.processDrawnCard(deckItem, player, newCard)
    if not player then return end
    local fullType = deckItem:getFullType()
    local special = gamePieceAndBoardHandler.specials[fullType]
    local onDraw = special and special.onDraw

    local inHand = player and player:getPrimaryHandItem()
    local heldCards = inHand and deckActionHandler.isDeckItem(inHand)

    if onDraw and deckActionHandler[onDraw] then deckActionHandler[onDraw](newCard, deckItem) end

    if player and (newCard:getContainer() == player:getInventory()) then
        if not inHand then player:setPrimaryHandItem(newCard) end
        if heldCards then deckActionHandler.mergeDecks(newCard, inHand, player, 1) end
    end
end


function deckActionHandler.drawCards_isValid(deckItem, player, num)
    local deckStates, currentFlipStates = deckActionHandler.getDeckStates(deckItem)
    if deckStates and #deckStates >= num then return true end
    return false
end

---@param deckItem InventoryItem
function deckActionHandler.drawCards(deckItem, player, num)
    local locations = {container=player:getInventory()}
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItem, {deckActionHandler._drawCards, num, deckItem, player, locations, true}, deckActionHandler.handleDetails)
end

function deckActionHandler.drawCard(deckItem, player) deckActionHandler.drawCards(deckItem, player, 1) end


function deckActionHandler._dealCards(deckItem, player, n, x, y)
    local worldItem = deckItem:getWorldItem()
    x = x or worldItem and (worldItem:getWorldPosX()-worldItem:getX()) or ZombRandFloat(0.48,0.52)
    y = y or worldItem and (worldItem:getWorldPosY()-worldItem:getY()) or ZombRandFloat(0.48,0.52)
    local z = worldItem and (worldItem:getWorldPosZ()-worldItem:getZ()) or 0
    ---@type IsoGridSquare
    local sq = (worldItem and worldItem:getSquare()) or (gameNightWindow and gameNightWindow.instance and gameNightWindow.instance.square)
    deckActionHandler._drawCards(n, deckItem, player, { sq=sq, offsets={x=x,y=y,z=z} })
end

function deckActionHandler.dealCards(deckItem, player, n, x, y)
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItem, {deckActionHandler._dealCards, deckItem, player, n, x, y}, deckActionHandler.handleDetails)
end

function deckActionHandler.dealCard(deckItem, player, x, y) deckActionHandler.dealCards(deckItem, player, 1, x, y) end



function deckActionHandler._drawCardIndex(deckItem, player, drawIndex, locations)
    local deckStates, currentFlipStates = deckActionHandler.getDeckStates(deckItem)
    if not deckStates then return deckItem end

    local deckCount = #deckStates
    if deckCount <= 1 then return deckItem end

    drawIndex = drawIndex or ZombRand(deckCount)+1
    local drawnCard, drawnFlipped

    for i=1,deckCount do
        if i==drawIndex then
            drawnCard = deckStates[i]
            drawnFlipped = currentFlipStates[i]
            deckStates[i] = nil
            currentFlipStates[i] = nil
        end

        if i>drawIndex then
            if deckStates[i-1] == nil then
                deckStates[i-1] = deckStates[i]
                currentFlipStates[i-1] = currentFlipStates[i]
                deckStates[i] = nil
                currentFlipStates[i] = nil
            end
        end
    end

    local newCard = deckActionHandler.generateCard(drawnCard, deckItem, drawnFlipped, locations)
    deckActionHandler.processDrawnCard(deckItem, player, newCard)
    return newCard
end


---@param deckItem InventoryItem
function deckActionHandler.drawRandCard(deckItem, player)
    local locations = {container=player:getInventory()}
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItem, {deckActionHandler._drawCardIndex, deckItem, player, nil, locations}, deckActionHandler.handleDetails)
    gamePieceAndBoardHandler.playSound(deckItem, player)
end


---@param deckItem InventoryItem
function deckActionHandler.drawSpecificCard(deckItem, player, index)
    local locations = {container=player:getInventory()}
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItem, {deckActionHandler._drawCardIndex, deckItem, player, index, locations}, deckActionHandler.handleDetails)
    gamePieceAndBoardHandler.playSound(deckItem, player)
end


function deckActionHandler._shuffleCards(deckItem)
    local deckStates, currentFlipStates = deckActionHandler.getDeckStates(deckItem)
    if not deckStates then return end

    for origIndex = #deckStates, 2, -1 do
        local shuffledIndex = ZombRand(origIndex)+1
        currentFlipStates[origIndex], currentFlipStates[shuffledIndex] = currentFlipStates[shuffledIndex], currentFlipStates[origIndex]
        deckStates[origIndex], deckStates[shuffledIndex] = deckStates[shuffledIndex], deckStates[origIndex]
    end
end
function deckActionHandler.shuffleCards(deckItem, player)
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItem, {deckActionHandler._shuffleCards, deckItem}, deckActionHandler.handleDetails)
    gamePieceAndBoardHandler.playSound(deckItem, player)
end


function deckActionHandler._searchDeck(deckItem, player)
    if deckActionHandler.isDeckItem(deckItem) then gameNightDeckSearch.open(player, deckItem) end
end
function deckActionHandler.searchDeck(deckItem, player)
    gamePieceAndBoardHandler.pickupAndPlaceGamePiece(player, deckItem, {deckActionHandler._searchDeck, deckItem, player}, deckActionHandler.handleDetails)
    gamePieceAndBoardHandler.playSound(deckItem, player)
end


function deckActionHandler.examineCard(deckItem, player, index)
    if deckActionHandler.isDeckItem(deckItem) then gameNightCardExamine.open(player, deckItem, true, index) end
end


return deckActionHandler
