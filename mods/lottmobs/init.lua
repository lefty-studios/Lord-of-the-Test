lottmobs = {}

local split = function(str, sep)
        local fields = {}
        local str = str or ""
        local sep = sep or ";"
        for word in string.gmatch(str, '([^'..sep..']+)') do
                fields[#fields + 1] = word
        end
        return fields
end

local value_in_table = function(tab, val)
        for index, value in ipairs(tab) do
                if value == val then
                        return true
                end
        end
        return false
end

lottmobs.do_custom_guard = function(guard)
	if guard.owner and guard.owner ~= "" then
		local player, entity_type, obj, min_player = nil, nil, nil, nil
		local min_dist = guard.view_range + 1
		local objs = minetest.get_objects_inside_radius(guard.object:getpos(), guard.view_range)
		for n = 1, #objs do

			if objs[n]:is_player() then
				player = objs[n]
				entity_type = "player"
			end

			if entity_type == "player" then

				s = guard.object:getpos()
				p = player:getpos()
				sp = s

				-- aim higher to make looking up hills more realistic
				p.y = p.y + 1
				sp.y = sp.y + 1

				local x, y, z = p.x - s.x, p.y - s.y, p.z - s.z
				dist = math.sqrt(x * x + y * y + z * z)

				if dist < guard.view_range then

					-- choose closest player to attack
					if line_of_sight_water(guard, sp, p, 2) == true
					and dist < min_dist
					and player:get_player_name() ~= guard.owner then
						min_dist = dist
						min_player = player
					end
				end
			end
		end

	                -- attack player
	    if min_player and guard.whitelist
		and not value_in_table(guard.whitelist, min_player:get_player_name()) then
	        local is_elf = minetest.check_player_privs(min_player, "GAMEelf")
	        local is_man = minetest.check_player_privs(min_player, "GAMEman")
	        local is_orc = minetest.check_player_privs(min_player, "GAMEorc")
	        local is_hobbit = minetest.check_player_privs(min_player, "GAMEhobbit")
	        local is_dwarf = minetest.check_player_privs(min_player, "GAMEdwarf")
	        if (guard.attack_elves and is_elf)
			or (guard.attack_men and is_man)
			or (guard.attack_orcs and is_orc)
			or (guard.attack_hobbits and is_hobbit)
			or (guard.attack_dwarves and is_dwarf)
			or (guard.blacklist
			and value_in_table(guard.blacklist, min_player:get_player_name())) then
	            guard.state = "attack"
	            guard.attack = min_player
	        end
	    end
	end
end

local attacks = {
	"attack_monsters",
	"attack_elves",
	"attack_men",
	"attack_orcs",
	"attack_hobbits",
	"attack_dwarves"
}

local get_guard_formspec = function(self)
    local selected_idx = 1
	if self.whitelist == nil then
		self.whitelist = {}
	end
	if self.blacklist == nil then
		self.blacklist = {}
	end
    if order == "stand" then selected_idx = 2 end
    return "size[10,9]"..
        "label[1,1;Name:\t"..self.game_name.."]"..
        "dropdown[1,2;2;order;follow,stand;"..selected_idx.."]"..
        "checkbox[1,3;attack_elves;Attack Elves;"..tostring(self.attack_elves).."]"..
        "checkbox[1,4;attack_men;Attack Men;"..tostring(self.attack_men).."]"..
        "checkbox[4,2;attack_orcs;Attack Orcs;"..tostring(self.attack_orcs).."]"..
        "checkbox[4,3;attack_hobbits;Attack Hobbits;"..tostring(self.attack_hobbits).."]"..
        "checkbox[4,4;attack_dwarves;Attack Dwarves;"..tostring(self.attack_dwarves).."]"..
        "checkbox[7,2;attack_monsters;Attack Monsters;"..tostring(self.attack_monsters).."]"..
        "field[1,6;9,1;whitelist;Whitelist;"..
		minetest.formspec_escape(table.concat(self.whitelist, ";")).."]"..
        "field[1,7;9,1;blacklist;Blacklist;"..
		minetest.formspec_escape(table.concat(self.blacklist, ";")).."]"..
        "button_exit[1,8;2,1;exit_button; Proceed]"
end

lottmobs.guard = function(self, clicker, payment, mob_name, race)
    lottmobs.change_settings = function(fields)
        if fields.order then
            self.order = fields.order
        end
        for i, v in pairs(attacks) do
            if fields[v] == "true" then
				self[v] = true
            elseif fields[v] == "false" then
				self[v] = nil
            end
        end
        if fields.whitelist then
            self.whitelist = split(fields.whitelist, ";")
        end
        if fields.blacklist then
            self.blacklist = split(fields.blacklist, ";")
        end
	end
	local item = clicker:get_wielded_item()
	local name = clicker:get_player_name()
	if item:get_name() == "lottfarming:corn"
	or item:get_name() == "farming:bread" then
		local hp = self.object:get_hp()
		if hp >= self.hp_max then
			minetest.chat_send_player(name, "NPC at full health.")
			return
		end
		hp = hp + 4
		if hp > self.hp_max then hp = self.hp_max end
		self.object:set_hp(hp)
		if not minetest.setting_getbool("creative_mode") then
			item:take_item()
			clicker:set_wielded_item(item)
		end
	elseif item:get_name() == payment and self.tamed == false then
		lottmobs.face_pos(self, clicker:getpos())
		self.state = "stand"
		minetest.show_formspec(name, "mob_hiring", lottmobs.hiring)
		lottmobs.hire = function(cost)
			if math.random(1, (50/cost)) == 1 then
				minetest.chat_send_player(name, "[NPC] <" .. mob_name .. "> Okay, I'll work for you.")
				local count = item:get_count()
				if count > cost or minetest.setting_getbool("creative_mode") then
					if not minetest.setting_getbool("creative_mode") then
						item:take_item(cost)
						clicker:set_wielded_item(item)
					end
					self.tamed = true
					if not self.owner or self.owner == "" then
						self.owner = clicker:get_player_name()
					end
					self.order = "follow"
					self.attack_monsters = true
					minetest.after(1, function()
						minetest.show_formspec(name, "mob_naming", "field[naming;Name your guard:;]")
					end
				else
					minetest.chat_send_player(name, "[NPC] <" .. mob_name .. "> What, you don't have that much money?! Stop wasting my time!")
				end
			else
				local rand = math.random(1, 5)
				if rand == 1 then
					minetest.chat_send_player(name, "[NPC] <" .. mob_name .. "> Stop bothering me!")
					self.object:remove()
				elseif rand == 2 then
					minetest.chat_send_player(name, "[NPC] <" .. mob_name .. "> Are you mocking me? I don't take kindly to mockers!")
					self.state = "attack"
					self.attack = clicker
				elseif rand == 3 then
					minetest.chat_send_player(name, "[NPC] <" .. mob_name .. "> Your joking, right? Oh, you're serious? Well, to let you know, I won't be working for you for that pitiful amount.")
				else
					minetest.chat_send_player(name, "[NPC] <" .. mob_name .. "> Do you really think I'll work for you for that much?!")
				end
			end
		end
		lottmobs.name = function(name)
			self.game_name = name
			self.nametag = name
			update_tag(self)
		end
	elseif self.owner and self.owner == name then
		minetest.show_formspec(name, "mob_settings", get_guard_formspec(self))
	else
		if self.game_name == "mob" then
			self.game_name = lottmobs[race]["names"][math.random(1, #lottmobs[race]["names"])]
		end
		minetest.chat_send_player(name, "[NPC] <" .. self.game_name .. "> " ..
			lottmobs[race]["messages"][math.random(1, #lottmobs[race]["messages"])])
	end
end

dofile(minetest.get_modpath("lottmobs").."/craftitems.lua")
dofile(minetest.get_modpath("lottmobs").."/elves.lua")
dofile(minetest.get_modpath("lottmobs").."/dwarfs.lua")
dofile(minetest.get_modpath("lottmobs").."/horse.lua")
dofile(minetest.get_modpath("lottmobs").."/trader_goods.lua")
dofile(minetest.get_modpath("lottmobs").."/trader.lua")
dofile(minetest.get_modpath("lottmobs").."/special_mobs.lua")
-- Mobs

mobs:register_mob("lottmobs:chicken", {
	type = "animal",
	hp_min = 5,
	hp_max = 10,
	collisionbox = {-0.3,0,-0.3, 0.3,0.8,0.3},
	textures = {
		{"lottmobs_chicken.png"},
	},
	visual = "mesh",
	mesh = "chicken_model.x",
	makes_footstep_sound = true,
	walk_velocity = 1,
	armor = 300,
		drops = {
		{name = "lottmobs:meat_raw",
		chance = 1,
		min = 1,
		max = 3,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 10,
	light_damage = 0,
	animation = {
		speed_normal = 10,
		speed_run = 15,
		stand_start = 0,
		stand_end = 0,
		sit_start = 1,
		sit_end = 9,
		walk_start = 10,
		walk_end = 50,
	},
	jump = true,
	step=1,
	passive = true,
	sounds = {
	},
})
mobs:register_spawn("lottmobs:chicken", {"lottmapgen:gondor_grass"}, 20, -1, 6000, 3, 31000)
mobs:register_spawn("lottmobs:chicken", {"lottmapgen:dunland_grass"}, 20, -1, 6000, 3, 31000)
mobs:register_spawn("lottmobs:chicken", {"lottmapgen:rohan_grass"}, 20, -1, 6000, 3, 31000)
mobs:register_spawn("lottmobs:chicken", {"lottmapgen:shire_grass"}, 20, -1, 5000, 3, 31000)

mobs:register_mob("lottmobs:ent", {
	type = "npc",
	hp_min = 50,
	hp_max = 70,
	collisionbox = {-0.5, 0, -0.5, 0.5, 5, 0.5},
	textures = {
		{"lottmobs_ent.png"},
	},
	visual_size = {x=3.5,y=3.5},
	visual = "mesh",
	mesh = "ent_model.x",
	view_range = 20,
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 1.5,
	armor = 100,
	damage = 5,
	drops = {
		{name = "default:sapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:aldersapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:applesapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:birchsapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:beechsapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:culumaldasapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:elmsapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:lebethronsapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:plumsapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:rowansapling",
		chance = 5,
		min = 1,
		max = 3,},
		{name = "lottplants:yavannamiresapling",
		chance = 250,
		min = 1,
		max = 1,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 0,
	lava_damage = 60,
	light_damage = 0,
	attack_type = "dogfight",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 17,
		stand_end = 17,
		walk_start = 10,
		walk_end = 80,
		run_start = 10,
		run_end = 80,
		punch_start = 1,
		punch_end = 1,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "mobs_yeti_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,

})
mobs:register_spawn("lottmobs:ent", {"lottmapgen:fangorn_grass"}, 20, -1, 6000, 3, 31000)

mobs:register_mob("lottmobs:spider", {
	type = "monster",
	hp_min = 20,
	hp_max = 40,
	collisionbox = {-0.9, -0.01, -0.7, 0.7, 0.6, 0.7},
	textures = {
		{"lottmobs_spider.png"},
		{"lottmobs_spider_1.png"},
		{"lottmobs_spider_2.png"},
	},
	visual_size = {x=7,y=7},
	visual = "mesh",
	mesh = "spider_model.x",
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	run_velocity = 3,
	armor = 200,
	damage = 3,
	drops = {
		{name = "farming:string",
		chance = 3,
		min = 1,
		max = 6,},
		{name = "wool:white",
		chance = 10,
		min = 1,
		max = 3,},
		{name = "lottmobs:meat_raw",
		chance = 5,
		min = 1,
		max = 2,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 5,
	lava_damage = 5,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 1,
		stand_end = 1,
		walk_start = 20,
		walk_end = 40,
		run_start = 20,
		run_end = 40,
		punch_start = 50,
		punch_end = 90,
	},
	on_rightclick = function(self, clicker)
		local player_inv = clicker:get_inventory()
		local item = clicker:get_wielded_item()
		if item:get_name() == "vessels:glass_bottle" then
			if player_inv:room_for_item("main", 1) then
                item:take_item(1)
                player_inv:add_item("main", "lottmobs:spiderpoison")
            end
			clicker:set_wielded_item(item)
		end
	end,
	jump = true,
	sounds = {
		war_cry = "mobs_spider",
		death = "mobs_howl",
		attack = "mobs_oerkki_attack",
	},
	step = 1,
})
mobs:register_spawn("lottmobs:spider", {"lottmapgen:mirkwood_grass"}, 20, -10, 6000, 3, 31000)

mobs:register_mob("lottmobs:rohan_guard", {
	type = "npc",
	hp_min = 20,
	hp_max = 30,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	textures = {
		{"lottmobs_rohan_guard.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_rohan_guard_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_rohan_guard_2.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_rohan_guard_3.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	makes_footstep_sound = true,
	view_range = 12,
	walk_velocity = 2,
	run_velocity = 3.5,
	armor = 100,
	damage = 5,
	drops = {
		{name = "lottmobs:horseh1",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "default:bronze_ingot",
		chance = 7,
		min = 1,
		max = 5,},
		{name = "lottmobs:horsepeg1",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottmobs:horsearah1",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "default:steel_sword",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottores:galvornsword",
		chance = 35,
		min = 1,
		max = 1,},
		{name = "lottweapons:steel_spear",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottarmor:helmet_bronze",
		chance = 30,
		min = 1,
		max = 1,},
		{name = "lottarmor:chestplate_steel",
		chance = 27,
		min = 1,
		max = 1,},
		{name = "lottarmor:leggings_tin",
		chance = 25,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_bronze",
		chance = 30,
		min = 1,
		max = 1,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 10,
	light_damage = 0,
	attack_type = "dogfight",
	follow = "lottother:narya",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	on_rightclick = function(self, clicker)
		lottmobs.guard(self, clicker, "default:gold_ingot", "Rohan Guard", "human")
	end,
	do_custom = function(self, dtime)
		lottmobs.do_custom_guard(self)
	end,
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:rohan_guard", {"lottmapgen:rohan_grass"}, 20, -1, 6000, 3, 31000)

mobs:register_mob("lottmobs:gondor_guard", {
	type = "npc",
	hp_min = 20,
	hp_max = 30,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	textures = {
		{"lottmobs_gondor_guard.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_gondor_guard_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_gondor_guard_2.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_gondor_guard_3.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	makes_footstep_sound = true,
	view_range = 12,
	walk_velocity = 2,
	run_velocity = 3.5,
	armor = 100,
	damage = 5,
	drops = {
		{name = "lottweapons:galvorn_warhammer",
		chance = 35,
		min = 1,
		max = 1,},
		{name = "default:steel_ingot",
		chance = 10,
		min = 2,
		max = 5,},
		{name = "lottweapons:galvorn_battleaxe",
		chance = 35,
		min = 1,
		max = 1,},
		{name = "default:steel_sword",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottplants:whitesapling",
		chance = 250,
		min = 1,
		max = 1,},
		{name = "lottweapons:steel_battleaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:steel_warhammer",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottarmor:helmet_steel",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:chestplate_steel",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:leggings_steel",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_steel",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:helmet_galvorn",
		chance = 50,
		min = 1,
		max = 1,},
		{name = "lottarmor:chestplate_galvorn",
		chance = 50,
		min = 1,
		max = 1,},
		{name = "lottarmor:leggings_galvorn",
		chance = 50,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_galvorn",
		chance = 50,
		min = 1,
		max = 1,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 5,
	light_damage = 0,
	attack_type = "dogfight",
	follow = "lottother:narya",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	on_rightclick = function(self, clicker)
		lottmobs.guard(self, clicker, "default:gold_ingot", "Gondor Guard", "human")
	end,
	do_custom = function(self, dtime)
		lottmobs.do_custom_guard(self)
	end,
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:gondor_guard", {"lottmapgen:gondor_grass"}, 20, -1, 6000, 3, 31000)

mobs:register_mob("lottmobs:ithilien_ranger", {
	type = "npc",
	hp_min = 25,
	hp_max = 40,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	textures = {
		{"lottmobs_ithilien_ranger.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_ithilien_ranger.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottclothes_cloak_ranger.png"},
		{"lottmobs_ithilien_ranger_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_ithilien_ranger_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottclothes_cloak_ranger.png"},
	},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	makes_footstep_sound = true,
	view_range = 16,
	walk_velocity = 2.5,
	run_velocity = 4,
	armor = 100,
	damage = 6,
	drops = {
		{name = "default:steel_ingot",
		chance = 10,
		min = 2,
		max = 5,},
		{name = "lottweapons:galvorn_battleaxe",
		chance = 50,
		min = 1,
		max = 1,},
		{name = "default:steel_sword",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:steel_spear",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:steel_dagger",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottclothes:cloak_ranger",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottclothes:cap_chetwood",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottclothes:jacket_chetwood",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottclothes:pants_chetwood",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottclothes:boots_chetwood",
		chance = 20,
		min = 1,
		max = 1,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 5,
	light_damage = 0,
	attack_type = "dogfight",
	follow = "lottother:narya",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	on_rightclick = function(self, clicker)
		lottmobs.guard(self, clicker, "default:gold_ingot", "Ithilien Ranger", "human")
	end,
	do_custom = function(self, dtime)
		lottmobs.do_custom_guard(self)
	end,
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:ithilien_ranger", {"lottmapgen:ithilien_grass"}, 20, -1, 6000, 3, 31000)

mobs:register_mob("lottmobs:dunlending", {
	type = "monster",
	hp_min = 17,
	hp_max = 27,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	textures = {
		{"lottmobs_dunlending.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_dunlending_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_dunlending_2.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_dunlending_3.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	armor = 200,
	run_velocity = 3,
	damage = 3,
	drops = {
		{name = "lottores:tinpick",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottores:tinaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottores:tinshovel",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottores:tinspear",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:tin_battleaxe",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottweapons:tin_spear",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottweapons:tin_warhammer",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottweapons:tin_dagger",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottarmor:helmet_tin",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:chestplate_tin",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:leggings_tin",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_tin",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottmobs:dirty_trousers",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottmobs:dirty_shirt",
		chance = 10,
		min = 1,
		max = 1,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 5,
	lava_damage = 5,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_barbarian_yell2",
		death = "mobs_barbarian_death",
		attack = "default_punch2",
	},
	step = 1,
})
mobs:register_spawn("lottmobs:dunlending", {"lottmapgen:dunland_grass"}, 20, -1, 6000, 3, 31000)

mobs:register_mob("lottmobs:hobbit", {
	type = "animal",
	hp_min = 5,
	hp_max = 15,
	collisionbox = {-0.3,-0.75,-0.3, 0.3,0.7,0.3},
	textures = {
		{"lottmobs_hobbit.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_hobbit_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_hobbit_2.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_hobbit_3.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	visual_size = {x=1, y=0.75},
	makes_footstep_sound = true,
	walk_velocity = 1,
	armor = 300,
	drops = {
		{name = "lottfarming:corn_seed",
		chance = 5,
		min = 3,
		max = 10,},
		{name = "lottfarming:berries_seed",
		chance = 5,
		min = 3,
		max = 10,},
		{name = "lottfarming:barley_seed",
		chance = 5,
		min = 3,
		max = 10,},
		{name = "lottfarming:pipeweed_seed",
		chance = 5,
		min = 3,
		max = 10,},
		{name = "lottfarming:potato_seed",
		chance = 5,
		min = 3,
		max = 10,},
		{name = "lottfarming:pipeweed",
		chance = 10,
		min = 1,
		max = 4,},
		{name = "lottfarming:pipe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottfarming:tomatoes_cooked",
		chance = 15,
		min = 1,
		max = 7,},
		{name = "lottfarming:turnip_cooked",
		chance = 15,
		min = 1,
		max = 7,},
		{name = "lottfarming:melon",
		chance = 15,
		min = 1,
		max = 7,},
		{name = "lottpotion:ale",
		chance = 20,
		min = 1,
		max = 5,},
		{name = "lottpotion:wine",
		chance = 20,
		min = 1,
		max = 5,},
		{name = "lottpotion:beer",
		chance = 20,
		min = 1,
		max = 5,},
		{name = "lottpotion:cider",
		chance = 20,
		min = 1,
		max = 5,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 5,
	light_damage = 0,
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	step=1,
	passive = true,
	sounds = {
	},
})
mobs:register_spawn("lottmobs:hobbit", {"lottmapgen:shire_grass"}, 20, -1, 6000, 3, 31000)

local orc_armor = "lottarmor_chestplate_steel.png^lottarmor_leggings_steel.png^lottarmor_helmet_steel.png^lottarmor_boots_steel.png^lottarmor_shield_steel.png^[colorize:#00000055"

mobs:register_mob("lottmobs:orc", {
	type = "monster",
	hp_min = 15,
	hp_max = 35,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	textures = {
		{"lottmobs_orc.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_orc.png", orc_armor, "lottweapons_orc_sword.png", "lottarmor_trans.png"},
		{"lottmobs_orc.png", orc_armor, "lottweapons_orc_sword.png", "lottclothes_cloak_mordor.png"},
		{"lottmobs_orc_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_orc_1.png", orc_armor, "lottweapons_orc_sword.png", "lottarmor_trans.png"},
		{"lottmobs_orc_1.png", orc_armor, "lottweapons_orc_sword.png", "lottclothes_cloak_mordor.png"},
		{"lottmobs_orc_2.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_orc_2.png", orc_armor, "lottweapons_orc_sword.png", "lottarmor_trans.png"},
		{"lottmobs_orc_2.png", orc_armor, "lottweapons_orc_sword.png", "lottclothes_cloak_mordor.png"},
	},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1.5,
	armor = 200,
	run_velocity = 3,
	damage = 2,
	drops = {
		{name = "bones:bone",
		chance = 5,
		min = 1,
		max = 2,},
		{name = "lottmobs:meat_raw",
		chance = 7,
		min = 1,
		max = 3,},
		{name = "lottfarming:orc_food",
		chance = 17,
		min = 1,
		max = 3,},
		{name = "lottfarming:orc_medicine",
		chance = 17,
		min = 1,
		max = 3,},
		{name = "lottfarming:potato",
		chance = 14,
		min = 1,
		max = 2,},
		{name = "lottfarming:turnip",
		chance = 14,
		min = 1,
		max = 2,},
		{name = "lottfarming:red_mushroom",
		chance = 10,
		min = 1,
		max = 8,},
		{name = "lottclothes:cloak_mordor",
		chance = 17,
		min = 1,
		max = 1,},
		{name = "lottpotion:wine",
		chance = 26,
		min = 1,
		max = 2,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 5,
	lava_damage = 10,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_barbarian_yell1",
		death = "mobs_death1",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:orc", {"lottmapgen:mordor_stone"}, 20, -1, 500, 3, 31000)
mobs:register_spawn("lottmobs:orc", {"default:snowblock"}, 15, -1, 8000, 3, 31000)
mobs:register_spawn("lottmobs:orc", {"default:dirt_with_snow"}, 15, -1, 8000, 3, 31000)
mobs:register_spawn("lottmobs:orc", {"lottmapgen:angsnowblock"}, 20, -1, 6000, 5, 31000)

mobs:register_mob("lottmobs:raiding_orc", {
	type = "monster",
	hp_min = 15,
	hp_max = 35,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	textures = {
		{"lottmobs_orc.png", orc_armor, "lottweapons_orc_sword.png", "lottarmor_trans.png"},
		{"lottmobs_orc_1.png", orc_armor, "lottweapons_orc_sword.png", "lottarmor_trans.png"},
		{"lottmobs_orc_2.png", orc_armor, "lottweapons_orc_sword.png", "lottarmor_trans.png"},
	},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	armor = 200,
	run_velocity = 3,
	damage = 3,
	drops = {
		{name = "lottweapons:orc_sword",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottarmor:helmet_steel",
		chance = 17,
		min = 1,
		max = 1,},
		{name = "lottarmor:chestplate_steel",
		chance = 17,
		min = 1,
		max = 1,},
		{name = "lottarmor:leggings_steel",
		chance = 17,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_steel",
		chance = 17,
		min = 1,
		max = 1,},
		{name = "lottarmor:shield_steel",
		chance = 17,
		min = 1,
		max = 1,},
		{name = "lottmobs:meat_raw",
		chance = 10,
		min = 1,
		max = 3,},
		{name = "lottfarming:orc_food",
		chance = 20,
		min = 1,
		max = 3,},
		{name = "farming:bread",
		chance = 10,
		min = 1,
		max = 3,},
		{name = "lottpotion:wine",
		chance = 25,
		min = 1,
		max = 5,},
		{name = "lottfarming:potato",
		chance = 10,
		min = 1,
		max = 5,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 5,
	lava_damage = 10,
	light_damage = 2,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_barbarian_yell1",
		death = "mobs_death1",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:raiding_orc", {"lottmapgen:ithilien_grass"}, 2, -1, 4000, 5, 31000)
mobs:register_spawn("lottmobs:raiding_orc", {"lottmapgen:rohan_grass"}, 2, -1, 4000, 5, 31000)
mobs:register_spawn("lottmobs:raiding_orc", {"lottmapgen:gondor_grass"}, 2, -1, 4000, 5, 31000)

mobs:register_mob("lottmobs:warg", {
	type = "monster",
	hp_min = 25,
	hp_max = 40,
	collisionbox = {-0.7, -0.75, -0.7, 0.7, 1, 0.7},
	visual_size = {x = 0.8, y = 0.8},
	textures = {
		{"lottmobs_warg.png"},
	},
	visual = "mesh",
	mesh = "warg.b3d",
	makes_footstep_sound = true,
	walk_velocity = 2,
	run_velocity = 5,
	view_range = 16,
	armor = 300,
	drops = {
		{name = "lottmobs:meat_raw",
		chance = 5,
		min = 3,
		max = 10,},
		{name = "lottclothes:felt_grey",
		chance = 5,
		min = 2,
		max = 7,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 5,
	light_damage = 0,
	damage = 8,
	attack_type = "dogfight", --Rather suitible name!
	animation = {
		speed_normal = 15,
		speed_run = 25,
		stand_start = 100,
		stand_end = 260,
		walk_start = 0,
		walk_end = 40,
		run_start = 40,
		run_end = 100,
		punch_start = 260,
		punch_end = 290,
	},
	jump = true,
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
	sounds = {},
})
mobs:register_spawn("lottmobs:warg", {"lottmapgen:mordor_stone"}, 20, -1, 5000, 3, 31000)
mobs:register_spawn("lottmobs:warg", {"default:snowblock"}, 15, -1, 7500, 3, 31000)
mobs:register_spawn("lottmobs:warg", {"lottmapgen:angsnowblock"}, 20, -1, 5000, 5, 31000)

mobs:register_mob("lottmobs:uruk_hai", {
	type = "monster",
	hp_min = 25,
	hp_max = 40,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	textures = {
		{"lottmobs_uruk_hai.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_uruk_hai_1.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_uruk_hai_2.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
		{"lottmobs_uruk_hai_3.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	armor = 100,
	run_velocity = 3,
	damage = 4,
	drops = {
		{name = "default:bronze_sword",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottarmor:helmet_bronze",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:chestplate_bronze",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:leggings_bronze",
		chance = 20,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_bronze",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:bronze_warhammer",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottweapons:bronze_battleaxe",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottweapons:bronze_spear",
		chance = 15,
		min = 1,
		max = 1,},
		{name = "lottfarming:potato",
		chance = 5,
		min = 1,
		max = 5,},
		{name = "lottmobs:meat_raw",
		chance = 5,
		min = 1,
		max = 3,},
	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 1,
	lava_damage = 5,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_barbarian_yell2",
		death = "mobs_death2",
		attack = "mobs_slash_attack",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:uruk_hai", {"lottmapgen:mordor_stone"}, 15, -1, 2000, 3, 31000)
mobs:register_spawn("lottmobs:uruk_hai", {"lottmapgen:fangorn_grass"}, 2, -1, 2000, 3, 31000)

mobs:register_mob("lottmobs:battle_troll", {
	type = "monster",
	hp_min = 45,
	hp_max = 60,
	collisionbox = {-0.7, -0.01, -0.7, 0.7, 2.6, 0.7},
	visual = "mesh",
	mesh = "troll_model.x",
	textures = {
		{"lottmobs_battle_troll.png"},
	},
	visual_size = {x=8, y=8},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	run_velocity = 1,
	damage = 6,
	drops = {
		{name = "bones:bone",
		chance = 5,
		min = 1,
		max = 5,},
		{name = "lottmobs:meat_raw",
		chance = 5,
		min = 1,
		max = 5,},
		{name = "lottweapons:steel_warhammer",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:bronze_warhammer",
		chance = 10,
		min = 1,
		max = 5,},
		{name = "lottweapons:silver_warhammer",
		chance = 10,
		min = 1,
		max = 5,},
		{name = "lottweapons:tin_warhammer",
		chance = 10,
		min = 1,
		max = 5,},
		{name = "lottweapons:copper_warhammer",
		chance = 10,
		min = 1,
		max = 5,},
	},
	light_resistant = true,
	armor = 100,
	drawtype = "front",
	water_damage = 5,
	lava_damage = 1,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		stand_start = 0,
		stand_end = 19,
		walk_start = 20,
		walk_end = 35,
		punch_start = 36,
		punch_end = 48,
		speed_normal = 15,
		speed_run = 15,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_howl",
		death = "mobs_howl",
		attack = "mobs_stone_death",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:battle_troll", {"lottmapgen:mordor_stone"}, 10, -1, 10000, 5, 31000)

mobs:register_mob("lottmobs:half_troll", {
	type = "monster",
	hp_min = 20,
	hp_max = 30,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	textures = {
		{"lottmobs_half_troll.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	run_velocity = 3,
	damage = 4,
	armor = 100,
	drops = {
		{name = "default:sword_steel",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "default:sword_bronze",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottores:coppersword",
		chance = 10,
		min = 1,
		max = 5,},
		{name = "lottores:tinsword",
		chance = 10,
		min = 1,
		max = 5,},
		{name = "lottores:goldsword",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottfarming:potato",
		chance = 10,
		min = 1,
		max = 2,},
		{name = "lottfarming:turnip",
		chance = 10,
		min = 1,
		max = 2,},
		{name = "lottfarming:red_mushroom",
		chance = 7,
		min = 1,
		max = 8,},
		{name = "lottpotion:wine",
		chance = 20,
		min = 1,
		max = 2,},

	},
	light_resistant = true,
	drawtype = "front",
	water_damage = 0,
	lava_damage = 10,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:half_troll", {"default:snow"}, 15, -1, 8000, 3, 31000)
mobs:register_spawn("lottmobs:half_troll", {"default:snowblock"}, 15, -1, 8000, 3, 31000)
mobs:register_spawn("lottmobs:half_troll", {"default:dirt_with_snow"}, 15, -1, 8000, 3, 31000)
mobs:register_spawn("lottmobs:half_troll", {"lottmapgen:angsnowblock"}, 20, -1, 6000, 5, 31000)

mobs:register_mob("lottmobs:nazgul", {
	type = "monster",
	hp_min = 90,
	hp_max = 110,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "ringwraith_model.x",
	textures = {
		{"lottmobs_nazgul.png"},
	},
	visual_size = {x=2, y=2},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	run_velocity = 3,
	damage = 10,
	drops = {
		{name = "lottores:mithril_ingot",
		chance = 5,
		min = 1,
		max = 5,},
		{name = "lottarmor:chestplate_gold",
		chance = 3,
		min = 1,
		max = 11,},
		{name = "lottarmor:leggings_gold",
		chance = 3,
		min = 1,
		max = 1,},
		{name = "lottarmor:helmet_gold",
		chance = 3,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_gold",
		chance = 3,
		min = 1,
		max = 1,},
		{name = "lottweapons:gold_spear",
		chance = 3,
		min = 1,
		max = 1,},
		{name = "lottores:goldsword",
		chance = 3,
		min = 1,
		max = 1,},
	},
	drawtype = "front",
	armor = 100,
	water_damage = 10,
	lava_damage = 0,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "shoot",
	arrow = "lottmobs:darkball",
	shoot_interval = 4,
	sounds = {
		attack = "lottmobs:darkball",
	},
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 1,
		stand_end = 1,
		walk_start = 20,
		walk_end = 60,
		punch_start = 70,
		punch_end = 110,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:nazgul", {"default:stone"}, 2, -1, 20000, 3, -50)

mobs:register_mob("lottmobs:witch_king", {
	type = "monster",
	hp_min = 250,
	hp_max = 350,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	textures = {
		{"lottmobs_witch_king.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	armor = 100,
	run_velocity = 3,
	damage = 12,
	drops = {
		{name = "lottores:mithril_ingot",
		chance = 7,
		min = 1,
		max = 10,},
		{name = "lottarmor:chestplate_mithril",
		chance = 6,
		min = 1,
		max = 1,},
		{name = "lottarmor:leggings_mithril",
		chance = 6,
		min = 1,
		max = 1,},
		{name = "lottarmor:helmet_mithril",
		chance = 6,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_mithril",
		chance = 6,
		min = 1,
		max = 1,},
		{name = "lottweapons:mithril_spear",
		chance = 6,
		min = 1,
		max = 1,},
		{name = "lottores:mithrilsword",
		chance = 6,
		min = 1,
		max = 1,},
	},
	drawtype = "front",
	water_damage = 1,
	lava_damage = 0,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "shoot",
	arrow = "lottmobs:darkball",
	shoot_interval = 2,
	sounds = {
		attack = "lottmobs:darkball",
	},
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:witch_king", {"default:stone"}, 2, -1, 40000, 10, -1000)

mobs:register_mob("lottmobs:balrog", {
	type = "monster",
	rotate = 180,
	hp_min = 1000,
	hp_max = 1250,
	collisionbox = {-0.8, -2.1, -0.8, 0.8, 2.6, 0.8},
	visual_size = {x=2, y=2},
	visual = "mesh",
	mesh = "balrog_model.b3d",
	textures = {
		{"lottmobs_balrog.png"},
	},
	makes_footstep_sound = true,
	view_range = 15,
	armor = 100,
	walk_velocity = 1,
	run_velocity = 3,
	damage = 30,
	drops = {
		{name = "lottores:mithril_ingot",
		chance = 10,
		min = 1,
		max = 25,},
		{name = "lottores:mithrilsword",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottores:mithrilpickaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:mithril_battleaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:mithril_spear",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:mithril_battleaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:mithril_warhammer",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:mithril_dagger",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottthrowing:crossbow_mithril",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottthrowing:bolt_mithril",
		chance = 10,
		min = 10,
		max = 50,},
		{name = "lottarmor:helmet_mithril",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottarmor:chestplate_mithril",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottarmor:leggings_mithril",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottarmor:boots_mithril",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottarmor:shield_mithril",
		chance = 10,
		min = 1,
		max = 1,},
	},
	drawtype = "front",
	water_damage = 0,
	lava_damage = 0,
	light_damage = 0,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		stand_start = 0,
		stand_end = 240,
		walk_start = 240,
		walk_end = 300,
		punch_start = 300,
		punch_end = 380,
		speed_normal = 15,
		speed_run = 15,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:balrog", {"default:stone"}, 2, -1, 100000, 10, -10000)

mobs:register_mob("lottmobs:dead_men", {
	type = "monster",
	hp_min = 1,
	hp_max = 1,
	collisionbox = {-0.3,-1.0,-0.3, 0.3,0.8,0.3},
	visual = "mesh",
	mesh = "lottarmor_character.b3d",
	textures = {
		{"lottmobs_dead_men.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png", "lottarmor_trans.png"},
	},
	makes_footstep_sound = true,
	view_range = 10,
	walk_velocity = 1,
	run_velocity = 1,
	damage = 2,
	armor = 1,
	water_damage = 0,
	lava_damage = 0,
	light_damage = 1,
	drawtype = "front",
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 189,
		punch_end = 198,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:dead_men", {"default:mossycobble"}, 2, -1, 6000, 10, -100)

mobs:register_mob("lottmobs:troll", {
	type = "monster",
	hp_min = 50,
	hp_max = 65,
	collisionbox = {-0.7, -0.01, -0.7, 0.7, 2.6, 0.7},
	visual = "mesh",
	mesh = "troll_model.x",
	textures = {
		{"lottmobs_troll.png"},
		{"lottmobs_troll_1.png"},
		{"lottmobs_troll_2.png"},
		{"lottmobs_troll_3.png"},
	},
	visual_size = {x=8, y=8},
	makes_footstep_sound = true,
	view_range = 15,
	walk_velocity = 1,
	run_velocity = 1,
	damage = 10,
	armor = 100,
	drops = {
		{name = "default:stone",
		chance = 5,
		min = 1,
		max = 7,},
		{name = "lottweapons:steel_battleaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:steel_warhammer",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:bronze_battleaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:bronze_warhammer",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:tin_battleaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:tin_warhammer",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:copper_battleaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:copper_warhammer",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:silver_battleaxe",
		chance = 10,
		min = 1,
		max = 1,},
		{name = "lottweapons:silver_warhammer",
		chance = 10,
		min = 1,
		max = 1,},
	},
	drawtype = "front",
	water_damage = 0,
	lava_damage = 0,
	light_damage = 60,
	on_rightclick = nil,
	attack_type = "dogfight",
	animation = {
		stand_start = 0,
		stand_end = 19,
		walk_start = 20,
		walk_end = 35,
		punch_start = 36,
		punch_end = 48,
		speed_normal = 15,
		speed_run = 15,
	},
	jump = true,
	sounds = {
		war_cry = "mobs_die_yell",
		death = "default_death",
		attack = "default_punch2",
	},
	attacks_monsters = true,
	peaceful = true,
	group_attack = true,
	step = 1,
})
mobs:register_spawn("lottmobs:troll", {"default:stone"}, 2, -1, 8000, 5, -10)
mobs:register_spawn("lottmobs:troll", {"default:snow"}, 2, -1, 6000, 5, 31000)
mobs:register_spawn("lottmobs:troll", {"default:snowblock"}, 2, -1, 6000, 5, 31000)
mobs:register_spawn("lottmobs:troll", {"lottmapgen:angsnowblock"}, 2, -1, 6000, 5, 31000)

-- Arrows

mobs:register_arrow("lottmobs:darkball", {
	visual = "sprite",
	visual_size = {x=1, y=1},
	textures = {"lottmobs_darkball.png"},
	velocity = 5,
	hit_player = function(self, player)
		local s = self.object:getpos()
		local p = player:getpos()
		local vec = {x=s.x-p.x, y=s.y-p.y, z=s.z-p.z}
		player:punch(self.object, 1.0,  {
			full_punch_interval=1.0,
			damage_groups = {fleshy=4},
		}, vec)
		local pos = self.object:getpos()
		for dx=-1,1 do
			for dy=-1,1 do
				for dz=-1,1 do
					local p = {x=pos.x+dx, y=pos.y+dy, z=pos.z+dz}
					local n = minetest.env:get_node(pos).name
					if minetest.registered_nodes[n].groups.flammable or math.random(1, 100) <= 30 then
						minetest.env:set_node(p, {name="fire:basic_flame"})
					else
						minetest.env:remove_node(p)
					end
				end
			end
		end
	end,
	hit_node = function(self, pos, node)
		for dx=-1,1 do
			for dy=-2,1 do
				for dz=-1,1 do
					local p = {x=pos.x+dx, y=pos.y+dy, z=pos.z+dz}
					local n = minetest.env:get_node(pos).name
					if minetest.registered_nodes[n].groups.flammable or math.random(1, 100) <= 30 then
						minetest.env:set_node(p, {name="fire:basic_flame"})
					else
						minetest.env:remove_node(p)
					end
				end
			end
		end
	end
})
