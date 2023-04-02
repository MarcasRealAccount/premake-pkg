local p    = premake
local pkg  = p.extensions.pkg
pkg.repo   = pkg.repo or {}
local repo = pkg.repo
pkg.pack   = pkg.pack or {}
local pack = pkg.pack
pack.dep   = pack.dep or {}
local dep  = pack.dep

p.override(p.main, "checkInteractive", function(base)
	for _, message in ipairs(pkg.messages) do
		if message.color then term.pushColor(message.color) end
		print(message.text)
		if message.color then term.popColor() end
	end
	if pkg.failed then
		error("Errors ^", 0)
	end
	base()
end)

function pkg:rmdir(dir)
	local realDir = path.translate(dir, "/") .. "/"
	
	if not os.isdir(realDir) then return end
	
	if os.host() == "windows" then
		os.executef("attrib -R -H -S %q /S /D", path.translate(path.normalize(realDir), "\\") .. "\\**")
	end
	os.rmdir(realDir)
end

function pkg:mkdir(dir)
	local realDir = path.translate(dir, "/") .. "/"
	
	if not os.isdir(realDir) then
		local curPath = ""
		for _, v in ipairs(realDir:explode("/")) do
			curPath = curPath .. v .. "/"
			if not os.isdir(curPath) then os.mkdir(curPath) end
		end
	end
end

function pkg:copyFile(from, to)
	local realFrom  = path.translate(from, "/")
	local realTo    = path.translate(to, "/")
	local realToDir = path.getdirectory(realTo) .. "/"
	
	self:mkdir(realToDir)
	os.copyfile(realFrom, realTo)
end

function pkg:copyFiles(from, filenames, to)
	if type(filenames) == "string" then return self:copyFiles(from, { filenames }, to) end
	if type(filenames) ~= "table" then return end
	for _, filename in pairs(filenames) do if type(filename) ~= "string" then return end end
	local realFrom = path.translate(from, "/") .. "/"
	local realTo   = path.translate(to, "/") .. "/"
	
	for _, filename in pairs(filenames) do
		self:copyFile(realFrom .. filename, realTo .. filename)
	end
end

function pkg:libName(libs, withSymbols)
	if type(libs) == "string" then return self:libName({ libs }, withSymbols) end
	if type(libs) ~= "table" then return {} end
	for _, lib in pairs(libs) do if type(lib) ~= "string" then return {} end end
	
	local libnames = {}
	for _, lib in pairs(libs) do
		local libname = lib
		if os.host() == "windows" then
			if withSymbols then
				table.insert(libnames, libname .. ".pdb")
			end
			libname = libname .. ".lib"
		else
			libname = "lib" .. libname .. ".a"
		end
		table.insert(libnames, libname)
	end
	return libnames
end

function pkg:formatString(fmt, replacements)
	while true do
		local i, j = fmt:find("%%{[^ \t\n}]*}")
		if i == nil then break end
		
		local replacementStr = fmt:sub(i + 2, j - 1)
		fmt = fmt:sub(1, i - 1) .. (replacements[replacementStr] or "") .. fmt:sub(j + 1)
	end
	return fmt
end

function pkg:pushMessage(text, color)
	table.insert(self.messages, { text = text, color = color })
end

function pkg:error(fmt, ...)
	self:pushMessage(string.format(fmt, ...), term.errorColor)
	self.failed = true
end

function pkg:pkgError(fmt, ...)
	self:error("%s for %s-%s", string.format(fmt, ...), self.currentPack.pack.name, tostring(self.currentPack.version.version))
end

function pkg:pkgErrorFF(fmt, ...)
	self:pkgError(fmt, ...)
	error(nil, 0)
end

function pkg:pushCurrentPackage(repo, package_, version)
	local pck = {
		repo    = repo,
		pack    = package_,
		version = version
	}
	table.insert(self.currentPacks, pck)
	self.currentPack = pck
end

function pkg:popCurrentPackage()
	self.currentPack = table.remove(self.currentPacks)
end

function pkg:getPacks(packName, isExt)
	local packs = {}
	
	for _, repo in ipairs(self.repos) do
		if isExt then
			for _, extension in ipairs(repo.exts) do
				if extension.name == packName then
					table.insert(packs, { extension, repo })
				end
			end
		else
			for _, package_ in ipairs(repo.pkgs) do
				if package_.name == packName then
					table.insert(packs, { package_, repo })
				end
			end
		end
	end
	
	return packs
end

function pkg:getLatestPackVer(packs, verRange)
	local bestRepo    = nil
	local bestPackage = nil
	local bestVersion = nil
	
	for _, pack in ipairs(packs) do
		for _, ver in ipairs(pack[1].versions) do
			if verRange:inRange(ver.version) then
				if not bestVersion or ver.version >= bestVersion.version then
					bestRepo    = pack[2]
					bestPackage = pack[1]
					bestVersion = ver
				end
			end
		end
	end
	
	return bestRepo, bestPackage, bestVersion
end

