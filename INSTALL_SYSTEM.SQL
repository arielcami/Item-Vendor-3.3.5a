-- Tabla principal del vendedor
CREATE TABLE IF NOT EXISTS a_itemvendor (
    entry INT UNSIGNED NOT NULL PRIMARY KEY, 
    `name` VARCHAR(80) NOT NULL, 
    buyPrice INT UNSIGNED NOT NULL, 
    maxCount INT UNSIGNED NOT NULL,
    stackable INT UNSIGNED NOT NULL DEFAULT 1,
    `state` TINYINT NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de logs de compras
CREATE TABLE IF NOT EXISTS a_itemvendor_log (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
    player_id INT UNSIGNED NOT NULL, 
    item_id MEDIUMINT UNSIGNED NOT NULL, 
    amount MEDIUMINT UNSIGNED NOT NULL, 
    expense INT UNSIGNED NOT NULL, 
    purchase_time TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de compras frecuentes
CREATE TABLE IF NOT EXISTS a_itemvendor_frequent (
    entry INT UNSIGNED NOT NULL, 
    buyPrice INT UNSIGNED NOT NULL, 
    maxCount TINYINT UNSIGNED NOT NULL, 
    `times` INT UNSIGNED NOT NULL DEFAULT '1', 
    player_id INT UNSIGNED NOT NULL, 
    UNIQUE KEY `uniq_entry_player` (`entry`, `player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de precio base (para items con buyPrice = 0)
CREATE TABLE IF NOT EXISTS a_itemvendor_fixed_amount (
    id TINYINT UNSIGNED NOT NULL DEFAULT 1,
    amount INT UNSIGNED NOT NULL DEFAULT 10000,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO a_itemvendor_fixed_amount (id, amount) VALUES (1, 10000);

-- Tabla de multiplicador global de precios
CREATE TABLE IF NOT EXISTS a_itemvendor_global_rate (
    id TINYINT UNSIGNED NOT NULL DEFAULT 1,
    rate TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO a_itemvendor_global_rate (id, rate) VALUES (1, 1);

-- Tabla de lista negra (items excluidos)
CREATE TABLE IF NOT EXISTS a_itemvendor_blacklist (
    id INT UNSIGNED NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de auditoría de acciones de GM
CREATE TABLE IF NOT EXISTS a_itemvendor_gm_log (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    gm_id INT UNSIGNED NOT NULL,
    action ENUM('ADD', 'EDIT', 'DELETE', 'CONFIG', 'POPULATE') NOT NULL,
    item_id INT UNSIGNED NULL,
    old_value TEXT NULL,
    new_value TEXT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO a_itemvendor_blacklist (id) VALUES 
(24477),(24476),(33470),(21877),(28430),(40553),(41257),(41383),(41384),(44926),
(44948),(30732),(30724),(31318),(34622),(31342),(31322),(31336),(31334),(31332),
(31331),(31323),(20698),(45173),(45172),(45174),(45175),(38497),(38496),(38498),
(27965),(34025),(34030),(37126),(28388),(28389),(17882),(17887),(22023),(22024),
(22584),(29841),(29868),(29871),(14891),(1442),(26173),(26174),(26175),(26180),
(26235),(26324),(26368),(26372),(26464),(26465),(26548),(26655),(26738),(26792),
(26843),(27196),(27218),(37301),(38292),(39163),(45575),(138),(931),(2275),
(2588),(2599),(3884),(3934),(5632),(40754),(40948),(43336),(43337),(43384),
(31266),(27774),(27811),(28117),(28122),(41403),(41404),(41405),(41406),(41407),
(41408),(41409),(41410),(41411),(41412),(41413),(41414),(41415),(41416),(41417),
(41418),(41419),(41420),(41421),(41422),(41423),(43362),(45908),(21038),(32722),
(33226),(34062),(34599),(38294),(38518),(42986),(43523),(46783),(54822),(52252),
(996),(1020),(1021),(1024),(1025),(1027),(1162),(5235);
