local ALLOWED_CHARACTER = 1 -- GUID del jugador que podrá configurar el NPC

local iconOro = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local iconPlata = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local iconCobre = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
local colorBlanco = "|CFFFFFFFF"
local finColor = "|r"

local function formatCurrency(copper)
    local oro = math.floor(copper / 10000)
    local plata = math.floor((copper % 10000) / 100)
    local cobre = copper % 100

    local function formatWithComma(n)
        local rev = tostring(n):reverse()
        local withCommas = rev:gsub("(%d%d%d)", "%1,")
        if withCommas:sub(-1) == "," then
            withCommas = withCommas:sub(1, -2)
        end
        return withCommas:reverse()
    end

    local partes = {}

    if oro > 0 then
        table.insert(partes, string.format("%s%s%s%s", colorBlanco, formatWithComma(oro), finColor, iconOro))
    end
    if plata > 0 or (cobre > 0 and oro > 0) then
        table.insert(partes, string.format("%s%d%s%s", colorBlanco, plata, finColor, iconPlata))
    end
    if cobre > 0 or (oro == 0 and plata == 0) then
        table.insert(partes, string.format("%s%d%s%s", colorBlanco, cobre, finColor, iconCobre))
    end
    return table.concat(partes, " ")
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

-- Agregar más objetos si se quiere
local LISTA_NEGRA = "33350,37410,24477,24476,33470,21877,28430,40553,41257,41383,41384,44926,44948,30732,30724,31318,34622,39302,"
    .. "31342,31322,31336,31334,31332,31331,31323,20698,45173,45174,45175,38497,38496,38498,27965,34025,34030,37126,28388,28389,17882,"
    .. "17887,22023,22024,22584,29841,29868,29871,14891,21442,26173,26174,26175,26180,26235,26324,26368,26372,26464,26465,26548,26655,26738,"
    .. "26792,26843,27196,27218,37301,38292,39163,138,931,2275,2588,2599,3884,3934,5632,40754,40948,43336,43337,43384,31266,27774,27811,"
    .. "28117,28122,41403,41404,41405,41406,41407,41408,41409,41410,41411,41412,41413,41414,41415,41416,41417,41418,41419,41420,41421,41422,"
    .. "41423,43362,45908,21038,32722,33226,34062,34599,38294,38518,42986,43523,46783,54822,52252,996,1020,1021,1024,1025,1027,1162,5235,"
    .. "19642,22822,49191,48509,48442,50319,45605,40408,42254,39427,42241,42247,42345,43613,44310,37856,37697,37649,42215,42216,42217,42343,"
    .. "45172,37739,29828,37611,36477,36673,38247,32053,32046,32044,28297,28310,28312,37597,32659,28929,28930,28931,28957,28955,28954,31492,"
    .. "26779,32190,32179,32178,32914,22802,22804,23044,22803,23458,17142,24071,20720,10049, 3222,2664,23422,2502, 2484,24100,12991,19924,"
    .. "32841,5283,2184,48515,48444,42269,42264,42259,42220,42218,42219,36561,38243,32028,32003,53890,53889,28313,28314,38469,28947,28922,28928,"
    .. "28953,32188,32189,23242,11743,20005,28905,5600,48440,48507,42238,42231,42226,42207,42236,42206,42212,42213,42214,45575,36575,31985,31965,"
    .. "28308,28309,28946,28920,32175,32174,22816,45630,17068,33080,3895,5255,4965,2498,2482,20979,37,49689,29712,29419,12348,1259"


local function GetConfigSetting(P, id)
    local Q = WorldDBQuery("SELECT config_value FROM a_itemvendor_config WHERE id = " .. id)
    local result_int = Q:GetUInt32(0)
    return (result_int == 1) and 'TRUE' or 'FALSE'
end

local function updateOneById(id)
    WorldDBQuery("UPDATE a_itemvendor_config SET config_value = 1 - config_value WHERE id = " .. id)
end

local function getTableFromDB()
    local Q = WorldDBQuery('SELECT * FROM a_itemvendor_config')
    local conf_table = {}
    if Q then
        repeat
            local value
            value = Q:GetUInt32(2) == 1 and 'TRUE' or 'FALSE';
            table.insert(conf_table, value)
        until not Q:NextRow();
    end
    return conf_table
end

local function ESTABLECER_PRECIO_GLOBAL(integer)
    WorldDBQuery('UPDATE a_itemvendor_global_rate SET rate = ' .. integer)
