--[[
    Autor: Ariel Camilo - Desarrollador de Software
    Script:                 Configurator: NPC Configurador de sistema de ventas.
    Para base de datos:     MySQL ^8.0.43
    Para core:              AzerothCore
    Wow Version:            3.3.5a
    Engine:                 Azerothcore Lua Engine (ALE)
]]

local NPC_ID = 60006
local configCache = {}
local cachedGlobalRate = nil
local cachedFlatPrice = nil 

-- Auditoría de GM
local function insertGMLog(gm_id, action, item_id, old_value, new_value)
    WorldDBExecute(string.format(
        "INSERT INTO a_itemvendor_gm_log (gm_id, action, item_id, old_value, new_value) VALUES (%d, '%s', %s, %s, %s)",
        gm_id, action, item_id or "NULL", old_value and ("'" .. old_value:gsub("'", "\\'") .. "'") or "NULL",
        new_value and ("'" .. new_value:gsub("'", "\\'") .. "'") or "NULL"
    ))
end

local FILTER_CATEGORIES = {
    { name = "Tipos de Item", indices = {1, 2, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30} },
    { name = "Calidades", indices = {11, 12, 13, 14, 15, 16, 17} },
    { name = "Ligado (Binding)", indices = {5, 6, 7, 8, 9, 10, 18} },
    { name = "Épicos en Armadura y Arma", indices = {3, 4} }
}

local function formatWithComma(n)
    local rev = tostring(n):reverse()
    local withCommas = rev:gsub("(%d%d%d)", "%1,")
    if withCommas:sub(-1) == "," then
        withCommas = withCommas:sub(1, -2)
    end
    return withCommas:reverse()
end

local function formatCurrency(copper)
    local oro = math.floor(copper / 10000)
    local plata = math.floor((copper % 10000) / 100)
    local cobre = copper % 100
    local path = "|TInterface\\MoneyFrame\\"
    local parts = {}

    if oro > 0 then
        table.insert(parts, string.format("%s%s%s%s", "|CFFFFFFFF", formatWithComma(oro), "|r",
            path .. "UI-GoldIcon:0:0:0:0|t"))
    end
    if plata > 0 or (cobre > 0 and oro > 0) then
        table.insert(parts, string.format("%s%d%s%s", "|CFFFFFFFF", plata, "|r", path .. "UI-SilverIcon:0:0:0:0|t"))
    end
    if cobre > 0 or (oro == 0 and plata == 0) then
        table.insert(parts, string.format("%s%d%s%s", "|CFFFFFFFF", cobre, "|r", path .. "UI-CopperIcon:0:0:0:0|t"))
    end
    return table.concat(parts, " ")
end

local SETTINGS = {
    [1] = 'Armas - Global',
    [2] = 'Armaduras - Global',
    [3] = 'Armas épicas',
    [4] = 'Armaduras épicas',
    [5] = 'Items que no se ligan',
    [6] = 'Items que se ligan al recoger',
    [7] = 'Items que se ligan al equipar',
    [8] = 'Items que se ligan al usar',
    [9] = 'Items que se ligan de misión',
    [10] = 'Items que se ligan de eventos',
    [11] = 'Items grises',
    [12] = 'Items blancos',
    [13] = 'Items verdes',
    [14] = 'Items azules',
    [15] = 'Items morados',
    [16] = 'Items naranja',
    [17] = 'Items artefacto',
    [18] = 'Items que se ligan a la cuenta',
    [19] = 'Consumibles',
    [20] = 'Bolsas',
    [21] = 'Gemas',
    [22] = 'Proyectiles',
    [23] = 'Recetas',
    [24] = 'Marcas de honor',
    [25] = 'Carcaj',
    [26] = 'Objetos de misión - Global',
    [27] = 'Llaves',
    [28] = 'Objetos comerciables',
    [29] = 'Miscelánea',
    [30] = 'Glifos'
}

local function cargarListaNegra()
    local Q = WorldDBQuery("SELECT id FROM a_itemvendor_blacklist");
    local ids = {}
    if Q then
        repeat
            table.insert(ids, tostring(Q:GetUInt32(0)))
        until not Q:NextRow()
    else
        print('La lista negra esta vacia y/o la tabla no existe.')
    end
    return table.concat(ids, ",")
