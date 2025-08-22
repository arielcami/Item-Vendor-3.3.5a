-- NPC MICHAEL JACKSON
SET 
@ENTRY = 60000,
@MODEL = 16540,
@DISPLAY_SCALE = 1,
@NAME = 'Michael Jackson',
@GUILD = 'Vendedor de Objetos',
@LEVEL = 83,
@NPC_FLAG = 1,
@SCALE = 1,
@RANK = 3,
@UNIT_CLASS = 8,
@FAMILY = 0, -- Beast type
@TYPE = 7,
@TYPE_FLAGS = 4,
@HEALTH = 450,
@MANA = 450,
@ARMOR = 4;

DELETE FROM creature_template WHERE `entry` = @ENTRY;
DELETE FROM creature_template_model WHERE CreatureID = @ENTRY;

INSERT INTO creature_template (
`entry`, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, `name`, subname, IconName, gossip_menu_id, 
minlevel, maxlevel, `exp`, faction, npcflag, speed_walk, speed_run, speed_swim, speed_flight, detection_range, 
scale, `rank`, dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance, unit_class, unit_flags, 
unit_flags2, dynamicflags, family, trainer_type, trainer_spell, trainer_class, trainer_race, `type`, type_flags, lootid, 
pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, 
ManaModifier, ArmorModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, spell_school_immune_mask, flags_extra, ScriptName, 
VerifiedBuild) 
VALUES 
(@ENTRY, 0, 0, 0, 0, 0, @NAME, @GUILD, NULL, 0, 
@LEVEL, @LEVEL, 2, 35, @NPC_FLAG, 1, 1, 1, 1, 20, 
@SCALE, @RANK, 0, 1, 2000, 2000, 1, 1, @UNIT_CLASS, 0, 
0, 0, @FAMILY, 0, 0, 0, 0, @TYPE, @TYPE_FLAGS, 0, 
0, 0, 0, 0, 0, 0, '', 0, 1, @HEALTH, 
@MANA, @ARMOR, 1, 0, 0, 1, 0, 0, 0, '', 
12340);

INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
VALUES (@ENTRY, 0, @MODEL, @DISPLAY_SCALE, 1, 12340);


-- NPC CONFIGURADOR
SET 
@ENTRY = 60001,
@MODEL = 16540,
@DISPLAY_SCALE = 1,
@NAME = 'Configurador',
@GUILD = 'Ajustes del Item Vendor',
@LEVEL = 83,
@NPC_FLAG = 1,
@SCALE = 1,
@RANK = 3,
@UNIT_CLASS = 8,
@FAMILY = 0, -- Beast type
@TYPE = 7,
@TYPE_FLAGS = 4,
@HEALTH = 450,
@MANA = 450,
@ARMOR = 4;

DELETE FROM creature_template WHERE `entry` = @ENTRY;
DELETE FROM creature_template_model WHERE CreatureID = @ENTRY;

INSERT INTO creature_template (
`entry`, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, KillCredit1, KillCredit2, `name`, subname, IconName, gossip_menu_id, 
minlevel, maxlevel, `exp`, faction, npcflag, speed_walk, speed_run, speed_swim, speed_flight, detection_range, 
scale, `rank`, dmgschool, DamageModifier, BaseAttackTime, RangeAttackTime, BaseVariance, RangeVariance, unit_class, unit_flags, 
unit_flags2, dynamicflags, family, trainer_type, trainer_spell, trainer_class, trainer_race, `type`, type_flags, lootid, 
pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, HealthModifier, 
ManaModifier, ArmorModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, spell_school_immune_mask, flags_extra, ScriptName, 
VerifiedBuild) 
VALUES 
(@ENTRY, 0, 0, 0, 0, 0, @NAME, @GUILD, NULL, 0, 
@LEVEL, @LEVEL, 2, 35, @NPC_FLAG, 1, 1, 1, 1, 20, 
@SCALE, @RANK, 0, 1, 2000, 2000, 1, 1, @UNIT_CLASS, 0, 
0, 0, @FAMILY, 0, 0, 0, 0, @TYPE, @TYPE_FLAGS, 0, 
0, 0, 0, 0, 0, 0, '', 0, 1, @HEALTH, 
@MANA, @ARMOR, 1, 0, 0, 1, 0, 0, 0, '', 
12340);


INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
VALUES (@ENTRY, 0, @MODEL, @DISPLAY_SCALE, 1, 12340);