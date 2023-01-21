local p             = premake
local pkg           = p.extensions.pkg
pkg.repoapis        = pkg.repoapis or {}
pkg.repoapis.github = pkg.repoapis.github or {}
local github        = pkg.repoapis.github

function github:updateRepo(repo, repoPath)
	repo.dir = pkg.dir .. "/repos/github-" .. repoPath:gsub("/", "-") .. "/"
	if os.isdir(repo.dir) then
		if _OPTIONS["pkg-purge"] then
			common:rmdir(repo.dir)
		else
			repo.cloned = true
		end
	end
	
	if not repo.cloned then
		local repoLink = string.format("https://github.com/%s.git", repoPath)
		if not os.executef("git clone \"%s\" \"%s\"", repoLink, repo.dir) then
			common.fail("Failed to clone repo '%s'", repoLink)
			return
		end
	elseif not os.executef("git -C \"%s\" pull -q", repo.dir) then
		common.fail("Failed to update repo '%s'", repo.dir)
	end
end