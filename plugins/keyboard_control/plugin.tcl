package require de1plus 1.0

set plugin_name "keyboard_control"

namespace eval ::plugins::${plugin_name} {
	variable author "Vincent Politzer"
	variable contact "redfoxdude@gmail.com"
	variable version 1.4.1
	variable description "Control your non-GHC DE1 with a keyboard"

	# last_keypress_time is used to filter repeated keypresses,
	# i.e. pressing and holding a key (or Android thinking a key is held)
	variable last_keypress_time 0
	variable repeated_keypress_count 0

	proc single_letter {newstr} {
		if {[string length $newstr] > 1} {
			return 0
		}
		if {[string is lower $newstr] || [string is upper $newstr]} {
			return 1
		}
		borg toast [translate "Letter keys only!"]
		return 0
	}

	proc convert_key_and_save {key_cmd} {
		if {$key_cmd == "Espresso"} {
			set save_key espresso_key
			set save_keycode espresso_keycode
		} elseif {$key_cmd == "Steam"} {
			set save_key steam_key
			set save_keycode steam_keycode
		} elseif {$key_cmd == "HotWater"} {
			set save_key water_key
			set save_keycode water_keycode
		} elseif {$key_cmd == "HotWaterRinse"} {
			set save_key flush_key
			set save_keycode flush_keycode
		}
		# force lowercase
		set ::plugins::keyboard_control::settings($save_key) [string tolower $::plugins::keyboard_control::settings($save_key)]
		# convert to ASCII
		scan $::plugins::keyboard_control::settings($save_key) %c ::plugins::keyboard_control::settings($save_keycode)
		msg [namespace current] "Saving keyboard_control settings"
		plugins save_settings "keyboard_control"
	}


	proc keycode_to_cmd {keycode keypress_time} {
		variable last_keypress_time
		variable repeated_keypress_count
		# lowercase letters have a keycode offset of 93 between ASCII and Android
		if {$::some_droid} { incr keycode 93 }

		# only allow lowercase letters
		if {$keycode >= 97 && $keycode <= 122} {
			# check when the last keypress came in (not counting CTRL modifier)
			set keypress_time_delta [expr $keypress_time - $last_keypress_time]
			set last_keypress_time $keypress_time
			# assume average keypress duration is ~300ms
			if {$keypress_time_delta < 300} {
				incr repeated_keypress_count 1
				borg toast "[translate "Check keyboard"]: $repeated_keypress_count [translate "repeated keypresses"]"
				msg [namespace current] "$repeated_keypress_count repeated keypresses / $keypress_time_delta since last"
				return "Invalid"
			}
			set repeated_keypress_count 0

			if {$keycode == $::plugins::keyboard_control::settings(espresso_keycode)} {
				return "Espresso"
			} elseif {$keycode == $::plugins::keyboard_control::settings(steam_keycode)} {
				return "Steam"
			} elseif {$keycode == $::plugins::keyboard_control::settings(water_keycode)} {
				return "HotWater"
			} elseif {$keycode == $::plugins::keyboard_control::settings(flush_keycode)} {
				return "HotWaterRinse"
			}
			return "Undefined"
		} else {
			return "Invalid"
		}
	}

