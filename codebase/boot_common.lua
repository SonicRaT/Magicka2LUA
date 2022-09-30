UPDATE_INDEX = UPDATE_INDEX or 0
UPDATE_INDEX_MOD = 60
G_HACK_INGAME = true
local game_require_func = nil
local user_settings_loaded = true

Console = {}

function FRAME_PRINT(format, ...)
	if ... == nil then
		local s = "FRAME " .. UPDATE_INDEX .. " : " .. format

		print(s)
	else
		format = "FRAME %d : " .. format

		print(string.format(format, UPDATE_INDEX, ...))
	end

	return 
end

function init_common()
	if EDITOR_LAUNCH then
		Application.set_autoload_enabled(true)
	end

	local use_strict = false

	if use_strict then
		require("foundation/scripts/util/strict")
	end

	require("foundation/scripts/boot/foundation_setup")
	Boot:setup(game_require_func)

	if PD_APPLICATION_PARAMETER["window-title"] and rawget(_G, "Window") then
		Window.set_title(PD_APPLICATION_PARAMETER["window-title"])
	end

	local frame_table_use_ordinary = true

	if FrameTable.init then
		FrameTable.init(frame_table_use_ordinary)
	end

	local function user_settings_init()
		local times = DevelopmentSetting("custom_slowdown_times") or 0

		for i = 1, times, 1 do
			DEBUG_SCALE_MULTIPLIER = DEBUG_SCALE_MULTIPLIER*0.8
		end

		return 
	end

	if Application.platform() == "ps4" then
		SaveManager:init()

		user_settings_loaded = false

		SaveManager:load_user_settings(function ()
			user_settings_loaded = true

			user_settings_init()

			return 
		end)
	else
		user_settings_init()
	end

	Encrypter:init()

	local network_version = "1.2.1.0"

	if Application.build() ~= "release" then
		network_version = network_version .. "dev"
	end

	rawset(_G, "VERSION_IDENTIFIER", network_version)

	return 
end

GLOBAL_TIME_SCALE = GLOBAL_TIME_SCALE or 1
DEBUG_SCALE_MULTIPLIER = DEBUG_SCALE_MULTIPLIER or 1
update = update or function (dt)
	try_no_return(leveleditor_update)

	if 0.5 < dt then
		print("Long stall (delta-time) discovered!")

		dt = 0.5
	end

	while not user_settings_loaded do
		SaveManager:update(dt)

		return 
	end

	dt = dt*GLOBAL_TIME_SCALE*DEBUG_SCALE_MULTIPLIER
	UPDATE_INDEX = (UPDATE_INDEX + 1)%UPDATE_INDEX_MOD

	if Debug and DEBUG_SCALE_MULTIPLIER ~= 1 then
		Debug.text("Time Multiplier: " .. tostring(DEBUG_SCALE_MULTIPLIER))
	end

	try_no_return(AchievementManager.update, AchievementManager, dt)

	if Application.is_ps4() then
		try_no_return(NetworkPSNAux.update, NetworkPSNAux, dt)
		try_no_return(SystemEventManager.update, SystemEventManager)
	end

	try_no_return(NetworkHandler.update, NetworkHandler, dt)
	try_no_return(Boot.update, Boot, dt)

	if Application.is_pc() and Keyboard_pressed("scroll lock") then
		toggle_gui()
	end

	if rawget(_G, "Development") then
		try_no_return(Development.update, Development, dt)
	end

	try_no_return(WorldManager.update, WorldManager, dt)
	try_no_return(Boot.post_update, Boot, dt)

	return 
end

function render()
	WorldManager:render()

	return 
end

function shutdown()
	Boot:shutdown()
	WorldManager:destroy()
	Boot:destroy()

	if NetworkHandler then
		NetworkHandler:shutdown_backend()
	end

	return 
end

