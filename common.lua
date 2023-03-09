if not common then
	common = {
		binDir      = "Bin/%{cfg.system}-%{cfg.platform}-%{cfg.buildcfg}/",
		objDir      = "Bin/Int-%{cfg.system}-%{cfg.platform}-%{cfg.buildcfg}/%{prj.name}/",
		dbgDir      = "/Run/",
		host        = os.host(),
		target      = os.target(),
		arch        = nil,
		targetArchs = nil,
		fullSetup   = true,
		failed      = false,
		messages    = {}
	}
end

newoption({
	trigger     = "target-arch",
	description = "Comma separated list of architectures to build (host == only host architecture)",
	value       = "architectures",
	default     = "host"
})

function common:makeMessage(text, color)
	return { text = text, color = color }
end

function common:pushMessage(message)
	table.insert(self.messages, message)
end

function common:fail(fmt, ...)
	self:pushMessage(self:makeMessage(string.format(fmt, ...), term.errorColor))
	self.failed = true
end

function common:projectName()
	return premake.api.scope.current.name
end

function common:projectLocation()
	return premake.api.scope.current.current.location
end

function common:projectStaticRuntime()
	return premake.api.scope.current.current.staticruntime
end

function common:addPCH(source, header)
	pchsource(source)
	filter("action:xcode4")
		pchheader(header)

	filter("action:not xcode4")
		pchheader(path.getname(header))

	filter({})

	forceincludes({ path.getname(header) })
end

function common:addActions()
	filter("files:**.inl")
		runclangformat(true)

	filter("files:**.h")
		runclangformat(true)

	filter("files:**.cpp")
		runclangformat(true)
		runclangtidy(true)

	filter({})
end

function common:addCoreDefines()
	filter("configurations:Debug")
		defines({ "BUILD_CONFIG=BUILD_CONFIG_DEBUG" })
		optimize("Off")
		symbols("On")

	filter("configurations:Release")
		defines({ "BUILD_CONFIG=BUILD_CONFIG_RELEASE" })
		optimize("Full")
		symbols("On")

	filter("configurations:Dist")
		defines({ "BUILD_CONFIG=BUILD_CONFIG_DIST" })
		optimize("Full")
		symbols("Off")

	filter("system:windows")
		toolset("msc")
		defines({
			"BUILD_SYSTEM=BUILD_SYSTEM_WINDOWS",
			"NOMINMAX", -- Windows.h disables
			"WIN32_LEAN_AND_MEAN",
			"_CRT_SECURE_NO_WARNINGS"
		})

	filter("system:macosx")
		toolset("clang")
		defines({ "BUILD_SYSTEM=BUILD_SYSTEM_MACOSX" })

	filter("system:linux")
		toolset("clang") -- Yes we hate gnu so why use gcc as the default toolset, just deal with it
		defines({ "BUILD_SYSTEM=BUILD_SYSTEM_LINUX" })

	filter("toolset:msc")
		defines({ "BUILD_TOOLSET=BUILD_TOOLSET_MSVC" })

	filter("toolset:clang")
		defines({ "BUILD_TOOLSET=BUILD_TOOLSET_CLANG" })

	filter("toolset:gcc")
		defines({ "BUILD_TOOLSET=BUILD_TOOLSET_GCC" })

	filter({})
end

function common:setConfigsAndPlatforms()
	configurations({ "Debug", "Release", "Dist" })
	platforms(self.targetArchs)

	for _, v in ipairs(self.targetArchs) do
		filter("platforms:" .. v)
			defines({ "BUILD_PLATFORM=BUILD_PLATFORM_" .. v:upper() })
			architecture(v)
	end
	filter({})
end

function common:outDirs(isStatic, targetSuffix)
	targetSuffix = targetSuffix or ""
	if isStatic then
		targetdir("%{wks.location}/" .. self.objDir .. targetSuffix)
		objdir("%{wks.location}/" .. self.objDir)
	else
		targetdir("%{wks.location}/" .. self.binDir .. targetSuffix)
		objdir("%{wks.location}/" .. self.objDir)
	end
