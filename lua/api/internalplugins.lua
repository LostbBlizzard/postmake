---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class GitHubActionConfig
---@field weburl string
---@field uploaddir? string
local GitHubActionConfig = {}

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

---@class ShellScriptConfig
---@field weburl string
---@field uploaddir string
---@field proxy? ShellScriptConfigProxy
---@field uninstallfile? string
---@field testmode? boolean
local ShellScriptConfig = {}


---@class InnoSetupConfigProxy
---@field uninstallcmd string
---@field program string
---@field path string
local InnoSetupConfigProxy = {};

---@class InnoSetConfig
---@field LaunchProgram? string The Path to Launch On Startup.
---@field Appid string
---@field proxy? InnoSetupConfigProxy	
---@field DefaultGroupName? string	
---@field OutputBaseFilename? string	
---@field MyAppURL? string	
---@field MyAppExeName? string	
---@field MyAppPublisher? string	
---@field MyAppVersion? string	
---@field AppId string	
---@field UninstallDelete? string[] Additional files or directories you want the uninstaller to delete See https://jrsoftware.org/ishelp/topic_uninstalldeletesection.htm
local InnoSetConfig = {}


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
