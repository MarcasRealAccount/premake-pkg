local p   = premake
local api = p.api

p.extensions     = p.extensions or {}
p.extensions.pkg = p.extensions.pkg or {
	_VERSION     = "2.0.0",
	dir          = "",
	reposDir     = "",
	arch         = "",
	reloadRepos  = true,
	fullSetup    = true,
	purged       = false,
	failed       = false,
	messages     = {},
	repos        = {},
	currentPacks = {},
	currentPack  = {
		repo    = nil,
		pack    = nil,
		version = nil
	}
}
local pkg = p.extensions.pkg

if not _ACTION or _ACTION == "clean" or _ACTION == "format" or _OPTIONS["help"] then
	pkg.fullSetup = false
end

local function toPremakeArch(name)
	local lc = name:lower()
	if lc == "i386" then
		return "x86"
	elseif lc == "x86_64" or lc == "x64" then
		return "amd64"
	elseif lc == "arm32" then
		return "arm"
	else
		return lc
	end
end

local function getHostArch()
	local arch
	if os.host() == "windows" then
		arch = os.getenv("PROCESSOR_ARCHITECTURE")
		if arch == "x86" then
			local is64 = os.getenv("PROCESSOR_ARCHITEW6432")
			if is64 then arch = is64 end
		end
	elseif os.host() == "macosx" then
		arch = os.outputof("echo $HOSTTYPE")
	else
		arch = os.outputof("uname -m")
	end

	return toPremakeArch(arch)
end

function pkg:scriptDir()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)")
end

newoption({
	trigger     = "pkg-purge-full",
	description = "Deletes all repositories first",
	category    = "pkg"
})

newoption({
	trigger     = "pkg-repos-dir",
	description = "Overrides base repos directory",
	category    = "pkg",
	value       = "path",
	default     = pkg:scriptDir() .. "/repos/"
})

newoption({
	trigger     = "pkg-repos",
	description = "Comma separated list of repos",
	category    = "pkg",
	value       = "csv",
	default     = "github+MarcasRealAccount/premake-pkgs"
})

pkg.dir      = pkg:scriptDir()
pkg.reposDir = path.getabsolute(path.normalize(_OPTIONS["pkg-repos-dir"]))
pkg.arch     = getHostArch()

return true