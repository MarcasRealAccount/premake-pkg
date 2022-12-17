local p   = premake
local pkg = p.extensions.pkg

local function invokePremake(args)
	return os.executef("%q %s", _PREMAKE_COMMAND, args)
end

function pkg:setupPremake(wksName, configs, dir, buildDir)
	dir      = dir .. "/"
	buildDir = path.getabsolute(buildDir, dir) .. "/"
	local buildTool = nil
	if common.host == "windows" then
		buildTool = self:getMSBuild(configs, buildDir)
		local action = string.format("vs%d", buildTool.vsVersion)
		if not invokePremake(action) then
			self:pkgError("Failed to run premake")
		end
		buildTool:setSolution(buildDir .. wksName .. ".sln")
	else
		buildTool = self:getGMake(configs, buildDir)
		if not invokePremake("gmake2") then
			self:pkgError("Failed to run premake")
		end
		
		for _, config in ipairs(configs) do
			buildTool:setConfigPath(config, buildDir)
			buildTool:setConfigArgs(config, string.format("config=%s", config))
		end
	end
	return buildTool
end