end

local function ESTABLECER_PRECIO_DE_COMPRA_DEFAULT(integer)
    WorldDBQuery('UPDATE a_itemvendor_fixed_amount SET amount = ' .. integer)
end

local function populateTable()
    local config_table = getTableFromDB()

    local CONF = {
        ['ARMAS']                          = config_table[1],
        ['ARMADURAS']                      = config_table[2],
        ['ARMAS_EPICAS']                   = config_table[3],
        ['ARMADURAS_EPICAS']               = config_table[4],
        ['ITEMS_QUE_NO_SE_LIGAN']          = config_table[5],
        ['ITEMS_QUE_SE_LIGAN_AL_RECOGER']  = config_table[6],
        ['ITEMS_QUE_SE_LIGAN_AL_EQUIPAR']  = config_table[7],
        ['ITEMS_QUE_SE_LIGAN_AL_USAR']     = config_table[8],
        ['ITEMS_QUE_SE_LIGAN_MISION']      = config_table[9],
        ['ITEMS_QUE_SE_LIGAN_iCOKE']       = config_table[10],
        ['CALIDAD_GRIS']                   = config_table[11],
        ['CALIDAD_BLANCO']                 = config_table[12],
        ['CALIDAD_VERDE']                  = config_table[13],
        ['CALIDAD_AZUL']                   = config_table[14],
        ['CALIDAD_MORADO']                 = config_table[15],
        ['CALIDAD_NARANJA']                = config_table[16],
        ['CALIDAD_ARTEFACTO']              = config_table[17],
        ['ITEMS_QUE_SE_LIGAN_A_LA_CUENTA'] = config_table[18],
        ['CONSUMIBLES']                    = config_table[19],
        ['BOLSAS']                         = config_table[20],
        ['GEMAS']                          = config_table[21],
        ['PROYECTILES']                    = config_table[22],
        ['RECETAS']                        = config_table[23],
        ['MARCAS_DE_HONOR']                = config_table[24],
        ['CARCAJ']                         = config_table[25],
        ['OBJETOS_DE_MISION']              = config_table[26],
        ['LLAVES']                         = config_table[27],
        ['OBJETOS_COMERCIABLES']           = config_table[28],
        ['MISCELANEA']                     = config_table[29],
        ['GLIFOS']                         = config_table[30]
    }

    local dump_data = "INSERT INTO a_itemvendor (entry, `name`, buyPrice, maxCount) SELECT it.entry, itl.Name, "
        .. "it.buyPrice, it.maxcount FROM item_template it "
        .. "JOIN item_template_locale itl ON it.entry = itl.ID "
        .. "AND itl.locale = 'esMX' " ..

        -- Condiciones por binding
        "AND (" ..
        "(it.bonding = 0 AND " .. CONF['ITEMS_QUE_NO_SE_LIGAN'] .. ") OR " ..
        "(it.bonding = 1 AND " .. CONF['ITEMS_QUE_SE_LIGAN_AL_RECOGER'] .. ") OR " ..
        "(it.bonding = 2 AND " .. CONF['ITEMS_QUE_SE_LIGAN_AL_EQUIPAR'] .. ") OR " ..
        "(it.bonding = 3 AND " .. CONF['ITEMS_QUE_SE_LIGAN_AL_USAR'] .. ") OR " ..
        "(it.bonding = 4 AND " .. CONF['ITEMS_QUE_SE_LIGAN_MISION'] .. ") OR " ..
        "(it.bonding = 5 AND " .. CONF['ITEMS_QUE_SE_LIGAN_iCOKE'] .. ")) " ..

        -- Condiciones por clase, algunas hardcoded
        "AND (" ..
        "(it.class = 0 AND " .. CONF['CONSUMIBLES'] .. ") OR " ..
        "(it.class = 1 AND " .. CONF['BOLSAS'] .. ") OR " ..
        "(it.class = 2 AND " .. CONF['ARMAS'] .. ") OR " ..
        "(it.class = 3 AND " .. CONF['GEMAS'] .. ") OR " ..
        "(it.class = 4 AND " .. CONF['ARMADURAS'] .. ") OR " ..
        "(it.class = 5 AND " .. CONF['MARCAS_DE_HONOR'] .. ") OR " ..
        "(it.class = 6 AND " .. CONF['PROYECTILES'] .. ") OR " ..
        "(it.class = 7 AND " .. CONF['OBJETOS_COMERCIABLES'] .. ") OR " ..
        "(it.class = 8 AND FALSE) OR " ..
        "(it.class = 9 AND " .. CONF['RECETAS'] .. ") OR " ..
        "(it.class = 10 AND FALSE) OR " ..
        "(it.class = 11 AND " .. CONF['CARCAJ'] .. ") OR " ..
        "(it.class = 12 AND " .. CONF['OBJETOS_DE_MISION'] .. ") OR " ..
        "(it.class = 13 AND " .. CONF['LLAVES'] .. ") OR " ..
        "(it.class = 14 AND FALSE) OR " ..
        "(it.class = 15 AND " .. CONF['MISCELANEA'] .. ") OR " ..
        "(it.class = 16 AND " .. CONF['GLIFOS'] .. ")) " ..

        -- Condiciones por calidad
        "AND (" ..
        "(it.quality = 0 AND " .. CONF['CALIDAD_GRIS'] .. ") OR " ..
        "(it.quality = 1 AND " .. CONF['CALIDAD_BLANCO'] .. ") OR " ..
        "(it.quality = 2 AND " .. CONF['CALIDAD_VERDE'] .. ") OR " ..
        "(it.quality = 3 AND " .. CONF['CALIDAD_AZUL'] .. ") OR " ..
        "(it.quality = 4 AND " .. CONF['CALIDAD_MORADO'] .. ") OR " ..
        "(it.quality = 5 AND " .. CONF['CALIDAD_NARANJA'] .. ") OR " ..
        "(it.quality = 6 AND " .. CONF['CALIDAD_ARTEFACTO'] .. ") OR " ..
        "(it.quality = 7 AND " .. CONF['ITEMS_QUE_SE_LIGAN_A_LA_CUENTA'] .. ")) " ..

        -- Excepciones por armas y armaduras épicas
        "AND NOT (it.class = 2 AND it.quality = 4 AND NOT " .. CONF['ARMAS_EPICAS'] .. ") " ..
        "AND NOT (it.class = 4 AND it.quality = 4 AND NOT " .. CONF['ARMADURAS_EPICAS'] .. ") " ..

        -- Exclusión de la lista negra
        "AND it.entry NOT IN (" .. LISTA_NEGRA .. ")"

    return dump_data --> Retorna String
