local p   = premake
local pkg = p.extensions.pkg

function pkg:formatString(fmt, replacements)
	while true do
		local i, j = fmt:find("%%{%S*}")
		if i == nil then
			break
		end

		local replacementStr = fmt:sub(i + 2, j - 1)
		fmt = fmt:sub(1, i) .. (replacements[replacementStr] or "") .. fmt:sub(j)
	end
	return fmt
end

local function invokePremake(args)
	return os.executef("%q %s", _PREMAKE_COMMAND, args)
end

function pkg:setupPremake(wksName, arch, configs, dir, buildDir, outputDir)
	dir             = dir .. "/"
	buildDir        = path.getabsolute(buildDir, dir) .. "/"
	local buildTool = nil
	if common.host == "windows" then
		buildTool    = self:getMSBuild(configs, buildDir)
		local action = string.format("vs%d", buildTool.vsVersion)
		if not invokePremake(action) then
			self:pkgErrorFF("Failed to run premake")
		end
		buildTool:setSolution(buildDir .. wksName .. ".sln")
	else
		buildTool = self:getGMake(configs, buildDir)
		if not invokePremake("gmake2") then
			self:pkgErrorFF("Failed to run premake")
		end
		
		for _, config in ipairs(configs) do
			buildTool:setConfigPath(config, buildDir)
			buildTool:setConfigArgs(config, string.format("config=%s_%s", config:lower(), arch:lower()))
		end
	end
	buildTool.pathFmt = outputDir
	return buildTool
end
