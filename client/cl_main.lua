local Bridge = exports['void_bridge']:GetBridge()

-- Table tracking locally spawned bag props
local spawnedBags = {}
local isBusy = false

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------

local function DebugPrint(...)
    if Config.Debug then
        print("^4[void_clothingbag]^7", ...)
    end
end

-- Helper to load prop models safely
local function LoadModel(modelHash)
    if not IsModelValid(modelHash) then return false end
    RequestModel(modelHash)
    local timeout = 1000
    while not HasModelLoaded(modelHash) and timeout > 0 do
        Wait(10)
        timeout = timeout - 10
    end
    return HasModelLoaded(modelHash)
end

-- Bends down and places the bag in front of the player, snapping it to the ground Z
local function GetPlacementCoords()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local rad = math.rad(heading)
    
    -- Compute coordinates 1.0 meter in front of player
    local spawnX = playerCoords.x + (math.sin(-rad) * 0.9)
    local spawnY = playerCoords.y + (math.cos(-rad) * 0.9)
    
    -- Raycast down to find ground level
    local groundZ = playerCoords.z
    local success, z = GetGroundZFor_3dCoord(spawnX, spawnY, playerCoords.z + 1.0, 0)
    if success then
        groundZ = z
    else
        -- Fallback: raycast down to ensure it snaps to surfaces
        local ray = StartShapeTestRay(spawnX, spawnY, playerCoords.z + 2.0, spawnX, spawnY, playerCoords.z - 2.0, 1, playerPed, 0)
        local _, hit, endCoords, _, _ = GetShapeTestResult(ray)
        if hit ~= 0 then
            groundZ = endCoords.z
        end
    end
    
    -- Face the bag toward the player (heading + 180)
    return vector3(spawnX, spawnY, groundZ), (heading + 180.0) % 360.0
end

-- Open the specified clothing system
local function OpenClothingMenu()
    local system = Config.ClothingSystem
    DebugPrint("Attempting to open outfit menu using clothing system: " .. system)
    
    if system == "illenium-appearance" then
        TriggerEvent("illenium-appearance:client:openOutfitMenu")
    elseif system == "qb-clothing" then
        TriggerEvent("qb-clothing:client:openOutfitMenu")
    elseif system == "fivem-appearance" then
        if GetResourceState('fivem-appearance') == 'started' then
            pcall(function()
                exports["fivem-appearance"]:openWardrobe()
            end)
        else
            TriggerEvent("fivem-appearance:client:openOutfitMenu")
        end
    elseif system == "ox_appearance" then
        TriggerEvent("ox_appearance:wardrobe")
    elseif system == "custom" then
        if Config.OpenCustomOutfitMenu then
            Config.OpenCustomOutfitMenu()
        end
    else
        print(("^1[void_clothingbag] Unknown clothing system configured: %s^7"):format(system))
    end
end

-------------------------------------------------------------------------------
-- CORE LOGIC & SYNC
-------------------------------------------------------------------------------

-- Spawns bag props locally for the synced list
local function CreateLocalBag(bagId, bagData)
    if spawnedBags[bagId] then return end
    
    local itemConf = Config.BagItems[bagData.item]
    if not itemConf then return end
    
    local modelHash = GetHashKey(itemConf.propModel)
    if not LoadModel(modelHash) then
        print(("^1[void_clothingbag] Error: Failed to load prop model '%s'. Make sure this prop exists on your server game build!^7"):format(itemConf.propModel))
        return
    end
    
    if not bagData.coords then
        print(("^1[void_clothingbag] Error: Received nil coordinates for bag ID '%s'^7"):format(bagId))
        return
    end
    
    local x, y, z
    if type(bagData.coords) == "vector3" then
        x, y, z = bagData.coords.x, bagData.coords.y, bagData.coords.z
    elseif type(bagData.coords) == "table" then
        x, y, z = bagData.coords.x or bagData.coords[1], bagData.coords.y or bagData.coords[2], bagData.coords.z or bagData.coords[3]
    else
        x, y, z = tonumber(bagData.coords.x), tonumber(bagData.coords.y), tonumber(bagData.coords.z)
    end
    
    if not x or not y or not z then
        print(("^1[void_clothingbag] Error: Invalid coordinate values: x=%s, y=%s, z=%s^7"):format(tostring(x), tostring(y), tostring(z)))
        return
    end
    
    local prop = CreateObject(modelHash, x, y, z, false, false, false)
    SetEntityHeading(prop, bagData.heading)
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, true, true)
    
    -- Store spawned data
    spawnedBags[bagId] = {
        id = bagId,
        prop = prop,
        coords = vector3(x, y, z),
        heading = bagData.heading,
        ownerCitizenId = bagData.ownerCitizenId,
        ownerSource = bagData.ownerSource,
        item = bagData.item
    }
    
    SetModelAsNoLongerNeeded(modelHash)
    DebugPrint("Created local bag prop for ID: " .. bagId)
    
    -- Target system registration
    if Bridge.Target.GetSystem() ~= "none" then
        local targetOptions = {
            {
                name = "open_clothing_bag_" .. bagId,
                icon = "fas fa-tshirt",
                label = Config.Labels.changeOutfit,
                action = function()
                    TriggerServerEvent("void_clothingbag:server:openOutfitMenu", bagId)
                end,
                canInteract = function()
                    if Config.OnlyOwnerCanOpen then
                        local pData = Bridge.GetPlayerData()
                        return pData.citizenid == bagData.ownerCitizenId
                    end
                    return true
                end
            },
            {
                name = "pack_clothing_bag_" .. bagId,
                icon = "fas fa-briefcase",
                label = Config.Labels.packUp,
                action = function()
                    TriggerServerEvent("void_clothingbag:server:requestPackBag", bagId)
                end,
                canInteract = function()
                    if Config.OnlyOwnerCanPack then
                        local pData = Bridge.GetPlayerData()
                        return pData.citizenid == bagData.ownerCitizenId
                    end
                    return true
                end
            }
        }
        
        Bridge.Target.AddTargetEntity(prop, {
            options = targetOptions,
            distance = Config.InteractDistance
        })
    end
