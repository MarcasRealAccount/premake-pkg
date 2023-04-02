local p          = premake
local pkg        = p.extensions.pkg
pkg.builders     = pkg.builders or {}
local builders   = pkg.builders
builders.premake = builders.premake or {}
local premake    = builders.premake

function premake:invokePremake(args)
	local repos = ""
	for _, v in ipairs(pkg.repos) do
		if repos:len() > 0 then
			repos = repos .. ","
		end
		repos = repos .. v.api.name .. "+" .. v.path
	end
	local cmd = string.format("%s %s --pkg-repos-dir=%q --pkg-repos=%q", _PREMAKE_COMMAND, args, pkg.reposDir, repos)
	return os.execute(cmd)
end

function premake:setup(wksName, arch, configs, dir, buildDir, outputDir)
	dir             = dir .. "/"
	buildDir        = path.getabsolute(buildDir, dir)
	local buildTool = nil
	if os.host() == "windows" then
		buildTool    = builders.msbuild:new(configs, buildDir)
		local action = string.format("vs%d", buildTool.vsVersion)
		if not self:invokePremake(action) then
			pkg:pkgErrorFF("Failed to run premake")
		end
		buildTool:setSolution(string.format("%s/%s.sln", buildDir, wksName))
	else
		buildTool = builders.gmake:new(configs, buildDir)
		if not self:invokePremake("gmake2") then
			pkg:pkgErrorFF("Failed to run premake")
		end
		for _, config in ipairs(configs) do
			buildTool:setConfigDir(config, buildDir)
			buildTool:setConfigArgs(config, string.format("config=%s_%s", config:lower(), arch:lower()))
		end
	end
	buildTool.pathFmt = outputDir
	return buildTool
end