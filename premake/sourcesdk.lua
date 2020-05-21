newoption({
	trigger = "sourcesdk",
	description = "Sets the path to the SourceSDK directory",
	value = "path to SourceSDK directory"
})

local function GetSDKPath(directory)
	directory = directory or _OPTIONS["sourcesdk"] or os.getenv("SOURCE_SDK") or SOURCESDK_DIRECTORY or --[[deprecated]] DEFAULT_SOURCESDK_DIRECTORY

	assert(type(directory) == "string", "Source SDK path is not a string!")

	local dir = path.getabsolute(directory)
	assert(os.isdir(dir), "'" .. dir .. "' doesn't exist (Source SDK)")

	return path.getrelative(_SCRIPT_DIR, directory)
end

local function IncludeSDKCommonInternal(directory)
	local _project = project()

	defines({
		_project.serverside and "GAME_DLL" or "CLIENT_DLL",
		"RAD_TELEMETRY_DISABLED",
		"NO_STRING_T",
		"VECTOR",
		"VERSION_SAFE_STEAM_API_INTERFACES",
		"PROTECTED_THINGS_ENABLE"
	})

	filter("system:windows")
		defines({"_DLL_EXT=.dll", "WIN32", "COMPILER_MSVC"})

		filter({"system:windows", "architecture:x86"})
			defines("COMPILER_MSVC32")
			libdirs(path.join(directory, "lib", "public"))

		filter({"system:windows", "architecture:x86_64"})
			defines({"COMPILER_MSVC64", "PLATFORM_64BITS", "WIN64", "_WIN64"})
			libdirs(path.join(directory, "lib", "public", "x64"))

		filter({"system:windows", "configurations:Debug"})
			linkoptions("/NODEFAULTLIB:\"libcmt\"")

	filter("system:linux")
		disablewarnings({
			"unused-local-typedefs",
			"unused-parameter",
			"strict-aliasing",
			"unknown-pragmas",
			"invalid-offsetof",
			"undef",
			"ignored-attributes"
		})
		defines({
			"_DLL_EXT=.so",
			"COMPILER_GCC",
			"POSIX",
			"_POSIX",
			"LINUX",
			"_LINUX",
			"GNUC",
			"SWDS"
		})

		filter({"system:linux", "architecture:x86"})
			libdirs(path.join(path.getabsolute(directory), "lib", "public", "linux32"))

		filter({"system:linux", "architecture:x86_64"})
			defines("PLATFORM_64BITS")
			libdirs(path.join(path.getabsolute(directory), "lib", "public", "linux64"))

	filter("system:macosx")
		disablewarnings({
			"unused-local-typedef",
			"unused-parameter",
			"unused-private-field",
			"overloaded-virtual",
			"unknown-pragmas",
			"unused-variable",
			"unknown-warning-option",
			"invalid-offsetof",
			"undef",
			"expansion-to-defined"
		})
		defines({
			"_DLL_EXT=.dylib",
			"COMPILER_GCC",
			"POSIX",
			"_POSIX",
			"OSX",
			"_OSX",
			"GNUC",
			"_DARWIN_UNLIMITED_SELECT",
			"FD_SETSIZE=10240",
			"OVERRIDE_V_DEFINES",
			"SWDS"
		})

		filter({"system:macosx", "architecture:x86"})
			libdirs(path.join(path.getabsolute(directory), "lib", "public", "osx32"))

		filter({"system:macosx", "architecture:x86_64"})
			defines("PLATFORM_64BITS")
			libdirs(path.join(path.getabsolute(directory), "lib", "public", "osx64"))

	filter({})
end

function IncludeSDKCommon(directory)
	IncludePackage("sdkcommon")

	local _project = project()

	directory = GetSDKPath(directory)

	defines("GMOD_USE_SOURCESDK")
	sysincludedirs({
		path.join(directory, "common"),
		path.join(directory, "public")
	})

	if _project.serverside then
		sysincludedirs({
			path.join(directory, "game", "server"),
			path.join(directory, "game", "shared")
		})
	else
		sysincludedirs({
			path.join(directory, "game", "client"),
			path.join(directory, "game", "shared")
		})
	end

	files({
		path.join(directory, "interfaces", "interfaces.cpp"),
		path.join(directory, "public", "interfaces", "interfaces.h")
	})
	vpaths({
		["SourceSDK"] = {
			path.join(directory, "interfaces", "interfaces.cpp"),
			path.join(directory, "public", "interfaces", "interfaces.h")
		}
	})

	IncludeSDKCommonInternal(directory)
