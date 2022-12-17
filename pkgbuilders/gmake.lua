local p   = premake
local pkg = p.extensions.pkg

function pkg:getGMake(configs, buildDir)
	local info = self:getGenericBuildTool(configs, buildDir)
	
	function info:setConfigPath(config, configPath)
		local cfg = self.configs[config]
		cfg.path  = configPath
	end
	function info:setConfigArgs(config, args)
		local cfg = self.configs[config]
		cfg.args  = args
	end
	function info:build()
		for config, data in pairs(self.configs) do
			local targets = ""
			for target, dat in pairs(data.data.targets) do
				if targets:len() > 0 then
					targets = targets .. " "
				end
				targets = targets .. target
			end
			
			if not os.executef("make -C %q -j %s %s", data.path, targets, data.args) then
				pkg:pkgError("Failed to build configuration '%s'", config)
			end
			
			for target, dat in pairs(data.data.targets) do
				common:copyFiles(string.format("%s/%s/", data.path, dat.path), dat.outputFiles, string.format("%s/%s-%s-%s/", self.binDir, common.host, common.arch, data.data.config))
			end
		end
	end
	return info
end