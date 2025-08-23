
local MAX_RESULTS = 25
local FORBIDDEN_CHARACTERS = { '"', "'", '\\', '%', '_', ';', '#', '`', '/', '-', '$', '*' }
local ITEMS_IDS, ITEMS_PRICES, ITEMS_MAXCOUNTS, ITEMS_UNIQUES, GLOBAL_RATE_COEFFICIENT, FLAT_PRICE
local iconOro = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:0:0|t"
local iconPlata = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:0:0|t"
local iconCobre = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:0:0|t"
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

-- Elegir iconos
local function ico(sel)
    return (sel==1) and "|TInterface\\Icons\\inv_misc_spyglass_01:42:42:-21:0|t" or (sel==2) and "|TInterface\\Icons\\inv_inscription_scroll:42:42:-21:0|t" or 
           (sel==3) and "|TInterface\\Icons\\inv_misc_coin_02:42:42:-21:0|t" 
end

-- Función para determinar si hay caracteres peligrosos en la entrada
local function hasForbiddenChars(str)
    for c in str:gmatch(".") do
        for _, forbidden in ipairs(FORBIDDEN_CHARACTERS) do
            if c == forbidden then
                return true
            end
        end
    end
    return false
end

-- Consultas dinámicas
local function Query()
    local q = {
        CREATE_ITEM_TABLE = function()
            return [[CREATE TABLE IF NOT EXISTS a_itemvendor (entry INT UNSIGNED NOT NULL PRIMARY KEY, `name` VARCHAR(80) NOT NULL, 
            buyPrice INT UNSIGNED NOT NULL, maxCount INT UNSIGNED NOT NULL)]]
        end,

        CREATE_LOG_TABLE = function()
            return [[CREATE TABLE IF NOT EXISTS a_itemvendor_log (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, player_id INT UNSIGNED NOT NULL, 
                item_id MEDIUMINT UNSIGNED NOT NULL, amount MEDIUMINT UNSIGNED NOT NULL, expense INT UNSIGNED NOT NULL, 
                purchase_time TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP)]]
        end,

        CREATE_FRECUENT_TABLE = function()
            return [[CREATE TABLE IF NOT EXISTS a_itemvendor_frecuent (entry INT UNSIGNED NOT NULL, buyPrice INT UNSIGNED NOT NULL, 
                    maxCount TINYINT UNSIGNED NOT NULL, times INT UNSIGNED NOT NULL DEFAULT '1', 
                    player_id INT UNSIGNED NOT NULL, UNIQUE KEY uniq_entry_player (entry,player_id))]]
        end,

        CREATE_FIXED_AMOUNT_TABLE = function ()
            return [[CREATE TABLE IF NOT EXISTS a_itemvendor_fixed_amount (amount INT UNSIGNED PRIMARY KEY DEFAULT 10000)]]
        end,

        CREATE_GLOBAL_RATE_TABLE = function ()
            return [[CREATE TABLE IF NOT EXISTS a_itemvendor_global_rate (rate TINYINT UNSIGNED PRIMARY KEY DEFAULT 1)]]
        end,

        INSERT_INTO_LOG = function(player_id, item_id, amount, expense)
            return string.format("INSERT INTO a_itemvendor_log (player_id, item_id, amount, expense) VALUES (%d, %d, %d, %d)",
                player_id, item_id, amount, expense)
        end,

        INSERT_OR_UPDATE_FREQUENT_PURCHASE = function(entry, buyPrice, maxCount, player_id)
            return string.format("INSERT INTO a_itemvendor_frecuent (entry, buyPrice, maxCount, times, player_id) " ..
                "VALUES (%d, %d, %d, 1, %d) ON DUPLICATE KEY UPDATE times = times + 1", entry, buyPrice, maxCount, player_id)
        end,

        INSERT_DEFAULT_FIXED_AMOUNT = function ()
            return [[INSERT INTO a_itemvendor_fixed_amount VALUES ()]]
        end,

        INSERT_DEFAULT_GLOBAL_RATE = function ()
            return [[INSERT INTO a_itemvendor_global_rate VALUES ()]]
        end,

        SELECT_ITEM_BY_NAME = function(name)
            return string.format("SELECT * FROM a_itemvendor WHERE `name` LIKE '%%%s%%' LIMIT %d", name, (MAX_RESULTS > 30 and 30 or MAX_RESULTS))
        end,

        SELECT_FRECUENT_PURCHASES_BY_PLAYER_ID = function(player_id)
            return string.format("SELECT * FROM a_itemvendor_frecuent WHERE player_id = %d ORDER BY times DESC LIMIT 15", player_id)
        end,

        SELECT_ONE_BY_ENTRY = function(entry)
            return string.format("SELECT 1 FROM a_itemvendor WHERE entry = %d LIMIT 1", entry)
        end,

        SELECT_GLOBAL_RATE = function()
            local query = WorldDBQuery("SELECT rate FROM a_itemvendor_global_rate")
            return query:GetUInt8(0)
        end,

        SELECT_FLAT_AMOUNT_BUYPRICE = function()
            local query = WorldDBQuery("SELECT amount FROM a_itemvendor_fixed_amount")
            return query:GetUInt32(0)
        end,

        UPDATE_ITEM_BUY_PRICE = function(input, option)
            return string.format("UPDATE a_itemvendor SET buyPrice = %d WHERE `entry` = %d", input, option)
        end,

        DELETE_ONE_BY_ENTRY = function (entry)
            return string.format("DELETE FROM a_itemvendor WHERE entry = %d", entry)
        end,

        CHECK_IF_TABLE_IS_POPULATED = function ()
            return "SELECT 1 FROM a_itemvendor LIMIT 1"
        end,

        CHECK_IF_FIXED_AMOUNT_EXISTS = function ()
            return "SELECT 1 FROM a_itemvendor_fixed_amount LIMIT 1"
        end,

        SELECT_ONE_FROM_LOG_BY_PLAYER_ID = function (player_id)
            return string.format("SELECT 1 FROM a_itemvendor_log WHERE player_id = %d", player_id)
        end,

        SELECT_LAST_20_FROM_LOG_BY_PLAYER_ID = function(player_id)
            return string.format("SELECT amount, item_id, purchase_time, expense FROM a_itemvendor_log WHERE player_id = %d ORDER BY purchase_time DESC LIMIT 20", player_id)
        end,

        SELECT_BUYPRICE_AND_MAXCOUNT_BY_ITEM_ENTRY = function (item_entry)
            return string.format("SELECT BuyPrice, maxcount FROM item_template WHERE entry = %d", item_entry)
        end,

        SELECT_BUYPRICE_BY_ITEM_ENTRY = function (item_entry)
            return string.format("SELECT buyPrice FROM a_itemvendor WHERE entry = %d", item_entry)
        end,

        SELECT_ITEM_ENTRY_BY_ITEM_ENTRY = function (item_entry)
            return string.format("SELECT entry FROM a_itemvendor WHERE entry = %d", item_entry)
        end
    }
    return q
