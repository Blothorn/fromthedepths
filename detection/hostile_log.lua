-- Time between messages.
messagePeriod = 1.0

previousMessageTime = 0.0

minScoreForBlockCount = 200

I = nil
myPosition = Vector3.zero
myYaw = 0

teamsByID = {}
teamsByID[993971311]  = "DWG"
teamsByID[56092858]   = "OW"
teamsByID[1196427404] = "WF"
teamsByID[2008041703] = "TG"
teamsByID[1616893782] = "LH"
teamsByID[752536525]  = "SS"
teamsByID[1557749608] = "GT"
teamsByID[1963323994] = "SD"

function Update(Iarg)
    I = Iarg
    currentTime = I:GetGameTime()
    if currentTime < previousMessageTime + messagePeriod then
        return
    end
    
    previousMessageTime = currentTime
    
    if I:GetNumberOfMainframes() == 0 then
        LogBoth('No mainframe found!')
        return
    end
    
    myPosition = I:GetConstructPosition()
    myYaw = I:GetConstructYaw()
    
    LogResourceZone()
    LogClosestTarget()
end

function LogBoth(message)
    I:Log(message)
    I:LogToHud(message)
end

function LogClosestTarget()
    -- Return true iff message logged.
    
    if I:GetNumberOfTargets(0) == 0 then
        return false
    end
    
    -- Choose mainframe with the highest last score, assume this is range + blockcount.
    local mainframeToUse = nil
    local highestScore = 0
    
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local targetCount = I:GetNumberOfTargets(mainframeIndex)
        local target = I:GetTargetInfo(mainframeIndex, targetCount - 1)
        if mainframeToUse == nil or (targetCount > 0 and target.Score > highestScore) then
            highestScore = target.Score
            mainframeToUse = mainframeIndex
        end
    end
    
    -- Choose a target.
    local logTarget = nil
    local logTargetRelativePosition = nil

    for targetIndex = 0, I:GetNumberOfTargets(mainframeToUse) - 1 do
        local target = I:GetTargetInfo(mainframeToUse, targetIndex)
        local relativePosition = target.Position - myPosition
        if target.Protected and (logTarget == nil or relativePosition.magnitude < logTargetRelativePosition.magnitude) then
            logTarget = target
            logTargetRelativePosition = relativePosition
        end
    end
    
    if logTarget == nil then
        return false
    end
    
    local oclock = ComputeOClock(logTargetRelativePosition)
    local blockCountString
    if highestScore > minScoreForBlockCount then
        local blockCount = logTarget.Score - logTargetRelativePosition.magnitude
        blockCountString = string.format(' %0.1fk blocks', blockCount / 1000)
    elseif highestScore ~= 0 then
        blockCountString = string.format(' %d score', logTarget.Score)
    else
        blockCountString = ''
    end
    
    local message = string.format([[%s%s %d o'clock, distance %d m, altitude %d m, %d bogeys total]], 
                            teamsByID[logTarget.Team] or 'unknown team',
                            blockCountString,
                            oclock, 
                            logTargetRelativePosition.magnitude, 
                            logTarget.Position.y,
                            I:GetNumberOfTargets(mainframeToUse)
                            )
    LogBoth(message)
    return true
end

function LogResourceZone()
    local bestResourceZone = nil
    local bestRelativePosition = nil
    local bestScore = nil
    local resourceZoneCount = 0
    
    for index, resourceZone in pairs(I.ResourceZones) do
        local resourcesRemaining = MetalScrapRemaining(resourceZone.Resources)
        if resourcesRemaining > 0 then
            resourceZoneCount = resourceZoneCount + 1
            local relativePosition = resourceZone.Position - myPosition
            local score = resourcesRemaining / math.max(relativePosition.magnitude, 100.0)
            if bestResourceZone == nil or score > bestScore then
                bestResourceZone = resourceZone
                bestRelativePosition = relativePosition
                bestScore = score
            end
        end
    end
    
    if bestResourceZone == nil then
        return false
    end
    
    local oclock = ComputeOClock(bestRelativePosition)
    local resourcesRemaining = MetalScrapRemaining(bestResourceZone.Resources)
    local message = string.format([[Resource zone %d o'clock, distance %d m, %d metal + scrap, %d zone(s) total]], 
                                  oclock, 
                                  bestRelativePosition.magnitude, 
                                  resourcesRemaining, 
                                  resourceZoneCount)
    LogBoth(message)
    return true
end

function LogDefault()
    message = 'No points of interest.'
    LogBoth(message)
    return true
end

function MetalScrapRemaining(resources)
    return resources.MetalTotal + resources.ScrapTotal
end

function MaxResourcesRemaining(resources)
    local result = math.max(resources.NaturalTotal, resources.MetalTotal)
    result = math.max(result, resources.OilTotal)
    result = math.max(result, resources.ScrapTotal)
    -- result = math.max(result, resources.CrystalTotal)
    return result
end

function ComputeOClock(relativePosition)
    local azimuth = math.deg(math.atan2(relativePosition.x, relativePosition.z)) - myYaw
    local result = math.fmod(math.ceil(azimuth / 30 - 0.5), 12)
    if result < 1 then
        result = result + 12
    end
    return result
end