end

function IncludeSDKTier0(directory)
	IncludePackage("sdktier0")

	local _project = project()

	directory = GetSDKPath(directory)

	sysincludedirs(path.join(directory, "public", "tier0"))

	filter("system:windows or macosx")
		links("tier0")

	filter({"system:linux", "architecture:x86"})
		links("tier0")

	filter({"system:linux", "architecture:x86_64"})
		links(_project.serverside and "tier0" or "tier0_client")

	filter({})
end

function IncludeSDKTier1(directory)
	IncludePackage("sdktier1")

	local _project = project()

	directory = GetSDKPath(directory)

	sysincludedirs(path.join(directory, "public", "tier1"))
	links("tier1")

	filter("system:windows")
		links({"vstdlib", "ws2_32", "rpcrt4"})

	filter({"system:linux", "architecture:x86"})
		links("vstdlib")

	filter({"system:linux", "architecture:x86_64"})
		links(_project.serverside and "vstdlib" or "vstdlib_client")

	filter("system:macosx")
		links({"vstdlib", "iconv"})

	group("garrysmod_common")
		project("tier1")
			kind("StaticLib")
			warnings("Default")
			location(path.join(_GARRYSMOD_COMMON_DIRECTORY, "projects", os.target(), _ACTION))
			defines({"TIER1_STATIC_LIB", "_CRT_SECURE_NO_WARNINGS"})
			targetdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			debugdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			objdir(path.join("!%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}", "intermediate", "%{prj.name}"))
			sysincludedirs({
				path.join(directory, "public"),
				path.join(directory, "public", "tier0"),
				path.join(directory, "public", "tier1")
			})
			files({
				path.join(directory, "tier1", "appinstance.cpp"),
				path.join(directory, "tier1", "bitbuf.cpp"),
				path.join(directory, "tier1", "newbitbuf.cpp"),
				path.join(directory, "tier1", "byteswap.cpp"),
				path.join(directory, "tier1", "characterset.cpp"),
				path.join(directory, "tier1", "checksum_crc.cpp"),
				path.join(directory, "tier1", "checksum_md5.cpp"),
				path.join(directory, "tier1", "checksum_sha1.cpp"),
				path.join(directory, "tier1", "circularbuffer.cpp"),
				path.join(directory, "tier1", "commandbuffer.cpp"),
				path.join(directory, "tier1", "convar.cpp"),
				path.join(directory, "tier1", "datamanager.cpp"),
				path.join(directory, "tier1", "diff.cpp"),
				path.join(directory, "tier1", "exprevaluator.cpp"),
				path.join(directory, "tier1", "generichash.cpp"),
				path.join(directory, "tier1", "interface.cpp"),
				path.join(directory, "tier1", "keyvalues.cpp"),
				path.join(directory, "tier1", "keyvaluesjson.cpp"),
				path.join(directory, "tier1", "kvpacker.cpp"),
				path.join(directory, "tier1", "lzmaDecoder.cpp"),
				path.join(directory, "tier1", "lzss.cpp"),
				path.join(directory, "tier1", "mempool.cpp"),
				path.join(directory, "tier1", "memstack.cpp"),
				path.join(directory, "tier1", "NetAdr.cpp"),
				path.join(directory, "tier1", "splitstring.cpp"),
				path.join(directory, "tier1", "rangecheckedvar.cpp"),
				path.join(directory, "tier1", "stringpool.cpp"),
				path.join(directory, "tier1", "strtools.cpp"),
				path.join(directory, "tier1", "strtools_unicode.cpp"),
				path.join(directory, "tier1", "tier1.cpp"),
				path.join(directory, "tier1", "tier1_logging.cpp"),
				path.join(directory, "tier1", "timeutils.cpp"),
				path.join(directory, "tier1", "uniqueid.cpp"),
				path.join(directory, "tier1", "utlbuffer.cpp"),
				path.join(directory, "tier1", "utlbufferutil.cpp"),
				path.join(directory, "tier1", "utlsoacontainer.cpp"),
				path.join(directory, "tier1", "utlstring.cpp"),
				path.join(directory, "tier1", "utlsymbol.cpp"),
				path.join(directory, "tier1", "miniprofiler_hash.cpp"),
				path.join(directory, "tier1", "sparsematrix.cpp"),
				path.join(directory, "tier1", "memoverride_dummy.cpp"),
				path.join(directory, "public", "tier1", "appinstance.h"),
				path.join(directory, "public", "tier1", "bitbuf.h"),
				path.join(directory, "public", "tier1", "byteswap.h"),
				path.join(directory, "public", "tier1", "callqueue.h"),
				path.join(directory, "public", "tier1", "characterset.h"),
				path.join(directory, "public", "tier1", "checksum_crc.h"),
				path.join(directory, "public", "tier1", "checksum_md5.h"),
				path.join(directory, "public", "tier1", "checksum_sha1.h"),
				path.join(directory, "public", "tier1", "circularbuffer.h"),
				path.join(directory, "public", "tier1", "commandbuffer.h"),
				path.join(directory, "public", "tier1", "convar.h"),
				path.join(directory, "public", "tier1", "datamanager.h"),
				path.join(directory, "public", "tier1", "delegates.h"),
				path.join(directory, "public", "tier1", "diff.h"),
				path.join(directory, "public", "tier1", "exprevaluator.h"),
				path.join(directory, "public", "tier1", "fmtstr.h"),
				path.join(directory, "public", "tier1", "functors.h"),
				path.join(directory, "public", "tier1", "generichash.h"),
				path.join(directory, "public", "tier1", "iconvar.h"),
				path.join(directory, "public", "tier1", "interface.h"),
				path.join(directory, "public", "tier1", "interpolatedvar.h"),
				path.join(directory, "public", "tier1", "keyvalues.h"),
				path.join(directory, "public", "tier1", "keyvaluesjson.h"),
				path.join(directory, "public", "tier1", "kvpacker.h"),
				path.join(directory, "public", "tier1", "lzmaDecoder.h"),
				path.join(directory, "public", "tier1", "lerp_functions.h"),
				path.join(directory, "public", "tier1", "lzss.h"),
				path.join(directory, "public", "tier1", "mempool.h"),
				path.join(directory, "public", "tier1", "memstack.h"),
				path.join(directory, "public", "tier1", "netadr.h"),
				path.join(directory, "public", "tier1", "processor_detect.h"),
				path.join(directory, "public", "tier1", "rangecheckedvar.h"),
				path.join(directory, "public", "tier1", "refcount.h"),
				path.join(directory, "public", "tier1", "smartptr.h"),
				path.join(directory, "public", "tier1", "sparsematrix.h"),
				path.join(directory, "public", "tier1", "stringpool.h"),
				path.join(directory, "public", "tier1", "strtools.h"),
				path.join(directory, "public", "tier1", "tier1.h"),
				path.join(directory, "public", "tier1", "tier1_logging.h"),
				path.join(directory, "public", "tier1", "timeutils.h"),
				path.join(directory, "public", "tier1", "tokenset.h"),
				path.join(directory, "public", "tier1", "utlbidirectionalset.h"),
				path.join(directory, "public", "tier1", "utlblockmemory.h"),
				path.join(directory, "public", "tier1", "utlbuffer.h"),
				path.join(directory, "public", "tier1", "utlbufferutil.h"),
				path.join(directory, "public", "tier1", "utlcommon.h"),
				path.join(directory, "public", "tier1", "utldict.h"),
				path.join(directory, "public", "tier1", "utlenvelope.h"),
				path.join(directory, "public", "tier1", "utlfixedmemory.h"),
				path.join(directory, "public", "tier1", "utlhandletable.h"),
				path.join(directory, "public", "tier1", "utlhash.h"),
				path.join(directory, "public", "tier1", "utlhashtable.h"),
				path.join(directory, "public", "tier1", "utllinkedlist.h"),
				path.join(directory, "public", "tier1", "utlmap.h"),
				path.join(directory, "public", "tier1", "utlmemory.h"),
				path.join(directory, "public", "tier1", "utlmultilist.h"),
				path.join(directory, "public", "tier1", "utlpriorityqueue.h"),
				path.join(directory, "public", "tier1", "utlqueue.h"),
				path.join(directory, "public", "tier1", "utlrbtree.h"),
				path.join(directory, "public", "tier1", "utlsoacontainer.h"),
				path.join(directory, "public", "tier1", "utlsortvector.h"),
				path.join(directory, "public", "tier1", "utlstack.h"),
				path.join(directory, "public", "tier1", "utlstring.h"),
				path.join(directory, "public", "tier1", "utlstringtoken.h"),
				path.join(directory, "public", "tier1", "utlstringmap.h"),
				path.join(directory, "public", "tier1", "utlsymbol.h"),
				path.join(directory, "public", "tier1", "utltscache.h"),
				path.join(directory, "public", "tier1", "utlvector.h"),
				path.join(directory, "public", "tier1", "miniprofiler_hash.h"),
				path.join(directory, "public", "datamap.h"),
				path.join(directory, "common", "xbox", "xboxstubs.h"),
				path.join(directory, "utils", "lzma", "C", "LzmaDec.c")
			})
			vpaths({
				["Source files/*"] = {
					path.join(directory, "tier1", "*.cpp"),
					path.join(directory, "utils", "lzma", "C", "*.c")
				},
				["Header files/*"] = {
					path.join(directory, "public", "tier1", "*.h"),
					path.join(directory, "public", "*.h"),
					path.join(directory, "common", "xbox", "*.h")
				}
			})

			IncludeSDKCommonInternal(directory)

			filter("files:**.c")
				language("C")

			filter("system:windows")
				files({
					path.join(directory, "tier1", "processor_detect.cpp"),
					path.join(directory, "public", "tier1", "uniqueid.h")
				})

			filter("system:linux")
				disablewarnings("unused-result")
				files({
					path.join(directory, "tier1", "processor_detect_linux.cpp"),
					path.join(directory, "tier1", "qsort_s.cpp"),
					path.join(directory, "tier1", "pathmatch.cpp")
				})
				linkoptions({
					"-Xlinker --wrap=fopen",
					"-Xlinker --wrap=freopen",
					"-Xlinker --wrap=open",
					"-Xlinker --wrap=creat",
					"-Xlinker --wrap=access",
					"-Xlinker --wrap=__xstat",
					"-Xlinker --wrap=stat",
					"-Xlinker --wrap=lstat",
					"-Xlinker --wrap=fopen64",
					"-Xlinker --wrap=open64",
					"-Xlinker --wrap=opendir",
					"-Xlinker --wrap=__lxstat",
					"-Xlinker --wrap=chmod",
					"-Xlinker --wrap=chown",
					"-Xlinker --wrap=lchown",
					"-Xlinker --wrap=symlink",
					"-Xlinker --wrap=link",
					"-Xlinker --wrap=__lxstat64",
					"-Xlinker --wrap=mknod",
					"-Xlinker --wrap=utimes",
					"-Xlinker --wrap=unlink",
					"-Xlinker --wrap=rename",
					"-Xlinker --wrap=utime",
					"-Xlinker --wrap=__xstat64",
					"-Xlinker --wrap=mount",
					"-Xlinker --wrap=mkfifo",
					"-Xlinker --wrap=mkdir",
					"-Xlinker --wrap=rmdir",
					"-Xlinker --wrap=scandir",
					"-Xlinker --wrap=realpath"
				})

			filter("system:macosx")
				files(path.join(directory, "tier1", "processor_detect_linux.cpp"))

	group("")
	project(_project.name)