end

local function getTableFromDB()
    local Q = WorldDBQuery('SELECT * FROM a_itemvendor_config')
    local conf_table = {}
    if Q then
        repeat
            local value = Q:GetUInt32(2) == 1 and 'TRUE' or 'FALSE';
            table.insert(conf_table, value)
        until not Q:NextRow();
    end
    return conf_table
end

local function refreshConfigCache()
    -- Filtros
    configCache = {}
    local Q = WorldDBQuery('SELECT id, config_value FROM a_itemvendor_config ORDER BY id')
    if Q then
        repeat
            local id = Q:GetUInt32(0)
            local value = Q:GetUInt32(1)
            configCache[id] = (value == 1)
        until not Q:NextRow()
    end
    
    -- Rate Global
    local qRate = WorldDBQuery('SELECT rate FROM a_itemvendor_global_rate WHERE id = 1')
    cachedGlobalRate = qRate and qRate:GetUInt8(0) or 1
    
    -- Precio Base
    local qPrice = WorldDBQuery('SELECT amount FROM a_itemvendor_fixed_amount WHERE id = 1')
    cachedFlatPrice = qPrice and qPrice:GetUInt32(0) or 10000
end

-- Función para obtener valor desde caché
local function getCachedConfig(id)
    if configCache[id] == nil then
        refreshConfigCache()
    end
    return configCache[id] or false
end 

local function getCachedGlobalRate()
    if cachedGlobalRate == nil then
        refreshConfigCache()
    end
    return cachedGlobalRate
end

local function getCachedFlatPrice()
    if cachedFlatPrice == nil then
        refreshConfigCache()
    end
    return cachedFlatPrice
end

local function updateGlobalRate(newRate)
    cachedGlobalRate = newRate
    WorldDBExecute('UPDATE a_itemvendor_global_rate SET rate = ' .. newRate .. ' WHERE id = 1')
end

local function updateFlatPrice(newPrice)
    cachedFlatPrice = newPrice
    WorldDBExecute('UPDATE a_itemvendor_fixed_amount SET amount = ' .. newPrice .. ' WHERE id = 1')
end

local function toggleConfig(id)
    local newValue = not getCachedConfig(id)
    configCache[id] = newValue
    local intValue = newValue and 1 or 0
    WorldDBExecute("UPDATE a_itemvendor_config SET config_value = " .. intValue .. " WHERE id = " .. id)
end


