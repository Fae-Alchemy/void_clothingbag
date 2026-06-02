# void_clothingbag

A premium, modular FiveM script that allows players to use physical inventory items (e.g. clothing bag, duffel bag) to open their pre-saved wardrobe/outfit systems. Built with **void_bridge**, it is framework-agnostic (supporting QBCore, ESX, and Standalone out of the box) and integrates seamlessly with popular target and clothing systems.

---

## Features

- **Double-Mode Support**:
  - `place` Mode: Places a physical bag prop in front of the player (snapped to the ground using raycasts). The bag prop becomes interactive (via target systems or 3D text/keyboard prompts) so players can change clothes or pack the bag back up.
  - `use` Mode: Simply plays a short animation (e.g. unzipping) and immediately opens the outfit menu without consuming or placing the item.
- **Auto-Cleanup Distance Safeguard**: If the player walks too far from their placed bag, the bag automatically packs back into their inventory.
- **Offline Refund Safeguard**: If a player disconnects while their bag is placed on the ground, the script detects the drop, deletes the prop, and refunds the item directly to their database inventory.
- **Security Validation**: Fully verified server-side distance checks and item presence validations to prevent exploits.
- **Modular Clothing Integrations**: Supports `illenium-appearance`, `qb-clothing`, `fivem-appearance`, `ox_appearance`, or custom scripts.
- **Unified Target Integration**: Seamlessly maps interaction options to `ox_target`, `qb-target`, or `qtarget` via `void_bridge`.
- **Keyboard Fallback**: Standard floating 3D text prompts and key listener loop (`E` to open, `G` to pack) for standalone/non-target servers.

---

## Installation

1. Copy the `void_clothingbag` folder to your server's `resources` directory.
2. Add `ensure void_clothingbag` to your `server.cfg` (make sure it runs **after** `void_bridge` and your clothing script).
3. Add the required items to your inventory system.

---

## Item Registration Examples

### 1. Ox Inventory (`ox_inventory/data/items.lua`)
Add the following entries:
```lua
['clothingbag'] = {
    label = 'Clothing Bag',
    weight = 1000,
    stack = false,
    close = true,
    description = 'A portable bag containing your pre-saved outfits.'
},
['duffelbag'] = {
    label = 'Duffel Bag',
    weight = 1500,
    stack = false,
    close = true,
    description = 'A large duffel bag to swap your outfits on the go.'
}
```

### 2. QB-Core (`qb-core/shared/items.lua`)
Add the following entries:
```lua
['clothingbag'] = {
    ['name'] = 'clothingbag',
    ['label'] = 'Clothing Bag',
    ['weight'] = 1000,
    ['type'] = 'item',
    ['image'] = 'clothingbag.png',
    ['unique'] = true,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'A portable bag containing your pre-saved outfits.'
},
['duffelbag'] = {
    ['name'] = 'duffelbag',
    ['label'] = 'Duffel Bag',
    ['weight'] = 1500,
    ['type'] = 'item',
    ['image'] = 'duffelbag.png',
    ['unique'] = true,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'A large duffel bag to swap your outfits on the go.'
}
```

### 3. ESX (Database `items` table)
Import the SQL structure:
```sql
INSERT INTO `items` (`name`, `label`, `limit`, `rare`, `can_remove`) VALUES
('clothingbag', 'Clothing Bag', 1, 0, 1),
('duffelbag', 'Duffel Bag', 1, 0, 1);
```

---

## Configuration

All custom settings can be found in `config.lua`:
* `Config.ClothingSystem`: Choice of `'illenium-appearance'`, `'qb-clothing'`, `'fivem-appearance'`, `'ox_appearance'`, or `'custom'`.
* `Config.InteractDistance`: Maximum distance to open or pack a placed bag.
* `Config.AutoPackDistance`: Range before the bag automatically returns to the owner's inventory.
* `Config.OnlyOwnerCanOpen`: Lock outfit changing to the player who placed the bag.
* `Config.OnlyOwnerCanPack`: Restrict pickup permission to the owner.
* `Config.OpenCustomOutfitMenu`: Define custom triggers if using a paid/unique clothing script.
