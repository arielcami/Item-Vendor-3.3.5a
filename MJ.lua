--[[
    Autor: Ariel Camilo - Desarrollador de Software
    Script:                 ItemVedor: Vendedor de objetos dinámico
    Para base de datos:     MySQL ^8.0.43
    Para core:              AzerothCore
    Wow Version:            3.3.5a
    Engine:                 Azerothcore Lua Engine (ALE)

    IMPORTANTE:     El método player:GetInventoryFreeSlots() fue añadido recientemente al source
                    por lo que no funcionará en versiones compiladas antes del 18 de Marzo de 2026.
                    PR: https://github.com/azerothcore/mod-ale/pull/369
]]

local function INSTALL_SYSTEM()
    local CREATES = {
        "CREATE TABLE IF NOT EXISTS a_itemvendor_fixed_amount (id TINYINT UNSIGNED NOT NULL DEFAULT 1,amount INT UNSIGNED NOT NULL DEFAULT 10000,PRIMARY KEY (id))",
        "CREATE TABLE IF NOT EXISTS a_itemvendor_global_rate (id TINYINT UNSIGNED NOT NULL DEFAULT 1,rate TINYINT UNSIGNED NOT NULL DEFAULT 1,PRIMARY KEY (id))",
        "CREATE TABLE IF NOT EXISTS a_itemvendor_blacklist (id INT UNSIGNED NOT NULL, PRIMARY KEY (id))",
        "CREATE TABLE IF NOT EXISTS a_itemvendor (entry INT UNSIGNED NOT NULL PRIMARY KEY,`name` VARCHAR(80) NOT NULL,buyPrice INT UNSIGNED NOT NULL,maxCount INT UNSIGNED NOT NULL,stackable INT UNSIGNED NOT NULL DEFAULT 1,state TINYINT NOT NULL DEFAULT 1)",
        "CREATE TABLE IF NOT EXISTS a_itemvendor_log (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,player_id INT UNSIGNED NOT NULL,item_id MEDIUMINT UNSIGNED NOT NULL,amount MEDIUMINT UNSIGNED NOT NULL,expense INT UNSIGNED NOT NULL,purchase_time TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP)",
        "CREATE TABLE IF NOT EXISTS a_itemvendor_frequent (entry INT UNSIGNED NOT NULL,buyPrice INT UNSIGNED NOT NULL,maxCount TINYINT UNSIGNED NOT NULL,times INT UNSIGNED NOT NULL DEFAULT '1',player_id INT UNSIGNED NOT NULL,UNIQUE KEY uniq_entry_player (entry, player_id))",
        "CREATE TABLE IF NOT EXISTS a_itemvendor_gm_log (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,gm_id INT UNSIGNED NOT NULL,action ENUM('ADD', 'EDIT', 'DELETE', 'CONFIG', 'POPULATE') NOT NULL,item_id INT UNSIGNED NULL,old_value TEXT NULL,new_value TEXT NULL,timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)"
    }

    local INSERTS = {
        "INSERT IGNORE INTO a_itemvendor_global_rate (id, rate) VALUES (1, 1)",
        "INSERT IGNORE INTO a_itemvendor_fixed_amount (id, amount) VALUES (1, 10000)"
    }

    -- Execute Creates
    for i = 1, #CREATES do
        WorldDBExecute(CREATES[i])
    end

    -- Execute Inserts
    for i = 1, #INSERTS do
        WorldDBExecute(INSERTS[i])
    end

    -- Lista negra de objetos que jamás deberían poder comprarse
    local blacklist = [[(24477),(24476),(33470),(21877),(28430),(40553),(41257),(41383),(41384),(44926),(44948),(30732),(30724),
    (31318),(34622),(31342),(31322),(31336),(31334),(31332),(31331),(31323),(20698),(45173),(45172),(45174),(45175),(38497),
    (38496),(38498),(27965),(34025),(34030),(37126),(28388),(28389),(17882),(17887),(22023),(22024),(22584),(29841),(29868),
    (29871),(14891),(1442),(26173),(26174),(26175),(26180),(26235),(26324),(26368),(26372),(26464),(26465),(26548),(26655),
    (26738),(26792),(26843),(27196),(27218),(37301),(38292),(39163),(45575),(138),(931),(2275),(2588),(2599),(3884),(3934),
    (5632),(40754),(40948),(43336),(43337),(43384),(31266),(27774),(27811),(28117),(28122),(41403),(41404),(41405),(41406),
    (41407),(41408),(41409),(41410),(41411),(41412),(41413),(41414),(41415),(41416),(41417),(41418),(41419),(41420),(41421),
    (41422),(41423),(43362),(45908),(21038),(32722),(33226),(34062),(34599),(38294),(38518),(42986),(43523),(46783),(54822),
    (52252),(996),(1020),(1021),(1024),(1025),(1027),(1162),(5235)]]

    WorldDBExecute("INSERT IGNORE INTO a_itemvendor_blacklist (id) VALUES "..blacklist)
