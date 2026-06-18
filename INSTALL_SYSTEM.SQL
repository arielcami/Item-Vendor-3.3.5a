CREATE TABLE `a_itemvendor` (
    `entry` INT UNSIGNED NOT NULL,
    `name` VARCHAR(80) NOT NULL,
    `buyPrice` INT UNSIGNED NOT NULL,
    `maxCount` INT UNSIGNED NOT NULL,
    `stackable` INT UNSIGNED NOT NULL DEFAULT 1,
    `state` TINYINT NOT NULL DEFAULT 1,
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `a_itemvendor_log` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `player_id` INT UNSIGNED NOT NULL,
    `item_id` MEDIUMINT UNSIGNED NOT NULL,
    `amount` MEDIUMINT UNSIGNED NOT NULL,
    `expense` INT UNSIGNED NOT NULL,
    `purchase_time` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    `state` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_player_state_time` (`player_id`, `state`, `purchase_time` DESC),
    KEY `idx_item_id` (`item_id`),
    KEY `idx_state_time` (`state`, `purchase_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `a_itemvendor_frequent` (
    `entry` INT UNSIGNED NOT NULL,
    `buyPrice` INT UNSIGNED NOT NULL,
    `maxCount` TINYINT UNSIGNED NOT NULL,
    `times` INT UNSIGNED NOT NULL DEFAULT 1,
    `player_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`entry`, `player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `a_itemvendor_fixed_amount` (
    `id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `amount` INT UNSIGNED NOT NULL DEFAULT 10000,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `a_itemvendor_fixed_amount` (`id`, `amount`) VALUES (1, 10000);

CREATE TABLE `a_itemvendor_global_rate` (
    `id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `rate` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `a_itemvendor_global_rate` (`id`, `rate`) VALUES (1, 1);

CREATE TABLE `a_itemvendor_blacklist` (
    `id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `a_itemvendor_gm_log` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `gm_id` INT UNSIGNED NOT NULL,
    `action` ENUM('ADD', 'EDIT', 'DELETE', 'CONFIG', 'POPULATE') NOT NULL,
    `item_id` INT UNSIGNED DEFAULT NULL,
    `old_value` TEXT,
    `new_value` TEXT,
    `timestamp` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_gm_id` (`gm_id`),
    KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `a_itemvendor_config` (
    `id` SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `config_name` VARCHAR(100) NOT NULL,
    `config_value` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `config_name` (`config_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
