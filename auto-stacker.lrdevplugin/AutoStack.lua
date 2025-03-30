local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrApplication = import 'LrApplication'

local function importAndGroupIntoStacks()
    LrTasks.startAsyncTask(function()
        local catalog = LrApplication.activeCatalog()
        
        local selectedFiles = LrDialogs.runOpenPanel({
            title = "Select text file with the list of grouped photos",
            canChooseFiles = true,
            allowsMultipleSelection = false,
            fileTypes = {'txt'}
        })

        if not selectedFiles or #selectedFiles == 0 then return end

        local txtFilePath = selectedFiles[1]
        local txtContent = LrFileUtils.readFile(txtFilePath)

        if not txtContent then
            LrDialogs.message("Error", "Failed to read the selected file.", "critical")
            return
        end

        local groupsOfImages = {}
        local currentGroup = {}
        local totalImageCount = 0
    
        for line in txtContent:gmatch("[^\r\n]+") do
            -- Trim whitespace from the line
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                if line == "#group" then
                    -- Start a new group when the marker is found
                    currentGroup = {}
                    table.insert(groupsOfImages, currentGroup)
                else
                    -- If there is no group yet, create a default one
                    if not currentGroup then
                        currentGroupp = {}
                        table.insert(groupsOfImages, currentGroup)
                    end
                    table.insert(currentGroup, line)
                    totalImageCount = totalImageCount + 1
                end
            end
        end

        catalog:withWriteAccessDo("Import and Stack Photos", function()
            for i, group in ipairs(groupsOfImages) do
                local stackLeader = nil
                
                for j, filePath in ipairs(group) do
                    if filePath and LrFileUtils.exists(filePath) then
                        if j == 1 then
                            -- Create stack leader without stacking options
                            stackLeader = catalog:addPhoto(filePath)
                        else
                            -- Stack subsequent photos under leader
                            catalog:addPhoto(filePath, stackLeader, 'below')
                        end
                    end
                end
            end
        end)
        
        LrDialogs.showBezel("Imported " .. tostring(totalImageCount) .. " photos and created " .. tostring(#groupsOfImages) .. " stacks")
    end)
end

importAndGroupIntoStacks()
