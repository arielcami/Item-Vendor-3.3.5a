local NPC_ID = 60000
local MAX_RESULTS = 28
local ITEMS_IDS, ITEMS_PRICES, ITEMS_MAXCOUNTS, ITEMS_UNIQUES, GLOBAL_RATE_COEFFICIENT, FLAT_PRICE
local itemID_for_adding, itemNAME_for_adding, itemBuyPrice_for_adding, itemMaxcount_for_adding

-- Función para escapar caracteres especiales en SQL
local function escapeSQL(input)
    if input == nil then
        return ""
    end
    local str = tostring(input)
    local escapes = {
        ['\\'] = '\\\\',
        ['\''] = '\\\'',
        ['"'] = '\\"',
        ['\0'] = '\\0',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\x1a'] = '\\Z'
    }
    return (str:gsub("([\\'\"\0\n\r\x1a])", escapes))
end

-- Función para formatear fecha en español
local function formatDate(timestamp)
    local months = {'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'}
    local days = {'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'}

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
    local dayNameCapitalized = dayName:gsub("^%l", string.upper)

    local period = hour >= 12 and "p.m." or "a.m."
    local hour12 = hour % 12
    if hour12 == 0 then
        hour12 = 12
    end

    return string.format("%s %d de %s de %d - %d:%s %s", dayNameCapitalized, day, months[month], year, hour12, minute, period)
end

