local p          = premake
local pkg        = p.extensions.pkg
pkg.builders     = pkg.builders or {}
local builders   = pkg.builders
builders.msbuild = builders.msbuild or builders.generic:new()
local msbuild    = builders.msbuild

local function vsWhere(args)
	local out, err = os.outputof(string.format("\"C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe\" %s", args))
	if err ~= 0 then
		pkg:pkgErrorFF("VSWhere returned %s", out)
	end
	return out
end

function msbuild:new(configs, buildDir)
	local object = builders.generic.new(msbuild)
	object:setup(configs, buildDir)
	
	object.msvcVersion = tonumber(vsWhere("-prerelease -latest -property catalog_productLine"):match("%d+"))
	object.vsVersion   = tonumber(vsWhere("-prerelease -latest -property catalog_productLineVersion"))
	object.path        = vsWhere("-prerelease -latest -property installationPath")
	object.msbuild     = path.translate(path.normalize(object.path .. "\\MSBuild\\Current\\Bin\\MSBuild.exe"), "\\")
	object.solution    = object.buildDir
	return object
end

function msbuild:setSolution(solution)
	self.solution = path.translate(path.normalize(solution), "\\")
end

function msbuild:build()
	for config, data in pairs(self.configs) do
		for target, dat in pairs(data.data.targets) do
			dat.dir = self.buildDir .. pkg:formatString(self.pathFmt, { targetname = target, targetdir = dat.path, config = config })
		end
		
		if not os.executef("call %q -noLogo -verbosity:minimal -p:Configuration=%s -m %q", self.msbuild, config, self.solution) then
			pkg:pkgError("Failed to build configuration '%s'", config)
			goto CONTINUE
		end
		
		for target, dat in pairs(data.data.targets) do
			pkg:copyFiles(dat.dir, dat.outputFiles, string.format("%s/%s-%s-%s/", self.binDir, os.host(), pkg.arch, data.data.config))
		end
		
		::CONTINUE::
	end
end