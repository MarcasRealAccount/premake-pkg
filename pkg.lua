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
	common:fail("%s for %s-%s", string.format(msgFormat, ...), self.currentlyBuildingPackage.pack.name, self:semverToString(self.currentlyBuildingPackage.version.version))
end

function pkg:pkgErrorFF(msgFormat, ...)
	self:pkgError(msgFormat, ...)
	error(nil, 0)
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

function pkg:runBuildScript(repo, pack, version, args)
	local rerunBuildScriptNextTime = false
	
	_PKG_ARGS = args
	local suc, msg = pcall(function()
		rerunBuildScriptNextTime = dofile(version.fullPath .. "/" .. version.buildscript)
	end)
	if not suc and msg then
		self:pkgError("Threw an exception in the build script\n%s\n", tostring(msg))
	end
	_PKG_ARGS = nil
	
	return rerunBuildScriptNextTime
end

function pkg:runDepScript(repo, pack, version, args)
	_PKG_ARGS = args
	local suc, msg = pcall(function() dofile(version.fullPath .. "/" .. version.depscript) end)
	if not suc and msg then
		self:pkgError("Threw an exception in the dep script\n%s\n", tostring(msg))
	end
	_PKG_ARGS = nil
end

function pkg:requirePackage(pack)
	-- TODO(MarcasRealAccount): Implement cross compilation support through 'common.targetArchs'
	self:updateRepos()
	
	local packa, version, args = self:splitPkgName(pack)
	local packs                = self:getPackages(packa)
	if not packs or #packs == 0 then
		common:fail("Failed to find package '%s'", packa)
		return false
	end
	local range              = self:semverRange(version, true)
	local repo, packag, vers = self:getPkgVersion(packs, range)
	if not vers then
		common:fail("Failed to find version '%s' for package '%s'", version, packa)
		return false
	end
	
	if vers.loaded then
		self:runDepScript(repo, packag, vers)
		return true
	end
	
	self.currentlyBuildingPackage = { repo = repo, pack = packag, version = vers }
	local loaderAPI, filepath     = self:getLoaderAPI(vers.path)
	vers.loaded                   = true
	if not loaderAPI or not loaderAPI:loadPackage(repo, packag, vers, filepath) then
		return false
	end
	
	if not vers.built then
		if os.isfile(string.format("%s/Bin/%s-%s.built", vers.fullPath, common.host, common.arch)) then
			vers.built = true
		end
	end
	
	if not vers.built then
		if not self:runBuildScript(repo, packag, vers, args) then
			io.writefile(string.format("%s/Bin/%s-%s.built", vers.fullPath, common.host, common.arch), "Built")
		end
		vers.built = true
	end
	self:runDepScript(repo, packag, vers, args)
	self.currentlyBuildingPackage = { }
	return true
end

function pkgdeps(deps)
	if not common.fullSetup then
		return
	end

	if type(deps) ~= "table" and type(deps) ~= "string" then
		common:fail("pkgdeps argument #1 has to be either a table of strings or a string")
		return
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
			common:fail("pkgdeps argument #1 has to be either a table of strings or a string")
			return
		end
		
		pkg:requirePackage(dep)
	end
end
