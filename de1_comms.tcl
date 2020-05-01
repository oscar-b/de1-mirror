
package provide de1_comms

set ::failed_attempt_count_connecting_to_de1 0
set ::successful_de1_connection_count 0

proc de1_real_machine {} {
	if {$::connectivity == "BLE"} {
		return true
	} 
	if {$::connectivity == "TCP"} {
		return true
	} 
	if {$::connectivity == "USB"} {
		return true
	} 

	# "mock" machine or any other (unexpected) fallthrough value
	return false
}

proc de1_real_machine_connected {} {
	if {![de1_real_machine]} {
		return false
	}

	# for each form of connectivity, determine whether the machine is 
	# currently connected
	if {$::connectivity == "BLE"} {
		if {[ifexists ::sinstance($::de1(suuid))] != ""} {
			return true
		}
	}

# TODO(REED) - implement connected checks for the other forms of connectivity
# note these should probably move into e.g. bluetooth.tcl for organizational reasons

	return false
}

# Can use these "de1_safe_for" functions to implement safety checks as needed, in a way that works across
# different means of connectivity.  E.g. these could be written to say 'let's not allow any 
# calibrarion operations except via BLE' if that was the desired policy to be enforced
# (As it stands the policy is "stuff is safe on any "real" machine that is currently thought 
# to be connected.)
proc de1_safe_for_firmware {} {
	return [de1_real_machine_connected]
}

proc de1_safe_for_mmr {} {
	return [de1_safe_for_firmware]
}

proc de1_safe_for_calibration {} {
	return [de1_safe_for_firmware]
}

proc userdata_append {comment cmd} {
	lappend ::de1(cmdstack) [list $comment $cmd]
	run_next_userdata_cmd
}

proc de1_interface {subcommand {}}

proc read_de1_version {} {
	catch {
		userdata_append "read_de1_version" [list de1_comm read "Versions"]
	}
}

# repeatedly request de1 state
proc poll_de1_state {} {
	msg "poll_de1_state"
	read_de1_state
	after 1000 poll_de1_state
}

proc read_de1_state {} {
	if {[catch {
		userdata_append "read de1 state" [list de1_comm read "StateInfo"]
	} err] != 0} {
		msg "Failed to 'read de1 state' in DE1 because: '$err'"
	}
}

proc int_to_hex {in} {
	return [format %02X $in]
}

# calibration change notifications ENABLE
proc de1_enable_calibration_notifications {} {
	if {![de1_real_machine_connected] || ![de1_safe_for_calibration]} {
		msg "DE1 not connected, cannot send command 1"
		return
	}

	userdata_append "enable de1 calibration notifications" [list de1_comm enable Calibration]
}

# calibration change notifications DISABLE
proc de1_disable_calibration_notifications {} {
	if {![de1_real_machine_connected] || ![de1_safe_for_calibration]} {
		msg "DE1 not connected, cannot send command 2"
		return
	}

	userdata_append "disable de1 calibration notifications" [list de1_comm disable Calibration]
}

# temp changes
proc de1_enable_temp_notifications {} {
	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 3"
		return
	}

	# REED to JOHN: Prouction code has cuuid_0D here, but cuuid_0D looks like ShotSample not Temperatures (0A).
	# I am keeping the behavior as I found it (still 0D) but I may be preserving a bug.  
	# So take a look... and even if you don't keep this code, consider taking a look at bluetooth.tcl 
	userdata_append "enable de1 temp notifications" [list de1_comm enable ShotSample]
}

# status changes
proc de1_enable_state_notifications {} {
	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 4"
		return
	}

	userdata_append "enable de1 state notifications" [list de1_comm enable StateInfo]
}

proc de1_disable_temp_notifications {} {
	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 5"
		return
	}

	# REED to JOHN: Prouction code has cuuid_0D here, but cuuid_0D looks like ShotSample not Temperatures (0A).
	# I am keeping the behavior as I found it (still 0D) but I may be preserving a bug.  
	# So take a look... and even if you don't keep this code, consider taking a look at bluetooth.tcl 
	userdata_append "disable temp notifications" [list de1_com disable ShotSample]
}

proc de1_disable_state_notifications {} {
	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 6"
		return
	}

	userdata_append "disable state notifications" [list de1_comm disable StateInfo]
}

