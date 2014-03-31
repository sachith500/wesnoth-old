local H = wesnoth.require "lua/helper.lua"
local AH = wesnoth.require "ai/lua/ai_helper.lua"

local ca_forest_animals_tusklet_move = {}

function ca_forest_animals_tusklet_move:evaluation(ai, cfg)
    -- Tusklets will simply move toward the closest tusker, without regard for anything else
    -- Except if no tuskers are left, in which case the previous CA takes over and does a random move

    -- Both cfg.tusker_type and cfg.tusklet_type need to be set for this to kick in
    if (not cfg.tusker_type) or (not cfg.tusklet_type) then return 0 end

    local tusklets = wesnoth.get_units { side = wesnoth.current.side, type = cfg.tusklet_type, formula = '$this_unit.moves > 0' }
    local tuskers = wesnoth.get_units { side = wesnoth.current.side, type = cfg.tusker_type }

    if tusklets[1] and tuskers[1] then return cfg.ca_score end
    return 0
end

function ca_forest_animals_tusklet_move:execution(ai, cfg)
    local tusklets = wesnoth.get_units { side = wesnoth.current.side, type = cfg.tusklet_type, formula = '$this_unit.moves > 0' }
    local tuskers = wesnoth.get_units { side = wesnoth.current.side, type = cfg.tusker_type }
    --print('#tusklets, #tuskers', #tusklets, #tuskers)

    for i,tusklet in ipairs(tusklets) do
        -- find closest tusker
        local goto_tusker, min_dist = {}, 9999
        for i,t in ipairs(tuskers) do
            local dist = H.distance_between(t.x, t.y, tusklet.x, tusklet.y)
            if (dist < min_dist) then
                min_dist, goto_tusker = dist, t
            end
        end
        --print('closets tusker:', goto_tusker.x, goto_tusker.y, goto_tusker.id)

        -- Move tusklet toward that tusker
        local best_hex = AH.find_best_move(tusklet, function(x, y)
            return -H.distance_between(x, y, goto_tusker.x, goto_tusker.y)
        end)
        --print('tusklet', tusklet.x, tusklet.y, ' -> ', best_hex[1], best_hex[2])
        AH.movefull_stopunit(ai, tusklet, best_hex)

        -- Also make sure tusklets never attack
        if tusklet and tusklet.valid then AH.checked_stopunit_all(ai, tusklet) end
    end
end

return ca_forest_animals_tusklet_move