local function populateTable()
    local config_table = getTableFromDB()
    local LISTA_NEGRA = cargarListaNegra()

    local CONF = {
        ['ARMAS'] = config_table[1],
        ['ARMADURAS'] = config_table[2],
        ['ARMAS_EPICAS'] = config_table[3],
        ['ARMADURAS_EPICAS'] = config_table[4],
        ['ITEMS_QUE_NO_SE_LIGAN'] = config_table[5],
        ['ITEMS_QUE_SE_LIGAN_AL_RECOGER'] = config_table[6],
        ['ITEMS_QUE_SE_LIGAN_AL_EQUIPAR'] = config_table[7],
        ['ITEMS_QUE_SE_LIGAN_AL_USAR'] = config_table[8],
        ['ITEMS_QUE_SE_LIGAN_MISION'] = config_table[9],
        ['ITEMS_QUE_SE_LIGAN_iCOKE'] = config_table[10],
        ['CALIDAD_GRIS'] = config_table[11],
        ['CALIDAD_BLANCO'] = config_table[12],
        ['CALIDAD_VERDE'] = config_table[13],
        ['CALIDAD_AZUL'] = config_table[14],
        ['CALIDAD_MORADO'] = config_table[15],
        ['CALIDAD_NARANJA'] = config_table[16],
        ['CALIDAD_ARTEFACTO'] = config_table[17],
        ['ITEMS_QUE_SE_LIGAN_A_LA_CUENTA'] = config_table[18],
        ['CONSUMIBLES'] = config_table[19],
        ['BOLSAS'] = config_table[20],
        ['GEMAS'] = config_table[21],
        ['PROYECTILES'] = config_table[22],
        ['RECETAS'] = config_table[23],
        ['MARCAS_DE_HONOR'] = config_table[24],
        ['CARCAJ'] = config_table[25],
        ['OBJETOS_DE_MISION'] = config_table[26],
        ['LLAVES'] = config_table[27],
        ['OBJETOS_COMERCIABLES'] = config_table[28],
        ['MISCELANEA'] = config_table[29],
        ['GLIFOS'] = config_table[30]
    }

    local dump_data = "INSERT INTO a_itemvendor (entry, `name`, buyPrice, maxCount, stackable, state) " ..
                          "SELECT it.entry, COALESCE(itl.Name, it.name), it.buyPrice, it.maxcount, it.stackable, 1 " ..
                          "FROM item_template it LEFT JOIN item_template_locale itl ON it.entry = itl.ID AND itl.locale = 'esMX' " ..
                          "WHERE 1=1 " .. "AND ((" .. CONF['ITEMS_QUE_NO_SE_LIGAN'] .. " AND it.bonding = 0) OR " .. "(" ..
                          CONF['ITEMS_QUE_SE_LIGAN_AL_RECOGER'] .. " AND it.bonding = 1) OR " .. "(" ..
                          CONF['ITEMS_QUE_SE_LIGAN_AL_EQUIPAR'] .. " AND it.bonding = 2) OR " .. "(" ..
                          CONF['ITEMS_QUE_SE_LIGAN_AL_USAR'] .. " AND it.bonding = 3) OR " .. "(" ..
                          CONF['ITEMS_QUE_SE_LIGAN_MISION'] .. " AND it.bonding = 4) OR " .. "(" ..
                          CONF['ITEMS_QUE_SE_LIGAN_iCOKE'] .. " AND it.bonding = 5)) " .. "AND ((" ..
                          CONF['CONSUMIBLES'] .. " AND it.class = 0) OR " .. "(" .. CONF['BOLSAS'] ..
                          " AND it.class = 1) OR " .. "(" .. CONF['ARMAS'] .. " AND it.class = 2) OR " .. "(" ..
                          CONF['GEMAS'] .. " AND it.class = 3) OR " .. "(" .. CONF['ARMADURAS'] ..
                          " AND it.class = 4) OR " .. "(" .. CONF['MARCAS_DE_HONOR'] .. " AND it.class = 5) OR " .. "(" ..
                          CONF['PROYECTILES'] .. " AND it.class = 6) OR " .. "(" .. CONF['OBJETOS_COMERCIABLES'] ..
                          " AND it.class = 7) OR " .. "(" .. CONF['RECETAS'] .. " AND it.class = 9) OR " .. "(" ..
                          CONF['CARCAJ'] .. " AND it.class = 11) OR " .. "(" .. CONF['OBJETOS_DE_MISION'] ..
                          " AND it.class = 12) OR " .. "(" .. CONF['LLAVES'] .. " AND it.class = 13) OR " .. "(" ..
                          CONF['MISCELANEA'] .. " AND it.class = 15) OR " .. "(" .. CONF['GLIFOS'] ..
                          " AND it.class = 16)) " .. "AND ((" .. CONF['CALIDAD_GRIS'] .. " AND it.quality = 0) OR " ..
                          "(" .. CONF['CALIDAD_BLANCO'] .. " AND it.quality = 1) OR " .. "(" .. CONF['CALIDAD_VERDE'] ..
                          " AND it.quality = 2) OR " .. "(" .. CONF['CALIDAD_AZUL'] .. " AND it.quality = 3) OR " .. "(" ..
                          CONF['CALIDAD_MORADO'] .. " AND it.quality = 4) OR " .. "(" .. CONF['CALIDAD_NARANJA'] ..
                          " AND it.quality = 5) OR " .. "(" .. CONF['CALIDAD_ARTEFACTO'] .. " AND it.quality = 6) OR " ..
                          "(" .. CONF['ITEMS_QUE_SE_LIGAN_A_LA_CUENTA'] .. " AND it.quality = 7)) " ..

                          "AND NOT (it.class = 2 AND it.quality = 4 AND " .. CONF['ARMAS_EPICAS'] .. " = 0) " ..
                          "AND NOT (it.class = 4 AND it.quality = 4 AND " .. CONF['ARMADURAS_EPICAS'] .. " = 0) "

    if LISTA_NEGRA ~= "" then
        dump_data = dump_data .. "AND it.entry NOT IN (" .. LISTA_NEGRA .. ")"
    end

    return dump_data