end

function IncludeSDKTier2(directory)
	IncludePackage("sdktier2")

	local _project = project()
	print("WARNING: Project '" .. _project.name .. "' included Source SDK 'tier2' library, which is currently not available in x86-64.")

	directory = GetSDKPath(directory)

	filter("architecture:x86")
		sysincludedirs(path.join(directory, "public", "tier2"))

		filter({"architecture:x86", "system:windows"})
			links("tier2")

		filter({"architecture:x86", "system:macosx"})
			linkoptions(path.join(path.getabsolute(directory), "lib", "public", "osx32", "tier2.a"))

		filter({"architecture:x86", "system:linux"})
			linkoptions(path.join(path.getabsolute(directory), "lib", "public", "linux32", "tier2.a"))

	filter({})
end

function IncludeSDKTier3(directory)
	IncludePackage("sdktier3")

	local _project = project()
	print("WARNING: Project '" .. _project.name .. "' included Source SDK 'tier3' library, which is currently not available in x86-64.")

	directory = GetSDKPath(directory)

	filter("architecture:x86")
		sysincludedirs(path.join(directory, "public", "tier3"))

		filter({"architecture:x86", "system:windows"})
			links("tier3")

		filter({"architecture:x86", "system:macosx"})
			linkoptions(path.join(path.getabsolute(directory), "lib", "public", "osx32", "tier3.a"))

		filter({"architecture:x86", "system:linux"})
			linkoptions(path.join(path.getabsolute(directory), "lib", "public", "linux32", "tier3.a"))

	filter({})