-- Consultas dinámicas
local function Query()
    return {
        CREATE_ITEM_TABLE = function()
            WorldDBExecute(
                [[CREATE TABLE IF NOT EXISTS a_itemvendor (entry INT UNSIGNED NOT NULL PRIMARY KEY, `name` VARCHAR(80) NOT NULL, buyPrice INT UNSIGNED NOT NULL, maxCount INT UNSIGNED NOT NULL)]])
        end,

        CREATE_LOG_TABLE = function()
            WorldDBExecute(
                [[CREATE TABLE IF NOT EXISTS a_itemvendor_log (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, player_id INT UNSIGNED NOT NULL,
                item_id MEDIUMINT UNSIGNED NOT NULL, amount MEDIUMINT UNSIGNED NOT NULL, expense INT UNSIGNED NOT NULL,
                purchase_time TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP)]])
        end,

        CREATE_FRECUENT_TABLE = function()
            WorldDBExecute(
                [[CREATE TABLE IF NOT EXISTS a_itemvendor_frecuent (entry INT UNSIGNED NOT NULL, buyPrice INT UNSIGNED NOT NULL,
                maxCount TINYINT UNSIGNED NOT NULL, times INT UNSIGNED NOT NULL DEFAULT '1', player_id INT UNSIGNED NOT NULL,
                UNIQUE KEY uniq_entry_player (entry,player_id))]])
        end,

        CREATE_FIXED_AMOUNT_TABLE = function()
            WorldDBExecute(
                "CREATE TABLE IF NOT EXISTS a_itemvendor_fixed_amount (amount INT UNSIGNED PRIMARY KEY DEFAULT 10000)")
        end,

        CREATE_GLOBAL_RATE_TABLE = function()
            WorldDBExecute(
                "CREATE TABLE IF NOT EXISTS a_itemvendor_global_rate (rate TINYINT UNSIGNED PRIMARY KEY DEFAULT 1)")
        end,

        CREATE_BLACKLIST_TABLE = function()
            WorldDBExecute(
                [[CREATE TABLE IF NOT EXISTS a_itemvendor_blacklist (id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY)]])
        end,

        PUPULATE_BLACKLIST_TABLE = function()
            WorldDBExecute(
                [[INSERT IGNORE INTO a_itemvendor_blacklist (id) VALUES (24477),(24476),(33470),(21877),(28430),(40553),(41257),(41383),(41384),(44926), 
            (44948),(30732),(30724),(31318),(34622),(31342),(31322),(31336),(31334),(31332),(31331),(31323),(20698),(45173),(45172),(45174),(45175),(38497), 
            (38496),(38498),(27965),(34025),(34030),(37126),(28388),(28389),(17882),(17887),(22023),(22024),(22584),(29841),(29868),(29871),(14891),(1442), 
            (26173),(26174),(26175),(26180),(26235),(26324),(26368),(26372),(26464),(26465),(26548),(26655),(26738),(26792),(26843),(27196),(27218),(37301), 
            (38292),(39163),(45575),(138),(931),(2275),(2588),(2599),(3884),(3934),(5632),(40754),(40948),(43336),(43337),(43384),(31266),(27774),(27811), 
            (28117),(28122),(41403),(41404),(41405),(41406),(41407),(41408),(41409),(41410),(41411),(41412),(41413),(41414),(41415),(41416),(41417),(41418), 
            (41419),(41420),(41421),(41422),(41423),(43362),(45908),(21038),(32722),(33226),(34062),(34599),(38294),(38518),(42986),(43523),(46783),(54822), 
            (52252),(996),(1020),(1021),(1024),(1025),(1027),(1162),(5235)]])
        end,

        BLACKLIST_TABLE_IS_EMPTY = function()
            local sql = WorldDBQuery("SELECT 1 FROM a_itemvendor_blacklist LIMIT 1")
            local ret
            if sql then
                -- IS FULL
                ret = false
            else
                -- IS EMPTY
                ret = true
            end
            return ret
        end,

        INSERT_INTO_LOG = function(player_id, item_id, amount, expense)
            WorldDBExecute(string.format(
                "INSERT INTO a_itemvendor_log (player_id, item_id, amount, expense) VALUES (%d, %d, %d, %d)", player_id,
                item_id, amount, expense))
        end,

        INSERT_OR_UPDATE_FREQUENT_PURCHASE = function(entry, buyPrice, maxCount, player_id)
            WorldDBExecute(string.format(
                "INSERT INTO a_itemvendor_frecuent (entry, buyPrice, maxCount, times, player_id) VALUES (%d, %d, %d, 1, %d) ON DUPLICATE KEY UPDATE times = times + 1",
                entry, buyPrice, maxCount, player_id))
        end,

        INSERT_DEFAULT_FIXED_AMOUNT = function()
            WorldDBExecute("INSERT INTO a_itemvendor_fixed_amount VALUES ()")
        end,

        INSERT_DEFAULT_GLOBAL_RATE = function()
            WorldDBExecute("INSERT INTO a_itemvendor_global_rate VALUES ()")
        end,

        INSERT_NPC = function(entry)
            local statement_1 =
                [[INSERT IGNORE INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1,
            KillCredit2, `name`, subname, IconName, gossip_menu_id, minlevel, maxlevel, `exp`, faction, npcflag, speed_walk, speed_run, speed_swim,
            speed_flight, detection_range, scale, `rank`, dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance,
            unit_class, unit_flags, unit_flags2, dynamicflags, family, trainer_type, trainer_spell, trainer_class, trainer_race, `type`,
            type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier,
            ManaModifier, ArmorModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, spell_school_immune_mask,
            flags_extra, ScriptName, VerifiedBuild) VALUES ]]

            local statement_2 =
                "INSERT IGNORE INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) VALUES "

            WorldDBExecute(statement_1 .. [[(]] .. entry .. [[,0,0,0,0,0,'Michael Jackson','Vendedor de Objetos',NULL,0,83,83,2,35,1,1,1,1,1,20,1,3,0,1,2000,2000,1,1,8,0,0,0,0,0,0,0,0,7,4,0,0,0,0,0,0,0,'',0,1,450,450,4,1,0,0,1,0,0,0,'',12340)]])
            WorldDBExecute(statement_2 .. [[(]] .. entry .. [[, 0, 16540, 1, 1, 12340)]])
        end,

        LOOK_FOR_ITEM_BY_NAME_OR_PART = function(name_or_part)
            local escapedName = escapeSQL(name_or_part)
            local sql = WorldDBQuery(string.format(
                "SELECT entry, buyPrice, maxCount FROM a_itemvendor WHERE `name` LIKE '%%%s%%' LIMIT %d", escapedName,
                (MAX_RESULTS > 30 and 30 or MAX_RESULTS)))
            if sql then
                local result = {}
                repeat
                    table.insert(result, {sql:GetUInt32(0), sql:GetUInt32(1), sql:GetUInt32(2)})
                until not sql:NextRow();
                return result
            else
                return nil
            end
        end,

        GET_FRECUENT_PURCHASES_BY_PLAYER_ID = function(player_id)
            local sql = WorldDBQuery(string.format(
                "SELECT * FROM a_itemvendor_frecuent WHERE player_id = %d ORDER BY times DESC LIMIT " .. MAX_RESULTS,
                player_id))
            return sql
        end,

        GET_GLOBAL_RATE = function()
            local query = WorldDBQuery("SELECT rate FROM a_itemvendor_global_rate")
            return query:GetUInt8(0)
        end,

        GET_FLAT_AMOUNT_BUYPRICE = function()
            local query = (WorldDBQuery("SELECT amount FROM a_itemvendor_fixed_amount")):GetUInt32(0)
            return query
        end,

        VENDOR_TABLE_IS_EMPTY = function()
            local sql = WorldDBQuery("SELECT 1 FROM a_itemvendor LIMIT 1")
            local ret
            if sql then
                ret = false
            else
                ret = true
            end
            return ret
        end,

        FIXED_BUYPRICE_AMOUNT_EXISTS = function()
            local sql = (WorldDBQuery("SELECT 1 FROM a_itemvendor_fixed_amount LIMIT 1")):GetUInt8(0) == 1 and true or
                            false
            return sql
        end,

        PLAYER_HAS_LOG = function(player_id)
            local sql = WorldDBQuery(string.format("SELECT 1 FROM a_itemvendor_log WHERE player_id = %d", player_id))
            return sql and true or false
        end,

        GET_LAST_ITEMS_FROM_LOG = function(player_id)
            local sql = WorldDBQuery(string.format(
                "SELECT amount, item_id, purchase_time, expense FROM a_itemvendor_log WHERE player_id = %d ORDER BY purchase_time DESC LIMIT " ..
                    MAX_RESULTS, player_id))
            return sql
        end,

        NPC_EXISTS = function()
            local sql = WorldDBQuery(string.format("SELECT 1 FROM creature_template WHERE entry = %d", NPC_ID))
            return sql and true or false
        end,

        FIND_ONE = function(entry)
            local sql = WorldDBQuery(string.format('SELECT * from a_itemvendor WHERE entry = %d', entry))
            return sql and sql or false
        end,

        FIND_ONE_ITEM_TEMPLATE = function(entry)
            local sql = WorldDBQuery(string.format(
                'SELECT entry, BuyPrice, maxcount from item_template WHERE entry = %d', entry))
            return sql and {sql:GetUInt32(0), sql:GetUInt32(1), sql:GetUInt32(2)} or false
        end,

        UPDATE_ITEM_BUYPRICE = function(entry, new_price)
            local get = WorldDBQuery('SELECT * from a_itemvendor WHERE entry = ' .. entry)
            local result = false
            if get then
                WorldDBExecute(string.format('UPDATE a_itemvendor SET buyPrice = %d WHERE entry = %d', new_price, entry))
                result = true
            end
            return result
        end,

        INSERT_ITEM_IN_VENDOR_TABLE = function(entry, name, buyprice, maxcount)
            local escapedName = escapeSQL(name)
            local sql = string.format(
                'INSERT INTO a_itemvendor (entry, `name`, buyPrice, maxCount) VALUES (%d, "%s", %d, %d)', entry,
                escapedName, buyprice, maxcount)
            WorldDBExecute(sql)
        end,

        DELETE_ITEM_FROM_VENDOR_TABLE = function(entry)
            WorldDBExecute('DELETE FROM a_itemvendor WHERE entry = ' .. entry)
        end
    }