end
INSTALL_SYSTEM()


-- Configuración
local NPC_ID = 60002
local MAX_RESULTS = 28
local GLOBAL_RATE_COEFFICIENT, FLAT_PRICE


-- Helper para sanitizar la entrada de texto del jugador
local function escapeSQL(input)
    if input == nil then
        return ""
    end
    local str = tostring(input)
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, "'", "\\'")
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\r", "\\r")
    str = string.gsub(str, "\t", "\\t")
    str = string.gsub(str, "\b", "\\b")
    str = string.gsub(str, "\26", "\\Z")
    str = string.gsub(str, "%%", "\\%")
    str = string.gsub(str, "_", "\\_")
    return str
end

-- Helper para trasncribir de CURRENT TIMESTAMP desde la DB a fecha legible en la UI
local function formatDate(timestamp)
    local months = {'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'}
    local days = {'Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'}
    local year = tonumber(timestamp:sub(1, 4))
    local month = tonumber(timestamp:sub(6, 7))
    local day = tonumber(timestamp:sub(9, 10))
    local hour = tonumber(timestamp:sub(12, 13))
    local minute = timestamp:sub(15, 16)

    local dayName = days[tonumber(os.date("%w", os.time({
        year = year,
        month = month,
        day = day
    }))) + 1]

    local period = hour >= 12 and "pm" or "am"
    local hour12 = hour % 12
    if hour12 == 0 then
        hour12 = 12
    end

    return string.format("%s %d de %s de %d - %d:%s %s", dayName, day, months[month], year, hour12, minute, period)
end