# TODO(REED) - check on de1_version_bleapi (vars.tcl) which needs to be correct even for general case
proc mmr_available {} {

	if {$::de1(mmr_enabled) == 0} {
		if {[de1_version_bleapi] > 3} {
			# mmr feature became available at this version number
			set ::de1(mmr_enabled) 1
		} else {
			msg "MMR is not enabled on this DE1 BLE API <4 #: [de1_version_bleapi]"
		}
	}
	return $::de1(mmr_enabled)
}

proc de1_enable_mmr_notifications {} {

	if {[mmr_available] == 0} {
		msg "Unable to de1_enable_mmr_notifications because MMR not available"
		return
	}

	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 7"
		return
	}

	userdata_append "enable MMR read notifications" [list de1_comm enable ReadFromMMR]
}

# water level notifications
proc de1_enable_water_level_notifications {} {
	if {![de1_real_machine_connected]} {
		# REED to JOHN: 2 debug messages have "command 7" in them (MMR Read & Water Level).  
		# Dunno if it matters much, but there it is.
		msg "DE1 not connected, cannot send command 7"
		return
	}

	userdata_append "enable de1 water level notifications" [list de1_comm enable WaterLevels]
}

proc de1_disable_water_level_notifications {} {
	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 8"
		return
	}

	userdata_append "disable state notifications" [list de1_comm disable WaterLevels]
}

# firmware update command notifications (not writing new fw, this is for erasing and switching firmware)
proc de1_enable_maprequest_notifications {} {
	if {![de1_real_machine_connected] || ![de1_safe_for_firmware]} {
		msg "DE1 not connected, cannot send command 9"
		return
	}

	userdata_append "enable de1 state notifications" [list de1_comm enable FWMapRequest]
}

proc fwfile {} {
	
	if {$::settings(ghc_is_installed) == 1 || $::settings(ghc_is_installed) == 2 || $::settings(ghc_is_installed) == 3} {
		# new firmware for v1.3 machines and newer, that have a GHC.
		# this dual firmware aspect is temporary, only until we have improved the firmware to be able to correctly migrate v1.0 v1.1 hardware machines to the new calibration settings.
		# please do not bypass this test and load the new firmware on your v1.0 v1.1 machines yet.  Once we have new firmware is known to work on those older machines, we'll get rid of the 2nd firmware image.

		# note that ghc_is_installed=1 ghc hw is there but unused, whereas ghc_is_installed=3 ghc hw is required.
		return "[homedir]/fw/bootfwupdate2.dat"
	} else {
		return "[homedir]/fw/bootfwupdate.dat"
	}
}

proc start_firmware_update {} {
	if {![de1_real_machine_connected] || ![de1_safe_for_firmware]} {
		msg "DE1 not connected, cannot send command 10"
		return
	}

	if {$::settings(force_fw_update) != 1} {
		set ::de1(firmware_update_button_label) "Up to date"
		return
	}


	if {$::de1(currently_erasing_firmware) == 1} {
		msg "Already erasing firmware"
		return
	}

	if {$::de1(currently_updating_firmware) == 1} {
		msg "Already updating firmware"
		return
	}

	de1_enable_maprequest_notifications
	
	set ::de1(firmware_bytes_uploaded) 0
	set ::de1(firmware_update_size) [file size [fwfile]]

# REED to JOHN: In bluetooth.tcl this code is gated by
# 	if {$::android != 1} {
# I am not confident I grasped the intent of this if statement as it bears on what I am interpreting
# as a "delay, then execute with disabled characteristics" behavior.  
# Here I am treating it as a "simulate the firmware update for a configuration that shouldn't
# get a real update" But I can see that this may be more like a "prevent a race condition / 
# unsafe operations from transpiring in the middle of an update", in which case I have it
# totally wrong here.  Or something else.  Anyway definitely check my work.
	if {[!de1_safe_for_firmware]} {
		after 100 write_firmware_now
# TODO(REED) the following comment is hard to understand, fix
#### REED COMMENTED OUT THE FOLLOWING BLE SPECIFIC "DISABLINGS" AND DID NOT 
#### RECREATE THEM ON THE bluetooth.tcl SIDE.  YIKES, WAS THAT RIGHT?  DOES IT MATTER?
####
#### (If it is important to recreate these, then we should probably have per-connectivity-type
####  logic here (meaning, "if {$::connectivity == BLE } {...} else if {$::connectivity == TCP} {...}  )
#### so as to achieve this "disabling" behavior in a manner that doesn't rely on zeroing out the 
#### characteristic uuids (as there's no direct analog to doing that, outside BLE)
#		set ::sinstance($::de1(suuid))
#		set ::de1(cuuid_09) 0
#		set ::de1(cuuid_06) 0
#		set ::cinstance($::de1(cuuid_09)) 0
	}

	set arr(WindowIncrement) 0
	set arr(FWToErase) 1
	set arr(FWToMap) 1
	set arr(FirstError1) 0
	set arr(FirstError2) 0
	set arr(FirstError3) 0
	set data [make_packed_maprequest arr]

	set ::de1(firmware_update_button_label) "Updating"

	# it'd be useful here to test that the maprequest was correctly packed
	set ::de1(currently_erasing_firmware) 1
	userdata_append "Erase firmware: [array get arr]" [list de1_comm write FWMapRequest $data]

}

