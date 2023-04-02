local p        = premake
local pkg      = p.extensions.pkg
pkg.builders   = pkg.builders or {}
local builders = pkg.builders
builders.gmake = builders.gmake or builders.generic:new()
local gmake    = builders.gmake

function gmake:new(configs, buildDir)
	local object = builders.generic.new(gmake)
	object:setup(configs, buildDir)
	return object
end

function gmake:setConfigDir(config, configDir)
	local cfg = self.configs[config]
	cfg.dir   = configDir
end

function gmake:setConfigArgs(config, args)
	local cfg = self.configs[config]
	cfg.args  = args
end

function gmake:build()
	for config, data in pairs(self.configs) do
		local targets = ""
		for target, dat in pairs(data.data.targets) do
			if targets:len() > 0 then
				targets = targets .. " "
			end
			targets  = targets .. target
			dat.dir = data.path .. pkg:formatString(self.pathFmt, { targetname = target, targetdir = dat.path, config = config })
		end
		
		if not os.executef("make -C %q -j %s %s", data.path, targets, data.args or "") then
			pkg:pkgError("Failed to build configuration '%s'", config)
			goto CONTINUE
		end
		
		for target, dat in pairs(data.data.targets) do
			pkg:copyFiles(dat.dir, dat.outputFiles, string.format("%s/%s-%s-%s/", self.binDir, os.host(), pkg.arch, data.data.config))
		end
		
		::CONTINUE::
	end
end