end

-- Deletes locally spawned bag props
local function DeleteLocalBag(bagId)
    local bag = spawnedBags[bagId]
    if not bag then return end
    
    if DoesEntityExist(bag.prop) then
        if Bridge.Target.GetSystem() ~= "none" then
            Bridge.Target.RemoveTargetEntity(bag.prop)
        end
        DeleteEntity(bag.prop)
    end
    
    spawnedBags[bagId] = nil
    DebugPrint("Deleted local bag prop for ID: " .. bagId)
end

-- Receive updated list of active bags from server
RegisterNetEvent("void_clothingbag:client:syncBags", function(activeBags)
    -- Remove local bags no longer present in server list
    for bagId, _ in pairs(spawnedBags) do
        if not activeBags[bagId] then
            DeleteLocalBag(bagId)
        end
    end
    
    -- Add newly added bags from server list
    for bagId, bagData in pairs(activeBags) do
        if not spawnedBags[bagId] then
            CreateLocalBag(bagId, bagData)
        end
    end
end)

-------------------------------------------------------------------------------
-- BAG USAGE TRIGGERS
-------------------------------------------------------------------------------

-- Server triggers this when a player clicks use on the bag item in their inventory
RegisterNetEvent("void_clothingbag:client:useBagItem", function(id, item, ownerCitizenId, ownerSource)
    local playerPed = PlayerPedId()
    
    -- Prevention checks
    if IsPedInAnyVehicle(playerPed, false) or IsPedSwimming(playerPed) or IsPedFalling(playerPed) or IsEntityDead(playerPed) then
        Bridge.Notify(Config.Labels.invalidCondition, "error")
        TriggerServerEvent("void_clothingbag:server:cancelUse", id)
        return
    end
    
    if isBusy then return end
    isBusy = true
    
    local itemConf = Config.BagItems[item]
    if not itemConf then
        isBusy = false
        return
    end
    
    if itemConf.mode == "place" then
        -- Calculate placement location
        local spawnCoords, spawnHeading = GetPlacementCoords()
        local anim = itemConf.animations.place
        
        -- Start progress bar for placing the bag
        local completed = lib.progressBar({
            duration = anim.duration,
            label = itemConf.progress.placeLabel,
            useLib = true,
            disable = {
                car = true,
                move = true,
                combat = true,
                mouse = false
            },
            anim = {
                dict = anim.dict,
                clip = anim.clip,
                flag = anim.flag
            }
        })
        
        if completed then
            TriggerServerEvent("void_clothingbag:server:confirmPlace", id, item, spawnCoords, spawnHeading)
        else
            TriggerServerEvent("void_clothingbag:server:cancelUse", id)
        end
    else
        -- Immediate Use Mode
        local anim = itemConf.animations.use
        local completed = lib.progressBar({
            duration = anim.duration,
            label = itemConf.progress.useLabel,
            useLib = true,
            disable = {
                car = true,
                move = true,
                combat = true,
                mouse = false
            },
            anim = {
                dict = anim.dict,
                clip = anim.clip,
                flag = anim.flag
            }
        })
        
        if completed then
            OpenClothingMenu()
        end
        TriggerServerEvent("void_clothingbag:server:confirmImmediateUse", id)
    end
    
    isBusy = false
end)

