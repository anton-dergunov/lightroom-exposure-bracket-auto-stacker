--[[
Stand-ins for the Lightroom SDK calls the plugin makes, so its Lightroom-facing code runs under plain Lua.
Installs a global `import`, `_PLUGIN` and `WIN_ENV`, and returns `state`, which tests reset and inspect:
  state.folder      what the folder picker returns
  state.confirm     what LrDialogs.confirm returns ("ok" or "cancel")
  state.messages    dialogs shown: { title, text, style }
  state.catalog     photos added: { path, leader, position }; byPath indexes them
  state.sources     folder paths last passed to catalog:setActiveSources
  state.targets     photos catalog:getTargetPhotos returns (default: every photo)
Photos have the LrPhoto methods the plugin uses; tests set photo.exposureBias and photo.shutterSpeed directly.
]]

local state = {}

function state.reset(folder)
    state.folder = folder
    state.confirm = "ok"
    state.messages = {}
    state.catalog = { photos = {}, byPath = {} }
    state.sources = nil
    state.targets = nil
end

local catalog = {}

function catalog:findPhotoByPath(path)
    return state.catalog.byPath[path]
end

local Photo = {}
Photo.__index = Photo

function Photo:top() return self.leader or self end

function Photo:members()
    local top, list = self:top(), {}
    for _, photo in ipairs(state.catalog.photos) do
        if photo:top() == top then list[#list + 1] = photo end
    end
    return list
end

function Photo:getRawMetadata(key)
    if key == "isInStackInFolder" then return #self:members() > 1 end
    if key == "topOfStackInFolderContainingPhoto" then return self:top() end
    if key == "stackInFolderMembers" then return self:members() end
    return self[key]
end

function Photo:setRawMetadata(key, value) self[key] = value end

function catalog:getTargetPhotos()
    return state.targets or state.catalog.photos
end

function catalog:addPhoto(path, leader, position)
    if state.catalog.byPath[path] then error("The photo is already in the catalog: " .. path) end
    local photo = setmetatable({ path = path, leader = leader, position = position,
        localIdentifier = #state.catalog.photos + 1, pickStatus = 0 }, Photo)
    table.insert(state.catalog.photos, photo)
    state.catalog.byPath[path] = photo
    return photo
end

-- A folder exists once a photo in it has been added, as in Lightroom.
function catalog:getFolderByPath(path)
    for _, photo in ipairs(state.catalog.photos) do
        if photo.path:sub(1, #path + 1) == path .. "/" and not photo.path:sub(#path + 2):find("/") then
            return { path = path }
        end
    end
end

function catalog:setActiveSources(sources)
    state.sources = {}
    for i, source in ipairs(sources) do state.sources[i] = source.path end
    table.sort(state.sources)
    return true
end

function catalog:withWriteAccessDo(_, work)
    work()
    return "executed"
end

local modules = {
    LrApplication = { activeCatalog = function() return catalog end },
    LrDialogs = {
        runOpenPanel = function() return state.folder and { state.folder } end,
        confirm = function() return state.confirm end,
        message = function(title, text, style)
            table.insert(state.messages, { title = title, text = text, style = style })
        end,
        attachErrorDialogToFunctionContext = function() end,
    },
    LrFunctionContext = {
        postAsyncTaskWithContext = function(_, fn) fn({}) end,
    },
    LrProgressScope = setmetatable({}, { __call = function()
        return {
            done = function() end,
            setCancelable = function() end,
            isCanceled = function() return false end,
            setPortionComplete = function() end,
        }
    end }),
    LrTasks = {
        startAsyncTask = function(fn) fn() end,
        pcall = pcall,
        -- os.execute returns a number in Lua 5.1 and (ok, "exit", code) from 5.2 on.
        execute = function(command)
            local a, _, code = os.execute(command)
            if type(a) == "number" then return a end
            return code or (a and 0 or 1)
        end,
    },
    LrPathUtils = {
        child = function(path, name) return path .. "/" .. name end,
        getStandardFilePath = function() return os.getenv("TMPDIR") or "/tmp" end,
    },
    LrFileUtils = {
        exists = function(path)
            local file = io.open(path, "rb")
            if file then file:close() return "file" end
            return false
        end,
        readFile = function(path)
            local file = io.open(path, "rb")
            local text = file:read("*a")
            file:close()
            return text
        end,
        delete = function(path) os.remove(path) end,
        chooseUniqueFileName = function(path) return path .. "-" .. tostring(os.time()) .. "-" .. math.random(1e6) end,
    },
}

function import(name)
    return assert(modules[name], "no fake for " .. name)
end

_PLUGIN = { path = TEST_ROOT .. "/auto-stacker.lrdevplugin" }
WIN_ENV = false

state.reset(nil)
return state