end

function IncludeSDKMathlib(directory)
	IncludePackage("sdkmathlib")

	local _project = project()
	local _workspace = _project.workspace

	directory = GetSDKPath(directory)

	sysincludedirs(path.join(directory, "public", "mathlib"))
	links("mathlib")

	group("garrysmod_common")
		project("mathlib")
			kind("StaticLib")
			warnings("Default")
			location(path.join(_GARRYSMOD_COMMON_DIRECTORY, "projects", os.target(), _ACTION))
			defines("MATHLIB_LIB")
			targetdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			debugdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			objdir(path.join("!%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}", "intermediate", "%{prj.name}"))
			sysincludedirs({
				path.join(directory, "public"),
				path.join(directory, "public", "mathlib"),
				path.join(directory, "public", "tier0"),
			})
			files({
				path.join(directory, "mathlib", "expressioncalculator.cpp"),
				path.join(directory, "mathlib", "color_conversion.cpp"),
				path.join(directory, "mathlib", "cholesky.cpp"),
				path.join(directory, "mathlib", "halton.cpp"),
				path.join(directory, "mathlib", "lightdesc.cpp"),
				path.join(directory, "mathlib", "mathlib_base.cpp"),
				path.join(directory, "mathlib", "powsse.cpp"),
				path.join(directory, "mathlib", "sparse_convolution_noise.cpp"),
				path.join(directory, "mathlib", "sseconst.cpp"),
				path.join(directory, "mathlib", "sse.cpp"),
				path.join(directory, "mathlib", "ssenoise.cpp"),
				path.join(directory, "mathlib", "anorms.cpp"),
				path.join(directory, "mathlib", "bumpvects.cpp"),
				path.join(directory, "mathlib", "IceKey.cpp"),
				path.join(directory, "mathlib", "kdop.cpp"),
				path.join(directory, "mathlib", "imagequant.cpp"),
				path.join(directory, "mathlib", "spherical.cpp"),
				path.join(directory, "mathlib", "polyhedron.cpp"),
				path.join(directory, "mathlib", "quantize.cpp"),
				path.join(directory, "mathlib", "randsse.cpp"),
				path.join(directory, "mathlib", "simdvectormatrix.cpp"),
				path.join(directory, "mathlib", "vmatrix.cpp"),
				path.join(directory, "mathlib", "almostequal.cpp"),
				path.join(directory, "mathlib", "simplex.cpp"),
				path.join(directory, "mathlib", "eigen.cpp"),
				path.join(directory, "mathlib", "box_buoyancy.cpp"),
				path.join(directory, "mathlib", "camera.cpp"),
				path.join(directory, "mathlib", "planefit.cpp"),
				path.join(directory, "mathlib", "polygon.cpp"),
				path.join(directory, "mathlib", "volumeculler.cpp"),
				path.join(directory, "mathlib", "transform.cpp"),
				path.join(directory, "mathlib", "sphere.cpp"),
				path.join(directory, "mathlib", "capsule.cpp"),
				path.join(directory, "mathlib", "noisedata.h"),
				path.join(directory, "mathlib", "sse.h"),
				path.join(directory, "public", "mathlib", "anorms.h"),
				path.join(directory, "public", "mathlib", "bumpvects.h"),
				path.join(directory, "public", "mathlib", "beziercurve.h"),
				path.join(directory, "public", "mathlib", "camera.h"),
				path.join(directory, "public", "mathlib", "compressed_3d_unitvec.h"),
				path.join(directory, "public", "mathlib", "compressed_light_cube.h"),
				path.join(directory, "public", "mathlib", "compressed_vector.h"),
				path.join(directory, "public", "mathlib", "expressioncalculator.h"),
				path.join(directory, "public", "mathlib", "halton.h"),
				path.join(directory, "public", "mathlib", "IceKey.H"),
				path.join(directory, "public", "mathlib", "lightdesc.h"),
				path.join(directory, "public", "mathlib", "math_pfns.h"),
				path.join(directory, "public", "mathlib", "mathlib.h"),
				path.join(directory, "public", "mathlib", "noise.h"),
				path.join(directory, "public", "mathlib", "polyhedron.h"),
				path.join(directory, "public", "mathlib", "quantize.h"),
				path.join(directory, "public", "mathlib", "simdvectormatrix.h"),
				path.join(directory, "public", "mathlib", "spherical_geometry.h"),
				path.join(directory, "public", "mathlib", "ssemath.h"),
				path.join(directory, "public", "mathlib", "ssequaternion.h"),
				path.join(directory, "public", "mathlib", "vector.h"),
				path.join(directory, "public", "mathlib", "vector2d.h"),
				path.join(directory, "public", "mathlib", "vector4d.h"),
				path.join(directory, "public", "mathlib", "vmatrix.h"),
				path.join(directory, "public", "mathlib", "vplane.h"),
				path.join(directory, "public", "mathlib", "simplex.h"),
				path.join(directory, "public", "mathlib", "eigen.h"),
				path.join(directory, "public", "mathlib", "box_buoyancy.h"),
				path.join(directory, "public", "mathlib", "cholesky.h"),
				path.join(directory, "public", "mathlib", "planefit.h"),
				path.join(directory, "public", "mathlib", "intvector3d.h"),
				path.join(directory, "public", "mathlib", "polygon.h"),
				path.join(directory, "public", "mathlib", "quadric.h"),
				path.join(directory, "public", "mathlib", "volumeculler.h"),
				path.join(directory, "public", "mathlib", "transform.h"),
				path.join(directory, "public", "mathlib", "sphere.h"),
				path.join(directory, "public", "mathlib", "capsule.h")
			})
			vpaths({
				["Source files/*"] = path.join(directory, "mathlib", "*.cpp"),
				["Header files/*"] = {
					path.join(directory, "mathlib", "*.h"),
					path.join(directory, "public", "mathlib", "*.h")
				}
			})

			IncludeSDKCommonInternal(directory)

			filter("system:linux")
				disablewarnings("ignored-attributes")

	group("")
	project(_project.name)