end

function common:actionSupportsDebugDir()
	return _ACTION == "xcode4" or _ACTION == "gmake" or _ACTION == "gmake2" or _ACTION == "cmake"
end

function common:debugDir()
	local projectName     = self:projectName()
	local projectLocation = self:projectLocation()
	debugdir(projectLocation .. self.dbgDir)

	if common:actionSupportsDebugDir() then
		self:pushMessage(self:makeMessage(string.format("The '%s' action doesn't support debug directory.\nSo for the project '%s' you have to manually 'cd' into the directory: '%s%s'", _ACTION, projectName, projectLocation, self.dbgDir), term.warningColor))
	end
end

function common:scriptDir()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)")
end

function common:normalizedPath(filepath)
	return path.translate(filepath, "/")
end

function common:escapeChars(str)
	return str:gsub("\\", "\\\\")
end

function common:copyDirCommand(from, to)
	local realFrom = self:normalizedPath(os.realpath(from .. "/"), "/")
	local realTo = self:normalizedPath(os.realpath(to .. "/"), "/")

	if self.host == "windows" then
		return "xcopy /Q /E /Y /I \"" .. realFrom .. "\" \"" .. realTo .. "\""
	else
		return "cp -rf \"" .. realFrom .. "\" \"" .. realTo .. "\""
	end
end

function common:getScriptActionCommand(action)
	local commandArgs = "\"--file=" .. _MAIN_SCRIPT .. "\" "

	for k, v in pairs(_OPTION) do
		if k == "target-arch" then
			commandArgs = commandArgs .. "\"--" .. k .. "=%{cfg.architecture}\" "
		else
			commandArgs = commandArgs .. "\"--" .. k .. "=" .. v .. "\" "
		end
	end

	commandArgs = commandArgs .. action

	if self.host == "windows" then
		return self:escapeChars("\"" .. _PREMAKE_COMMAND .. "\" " .. commandArgs)
	else
		return self:escapeChars("'" .. _PREMAKE_COMMAND .. "' " .. commandArgs)
	end
end

function common:libName(names, withDebug)
	if type(names) == "table" then
		local libnames = {}

		for _, v in ipairs(names) do
			local libname = v
			if self.target == "windows" then
				if withDebug then
					table.insert(libnames, libname .. ".pdb")
				end
				libname = libname .. ".lib"
			else
				libname = "lib" .. libname .. ".a"
			end
			table.insert(libnames, libname)
		end

		return libnames
	else
		local libnames = self:libName({ names }, withDebug)
		if #libnames == 1 then return libnames[1] end
		return libnames
	end
end

function common:sharedLibName(names, withDebug)
	if type(names) == "table" then
		local libnames = {}

		for _, v in ipairs(names) do
			local libname = v
			if self.target == "windows" then
				if withDebug then
					table.insert(libnames, libname .. ".pdb")
				end
				libname = libname .. ".dll"
			elseif self.target == "macosx" then
				libname = "lib" .. libname .. ".dylib"
			else
				libname = "lib" .. libname .. ".a"
			end
			table.insert(libnames, libname)
		end

		return libnames
	else
		local libnames = self:sharedLibName({ names }, withDebug)
		if #libnames == 1 then return libnames[1] end
		return libnames
	end
end

function common:hasLib(lib, searchPaths)
	if type(searchPaths) ~= "table" then searchPaths = { searchPaths } end
	for _, searchPath in ipairs(searchPaths) do
		if #os.matchfiles(searchPath .. "/" .. self:libName(lib)) > 0 then
			return true
		end
	end
	return false
end

function common:hasSharedLib(lib, searchPaths)
	if type(searchPaths) ~= "table" then searchPaths = { searchPaths } end
	for _, searchPath in ipairs(searchPaths) do
		if #os.matchfiles(searchPath .. "/" .. self:sharedLibName(lib)) > 0 then
			return true
		end
	end
	return false
