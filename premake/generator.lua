assert(_ACTION ~= nil, "no action (vs20**, gmake or xcode for example) provided!")

newoption({
	trigger = "workspace",
	description = "Sets the path for the workspace directory",
	value = "path for workspace directory"
})

newoption({
	trigger = "macosx_sdkroot",
	description = "Sets the path for the MacOSX SDK directory (the SDKROOT environment variable is a better alternative when running make)",
	value = "path for MacOSX SDK directory"
})

_GARRYSMOD_COMMON_DIRECTORY = path.getabsolute("..")

includeexternal("lua_shared.lua")
includeexternal("detouring.lua")
includeexternal("scanning.lua")
includeexternal("sourcesdk.lua")
includeexternal("pkg_config.lua")

function CreateWorkspace(config)
	assert(type(config) == "table", "supplied argument is not a table!")

	local name = config.name
	assert(type(name) == "string", "'name' is not a string!")

	local directory = config.path or _OPTIONS["workspace"] or WORKSPACE_DIRECTORY or --[[deprecated]] DEFAULT_WORKSPACE_DIRECTORY
	assert(type(directory) == "string", "workspace path is not a string!")

	local _workspace = workspace(name)
	assert(_workspace.directory == nil, "a workspace with the name '" .. name .. "' already exists!")

	local abi_compatible
	if config.allow_debug ~= nil then
		assert(type(config.allow_debug) == "boolean", "'allow_debug' is not a boolean!")
		print("WARNING: The 'allow_debug' option has been deprecated in favor of 'abi_compatible' (same functionality, better name, takes precedence over 'allow_debug', allows setting per project where the workspace setting takes precedence if set to true)")
		abi_compatible = not config.allow_debug
	end

	if config.abi_compatible ~= nil then
		abi_compatible = config.abi_compatible
		assert(type(abi_compatible) == "boolean", "'abi_compatible' is not a boolean!")
		_workspace.abi_compatible = abi_compatible
	end

	_workspace.directory = directory

		language("C++")
		location(_workspace.directory)
		warnings("Extra")
		flags({"NoPCH", "MultiProcessorCompile", "ShadowedVariables", "UndefinedIdentifiers"})
		characterset("MBCS")
		intrinsics("On")
		inlining("Auto")
		rtti("On")
		strictaliasing("Level3")
		vectorextensions("SSE2")
		pic("On")
		platforms({"x86_64", "x86"})
		targetdir(path.join("%{wks.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
		debugdir(path.join("%{wks.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
		objdir(path.join("!%{wks.location}", "%{cfg.architecture}", "%{cfg.buildcfg}", "intermediate", "%{prj.name}"))

		if abi_compatible then
			configurations({"ReleaseWithSymbols", "Release"})

			filter("system:linux or macosx")
				defines("_GLIBCXX_USE_CXX11_ABI=0")
		else
			configurations({"ReleaseWithSymbols", "Release", "Debug"})
		end

		filter("platforms:x86_64")
			architecture("x86_64")

		filter("platforms:x86")
			architecture("x86")

		filter("configurations:ReleaseWithSymbols")
			optimize("Debug")
			symbols("Full")
			defines("NDEBUG")
			runtime("Release")

		filter("configurations:Release")
			flags("LinkTimeOptimization")
			optimize("Full")
			symbols("Full")
			defines("NDEBUG")
			runtime("Release")

		if not abi_compatible then
			filter("configurations:Debug")
				optimize("Off")
				symbols("Full")
				defines({"DEBUG", "_DEBUG"})
				runtime("Debug")
		end

		filter("system:windows")
			cppdialect("C++17")
			staticruntime("On")
			defaultplatform("x86")
			defines({
				"_CRT_NONSTDC_NO_WARNINGS",
				"_CRT_SECURE_NO_WARNINGS",
				"STRICT"
			})

		filter("system:linux")
			cppdialect("GNU++17")
			staticruntime("Off")
			defaultplatform("x86")

		filter("system:macosx")
			cppdialect("GNU++17")
			staticruntime("Off")
			defaultplatform("x86_64")
			buildoptions({"-mmacosx-version-min=10.7", "-stdlib=libc++"})
			linkoptions({"-mmacosx-version-min=10.7", "-stdlib=libc++"})

			local macosx_sdkroot = _OPTIONS["macosx_sdkroot"]
			if macosx_sdkroot ~= nil then
				buildoptions("-isysroot " .. macosx_sdkroot)
				linkoptions("-isysroot " .. macosx_sdkroot)
			end

		filter({})
end

newoption({
	trigger = "source",
	description = "Sets the path to the source directory",
	value = "path to source directory"
})

newoption({
	trigger = "autoinstall",
	description = "Automatically installs the module to GarrysMod/garrysmod/bin (works as a flag and a receiver for a path)"
})

local function GetSteamLibraryDirectories()
	local dir

	if os.istarget("windows") then
		local regPath = os.getWindowsRegistry("HKCU:\\Software\\Valve\\Steam\\SteamPath")
		if regPath then
			dir = path.join(regPath, "SteamApps")
		else
			local p = io.popen("wmic logicaldisk get caption")

			for line in p:read("*a"):gmatch("%S+") do
				if line ~= "Caption" then
					local steamDir1 = path.join(line, "Program Files (x86)", "Steam", "SteamApps")
					local steamDir2 = path.join(line, "Program Files", "Steam", "SteamApps")

					if os.isdir(steamDir1) then
						dir = steamDir1
					elseif os.isdir(steamDir2) then
						dir = steamDir2
					end
				end
			end

			p:close()
		end
	elseif os.istarget("linux") then
		dir = path.join(os.getenv("HOME") or "~", ".local", "share", "Steam", "SteamApps")
	elseif os.istarget("macosx") then
		dir = path.join(os.getenv("HOME") or "~", "Library", "Application Support", "Steam", "SteamApps")
	end

	if dir then
		local dirs = {dir}

		if os.isfile(path.join(dir, "libraryfolders.vdf")) then
			local f = io.open(path.join(dir, "libraryfolders.vdf"), "r")

			for _, libdir in f:read("*a"):gmatch("\n%s*\"(%d+)\"%s*\"(.-)\"") do
				if os.isdir(libdir) then
					local sappsPath = path.join(libdir, "steamapps")
					if os.isdir(sappsPath) then
						dirs[#dirs + 1] = sappsPath
					end
				end
			end

			f:close()
		end

		return dirs
	end

	return {}
end

local function FindGarrysModDirectory()
	local dirs = GetSteamLibraryDirectories()

	for _, dir in ipairs(dirs) do
		if os.isdir(path.join(dir, "common", "GarrysMod")) then
			return path.join(dir, "common", "GarrysMod")
		elseif os.isdir(path.join(dir, "common", "garrysmod")) then
			return path.join(dir, "common", "garrysmod")
		end
	end

	return
end

local function FindGarrysModLuaBinDirectory()
	local dir = FindGarrysModDirectory()
	if not dir then
		return
	end

	local gluabinPath = path.join(dir, "garrysmod", "lua", "bin")
	if not os.isdir(gluabinPath) then
		os.mkdir(gluabinPath)
	end

	return gluabinPath
end

function CreateProject(config)
	assert(type(config) == "table", "supplied argument is not a table!")

	local is_server = config.serverside
	assert(type(is_server) == "boolean", "'serverside' option is not a boolean!")

	local sourcepath = config.source_path or _OPTIONS["source"] or SOURCE_DIRECTORY or --[[deprecated]] DEFAULT_SOURCE_DIRECTORY
	assert(type(sourcepath) == "string", "source code path is not a string!")

	local manual_files = config.manual_files
	if manual_files == nil then
		manual_files = false
	else
		assert(type(manual_files) == "boolean", "'manual_files' is not a boolean!")
	end

	local _workspace = workspace()

	local abi_compatible = _workspace.abi_compatible
	if not abi_compatible then
		if config.abi_compatible ~= nil then
			abi_compatible = config.abi_compatible
			assert(type(abi_compatible) == "boolean", "'abi_compatible' is not a boolean!")
		else
			abi_compatible = false
		end
	end

	local name = (is_server and "gmsv_" or "gmcl_") .. _workspace.name

	if abi_compatible and os.istarget("windows") and _ACTION ~= "vs2015" and _ACTION ~= "vs2017" and _ACTION ~= "vs2019" then
		error("The only supported compilation platforms for this project (" .. name .. ") on Windows are Visual Studio 2015, 2017 and 2019.")
	end

	local _project = project(name)

	assert(_project.directory == nil, "a project with the name '" .. name .. "' already exists!")

	_project.directory = sourcepath
	_project.serverside = is_server

		if abi_compatible then
			removeconfigurations("Debug")
			configurations({"ReleaseWithSymbols", "Release"})
		else
			configurations({"ReleaseWithSymbols", "Release", "Debug"})
		end

		kind("SharedLib")
		language("C++")
		defines({
			"GMMODULE",
			string.upper(string.gsub(_workspace.name, "%.", "_")) .. (_project.serverside and "_SERVER" or "_CLIENT"),
			"IS_SERVERSIDE=" .. tostring(is_server)
		})
		sysincludedirs(path.join(_GARRYSMOD_COMMON_DIRECTORY, "include"))
		includedirs(_project.directory)

		if not manual_files then
			files({
				path.join(_project.directory, "*.h"),
				path.join(_project.directory, "*.hpp"),
				path.join(_project.directory, "*.hxx"),
				path.join(_project.directory, "*.c"),
				path.join(_project.directory, "*.cpp"),
				path.join(_project.directory, "*.cxx")
			})
		end

		vpaths({
			["Header files/*"] = {
				path.join(_project.directory, "**.h"),
				path.join(_project.directory, "**.hpp"),
				path.join(_project.directory, "**.hxx")
			},
			["Source files/*"] = {
				path.join(_project.directory, "**.c"),
				path.join(_project.directory, "**.cpp"),
				path.join(_project.directory, "**.cxx")
			}
		})

		if abi_compatible then
			local filepath = path.join(_GARRYSMOD_COMMON_DIRECTORY, "source", "ABICompatibility.cpp")
			files(filepath)
			vpaths({["garrysmod_common"] = filepath})
		end

		targetprefix("")
		targetextension(".dll")

		filter({"system:windows", "platforms:x86"})
			targetsuffix("_win32")

			filter({"system:windows", "platforms:x86", "configurations:ReleaseWithSymbols or Debug"})
				linkoptions("/SAFESEH:NO")

		filter({"system:windows", "platforms:x86_64"})
			targetsuffix("_win64")

		filter({"system:linux", "platforms:x86"})
			targetsuffix("_linux")

		filter({"system:linux", "platforms:x86_64"})
			targetsuffix("_linux64")

		filter({"system:macosx", "platforms:x86"})
			targetsuffix("_osx")

		filter({"system:macosx", "platforms:x86_64"})
			targetsuffix("_osx64")

		if _OPTIONS["autoinstall"] then
			local binDir = _OPTIONS["autoinstall"] ~= "" and _OPTIONS["autoinstall"] or os.getenv("GARRYSMOD_LUA_BIN") or FindGarrysModLuaBinDirectory() or GARRYSMOD_LUA_BIN_DIRECTORY or --[[deprecated]] DEFAULT_GARRYSMOD_LUA_BIN_DIRECTORY
			assert(type(binDir) == "string", "The path to garrysmod/lua/bin is not a string!")

			filter("system:windows")
				postbuildcommands({"{COPY} %{cfg.buildtarget.abspath} \"" .. binDir .. "\""})

			filter("system:not windows")
				postbuildcommands({"{COPY} %{cfg.buildtarget.abspath} \"" .. binDir .. "%{cfg.buildtarget.name}\""})
		end

		filter({})
end

function HasIncludedPackage(name)
	local _project = project()
	_project.packages = _project.packages or {}
	return _project.packages[name] == true
end

function IncludePackage(name)
	assert(not HasIncludedPackage(name), "a project with the name '" .. name .. "' already exists!")
	project().packages[name] = true
end
