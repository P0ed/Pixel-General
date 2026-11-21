# Tactical AI

AI seats and local auto-battle use the same deterministic heuristic. In LAN
games, the host runs AI seats and relays their actions to the other peers.

The heuristic assigns units to attack, hunt, defend, retreat, or support based
on the objective, nearby settlements, and visible enemies. It rebuilds those
assignments when the acting country, turn, or roster changes and refreshes
visible enemies and settlement ownership before each action. In Survival,
the defending side garrisons its positions while the attacker increases
pressure as the deadline approaches.

On each decision, the AI checks for critical resupply, then chooses among
attacks, disembarkation, embarkation, movement, and purchases in that order.
When it runs out of actions, it ends the turn. The reducer applies the action
and resolves combat using the battle's random stream.

The driver is `AI.heuristic` and the planner is `TacticalSim.run(ai:)`.
[TacticalAI.swift](../COR/Tactical/AI/TacticalAI.swift)