proc write_firmware_now {} {
	set ::de1(currently_updating_firmware) 1
	msg "Start writing firmware now"

	set ::de1(firmware_update_binary) [read_binary_file [fwfile]]
	set ::de1(firmware_bytes_uploaded) 0

	firmware_upload_next
}


proc firmware_upload_next {} {
	
	if {$::connectivity=="mock"} {
		msg "firmware_upload_next connected to 'mock' machine; updating button text (only)"
	} elseif {[de1_real_machine_connected] && [de1_safe_for_firmware]} {
		msg "firmware_upload_next $::de1(firmware_bytes_uploaded)"
	} else {
		msg "DE1 not connected, cannot send command 11"
		return
	}

	#delay_screen_saver

	if  {$::de1(firmware_bytes_uploaded) >= $::de1(firmware_update_size)} {
		set ::settings(firmware_crc) [crc::crc32 -filename [fwfile]]
		save_settings

		if {$::connectivity == "mock"} {
			set ::de1(firmware_update_button_label) "Updated"
			
		} else {
			set ::de1(firmware_update_button_label) "Testing"

			#set ::de1(firmware_update_size) 0
			unset -nocomplain ::de1(firmware_update_binary)
			#set ::de1(firmware_bytes_uploaded) 0

			#write_FWMapRequest(self.FWMapRequest, 0, 0, 1, 0xFFFFFF, True)		
			#def write_FWMapRequest(ctic, WindowIncrement=0, FWToErase=0, FWToMap=0, FirstError=0, withResponse=True):

			set arr(WindowIncrement) 0
			set arr(FWToErase) 0
			set arr(FWToMap) 1
			set arr(FirstError1) [expr 0xFF]
			set arr(FirstError2) [expr 0xFF]
			set arr(FirstError3) [expr 0xFF]
			set data [make_packed_maprequest arr]
			userdata_append "Find first error in firmware update: [array get arr]" [list de1_comm write FWMapRequest $data]
		}
	} else {
		set ::de1(firmware_update_button_label) "Updating"

		set data "\x10[make_U24P0 $::de1(firmware_bytes_uploaded)][string range $::de1(firmware_update_binary) $::de1(firmware_bytes_uploaded) [expr {15 + $::de1(firmware_bytes_uploaded)}]]"
		userdata_append "Write [string length $data] bytes of firmware data ([convert_string_to_hex $data])" [list de1_comm write WriteToMMR $data]
		set ::de1(firmware_bytes_uploaded) [expr {$::de1(firmware_bytes_uploaded) + 16}]
		if {$::connectivity != "mock"} {
			after 1 firmware_upload_next
		}
	}
}


proc mmr_read {address length} {
	if {[mmr_available] == 0} {
		msg "Unable to mmr_read because MMR not available"
		return
	}


 	set mmrlen [binary decode hex $length]	
	set mmrloc [binary decode hex $address]
	set data "$mmrlen${mmrloc}[binary decode hex 00000000000000000000000000000000]"
	
	if {$::connectivity == "mock"} {
		msg "MMR requesting read [convert_string_to_hex $mmrlen] bytes of firmware data from [convert_string_to_hex $mmrloc]: with comment [convert_string_to_hex $data]"
		return
	}

	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send BLE command 11"
		return
	}

	userdata_append "MMR requesting read [convert_string_to_hex $mmrlen] bytes of firmware data from [convert_string_to_hex $mmrloc] with '[convert_string_to_hex $data]'" [list de1_comm write ReadFromMMR $data]
}

