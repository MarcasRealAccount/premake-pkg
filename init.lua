local scriptDir = debug.getinfo(1, "S").source:sub(2)
scriptDir       = scriptDir:match("(.*/)")

for _, file in ipairs(dofile(path.getabsolute("_manifest.lua", scriptDir))) do
	if file ~= "init.lua" then
		require(path.replaceextension(path.getabsolute(file, scriptDir), ""))
	end
end