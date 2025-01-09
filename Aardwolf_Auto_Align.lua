dofile(GetInfo(60) .. "aardwolf_colors.lua")

--
-- Variables
--

autoalign_align_var_name = "autoalign_align"
autoalign_align = GetVariable(autoalign_align_var_name) or "neutral"

debug_mode_var_name = "autoalign_debug_mode"
debug_mode = tonumber(GetVariable(debug_mode_var_name)) or 0

local character_state = -1
local character_align = -1

--
-- Plugin Methods
--

local plugin_id_gmcp_handler = "3e7dedbe37e44942dd46d264"

function OnPluginBroadcast(msg, id, name, text)
    if (id == plugin_id_gmcp_handler) then
        if (text == "char.status") then
            on_character_status_update(gmcp("char.status"))
        end
    end
end

function OnPluginInstall()
    init_plugin()
end

function OnPluginConnect()
    init_plugin()
end

function OnPluginEnable()
    init_plugin()
end

function init_plugin()
    if not IsConnected() then
        return
    end

    -- Wait until tags can be called
    local current_state = gmcp("char.status.state")
    if ((current_state ~= "3") and (current_state ~= "8") and (current_state ~= "9") and (current_state ~= "11")) then
        return
    end

    EnableTimer("timer_init_plugin", false)
    Message("Enabled Plugin")
    on_character_status_update(gmcp("char.status"))
end

function gmcp(s)
    local ret, datastring = CallPlugin(plugin_id_gmcp_handler, "gmcpdata_as_string", s)
    pcall(loadstring("data = " .. datastring))
    return data
end


--
-- Help & Options
--

function alias_help(name, line, wildcards)
    Message([[@WCommands:@w

  @Wautoalign help                 @w- Print out this help message
  @Wautoalign update               @w- Updates to the latest version of the plugin
  @Wautoalign reload               @w- Reloads the plugin
  @Wautoalign options              @w- Print out the plugin options
  @Wautoalign set @Yalign            @w- set target alignment to good, evil, or neutral

  @Wautoalign debug                @w- Toggles debug logs
  @Wautoalign force update @Ybranch  @w- Force updates to the branch specified]])
end


function alias_options(name, line, wildcards)
    Message(string.format([[@WCurrent options:@w

  @WAlignment:  @w(%s@w)]],
    autoalign_align))
end

function alias_set_debug_mode(name, line, wildcards)
    local new_debug_mode = -1

    if debug_mode == 1 then
        new_debug_mode = 0
    else
        new_debug_mode = 1
    end

    if new_debug_mode == 0 then
        Message("@WDisabled debug logs")
    else
        Message("@WEnabled debug logs")
    end
    SetVariable(debug_mode_var_name, new_debug_mode)
    debug_mode = new_debug_mode
end

function alias_set_align(name, line, wildcards)
    local align = string.lower(wildcards.align)
    if align == "good" or align == "evil" or align == "neutral" then
        SetVariable(autoalign_align_var_name, align)
        autoalign_align = align
        Message("autoalign set to @Y" .. align .. " @W")
        check_align()
    else
        Error("@Y" .. align .. " @W is not a valid alignment")
    end
end

--
-- Main Code
--

function on_character_status_update(status)
    -- handle state changes
    local previous_state = character_state
    character_state = tonumber(status.state)
    character_align = tonumber(status.align)

    if character_state == 3 then
        check_align()
    end
end

waiting_for_essence = false

function check_align()
    if waiting_for_essence then
        return
    end

    if autoalign_align == "neutral" then
        if character_align < -750 then
            waiting_for_essence = true
            Execute("essence good")
        elseif character_align > 750 then
            waiting_for_essence = true
            Execute("essence evil")
        end
    elseif autoalign_align == "good" then
        if character_align < 500 then
            waiting_for_essence = true
            Execute("essence good")
        end
    elseif autoalign_align == "evil" then
        if character_align > -500 then
            waiting_for_essence = true
            Execute("essence evil")
        end
    end
end

function trigger_essence_evil(name, line, wildcards, style)
    waiting_for_essence = false
