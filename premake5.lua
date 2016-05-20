require "msvc_xp"

ROOT_DIR = (path.getabsolute(path.getdirectory(_SCRIPT)) .. "/")
BUILD_DIR = (ROOT_DIR .. ".build/")
OBJ_DIR = (BUILD_DIR .. "obj/" .. _ACTION .. "/")
SRC_DIR = (ROOT_DIR .. "src/")
MINILUA = (BUILD_DIR .. "bin/" .. _ACTION .. "/%{cfg.architecture}/minilua")
BUILDVM = (BUILD_DIR .. "bin/" .. _ACTION .. "/%{cfg.architecture}/buildvm")

workspace "luajit"
	platforms {"x86", "x64"}
	configurations {"Release", "Release-static"}

	location (BUILD_DIR .. "projects/" .. _ACTION .. "/")
	objdir (BUILD_DIR .. "%{cfg.platform}_" .. _ACTION .. "/obj/%{cfg.buildcfg}/%{prj.name}")
	targetdir ("lib/" .. _ACTION .. "/%{cfg.architecture}/")

	debugformat "c7"
	editandcontinue "Off"
	nativewchar "on"
	optimize "Speed"

	flags {
		"NoMinimalRebuild",
		"NoPCH",
		"Symbols",
		"Unicode",
		"FatalWarnings",
	}

	filter "Release-static"
		targetsuffix "-static"
		flags {
			"StaticRuntime",
		}

	filter "system:windows"
		defines {
			"_CRT_SECURE_NO_WARNINGS",
		}
	filter {}

project "minilua"
	language "C"
	kind "ConsoleApp"
	targetdir (BUILD_DIR .. "bin/" .. _ACTION .. "/%{cfg.architecture}/")

	files {
		"src/host/minilua.c"
	}

project "buildvm"
	language "C"
	kind "ConsoleApp"
	targetdir (BUILD_DIR .. "bin/" .. _ACTION .. "/%{cfg.architecture}/")

	dependson "minilua"

	filter {'files:src/vm_x86.dasc', 'platforms:x86'}
		buildcommands {
			MINILUA .. " " .. ROOT_DIR .. "dynasm/dynasm.lua -LN -D WIN -D JIT -D FFI -o %{cfg.objdir}/buildvm_arch.h " .. ROOT_DIR .. "src/vm_x86.dasc",
		}
	filter {'files:src/vm_x86.dasc', 'platforms:x64'}
		buildcommands {
			MINILUA .. " " .. ROOT_DIR .. "dynasm/dynasm.lua -LN -D WIN -D JIT -D FFI -D P64 -o %{cfg.objdir}/buildvm_arch.h " .. ROOT_DIR .. "src/vm_x86.dasc",
		}
	filter 'files:src/vm_x86.dasc'
		buildmessage 'Compiling %{file.relpath}'
		buildoutputs {
			"host/buildvm_arch.h",
		}
	filter {}

	includedirs {
		"%{cfg.objdir}/",
		SRC_DIR,
	}
	files {
		SRC_DIR .. "vm_x86.dasc",
		SRC_DIR .. "host/buildvm*.c",
	}

project "luajit"
	language "C"
	kind "StaticLib"

	local ALLLIB = SRC_DIR .. "lib_base.c " .. SRC_DIR .. "lib_math.c " .. SRC_DIR .. "lib_bit.c " .. SRC_DIR .. "lib_string.c " .. SRC_DIR .. "lib_table.c " .. SRC_DIR .. "lib_io.c " .. SRC_DIR .. "lib_os.c " .. SRC_DIR .. "lib_package.c " .. SRC_DIR .. "lib_debug.c " .. SRC_DIR .. "lib_jit.c " .. SRC_DIR .. "lib_ffi.c"
	prebuildcommands {
		BUILDVM .. " -m peobj -o %{cfg.objdir}/lj_vm.obj",
		BUILDVM .. " -m bcdef -o %{cfg.objdir}/lj_bcdef.h " .. ALLLIB,
		BUILDVM .. " -m ffdef -o %{cfg.objdir}/lj_ffdef.h " .. ALLLIB,
		BUILDVM .. " -m libdef -o %{cfg.objdir}/lj_libdef.h " .. ALLLIB,
		BUILDVM .. " -m recdef -o %{cfg.objdir}/lj_recdef.h " .. ALLLIB,
		BUILDVM .. " -m vmdef -o %{cfg.objdir}/vmdef.lua " .. ALLLIB,
		BUILDVM .. " -m folddef -o %{cfg.objdir}/lj_folddef.h " .. SRC_DIR .. "lj_opt_fold.c",
	}

	dependson "buildvm"

	includedirs {
		"%{cfg.objdir}",
		SRC_DIR,
	}
	linkoptions {
		"%{cfg.objdir}/lj_vm.obj",
	}
	files {
		SRC_DIR .. "lj_*.c",
		SRC_DIR .. "lib_*.c",
	}

project "luajit-cmd"
	language "C"
	kind "ConsoleApp"
	targetdir (BUILD_DIR .. "bin/" .. _ACTION .. "/%{cfg.architecture}/")

	links {
		"luajit",
	}

	files {
		SRC_DIR .. "luajit.c",
	}

