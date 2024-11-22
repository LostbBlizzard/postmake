---@nodoc
---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return


---@alias ostype
---| 'windows' [# Windows 10+]
---| 'macos' [# Mac OS X]
---| 'linux' [# GNU/Linux]
---| 'openbsd' [# Openbsd]

---@alias archtype
---| 'x64' [# The x86_64 CPU Architecture]
---| 'x32' [# The x86_32 CPU Architecture]
---| 'arm64' [# The Arm64 CPU Architecture]
---| 'universal' [# Any Architecture]


---@alias shellscriptstyle
---| 'classic' [Just a simple echo of the current task]
---| 'modern' [Progess Bars + Percent + echo of the current task]
---| 'hypermodern' [Color/Emoji and other hip things]


---@alias shellscriptcompressiontype
---| 'tar.gz' [tar.gz files]
---| 'zip' [zip files]


---@alias checksumtype
---| 'sha256' [SHA-2 (Secure Hash Algorithm 2)]