-- Consultas encapsuladas
local function Query()
    return {
        INSERT_INTO_LOG = function(player_id, item_id, amount, expense)
            WorldDBExecute(string.format("INSERT INTO a_itemvendor_log (player_id, item_id, amount, expense) VALUES (%d, %d, %d, %d)", player_id, item_id, amount, expense))
        end,
        
        INSERT_OR_UPDATE_FREQUENT_PURCHASE = function(entry, buyPrice, maxCount, player_id)
            WorldDBExecute(string.format(
                "INSERT INTO a_itemvendor_frequent (entry, buyPrice, maxCount, times, player_id) VALUES (%d, %d, %d, 1, %d) ON DUPLICATE KEY UPDATE times = times + 1",
                entry, buyPrice, maxCount, player_id))
        end,

        LOOK_FOR_ITEM_BY_NAME_OR_PART = function(name_or_part)
            local sql = WorldDBQuery(string.format(
                "SELECT entry, buyPrice, maxCount, stackable FROM a_itemvendor WHERE `name` LIKE '%%%s%%' AND state = 1 LIMIT %d",
                escapeSQL(name_or_part), (MAX_RESULTS > 30 and 30 or MAX_RESULTS)))
            if sql then
                local res = {}
                repeat
                    table.insert(res, {sql:GetUInt32(0), sql:GetUInt32(1), sql:GetUInt32(2), sql:GetUInt32(3)})
                until not sql:NextRow()
                return res
            end
            return nil
        end,

        GET_FREQUENT_PURCHASES_BY_PLAYER_ID = function(player_id)
            return WorldDBQuery(string.format(
                "SELECT entry, buyPrice, maxCount FROM a_itemvendor_frequent WHERE player_id = %d ORDER BY times DESC LIMIT " .. MAX_RESULTS, player_id))
        end,
        
        GET_GLOBAL_RATE = function()
            local q = WorldDBQuery("SELECT rate FROM a_itemvendor_global_rate WHERE id = 1")
            return q and q:GetUInt8(0) or 1
        end,
        
        GET_FLAT_AMOUNT_BUYPRICE = function()
            local q = WorldDBQuery("SELECT amount FROM a_itemvendor_fixed_amount WHERE id = 1")
            return q and q:GetUInt32(0) or 10000
        end,
        
        VENDOR_TABLE_IS_EMPTY = function()
            return not WorldDBQuery("SELECT 1 FROM a_itemvendor WHERE state = 1 LIMIT 1")
        end,
        
        PLAYER_HAS_LOG = function(player_id)
            return WorldDBQuery(string.format("SELECT 1 FROM a_itemvendor_log WHERE player_id = %d", player_id)) and
                       true or false
        end,
        
        GET_LAST_ITEMS_FROM_LOG = function(player_id)
            return WorldDBQuery(string.format(
                "SELECT amount, item_id, purchase_time, expense FROM a_itemvendor_log WHERE player_id = %d ORDER BY purchase_time DESC LIMIT " ..
                    MAX_RESULTS, player_id))
        end,

        FIND_ONE = function(entry)
            return WorldDBQuery(string.format(
                'SELECT entry, `name`, buyPrice, maxCount, stackable from a_itemvendor WHERE entry = %d AND state = 1',
                entry))
        end,

        FIND_ONE_ITEM_TEMPLATE = function(entry)
            local sql = WorldDBQuery(string.format(
                'SELECT entry, BuyPrice, maxcount, stackable from item_template WHERE entry = %d', entry))
            return sql and {sql:GetUInt32(0), sql:GetUInt32(1), sql:GetUInt32(2), sql:GetUInt32(3)} or false
        end,

        UPDATE_ITEM_BUYPRICE = function(entry, new_price)
            WorldDBExecute(string.format('UPDATE a_itemvendor SET buyPrice = %d WHERE entry = %d', new_price, entry))
            return true
        end,

        INSERT_ITEM_IN_VENDOR_TABLE = function(entry, name, buyprice, maxcount, stackable)
            WorldDBExecute(string.format(
                'INSERT INTO a_itemvendor (entry, `name`, buyPrice, maxCount, stackable, state) VALUES (%d, "%s", %d, %d, %d, 1) ON DUPLICATE KEY UPDATE state = 1, stackable = %d',
                entry, escapeSQL(name), buyprice, maxcount, stackable, stackable))
        end,

        DELETE_ITEM_FROM_VENDOR_TABLE = function(entry)
            WorldDBExecute('UPDATE a_itemvendor SET state = 0 WHERE entry = ' .. entry)
        end,

        IS_FIXED_AMOUNT_EMPTY = function()
            return not WorldDBQuery("SELECT 1 FROM a_itemvendor_fixed_amount WHERE id = 1")
        end,
        
        IS_GLOBAL_RATE_EMPTY = function()
            return not WorldDBQuery("SELECT 1 FROM a_itemvendor_global_rate WHERE id = 1")
        end,
        
        IS_BLACKLIST_EMPTY = function()
            local q = WorldDBQuery("SELECT 1 FROM a_itemvendor_blacklist LIMIT 1")
            if q then 
                return false
            else
                return true
            end
        end,

        POPULATE_FIXED_AMOUNT_ASYNC = function(callback)
            WorldDBQueryAsync("INSERT IGNORE INTO a_itemvendor_fixed_amount (id, amount) VALUES (1, 10000)", callback)
        end,
        
        POPULATE_GLOBAL_RATE_ASYNC = function(callback)
            WorldDBQueryAsync("INSERT IGNORE INTO a_itemvendor_global_rate (id, rate) VALUES (1, 1)", callback)
        end,

        IS_ITEM_BLACKLISTED = function(entry)
            local q = WorldDBQuery(string.format("SELECT 1 FROM a_itemvendor_blacklist WHERE id = %d", entry))
            return q ~= nil
        end,

        INSERT_GM_LOG = function(gm_id, action, item_id, old_value, new_value)
            WorldDBExecute(string.format("INSERT INTO a_itemvendor_gm_log (gm_id, action, item_id, old_value, new_value) VALUES (%d, '%s', %s, %s, %s)",
                gm_id, action, item_id or "NULL", old_value and ("'" .. escapeSQL(old_value) .. "'") or "NULL", new_value and ("'" .. escapeSQL(new_value) .. "'") or "NULL"
            ))
        end
    }
end
local DB = Query()

-- Extrae la string necesaria para crear un ícono en la UI
local function getIcon(item_id)
    local it = GetItemTemplate(item_id)
    return it and string.format("|TInterface\\Icons\\%s:21:21:-22|t", it:GetIcon()) or "|TInterface\\Icons\\INV_Misc_QuestionMark:21:21:-22|t"
end

-- Toma un número y lo devuelve formateado con los íconos de oro, plata y cobre del juego
local function formatCurrency(copper)
    local oro, plata, cobre = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
    local path, parts = "|TInterface\\MoneyFrame\\", {}
    local function fn(n)
        return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end
    if oro > 0 then
        table.insert(parts, "|CFFFFFFFF" .. fn(oro) .. "|r" .. path .. "UI-GoldIcon:0:0:2:0|t")
    end
    if plata > 0 or (cobre > 0 and oro > 0) then
        table.insert(parts, "|CFFFFFFFF" .. plata .. "|r" .. path .. "UI-SilverIcon:0:0:2:0|t")
    end
    if cobre > 0 or (oro == 0 and plata == 0) then
        table.insert(parts, "|CFFFFFFFF" .. cobre .. "|r" .. path .. "UI-CopperIcon:0:0:2:0|t")
    end
    return table.concat(parts, " ")
