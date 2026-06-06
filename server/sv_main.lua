local Bridge = exports['void_bridge']:GetBridge()

-- Table storing active placed bags on the ground
-- Format: [bagId] = { coords, heading, ownerCitizenId, ownerSource, item, placed }
local activeBags = {}

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS & LOGGING
-------------------------------------------------------------------------------

local function DebugPrint(...)
    if Config.Debug then
        print("^4[void_clothingbag]^7", ...)
    end
end

-- Sync active bags with a specific client or all clients
local function SyncBags(target)
    if target then
        TriggerClientEvent("void_clothingbag:client:syncBags", target, activeBags)
    else
        TriggerClientEvent("void_clothingbag:client:syncBags", -1, activeBags)
    end
end

-- Offline player refund helper
local function RefundOfflinePlayer(citizenid, identifier, item)
    local invSys = Bridge.Inventory.GetSystem()
    local fw = Bridge.GetFramework()
    
    DebugPrint(("Attempting offline refund for citizenid [%s] identifier [%s] item [%s]"):format(citizenid, identifier, item))
    
    if invSys == "ox_inventory" then
        pcall(function()
            exports.ox_inventory:AddItem(identifier, item, 1)
        end)
        return
    end
    
    if fw == "qbcore" or fw == "qbx" then
        MySQL.single('SELECT inventory FROM players WHERE citizenid = ?', {citizenid}, function(result)
            if result and result.inventory then
                local inventory = {}
                pcall(function() inventory = json.decode(result.inventory) or {} end)
                
                local freeSlot = nil
                for i = 1, 41 do
                    if not inventory[tostring(i)] then
                        freeSlot = i
                        break
                    end
                end
                
                if freeSlot then
                    inventory[tostring(freeSlot)] = {
                        name = item,
                        amount = 1,
                        info = {},
                        slot = freeSlot,
                        type = "item",
                        created = os.time()
                    }
                    local encoded = json.encode(inventory)
                    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', {encoded, citizenid})
                    DebugPrint("Offline refund complete via QBCore database.")
                end
            end
        end)
    elseif fw == "esx" then
        MySQL.update('UPDATE user_inventory SET count = count + 1 WHERE identifier = ? AND item = ?', {identifier, item}, function(rowsChanged)
            if rowsChanged == 0 then
                -- Check modern ESX users table json column
                MySQL.single('SELECT inventory FROM users WHERE identifier = ?', {identifier}, function(result)
                    if result and result.inventory then
                        local inventory = {}
                        pcall(function() inventory = json.decode(result.inventory) or {} end)
                        if inventory[item] then
                            inventory[item] = inventory[item] + 1
                        else
                            inventory[item] = 1
                        end
                        MySQL.update('UPDATE users SET inventory = ? WHERE identifier = ?', {json.encode(inventory), identifier})
                        DebugPrint("Offline refund complete via ESX users table inventory.")
                    end
                end)
            else
                DebugPrint("Offline refund complete via ESX user_inventory table.")
            end
        end)
    end
end

-------------------------------------------------------------------------------
-- REGISTRATION OF USABLE ITEMS
-------------------------------------------------------------------------------

local function UseBagItem(source, itemName)
    print(("[void_clothingbag] Item '%s' used by player server ID %d"):format(itemName, source))
    
    local player = Bridge.GetPlayer(source)
    if not player then
        print(("[void_clothingbag] Error: Could not retrieve player object for server ID %d"):format(source))
        return
    end
    
    local pData = player.GetData()
    local citizenid = pData.citizenid
    if not citizenid then
        print(("[void_clothingbag] Error: Player citizenid is nil for server ID %d"):format(source))
        return
    end
    
    -- Check if player already has an active bag placed or in placement phase
    for bagId, bag in pairs(activeBags) do
        if bag.ownerCitizenId == citizenid then
            Bridge.Notify(source, "You already have an active bag placed or in use!", "error")
            return
        end
    end
    
    -- Generate unique bag ID
    local bagId = "bag_" .. math.random(100000, 999999) .. "_" .. os.time()
    
    -- Store pre-placement state
    activeBags[bagId] = {
        ownerSource = source,
        ownerCitizenId = citizenid,
        ownerIdentifier = pData.identifier,
        item = itemName,
        placed = false
    }
    
    -- Trigger client placement UI & logic
    TriggerClientEvent("void_clothingbag:client:useBagItem", source, bagId, itemName, citizenid, source)
end

