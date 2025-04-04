-- Package Manager
--
-- version: 1.0.0
-- remote: https://github.com/SignalFromTheStars/aseprite-package-manager
------------------------------------------------------------
if not app.isUIAvailable then
    return
end

local function isCommandAvailable(command)
    return os.execute(command .. " --version 2>&1")
end

local function openBrowser(url)
    local command
    if app.os.name == "Windows" then
        command = string.format('start "" "%s"', url)
    elseif app.os.name == "Linux" then
        command = string.format('xdg-open "%s"', url)
    elseif app.os.name == "macOS" then
        command = string.format('open "%s"', url)
    end
    if command then
        os.execute(command)
    end
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

local function saveStringToFile(filename, str, mode)
    local file = io.open(filename, mode)
    file:write(str)
    file:close()
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

local function readJson(filename)
    local stringJson = readFileToString(filename)
    if stringJson then
        return json.decode(stringJson)
    end
end

local scriptsDir = app.fs.joinPath(app.fs.userConfigPath, "scripts")
if not app.fs.isDirectory(scriptsDir) then
    app.alert("Cannot find the scripts dir")
    return
end

local packageManagerDir = app.fs.joinPath(scriptsDir, "Package Manager") 
if not app.fs.isDirectory(packageManagerDir) then
    app.fs.makeDirectory(packageManagerDir)
end

packageManagerSettingsPath = app.fs.joinPath(packageManagerDir, "settings.json")
local SETTINGS = readJson(packageManagerSettingsPath)
if not SETTINGS then
    -- create default settings
    SETTINGS = {
        metaDataUri = "https://raw.githubusercontent.com/SignalFromTheStars/aseprite-package-manager/refs/heads/main/src/metadata.json",
        didAcceptWarning = false
    }
    saveStringToFile(packageManagerSettingsPath, json.encode(SETTINGS), 'w+')
end

if not SETTINGS.didAcceptWarning then
    local result = app.alert{ title="Warning",
        text="Do you understand that the external scripts installed with this may be harmful?",
        buttons={"Yes", "No"}}
    if result ~= 1 then
        dlg:close()
        return
    end
    SETTINGS.didAcceptWarning = true
    saveStringToFile(packageManagerSettingsPath, json.encode(SETTINGS), 'w+')
end

local DOWNLOADER = findDownloader()

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

local function postRequest(url, jsonStr)
    local command

    if DOWNLOADER == "powershell" then
        command = string.format('powershell -Command "Invoke-RestMethod -Uri \"%s\" -Method Post -Body %s -ContentType \"application/json\""', url, jsonStr)
    elseif DOWNLOADER == "curl" then
        command = string.format("curl -X POST -H 'Content-Type: application/json' -d '%s' '%s'", jsonStr, url)
    else 
        app.alert("Cannot find a POST request tool like `curl`, or `powershell`, see the about tab and use git pull request")
        return
    end

    local result = os.execute(command)
    if result then
        return true
    else
        app.alert("POST Request Failed")
    end

    return false
end


-- in use for install and update (they are the same)
local function installScript(package)
    local scriptPathDir = app.fs.filePath(package.scriptPath)
    if not app.fs.isDirectory(scriptPathDir) then
        app.fs.makeAllDirectories(scriptPathDir)
    end

    if downloadFile(package.downloadUrl, package.scriptPath) then
        -- create local meta data
        saveStringToFile(package.scriptPath .. ".json", json.encode(package), 'w+')
    end

    -- reload script dir
    app.command.Refresh()
    return true
end

local function uninstallScript(package)
    if not removeFile(package.scriptPath) then
        app.alert("cannot remove the selected package")
        return false
    end

    -- remove the local metadata
    removeFile(package.scriptPath .. ".json") 
    
    -- remove the dir when empty
    local scriptPathDir = app.fs.filePath(package.scriptPath)
    local otherScriptsInPath = app.fs.listFiles(scriptPathDir)
    if #otherScriptsInPath == 0 and scriptsDir ~= scriptPathDir then
        app.fs.removeDirectory(scriptPathDir)
    end

    -- reload script dir
    app.command.Refresh()
    return true
end

