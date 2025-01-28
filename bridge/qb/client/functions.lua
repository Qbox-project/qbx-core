require 'client.functions'
local functions = {}

-- Player

---@deprecated import PlayerData using module 'qbx_core:playerdata' https://docs.qbox.re/resources/qbx_core/modules/playerdata
---@param cb? fun(playerData: PlayerData)
---@return PlayerData? playerData
function functions.GetPlayerData(cb)
    if not cb then return QBX.PlayerData end

    cb(QBX.PlayerData)
end

---@deprecated use the GetEntityCoords and GetEntityHeading natives directly
functions.GetCoords = function(entity) -- luacheck: ignore
    local coords = GetEntityCoords(entity)
    return vec4(coords.x, coords.y, coords.z, GetEntityHeading(entity))
end

---@deprecated use https://overextended.dev/ox_inventory/Functions/Client#search
functions.HasItem = function(items, amount)
    amount = amount or 1
    local count = exports.ox_inventory:Search('count', items)
    if type(items) == 'table' and type(count) == 'table' then
        for _, v in pairs(count) do
            if v < amount then
                return false
            end
        end

        return true
    end

    return count >= amount
end

-- Utility

---@deprecated use qbx.drawText2d from modules/lib.lua
functions.DrawText = function(x, y, width, height, scale, r, g, b, a, text)
    qbx.drawText2d({
        text = text,
        coords = vec2(x, y),
        scale = scale,
        font = 4,
        color = vec4(r, g, b, a),
        width = width,
        height = height,
    })
end

---@deprecated use qbx.drawText3d from modules/lib.lua
functions.DrawText3D = function(x, y, z, text)
    qbx.drawText3d({
        text = text,
        coords = vec3(x, y, z),
        scale = 0.35,
        font = 4,
        color = vec4(255, 255, 255, 215)
    })
end

---@deprecated use lib.requestAnimDict from ox_lib
functions.RequestAnimDict = lib.requestAnimDict

---@deprecated use lib.requestAnimDict from ox_lib, and the TaskPlayAnim and RemoveAnimDict natives directly
functions.PlayAnim = function(animDict, animName, upperbodyOnly, duration)
    local flags = upperbodyOnly and 16 or 0
    local runTime = duration or -1
    lib.playAnim(cache.ped, animDict, animName, 8.0, 3.0, runTime, flags, 0.0, false, false, true)
end

---@deprecated use lib.requestModel from ox_lib
functions.LoadModel = lib.requestModel

---@deprecated use lib.requestAnimSet from ox_lib
functions.LoadAnimSet = lib.requestAnimSet

---@deprecated use lib.progressBar from ox_lib
---@param label string
---@param duration integer ms
---@param useWhileDead boolean
---@param canCancel boolean
---@param disableControls? {disableMovement: boolean, disableCarMovement: boolean, disableCombat: boolean, disableMouse: boolean}
---@param animation? {animDict: string, anim: string, flags: unknown}
---@param prop? unknown
---@param onFinish fun()
---@param onCancel fun()
function functions.Progressbar(_, label, duration, useWhileDead, canCancel, disableControls, animation, prop, _, onFinish, onCancel)
    if lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = useWhileDead,
        canCancel = canCancel,
        disable = {
            move = disableControls?.disableMovement,
            car = disableControls?.disableCarMovement,
            combat = disableControls?.disableCombat,
            mouse = disableControls?.disableMouse,
        },
        anim = {
            dict = animation?.animDict,
            clip = animation?.anim,
            flags = animation?.flags
        },
        prop = {
            model = prop?.model,
            pos = prop?.coords,
            rot = prop?.rotation,
        },
    }) then
        if onFinish then
            onFinish()
        end
    else
        if onCancel then
            onCancel()
        end
    end
end

-- Getters