end

local function getSecureInt(insecure_int)
    return math.max(0, math.floor(tonumber(insecure_int) or 0))
end

local function CLICK_1(e, P, U)
    if P:IsGM() then
        P:GossipMenuAddItem(4, 'Configurar Filtros', 0, 1)
        P:GossipMenuAddItem(4, '|cff00ff00Aplicar y Poblar Vendedor|r', 0, 2, false, 'Esto borrará la lista actual y creará una nueva basada en los filtros. ¿Proceder?')
        P:GossipSendMenu(1, U)
    end
end

local function CLICK_2(e, P, U, S, I, msg)

    if not P:IsGM() then
        P:GossipComplete()
        return
    end

    P:GossipClearMenu()
    
    -- Volver al menú principal
    if (S == 0) and (I == 0) then
        P:GossipComplete()
        CLICK_1(e, P, U)
        return
    end
    
    -- Menú principal de configuración
    if (S == 0) and (I == 1) then
        refreshConfigCache()
        local rate_global = getCachedGlobalRate()
        local zero_buyPrice = getCachedFlatPrice()
        
        P:GossipMenuAddItem(4, 'Rate de precios: [ |cffffffff' .. rate_global .. 'x|r ]', 500, 500, true, 'Multiplicador global:')
        P:GossipMenuAddItem(4, 'Precio base (si es 0): ' .. formatCurrency(zero_buyPrice), 500, 501, true, 'Valor en cobre:')
        
        -- Submenús por categoría
        for catIndex, cat in ipairs(FILTER_CATEGORIES) do
            P:GossipMenuAddItem(4, cat.name .. ' >>', 100, catIndex)
        end
        
        P:GossipMenuAddItem(4, '<< Volver', 0, 0)
        P:GossipSendMenu(1, U)
        return
    end
    
    -- Submenú de categoría
    if (S == 100) then
        local cat = FILTER_CATEGORIES[I]
        if cat then
            P:GossipClearMenu()
            for _, index in ipairs(cat.indices) do
                local config_name = SETTINGS[index]
                local val = getCachedConfig(index) and 'TRUE' or 'FALSE'
                local color = val == 'TRUE' and '|CFF009e00' or '|CFFFF0000'
                P:GossipMenuAddItem(4, config_name .. ' [' .. color .. val .. '|r]', index, 0)
            end
            P:GossipMenuAddItem(4, '<< Volver a Filtros', 0, 1)
            P:GossipSendMenu(1, U)
        end
        return
    end
    
    -- Toggle de configuración
    if (S >= 1) and (S <= 30) and (I == 0) then
        toggleConfig(S)

        -- Registrar en auditoría GM
        local configName = SETTINGS[S]
        local newState = getCachedConfig(S) and 'TRUE' or 'FALSE'
        insertGMLog(P:GetGUIDLow(), 'CONFIG', nil, configName, configName .. " = " .. newState)

        -- Volver al submenú correspondiente
        for catIndex, cat in ipairs(FILTER_CATEGORIES) do
            for _, index in ipairs(cat.indices) do
                if index == S then
                    CLICK_2(e, P, U, 100, catIndex, msg)
                    return
                end
            end
        end
        -- Si no encuentra, volver al menú principal
        CLICK_2(e, P, U, 0, 1, msg)
        return
    end

    -- Actualizar rate o precio base
    if (S == 500) then
        local secured_int = getSecureInt(msg)
        if (I == 500) then
            updateGlobalRate(secured_int)
            P:SendBroadcastMessage("|cff00ff00Rate global actualizado a " .. secured_int .. "x.")

            -- Registrar en auditoría GM
            insertGMLog(P:GetGUIDLow(), 'CONFIG', nil, "Rate: " .. getCachedGlobalRate() .. "x", "Rate: " .. secured_int .. "x")

        elseif (I == 501) then
            updateFlatPrice(secured_int)
            P:SendBroadcastMessage("|cff00ff00Precio base actualizado a " .. formatCurrency(secured_int) .. ".")

            -- Registrar en auditoría GM
            local oldPriceFormatted = formatCurrency(getCachedFlatPrice())
            local newPriceFormatted = formatCurrency(secured_int)
            insertGMLog(P:GetGUIDLow(), 'CONFIG', nil, oldPriceFormatted, newPriceFormatted)

        end
        P:GossipComplete()
        CLICK_1(1, P, U)
        return
    end

    -- Aplicar y poblar
    if (S == 0) and (I == 2) then
        WorldDBExecute('DELETE FROM a_itemvendor')
        WorldDBExecute(populateTable())
        P:SendBroadcastMessage('|CFF00FF00Vendedor actualizado con éxito.')

        insertGMLog(P:GetGUIDLow(), 'POPULATE', nil, nil, "Tabla a_itemvendor regenerada con filtros actuales")

        P:GossipComplete()
        return
    end