proc mmr_write { address length value} {
	if {[mmr_available] == 0} {
		msg "Unable to mmr_read because MMR not available"
		return
	}

 	set mmrlen [binary decode hex $length]	
	set mmrloc [binary decode hex $address]
 	set mmrval [binary decode hex $value]	
	set data "$mmrlen${mmrloc}${mmrval}[binary decode hex 000000000000000000000000000000]"
	
	if {$::connectivity ==  "mock"} {
		msg "MMR writing [convert_string_to_hex $mmrlen] bytes of firmware data to [convert_string_to_hex $mmrloc] with value [convert_string_to_hex $mmrval] : with comment [convert_string_to_hex $data]"
		return
	}

	if ![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send BLE command 11"
		return
	}
	userdata_append "MMR writing [convert_string_to_hex $mmrlen] bytes of firmware data to [convert_string_to_hex $mmrloc] with value [convert_string_to_hex $mmrval] : with comment [convert_string_to_hex $data]" [list de1comm write WriteToMMR $data]
}

proc set_tank_temperature_threshold {temp} {
	msg "Setting desired water tank temperature to '$temp'"

	if {$temp == 0} {
		mmr_write "80380C" "04" [zero_pad [int_to_hex $temp] 2]
	} else {
		# if the water temp is being set, then set the water temp temporarily to 60º in order to force a water circulation for 2 seconds
		# then a few seconds later, set it to the real, desired value
		set hightemp 60
		mmr_write "80380C" "04" [zero_pad [int_to_hex $hightemp] 2]
		after 4000 [list mmr_write "80380C" "04" [zero_pad [int_to_hex $temp] 2]]
	}
}

# /*
#  *  Memory Mapped Registers
#  *
#  *  RangeNum Position       Len  Desc
#  *  -------- --------       ---  ----
#  *         1 0x0080 0000      4  : HWConfig
#  *         2 0x0080 0004      4  : Model
#  *         3 0x0080 2800      4  : How many characters in debug buffer are valid. Accessing this pauses BLE debug logging.
#  *         4 0x0080 2804 0x1000  : Last 4K of output. Zero terminated if buffer not full yet. Pauses BLE debug logging.
#  *         6 0x0080 3808      4  : Fan threshold.
#  *         7 0x0080 380C      4  : Tank water threshold.
#  *        11 0x0080 381C      4  : GHC Info Bitmask, 0x1 = GHC Present, 0x2 = GHC Active
#  *
#  */



proc set_steam_flow {desired_flow} {
	#return
	msg "Setting steam flow rate to '$desired_flow'"
	mmr_write "803828" "04" [zero_pad [int_to_hex $desired_flow] 2]
}

proc get_steam_flow {} {
	msg "Getting steam flow rate"
	mmr_read "803828" "00"
}


proc set_steam_highflow_start {desired_seconds} {
	#return
	msg "Setting steam high flow rate start seconds to '$desired_seconds'"
	mmr_write "80382C" "04" [zero_pad [int_to_hex $desired_seconds] 2]
}

proc get_steam_highflow_start {} {
	msg "Getting steam high flow rate start seconds "
	mmr_read "80382C" "00"
}


proc set_ghc_mode {desired_mode} {
	msg "Setting group head control mode '$desired_mode'"
	mmr_write "803820" "04" [zero_pad [int_to_hex $desired_mode] 2]
}

proc get_ghc_mode {} {
	msg "Reading group head control mode"
	mmr_read "803820" "00"
}

proc get_ghc_is_installed {} {
	msg "Reading whether the group head controller is installed or not"
	mmr_read "80381C" "00"
}

proc get_fan_threshold {} {
	msg "Reading at what temperature the PCB fan turns on"
	mmr_read "803808" "00"
}

proc set_fan_temperature_threshold {temp} {
	msg "Setting desired water tank temperature to '$temp'"
	mmr_write "803808" "04" [zero_pad [int_to_hex $temp] 2]
}