end

local DB = Query()

local function getIcon(item_id)
    local ItemTemplate = GetItemTemplate(item_id)
    local icon = ItemTemplate:GetIcon()
    local icon_base = "|TInterface\\Icons\\%s:21:21:-22|t"
    return string.format(icon_base, icon)
end

local function getIconBig(item_id)
    local ItemTemplate = GetItemTemplate(item_id)
    local icon = ItemTemplate:GetIcon()
    local icon_base = "|TInterface\\Icons\\%s:45:45:-22|t"
    return string.format(icon_base, icon)
end

local function formatCurrency(copper)
    local oro = math.floor(copper / 10000)
    local plata = math.floor((copper % 10000) / 100)
    local cobre = copper % 100
    local path = "|TInterface\\MoneyFrame\\"
    local parts = {}

    local function formatNumber(n)
        return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end

    if oro > 0 then
        table.insert(parts, "|CFFFFFFFF" .. formatNumber(oro) .. "|r" .. path .. "UI-GoldIcon:0:0:2:0|t")
    end
    if plata > 0 or (cobre > 0 and oro > 0) then
        table.insert(parts, "|CFFFFFFFF" .. plata .. "|r" .. path .. "UI-SilverIcon:0:0:2:0|t")
    end
    if cobre > 0 or (oro == 0 and plata == 0) then
        table.insert(parts, "|CFFFFFFFF" .. cobre .. "|r" .. path .. "UI-CopperIcon:0:0:2:0|t")
    end
    return table.concat(parts, " ")