function pkg:runBuildScript(repo, pack, version, args)
	local rerun = false
	local succ  = true
	_PKG_ARGS   = args
	local suc, msg = pcall(function()
		rerun = dofile(version.dir .. "/" .. version.buildscript)
	end)
	if not suc then
		if msg then
			self:pkgError("Threw an exception in the build script\n%s", tostring(msg))
		end
		rerun = true
		succ  = false
	end
	_PKG_ARGS = nil
	if not rerun and repo.api:supportsBuilt() then
		io.writefile(string.format("%s/Bin/%s-%s.built", version.dir, os.host(), self.arch), "Built")
	end
	return succ
end

function pkg:runScript(repo, pack, version, args)
	local succ = true
	_PKG_ARGS  = args
	local suc, msg = pcall(function()
		dofile(version.dir .. "/" .. version.script)
	end)
	if not suc then
		if msg then
			self:pkgError("Threw an exception in the script\n%s", tostring(msg))
		end
		succ = false
	end
	_PKG_ARGS = nil
	return succ
end

function pkg:requirePackage(package_, isExt)
	if not self.fullSetup and not isExt then return false end

	self:loadRepos()

	local t = iif(isExt, "extension", "package")

	local packName, verRange, args = dep:splitPackName(package_)
	
	local packs = self:getPacks(packName, isExt)
	if not packs or #packs == 0 then
		self:error("Failed to find %s '%s'", t, packName)
		return false
	end
	
	local repo, pack_, version = self:getLatestPackVer(packs, verRange)
	if not version then
		self:error("Failed to find version for %s '%s' within range '%s'", t, packName, tostring(verRange))
		return false
	end
	
	self:pushCurrentPackage(repo, pack_, version)
	if not version.loaded then
		version.dir    = version.api:getPackDir(repo, pack_, version)
		version.loaded = version.api:load(repo, pack_, version)
		if not version.loaded then return false end
	end
	
	if version.buildscript and os.host() == os.target() then
		if repo.api:supportsBuilt() and not version.built then
			if os.isfile(string.format("%s/Bin/%s-%s.built", version.dir, os.host(), self.arch)) then
				version.built = true
			end
		end
		
		if not version.built then
			version.built = self:runBuildScript(repo, pack_, version, args)
			if not version.built then return false end
		end
	end
	self:runScript(repo, pack_, version, args)
	self:popCurrentPackage()
end

function pkg:loadRepos()
	if not self.reloadRepos then return end
	self.reloadRepos = false
	if not pkg.purged and _OPTIONS["pkg-purge-full"] then
		for _, api in pairs(self.repoapis) do
			api:purgeFull()
		end
		pkg.purged = true
	end
	for _, repo in ipairs(self.repos) do
		if not repo.loaded then
			repo.dir    = repo.api:getRepoDir(repo)
			repo.loaded = repo.api:load(repo)
		end
	end
end

function pkg:addRepo(name)
	local repoapi, repopath = repo:splitRepoName(name)
	local api = nil
	if not repoapi then
		self:error("Repo name '%s' needs to specify a repoapi like 'github+repopath'", name)
		return false
	end
	api = self.repoapis[repoapi]
	if not api then
		self:error("Repoapi '%s' does not exist for '%s'", repoapi, name)
		return false
	end
	repopath = api:normalizePath(repopath)
	for _, v in ipairs(self.repos) do
		if v.api == api and v.path == repopath then
			return true
		end
	end
	table.insert(self.repos, repo:new(api, repopath))
	self.reloadRepos = true
	return true
end

function pkgexts(extensions)
	if type(extensions) == "string" then return pkgexts({ extensions }) end
	
	local wrongTypes = false
	if type(extensions) ~= "table" then
		wrongTypes = true
	else
		for _, extension in pairs(extensions) do
			if type(extension) ~= "string" then
				wrongType = true
				break
			end
		end
	end
	if wrongTypes then
		pkg:error("pkgexts() requires string or table of strings")
		return false
	end
	
	for _, extension in pairs(extensions) do
		pkg:requirePackage(extension, true)
	end
	return true
end

function pkgdeps(dependencies)
	if type(dependencies) == "string" then return pkgdeps({ dependencies }) end
	
	local wrongTypes = false
	if type(dependencies) ~= "table" then
		wrongTypes = true
	else
		for _, dependency in pairs(dependencies) do
			if type(dependency) ~= "string" then
				wrongType = true
				break
			end
		end
	end
	if wrongTypes then
		pkg:error("pkgdeps() requires string or table of strings")
		return false
	end
	
	for _, dependency in pairs(dependencies) do
		pkg:requirePackage(dependency, false)
	end
	return true
end

function pkgrepos(repos)
	if type(repos) == "string" then return pkgrepos({ repos }) end
	
	local wrongTypes = false
	if type(repos) ~= "table" then
		wrongTypes = true
	else
		for _, repo in pairs(repos) do
			if type(repo) ~= "string" then
				wrongTypes = true
				break
			end
		end
	end
	if wrongTypes then
		pkg:error("pkgrepos() requires string or table of strings")
		return false
	end
	
	for _, repo in pairs(repos) do
		pkg:addRepo(repo)
	end
	return true
end

function pkgreposdir(dir)
	if type(dir) ~= "string" then
		pkg:error("pkgreposdir() requires string")
		return false
	end
	
	pkg.reposDir = path.getabsolute(path.normalize(dir))
	return true
end