proc get_tank_temperature_threshold {} {
	msg "Reading desired water tank temperature"
	mmr_read "80380C" "00"
}

proc de1_cause_refill_now_if_level_low {} {

	# john 05-08-19 commented out, will obsolete soon.  Turns out not to work, because SLEEP mode does not check low water setting.
	return

	# set the water level refill point to 10mm more water
	set backup_waterlevel_setting $::settings(water_refill_point)
	set ::settings(water_refill_point) [expr {$::settings(water_refill_point) + 20}]
	de1_send_waterlevel_settings

	# then set the water level refill point back to the user setting
	set ::settings(water_refill_point) $backup_waterlevel_setting

	# and in 30 seconds, tell the machine to set it back to normal
	after 30000 de1_send_waterlevel_settings
}

proc de1_send_waterlevel_settings {} {
	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send BLE command 12"
		return
	}

	set data [return_de1_packed_waterlevel_settings]
	parse_binary_water_level $data arr2
	userdata_append "Set water level settings: [array get arr2]" [list de1_comm write WaterLevels $data]
}


### REED to JOHN: I decided to retain the ::de1(wrote) logic outside the BLE connectivity code, 
### making it applicable to all communication modalities, even though the protection it provides 
### may not be of benefit to non the-BLE cases.  Even though this may come at some cost in terms
### of throughput, it seemed the safer thing to do.  It would be pretty easy to defeat the protection 
### by making this one check (here at the top of proc run_next_userdata_command) conditional on
### {$::connectivity == "BLE"}, while still preserving the logic of setting and unsetting
### de1(wrote) ... which would make the "one command at a time" ve "not" an easy choice to revert.
proc run_next_userdata_cmd {} {
	# only write one command at a time.  this protection was implemented for BLE
	# but currently retained for all forms of connectivity (safer).
	if {$::de1(wrote) == 1} {
		#msg "Do no write, already writing to DE1"
		return
	}

	if {![de1_real_machine_connected]} {
# TODO(REED) note this useful-looking definition for what "not connected via BLE looks like
#	if {($::de1(device_handle) == "0" || $::de1(device_handle) == "1") && $::de1(scale_device_handle) == "0"} {
		#msg "error: de1 not connected"
		return
	}

	if {$::de1(cmdstack) ne {}} {

		set cmd [lindex $::de1(cmdstack) 0]
		set cmds [lrange $::de1(cmdstack) 1 end]
		set result 0
		msg ">>> [lindex $cmd 0] (-[llength $::de1(cmdstack)])"
		set errcode [catch {
		set result [{*}[lindex $cmd 1]]
			
		}]

	    if {$errcode != 0} {
	        catch {
	            msg "run_next_userdata_cmd catch error: $::errorInfo"
	        }
	    }


		if {$result != 1} {
			msg "comm command failed, will retry ($result): [lindex $cmd 1]"

			# john 4/28/18 not sure if we should give up on the command if it fails, or retry it
			# retrying a command that will forever fail kind of kills the BLE abilities of the app
			
			#after 500 run_next_userdata_cmd
			return 
		}


		set ::de1(cmdstack) $cmds
		set ::de1(wrote) 1
		set ::de1(previouscmd) [lindex $cmd 1]
		if {[llength $::de1(cmdstack)] == 0} {
			msg "BLE command queue is now empty"
		}

	} else {
		#msg "no userdata cmds to run"
	}
}

proc close_all_comms_and_exit {} {

# TODO(REED) Write code to close non-BLE comms here

# call the ble-specific routine to finish exiting (unconditionally,regardless of $::connectvity)
# because we might be connected to scales and whatnot
	close_all_ble_and_exit
}	

proc app_exit {} {
	close_log_file

	if {$::connectivity == "mock"} {
		close_all_comms_and_exit
	}

	# john 1/15/2020 this is a bit of a hack to work around a firmware bug in 7C24F200 that has the fan turn on during sleep, if the fan threshold is set > 0
	set_fan_temperature_threshold 0

	set ::exit_app_on_sleep 1
	start_sleep
	
	# fail-over, if the DE1 doesn't to to sleep
	set since_last_ping [expr {[clock seconds] - $::de1(last_ping)}]
	if {$since_last_ping > 10} {
		# wait less time for the fail-over if we don't have any temperature pings from the DE1
		after 1000 close_all_comms_and_exit
	} else {
		after 5000 close_all_comms_and_exit
	}

	after 10000 "exit 0"
}