local function RegisterItems()
    local fw = Bridge.GetFramework()
    print(("[void_clothingbag] Initializing usable items for framework: %s"):format(fw))
    
    for itemName, conf in pairs(Config.BagItems) do
        -- 1. Standard Qbox usable items
        if fw == 'qbx' then
            exports.qbx_core:CreateUseableItem(itemName, function(source, item)
                UseBagItem(source, itemName)
            end)
            print(("[void_clothingbag] Registered Qbox usable item: %s"):format(itemName))

        -- 2. Standard QBCore usable items
        elseif fw == 'qbcore' then
            local QBCore = exports['qb-core']:GetCoreObject()
            QBCore.Functions.CreateUseableItem(itemName, function(source, item)
                UseBagItem(source, itemName)
            end)
            print(("[void_clothingbag] Registered QBCore usable item: %s"):format(itemName))
            
        -- 3. Standard ESX usable items
        elseif fw == 'esx' then
            local ESX = nil
            pcall(function() ESX = exports['es_extended']:getSharedObject() end)
            if not ESX then TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) end
            if ESX then
                ESX.RegisterUsableItem(itemName, function(source)
                    UseBagItem(source, itemName)
                end)
                print(("[void_clothingbag] Registered ESX usable item: %s"):format(itemName))
            end
            
        -- 4. Standalone command registration for testing
        else
            RegisterCommand("use_" .. itemName, function(source, args)
                UseBagItem(source, itemName)
            end, false)
            print(("[void_clothingbag] Registered standalone test command: /use_%s"):format(itemName))
        end

        -- 4. Dynamic ox_inventory exports registration
        -- This allows ox_inventory to trigger this export when the item is used
        AddEventHandler('__cfx_export_' .. GetCurrentResourceName() .. '_' .. itemName, function(setCB)
            setCB(function(event, item, inventory, slot, data)
                if event == 'usingItem' then
                    UseBagItem(inventory.id, itemName)
                    return true
                end
            end)
        end)
        DebugPrint("Registered dynamic ox_inventory export for: " .. itemName)
    end
end

-- Initialize item registrations
CreateThread(function()
    Wait(500)
    RegisterItems()
end)

-------------------------------------------------------------------------------
-- NETWORK EVENTS / HANDLERS
-------------------------------------------------------------------------------

-- Client requests sync when loading in
RegisterNetEvent("void_clothingbag:server:playerLoaded", function()
    local src = source
    SyncBags(src)
end)

-- Client cancelled placement
RegisterNetEvent("void_clothingbag:server:cancelUse", function(bagId)
    local src = source
    if activeBags[bagId] and activeBags[bagId].ownerSource == src then
        activeBags[bagId] = nil
        DebugPrint("Bag placement cancelled for ID: " .. bagId)
    end
end)

-- Client confirms placement
RegisterNetEvent("void_clothingbag:server:confirmPlace", function(bagId, itemName, coords, heading)
    local src = source
    local bag = activeBags[bagId]
    
    if not bag or bag.ownerSource ~= src then return end
    
    -- Verify player actually has the item before removing it
    if Bridge.Inventory.HasItem(src, itemName, 1) then
        if Bridge.Inventory.RemoveItem(src, itemName, 1) then
            bag.coords = coords
            bag.heading = heading
            bag.placed = true
            
            SyncBags() -- Broadcast to all clients
            Bridge.Notify(src, ("Placed %s on the ground."):format(Config.BagItems[itemName].label), "success")
            DebugPrint(("Bag %s placed at %s"):format(bagId, tostring(coords)))
        else
            activeBags[bagId] = nil
            Bridge.Notify(src, "Failed to remove bag item.", "error")
        end
    else
        activeBags[bagId] = nil
        Bridge.Notify(src, "You do not have the bag item in your inventory.", "error")
    end
end)

-- Client confirms immediate use mode (opens menu directly, does not place or consume item)
RegisterNetEvent("void_clothingbag:server:confirmImmediateUse", function(bagId)
    local src = source
    if activeBags[bagId] and activeBags[bagId].ownerSource == src then
        activeBags[bagId] = nil
        DebugPrint("Immediate use bag session completed and cleared: " .. bagId)
    end
end)

-- Client clicks target to open outfit menu
RegisterNetEvent("void_clothingbag:server:openOutfitMenu", function(bagId)
    local src = source
    local bag = activeBags[bagId]
    if not bag or not bag.placed then return end
    
    -- Server-side security distance check
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - bag.coords)
    
    if distance > Config.InteractDistance + 2.0 then
        DebugPrint(("Player %s attempted to open bag %s from too far (%f meters)"):format(GetPlayerName(src), bagId, distance))
        return
    end
    
    -- Check permissions
    local player = Bridge.GetPlayer(src)
    if not player then return end
    
    local citizenid = player.GetData().citizenid
    if Config.OnlyOwnerCanOpen and bag.ownerCitizenId ~= citizenid then
        Bridge.Notify(src, Config.Labels.cannotInteract, "error")
        return
    end
    
    -- Trigger client menu opening
    TriggerClientEvent("void_clothingbag:client:openWardrobe", src)
end)

