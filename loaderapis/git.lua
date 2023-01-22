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
	version.fullPath = path.getabsolute(string.format("%ss/%s-%s", prefix, pack.name, pkg:semverToString(version.version)), repo.dir) .. "/"
	if os.isdir(version.fullPath) then
		local file = io.readfile(string.format("%s/%s", version.fullPath, ".pkgpatchversion"))
		local currentVersion = iif(file ~= nil, tonumber(file), version.patch_version)
		version.cloned = currentVersion == version.patch_version
		if not version.cloned then
			local code, err = common:rmdir(version.fullPath)
			if code < 0 then pkg:pkgError(err) end
		end
	end
	
	if not version.cloned then
		local gitBranch = ""
		if version.branch then
			if version.commit then
				gitBranch = string.format("\"--branch=%s\"", version.branch)
			else
				gitBranch = string.format("--depth=1 \"--branch=%s\"", version.branch)
			end
		end
		
		if not os.executef("git clone %s \"%s\" \"%s\"", gitBranch, filepath, version.fullPath) then
			common:fail("Failed to clone package '%s' version '%s'", pack.name, pkg:semverToString(version.version))
			return false
		end
		
		if version.commit and not os.executef("git -C %q checkout %s", version.fullPath, version.commit) then
			common:fail("Failed to checkout commit '%s' package '%s' version '%s'", verison.commit, pack.name, pkg:semverToString(version.version))
			return false
		end
		
		if version.apply_patch then
			if not os.executef("git -C \"%s\" am -q --no-gpg-sign \"%s/patches/%s-%s-%s.patch\"", version.fullPath, repo.dir, prefix, pack.name, pkg:semverToString(version.version)) then
				common:fail("Failed to apply patch for package '%s' version '%s'", pack.name, pkg:semverToString(version.version))
				return false
			end
			io.writefile(string.format("%s/%s", version.fullPath, ".pkgpatchversion"), tostring(version.patch_version))
		end
	end
	
	return true
end