local H = wesnoth.require "lua/helper.lua"
local AH = wesnoth.require "ai/lua/ai_helper.lua"
local BC = wesnoth.require "ai/lua/battle_calcs.lua"
local LS = wesnoth.require "lua/location_set.lua"

local ca_simple_attack = {}

function ca_simple_attack:evaluation(ai, cfg, self)

    -- Find all units that can attack and match the SUF
    local units = wesnoth.get_units {
        side = wesnoth.current.side,
        formula = '$this_unit.attacks_left > 0',
        { "and", cfg.filter }
    }

    -- Eliminate units without attacks
    for i = #units,1,-1 do
        if (not H.get_child(units[i].__cfg, 'attack')) then
            table.remove(units, i)
        end
    end
    --print('#units', #units)
    if (not units[1]) then return 0 end

    -- Get all possible attacks
    local attacks = AH.get_attacks(units, { include_occupied = true })
    --print('#attacks', #attacks)
    if (not attacks[1]) then return 0 end

    -- If cfg.filter_second is set, set up a map (location set)
    -- of enemies that it is okay to attack
    local enemy_map
    if cfg.filter_second then
        local enemies = wesnoth.get_units {
            { "filter_side", {{ "enemy_of", { side = wesnoth.current.side } }} },
            { "and", cfg.filter_second }
        }
        --print('#enemies', #enemies)
        if (not enemies[1]) then return 0 end

        enemy_map = LS.create()
        for i,e in ipairs(enemies) do enemy_map:insert(e.x, e.y) end
    end

    -- Now find the best of the possible attacks
    local max_rating, best_attack = -9e99, {}
    for i, att in ipairs(attacks) do
        local valid_target = true
        if cfg.filter_second and (not enemy_map:get(att.target.x, att.target.y)) then
            valid_target = false
        end

        if valid_target then
            local attacker = wesnoth.get_unit(att.src.x, att.src.y)
            local enemy = wesnoth.get_unit(att.target.x, att.target.y)
            local dst = { att.dst.x, att.dst.y }

            local rating = BC.attack_rating(attacker, enemy, dst)
            --print('rating:', rating, attacker.id, enemy.id)

            if (rating > max_rating) then
                max_rating = rating
                best_attack = att
            end
        end
    end

    if (max_rating > -9e99) then
        self.data.attack = best_attack
        return cfg.ca_score
    end

    return 0
end

function ca_simple_attack:execution(ai, cfg, self)
    local attacker = wesnoth.get_unit(self.data.attack.src.x, self.data.attack.src.y)
    local defender = wesnoth.get_unit(self.data.attack.target.x, self.data.attack.target.y)

    AH.movefull_outofway_stopunit(ai, attacker, self.data.attack.dst.x, self.data.attack.dst.y)
    if (not attacker) or (not attacker.valid) then return end
    if (not defender) or (not defender.valid) then return end

    AH.checked_attack(ai, attacker, defender, (cfg.weapon or -1))
    self.data.attack = nil
end

return ca_simple_attack