-- --made by .lone17 with ❤️

local currentlyPlayingRadio = nil
local currentVolume = 1.0 -- Default volume (1.0 = 100%)

RegisterNetEvent("playRadio")
RegisterNetEvent("stopRadio")
RegisterNetEvent("updateVolume")

AddEventHandler("playRadio", function(radioData)
    local name = radioData.radioname
    local radioUrl = radioData.url
    local volume = radioData.volume or currentVolume
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)

    local playerIds = GetPlayersInSameVehicle(source)
   -- if #playerIds == 1 and vehicle then  
        TriggerClientEvent("loneradio:playRadio",source,"play",2,{ name = name ,link = radioUrl, volume = volume})
        currentlyPlayingRadio = { url = radioUrl, volume = volume }
    --else
        -- Player is in a vehicle or there are other players nearby
      for _, playerId in ipairs(playerIds) do
                currentlyPlayingRadio = {
                    name = radioData.name or "Unknown Radio",
                    url = radioUrl,
                    volume = volume
                }
               TriggerClientEvent("loneradio:playRadio",playerId,"play",2,{ name = name , link = radioUrl, volume = volume})
        		currentlyPlayingRadio = { url = radioUrl, volume = volume }
    end 
end)

AddEventHandler("stopRadio", function()
    TriggerClientEvent("loneradio:stopRadio", -1)
    currentlyPlayingRadio = nil
end)

AddEventHandler("updateVolume", function(volume)
    if currentlyPlayingRadio then
        currentlyPlayingRadio.volume = volume
        TriggerClientEvent("loneradio:updateVolume", -1, volume)
    end
end)



function GetClosestPlayers(source, count)
    local players = GetPlayers()
    local closestPlayers = {}

    table.sort(players, function(a, b)
        return #(GetEntityCoords(GetPlayerPed(a))), #(GetEntityCoords(GetPlayerPed(source))) < #(GetEntityCoords(GetPlayerPed(b))),#(GetEntityCoords(GetPlayerPed(source)))
    end)

    for i = 1, count do
        if players[i] then
            table.insert(closestPlayers, players[i])
        end
    end

    return closestPlayers
end



function GetAllOnlinePlayers()
    local players = {}

    for _, playerId in ipairs(GetPlayers()) do
        table.insert(players, playerId)
    end

    return players
end

-- Function to get players in the same vehicle as the specified player
function GetPlayersInSameVehicle(source)
    local localVehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    local playersInSameVehicle = {}

    for _, playerId in ipairs(GetAllOnlinePlayers()) do
        if playerId ~= source then
            local playerPed = GetPlayerPed(playerId)
            local vehicle = GetVehiclePedIsIn(playerPed, false)

            if DoesEntityExist(playerPed) and DoesEntityExist(vehicle) and vehicle == localVehicle then
                table.insert(playersInSameVehicle, playerId)
            end
        end
    end

    return playersInSameVehicle
end

-- Example usage:
RegisterCommand("listplayersinvehicle", function(source, args, rawCommand)
    local source = source

    local playersInVehicle = GetPlayersInSameVehicle(source)

    if #playersInVehicle > 0 then
        local playerNames = {}

        for _, playerId in ipairs(playersInVehicle) do
            print(playerId)
            local playerName = GetPlayerName(playerId)
            table.insert(playerNames, playerName)
        end

        local playerList = table.concat(playerNames, ", ")
        TriggerClientEvent("chatMessage", source, "SYSTEM", {255, 255, 0}, "Players in the same vehicle: " .. playerList)
    else
        TriggerClientEvent("chatMessage", source, "SYSTEM", {255, 0, 0}, "No players in the same vehicle.")
    end
end, false)