---@param pool string
---@param ignoreList? integer[]
---@return integer[]
local function getEntities(pool, ignoreList) -- luacheck: ignore
    ignoreList = ignoreList or {}
    local ents = GetGamePool(pool)
    local entities = {}
    local ignoreMap = {}
    for i = 1, #ignoreList do
        ignoreMap[ignoreList[i]] = true
    end

    for i = 1, #ents do
        local entity = ents[i]
        if not ignoreMap[entity] then
            entities[#entities + 1] = entity
        end
    end

    return entities
end

---@deprecated use the GetGamePool('CVehicle') native directly
functions.GetVehicles = function()
    return GetGamePool('CVehicle')
end

---@deprecated use the GetGamePool('CObject') native directly
functions.GetObjects = function()
    return GetGamePool('CObject')
end

---@deprecated use the GetActivePlayers native directly
functions.GetPlayers = GetActivePlayers

---@deprecated use the GetGamePool('CPed') native directly
functions.GetPeds = function(ignoreList)
    return getEntities('CPed', ignoreList)
end

---@param entities integer[]
---@param coords vector3? if unset uses player coords
---@return integer closestObj or -1
---@return number closestDistance or -1
local function getClosestEntity(entities, coords) -- luacheck: ignore
    coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords or GetEntityCoords(cache.ped)
    local closestDistance = -1
    local closestEntity = -1
    for i = 1, #entities do
        local entity = entities[i]
        local entityCoords = GetEntityCoords(entity)
        local distance = #(entityCoords - coords)
        if closestDistance == -1 or closestDistance > distance then
            closestEntity = entity
            closestDistance = distance
        end
    end

    return closestEntity, closestDistance
end

---@deprecated use lib.getClosestPed from ox_lib
---Use GetClosestPlayer if wanting to ignore non-player peds
functions.GetClosestPed = function(coords, ignoreList)
    return getClosestEntity(getEntities('CPed', ignoreList), coords)
end

---@deprecated use qbx.isWearingGloves from modules/lib.lua
functions.IsWearingGloves = qbx.isWearingGloves

---@deprecated use lib.getClosestPlayer from ox_lib
functions.GetClosestPlayer = function(coords) -- luacheck: ignore
    coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords or GetEntityCoords(cache.ped)
    local playerId, _, playerCoords = lib.getClosestPlayer(coords, 5, false)
    local closestDistance = playerCoords and #(playerCoords - coords) or nil
    return playerId or -1, closestDistance or -1
end

---@deprecated use lib.getNearbyPlayers from ox_lib
functions.GetPlayersFromCoords = function(coords, radius)
    coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords or GetEntityCoords(cache.ped)
    local players = lib.getNearbyPlayers(coords, radius or 5, true)

    -- This is for backwards compatability as beforehand it only returned the PlayerId, where Lib returns PlayerPed, PlayerId and PlayerCoords
    for i = 1, #players do
        players[i] = players[i].id
    end

    return players
end

---@deprecated use lib.getClosestVehicle from ox_lib
functions.GetClosestVehicle = function(coords)
    return getClosestEntity(GetGamePool('CVehicle'), coords)
end

---@deprecated use lib.getClosestObject from ox_lib
functions.GetClosestObject = function(coords)
    return getClosestEntity(GetGamePool('CObject'), coords)
end

---@deprecated use the GetWorldPositionOfEntityBone native and calculate distance directly
functions.GetClosestBone = function(entity, list)
    local playerCoords = GetEntityCoords(cache.ped)

    ---@type integer | {id: integer} | {id: integer, type: string, name: string}, vector3, number
    local bone, coords, distance
    for _, element in pairs(list) do
        local boneCoords = GetWorldPositionOfEntityBone(entity, element.id or element)
        local boneDistance = #(playerCoords - boneCoords)
        if not coords or distance > boneDistance then
            bone = element
            coords = boneCoords
            distance = boneDistance
        end
    end

    if not bone then
        bone = {id = GetEntityBoneIndexByName(entity, 'bodyshell'), type = 'remains', name = 'bodyshell'}
        coords = GetWorldPositionOfEntityBone(entity, bone.id)
        distance = #(coords - playerCoords)
    end

    return bone, coords, distance
end

---@deprecated use the GetWorldPositionOfEntityBone native and calculate distance directly
functions.GetBoneDistance = function(entity, boneType, bone)
    local boneIndex = boneType == 1 and GetPedBoneIndex(entity, bone --[[@as integer]]) or GetEntityBoneIndexByName(entity, bone --[[@as string]])
    local boneCoords = GetWorldPositionOfEntityBone(entity, boneIndex)
    local playerCoords = GetEntityCoords(cache.ped)
    return #(playerCoords - boneCoords)
end

---@deprecated use the AttachEntityToEntity native directly
functions.AttachProp = function(ped, model, boneId, x, y, z, xR, yR, zR, vertex)
    local modelHash = type(model) == 'string' and joaat(model) or model
    local bone = GetPedBoneIndex(ped, boneId)
    lib.requestModel(modelHash)
    local prop = CreateObject(modelHash, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(prop, ped, bone, x, y, z, xR, yR, zR, true, true, false, true, not vertex and 2 or 0, true)
    SetModelAsNoLongerNeeded(modelHash)
    return prop
end

-- Vehicle

---@deprecated use qbx.spawnVehicle from modules/lib.lua
---@param model string|number
---@param cb? fun(vehicle: number)
---@param coords? vector4 player position if not specified
---@param isnetworked? boolean defaults to true
---@param teleportInto boolean teleport player to driver seat if true
function functions.SpawnVehicle(model, cb, coords, isnetworked, teleportInto)
    local playerCoords = GetEntityCoords(cache.ped)
    local combinedCoords = vec4(playerCoords.x, playerCoords.y, playerCoords.z, GetEntityHeading(cache.ped))
    coords = type(coords) == 'table' and vec4(coords.x, coords.y, coords.z, coords.w or combinedCoords.w) or coords or combinedCoords
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(model) then return end

    isnetworked = isnetworked == nil or isnetworked
    lib.requestModel(model)
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, isnetworked, false)
    local netid = NetworkGetNetworkIdFromEntity(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetNetworkIdCanMigrate(netid, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetVehicleFuelLevel(veh, 100.0)
    SetModelAsNoLongerNeeded(model)

    if teleportInto then TaskWarpPedIntoVehicle(cache.ped, veh, -1) end

    if cb then cb(veh) end
end

---@deprecated use qbx.deleteVehicle from modules/lib.lua
functions.DeleteVehicle = qbx.deleteVehicle

---@deprecated use qbx.getVehiclePlate from modules/lib.lua
functions.GetPlate = function(vehicle)
    if vehicle == 0 then return end

    return qbx.getVehiclePlate(vehicle)
end

---@deprecated use qbx.getVehicleDisplayName from modules/lib.lua
functions.GetVehicleLabel = function(vehicle)
    if vehicle == nil or vehicle == 0 then return end

    return qbx.getVehicleDisplayName(vehicle)
end

---@deprecated use lib.getNearbyVehicles from ox_lib
functions.SpawnClear = function(coords, radius)
    coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords or GetEntityCoords(cache.ped)
    radius = radius or 5
    local vehicles = GetGamePool('CVehicle')
    local closeVeh = {}
    for i = 1, #vehicles do
        local vehicleCoords = GetEntityCoords(vehicles[i])
        local distance = #(vehicleCoords - coords)
        if distance <= radius then
            closeVeh[#closeVeh + 1] = vehicles[i]
        end
    end

    return #closeVeh == 0
end

---@deprecated use lib.getVehicleProperties from ox_lib
function functions.GetVehicleProperties(vehicle)
    local props = lib.getVehicleProperties(vehicle)
    if not props then return end

    local tireHealth = {}
        for i = 0, 3 do
            tireHealth[i] = GetVehicleWheelHealth(vehicle, i)
        end

    local tireBurstState = {}
    local tireBurstCompletely = {}

    for i = 0, 7 do
        local damage = props.tyres[i]
        tireBurstState[i] = damage == 1 or damage == 2
        tireBurstCompletely[i] = damage == 2
    end

    local windowStatus = {}
    for i = 0, 7 do
        windowStatus[i] = IsVehicleWindowIntact(vehicle, i)
    end

    local doorStatus = {}
    for i = 0, 5 do
        doorStatus[i] = IsVehicleDoorDamaged(vehicle, i) == 1
    end

    -- qb properties not in ox
    props.tireHealth = tireHealth
    props.tireBurstState = tireBurstState
    props.tireBurstCompletely = tireBurstCompletely
    props.windowStatus = windowStatus
    props.doorStatus = doorStatus
    props.headlightColor = GetVehicleHeadlightsColour(vehicle)
    props.modKit17 = props.modNitrous
    props.modKit19 = props.modSubwoofer
    props.modKit21 = props.modHydraulics
    props.modKit47 = props.modDoorR
    props.modKit49 = props.modLightbar
    props.liveryRoof = props.modRoofLivery

    return props
end

local gameBuild = GetGameBuildNumber()

---@deprecated use lib.setVehicleProperties from ox_lib
function functions.SetVehicleProperties(vehicle, props)
    if props.tireHealth and not props.tyres then
        for wheelIndex, health in pairs(props.tireHealth) do
            SetVehicleWheelHealth(vehicle, wheelIndex, health)
        end
    end

    if props.headlightColor then
        SetVehicleHeadlightsColour(vehicle, props.headlightColor)
    end

    if (props.tireBurstCompletely or props.tireBurstState) and not props.tyres then
        props.tyres = {}
        for i = 0, 7 do
            props.tyres[i] = props.tireBurstCompletely and props.tireBurstCompletely[i] and 2 or props.tireBurstState and props.tireBurstState[i] and 1 or nil
        end
    end

    local numWindowsDamaged = 0
    if props.windowStatus and not props.windows then
        props.windows = {}
        for i, isDamaged in pairs(props.windowStatus) do
            if isDamaged then
                numWindowsDamaged += 1
                props.windows[numWindowsDamaged] = i
            end
        end
    end

    local numDoorsDamaged = 0
    if props.doorStatus and not props.doors then
        props.doors = {}
        for i, isDamaged in pairs(props.doorStatus) do
            if isDamaged then
                numDoorsDamaged += 1
                props.doors[numDoorsDamaged] = i
            end
        end
    end

    -- qb properties converted to ox
    props.modNitrous = props.modNitrous or props.modKit17
    props.modSubwoofer = props.modSubwoofer or props.modKit17
    props.modHydraulics = props.modHydraulics or props.modKit21
    props.modDoorR = props.modDoorR or props.modKit47
    props.modLightbar = props.modLightbar or props.modKit49
    props.modRoofLivery = props.modRoofLivery or props.liveryRoof

    --- lib.setVehicleProperties copied and pasted from Overextended below so that we can remove the error so that setting properties is best effort
    assert(DoesEntityExist(vehicle), ('Unable to set vehicle properties for "%s" (entity does not exist)'):format(vehicle))

    if NetworkGetEntityIsNetworked(vehicle) and NetworkGetEntityOwner(vehicle) ~= cache.playerId then
        lib.print.warn('setting vehicle properties on non entity owner client. This may cause certain properties to fail to set. entity:', vehicle)
    end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    SetVehicleModKit(vehicle, 0)
    -- SetVehicleAutoRepairDisabled(vehicle, true)

    if props.extras then
        for id, disable in pairs(props.extras) do
            SetVehicleExtra(vehicle, tonumber(id) --[[@as number]], disable == 1)
        end
    end

    if props.plate then
        SetVehicleNumberPlateText(vehicle, props.plate)
    end

    if props.plateIndex then
        SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
    end

    if props.bodyHealth then
        SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0)
    end

    if props.engineHealth then
        SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0)
    end

    if props.tankHealth then
        SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0)
    end

    if props.fuelLevel then
        SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
    end

    if props.oilLevel then
        SetVehicleOilLevel(vehicle, props.oilLevel + 0.0)
    end

    if props.dirtLevel then
        SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0)
    end

    if props.color1 then
        if type(props.color1) == 'number' then
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1 --[[@as number]], colorSecondary --[[@as number]])
        else
            if props.paintType1 then SetVehicleModColor_1(vehicle, props.paintType1, colorPrimary, pearlescentColor) end

            SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3])
        end
    end

    if props.color2 then
        if type(props.color2) == 'number' then
            ClearVehicleCustomSecondaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1 or colorPrimary --[[@as number]], props.color2 --[[@as number]])
        else
            if props.paintType2 then SetVehicleModColor_2(vehicle, props.paintType2, colorSecondary) end

            SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3])
        end
    end

    if props.pearlescentColor or props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor or wheelColor)
    end

    if props.interiorColor then
        SetVehicleInteriorColor(vehicle, props.interiorColor)
    end

    if props.dashboardColor then
        SetVehicleDashboardColor(vehicle, props.dashboardColor)
    end

    if props.wheels then
        SetVehicleWheelType(vehicle, props.wheels)
    end

    if props.wheelSize then
        SetVehicleWheelSize(vehicle, props.wheelSize)
    end

    if props.wheelWidth then
        SetVehicleWheelWidth(vehicle, props.wheelWidth)
    end

    if props.windowTint then
        SetVehicleWindowTint(vehicle, props.windowTint)
    end

    if props.neonEnabled then
        for i = 1, #props.neonEnabled do
            SetVehicleNeonLightEnabled(vehicle, i - 1, props.neonEnabled[i])
        end
    end

    if props.windows then
        for i = 1, #props.windows do
            RemoveVehicleWindow(vehicle, props.windows[i])
        end
    end

    if props.doors then
        for i = 1, #props.doors do
            SetVehicleDoorBroken(vehicle, props.doors[i], true)
        end
    end

    if props.tyres then
        for tyre, state in pairs(props.tyres) do
            SetVehicleTyreBurst(vehicle, tonumber(tyre) --[[@as number]], state == 2, 1000.0)
        end
    end

    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end

    if props.modSmokeEnabled ~= nil then
        ToggleVehicleMod(vehicle, 20, props.modSmokeEnabled)
    end

    if props.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end

    if props.modSpoilers then
        SetVehicleMod(vehicle, 0, props.modSpoilers, false)
    end

    if props.modFrontBumper then
        SetVehicleMod(vehicle, 1, props.modFrontBumper, false)
    end

    if props.modRearBumper then
        SetVehicleMod(vehicle, 2, props.modRearBumper, false)
    end

    if props.modSideSkirt then
        SetVehicleMod(vehicle, 3, props.modSideSkirt, false)
    end

    if props.modExhaust then
        SetVehicleMod(vehicle, 4, props.modExhaust, false)
    end

    if props.modFrame then
        SetVehicleMod(vehicle, 5, props.modFrame, false)
    end

    if props.modGrille then
        SetVehicleMod(vehicle, 6, props.modGrille, false)
    end

    if props.modHood then
        SetVehicleMod(vehicle, 7, props.modHood, false)
    end

    if props.modFender then
        SetVehicleMod(vehicle, 8, props.modFender, false)
    end

    if props.modRightFender then
        SetVehicleMod(vehicle, 9, props.modRightFender, false)
    end

    if props.modRoof then
        SetVehicleMod(vehicle, 10, props.modRoof, false)
    end

    if props.modEngine then
        SetVehicleMod(vehicle, 11, props.modEngine, false)
    end

    if props.modBrakes then
        SetVehicleMod(vehicle, 12, props.modBrakes, false)
    end

    if props.modTransmission then
        SetVehicleMod(vehicle, 13, props.modTransmission, false)
    end

    if props.modHorns then
        SetVehicleMod(vehicle, 14, props.modHorns, false)
    end

    if props.modSuspension then
        SetVehicleMod(vehicle, 15, props.modSuspension, false)
    end

    if props.modArmor then
        SetVehicleMod(vehicle, 16, props.modArmor, false)
    end

    if props.modNitrous then
        SetVehicleMod(vehicle, 17, props.modNitrous, false)
    end

    if props.modTurbo ~= nil then
        ToggleVehicleMod(vehicle, 18, props.modTurbo)
    end

    if props.modSubwoofer ~= nil then
        ToggleVehicleMod(vehicle, 19, props.modSubwoofer)
    end

    if props.modHydraulics ~= nil then
        ToggleVehicleMod(vehicle, 21, props.modHydraulics)
    end

    if props.modXenon ~= nil then
        ToggleVehicleMod(vehicle, 22, props.modXenon)
    end

    if props.xenonColor then
        SetVehicleXenonLightsColor(vehicle, props.xenonColor)
    end

    if props.modFrontWheels then
        SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomTiresF)
    end

    if props.modBackWheels then
        SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomTiresR)
    end

    if props.modPlateHolder then
        SetVehicleMod(vehicle, 25, props.modPlateHolder, false)
    end

    if props.modVanityPlate then
        SetVehicleMod(vehicle, 26, props.modVanityPlate, false)
    end

    if props.modTrimA then
        SetVehicleMod(vehicle, 27, props.modTrimA, false)
    end

    if props.modOrnaments then
        SetVehicleMod(vehicle, 28, props.modOrnaments, false)
    end

    if props.modDashboard then
        SetVehicleMod(vehicle, 29, props.modDashboard, false)
    end

    if props.modDial then
        SetVehicleMod(vehicle, 30, props.modDial, false)
    end

    if props.modDoorSpeaker then
        SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false)
    end

    if props.modSeats then
        SetVehicleMod(vehicle, 32, props.modSeats, false)
    end

    if props.modSteeringWheel then
        SetVehicleMod(vehicle, 33, props.modSteeringWheel, false)
    end

    if props.modShifterLeavers then
        SetVehicleMod(vehicle, 34, props.modShifterLeavers, false)
    end

    if props.modAPlate then
        SetVehicleMod(vehicle, 35, props.modAPlate, false)
    end

    if props.modSpeakers then
        SetVehicleMod(vehicle, 36, props.modSpeakers, false)
    end

    if props.modTrunk then
        SetVehicleMod(vehicle, 37, props.modTrunk, false)
    end

    if props.modHydrolic then
        SetVehicleMod(vehicle, 38, props.modHydrolic, false)
    end

    if props.modEngineBlock then
        SetVehicleMod(vehicle, 39, props.modEngineBlock, false)
    end

    if props.modAirFilter then
        SetVehicleMod(vehicle, 40, props.modAirFilter, false)
    end

    if props.modStruts then
        SetVehicleMod(vehicle, 41, props.modStruts, false)
    end

    if props.modArchCover then
        SetVehicleMod(vehicle, 42, props.modArchCover, false)
    end

    if props.modAerials then
        SetVehicleMod(vehicle, 43, props.modAerials, false)
    end

    if props.modTrimB then
        SetVehicleMod(vehicle, 44, props.modTrimB, false)
    end

    if props.modTank then
        SetVehicleMod(vehicle, 45, props.modTank, false)
    end

    if props.modWindows then
        SetVehicleMod(vehicle, 46, props.modWindows, false)
    end

    if props.modDoorR then
        SetVehicleMod(vehicle, 47, props.modDoorR, false)
    end

    if props.modLivery then
        SetVehicleMod(vehicle, 48, props.modLivery, false)
        SetVehicleLivery(vehicle, props.modLivery)
    end

    if props.modRoofLivery then
        SetVehicleRoofLivery(vehicle, props.modRoofLivery)
    end

    if props.modLightbar then
        SetVehicleMod(vehicle, 49, props.modLightbar, false)
    end

    if props.bulletProofTyres ~= nil then
        SetVehicleTyresCanBurst(vehicle, props.bulletProofTyres)
    end

    if gameBuild >= 2372 and props.driftTyres then
        SetDriftTyresEnabled(vehicle, true)
    end

    return true
