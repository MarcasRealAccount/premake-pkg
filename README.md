# premake-pkg
A package and extension manager for premake, that supports Windows, Linux and MacOS

# How it works
To put it simply, the module downloads the dependencies of a project.  
This is done by first downloading repositories given with `pkgrepos({ "repoapi+path" })`,  
where repoapi and path defines a repository, like repoapi=github and path=MarcasRealAccount/premake-pkgs  
I.e. `pkgrepos({ "github+MarcasRealAccount/premake-pkgs" })`. (By default [premake-pkgs](https://github.com/MarcasRealAccount/premake-pkgs) is available)  
Then after downloading the repositories the premake script can then use `pkgdeps({ "package@version" })` to depend on a specific package version,  
`@version` may be omitted to specify the latest version (This is subject to change, as that might break in the future).  
The package manager then looks through all `repo.json` files in all loaded repositories in reverse order of pkgrepos, this is to allow overriding packages (may be handy at times).  
Once the package is found it checks if the given version exists or if not specified selects the latest version,  
it then downloads the package based on a `loaderapi+path` similar to repositories (`git` for git repos and none for a repo relative path, handy for repo packages or extensions).  
Once a package has been downloaded it will invoke a build script if the package hasn't been built already,  
this build script is located in the package itself (Most likely added via a git patch or similar),  
this script will setup the project and build it the same way it normally would be used,  
however it has to build every path (Debug, Release and Dist) in cmake that equates to (Debug, RelWithDebInfo, Release).  
After that it will invoke a dependency script which adds the output directory as a library path, adds links and external include dirs. (Though this isn't necessarily the case for all packages)  
There is also `pkgexts({})` which adds extensions. (These are handy to utilize in the [premake-system.lua](https://premake.github.io/docs/Locating-Scripts) file)

# How to use
All you need to do is clone this github repository. Find the [premake-system.lua](https://premake.github.io/docs/Locating-Scripts) file and add `require("premake-pkg")`
