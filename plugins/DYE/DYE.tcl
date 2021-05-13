#######################################################################################################################
### A Decent DE1app plugin for the DSx skin that improves the default logging / "describe your espresso"
### functionality in Insight and DSx.
###  
### INSTALLATION: 
###	    1) Ensure you have DE1 app v1.33 stable (except for fontawesome symbols, which may need to be downloaded manually) 
###			or higher, and DSx version v4.39 or higher.
###		2) Copy this file "describe_your_espresso.dsx" to the "de1_plus/skins/DSx/DSx_Plugins" folder.
###		3) Restart the app with DSx as skin.
###
### Features:
###	1) "Describe your espresso" accesible from DSx home screen with a single click, for both next and last shots.
###	2) All main description data in a single screen for easier data entry.
###		* Irrelevant options ("I weight my beans" / "I use a refractometer") are removed.
###	3) Facilitate data entry in the UI:
###		* Numeric fields can be typed directly.
###		* Keyboard return in non-multiline entries take you directly to the next field.
###		* Choose categories fields (bean brand, type, grinder, etc) from a list of all previously typed values.
###		* Star-rating system for Enjoyment
###		* Mass-modify past entered categories values at once.
###	4) Description data from previous shot can now be retrieved and modified:
###		* A summary is shown on the History Viewer page, below the profile on both the left and right shots.
###		* When that summary is clicked, the describe page is open showing the description for the past shot,
###			which can be modified.
### 5) Create a SQLite database of shot descriptions.
### 	* Populate on startup
###		* User decides what is to be stored in the database.
###		* Update whenever there are new shots or shot data changes
###		* Update on startup when a shot file has been changed on disk (TODO using a simple/fast test, some cases
###			may be undetected, review)
###		* TBD Persist profiles too (as an option)
### 6) "Filter Shot History" page callable from the history viewer to restrict the shots being shown on both 
###		left and right listboxes.
### 7) TBD Add new description data: other equipment, beans details (country, variety), detailed coffee ratings like
##		in cupping scoring sheets, etc.
### 8) Upload shot files to Miha's visualizer or other repositories with a button press.
### 9) Configuration page allows defining settings and launch database maintenance actions from within the app. 
###
### Source code available in GitHub: https://github.com/ebengoechea/dye_de1app_dsx_plugin/
### This code is released under GPLv3 license. See LICENSE file under the DE1 source folder in github.
###
### By Enrique Bengoechea <enri.bengoechea@gmail.com> 
### (with lots of copy/paste/tweak from Damian, John and Johanna's code!)
########################################################################################################################

#set ::skindebug 1 
#plugins enable DYE

namespace eval ::plugins::DYE {
	variable author "Enrique Bengoechea"
	variable contact "enri.bengoechea@gmail.com"
	variable version 2.03
	variable github_repo ebengoechea/de1app_plugin_DYE
	variable name [translate "Describe Your Espresso"]
	variable description [translate "Describe any shot from your history and plan the next one: beans, grinder, extraction parameters and people."]

	variable min_de1app_version {1.36}
	variable min_DSx_version {4.54}
	variable debug_text {}	
	
	# Store widgets used in the skin-specific GUI integration 
	variable widgets
	array set widgets {}
	
	variable desc_text_fields {bean_brand bean_type roast_date roast_level bean_notes grinder_model grinder_setting \
		espresso_notes my_name drinker_name skin repository_links}	
	variable desc_numeric_fields {grinder_dose_weight drink_weight drink_tds drink_ey espresso_enjoyment}
	variable propagated_fields {bean_brand bean_type roast_date roast_level bean_notes grinder_model grinder_setting \
		my_name drinker_name}
	
	variable default_shot_desc_font_color {#206ad4}
	variable last_shot_desc {}	
	variable next_shot_desc {}
	variable past_shot_desc {}
	variable past_shot_desc_one_line {}
	variable past_shot_desc2 {}
	variable past_shot_desc_one_line2 {}
}

### PLUGIN WORKFLOW ###################################################################################################

# Startup the Describe Your Espresso plugin.
proc ::plugins::DYE::main {} {
	msg "Starting the 'Describe Your Espresso' plugin"
	check_versions
		
	set skin $::settings(skin)
	set skin_src_fn "[plugin_directory]/DYE/setup_${skin}.tcl"
	if { [file exists $skin_src_fn] } { source $skin_src_fn }
	
	if { [namespace which -command "::plugins::DYE::setup_ui_$::settings(skin)"] ne "" } {
		::plugins::DYE::setup_ui_$::settings(skin)
	}
	foreach page {DYE DYE_fsh} {
		dui page add $page -namespace true
	}
	
	# Update the describe settings when the a shot is started 
	trace add execution ::reset_gui_starting_espresso enter ::plugins::DYE::reset_gui_starting_espresso_enter_hook
	trace add execution ::reset_gui_starting_espresso leave ::plugins::DYE::reset_gui_starting_espresso_leave_hook
	
	# Ensure the description summary is updated whenever last shot is saved to history.
	# We don't use 'register_state_change_handler' as that would not update the shot file if its metadata is 
	#	changed in the Godshots page in Insight or DSx (though currently that does not work)
	#register_state_change_handler Espresso Idle ::plugins::SDB::save_espresso_to_history_hook
	if { [plugins enabled visualizer_upload] } {
		plugins load visualizer_upload
		trace add execution ::plugins::visualizer_upload::uploadShotData leave ::plugins::DYE::save_espresso_to_history_hook
	} else {
		trace add execution ::save_this_espresso_to_history leave ::plugins::DYE::save_espresso_to_history_hook
	}
	
	if { [ifexists ::debugging 0] == 1 && $::android != 1 } {
		ifexists ::debugging_window_title "Decent"
		wm title . "$::debugging_window_title DYE v$::plugins::DYE::version"
	}
}

# Paint settings screen
proc ::plugins::DYE::preload {} {
	if { [plugins available SDB] } {
		plugins preload SDB
	}
	package require de1_logging 1.0
	package require de1_dui 1.0
	
	# Because DUI calls the page setup commands automatically we need to initialize stuff here
	dui add image_dirs "[homedir]/[plugin_directory]/DYE/"
		
	check_settings
	plugins save_settings DYE

	setup_default_aspects
	dui page add DYE_settings -namespace true -theme default
	return DYE_settings
}

proc ::plugins::DYE::msg { {flag ""} args } {
	if { [string range $flag 0 0] eq "-" && [llength $args] > 0 } {
		::logging::default_logger $flag "::plugins::DYE" {*}$args
	} else {
		::logging::default_logger "::plugins::DYE" $flag {*}$args
	}
}

# Verify the minimum required versions of DE1 app & skin are used, and that required plugins are availabe and installed,
#	otherwise prevents startup.
proc ::plugins::DYE::check_versions {} {
	if { [package vcompare [package version de1app] $::plugins::DYE::min_de1app_version] < 0 } {
		message_page "[translate {Plugin 'Describe Your Espreso'}] v$::plugins::DYE::plugin_version [translate requires] \
DE1app v$::plugins::DYE::min_de1app_version [translate {or higher}]\r\r[translate {Current DE1app version is}] [package version de1app]" \
		[translate Ok]
	}	
	
	set skin $::settings(skin)
	if { $skin ni {Insight DSx MimojaCafe} } {
		plugins disable DYE
		error [translate "The 'Describe Your Espresso' (DYE) plugin does not yet work with your skin. Please reach out to your skins author"]
		return
	}
	
	if { [info exists ::plugins::DYE::min_${skin}_version ] } {
		# TODO: Make a proc that properly returns the skin version??
		if { $skin eq "DSx" } {
			if { [package vcompare $::DSx_settings(version) [subst \$::plugins::DYE::min_$::settings(skin)_version]] < 0 } {
				message_page "[translate {Plugin 'Describe Your Espreso'}] v$::plugins::DYE::plugin_version [translate requires]\
$::settings(skin) skin v[subst \$::plugins::DYE::min_$::settings(skin)_version] [translate {or higher}]\r\r[translate {Current $::settings(sking) version is}] $::DSx_settings(version)" \
				[translate Ok]
			}
		}
	}
	
	# Check plugin dependencies, and ensure they're loaded in the correct order.
	set depends_msg "" 		
	if { [plugins available SDB] } {
		plugins load SDB
	} else {
		append depends_msg "\n[translate {Please install 'Shot DataBase' plugin for 'Describe Your Espresso' to work}]"
	}
	
	if { $depends_msg ne "" } {
		# Throw an error that is catched by the plugins system and the plugin is disabled
		error $depends_msg
	}
}

# Ensure all settings values are defined, otherwise set them to their default values.
proc ::plugins::DYE::check_settings {} {
	variable settings
	
	if { ![info exists settings(version)] || [package vcompare $settings(version) $::plugins::DYE::version] < 0 } {
		upgrade [value_or_default settings(version) ""]
	}
	set settings(version) $::plugins::DYE::version
	
	ifexists settings(calc_ey_from_tds) on
	ifexists settings(show_shot_desc_on_home) 1
	ifexists settings(shot_desc_font_color) $::plugins::DYE::default_shot_desc_font_color
	ifexists settings(describe_from_sleep) 1
	ifexists settings(date_format) "%d/%m/%Y"
	ifexists settings(describe_icon) [dui symbol get mug]
	ifexists settings(propagate_previous_shot_desc) 1
	ifexists settings(backup_modified_shot_files) 0
	ifexists settings(use_stars_to_rate_enjoyment) 1
	ifexists settings(next_shot_DSx_home_coords) {500 1165}
	ifexists settings(last_shot_DSx_home_coords) {2120 1165}
	ifexists settings(github_latest_url) "https://api.github.com/repos/ebengoechea/de1app_plugin_DYE/releases/latest"

	# Propagation mechanism 
	ifexists settings(next_modified) 0
	foreach field_name "$::plugins::DYE::propagated_fields espresso_notes" {
		if { ! [info exists settings(next_$field_name)] } {
			set settings(next_$field_name) {}
		}
	}
	if { $settings(next_modified) == 0 } {
		if { $settings(propagate_previous_shot_desc) == 1 } {
			foreach field_name $::plugins::DYE::propagated_fields {
				set settings(next_$field_name) $::settings($field_name)
			}
			set settings(next_espresso_notes) {}
		} else {
			foreach field_name "$::plugins::DYE::propagated_fields next_espresso_notes" {
				set settings(next_$field_name) {}
			}
		}
	}
	
#	ifexists settings(visualizer_url) "visualizer.coffee"
#	ifexists settings(visualizer_endpoint) "api/shots/upload"
#	if { ![info exists settings(visualizer_username)] } { set settings(visualizer_username) {} }
#	if { ![info exists settings(visualizer_password)] } { set settings(visualizer_password) {} }
#	if { ![info exists settings(last_visualizer_result)] } { set settings(last_visualizer_result) {} }
#	ifexists settings(auto_upload_to_visualizer) 0
#	ifexists settings(min_seconds_visualizer_auto_upload) 6

	# Ensure load_DSx_past_shot and load_DSx_past2_shot in DSx includes exactly all fields we need when they load the 
	# shots.  	
	if { $::settings(skin) eq "DSx" } {
		# clock drink_weight grinder_dose_weight - already included
		set ::DSx_settings(extra_past_shot_fields) {bean_brand bean_type roast_date \
roast_level bean_notes grinder_model grinder_setting drink_tds drink_ey espresso_enjoyment \
espresso_notes my_name drinker_name scentone skin beverage_type final_desired_shot_weight repository_links}	
	}
}

proc ::plugins::DYE::upgrade { previous_version } {
	variable settings
	variable version
	
	msg -INFO "plugin upgraded from v$previous_version to v$version"
	if { $previous_version eq "" } {
		set old_settings_file "[homedir]/skins/DSx/DSx_User_Set/DYE_settings.tdb"
		if { [file exists $old_settings_file] } {
			set settings_file_contents [encoding convertfrom utf-8 [read_binary_file $old_settings_file]]
			if {[string length $settings_file_contents] != 0} {
				array set old_settings $settings_file_contents
				foreach s {calc_ey_from_tds show_shot_desc_on_home shot_desc_font_color describe_from_sleep date_format 
						describe_icon propagate_previous_shot_desc backup_modified_shot_files use_stars_to_rate_enjoyment 
						next_shot_DSx_home_coords last_shot_DSx_home_coords github_latest_url next_modified next_espresso_notes 
						next_bean_brand next_bean_type next_roast_date next_roast_level next_bean_notes next_grinder_model 
						next_grinder_setting next_my_name next_drinker_name} {
					if { [info exists old_settings($s)] } {
						set settings($s) $old_settings($s)
					}
				}
				
				msg -INFO "settings copied from old DSx DYE plugin"
			}
		}

		if { [file exists "[homedir]/skins/DSx/DSx_Plugins/describe_your_espresso.dsx"] } {
			file rename -force "[homedir]/skins/DSx/DSx_Plugins/describe_your_espresso.dsx" \
				"[homedir]/skins/DSx/DSx_Plugins/describe_your_espresso.off"
			msg -INFO "describe_your_espresso.dsx has been disabled"
		}
	}
}

# Defines the DYE-specific aspect styles for the default theme. These are always needed even if the current theme used is 
# another one, to have a default and to build the settings page with the default theme.
proc ::plugins::DYE::setup_default_aspects { args } {
	set theme default
	dui aspect set -theme $theme -style dsx_settings {dbutton.shape round dbutton.bwidth 384 dbutton.bheight 192 
		dbutton_symbol.pos {0.2 0.5} dbutton_symbol.font_size 37 
		dbutton_label.pos {0.65 0.5} dbutton_label.font_size 18 
		dbutton_label1.pos {0.65 0.8} dbutton_label1.font_size 16}
	
	dui aspect set -theme $theme -style dsx_midsize {dbutton.shape round dbutton.bwidth 220 dbutton.bheight 140
		dbutton_label.pos {0.5 0.5} dbutton_symbol.font_size 30}
	
	set bold_font [dui aspect get text font_family -theme default -style bold]
	dui aspect set -theme $theme -style dsx_done [list dbutton.shape round dbutton.bwidth 220 dbutton.bheight 140 \
		dbutton_label.pos {0.5 0.5} dbutton_label.font_size 20 dbutton_label.font_family $bold_font]
	
	dui aspect set -theme $theme -type symbol -style dye_main_nav_button { font_size 24 fill "#35363d" }
	
	dui aspect set -theme $theme -type text -style section_header [list font_family $bold_font font_size 20]
	
	dui aspect set -theme $theme -type dclicker -style dye_double {orient horizontal use_biginc 1 symbol chevron-double-left 
		symbol1 chevron-left symbol2 chevron-right symbol3 chevron-double-right }
	dui aspect set -theme $theme -type dclicker_symbol -style dye_double {pos {0.075 0.5} font_size 24 anchor center fill "#7f879a"} 
	dui aspect set -theme $theme -type dclicker_symbol1 -style dye_double {pos {0.275 0.5} font_size 24 anchor center fill "#7f879a"} 
	dui aspect set -theme $theme -type dclicker_symbol2 -style dye_double {pos {0.725 0.5} font_size 24 anchor center fill "#7f879a"}
	dui aspect set -theme $theme -type dclicker_symbol3 -style dye_double {pos {0.925 0.5} font_size 24 anchor center fill "#7f879a"}

	dui aspect set -theme $theme -type dclicker -style dye_single {orient horizontal use_biginc 0 symbol chevron-left symbol1 chevron-right}
	dui aspect set -theme $theme -type dclicker_symbol -style dye_single {pos {0.1 0.5} font_size 24 anchor center fill "#7f879a"} 
	dui aspect set -theme $theme -type dclicker_symbol1 -style dye_single {pos {0.9 0.5} font_size 24 anchor center fill "#7f879a"} 
	
	foreach {a aval} [dui aspect list -theme default -type dbutton -style dsx_settings -values 1 -full_aspect 1]] {
		msg -DEBUG "setup_default_aspects, $a = $aval"
	}
	::logging::flush_log
}

