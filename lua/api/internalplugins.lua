---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class GitHubActionConfig
---@field weburl string
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
local ShellScriptConfig = {}


---@class InnoSetupConfigProxy
---@field uninstallcmd string
---@field program string
local InnoSetupConfigProxy = {};

---@class InnoSetConfig
---@field LaunchProgram? string The Path to Launch On Startup.
---@field Appid string
---@field Proxy? InnoSetupConfigProxy	
local InnoSetConfig = {}
