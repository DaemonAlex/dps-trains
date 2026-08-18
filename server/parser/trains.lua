local config = require "config"
setmetatable(config, nil)

if not config.general.enableParser then
    return
end

local xmlparser = require "server.parser.xmlparser"
local function createTrainFile(variations)
    local output = ""
    local function write(data)
        output = output .. data
    end

    write("return {\n")
    for i=1, #variations do
        local variation = variations[i]
        write("  {\n")
        write(("   index = %i,\n"):format(variation.index))
        if variation.gameBuild then
            write(("   gameBuild = %i,\n"):format(variation.gameBuild))
        end
        write("   models = {\n")

        for model, _ in pairs(variation.models) do
            write(("    `%s`,\n"):format(model))
        end

        write("   },\n")
        write(("  }%s\n"):format(i ~= #variations and ',' or ''))
    end

    write("}")
    SaveResourceFile(cache.resource, "data/trains.lua", output, string.len(output))
    lib.print.info(("Successfully generated train data. The output is in data/trains.lua"))
end


local function parseTrainConfig(doc)
    local trainVariations = {}
    -- We only care about the 2nd child. train_configs -> train_config
    local train_configs = doc.children[1]
    local index = 0
    for i=1, #train_configs.children do
        local trainConfig = train_configs.children[i]
        if trainConfig.tag ~= "train_config" then
            goto cont
        end

        local gameBuild = nil
        for l = 1, #trainConfig.orderedattrs do
            local attr = trainConfig.orderedattrs[l]

            if attr and attr.name == "gameBuild" then
                gameBuild = tonumber(attr.value)
                break
            end
        end

        local variation = {
            index = i - 1,
            models = {},
            gameBuild = gameBuild
        }

        --- These are the carriages, we are interested in the model
        for l=1, #trainConfig.children do
            local carriage = trainConfig.children[l]
            variation.models[carriage.attrs.model_name] = true
        end

        trainVariations[i] = variation
        ::cont::
    end

    createTrainFile(trainVariations)
end

RegisterCommand("parseTrainConfig", function(source, args)
    Wait(0)
    if source ~= 0 then
        lib.print.error(("Cannot use train parser from the client"))
        return
    end

    if not args[1] then
        lib.print.error(("No file provided"))
        return
    end

    local fileName = args[1]
    local filePath = ("%s/%s"):format(GetResourcePath(cache.resource), fileName)

    local doc, err = xmlparser.parseFile(filePath, false)
    if err then
        lib.print.error(("Error while parsing train config\n %s"):format(err))
    end

    parseTrainConfig(doc)
end, true)