end

-- Elegir iconos
local function ico(sel)
    return (sel == 1) and "|TInterface\\Icons\\inv_misc_spyglass_01:42:42:-21:0|t" or (sel == 2) and
        "|TInterface\\Icons\\inv_inscription_scroll:42:42:-21:0|t" or (sel == 3) and
        "|TInterface\\Icons\\inv_misc_coin_02:42:42:-21:0|t" or (sel == 4) and
        "|TInterface\\Icons\\spell_holy_stoicism:42:42:-21:0|t" or (sel == 5) and
        "|TInterface\\Icons\\inv_enchant_shardglowingsmall:42:42:-21:0|t" or (sel == 6) and
        "|TInterface\\Icons\\spell_shadow_sacrificialshield:42:42:-21:0|t"
end

local function extractName(link)
    if type(link) ~= "string" then
        return nil
    end
    return link:match("%[(.-)%]")
end

local function cleanAndConvert(input)
    return math.max(0, math.floor(tonumber(input) or 0))
end

-- Centralized cache to prevent data overlap between players
local playerVendorCache = {}

-- Helper function to get or initialize a player's specific cache
local function GetPlayerCache(player)
    local guid = player:GetGUIDLow()
    if not playerVendorCache[guid] then
        playerVendorCache[guid] = {
            searchResults   = { ids = {}, prices = {}, maxCounts = {}, uniques = {} },
            pendingItem     = { id = 0, name = "", price = 0, maxCount = 0 }
        }
    end
    return playerVendorCache[guid]
end