end

local QQ = Query()

local function CLICK_1(e, P, U)

    local fixed_amount_exists = WorldDBQuery(QQ.CHECK_IF_FIXED_AMOUNT_EXISTS())

    if not fixed_amount_exists then
        WorldDBExecute(QQ.INSERT_DEFAULT_FIXED_AMOUNT())
        WorldDBExecute(QQ.INSERT_DEFAULT_GLOBAL_RATE())
    end

    local table_is_populated = WorldDBQuery( QQ.CHECK_IF_TABLE_IS_POPULATED() ) 

    if not table_is_populated then
        P:SendBroadcastMessage('|CFFff0000El sistema necesita configuración. No se encontraron registros de objetos.')
        return
    end

    P:GossipMenuAddItem(8, ico(1) .. 'Buscar un objeto', 0, 0, true, 'Ingresa parte del nombre del objeto...')
    P:GossipMenuAddItem(8, ico(3) .. 'Comprados frecuentemente', 5, 0)    
    P:GossipMenuAddItem(8, ico(2) .. 'Ver registro de compras (20)', 4, 0)
    P:GossipSendMenu(1, U)
    
end


local function getIcon(item_id)
    local ItemTemplate = GetItemTemplate(item_id)
    local icon = ItemTemplate:GetIcon()
    local icon_base = "|TInterface\\Icons\\%s:21:21:-22|t"
    return string.format(icon_base, icon)
end