end

local function getSecureInt(insecure_int)
    local result = math.max(0, math.floor(tonumber(insecure_int) or 0))
    return result
end


local function CLICK_1(e, P, U)

    local fixed_amount_exists = WorldDBQuery("SELECT 1 FROM a_itemvendor_fixed_amount LIMIT 1")

    if not fixed_amount_exists then
        WorldDBExecute("INSERT INTO a_itemvendor_fixed_amount VALUES ()")
        WorldDBExecute("INSERT INTO a_itemvendor_global_rate VALUES ()")
    end

    if (P:GetGUIDLow() == ALLOWED_CHARACTER) then
        P:GossipMenuAddItem(4, 'Configurar', 0, 1)
        P:GossipMenuAddItem(4, 'Aplicar configuración', 0, 2, false, '¿Seguro quieres aplicar la configuración?')
        P:GossipSendMenu(1, U)
    end
end

local function CLICK_2(e, P, U, S, I, msg)

    if (P:GetGUIDLow() == ALLOWED_CHARACTER) then

        local raw_sql = WorldDBQuery('SELECT rate FROM a_itemvendor_global_rate LIMIT 1')
        local raw_sql2 = WorldDBQuery('SELECT amount FROM a_itemvendor_fixed_amount LIMIT 1')
        local rate_global, zero_buyPrice 

        rate_global     = raw_sql:GetUInt8(0)
        zero_buyPrice   = raw_sql2:GetUInt32(0)

        -- Mostrar menú
        if (S == 0) and (I == 1) then
            P:GossipMenuAddItem(4, 'Rate de precios: [ |cffffffff'..rate_global..'x|r ]', 500, 500, true, 'Escribe el coeficiente multiplicador de precios global.')
            P:GossipMenuAddItem(4, 'Valor precio de compra cero: '..formatCurrency(zero_buyPrice)..'', 500, 501, true, 'Ingresa el valor que se asignará como precio de compra (en cobre) de los objetos cuyo precio de compra original es cero.\n\n1 oro = 10,000 cobre.')
 
            for index, config_name in ipairs(SETTINGS) do
                local true_or_false = GetConfigSetting(P, index)
                local color = true_or_false == 'TRUE' and '|CFF009e00' or '|CFFFF0000'
                P:GossipMenuAddItem(4, config_name .. ' [' .. color .. true_or_false .. '|r]', index, 0)
                -- P:SendBroadcastMessage(true_or_false)
            end
            P:GossipSendMenu(1, U)
        end

        if (S == 500) then 
            local secured_int = getSecureInt(msg)

            if secured_int > 0 then
                if (I == 500) then -- Multiplicador de precios global
                    
                    -- Evitar que se coloquen decimales como coeficiente global
                    local not_zero = (secured_int < 1) and 1 or math.floor(secured_int)
                
                    ESTABLECER_PRECIO_GLOBAL(not_zero)
                    P:SendBroadcastMessage('Rate de precios global estabecido a: ' .. not_zero)

                elseif (I == 501) then -- Valor de precio de compra cero
                    
                    -- Limitar el valor mínimo de compra a 50 plata
                    local at_least_5000 = (secured_int < 5000) and 5000 or secured_int
                
                    ESTABLECER_PRECIO_DE_COMPRA_DEFAULT(at_least_5000)
                    P:SendBroadcastMessage('Valor de precio de compra cero: ' .. at_least_5000)
                end 
            else
                P:SendBroadcastMessage('Ingresa un número entero positivo.')
            end
            CLICK_1(1, P, U)
        end

        -- Actualizar el valor de un setting
        if (S >= 1) and (I == 0) then
            updateOneById(S)
            P:GossipClearMenu()
            CLICK_2(2, P, U, 0, 1)
        end

        -- Aplicar configuración
        if (S == 0) and (I == 2) then

            WorldDBQueryAsync('DELETE FROM a_itemvendor', function(deleteResult)
                WorldDBQueryAsync(populateTable(), function(insertResult)
                end)
 
            end)

            P:SendBroadcastMessage('|CFF00FF00Correcto. La oferta de items ha sido actualizada.')
            P:GossipComplete()
        end
    end
