local p   = premake
local pkg = p.extensions.pkg

function pkg:setupCMake(prjName, configs, dir, buildDir, args)
	dir      = dir .. "/"
	buildDir = path.getabsolute(buildDir, dir) .. "/"
	local buildTool = nil
	if common.host == "windows" then
		buildTool    = self:getMSBuild(configs, buildDir)
		local cmakeG = string.format("Visual Studio %d %d", buildTool.msvcVersion, buildTool.vsVersion)
		if not os.executef("cmake --log-level=ERROR -S %q -B %q -G %q %s", dir, buildDir, cmakeG, args) then
			self:pkgError("Failed to run cmake")
		end
		buildTool:setSolution(buildDir .. prjName .. ".sln")

		for _, config in ipairs(configs) do
			local cfg = buildTool.configs[config]
			for target, data in pairs(cfg.data.targets) do
				data.fullPath = buildDir .. string.format("%s/%s", data.path, config)
			end
		end
	else
		buildTool = self:getGMake(configs, buildDir)
		for _, config in ipairs(configs) do
			local configPath = buildDir .. config .. "/"
			if not os.executef("cmake --log-level=ERROR -S %q -B %q -G %q -D CMAKE_BUILD_TYPE=%s %s", dir, configPath, "Unix Makefiles", config, args) then
				self:pkgError("Failed to run cmake in '%s'", config)
			end
			buildTool:setConfigPath(config, configPath)

			local cfg = buildTool.configs[config]
			for target, data in pairs(cfg.data.targets) do
				data.fullPath = configPath .. target
			end
		end
	end
	return buildTool
end
