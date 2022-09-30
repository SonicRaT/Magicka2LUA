local function boot_base_require(path, ...)
	for _, s in ipairs({
		...
	}) do
		local base_file = "foundation/scripts/" .. path .. "/" .. s

		require(base_file)
	end

	return 
end

local Profiler_start = Profiler.start
local Profiler_stop = Profiler.stop
local Resolution, ui = nil

local function nop_func()
	return 
end

local nop_instance = {
	init = nop_func,
	update = nop_func,
	destroy = nop_func
}
Resolution = _Resolution or nop_instance
ui = _UIContext or nop_instance

ui.destroy(ui)
Resolution.destroy()
Resolution.init()
ui.init(ui)

Boot = Boot or {}
Boot.setup = function (self, game_require_callback)
	boot_base_require("debug", "category_print", "exceptions")

	if Application.build() == "release" then
		boot_base_require("development", "development_update", "local_boot")
	end

	self.load_context(self)
	self.create_context(self)
	self.load_scriptfiles_package(self)
	self.load_scriptutils(self)
	self.load_init_worldmanager(self)
	self.load_entity_system(self)
	game_require_callback(self.package_manager)
	self.setup_statemachine(self)

	return 
end
Boot.load_init_worldmanager = function (self)
	boot_base_require("world", "world_manager")
	WorldManager:init()

	return 
end
Boot.create_context = function (self)
	self.package_manager = PackageManager:init()
	PackageManager.loading_disabled = EDITOR_LAUNCH

	return 
end
Boot.init_resolution = function ()
	Resolution = require("foundation/scripts/util/engine/resolution")

	Resolution.init()

	return 
end
Boot.init_ui = function ()
	ui = require("scripts/game/ui2/ui_context")

	ui:init()

	return 
end
Boot.pre_update = function (self, dt)
	Profiler_start("lua_pre_update")
	self.machine:pre_update(dt)
	Profiler_stop()

	return 
end
Boot.update = function (self, dt)
	self.pre_update(self, dt)
	Profiler_start("lua_update")
	Profiler_start("package_manager_update")
	self.package_manager:update(dt)
	Profiler_stop()
	Profiler_start("machine_update")
	try_no_return(self.machine.update, self.machine, dt)
	Profiler_stop()
	Profiler_start("ui_update")
	try_no_return(ui.update, ui, dt)
	Profiler_stop()
	Profiler_start("Resolution_update")
	Resolution.update()
	Profiler_stop()
	Profiler_stop()

	return 
end
Boot.post_update = function (self, dt)
	Profiler_start("lua_post_update")
	self.machine:post_update(dt)
	Profiler_start("debug_update")
	Debug.update(dt)
	Profiler_stop()
	FrameTable.update()
	Profiler_stop()

	if self.quit_game and Application.is_pc() and not EDITOR_LAUNCH then
		Application.quit()
	end

	return 
end
Boot.setup_statemachine = function (self)
	local sm_context = {
		package_manager = self.package_manager
	}
	local start_state, state_param_block = entrypoint()
	self.machine = StateMachine(sm_context, "context", start_state, state_param_block)

	return 
end
Boot.load_context = function (self)
	boot_base_require("package", "package_manager")

	return 
end
Boot.load_scriptfiles_package = function (self)
	self.package_manager:load_synchronous("foundation/resource_packages/foundation_package")
	self.package_manager:load_synchronous("foundation/resource_packages/script_files_foundation")

	return 
end
Boot.load_scriptutils = function (self)
	local util_classes = {
		"table_aux",
		"input_aux",
		"frame_table",
		"varargs",
		"class",
		"callback",
		"rectangle",
		"state_machine",
		"misc_util",
		"pd_timer",
		"unit_aux",
		"stack",
		"object_proxy",
		"debug_utils",
		"bit",
		"random_table",
		"event_delegate",
		"queue",
		"null",
		"base64",
		"os_aux"
	}

	if Application.platform() == "ps4" then
		util_classes[#util_classes + 1] = "pdxigs"
	end

	local network_classes = {
		"network_unit",
		"network_aux",
		"network_gameobject_event",
		"network_handler",
		"network_lobby_handler",
		"network_message_router",
		"network_settings",
		"network_unit_spawner",
		"network_unit_storage"
	}

	if Application.platform() == "ps4" then
		network_classes[#network_classes + 1] = "network_psn_aux"
	end

	local gamemode_classes = {
		"network_game_mode",
		"network_game_mode_client",
		"network_game_mode_server"
	}
	local util_engine_classes = {
		"math_aux",
		"vector3_aux",
		"quaternion_aux",
		"user_setting",
		"resolution"
	}

	boot_base_require("util", "script_global_value_parser", "patches", "profiling_patches")
	boot_base_require("util", unpack(util_classes))
	boot_base_require("util/gui", "gui_aux")
	boot_base_require("util/engine", unpack(util_engine_classes))
	boot_base_require("input", "input_manager", "input_listener", "dual_shock_controller", "steam_controller", "rumble_manager")
	boot_base_require("world", "world_proxy")
	boot_base_require("rendering", "viewport_proxy")
	boot_base_require("camera", "camera_proxy")
	boot_base_require("level", "level_proxy")
	boot_base_require("debug", "debug", "debug_drawer", "debug_mouse")
	boot_base_require("network", unpack(network_classes))
	boot_base_require("network/game", "network_game")
	boot_base_require("network/game/game_mode", unpack(gamemode_classes))
	boot_base_require("unit_cache", "unit_info_cache")
	boot_base_require("system", "system_event_manager")

	if Application.build() == "release" then
		boot_base_require("development", "development_update")
	end

	return 
end
Boot.load_entity_system = function (self)
	boot_base_require("entity_system", "entity_aux", "entity_manager", "entity_manager_one_point_zero")

	return 
end
Boot.shutdown = function (self)
	self.quit_game = true

	self.machine:destroy(true)
	ui:destroy()
	Resolution.destroy()

	return 
end
Boot.destroy = function (self)
	self.package_manager:destroy()

	return 
end

return 
