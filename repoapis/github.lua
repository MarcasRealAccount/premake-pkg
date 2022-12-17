local p             = premake
local pkg           = p.extensions.pkg
pkg.repoapis        = pkg.repoapis or {}
pkg.repoapis.github = pkg.repoapis.github or {}
local github        = pkg.repoapis.github

function github:updateRepo(repo, repoPath)
	repo.dir = pkg.dir .. "/repos/github-" .. repoPath:gsub("/", "-") .. "/"
	if os.isdir(repo.dir) then
		-- TODO(MarcasRealAccount): Implement a way to prune a repository
		repo.cloned = true
	end
	
	if not repo.cloned then
		local repoLink = string.format("https://github.com/%s.git", repoPath)
		if not os.executef("git clone \"%s\" \"%s\"", repoLink, repo.dir) then
			error(string.format("Failed to clone repo '%s'", repoLink))
		end
	else
		if not os.executef("git -C \"%s\" pull -q", repo.dir) then
			error(string.format("Failed to update repo '%s'", repo.dir))
		end
	end
end