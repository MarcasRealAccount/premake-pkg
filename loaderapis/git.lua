local p            = premake
local pkg          = p.extensions.pkg
pkg.loaderapis     = pkg.loaderapis or {}
pkg.loaderapis.git = pkg.loaderapis.git or {}
local git          = pkg.loaderapis.git

function git:loadPackage(repo, pack, version, filepath)
	local prefix = "pkg"
	if pack.isExtension then
		prefix = "ext"
	end
	version.fullPath = path.getabsolute(string.format("%ss/%s-%s", prefix, pack.name, version.name), repo.dir) .. "/"
	if os.isdir(version.fullPath) then
		-- Defo make better
		version.cloned = true
	end
	
	if not version.cloned then
		local gitBranch = ""
		if version.branch then
			gitBranch = string.format("\"--branch=%s\"", version.branch)
		end
		
		if not os.executef("git clone --depth=1 %s \"%s\" \"%s\"", gitBranch, filepath, version.fullPath) then
			error(string.format("Failed to clone package '%s' version '%s'", pack.name, version.name))
		end
		
		if version.apply_patch then
			if not os.executef("git -C \"%s\" am -q --no-gpg-sign \"%s/patches/%s-%s-%s.patch\"", version.fullPath, repo.dir, prefix, pack.name, version.name) then
				error(string.format("Failed to apply patch for package '%s' version '%s'", pack.name, version.name))
			end
		end
	else
		if not os.executef("git -C \"%s\" pull -q", version.fullPath) then
			error(string.format("Failed to update package '%s' version '%s'", pack.name, version.name))
		end
	end
end