function game_require_func(package_manager)
	local function boot_game_require(path, ...)
		for _, s in ipairs({
			...
		}) do
			local game_file = "scripts/game/" .. path .. "/" .. s

			require(game_file)
		end

		return 
	end

	package_manager.load_synchronous(package_manager, "resource_packages/script_files_game")
	package_manager.load_synchronous(package_manager, "foundation/resource_packages/foundation_debug_package")
	require("scripts/build_revision_information")
	boot_game_require("ui", "ui", "ui_element", "ui_elements")
	boot_game_require("util", "queue", "settings", "entity_aux_game", "encrypter")
	boot_game_require("network", "network_game_transport", "network_game_mode_includes", "network_object_settings", "network_player_manager")
	boot_game_require("game_state", "game_state_login", "game_state_splashscreen", "state_context", "game_state_ingame", "game_state_menu", "game_state_loading")
	boot_game_require("managers", "localization_manager", "save_manager", "achievement_manager", "mission_complete_manager", "culling_manager", "profile_manager", "challenge_provider", "gui_manager")

	local input_settings_files = {
		"controller_settings_aux",
		"freeflight_controller_settings",
		"controller_settings",
		"game_controller_settings"
	}

	boot_game_require("settings/input", unpack(input_settings_files))

	local game_settings_files = {
		"game_settings",
		"level_settings",
		"mission_settings"
	}

	boot_game_require("settings/game", unpack(game_settings_files))
	boot_game_require("player", "player_manager")
	boot_game_require("entity_system", "entity_system")
	boot_game_require("flow", "flow_callbacks")

	if Application.build() ~= "release" then
		URLapi.switch_to_sandbox()
	end

	if Application.is_ps4() then
		SystemEventManager:init()
		NetworkPSNAux:init()
		NetworkPSNAux:set_content_restriction(PS4.content_restriction_age())
	end

	NetworkHandler:init()
	AchievementManager:init()
	CullingManager:init()

	local argv = {
		Application.argv()
	}

	if Application.is_ps4() and argv[1] == "-debugger" then
		AchievementManager:set_enabled(false)
	end

	LocalizationManager:init(package_manager)

	if Application.is_ps4() and PS4.enter_assignement_button() == "circle" then
		remap_gamepad()
	end

	if Application.build() == "release" then
		boot_game_require("development", "development_console_commands")
	end

	if Application.build() == "release" then
		boot_game_require("development", "development_setup", "development_commands")
		Development:init()

		local speed_down_key = DevelopmentSetting("development_keys", "speed_down") or "page down"

		Development:set_binding(speed_down_key, function ()
			DEBUG_SCALE_MULTIPLIER = DEBUG_SCALE_MULTIPLIER*0.8

			return 
		end)

		local speed_up_key = DevelopmentSetting("development_keys", "speed_up") or "page up"

		Development:set_binding(speed_up_key, function ()
			DEBUG_SCALE_MULTIPLIER = DEBUG_SCALE_MULTIPLIER*1.25

			return 
		end)

		local kill_all_key = DevelopmentSetting("development_keys", "kill_enemies") or "backspace"

		local function kill_all_fun()
			if not G_HACK_INGAME then
				return 
			end

			local w = Application.main_world()
			local units = World.units(w)

			for _, u in ipairs(units) do
				local behaviour_ext = EntityAux.extension(u, "behaviour")

				if behaviour_ext then
					DC_kill_unit(u)
				end
			end

			return 
		end

		Development:set_binding(kill_all_key, kill_all_fun)

		local kill_selected_key = DevelopmentSetting("development_keys", "kill_selected") or "delete"

		Development:set_binding(kill_selected_key, function ()
			DC_kill_selected_unit()

			return 
		end)

		local cheats_toggle_key = DevelopmentSetting("development_keys", "toggle_cheats") or "end"

		Development:set_binding(cheats_toggle_key, function ()
			DC_toggle_gui()

			return 
		end)

		local infinite_focus_toggle_key = DevelopmentSetting("development_keys", "toggle_infinite_focus") or "home"

		Development:set_binding(infinite_focus_toggle_key, function ()
			DC_toggle_infinite_focus()

			return 
		end)

		local restart_level_key = DevelopmentSetting("development_keys", "restart_level") or "insert"

		Development:set_binding(restart_level_key, function ()
			DC_restart_level()

			return 
		end)

		local reset_achievements_key = DevelopmentSetting("development_keys", "reset_achievements") or "pause"

		Development:set_binding(reset_achievements_key, function ()
			DC_reset_achievements()

			return 
		end)
	end

	return 
end

function remap_gamepad()
	for index, object in ipairs(GameControllerSettings.padps4) do
		local key = GameControllerSettings.padps4[index].key

		if key == "cross" then
			GameControllerSettings.padps4[index].key = "circle"
		elseif key == "circle" then
			GameControllerSettings.padps4[index].key = "cross"
		end
	end

	return 
end

leveleditor_update = leveleditor_update or function ()
	return 
end

function development_create_loadinginfo(level_name)
	return {
		level_name = "levels/" .. level_name .. "/world",
		level_name_short = level_name,
		level_package = "resource_packages/" .. level_name
	}
end

local gui_toggler = true

function toggle_gui()
	local flow_delegate = rawget(_G, "G_flow_delegate")

	if flow_delegate == nil then
		return 
	end

	gui_toggler = not gui_toggler

	flow_delegate.trigger(flow_delegate, "send_show_hide_gui", gui_toggler, true)

	return 
end

return 
