--- If needing to integrate your own target / bridge support. Use this file as a template
--- Natives are restricted here. If you need to use natives use a separate resource

--- Functions
--- canDriveTrain(train: number, bones: string[], distance?: number): boolean
--- canSitInSeat()
--- checkDependency(resource: string, minimumVersion: string, printMessage?: string): boolean | nil, string | nil

checkDependency("ox_target", "1.17.1", "ox_target version 1.17.1 or above is required for bridge intergration")

local ox_target = exports.ox_target
local train = exports[cache.resource]

AddEventHandler("Ehbw-Trains:trainEnteredScope", function(handle, data)
    --print("trainEnteredScope", handle, data)
    --- Cablecars cannot be driven, and are not implemented anymore. Maybe in FiveM enhanced
    if config.general.enablePlayerDriving and config[data.type].enablePlayerDriving and data.type ~= 'cablecar' then
        ox_target:addLocalEntity({handle}, {
            {
                name = 'ehbw_drive_train',
                label = locale("target_drive_train"),
                icon = "fa-solid fa-train",
                canInteract = function (entity)
                    -- You can adjust the vehicle bones to your own needs (or if you use a custom metro/freight model override)
                    return canDriveTrain(entity, data.type == "freight" and {"door_pside_f"} or {"seat_dside_f"}, 8.0)
                end,
                onSelect = function (selectData)
                    train:driveTrain(selectData.entity)
                end
            }
        })
    end

    --- Iterate through all carriages to allow seating using the target in all of them
    if data.type == "metro" then
        local carriage = handle
        local count = 1

        while DoesEntityExist(carriage) do
            ox_target:addLocalEntity({carriage}, {
                {
                    name = "ehbw_sit_in_train",
                    label = locale("target_sit_in_train"),
                    icon = "fa-solid fa-chair",
                    canInteract = function (entity, distance, coords, name, bone)
                        return canSitInSeat(entity, distance)
                    end,
                    onSelect = function (data)
                        train:sitInSeat(data.entity, data.coords)
                    end
                }
            })

            carriage = GetTrainCarriage(handle, count)
            count += 1
            Wait(0)
        end
    end
end)

AddEventHandler("Ehbw-Trains:trainExitedScope", function (handle, data) end)