	proc handle_keypress {keycode keypress_time} {
		msg [namespace current] "Keypress detected: $keycode / $keypress_time / $::some_droid"
		set curr_state $::de1_num_state($::de1(state))
		set curr_substate $::de1_substate_types($::de1(substate))
		set kbc_cmd [::plugins::keyboard_control::keycode_to_cmd $keycode $keypress_time]

		msg [namespace current] "Keypress deemed: $kbc_cmd"
		if {$kbc_cmd != "Invalid"}	{
			# Check if machine is ready
			if {($curr_state == "Idle") && ($curr_substate == "ready")} {
				if {$kbc_cmd == "Espresso"} {
					borg toast [translate "Starting espresso"]
					if { [string tolower $::settings(skin)] eq "metric" } {
						do_start_espresso
					} else {
						start_espresso
					}
				} elseif {$kbc_cmd == "Steam"} {
					borg toast [translate "Starting steam"]
					if { [string tolower $::settings(skin)] eq "metric" } {
						do_start_steam
					} else {
						start_steam
					}
				} elseif {$kbc_cmd == "HotWater"} {
					borg toast [translate "Starting hot water"]
					if { [string tolower $::settings(skin)] eq "metric" } {
						do_start_water
					} else {
						start_water
					}
				} elseif {$kbc_cmd == "HotWaterRinse"} {
					borg toast [translate "Starting flush"]
					if { [string tolower $::settings(skin)] eq "metric" } {
						do_start_flush
					} else {
						start_flush
					}
				}
			# Check if the machine is in the process of heating or ending
			} elseif {($curr_substate != "heating") && ($curr_substate != "ending")} {
				if {$curr_state == "Espresso"} {
					if {($kbc_cmd == "HotWater") || ($kbc_cmd == "HotWaterRinse") || ($kbc_cmd == "Undefined")} {
						# stop espresso
						borg toast [translate "Stopping espresso"]
						start_idle
					} elseif {($kbc_cmd == "Espresso") || ($kbc_cmd == "Steam")} {
						if {($::plugins::keyboard_control::settings(enable_next_step_tap) == 1) && ($curr_substate != "final heating") && ($curr_substate != "stabilising")} {
							# move on to next espresso step
							borg toast [translate "Moving to next step"]
							start_next_step
						} else {
							borg toast [translate "Stopping espresso"]
							start_idle
						}
					}
				} elseif {$curr_state == "Steam"} {
					if {($kbc_cmd == "Espresso") || ($kbc_cmd == "Steam") || ($kbc_cmd == "HotWater") || ($kbc_cmd == "HotWaterRinse") || ($kbc_cmd == "Undefined")} {
						# stop steam
						borg toast [translate "Stopping steam"]
						start_idle
					}
				} elseif {$curr_state == "HotWater"} {
					if {($kbc_cmd == "Espresso") || ($kbc_cmd == "Steam") || ($kbc_cmd == "HotWater") || ($kbc_cmd == "HotWaterRinse") || ($kbc_cmd == "Undefined")} {
						# stop water
						borg toast [translate "Stopping hot water"]
						start_idle
					}
				} elseif {$curr_state == "HotWaterRinse"} {
					if {($kbc_cmd == "Espresso") || ($kbc_cmd == "Steam") || ($kbc_cmd == "HotWater") || ($kbc_cmd == "HotWaterRinse") || ($kbc_cmd == "Undefined")} {
						# stop flush
						borg toast [translate "Stopping flush"]
						start_idle
					}
				}
			} else {
				borg toast [translate "Please wait"]
			}
		}
	}