-- Client requests to pack bag back up
RegisterNetEvent("void_clothingbag:server:requestPackBag", function(bagId)
    local src = source
    local bag = activeBags[bagId]
    if not bag or not bag.placed then return end
    
    -- Server distance check
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - bag.coords)
    
    if distance > Config.InteractDistance + 2.0 then return end
    
    -- Permissions check
    local player = Bridge.GetPlayer(src)
    if not player then return end
    
    local citizenid = player.GetData().citizenid
    if Config.OnlyOwnerCanPack and bag.ownerCitizenId ~= citizenid then
        Bridge.Notify(src, Config.Labels.cannotInteract, "error")
        return
    end
    
    -- Trigger packing animation on client
    TriggerClientEvent("void_clothingbag:client:playPackAnimation", src, bagId, bag.item)
end)

-- Client completed packing animation
RegisterNetEvent("void_clothingbag:server:confirmPack", function(bagId)
    local src = source
    local bag = activeBags[bagId]
    if not bag or not bag.placed then return end
    
    -- Distance verification
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if #(playerCoords - bag.coords) > Config.InteractDistance + 2.0 then return end
    
    -- Return item to player inventory
    if Bridge.Inventory.AddItem(src, bag.item, 1) then
        activeBags[bagId] = nil
        SyncBags()
        Bridge.Notify(src, ("You packed up the %s."):format(Config.BagItems[bag.item].label), "success")
        DebugPrint("Bag packed and removed: " .. bagId)
    else
        Bridge.Notify(src, "Inventory full! Cannot pick up bag.", "error")
    end
end)

-- Client cancelled packing animation
RegisterNetEvent("void_clothingbag:server:cancelPack", function(bagId)
    local src = source
    DebugPrint(("Packing cancelled by player %s for bag %s"):format(GetPlayerName(src), bagId))
end)

-- Auto-pack triggers client-side when owner walks too far
RegisterNetEvent("void_clothingbag:server:autoPackBag", function(bagId)
    local src = source
    local bag = activeBags[bagId]
    if not bag or not bag.placed then return end
    
    -- Verify sender is the owner
    if bag.ownerSource ~= src then return end
    
    -- Try giving the item back to the owner
    if Bridge.Inventory.AddItem(src, bag.item, 1) then
        activeBags[bagId] = nil
        SyncBags()
        Bridge.Notify(src, ("Your %s was automatically packed up."):format(Config.BagItems[bag.item].label), "inform")
        DebugPrint("Bag auto-packed: " .. bagId)
    else
        -- If inventory is full, we must drop it or keep it on ground, let's notify
        Bridge.Notify(src, "Your inventory was full, could not auto-pack your bag!", "error")
    end
end)

-------------------------------------------------------------------------------
-- DISCONNECT SAFEGUARD / AUTO-REFUND
-------------------------------------------------------------------------------

AddEventHandler("playerDropped", function(reason)
    local src = source
    
    for bagId, bag in pairs(activeBags) do
        if bag.ownerSource == src then
            if bag.placed then
                -- Player is offline, perform database/offline refund
                RefundOfflinePlayer(bag.ownerCitizenId, bag.ownerIdentifier, bag.item)
            end
            
            -- Remove from table and sync
            activeBags[bagId] = nil
            SyncBags()
            DebugPrint(("Cleaned up and refunded bag %s for disconnected player %s"):format(bagId, GetPlayerName(src)))
        end
    end
end)

-------------------------------------------------------------------------------
-- VERSION CHECKER
-------------------------------------------------------------------------------

local function CheckVersion()
    local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
    if not currentVersion then
        print("^1[void_clothingbag] Unable to check version: fxmanifest.lua is missing 'version' metadata.^7")
        return
    end

    PerformHttpRequest('https://raw.githubusercontent.com/Fae-Alchemy/void_clothingbag/main/fxmanifest.lua', function(statusCode, response, headers)
        if statusCode ~= 200 then
            print("^1[void_clothingbag] Version check failed: GitHub returned status code " .. tostring(statusCode) .. "^7")
            return
        end

        local latestVersion = string.match(response, "%sversion%s+['\"]([^'\"]+)['\"]")
        if latestVersion then
            if latestVersion ~= currentVersion then
                print("^4====================================================================^7")
                print("^4[void_clothingbag] ^1A new update is available!^7")
                print(("^4[void_clothingbag] ^7Current Version: ^1%s^7 | Latest Version: ^2%s^7"):format(currentVersion, latestVersion))
                print("^4[void_clothingbag] ^7Download the update here: ^5https://github.com/Fae-Alchemy/void_clothingbag^7")
                print("^4====================================================================^7")
            else
                print(("^4[void_clothingbag] ^7Resource is ^2up-to-date^7 (Version: %s)"):format(currentVersion))
            end
        else
            print("^1[void_clothingbag] Version check failed: Unable to parse version from GitHub manifest.^7")
        end
    end, 'GET')
end

CreateThread(function()
    Wait(2000)
    CheckVersion()
end)
