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

-- Parámetros de configuración --
local NPC_ID = 60000
local MAX_RESULTS = 28
local FLAT_PRICE
local M = {} -- Cache global
local col = '|cff00ffb3' -- Color temático
local config = {
    tables = {
        fixed_amount    = 'a_itemvendor_fixed_amount',    --> Tabla para monto fijo de objetos que no tienen precio de compra (buyPrice)
        global_rate     = 'a_itemvendor_global_rate',     --> Tabla para el multiplicador global de los precios
        blacklist       = 'a_itemvendor_blacklist',       --> Tabla para albergar la lista negra de objetos
        item_vendor     = 'a_itemvendor',                 --> Tabla que alberga los objetos disponibles
        player_log      = 'a_itemvendor_log',             --> Tabla de registro (log)
        frecuent        = 'a_itemvendor_frequent',        --> Tabla de compras frecuentes
        gm_log          = 'a_itemvendor_gm_log',          --> Tabla de registro de GM
    }
}


-- Auto Instalación
local function INSTALL_SYSTEM()

    local CREATES = { 
        string.format([[CREATE TABLE IF NOT EXISTS %s (
            id TINYINT UNSIGNED NOT NULL DEFAULT 1,
            amount INT UNSIGNED NOT NULL DEFAULT 10000,
            PRIMARY KEY (id))]], config.tables.fixed_amount),

        string.format([[CREATE TABLE IF NOT EXISTS %s (
            id TINYINT UNSIGNED NOT NULL DEFAULT 1,
            rate TINYINT UNSIGNED NOT NULL DEFAULT 1,
            PRIMARY KEY (id))]], config.tables.global_rate),

        string.format([[CREATE TABLE IF NOT EXISTS %s (
            id INT UNSIGNED NOT NULL, 
            PRIMARY KEY (id))]], config.tables.blacklist),

        string.format([[CREATE TABLE IF NOT EXISTS %s (
            entry INT UNSIGNED NOT NULL PRIMARY KEY,
            `name` VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
            buyPrice INT UNSIGNED NOT NULL,
            maxCount INT UNSIGNED NOT NULL,
            stackable INT UNSIGNED NOT NULL DEFAULT 1,
            state TINYINT NOT NULL DEFAULT 1)]], config.tables.item_vendor),

        string.format([[CREATE TABLE IF NOT EXISTS %s (
            id INT AUTO_INCREMENT PRIMARY KEY, 
            player_id INT UNSIGNED NOT NULL,
            item_id MEDIUMINT UNSIGNED NOT NULL, 
            amount MEDIUMINT UNSIGNED NOT NULL, 
            expense INT UNSIGNED NOT NULL, 
            purchase_time TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            state TINYINT UNSIGNED NOT NULL DEFAULT 1,
            INDEX idx_player_state_time (player_id, state, purchase_time DESC), 
            INDEX idx_item_id (item_id), INDEX idx_state_time (state, purchase_time))]], config.tables.player_log),

        string.format([[CREATE TABLE IF NOT EXISTS %s (
            entry INT UNSIGNED NOT NULL,
            buyPrice INT UNSIGNED NOT NULL,
            maxCount TINYINT UNSIGNED NOT NULL,
            times INT UNSIGNED NOT NULL DEFAULT 1,
            player_id INT UNSIGNED NOT NULL,
            UNIQUE KEY uniq_entry_player (entry, player_id))]], config.tables.frecuent),

        string.format([[CREATE TABLE IF NOT EXISTS %s (
            id INT AUTO_INCREMENT PRIMARY KEY,
            gm_id INT UNSIGNED NOT NULL,
            action ENUM('ADD', 'EDIT', 'DELETE', 'CONFIG', 'POPULATE') NOT NULL,
            item_id INT UNSIGNED NULL,
            old_value TEXT NULL,
            new_value TEXT NULL,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]], config.tables.gm_log)
    }

    local INSERTS = {
        string.format("INSERT IGNORE INTO %s (id, rate) VALUES (1, 1)", config.tables.global_rate),
        string.format("INSERT IGNORE INTO %s (id, amount) VALUES (1, 10000)", config.tables.fixed_amount)
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
    local blacklistIDs = {24477,24476,33470,21877,28430,40553,41383,41384,44926,44948,30732,30724,31318,34622,31342,31322,31336,
    31334,31332,31331,31323,20698,45173,45172,45174,45175,38497,38496,38498,27965,34025,34030,37126,28388,28389,17882,17887,22023,
    22024,22584,29841,29868,29871,14891,1442,26173,26174,26175,26180,26235,26324,26368,26372,26464,26465,26548,26655,26738,26792,
    26843,27196,27218,37301,38292,39163,45575,138,931,2275,2588,2599,3884,3934,5632,40754,40948,43336,43337,43384,31266,27774,
    27811,28117,28122,41403,41404,41405,41406,41407,41408,41409,41410,41411,41412,41413,41414,41415,41416,41417,41418,41419,
    41420,41421,41422,41423,43362,45908,21038,32722,33226,34062,34599,38294,38518,42986,43523,46783,54822,52252,996,1020,
    1021,1024,1025,1027,1162,5235,17,12443,746,788,905,906,907,908,909,951,1018,1022,1023,1026,1163,1165,1281,2103,
    3145,3507,3865,4842,4853,5041,5091,5378,5688,5953,5954,6213,6255,7171,7248,8164,10555,12187,12188,12189,12244,12245,
    12385,12526,12961,12962,12971,13586,13710,12972,13711,13712,13713,13714,13715,13716,13717,14883,14884,14885,14886,14887,
    14888,14889,14890,14892,16061,16062,16063,16064,16065,16066,16086,16102,16103,16105,16106,16107,16108,16116,16117,16118,
    16119,16120,16121,16122,16123,16124,16125,16126,16127,16129,16131,16132,16134,16135,16136,16137,16138,16139,16140,16141,
    16142,16143,16144,16145,16146,16147,16148,16149,16150,16151,16152,16153,16154,16155,16156,16157,16158,16159,16160,16161,
    16162,16163,16164,16165,16172,16211,16212,16213,17162,17163,17342,17343,18105,18106,18161,18162,18163,18164,18165,
    18763,18764,18765,19184,19185,19186,19187,19188,19189,19190,19191,19192,19193,19194,19195,19196,19197,19198,19199,
    19200,19201,19313,19314,19427,19428,19455,19456,19457,19502,19503,19504,19622,19662,19742,19743,19809,19810,19811,20370,
    20372,21419,21420,21421,21422,21423,21424,21425,21426,21427,21428,21429,21430,21431,21432,21433,21434,21435,21437,21439,
    21440,21441,21442,21443,21444,21445,21446,21447,21448,21449,21450,21451,21782,21857,22316,23418,23656,26128,26129,26130,
    26131,26132,26133,26134,26135,26513,26527,26541,26569,26765,26779,29885,32594,34467,40232,77,86,87,94,95,98,99,101,102,
    103,105,114,115,119,123,125,126,130,131,132,133,134,136,149,151,155,157,184,741,761,784,786,806,807,808,836,855,930,941,
    964,1046,1047,1099,1128,1170,1174,1253,1267,1268,1269,1321,1323,1335,1354,1403,1492,1533,1599,1612,1622,1638,1649,1654,
    1655,1689,1693,1694,1695,1704,1719,1724,1878,1880,1918,1950,1963,1995,2002,2003,2071,2104,2115,2322,2323,2363,2404,2405,
    2461,2462,2478,2513,2517,2518,2554,2600,2602,2789,2790,2791,2792,2804,3001,3032,3068,3147,3149,3271,3333,3436,3441,3768,
    3773,3883,3885,3886,3887,3888,3933,4156,4163,4193,4222,4224,4227,4229,4418,4427,4501,4657,4664,4667,4670,4673,4902,4934,
    4955,4997,5090,5144,5146,5157,5159,5161,5162,5228,5407,5607,11443,14363,14597,14609,14691,14696,15888,15889,23364,23366,
    41,42,46,50,54,58,89,90,92,93,122,137,141,146,152,4295,8815,8829,8854,8866,8888,17412,17889,17890,21878,22026,22027,
    23245,23700,23699,23698,23696,23567,23701,1977,20351,20352,20355,20311,20314,20280,20285,20324,20325,20328,20267,
    20269,20149,20146,20338,20339,20342,20297,20300,20238,20245,1084,1085,1086,1087,1088,1089,1090,1091,1092,1093,
    1095,1096,1100,1101,1102,1105,1108,1109,1111,1112,1641,1648,1651,1657,1658,1676,3113,3114,3115,3116,3118,3119,3120,3121,
    3123,3124,4266,4267,4268,4269,4270,4271,4272,4273,4274,4275,4276,4277,4279,4280,4281,4282,4283,4284,4285,4286,4287,4288,
    8954,8955,8958,8960,8961,8962,8963,8964,8965,8966,8967,8968,8969,8971,8972,8974,8975,8976,8977,8978,8980,8981,8983,8986,
    8987,8988,8989,8990,8991,8992,8994,8995,8996,8997,8998,8999,9000,9001,9002,9003,9004,9005,9006,9007,9008,9009,9010,9011,
    9012,9013,9014,9015,9016,9017,9018,9019,9020,9021,9022,9023,9024,9025,9026,9027,9028,9029,9031,9032,9033,9034,9035,
    16085, 4882,3541,3545,3537,886,3522,3526,3529,5495,3861,18154,18023,23234,4223,8760,1332,1339,5147,4225,8900,8773,8795,
    1328,8764,8779,8790,8745,5145,5150,5152,8783,5160,4230,8774,8901,8794,8743,5155,5163,5153,8902,8776,8799,1341,1886,1882,
    4228,8777,8763,8770,8903,8904,8796,5141,8756,8759,8765,8800,8772,8905,8781,8791,5730,1334,1877,3088,8785,8762,8771,8778,
    8906,8797,8758,8787,8788,8789,8757,8761,8768,8907,8780,8798,5139,5148,5154,8769,8782,8792,5158,8775,8786,8801,8744,5142,
    5149,5151,5156,4226,8784,8793,1402,41753,41750,7426,7427,1851,13303,20952,20962,20953,20819,20829,20825,20822,21194,
    21193,21195,21313,11099,4033,9311,3031,2514,3029,13330,35538,23578,6182,14384,14394,14383,14382,14385,14387,14386,
    14388,14393,14389,14391,34645,13305,9888,5005,5223,5227,5406,6374,11199,11200,11201,35626,36900,4190,4195,4194,5013,13304,
    997,43560,18002,6376,6222,6345,8547,13307,1216,33350,15071,15070,15069,15068,36915,43563,1072,6244,3034,5916,20337,10723,
    23832,10580,5937,23831,3571,3542,3546,3538,21762,2021,1224,1228,1229,1231,1232,1238,1239,1243,1244,1245,1246,1250,1681,
    3134,3138,3139,3140,3141,3142,3143,3144,3146,4198,4199,4201,4202,4203,4204,4205,4206,4207,4208,4209,4210,4211,4212,4214,
    4215,4216,4217,4218,4219,4220,4221,5719,5720,5721,5722,5723,5724,5725,5726,5727,5728,5729,9190,9191,9192,9193,9194,9195,
    9198,9199,9200,9201,9202,9203,9204,9205,9207,9208,9209,9211,9212,9215,9216,9217,9218,9219,9221,9222,9223,9225,9226,9227,
    9228,9229,9230,9231,10460,4031,5229,37706,24269,3006,4030,43002,43561,7497,12866,17262,16026,17242,13306,5130,5129,5126,
    5127,5131,5132,1136,1138,1139,1141,1149,1150,1151,1534,1536,4164,4165,4166,4167,5658,5660,5661,5662,5666,5667,5670,
    5671,5672,5673,5674,5676,5677,5678,5679,5680,5682,5683,5684,5685,6132,6133,8909,8910,8911,8912,8913,8914,8915,8916,8917,
    8918,8919,8920,8921,8922,8929,8930,8931,8933,8934,8935,8936,8937,8938,8939,8940,8941,8942,8943,8944,8945,8947,5046,43559,
    3028,12440,5004,13302,10719,40768,19082,22596,30458,6216,948,3227,43558,43562,34835,7547,20834,7548,12817,12831,12832,35529,
    7192,35553,6734,6736,7977,5577,12826,35531,12816,5823,8546,6207,6208,6209,6210,16027,16028,16029,16030,16031,16033,16034,
    16035,16036,16037,16038,16104,17827,17828,17829,17830,17883,17884,17885,17888,17891,17892,17893,17894,17895,17896,17897,
    17898,17899,18599,18666,18667,18668,18669,22020,22021,22022,22025,22028,22029,22030,22031,22032,22033,22034,22035,22036,
    22037,22038,22039,22040,22041,22042,22043,22585,22586,22587,22588,23725,23727,23728,29839,29840,29842,29852,29856,29857,
    29860,29861,29863,29872,29874,30193,30197,31843,31845,31849,33315,25582,25627,4032,1623,33063,23233,5641,2556,13500,6891,
    5657,3533,3535,3528,17967,3002,2923,2919,3004,3003,3791,3005,3789,23840,8840,34647,1164,20423,21761,18235,8243,38996,38970,
    38957,11115,5049,945,45280,42170,37100,34663,20956,5045,5047,2410,1996,3788,23855,12211,2922,27002,27007,2688,44832,2693,
    20583,20584,20585,20586,20587,20588,20589,20590,20591,20592,20593,20594,20595,20596,20597,20598,1400,1029,1030,1031,1032,1033,
    1034,1035,1036,1037,1038,1048,1049,1052,1053,1057,1058,1061,1063,1588,1589,1591,1597,1603,1619,3125,3126,3127,3129,3130,3132,
    3133,4168,4169,4170,4171,4172,4173,4174,4175,4176,4177,4178,4179,4180,4181,4182,4183,4184,4185,4186,4187,4188,4189,5696,5697,
    5698,5699,5700,5701,5702,5703,5704,5705,5706,5707,5708,5709,5710,5711,5712,5713,5714,5715,5716,9037,9039,9040,9041,9043,9044,
    9046,9047,9048,9049,9050,9051,9052,9053,9054,9055,9056,9057,9058,9059,9062,9063,9064,9065,9066,9067,9068,9069,9070,9071,9072,
    9073,9074,9075,9076,9077,9078,9079,9080,9081,9082,9083,9084,9085,9086,9087,9089,9090,9091,9092,9093,9094,9095,9096,9097,9098,
    9099,9100,9101,9102,9103,9104,9105,9123,9124,9125,9126,9127,9128,9129,9130,9131,9132,9133,9134,9135,9136,9137,9138,9139,9140,
    9141,9142,9143,9145,9146,9147,9148,9150,9151,9152,9156,9157,9158,9159,9160,9161,9162,9164,9165,9166,9167,9168,9169,9170,9171,
    9174,9175,9176,9177,9178,9180,9181,9182,9183,9184,9185,9188,38270,966,967,968,973,974,975,976,980,985,986,989,992,994,1002,
    1004,1554,1559,1567,1568,1571,1574,3089,3090,3091,3092,3093,3094,3095,3096,3097,3098,3099,3100,3101,3102,4141,4142,4143,4144,
    4145,4146,4147,4148,4149,4150,4151,4152,4153,4154,4155,4157,4158,4159,4160,4161,4162,5644,5647,5648,5649,5650,8802,8803,8804,
    8805,8806,8807,8808,8809,8810,8811,8812,8813,8814,8816,8818,8819,8820,8821,8822,8823,8824,8825,8826,8828,8830,8832,8833,8834,
    8835,8837,8841,8842,8843,8844,8847,8848,8849,8850,8851,8852,8853,8855,8856,8857,8858,8859,8860,8861,8862,8863,8864,8865,8867,
    8868,8869,8870,8871,8872,8873,8874,8875,8876,8877,8878,8879,8880,8881,8882,8883,8884,8885,8886,8887,8889,8890,8891,8892,8893,
    8894,8895,8896,8897,8898,8899,38643,2929,6130,4728,12763,8543,6183,3543,3539,3524,3525,3523,4192,3544,3540,3534,3532,3557,
    3549,3548,5008,7550,5265,6837,8493,3547,3527,5015,5014,23235}

    --print('Total de indices: ' .. #blacklistIDs)
    
    for i = 1, #blacklistIDs, 40 do
        local batch = {}
        for j = i, math.min(i + 39, #blacklistIDs) do
            table.insert(batch, "(" .. blacklistIDs[j] .. ")")
        end
        WorldDBExecute("INSERT IGNORE INTO ".. config.tables.blacklist .." (id) VALUES " .. table.concat(batch, ","))
    end

end
INSTALL_SYSTEM()


-- Helper para limpiar la entrada string
local function CLEAN_INPUT(input)
    if type(input) ~= "string" then
        return ""
    end
    local cleaned = input:match("^%s*(.-)%s*$")
    cleaned = cleaned:gsub("%s+", " ")
    cleaned = cleaned:gsub("[^a-zA-Z0-9 áéíóúñÁÉÍÓÚÑ.]", "")
    cleaned = cleaned:gsub("%s+", " ")
    cleaned = cleaned:match("^%s*(.-)%s*$")
    return cleaned
end


-- Helper para limpiar la entrada numérica
local function TO_POSITIVE_INTEGER(input)
    local floored_positive_int = math.max(0, math.floor(tonumber(input) or 0))
    return (floored_positive_int > 200) and 200 or floored_positive_int
end


-- Helper para limpiar ID de objeto (entero positivo, máximo mediumint unsigned)
local function TO_ITEM_ID(input)
    if type(input) == "string" then
        input = input:gsub("[,.]", "") -- quita comas y puntos
    end
    local id = math.floor(tonumber(input) or 0)
    if id < 0 then id = 0 end
    if id > 16777215 then id = 16777215 end
    return id
end


-- Helper para transcribir de CURRENT TIMESTAMP desde la DB a fecha legible en la UI
local function FORMAT_TIMESTAMP(timestamp)
    local months = {'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'}
    local days = {'Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'}
    local year = tonumber(timestamp:sub(1, 4))
    local month = tonumber(timestamp:sub(6, 7))
    local day = tonumber(timestamp:sub(9, 10))
    local hour = tonumber(timestamp:sub(12, 13))
    local minute = timestamp:sub(15, 16)

    -- Validación de fecha: os.time devuelve nil si la fecha no es válida (ej. 29 de febrero en año no bisiesto)
    local time = os.time({ year = year, month = month, day = day })
    local dayName = time and days[tonumber(os.date("%w", time)) + 1] or "?"

    local period = hour >= 12 and "pm" or "am"
    local hour12 = hour % 12
    if hour12 == 0 then hour12 = 12 end

    if dayName ~= "?" then
        return string.format("%s %d de %s de %d - %d:%s %s", dayName, day, months[month], year, hour12, minute, period)
    else
        -- Fallback: devuelve la fecha sin día de la semana para evitar mostrar "?" pero conserva legibilidad
        return string.format("%d de %s de %d - %d:%s %s", day, months[month], year, hour12, minute, period)
    end
end


-- Namespace
local function Query()
    return {
        INSERT_INTO_LOG = function(player_id, item_id, amount, expense)
            WorldDBExecute(string.format("INSERT INTO %s (player_id, item_id, amount, expense, `state`) VALUES (%d, %d, %d, %d, 1)", config.tables.player_log, player_id, item_id, amount, expense))
        end,
        
        INSERT_OR_UPDATE_FREQUENT_PURCHASE = function(entry, buyPrice, maxCount, player_id)
            WorldDBExecute(string.format(
                "INSERT INTO %s (entry, buyPrice, maxCount, times, player_id) VALUES (%d, %d, %d, 1, %d) ON DUPLICATE KEY UPDATE times = times + 1", config.tables.frecuent,
                entry, buyPrice, maxCount, player_id))
        end,

        GET_ITEM_BY_NAME_OR_PART = function(name_or_part)
            local sql = WorldDBQuery( -- name_or_part ya viene pre-sanitizado
                string.format("SELECT entry, buyPrice, maxCount, stackable FROM %s WHERE `name` LIKE '%%%s%%' AND state = 1 LIMIT %d", 
                config.tables.item_vendor, name_or_part, (MAX_RESULTS > 30 and 30 or MAX_RESULTS)))
            if sql then
                local res = {}
                repeat
                    table.insert(res, {sql:GetUInt32(0), sql:GetUInt32(1), sql:GetUInt32(2), sql:GetUInt32(3)})
                until not sql:NextRow()
                return res
            else
                return nil
            end 
        end,

        GET_ITEM_BY_ID = function(entry)
            local sql = WorldDBQuery( -- entry ya viene pre-sanitizado
                string.format("SELECT entry, buyPrice, maxCount, stackable FROM %s WHERE entry = %d AND state = 1", 
                config.tables.item_vendor, entry))
            if sql then
                local res = {}
                repeat
                    table.insert(res, {sql:GetUInt32(0), sql:GetUInt32(1), sql:GetUInt32(2), sql:GetUInt32(3)})
                until not sql:NextRow()
                return res
            else
                return nil
            end 
        end,

        GET_FREQUENT_PURCHASES_BY_PLAYER_ID = function(player_id)
            local sql = string.format('SELECT entry, buyPrice, maxCount FROM %s WHERE player_id = %d ORDER BY times DESC LIMIT %d',
                config.tables.frecuent, player_id, MAX_RESULTS)
            
            local Q = WorldDBQuery(sql)
            
            if not Q then
                return nil
            end
            
            local res = {}
            repeat
                local item_id = Q:GetUInt32(0)
                local link = GetItemLink(item_id, 7)
                res[#res + 1] = { item_id, Q:GetUInt32(1), Q:GetUInt32(2), link}
            until not Q:NextRow()
            return res
        end,
        
        GET_GLOBAL_RATE = function()
            local q = WorldDBQuery(string.format("SELECT rate FROM %s WHERE id = 1", config.tables.global_rate))
            return q and q:GetUInt8(0) or 1
        end,
        
        GET_FLAT_AMOUNT_BUYPRICE = function()
            local q = WorldDBQuery(string.format("SELECT amount FROM %s WHERE id = 1", config.tables.fixed_amount))
            return q and q:GetUInt32(0) or 10000
        end,
        
        VENDOR_TABLE_IS_EMPTY = function()
            return not WorldDBQuery(string.format("SELECT 1 FROM %s WHERE state = 1 LIMIT 1", config.tables.item_vendor))
        end,
        
        PLAYER_HAS_LOG = function(player_id)
            return WorldDBQuery(string.format("SELECT 1 FROM %s WHERE state = 1 and player_id = %d", config.tables.player_log, player_id)) and true or false
        end,
        
        GET_LAST_ITEMS_FROM_LOG = function(player_id)
            return WorldDBQuery(string.format(
                "SELECT amount, item_id, purchase_time, expense FROM %s WHERE state = 1 AND player_id = %d ORDER BY purchase_time DESC LIMIT " .. MAX_RESULTS, config.tables.player_log, player_id))
        end,

        FIND_ONE = function(entry)
            return WorldDBQuery(string.format(
                'SELECT entry, `name`, buyPrice, maxCount, stackable from %s WHERE entry = %d AND state = 1', config.tables.item_vendor, 
                entry))
        end,

        FIND_ONE_ITEM_TEMPLATE = function(entry)
            local sql = WorldDBQuery(string.format('SELECT entry, BuyPrice, maxcount, stackable FROM item_template WHERE entry = %d', entry))
            return sql and {sql:GetUInt32(0), sql:GetUInt32(1), sql:GetUInt32(2), sql:GetUInt32(3)} or false
        end,

        UPDATE_ITEM_BUYPRICE = function(entry, new_price)
            WorldDBExecute(string.format('UPDATE %s SET buyPrice = %d WHERE entry = %d', config.tables.item_vendor, new_price, entry))
            return true
        end,

        INSERT_ITEM_IN_VENDOR_TABLE = function(entry, name, buyprice, maxcount, stackable)
            WorldDBExecute(string.format('INSERT INTO %s (entry, `name`, buyPrice, maxCount, stackable, state) VALUES (%d, "%s", %d, %d, %d, 1) ON DUPLICATE KEY UPDATE state = 1, stackable = %d',
                config.tables.item_vendor, entry, CLEAN_INPUT(name), buyprice, maxcount, stackable, stackable))
        end,

        DELETE_ITEM_FROM_VENDOR_TABLE = function(entry)
            WorldDBExecute(string.format('UPDATE %s SET state = 0 WHERE entry = %d', config.tables.item_vendor, entry))
        end,

        IS_FIXED_AMOUNT_EMPTY = function()
            return not WorldDBQuery(string.format("SELECT 1 FROM %s WHERE id = 1", config.tables.fixed_amount))
        end,
        
        IS_GLOBAL_RATE_EMPTY = function()
            return not WorldDBQuery(string.format("SELECT 1 FROM %s WHERE id = 1", config.tables.global_rate))
        end,
        
        IS_BLACKLIST_EMPTY = function()
            local q = WorldDBQuery(string.format("SELECT 1 FROM %s LIMIT 1", config.tables.blacklist))
            if q then 
                return false
            else
                return true
            end
        end,

        POPULATE_FIXED_AMOUNT_ASYNC = function(callback)
            WorldDBQueryAsync(string.format("INSERT IGNORE INTO %s (id, amount) VALUES (1, 10000)", config.tables.fixed_amount), callback)
        end,
        
        POPULATE_GLOBAL_RATE_ASYNC = function(callback)
            WorldDBQueryAsync(string.format("INSERT IGNORE INTO %s (id, rate) VALUES (1, 1)", config.tables.global_rate), callback)
        end,

        IS_ITEM_BLACKLISTED = function(entry)
            local q = WorldDBQuery(string.format("SELECT 1 FROM %s WHERE id = %d", config.tables.blacklist, entry))
            return q ~= nil
        end,

        INSERT_GM_LOG = function(gm_id, action, item_id, old_value, new_value)
            WorldDBExecute(string.format("INSERT INTO "..config.tables.gm_log.." (gm_id, action, item_id, old_value, new_value) VALUES (%d, '%s', %s, %s, %s)",
                gm_id, action, item_id 
                or "NULL", old_value 
                and ("'" .. CLEAN_INPUT(old_value) .. "'") 
                or "NULL", new_value 
                and ("'" .. CLEAN_INPUT(new_value) .. "'") 
                or "NULL"
            ))
        end,

        CLEAR_FREQUENT_PURCHASES_BY_PLAYER_ID = function(player_id)
            WorldDBExecute(string.format("DELETE FROM %s WHERE player_id = %d", config.tables.frecuent, player_id))
        end,

        CLEAR_LOG_BY_PLAYER_ID = function(player_id)
            WorldDBExecute(string.format("UPDATE %s SET state = 0 WHERE player_id = %d", config.tables.player_log, player_id))
        end, 
    }
end
local DB = Query()


-- Creador de iconos
local function ICO(iconString, size)  
    return iconString 
        and string.format('|TInterface\\Icons\\%s:%d:%d:-21|t', iconString, size, size)
        or string.format('|TInterface/PaperDollInfoFrame/UI-GearManager-Undo:%d:%d:-21|t', size, size)
end


-- Toma un número y lo devuelve formateado con los íconos de oro, plata y cobre del juego
local function TO_MONEY_ICO(copper)
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


-- Extrae la string necesaria para crear un ícono en la UI
local function GET_ICON(item_id)
    if item_id == 0 then
        return '|TInterface/PaperDollInfoFrame/UI-GearManager-Undo:32:32:-21|t'
    else
        local it = GetItemTemplate(item_id)
        return it and string.format("|TInterface\\Icons\\%s:32:32:-21|t", it:GetIcon()) or "|TInterface\\Icons\\INV_Misc_QuestionMark:32:32:-21|t"
    end
end


-- Evento 1
local function GOSSIP_EVENT_ON_HELLO(e, P, NPC) 

    if DB.VENDOR_TABLE_IS_EMPTY() then
        P:SendBroadcastMessage('|cffff0000Error. El sistema necesita configuración.')
        return
    end

    local iconSize = 42

    P:GossipClearMenu()
    P:GossipMenuAddItem(8, ICO('inv_misc_spyglass_01', iconSize) .. 'Buscar objeto por nombre...', 1, 0, true, 'Ingresa parte del nombre del objeto.')
    P:GossipMenuAddItem(8, ICO('inv_misc_key_05', iconSize) .. 'Buscar objeto por ID...', 8, 0, true, 'Ingresa el ID del objeto.')
    P:GossipMenuAddItem(8, ICO('inv_misc_coin_02', iconSize) .. 'Compras frecuentes', 3, 0)
    P:GossipMenuAddItem(8, ICO('inv_inscription_scroll', iconSize) .. 'Registro de compras', 4, 0)

    if P:IsGM() then
        P:GossipMenuAddItem(8, ICO('spell_holy_stoicism', iconSize) .. 'Editar precio', 5, 0, true, "Ingresa el |CFF00FF00ID|r del objeto:")
        P:GossipMenuAddItem(8, ICO('inv_enchant_shardglowingsmall', iconSize) .. 'Añadir', 6, 0, true, "Ingresa el |CFF00FF00ID|r del objeto:")
        P:GossipMenuAddItem(8, ICO('spell_shadow_sacrificialshield', iconSize) .. 'Eliminar', 7, 0, true, "Ingresa el |CFF00FF00ID|r del objeto:")
    end
    P:GossipSendMenu(1, NPC)

    -- Limpiamos cache
    M[P:GetGUIDLow()] = {}

end


-- Evento 2
local function GOSSIP_EVENT_ON_SELECT(e, P, NPC, SEND, OPTION, RAW_INPUT) 

    -- Volver al menú principal
    if SEND == 99999 and OPTION == 99999 then
        GOSSIP_EVENT_ON_HELLO(1, P, NPC)
        return
    end

    -- Búsqueda de objetos por nombre
    if SEND == 1 and OPTION == 0 then
        local clean_input = CLEAN_INPUT(RAW_INPUT)

        if clean_input == '' then
            P:SendBroadcastMessage('|CFFFF0000Error. Debes escribir el nombre de un objeto.')
            return
        end

        local found = DB.GET_ITEM_BY_NAME_OR_PART(clean_input) --> {entry, buyPrice, maxCount, stackable}

        if found then
            P:SendBroadcastMessage(string.format(col..'%d resultados para "%s": ' , #found, clean_input))
        
            for row = 1, #found do
                local _entry, _buyprice, _maxcount, _stackable = table.unpack(found[row])
                local link = GetItemLink(_entry, 7)
                local _itemlink = GET_ICON(_entry) .. row..'. ' ..link
                local coins = TO_MONEY_ICO(_buyprice)
                local chat_link = col .. row .. '. ' .. link .. ' ' .. coins
                local info = string.format(row..'. %s\nPrecio unitario: %s\nIngresa la cantidad que deseas:', link, coins)
                P:GossipMenuAddItem(8, _itemlink, 2, _entry, true, info)
                P:SendBroadcastMessage(chat_link)
                M[P:GetGUIDLow()][_entry] = {link, _buyprice, _maxcount, _stackable} -- Insertar en cache
            end
            P:GossipMenuAddItem(8, GET_ICON(0) .. 'Realizar otra búsqueda', 99999, 99999)
            P:GossipSendMenu(1, NPC)
        else
            P:SendBroadcastMessage('|CFFFF0000No se encontraron coincidencias.')
            P:GossipComplete()
            return
        end
        return

    -- Búsqueda de objetos por ID
    elseif SEND == 8 and OPTION == 0 then
        local clean_input = TO_ITEM_ID(RAW_INPUT)

        if clean_input == 0 then
            P:SendBroadcastMessage('|CFFFF0000Error. Debes escribir el ID de un objeto.')
            return
        end

        local found = DB.GET_ITEM_BY_ID(clean_input) --> {entry, buyPrice, maxCount, stackable}

        if found then
            P:SendBroadcastMessage(col .. '¡Objeto encontrado!')
        
            for row = 1, #found do
                local _entry, _buyprice, _maxcount, _stackable = table.unpack(found[row])
                local link = GetItemLink(_entry, 7)
                local _itemlink = GET_ICON(_entry) .. row..'. ' ..link
                local coins = TO_MONEY_ICO(_buyprice)
                local chat_link = col .. row .. '. ' .. link .. ' ' .. coins
                local info = string.format(row..'. %s\nPrecio unitario: %s\nIngresa la cantidad que deseas:', link, coins)
                P:GossipMenuAddItem(8, _itemlink, 2, _entry, true, info)
                P:SendBroadcastMessage(chat_link)
                M[P:GetGUIDLow()][_entry] = {link, _buyprice, _maxcount, _stackable} -- Insertar en cache
            end
            P:GossipMenuAddItem(8, GET_ICON(0) .. 'Realizar otra búsqueda', 99999, 99999)
            P:GossipSendMenu(1, NPC)
        else
            P:SendBroadcastMessage('|CFFFF0000No se encontraron coincidencias.')
            P:GossipComplete()
            return
        end
        return

    -- Compra de objeto
    elseif SEND == 2 then

        local guid = P:GetGUIDLow()
        local entry = OPTION
        local itemData = M[guid] and M[guid][entry]

        -- Validar que el item existe en caché
        if not itemData then
            P:SendBroadcastMessage("|cffff0000Error: Objeto no encontrado. Realiza una nueva búsqueda.")
            P:GossipComplete()
            return
        end

        local link, buyPrice, maxCount, stackable = table.unpack(itemData)
        local globalRate = DB.GET_GLOBAL_RATE()
        local unitPrice = buyPrice * globalRate
        local desired = TO_POSITIVE_INTEGER(RAW_INPUT)

        -- Validar cantidad ingresada
        if desired < 1 then
            P:SendBroadcastMessage("|cffff0000Debes ingresar un número entero positivo.")
            P:GossipComplete()
            return
        end

        local toBuy = desired
        local mLimit, mSpace, mGold = 0, 0, 0
        local limitReason, spaceReason, goldReason = "", "", ""

        -- 1. Límite de posesión (maxCount)
        if maxCount > 0 then
            local currentlyOwned = P:GetItemCount(entry)
            local canTake = maxCount - currentlyOwned
            if canTake <= 0 then
                P:SendBroadcastMessage("|cffff0000No puedes llevar más de ese objeto.")
                P:GossipComplete()
                return
            end
            if toBuy > canTake then
                mLimit = toBuy - canTake
                toBuy = canTake
                limitReason = mLimit .. " objetos exceden el límite de posesión (" .. maxCount .. " máximo)"
            end
        end

        -- 2. Espacio en inventario
        local freeSlots = P:GetInventoryFreeSlots()
        local maxSpace = freeSlots * (stackable > 0 and stackable or 1)
        if toBuy > maxSpace then
            mSpace = toBuy - maxSpace
            toBuy = maxSpace
            spaceReason = mSpace .. " objetos no se pudieron agregar por falta de espacio"
        end

        -- Si después de límite y espacio no hay nada que comprar
        if toBuy <= 0 then
            local razones = {}
            if limitReason ~= "" then table.insert(razones, limitReason) end
            if spaceReason ~= "" then table.insert(razones, spaceReason) end
            P:SendBroadcastMessage("|cffff0000No se pudo comprar ningún objeto. " .. table.concat(razones, " y ") .. ".")
            P:GossipComplete()
            return
        end

        -- 3. Oro
        local cost = toBuy * unitPrice
        local playerMoney = P:GetCoinage()
        if playerMoney < cost then
            local maxAffordable = math.floor(playerMoney / unitPrice)
            if maxAffordable <= 0 then
                P:SendBroadcastMessage("|cffff0000No tienes suficiente oro para realizar la compra.")
                P:GossipComplete()
                return
            end
            mGold = toBuy - maxAffordable
            toBuy = maxAffordable
            cost = toBuy * unitPrice
            goldReason = mGold .. " objetos no se compraron por falta de oro"
        end

        -- Construir mensaje de limitaciones
        local limitaciones = {}
        if limitReason ~= "" then table.insert(limitaciones, limitReason) end
        if spaceReason ~= "" then table.insert(limitaciones, spaceReason) end
        if goldReason ~= "" then table.insert(limitaciones, goldReason) end

        -- 4. Entrega final
        if P:AddItem(entry, toBuy) then
            P:ModifyMoney(-cost)
            local mensajeExito = "|CFF00FF00Comprado: " .. toBuy .. "× " .. link .. '|CFF00FF00 por ' .. TO_MONEY_ICO(cost)
            if #limitaciones > 0 then
                mensajeExito = mensajeExito .. " |cffffcc00(Nota: " .. table.concat(limitaciones, "; ") .. ")|r"
            end
            P:SendBroadcastMessage(mensajeExito)
            DB.INSERT_INTO_LOG(guid, entry, toBuy, cost)
            DB.INSERT_OR_UPDATE_FREQUENT_PURCHASE(entry, buyPrice, maxCount, guid)
            NPC:SendUnitSay(P:GetName() .. " ha comprado " .. toBuy .. "× " .. link .. ".", 0)
        else
            P:SendBroadcastMessage("|cffff0000Error al añadir el objeto al inventario.")
        end
        P:GossipComplete()
        return
    
    -- Compras frecuentes
    elseif SEND == 3 and OPTION == 0 then
        
        local guid = P:GetGUIDLow()
        local frecuent = DB.GET_FREQUENT_PURCHASES_BY_PLAYER_ID(guid)

        if frecuent then
            P:GossipClearMenu()
            local msg = "%d. %s\nIngresa la cantidad a comprar.\n\nPrecio unitario: %s"
            local iconSize = 32
            local globalRate = DB.GET_GLOBAL_RATE()
            
            for i = 1, #frecuent do
                local entry = frecuent[i][1]
                local buyP = frecuent[i][2]
                local maxC = frecuent[i][3]
                local link = frecuent[i][4]
                
                local displayPrice = (buyP == 0 and FLAT_PRICE or buyP) * globalRate
                local coinIcons = TO_MONEY_ICO(displayPrice)
                
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
                
                -- Guardar en cache para usar en la compra
                M[guid][entry] = {link, buyP, maxC, stack}
                
                local icon = GET_ICON(entry)
                P:GossipMenuAddItem(0, icon .. i .. '. ' .. link , 2, entry, true, string.format(msg, i, link, coinIcons))
            end

            -- Limpiar
            local myico = ICO('ability_shaman_cleansespirit', iconSize)
            P:GossipMenuAddItem(0, myico .. 'Limpiar mi lista de frecuentes.', 3, 9999, false, '¿Estás seguro de que quieres limpiar tu registro de compras frecuentes?')
            
            P:GossipMenuAddItem(0, GET_ICON(0) .. 'Volver', 99999, 99999)
            P:GossipSendMenu(1, NPC)
        else
            P:SendBroadcastMessage('|cffff0000No tienes compras frecuentes registradas.')
            P:GossipComplete()
        end
        return

    -- Limpiar frecuentes
    elseif SEND == 3 and OPTION == 9999 then
        local guid = P:GetGUIDLow()
        DB.CLEAR_FREQUENT_PURCHASES_BY_PLAYER_ID(guid)
        P:SendBroadcastMessage('|cff00ff00Tu lista de compras frecuentes ha sido limpiada.')
        P:GossipComplete()
        return

    -- GM: EDITAR PRECIO - Paso 1 (Recibe ID del ítem)
    elseif SEND == 5 and OPTION == 0 then
        local entry = TO_ITEM_ID(RAW_INPUT)
        if entry == 0 then
            P:SendBroadcastMessage("|cffff0000Debes ingresar un ID de objeto válido.")
            P:GossipComplete()
            return
        end
        
        local itemInVendor = DB.FIND_ONE(entry)
        if not itemInVendor then
            P:SendBroadcastMessage("|cffff0000El objeto con ID " .. entry .. " no está en el vendor o está inactivo.")
            P:GossipComplete()
            return
        end
        
        -- Guardar en caché para el siguiente paso
        local guid = P:GetGUIDLow()
        local link = GetItemLink(entry, 7)
        local currentPrice = itemInVendor:GetUInt32(2)  -- buyPrice
        
        M[guid].pendingItem = {
            id = entry,
            price = currentPrice
        }
        
        P:GossipClearMenu()
        local example = 50000
        local msg = string.format('Ingresa el nuevo precio en cobre\n(ej: %d para %s)', example, TO_MONEY_ICO(example))
        P:GossipMenuAddItem(0, GET_ICON(entry) .. "[EDITAR] " .. link .. ": " .. TO_MONEY_ICO(currentPrice), 5, entry, true, msg)
        P:GossipMenuAddItem(0, GET_ICON(0) .. 'Cancelar', 99999, 99999)
        P:GossipSendMenu(1, NPC)
        return
    end

    -- GM: EDITAR PRECIO - Paso 2 (Recibe nuevo precio y ejecuta UPDATE)
    if SEND == 5 and OPTION > 0 then
        local guid = P:GetGUIDLow()
        local entry = OPTION
        local newPrice = TO_ITEM_ID(RAW_INPUT)
        
        -- Validación: ¿Hay datos pendientes y coinciden?
        if not M[guid].pendingItem or M[guid].pendingItem.id ~= entry then
            P:SendBroadcastMessage("|cffff0000Error: Inconsistencia en los datos. Operación cancelada.")
            P:GossipComplete()
            return
        end
        
        if newPrice <= 0 then
            P:SendBroadcastMessage("|cffff0000El precio debe ser un número positivo mayor a 0.")
            P:GossipComplete()
            return
        end
        
        local success = DB.UPDATE_ITEM_BUYPRICE(entry, newPrice)
        
        if success then
            local link = GetItemLink(entry, 7)
            P:SendBroadcastMessage("|cff00ff00Precio de " .. link .. "|cff00ff00 actualizado a " .. TO_MONEY_ICO(newPrice) .. ".")
            DB.INSERT_GM_LOG(guid, 'EDIT', entry, tostring(M[guid].pendingItem.price), tostring(newPrice))
        else
            P:SendBroadcastMessage("|cffff0000Error al actualizar el precio en la base de datos.")
        end
        
        M[guid].pendingItem = nil
        GOSSIP_EVENT_ON_HELLO(1, P, NPC)
        return
    end

    -- GM: AÑADIR - Paso 1 (Recibe ID del ítem a añadir)
    if SEND == 6 and OPTION == 0 then
        local guid = P:GetGUIDLow()
        local id = TO_ITEM_ID(RAW_INPUT)
        
        if id == 0 then
            P:SendBroadcastMessage("|cffff0000Debes ingresar un ID de objeto válido (mayor a 0).")
            P:GossipComplete()
            return
        end
        
        -- 1. ¿Existe en item_template?
        local it = DB.FIND_ONE_ITEM_TEMPLATE(id)
        if not it then
            P:SendBroadcastMessage("|cffff0000El objeto con ID " .. id .. " no existe en item_template.")
            P:GossipComplete()
            return
        end
        
        -- 2. ¿Está en la blacklist?
        if DB.IS_ITEM_BLACKLISTED(id) then
            P:SendBroadcastMessage("|cffff0000ERROR: El objeto " .. GetItemLink(id, 7) .. "|cffff0000 está en la lista negra y NO puede ser añadido al vendor.")
            P:GossipComplete()
            return
        end
        
        -- 3. ¿Ya existe en el vendor con state = 1?
        local existingItem = DB.FIND_ONE(id)
        if existingItem then
            local currentPrice = existingItem:GetUInt32(2)
            local currentMaxCount = existingItem:GetUInt32(3)
            local currentStackable = existingItem:GetUInt32(4)
            local link = GetItemLink(id, 7)
            
            P:SendBroadcastMessage("|cffffcc00ADVERTENCIA: El objeto " .. link .. "|cffffcc00 ya existe en el vendor.")
            P:SendBroadcastMessage("|cffffcc00Precio actual: " .. TO_MONEY_ICO(currentPrice) .. " | Límite: " .. currentMaxCount .. " | Stack: " .. currentStackable)
            P:SendBroadcastMessage("|cffffcc00Al confirmar, se REACTIVARÁ (si estaba inactivo) y se actualizará el stackable a " .. it[4] .. ".")
        end
        
        -- 4. Todo bien, proceder con el preview
        local link = GetItemLink(id, 7)
        local suggestedPrice = it[2]
        local maxCount = it[3]
        local stackable = it[4]
        
        M[guid].pendingItem = {
            id = id,
            name = link,
            price = suggestedPrice,
            maxCount = maxCount,
            stackable = stackable
        }
        
        P:GossipClearMenu()
        local price_coins = TO_MONEY_ICO(suggestedPrice)
        P:GossipMenuAddItem(0, GET_ICON(id) .. "[+] " .. link, 6, id)
        P:GossipMenuAddItem(0, GET_ICON(0) .. 'Cancelar', 99999, 99999)
        local msg = string.format('[AÑADIR] %s\nPrecio: %s\nLímite: %d\nStack: %d', link, price_coins, maxCount, stackable)
        P:SendBroadcastMessage(msg)
        P:GossipSendMenu(1, NPC)
        return
    end

    -- GM: AÑADIR - Paso 2 (Confirmación y ejecución)
    if SEND == 6 and OPTION > 0 then
        local guid = P:GetGUIDLow()
        
        if not M[guid].pendingItem or M[guid].pendingItem.id == 0 then
            P:SendBroadcastMessage("|cffff0000Error: No hay datos pendientes para confirmar. Inicia el proceso de nuevo.")
            P:GossipComplete()
            return
        end
        
        if OPTION ~= M[guid].pendingItem.id then
            P:SendBroadcastMessage("|cffff0000Error: Inconsistencia en los datos. Operación cancelada.")
            P:GossipComplete()
            return
        end
        
        -- Segundo check de blacklist (TOCTOU protection)
        if DB.IS_ITEM_BLACKLISTED(M[guid].pendingItem.id) then
            P:SendBroadcastMessage("|cffff0000ERROR: El objeto ha sido añadido a la lista negra mientras confirmabas. Operación cancelada.")
            P:GossipComplete()
            return
        end
        
        -- Validación final: ¿El ítem sigue existiendo en item_template?
        local it = DB.FIND_ONE_ITEM_TEMPLATE(M[guid].pendingItem.id)
        if not it then
            P:SendBroadcastMessage("|cffff0000ERROR: El objeto ya no existe en item_template. ¿Fue eliminado?")
            P:GossipComplete()
            return
        end
        
        -- Ejecutar la inserción/actualización
        DB.INSERT_ITEM_IN_VENDOR_TABLE(
            M[guid].pendingItem.id, 
            M[guid].pendingItem.name, 
            M[guid].pendingItem.price, 
            M[guid].pendingItem.maxCount, 
            M[guid].pendingItem.stackable
        )
        
        local link = GetItemLink(M[guid].pendingItem.id, 7)
        local successMsg = string.format(
            '|cff00ff00¡Objeto añadido/activado exitosamente!|r\n' .. 'ID: %d | %s\n' .. 'Precio: %s | Límite: %d | Stack: %d',
            M[guid].pendingItem.id, link, TO_MONEY_ICO(M[guid].pendingItem.price),  M[guid].pendingItem.maxCount,
            M[guid].pendingItem.stackable)
        P:SendBroadcastMessage(successMsg)
        
        -- (gm_id, action, item_id, old_value, new_value)
        DB.INSERT_GM_LOG(guid, 'ADD', M[guid].pendingItem.id, nil, nil)
        
        M[guid].pendingItem = nil
        GOSSIP_EVENT_ON_HELLO(1, P, NPC)
        return

    -- GM: ELIMINAR (Soft Delete)
    elseif SEND == 7 and OPTION == 0 then
        local guid = P:GetGUIDLow()
        local entry = TO_ITEM_ID(RAW_INPUT)
        
        if entry == 0 then
            P:SendBroadcastMessage("|cffff0000Debes ingresar un ID de objeto válido.")
            P:GossipComplete()
            return
        end
        
        -- Validar que existe en el vendor
        local itemInVendor = DB.FIND_ONE(entry)
        if not itemInVendor then
            P:SendBroadcastMessage("|cffff0000El objeto con ID " .. entry .. " no está en el vendor o ya está inactivo.")
            P:GossipComplete()
            return
        end
        
        local link = GetItemLink(entry, 7)
        DB.DELETE_ITEM_FROM_VENDOR_TABLE(entry) 
        P:SendBroadcastMessage("|cffff0000Objeto " .. link .. "|cffff0000 marcado como inactivo.")

        -- (gm_id, action, item_id, old_value, new_value)
        DB.INSERT_GM_LOG(guid, 'DELETE', entry, nil, nil)
        GOSSIP_EVENT_ON_HELLO(1, P, NPC)
        return

    -- REGISTRO DE COMPRAS
    elseif SEND == 4 and OPTION == 0 then
        local guid = P:GetGUIDLow()
        if DB.PLAYER_HAS_LOG(guid) then
            local log = DB.GET_LAST_ITEMS_FROM_LOG(guid)
            local counter = 1
            local y = '|cff8fd1c4'

            local myico = ICO('ability_shaman_cleansespirit', 34)
            P:GossipClearMenu()
            P:GossipMenuAddItem(0, myico .. 'Limpiar mi registro de compras.', 4, 9995, false, '¿Estás seguro de que quieres limpiar tu registro de compras?')
            P:GossipMenuAddItem(0, GET_ICON(0) .. 'Volver', 99999, 99999)
            P:GossipSendMenu(1, NPC)

            P:SendBroadcastMessage(y .. 'Últimos registros (hora Perú UTC-5) de ' .. P:GetName() .. ':')
            repeat
                local amount = log:GetUInt32(0)
                local itemId = log:GetUInt32(1)
                local rawDate = log:GetString(2)
                local date = FORMAT_TIMESTAMP(rawDate)
                local expense = TO_MONEY_ICO(log:GetUInt32(3))
                local msg = string.format('%s%d%s. %s%s×%d%s por %s%s - %s', y, counter, y,  GetItemLink(itemId, 7), y, amount, y,
                    expense, y, date)
                P:SendBroadcastMessage(msg)
                counter = counter + 1
            until not log:NextRow()
        else
            P:SendBroadcastMessage('|cffff0000No hay registros de compras.')
            P:GossipComplete()
        end
        return
    end

    -- LIMPIAR REGISTRO DE COMPRAS
    if SEND == 4 and OPTION == 9995 then
        local guid = P:GetGUIDLow()
        DB.CLEAR_LOG_BY_PLAYER_ID(guid)
        P:SendBroadcastMessage('|cff00ff00Tu registro de compras ha sido limpiado.')
        GOSSIP_EVENT_ON_HELLO(1, P, NPC)
        return
    end

end

local function ON_PLAYER_LOGIN_OR_LOGOUT(e, P)

    local id = P:GetGUIDLow()

    -- Login
    if e == 3 then
        M[id] = {}

    -- Logout
    elseif e == 4 then
        M[id] = nil
    end
end


RegisterCreatureGossipEvent(NPC_ID, 1, GOSSIP_EVENT_ON_HELLO)
RegisterCreatureGossipEvent(NPC_ID, 2, GOSSIP_EVENT_ON_SELECT)
RegisterPlayerEvent(3, ON_PLAYER_LOGIN_OR_LOGOUT)
RegisterPlayerEvent(4, ON_PLAYER_LOGIN_OR_LOGOUT)