end

function IncludeSDKRaytrace(directory)
	IncludePackage("sdkraytrace")

	local _project = project()
	local _workspace = _project.workspace

	directory = GetSDKPath(directory)

	links("raytrace")

	group("garrysmod_common")
		project("raytrace")
			kind("StaticLib")
			warnings("Default")
			location(path.join(_GARRYSMOD_COMMON_DIRECTORY, "projects", os.target(), _ACTION))
			targetdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			debugdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			objdir(path.join("!%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}", "intermediate", "%{prj.name}"))
			sysincludedirs({
				path.join(directory, "utils", "common"),
				path.join(directory, "public"),
				path.join(directory, "public", "tier0"),
				path.join(directory, "public", "tier1")
			})
			files({
				path.join(directory, "raytrace", "raytrace.cpp"),
				path.join(directory, "raytrace", "trace2.cpp"),
				path.join(directory, "raytrace", "trace3.cpp")
			})
			vpaths({["Source files/*"] = path.join(directory, "raytrace", "*.cpp")})

			IncludeSDKCommonInternal(directory)

	group("")
	project(_project.name)
end

function IncludeSDKBitmap(directory)
	IncludePackage("sdkbitmap")

	local _project = project()

	directory = GetSDKPath(directory)

	links("bitmap")

	group("garrysmod_common")
		project("bitmap")
			kind("StaticLib")
			warnings("Default")
			location(path.join(_GARRYSMOD_COMMON_DIRECTORY, "projects", os.target(), _ACTION))
			targetdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			debugdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			objdir(path.join("!%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}", "intermediate", "%{prj.name}"))
			sysincludedirs({
				path.join(directory, "utils", "common"),
				path.join(directory, "public"),
				path.join(directory, "public", "tier0"),
				path.join(directory, "public", "tier1")
			})
			files({
				path.join(directory, "bitmap", "bitmap.cpp"),
				path.join(directory, "bitmap", "colorconversion.cpp"),
				path.join(directory, "bitmap", "floatbitmap.cpp"),
				path.join(directory, "bitmap", "floatbitmap2.cpp"),
				path.join(directory, "bitmap", "floatbitmap3.cpp"),
				path.join(directory, "bitmap", "floatbitmap_bilateralfilter.cpp"),
				path.join(directory, "bitmap", "floatcubemap.cpp"),
				path.join(directory, "bitmap", "imageformat.cpp"),
				path.join(directory, "bitmap", "psd.cpp"),
				path.join(directory, "bitmap", "psheet.cpp"),
				path.join(directory, "bitmap", "resample.cpp"),
				path.join(directory, "bitmap", "tgaloader.cpp"),
				path.join(directory, "bitmap", "texturepacker.cpp"),
				path.join(directory, "bitmap", "tgawriter.cpp"),
				path.join(directory, "public", "bitmap", "bitmap.h"),
				path.join(directory, "public", "bitmap", "floatbitmap.h"),
				path.join(directory, "public", "bitmap", "imageformat.h"),
				path.join(directory, "public", "bitmap", "imageformat_declarations.h"),
				path.join(directory, "public", "bitmap", "psd.h"),
				path.join(directory, "public", "bitmap", "psheet.h"),
				path.join(directory, "public", "bitmap", "texturepacker.h"),
				path.join(directory, "public", "bitmap", "tgaloader.h"),
				path.join(directory, "public", "bitmap", "tgawriter.h"),
				path.join(directory, "public", "bitmap", "stb_dxt.h")
			})
			vpaths({
				["Source files/*"] = path.join(directory, "bitmap", "*.cpp"),
				["Header files/*"] = path.join(directory, "public", "bitmap", "*.h")
			})

			IncludeSDKCommonInternal(directory)

			filter("system:windows")
				files(path.join(directory, "bitmap", "floatbitmap4.cpp"))

	group("")
	project(_project.name)