proc de1_send_state {comment msg} {
	if {$![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 13"
		return
	}

	#clear_timers
	delay_screen_saver
	
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	#set ::de1(substate) -
	#msg "Sending to DE1: '$msg'"
	userdata_append $comment [list de1_comm write RequestedState "$msg"]
}


#proc send_de1_shot_and_steam_settings {} {
#	return
#	msg "send_de1_shot_and_steam_settings"
	#return
	#de1_send_shot_frames
#	de1_send_steam_hotwater_settings

#}

proc de1_send_shot_frames {} {

	set parts [de1_packed_shot]
	set header [lindex $parts 0]
	
	####
	# this is purely for testing the parser/deparser
	parse_binary_shotdescheader $header arr2
	#msg "frame header of [string length $header] bytes parsed: $header [array get arr2]"
	####


	userdata_append "Espresso header: [array get arr2]" [list de1_comm write HeaderWrite $header]

	set cnt 0
	foreach packed_frame [lindex $parts 1] {

		####
		# this is purely for testing the parser/deparser
		incr cnt
		unset -nocomplain arr3
		parse_binary_shotframe $packed_frame arr3
		#msg "frame #$cnt data parsed [string length $packed_frame] bytes: $packed_frame  : [array get arr3]"
		msg "frame #$cnt: [string length $packed_frame] bytes: [array get arr3]"
		####

		userdata_append "Espresso frame #$cnt: [array get arr3] (FLAGS: [parse_shot_flag $arr3(Flag)])"  [list de1_comm write FrameWrite $packed_frame]
	}

	# only set the tank temperature for advanced profile shots
	if {$::settings(settings_profile_type) == "settings_2c"} {
		set_tank_temperature_threshold $::settings(tank_desired_water_temperature)
	} else {
		set_tank_temperature_threshold 0
	}


	return
}

proc save_settings_to_de1 {} {
	de1_send_shot_frames
	de1_send_steam_hotwater_settings
}

proc de1_send_steam_hotwater_settings {} {

	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 16"
		return
	}

	set data [return_de1_packed_steam_hotwater_settings]
	parse_binary_hotwater_desc $data arr2
	userdata_append "Set water/steam settings: [array get arr2]" [list de1_comm write ShotSettings $data]

	set_steam_flow $::settings(steam_flow)
	set_steam_highflow_start $::settings(steam_highflow_start)
}

proc de1_send_calibration {calib_target reported measured {calibcmd 1} } {
	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 17"
		return
	}

	if {$calib_target == "flow"} {
		set target 0
	} elseif {$calib_target == "pressure"} {
		set target 1
	} elseif {$calib_target == "temperature"} {
		set target 2
	} else {
		msg "Uknown calibration target: '$calib_target'"
		return
	}

	set arr(WriteKey) [expr 0xCAFEF00D]

	# change calibcmd to 2, to reset to factory settings, otherwise default of 1 does a write
	set arr(CalCommand) $calibcmd
	
	set arr(CalTarget) $target
	set arr(DE1ReportedVal) [convert_float_to_S32P16 $reported]
	set arr(MeasuredVal) [convert_float_to_S32P16 $measured]

	set data [make_packed_calibration arr]
	parse_binary_calibration $data arr2
	userdata_append "Set calibration: [array get arr2] : [string length $data] bytes: ([convert_string_to_hex $data])" [list de1_comm write Calibration $data]
}

proc de1_read_calibration {calib_target {factory 0} } {
	if {![de1_real_machine_connected]} {
		msg "DE1 not connected, cannot send command 18"
		return
	}


	if {$calib_target == "flow"} {
		set target 0
	} elseif {$calib_target == "pressure"} {
		set target 1
	} elseif {$calib_target == "temperature"} {
		set target 2
	} else {
		msg "Uknown calibration target: '$calib_target'"
		return
	}

	#set arr(WriteKey) [expr 0xCAFEF00D]
	set arr(WriteKey) 1

	set arr(CalCommand) 0
	set what "current"
	if {$factory == "factory"} {
		set arr(CalCommand) 3
		set what "factory"
	}
	
	set arr(CalTarget) $target
	set arr(DE1ReportedVal) 0
	set arr(MeasuredVal) 0

	set data [make_packed_calibration arr]
	parse_binary_calibration $data arr2
	userdata_append "Read $what calibration: [array get arr2] : [string length $data] bytes: ([convert_string_to_hex $data])" [list de1_comm write Calibrarion $data]

}