end

function trigger_essence_good(name, line, wildcards, style)
    waiting_for_essence = false
end

function trigger_essence_fail(name, line, wildcards, style)
    waiting_for_essence = false
    check_align()
end

--
-- Print methods
--

function Message(str)
    AnsiNote(stylesToANSI(ColoursToStyles(string.format("\n@C[@GAlign@C] %s@w\n", str))))
end

function Debug(str)
    if debug_mode == 1 then
        Message(string.format("@gDEBUG@w %s", str))
    end
end

function Error(str)
    Message(string.format("@RERROR@w %s", str))
end

--
-- Update code
--

async = require "async"

local version_url = "https://raw.githubusercontent.com/AardPlugins/Aardwolf-Auto-Align/refs/heads/main/VERSION"
local plugin_base_url = "https://raw.githubusercontent.com/AardPlugins/Aardwolf-Auto-Align/refs"
local plugin_files = {
    {
        remote_file = "Aardwolf_Auto_Align.xml",
        local_file =  GetPluginInfo(GetPluginID(), 6),
        update_page= ""
    },
    {
        remote_file = "Aardwolf_Auto_Align.lua",
        local_file =  GetPluginInfo(GetPluginID(), 20) .. "Aardwolf_Auto_Align.lua",
        update_page= ""
    }
}
local download_file_index = 0
local download_file_branch = ""
local plugin_version = GetPluginInfo(GetPluginID(), 19)

function download_file(url, callback)
    Debug("Starting download of " .. url)
    -- Add timestamp as a query parameter to bust cache
    url = url .. "?t=" .. GetInfo(304)
    async.doAsyncRemoteRequest(url, callback, "HTTPS")
end

function alias_reload_plugin(name, line, wildcards)
    Message("Reloading plugin")
    reload_plugin()
end

function alias_update_plugin(name, line, wildcards)
    Debug("Checking version to see if there is an update")
    download_file(version_url, check_version_callback)
end

function check_version_callback(retval, page, status, headers, full_status, request_url)
    if status ~= 200 then
        Error("Error while fetching latest version number")
        return
    end

    local upstream_version = Trim(page)
    if upstream_version == tostring(plugin_version) then
        Message("@WNo new updates available")
        return
    end

    Message("@WUpdating to version " .. upstream_version)

    local branch = "tags/v" .. upstream_version
    download_plugin(branch)
end

function alias_force_update_plugin(name, line, wildcards)
    local branch = "main"

    if wildcards.branch ~= "" then
        branch = wildcards.branch
    end

    Message("@WForcing updating to branch " .. branch)

    branch = "heads/" .. branch
    download_plugin(branch)
end

function download_plugin(branch)
    Debug("Downloading plugin branch " .. branch)
    download_file_index = 0
    download_file_branch = branch

    download_next_file()
end

function download_next_file()
    download_file_index = download_file_index + 1

    if download_file_index > #plugin_files then
        Debug("All plugin files downloaded")
        finish_update()
        return
    end

    local url = string.format("%s/%s/%s", plugin_base_url, download_file_branch, plugin_files[download_file_index].remote_file)
    download_file(url, download_file_callback)
end

function download_file_callback(retval, page, status, headers, full_status, request_url)
    if status ~= 200 then
        Error("Error while fetching the plugin")
        return
    end

    plugin_files[download_file_index].update_page = page

    download_next_file()
end

function finish_update()
    Message("@WUpdating plugin. Do not touch anything!")

    -- Write all downloaded files to disk
    for i, plugin_file in ipairs(plugin_files) do
        local file = io.open(plugin_file.local_file, "w")
        file:write(plugin_file.update_page)
        file:close()
    end

    reload_plugin()

    Message("@WUpdate complete!")
end

function reload_plugin()
    if GetAlphaOption("script_prefix") == "" then
        SetAlphaOption("script_prefix", "\\\\\\")
    end
    Execute(
        GetAlphaOption("script_prefix") .. 'DoAfterSpecial(0.5, "ReloadPlugin(\'' .. GetPluginID() .. '\')", sendto.script)'
    )
end
