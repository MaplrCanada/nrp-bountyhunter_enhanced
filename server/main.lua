-- nrp-bounterhunter_enhanced/server/main.lua

local QBCore = exports['qb-core']:GetCoreObject()
local availableBounties = {}
local activeBounties = {}
local bountyLocations = {
    {area = "Sandy Shores", coords = vector3(1895.65, 3715.89, 32.75), heading = 215.0},
    {area = "Grapeseed", coords = vector3(2548.57, 4668.98, 33.15), heading = 128.0},
    {area = "Paleto Bay", coords = vector3(-15.29, 6293.21, 31.38), heading = 45.0},
    {area = "Vinewood Hills", coords = vector3(-1546.35, 137.05, 55.65), heading = 300.0},
    {area = "Vespucci Beach", coords = vector3(-1365.54, -1159.15, 4.12), heading = 90.0},
    {area = "El Burro Heights", coords = vector3(1365.87, -2088.76, 52.0), heading = 180.0},
    {area = "Harmony", coords = vector3(585.27, 2788.53, 42.13), heading = 2.0},
    {area = "Great Chaparral", coords = vector3(-386.12, 2587.32, 90.13), heading = 270.0},
    {area = "Davis", coords = vector3(97.59, -1927.71, 20.8), heading = 320.0},
    {area = "Mirror Park", coords = vector3(1151.34, -645.02, 57.39), heading = 75.0}
}

local bountyTargets = {
    {
        difficulty = "Easy",
        models = Config.Difficulties["Easy"].models,
        weapons = Config.Difficulties["Easy"].weapons,
        health = Config.Difficulties["Easy"].health,
        armor = Config.Difficulties["Easy"].armor,
        accuracy = Config.Difficulties["Easy"].accuracy,
        reward = Config.Difficulties["Easy"].reward,
        reputation = Config.Difficulties["Easy"].reputation
    },
    {
        difficulty = "Medium",
        models = Config.Difficulties["Medium"].models,
        weapons = Config.Difficulties["Medium"].weapons,
        health = Config.Difficulties["Medium"].health,
        armor = Config.Difficulties["Medium"].armor,
        accuracy = Config.Difficulties["Medium"].accuracy,
        reward = Config.Difficulties["Medium"].reward,
        reputation = Config.Difficulties["Medium"].reputation
    },
    {
        difficulty = "Hard",
        models = Config.Difficulties["Hard"].models,
        weapons = Config.Difficulties["Hard"].weapons,
        health = Config.Difficulties["Hard"].health,
        armor = Config.Difficulties["Hard"].armor,
        accuracy = Config.Difficulties["Hard"].accuracy,
        reward = Config.Difficulties["Hard"].reward,
        reputation = Config.Difficulties["Hard"].reputation
    }
}

-- Progression system - Ranks and rewards
local ranks = {
    [0] = {name = "Rookie", requiredRep = 0, payment = 50},
    [1] = {name = "Tracker", requiredRep = 100, payment = 75},
    [2] = {name = "Hunter", requiredRep = 300, payment = 100},
    [3] = {name = "Veteran Hunter", requiredRep = 600, payment = 150},
    [4] = {name = "Master Hunter", requiredRep = 1000, payment = 200}
}

-- Achievement badges
local badges = {
    {
        id = "first_blood",
        icon = "🎯",
        title = "First Blood",
        description = "Complete your first bounty",
        requiredBounties = 1
    },
    {
        id = "silver_hunter",
        icon = "🥈",
        title = "Silver Hunter",
        description = "Complete 10 bounties",
        requiredBounties = 10
    },
    {
        id = "gold_hunter",
        icon = "🥇",
        title = "Gold Hunter",
        description = "Complete 25 bounties",
        requiredBounties = 25
    },
    {
        id = "high_roller",
        icon = "💰",
        title = "High Roller",
        description = "Earn $25,000 in bounties",
        requiredEarnings = 25000
    },
    {
        id = "professional",
        icon = "👑",
        title = "Professional",
        description = "Reach Master Hunter rank",
        requiredRank = 4
    },
    {
        id = "challenge_seeker",
        icon = "🔥",
        title = "Challenge Seeker",
        description = "Complete 10 hard bounties",
        requiredHardBounties = 10
    }
}