end


local function AL_RECARGAR_ELUNA(e)

    local create_query = [[CREATE TABLE IF NOT EXISTS a_itemvendor_config (
        id SMALLINT UNSIGNED PRIMARY KEY AUTO_INCREMENT, 
        config_name VARCHAR(100) UNIQUE, 
        config_value INT UNSIGNED NOT NULL)]]
    
    local initial_insert = [[INSERT IGNORE INTO a_itemvendor_config (config_name, config_value) VALUES ('ARMAS', 0), ('ARMADURAS', 0), ('ARMAS_EPICAS', 0),
    ('ARMADURAS_EPICAS', 0), ('ITEMS_QUE_NO_SE_LIGAN', 0), ('ITEMS_QUE_SE_LIGAN_AL_RECOGER', 0), ('ITEMS_QUE_SE_LIGAN_AL_EQUIPAR', 0),
    ('ITEMS_QUE_SE_LIGAN_AL_USAR', 0), ('ITEMS_QUE_SE_LIGAN_MISION', 0), ('ITEMS_QUE_SE_LIGAN_iCOKE', 0), ('CALIDAD_GRIS', 0), ('CALIDAD_BLANCO', 0),
    ('CALIDAD_VERDE', 0), ('CALIDAD_AZUL', 0), ('CALIDAD_MORADO', 0), ('CALIDAD_NARANJA', 0), ('CALIDAD_ARTEFACTO', 0), ('ITEMS_QUE_SE_LIGAN_A_LA_CUENTA', 0),
    ('CONSUMIBLES', 0), ('BOLSAS', 0), ('GEMAS', 0), ('PROYECTILES', 0), ('RECETAS', 0), ('MARCAS_DE_HONOR', 0), ('CARCAJ', 0), ('OBJETOS_DE_MISION', 0),
    ('LLAVES', 0), ('OBJETOS_COMERCIABLES', 0), ('MISCELANEA', 0), ('GLIFOS', 0)]]

    WorldDBQueryAsync(create_query, function (createResult)
        WorldDBExecute(initial_insert)  
    end)

end

RegisterCreatureGossipEvent(60001, 1, CLICK_1)
RegisterCreatureGossipEvent(60001, 2, CLICK_2)
RegisterServerEvent(33, AL_RECARGAR_ELUNA)
