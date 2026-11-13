dofile(ModPath .. "automenubuilder.lua")
dofile(ModPath .. "randomlib.lua")

local debug = true

if not RandomizeSpreeModifiers then
    _G.RandomizeSpreeModifiers = _G.RandomizeSpreeModifiers or {}
    RandomizeSpreeModifiers._save_path = SavePath .. "RandomizeSpreeModifiers.txt"
    RandomizeSpreeModifiers.settings = {
        loud = true,
        stealth = false,
		forced = false
    }
	tweak_data.crime_spree.modifiers.forced = {} -- Removes the non-repeating forced modifiers as they are not needed, and they could screw with mods that add new repeated modifiers

    function RandomizeSpreeModifiers:load()
        local file = io.open(self._save_path, "r")
        if file then
            RandomizeSpreeModifiers.seed = tonumber(file:read("n"))
        end
		if RandomizeSpreeModifiers.seed == nil then RandomizeSpreeModifiers.seed = tonumber(os.time()+os.clock()*1000000) end
		if debug then log("RSM >> loaded seed"..tonumber(RandomizeSpreeModifiers.seed)) end
		RandomNumber:set_seed(RandomizeSpreeModifiers.seed)
    end

    function RandomizeSpreeModifiers:save()
        local file = io.open(self._save_path, "w")
		if not RandomizeSpreeModifiers.seed then RandomizeSpreeModifiers:load() end
        if file then
            file:write(RandomNumber:get_seed())
        end
		if debug then log("RSM >> saved seed"..tonumber(RandomNumber:get_seed())) end
    end

	function RandomizeSpreeModifiers:get_random(x)
		return (RandomNumber:get_random_32()%x)+1
	end

end

Hooks:OverrideFunction(CrimeSpreeManager, "_get_modifiers", function(self, table_name, max_count, add_repeating)
	local temp_seed = RandomNumber:get_seed()
	if debug then log("RSM >> temp seed "..tostring(temp_seed)) end
	local modifiers = {}
	local default_modifier_level = tweak_data.crime_spree.modifier_levels[table_name] or 0
	local modifiers_table = {}
	-- create a shallow copy of modifiers table
	for _, v in ipairs(tweak_data.crime_spree.modifiers[table_name]) do
		local contains, prerequisite = false, true
		if v.prerequisite then prerequisite = false end
		for _, modifier_data in ipairs(self:server_active_modifiers()) do
			if modifier_data.id == v.id then
				contains = true
				break
			end
			if modifier_data.id == v.prerequisite then
				prerequisite = true
			end
		end
		if not contains and prerequisite then
			table.insert(modifiers_table,v) end
	end
	-- add_repeating is ignored for future mod compatability and because it does not matter in vanilla if made smart
	if tweak_data.crime_spree.repeating_modifiers[table_name] then
		for i=1,#tweak_data.crime_spree.repeating_modifiers[table_name] do
			local v = tweak_data.crime_spree.repeating_modifiers[table_name][i]
			local prerequisite = true
			if v.prerequisite then prerequisite = false end
			for _, modifier_data in ipairs(self:server_active_modifiers()) do
				if modifier_data.id == v.prerequisite then prerequisite = true end
			end
			if prerequisite then modifiers_table[#modifiers_table+1] = v end
			if debug then log("RSM REPEAT " .. modifiers_table[#modifiers_table].id) end
		end
	end
	if debug then log("RSM " .. table_name .. " " .. #modifiers_table) end
	
	if not modifiers_table or not modifiers_table[1] then
		Application:error("Can not get modifiers from table as there is no starting modifier: ", table_name)
		return {}
	end
	
	if RandomizeSpreeModifiers.settings[table_name] then
		while max_count > #modifiers and #modifiers_table > 0 do
			local id = RandomizeSpreeModifiers:get_random(#modifiers_table)
			if debug then log("RSM " .. modifiers_table[id].id) end
			table.insert(modifiers, modifiers_table[id])
			table.remove(modifiers_table, id)
		end
	else
		for _, modifier in ipairs(modifiers_table) do
			table.insert(modifiers, modifier)
			if max_count <= #modifiers then
				break
			end
		end

		if add_repeating then
			local diff = max_count - #modifiers
			if diff > 0 then
				for i = 1, diff do
					local idx = i % #modifiers_table + 1
					local new_mod = deep_clone(modifiers_table[idx])
					new_mod.id = new_mod.id .. tostring(math.floor(self:server_spree_level() / new_mod.level) * i)
					if debug then log("RSM ADD " .. new_mod.id) end
					table.insert(modifiers, new_mod)
				end
			end
		end
	end
	RandomNumber:set_seed(temp_seed)
	return modifiers
end)

Hooks:PostHook(CrimeSpreeManager, "load", "modify_tweakdata_on_load", function (self, version)
	if debug then log("RSM >> load") end
    RandomizeSpreeModifiers:load()
end)

Hooks:PostHook(CrimeSpreeManager, "select_modifier", "randomize_on_select_modifier", function (self)
	if debug then log("RSM >> save select") end
	RandomNumber:get_random_32()
	RandomizeSpreeModifiers:save()
end)

Hooks:PostHook(CrimeSpreeManager, "start_crime_spree", "randomize_on_start_crime_spree", function (self, version)
	if debug then log("RSM >> save start") end
	RandomNumber:get_random_32()
    RandomizeSpreeModifiers:save()
end)

Hooks:Add("MenuManagerBuildCustomMenus","MenuManagerBuildCustomMenusRSM", function (menu_manager, nodes)
    AutoMenuBuilder:load_settings(RandomizeSpreeModifiers.settings, "RandomizeSpreeModifiersSettings")
    AutoMenuBuilder:create_menu_from_table(nodes, RandomizeSpreeModifiers.settings, "RandomizeSpreeModifiersSettings", "blt_options")
end)

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInitRSM", function (loc)
    loc:add_localized_strings({
        ["menu_RandomizeSpreeModifiersSettings"] = "Randomize Spree Modifiers"
    })
end)
