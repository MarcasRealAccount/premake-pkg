local p   = premake
local pkg = p.extensions.pkg

function pkg:formatString(fmt, replacements)
	while true do
		local i, j = fmt:find("%%{[^ \t\n}]*}")
		if i == nil then
			break
		end

		local replacementStr = fmt:sub(i + 2, j - 1)
		fmt = fmt:sub(1, i - 1) .. (replacements[replacementStr] or "") .. fmt:sub(j + 1)
	end
	return fmt
end

function pkg:pkgError(msgFormat, ...)
	error(string.format("%s for %s-%s", string.format(msgFormat, ...), self.currentlyBuildingPackage.pack.name, self.currentlyBuildingPackage.version.name))
end

function pkg:getGenericBuildTool(configs, buildDir)
	local info = { ["configs"] = {} }
	for _, config in ipairs(configs) do
		info.configs[config] = {}
	end
	info.binDir   = string.format("%s/Bin/", self.currentlyBuildingPackage.version.fullPath)
	info.buildDir = path.normalize(buildDir) .. "/"
	function info:mapConfigs(configMap)
		for config, data in pairs(configMap) do
			local cfg = self.configs[config]
			cfg.data  = data
		end
	end
	function info:cleanTemp()
		common:rmdir(self.buildDir)
	end
	return info
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
	local packs          = self:getPackages(packa)
	if not packs or #packs == 0 then
		error(string.format("Failed to find package '%s'", packa))
	end
	local range              = self:semverRange(version, true)
	local repo, packag, vers = self:getPkgVersion(packs, range)
	if not vers then
		error(string.format("Failed to find version '%s' for package '%s'", version, packa))
	end
	
	if vers.loaded then
		self:runDepScript(repo, packag, vers)
		return
	end
	
	self.currentlyBuildingPackage = { repo = repo, pack = packag, version = vers }
	local loaderAPI, filepath = self:getLoaderAPI(vers.path)
	loaderAPI:loadPackage(repo, packag, vers, filepath)
	vers.loaded = true
	
	if not vers.built then
		if os.isfile(string.format("%s/Bin/.built", vers.fullPath)) then
			vers.built = true
		end
	end
	
	if not vers.built then
		self:runBuildScript(repo, packag, vers)
		io.writefile(string.format("%s/Bin/.built", vers.fullPath), "Built")
		vers.built = true
	end
	self:runDepScript(repo, packag, vers)
	self.currentlyBuildingPackage = { }
end

function pkgdeps(deps)
	if not common.fullSetup then
		return
	end

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
