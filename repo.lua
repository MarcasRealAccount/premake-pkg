local p   = premake
local pkg = p.extensions.pkg

function pkg:splitPkgName(name)
	local index   = name:find("@", 1, true)
	if not index then
		return name, ""
	end
	return name:sub(1, index - 1), name:sub(index + 1)
end

function pkg:addRepo(repo)
	table.insert(self.repos, {
		path    = repo,
		updated = false,
		cloned  = false
	}, 1)
	self.updateRepos = true
end

function pkg:updateRepo(repo)
	if not repo then
		error("pkg repo is nil")
	end

	if not repo.path then
		error("pkg repo is missing a path")
	end

	if type(repo.path) ~= "string" then
		error("pkg repo path has to be a string")
	end

	local path     = repo.path
	local index    = path:find("+", 1, true)
	if not index then
		error(string.format("'%s' doesn't use an api, if github repo add 'github+'", path))
	end
	local apiName  = path:sub(1, index - 1)
	local repoPath = path:sub(index + 1)
	local repoapi  = pkg.repoapis[apiName]
	if not repoapi then
		error(string.format("'%s' uses unknown api '%s'", path, apiName))
	end
	repo.api     = repoapi
	repo.updated = true
	repoapi:updateRepo(repo, repoPath)
	repo.data = json.decode(io.readfile(string.format("%s/repo.json", repo.dir)))
	for _, extension in ipairs(repo.data.exts) do
		extension.isExtension = true
	end
	for _, pack in ipairs(repo.data.pkgs) do
		pack.isExtension = false
	end
end

function pkg:updateRepos()
	if not self.reloadRepos then
		return
	end
	self.reloadRepos = false
	-- TODO(MarcasRealAccount): Implement a way to prune a repository
	for _, repo in ipairs(self.repos) do
		if not repo.updated then
			pkg:updateRepo(repo)
		end
	end
end

function pkg:getExtension(ext)
	for _, repo in ipairs(self.repos) do
		for _, extension in ipairs(repo.data.exts) do
			if extension.name == ext then
				return extension, repo
			end
		end
	end
	
	return nil, nil
end

function pkg:getPackage(pack)
	for _, repo in ipairs(self.repos) do
		for _, packa in ipairs(repo.data.pkgs) do
			if packa.name == pack then
				return packa, repo
			end
		end
	end
	
	return nil, nil
end

function pkg:getPkgVersion(pack, version)
	if not version or version:len() == 0 then
		version = pack.latest_version
	end
	
	for _, ver in ipairs(pack.versions) do
		if ver.name == version then
			return ver
		end
	end
	return nil
end

function pkgrepos(repos)
	if type(repos) ~= "table" and type(repos) ~= "string" then
		error("pkgrepos argument #1 has to be either a table of strings or a string")
	end
	
	if type(repos) == "string" then
		pkgrepos({ repos })
		return
	end
	
	for _, repo in ipairs(repos) do
		if type(repo) ~= "string" then
			error("pkgrepos argument #1 has to be either a table of strings or a string")
		end
		
		pkg:addRepo(repo)
	end
end