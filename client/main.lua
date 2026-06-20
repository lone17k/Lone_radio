--Made by .lone17 with ❤️

oliSound = exports.olisound

local currentlyPlayingRadio = nil
local activeVehicleRadios = {}
local audioLoopRunning = false

-- Persist config
local persistEnabled = Config.persistRadio or false
local playerPersistOverride = true
local savedRadio = nil
local skipNextStateBagClose = false -- Prevents UI close when player presses Pause

-- Track vehicle state
local wasInVehicle = false
local lastVehicleNetId = nil

RegisterNUICallback("playRadio", function(data, cb)
    local radioUrl = data.url
    local volume = data.volume or 50

    if radioUrl then
        TriggerServerEvent("playRadio", { radioname = data.radioname, url = radioUrl, volume = volume })
        currentlyPlayingRadio = { name = data.radioname, url = radioUrl, volume = volume }
        savedRadio = { name = data.radioname, url = radioUrl, volume = volume }
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
    skipNextStateBagClose = true -- Don't let state bag handler close the UI
    TriggerServerEvent("stopRadio")
    currentlyPlayingRadio = nil
    savedRadio = nil
    cb({})
end)

RegisterNUICallback("updateVolume", function(data, cb)
    local volume = data.volume

    if currentlyPlayingRadio then
        currentlyPlayingRadio.volume = volume

        -- INSTANT local volume update (no server round-trip needed for audio)
        if lastVehicleNetId then
            local soundId = "radio_" .. lastVehicleNetId
            if oliSound:soundExists(soundId) then
                oliSound:setVolume(soundId, volume / 100.0)
            end
        end

        -- Update server state bag for sync with other players
        TriggerServerEvent("updateVolume", volume)
    end
    if savedRadio then
        savedRadio.volume = volume
    end

    cb({})
end)

RegisterNUICallback("closeradio", function(data, cb)
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback("togglePersist", function(data, cb)
    playerPersistOverride = data.enabled
    cb({})
end)

function openRadioMenu()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle and vehicle ~= 0 then
        local state = Entity(vehicle).state.loneradio
        if state and state.isPlaying then
            currentlyPlayingRadio = state
        else
            currentlyPlayingRadio = nil
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        openRadioMenu = true,
        radios = Config.Radios,
        currentlyPlayingRadio = currentlyPlayingRadio,
        persistRadio = persistEnabled,
        playerPersistOverride = playerPersistOverride,
        wallpapers = {}
    })
    
    TriggerServerEvent('lone_radio:server:GetWallpapers')
end

RegisterNetEvent('lone_radio:client:ReceiveWallpapers', function(dynamicWallpapers)
    SendNUIMessage({
        updateWallpapers = true,
        wallpapers = dynamicWallpapers
    })
end)

function closeRadioMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ close = true, closeall = false })
end

function closeRadioMenu2()
    SendNUIMessage({ close = true, closeall = true })
    SetNuiFocus(false, false)
end

RegisterCommand(Config.command, function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        openRadioMenu()
    end
end)

-- ============================================================
-- Nearby radio discovery (one-shot)
-- Picks up vehicles that were ALREADY playing and in scope before
-- we cared about them (e.g. when we first get into a car).
-- Real-time discovery while driving is handled event-driven by the
-- state-bag change handler below, which fires when a vehicle's bag
-- is replicated to us on scope entry — so no perpetual scan is needed.
-- ============================================================
local function scanNearbyRadios()
    local ped = PlayerPedId()
    local plyCoords = GetEntityCoords(ped)
    local vehicles = GetGamePool("CVehicle")

    for _, vehicle in ipairs(vehicles) do
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        -- Skip already-tracked vehicles first (avoids statebag + coord native calls)
        if not activeVehicleRadios[netId] then
            local vehCoords = GetEntityCoords(vehicle)
            if #(plyCoords - vehCoords) < 50.0 then
                local state = Entity(vehicle).state.loneradio
                if state and state.isPlaying then
                    PlayVehicleRadioLocal(netId, state)
                end
            end
        end
    end
end

