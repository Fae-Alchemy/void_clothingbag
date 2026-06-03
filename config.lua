Config = {}

-- Enable debug printing in console
Config.Debug = false

-- Choose your clothing system:
-- Options: "illenium-appearance", "qb-clothing", "fivem-appearance", "ox_appearance", "custom"
Config.ClothingSystem = "illenium-appearance"

-- Unified notifications durations (in milliseconds)
Config.NotifyDuration = 5000

-- Usable items configuration
Config.BagItems = {
    ["clothingbag"] = {
        label = "Clothing Bag",
        propModel = "prop_mil_bag_01", -- Model to spawn when placed
        mode = "place", -- Options: "place" (spawns prop on ground) or "use" (opens menu directly on use)
        
        -- Animation settings for placing/packing
        animations = {
            place = {
                dict = "amb@medic@standing@tendtodead@idle_a",
                clip = "idle_a",
                duration = 3000,
                flag = 1,
            },
            pack = {
                dict = "amb@medic@standing@tendtodead@idle_a",
                clip = "idle_a",
                duration = 2500,
                flag = 1,
            },
            use = { -- Used if mode is "use"
                dict = "clothingshirt",
                clip = "try_shirt_positive_d",
                duration = 2000,
                flag = 49,
            }
        },
        
        -- Labels for the progress bars
        progress = {
            placeLabel = "Placing clothing bag...",
            packLabel = "Packing up clothing bag...",
            useLabel = "Opening clothing bag..."
        }
    },
    ["duffelbag"] = {
        label = "Duffel Bag",
        propModel = "prop_ld_bag_01", -- Duffel bag prop model
        mode = "place",
        
        animations = {
            place = {
                dict = "amb@medic@standing@tendtodead@idle_a",
                clip = "idle_a",
                duration = 3500,
                flag = 1,
            },
            pack = {
                dict = "amb@medic@standing@tendtodead@idle_a",
                clip = "idle_a",
                duration = 3000,
                flag = 1,
            },
            use = {
                dict = "clothingshirt",
                clip = "try_shirt_positive_d",
                duration = 2000,
                flag = 49,
            }
        },
        
        progress = {
            placeLabel = "Placing duffel bag...",
            packLabel = "Packing up duffel bag...",
            useLabel = "Opening duffel bag..."
        }
    }
}

-- Interaction distances
Config.InteractDistance = 2.0  -- Maximum distance to interact with a placed bag
Config.AutoPackDistance = 6.0   -- If a player walks beyond this distance, the bag automatically packs back into their inventory

-- Access & permissions for placed bags
Config.OnlyOwnerCanOpen = false  -- If true, only the player who placed the bag can open it to change outfits
Config.OnlyOwnerCanPack = true   -- If true, only the player who placed the bag can pack it back up into their inventory

-- Text labels for targets & interaction prompts
Config.Labels = {
    changeOutfit = "Change Outfit",
    packUp = "Pack Up Bag",
    cannotInteract = "This is not your bag",
    invalidCondition = "You cannot use this right now"
}

-- CUSTOM CLOTHING TRIGGER CALLBACK
-- This function is called if Config.ClothingSystem is set to "custom"
-- Useful for custom clothing systems or paid assets not listed above
Config.OpenCustomOutfitMenu = function()
    -- Add your custom trigger here, e.g.:
    -- exports['my-custom-clothing']:OpenOutfits()
    print("[void_clothingbag] Custom outfit menu opened. Configure in config.lua")
end