end

-- Iconos de la pantalla principal
local function ico(sel)
    local icons = {"inv_misc_spyglass_01", "inv_inscription_scroll", "inv_misc_coin_02", "spell_holy_stoicism", "inv_enchant_shardglowingsmall", "spell_shadow_sacrificialshield"}
    return string.format("|TInterface\\Icons\\%s:42:42:-21:0|t", icons[sel])
end

-- Extrae el nombre de un objeto a partir de su link
local function extractName(link)
    return link:match("%[(.-)%]")
end

-- Helper para devolver un INTEGER positivo, o cero
local function cleanAndConvert(input)
    return math.max(0, math.floor(tonumber(input) or 0))
end

-- Función auxiliar para crear un registro de caché para un item
local function createItemCacheEntry(entry, price, maxCount, stackable)
    local icon = getIcon(entry)
    local name = extractName(GetItemLink(entry, 7)) or "Desconocido"

    return {
        name = name,
        price = price,
        maxCount = maxCount,
        stackable = stackable or 1,
        icon = icon,
        link = GetItemLink(entry, 7)
    }
end

-- Cache de sesión por Jugador
local playerVendorCache = {}
local function GetPlayerCache(player)
    local guid = player:GetGUIDLow()
    if not playerVendorCache[guid] then
        playerVendorCache[guid] = {
            searchResults = {},
            searchOrder = {},
            pendingItem = {
                id = 0,
                name = "",
                price = 0,
                maxCount = 0,
                stackable = 1
            }
        }
    end
    return playerVendorCache[guid]
end

local function ON_PLAYER_LOGOUT(e, P)
    -- Limpieza total de cache particular
    playerVendorCache[P:GetGUIDLow()] = nil
end

-- Función principal 1
local function CLICK_1(event, player, creature)
    local cache = GetPlayerCache(player)
    cache.searchResults = {}
    cache.searchOrder = {}
    if DB.VENDOR_TABLE_IS_EMPTY() then
        player:SendBroadcastMessage('|CFFFF0000El sistema de ventas necesita configuración.|r');
        player:GossipComplete();
        return
    end
    player:GossipMenuAddItem(8, ico(1) .. 'Buscar un objeto', 0, 0, true, 'Ingresa el nombre o parte del nombre:')
    player:GossipMenuAddItem(8, ico(3) .. 'Compras frecuentes', 1, 0)
    player:GossipMenuAddItem(8, ico(2) .. 'Registro de compras', 2, 0)
    if player:IsGM() then
        player:GossipMenuAddItem(8, ico(4) .. 'Editar precio', 3, 0, true, "Ingresa el |CFF00FF00ID|r del objeto:")
        player:GossipMenuAddItem(8, ico(5) .. 'Añadir', 4, 0, true, "Ingresa el |CFF00FF00ID|r del objeto:")
        player:GossipMenuAddItem(8, ico(6) .. 'Eliminar', 5, 0, true, "Ingresa el |CFF00FF00ID|r del objeto:")
    end
    player:GossipSendMenu(1, creature)
end