	proc preload {} {

		# Unique name per page
		set page_name "plugin_keyboard_control_page_default"

		# Background image and "Done" button
		add_de1_page "$page_name" "settings_message.png" "default"
		add_de1_text $page_name 1280 1310 -text [translate "Done"] -font Helv_10_bold -fill "#fAfBff" -anchor "center"
		add_de1_button $page_name {say [translate {Done}] $::settings(sound_button_in); plugins save_settings keyboard_control; page_to_show_when_off extensions}  980 1210 1580 1410 ""

		# Headline
		add_de1_text $page_name 1280 300 -text [translate "Keyboard Control"] -font Helv_20_bold -width 1200 -fill "#444444" -anchor "center" -justify "center"

		# Espresso Key Setting
		add_de1_text $page_name 280 440 -text [translate "Espresso Key"] -font Helv_8 -width 300 -fill "#444444" -anchor "nw" -justify "center"
		add_de1_widget "$page_name" entry 280 500  {
			bind $widget <Return> { say [translate {save}] $::settings(sound_button_in); borg toast [translate "Saved"]; ::plugins::keyboard_control::convert_key_and_save "Espresso"; hide_android_keyboard}
			bind $widget <Leave> { say [translate {save}] $::settings(sound_button_in); borg toast [translate "Saved"]; ::plugins::keyboard_control::convert_key_and_save "Espresso"; hide_android_keyboard}
		} -width [expr {int(3 * $::globals(entry_length_multiplier))}] -validate all -validatecommand {::plugins::keyboard_control::single_letter %P} -font Helv_8  -borderwidth 1 -bg #fbfaff  -foreground #4e85f4 -textvariable ::plugins::keyboard_control::settings(espresso_key) -relief flat  -highlightthickness 1 -highlightcolor #000000

		# Steam Key Setting
		add_de1_text $page_name 280 600 -text [translate "Steam Key"] -font Helv_8 -width 300 -fill "#444444" -anchor "nw" -justify "center"
		add_de1_widget "$page_name" entry 280 660  {
			bind $widget <Return> { say [translate {save}] $::settings(sound_button_in); borg toast [translate "Saved"]; ::plugins::keyboard_control::convert_key_and_save "Steam"; hide_android_keyboard}
			bind $widget <Leave> { say [translate {save}] $::settings(sound_button_in); borg toast [translate "Saved"]; ::plugins::keyboard_control::convert_key_and_save "Steam"; hide_android_keyboard}
		} -width [expr {int(3 * $::globals(entry_length_multiplier))}] -validate all -validatecommand {::plugins::keyboard_control::single_letter %P} -font Helv_8  -borderwidth 1 -bg #fbfaff  -foreground #4e85f4 -textvariable ::plugins::keyboard_control::settings(steam_key) -relief flat  -highlightthickness 1 -highlightcolor #000000

		# Hot Water Key Setting
		add_de1_text $page_name 280 760 -text [translate "Hot Water Key"] -font Helv_8 -width 300 -fill "#444444" -anchor "nw" -justify "center"
		add_de1_widget "$page_name" entry 280 820  {
			bind $widget <Return> { say [translate {save}] $::settings(sound_button_in); borg toast [translate "Saved"]; ::plugins::keyboard_control::convert_key_and_save "HotWater"; hide_android_keyboard}
			bind $widget <Leave> { say [translate {save}] $::settings(sound_button_in); borg toast [translate "Saved"]; ::plugins::keyboard_control::convert_key_and_save "HotWater"; hide_android_keyboard}
		} -width [expr {int(3 * $::globals(entry_length_multiplier))}] -validate all -validatecommand {::plugins::keyboard_control::single_letter %P} -font Helv_8  -borderwidth 1 -bg #fbfaff  -foreground #4e85f4 -textvariable ::plugins::keyboard_control::settings(water_key) -relief flat  -highlightthickness 1 -highlightcolor #000000

		# Flush Key Setting
		add_de1_text $page_name 280 920 -text [translate "Flush Key"] -font Helv_8 -width 300 -fill "#444444" -anchor "nw" -justify "center"
		add_de1_widget "$page_name" entry 280 980  {
			bind $widget <Return> { say [translate {save}] $::settings(sound_button_in); borg toast [translate "Saved"]; ::plugins::keyboard_control::convert_key_and_save "HotWaterRinse"; hide_android_keyboard}
			bind $widget <Leave> { say [translate {save}] $::settings(sound_button_in); borg toast [translate "Saved"]; ::plugins::keyboard_control::convert_key_and_save "HotWaterRinse"; hide_android_keyboard}
		} -width [expr {int(3 * $::globals(entry_length_multiplier))}] -validate all -validatecommand {::plugins::keyboard_control::single_letter %P} -font Helv_8  -borderwidth 1 -bg #fbfaff  -foreground #4e85f4 -textvariable ::plugins::keyboard_control::settings(flush_key) -relief flat  -highlightthickness 1 -highlightcolor #000000

		# Next Step on Espresso or Steam key tap Setting
		add_de1_widget "$page_name" checkbutton 260 1100 {} -text [translate "Next Step on Espresso or Steam key tap"] -indicatoron true  -font Helv_8 -bg #FFFFFF -anchor nw -foreground #4e85f4 -variable ::plugins::keyboard_control::settings(enable_next_step_tap)  -borderwidth 0 -selectcolor #FFFFFF -highlightthickness 0 -activebackground #FFFFFF  -bd 0 -activeforeground #4e85f4 -relief flat -bd 0

		return $page_name
	}

	proc main {} {
		msg [namespace current] "keyboard_control plugin enabled"
		focus .can
		bind Canvas <KeyPress> {::plugins::keyboard_control::handle_keypress %k %t}
	}
}
