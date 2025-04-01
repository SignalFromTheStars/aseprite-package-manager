-- Package Manager
--
-- version: 1.0.0
-- remote: https://github.com/SignalFromTheStars/aseprite-package-manager
------------------------------------------------------------
ScriptInfo = {
    version = Version("1.0.0"),
    remote = "https://github.com/SignalFromTheStars/aseprite-package-manager"
}

if not app.isUIAvailable then
    return;
end

dlg = Dialog({title = "Package Manager"})

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

local function getKeys(tbl)
    if tbl == nil then 
        return {}
    end
    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

local function updateInfo(id, package)
    -- reset
    -- dlg:modify({id="vendor".. id, text=""})
    -- dlg:modify({id="description" .. id, text=""})
    -- dlg:modify({id="version" .. id, text=""})
    -- dlg:modify({id="action" .. id, text="", visible = false})

    if not package then
        return
    end

    dlg:modify({id="vendor" .. id, text=package.vendor})
    dlg:modify({id="description" .. id, text=package.description})
    dlg:modify({id="version" .. id, text=package.version})

    if package.isInstalled then
        dlg:modify({id="action" .. id, text="UNINSTALL", visible = true})
    else
        dlg:modify({id="action" .. id, text="INSTALL", visible = true})
    end

end

local packagesInstallOptions = {}
local packagesUninstallOptions = {}
local packagesUpdateOptions = {}

local function processMetaData()
    -- reset
    packagesInstallOptions = {}
    packagesUninstallOptions = {}
    packagesUpdateOptions = {}

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

    for i, package in ipairs(metaData) do
        package.scriptPath = app.fs.joinPath(packageManagerDir, package.category, package.scriptName)
        package.isInstalled = app.fs.isFile(package.scriptPath)

        local keyName = package.vendor .. " : " .. package.name
        if package.isInstalled then 
            packagesUninstallOptions[keyName] = package
        else
            packagesInstallOptions[keyName] = package 
        end
    end
end

local function setTabName(id, options)
    if id == "packages" then
        return "Packages (" .. #getKeys(options) .. ")"
    elseif id == "updates" then
        return "Updates (" .. #getKeys(options) .. ")"
    elseif id == "installed" then
        return "Installed (" .. #getKeys(options) .. ")"
    end
end


-- type == package , updates, instal
local function uiTab(id, options)
    
    dlg:combobox({
        id = id,
        option = "",
        options = {"", table.unpack(getKeys(options))},
        onchange=function(e)
            if id == "package" then
                updateInfo(id, options[dlg.data.package])
            elseif id == "updates" then
                updateInfo(id, options[dlg.data.updates])
            elseif id == "installed" then
                updateInfo(id, options[dlg.data.installed])
            end
        end
    })

    dlg:separator()
    dlg:label({ id="vendor" .. id, label="Vendor", text="", visible = true })
    dlg:label({ id="description" .. id, label="Description", text="", visible = true })
    dlg:label({ id="version" .. id, label="Version", text="", visible = true })
    dlg:button({
        id="action" .. id,
        text="",
        selected=false,
        focus=false,
        visible=false,
        onclick=function()
            if id == "package" then
                local package = options[dlg.data.package]
                if not installScript(package.url, package.scriptPath) then
                    return
                end
                app.alert{title="Install Package", text="The package is installed", buttons="OK"}
            elseif id == "updates" then
               -- @todo
            elseif id == "installed" then
                local package = options[dlg.data.installed]
                if not uninstallScript(package.scriptPath) then
                    return
                end
                app.alert{title="Uninstall Package", text="The package is removed", buttons="OK"}
            end

            -- refresh the whole window
            dlg:close()
            app.command.RunScript({filename = app.fs.joinPath(scriptsDir, "packages.lua") })
        end 
    })
end

processMetaData()

dlg:tab({ id="packages", text=setTabName("packages", packagesInstallOptions)})
uiTab("package", packagesInstallOptions)

dlg:tab({ id="updates", text=setTabName("updates", packagesUpdateOptions)})
uiTab("updates", packagesUpdateOptions)

dlg:tab({ id="installed", text=setTabName("installed", packagesUninstallOptions)})
uiTab("installed", packagesUninstallOptions)

dlg:tab({ id="about",text="About"})
:separator(" ABOUT ")
:label({ label="Made by", text="Martin" })
:label({ label="Version", text="1.0.0" })
:label({ label="Why?", text="Because I like to create things with LUA and help other people" })
:separator(" SUPPORT ")
:label({ label="", text="You can support me, i'm creating a pixel art adventure game" })
:label({ label="Site", text="https://signalfromthestars.com" })
:label({ label="Insta", text="https://www.instagram.com/signalfromthestars" })
:label({ label="GitHub", text="https://github.com/SignalFromTheStars" })
:separator(" BUGS ")
:label({ label="Ooops", text="You can visit the the github page and/or try to update the Package Manager" })
:separator()
:button({
    text="UPDATE",
    selected=false,
    focus=false,
    onclick=function()
        -- @todo update check
    end 
})

dlg:endtabs()

dlg:show{ wait=true, autoscrollbars=true }