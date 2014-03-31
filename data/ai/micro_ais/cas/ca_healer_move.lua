local H = wesnoth.require "lua/helper.lua"
local W = H.set_wml_action_metatable {}
local LS = wesnoth.require "lua/location_set.lua"
local AH = wesnoth.require "ai/lua/ai_helper.lua"
local BC = wesnoth.require "ai/lua/battle_calcs.lua"

local ca_healer_move = {}

function ca_healer_move:evaluation(ai, cfg, self)
    -- Should happen with higher priority than attacks, except at beginning of turn,
    -- when we want attacks done first
    -- This is done so that it is possible for healers to attack, if they do not
    -- find an appropriate hex to back up other units
    local score = 105000
    if self.data.HS_return_score then score = self.data.HS_return_score end
    --print('healer_support score:', score)

    cfg = cfg or {}

    local healers = wesnoth.get_units { side = wesnoth.current.side, ability = "healing",
        formula = '$this_unit.moves > 0', { "and", cfg.filter }
    }
    if (not healers[1]) then return 0 end

    local healers_noMP = wesnoth.get_units { side = wesnoth.current.side, ability = "healing",
        formula = '$this_unit.moves = 0', { "and", cfg.filter }
    }

    local all_units = wesnoth.get_units{ side = wesnoth.current.side,
        {"and", cfg.filter_second}
    }

    local healees, units_MP = {}, {}
    for i,u in ipairs(all_units) do
        -- Potential healees are units without MP that don't already have a healer (also without MP) next to them
        -- Also, they cannot be on a village or regenerate
        if (u.moves == 0) then
            if (not wesnoth.match_unit(u, {ability = "regenerates"})) then
                local is_village = wesnoth.get_terrain_info(wesnoth.get_terrain(u.x, u.y)).village
                if (not is_village) then
                    local healee = true
                    for j,h in ipairs(healers_noMP) do
                        if (H.distance_between(u.x, u.y, h.x, h.y) == 1) then
                            --print('Already next to healer:', u.x, u.y, h.x, h.y)
                            healee = false
                            break
                        end
                    end
                    if healee then table.insert(healees, u) end
                end
            end
        else
            table.insert(units_MP,u)
        end
    end
    --print('#healees, #units_MP', #healees, #units_MP)

    -- Take all units with moves left off the map, for enemy path finding
    for i,u in ipairs(units_MP) do wesnoth.extract_unit(u) end

    -- Enemy attack map
    local enemies = wesnoth.get_units {
        { "filter_side", {{"enemy_of", {side = wesnoth.current.side} }} }
    }
    local enemy_attack_map = BC.get_attack_map(enemies)
    --AH.put_labels(enemy_attack_map.units)

    local avoid_map = LS.of_pairs(ai.get_avoid())

    -- Put units back out there
    for i,u in ipairs(units_MP) do wesnoth.put_unit(u) end

    -- Now find the best healer move
    local max_rating, best_hex = -9e99, {}
    for i,h in ipairs(healers) do
        --local rating_map = LS.create()

        local reach = wesnoth.find_reach(h)
        for j,r in ipairs(reach) do

            local rating, adjacent_healer = 0

            -- Only consider hexes that are next to at least one noMP unit that
            --  - either can be attacked by an enemy (15 points per enemy)
            --  - or has non-perfect HP (1 point per missing HP)

            -- Also, hex must be unoccupied by another unit, of course
            local unit_in_way = wesnoth.get_unit(r[1], r[2])
            if (not avoid_map:get(r[1], r[2])) then
                if (not unit_in_way) or (unit_in_way == h) then
                    for k,u in ipairs(healees) do
                        if (H.distance_between(u.x, u.y, r[1], r[2]) == 1) then
                            -- !!!!!!! These ratings have to be positive or the method doesn't work !!!!!!!!!
                            rating = rating + u.max_hitpoints - u.hitpoints

                            -- If injured_units_only = true then don't count units with full HP
                            if (u.max_hitpoints - u.hitpoints > 0) or (not cfg.injured_units_only) then
                                rating = rating + 15 * (enemy_attack_map.units:get(u.x, u.y) or 0)
                            end
                        end
                    end
                end
            end

            -- Number of enemies that can threaten the healer at that position
            -- This has to be no larger than cfg.max_threats for hex to be considered
            local enemies_in_reach = enemy_attack_map.units:get(r[1], r[2]) or 0

            -- If this hex fulfills those requirements, 'rating' is now greater than 0
            -- and we do the rest of the rating, otherwise set rating to below max_rating
            if (rating == 0) or (enemies_in_reach > (cfg.max_threats or 9999)) then
                rating = max_rating - 1
            else
                -- Strongly discourage hexes that can be reached by enemies
                rating = rating - enemies_in_reach * 1000

                -- All else being more or less equal, prefer villages and strong terrain
                local is_village = wesnoth.get_terrain_info(wesnoth.get_terrain(r[1], r[2])).village
                if is_village then rating = rating + 2 end

                local defense = 100 - wesnoth.unit_defense(h, wesnoth.get_terrain(r[1], r[2]))
                rating = rating + defense / 10.

                --rating_map:insert(r[1], r[2], rating)
            end

            if (rating > max_rating) then
                max_rating, best_healer, best_hex = rating, h, {r[1], r[2]}
            end
        end
        --AH.put_labels(rating_map)
        --W.message { speaker = h.id, message = 'Healer rating map for me' }
    end
    --print('best unit move', best_hex[1], best_hex[2], max_rating)

    -- Only move healer if a good move as found
    -- Be aware that this means that other CAs will move the healers if not
    if (max_rating > -9e99) then
        self.data.HS_unit, self.data.HS_hex = best_healer, best_hex
        return score
    end

    return 0
end

function ca_healer_move:execution(ai, cfg, self)
    AH.movefull_outofway_stopunit(ai, self.data.HS_unit, self.data.HS_hex)
    self.data.HS_unit, self.data.HS_hex =  nil, nil
end

return ca_healer_move
