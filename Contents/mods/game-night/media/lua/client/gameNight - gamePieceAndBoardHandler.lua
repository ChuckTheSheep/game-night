local gamePieceAndBoardHandler = {}

gamePieceAndBoardHandler.itemTypes = {
    "Base.Dice", "Base.GamePieceWhite", "Base.GamePieceRed",
    "Base.GamePieceBlack", "Base.BackgammonBoard", "Base.CheckerBoard",
    "Base.ChessWhite","Base.ChessBlack","Base.PokerChips",
    --added

    "Base.DiceWhite",

    "Base.PokerChipsBlue","Base.PokerChipsYellow","Base.PokerChipsWhite","Base.PokerChipsBlack",
    "Base.PokerChipsOrange","Base.PokerChipsPurple","Base.PokerChipsGreen",

    "Base.GamePieceBlackBackgammon","Base.ChessBoard",
    "Base.ChessWhiteKing","Base.ChessBlackKing","Base.ChessWhiteBishop","Base.ChessBlackBishop",
    "Base.ChessWhiteQueen", "Base.ChessBlackQueen", "Base.ChessWhiteRook","Base.ChessBlackRook",
    "Base.ChessWhiteKnight", "Base.ChessBlackKnight",
}

gamePieceAndBoardHandler._itemTypes = nil
function gamePieceAndBoardHandler.generate_itemTypes()
    gamePieceAndBoardHandler._itemTypes = {}
    for _,itemType in pairs(gamePieceAndBoardHandler.itemTypes) do gamePieceAndBoardHandler._itemTypes[itemType] = true end
end

gamePieceAndBoardHandler.specials = {
    ["Base.Dice"]={ category = "Die", sides = 6 },
    ["Base.DiceWhite"]={ category = "Die", sides = 6 },
    ["Base.GamePieceRed"]={ flipTexture = true },
    ["Base.GamePieceBlack"]={ flipTexture = true },
    ["Base.BackgammonBoard"]={ category = "GameBoard" },
    ["Base.CheckerBoard"]={ category = "GameBoard" },
    ["Base.ChessBoard"]={ category = "GameBoard" },
}

function gamePieceAndBoardHandler.getGamePiece(gamePiece)
    return gamePieceAndBoardHandler._itemTypes[gamePiece:getFullType()]
end

---@param gamePiece InventoryItem
function gamePieceAndBoardHandler.handleDetails(gamePiece)

    local fullType = gamePiece:getFullType()
    if not gamePieceAndBoardHandler._itemTypes then gamePieceAndBoardHandler.generate_itemTypes() end
    if not gamePieceAndBoardHandler._itemTypes[fullType] then return end

    gamePiece:getTags():add("gameNight")
    gamePiece:getModData()["gameNight_sound"] = "pieceMove"

    local special = gamePieceAndBoardHandler.specials[fullType]

    local newCategory = special and special.category or "GamePiece"
    if newCategory then gamePiece:setDisplayCategory(newCategory) end

    local sides = special and special.sides
    if sides then gamePiece:getModData()["gameNight_dieSides"] = sides end

    local altState = gamePiece:getModData()["gameNight_altState"] or ""

    local texturePath = "inPlayTextures/"..gamePiece:getType()..altState..".png"
    local texture = Texture.trygetTexture(texturePath)
    if texture then gamePiece:getModData()["gameNight_textureInPlay"] = texture end

    local iconPath = "outOfPlayTextures/"..gamePiece:getType()..altState..".png"
    local icon = Texture.trygetTexture(iconPath)
    if icon then gamePiece:setTexture(icon) end

    if isClient() then
        local worldItem = gamePiece:getWorldItem()
        if worldItem then worldItem:transmitModData() end
    end

    ---@type ItemContainer
    local container = gamePiece:getContainer()
    if container then container:setDrawDirty(true) end
end


---@param gamePiece InventoryItem
function gamePieceAndBoardHandler.playSound(gamePiece, sound, player)
    if not player then return end
    sound = sound or gamePiece:getModData()["gameNight_sound"]
    if sound then player:getEmitter():playSound(sound) end
end


---@param gamePiece InventoryItem
function gamePieceAndBoardHandler.takeAction(player, gamePiece, onComplete)
    local xPos, yPos, zPos, square = 0, 0, 0, nil
    ---@type IsoWorldInventoryObject|IsoObject
    local worldItem = gamePiece:getWorldItem()
    if worldItem then
        square = worldItem:getSquare()
        xPos, yPos, zPos = worldItem:getWorldPosX()-worldItem:getX(), worldItem:getWorldPosY()-worldItem:getY(), worldItem:getWorldPosZ()-worldItem:getZ()
    end
    local pickUpAction = ISInventoryTransferAction:new(player, gamePiece, gamePiece:getContainer(), player:getInventory(), 1)
    if onComplete and type(onComplete)=="table" then pickUpAction.setOnComplete = onComplete end
    ISTimedActionQueue.add(pickUpAction)

    local dropAction = ISDropWorldItemAction:new(player, gamePiece, square, xPos, yPos, zPos, 0, false)
    dropAction.maxTime = 1
    ISTimedActionQueue.add(dropAction)
end


function gamePieceAndBoardHandler.setModDataValue(gamePiece, key, value)
    gamePiece:getModData()[key] = value
end


function gamePieceAndBoardHandler.rollDie(gamePiece, player)
    local sides = gamePiece:getModData()["gameNight_dieSides"]
    if not sides then return end

    local result = ZombRand(sides)+1
    result = result>1 and result or ""

    gamePieceAndBoardHandler.takeAction(player, gamePiece, {gamePieceAndBoardHandler.setModDataValue, "gameNight_altState", result})
    gamePieceAndBoardHandler.playSound(gamePiece, "dieRoll", player)
end



function gamePieceAndBoardHandler.flipPiece(gamePiece, player)
    local special = gamePieceAndBoardHandler.specials[gamePiece:getFullType()]
    if not special or not special.flipTexture then return end

    local current = gamePiece:getModData()["gameNight_altState"]
    local result = "Flipped"
    if current then result = nil end

    gamePieceAndBoardHandler.takeAction(player, gamePiece, {gamePieceAndBoardHandler.setModDataValue, "gameNight_altState", result})
    gamePieceAndBoardHandler.playSound(gamePiece, player)
end

return gamePieceAndBoardHandler