local H = wesnoth.require "lua/helper.lua"
local AH = wesnoth.require "ai/lua/ai_helper.lua"

local ca_forest_animals_tusker_attack = {}

function ca_forest_animals_tusker_attack:evaluation(ai, cfg)
    -- Check whether there is an enemy next to a tusklet and attack it ("protective parents" AI)

    -- Both cfg.tusker_type and cfg.tusklet_type need to be set for this to kick in
    if (not cfg.tusker_type) or (not cfg.tusklet_type) then return 0 end

    local tuskers = wesnoth.get_units { side = wesnoth.current.side, type = cfg.tusker_type, formula = '$this_unit.moves > 0' }
    local adj_enemies = wesnoth.get_units {
        { "filter_side", {{"enemy_of", {side = wesnoth.current.side} }} },
        { "filter_adjacent", { side = wesnoth.current.side, type = cfg.tusklet_type } }
    }
    --print('#tuskers, #adj_enemies', #tuskers, #adj_enemies)

    if tuskers[1] and adj_enemies[1] then return cfg.ca_score end
    return 0
end

function ca_forest_animals_tusker_attack:execution(ai, cfg)
    local tuskers = wesnoth.get_units { side = wesnoth.current.side, type = cfg.tusker_type, formula = '$this_unit.moves > 0' }
    local adj_enemies = wesnoth.get_units {
        { "filter_side", {{"enemy_of", {side = wesnoth.current.side} }} },
        { "filter_adjacent", { side = wesnoth.current.side, type = cfg.tusklet_type } }
    }

    -- Find the closest enemy to any tusker
    local min_dist, attacker, target = 9e99, {}, {}
    for i,t in ipairs(tuskers) do
        for j,e in ipairs(adj_enemies) do
            local dist = H.distance_between(t.x, t.y, e.x, e.y)
            if (dist < min_dist) then
                min_dist, attacker, target = dist, t, e
            end
        end
    end
    --print(attacker.id, target.id)

    -- The tusker moves as close to enemy as possible
    -- Closeness to tusklets is secondary criterion
    local adj_tusklets = wesnoth.get_units { side = wesnoth.current.side, type = cfg.tusklet_type,
        { "filter_adjacent", { id = target.id } }
    }

    local best_hex = AH.find_best_move(attacker, function(x, y)
        local rating = - H.distance_between(x, y, target.x, target.y)
        for i,t in ipairs(adj_tusklets) do
            if (H.distance_between(x, y, t.x, t.y) == 1) then rating = rating + 0.1 end
        end

        return rating
    end)
    --print('attacker', attacker.x, attacker.y, ' -> ', best_hex[1], best_hex[2])
    AH.movefull_stopunit(ai, attacker, best_hex)
    if (not attacker) or (not attacker.valid) then return end
    if (not target) or (not target.valid) then return end

    -- If adjacent, attack
    local dist = H.distance_between(attacker.x, attacker.y, target.x, target.y)
    if (dist == 1) then
        AH.checked_attack(ai, attacker, target)
    else
        AH.checked_stopunit_attacks(ai, attacker)
    end
end

return ca_forest_animals_tusker_attack
