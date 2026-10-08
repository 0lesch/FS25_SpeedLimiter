local modName = g_currentModName

local function register(typeManager)
    if typeManager.typeName ~= "vehicle" then
        return
    end
    for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
        if SpeedLimiter.prerequisitesPresent(typeEntry.specializations) then
            g_vehicleTypeManager:addSpecialization(typeName, modName .. ".speedLimiter")
        end
    end
end

TypeManager.finalizeTypes = Utils.appendedFunction(TypeManager.finalizeTypes, register)