proc de1_read_version_obsolete {} {
	msg "LIKELY OBSOLETE BLE FUNCTION: DO NOT USE"

	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read de1 version" [list de1_comm read Temperatures]
}

proc de1_read_hotwater {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read de1 hot water/steam" [list de1_comm read ShotSettings]
}

proc de1_read_shot_header {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read shot header" [list de1_comm read HeaderWrite]
}
proc de1_read_shot_frame {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read shot frame" [list de1_comm read FrameWrite]
}

proc remove_null_terminator {instr} {
	set pos [string first "\x00" $instr]
	if {$pos == -1} {
		return $instr
	}

	incr pos -1
	return [string range $instr 0 $pos]
}

proc android_8_or_newer {} {

	if {$::runtime != "android"} {
		msg "android_8_or_newer reports: not android (0)"		
		return 0
	}

	catch {
		set x [borg osbuildinfo]
		#msg "osbuildinfo: '$x'"
		array set androidprops $x
		msg [array get androidprops]
		msg "Android release reported: '$androidprops(version.release)'"
	}
	set test 0
	catch {
		set test [expr {$androidprops(version.release) >= 8}]
	}
	#msg "Is this Android 8 or newer? '$test'"
	return $test
	

	#msg "android_8_or_newer failed and reports: 0"
	#return 0
}

proc connect_to_devices {} {

	#@return
	msg "connect_to_devices"

	if {$::connectivity != "BLE"} {
		connect_to_de1
	}
	# we unconditionally call ble_connect_to_devices because:
	# - if BLE *is* the de1 connectivity mode, it establishes that connection
	# - if BLE is *NOT* the de1 connectivity mode, it does not disrupt whatever is already
	#   active
	# - whether or not we are using BLE to talk to the DE1, this allows other
	#   BLE devices to be connected (e.g. scale)
	# - for the latter case (scales etc) we don't want a bunch of ble-specific complexity
	#   in this file (e.g. determining which BLE connection approach to invoke, dependent
	#   on android version.) seems safer & better architectured to leave that all in one 
	#   place, with "ble" in the filename)
	ble_connect_to_devices
}


set ::currently_connecting_de1_handle 0
proc connect_to_de1 {} {
	msg "connect_to_de1"
	#return

	if {$::connectivity == "BLE"} {
		return [ble_connect_to_de1]
	} elseif {$::connectivity == "mock"} {
		msg "simulated DE1 connection"
	    set ::de1(connect_time) [clock seconds]
	    set ::de1(last_ping) [clock seconds]

	    msg "Connected to fake DE1"
		set ::de1(device_handle) 1

		# example binary string containing binary version string
		#set version_value "\x01\x00\x00\x00\x03\x00\x00\x00\xAC\x1B\x1E\x09\x01"
		#set version_value "\x01\x00\x00\x00\x03\x00\x00\x00\xAC\x1B\x1E\x09\x01"
		set version_value "\x02\x04\x00\xA4\x0A\x6E\xD0\x68\x51\x02\x04\x00\xA4\x0A\x6E\xD0\x68\x51"
		parse_binary_version_desc $version_value arr2
		set ::de1(version) [array get arr2]

		return
	} else {
		# TODO(REED) Actually connect here -- see this routine in ble for the catch / error code handling

		# subscribe and initialize outside
		# what happens during BLE enumeration using the recommendations from here: 
		# https://3.basecamp.com/3671212/buckets/7351439/messages/1976315941#__recording_2008131794
		de1_enable_temp_notifications
		de1_enable_water_level_notifications
		de1_send_steam_hotwater_settings
		de1_send_shot_frames
		read_de1_version
		de1_enable_state_notifications
		read_de1_state
	} 

    set ::de1(connect_time) 0
    
    set ::de1_name "DE1"
}