end

function common:rmdir(dir)
	local realDir = self:normalizedPath(dir) .. "/"

	if not os.isdir(realDir) then
		return 1, "'" .. dir .. "' is not a directory!"
	end

	if self.host == "windows" then
		os.executef("attrib -R -H -S %q /S /D", path.translate(path.normalize(realDir), "\\") .. "\\**")
	end
	local code, err = os.rmdir(realDir)
	if not code then return -4, err end

	return 0
end

function common:mkdir(dir)
	local realDir = self:normalizedPath(dir) .. "/"

	if not os.isdir(realDir) then
		local curPath = ""
		for _, v in ipairs(string.explode(realDir, "/")) do
			curPath = curPath .. v .. "/"
			local code, err = os.mkdir(curPath)
			if not code then return -2, err end
		end
	end

	return 0
end

function common:copyFile(from, to)
	local realFrom  = self:normalizedPath(from)
	local realTo    = self:normalizedPath(to)
	local realToDir = path.getdirectory(realTo) .. "/"

	local code, err = self:mkdir(realToDir)
	if code < 0 then return code, err end

	code, err = os.copyfile(realFrom, realTo)
	if not code then return -3, err end

	return 0
end

function common:copyFiles(from, filenames, to)
	if type(filenames) ~= "table" then
		filenames = { filenames }
	end
	local realFrom = self:normalizedPath(from) .. "/"
	local realTo   = self:normalizedPath(to) .. "/"

	local errors = {}
	for _, v in ipairs(filenames) do
		local code, err = self:copyFile(realFrom .. v, realTo .. v)
		if code < 0 then
			table.insert(errors, { code, err })
		end
	end

	return errors
end

function common:copyDir(from, to)
	local realFrom = self:normalizedPath(from) .. "/"
	local realTo   = self:normalizedPath(to) .. "/"

	if not os.isdir(realFrom) then
		return -1, "'" .. from .. "' is not a directory!"
	end

	local errors = {}
	local matches = os.matchfiles(realFrom .. "**")
	for _, v in ipairs(matches) do
		code, err = self:copyFile(v, realTo .. path.getrelative(realFrom, v))
		if code < 0 then
			table.insert(errors, { code, err })
		end
	end

	return errors
end

local function toPremakeArch(name)
	local lc = name:lower()
	if lc == "i386" then
		return "x86"
	elseif lc == "x86_64" or lc == "x64" then
		return "amd64"
	elseif lc == "arm32" then
		return "arm"
	else
		return lc
	end
end

local function getHostArch()
	local arch
	if common.host == "windows" then
		arch = os.getenv("PROCESSOR_ARCHITECTURE")
		if arch == "x86" then
			local is64 = os.getenv("PROCESSOR_ARCHITEW6432")
			if is64 then arch = is64 end
		end
	elseif common.host == "macosx" then
		arch = os.outputof("echo $HOSTTYPE")
	else
		arch = os.outputof("uname -m")
	end

	return toPremakeArch(arch)
end

local function getTargetArchs()
	if _OPTIONS["target-arch"] == "host" then
		return { common.arch }
	else
		local archs = string.explode(_OPTIONS["target-arch"], "%s*,%s*")
		local output = {}
		for _, arch in ipairs(archs) do
			table.insert(output, toPremakeArch(arch))
		end
		return output
	end
end

common.arch        = getHostArch()
common.targetArchs = getTargetArchs()

require("actions/clean")
require("actions/formattidy")

if not _ACTION or _ACTION == "clean" or _ACTION == "format" or _OPTIONS["help"] then
	common.fullSetup = false
end

term.warningColor = term.yellow
term.errorColor   = term.red
term.infoColor    = term.green

premake.override(premake.main, "checkInteractive", function(base)
	for _, message in ipairs(common.messages) do
		term.pushColor(message.color)
		print(message.text)
		term.popColor()
	end
	if common.failed then
		error("Errors ^", 0)
	end
	base()
end)