local function CLICK_2(e, P, U, send, option, raw_input)

    FLAT_PRICE = QQ.SELECT_FLAT_AMOUNT_BUYPRICE();
    GLOBAL_RATE_COEFFICIENT = QQ.SELECT_GLOBAL_RATE();

    -- Regresar a la búsqueda de objetos
    if (send == 6) and (option == 0) then
        CLICK_1(1, P, U)
        return
    end

    -- Compras frecuentes
    if (send == 5 and option == 0) then
    
        local Q = QQ.SELECT_FRECUENT_PURCHASES_BY_PLAYER_ID(P:GetGUIDLow())
        local frecuently_bought_items = WorldDBQuery(Q);

        if frecuently_bought_items then

            -- Pasamos agua, jabón y lejía
            ITEMS_IDS       = {}
            ITEMS_PRICES    = {}
            ITEMS_MAXCOUNTS = {}
            ITEMS_UNIQUES   = {}
            
            local conteo = 1

            P:SendBroadcastMessage('Mostrando compras frecuentes de ' .. P:GetName()..'.')
            
            repeat
                local item_entry    = frecuently_bought_items:GetUInt32(0);
                local item_buyprice = (frecuently_bought_items:GetUInt32(1) == 0) and FLAT_PRICE or frecuently_bought_items:GetUInt32(1);
                local item_maxcount = frecuently_bought_items:GetUInt32(2);
                local item_unique   = (item_maxcount == 1) and true or false
                local item_link     = GetItemLink(item_entry, 7)
                local price_show    = formatCurrency(item_buyprice * GLOBAL_RATE_COEFFICIENT);

                P:GossipMenuAddItem(0, getIcon(item_entry).. item_link .. ' |cff752f00' .. price_show, item_entry, conteo, true, 'Ingresa la cantidad que quieres comprar.')

                table.insert(ITEMS_IDS, item_entry)
                table.insert(ITEMS_PRICES, item_buyprice)
                table.insert(ITEMS_MAXCOUNTS, item_maxcount)
                table.insert(ITEMS_UNIQUES, item_unique)
                P:SendBroadcastMessage(conteo .. '. ' .. item_link) -- .. ' ' .. price_show)
                conteo = conteo + 1 

            until not frecuently_bought_items:NextRow();

            P:GossipMenuAddItem(0, '< Regresar a la búsqueda', 6, 0)
            P:GossipSendMenu(1, U)
        else    
            P:GossipComplete();
            P:SendBroadcastMessage('|cffff0000No tienes registros de compras frecuentes.')
        end
        return
    end

    -- Ver registros
    if (send == 4) then
        if (option == 0) then
            local playerID = P:GetGUIDLow()
            local check_log = WorldDBQuery( QQ.SELECT_ONE_FROM_LOG_BY_PLAYER_ID(playerID) );

            if check_log then
                local Q = WorldDBQuery( QQ.SELECT_LAST_20_FROM_LOG_BY_PLAYER_ID(playerID) )

                P:SendBroadcastMessage('Mostrando los últimos registros de ' .. P:GetName() .. '.')

                local counter = 1
                repeat
                    local cantidad = Q:GetUInt32(0)
                    local itemID = Q:GetUInt32(1)
                    local fecha = Q:GetString(2)
                    local gasto = formatCurrency(Q:GetUInt32(3))

                    P:SendBroadcastMessage(counter .. '. ' .. cantidad .. '× '..  GetItemLink(itemID, 7) .. ' por ' .. gasto .. ' / '   .. fecha)
                    counter = counter + 1
                until not Q:NextRow();
            else
                P:SendBroadcastMessage('|cffff0000Aún no has comprado ningún objeto.')
            end
        end
        P:GossipComplete()
        return
    end


    -- Checkear la entrada por caracteres maliciosos
    if hasForbiddenChars(raw_input) then
        P:SendBroadcastMessage('|cffff0000[Error]: No se puede realizar la búsqueda con esos caracteres.')
        P:GossipComplete()
        return
    else
        -- Búsqueda de objeto
        if (send + option == 0) then
            -- El NPC avisa al jugador que ha iniciado la busqueda con las palabras clave
            U:SendUnitSay('Buscando "' .. raw_input .. '" para ' .. P:GetName() .. '...', 0)

            local Q = WorldDBQuery( QQ.SELECT_ITEM_BY_NAME(raw_input));

            local conteo = 1

            if Q then
                P:SendBroadcastMessage('Mostrando resultados para "|cff00ff00' .. raw_input .. '|r"')

                -- Pasamos agua, jabón y lejía
                ITEMS_IDS       = {}
                ITEMS_PRICES    = {}
                ITEMS_MAXCOUNTS = {}
                ITEMS_UNIQUES   = {}

                repeat -- Bloque iterativo
                    -- 0:entry, 1:name (NO SE USA), 2:buyPrice, 3:maxCount
                    local item_entry    = Q:GetUInt32(0)
                    local item_buyPrice = (Q:GetUInt32(2) == 0) and FLAT_PRICE or Q:GetUInt32(2)
                    local item_maxCount = Q:GetUInt32(3)
                    local price_show    = formatCurrency(item_buyPrice * GLOBAL_RATE_COEFFICIENT);
                    local isUnique      = (item_maxCount == 1) and true or false
                    local item_link     = GetItemLink(item_entry, 7);

                    P:GossipMenuAddItem(0, getIcon(item_entry) .. item_link .. ' |cff752f00' .. price_show .. '|r', item_entry, conteo, true, 'Ingresa la cantidad que quieres comprar.')

                    -- print(item_link)

                    -- Guardamos los precios solamente de los objetos que se mostrarán en el diálogo final.
                    table.insert(ITEMS_IDS, item_entry)
                    table.insert(ITEMS_PRICES, item_buyPrice)
                    table.insert(ITEMS_MAXCOUNTS, item_maxCount)
                    table.insert(ITEMS_UNIQUES, isUnique)       

                    P:SendBroadcastMessage(conteo .. '. ' .. item_link .. ' ' .. price_show)                   
                    conteo = conteo + 1
                until not Q:NextRow();

                local plural = (conteo <= 2) and 'encontró un objeto' or 'encontraron ' .. (conteo - 1) .. ' objetos '

                P:SendBroadcastMessage('--------- Se ' .. plural .. ' ------------')
                P:GossipMenuAddItem(0, '< Regresar a la búsqueda', 6, 0)
                P:GossipSendMenu(1, U)
            else
                P:SendBroadcastMessage('No se encontraron resultados...')
                P:GossipComplete()
                return
            end
        end
    end

    -- Lógica de compras
    if (option > 0) and (option < 10) then
        local item_id       = send
        local item_price    = ITEMS_PRICES[option]
        local item_maxCount = ITEMS_MAXCOUNTS[option]
        local is_unique     = ITEMS_UNIQUES[option]
        local item_link     = GetItemLink(item_id, 7)

        P:SendBroadcastMessage('Selección: ' .. item_link)
        P:SendBroadcastMessage('Precio unitario: ' .. formatCurrency(item_price))

        local input = (tonumber(raw_input) and math.floor(tonumber(raw_input)) >= 1) and math.floor(tonumber(raw_input)) or 0;

        -- Limitamos la entrada a 200 unidades
        input = (input > 200) and 200 or input

        -- El jugador ingresó un número correcto
        if (input >= 1) then
            local player_money = P:GetCoinage();
            local amount = item_price * GLOBAL_RATE_COEFFICIENT * input;
            local playerID = P:GetGUIDLow();

            if (player_money >= amount) then -- El jugador tiene dinero
                local pago = formatCurrency(item_price * GLOBAL_RATE_COEFFICIENT * input)

                if is_unique then -- El objeto es único
                    -- El jugador desea comprar un objeto único que ya posee
                    if P:HasItem(item_id) then
                        P:SendBroadcastMessage('|cffff0000No puedes llevar más de ese objeto único.')
                        P:GossipComplete()
                        return
                    else -- El jugador no posee el objeto único que desea comprar
                        local single_purchase = item_price * GLOBAL_RATE_COEFFICIENT

                        P:ModifyMoney(-single_purchase)
                        P:AddItem(item_id, 1)
                        P:SendBroadcastMessage('|cff00ff00Has comprado 1× ' .. item_link .. ' |cff00ff00por |cffff00ff' .. pago)
                        WorldDBExecute( QQ.INSERT_INTO_LOG(playerID, item_id, 1, single_purchase) )
                    end
                else -- El objeto NO es único así que la compra solo es limitada por la cantidad de oro del jugador
                    P:ModifyMoney(-amount)
                    P:AddItem(item_id, input)
                    P:SendBroadcastMessage('|cff00ff00Has comprado ' .. input .. '× ' .. item_link .. ' |cff00ff00por |cffff00ff' .. pago)

                    WorldDBExecute( QQ.INSERT_INTO_LOG(playerID, item_id, input, amount) )
                end
                U:SendUnitSay(P:GetName() .. ' ha comprado ' .. input .. '× ' .. item_link, 0)

                WorldDBExecute( QQ.INSERT_OR_UPDATE_FREQUENT_PURCHASE(item_id, item_price, item_maxCount, playerID))

            else -- El jugador no tiene dinero
                P:SendBroadcastMessage('|cffff0000No tienes suficiente dinero para esa compra.')
            end
        else -- El jugador ingresó un número incorrecto
            P:SendBroadcastMessage('|cffff0000Ingresa un número entero positivo.')
        end
        P:GossipComplete()
    end
end

local function AL_RECARGAR_ELUNA(e)
    WorldDBExecute(QQ.CREATE_ITEM_TABLE())
    WorldDBExecute(QQ.CREATE_LOG_TABLE())
    WorldDBExecute(QQ.CREATE_FRECUENT_TABLE())
    WorldDBExecute(QQ.CREATE_FIXED_AMOUNT_TABLE())
    WorldDBExecute(QQ.CREATE_GLOBAL_RATE_TABLE())
end

RegisterCreatureGossipEvent(60000, 1, CLICK_1)
RegisterCreatureGossipEvent(60000, 2, CLICK_2)
RegisterServerEvent(33, AL_RECARGAR_ELUNA)
