--made by .lone17 with ❤️

xSound = exports.xsound

local currentlyPlayingRadio = nil
local exitedwhilePlayingRadio = nil
local songname

RegisterNUICallback("playRadio", function(data, cb)
    local radioUrl = data.url
    local volume = data.volume or 1.0

    if radioUrl then
        TriggerServerEvent("playRadio", { radioname = data.radioname,url = radioUrl, volume = volume })
        currentlyPlayingRadio = { name = data.name, url = radioUrl, volume = volume }
    end

    cb({})
end)

RegisterNetEvent("updateCurrentRadio", function(updatedRadio)
    currentlyPlayingRadio = updatedRadio
    SendNUIMessage({
        updateCurrentRadio = true,
        currentRadio = currentlyPlayingRadio.name
    })
end)

RegisterNUICallback("stopRadio", function(data, cb)
    TriggerServerEvent("stopRadio")
    currentlyPlayingRadio = nil
    cb({})
end)

RegisterNUICallback("updateVolume", function(data, cb)
    local volume = data.volume

    if currentlyPlayingRadio then
        currentlyPlayingRadio.volume = volume
        TriggerServerEvent("updateVolume", volume)
    end

    cb({})
end)

RegisterNUICallback("closeradio", function(data, cb)
    closeRadioMenu()

    cb({})
end)

-- Add volume control using xsound or any other audio library here

function openRadioMenu()
    SetNuiFocus(true, true)
    SendNUIMessage({
        openRadioMenu = true,
        radios = Config.Radios,
        currentlyPlayingRadio = currentlyPlayingRadio
    })
end

function closeRadioMenu()
    SetNuiFocus(false, false)
   
end

function closeRadioMenu2()
        SendNUIMessage({
            close = true,
            closeall = true,               
        })
        SetNuiFocus(false, false)

   
end

-- Example: bind this to a key (e.g., F8) to open/close the radio menu
RegisterCommand(Config.command, function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        openRadioMenu()
     end
   
end)

-- Close the radio menu when the player is in a vehicle
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if not IsPedInAnyVehicle(PlayerPedId(), false) then
           TriggerEvent("loneradio:pauseRadio")
           exitedwhilePlayingRadio = false
            closeRadioMenu()
        end
    end
end)

local musicId
local playing = false
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    musicId = "music_id_" .. PlayerPedId()
    local pos
    while true do
        Citizen.Wait(100)
        if playing then
            if xSound:isPlaying(musicId) then
                pos = GetEntityCoords(PlayerPedId())
                TriggerEvent("loneradio:playRadio", "position", musicId, { position = pos })
            else
                Citizen.Wait(1000)
            end
        else
            Citizen.Wait(1000)
        end
    end
end)

local musiclink,volume

local firsttime = true

RegisterNetEvent("loneradio:playRadio")
AddEventHandler("loneradio:playRadio", function(type, musicId, data)
    musicId = "music_id_" .. PlayerPedId()
    if type == "position" then
       -- if xSound:soundExists(musicId) then
            xSound:Position(musicId, data.position)
       -- end
    end

    if type == "play" then
        playing = true
        local playerPed = GetPlayerPed(-1)
        local pos = GetEntityCoords(playerPed, false)
        songname = data.name
        musiclink = data.link
        volume = data.volume
        xSound:PlayUrlPos(musicId, data.link, data.volume/100, pos)
        xSound:Distance(musicId, 20)
        SendNUIMessage({
            showradio=true,
            name = data.name              
         })
    end
end)
local playing2 = false
RegisterNetEvent("loneradio:stopRadio")
AddEventHandler("loneradio:stopRadio", function()
    musicId = "music_id_" .. PlayerPedId()
    if playing then
        playing = false
        xSound:Destroy(musicId)
        closeRadioMenu2()
    end
end)

RegisterNetEvent("loneradio:pauseRadio")
AddEventHandler("loneradio:pauseRadio", function()
    musicId = "music_id_" .. PlayerPedId()
    if playing then
            playing = false
            playing2 = true
        xSound:Destroy(musicId)
        closeRadioMenu2()
    end
end)


RegisterNetEvent("loneradio:updateVolume")
AddEventHandler("loneradio:updateVolume", function(volume)
    musicId = "music_id_" .. PlayerPedId()
    if playing then
        xSound:setVolume(musicId,volume/100)
    end
end)

local triggered = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if playing2 then
        if not exitedwhilePlayingRadio then
            if IsPedInAnyVehicle(PlayerPedId(), false) then
                TriggerEvent("loneradio:playRadio", "play", musicId, { name = songname, link = musiclink, volume = volume})
                SendNUIMessage({
                   showradio=true,
                   name = songname,      
                })
                        playing2 = false
                        
            exitedwhilePlayingRadio = true
            end
        end
        end
    end
end)