end

local function AL_RECARGAR_ELUNA(e)
    WorldDBExecute([[CREATE TABLE IF NOT EXISTS a_itemvendor_config (
        id SMALLINT UNSIGNED PRIMARY KEY AUTO_INCREMENT, 
        config_name VARCHAR(100) UNIQUE, 
        config_value INT UNSIGNED NOT NULL)
    ]])
    WorldDBExecute([[INSERT IGNORE INTO a_itemvendor_config (config_name, config_value) VALUES 
        ('ARMAS', 1), ('ARMADURAS', 1), ('ARMAS_EPICAS', 0), ('ARMADURAS_EPICAS', 0), ('ITEMS_QUE_NO_SE_LIGAN', 1),
        ('ITEMS_QUE_SE_LIGAN_AL_RECOGER', 0), ('ITEMS_QUE_SE_LIGAN_AL_EQUIPAR', 1), ('ITEMS_QUE_SE_LIGAN_AL_USAR', 1),
        ('ITEMS_QUE_SE_LIGAN_MISION', 0), ('ITEMS_QUE_SE_LIGAN_iCOKE', 0), ('CALIDAD_GRIS', 0), ('CALIDAD_BLANCO', 1),
        ('CALIDAD_VERDE', 1), ('CALIDAD_AZUL', 1), ('CALIDAD_MORADO', 1), ('CALIDAD_NARANJA', 0), ('CALIDAD_ARTEFACTO', 0),
        ('ITEMS_QUE_SE_LIGAN_A_LA_CUENTA', 0), ('CONSUMIBLES', 1), ('BOLSAS', 1), ('GEMAS', 1), ('PROYECTILES', 1),
        ('RECETAS', 1), ('MARCAS_DE_HONOR', 0), ('CARCAJ', 1), ('OBJETOS_DE_MISION', 0), ('LLAVES', 0), ('OBJETOS_COMERCIABLES', 1),
        ('MISCELANEA', 0), ('GLIFOS', 1)
    ]])

    -- Inicializar caché
    refreshConfigCache()
end

RegisterCreatureGossipEvent(NPC_ID, 1, CLICK_1)
RegisterCreatureGossipEvent(NPC_ID, 2, CLICK_2)
RegisterServerEvent(33, AL_RECARGAR_ELUNA)

--[[

-- Ver últimas 50 acciones de GMs
SELECT 
    l.id,
    c.name AS gm_name,
    l.action,
    l.item_id,
    COALESCE(it.name, 'N/A') AS item_name,
    l.old_value,
    l.new_value,
    l.timestamp
FROM a_itemvendor_gm_log l
LEFT JOIN characters c ON l.gm_id = c.guid
LEFT JOIN item_template it ON l.item_id = it.entry
ORDER BY l.timestamp DESC
LIMIT 50;

]]
