---@nodoc
---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class GitHubActionExportVarable
---@field flag FlagObject
---@field isrequired boolean
local GitHubActionExportVarable = {}

---@class VersionSetting
---@field getdatabase? (string|fun(): string)
---@field actiondatabaseurl? string
---@field uploaddatabase? fun(newdatabase:string)
local VersionSetting = {}

---@class GitHubActionConfigDependencies
---@field linux? LinuxShellScriptConfigDependencies
---@field macos? MacOsShellScriptConfigDependencies
---@field windows? WindowsGithubConfigDependencies

---@class GithubActionConfigProxy
---@field path string
---@field program string
local GithubActionConfigProxy = {};

---@class GitHubActionConfig
---@field weburl string
---@field uploaddir? string
---@field version? VersionSetting
---@field singlefile? string
---@field compressiontype? shellscriptcompressiontype
---@field export GitHubActionExportVarable[]
---@field dependencies? GitHubActionConfigDependencies
---@field testmode? boolean
---@field proxy? GithubActionConfigProxy
---@field silent? boolean
---@field checksum? checksumtype
local GitHubActionConfig = {
	silent = false,
}



---@class ShellScriptConfigProxy
---@field uninstallcmd string
---@field program string
local ShellScriptConfigProxy = {};

---@class ShellScriptPlugin
local ShellScriptPlugin = {};

---@param input string
---@param uploadfilecontext { [string]: string }
---@param onadded fun(input : string,newfilename:string)?
---@return string
function ShellScriptPlugin.GetUploadfilePath(input, uploadfilecontext, onadded) end

---@class LinuxShellScriptConfigDependenciesPackages
---@field apt string[]
---@field pacman string[]
---@field yum string[]

---@class LinuxShellScriptConfigDependencies
---@field packages? LinuxShellScriptConfigDependenciesPackages

---@class MacOsShellScriptConfigDependencies

---@class WindowsGithubConfigDependencies

---@class ShellScriptConfigDependencies
---@field linux? LinuxShellScriptConfigDependencies
---@field macos? MacOsShellScriptConfigDependencies

---@class ShellScriptConfig
---@field weburl string
---@field uploaddir string
---@field proxy? ShellScriptConfigProxy
---@field uninstallfile? string
---@field singlefile? string
---@field testmode? boolean
---@field style? shellscriptstyle
---@field compressiontype? shellscriptcompressiontype
---@field dependencies? ShellScriptConfigDependencies
---@field silent? boolean
---@field checksum? checksumtype
local ShellScriptConfig = {
	style = 'classic',
	compressiontype = "tar.gz",
	silent = false,
}


---@class InnoSetupConfigProxy
---@field uninstallcmd string
---@field program string
---@field path string
local InnoSetupConfigProxy = {};

---@class InnoSetConfig
---@field LaunchProgram? string The Path to Launch On Startup.
---@field AppId string
---@field proxy? InnoSetupConfigProxy	
---@field DefaultGroupName? string	
---@field OutputBaseFilename? string	
---@field MyAppURL? string	
---@field MyAppExeName? string	
---@field MyAppPublisher? string	
---@field MyAppVersion? string	
---@field UninstallDelete? string[] Additional files or directories you want the uninstaller to delete See https://jrsoftware.org/ishelp/topic_uninstalldeletesection.htm
---@field silent? boolean
local InnoSetConfig = {
	silent = false,
}


---@class EnbedPlugin
local EnbedPlugin = {};

---@param basefile string
---@param outputfile string
---@param lang string
function EnbedPlugin.enbed(basefile, outputfile, lang) end

---@param callback fun(basefile:string, outputfile:string)
---@param lang string
function EnbedPlugin.addlang(lang, callback) end

---@param filepath string
---@param lang string
function EnbedPlugin.maketypedef(filepath, lang) end

---@class DpkgConfig
local DpkgConfig = {}
