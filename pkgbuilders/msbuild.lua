local p   = premake
local pkg = p.extensions.pkg

local function vsWhere(args)
	local out, err = os.outputof(string.format("\"C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe\" %s", args))
	if err ~= 0 then
		error(out)
	end
	return out
end

function pkg:getMSBuild(configs, buildDir)
	local info = self:getGenericBuildTool(configs, buildDir)
	
	info.msvcVersion = tonumber(vsWhere("-prerelease -latest -property catalog_productLine"):match("%d+"))
	info.vsVersion   = tonumber(vsWhere("-prerelease -latest -property catalog_productLineVersion"))
	info.path        = vsWhere("-prerelease -latest -property installationPath")
	info.msbuild     = path.translate(path.normalize(info.path .. "\\MSBuild\\Current\\Bin\\MSBuild.exe"), "\\")
	info.solution    = self.buildDir
	function info:setSolution(solution)
		self.solution = path.translate(path.normalize(solution), "\\")
	end
	function info:build()
		for config, data in pairs(self.configs) do
			if not os.executef("call %q -verbosity:minimal -p:Configuration=%s -m %q", self.msbuild, config, self.solution) then
				pkg:pkgError("Failed to build configuration '%s'", config)
			end
			
			for target, dat in pairs(data.data.targets) do
				common:copyFiles(string.format("%s/%s/%s/", self.buildDir, dat.path, config), dat.outputFiles, string.format("%s/%s-%s-%s/", self.binDir, common.host, common.arch, data.data.config))
			end
		end
	end
	return info
end