---------------------------
-- MAIN GOSSIP MENU (CLICK_1)
---------------------------
local function CLICK_1(event, player, creature)
    -- Initialize or reset search results when opening the main menu
    local cache = GetPlayerCache(player)
    cache.searchResults = {
        ids = {},
        prices = {},
        maxCounts = {},
        uniques = {}
    }

    if DB.VENDOR_TABLE_IS_EMPTY() then
        player:SendBroadcastMessage('|CFFff0000El sistema necesita configuración antes de ejecutarse.')
        player:GossipComplete()
        return
    end

    player:GossipMenuAddItem(8, ico(1) .. 'Buscar un objeto', 0, 0, true, 'Ingresa parte del nombre del objeto...')
    player:GossipMenuAddItem(8, ico(3) .. 'Comprados frecuentemente', 1, 0)
    player:GossipMenuAddItem(8, ico(2) .. string.format('Ver registro de compras (%d)', MAX_RESULTS), 2, 0)

    if player:IsGM() then
        player:GossipMenuAddItem(8, ico(4) .. 'Editar precio de un objeto', 3, 0, true, "Ingresa el |cffffff00ID|r del objeto a editar:\n(Solo números enteros positivos)")
        player:GossipMenuAddItem(8, ico(5) .. 'Añadir un objeto', 4, 0, true, "Ingresa el |cffffff00ID|r del objeto a agregar:\n(Solo números enteros positivos) ")
        player:GossipMenuAddItem(8, ico(6) .. 'Eliminar un objeto', 5, 0, true, "Ingresa el |cffffff00ID|r del objeto a eliminar:\n(Solo números enteros positivos)")
    end

    player:GossipSendMenu(1, creature)
end

