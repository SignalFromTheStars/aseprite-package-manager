-- Package Manager
--
-- version: 1.0.0
-- remote: https://github.com/SignalFromTheStars/aseprite-package-manager
------------------------------------------------------------
ScriptInfo = {
    version = Version("1.0.0"),
    remote = "https://github.com/SignalFromTheStars/aseprite-package-manager"
}

local function isCommandAvailable(command)
    return os.execute(command .. " --version 2>&1")
end

local function removeFile(path)
    if not path then
        return false
    end
    if app.os.name == "Windows" then
        return os.execute(string.format('del "%s"', path))
    elseif app.os.name == "Linux" or app.os.name == "macOS" then
        return os.execute(string.format('rm "%s"', path))
    end
end

local function findDownloader(command)
    if app.os.name == "Windows" then
        return 'powershell'
    elseif app.os.name == "Linux" or app.os.name == "macOS" then
        if isCommandAvailable("curl") then
            return 'curl'
        elseif isCommandAvailable("wget") then
            return 'wget'
        else
            app.alert("Cannot find a download tool like `curl`, `wget` or `powershell`")
            return
        end
    end
end

--local META_DATA_URI = "https://github.com/SignalFromTheStars/aseprite-package-manager/metadata.json"
local META_DATA_URI = "file:////Users/diana/Documents/MvB/aseprite-package-manager/src/metadata.json"
local DOWNLOADER = findDownloader()
local scriptsDir = app.fs.joinPath(app.fs.userConfigPath, "scripts")
if not app.fs.isDirectory(scriptsDir) then
    app.alert("Cannot find the scripts dir")
    return
end
local packageManagerDir = app.fs.joinPath(scriptsDir, "Package Manager") 
if not app.fs.isDirectory(packageManagerDir) then
    app.fs.makeDirectory(packageManagerDir)
end
local metaDataPath = app.fs.joinPath(packageManagerDir, "metadata.json")

local function downloadFile(url, savePath)
    local command

    if DOWNLOADER == "powershell" then
        command = string.format('powershell -Command "Invoke-WebRequest -Uri \"%s\" -OutFile \"%s\""', url, savePath)
    elseif DOWNLOADER == "curl" then
        command = string.format('curl -L -o "%s" "%s"', savePath, url)
    elseif DOWNLOADER == "wget" then
        command = string.format('wget -O "%s" "%s"', savePath, url)
    else 
        app.alert("Cannot find a download tool like `curl`, `wget` or `powershell`")
        return
    end

    -- download the file
    local result = os.execute(command)
    if result then
        -- print("Downloaded to: " .. savePath)
        return true
    else
        app.alert("Download Failed")
    end

    return false
end

-- in use for install and update (they are the same)
local function installScript(url, scriptPath)
    local scriptPathDir = app.fs.filePath(scriptPath)
    if not app.fs.isDirectory(scriptPathDir) then
        app.fs.makeAllDirectories(scriptPathDir)
    end

    downloadFile(url, scriptPath)

    -- reload script dir
    app.command.Refresh()

    app.alert{title="Install Package", text="The package is installed", buttons="OK"}
    return true
end

local function uninstallScript(scriptPath)
    if not removeFile(scriptPath) then
        app.alert("cannot remove the selected package")
        return false
    end

    -- remove the dir when empty
    local scriptPathDir = app.fs.filePath(scriptPath)
    local otherScriptsInPath = app.fs.listFiles(scriptPathDir)
    if #otherScriptsInPath == 0 then
        app.fs.removeDirectory(scriptPathDir)
    end

    -- reload script dir
    app.command.Refresh()

    app.alert{title="Uninstall Package", text="The package is removed", buttons="OK"}
    return true
end

local function readFileToString(filename)
    local file = io.open(filename, "r")
    if not file then
        return false
    end
    local content = file:read("*all") 
    file:close()
    return content
end

local btnText = {}

local function processMetaData(elm)
    if downloadFile(META_DATA_URI, metaDataPath) == false then
        app.alert("Cannot download the meta data, try again later")
        return false
    end

    -- read the json
    if app.version < Version("1.3-rc5") then
        app.alert("This Aseprite version is not support, update to the latest version")
        return false
    end
    local metaDataJson = readFileToString(metaDataPath)
    if metaDataJson == false then
        app.alert("Cannot read file")
        return false
    end

    local metaData= json.decode(metaDataJson)
    if not metaData then
        app.alert("Cannot process meta data")
        return false
    end

    local countPackages = #metaData
    for i, package in ipairs(metaData) do
        local scriptPath = app.fs.joinPath(packageManagerDir, package.category, package.scriptName)

        elm:newrow({ always=true })
            :label({ label="Vendor", text=package.vendor })
            :label({ label="Name", text=package.name })
            :label({ label="Description", text=package.description })
            :label({ label="Version", text=package.version .. " (" .. package.commit .. ")" })

        local isInstalled = app.fs.isFile(scriptPath)

        local btnId = "btnPackage" .. tostring(i)
        btnText[btnId] = nil
        if isInstalled then
            btnText[btnId] = "UNINSTALL"
        else
            btnText[btnId] = "INSTALL"
        end

        elm:button({
            id=btnId,
            text=btnText[btnId],
            selected=false,
            focus=false,
            onclick=function()

                if btnText[btnId] == "INSTALL" then
                    if installScript(package.url, scriptPath) then
                        btnText[btnId] = "UNINSTALL" -- the new situation
                    end
                elseif btnText[btnId] == "UNINSTALL" then
                    if uninstallScript(scriptPath) then
                        btnText[btnId] = "INSTALL" -- the new situation
                    end
                end

                dlg:modify({id=btnId, text=btnText[btnId]})
            end 
        })

        if btnText[btnId] == "UNINSTALL" then
            local btnPackageUpdateId = "btnPackageUpdate" .. tostring(i)
            elm:button({
                id=btnPackageUpdateId,
                text="UPDATE",
                selected=false,
                focus=false,
                onclick=function()
                    -- @todo update check
                    if installScript(package.url, scriptPath) then
                        dlg:modify({id=btnPackageUpdateId, text="UPDATED", visible = false})
                    end
                end 
            })
        end

        if i ~= countPackages then
            elm:separator()
        end
    end
end

dlg = Dialog({
    title = "Package Manager"
})
local tabPackages = dlg:tab({ id="packages",
        text="Packages",
    --  onclick=function(ev) 
    --     print("pressed tab: " .. ev.tab)
    -- end
        })

-- Load everything, it is not possible to add elements inside the tab at a later moment (@bug)
processMetaData(tabPackages)


local tabSettings = dlg:tab({ id="settings",
         text="Settings",
        --  onclick=function(ev) 
        --     print("pressed tab: " .. ev.tab)
        -- end
         })
local tabAbout = dlg:tab({ id="about",
    text="About",
    -- onclick=function(ev) 
    -- print("pressed tab: " .. ev.tab)
    -- end
})

dlg:endtabs({ id="wat",
    text="wat",
    -- onchange=function(ev)
    --     print("selected tab: " .. ev.tab)
    --  end 
})

--          dlg:separator{ text="Page 1" }:entry{ label="Data 1", id="data1" }
-- dlg:separator()




if app.isUIAvailable then
    dlg:show{ wait=true, autoscrollbars=true }
end