local function getKeys(tbl)
    if tbl == nil then 
        return {}
    end
    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local function updateInfo(id, package)
    -- reset
    dlg:modify({id="vendor".. id, text="", visible = false})
    dlg:modify({id="description" .. id, text="", visible = false})
    dlg:modify({id="version" .. id, text="", visible = false})
    dlg:modify({id="action" .. id, text="", visible = false})
    dlg:modify({id="productUrl" .. id, visible = false})

    if not package then
        return
    end

    local data = package
    if package.isInstalled then
        data = package.localData
    end

    dlg:modify({id="vendor" .. id, text=data.vendor, visible = (data.vendor)})
    dlg:modify({id="description" .. id, text=data.description, visible = (data.description)})
    dlg:modify({id="version" .. id, text=package.version, visible = (package.version)})
    dlg:modify({id="localVersion" .. id, text=data.version, visible = (data.version)})
    dlg:modify({id="productUrl" .. id, visible = (data.productUrl)})

    if id == "installed" or id == "package" then
        if package.isInstalled then
            dlg:modify({id="action" .. id, text="UNINSTALL", visible = (data.downloadUrl)})
        else
            dlg:modify({id="action" .. id, text="INSTALL", visible = (data.downloadUrl)})
        end
    elseif id == "updates" then
        dlg:modify({id="action" .. id, text="UPDATE", visible = (data.downloadUrl)})
    end
end

local packagesInstallOptions = {}
local packagesUninstallOptions = {}
local packagesUpdateOptions = {}
local categories = {}

local function processMetaData()
    -- reset
    packagesInstallOptions = {}
    packagesUninstallOptions = {}
    packagesUpdateOptions = {}

    if downloadFile(SETTINGS.metaDataUri, metaDataPath) == false then
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

    for i, pkg in ipairs(metaData) do
        local packageScriptPath = app.fs.joinPath(packageManagerDir, pkg.category, pkg.scriptName)
        if pkg.name == "Package Mangager" then
            -- special case
            packageScriptPath = app.fs.joinPath(scriptsDir, pkg.scriptName)
        end

        -- for other processing
        table.insert(categories, pkg.category)

        -- create a new object
        local packageData = {
            -- json
            name = pkg.name,
            vendor = pkg.vendor,
            downloadUrl = pkg.downloadUrl,
            scriptName = pkg.scriptName,
            category = pkg.category,
            version = pkg.version,
            license = pkg.license,
            description = pkg.description,
            -- extend
            keyName = pkg.category .. " - " .. pkg.vendor .. " : " .. pkg.name,
            scriptPath = packageScriptPath,
            isInstalled = app.fs.isFile(packageScriptPath),
            haveUpdate = false,
            localData = {},
        }

        if packageData.isInstalled then
            -- maybe this package do have a update
            local localPackageMetaDataJson = readFileToString(packageData.scriptPath .. ".json")
            if localPackageMetaDataJson then
                packageData.localData = json.decode(localPackageMetaDataJson)
                if packageData.localData then           
                    -- maybe it have a update
                    if pkg.version and packageData.localData and packageData.localData.version ~= pkg.version then
                        packagesUpdateOptions[packageData.keyName] = packageData
                        packageData.haveUpdate = true
                    end
                end
            end
            packagesUninstallOptions[packageData.keyName] = packageData
        else
            packagesInstallOptions[packageData.keyName] = packageData 
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

local function reloadWindow()
    dlg:close()
    app.command.RunScript({filename = app.fs.joinPath(scriptsDir, "packages.lua") })
end

-- id == package , updates, installed
local function uiTab(id, options)
    dlg:combobox({
        id = id,
        label = "Package",
        option = "",
        options = {"", table.unpack(getKeys(options))},
        onchange=function(e)
            updateInfo(id, options[dlg.data[id]])
        end
    })

    dlg:separator()
    dlg:label({ id="vendor" .. id, label="Vendor", text="", visible = false })
    dlg:label({ id="description" .. id, label="Description", text="", visible = false })            
    dlg:label({ id="localVersion" .. id, label="Local version", text="", visible = false })
    dlg:label({ id="version" .. id, label="Remote version", text="", visible = false })
    dlg:button({
        id="action" .. id,
        text="",
        selected=false,
        focus=false,
        visible=false,
        onclick=function()
            local package = options[dlg.data[id]]
            if id == "package" then
                if not installScript(package) then
                    return
                end
                app.alert{title="Install Package", text="The package is installed", buttons="OK"}
            elseif id == "updates" then
                if not installScript(package) then
                    return
                end
                app.alert{title="Update Package", text="The package is updated", buttons="OK"}
            elseif id == "installed" then
                if not uninstallScript(package) then
                    return
                end
                app.alert{title="Uninstall Package", text="The package is removed", buttons="OK"}
            end

            reloadWindow()
        end 
    })
    dlg:button({
        id="productUrl" .. id,
        text="Webpage",
        visible=false,
        onclick=function()
            local package = options[dlg.data[id]]
            openBrowser(package.productUrl)
        end 
    })
end

processMetaData()

dlg = Dialog({title = "Package Manager"})
dlg:tab({ id="packages", text=setTabName("packages", packagesInstallOptions)})
uiTab("package", packagesInstallOptions)

dlg:tab({ id="updates", text=setTabName("updates", packagesUpdateOptions)})
uiTab("updates", packagesUpdateOptions)

