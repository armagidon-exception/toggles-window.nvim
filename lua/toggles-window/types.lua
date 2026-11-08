---@meta toggles-window

---@class (exact) toggles-window.Config
---@field icons? toggles-window.IconOpts
---@field max_width? integer
---@field max_height? integer
---@field title? string
---@field border? "bold"|"double"|"none"|"rounded"|"shadow"|"single"|"solid"|toggles-window.CustomBorder
---@field expose_toggles? toggles-window.ExposedToggle[]

---@class (exact) toggles-window.IconOpts
---@field disabled_icon? string
---@field enabled_icon? string

---@alias toggles-window.CustomBorder [string,string,string,string,string,string,string,string]

---@class (exact) toggles-window.win
---@field win integer
---@field current_win integer
---@field buf integer
---@field lines_to_toggles snacks.toggle.Class[]

---@class (exact) toggles-window
---@field private config toggles-window.Config
---@field private ns integer
---@field private win? toggles-window.win

---@alias toggles-window.ExposedToggle string|fun():snacks.toggle.Class