-- Open outfits trigger (e.g. from target interaction or menu trigger)
RegisterNetEvent("void_clothingbag:client:openWardrobe", function()
    local anim = Config.ChangeOutfitAnimation or {
        dict = "clothingshirt",
        clip = "try_shirt_positive_d",
        duration = 4000,
        flag = 49,
        label = "Changing clothes..."
    }
    
    local completed = lib.progressBar({
        duration = anim.duration,
        label = anim.label,
        useLib = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            mouse = false
        },
        anim = {
            dict = anim.dict,
            clip = anim.clip,
            flag = anim.flag
        }
    })
    
    if completed then
        OpenClothingMenu()
    end
end)

-- Play packing animation during pickup
RegisterNetEvent("void_clothingbag:client:playPackAnimation", function(id, item)
    local itemConf = Config.BagItems[item]
    if not itemConf then return end
    
    local anim = itemConf.animations.pack
    
    local completed = lib.progressBar({
        duration = anim.duration,
        label = itemConf.progress.packLabel,
        useLib = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            mouse = false
        },
        anim = {
            dict = anim.dict,
            clip = anim.clip,
            flag = anim.flag
        }
    })
    
    if completed then
        TriggerServerEvent("void_clothingbag:server:confirmPack", id)
    else
        TriggerServerEvent("void_clothingbag:server:cancelPack", id)
    end
end)

-------------------------------------------------------------------------------
-- NON-TARGET SYSTEM FALLBACK PROMPT THREAD
-------------------------------------------------------------------------------

-- Helper to draw 3D floating text over bags
local function DrawText3D(coords, text)
    local onScreen, _x, _y = GetScreenCoordFrom3dCoord(coords.x, coords.y, coords.z + 0.35)
    if onScreen then
        SetTextScale(0.32, 0.32)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 80)
    end
end

-- Handles interactions if target is disabled / unavailable
CreateThread(function()
    while true do
        local sleep = 1000
        local targetSys = Bridge.Target.GetSystem()
        
        -- Only run this thread if no target system is active
        if targetSys == "none" then
            local nextBag = nil
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local minDistance = 999.0
            
            for bagId, bag in pairs(spawnedBags) do
                local dist = #(playerCoords - bag.coords)
                if dist < minDistance then
                    minDistance = dist
                    nextBag = bag
                end
            end
            
            if nextBag and minDistance < 5.0 then
                sleep = 0
                
                -- Check permissions for UI string
                local pData = Bridge.GetPlayerData()
                local canOpen = not Config.OnlyOwnerCanOpen or (pData.citizenid == nextBag.ownerCitizenId)
                local canPack = not Config.OnlyOwnerCanPack or (pData.citizenid == nextBag.ownerCitizenId)
                
                local prompt = ""
                if canOpen then
                    prompt = prompt .. "[~g~E~w~] Open Wardrobe "
                end
                if canPack then
                    prompt = prompt .. "[~g~G~w~] Pack Bag"
                end
                
                if prompt == "" then
                    prompt = Config.Labels.cannotInteract
                end
                
                if minDistance < Config.InteractDistance then
                    DrawText3D(nextBag.coords, prompt)
                    
                    -- E key pressed
                    if canOpen and IsControlJustReleased(0, 38) then
                        TriggerServerEvent("void_clothingbag:server:openOutfitMenu", nextBag.id)
                    end
                    
                    -- G key pressed
                    if canPack and IsControlJustReleased(0, 47) then
                        TriggerServerEvent("void_clothingbag:server:requestPackBag", nextBag.id)
                    end
                else
                    DrawText3D(nextBag.coords, nextBag.item == "clothingbag" and "Clothing Bag" or "Duffel Bag")
                end
            end
        end
        
        Wait(sleep)
    end
end)

-------------------------------------------------------------------------------
-- AUTOMATIC DISTANCE AUTO-PACK THREAD
-------------------------------------------------------------------------------

-- Automatically picks up the player's placed bag if they walk too far away
CreateThread(function()
    while true do
        Wait(1000)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local myCitizenId = Bridge.GetPlayerData().citizenid
        
        for bagId, bag in pairs(spawnedBags) do
            -- Only auto-pack if they are the owner who placed it
            if bag.ownerCitizenId == myCitizenId then
                local dist = #(playerCoords - bag.coords)
                if dist > Config.AutoPackDistance then
                    DebugPrint("Auto-packing bag ID " .. bagId .. " because owner walked too far.")
                    TriggerServerEvent("void_clothingbag:server:autoPackBag", bagId)
                end
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- CLEANUP ON RESOURCE STOP
-------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for bagId, bag in pairs(spawnedBags) do
        if DoesEntityExist(bag.prop) then
            if Bridge.Target.GetSystem() ~= "none" then
                Bridge.Target.RemoveTargetEntity(bag.prop)
            end
            DeleteEntity(bag.prop)
        end
    end
    spawnedBags = {}
end)
