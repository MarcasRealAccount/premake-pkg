local p   = premake
local pkg = p.extensions.pkg

function pkg:getVSInfo()
	local info = {}
	
	local versionIdStr = os.outputof("\"C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe\" -prerelease -latest -property catalog_productLine"):match("%d+")
	local versionStr   = os.outputof("\"C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe\" -prerelease -latest -property catalog_productLineVersion")
	local versionId    = tonumber(versionIdStr)
	local version      = tonumber(versionStr)
	info.path      = os.outputof("\"C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe\" -prerelease -latest -property installationPath")
	info.msbuild   = string.format("%s\\MSBuild\\Current\\Bin\\MSBuild.exe", info.path)
	info.buildTool = string.format("Visual Studio %d %d", versionId, version)
	function info:build(solution, configs)
		for config, data in pairs(configs) do
			if not os.executef("call %q -verbosity:minimal -p:Configuration=%s -m %q", path.translate(path.normalize(self.msbuild), "\\"), config, path.translate(path.normalize(solution), "\\")) then
				error(string.format("Failed to build configuration %s of package %s", config, pkg.currentlyBuildingPackage.pack.name))
			end
			
			local suffix = ""
			if data.isStaticRT then
				suffix = "-StaticRT"
			end
			common:copyFiles(data.path, data.outputFiles, string.format("%s/Bin/%s-%s-%s%s/", pkg.currentlyBuildingPackage.version.fullPath, common.host, common.arch, data.config, suffix))
		end
	end
	return info
end

function pkg:setupCMake(buildTool, dir, buildDir, args)
	if not os.executef("cmake --log-level=ERROR -S %q -B %q -G %q %s", dir, buildDir, buildTool, args) then
		error(string.format("Failed to run cmake for %s-%s", self.currentlyBuildingPackage.pack.name, self.currentlyBuildingPackage.version.name))
	end
end

function pkg:runBuildScript(repo, pack, version)
	dofile(version.fullPath .. "/" .. version.buildscript)
end

function pkg:runDepScript(repo, pack, version)
	dofile(version.fullPath .. "/" .. version.depscript)
end

function pkg:requirePackage(pack)
	self:updateRepos()
	
	local packa, version = self:splitPkgName(pack)
	local packag, repo   = self:getPackage(packa)
	if not packag then
		error(string.format("Failed to find package '%s'", packa))
	end
	local vers = self:getPkgVersion(packag, version)
	if not vers then
		error(string.format("Failed to find version '%s' for package '%s'", version, packa))
	end
	
	if vers.loaded then
		self:runDependencyScript(repo, packag, vers)
		return
	end
	
	local loaderAPI, filepath = self:getLoaderAPI(vers.path)
	loaderAPI:loadPackage(repo, packag, vers, filepath)
	vers.loaded = true
	
	if not vers.built then
		if os.isfile(string.format("%s/Bin/.built", vers.fullPath)) then
			vers.built = true
		end
	end
	
	if not vers.built then
		self.currentlyBuildingPackage = { repo = repo, pack = packag, version = vers }
		self:runBuildScript(repo, packag, vers)
		io.writefile(string.format("%s/Bin/.built", vers.fullPath), "Built")
		vers.built = true
	end
	self:runDepScript(repo, packag, vers)
end

function pkgdeps(deps)
	if type(deps) ~= "table" and type(deps) ~= "string" then
		error("pkgdeps argument #1 has to be either a table of strings or a string")
	end
	
	if type(deps) == "string" then
		pkgdeps({ deps })
		return
	end
	
	if #deps == 0 then
		return
	end
	
	for _, dep in ipairs(deps) do
		if type(dep) ~= "string" then
			error("pkgdeps argument #1 has to be either a table of strings or a string")
		end
		
		pkg:requirePackage(dep)
	end
end