# Update the current shot description from the "next" description when doing a new espresso, if it has been
# modified by the user.
proc ::plugins::DYE::reset_gui_starting_espresso_enter_hook { args } { 
	msg "DYE: reset_gui_starting_espresso_enter_hook"
	set propagate $::plugins::DYE::settings(propagate_previous_shot_desc)
	
#	if { $::plugins::DYE::settings(next_modified) == 1 } {
		foreach f $::plugins::DYE::propagated_fields {
			set ::settings($f) $::plugins::DYE::settings(next_$f)
#			if { $propagate == 0 } {
#				set ::plugins::DYE::settings(next_$f) {}
#			}
		}
#	} elseif { $propagate == 0 } {
#		foreach f $::plugins::DYE::propagated_fields {
#			set ::settings($f) {}
#		}
#	}
	set ::settings(repository_links) {}	
}


# Reset the "next" description and update the current shot summary description
proc ::plugins::DYE::reset_gui_starting_espresso_leave_hook { args } {
#	msg "DYE: reset_gui_starting_espresso_leave_hook, ::android=$::android, ::undroid=$::undroid"	
#	msg "DYE: reset_gui_starting_espresso_leave - DSx settings bean_weight=$::DSx_settings(bean_weight), settings grinder_dose_weight=$::settings(grinder_dose_weight), DSx_settings live_graph_beans=$::DSx_settings(live_graph_beans)"
#	msg "DYE: reset_gui_starting_espresso_leave - settings drink_weight=$::settings(drink_weight), DSx_settings saw=$::DSx_settings(saw), settings final_desired_shot_weight=$::settings(final_desired_shot_weight), DSx_settings live_graph_weight=$::DSx_settings(live_graph_weight), DE1 scale_sensor_weight $::de1(scale_sensor_weight)"
#	msg "DYE: reset_gui_starting_espresso_leave - DYE_settings next_modified=$::plugins::DYE::settings(next_modified)"
	
#	if { $::plugins::DYE::settings(next_modified) == 1 } {
		# This can't be set on <enter> as it is blanked in reset_gui_starting_espresso
		set ::settings(espresso_notes) $::plugins::DYE::settings(next_espresso_notes)
		set ::plugins::DYE::settings(next_espresso_notes) {}
		set ::plugins::DYE::settings(next_modified) 0
#	}

	if { $::settings(skin) eq "DSx" } {
		if { [info exists ::DSx_settings(live_graph_beans)] && $::DSx_settings(live_graph_beans) > 0 } {
			set ::settings(grinder_dose_weight) $::DSx_settings(live_graph_beans)
		} elseif { [info exists ::DSx_settings(bean_weight)] && $::DSx_settings(bean_weight) > 0 } {
			set ::settings(grinder_dose_weight) [round_to_one_digits [return_zero_if_blank $::DSx_settings(bean_weight)]]
		} else {
			set ::settings(grinder_dose_weight) 0
		}
	}
	
	if { $::undroid == 1 } {		
		if { [info exists ::DSx_settings(saw)] && $::DSx_settings(saw) > 0 } {
			set ::settings(drink_weight) [round_to_one_digits $::DSx_settings(saw)] 
		} elseif { [info exists ::settings(final_desired_shot_weight)] && $::settings(final_desired_shot_weight) > 0 } {
			set ::settings(drink_weight) [round_to_one_digits $::settings(final_desired_shot_weight)]
		} else {
			set ::settings(drink_weight) 0
		}
	} else {
		if { [info exists ::DSx_settings(live_graph_weight)] && $::DSx_settings(live_graph_weight) > 0 } {
			set ::settings(drink_weight) $::DSx_settings(live_graph_weight)
		# Don't use de1(scale_sensor_weight), if bluetooth scale disconnects then this is set to the previous shot weight
#		} elseif { $::de1(scale_sensor_weight) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::de1(scale_sensor_weight)]
		} elseif { [info exists ::DSx_settings(saw)] && $::DSx_settings(saw) > 0 } {
			set ::settings(drink_weight) [round_to_one_digits $::DSx_settings(saw)] 
		} elseif { [info exists ::settings(final_desired_shot_weight)] && $::settings(final_desired_shot_weight) > 0 } {
			set ::settings(drink_weight) [round_to_one_digits $::settings(final_desired_shot_weight)]
		} else {
			set ::settings(drink_weight) 0
		}
	}

	::plugins::DYE::define_last_shot_desc
	::plugins::DYE::define_next_shot_desc
	
	# Settings already saved in reset_gui_starting_espresso, but as we have redefined them...
	::save_settings
	plugins save_settings DYE
}

# Hook executed after save_espresso_rating_to_history
# TBD: NO LONGER NEEDED? define_last_shot_desc ALREADY DONE in reset_gui_starting_espresso_leave_hook,
#	only useful if this is invoked from Insight's original Godshots/Describe Espresso pages.
proc ::plugins::DYE::save_espresso_to_history_hook { args } {
	msg "save_espresso_to_history_hook"
	::plugins::DYE::define_last_shot_desc
}


# Returns a 2 or 3-lines formatted string with the summary of a shot description.
proc ::plugins::DYE::shot_description_summary { {bean_brand {}} {bean_type {}} {roast_date {}} {grinder_model {}} \
		{grinder_setting {}} {drink_tds 0} {drink_ey 0} {espresso_enjoyment 0} {lines 2} \
		{default_if_empty "Tap to describe this shot" }} {
	set shot_desc ""

	set beans_items [list_remove_element [list $bean_brand $bean_type $roast_date] ""]
	set grinder_items [list_remove_element [list $grinder_model $grinder_setting] ""]
	set extraction_items {}
	if {$drink_tds > 0} { lappend extraction_items "[translate TDS] $drink_tds\%" }
	if {$drink_ey > 0} { lappend extraction_items "[translate EY] $drink_ey\%" }
	if {$espresso_enjoyment > 0} { lappend extraction_items "[translate Enjoyment] $espresso_enjoyment" }
	
	set each_line {}
	if {[llength $beans_items] > 0} { lappend each_line [string trim [join $beans_items " "]] }
	if {[llength $grinder_items] > 0} { lappend each_line [string trim [join $grinder_items " \@ "]] }
	if {[llength $extraction_items] > 0} { lappend each_line [string trim [join $extraction_items ", "]] }
			
	if { $lines == 1 } {
		set shot_desc [join $each_line " \- "]
	} elseif { $lines == 2 } {
		if {[llength $each_line] == 3} {
			set shot_desc "[lindex $each_line 0] \- [lindex $each_line 1]\n[lindex $each_line 2]"
		} else {
			set shot_desc [join $each_line "\n"] 
		}
	} else {
		set shot_desc [join $each_line "\n"]
	}

	if {$shot_desc eq ""} { 
		set shot_desc "\[[translate $default_if_empty]\]" 
	}  		
	return $shot_desc
}

# Returns a string with the summary description of the current (last) shot.
# Needs the { args } as this is being used in a trace add execution.
proc ::plugins::DYE::define_last_shot_desc { args } {
	if { $::plugins::DYE::settings(show_shot_desc_on_home) == 1 } {
		if { $::settings(history_saved) == 1 } {		
			set ::plugins::DYE::last_shot_desc [shot_description_summary $::settings(bean_brand) \
				$::settings(bean_type) $::settings(roast_date) $::settings(grinder_model) \
				$::settings(grinder_setting) $::settings(drink_tds) $::settings(drink_ey) \
				$::settings(espresso_enjoyment) 3]
		} else {
			set ::plugins::DYE::last_shot_desc "\[ [translate {Shot not saved to history}] \]"
		}
	} else {
		set ::plugins::DYE::last_shot_desc ""
	}
}


# Returns a string with the summary description of the shot selected on the left side of the DSx History Viewer.
# Needs the { args } as this is being used in a trace add execution.
proc ::plugins::DYE::define_past_shot_desc { args } {
	variable past_shot_desc
	variable past_shot_desc_one_line
	
	if { $::settings(skin) eq "DSx" && [info exists ::DSx_settings(past_bean_brand)] } {
		set past_shot_desc [shot_description_summary $::DSx_settings(past_bean_brand) \
			$::DSx_settings(past_bean_type) $::DSx_settings(past_roast_date) $::DSx_settings(past_grinder_model) \
			$::DSx_settings(past_grinder_setting) $::DSx_settings(past_drink_tds) $::DSx_settings(past_drink_ey) \
			$::DSx_settings(past_espresso_enjoyment)]
		
		set past_shot_desc_one_line [shot_description_summary $::DSx_settings(past_bean_brand) \
			$::DSx_settings(past_bean_type) $::DSx_settings(past_roast_date) $::DSx_settings(past_grinder_model) \
			$::DSx_settings(past_grinder_setting) $::DSx_settings(past_drink_tds) $::DSx_settings(past_drink_ey) \
			$::DSx_settings(past_espresso_enjoyment) 1 ""]
	} else {
		set past_shot_desc ""
		set past_shot_desc_one_line ""
	}
}

# Returns a string with the summary description of the shot selected on the right side of the DSx History Viewer. 
# Needs the { args } as this is being used in a trace add execution.
proc ::plugins::DYE::define_past_shot_desc2 { args } {
	variable past_shot_desc2
	variable past_shot_desc_one_line2
	
	if { $::settings(skin) eq "DSx" } {
		if {$::DSx_settings(history_godshots) == "history" && [info exists ::DSx_settings(past_bean_brand2)] } {
			set past_shot_desc2 [shot_description_summary $::DSx_settings(past_bean_brand2) \
				$::DSx_settings(past_bean_type2) $::DSx_settings(past_roast_date2) $::DSx_settings(past_grinder_model2) \
				$::DSx_settings(past_grinder_setting2) $::DSx_settings(past_drink_tds2) $::DSx_settings(past_drink_ey2) \
				$::DSx_settings(past_espresso_enjoyment2)]
			
			set past_shot_desc_one_line2 [shot_description_summary $::DSx_settings(past_bean_brand2) \
				$::DSx_settings(past_bean_type2) $::DSx_settings(past_roast_date2) $::DSx_settings(past_grinder_model2) \
				$::DSx_settings(past_grinder_setting2) $::DSx_settings(past_drink_tds2) $::DSx_settings(past_drink_ey2) \
				$::DSx_settings(past_espresso_enjoyment2) 1 ""]
		} else {
			set past_shot_desc2 ""
			set past_shot_desc_one_line2 ""
		}
	} else {
		set past_shot_desc2 ""
		set past_shot_desc_one_line2 ""
	}
}

# Returns a string with the summary description of the next shot.
# Needs the { args } as this is being used in a trace add execution.
proc ::plugins::DYE::define_next_shot_desc { args } {
	variable settings
	variable next_shot_desc
	
	if { $settings(show_shot_desc_on_home) == 1 && [info exists settings(next_bean_brand)] } {
		set desc [shot_description_summary $settings(next_bean_brand) \
			$settings(next_bean_type) $settings(next_roast_date) $settings(next_grinder_model) \
			$settings(next_grinder_setting) {} {} {} 2 "\[Tap to describe the next shot\]" ]
		if { $settings(next_modified) == 1 } { append desc " *" }
		set next_shot_desc $desc
	} else {
		set next_shot_desc ""
	}
}

proc ::plugins::DYE::return_blank_if_zero {in} {
	if {$in == 0} { return {} }
	return $in
}

# Takes a shot (if the shot contents array is provided, use it, otherwise reads from disk from the filename parameter),
# 	uploads it to visualizer, changes its repository_links settings if necessary, and persists the change to disk.
# 'clock' can have any format supported by proc get_shot_file_path, though it is ignored if contents is provided.
# Returns the repository link if successful, empty string otherwise
proc ::plugins::DYE::upload_to_visualizer_and_save { clock } {
	if { ! [plugins enabled visualizer_upload] } return
	array set arr_changes {}
	set content [::plugins::SDB::modify_shot_file $clock arr_changes 0 0]
	if { $content eq "" } return
	
	set ::plugins::visualizer_upload::settings(last_upload_shot) $clock
	set ::plugins::visualizer_upload::settings(last_upload_result) ""
	set ::plugins::visualizer_upload::settings(last_upload_id) ""
	
	set repo_link ""
	set visualizer_id [::plugins::visualizer_upload::upload $content]
	if { $visualizer_id ne "" } {
		regsub "<ID>" $::plugins::visualizer_upload::settings(visualizer_browse_url) $visualizer_id link 
		set repo_link "Visualizer $link"
		if { [string match "*$repo_link*" $content] != 1 } {
			set arr_changes(repository_links) $repo_link
			::plugins::SDB::modify_shot_file $clock arr_changes
		}
	}
	
	return $repo_link
}

# Adapted from skin_directory_graphics in utils.tcl 
proc ::plugins::DYE::plugin_directory_graphics {} {
	global screen_size_width
	global screen_size_height

	set plugindir "[plugin_directory]"

	set dir "$plugindir/DYE/${screen_size_width}x${screen_size_height}"

	if {[info exists ::rescale_images_x_ratio] == 1} {
		set dir "$plugindir/DYE/2560x1600"
	}
	
	return $dir
}

proc ::plugins::DYE::page_skeleton { page {title {}} {titlevar {}} {done_button yes} {cancel_button yes} {buttons_loc right} } {
	if { $title ne "" } {
		dui add text $page 1280 60 -text $title -tags page_title -style page_title 
	} elseif { $titlevar ne "" } {
		dui add variable $page 1280 60 -textvariable $titlevar -tags page_title -style page_title
	}

	set done_button [string is true $done_button]
	set cancel_button [string is true $cancel_button]
	set button_width [dui aspect get dbutton bwidth -style dsx_done -default 220]
	
	if { $buttons_loc eq "center" } {
		if { $done_button && $cancel_button } {
			set x_cancel [expr {1280-$button_width-75}]
			set x_done [expr {1280+75}]
		} elseif { $done_button } {
			set x_done [expr {1280-$button_width/2}]
		} elseif { $cancel_button } {
			set x_cancel [expr {1280-$button_width/2}]
		}
	} elseif { $buttons_loc eq "left" } {
		if { $done_button && $cancel_button } {
			set x_cancel 100
			set x_done 400
		} elseif { $done_button } {
			set x_done 100
		} elseif { $cancel_button } {
			set x_cancel 100
		}
	} else {
		if { $done_button && $cancel_button } {
			set x_cancel 1900
			set x_done 2200
		} elseif { $done_button } {
			set x_done 2200
		} elseif { $cancel_button } {
			set x_cancel 2200
		}
	}

	set y 1425	
	if { $cancel_button } {
		dui add dbutton $page $x_cancel $y -label [translate Cancel] -tags page_cancel -style dsx_done
	}
	if { $done_button } {
		dui add dbutton $page $x_done $y -label [translate Ok] -tags page_done -style dsx_done
	}
}

### "DESCRIBE YOUR ESPRESSO" PAGE #####################################################################################

namespace eval ::dui::pages::DYE {
	variable widgets
	array set widgets {}
	