end

function IncludeSDKVTF(directory)
	IncludePackage("sdkvtf")

	local _project = project()

	directory = GetSDKPath(directory)

	links("vtf")

	group("garrysmod_common")
		project("vtf")
			kind("StaticLib")
			warnings("Default")
			links("bitmap")
			location(path.join(_GARRYSMOD_COMMON_DIRECTORY, "projects", os.target(), _ACTION))
			targetdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			debugdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			objdir(path.join("!%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}", "intermediate", "%{prj.name}"))
			sysincludedirs({
				path.join(directory, "utils", "common"),
				path.join(directory, "public"),
				path.join(directory, "public", "tier0"),
				path.join(directory, "public", "tier1")
			})
			files({
				path.join(directory, "vtf", "vtf.cpp"),
				path.join(directory, "vtf", "convert_x360.cpp"),
				path.join(directory, "vtf", "cvtf.h"),
				path.join(directory, "public", "vtf", "vtf.h")
			})
			vpaths({
				["Source files/*"] = path.join(directory, "vtf", "*.cpp"),
				["Header files/*"] = {
					path.join(directory, "vtf", "*.h"),
					path.join(directory, "public", "vtf", "*.h")
				}
			})

			IncludeSDKCommonInternal(directory)

			filter("system:windows")
				files({
					path.join(directory, "vtf", "s3tc_decode.cpp"),
					path.join(directory, "vtf", "s3tc_decode.h")
				})

	group("")
	project(_project.name)