end

---@deprecated use lib.requestNamedPtfxAsset from ox_lib
functions.LoadParticleDictionary = lib.requestNamedPtfxAsset

---@deprecated use ParticleFx natives directly
functions.StartParticleAtCoord = function(dict, ptName, looped, coords, rot, scale, alpha, color, duration) -- luacheck: ignore
    coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords or GetEntityCoords(cache.ped)

    lib.requestNamedPtfxAsset(dict)
    UseParticleFxAssetNextCall(dict)
    SetPtfxAssetNextCall(dict)

    local particleHandle
    if looped then
        particleHandle = StartParticleFxLoopedAtCoord(ptName, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false, false)
        if color then
            SetParticleFxLoopedColour(particleHandle, color.r, color.g, color.b, false)
        end

        SetParticleFxLoopedAlpha(particleHandle, alpha or 10.0)

        if duration then
            Wait(duration)
            StopParticleFxLooped(particleHandle, false)
        end
    else
        SetParticleFxNonLoopedAlpha(alpha or 1.0)

        if color then
            SetParticleFxNonLoopedColour(color.r, color.g, color.b)
        end

        StartParticleFxNonLoopedAtCoord(ptName, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
    end

    return particleHandle
end

---@deprecated use ParticleFx natives directly
functions.StartParticleOnEntity = function(dict, ptName, looped, entity, bone, offset, rot, scale, alpha, color, evolution, duration) -- luacheck: ignore
    lib.requestNamedPtfxAsset(dict)
    UseParticleFxAssetNextCall(dict)

    local particleHandle = nil
    ---@cast bone number
    local pedBoneIndex = bone and GetPedBoneIndex(entity, bone) or 0
    ---@cast bone string
    local nameBoneIndex = bone and GetEntityBoneIndexByName(entity, bone) or 0
    local entityType = GetEntityType(entity)
    local boneID = entityType == 1 and (pedBoneIndex ~= 0 and pedBoneIndex) or (looped and nameBoneIndex ~= 0 and nameBoneIndex)
    if looped then
        if boneID then
            particleHandle = StartParticleFxLoopedOnEntityBone(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, boneID, scale or 1.0, false, false, false)
        else
            particleHandle = StartParticleFxLoopedOnEntity(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
        end

        if evolution then
            SetParticleFxLoopedEvolution(particleHandle, evolution.name, evolution.amount, false)
        end

        if color then
            SetParticleFxLoopedColour(particleHandle, color.r, color.g, color.b, false)
        end

        SetParticleFxLoopedAlpha(particleHandle, alpha or 1.0)

        if duration then
            Wait(duration)
            StopParticleFxLooped(particleHandle, false)
        end
    else
        SetParticleFxNonLoopedAlpha(alpha or 1.0)

        if color then
            SetParticleFxNonLoopedColour(color.r, color.g, color.b)
        end

        if boneID then
            StartParticleFxNonLoopedOnPedBone(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, boneID, scale or 1.0, false, false, false)
        else
            StartParticleFxNonLoopedOnEntity(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale or 1.0, false, false, false)
        end
    end

    return particleHandle
end

---@deprecated use qbx.getStreetName from modules/lib.lua
functions.GetStreetNametAtCoords = qbx.getStreetName

---@deprecated use qbx.getZoneName from modules/lib.lua
functions.GetZoneAtCoords = qbx.getZoneName

---@deprecated use qbx.getCardinalDirection from modules/lib.lua
functions.GetCardinalDirection = function(entity)
    if not entity or not DoesEntityExist(entity) then
        return 'Cardinal Direction Error'
    end

    return qbx.getCardinalDirection(entity)
end

---@deprecated use the GetClockMinutes and GetClockHours natives and format the output directly
functions.GetCurrentTime = function()
    local obj = {}
    obj.min = GetClockMinutes()
    obj.hour = GetClockHours()

    if obj.hour <= 12 then
        obj.ampm = 'AM'
    elseif obj.hour >= 13 then
        obj.ampm = 'PM'
        obj.formattedHour = obj.hour - 12
    end

    if obj.min <= 9 then
        obj.formattedMin = ('0%s'):format(obj.min)
    end

    return obj
end

---@deprecated use the GetGroundZFor_3dCoord native directly
functions.GetGroundZCoord = function(coords)
    if not coords then return end

    local retval, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    if retval then
        return vec3(coords.x, coords.y, groundZ)
    end

    lib.print.verbose('Couldn\'t find Ground Z Coordinates given 3D Coordinates:', coords)
    return coords
end

---Text box popup for player which dissappears after a set time.
---@param text table|string text of the notification
---@param notifyType? NotificationType informs default styling. Defaults to 'inform'
---@param duration? integer milliseconds notification will remain on screen. Defaults to 5000
---@param subTitle? string extra text under the title
---@param notifyPosition? NotificationPosition
---@param notifyStyle? table Custom styling. Please refer too https://overextended.dev/ox_lib/Modules/Interface/Client/notify#libnotify
---@param notifyIcon? string Font Awesome 6 icon name
---@param notifyIconColor? string Custom color for the icon chosen before
function functions.Notify(text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
    exports.qbx_core:Notify(text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
end

return functions
