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
proc get_min_machine_temperature {} {return $::settings(minimum_water_temperature)}


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
	update_de1_async 1
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
	# TODO: only execute following lines if start_espresso is successful
	set_next_page "off" "espresso_done"
	metric_history_push "espresso_done"
}

proc can_start_steam {} { return [expr [is_connected] && ($::de1(substate) == 0) && [has_water]] }
proc do_start_steam {} {
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
	start_steam
}

proc can_start_water {} { return [expr [is_connected] && ($::de1(substate) == 0) && [has_water]] }
proc do_start_water {} {
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

proc metric_load_profile { profile_filename } {
	select_profile $profile_filename
	metric_copy_yield_from_settings
	if {[ifexists ::settings(bean_brand)] == ""} { set ::settings(bean_brand) [translate "Unknown roaster"]}
	if {[ifexists ::settings(bean_type)] == ""} { set ::settings(bean_type) [translate "Unknown bean"]}
    set ::settings(grinder_setting) [validate_setting $::settings(grinder_setting) $::metric_setting_grind_min $::metric_setting_grind_max $::metric_setting_grind_default]
    set ::settings(grinder_dose_weight) [validate_setting $::settings(grinder_dose_weight) $::metric_setting_dose_min $::metric_setting_dose_max $::metric_setting_dose_default]
    set ::metric_yield [validate_setting $::metric_yield $::metric_setting_yield_min $::metric_setting_yield_max $::metric_setting_yield_default]
	recalculate_brew_ratio
	save_settings_async
	update_de1_async
}

proc metric_bean_details_changed {} {
	save_settings_async
	save_profile_async
}

proc metric_grind_changed {} {
	save_settings_async
	save_profile_async
}

proc metric_dose_changed {} {
	recalculate_yield
	save_settings_async
	save_profile_async
	update_de1_async
}

proc metric_ratio_changed {} {
	recalculate_yield
	save_settings_async
	save_profile_async
	update_de1_async
}

proc metric_yield_changed {} {
	metric_copy_yield_to_settings
	recalculate_brew_ratio
	save_settings_async
	save_profile_async
	update_de1_async
}

proc metric_temperature_changed {} {
	if {[ifexists ::metric_temperature_delta] != 0} {
		change_espresso_temperature $::metric_temperature_delta
		set ::metric_temperature_delta 0
		save_profile_async
		update_de1_async
	}
}

proc recalculate_yield {} {
    set new_yield [expr $::settings(grinder_dose_weight) * $::metric_ratio]
    set new_yield [round_to_one_digits $new_yield]
	if {$new_yield < $::metric_setting_yield_min} {
		set ::metric_yield $::metric_setting_yield_min
		recalculate_brew_ratio
	} elseif {$new_yield > $::metric_setting_yield_max} {
		set ::metric_yield $::metric_setting_yield_max
		recalculate_brew_ratio
	} else {
		set ::metric_yield $new_yield
	}

	metric_copy_yield_to_settings
}

proc recalculate_brew_ratio {} {
    set new_ratio [round_to_one_digits [expr $::metric_yield / $::settings(grinder_dose_weight)]]
	if {$new_ratio < $::metric_setting_ratio_min} {
    	set ::metric_ratio $::metric_setting_ratio_min
		recalculate_yield
	} elseif {$new_ratio > $::metric_setting_ratio_max} {
    	set ::metric_ratio  $::metric_setting_ratio_max
		recalculate_yield
	} else {
	    set ::metric_ratio $new_ratio
	}
}