	# Widgets in the page bind to variables in this data array, not to the actual global variables behind, so they 
	# can be changed dynamically to load and save to different shots (last, next or those selected in the left or 
	# right of the history viewer). Values are actually saved only when tapping the "Done" button.
	variable data
	array set data {
		page_painted 0
		previous_page {}
		page_title {translate {Describe your espresso}}
		# next / current / past / DSx_past / DSx_past2
		describe_which_shot {current}
		read_from_status "last"
		read_from_last_text "Read from\rlast shot" 
		read_from_prev_text "Read from\rselection"
		read_from_label {}
		shot_file {}
		clock 0
		grinder_dose_weight 0
		drink_weight 0
		bean_brand {}
		bean_type {}
		roast_date {}
		roast_level {}
		bean_notes {}
		grinder_model {}
		grinder_setting {}
		drink_tds 0
		drink_ey 0
		espresso_enjoyment 0
		espresso_notes {}
		my_name {}
		drinker_name {}
		skin {}
		beverage_type {}
		upload_to_visualizer_label {}
		repository_links {}
		warning_msg {}
	}
	#		other_equipment {}

	# src_data contains a copy of the source data when the page is loaded. So we can easily check whether something
	# has changed.
	variable src_data
	array set src_data {}
}

proc ::dui::pages::DYE::setup {} {
	variable data
	variable widgets
	set page [namespace tail [namespace current]]
	set skin $::settings(skin)	
	
	::plugins::DYE::page_skeleton $page "" page_title yes yes right

	# NAVIGATION
	set x_left_label 100; set y 40; set hspace 110
	dui add symbol $page $x_left_label $y -symbol backward -tags move_backward -style dye_main_nav_button -command yes
	
	dui add symbol $page [expr {$x_left_label+$hspace}] $y -symbol forward -tags move_forward -style dye_main_nav_button \
		-command yes
	
	dui add symbol $page [expr {$x_left_label+$hspace*2}] $y -symbol fast-forward -tags move_to_next -style dye_main_nav_button \
		-command yes

	set x_right 2360
	dui add symbol $page $x_right $y -symbol history -tags open_history_viewer -style dye_main_nav_button -command yes
	
	dui add symbol $page [expr {$x_right-$hspace}] $y -symbol search -tags search_shot -style dye_main_nav_button \
		-command yes

	dui add symbol $page [expr {$x_right-$hspace*2}] $y -symbol list -tags select_shot -style dye_main_nav_button \
		-command yes
	
	# LEFT COLUMN 
	set x_left_field 400; set width_left_field 28; set x_left_down_arrow 990
	
	# BEANS DATA
	dui add image $page $x_left_label 150 "bean_${skin}.png" -tags beans_img
	dui add text $page $x_left_field 250 -text [translate "Beans"] -tags beans_header -style section_header \
		-command beans_select
	
	dui add symbol $page [expr {$x_left_field+300}] 245 -tags beans_select -symbol sort-down -font_size 24 -command yes

	# Beans roaster / brand 
	set y 350
	dui add dcombobox $page $x_left_field $y -tags bean_brand -width $width_left_field \
		-label [translate [::plugins::SDB::field_lookup bean_brand name]] -label_pos [list $x_left_label $y] \
		-values {[::plugins::SDB::available_categories bean_brand]} \
		-page_title [translate "Select the beans roaster or brand"] -listbox_width 1000
	
	# Beans type/name
	incr y 100
	dui add dcombobox $page $x_left_field $y -tags bean_type -width $width_left_field \
		-label [translate [::plugins::SDB::field_lookup bean_type name]] -label_pos [list $x_left_label $y] \
		-values {[::plugins::SDB::available_categories bean_type]} -page_title [translate "Select the beans type"] \
		-listbox_width 1000

	# Roast date
	incr y 100
	dui add entry $page $x_left_field $y -tags roast_date -width $width_left_field \
		-label [translate [::plugins::SDB::field_lookup roast_date name]] -label_pos [list $x_left_label $y] \

	# Roast level
	incr y 100
	dui add dcombobox $page $x_left_field $y -tags roast_level -width $width_left_field \
		-label [translate [::plugins::SDB::field_lookup roast_level name]] -label_pos [list $x_left_label $y] \
		-values {[::plugins::SDB::available_categories roast_level]} -page_title [translate "Select the beans roast level"] \
		-listbox_width 800

	# Bean notes
	incr y 100
	dui add multiline_entry $page $x_left_field $y -tags bean_notes -width $width_left_field -height 3 \
		-label [translate [::plugins::SDB::field_lookup bean_notes name]] -label_pos [list $x_left_label $y]
	
	# EQUIPMENT
	set y 925

	dui add image $page $x_left_label $y "niche_${skin}.png" -tags equipment_img
	dui add text $page $x_left_field [expr {$y+130}] -text [translate "Equipment"] -style section_header
		
	# Other equipment (EXPERIMENTAL)
#	if { [info exists ::debugging] && $::debugging == 1 } {
#		dui add dbutton $page $x_left_label [expr {$y+50}] [expr {$x_left_field+400}] [expr {$y+200}] \
#			-command { say "" $::settings(sound_button_in); ::plugins::DYE::SEQ::load_page } \			
#	}
	
	# Grinder model
	incr y 240
	dui add dcombobox $page $x_left_field $y -tags grinder_model -width $width_left_field \
		-label [translate [::plugins::SDB::field_lookup grinder_model name]] -label_pos [list $x_left_label $y] \
		-values {[::plugins::SDB::available_categories grinder_model]} -callback_cmd select_grinder_model_callback \
		-page_title [translate "Select the grinder model"] -listbox_width 1200
	bind $widgets(grinder_model) <Leave> ::dui::pages::DYE::grinder_model_change
	
	# Grinder setting
	incr y 100
	dui add dcombobox $page $x_left_field $y -tags grinder_setting -width $width_left_field \
		-label [translate [::plugins::SDB::field_lookup grinder_setting name]] -label_pos [list $x_left_label $y] \
		-command grinder_setting_select
	
	# EXTRACTION
	set x_right_label 1280; set x_right_field 1525
	dui add image $page $x_right_label 150 "espresso_${skin}.png" -tags extraction_img
	dui add text $page 1550 250 -text [translate "Extraction"] -style section_header

	# Calc EY from TDS button
	dui add dbutton $page 2050 175 -tags calc_ey_from_tds -style dsx_settings -label [translate "Calc EY from TDS"] \
		-label_pos {0.5 0.3} -label1variable {$::plugins::DYE::settings(calc_ey_from_tds)} -label1_pos {0.5 0.7} \
		-command calc_ey_from_tds_click -bheight 140
	
	# Grinder Dose weight
	set y 350
	lassign [::plugins::SDB::field_lookup grinder_dose_weight {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_decimals min max default smallinc biginc
	
	dui add entry $page $x_right_field $y -tags grinder_dose_weight -width 8 -label_pos [list $x_right_label $y] \
		-label [translate [::plugins::SDB::field_lookup grinder_dose_weight name]] -data_type numeric \
		-editor_page yes -editor_page_title [translate "Edit beans dose weight (g)"] \
		-min $min -max $max -default $default -n_decimals $n_decimals -smallincrement $smallinc -bigincrement $biginc 
	bind $widgets(grinder_dose_weight) <FocusOut> "[namespace current]::calc_ey_from_tds"
	
	# Drink weight
	set offset 525
	lassign [::plugins::SDB::field_lookup drink_weight {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_decimals min max default smallinc biginc
	
	dui add entry $page [expr {$x_right_field+$offset}] $y -tags drink_weight -width 8 \
		-label [translate [::plugins::SDB::field_lookup drink_weight name]] -label_pos [list [expr {$x_right_label+$offset}] $y] \
		-data_type numeric -editor_page yes -editor_page_title [translate "Edit final drink weight (g)"]\
		-min $min -max $max -default $default -n_decimals $n_decimals -smallincrement $smallinc -bigincrement $biginc
	bind $widgets(drink_weight) <FocusOut> "[namespace current]::calc_ey_from_tds"
	
	# Total Dissolved Solids
	set x_hclicker_field 2050
	incr y 100	
	lassign [::plugins::SDB::field_lookup drink_tds {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_decimals min max default smallinc biginc
	dui add text $page $x_right_label [expr {$y+6}] -text [translate "Total Dissolved Solids (TDS)"] -tags {drink_tds_label drink_tds*}
	dui add dclicker $page [expr {$x_right_field+300}] $y -bwidth 610 -bheight 75 -tags drink_tds \
		-labelvariable {$%NS::data(drink_tds)%} -style dye_double \
		-min $min -max $max -default $default -n_decimals $n_decimals -smallincrement $smallinc -bigincrement $biginc \
		-editor_page yes -editor_page_title [translate "Edit Total Dissolved Solids (%%)"] -callback_cmd %NS::calc_ey_from_tds
	#bind $widgets(drink_tds) <FocusOut> ::dui::pages::DYE::calc_ey_from_tds
	
	# Extraction Yield
	incr y 100
	lassign [::plugins::SDB::field_lookup drink_ey {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_decimals min max default smallinc biginc
	dui add text $page $x_right_label [expr {$y+6}] -text [translate "Extraction Yield (EY)"] -tags {drink_ey_label drink_ey*}
	dui add dclicker $page [expr {$x_right_field+300}] $y -bwidth 610 -bheight 75 -tags drink_ey \
		-labelvariable {$%NS::data(drink_ey)%} -style dye_double \
		-min $min -max $max -default $default -n_decimals $n_decimals -smallincrement $smallinc -bigincrement $biginc \
		-editor_page yes -editor_page_title [translate "Edit Extraction Yield (%%)"]	

	
	# Enjoyment entry with horizontal clicker
	incr y 100
	lassign [::plugins::SDB::field_lookup espresso_enjoyment {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_decimals min max default smallinc biginc
	dui add text $page $x_right_label [expr {$y+6}] -text [translate "Enjoyment (0-100)"] -tags espresso_enjoyment_label
		
	dui add dclicker $page [expr {$x_right_field+300}] $y -bwidth 610  -bheight 75 -tags espresso_enjoyment \
		-labelvariable espresso_enjoyment -style dye_double \
		-min $min -max $max -default $default -n_decimals $n_decimals -smallincrement $smallinc -bigincrement $biginc \
		-editor_page yes -editor_page_title [translate "Edit espresso enjoyment"]	
	
	# Enjoyment stars rating (on top of the enjoyment text entry + arrows, then dinamically one or the other is hidden
	#	when the page is shown, depending on the settings)
	dui add drater $page [expr {$x_hclicker_field-250}] $y -tags espresso_enjoyment_rater -width 650 \
		-variable espresso_enjoyment -min $min -max $max -n_ratings 5 -use_halfs yes
	
	# Espresso notes
	incr y 100
	dui add multiline_entry $page $x_right_field $y -tags espresso_notes -height 5 -canvas_width 900 \
		-label [translate [::plugins::SDB::field_lookup espresso_notes name]] -label_pos [list $x_right_label $y]

	# PEOPLE
	set y 1030
	dui add image $page $x_right_label $y "people_${skin}.png" -tags people_img
	dui add text $page $x_right_field [expr {$y+140}] -text [translate "People"] -style section_header 
		
	# Barista (my_name)
	incr y 240
	dui add dcombobox $page $x_right_field $y -tags my_name -canvas_width 325 \
		-label [translate [::plugins::SDB::field_lookup my_name name]] -label_pos [list $x_right_label $y] \
		-values {[::plugins::SDB::available_categories my_name]} -page_title [translate "Select the barista"] \
		-listbox_width 800
	
	# Drinker name
	dui add dcombobox $page [expr {$x_right_field+575}] $y -tags drinker_name -canvas_width 325 \
		-label [translate [::plugins::SDB::field_lookup drinker_name name]] -label_pos [list [expr {$x_right_label+675}] $y] \
		-values {[::plugins::SDB::available_categories drinker_name]} -page_title [translate "Select the coffee drinker"] \
		-listbox_width 800
	
	# BOTTOM BUTTONS	
	# Clear shot data (only clears "propagated" fields)
	set x 100; set y 1385
	dui add dbutton $page $x $y -tags clear_shot_data -style dsx_settings -symbol eraser -label [translate "Clear shot\rdata"]	

	# Recover "propagated" fields from a previous shot
	set x [expr {$x+[dui aspect get dbutton bwidth -style dsx_settings -default 400]+75}]
	set data(read_from_label) [translate $data(read_from_last_text)]
	dui add dbutton $page $x $y -tags read_from -style dsx_settings -symbol file-import -labelvariable read_from_label

	# Upload to Miha's Visualizer button
	set x [expr {$x+[dui aspect get dbutton bwidth -style dsx_settings -default 400]+75}]
	set data(upload_to_visualizer_label) [translate "Upload to\rVisualizer"]
	dui add dbutton $page $x $y -tags upload_to_visualizer -style dsx_settings -symbol file-upload \
		-labelvariable upload_to_visualizer_label -initial_state hidden
	
	dui add variable $page 2420 1380 -tags warning_msg -style remark -anchor e -justify right -initial_state hidden
}

# 'which_shot' can be either a clock value matching a past shot clock, or any of 'current', 'next', 'DSx_past' or 
#	'DSx_past2'.
proc ::dui::pages::DYE::load { page_to_hide page_to_show {which_shot current} } {
	variable data
	# If reloading the page (to show a different shot data), remember the original page we came from
	if { $page_to_hide ne "DYE" } {
		set data(previous_page) $page_to_hide
	}
	
	if { [info exists ::settings(espresso_clock)] && $::settings(espresso_clock) ne "" && $::settings(espresso_clock) > 0} {
		set current_clock $::settings(espresso_clock)
	} else {	
		set current_clock 0
	}
	
	set data(describe_which_shot) $which_shot
	if { [string is integer $which_shot] && $which_shot > 0 } {
		if { $which_shot == $current_clock } {
			set data(describe_which_shot) "current"
		} else {
			set data(describe_which_shot) "past"
		}
		set data(clock) $which_shot
	} elseif { $which_shot eq "current" } { 
		if { $current_clock == 0 } {
			info_page [translate "Last shot is not available to describe"] [translate Ok]
			return
		} else {
			set data(clock) $current_clock
		}
	} elseif { $which_shot eq "next" } {
		set data(clock) {}
	} elseif { [string range $which_shot 0 2] eq "DSx" } {
		if { $::settings(skin) eq "DSx" } {
			set data(describe_which_shot) $which_shot
			if { $which_shot eq "DSx_past" } {
				if { [info exists ::DSx_settings(past_clock)] } {
					set data(clock) $::DSx_settings(past_clock)	
				} else {
					msg -ERROR "which_shot='$which_shot' but DSx_settings(past_clock) is undefined"
					info_page [translate "DSx History Viewer past shot is undefined"] [translate Ok]
					return 0					
				}
			} elseif { $which_shot eq "DSx_past2" } {
				if { [info exists ::DSx_settings(past_clock2)] } {
					set data(clock) $::DSx_settings(past_clock2)	
				} else {
					msg -ERROR "which_shot='$which_shot' but DSx_settings(past_clock2) is undefined"
					info_page [translate "DSx History Viewer past shot 2 is undefined"] [translate Ok]
					return 0
				}
			}
		} else {
			msg -ERROR "Can't use which shot '$which_shot' when not using the DSx skin"
			info_page [translate "Shot type '$which_shot' requires skin DSx"] [translate Ok]
			return 0
		}
	} else {
		msg -ERROR "Unrecognized value of which_shot: '$which_shot'"
		info_page "[translate {Unrecognized shot type to show in 'Describe Your Espresso'}]: '$which_shot'" [translate Ok]
		return 0
	}
	
	if { [load_description] == 0 } {
		info_page [translate "The requested shot description for '$which_shot' is not available"] [translate Ok]
		return 0
	}
	
	return 1
}

# This is added to the page context actions, so automatically executed every time (after) the page is shown.
proc ::dui::pages::DYE::show { page_to_hide page_to_show } {
	variable widgets
	variable data
	
	set use_stars $::plugins::DYE::settings(use_stars_to_rate_enjoyment)
	dui item show_or_hide $use_stars $page_to_show espresso_enjoyment_rater*
	dui item show_or_hide [expr {!$use_stars}] $page_to_show espresso_enjoyment*

	set is_not_next [expr {$data(describe_which_shot) ne "next"}]
	dui item enable_or_disable $is_not_next $page_to_show {move_forward move_to_next grinder_dose_weight* 
		drink_weight* drink_tds* drink_ey* espresso_enjoyment* espresso_enjoyment_rater* espresso_enjoyment_label}
	
	if { $is_not_next } {
		set previous_shot [::plugins::SDB::previous_shot $data(clock)]
		dui item enable_or_disable [expr {$previous_shot ne ""}] $page_to_show "move_backward"
		
		if { $use_stars } {
			dui item enable $page_to_show espresso_enjoyment_rater*
			# Force redrawing the stars after showing/hiding
			set data(espresso_enjoyment) $data(espresso_enjoyment)
		}
		
	}
	
	dui item relocate_text_wrt $page_to_show beans_select beans_header e 25 -8 w
	grinder_model_change
	calc_ey_from_tds
	update_visualizer_button 0
}
	
proc ::dui::pages::DYE::unload_page {} {
	variable data

	if { $data(previous_page) eq "sleep" } {
		set_next_page off off
		set ::current_espresso_page "off"
		start_sleep				
	} elseif { $data(previous_page) ne "" } {
		dui page load $data(previous_page)
	} else {
		dui page load off
	}	
}	

proc ::dui::pages::DYE::move_backward {} {
	variable data
	if { [ask_to_save_if_needed] eq "cancel" } return

	if { $data(describe_which_shot) eq "next" } {
		dui page load DYE current -reload yes		
	} else {
		set previous_clock [::plugins::SDB::previous_shot $data(clock)]
		if { $previous_clock ne "" && $previous_clock > 0 } {
			dui page load DYE $previous_clock -reload yes
		}
	}
}

proc ::dui::pages::DYE::move_forward {} {
	variable data
	
	if { $data(describe_which_shot) eq "next" } return
	if { [ask_to_save_if_needed] eq "cancel" } return
	
	if { $data(describe_which_shot) eq "current" || $data(clock) == $::settings(espresso_clock) } {
		dui page load DYE next -reload yes
	} else {		
		set next_clock [::plugins::SDB::next_shot $data(clock)]
		if { $next_clock ne "" && $next_clock > 0} {
			dui page load DYE $next_clock -reload yes
		}
	}
}

proc ::dui::pages::DYE::move_to_next {} {
	variable data
	if { $data(describe_which_shot) eq "next" } return	
	if { [ask_to_save_if_needed] eq "cancel" } return
	
	dui page load DYE next -reload yes
}

proc ::dui::pages::DYE::search_shot {} {
	set answer [ask_to_save_if_needed]
	if { $answer eq "cancel" } return

	dui page load DYE_fsh -page_title [translate "Select the shot to describe"] -callback_cmd ::dui::pages::DYE::search_shot_callback
}

proc ::dui::pages::DYE::search_shot_callback { selected_shots matched_shots } {
	variable data
	if { [llength $selected_shots] == 0 } { 
		dui page show DYE
	} else {
		set previous_page $data(previous_page)
		dui page load DYE [lindex $selected_shots 0]
		set data(previous_page) $previous_page
	}
}

proc ::dui::pages::DYE::select_shot {} {
	set answer [ask_to_save_if_needed]
	if { $answer eq "cancel" } return
	
	array set shots [::plugins::SDB::shots "clock shot_desc" 1 {} 500]
	dui page load dui_item_selector {} $shots(shot_desc) -values_ids $shots(clock) \
		-page_title [translate "Select the shot to describe"] \
		-callback_cmd [namespace current]::select_shot_callback -listbox_width 2300
}

proc ::dui::pages::DYE::select_shot_callback { shot_desc shot_id args } {
	variable data

	if { [llength $shot_id] == 0 } { 
		dui page show DYE
	} else {
		set previous_page $data(previous_page)
		dui page load DYE [lindex $shot_id 0]
		set data(previous_page) $previous_page
	}
}

proc ::dui::pages::DYE::open_history_viewer {} {
	set answer [ask_to_save_if_needed]
	if { $answer eq "cancel" } return
	
	if { $::settings(skin) eq "DSx" } {
		::history_prep
	} else {
		history_viewer open -callback_cmd ::dui::pages::DYE::history_viewer_callback
	}
}

proc ::dui::pages::DYE::history_viewer_callback { left_clock right_clock } {
	variable data
	
	if { $left_clock eq "" } { 
		dui page show DYE
	} else {
		set previous_page $data(previous_page)
		dui page load DYE [lindex $left_clock 0]
		set data(previous_page) $previous_page
	}
}

proc ::dui::pages::DYE::beans_select {} {
	variable data
	say "" $::settings(sound_button_in)
	
	set selected [string trim "$data(bean_brand) $data(bean_type) $data(roast_date)"]
	regsub -all " +" $selected " " selected

	dui page load dui_item_selector {} [::plugins::SDB::available_categories bean_desc] \
		-page_title "Select the beans batch" -selected $selected -callback_cmd [namespace current]::select_beans_callback \
		-listbox_width 1700
}

# Callback procedure returning control from the item_selection page to the describe_espresso page, to select the 
# full beans definition item from the list of previously entered values. 
proc ::dui::pages::DYE::select_beans_callback { clock bean_desc item_type } {
	variable data
	dui page show [namespace tail [namespace current]]
		
	if { $bean_desc ne "" } {
		set db ::plugins::SDB::get_db
		db eval {SELECT bean_brand,bean_type,roast_date,roast_level,bean_notes FROM V_shot \
				WHERE clock=(SELECT MAX(clock) FROM V_shot WHERE bean_desc=$bean_desc)} {
			set data(bean_brand) $bean_brand
			set data(bean_type) $bean_type
			set data(roast_date) $roast_date
			set data(roast_level) $roast_level
			set data(bean_notes) $bean_notes
		}
	}
}

# Callback procedure returning control from the item_selection page to the describe_espresso page when a grinder
#	model is selected from the list. We need a callback proc, unlike with other fields, because we need to invoke
#	'grinder_model_change'.
proc ::dui::pages::DYE::select_grinder_model_callback { value id type } {
	variable data
	dui page show [namespace tail [namespace current]]
	
	if { $value ne "" } {
		set data(grinder_model) $value
		grinder_model_change
	}
}

proc ::dui::pages::DYE::grinder_setting_select { variable values args} {	
	variable data
	dui sound make button_in
	if { $data(grinder_model) eq "" } return

	dui page load dui_item_selector ::dui::pages::DYE::data(grinder_setting) \
		[::plugins::SDB::available_categories grinder_setting \
		-filter " grinder_model=[::plugins::SDB::string2sql $data(grinder_model)]"] \
		-page_title [translate "Select the grinder setting"] -selected $data(grinder_setting) -listbox_width 700
}

proc ::dui::pages::DYE::grinder_model_change {} {
	variable data
	
	dui item enable_or_disable [expr {$data(grinder_model) ne ""}] [namespace tail [namespace current]] grinder_setting-dda
}

proc ::dui::pages::DYE::clear_shot_data {} {
	variable data
	say "clear" $::settings(sound_button_in)
	foreach f $::plugins::DYE::propagated_fields {
		set data($f) {}
	}
	set data(espresso_notes) {}
#	if { $data(describe_which_shot) eq "next" } {
#		set ::plugins::DYE::settings(next_modified) 1
#	}
}

proc ::dui::pages::DYE::read_from {} {
	variable data
	say "read" $::settings(sound_button_in)

	# Bring descriptive data from last shot (in-memory if editing the next description), if not using
	# the last shot use the DB to get it back.
	if { ![info exists data(clock) ]|| $data(clock) == 0 || $data(clock) eq {} } {			
		set filter "clock < [clock seconds]"
	} else {
		set filter "clock < $data(clock)"
	}
	set sql_conditions {}
	foreach f $::plugins::DYE::propagated_fields {
		lappend sql_conditions "LENGTH(TRIM(COALESCE($f,'')))>0"
	}
	
	if { $data(read_from_status) eq "prev" } {
		array set shots [::plugins::SDB::shots "clock shot_desc" 1 "$filter AND ([join $sql_conditions { OR }])" 500]
		dui page load dui_item_selector {} $shots(shot_desc) -values_ids $shots(clock) \
			-page_title [translate "Select the shot to read the data from"] \
			-callback_cmd [namespace current]::select_read_from_shot_callback -listbox_width 2300
		set data(read_from_status) "last"
	} else {
		array set last_shot [::plugins::SDB::shots "$::plugins::DYE::propagated_fields" 1 \
			"$filter AND ([join $sql_conditions { OR }])" 1]
		foreach f [array names last_shot] {
			set data($f) [lindex $last_shot($f) 0]
		}
				
		set data(read_from_status) "prev"
	}
	
	set data(read_from_label) [translate $data(read_from_${data(read_from_status)}_text)]
#	if { $data(describe_which_shot) eq "next" } {
#		set DYE::settings(next_modified) 1
#	}
}

# Callback procedure returning control from the item_selection page to the describe_espresso page, to select a 
# source shot to be used for next shot propagation values. 
proc ::dui::pages::DYE::select_read_from_shot_callback { shot_desc shot_clock item_type args } {
	variable data
	dui page show [namespace tail [namespace current]]
	
	if { $shot_clock ne "" } {
		array set shot [::plugins::SDB::shots "$::plugins::DYE::propagated_fields" 1 "clock=$shot_clock" 1]
		foreach f [array names shot] {
			set data($f) [lindex $shot($f) 0]
		}
	}
}

# Opens the last shot, the shot on the left of the history viewer, or the shot on the right of the history
# 	viewer, and writes all relevant DYE fields to the ::dui::pages::DYE page variables.
# Returns 1 if successful, 0 otherwise.
proc ::dui::pages::DYE::load_description {} {
	variable widgets
	variable data
	variable src_data
	
#	foreach f {grinder_dose_weight drink_weight drink_tds drink_ey espresso_enjoyment} {
#		$widgets(${f}) configure -state normal
#	}
	
	set data(read_from_label) [translate $data(read_from_${data(read_from_status)}_text)]
	
	if { $data(describe_which_shot) eq "DSx_past" } {
#		if { ! [info exists ::DSx_settings(past_clock)] } { return 0 }
#		set data(clock) $::DSx_settings(past_clock)
						
		set data(shot_file) $::DSx_settings(past_shot_file)
		set data(page_title) "Describe past espresso: $::DSx_settings(shot_date_time)"

		foreach f $::plugins::DYE::desc_text_fields {
			if { [info exists ::DSx_settings(past_$f)] } {
				set data($f) [string trim $::DSx_settings(past_$f)]
			} else {
				set data($f) {}
			}
		}
		foreach f $::plugins::DYE::desc_numeric_fields {
			if { [info exists ::DSx_settings(past_$f)] } {
				set data($f) [::plugins::DYE::return_blank_if_zero $::DSx_settings(past_$f)]
			} else {
				set data($f) {}
			}
		}
		
		# Bean and Drink weights past variable names don't follow the past_* naming convention, so we have to handle
		# them differently
		if { [return_zero_if_blank [ifexists ::DSx_settings(past_bean_weight) 0]] > 1 } {
			set data(grinder_dose_weight) $::DSx_settings(past_bean_weight)
		} else {
			set data(grinder_dose_weight) {}
		}
		
		if { [return_zero_if_blank [ifexists ::DSx_settings(drink_weight) 0]] > 1 } {
			set data(drink_weight) $::DSx_settings(drink_weight) 
#		} elseif { $::DSx_settings(past_final_desired_shot_weight) > 0 } {
#			set data(drink_weight) $::DSx_settings(past_final_desired_shot_weight)
		} else {
			set data(drink_weight) {}
		}

#		if { $data(drink_weight) eq "" && $::DSx_settings(past_final_desired_shot_weight) > 0 } {
#			set data(drink_weight) $::DSx_settings(past_final_desired_shot_weight)
#		}
	} elseif { $data(describe_which_shot) eq "DSx_past2" } {
#		if { ! [info exists ::DSx_settings(past_clock2)] } { return 0 }
#		set data(clock) $::DSx_settings(past_clock2)
		
		set data(shot_file) $::DSx_settings(past_shot_file2)
		set data(page_title) "Describe past espresso: $::DSx_settings(shot_date_time2)"
		
		foreach f $::plugins::DYE::desc_text_fields {
			if { [info exists ::DSx_settings(past_${f}2)] } {
				set data($f) [string trim $::DSx_settings(past_${f}2)]
			} else {
				set data($f) {}
			}
		}
		foreach f $::plugins::DYE::desc_numeric_fields {
			if { [info exists ::DSx_settings(past_${f}2)] } {
				set data($f) [::plugins::DYE::return_blank_if_zero $::DSx_settings(past_${f}2)]
			} else {
				set data($f) {}
			}
		}

		# Bean and Drink weights past variable names don't follow the past_* naming convention, so we have to handle
		# them differently
		if { [return_zero_if_blank [ifexists ::DSx_settings(past_bean_weight2) 0]] > 1 } {
			set data(grinder_dose_weight) $::DSx_settings(past_bean_weight2)
		} else {
			set data(grinder_dose_weight) {}
		}
		
		if { [return_zero_if_blank [ifexists ::DSx_settings(drink_weight2) 0]] > 1} {
			set data(drink_weight) $::DSx_settings(drink_weight2) 
#		} elseif { $::DSx_settings(past_final_desired_shot_weight2) > 0 } {
#			set data(drink_weight) $::DSx_settings(past_final_desired_shot_weight2)
		} else {
			set data(drink_weight) {}
		}
		
#		if { $data(drink_weight) eq "" && $::DSx_settings(past_final_desired_shot_weight) > 0 } {
#			set data(drink_weight) $::DSx_settings(past_final_desired_shot_weight)
#		}
		
	} elseif { $data(describe_which_shot) eq "next" } {
		#set data(clock) {}
		set data(shot_file) {}
		set data(page_title) "Describe your next espresso"

		foreach f {grinder_dose_weight drink_weight drink_tds drink_ey espresso_enjoyment} {
			set data($f) {}
#			$widgets($f) configure -state disabled
		}

#		foreach f {bean_brand bean_type roast_date roast_level bean_notes grinder_model grinder_setting \
#				other_equipment espresso_notes my_name drinker_name} 		
		foreach f {bean_brand bean_type roast_date roast_level bean_notes grinder_model grinder_setting \
				espresso_notes my_name drinker_name} {
			set data($f) [string trim $::plugins::DYE::settings(next_$f)]
		}
		
		set data(grinder_dose_weight) {}
		set data(drink_weight) {}
		set data(repository_links) {}
	} elseif { $data(describe_which_shot) eq "past" } {
		array set shot [::plugins::SDB::load_shot $data(clock)]
		if { [array size shot] == 0 } { return 0 }
		# What for?
		set data(shot_file) [::plugins::SDB::get_shot_file_path $data(clock)]
		set data(page_title) "Describe past espresso: [formatted_shot_date]"
		
		foreach f "$::plugins::DYE::desc_text_fields $::plugins::DYE::desc_numeric_fields" {
			set data($f) $shot($f) 
		}
		
	} elseif { $data(describe_which_shot) eq "current" } {
		#if { ! [info exists ::settings(espresso_clock)] } { return 0 }
		# Assume $data(describe_which_shot) eq "current"
		#set data(clock) $::settings(espresso_clock)
		set data(shot_file) [::plugins::SDB::get_shot_file_path $::settings(espresso_clock)]
		#"[homedir]/history/[clock format $::settings(espresso_clock) -format $::plugins::DYE::filename_clock_format].shot"
		set data(page_title) "Describe last espresso: [::dui::pages::DYE::last_shot_date]"
		
		foreach f $::plugins::DYE::desc_text_fields {
			if { [info exists ::settings($f)] } {
				set data($f) [string trim $::settings($f)]
			} else {
				set data($f) {}
			}
		}		
		foreach f $::plugins::DYE::desc_numeric_fields {
			if { [info exists ::settings($f)] } {
				set data($f) [::plugins::DYE::return_blank_if_zero $::settings($f)]
			} else {
				set data($f) {}
			}
		}
		
	}
		
	array set src_data {}
	foreach fn "$::plugins::DYE::desc_numeric_fields $::plugins::DYE::desc_text_fields" {
		set src_data($fn) $data($fn)
	}
	
	return 1
}


# Saves the local variables from the Describe Espresso page into the target variables depending on which
#	description we're editing (last shot, left on the history viewer, or right in the history viewer),
#	and saves the modified data in the correct history .shot file.
proc ::dui::pages::DYE::save_description {} {
	variable data
	variable src_data
	set needs_saving 0
	array set new_settings {}
	
	# $::settings(espresso_clock) may not be defined on a new install!
	set last_clock [ifexists ::settings(espresso_clock) 0]
	
	set is_past_edition_of_current 0
	if { $::settings(skin) eq "DSx" } {
		if { ($data(describe_which_shot) eq "DSx_past" && $::DSx_settings(past_clock) == $last_clock) || \
				($data(describe_which_shot) eq "DSx_past2" && $::DSx_settings(past_clock2) == $last_clock) } {
			set is_past_edition_of_current 1
		}
	}
	
	if { $::settings(skin) eq "DSx" && ($data(describe_which_shot) eq "DSx_past" || $data(describe_which_shot) eq "DSx_past2")} {
		if { $data(describe_which_shot) eq "DSx_past" || ($data(describe_which_shot) eq "DSx_past2" && \
				$::DSx_settings(past_clock) == $::DSx_settings(past_clock2)) } {
			set clock $::DSx_settings(past_clock) 
			foreach f $::plugins::DYE::desc_numeric_fields {
				if { ![info exists ::DSx_settings(past_$f)] || $::DSx_settings(past_$f) ne [return_zero_if_blank $data($f)] } {
					set ::DSx_settings(past_$f) [return_zero_if_blank $data($f)]
					set new_settings($f) [return_zero_if_blank $data($f)] 
					set needs_saving 1
					
					# These two don't follow the above var naming convention
					# These two don't follow the above var naming convention
					if { $f eq "grinder_dose_weight" && [return_zero_if_blank $data($f)] > 0 } {
						set ::DSx_settings(past_bean_weight) [round_to_one_digits $data(grinder_dose_weight)]
					}
					if { $f eq "drink_weight" && [return_zero_if_blank $data($f)] > 0 } {
						set ::DSx_settings(drink_weight) [round_to_one_digits $data(drink_weight)]
					}
				}
			}
			foreach f $::plugins::DYE::desc_text_fields {
				if { ![info exists ::DSx_settings(past_$f)] || $::DSx_settings(past_$f) ne $data($f) } {
					set ::DSx_settings(past_$f) [string trim $data($f)]
					set new_settings($f) $data($f)
					set needs_saving 1
				}
			}

			if { $needs_saving == 1 } { 
				::plugins::DYE::define_past_shot_desc 
				if { $::DSx_settings(past_clock) == $::DSx_settings(past_clock2) } {
					::plugins::DYE::define_past_shot_desc2
				}
				::save_DSx_settings
			}
		} 
		
		if { $data(describe_which_shot) eq "DSx_past2" || ($data(describe_which_shot) eq "DSx_past" && \
				$::DSx_settings(past_clock) == $::DSx_settings(past_clock2)) } {
			set clock $::DSx_settings(past_clock2) 
			foreach f $::plugins::DYE::desc_numeric_fields {
				if { ![info exists ::DSx_settings(past_${f}2)] || \
						$::DSx_settings(past_${f}2) ne [return_zero_if_blank $data($f)] } {
					set ::DSx_settings(past_${f}2) [return_zero_if_blank $data($f)]
					set new_settings($f) [return_zero_if_blank $data($f)]
					set needs_saving 1
					
					# These two don't follow the above var naming convention
					if { $f eq "grinder_dose_weight" && [return_zero_if_blank $data($f)] > 0 } {
						set ::DSx_settings(past_bean_weight2) [round_to_one_digits $data(grinder_dose_weight)]
					}
					if { $f eq "drink_weight" && [return_zero_if_blank $data($f)] > 0 } {
						set ::DSx_settings(drink_weight2) [round_to_one_digits $data(drink_weight)]
					}
				}
			}
			foreach f $::plugins::DYE::desc_text_fields {
				if { ![info exists ::DSx_settings(past_${f}2)] || $::DSx_settings(past_${f}2) ne $data($f) } {
					set ::DSx_settings(past_${f}2) $data($f)
					set new_settings($f) [string trim $data($f)]
					set needs_saving 1
				}
			}

			if { $needs_saving == 1 } { 
				::plugins::DYE::define_past_shot_desc2 
				if { $::DSx_settings(past_clock) == $::DSx_settings(past_clock2) } {
					::plugins::DYE::define_past_shot_desc
				}
			}
		}

		if { $needs_saving == 0 } { return 1 }

		if { $is_past_edition_of_current == 0 } {
			::plugins::SDB::modify_shot_file $data(shot_file) new_settings
			
			if { $::plugins::SDB::settings(db_persist_desc) == 1 } {
				set new_settings(file_modification_date) [file mtime $data(shot_file)]
				::plugins::SDB::update_shot_description $clock new_settings
			}
			
			::save_DSx_settings
			msg "DYE: Save past espresso to history"
		}
		
		return 1
	} 
	
	if { $data(describe_which_shot) eq "current" || $is_past_edition_of_current == 1 } {
		# With the new events system from v1.35 the last shot file may take a few seconds to save to disk
		if { $data(shot_file) eq "" } {
			set data(shot_file) [::plugins::SDB::get_shot_file_path $::settings(espresso_clock)]
			if { $data(shot_file) eq "" } {
				set data(warning_msg) [translate "Shot file not saved to history yet. Please wait a few seconds and retry"]
				dui item show DYE warning_msg
				after 3000 { dui item hide DYE warning_msg }
				return 0
			}
		}
		
		foreach f $::plugins::DYE::desc_numeric_fields {
			if { ![info exists ::settings($f)] || $::settings($f) ne [return_zero_if_blank $data($f)] } {
				set ::settings($f) [return_zero_if_blank $data($f)]
				set new_settings($f) [return_zero_if_blank $data($f)]
				set needs_saving 1
			}			
		}
		foreach f $::plugins::DYE::desc_text_fields {
			if { ![info exists ::settings($f)] || $::settings($f) ne $data($f) } {
				set ::settings($f) [string trim $data($f)]
				set new_settings($f) [string trim $data($f)]
				set needs_saving 1

				if { $::plugins::DYE::settings(next_modified) == 0 && [lsearch $::plugins::DYE::propagated_fields $f] > -1 && \
						$::plugins::DYE::settings(propagate_previous_shot_desc) == 1 } {
					set ::plugins::DYE::settings(next_$f) [string trim $data($f)]
				}
			}
		}

		set needs_save_DSx_settings 0
		if { $::settings(skin) eq "DSx" } {
			if { [return_zero_if_blank $data(grinder_dose_weight)] > 0 && \
					[ifexists ::DSx_settings(live_graph_beans) {}] ne $data(grinder_dose_weight)} {
				set ::DSx_settings(live_graph_beans) [round_to_one_digits $data(grinder_dose_weight)]
				set needs_save_DSx_settings 1
			}
			if { [return_zero_if_blank $data(drink_weight)] > 0 && \
					[ifexists ::DSx_settings(live_graph_weight) {}] ne $data(drink_weight) } {
				set ::DSx_settings(live_graph_weight) [round_to_one_digits $data(drink_weight)]
				set needs_save_DSx_settings 1
			}
		}
		
#		# TBD THIS IS TO UPDATE THE TEXT WITH THE WEIGHTS AND RATIOS BELOW THE LAST SHOT CHART IN THE MAIN PAGE,
#		# 	BUT THE TEXT IS NOT BEING UPDATED, UNLIKE IN THE HISTORY VIEWER.
#		if { [return_zero_if_blank $data(grinder_dose_weight)] > 0 && \
#				$data(grinder_dose_weight) != $::settings(DSx_bean_weight) } {
#			set ::settings(DSx_bean_weight) [round_to_one_digits $data(grinder_dose_weight)]
#		}
		
		if { $needs_save_DSx_settings } {
			::save_DSx_settings
		}
		if { $needs_saving == 1 } {
			::save_settings
			plugins save_settings DYE
			
			::plugins::SDB::modify_shot_file $data(shot_file) new_settings
			if { $::plugins::SDB::settings(db_persist_desc) == 1 } {
				set new_settings(file_modification_date) [file mtime $data(shot_file)]
				::plugins::SDB::update_shot_description $data(clock) new_settings
			}
			
			# OLD (before v1.11), wrongly stored profile changes for next shot made after making the shot but before editing last shot description.
			#::save_espresso_rating_to_history
			::plugins::DYE::define_last_shot_desc
			::plugins::DYE::define_next_shot_desc
		}
	
	} elseif { $data(describe_which_shot) eq "past" } {
		foreach f $::plugins::DYE::desc_numeric_fields {
			if { [return_zero_if_blank $data($f)] ne [return_zero_if_blank $src_data($f)] } {
				set new_settings($f) [return_zero_if_blank $data($f)]
				set needs_saving 1
			}			
		}
		foreach f $::plugins::DYE::desc_text_fields {
			if { $data($f) ne $src_data($f) } {
				set new_settings($f) [string trim $data($f)]
				set needs_saving 1
			}
		}
		
		if { $needs_saving } {
			::plugins::SDB::modify_shot_file $data(shot_file) new_settings
			if { $::plugins::SDB::settings(db_persist_desc) == 1 } {
				set new_settings(file_modification_date) [file mtime $data(shot_file)]
				::plugins::SDB::update_shot_description $data(clock) new_settings
			}
		}
	} elseif { $data(describe_which_shot) eq "next" } {
#		foreach f {bean_brand bean_type roast_date roast_level bean_notes grinder_model grinder_setting \
#				other_equipment espresso_notes my_name drinker_name} 		
		foreach f {bean_brand bean_type roast_date roast_level bean_notes grinder_model grinder_setting \
				espresso_notes my_name drinker_name} {
			if { $::plugins::DYE::settings(next_$f) ne $data($f) } {
				set ::plugins::DYE::settings(next_$f) [string trim $data($f)]
				set needs_saving 1
			}			
		}

		if { $needs_saving == 1 } {
			set ::plugins::DYE::settings(next_modified) 1
			::plugins::DYE::define_next_shot_desc
			plugins save_settings DYE
		}		
	}
	
	return 1
}

# A clone of DSx last_shot_date, but uses settings(espresso_clock) if DSx_settings(live_graph_time) is not
# available (e.g. if DSx_settings.tdb were manually removed). Also will allow future skin-independence.
proc ::dui::pages::DYE::last_shot_date {} {
	if { [info exists ::DSx_settings(live_graph_time)] } {
		return [::last_shot_date]
	} elseif { [info exists ::settings(espresso_clock)] } {
		set last_shot_clock $::settings(espresso_clock)
		set date [clock format $last_shot_clock -format {%a %d %b}]
		if {$::settings(enable_ampm) == 0} {
			set a [clock format $last_shot_clock -format {%H}]
			set b [clock format $last_shot_clock -format {:%M}]
			set c $a
		} else {
			set a [clock format $last_shot_clock -format {%I}]
			set b [clock format $last_shot_clock -format {:%M}]
			set c $a
			regsub {^[0]} $c {\1} c
		}
		if {[ifexists ::settings(enable_ampm) 1] == 1} {
			set pm [clock format $last_shot_clock -format %P]
		} else {
			set pm ""
		}
		return "$date $c$b$pm"
	} else {
		return ""
	}
}

# Adapted from Damian's DSx last_shot_date. 
proc ::dui::pages::DYE::formatted_shot_date {} {
	variable data
	set shot_clock $data(clock)
	if { $shot_clock eq "" || $shot_clock <= 0 } {
		return ""
	}
	
	set date [clock format $shot_clock -format {%a %d %b}]
	if { [ifexists ::settings(enable_ampm) 0] == 0} {
		set a [clock format $shot_clock -format {%H}]
		set b [clock format $shot_clock -format {:%M}]
		set c $a
	} else {
		set a [clock format $shot_clock -format {%I}]
		set b [clock format $shot_clock -format {:%M}]
		set c $a
		regsub {^[0]} $c {\1} c
	}
	if { $::settings(enable_ampm) == 1 } {
		set pm [clock format $shot_clock -format %P]
	} else {
		set pm ""
	}
	return "$date $c$b$pm"
}

# Return 1 if some data has changed in the form.
proc ::dui::pages::DYE::needs_saving { } {
	variable data
	variable src_data
	
	foreach fn $::plugins::DYE::desc_text_fields {
		if { $data($fn) ne $src_data($fn) } {
			return 1
		}
	}	
	foreach fn $::plugins::DYE::desc_numeric_fields {
		if { [return_zero_if_blank $data($fn)] != [return_zero_if_blank $src_data($fn)] } {
			return 1
		}
	}
	return 0
}

proc ::dui::pages::DYE::calc_ey_from_tds_click {} {
	say "" $::settings(sound_button_in)
	if { $::plugins::DYE::settings(calc_ey_from_tds) eq "on" } {
		set ::plugins::DYE::settings(calc_ey_from_tds) off
	} else { 
		set ::plugins::DYE::settings(calc_ey_from_tds) on 
		::dui::pages::DYE::calc_ey_from_tds
	}		
}

# Calculates the Extraction Yield % to be shown in the Describe Espresso page from the user-entered
# Total Dissolved Solids %, the dose and the drink weight. Uses standard formula.
proc ::dui::pages::DYE::calc_ey_from_tds  {} {
	variable data 
	
	if { $::plugins::DYE::settings(calc_ey_from_tds) eq "on" } {		
		if { $data(drink_weight) > 0 && $data(grinder_dose_weight) > 0 && $data(drink_tds) > 0 } {
			set data(drink_ey) [round_to_two_digits [expr {$data(drink_weight) * $data(drink_tds) / \
				$data(grinder_dose_weight)}]]
		} else {
			set data(drink_ey) {}
		}
	}
}

proc ::dui::pages::DYE::upload_to_visualizer {} {
	variable data
	variable widgets
	set remark_color [dui aspect get text fill -style remark -default orange]
#	if { $::dui::pages::DYE::data(repository_links) ne {} } {
#		say [translate "browsing"] $::settings(sound_button_in)
#		if { [llength $::dui::pages::DYE::data(repository_links)] > 1 } {
#			web_browser [lindex $::dui::pages::DYE::data(repository_links) 1]
#		}
#		return
#	}
	
	say "" $::settings(sound_button_in)
	if { $::android == 1 && [borg networkinfo] eq "none" } {
		set data(upload_to_visualizer_label) [translate "Failed\rNo wifi"]
#		set ::plugins::DYE::settings(last_visualizer_result) "[translate {Upload failed}]: [translate {No wifi}]"
		dui item config $widgets(upload_to_visualizer-lbl) -fill $remark_color 
		#update
		after 3000 ::dui::pages::DYE::update_visualizer_button
		dui sound make button_out
		return
	}
	
	# Ensure latest values are in the shot file in case they have changed
	if { [::dui::pages::DYE::needs_saving] } {
		set answer [ask_to_save_if_needed]
		if { $answer eq "cancel" } return
	}
		
	set data(upload_to_visualizer_label) [translate "Uploading..."]
	dui item config $widgets(upload_to_visualizer-lbl) -fill $remark_color
	#update
	
	set repo_link [::plugins::DYE::upload_to_visualizer_and_save $data(clock)]
	
	if { $repo_link eq "" } {
		set data(upload_to_visualizer_label) [translate "Upload\rfailed"]
		#update
		after 3000 ::dui::pages::DYE::update_visualizer_button
	} else {
		set data(upload_to_visualizer_label) [translate "Upload\rsuccessful"]
		if { $data(repository_links) eq "" } { 
			set data(repository_links) $repo_link
		} elseif { $data(repository_links) ne $repo_link } {
			lappend data(repository_links) $repo_link
		}
		
		#update
		after 3000 ::dui::pages::DYE::update_visualizer_button
	}
	dui sound make button_out
}

proc ::dui::pages::DYE::update_visualizer_button { {check_page 1} } {
	variable data
	variable widgets
	set page [namespace tail [namespace current]]
	
	if { [string is true $check_page] && [dui page current] ne $page } {
		msg "WARNING: WRONG page in update_visualizer_button='[dui page current]'"	
		return
	}

	if { $data(describe_which_shot) ne "next" && [plugins enabled visualizer_upload] &&
			$::plugins::visualizer_upload::settings(visualizer_username) ne "" && 
			$::plugins::visualizer_upload::settings(visualizer_password) ne "" } {
		dui item config $widgets(upload_to_visualizer-lbl) -fill [dui aspect get {dbutton_label text} fill]
		dui item show $page upload_to_visualizer*
				
		if { $data(repository_links) eq {} } {
			#dui item config $widgets(upload_to_visualizer_symbol) -text [dui symbol get file-upload]
			set data(upload_to_visualizer_label) [translate "Upload to\rVisualizer"]
		} else {
			set data(upload_to_visualizer_label) [translate "Re-upload to\rVisualizer"]
		}
#		else {
			#dui item config $widgets(upload_to_visualizer_symbol) -text [dui symbol get file-contract]
#			set $data(upload_to_visualizer_label) [translate "See in\rVisualizer"]
#		}
	} else {
		dui item hide $page "upload_to_visualizer*"
	}
}

proc ::dui::pages::DYE::ask_to_save_if_needed {} {
	if { [needs_saving] == 1 } {
		set answer [tk_messageBox -message "[translate {You have unsaved changes to the shot description.}]\r\
			[translate {Do you want to save your changes first?}]" \
			-type yesnocancel -icon question]
		if { $answer eq "yes" } { 
			save_description
		} 
		return $answer 
	} else {
		return "yes"
	}
}

proc ::dui::pages::DYE::page_cancel {} {
	set answer [ask_to_save_if_needed]
	if { $answer eq "cancel" } return
	
	say [translate {cancel}] $::settings(sound_button_in);
	unload_page
}

proc ::dui::pages::DYE::page_done {} {
	say [translate {done}] $::settings(sound_button_in)
	# BEWARE: If we don't fully qualify this call, code [info args $pname] in stacktrace, as invoked from 
	#	save_settings, fails.
	if { ! [save_description] } {
		return
	}
	unload_page
}

### "FILTER SHOT HISTORY" PAGE #########################################################################################

namespace eval ::dui::pages::DYE_fsh {
	variable widgets
	array set widgets {}
	
	variable data
	array set data {
		page_title "Filter Shot History"
		previous_page {}
		callback_cmd {}
		category1 {profile_tile}
		categories1_label {Profiles}
		category2 {beans}
		categories2_label {Beans}
		left_filter_status {off}
		right_filter_status {off}
		left_filter_shots {}
		right_filter_shots {}
		matched_shots {}
		matched_clocks {}
		n_matched_shots_text {}
		date_from {}
		date_to {}
		ey_from {}
		ey_to {}
		ey_max 0
		tds_from {}
		tds_to {}
		tds_max 0
		enjoyment_from {}
		enjoyment_to {}
		enjoyment_max 0
		order_by_date "Date"
		order_by_tds "TDS"
		order_by_ey "EY"
		order_by_enjoyment "Enjoyment"
	}
}

# Setup the "Search Shot History" page User Interface.
proc ::dui::pages::DYE_fsh::setup {} {
	variable widgets
	variable data
	set page [namespace tail [namespace current]]
	
	::plugins::DYE::page_skeleton $page "" page_title yes yes center
	
	# Categories1 listbox
	set x_left 60; set y 120
	dui add variable $page $x_left $y -tags categories1_label -style section_header -command categories1_label_dropdown
	dui add symbol $page [expr {$x_left+300}] $y -symbol sort-down -tags categories1_label_dropdown \
		-aspect_type dcombobox_ddarrow -command true
	
	dui add listbox $page $x_left [expr {$y+80}] -tags categories1 -canvas_width 500 -canvas_height 560 \
		-selectmode multiple -yscrollbar yes -font_size -1
	
	# Reset categories1
	dui add text $page [expr {$x_left+340}] [expr {$y+15}] -text "\[ [translate "Reset"] \]" -tags reset_categories1 \
		-style remark -command true 
	
	# Categories2 listbox
	set x_left2 750
	dui add variable $page $x_left2 $y -tags categories2_label -style section_header -command categories2_label_dropdown
	dui add symbol $page [expr {$x_left2+300}] $y -symbol sort-down -tags categories2_label_dropdown \
		-aspect_type dcombobox_ddarrow -command true
	
	dui add listbox $page $x_left2 [expr {$y+80}] -tags categories2 -canvas_width 500 -canvas_height 560 \
		-selectmode multiple -yscrollbar yes -font_size -1

	# Reset categories2
	dui add text $page [expr {$x_left2+340}] [expr {$y+15}] -text "\[ [translate "Reset"] \]" -tags reset_categories2 \
		-style remark -command true
	
	# Date period from
	set x_right_label 1480; set x_right_widget 1800; set y 200
	dui add entry $page $x_right_widget $y -tags date_from -width 11 -data_type date \
		-label [translate "Date from"] -label_pos [list $x_right_label $y] 
	bind $widgets(date_from) <FocusOut> [namespace current]::date_from_leave
	
	# Date period to	
	dui add entry $page 2125 $y -tags date_to -width 11 -data_type date -label [translate "to"] \
		-label_pos {w -20 0} -label_anchor e -label_justify right
	bind $widgets(date_to) <FocusOut> [namespace current]::date_to_leave
	
	# TDS from
	lassign [::plugins::SDB::field_lookup drink_tds {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_dec min max default smallinc biginc
	incr y 100
	dui add entry $page $x_right_widget $y -tags tds_from -width 6 -data_type numeric \
		-label [translate "TDS % from"] -label_pos [list $x_right_label $y] -editor_page yes \
		-min $min -max $max -default $default -n_decimals $n_dec -smallincrement $smallinc -bigincrement $biginc
	# TDS to
	dui add entry $page 2025 $y -tags tds_to -width 6 -data_type numeric \
		-label [translate "to"] -label_pos {w -20 0} -label_anchor e -label_justify right -editor_page yes \
		-min $min -max $max -default $default -n_decimals $n_dec -smallincrement $smallinc -bigincrement $biginc
	
	# EY from
	lassign [::plugins::SDB::field_lookup drink_ey {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_dec min max default smallinc biginc	
	incr y 100
	dui add entry $page $x_right_widget $y -tags ey_from -width 6 -data_type numeric \
		-label [translate "EY % from"] -label_pos [list $x_right_label $y] -editor_page yes \
		-min $min -max $max -default $default -n_decimals $n_dec -smallincrement $smallinc -bigincrement $biginc
	# EY to
	dui add entry $page 2025 $y -tags ey_to -width 6 -data_type numeric \
		-label [translate "to"] -label_pos {w -20 0} -label_anchor e -label_justify right -editor_page yes \
		-min $min -max $max -default $default -n_decimals $n_dec -smallincrement $smallinc -bigincrement $biginc
		
	# Enjoyment from
	lassign [::plugins::SDB::field_lookup espresso_enjoyment {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_dec min max default smallinc biginc	
	incr y 100
	dui add entry $page $x_right_widget $y -tags enjoyment_from -width 6 -data_type numeric \
		-label [translate "Enjoyment from"]	-label_pos [list $x_right_label $y] -editor_page yes \
		-min $min -max $max -default $default -n_decimals $n_dec -smallincrement $smallinc -bigincrement $biginc
	# Enjoyment to
	dui add entry $page 2025 $y -tags enjoyment_to -width 6 -data_type numeric \
		-label [translate "to"]	-label_pos {w -20 0} -label_anchor e -label_justify right -editor_page yes \
		-min $min -max $max -default $default -n_decimals $n_dec -smallincrement $smallinc -bigincrement $biginc
	
	# Enjoyment stars rating from/to
	dui add drater $page $x_right_widget $y -tags enjoyment_from_rater -width 600 -variable enjoyment_from \
		-min $min -max $max -n_ratings 5 -use_halfs yes -label [translate "Enjoyment from"]	-label_pos [list $x_right_label $y]
	dui add drater $page $x_right_widget [expr {$y+75}] -tags enjoyment_to_rater -width 600 -variable enjoyment_to \
		-min $min -max $max -n_ratings 5 -use_halfs yes -label [translate "to"]	-label_pos {w -20 0} -label_anchor e -label_justify right 
	
	# Order by
	dui add text $page $x_right_label 688 -tags order_by_label -text [translate "Order by"] -font_size +2

	set x $x_right_widget; set y 720
	dui add variable $page [incr x 50] $y -tags order_by_date -anchor center -justify center -command [list %NS::set_order_by date]
	dui add variable $page [incr x 175] $y -tags order_by_tds -anchor center -justify center -command [list %NS::set_order_by tds]
	dui add variable $page [incr x 155] $y -tags order_by_ey -anchor center -justify center -command [list %NS::set_order_by ey]
	dui add variable $page [incr x 205] $y -tags order_by_enjoyment -anchor center -justify center \
		-command [list %NS::set_order_by enjoyment]
	
	# Reset button
	set y 810
	dui add dbutton $page $x_left $y -tags reset -label [translate Reset] -style dsx_done

	# Search button
	dui add dbutton $page 2260 $y -tags search -label [translate Search] -style dsx_done

	# Number of search matches
	set data(n_matched_shots_text) [translate "No shots"]
	dui add variable $page 2200 890 -textvariable n_matched_shots_text -style remark -anchor "ne" -justify "right" -width 800
	
	# Search results showing matching shots
	dui add listbox $page $x_left 975 -tags shots -canvas_width 2300 -canvas_height 350 -yscrollbar yes -font_size -1 
	
	# Button "Apply to left history"
	set y 1375
	dui add dbutton $page $x_left $y -tags apply_to_left_side -symbol filter -style dsx_settings \
		-label "[translate {Apply to}]\n[translate {left side}]" -label_pos {0.65 0.3} \
		-label1variable left_filter_status -label1_pos {0.65 0.8} -initial_state hidden
		
	# Button "Apply to right history"
	dui add dbutton $page 2100 $y -tags apply_to_right_side -symbol filter -style dsx_settings \
		-label "[translate {Apply to}]\n[translate {right side}]" -label1variable right_filter_status -initial_state hidden
		
}

# Prepare the DYE_filter_shot_history page.
proc ::dui::pages::DYE_fsh::load { page_to_hide page_to_show args } {
	variable data
	array set opts $args
	
	set data(previous_page) $page_to_hide
	set data(callback_cmd) [value_or_default opts(-callback_cmd) {}]
	set data(category1) [value_or_default opts(-category1) profile_title]
	set data(category2) [value_or_default opts(-category2) bean_desc]
	set data(page_title) [value_or_default opts(-page_title) [translate "Filter Shot History"]]
	set_order_by date

	return 1
}

proc ::dui::pages::DYE_fsh::show { page_to_hide page_to_show } {
	variable data
	variable widgets
	
	dui item relocate_text_wrt $page_to_show reset_categories1 categories1-ysb ne 0 -12 se 
	dui item relocate_text_wrt $page_to_show reset_categories2 categories2-ysb ne 0 -12 se

	category1_change $data(category1)
	category2_change $data(category2)
	
	dui item show_or_hide $::plugins::DYE::settings(use_stars_to_rate_enjoyment) $page_to_show {enjoyment_from_rater* enjoyment_to_rater*}
	dui item show_or_hide [expr {!$::plugins::DYE::settings(use_stars_to_rate_enjoyment)}] $page_to_show {enjoyment_from* enjoyment_to*}
	# Force repainting the stars
	set data(enjoyment_from) $data(enjoyment_from) 
	set data(enjoyment_to) $data(enjoyment_to)
	
	dui item show_or_hide [expr {$::settings(skin) eq "DSx" && $data(previous_page) eq "DSx_past"}] $page_to_show \
		{apply_to_left_side* apply_to_right_side*}
}

proc ::dui::pages::DYE_fsh::categories1_label_dropdown { } {
	variable data

	set cats {}
	foreach cat [array names ::plugins::SDB::data_dictionary ] {
		lassign [::plugins::SDB::field_lookup $cat "data_type name"] data_type cat_name
		if { $data_type eq "category" && $cat ne $data(category2) } {
			lappend cats "[list $cat "$cat_name"]" 
		}
	}

	set item_ids {}
	set items {}	
	set cats [lsort -dictionary -index 1 $cats]
	foreach cat $cats {
		lappend item_ids [lindex $cat 0]
		lappend items [lindex $cat 1]
	}
	
	dui say [translate "Select"] button_in
	dui page load dui_item_selector [namespace current]::data(category1) $items -selected $data(categories1_label) \
		-values_ids $item_ids -item_type categories -page_title [translate "Select a category"] \
		-callback_cmd [namespace current]::select_category1_callback 
}

proc ::dui::pages::DYE_fsh::category1_change { new_category } {
	variable data
	variable widgets
#	if { $data(category1) eq $new_category } return
		
	set data(category1) {}
	if { $new_category ne "" } {
		lassign [::plugins::SDB::field_lookup $new_category "name data_type"] cat_name data_type
		if { $cat_name eq "" } {
			msg "DYE: ERROR on FSH::load_page, category1='$new_category' not found"
			return
		}
		if { $data_type ne "category" } {
			msg "DYE: ERROR on FSH::load_page, field '$new_category' is not a category"
			return
		}
		set data(category1) $new_category
		set data(categories1_label) [translate $cat_name]
		update
	}
	
	after 300 dui item relocate_text_wrt DYE_fsh categories1_label_dropdown categories1_label e 20 -6 w
	fill_categories1_listbox
}

proc ::dui::pages::DYE_fsh::fill_categories1_listbox {} {
	variable data
	variable widgets

	$widgets(categories1) delete 0 end
	if { $data(category1) ne "" } {
		set cat_values [::plugins::SDB::available_categories $data(category1)]
		$widgets(categories1) insert 0 {*}$cat_values
	}
}

proc ::dui::pages::DYE_fsh::reset_categories1 {} {
	variable widgets
	say [translate {reset}] $::settings(sound_button_in)
	$widgets(categories1) selection clear 0 end
}

proc ::dui::pages::DYE_fsh::select_category1_callback { category_name category type } {
	variable data
	set data(category1) $category
	dui page show DYE_fsh
	category1_change $category
}

proc ::dui::pages::DYE_fsh::categories2_label_dropdown { } {
	variable data

	set cats {}
	foreach cat [array names ::plugins::SDB::data_dictionary ] {
		lassign [::plugins::SDB::field_lookup $cat "data_type name"] data_type cat_name
		if { $data_type eq "category" && $cat ne $data(category1) } {
			lappend cats "[list $cat "$cat_name"]" 
		}
	}

	set item_ids {}
	set items {}	
	set cats [lsort -dictionary -index 1 $cats]
	foreach cat $cats {
		lappend item_ids [lindex $cat 0]
		lappend items [lindex $cat 1]
	}
	
	dui say [translate "Select"] button_in
	dui page load dui_item_selector [namespace current]::data(category2) $items -selected $data(categories2_label)  \
		-values_ids $item_ids -item_type categories -page_title [translate "Select a category"] \
		-callback_cmd [namespace current]::select_category2_callback
}
	
proc ::dui::pages::DYE_fsh::category2_change { new_category } {
	variable data
	variable widgets
#	if { $data(category2) eq $new_category } return
		
	set data(category2) {}
	if { $new_category ne "" } {
		lassign [::plugins::SDB::field_lookup $new_category "name data_type"] cat_name data_type
		if { $cat_name eq "" } {
			msg "DYE: ERROR on FSH::load_page, category2='$new_category' not found"
			return
		}
		if { $data_type ne "category" } {
			msg "DYE: ERROR on FSH::load_page, field '$new_category' is not a category"
			return			
		}
		set data(category2) $new_category
		set data(categories2_label) [translate $cat_name]
		update
	}

	after 300 dui item relocate_text_wrt DYE_fsh categories2_label_dropdown categories2_label e 20 -6 w	
	fill_categories2_listbox	
}

proc ::dui::pages::DYE_fsh::fill_categories2_listbox {} {
	variable widgets
	variable data
	
	$widgets(categories2) delete 0 end
	if { $data(category2) ne "" } {
		set cat_values [::plugins::SDB::available_categories $data(category2)]
		$widgets(categories2) insert 0 {*}$cat_values
	}
}

proc ::dui::pages::DYE_fsh::reset_categories2 {} {
	variable widgets
	dui say [translate {Reset}] button_in
	$widgets(categories2) selection clear 0 end
}

proc ::dui::pages::DYE_fsh::select_category2_callback { category_name category type } {
	variable data
	set data(category2) $category
	dui page show DYE_fsh
	category2_change $category	
}

proc ::dui::pages::DYE_fsh::date_from_leave {} {
	variable widgets
	variable data
	if { $data(date_from) eq ""} {
		dui item config $widgets(date_from) -bg [dui aspect get entry bg]
	} elseif { [regexp {^([0-9][0-9]*/)*([0-9][0-9]*/)*[0-9]{4}$} $data(date_from)] == 0 } {
		dui item config $widgets(date_from) -bg [dui aspect get text fill -style remark]
	} else {
		dui item config $widgets(date_from) -bg [dui aspect get entry bg]
		
		if { [regexp {^[0-9]{4}$} $data(date_from)] == 1 } {
			set data(date_from) "1/1/$data(date_from)" 
		} elseif { [regexp {^[0-9][0-9]*/[0-9]{4}$} $data(date_from)] == 1 } {
			set data(date_from) "1/$data(date_from)"
		}	
#				set ::DYE_debug_text "Entered '$::dui::pages::DYE_fsh::data(date_from)'"
#				if { [catch {clock scan $::dui::pages::DYE_fsh::data(date_from) -format $::plugins::DYE::settings{date_format} -timezone :UTC}] } {
#					%W configure -bg $::DSx_settings(orange)
#				} else {
#					%W configure -bg $::DSx_settings(bg_colour)
#				}			
	}
	dui platform hide_android_keyboard
}

proc ::dui::pages::DYE_fsh::date_to_leave {} {
	variable widgets
	variable data
	if { $data(date_to) eq ""} {
		dui item config $widgets(date_to) -bg [dui aspect get entry bg]
	} elseif { [regexp {^([0-9][0-9]*/)*([0-9][0-9]*/)*[0-9]{4}$} $data(date_to)] == 0 } {
		dui item config $widgets(date_to) -bg [dui aspect get text fill -style remark]
	} else {
		$widgets(date_to) configure -bg [dui aspect get entry bg]
		
		if { $::plugins::DYE::settings(date_format) eq "%d/%m/%Y" } {
			if { [regexp {^[0-9]{4}$} $data(date_to)] == 1 } {
				set data(date_to) "31/12/$data(date_to)" 
			} elseif { [regexp {^[0-9][0-9]*/[0-9]{4}$} $data(date_from)] == 1 } {
				set data(date_to) "31/$data(date_to)"
			}
		} elseif { $::plugins::DYE::settings(date_format) eq "%m/%d/%Y" }  {
			if { [regexp {^[0-9]{4}$} $data(date_to)] == 1 } {
				set data(date_to) "12/31/$data(date_to)" 
			}					
		}
			
	}
	dui platform hide_android_keyboard 
}

proc ::dui::pages::DYE_fsh::set_order_by { field } {
	variable data
	dui sound make button_in
	
	set data(order_by_date) "[translate Date]"
	set data(order_by_tds) "[translate TDS]"
	set data(order_by_ey) "[translate EY]"
	set data(order_by_enjoyment) "[translate Enjoyment]"
	
	set data(order_by_$field) "\[ $data(order_by_$field) \]"	
}

proc ::dui::pages::DYE_fsh::reset {} {
	variable data
	variable widgets	
	dui say [translate {Reset}] button_in
	
	$widgets(categories1) selection clear 0 end
	$widgets(categories2) selection clear 0 end
	set data(date_from) {}
	set data(date_to) {}
	set data(tds_from) {}
	set data(tds_to) {}
	set data(ey_from) {}
	set data(ey_to) {}
	set data(enjoyment_from) {}	
	set data(enjoyment_to) {}
	
	set_order_by date	
	$widgets(shots) delete 0 end
	set data(matched_shots) {}
	set data(matched_clocks) {}
	set data(n_matched_shots_text) "[translate {No matching shots}]"
}

## Runs the specified search in the shot history and show the results in the shots listbox.
## ::DSx_filtered_past_shot_files
proc ::dui::pages::DYE_fsh::search {} {
	variable widgets
	variable data
	dui say [translate {Search}] button_in
	
	# Build the SQL SELECT statement
	set where_conds {}
	
	set c1_values [dui item listbox_get_selection $widgets(categories1)]
	if { $c1_values ne "" } {
		lappend where_conds "$data(category1) IN ([::plugins::SDB::strings2sql $c1_values])"
	}
#	set c1_widget $widgets(categories1)
#	if {[$c1_widget curselection] ne ""} {
#		set c1_values {}
#		foreach idx [$c1_widget curselection] {
#			lappend c1_values [$c1_widget get $idx]
#		}
#		lappend where_conds "$data(category1) IN ([::plugins::SDB::strings2sql $c1_values])"
#	}

	set c2_values [dui item listbox_get_selection $widgets(categories2)]
	if { $c2_values ne "" } {
		lappend where_conds "$data(category2) IN ([::plugins::SDB::strings2sql $c2_values])"
	}
#	set c2_widget $widgets(categories2)
#	if {[$c2_widget curselection] ne ""} {
#		set c2_values {}
#		foreach idx [$c2_widget curselection] {
#			lappend c2_values [$c2_widget get $idx]
#		}
#		lappend where_conds "bean_desc IN ([::plugins::SDB::strings2sql $beans])"
#	}
	
	if { $data(date_from) ne "" } {
		set from_clock [clock scan "$data(date_from) 00:00:00" -format "$::plugins::DYE::settings(date_format) %H:%M:%S"]
		lappend where_conds "clock>=$from_clock"
	}	
	if { $data(date_to) ne "" } {
		set to_clock [clock scan "$data(date_to) 23:59:59" -format "$::plugins::DYE::settings(date_format) %H:%M:%S"]
		lappend where_conds "clock<=$to_clock"
	}

	if { $data(tds_from) ne "" } {
		lappend where_conds "LENGTH(drink_tds)>0 AND drink_tds>=$data(tds_from)"
	}	
	if { $data(tds_to) ne "" } {
		lappend where_conds "LENGTH(drink_tds)>0 AND drink_tds<=$data(tds_to)"
	}
	
	if { $data(ey_from) ne "" } {
		lappend where_conds "LENGTH(drink_ey)>0 AND drink_ey>=$data(ey_from)"
	}	
	if { $data(ey_to) ne "" } {
		lappend where_conds "LENGTH(drink_ey)>0 AND drink_ey<=$data(ey_to)"
	}

	if { $data(enjoyment_from) ne "" } {
		lappend where_conds "LENGTH(espresso_enjoyment)>0 AND espresso_enjoyment>=$data(enjoyment_from)"
	}	
	if { $data(enjoyment_to) ne "" && $data(enjoyment_to) > 0 } {
		lappend where_conds "LENGTH(espresso_enjoyment)>0 AND espresso_enjoyment<=$data(enjoyment_to)"
	}
	
	set sql "SELECT clock, filename, shot_desc FROM V_shot WHERE removed=0 "
	if {[llength $where_conds] > 0} { 
		append sql "AND [join $where_conds " AND "] "
	}
	
	if { [string first "\[" $data(order_by_enjoyment)] >= 0 } {
		append sql {ORDER BY espresso_enjoyment DESC, clock DESC}
	} elseif { [string first "\[" $data(order_by_ey)] >= 0 } {
		append sql {ORDER BY drink_ey DESC, clock DESC}
	} elseif { [string first "\[" $data(order_by_tds)] >= 0 } {
		append sql {ORDER BY drink_tds DESC, clock DESC}
	} else {
		append sql {ORDER BY clock DESC}
	}
		
	# Run the search
	set data(matched_shots) {}
	set data(matched_clocks) {}
	set cnt 0
	$widgets(shots) delete 0 end	
	
	set db ::plugins::SDB::get_db
	msg "DYE: $sql"
	db eval "$sql" {
		# data(matched_shots) has this apparently nonsense repeated data structure because that's exactly what DSx
		# expects, and this was used only for filtering DSx History Viewer on DYE before v2.00
		lappend data(matched_shots) $filename "$filename.shot"
		lappend data(matched_clocks) $clock
		$widgets(shots) insert $cnt $shot_desc
		
		# TODO Move this line to the select for left side button.
		if { $cnt == 0 && $::settings(skin) eq "DSx"} { 
			set ::DSx_settings(DSx_past_espresso_name) $filename 
		}
			
		incr cnt
	}
	
	set data(n_matched_shots) $cnt
	if { $cnt == 0 } {
		set data(n_matched_shots_text) "[translate {No matching shots}]"
	} elseif { $cnt == 1 } {
		set data(n_matched_shots_text) "$cnt [translate {matching shot}]"
	} else {		
		set data(n_matched_shots_text) "$cnt [translate {matching shots}]"
	}
}

proc ::dui::pages::DYE_fsh::apply_to_left_side {} {
	variable data
	if { $::settings(skin) ne "DSx" } return
	
	dui say [translate {Filter}] button_in
	if {$data(left_filter_status) eq "off"} {
		if {[llength $data(matched_shots)] > 0} {
			# Ensure the files still exist on disk, otherwise don't include them
			set ::DSx_filtered_past_shot_files {} 
			for { set i 0 } { $i < [llength $data(matched_shots)] } { incr i 2 } {
				set fn [lindex $data(matched_shots) $i]
				if { [file exists "[homedir]/history/${fn}.shot"] } {
					lappend ::DSx_filtered_past_shot_files $fn
					lappend ::DSx_filtered_past_shot_files "${fn}.shot"
				} elseif { [file exists "[homedir]/history_archive/${fn}.shot"] } {
					lappend ::DSx_filtered_past_shot_files $fn
					lappend ::DSx_filtered_past_shot_files "${fn}.shot"
				}
			}				
			#set ::DSx_filtered_past_shot_files $data(matched_shots)
			set data(left_filter_status) "on"
		}
	} else {
		set data(left_filter_status) "off"
		unset -nocomplain ::DSx_filtered_past_shot_files
	}	
}

# Returns a list with the clocks of all shots returned from the last search. 
proc ::dui::pages::DYE_fsh::matched_shots {} {
	variable data
	return $data(matched_clocks)
}

# Returns a list with the clocks of the currently selected shot(s).
proc ::dui::pages::DYE_fsh::selected_shots {} {
	variable data
	return [dui item listbox_get_selection DYE_fsh shots $data(matched_clocks)]
}

proc ::dui::pages::DYE_fsh::apply_to_right_side {} {
	variable data
	if { $::settings(skin) ne "DSx" } return
	dui say [translate {Filter}] button_in
	
	if {$data(right_filter_status) eq "off"} {
		if {[llength $data(matched_shots)] > 0} {
			# Ensure the files still exist on disk, otherwise don't include them
			set ::DSx_filtered_past_shot_files2 {} 
			for { set i 0 } { $i < [llength $data(matched_shots)] } { incr i 2 } {
				set fn [lindex $data(matched_shots) $i]
				if { [file exists "[homedir]/history/${fn}.shot"] } {
					lappend ::DSx_filtered_past_shot_files2 $fn
					lappend ::DSx_filtered_past_shot_files2 "${fn}.shot"
				} elseif { [file exists "[homedir]/history_archive/${fn}.shot"] } {
					lappend ::DSx_filtered_past_shot_files2 $fn
					lappend ::DSx_filtered_past_shot_files2 "${fn}.shot"
				}
			}				
			#set ::DSx_filtered_past_shot_files2 $data(matched_shots)
			set data(right_filter_status) "on"
		}
	} else {
		set data(right_filter_status) "off"
		unset -nocomplain ::DSx_filtered_past_shot_files
	}
}

proc ::dui::pages::DYE_fsh::page_cancel {} {
	variable data
	dui say [translate {save}] button_in
	
	if { $data(callback_cmd) ne "" } {
		uplevel #0 [list $data(callback_cmd) {} {}]
	} elseif { $data(previous_page) eq "" } {
		if { $::settings(skin) eq "DSx" } {
			dui page show DSx_past
		} else {
			dui page show DYE
		}
	} else {
		dui page show $data(previous_page)
	} 	
}

proc ::dui::pages::DYE_fsh::page_done {} {
	variable data
	dui say [translate {save}] button_in
	
	if { $data(callback_cmd) ne "" } {
		#msg "::dui::pages::DYE_fsh::page_done, callback_cmd=$data(callback_cmd)"
		#msg "::dui::pages::DYE_fsh::page_done, matched_clocks=$data(matched_clocks), selected_clock=[dui item listbox_get_selection DYE_fsh shots $data(matched_clocks)]"				
		uplevel #0 [list $data(callback_cmd) [dui item listbox_get_selection DYE_fsh shots $data(matched_clocks)] $data(matched_clocks)]
		return
	} elseif { $data(previous_page) eq "" } {
		if { $::settings(skin) eq "DSx" } {
			dui page show DSx_past
		} else {
			dui page show DYE
		}
	} else {
		dui page show $data(previous_page)
	} 
	
	if { $::settings(skin) eq "DSx" && $data(previous_page) eq "DSx_past" } {
		if {$data(left_filter_status) eq "on"} {
			fill_DSx_past_shots_listbox
		}
		if {$data(right_filter_status) eq "on"} {
			fill_DSx_past2_shots_listbox
		}
	}
}

	
#### "SHORTCUTS MENU" PAGE #############################################################################################
#### STILL EXPERIMENTAL, USED ONLY WHILE DEBUGGING 
#
#namespace eval ::dui::pages::DYE_menu {
#	# State variables for the "DYE_menu" page. Not persisted. 
#	variable widgets
#	array set widgets {}
#	# affected_shots_slider 1
#	
#	variable data
#	array set data {
#		page_name "::dui::pages::DYE_menu"
#		previous_page {}
#		page_title {}
#		previous_page {}
#	}
#}
#
#proc ::dui::pages::DYE_menu::setup {} {
#	variable data
#	variable widgets
#	set page [namespace current]
#
#	add_de1_image $page 0 0 "[skin_directory_graphics]/background/bg2.jpg"
#
#	::plugins::DGUI::add_text $page 650 100 [translate "Menu"] -widget_name page_title \
#		-font_size $::plugins::DGUI::header_font_size -fill $::plugins::DGUI::page_title_color -anchor "center" 
#
#	# Close menu
#	::plugins::DGUI::add_symbol $page 1200	60 window_close -widget_name close_page -has_button 1 \
#		-button_cmd ::dui::pages::DYE_menu::page_done
#
#	# DYE shortcuts
#	set x 100; set y 200
#	
#	::plugins::DGUI::add_text $page $x $y [translate "Edit equipment types"] -widget_name edit_equipment -has_button 1 \
#		-button_width 400 -button_cmd {say "" $::settings(sound_button_in); ::plugins::DYE::MODC::load_page equipment_type}
#
#	::plugins::DGUI::add_text $page $x [incr y 80] [translate "Filter shot history"] -widget_name fsh -has_button 1 \
#		-button_width 400 -button_cmd {say "" $::settings(sound_button_in); ::dui::pages::DYE_fsh::load_page}
#
#	::plugins::DGUI::add_text $page $x [incr y 80] [translate "Numbers editor"] -widget_name edit_number -has_button 1 \
#		-button_width 400 -button_cmd {say "" $::settings(sound_button_in); ::plugins::DYE::NUME::load_page drink_tds }
#	
#	set x 800; set y 200
#	
#	::plugins::DGUI::add_text $page $x $y [translate "DYE settings"] -widget_name edit_equipment -has_button 1 \
#		-button_width 400 -button_cmd {say "" $::settings(sound_button_in); ::dui::pages::DYE_settings::load_page}
#	
#}
#
## Prepare and launch the DYE_modify_category page.
#proc ::dui::pages::DYE_menu::load { page_to_hide page_to_show } {	
#	variable data
#	variable widgets
#	set ns [namespace current]
#	
#	::plugins::DGUI::set_previous_page $ns
#	page_to_show_when_off $ns	
#		
#	hide_android_keyboard
#}
#
#proc ::dui::pages::DYE_menu::page_done {} {
#	variable data
#	page_to_show_when_off $data(previous_page)
#}
#
#### "CONFIGURATION SETTINGS" PAGE ######################################################################################

namespace eval ::dui::pages::DYE_settings {
	variable widgets
	array set widgets {}
	
	variable data
	array set data {
		page_name "::dui::pages::DYE_settings"
		db_status_msg {}
		update_plugin_state {-}
		latest_plugin_version {}
		latest_plugin_url {}
		latest_plugin_desc {}
		update_plugin_msg {}
		plugin_has_been_updated 0
	}
}

# Setup the "DYE_configuration" page User Interface.
proc ::dui::pages::DYE_settings::setup {} {
	variable widgets
	set page [namespace tail [namespace current]]

	# HEADER AND BACKGROUND
	dui add text $page 1280 100 -tags page_title -text [translate "Describe Your Espresso Settings"] -style page_title

	dui add canvas_item rect $page 10 190 2550 1430 -fill "#ededfa" -width 0
	dui add canvas_item line $page 14 188 2552 189 -fill "#c7c9d5" -width 2
	dui add canvas_item line $page 2551 188 2552 1426 -fill "#c7c9d5" -width 2
	
	dui add canvas_item rect $page 22 210 1270 1410 -fill white -width 0
	#dui add canvas_item rect $page 22 1200 1270 1410 -fill white -width 0
	dui add canvas_item rect $page 1290 210 2536 1410 -fill white -width 0	
		
	# LEFT SIDE
	set x 75; set y 250; set vspace 130; set lwidth 1050
	
	dui add text $page $x $y -text [translate "General options"] -style section_header
		
	dui add dcheckbox $page $x [incr y $vspace] -tags propagate_previous_shot_desc -command propagate_previous_shot_desc_change \
		-textvariable ::plugins::DYE::settings(propagate_previous_shot_desc) \
		-label [translate "Propagate Beans, Equipment & People from last to next shot"] -label_width $lwidth
	
	dui add dcheckbox $page $x [incr y $vspace] -tags describe_from_sleep -command describe_from_sleep_change \
		-textvariable ::plugins::DYE::settings(describe_from_sleep) \
		-label [translate "Icon on screensaver to describe last shot without waking up the DE1"] -label_width $lwidth

	dui add dcheckbox $page $x [incr y $vspace] -tags backup_modified_shot_files -command backup_modified_shot_files_change \
		-textvariable ::plugins::DYE::settings(backup_modified_shot_files) \
		-label [translate "Backup past shot files when they are modified (.bak)"] -label_width $lwidth

	dui add dcheckbox $page $x [incr y $vspace] -tags use_stars_to_rate_enjoyment \
		-textvariable ::plugins::DYE::settings(use_stars_to_rate_enjoyment) \
		-label [translate "Use 1-5 stars rating to evaluate enjoyment"] -label_width $lwidth
	
	# RIGHT SIDE
	set x 1350; set y 250
	dui add text $page $x $y -text [translate "DSx skin options"] -style section_header
	
	dui add dcheckbox $page $x [incr y 100] -tags show_shot_desc_on_home -command show_shot_desc_on_home_change \
		-textvariable ::plugins::DYE::settings(show_shot_desc_on_home) \
		-label [translate "Show next & last shot description summaries on DSx home page"] -label_width $lwidth 
	
	incr y [expr {int($vspace * 1.60)}]
	dui add dbutton $page [expr {$x+100}] $y -tags shot_desc_font_color -style dsx_settings -label [translate "Shots\rsummaries\rcolor"] \
		-symbol paint-brush -symbol_fill $::plugins::DYE::settings(shot_desc_font_color) -command shot_desc_font_color_change 
	incr y [expr {[dui aspect get dbutton bheight -style dsx_settings]+35}]
	
	dui add text $page [expr {int($x+100+[dui aspect get dbutton bwidth -style dsx_settings]/2)}] $y \
		-text "\[ [translate {Use default color}] \]" -anchor center -justify center \
		-fill  $::plugins::DYE::default_shot_desc_font_color -command set_default_shot_desc_font_color
	
	# FOOTER
	dui add dbutton $page 1035 1460 -tags page_done -style insight_ok -command page_done -label [translate Ok]
}

# Normally not used as this is not invoked directly but by the DSx settings pages carousel, but still kept for 
# consistency or for launching the page from a menu.
proc ::dui::pages::DYE_settings::load { page_to_hide page_to_show } {
}

# Added to context actions, so invoked automatically whenever the page is loaded
proc ::dui::pages::DYE_settings::show { page_to_hide page_to_show } {
	#update_plugin_state	
}


proc ::dui::pages::DYE_settings::show_shot_desc_on_home_change {} {	
	::plugins::DYE::define_last_shot_desc
	::plugins::DYE::define_next_shot_desc
	plugins save_settings DYE
}

proc ::dui::pages::DYE_settings::propagate_previous_shot_desc_change {} {
	if { $::plugins::DYE::settings(propagate_previous_shot_desc) == 1 } {
		if { $::plugins::DYE::settings(next_modified) == 0 } {
			foreach field_name $::plugins::DYE::propagated_fields {
				set ::plugins::DYE::settings(next_$field_name) $::settings($field_name)
			}
			set ::plugins::DYE::settings(next_espresso_notes) {}
		}
	} else {
		if { $::plugins::DYE::settings(next_modified) == 0 } {
			foreach field_name "$::plugins::DYE::propagated_fields next_espresso_notes" {
				set ::plugins::DYE::settings(next_$field_name) {}
			}			
		}
	}
	
	::plugins::DYE::define_next_shot_desc
	plugins save_settings DYE
}
	
proc ::dui::pages::DYE_settings::describe_from_sleep_change {} {
	if { [info exists ::plugins::DYE::widgets(describe_from_sleep_symbol)] } {
		if { $::plugins::DYE::settings(describe_from_sleep) == 1 } {
			.can itemconfig $::plugins::DYE::widgets(describe_from_sleep_symbol) \
				-text $::plugins::DYE::settings(describe_icon)
			.can coords $::plugins::DYE::widgets(describe_from_sleep_button) [rescale_x_skin 230] [rescale_y_skin 0] \
				[rescale_x_skin 460] [rescale_y_skin 230]
		} else {
			.can itemconfig $::plugins::DYE::widgets(describe_from_sleep_symbol) -text ""
			.can coords $::plugins::DYE::widgets(describe_from_sleep_button) 0 0 0 0
		}
	}
	plugins save_settings DYE
}
	
proc ::dui::pages::DYE_settings::backup_modified_shot_files_change {} {	
	plugins save_settings DYE
}

proc ::dui::pages::DYE_settings::shot_desc_font_color_change {} {
	variable widgets
	dui sound make button_in
	
	set colour [tk_chooseColor -initialcolor $::plugins::DYE::settings(shot_desc_font_color) \
		-title [translate "Set shot summary descriptions color"]]
	if { $colour ne "" } {
		if { $::settings(skin) eq "DSx" } {
			dui item config [lindex $::DSx_standby_pages 0] launch_dye_next-lbl -fill $colour
			dui item config [lindex $::DSx_standby_pages 0] launch_dye_last-lbl -fill $colour
			dui item config DSx_past {dsx_past_launch_dye-lbl dsx_past2_launch_dye-lbl} -fill $colour
			dui item config DSx_past_zoomed dye_shot_desc -fill $colour
			dui item config DSx_past2_zoomed dye_shot_desc -fill $colour
		}
		dui item config $widgets(shot_desc_font_color-sym) -fill $colour
	
		set ::plugins::DYE::settings(shot_desc_font_color) $colour
		plugins save_settings DYE
	}	
}

proc ::dui::pages::DYE_settings::set_default_shot_desc_font_color {} {
	variable widgets
	dui sound make button_in
	set colour $::plugins::DYE::default_shot_desc_font_color
	
	if { $::settings(skin) eq "DSx" } {
		dui item config [lindex $::DSx_standby_pages 0] launch_dye_next-lbl -fill $colour
		dui item config [lindex $::DSx_standby_pages 0] launch_dye_last-lbl -fill $colour
		dui item config DSx_past {dsx_past_launch_dye-lbl dsx_past2_launch_dye-lbl} -fill $colour
		dui item config DSx_past_zoomed dye_shot_desc -fill $colour
		dui item config DSx_past2_zoomed dye_shot_desc -fill $colour
	}
	
	dui item config $widgets(shot_desc_font_color-sym) -fill $colour
	set ::plugins::DYE::settings(shot_desc_font_color) $colour
	plugins save_settings DYE
}

#proc ::dui::pages::DYE_settings::update_plugin_state {} {
#	variable data
#	variable widgets
#	
#	::plugins::DGUI::enable_or_disable_widgets [expr !$data(plugin_has_been_updated)] update_plugin* [namespace current]
#	if { $data(plugin_has_been_updated) == 1 } return
#	
#	.can itemconfig $widgets(update_plugin_state) -fill $::plugins::DGUI::font_color
#	set data(update_plugin_msg) ""
#	
#	if { [ifexists ::plugins::DYE::settings(github_latest_url) "" ] eq "" } {
#		set data(update_plugin_state) [translate "No update URL"]
#	} elseif { $::android == 1 && [borg networkinfo] eq "none" } {
#		set data(update_plugin_state) [translate "No wifi"]		
#	} else {
#		lassign [::plugins::DYE::github_latest_release $::plugins::DYE::settings(github_latest_url)] \
#			data(latest_plugin_version) data(latest_plugin_url) data(latest_plugin_desc)
#		
##msg "DYE PLUGIN UPDATE - Comparing [lindex [package versions describe_your_espresso] 0] and $data(latest_plugin_version)"		
#		if { $data(latest_plugin_version) == -1 } {
#			set data(update_plugin_state) [translate "Error"]
#			set data(update_plugin_msg) $data(latest_plugin_desc)
#		} elseif { [package vcompare [lindex [package versions describe_your_espresso] 0] \
#				$data(latest_plugin_version) ] >= 0 } {
#			set data(update_plugin_state) [translate "Up-to-date"]
#		} else {
#			set data(update_plugin_state) "v$data(latest_plugin_version) [translate available]"
#			.can itemconfig $widgets(update_plugin_state) -fill $::plugins::DGUI::remark_color
#			if { $data(latest_plugin_desc) ne "" } {
#				set data(update_plugin_msg) "\[ [translate {What's new?}] \]"
#			}
#		}
#	}
#}
#
#proc ::dui::pages::DYE_settings::show_latest_plugin_description {} {
#	variable data
#	
#	if { $data(latest_plugin_version) eq "" || $data(latest_plugin_version) == -1 || \
#			$data(latest_plugin_desc) eq "" } return
#	if { [package vcompare [lindex [package versions describe_your_espresso] 0] \
#		$data(latest_plugin_version) ] >= 0 } return 
#	
#	::plugins::DYE::TXT::load_page "latest_plugin_desc" ::dui::pages::DYE_settings::data(latest_plugin_desc) 1 \
#		-page_title "[translate {What's new in DYE v}]$data(latest_plugin_version)"
#}
#
#proc ::dui::pages::DYE_settings::update_plugin_click {} {
#	variable data
#	
#	if { $data(latest_plugin_version) eq "" || $data(latest_plugin_version) == -1 } update_plugin_state
#	if { $data(latest_plugin_version) eq "" || $data(latest_plugin_version) == -1 || \
#			$data(latest_plugin_url) eq "" } return
#	
#	if { [package vcompare [lindex [package versions describe_your_espresso] 0] \
#		$data(latest_plugin_version) ] >= 0 } return
#
#	set update_result [::plugins::DYE::update_DSx_plugin_from_github $::plugins::DYE::plugin_file $data(latest_plugin_url)]
#	if { $update_result == 1 } {
#		set data(update_plugin_msg) "[translate {Plugin updated to v}]$data(latest_plugin_version)\r
#[translate {Please quit and restart to load changes}]"
#		set data(update_plugin_state) [translate "Up-to-date"]
#		set data(plugin_has_been_updated) 1		
#		update_plugin_state
#		#set ::app_has_updated 1
#	} else {
#		set data(update_plugin_msg) [translate "Error downloading update"]
#		set data(update_plugin_state) [translate "Error"]
#	}
#}

proc ::dui::pages::DYE_settings::page_done {} {
	dui say [translate {Done}] button_in
	dui page load extensions
}

#### GLOBAL STUFF AND STARTUP  #########################################################################################

# Ensure new metadata fields are initialized on the global settings on first use.
# This fails to create them for the first time if the code is on check_settings...
#foreach fn "drinker_name repository_links other_equipment"
foreach fn "drinker_name repository_links" {
	if { ! [info exists ::settings($fn)] } {
		set ::settings($fn) {}
	}
}