# TODO(REED) consider resurrecting this to shim a "connect via tcp" fake machine entry
# into the BT connection UI?
#proc append_to_de1_bluetooth_list {address} {
#	set newlist $::de1_bluetooth_list
#	lappend newlist $address
#	set newlist [lsort -unique $newlist]
#
#	if {[llength $newlist] == [llength $::de1_bluetooth_list]} {
#		return
#	}
#
#	msg "Scan found DE1: $address"
#	set ::de1_bluetooth_list $newlist
#	catch {
#		fill_ble_listbox
#	}
#}


proc later_new_de1_connection_setup {} {
	# less important stuff, also some of it is dependent on BLE version

	de1_enable_mmr_notifications
	de1_send_shot_frames
	set_fan_temperature_threshold $::settings(fan_threshold)
	de1_send_steam_hotwater_settings
	get_ghc_is_installed

	de1_send_waterlevel_settings
	de1_enable_water_level_notifications

	after 5000 read_de1_state

}

proc calibration_received {value} {

    #calibration_ble_received $value
	parse_binary_calibration $value arr2
	#msg "calibration data received [string length $value] bytes: $value  : [array get arr2]"

	set varname ""
	if {[ifexists arr2(CalTarget)] == 0} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_flow"
		} else {
			set varname	"calibration_flow"
		}
	} elseif {[ifexists arr2(CalTarget)] == 1} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_pressure"
		} else {
			set varname	"calibration_pressure"
		}
	} elseif {[ifexists arr2(CalTarget)] == 2} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_temperature"
		} else {
			set varname	"calibration_temperature"
		}
	} 

	if {$varname != ""} {
		# this BLE characteristic receives packets both for notifications of reads and writes, but also the real current value of the calibration setting
		if {[ifexists arr2(WriteKey)] == 0} {
			msg "$varname value received [string length $value] bytes: [convert_string_to_hex $value] $value : [array get arr2]"
			set ::de1($varname) $arr2(MeasuredVal)
		} else {
			msg "$varname NACK received [string length $value] bytes: [convert_string_to_hex $value] $value : [array get arr2] "
		}
	} else {
		msg "unknown calibration data received [string length $value] bytes: $value  : [array get arr2]"
	}

}

proc after_shot_weight_hit_update_final_weight {} {

	if {$::de1(scale_sensor_weight) > $::de1(final_water_weight)} {
		# if the current scale weight is more than the final weight we have on record, then update the final weight
		set ::de1(final_water_weight) $::de1(scale_sensor_weight)
		set ::settings(drink_weight) [round_to_one_digits $::de1(final_water_weight)]
	}

}

# TODO(REED) - use this?
proc fast_write_open {fn parms} {
    set f [open $fn $parms]
    fconfigure $f -blocking 0
    fconfigure $f -buffersize 1000000
    return $f
}


# TODO(REED) Consider resurrecting this for status on the settings page
#proc scanning_state_text {} {
#	if {$::scanning == 1} {
#		return [translate "Searching"]
#	}
#
#	if {$::currently_connecting_de1_handle != 0} {
#		return [translate "Connecting"]
#	} 
#
#	if {[expr {$::de1(connect_time) + 5}] > [clock seconds]} {
#		return [translate "Connected"]
#	}
#
#	#return [translate "Tap to select"]
#	if {[ifexists ::de1_needs_to_be_selected] == 1 || [ifexists ::scale_needs_to_be_selected] == 1} {
#		return [translate "Tap to select"]
#	}
#
#	return [translate "Search"]
#}

proc data_to_hex_string {data} {
    return [binary encode hex $data]
}



# /**** TODO(REED) ****/
    # Do the actual send operation on the configured connection.
    # These should all be wrapped in catch statements etc. for proper
    # error handling & recovery
    if {$::connectivity == "TCP"} {
        if {[info exists ::TCPSocket]} {
            # Presumably this should be wrapped in a catch statement
            # for cases of lost connection, full buffers, etc.
            puts -nonewline $::de1(desireSock) "<$command>$data_str\n"
            flush $::de1(desireSock)
            return 1
        }
    } elseif {$::connectivity == "USB"} {
        if {$::runtime == "android"} {
            ## OTG code goes here
        } else {
            ## USBserial code goes here
        }
    } else {
        msg "Connectivity configuration error"
    }
