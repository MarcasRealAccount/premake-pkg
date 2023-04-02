local p        = premake
local pkg      = p.extensions.pkg
pkg.packapis   = pkg.packapis or {}
local packapis = pkg.packapis
packapis.git   = packapis.git or {}
local git      = packapis.git

function git:getPackDir(repo, pack, version)
	return string.format("%s/%s/git/%s-%s", repo.dir, iif(pack.isExtension, "exts", "pkgs"), pack.name, tostring(version.version))
end

function git:load(repo, pack, version)
	local cloned = false
	local data   = version.data
	if os.isdir(version.dir) then
		local file = io.readfile(string.format("%s/%s", version.dir, ".pkgpatchversion"))
		local currentVersion = iif(file, tonumber(file), data.patch_version)
		cloned = currentVersion == data.patch_version
		if not cloned then
			pkg:rmdir(version.dir)
		end
	end
	
	if not cloned then
		local gitBranch = ""
		if data.branch then
			if data.commit then
				gitBranch = string.format("\"--branch=%s\"", data.branch)
			else
				gitBranch = string.format("--depth=1 \"--branch=%s\"", data.branch)
			end
		end
		
		if not os.executef("git clone %s \"%s\" \"%s\"", gitBranch, version.path, version.dir) then
			pkg:error("Failed to clone package '%s' version '%s'", pack.name, tostring(version.version))
			return false
		end
		
		if data.commit and not os.executef("git -C %q checkout %s", version.dir, data.commit) then
			pkg:error("Failed to checkout commit '%s' package '%s' version '%s'", data.commit, pack.name, tostring(version.version))
			return false
		end
		
		if data.apply_patch then
			if not os.executef("git -C \"%s\" am -q --no-gpg-sign \"%s/patches/%s-%s-%s.patch\"", version.dir, repo.dir, iif(pack.isExtension, "ext", "pkg"), pack.name, tostring(version.version)) then
				pkg:error("Failed to apply patch for package '%s' version '%s'", pack.name, tostring(version.version))
				return false
			end
			io.writefile(string.format("%s/%s", version.dir, ".pkgpatchversion"), tostring(data.patch_version))
		end
	end
	
	return true
end