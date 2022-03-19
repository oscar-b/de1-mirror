### helper functions ###

proc is_connected {} {return [expr {[clock seconds] - $::de1(last_ping)} < 5]}
proc is_heating {} { return [expr [is_connected] && $::de1(substate) == 1] }
# multiply water refill point by 1.1 because the DE1 can shut off just before this is reached
proc has_water {} { return [expr ![is_connected] || $::de1(water_level) > ($::settings(water_refill_point) * 1.1)] }

proc get_water_level {} {
	if {[expr ![is_connected]]} {return 0}
	return $::de1(water_level) 
}
proc get_min_water_level {} {return $::settings(water_refill_point)}
proc get_max_water_level {} {return [expr $::settings(water_level_sensor_max) * 0.9]}

proc get_machine_temperature {} {
		if {[expr ![is_connected]]} {return 0}
		#TODO: watertemp works in simulator
		return [group_head_heater_temperature]
}
proc get_min_machine_temperature {} {return $::de1(goal_temperature)}



proc get_status_text {} {
	if {[expr ![is_connected]]} {
		return [translate "disconnected"]
	}

	switch $::de1(substate) {
		"-" { 
			return "starting"
		}
		0 {
			return "ready"
		}
		1 {
			return "heating"
		}
		3 {
			return "stabilising"
		}
		4 {
			return "preinfusion"
		}
		5 {
			return "pouring"
		}
		6 {
			return "ending"
		}
		17 {
			return "refilling"
		}
		default {
			set result [de1_connected_state 0]
			if {$result == ""} { return "unknown" }
			return $result
		}
	}

}

# for the main functions (espresso, steam, water, flush), each has can_start_action and do_start_action functions
proc can_start_espresso {} { return [expr [is_connected] && ($::de1(substate) == 0) && [has_water]] }
proc do_start_espresso {} {
	if { [expr ![is_connected]] } {
		borg toast [translate "DE1 not connected"]
		return
	}
	if {[is_heating]} { 
		borg toast [translate "Please wait for heating"]
		return
	}
	if {[expr ![has_water]]} {
		borg toast [translate "Please refill water tank"]
		return
	}
	if { $::de1(substate) != 0 } {
		borg toast [translate "Machine is not ready"]
		return
	}
	start_espresso
}

proc can_start_steam {} { return [expr [is_connected] && ($::de1(substate) == 0) && [has_water]] }
proc do_start_steam {} {
	if {[expr ![is_connected]]} {
		borg toast [translate "DE1 not connected"]
		return
	}
	if {[is_heating]} { 
		borg toast [translate "Please wait for heating"]
		return
	}
	if {[expr ![has_water]]} {
		borg toast [translate "Please refill water tank"]
		return
	}
	if { $::de1(substate) != 0 } {
		borg toast [translate "Machine is not ready"]
		return
	}
	update_button_color $::steam_stop_button_id $::color_action_button_stop
	start_steam
}

proc can_start_water {} { return [expr [is_connected] && ($::de1(substate) == 0) && [has_water]] }
proc do_start_water {} {
	if {[expr ![is_connected]]} {
		borg toast [translate "DE1 not connected"]
		return
	}
	if {[is_heating]} { 
		borg toast [translate "Please wait for heating"]
		return
	}
	if {[expr ![has_water]]} {
		borg toast [translate "Please refill water tank"]
		return
	}
	if { $::de1(substate) != 0 } {
		borg toast [translate "Machine is not ready"]
		return
	}
	start_water
}

proc can_start_flush {} { return [expr [is_connected] && ($::de1(substate) == 0) && [has_water]] }
proc do_start_flush {} {
	if {[expr ![is_connected]]} {
		borg toast [translate "DE1 not connected"]
		return
	}
	if {[is_heating]} { 
		borg toast [translate "Please wait for heating"]
		return
	}
	if {[expr ![has_water]]} {
		borg toast [translate "Please refill water tank"]
		return
	}
	if { $::de1(substate) != 0 } {
		borg toast [translate "Machine is not ready"]
		return
	}
	set ::settings(preheat_temperature) 90
	set_next_page hotwaterrinse flush
	start_hot_water_rinse
}

proc can_show_last_shot {} { return [expr {$::timers(espresso_stop) > $::timers(espresso_start)}] }
proc do_show_last_shot {} {
	if {[expr ![can_show_last_shot]]} {
		borg toast [translate "No shot data available"]
		return
	}
	metric_jump_to "espresso_done"
}