dlg:tab({ id="installed", text=setTabName("installed", packagesUninstallOptions)})
uiTab("installed", packagesUninstallOptions)

dlg:tab({ id="settings",text="Settings"})
:separator(" Settings ")
:label({ text="Meta Data Uri"})
:entry({ id = "metaDataUri", text = SETTINGS.metaDataUri})
:check{ id="didAcceptWarning", label="", text= "I do understand that the external scripts installed with this may be harmful.", selected=SETTINGS.didAcceptWarning }
:button({
    text="Save settings",
    selected=false,
    focus=false,
    onclick=function()
        saveStringToFile(packageManagerSettingsPath, json.encode({
            metaDataUri = dlg.data.metaDataUri,
            didAcceptWarning = dlg.data.didAcceptWarning,
        }), 'w+')
        reloadWindow()
    end
})



dlg:tab({ id="submit",text="Submit"})
:entry({ id = "submitVendor", label="Vendor*", text = ""})
:entry({ id = "submitName", label="Name*", text = ""})
:entry({ id = "submitProductUrl", label="Product url", text = "https://{SOMETHING}"})
:entry({ id = "submitDownloadUrl", label="Script download url", text = "https://{SOMETHING}.lua"})
:entry({ id = "submitScriptName", label="Script name", text = "{SOMETHING}.lua"})
:entry({ id = "submitCategory", label="Category", text = ""})
:entry({ id = "submitVersion", label="Version", text = "x.y.z"})
:entry({ id = "submitLicense", label="License", text = ""})
:entry({ id = "submitDescription", label="Description*", text = ""})
:entry({ id = "submitEmail", label="Email*", text = ""})
:button({
    text="Submit Package",
    selected=false,
    focus=false,
    onclick=function()
        if dlg.data.submitVendor == "" then
            app.alert("Vendor is needed")
            return
        end
        if dlg.data.submitName == "" then
            app.alert("Name is needed")
            return
        end
        if dlg.data.submitEmail == "" then
            app.alert("Email is needed")
            return
        end
        if dlg.data.submitProductUrl == "" and dlg.data.submitDownloadUrl == "" then
            app.alert("You need to use a product url AND/OR a download url.")
            return
        end

        if postRequest("https://signalfromthestars.com/aseprite-submit-package.php", json.encode({
            vendor = dlg.data.submitVendor,
            name = dlg.data.submitName,
            productUrl = dlg.data.submitProductUrl,
            downloadUrl = dlg.data.submitDownloadUrl,
            scriptName = dlg.data.submitScriptName,
            category = dlg.data.submitCategory,
            version = dlg.data.submitVersion,
            license = dlg.data.submitLicense,
            description = dlg.data.submitDescription,
            email = dlg.data.submitEmail 
        })) then
            dlg:modify({ id = "submitVendor", text = ""})
            :modify({ id = "submitName", text = ""})
            :modify({ id = "submitProductUrl", text = "https://{SOMETHING}"})
            :modify({ id = "submitDownloadUrl", text = "https://{SOMETHING}.lua"})
            :modify({ id = "submitScriptName", text = "{SOMETHING}.lua"})
            :modify({ id = "submitCategory", text = ""})
            :modify({ id = "submitVersion", text = "x.y.z"})
            :modify({ id = "submitLicense", text = ""})
            :modify({ id = "submitDescription", text = ""})
            :modify({ id = "submitEmail", text = ""})

            app.alert("Your package is submitted")
        end
    end
})

dlg:tab({ id="about",text="About"})
:separator(" ABOUT ")
:label({ label="Made by", text="Martin" })
:label({ label="Version", text="1.0.0" })
:label({ label="Why?", text="Because I like to create things with LUA and help other people" })
:separator(" SUPPORT ")
:label({ label="", text="You can support me, i'm creating a pixel art adventure game" })
dlg:newrow{ always=true }
:button({
    text="https://signalfromthestars.com",
    selected=false,
    focus=false,
    onclick=function()
        openBrowser("https://signalfromthestars.com")
    end 
})
dlg:newrow{ always=true }
:button({
    text="https://www.instagram.com/signalfromthestars" ,
    selected=false,
    focus=false,
    onclick=function()
        openBrowser("https://www.instagram.com/signalfromthestars")
    end 
})
:separator(" BUGS ")
:label({ label="", text="Visit the the github page and/or try to update the Package Manager" })
:button({
    text="https://github.com/SignalFromTheStars",
    selected=false,
    focus=false,
    onclick=function()
        openBrowser("https://github.com/SignalFromTheStars/aseprite-package-manager")
    end 
})

dlg:endtabs()

dlg:show{ wait=true, autoscrollbars=true }