-- ============================================================
-- VEHICLE ENTER/EXIT
-- Single consolidated poll. On foot this is just one cheap
-- IsPedInAnyVehicle check per second (~0.00ms resmon).
-- ============================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- raised from 500ms; GTA enter/exit animation is ~1s anyway
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)

        if inVehicle and not wasInVehicle then
            -- GOT IN a vehicle
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 then
                lastVehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)

                -- Check if vehicle already has a radio
                local state = Entity(vehicle).state.loneradio
                if state and state.isPlaying then
                    -- Vehicle has its own radio -> sync to it
                    currentlyPlayingRadio = state
                    savedRadio = { name = state.name, url = state.url, volume = state.volume }
                    SendNUIMessage({ showradio = true, name = state.name })
                elseif persistEnabled and playerPersistOverride and savedRadio then
                    -- No radio on this vehicle but player has a saved one -> apply it
                    TriggerServerEvent("loneradio:enterVehicle")
                    currentlyPlayingRadio = savedRadio
                    SendNUIMessage({ showradio = true, name = savedRadio.name })
                end

                -- One-shot: catch any nearby cars already playing around us
                scanNearbyRadios()
            end
            wasInVehicle = true

        elseif not inVehicle and wasInVehicle then
            -- GOT OUT of a vehicle
            local shouldPersist = persistEnabled and playerPersistOverride and savedRadio

            if lastVehicleNetId then
                -- Clear old vehicle's state bag
                if shouldPersist then
                    -- Persist: only clear vehicle state, keep server-side saved radio
                    TriggerServerEvent("stopVehicleRadio")
                else
                    -- No persist: fully stop radio + clear saved
                    TriggerServerEvent("stopRadio")
                    savedRadio = nil
                end
            end

            -- Hide mini screen
            closeRadioMenu2()
            currentlyPlayingRadio = nil
            wasInVehicle = false
            lastVehicleNetId = nil
        end
    end
end)

-- ============================================================
-- AUDIO ENGINE: cleanup loop
-- ============================================================

function StartAudioLoop()
    if audioLoopRunning then return end
    audioLoopRunning = true

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000) -- unconditional wait: loop can never run faster than 1/s

            -- Collect dead entries first, then remove — safe Lua table mutation
            local toRemove = {}
            local hasActive = false

            for netId, _ in pairs(activeVehicleRadios) do
                local vehicle = NetToVeh(netId)
                if not DoesEntityExist(vehicle) then
                    local soundId = "radio_" .. netId
                    if oliSound:soundExists(soundId) then
                        oliSound:Destroy(soundId)
                    end
                    toRemove[#toRemove + 1] = netId
                else
                    hasActive = true
                end
            end

            for i = 1, #toRemove do
                activeVehicleRadios[toRemove[i]] = nil
            end

            if not hasActive then
                audioLoopRunning = false
                break
            end
        end
    end)
end

function PlayVehicleRadioLocal(netId, radioData)
    local vehicle = NetToVeh(netId)
    local soundId = "radio_" .. netId

    if DoesEntityExist(vehicle) then
        if oliSound:soundExists(soundId) then
            oliSound:Destroy(soundId)
        end
        
        local baseVol = (radioData.volume or 50) / 100.0
        -- PlayUrlVehicle automatically handles:
        -- - Position tracking (follows vehicle)
        -- - Muffling based on door/window state
        -- - Distance falloff
        oliSound:PlayUrlVehicle(soundId, radioData.url, baseVol, vehicle, true)
        oliSound:Distance(soundId, 12.0)
        
        activeVehicleRadios[netId] = radioData
        StartAudioLoop()
    end
end

-- State Bag listener
AddStateBagChangeHandler('loneradio', nil, function(bagName, key, value, _reserved, replicated)
    if not value then
        local netId = tonumber(bagName:gsub('entity:', ''), 10)
        local soundId = "radio_" .. netId
        if oliSound:soundExists(soundId) then
            oliSound:Destroy(soundId)
        end
        activeVehicleRadios[netId] = nil

        local currentVeh = GetVehiclePedIsIn(PlayerPedId(), false)
        if currentVeh ~= 0 and NetworkGetNetworkIdFromEntity(currentVeh) == netId then
            currentlyPlayingRadio = nil
            -- Only close UI if NOT triggered by the player themselves
            if skipNextStateBagClose then
                skipNextStateBagClose = false
            else
                SendNUIMessage({ close = true, closeall = true })
            end
        end
        return
    end

    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    PlayVehicleRadioLocal(netId, value)

    local currentVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    if currentVeh ~= 0 and NetworkGetNetworkIdFromEntity(currentVeh) == netId then
        currentlyPlayingRadio = value
        SendNUIMessage({ showradio = true, name = value.name })
    end
end)