-- Función principal 2, Lógica de negocio
local function CLICK_2(event, player, creature, sender, intId, rawInput)
    local cache = GetPlayerCache(player)
    FLAT_PRICE = DB.GET_FLAT_AMOUNT_BUYPRICE()
    GLOBAL_RATE_COEFFICIENT = DB.GET_GLOBAL_RATE()

    -- VOLVER AL MENÚ PRINCIPAL
    if sender == 6 then
        CLICK_1(event, player, creature)
        return
    end

    --------------------------------------------------------------------------
    -- GM: ELIMINAR (Soft Delete)
    --------------------------------------------------------------------------
    if sender == 5 and intId == 0 then
        local entry = cleanAndConvert(rawInput)
        if entry == 0 then
            player:SendBroadcastMessage("|cffff0000Debes ingresar un ID de objeto válido.")
            player:GossipComplete()
            return
        end
        DB.DELETE_ITEM_FROM_VENDOR_TABLE(entry)
        player:SendBroadcastMessage("|CFFFF0000Objeto con ID " .. entry .. " marcado como inactivo.")

        -- Registrar en auditoría GM
        local itemName = extractName(GetItemLink(entry, 7)) or "ID " .. entry
        DB.INSERT_GM_LOG(player:GetGUIDLow(), 'DELETE', entry, itemName, nil)


        CLICK_1(event, player, creature)
        return
    end

    --------------------------------------------------------------------------
    -- GM: EDITAR PRECIO - Paso 1 (Recibe ID del ítem)
    --------------------------------------------------------------------------
    if sender == 3 and intId == 0 then
        local entry = cleanAndConvert(rawInput)
        if entry == 0 then
            player:SendBroadcastMessage("|cffff0000Debes ingresar un ID de objeto válido.")
            player:GossipComplete()
            return
        end
        
        local itemInVendor = DB.FIND_ONE(entry)
        if not itemInVendor then
            player:SendBroadcastMessage("|cffff0000El objeto con ID " .. entry .. " no está en el vendor o está inactivo.")
            player:GossipComplete()
            return
        end
        
        -- Guardar en caché para el siguiente paso
        local name = extractName(GetItemLink(entry, 7)) or "Desconocido"
        local currentPrice = itemInVendor:GetUInt32(2)  -- buyPrice
        
        cache.pendingItem = {
            id = entry,
            name = name,
            price = currentPrice,
            maxCount = itemInVendor:GetUInt32(3),
            stackable = itemInVendor:GetUInt32(4)
        }
        
        player:GossipClearMenu()
        player:GossipMenuAddItem(0, "[EDITAR] " .. GetItemLink(entry, 7) .. " - Precio actual: " .. formatCurrency(currentPrice), 
            3, entry, true, "Ingresa el NUEVO precio en cobre (ej: 50000 para 5g):")
        player:GossipSendMenu(1, creature)
        return
    end

    --------------------------------------------------------------------------
    -- GM: EDITAR PRECIO - Paso 2 (Recibe nuevo precio y ejecuta UPDATE)
    --------------------------------------------------------------------------
    if sender == 3 and intId > 0 then
        local entry = intId
        local newPrice = cleanAndConvert(rawInput)
        
        -- Validación: ¿Hay datos pendientes y coinciden?
        if not cache.pendingItem or cache.pendingItem.id ~= entry then
            player:SendBroadcastMessage("|cffff0000Error: Inconsistencia en los datos. Operación cancelada.")
            player:GossipComplete()
            return
        end
        
        if newPrice < 0 then
            player:SendBroadcastMessage("|cffff0000El precio no puede ser negativo.")
            player:GossipComplete()
            return
        end
        
        local success = DB.UPDATE_ITEM_BUYPRICE(entry, newPrice)
        
        if success then
            local displayPrice = formatCurrency(newPrice)
            player:SendBroadcastMessage("|cff00ff00Precio de " .. GetItemLink(entry, 7) .. "|cff00ff00 actualizado a " .. displayPrice .. ".")

            -- Registrar en auditoría GM
            local oldPriceFormatted = formatCurrency(cache.pendingItem.price)
            local newPriceFormatted = formatCurrency(newPrice)
            DB.INSERT_GM_LOG(player:GetGUIDLow(), 'EDIT', entry, oldPriceFormatted, newPriceFormatted)

        else
            player:SendBroadcastMessage("|cffff0000Error al actualizar el precio en la base de datos.")
        end
        
        -- Limpiar pendingItem
        cache.pendingItem = { id = 0, name = "", price = 0, maxCount = 0, stackable = 1 }
        CLICK_1(event, player, creature)
        return
    end

    --------------------------------------------------------------------------
    -- GM: AÑADIR - Paso 1 (Recibe ID del ítem a añadir)
    --------------------------------------------------------------------------
    if sender == 4 and intId == 0 then
        local id = cleanAndConvert(rawInput)
        
        -- Validación: ID vacío o cero
        if id == 0 then
            player:SendBroadcastMessage("|cffff0000Debes ingresar un ID de objeto válido (mayor a 0).")
            player:GossipComplete()
            return
        end
        
        -- 1. ¿Existe en item_template?
        local it = DB.FIND_ONE_ITEM_TEMPLATE(id)
        if not it then
            player:SendBroadcastMessage("|cffff0000El objeto con ID " .. id .. " no existe en item_template.")
            player:GossipComplete()
            return
        end
        
        -- 2. ¿Está en la blacklist? (Primer check)
        if DB.IS_ITEM_BLACKLISTED(id) then
            player:SendBroadcastMessage("|cffff0000ERROR: El objeto " .. GetItemLink(id, 7) .. "|cffff0000 está en la lista negra y NO puede ser añadido al vendor.")
            player:GossipComplete()
            return
        end
        
        -- 3. ¿Ya existe en el vendor con state = 1?
        local existingItem = DB.FIND_ONE(id)
        if existingItem then
            local currentPrice = existingItem:GetUInt32(2)
            local currentMaxCount = existingItem:GetUInt32(3)
            local currentStackable = existingItem:GetUInt32(4)
            
            player:SendBroadcastMessage("|cffffcc00ADVERTENCIA: El objeto " .. GetItemLink(id, 7) .. "|cffffcc00 ya existe en el vendor.")
            player:SendBroadcastMessage("|cffffcc00Precio actual: " .. formatCurrency(currentPrice) .. " | Límite: " .. currentMaxCount .. " | Stack: " .. currentStackable)
            player:SendBroadcastMessage("|cffffcc00Al confirmar, se REACTIVARÁ (si estaba inactivo) y se actualizará el stackable a " .. it[4] .. ".")
        end
        
        -- 4. Todo bien, proceder con el preview
        local itemName = extractName(GetItemLink(id, 7)) or "Desconocido"
        local suggestedPrice = it[2]
        local maxCount = it[3]
        local stackable = it[4]
        
        cache.pendingItem = {
            id = id,
            name = itemName,
            price = suggestedPrice,
            maxCount = maxCount,
            stackable = stackable
        }
        
        player:GossipClearMenu()
        player:GossipMenuAddItem(
            0, 
            "[CONFIRMAR AÑADIR] " .. GetItemLink(id, 7) .. 
            " - Precio: " .. formatCurrency(suggestedPrice) .. 
            " - Límite: " .. maxCount .. 
            " - Stack: " .. stackable, 
            4, 
            id
        )
        player:GossipSendMenu(1, creature)
        return
    end

    --------------------------------------------------------------------------
    -- GM: AÑADIR - Paso 2 (Confirmación y ejecución)
    --------------------------------------------------------------------------
    if sender == 4 and intId > 0 then
        -- Validación: ¿Hay datos pendientes?
        if not cache.pendingItem or cache.pendingItem.id == 0 then
            player:SendBroadcastMessage("|cffff0000Error: No hay datos pendientes para confirmar. Inicia el proceso de nuevo.")
            player:GossipComplete()
            return
        end
        
        -- Validación: ¿El intId coincide con el ID pendiente?
        if intId ~= cache.pendingItem.id then
            player:SendBroadcastMessage("|cffff0000Error: Inconsistencia en los datos. Operación cancelada.")
            player:GossipComplete()
            return
        end
        
        -- Segundo check de blacklist (TOCTOU protection)
        if DB.IS_ITEM_BLACKLISTED(cache.pendingItem.id) then
            player:SendBroadcastMessage("|cffff0000ERROR: El objeto ha sido añadido a la lista negra mientras confirmabas. Operación cancelada.")
            player:GossipComplete()
            return
        end
        
        -- Validación final: ¿El ítem sigue existiendo en item_template?
        local it = DB.FIND_ONE_ITEM_TEMPLATE(cache.pendingItem.id)
        if not it then
            player:SendBroadcastMessage("|cffff0000ERROR: El objeto ya no existe en item_template. ¿Fue eliminado?")
            player:GossipComplete()
            return
        end
        
        -- Ejecutar la inserción/actualización
        DB.INSERT_ITEM_IN_VENDOR_TABLE(
            cache.pendingItem.id, 
            cache.pendingItem.name, 
            cache.pendingItem.price, 
            cache.pendingItem.maxCount, 
            cache.pendingItem.stackable
        )
        
        -- Feedback de éxito detallado
        local successMsg = string.format(
            '|cff00ff00¡Objeto añadido/activado exitosamente!|r\n' ..
            'ID: %d | Nombre: %s\n' ..
            'Precio: %s | Límite: %d | Stack: %d',
            cache.pendingItem.id,
            cache.pendingItem.name,
            formatCurrency(cache.pendingItem.price),
            cache.pendingItem.maxCount,
            cache.pendingItem.stackable
        )
        player:SendBroadcastMessage(successMsg)

        DB.INSERT_GM_LOG(player:GetGUIDLow(), 'ADD', cache.pendingItem.id, nil, cache.pendingItem.name .. " | Precio: " .. formatCurrency(cache.pendingItem.price))
        
        -- Limpiar pendingItem
        cache.pendingItem = { id = 0, name = "", price = 0, maxCount = 0, stackable = 1 }
        CLICK_1(event, player, creature)
        return
    end

    --------------------------------------------------------------------------
    -- CLIENTE: BÚSQUEDA
    --------------------------------------------------------------------------
    if sender == 0 and intId == 0 then
        local searchTerm = rawInput or ""
        
        -- Validación: término de búsqueda vacío
        if searchTerm == "" then
            player:SendBroadcastMessage("|cffff0000Debes ingresar un término de búsqueda.")
            player:GossipComplete()
            return
        end
        
        local res = DB.LOOK_FOR_ITEM_BY_NAME_OR_PART(searchTerm)
        local msg = "%s\n\nIngresa la cantidad a comprar.\n\nPrecio unitario: %s"
        
        if res and #res > 0 then
            player:GossipClearMenu()
            cache.searchResults = {}
            cache.searchOrder = {}
            local index = 1
            
            player:SendBroadcastMessage(string.format('|cff00ff00Resultados de "|r%s|cff00ff00" (%d encontrados)', searchTerm, #res))
            
            for _, row in ipairs(res) do
                local entry = row[1]
                local buyP = (row[2] == 0) and FLAT_PRICE or row[2]
                local displayPrice = buyP * GLOBAL_RATE_COEFFICIENT
                local coinIcons = formatCurrency(displayPrice)
                
                cache.searchResults[entry] = createItemCacheEntry(entry, buyP, row[3], row[4])
                table.insert(cache.searchOrder, entry)
                
                local ic = cache.searchResults[entry].icon
                local ilink = cache.searchResults[entry].link
                
                player:GossipMenuAddItem(0, ic .. ilink .. ' ' .. coinIcons, entry, index, true, string.format(msg, ilink, coinIcons))
                player:SendBroadcastMessage(index .. '. ' .. ilink .. ' ' .. coinIcons)
                index = index + 1
            end
            
            player:GossipMenuAddItem(0, '<< Volver', 6, 0)
            player:GossipSendMenu(1, creature)
        else
            player:SendBroadcastMessage(string.format('|cffff0000No se encontraron objetos con nombre "%s".', searchTerm))
            player:GossipComplete()
        end
        return
    end

    --------------------------------------------------------------------------
    -- CLIENTE: COMPRAS FRECUENTES
    --------------------------------------------------------------------------
    if sender == 1 and intId == 0 then
        local playerGuid = player:GetGUIDLow()
        local frecuentes = DB.GET_FREQUENT_PURCHASES_BY_PLAYER_ID(playerGuid)
        if frecuentes then
            player:GossipClearMenu()
            local msg = "Ingresa la cantidad a comprar.\n\nPrecio unitario: %s"
            local index = 1
            cache.searchResults = {}
            cache.searchOrder = {}
            repeat
                local entry = frecuentes:GetUInt32(0)
                local buyP = frecuentes:GetUInt32(1)
                local maxC = frecuentes:GetUInt32(2)
                local displayPrice = (buyP == 0 and FLAT_PRICE or buyP) * GLOBAL_RATE_COEFFICIENT
                local coinIcons = formatCurrency(displayPrice)

                -- Obtener stackable desde la tabla del vendor o desde item_template
                local vendorData = DB.FIND_ONE(entry)
                local stack = 1
                if vendorData then
                    stack = vendorData:GetUInt32(4)
                else
                    local it = DB.FIND_ONE_ITEM_TEMPLATE(entry)
                    if it then
                        stack = it[4]
                    end
                end

                cache.searchResults[entry] = createItemCacheEntry(entry, buyP, maxC, stack)
                table.insert(cache.searchOrder, entry)

                player:GossipMenuAddItem(0, cache.searchResults[entry].icon .. GetItemLink(entry, 7) .. ' ' .. coinIcons, entry, index, true, string.format(msg, coinIcons))
                index = index + 1
            until not frecuentes:NextRow()

            player:GossipMenuAddItem(0, '<< Volver', 6, 0)
            player:GossipSendMenu(1, creature)
        else
            player:SendBroadcastMessage('|cffff0000No tienes compras frecuentes registradas.')
            player:GossipComplete()
        end
        return
    end

    --------------------------------------------------------------------------
    -- CLIENTE: EJECUCIÓN DE COMPRA
    --------------------------------------------------------------------------
    if sender >= 0 and intId > 0 and intId <= #cache.searchOrder then
        local itemId = cache.searchOrder[intId]
        local itemData = cache.searchResults[itemId]
        
        if not itemId or not itemData then
            player:SendBroadcastMessage("|cffff0000Error: Objeto no encontrado en caché.")
            player:GossipComplete()
            return
        end
        
        local itemPrice = itemData.price * GLOBAL_RATE_COEFFICIENT
        local maxCount = itemData.maxCount
        local stack = itemData.stackable
        local desired = cleanAndConvert(rawInput)

        if desired < 1 then
            player:SendBroadcastMessage("|cffff0000Debes ingresar un número entero positivo.")
            player:GossipComplete()
            return
        end
        
        if desired > 200 then
            desired = 200
            player:SendBroadcastMessage("|cffffcc00La cantidad máxima por compra es 200. Se ajustó automáticamente.")
        end

        local toBuy = desired
        local mLimit, mSpace, mGold = 0, 0, 0
        local limitReason, spaceReason, goldReason = "", "", ""

        -- 1. Límite posesión
        if maxCount > 0 then
            local canTake = maxCount - player:GetItemCount(itemId)
            if canTake <= 0 then
                player:SendBroadcastMessage("|cffff0000No puedes llevar más de ese objeto.")
                player:GossipComplete()
                return
            end
            if toBuy > canTake then
                mLimit = toBuy - canTake
                toBuy = canTake
                limitReason = mLimit .. " objetos exceden el límite de posesión (" .. maxCount .. " máximo)"
            end
        end

        -- 2. Espacio
        local freeS = player:GetInventoryFreeSlots()
        local maxSpace = freeS * (stack > 0 and stack or 1)
        if toBuy > maxSpace then
            mSpace = toBuy - maxSpace
            toBuy = maxSpace
            spaceReason = mSpace .. " objetos no se pudieron agregar por falta de espacio"
        end

        if toBuy <= 0 then
            local razones = {}
            if limitReason ~= "" then table.insert(razones, limitReason) end
            if spaceReason ~= "" then table.insert(razones, spaceReason) end
            player:SendBroadcastMessage("|cffff0000No se pudo comprar ningún objeto. " .. table.concat(razones, " y ") .. ".")
            player:GossipComplete()
            return
        end

        -- 3. Oro
        local cost = toBuy * itemPrice
        if player:GetCoinage() < cost then
            local maxM = math.floor(player:GetCoinage() / itemPrice)
            if maxM <= 0 then
                player:SendBroadcastMessage("|cffff0000No tienes suficiente oro para realizar la compra.")
                player:GossipComplete()
                return
            end
            mGold = desired - maxM
            toBuy = maxM
            cost = toBuy * itemPrice
            goldReason = mGold .. " objetos no se compraron por falta de oro"
        end

        -- Construir mensaje de limitaciones
        local limitaciones = {}
        if limitReason ~= "" then table.insert(limitaciones, limitReason) end
        if spaceReason ~= "" then table.insert(limitaciones, spaceReason) end
        if goldReason ~= "" then table.insert(limitaciones, goldReason) end

        -- 4. Entrega final
        if player:AddItem(itemId, toBuy) then
            player:ModifyMoney(-cost)
            local mensajeExito = '|CFF00FF00Comprado: ' .. toBuy .. 'x ' .. GetItemLink(itemId, 7)
            if #limitaciones > 0 then
                mensajeExito = mensajeExito .. ' |cffffcc00(Nota: ' .. table.concat(limitaciones, "; ") .. ')|r'
            end
            player:SendBroadcastMessage(mensajeExito)
            DB.INSERT_INTO_LOG(player:GetGUIDLow(), itemId, toBuy, cost)
            DB.INSERT_OR_UPDATE_FREQUENT_PURCHASE(itemId, itemData.price, maxCount, player:GetGUIDLow())
            creature:SendUnitSay(player:GetName() .. ' ha comprado ' .. toBuy .. 'x ' .. GetItemLink(itemId, 7) .. '.', 0)
        else
            player:SendBroadcastMessage("|cffff0000Error al añadir el objeto al inventario.")
        end
        player:GossipComplete()
        return
    end

    --------------------------------------------------------------------------
    -- CLIENTE: REGISTRO DE COMPRAS
    --------------------------------------------------------------------------
    if sender == 2 and intId == 0 then
        local playerGuid = player:GetGUIDLow()
        if DB.PLAYER_HAS_LOG(playerGuid) then
            local log = DB.GET_LAST_ITEMS_FROM_LOG(playerGuid)
            local counter = 1
            local y = '|cff8fd1c4'
            player:SendBroadcastMessage(y .. 'Últimos registros (en hora Perú UTC-5) de ' .. player:GetName() .. ':')
            repeat
                local amount = log:GetUInt32(0)
                local itemId = log:GetUInt32(1)
                local rawDate = log:GetString(2)
                local date = formatDate(rawDate)
                local expense = formatCurrency(log:GetUInt32(3))
                local msg = string.format('%s' .. counter .. '%s. ' .. GetItemLink(itemId, 7) .. '%s×' .. amount .. '%s por ' .. expense .. '%s - ' .. date, y, y, y, y, y)
                player:SendBroadcastMessage(msg)
                counter = counter + 1
            until not log:NextRow()
        else
            player:SendBroadcastMessage('|cffff0000No hay registros de compras.')
        end
        player:GossipComplete()
        return
    end
end

RegisterCreatureGossipEvent(NPC_ID, 1, CLICK_1)
RegisterCreatureGossipEvent(NPC_ID, 2, CLICK_2)
RegisterPlayerEvent(4, ON_PLAYER_LOGOUT)
