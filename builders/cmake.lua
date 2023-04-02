local p        = premake
local pkg      = p.extensions.pkg
pkg.builders   = pkg.builders or {}
local builders = pkg.builders
builders.cmake = builders.cmake or {}
local cmake    = builders.cmake

function cmake:setup(prjName, configs, dir, buildDir, args)
	dir             = dir .. "/"
	buildDir        = path.getabsolute(buildDir, dir)
	local buildTool = nil
	if os.host() == "windows" then
		buildTool    = builders.msbuild:new(configs, buildDir)
		local cmakeG = string.format("Visual Studio %d %d", buildTool.msvcVersion, buildTool.vsVersion)
		if not os.executef("cmake --log-level=ERROR -S %q -B %q -G %q %s", dir, buildDir, cmakeG, args) then
			pkg:pkgErrorFF("Failed to run cmake")
		end
		buildTool:setSolution(string.format("%s/%s.sln", buildDir, prjName))
		buildTool.pathFmt = "%{targetdir}/%{config}"
	else
		buildTool = builders.gmake:new(configs, buildDir)
		for _, config in ipairs(configs) do
			local configDir = string.format("%s/%s/", buildDir, config)
			if not os.executef("cmake --log-level=ERROR -S %q -B %q -G %q -D CMAKE_BUILD_TYPE=%s %s", dir, configDir, "Unix Makefiles", config, args) then
				pkg:pkgErrorFF("Failed to run cmake for config '%s'", config)
			end
			buildTool:setConfigDir(config, configDir)
		end
		buildTool.pathFmt = "%{targetdir}/"
	end
	return buildTool
end