end

function IncludeSteamAPI(directory)
	IncludePackage("steamapi")
	sysincludedirs(path.join(GetSDKPath(directory), "public", "steam"))
	links("steam_api")
end

function IncludeSDKLZMA(directory)
	IncludePackage("sdklzma")

	local _project = project()

	directory = GetSDKPath(directory)

	sysincludedirs(path.join(directory, "utils", "lzma", "C"))
	links("LZMA")

	group("garrysmod_common")
		project("LZMA")
			kind("StaticLib")
			warnings("Default")
			defines("_7ZIP_ST")
			location(path.join(_GARRYSMOD_COMMON_DIRECTORY, "projects", os.target(), _ACTION))
			targetdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			debugdir(path.join("%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}"))
			objdir(path.join("!%{prj.location}", "%{cfg.architecture}", "%{cfg.buildcfg}", "intermediate", "%{prj.name}"))
			sysincludedirs(path.join(directory, "utils", "lzma", "C"))
			files({
				path.join(directory, "utils", "lzma", "C", "*.h"),
				path.join(directory, "utils", "lzma", "C", "*.c")
			})
			vpaths({
				["Header files/*"] = path.join(directory, "utils", "lzma", "C", "*.h"),
				["Source files/*"] = path.join(directory, "utils", "lzma", "C", "*.c"),
			})

	group("")
	project(_project.name)
end