-- Generate new bounties every hour
function GenerateBounties()
    availableBounties = {}
    
    for i = 1, math.random(3, 6) do
        local targetType = bountyTargets[math.random(1, #bountyTargets)]
        local location = bountyLocations[math.random(1, #bountyLocations)]
        local model = targetType.models[math.random(1, #targetType.models)]
        local weapon = targetType.weapons[math.random(1, #targetType.weapons)]
        local reward = math.random(targetType.reward.min, targetType.reward.max)
        
        -- Create slight variation in spawn location
        local offsetX = math.random(-50, 50)
        local offsetY = math.random(-50, 50)
        local coords = vector3(location.coords.x + offsetX, location.coords.y + offsetY, location.coords.z)
        
        -- Generate a random name for the bounty
        local firstNames = {"John", "Mike", "Trevor", "Steve", "Billy", "Ray", "Chester", "Cletus", "Earl", "Buck"}
        local lastNames = {"Johnson", "Smith", "Williams", "Jackson", "Thompson", "Davis", "Rodriguez", "Martinez", "Gonzalez", "Wilson"}
        local name = firstNames[math.random(1, #firstNames)] .. " " .. lastNames[math.random(1, #lastNames)]
        
        table.insert(availableBounties, {
            id = i,
            name = name,
            model = GetHashKey(model),
            difficulty = targetType.difficulty,
            area = location.area,
            coords = coords,
            heading = location.heading,
            weapon = GetHashKey(weapon),
            health = targetType.health,
            armor = targetType.armor,
            accuracy = targetType.accuracy,
            reward = reward,
            reputation = targetType.reputation
        })
    end
end

-- Generate initial bounties when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    GenerateBounties()
    
    -- Schedule bounty refresh every hour
    SetTimeout(3600000, RecurringBountyGeneration)
end)

function RecurringBountyGeneration()
    GenerateBounties()
    SetTimeout(3600000, RecurringBountyGeneration)
end

-- Get player's current rank
function GetPlayerRank(reputation)
    local highestRank = 0
    for grade, rankData in pairs(ranks) do
        if reputation >= rankData.requiredRep and grade > highestRank then
            highestRank = grade
        end
    end
    return highestRank
end

-- Get player stats
RegisterNetEvent('nrp-bounterhunter_enhanced:server:GetPlayerStats', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if Player.PlayerData.job.name ~= 'bountyhunter' then return end
    
    -- Get player metadata for bounty hunter stats
    local metadata = Player.PlayerData.metadata
    local bountyStat = metadata.bountystats or {
        totalBounties = 0,
        totalEarnings = 0,
        reputation = 0,
        hardBountiesCompleted = 0,
        unlockedBadges = {}
    }
    
    -- Get current rank
    local rankGrade = GetPlayerRank(bountyStat.reputation)
    local rankName = ranks[rankGrade].name
    
    -- Prepare stats for client
    local statsData = {
        totalBounties = bountyStat.totalBounties,
        totalEarnings = bountyStat.totalEarnings,
        reputation = bountyStat.reputation,
        rank = rankName
    }
    
    -- Prepare badges for client
    local badgesData = {}
    for _, badge in ipairs(Config.Badges) do  -- Make sure you're using Config.Badges, not hardcoded badges
        local isUnlocked = false
        
        -- Check if badge is unlocked
        if bountyStat.unlockedBadges and bountyStat.unlockedBadges[badge.id] then
            isUnlocked = true
        elseif badge.requiredBounties and bountyStat.totalBounties >= badge.requiredBounties then
            isUnlocked = true
        elseif badge.requiredEarnings and bountyStat.totalEarnings >= badge.requiredEarnings then
            isUnlocked = true
        elseif badge.requiredRank and rankGrade >= badge.requiredRank then
            isUnlocked = true
        elseif badge.requiredHardBounties and bountyStat.hardBountiesCompleted >= badge.requiredHardBounties then
            isUnlocked = true
        end
        
        table.insert(badgesData, {
            icon = badge.icon,
            title = badge.title,
            description = badge.description,
            unlocked = isUnlocked
        })
        
        -- If badge is newly unlocked, save it
        if isUnlocked and not (bountyStat.unlockedBadges and bountyStat.unlockedBadges[badge.id]) then
            if not bountyStat.unlockedBadges then
                bountyStat.unlockedBadges = {}
            end
            bountyStat.unlockedBadges[badge.id] = true
            Player.Functions.SetMetaData('bountystats', bountyStat)
            TriggerClientEvent('QBCore:Notify', src, "Achievement Unlocked: " .. badge.title, "success")
        end
    end
    
    -- Send stats and badges to client
    TriggerClientEvent('nrp-bounterhunter_enhanced:client:UpdatePlayerStats', src, statsData, badgesData)
end)

-- Get available bounties
RegisterNetEvent('nrp-bounterhunter_enhanced:server:GetAvailableBounties', function()
    local src = source
    TriggerClientEvent('nrp-bounterhunter_enhanced:client:ShowAvailableBounties', src, availableBounties)
end)

-- Accept a bounty
RegisterNetEvent('nrp-bounterhunter_enhanced:server:AcceptBounty', function(bountyId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player already has an active bounty
    for _, bounty in pairs(activeBounties) do
        if bounty.playerId == src then
            TriggerClientEvent('QBCore:Notify', src, "You already have an active bounty!", "error")
            return
        end
    end
    
    for i, bounty in ipairs(availableBounties) do
        if bounty.id == bountyId then
            -- Mark this bounty as active
            bounty.playerId = src
            activeBounties[bountyId] = bounty
            
            -- Remove from available list
            table.remove(availableBounties, i)
            
            -- Send to client
            TriggerClientEvent('nrp-bounterhunter_enhanced:client:BountyAccepted', src, bounty)
            break
        end
    end
end)

-- Complete a bounty
RegisterNetEvent('nrp-bounterhunter_enhanced:server:CompleteBounty', function(bountyId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local bounty = activeBounties[bountyId]
    if not bounty then return end
    
    -- Check if this is the player's bounty
    if bounty.playerId ~= src then
        TriggerClientEvent('QBCore:Notify', src, "This is not your bounty!", "error")
        return
    end
    
    -- Remove from active bounties
    activeBounties[bountyId] = nil

    TriggerClientEvent('nrp-bounterhunter_enhanced:client:BountyFinished', src)
    
    
    -- Calculate reward with rank bonus
    local metadata = Player.PlayerData.metadata
    local bountyStat = metadata.bountystats or {
        totalBounties = 0,
        totalEarnings = 0,
        reputation = 0,
        hardBountiesCompleted = 0,
        unlockedBadges = {}
    }
    
    local rankGrade = GetPlayerRank(bountyStat.reputation)
    local rankBonus = ranks[rankGrade].payment / 100 -- Convert percentage to multiplier
    local finalReward = math.floor(bounty.reward * (1 + rankBonus))
    
    -- Add payment
    Player.Functions.AddMoney("cash", finalReward, "bounty-reward")
    TriggerClientEvent('QBCore:Notify', src, "You received $" .. finalReward .. " for completing the bounty!", "success")
    
    -- Update player stats
    bountyStat.totalBounties = bountyStat.totalBounties + 1
    bountyStat.totalEarnings = bountyStat.totalEarnings + finalReward
    bountyStat.reputation = bountyStat.reputation + bounty.reputation
    
    -- Track hard bounties completed for achievements
    if bounty.difficulty == "Hard" then
        bountyStat.hardBountiesCompleted = (bountyStat.hardBountiesCompleted or 0) + 1
    end
    
    -- Save updated stats
    Player.Functions.SetMetaData('bountystats', bountyStat)

    print("Updated stats for " .. Player.PlayerData.name .. ": Total Bounties = " .. bountyStat.totalBounties .. ", Rep = " .. bountyStat.reputation)
    
    -- Check for rank up
    local newRankGrade = GetPlayerRank(bountyStat.reputation)
    if newRankGrade > rankGrade then
        local newRank = ranks[newRankGrade]
        TriggerClientEvent('QBCore:Notify', src, "Rank Up! You are now a " .. newRank.name, "success")
        
        -- Set job grade if needed
        if Player.PlayerData.job.grade.level < newRankGrade then
            Player.Functions.SetJob("bountyhunter", newRankGrade)
        end
    end
    
    -- Update client stats
    TriggerEvent('nrp-bounterhunter_enhanced:server:GetPlayerStats', src)
end)

-- Add some commands for admin control
QBCore.Commands.Add('refreshbounties', 'Refresh the bounty board (Admin Only)', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player.PlayerData.job.name == "admin" or IsPlayerAceAllowed(src, "command") then
        GenerateBounties()
        TriggerClientEvent('QBCore:Notify', src, "Bounty board has been refreshed!", "success")
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to do this.", "error")
    end
end)

-- Reset player stats (for testing)
QBCore.Commands.Add('resetbountystats', 'Reset your bounty hunter stats (Admin Only)', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player.PlayerData.job.name == "admin" or IsPlayerAceAllowed(src, "command") then
        local resetStats = {
            totalBounties = 0,
            totalEarnings = 0,
            reputation = 0,
            hardBountiesCompleted = 0,
            unlockedBadges = {}
        }
        Player.Functions.SetMetaData('bountystats', resetStats)
        TriggerClientEvent('QBCore:Notify', src, "Bounty hunter stats have been reset!", "success")
        TriggerEvent('nrp-bounterhunter_enhanced:server:GetPlayerStats', src)
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to do this.", "error")
    end
end)