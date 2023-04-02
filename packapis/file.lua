local p        = premake
local pkg      = p.extensions.pkg
pkg.packapis   = pkg.packapis or {}
local packapis = pkg.packapis
packapis.file  = packapis.file or {}
local file     = packapis.file

function file:getPackDir(repo, pack, version)
	return string.format("%s/%s", repo.dir, version.path)
end

function file:load(repo, pack, version)
	return true
end