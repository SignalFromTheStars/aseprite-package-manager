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

local function downloadScript(url, category, targetName)
    local scriptPath = app.fs.joinPath(packageManagerDir, category)
    if not app.fs.isDirectory(scriptPath) then
        app.fs.makeAllDirectories(scriptPath)
    end

    downloadFile(url, app.fs.joinPath(scriptPath, targetName))

    print("I cannot rescan the scripts directory press F5")
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
        elm:newrow({ always=true })
            :label({ label="Vendor", text=package.vendor })
            :label({ label="Name", text=package.name })
            :label({ label="Description", text=package.description })
            :label({ label="Version", text=package.version .. " (" .. package.commit .. ")" })
            :button({
            text="INSTALL",
            selected=false,
            focus=false,
            onclick=function()
                downloadScript(package.url, package.category, package.scriptName)
            end })
            :button({
                text="WEBSITE",
                selected=false,
                focus=false,
                onclick=function() end })

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





dlg:show{ wait=true, autoscrollbars=true }

