extends Node

signal player_selected(player_id)
signal player_moved(pos)
signal player_stats_updated(vision:float, movement:float, strength:float, stealth:float)
signal player_set_stance(stance:Globals.Stance)

signal map_save()
signal map_load(filename:String)

signal turn_end()
signal turn_changed(team_id: int)