---------------------------
-- OPTION HANDLER (CLICK_2)
---------------------------
local function CLICK_2(event, player, creature, sender, intId, rawInput)
    local cache = GetPlayerCache(player)

    FLAT_PRICE = DB.GET_FLAT_AMOUNT_BUYPRICE();
    GLOBAL_RATE_COEFFICIENT = DB.GET_GLOBAL_RATE();

    -- 1. NAVIGATION: RETURN
    if sender == 6 then
        CLICK_1(event, player, creature)
        return
    end

    -- 2. DELETE ITEM LOGIC (GM)
    if sender == 5 and intId == 0 then
        local entry = cleanAndConvert(rawInput)
        if entry > 0 then
            if DB.FIND_ONE(entry) then
                DB.DELETE_ITEM_FROM_VENDOR_TABLE(entry)
                player:SendBroadcastMessage('|CFF00FF00Se eliminó correctamente: ' .. GetItemLink(entry, 7))
            else
                player:SendBroadcastMessage('|CFFFF0000Error: El objeto no está en la lista del vendedor.')
            end
        end
        CLICK_1(event, player, creature)
        return
    end

    -- 3. CONFIRM ADD ITEM (GM)
    if sender == 4 and intId > 0 then
        DB.INSERT_ITEM_IN_VENDOR_TABLE(cache.pendingItem.id, cache.pendingItem.name, cache.pendingItem.price,
            cache.pendingItem.maxCount)
        player:SendBroadcastMessage('|CFF00FF00¡Objeto agregado correctamente!')
        CLICK_1(event, player, creature)
        return
    end

    -- 4. SEARCH ITEM TO ADD (GM)
    if sender == 4 and intId == 0 then
        local itemId = cleanAndConvert(rawInput)
        local itemTemplate = DB.FIND_ONE_ITEM_TEMPLATE(itemId)

        if not itemTemplate then
            player:SendBroadcastMessage('|CFFFF0000Error: El objeto no existe en la DB del servidor.')
        elseif DB.FIND_ONE(itemId) then
            player:SendBroadcastMessage('|CFFFF0000Error: El objeto ya está en la lista del vendedor.')
        else
            local itemLink = GetItemLink(itemId, 7)
            player:GossipClearMenu()
            player:SendBroadcastMessage('|CFF00FF00Objeto encontrado: ' .. itemLink)

            -- Store in player's pending cache (indexed by GUID)
            cache.pendingItem = {
                id = itemId,
                name = extractName(itemLink),
                price = itemTemplate[2],
                maxCount = itemTemplate[3]
            }

            player:GossipMenuAddItem(0, getIconBig(itemId) .. "|CFF0073ff[ACEPTAR AÑADIR]", 4, itemId)
            player:GossipSendMenu(1, creature)
            return
        end
        CLICK_1(event, player, creature)
        return
    end

    -- 5. CONFIRM EDIT PRICE (GM)
    if sender == 3 and intId > 0 then
        local newPrice = cleanAndConvert(rawInput)
        if DB.UPDATE_ITEM_BUYPRICE(intId, newPrice) then
            player:SendBroadcastMessage('|CFF00FF00¡Precio actualizado correctamente!')
        else
            player:SendBroadcastMessage('|CFFFF0000Error al actualizar precio.')
        end
        CLICK_1(event, player, creature)
        return
    end

    -- 6. SEARCH ITEM TO EDIT (GM)
    if sender == 3 and intId == 0 then
        local entry = cleanAndConvert(rawInput)
        local itemData = DB.FIND_ONE(entry)

        if itemData then
            player:GossipClearMenu()
            local itemId = itemData:GetUInt32(0)
            local itemName = itemData:GetString(1)
            local currentPrice = itemData:GetUInt32(2)

            player:GossipMenuAddItem(0, getIconBig(itemId) .. itemName .. ": " .. formatCurrency(currentPrice), 3, itemId, true, 'Escribe el nuevo precio en cobre:')
            player:GossipSendMenu(1, creature)
        else
            player:SendBroadcastMessage('|CFFFF0000Objeto no encontrado en el vendedor.')
            CLICK_1(event, player, creature)
        end
        return
    end

    -- 7. FREQUENT PURCHASES
    if sender == 1 and intId == 0 then
        local results = DB.GET_FRECUENT_PURCHASES_BY_PLAYER_ID(player:GetGUIDLow())
        if results then
            player:GossipClearMenu()

            -- Reset search results for this player
            cache.searchResults = { ids = {}, prices = {}, maxCounts = {}, uniques = {} }

            local counter = 1
            repeat
                local itemId = results:GetUInt32(0)
                local buyPrice = (results:GetUInt32(1) == 0) and FLAT_PRICE or results:GetUInt32(1)
                local maxCount = results:GetUInt32(2)
                local itemLink = GetItemLink(itemId, 7)
                local priceDisplay = formatCurrency(buyPrice * GLOBAL_RATE_COEFFICIENT)

                table.insert(cache.searchResults.ids, itemId)
                table.insert(cache.searchResults.prices, buyPrice)
                table.insert(cache.searchResults.maxCounts, maxCount)
                table.insert(cache.searchResults.uniques, (maxCount == 1))

                player:GossipMenuAddItem(0, getIcon(itemId) .. itemLink .. ' |cff752f00' .. priceDisplay, itemId, counter, true, 'Ingresa la cantidad:')
                counter = counter + 1
            until not results:NextRow()

            player:GossipMenuAddItem(0, '<< Regresar', 6, 0)
            player:GossipSendMenu(1, creature)
        else
            player:SendBroadcastMessage('|cffff0000No tienes registros frecuentes.')
            player:GossipComplete()
        end
        return
    end

    -- 8. VIEW PURCHASE LOG
    if sender == 2 and intId == 0 then
        local playerGuid = player:GetGUIDLow()
        if DB.PLAYER_HAS_LOG(playerGuid) then
            local log = DB.GET_LAST_ITEMS_FROM_LOG(playerGuid)
            local counter = 1
            local y = '|cff8fd1c4'
            player:SendBroadcastMessage(y .. 'Últimos registros de ' .. player:GetName() .. ':')
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

    -- 9. ITEM SEARCH (BY NAME)
    if sender == 0 and intId == 0 then
        local searchTerm = escapeSQL(rawInput)

        local queryData = DB.LOOK_FOR_ITEM_BY_NAME_OR_PART(searchTerm)

        if queryData then
            player:GossipClearMenu()

            -- Reset search results for this player
            cache.searchResults = { ids = {}, prices = {}, maxCounts = {}, uniques = {} }

            local counter = 1

            for _, row in ipairs(queryData) do
                local itemId = row[1]
                local buyPrice = (row[2] == 0) and FLAT_PRICE or row[2]
                local maxCount = row[3]
                local priceDisplay = formatCurrency(buyPrice * GLOBAL_RATE_COEFFICIENT)
                local itemLink = GetItemLink(itemId, 7)

                table.insert(cache.searchResults.ids, itemId)
                table.insert(cache.searchResults.prices, buyPrice)
                table.insert(cache.searchResults.maxCounts, maxCount)
                table.insert(cache.searchResults.uniques, (maxCount == 1))

                player:GossipMenuAddItem(0, getIcon(itemId) .. itemLink .. ' |cff752f00' .. priceDisplay, itemId, counter, true, 'Ingresa la cantidad:')
                player:SendBroadcastMessage(counter .. '. ' .. itemLink .. ' ' .. priceDisplay)
                counter = counter + 1
            end
            player:GossipMenuAddItem(0, '<< Regresar', 6, 0)
            player:GossipSendMenu(1, creature)
        else
            player:SendBroadcastMessage(string.format('No se encontraron resultados para "|CFF00FF00%s|r".', rawInput))
            player:GossipComplete()
        end
        return
    end

    -- 10. PURCHASE EXECUTION
    if intId > 0 and intId <= #cache.searchResults.ids then
        local itemId = cache.searchResults.ids[intId]
        local itemPrice = cache.searchResults.prices[intId]
        local isUnique = cache.searchResults.uniques[intId]
        local maxCount = cache.searchResults.maxCounts[intId]

        local desiredQuantity = cleanAndConvert(rawInput)
        if desiredQuantity < 1 then
            player:SendBroadcastMessage('|cffff0000Ingresa un número válido.')
            player:GossipComplete()
            return
        end

        if desiredQuantity > 200 then
            desiredQuantity = 200
        end

        -- Verificar objeto único antes de intentar comprar
        if isUnique and player:HasItem(itemId) then
            player:SendBroadcastMessage('|cffff0000Ya posees este objeto único.')
            player:GossipComplete()
            return
        end

        local addedCount = 0
        local totalCost = 0
        local itemCost = itemPrice * GLOBAL_RATE_COEFFICIENT

        for i = 1, desiredQuantity do
            if player:AddItem(itemId, 1) then
                addedCount = addedCount + 1
                totalCost = totalCost + itemCost
            else
                -- No hay más espacio, salir del bucle
                break
            end
        end

        if addedCount > 0 then
            player:ModifyMoney(-totalCost)
            player:SendBroadcastMessage('|CFF00FF00Comprado: ' .. addedCount .. '× ' .. GetItemLink(itemId, 7) .. ' |CFF00FF00por ' .. formatCurrency(totalCost) .. '.')
            DB.INSERT_INTO_LOG(player:GetGUIDLow(), itemId, addedCount, totalCost)
            DB.INSERT_OR_UPDATE_FREQUENT_PURCHASE(itemId, itemPrice, maxCount, player:GetGUIDLow())
            creature:SendUnitSay(player:GetName() .. ' ha comprado ' .. addedCount .. '× ' .. GetItemLink(itemId, 7) .. '.', 0)

            if addedCount < desiredQuantity then
                player:SendBroadcastMessage('|cffff6600Solo se pudieron agregar ' .. addedCount .. ' de ' .. desiredQuantity .. ' objetos por falta de espacio.')
            end
        else
            player:SendBroadcastMessage('|cffff0000No tienes espacio en el inventario.')
        end

        player:GossipComplete()
    end
end

RegisterCreatureGossipEvent(NPC_ID, 1, CLICK_1)
RegisterCreatureGossipEvent(NPC_ID, 2, CLICK_2)

local function AL_RECARGAR_ALE(e)
    DB.CREATE_ITEM_TABLE();
    DB.CREATE_LOG_TABLE();
    DB.CREATE_FRECUENT_TABLE();
    DB.CREATE_FIXED_AMOUNT_TABLE();
    DB.CREATE_GLOBAL_RATE_TABLE();
    DB.CREATE_BLACKLIST_TABLE();
end

RegisterServerEvent(33, AL_RECARGAR_ALE)
