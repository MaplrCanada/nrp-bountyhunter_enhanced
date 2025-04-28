-- ss-bountyhunter_enhanced/server/main.lua

local QBCore = exports['qb-core']:GetCoreObject()
local availableBounties = {}
local activeBounties = {}

function ValidateAPIKey()
    local isValid = false
    local validationComplete = false
    
    -- Construct the API URL with parameters
    local apiUrl = "https://test.maplr.ca/syntaxscripts/api.php?apikey=" .. Config.APIKey

    
    -- Make HTTP request to validate the API key
    PerformHttpRequest(apiUrl, function(statusCode, responseText, headers)
        if statusCode == 200 then
            local response = json.decode(responseText)
            if response and response.status == "success" then
                isValid = true
                print("[SyntaxScripts] Bounty Hunter API key validation successful!")
            else
                print("[SyntaxScripts] Bounty Hunter API key validation failed: " .. (response and response.message or "Unknown error"))
            end
        else
            print("[SyntaxScripts] Bounty Hunter API key validation failed. Status code: " .. statusCode)
        end
        validationComplete = true
    end, "GET")
    
    -- Wait for validation to complete (simple synchronous approach for startup)
    local timeout = 0
    while not validationComplete and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    
    return isValid
end

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    -- Validate API key before initializing the script
    if not ValidateAPIKey() then
        print("\n^1[ERROR] Bounty Hunter failed to validate API key. Script will not work.^7")
        print("^3Please make sure you have a valid API key in your config.lua file.^7")
        print("^3You can purchase a license at https://test.maplr.ca/syntaxscripts^7\n")
        return
    end
    
    -- If validation successful, continue with script initialization
    print("^2SyntaxScripts Bounty Hunter validated and started successfully!^7")
    print("^2You can now use the bounty hunter features in your server.^7")
    print("^2For support, visit https://test.maplr.ca/syntaxscripts^7")
    print("^2Make sure to check the config.lua for customization options.^7")
    print("^2Enjoy your bounty hunting experience!^7")
    GenerateBounties()
    
    -- Schedule bounty refresh based on config
    local refreshTimeMs = Config.RefreshTime * 60 * 1000
    SetTimeout(refreshTimeMs, RecurringBountyGeneration)
end)

-- Generate new bounties
function GenerateBounties()
    availableBounties = {}
    
    for i = 1, math.random(3, 6) do
        local difficultyTypes = {"Easy", "Medium", "Hard"}
        local difficultyType = difficultyTypes[math.random(1, #difficultyTypes)]
        local targetType = Config.Difficulties[difficultyType]
        local location = Config.Locations[math.random(1, #Config.Locations)]
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
            difficulty = difficultyType,
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
    
    -- Schedule bounty refresh based on config
    local refreshTimeMs = Config.RefreshTime * 60 * 1000
    SetTimeout(refreshTimeMs, RecurringBountyGeneration)
end)

function RecurringBountyGeneration()
    GenerateBounties()
    -- Use config refresh time
    local refreshTimeMs = Config.RefreshTime * 60 * 1000
    SetTimeout(refreshTimeMs, RecurringBountyGeneration)
end

-- Get player's current rank
function GetPlayerRank(reputation)
    local highestRank = 0
    for grade, rankData in pairs(Config.Ranks) do
        if reputation >= rankData.requiredRep and grade > highestRank then
            highestRank = grade
        end
    end
    return highestRank
end

-- Get player stats
RegisterNetEvent('ss-bountyhunter_enhanced:server:GetPlayerStats', function()
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
    local rankName = Config.Ranks[rankGrade].name
    
    -- Prepare stats for client
    local statsData = {
        totalBounties = bountyStat.totalBounties,
        totalEarnings = bountyStat.totalEarnings,
        reputation = bountyStat.reputation,
        rank = rankName
    }
    
    -- Prepare badges for client
    local badgesData = {}
    for _, badge in ipairs(Config.Badges) do
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
    TriggerClientEvent('ss-bountyhunter_enhanced:client:UpdatePlayerStats', src, statsData, badgesData)
end)

-- Cancel bounty
RegisterNetEvent('ss-bountyhunter_enhanced:server:CancelBounty', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Find and remove the bounty assigned to this player
    local bountyToRemove = nil
    local bountyId = nil
    
    for id, bounty in pairs(activeBounties) do
        if bounty.playerId == src then
            bountyToRemove = bounty
            bountyId = id
            break
        end
    end
    
    if bountyToRemove then
        -- Remove from active bounties
        activeBounties[bountyId] = nil
        TriggerClientEvent('QBCore:Notify', src, "Your bounty has been canceled.", "info")
        TriggerClientEvent('ss-bountyhunter_enhanced:client:BountyFinished', src)
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have an active bounty to cancel.", "error")
    end
end)

-- Get available bounties
RegisterNetEvent('ss-bountyhunter_enhanced:server:GetAvailableBounties', function()
    local src = source
    TriggerClientEvent('ss-bountyhunter_enhanced:client:ShowAvailableBounties', src, availableBounties)
end)

-- Accept a bounty
RegisterNetEvent('ss-bountyhunter_enhanced:server:AcceptBounty', function(bountyId)
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
            TriggerClientEvent('ss-bountyhunter_enhanced:client:BountyAccepted', src, bounty)
            break
        end
    end
end)

-- Complete a bounty
RegisterNetEvent('ss-bountyhunter_enhanced:server:CompleteBounty', function(bountyId)
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

    TriggerClientEvent('ss-bountyhunter_enhanced:client:BountyFinished', src)
    
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
    local rankBonus = Config.Ranks[rankGrade].payment / 100 -- Convert percentage to multiplier
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
        local newRank = Config.Ranks[newRankGrade]
        TriggerClientEvent('QBCore:Notify', src, "Rank Up! You are now a " .. newRank.name, "success")
        
        -- Set job grade if needed
        if Player.PlayerData.job.grade.level < newRankGrade then
            Player.Functions.SetJob("bountyhunter", newRankGrade)
        end
    end
    
    -- Update client stats
    TriggerEvent('ss-bountyhunter_enhanced:server:GetPlayerStats', src)
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
        TriggerEvent('ss-bountyhunter_enhanced:server:GetPlayerStats', src)
    else
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to do this.", "error")
    end
end)