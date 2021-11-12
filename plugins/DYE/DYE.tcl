#######################################################################################################################
### A Decent DE1app extension that provides shot logging (metadata description) of any shot in the history.
###  
### Source code available in GitHub: https://github.com/ebengoechea/dye_de1app_dsx_plugin/
### This code is released under GPLv3 license. See LICENSE file under the DE1 source folder in github.
###
### By Enrique Bengoechea <enri.bengoechea@gmail.com> 
### (with lots of copy/paste/tweak from Damian, John and Johanna's code!)
########################################################################################################################
#set ::skindebug 1
#plugins enable SDB
#plugins enable DYE
#fconfigure $::logging::_log_fh -buffering line
#dui config debug_buttons 0

package require http
package require tls
package require json
# zint may not be available in some standard Tcl/Tk distributions, for example on MacOS.
try {
	package require zint
} on error err {
	msg -WARNING "::plugins::DYE can't generate QR codes: $err"
}

namespace eval ::plugins::DYE {
	variable author "Enrique Bengoechea"
	variable contact "enri.bengoechea@gmail.com"
	variable version 2.16
	variable github_repo ebengoechea/de1app_plugin_DYE
	variable name [translate "Describe Your Espresso"]
	variable description [translate "Describe any shot from your history and plan the next one: beans, grinder, extraction parameters and people."]

	variable min_de1app_version {1.37}
	variable min_DSx_version {4.79}
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
		
	regsub -all { } $::settings(skin) "_" skin
	set skin_src_fn "[plugin_directory]/DYE/setup_${skin}.tcl"
	if { [file exists $skin_src_fn] } { 
		source $skin_src_fn
	}
	if { $skin eq "Insight_Dark" } {
		source "[plugin_directory]/DYE/setup_Insight.tcl"
	}
		
	if { [namespace which -command "::plugins::DYE::setup_ui_$skin"] ne "" } {
		::plugins::DYE::setup_ui_$skin
	} 
	if { $skin eq "Insight_Dark" } {
		::plugins::DYE::setup_ui_Insight
	}
	
	foreach page {DYE DYE_fsh} {
		dui page add $page -namespace true -type fpdialog
	}
	# Default slice/button height in menu dialogs: 120
	dui page add dye_edit_dlg -namespace true -type dialog -bbox {0 0 1150 840}
	dui page add dye_visualizer_dlg -namespace true -type dialog -bbox {0 0 900 960}
	dui page add dye_which_shot_dlg -namespace true -type dialog -bbox {0 0 1100 820}
	
	foreach page $::dui::pages::DYE_v3::pages {
		dui page add $page -namespace ::dui::pages::DYE_v3 -type fpdialog
	}
	
	# Update/propagate the describe settings when the a shot is started 
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
	dui page add DYE_settings -namespace true -theme default -type fpdialog
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
	
	regsub -all { } $::settings(skin) "_" skin
	if { $skin ni {Insight Insight_Dark DSx MimojaCafe} } {
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
	if { [info exists ::DSx_settings(next_shot_DSx_home_coords)] } {
		set settings(next_shot_DSx_home_coords) $::DSx_settings(next_shot_DSx_home_coords)
	} else {
		ifexists settings(next_shot_DSx_home_coords) {500 1165}
	}
	if { [info exists ::DSx_settings(last_shot_DSx_home_coords)] } {
		set settings(last_shot_DSx_home_coords) $::DSx_settings(last_shot_DSx_home_coords)
	} else {
		ifexists settings(last_shot_DSx_home_coords) {2120 1165}
	}
	ifexists settings(github_latest_url) "https://api.github.com/repos/ebengoechea/de1app_plugin_DYE/releases/latest"
	set settings(use_dye_v3) 0
	ifexists settings(relative_dates) 1
	ifexists settings(date_input_formats) {"%m/%d/%Y %H:%M" "%m/%d/%y %H:%M" "%m/%d/%Y" "%m/%d/%y" "%m.%d.%Y %H:%M" "%m.%d.%y %H:%M" "%m.%d.%Y" "%m.%d.%y"}
	ifexists settings(date_output_format) "%b %d %Y"
	ifexists settings(time_output_format) "%H:%M"
	ifexists settings(time_output_format_ampm) "%I:%M %p"
	ifexists settings(default_launch_action) last
	
	ifexists settings(apply_action_to_beans) 1
	ifexists settings(apply_action_to_equipment) 1
	ifexists settings(apply_action_to_ratio) 1
	ifexists settings(apply_action_to_extraction) 0
	ifexists settings(apply_action_to_note) 0
	ifexists settings(apply_action_to_people) 1
	ifexists settings(apply_action_to_profile) 0
	
	# Don't use ifexists for this, as it always evaluates the default value, inducing it to be changed
	if { ![info exists settings(last_shot_desc)] } {
		set settings(last_shot_desc) [define_last_shot_desc]
	}
	if { ![info exists settings(next_shot_desc)] } {
		set settings(next_shot_desc) [define_next_shot_desc]
	}
	
	# Propagation mechanism
	# drink_weight and espresso_notes are special as they're not propagated (from last to next), but can be defined in next.
	ifexists settings(next_modified) 0
	set propagated_fields [metadata fields -domain shot -category description -propagate 1]
	foreach field_name [concat $propagated_fields espresso_notes drink_weight] {
		if { ! [info exists settings(next_$field_name)] } {
			set settings(next_$field_name) {}
		}
	}
	
	if { $settings(next_modified) == 0 } {
		if { $settings(propagate_previous_shot_desc) == 1 } {
			foreach field_name $propagated_fields {
				if { [info exists ::settings($field_name)] } {
					set settings(next_$field_name) $::settings($field_name)
				} else {
					set settings(next_$field_name) {}
				}
			}
			set settings(next_espresso_notes) {}
		} else {
			foreach field_name [concat $propagated_fields next_espresso_notes] {
				set settings(next_$field_name) {}
			}
		}
	}
	
	ifexists settings(summary_fields) {bean_brand bean_type roast_date "" grinder_setting "" espresso_notes "" espresso_enjoyment}
	ifexists settings(next_summary_fields) {grinder_dose_weight drink_weight "" bean_brand bean_type roast_date "" grinder_setting espresso_notes}
	
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
	
	set bold_font [dui aspect get dtext font_family -theme default -style bold]
	dui aspect set -theme $theme -style dsx_done [list dbutton.shape round dbutton.bwidth 220 dbutton.bheight 140 \
		dbutton_label.pos {0.5 0.5} dbutton_label.font_size 20 dbutton_label.font_family $bold_font]
	
	dui aspect set -theme $theme -style dye_main_nav_button { dbutton.shape {} dbutton.fill {} dbutton.disabledfill {} 
		dbutton_symbol.font_size 28 dbutton_symbol.fill "#35363d" dbutton_symbol.disabledfill "#ccc"}
	
	dui aspect set -theme $theme -type dtext -style section_header [list font_family $bold_font font_size 20]
	
	dui aspect set -theme $theme -type dclicker -style dye_double {orient horizontal use_biginc 1 symbol chevron-double-left 
		symbol1 chevron-left symbol2 chevron-right symbol3 chevron-double-right }
	dui aspect set -theme $theme -type dclicker_symbol -style dye_double {pos {0.075 0.5} font_size 24 anchor center fill "#7f879a"} 
	dui aspect set -theme $theme -type dclicker_symbol1 -style dye_double {pos {0.275 0.5} font_size 24 anchor center fill "#7f879a"} 
	dui aspect set -theme $theme -type dclicker_symbol2 -style dye_double {pos {0.725 0.5} font_size 24 anchor center fill "#7f879a"}
	dui aspect set -theme $theme -type dclicker_symbol3 -style dye_double {pos {0.925 0.5} font_size 24 anchor center fill "#7f879a"}

	dui aspect set -theme $theme -type dclicker -style dye_single {orient horizontal use_biginc 0 symbol chevron-left symbol1 chevron-right}
	dui aspect set -theme $theme -type dclicker_symbol -style dye_single {pos {0.1 0.5} font_size 24 anchor center fill "#7f879a"} 
	dui aspect set -theme $theme -type dclicker_symbol1 -style dye_single {pos {0.9 0.5} font_size 24 anchor center fill "#7f879a"} 
	
	# DYE v3
	set bg_color [dui aspect get page bg_color -theme default]
	set btn_spacing 100
	set half_button_width [expr {int(($::dui::pages::DYE_v3::page_coords(panel_width)-$btn_spacing)/2)}]	
	set half_button_width 200
	
	dui aspect set -theme default [subst { 
		dbutton.bheight.dyev3_topnav 90 
		dbutton.shape.dyev3_topnav rect 
		dbutton_label.font_size.dyev3_topnav -1 
		dbutton_label.pos.dyev3_topnav {0.5 0.5} 
		dbutton_label.anchor.dyev3_topnav center 
		dbutton_label.justify.dyev3_topnav center 
	
		dbutton.bwidth.dyev3_nav_button 100 
		dbutton.bheight.dyev3_nav_button 120
		dbutton.fill.dyev3_nav_button {}
		dbutton.disabledfill.dyev3_nav_button {}
		dbutton_symbol.pos.dyev3_nav_button {0.5 0.5} 
		dbutton_symbol.fill.dyev3_nav_button grey
		dbutton_symbol.disabledfill.dyev3_nav_button #ccc
		
		text.font_size.dyev3_top_panel_text -1
		text.yscrollbar.dyev3_top_panel_text no
		text.bg.dyev3_top_panel_text $bg_color
		text.borderwidth.dyev3_top_panel_text 0
		text.highlightthickness.dyev3_top_panel_text 0
		text.relief.dyev3_top_panel_text flat
		
		text.font_size.dyev3_bottom_panel_text -1
	
		dtext.font_family.dyev3_right_panel_title notosansuibold 
		dtext.font_size.dyev3_right_panel_title +2
		dtext.fill.dyev3_right_panel_title black
		dtext.anchor.dyev3_right_panel_title center
		dtext.justify.dyev3_right_panel_title center
		
		graph.background.dyev3_text_graph white 
		graph.plotbackground.dyev3_text_graph white 
		graph.borderwidth.dyev3_text_graph 1 
		graph.plotrelief.dyev3_text_graph flat
		
		dtext.font_size.dyev3_chart_stage_title +2 
		dtext.anchor.dyev3_chart_stage_title center 
		dtext.justify.dyev3_chart_stage_title center 
		dtext.fill.dyev3_chart_stage_title black
		
		dtext.anchor.dyev3_chart_stage_colheader center 
		dtext.justify.dyev3_chart_stage_colheader center
		
		dtext.anchor.dyev3_chart_stage_value center
		dtext.justify.dyev3_chart_stage_value center
		
		dtext.anchor.dyev3_chart_stage_comp center
		dtext.justify.dyev3_chart_stage_comp center
		dtext.font_size.dyev3_chart_stage_comp -4
		dtext.fill.dyev3_chart_stage_comp white
	
		line.fill.dyev3_chart_stage_line_sep grey
				
		dbutton.shape.dyev3_action_half round
		dbutton.bwidth.dyev3_action_half $half_button_width
		dbutton.bheight.dyev3_action_half 125
		dbutton_symbol.pos.dyev3_action_half {0.2 0.5} 
		dbutton_label.pos.dyev3_action_half {0.6 0.5}
		dbutton_label.width.dyev3_action_half [expr {$half_button_width-75}]
		
		#text_tag.foregroud.which_shot black
		text_tag.font.dyev3_which_shot "[dui font get notosansuibold 15]"
		text_tag.justify.dyev3_which_shot center
		
		text_tag.justify.dyev3_profile_title center
		
		text_tag.foreground.dyev3_section black 
		text_tag.font.dyev3_section "[dui font get notosansuibold 17]" 
		text_tag.spacing1.dyev3_section [dui platform rescale_y 20]
		
		text_tag.foreground.dyev3_field "#7f879a" 
		text_tag.lmargin1.dyev3_field [dui platform rescale_x 35] 
		text_tag.lmargin2.dyev3_field [dui platform rescale_x 45]
		
		text_tag.foreground.dyev3_value blue
		text_tag.foreground.dyev3_measure_unit blue
		text_tag.foreground.dyev3_compare grey
		
		text_tag.font.dyev3_field_highlighted "[dui font get notosansuibold 15]"
		text_tag.background.dyev3_field_highlighted  pink
		text_tag.font.dyev3_field_nonhighlighted "[dui font get notosansuiregular 15]"
		text_tag.background.dyev3_field_nonhighlighted {}
	}]
	
}


# Reset the "next" description and update the current/last shot summary description
proc ::plugins::DYE::reset_gui_starting_espresso_leave_hook { args } {
	variable settings
	set skin $::settings(skin)
	
	# If the target dose or yield have been defined in the skin, ensure they are synchronized to next shot dose
	if { $skin eq "DSx" } {
		if { [info exists ::DSx_settings(bean_weight)] && $::DSx_settings(bean_weight) > 0 } {
			set settings(next_grinder_dose_weight) [round_to_one_digits $::DSx_settings(bean_weight)]
		}
		if { [info exists ::DSx_settings(saw)] && $::DSx_settings(bean_weight) > 0 } {
			set settings(next_drink_weight) [round_to_one_digits $::DSx_settings(saw)]
		}
	} elseif { $skin eq "MimojaCafe" } {
		if { [return_zero_if_blank $::settings(grinder_dose_weight)] > 0 && $settings(next_grinder_dose_weight) != $::settings(grinder_dose_weight) } {
			set settings(next_grinder_dose_weight) [round_to_one_digits $::settings(grinder_dose_weight)]
		}
		if { [::device::scale::expecting_present] } {
			if {$::settings(settings_profile_type) eq "settings_2c"} {
				if { [return_zero_if_blank $::settings(final_desired_shot_weight_advanced)] > 0  && 
						$settings(next_drink_weight) != $::settings(final_desired_shot_weight_advanced) } {
					set settings(next_drink_weight) [round_to_one_digits $::settings(final_desired_shot_weight_advanced)]
				}
			} else {
				if { [return_zero_if_blank $::settings(final_desired_shot_weight)] > 0 && \
						$settings(next_drink_weight) != $::settings(final_desired_shot_weight) } {
					set settings(next_drink_weight) [round_to_one_digits $::settings(final_desired_shot_weight)]
				}
			}
		}
		if { [return_zero_if_blank $::settings(grinder_setting)] > 0 && $settings(next_grinder_setting) ne $::settings(grinder_setting) } {
			set settings(next_grinder_setting) $::settings(grinder_setting)
		}
	}
	
	foreach field [concat [metadata fields -domain shot -category description -propagate 1] espresso_notes grinder_setting] {
		set type [metadata get $field data_type]
		if { ($type eq "number" || $field eq "grinder_setting") && $settings(next_$field) eq "" } {
			set ::settings($field) 0
		} else {
			set ::settings($field) $settings(next_$field)
		}
	}

#	if { $skin eq "DSx" } {
#		if { [info exists ::DSx_settings(live_graph_beans)] && $::DSx_settings(live_graph_beans) > 0 } {
#			set ::settings(grinder_dose_weight) $::DSx_settings(live_graph_beans)
#		} elseif { [info exists ::DSx_settings(bean_weight)] && $::DSx_settings(bean_weight) > 0 } {
#			set ::settings(grinder_dose_weight) [round_to_one_digits [return_zero_if_blank $::DSx_settings(bean_weight)]]
#		} else {
#			set ::settings(grinder_dose_weight) 0
#		}
#	}
	
	set settings(next_espresso_notes) {}
	set settings(next_modified) 0
	
	
#	if { $::undroid == 1 } {		
#		if { $skin eq "DSx" && [info exists ::DSx_settings(saw)] && $::DSx_settings(saw) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::DSx_settings(saw)] 
#		} elseif { [info exists ::settings(final_desired_shot_weight)] && $::settings(final_desired_shot_weight) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::settings(final_desired_shot_weight)]
#		} elseif { $skin eq "MimojaCafe" && [info exists ::settings(final_desired_shot_volume_advanced)] && 
#				$::settings(final_desired_shot_volume_advanced) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::settings(final_desired_shot_volume_advanced)]
#		} else {
#			set ::settings(drink_weight) 0
#		}
#	} else {
#		if { $skin eq "DSx" && [info exists ::DSx_settings(live_graph_weight)] && $::DSx_settings(live_graph_weight) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::DSx_settings(live_graph_weight)]
#		# Don't use de1(scale_sensor_weight)? If bluetooth scale disconnects then this is set to the previous shot weight
#		} elseif { $::de1(scale_sensor_weight) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::de1(scale_sensor_weight)]
#		} elseif { $skin eq "DSx" && [info exists ::DSx_settings(saw)] && $::DSx_settings(saw) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::DSx_settings(saw)] 
#		} elseif { [info exists ::settings(final_desired_shot_weight)] && $::settings(final_desired_shot_weight) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::settings(final_desired_shot_weight)]
#		} elseif { $skin eq "MimojaCafe" && [info exists ::settings(final_desired_shot_volume_advanced)] && 
#				$::settings(final_desired_shot_volume_advanced) > 0 } {
#			set ::settings(drink_weight) [round_to_one_digits $::settings(final_desired_shot_volume_advanced)]
#		} else {
#			set ::settings(drink_weight) 0
#		}
#	}

	define_last_shot_desc
	define_next_shot_desc
	
	# Settings already saved in reset_gui_starting_espresso, but as we have redefined them...
	::save_settings
	plugins save_settings DYE
}

# Hook executed after save_espresso_rating_to_history
# TBD: NO LONGER NEEDED? define_last_shot_desc ALREADY DONE in reset_gui_starting_espresso_leave_hook,
#	only useful if this is invoked from Insight's original Godshots/Describe Espresso pages.
proc ::plugins::DYE::save_espresso_to_history_hook { args } {
	msg -INFO [namespace current] save_espresso_to_history_hook
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
# BEWARE this should ONLY be invoked just after finishing a shot, otherwise the settings variables may contain
# 	the plan for the next shot instead of the last one.
proc ::plugins::DYE::define_last_shot_desc { args } {
	variable settings
	if { $::plugins::DYE::settings(show_shot_desc_on_home) == 1 } {
		if { $::settings(history_saved) == 1 } {		
			set settings(last_shot_desc) [shot_description_summary $::settings(bean_brand) \
				$::settings(bean_type) $::settings(roast_date) $::settings(grinder_model) \
				$::settings(grinder_setting) $::settings(drink_tds) $::settings(drink_ey) \
				$::settings(espresso_enjoyment) 3]
		} else {
			set settings(last_shot_desc) "\[ [translate {Shot not saved to history}] \]"
		}
	} else {
		set settings(last_shot_desc) ""
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
	
	if { $settings(show_shot_desc_on_home) == 1 && [info exists settings(next_bean_brand)] } {
		set desc [shot_description_summary $settings(next_bean_brand) \
			$settings(next_bean_type) $settings(next_roast_date) $settings(next_grinder_model) \
			$settings(next_grinder_setting) {} {} {} 2 "\[Tap to describe the next shot\]" ]
		if { $settings(next_modified) == 1 } { append desc " *" }
		set settings(next_shot_desc) $desc
	} else {
		set settings(next_shot_desc) ""
	}
}

# Returns an array with the same structure as ::plugins::SDB::load_shot but with the data for next shot, taken from
# the global and DYE settings. Data that doesn't apply to a "next" shot gets an empty string as value, or 0.0 for series.
# This is used so we can easily use the returned array as the source for DYE pages.
# TODO: REMOVE? NOT NEEDED ANYMORE?
proc ::plugins::DYE::load_next_shot { } {
	array set shot_data {
		comes_from_archive 0
		path {}
		filename {}
		file_modification_date {}
		clock {}
		date_time {}
		local_time {}
		espresso_elapsed {0.0}
		extraction_time 0.0
		espresso_pressure {0.0}
		espresso_weight {0.0}
		espresso_flow {0.0}
		espresso_flow_weight {0.0} 
		espresso_temperature_basket {0.0}
		espresso_temperature_mix {0.0}
		espresso_flow_weight_raw {0.0}
		espresso_water_dispensed {0.0} 
		espresso_temperature_goal {0.0}
		espresso_pressure_goal {0.0}
		espresso_flow_goal {0.0}
		espresso_state_change {0.0}
		repository_links {}
	}
		
	#set text_fields [::plugins::SDB::field_names "category text long_text date" "shot"]
	foreach field_name [metadata fields -domain shot -category description -data_type "category text long_text complex"] {
		if { [info exists ::plugins::DYE::settings(next_$field_name)] } {
			set shot_data($field_name) [string trim $::plugins::DYE::settings(next_$field_name)]
		} else {
			set shot_data($field_name) {}
		}
	}
	#[::plugins::SDB::field_names "numeric" "shot"]
	foreach field_name [metadata fields -domain shot -category description -data_type "number boolean"] {
		if { [info exists ::plugins::DYE::settings(next_$field_name)] && $::plugins::DYE::settings(next_$field_name) > 0 } {
			set shot_data($field_name) $::plugins::DYE::settings(next_$field_name)
		} else {
			# We use {} instead of 0 to get DB NULLs and empty values in entry textboxes
			set shot_data($field_name) {}
		}
	}

msg "DYE LOAD_NEXT_SHOT shot_data(drink_weight)=$shot_data(drink_weight)"	
msg "DYE LOAD_NEXT_SHOT ::settings(final_desired_shot_volume_advanced)=$::settings(final_desired_shot_volume_advanced)"	
	if { $::settings(skin) eq "MimojaCafe" && $::settings(final_desired_shot_volume_advanced) > 0 } {		
		set shot_data(drink_weight) [round_to_one_digits $::settings(final_desired_shot_volume_advanced)]
	} elseif { $::settings(skin) eq "DSx" && [info exists ::DSx_settings(saw)] && $::DSx_settings(saw) > 0 } {
		set shot_data(drink_weight) [round_to_one_digits $::DSx_settings(saw)]
	}
msg "DYE LOAD_NEXT_SHOT shot_data(drink_weight)=$shot_data(drink_weight)"	
	foreach field_name {app_version firmware_version_number enabled_plugins skin skin_version profile_title beverage_type} {
		if { [info exists ::settings($field_name)] } {
			set shot_data($field_name) $::settings($field_name)
		} else {
			set shot_data($field_name) {}
		}
	}
	
#	if { $shot_data(grinder_dose_weight) eq "" } {
#		if {[info exists file_sets(DSx_bean_weight)] == 1} {
#			set shot_data(grinder_dose_weight) $file_sets(DSx_bean_weight)
#		} elseif {[info exists file_sets(dsv4_bean_weight)] == 1} {
#			set shot_data(grinder_dose_weight) $file_sets(dsv4_bean_weight)
#		} elseif {[info exists file_sets(dsv3_bean_weight)] == 1} {
#			set shot_data(grinder_dose_weight) $file_sets(dsv3_bean_weight)
#		} elseif {[info exists file_sets(dsv2_bean_weight)] == 1} {
#			set shot_data(grinder_dose_weight) $file_sets(dsv2_bean_weight)
#		}
#	}
	
	return [array get shot_data]
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
	
    set ::plugins::visualizer_upload::settings(last_action) "upload"
	set ::plugins::visualizer_upload::settings(last_upload_shot) $clock
	set ::plugins::visualizer_upload::settings(last_upload_result) ""
	set ::plugins::visualizer_upload::settings(last_upload_id) ""
    
	set repo_link ""
	set visualizer_id [::plugins::visualizer_upload::upload $content]
	if { $visualizer_id ne "" } {
		set link [::plugins::visualizer_upload::id_to_url $visualizer_id browse]
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

proc ::plugins::DYE::page_skeleton { page {title {}} {titlevar {}} {done_button yes} {cancel_button yes} {buttons_loc right} \
		{buttons_style dsx_done} } {
	if { $title ne "" } {
		dui add dtext $page 1280 60 -text $title -tags page_title -style page_title 
	} elseif { $titlevar ne "" } {
		dui add variable $page 1280 60 -textvariable $titlevar -tags page_title -style page_title
	}

	set done_button [string is true $done_button]
	set cancel_button [string is true $cancel_button]
	set button_width [dui aspect get dbutton bwidth -style $buttons_style -default 220]
	
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

	if { $buttons_style eq "insight_ok" } {
		set y 1460
	} else {
		set y 1425
	}
	if { $cancel_button } {
		dui add dbutton $page $x_cancel $y -label [translate Cancel] -tags page_cancel -style $buttons_style
	}
	if { $done_button } {
		dui add dbutton $page $x_done $y -label [translate Ok] -tags page_done -style $buttons_style
	}
}

proc ::plugins::DYE::import_profile_from_shot { shot_clock } {
	array set shot [::plugins::SDB::load_shot $shot_clock 0 0 1]
	if { [array size shot] == 0 } {
		msg -WARNING [namespace current] import_profile_from_shot: "shot file for '$shot_clock' not found"
		return 0
	}

	foreach fn [concat profile profile_filename profile_to_save original_profile_title [::profile_vars]] { 
		set ::settings($fn) $shot($fn)
	}
	set ::settings(profile_has_changed) 1
	set ::settings(profile_hide) 0
	
	fill_profiles_listbox
	update_de1_explanation_chart
	profile_has_changed_set_colors
	
	::save_settings	
	return 1
}

proc ::plugins::DYE::import_profile_from_visualizer { vis_shot } {
	if { ![dict exists $vis_shot profile] } {
		msg -WARNING [namespace current] import_profile_from_visualizer: "'profile' field not found on downloaded shot"
		return 0
	}
	
	array set profile [dict get $vis_shot profile]
	
	foreach fn [::profile_vars] {
		if { [info exists profile($fn)] } {
			#msg -INFO "SETTINGS($fn)=$profile($fn)"
			set ::settings($fn) $profile($fn)
		} else {
			msg -WARNING [namespace current] import_profile_from_visualizer: "field '$fn' not found on downloaded profile"
		}
	}
	
	# ensure the profile is saved under the new name and not duplicated if saved several times
	set ::settings(profile_filename) "Visualizer__$profile(profile_filename)"
	set ::settings(original_profile_title) $profile(profile_title)
	set ::settings(profile_to_save) $profile(profile_title)
	
	set ::settings(profile_has_changed) 1
	set ::settings(profile_hide) 0
	
	fill_profiles_listbox
	update_de1_explanation_chart
	profile_has_changed_set_colors
	
	::save_settings	
	return 1
}

proc ::plugins::DYE::singular_or_plural { value singular plural } {
	set str "$value "
	if { $value == 1 } {
		append str [translate $singular]
	} else {
		append str [translate $plural]
	}
	return $str
}

# aclock must be in SECONDS
proc ::plugins::DYE::relative_date { aclock {ampm {}} } {
	set reldate {}
	set now [clock seconds]

	set yesterday_threshold [clock scan [clock format $now -format {%Y%m%d 00:00:00}] -format {%Y%m%d %H:%M:%S}]
	set 2days_threshold [clock scan [clock format [clock add $now -24 hours] -format {%Y%m%d 00:00:00}] -format {%Y%m%d %H:%M:%S}]
	
	if { $ampm eq {} } {
		set ampm [value_or_default ::settings(enable_ampm) 0]
	}	
	if { [string is true $ampm] } {
		set hourformat "%I:%M %p"
	} else {
		set hourformat "%H:%M"
	}
	
	if { $aclock >= $yesterday_threshold } {		
		set mindiff [expr {int(($now-$aclock)/60.0)}]
		if { $mindiff < 60 } {
			set reldate [singular_or_plural $mindiff {minute ago} {minutes ago}]
		} else {
			set hourdiff [expr {$mindiff/60}]
			set reldate [singular_or_plural $hourdiff {hour} {hours}]
				
			set mindiff [expr {$mindiff-($hourdiff*60)}]
			if { $mindiff == 0 } {
				append reldate " [translate {ago}]"
			} else {
				append reldate " [singular_or_plural $mindiff {minute ago} {minutes ago}]"
			}
		}
	} elseif { $aclock >= $2days_threshold } {
		set reldate "[translate {Yesterday at}] [clock format $aclock -format $hourformat]"
	} else {
		set daysdiff [expr {int(($yesterday_threshold-$aclock)/(60.0*60.0*24.0))+1}]
		if { $daysdiff < 31 } {
			set reldate "[singular_or_plural $daysdiff {day ago} {days ago}] [translate at] [clock format $aclock -format $hourformat]"
		} else {
			set reldate [clock format $aclock -format "%b %d %Y $hourformat"]
		}
	}

	return $reldate
}

## Adapted from Damian's DSx last_shot_date. 
#proc ::dui::pages::DYE::formatted_shot_date {} {
#	variable data
#	set shot_clock $data(clock)
#	if { $shot_clock eq "" || $shot_clock <= 0 } {
#		return ""
#	}
#	
#	set date [clock format $shot_clock -format {%a %d %b}]
#	if { [ifexists ::settings(enable_ampm) 0] == 0} {
#		set a [clock format $shot_clock -format {%H}]
#		set b [clock format $shot_clock -format {:%M}]
#		set c $a
#	} else {
#		set a [clock format $shot_clock -format {%I}]
#		set b [clock format $shot_clock -format {:%M}]
#		set c $a
#		regsub {^[0]} $c {\1} c
#	}
#	if { $::settings(enable_ampm) == 1 } {
#		set pm [clock format $shot_clock -format %P]
#	} else {
#		set pm ""
#	}
#	return "$date $c$b$pm"
#}

proc ::plugins::DYE::format_date { aclock {relative {}} {ampm {}} } {
	variable settings
	
	if { $relative eq {} } {
		set relative [value_or_default ::plugins::DYE::settings(relative_dates) 0]
	}
	if { $ampm eq {} } {
		set ampm [value_or_default ::settings(enable_ampm) 0]
	}
	
	if { [string is true $relative] } {
		return [relative_date $aclock]
	} else {		
		if { [string is true $ampm] } {
			set hourformat $settings(time_output_format_ampm)
		} else {
			set hourformat $settings(time_output_format)
		}
		return [clock format $aclock -format "$settings(date_output_format) $hourformat"]
	}
}


proc ::plugins::DYE::open { args } {
	variable settings
	
	if { [llength $args] == 1 } {
		set use_dye_v3 0
		set which_shot [lindex $args 0]
		set args {}
	} elseif { [llength $args] > 1 } {
		if { [string range [lindex $args 0] 0 0] ne "-" } {
			set which_shot [lindex $args 0]
			set args [lrange $args 1 end]
		} else {
			set which_shot [dui::args::get_option -which_shot "default" 1]
		}
		set use_dye_v3 [string is true [dui::args::get_option -use_dye_v3 [value_or_default ::plugins::DYE::settings(use_dye_v3) 0] 1]]		 
	}
	
	if { $which_shot eq {} || $which_shot eq "default" } {
		set which_shot $settings(default_launch_action) 
	}
	
	set dlg_coords [dui::args::get_option -coords {2400 975} 1]
	set dlg_anchor [dui::args::get_option -anchor "e" 1]
	
	if { $use_dye_v3 } {	
		dui page load DYE_v3 -which_shot $which_shot {*}$args 
	} elseif { $which_shot eq "dialog" } {
		dui page open_dialog dye_which_shot_dlg -coords $dlg_coords -anchor $dlg_anchor {*}$args
	} else {
		dui page load DYE $which_shot {*}$args
	}
}

### "DESCRIBE YOUR ESPRESSO" PAGE #####################################################################################

namespace eval ::dui::pages::DYE {
	variable widgets
	array set widgets {}
	
	# Widgets in the page bind to variables in this data array, not to the actual global variables behind, so they 
	# can be changed dynamically to load and save to different shots (last, next or those selected in the left or 
	# right of the history viewer). Values are actually saved only when tapping the "Done" button.
	# describe_which_shot: next / current / past / DSx_past / DSx_past2	
	variable data
	array set data {		
		page_title {Describe your last espresso}
		describe_which_shot {current}
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
		visualizer_status_label {}
		repository_links {}
		warning_msg {}
		apply_action_to {beans equipment ratio people}
		days_offroast_msg {}
	}
	#		other_equipment {}

	# src_data contains a copy of the source data when the page is loaded. So we can easily check whether something
	# has changed.
	variable src_data
	array set src_data {}
	# If editing the next shot description, remember whether it was modified originally, to be able to restore the
	# value in case the changes are cancelled.
	variable src_next_modified 0
}

proc ::dui::pages::DYE::setup {} {
	variable data
	variable widgets
	set page [namespace tail [namespace current]]
	regsub -all { } $::settings(skin) "_" skin
	
	#::plugins::DYE::page_skeleton $page "" "" yes no center insight_ok
	dui add variable $page 1280 60 -tags page_title -style page_title -command {%NS::toggle_title}
	
	dui add variable $page 1280 125 -textvariable {[::dui::pages::DYE::propagate_state_msg]} -tags propagate_state_msg \
		-anchor center -justify center -font_size -3
	
	# NAVIGATION
	set x_left_label 100; set y 40; set hspace 110
	
	dui add dbutton $page 0 0 200 175 -tags move_backward -symbol backward -symbol_pos {0.7 0.4} -style dye_main_nav_button  
	#dui add symbol $page $x_left_label $y -symbol backward -tags move_backward -style dye_main_nav_button -command yes
	
	dui add dbutton $page 200 0 350 175 -tags move_forward -symbol forward -symbol_pos {0.5 0.4} -style dye_main_nav_button
#	dui add symbol $page [expr {$x_left_label+$hspace}] $y -symbol forward -tags move_forward -style dye_main_nav_button \
#		-command yes
	
	dui add dbutton $page 350 0 550 175 -tags move_to_next -symbol fast-forward -symbol_pos {0.35 0.4} -style dye_main_nav_button
#	dui add symbol $page [expr {$x_left_label+$hspace*2}] $y -symbol fast-forward -tags move_to_next -style dye_main_nav_button \
#		-command yes

	set x_right 2360
	dui add dbutton $page 2360 0 2560 175 -tags open_history_viewer -symbol history -symbol_pos {0.35 0.4} -style dye_main_nav_button
#	dui add symbol $page $x_right $y -symbol history -tags open_history_viewer -style dye_main_nav_button -command yes
	
	dui add dbutton $page 2210 0 2360 175 -tags search_shot -symbol search -symbol_pos {0.5 0.4} -style dye_main_nav_button
#	dui add symbol $page [expr {$x_right-$hspace}] $y -symbol search -tags search_shot -style dye_main_nav_button \
#		-command yes

	dui add dbutton $page 2010 0 2210 175 -tags select_shot -symbol list -symbol_pos {0.6 0.4} -style dye_main_nav_button
#	dui add symbol $page [expr {$x_right-$hspace*2}] $y -symbol list -tags select_shot -style dye_main_nav_button \ 
#		-command yes
	
	# LEFT COLUMN 
	set x_left_field 400; set width_left_field 28; set x_left_down_arrow 990
	
	# BEANS DATA
	dui add image $page $x_left_label 150 "bean_${skin}.png" -tags beans_img
	dui add dtext $page $x_left_field 250 -text [translate "Beans"] -tags beans_header -style section_header \
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
	dui add entry $page $x_left_field $y -tags roast_date -width [expr {$width_left_field/2}] \
		-label [translate [::plugins::SDB::field_lookup roast_date name]] -label_pos [list $x_left_label $y]
	bind $widgets(roast_date) <Leave> [list + [namespace current]::compute_days_offroast]
	
	dui add variable $page [expr {$x_left_field+400}] $y -tags days_offroast_msg
	bind $widgets(roast_date) <Configure> [list ::dui::item::relocate_text_wrt DYE days_offroast_msg roast_date e 30 0 w]
		
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
	dui add dtext $page $x_left_field [expr {$y+130}] -text [translate "Equipment"] -style section_header
			
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
	dui add dtext $page 1550 250 -text [translate "Extraction"] -style section_header

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
	dui add dtext $page $x_right_label [expr {$y+6}] -text [translate "Total Dissolved Solids (TDS)"] -tags {drink_tds_label drink_tds*}
	dui add dclicker $page [expr {$x_right_field+300}] $y -bwidth 610 -bheight 75 -tags drink_tds \
		-labelvariable {$%NS::data(drink_tds)%} -style dye_double \
		-min $min -max $max -default $default -n_decimals $n_decimals -smallincrement $smallinc -bigincrement $biginc \
		-editor_page yes -editor_page_title [translate "Edit Total Dissolved Solids (%%)"] -callback_cmd %NS::calc_ey_from_tds
	#bind $widgets(drink_tds) <FocusOut> ::dui::pages::DYE::calc_ey_from_tds
	
	# Extraction Yield
	incr y 100
	lassign [::plugins::SDB::field_lookup drink_ey {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_decimals min max default smallinc biginc
	dui add dtext $page $x_right_label [expr {$y+6}] -text [translate "Extraction Yield (EY)"] -tags {drink_ey_label drink_ey*}
	dui add dclicker $page [expr {$x_right_field+300}] $y -bwidth 610 -bheight 75 -tags drink_ey \
		-labelvariable {$%NS::data(drink_ey)%} -style dye_double \
		-min $min -max $max -default $default -n_decimals $n_decimals -smallincrement $smallinc -bigincrement $biginc \
		-editor_page yes -editor_page_title [translate "Edit Extraction Yield (%%)"]
	
	# Enjoyment entry with horizontal clicker
	incr y 100
	lassign [::plugins::SDB::field_lookup espresso_enjoyment {n_decimals min_value max_value default_value small_increment big_increment}] \
		n_decimals min max default smallinc biginc
	dui add dtext $page $x_right_label [expr {$y+6}] -text [translate "Enjoyment (0-100)"] -tags espresso_enjoyment_label
		
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
	dui add multiline_entry $page $x_right_field $y -tags espresso_notes -height 5 -canvas_width 900 -label_width 245 \
		-label [translate [::plugins::SDB::field_lookup espresso_notes name]] -label_pos [list $x_right_label $y]

	# PEOPLE
	set y 1030
	dui add image $page $x_right_label $y "people_${skin}.png" -tags people_img
	dui add dtext $page $x_right_field [expr {$y+140}] -text [translate "People"] -style section_header 
		
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
	dui add dbutton $page 1280 1460 -label [translate Done] -tags page_done -style insight_ok -anchor n
	
	set y 1415 	
	dui add dbutton $page 100 $y -tags edit_dialog -style dsx_settings -symbol chevron-up -label [translate "Edit data"] -bheight 160
	
	dui add dbutton $page 2440 $y -anchor ne -tags visualizer_dialog -style dsx_settings -symbol chevron-up -symbol_pos {0.8 0.45} \
		-label [translate "Visualizer"] -label_pos {0.35 0.45} -label1variable visualizer_status_label -label1_pos {0.5 0.8} \
		-label1_anchor center -label1_justify center -label1_font_size -3 -bheight 160
	
	dui add variable $page 2420 1390 -tags warning_msg -style remark -anchor e -justify right -initial_state hidden
}

# 'which_shot' can be either a clock value matching a past shot clock, or any of 'current', 'next', 'DSx_past' or 
#	'DSx_past2'.
proc ::dui::pages::DYE::load { page_to_hide page_to_show {which_shot default} } {
	variable data
	
	ifexists ::settings(espresso_clock) 0
	set current_clock $::settings(espresso_clock)
		
	if { $which_shot eq {} || $which_shot eq "default" } {
		set which_shot $::plugins::DYE::settings(default_launch_action)
	}
	if { $which_shot eq "dialog" } {
		set which_shot last
	}
	
	set data(describe_which_shot) $which_shot
	if { [string is integer $which_shot] && $which_shot > 0 } {
		if { $which_shot == $current_clock } {
			set data(describe_which_shot) "current"
		} else {
			set data(describe_which_shot) "past"
		}
		set data(clock) $which_shot
	} elseif { $which_shot in {last current} } {
		set which_shot "current"
		set data(describe_which_shot) "current"
		set data(clock) $current_clock
#		if { $current_clock == 0 } {
#			info_page [translate "Last shot is not available to describe"] [translate Ok]
#			return
#		} else {
#			set data(clock) $current_clock
#		}
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

	load_description
#	if { ![load_description] } {
#		info_page [translate "The requested shot description for '$which_shot' is not available"] [translate Ok]
#		return 0
		#set data()
#	}
	
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
	
	if { $is_not_next && $data(path) eq {} } {
		# Past shot that was not saved to history
		set fields {beans_select edit_dialog* visualizer_dialog* espresso_enjoyment_rater* espresso_enjoyment_label}
		foreach f [metadata fields -domain shot -category description] {
			lappend fields $f*
		}
		dui item disable $page_to_show $fields
	} else {
		# Next shot
		# Removed from cond_fields: grinder_dose_weight* drink_weight* 
		set cond_fields {move_forward move_to_next drink_tds* drink_ey* 
			espresso_enjoyment* espresso_enjoyment_rater* espresso_enjoyment_label}
		set fields {beans_select edit_dialog* espresso_enjoyment_rater* espresso_enjoyment_label}
		foreach f [metadata fields -domain shot -category description] {
			if { "$f*" ni $cond_fields } {
				lappend fields $f*
			}
		}
		dui item enable $page_to_show $fields
		
		dui item enable_or_disable $is_not_next $page_to_show $cond_fields
	}
	
	if { $is_not_next } {
		set previous_shot [::plugins::SDB::previous_shot $data(clock)]
		dui item enable_or_disable [expr {$previous_shot ne ""}] $page_to_show "move_backward*"
		
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

# Ensure the shot description is saved if it has been modified and we're leaving the page unexpectedly, for example
# 	if a GHC button is tapped while editing the shot, or the machine is starting up.
# ALWAYS saves the shot changes when the page is hidden, EXCEPT if the Cancel button has been clicked.
# Because we save here, we don't need to save explicitly when leaving the page, EXCEPT if we're loading a new shot
#	in the same page (e.g. when navigation buttons are clicked).
proc ::dui::pages::DYE::hide { page_to_hide page_to_show } {
	variable data

	save_description
	dui say [translate "Saved"] ""
}

proc ::dui::pages::DYE::toggle_title { } {
	set ::plugins::DYE::settings(relative_dates) [expr {!$::plugins::DYE::settings(relative_dates)}]
	define_title
	plugins save_settings DYE
}

proc ::dui::pages::DYE::propagate_state_msg {} {
	variable data
	set page [namespace tail [namespace current]]
	
	dui item config $page propagate_state_msg -fill [dui aspect get dtext fill -theme [dui page theme $page]]
	if { $data(describe_which_shot) eq "next" } {
		if { ![string is true $::plugins::DYE::settings(propagate_previous_shot_desc)] } {
			return [translate "Propagation is disabled"]
		} elseif { [string is true $::plugins::DYE::settings(next_modified)] } {
			return [translate "Next shot description manually edited, changes in last shot won't propagate here"]
		} else {
			return [translate "Changes in last shot metadata will propagate here"]
		}
	} elseif { $data(path) eq {} } {
		dui item config $page propagate_state_msg -fill [dui aspect get dtext fill -theme [dui page theme $page] -style error]
		return [translate "Shot not saved to history"]
	} elseif { $data(describe_which_shot) eq "current" || $data(clock) == $::settings(espresso_clock) } {
		if { ![string is true $::plugins::DYE::settings(propagate_previous_shot_desc)] } {
			return [translate "Propagation is disabled"]
		} elseif { [string is true $::plugins::DYE::settings(next_modified)] } {
			return [translate "Next shot description manually edited, changes here won't propagate to next"]
		} else {
			return [translate "Changes here will propagate to next shot"]
		}
	} else {
		return ""
	}	
}

proc ::dui::pages::DYE::move_backward {} {
	variable data
	save_description

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
	
	save_description
	
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
	save_description
	dui page load DYE next -reload yes
}

proc ::dui::pages::DYE::search_shot {} {
	dui page open_dialog DYE_fsh -page_title [translate "Select the shot to describe"] \
		-return_callback [namespace current]::search_shot_callback -theme [dui theme get]
}

proc ::dui::pages::DYE::search_shot_callback { selected_shots matched_shots } {
	if { [llength $selected_shots] > 0 } {
		dui page load DYE [lindex $selected_shots 0] -reload yes
	}
}

proc ::dui::pages::DYE::select_shot {} {
	array set shots [::plugins::SDB::shots "clock shot_desc" 1 {} 500]
	if { [array size shots] > 0 } {
		dui page open_dialog dui_item_selector {} $shots(shot_desc) -values_ids $shots(clock) -listbox_width 2300 \
			-page_title [translate "Select the shot to describe"] -return_callback [namespace current]::select_shot_callback \
			-theme [dui theme get]
	}
}

proc ::dui::pages::DYE::select_shot_callback { shot_desc shot_id args } {
	variable data

	if { [llength $shot_id] > 0 } {
		dui page load DYE [lindex $shot_id 0] -reload yes
	}
}

proc ::dui::pages::DYE::open_history_viewer {} {
	if { $::settings(skin) eq "DSx" } {
		::history_prep
	} else {
		history_viewer open -callback_cmd ::dui::pages::DYE::history_viewer_callback
	}
}

proc ::dui::pages::DYE::history_viewer_callback { left_clock right_clock } {
	variable data
	
#	if { $left_clock eq "" } { 
#		dui page show DYE
#	} else {
#		set previous_page $data(previous_page)
#		dui page load DYE [lindex $left_clock 0]
#		set data(previous_page) $previous_page
#	}
	
	if { $left_clock ne "" } { 
		dui page load DYE [lindex $left_clock 0]
	}
	
}

proc ::dui::pages::DYE::beans_select {} {
	variable data
	say "" $::settings(sound_button_in)
	
	set selected [string trim "$data(bean_brand) $data(bean_type) $data(roast_date)"]
	regsub -all " +" $selected " " selected

	dui page open_dialog dui_item_selector {} [::plugins::SDB::available_categories bean_desc] -theme [dui theme get] \
		-page_title "Select the beans batch" -selected $selected -return_callback [namespace current]::select_beans_callback \
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

proc ::dui::pages::DYE::compute_days_offroast {} {
	variable data
	set roast_date [string trim $data(roast_date)]
	if { $roast_date eq "" } {
		set data(days_offroast_msg) ""
		return
	} 
		
	set input_formats $::plugins::DYE::settings(date_input_formats)
	if { "" ni $input_formats } {
		lappend input_formats ""
	}
	
	set roast_clock ""
	set i 0
	set fmt [lindex $input_formats 0]
	while { $i < [llength $input_formats] && $roast_clock eq "" } {
		try { 
			if { $fmt eq "" } {
				set roast_clock [clock scan $roast_date]
			} else {
				set roast_clock [clock scan $roast_date -format $fmt]
			}
		} on error err {}
		
		incr i
		set fmt [lindex $input_formats $i]
	}
	
	if { $roast_clock eq "" } {
		set data(days_offroast_msg) ""
		msg -NOTICE [namespace current] compute_days_offroast: "can't parse roast date '$data(roast_date)'"
	} else {
		if { $data(describe_which_shot) eq "next" } {
			set ref [clock seconds]
		} elseif { $data(clock) ne {} && $data(clock) > 0 } {
			set ref $data(clock)
		} else {
			set data(days_offroast_msg) ""
			return
		}
		
		set days [expr {int(($ref-$roast_clock)/(24.0*60.0*60.0))}]
		set data(days_offroast_msg) [::plugins::DYE::singular_or_plural $days {day off-roast} {days off-roast}]
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

	dui page open_dialog dui_item_selector ::dui::pages::DYE::data(grinder_setting) -theme [dui theme get] \
		[::plugins::SDB::available_categories grinder_setting 1 " grinder_model=[::plugins::SDB::string2sql $data(grinder_model)]"] \
		-page_title [translate "Select the grinder setting"] -selected $data(grinder_setting) -listbox_width 700 
}

proc ::dui::pages::DYE::grinder_model_change {} {
	variable data
	
	dui item enable_or_disable [expr {$data(grinder_model) ne ""}] [namespace tail [namespace current]] grinder_setting-dda
}

proc ::dui::pages::DYE::field_in_apply_to { field apply_to } {
	set section [metadata get $field section]
	return [expr { $apply_to eq {} || $section in $apply_to || ($field eq "espresso_notes" && "note" in $apply_to) ||
		($section eq "beans_batch" && "beans" in $apply_to) || 
		("ratio" in $apply_to && $field in {grinder_dose_weight drink_weight})}]
}

proc ::dui::pages::DYE::clear_shot_data { {apply_to {}} } {
	variable data
	
	dui say "clear" sound_button_in
	foreach fn [concat [metadata fields -domain shot -category description -propagate 1] drink_weight espresso_notes] {
		if { [field_in_apply_to $fn $apply_to] } {
			set data($fn) {}
		}
	}
	# Why commented?
#	if { $data(describe_which_shot) eq "next" } {
#		set ::plugins::DYE::settings(next_modified) 1
#	}
}

# what = [previous] / selected
proc ::dui::pages::DYE::read_from { {what previous} {apply_to {}} } {
	variable data
	say "read" $::settings(sound_button_in)

	set read_fields [concat [metadata fields -domain shot -category description -propagate 1] drink_weight espresso_notes clock]
	
	# Next shot spec doesn't have a clock
	if { $data(clock) == 0 || $data(clock) eq {} } {
		set filter "clock < [clock seconds]"
	} else {
		set filter "clock < $data(clock)"
	}
	set sql_conditions {}
	foreach f $read_fields {
		lappend sql_conditions "LENGTH(TRIM(COALESCE($f,'')))>0"
	}
	
	if { $what eq "selected" } {
		array set shots [::plugins::SDB::shots "clock shot_desc" 1 "$filter AND ([join $sql_conditions { OR }])" 500]
		if { [array size shots] > 0 } {
			dui page open_dialog dui_item_selector {} $shots(shot_desc) -values_ids $shots(clock) \
				-page_title [translate "Select the shot to read the data from"] -theme [dui theme get] \
				-return_callback [namespace current]::select_read_from_shot_callback -listbox_width 2300
		}
	} else {
		array set last_shot [::plugins::SDB::shots $read_fields 1 "$filter AND ([join $sql_conditions { OR }])" 1]
		if { [array size last_shot] > 0 } {
			foreach f [array names last_shot] {
				if { $f ne "clock" && [field_in_apply_to $f $apply_to ] } {
					set data($f) [lindex $last_shot($f) 0]
				}
			}
			
			if { $data(describe_which_shot) eq "next" && "profile" in $apply_to } {
				::plugins::DYE::import_profile_from_shot $last_shot(clock)
			}
		}
	}
	
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
		set read_fields [concat [metadata fields -domain shot -category description -propagate 1] drink_weight espresso_notes]
		array set shot [::plugins::SDB::shots "$read_fields" 1 "clock=$shot_clock" 1]
		foreach f [array names shot] {
			if { [field_in_apply_to $f $data(apply_action_to)] } {
				set data($f) [lindex $shot($f) 0]
			}
		}
		
		if { $data(describe_which_shot) eq "next" && "profile" in $data(apply_action_to) } {
			::plugins::DYE::import_profile_from_shot $shot_clock
		}
	}
}

proc ::dui::pages::DYE::define_title {} {
	variable data
	if { $data(describe_which_shot) eq "next" } {
		set data(page_title) [translate "Plan your NEXT shot"]
	} elseif { $data(clock) eq {} || $data(clock) == 0 } {
		set data(page_title) "[translate {Describe LAST shot}]"
	} elseif { $data(describe_which_shot) eq "current" || $data(clock) == $::settings(espresso_clock) } {
		set data(page_title) "[translate {Describe LAST shot}]: [::plugins::DYE::format_date $data(clock)]"
	} else {
		set data(page_title) "[translate {Describe shot}]: [::plugins::DYE::format_date $data(clock)]"
	}
}

# Opens the last shot, the shot on the left of the history viewer, or the shot on the right of the history
# 	viewer, and writes all relevant DYE fields to the ::dui::pages::DYE page variables.
# Returns 1 if successful, 0 otherwise.
# NOTE: Originally, if opened from DSx history viewer this reads the variables from DSx shot parsed variables,
#	if opened to see the last shot it used the settings variables, and only opened and read the shot file for
#	other cases. This produced a number of problems, so was changed on 2021-09-28 to always read the shot file,
#	which avoids problems and simplifies code a lot.
proc ::dui::pages::DYE::load_description {} {
	variable widgets
	variable data
	variable src_data
	variable src_next_modified
	
	array set src_data {}

	define_title
	
	if { $data(describe_which_shot) eq "next" } {
		#set data(clock) {}
		set src_next_modified $::plugins::DYE::settings(next_modified)
		set data(path) {}

		foreach fn [metadata fields -domain shot -category description -propagate 1] {
			set src_data($fn) $::plugins::DYE::settings(next_$fn)
			set data($fn) $::plugins::DYE::settings(next_$fn)
		}
		foreach fn [metadata fields -domain shot -category description -propagate 0] {
			if { $fn eq "espresso_notes" || $fn eq "drink_weight" } {
				set src_data($fn) $::plugins::DYE::settings(next_$fn)
				set data($fn) $::plugins::DYE::settings(next_$fn)
			} else {
				set src_data($fn) {}
				set data($fn) {}
			}
		}
		
		# MimojaCafe and DSx allow you to define some variables of next shot, so we ensure they are coordinated
		# with DYE next shot description.
		if { $::settings(skin) eq "MimojaCafe" } {
			# For these fields, the definition in MC home page takes precedence over values in DYE::settings(next_*)
			if { [return_zero_if_blank $::settings(grinder_dose_weight)] > 0 } {
				set data(grinder_dose_weight) [round_to_one_digits $::settings(grinder_dose_weight)]
			}
			
			if {[::device::scale::expecting_present]} {
				if {$::settings(settings_profile_type) eq "settings_2c"} {
					if { [return_zero_if_blank $::settings(final_desired_shot_weight_advanced)] > 0 } {
						set data(drink_weight) [round_to_one_digits $::settings(final_desired_shot_weight_advanced)]
					}
				} else {
					if { [return_zero_if_blank $::settings(final_desired_shot_weight)] > 0 } {
						set data(drink_weight) [round_to_one_digits $::settings(final_desired_shot_weight)]
					}
				}
			}
			
			if { [return_zero_if_blank $::settings(grinder_setting)] > 0 } {
				set data(grinder_setting) $::settings(grinder_setting)
			}
		} elseif { $::settings(skin) eq "DSx" } {
			if { [return_zero_if_blank $::DSx_settings(bean_weight)] > 0 } {
				set data(grinder_dose_weight) [round_to_one_digits $::DSx_settings(bean_weight)]
			}			
			if { [return_zero_if_blank $::DSx_settings(saw)] > 0 } {
				set data(drink_weight) [round_to_one_digits $::DSx_settings(saw)]
			}
		}
	} else {
		set src_next_modified {}
		
		array set shot [::plugins::SDB::load_shot $data(clock)]	
		if { [array size shot] == 0 } {
			foreach fn [metadata fields -domain shot -category description] {
				set src_data($fn) {}
				set data($fn) {}
			}
			set data(path) {}
			set data(days_offroast_msg) ""
			return 0 
		} else {			
			foreach fn [metadata fields -domain shot -category description] {
				set src_data($fn) $shot($fn)
				set data($fn) $shot($fn)
			}
			set data(path) $shot(path)
		}
	}
	
	compute_days_offroast
	return 1
}

proc ::dui::pages::DYE::save_description { {force_save_all 0} } {
	variable data
	variable src_data
	array set changes {}
	
	set last_espresso_clock [value_or_default ::settings(espresso_clock) 0]
	set propagate [string is true $::plugins::DYE::settings(propagate_previous_shot_desc)]
	set next_modified [string is true $::plugins::DYE::settings(next_modified)]
	set skin $::settings(skin)
	set settings_changed 0
	set dye_settings_changed 0
	set dsx_settings_changed 0

	# Determine what to change (either all, or detect the actual changes)
	if { [string is true $force_save_all] } {
		foreach field [metadata fields -domain shot -category description] {
			if { [info exists data($field)] } {
				set changes($field) $data($field)
			}
		}
	} else {
		foreach field [metadata fields -domain shot -category description] {
			if { [info exists data($field)] } {
				if { $data($field) ne $src_data($field) } {
					set changes($field) $data($field)
				}
			}
		}	
		if { [array size changes] == 0 } {
			return 1
		}
	}
	
	if { $data(describe_which_shot) eq "next" } {
		foreach field [array names changes] {
			if { [info exists ::plugins::DYE::settings(next_$field)] } {
				set ::plugins::DYE::settings(next_modified) 1
				set ::plugins::DYE::settings(next_$field) $changes($field)
				if { ([metadata get $field propagate] || $field eq "espresso_notes") && [info exists ::settings($field)] } {
					if { $changes($field) eq "" && ([metadata get $field data_type] eq "number" || $field eq "grinder_setting") } {
						if { $field ni {grinder_dose_weight grinder_setting} } {
							set ::settings($field) 0
						}
					} else {
						set ::settings($field) $changes($field)
					}
					set settings_changed 1
					
					if { $skin eq "DSx" && $field eq "grinder_dose_weight" && [return_zero_if_blank $::settings(grinder_dose_weight)] > 0 } {
						set ::DSx_settings(bean_weight) $::settings(grinder_dose_weight)
						set dsx_settings_changed 1
					}
				} elseif { $field eq "drink_weight" } {
					if { $skin eq "MimojaCafe" } {
						if {[::device::scale::expecting_present] && [return_zero_if_blank $changes(drink_weight)] > 0 } {
							if {$::settings(settings_profile_type) eq "settings_2c"} {
								set ::settings(final_desired_shot_weight_advanced) $changes(drink_weight)
							} else {
								set ::settings(final_desired_shot_weight) $changes(drink_weight)
							}
							set settings_changed 1
						}
					} elseif { $skin eq "DSx" } {
						if { [return_zero_if_blank $changes(drink_weight)] > 0 } {
							set ::DSx_settings(saw) $changes(drink_weight) 
							set dsx_settings_changed 1
						}
					}
				}
			}
		}
		
		set ::plugins::DYE::settings(next_shot_desc) [::plugins::DYE::shot_description_summary $data(bean_brand) $data(bean_type) \
			$data(roast_date) $data(grinder_model) $data(grinder_setting) $data(drink_tds) $data(drink_ey) $data(espresso_enjoyment)]
		set dye_settings_changed 1
	} elseif { $data(path) eq {} } {
		# Past shot not properly saved to history folder
		return 1
	} else {		
		if { $data(describe_which_shot) eq "current" || $data(clock) == $last_espresso_clock } {
			foreach field [array names changes] {
				if { $propagate && !$next_modified && [metadata get $field propagate] } {
					set ::plugins::DYE::settings(next_$field) $changes($field)
					set dye_settings_changed 1
				}
								
				if { [info exists ::settings($field)] } {
					if { $changes($field) eq "" && [metadata get $field data_type] eq "number" } {
						set ::settings($field) 0
					} else {
						set ::settings($field) $changes($field)
					}
					set settings_changed 1
				}
			}
			
			set ::plugins::DYE::settings(last_shot_desc) [::plugins::DYE::shot_description_summary $data(bean_brand) $data(bean_type) \
				$data(roast_date) $data(grinder_model) $data(grinder_setting) $data(drink_tds) $data(drink_ey) $data(espresso_enjoyment)]
			if { $dye_settings_changed } {
				set ::plugins::DYE::settings(next_shot_desc) [::plugins::DYE::shot_description_summary $data(bean_brand) $data(bean_type) \
					$data(roast_date) $data(grinder_model) $data(grinder_setting) $data(drink_tds) $data(drink_ey) $data(espresso_enjoyment)]
			}
			set dye_settings_changed 1
			
			# Update data on labels in small chart on DSx home page
			if { $::settings(skin) eq "DSx" } {
				if { [return_zero_if_blank $data(grinder_dose_weight)] > 0 && \
						[value_or_default ::DSx_settings(live_graph_beans) {}] ne $data(grinder_dose_weight)} {
					set ::DSx_settings(live_graph_beans) [round_to_one_digits $data(grinder_dose_weight)]
					set dsx_settings_changed 1
				}
				if { [return_zero_if_blank $data(drink_weight)] > 0 && \
						[value_or_default ::DSx_settings(live_graph_weight) {}] ne $data(drink_weight) } {
					set ::DSx_settings(live_graph_weight) [round_to_one_digits $data(drink_weight)]
					set dsx_settings_changed 1
				}
			}
		}
		
		::plugins::SDB::modify_shot_file $data(path) changes
		
		if { $::plugins::SDB::settings(db_persist_desc) == 1 } {
			set changes(file_modification_date) [file mtime $data(path)]
			::plugins::SDB::update_shot_description $data(clock) changes
		}
		
		# Handle DSx history viewer variables
		if { $::settings(skin) eq "DSx" } {
			if { $data(clock) == [value_or_default ::DSx_settings(past_clock) 0] } {
#				This doesn't seem required (the DSx vars behind get outdated but think they aren't used for anything) 
				foreach field [array names changes] {
					if { [info exists ::DSx_settings(past_$field)] } {
						if { $changes($field) eq "" && [metadata get $field data_type] eq "number" } {
							set ::DSx_settings(past_$field) 0
						} else {
							set ::DSx_settings(past_$field) $changes($field)
						}
						set dsx_settings_changed 1
					}
					# These two don't follow the above var naming convention
					if { $field eq "grinder_dose_weight" && [return_zero_if_blank $changes($field)] > 0 } {
						set ::DSx_settings(past_bean_weight) [round_to_one_digits $changes($field)]
					}
					if { $field eq "drink_weight" && [return_zero_if_blank $changes($field)] > 0 } {
						set ::DSx_settings(drink_weight) [round_to_one_digits $data($field)]
					}
				}
			
				set ::plugins::DYE::past_shot_desc [::plugins::DYE::shot_description_summary $data(bean_brand) $data(bean_type) $data(roast_date) \
					$data(grinder_model) $data(grinder_setting) $data(drink_tds) $data(drink_ey) $data(espresso_enjoyment)]
				set ::plugins::DYE::past_shot_desc_one_line [::plugins::DYE::shot_description_summary $data(bean_brand) $data(bean_type) $data(roast_date) \
					$data(grinder_model) $data(grinder_setting) $data(drink_tds) $data(drink_ey) $data(espresso_enjoyment) 1 ""]
			}
			
			if { $data(clock) == [value_or_default ::DSx_settings(past_clock2) 0] } {
				foreach field [array names changes] {
					if { [info exists ::DSx_settings(past_${field}2)] } {
						if { $changes($field) eq "" && [metadata get $field data_type] eq "number" } {
							set ::DSx_settings(past_${field}2) 0
						} else {
							set ::DSx_settings(past_${field}2) $changes($field)
						}
						set dsx_settings_changed 1
					}
					# These two don't follow the above var naming convention
					if { $field eq "grinder_dose_weight" && [return_zero_if_blank $changes($field)] > 0 } {
						set ::DSx_settings(past_bean_weight2) [round_to_one_digits $changes($field)]
					}
					if { $field eq "drink_weight" && [return_zero_if_blank $changes($field)] > 0 } {
						set ::DSx_settings(drink_weight2) [round_to_one_digits $data($field)]
					}
				}
				
				set ::plugins::DYE::past_shot_desc2 [::plugins::DYE::shot_description_summary $data(bean_brand) $data(bean_type) $data(roast_date) \
					$data(grinder_model) $data(grinder_setting) $data(drink_tds) $data(drink_ey) $data(espresso_enjoyment)]
				set ::plugins::DYE::past_shot_desc_one_line2 [::plugins::DYE::shot_description_summary $data(bean_brand) $data(bean_type) $data(roast_date) \
					$data(grinder_model) $data(grinder_setting) $data(drink_tds) $data(drink_ey) $data(espresso_enjoyment) 1 ""]
			}
		}
	}

	if { $settings_changed } {
		::save_settings
	}
	if { $dye_settings_changed } {
		plugins save_settings DYE
	}
	if { $dsx_settings_changed } {
		::save_DSx_settings
	}
	
	return 1
}

# Undo changes, reverting all editions done since entering the page. 
# Beware that there may have been intermediate saves (when the page is hidden, e.g. for showing a dialog), so we
#	need to do exactly the reverse as save_description, going back to data in the src_data array.
proc ::dui::pages::DYE::undo_changes { {apply_to {}} } {
	variable data
	variable src_data
	variable src_next_modified
	
	set copy_src_next_modified $src_next_modified
	
	# Revert values for all fields and force-save
	foreach field [metadata fields -domain shot -category description] {
		if { [info exists data($field)] && [info exists src_data($field)]} {
			if { [field_in_apply_to $field $apply_to] } {
				set data($field) $src_data($field)
			}
		}
	}
	save_description 1
	
	if { $data(describe_which_shot) eq "next" } {
		set ::plugins::DYE::settings(src_next_modified) $copy_src_next_modified 
	}
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

# TBR: NO LONGER NEEDED
# Return 1 if some data has changed in the form, with respect to the data that was there when we originally loaded
# the shot in the page.
proc ::dui::pages::DYE::needs_saving { } {
	variable data
	variable src_data
		
	if { $data(close_action) ne {} } {
		return 0		
	}
	
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

proc ::dui::pages::DYE::edit_dialog {} {
	variable data
	dui sound make sound_button_in
	set is_next [expr {$data(describe_which_shot) eq "next"}]
	
	dui page open_dialog dye_edit_dlg $is_next [expr {!$is_next}] \
		-coords {100 1390} -anchor sw -disable_items 1 -return_callback [namespace current]::process_edit_dialog 
}

proc ::dui::pages::DYE::process_edit_dialog { {action {}} {apply_to {}} } {
	variable data
	set data(apply_action_to) $apply_to
	
	if { $action eq "clear" } {
		clear_shot_data $apply_to
	} elseif { $action eq "read_previous" } {
		read_from previous $apply_to
	} elseif { $action eq "read_selected" } {
		read_from selected $apply_to
	} elseif { $action eq "undo" } {
		undo_changes $apply_to
	}
}

proc ::dui::pages::DYE::visualizer_dialog {} {
	variable data
	dui sound make sound_button_in
	
	save_description
	set repo_link {}
	if { $data(repository_links) ne {} } {
		set repo_link [lindex $data(repository_links) 1]
	}
	dui page open_dialog dye_visualizer_dlg -coords {2440 1390} -anchor se -disable_items 1 \
		-return_callback [namespace current]::process_visualizer_dlg $data(clock) {} $repo_link
}

proc ::dui::pages::DYE::update_visualizer_button { {check_page 1} } {
	variable data
	variable widgets
	set page [namespace tail [namespace current]]
	
	if { [string is true $check_page] && [dui page current] ne $page } {
		msg "WARNING: WRONG page in update_visualizer_button='[dui page current]'"	
		return
	}

	set data(visualizer_status_label) {}
	
	if { [plugins available visualizer_upload] } {
#		if { $data(describe_which_shot) eq "next" } {
#			dui item disable $page visualizer_dialog*
#		}
		
		if { $data(describe_which_shot) eq "next" } {
			set data(visualizer_status_label) {}
		} else {
			if { $data(repository_links) ne {} } {
				set data(visualizer_status_label) [translate "Uploaded"]
			} elseif { [plugins enabled visualizer_upload] && $::plugins::visualizer_upload::settings(last_upload_shot) == $data(clock) } {
				set data(visualizer_status_label) [translate [regsub -all {[^a-zA-Z ]} [lrange $::plugins::visualizer_upload::settings(last_upload_result) 0 1] ""]]
			} else {
				set data(visualizer_status_label) [translate "Not uploaded"]
			}
		}
	} else {
		dui item hide $page visualizer_dialog* -current yes -initial yes
	}
}

# If 'apply_download_to' is not empty, that means we have downloaded a shot by code
proc ::dui::pages::DYE::process_visualizer_dlg { {repo_link {}} {downloaded_shot {}} {apply_download_to {}} } {
	variable data
	
	if { $repo_link ne {} && $data(repository_links) eq {} } {
		set data(repository_links) [list Visualizer $repo_link]
	}
	
	if { $downloaded_shot ne {} } {
		array set categories {
			beans {bean_brand bean_type roast_date roast_level bean_notes}
			equipment {grinder_model grinder_setting}
			ratio {bean_weight drink_weight}
			other {drink_tds drink_ey espresso_enjoyment espresso_notes}
		}
			
		foreach cat [array names categories] {
			if { $apply_download_to eq {} || $cat in $apply_download_to } {
				foreach f $categories($cat) {
					set down_value [dict get $downloaded_shot $f]
					if { $f eq "bean_weight" } {
						set f "grinder_dose_weight"
					} 
					
					if { $down_value ne "null" && $down_value ne {} && $down_value ne $data($f) } {
						lassign [metadata get $f data_type] data_type
						if { $data_type eq "number" } {
							if { $down_value > 0 } {
								set data($f) [number_in_range $down_value]
							}
						}
						set data($f) $down_value
					}
				}
			}
		}
		
		if { $data(describe_which_shot) eq "next" && "profile" in $apply_download_to } {
			::plugins::DYE::import_profile_from_visualizer $downloaded_shot
		}
	}
	
	update_visualizer_button
}

# TBR: NO LONGER NEEDED
proc ::dui::pages::DYE::ask_to_save_if_needed { {action page_cancel} } {
	variable data
	
	if { [needs_saving] == 1 } {
		set data(close_action) $action
		dui page open_dialog dui_confirm_dialog -coords {0.5 0.5} -anchor center -size {1300 450} \
			-return_callback ::dui::pages::DYE::confirm_save -theme [dui theme get] \
			"You have unsaved changes to the shot description. Do you want to save your changes first?" \
			{"Save changes" "Discard changes"} -buttons_y 0.8
		return 0
	} else {
		set data(close_action) {}
		return 1
	}
}

proc ::dui::pages::DYE::page_done {} {
	variable data
	dui sound make sound_button_in
	
	# Don't need to save_description here, it is done automatically in dui::pages::DYE::hide. 
	dui page close_dialog
}

### DYE EDIT DIALOG PAGE ###########################################################################################

namespace eval ::dui::pages::dye_edit_dlg {
	variable widgets
	array set widgets {}
		
	variable data
	array set data {
		enable_profile 1
		enable_extraction 1
		settings_changed 0
		select_apply_to all
	}

	# Actions: Clear shot data, Read from last shot, Read from selected shot, Undo changes
	proc setup {} {
		variable data
		set page [namespace tail [namespace current]]
		
		set page_width [dui page width $page 0]
		set page_height [dui page height $page 0]
		set splits [dui page split_space 0 $page_height 0.3 0.1 0.1 0.1 0.1]
		
		set i 0		
		set y0 [lindex $splits $i]
		set y1 [lindex $splits [incr i]]
		
		dui add dbutton $page [expr {$page_width-120}] 0 $page_width 120 -tags close_dialog -style menu_dlg_close \
			-command dui::page::close_dialog

		dui add dtext $page 0.05 [expr {$y0+50}] -tags apply_action_to -text [translate "Apply edition to:"] \
			-style menu_dlg -font_family notosansuibold
		
		dui add dbutton $page 0.60 [expr {$y0+70}] -bwidth 0.35 -bheight 80 -anchor center -tags select_apply_to \
			-style menu_dlg -label [translate "Select all"]
		
		dui add dcheckbox $page 0.05 [expr {$y0+150}] -tags apply_to_beans -textvariable ::plugins::DYE::settings(apply_action_to_beans) \
			-style menu_dlg -label [translate "Beans"] -command { set ::dui::pages::dye_edit_dlg::data(settings_changed) 1}			
		dui add dcheckbox $page 0.30 [expr {$y0+150}] -tags apply_to_equipment -textvariable ::plugins::DYE::settings(apply_action_to_equipment) \
			-style menu_dlg -label [translate "Equipment"] -command { set ::dui::pages::dye_edit_dlg::data(settings_changed) 1}			
		dui add dcheckbox $page 0.57 [expr {$y0+150}] -tags apply_to_ratio -textvariable ::plugins::DYE::settings(apply_action_to_ratio) \
			-style menu_dlg -label [translate "Ratio"] -command { set ::dui::pages::dye_edit_dlg::data(settings_changed) 1}
		dui add dcheckbox $page 0.75 [expr {$y0+150}] -tags apply_to_extraction -textvariable ::plugins::DYE::settings(apply_action_to_extraction) \
			-style menu_dlg -label [translate "Extraction"] -command { set ::dui::pages::dye_edit_dlg::data(settings_changed) 1}
		
		dui add dcheckbox $page 0.05 [expr {$y0+260}] -tags apply_to_note -textvariable ::plugins::DYE::settings(apply_action_to_note) \
			-style menu_dlg -label [translate "Esp. Note"] -command { set ::dui::pages::dye_edit_dlg::data(settings_changed) 1}
		dui add dcheckbox $page 0.30 [expr {$y0+260}] -tags apply_to_people -textvariable ::plugins::DYE::settings(apply_action_to_people) \
			-style menu_dlg -label [translate "People"] -command { set ::dui::pages::dye_edit_dlg::data(settings_changed) 1}
		dui add dcheckbox $page 0.57 [expr {$y0+260}] -tags apply_to_profile -textvariable ::plugins::DYE::settings(apply_action_to_profile) \
			-style menu_dlg -label [translate "Profile"] -command { set ::dui::pages::dye_edit_dlg::data(settings_changed) 1}
		
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline -width 3
		
		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags clear_data -style menu_dlg_btn \
			-label [translate "Clear shot data"] -symbol eraser -command {%NS::page_close clear}
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline 

		dui add variable $page 0.5 $y1 -anchor center -justify center -width 0.8 -tags warning_msg -fill red -font_size +3 
		
		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags read_last -style menu_dlg_btn \
			-label [translate "Read from previous shot"] -symbol file-import -command {%NS::page_close read_previous}
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline

		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags read_selected -style menu_dlg_btn \
			-label "[translate {Read from selected shot}]..." -symbol file-import -command {%NS::page_close read_selected}
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline
		
		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags undo_changes -style menu_dlg_btn \
			-label [translate "Undo changes"] -symbol undo -command {%NS::page_close undo}
	}

	proc load { page_to_hide page_to_show {enable_profile 0} {enable_extraction 0} args } {
		variable data
		
		set data(enable_profile) [string is true $enable_profile]
		set data(enable_extraction) [string is true $enable_extraction]
		return 1
	}
	
	proc show { page_to_hide page_to_show } {
		variable data
		
		dui item enable_or_disable $data(enable_profile) dye_edit_dlg apply_to_profile*
		dui item enable_or_disable $data(enable_extraction) dye_edit_dlg apply_to_extraction*
	}
	
	proc select_apply_to {} {
		variable data
		variable widgets
		
		foreach what {beans equipment ratio extraction note people profile} {
			if { [dui item cget $widgets(apply_to_$what) -state] eq "normal" } {
				if { $data(select_apply_to) eq "all" } {
					set ::plugins::DYE::settings(apply_action_to_$what) 1
				} elseif { $data(select_apply_to) eq "none" } {
					set ::plugins::DYE::settings(apply_action_to_$what) 0
				} elseif { $what in {beans equipment ratio people} } {
					set ::plugins::DYE::settings(apply_action_to_$what) 1
				} else {
					set ::plugins::DYE::settings(apply_action_to_$what) 0
				}
			}
		}
		
		if { $data(select_apply_to) eq "all" } {
			dui item config $widgets(select_apply_to-lbl) -text [translate "Select none"]
			set data(select_apply_to) "none"
		} elseif { $data(select_apply_to) eq "none" } {
			dui item config $widgets(select_apply_to-lbl) -text [translate "Select default"]
			set data(select_apply_to) "default"
		} else {
			dui item config $widgets(select_apply_to-lbl) -text [translate "Select all"]
			set data(select_apply_to) "all"
		}
		
		set data(settings_changed) 1
	}
	
	proc page_hide { } {
		variable data
		if { $data(settings_changed) } {
			plugins save_settings DYE
		}
	}
	
	proc page_close { {action {}} } {
		variable data
		
		set apply_to {}
		foreach what {beans equipment ratio extraction note people profile} {
			if { $::plugins::DYE::settings(apply_action_to_$what) && \
					[dui item cget dye_edit_dlg apply_to_$what -state] eq "normal" } {
				lappend apply_to $what
			}
		}
		
		dui::page::close_dialog $action $apply_to
	}
}

### VISUALIZER DIALOG PAGE #########################################################################################

namespace eval ::dui::pages::dye_visualizer_dlg {
	variable widgets
	array set widgets {}
		
	variable data
	array set data {
		shot_clock {}
		visualizer_id {}
		repo_link {}
		upload_status_msg {}
		download_status_msg {}
		download_by_code_status_msg {}
		browse_msg {}
		warning_msg {}
		downloaded_shot {}
		download_code {}
		download_beans 1
		download_equipment 1
		download_ratio 1
		download_profile 1
		apply_download_to {}
	}

	variable qr_img
	
	proc setup {} {
		variable data
		set page [namespace tail [namespace current]]
		
		set page_width [dui page width $page 0]
		set page_height [dui page height $page 0]
		set splits [dui page split_space 0 $page_height 0.1 0.1 0.1 0.4 0.1]
		
		set i 0		
		set y0 [lindex $splits $i]
		set y1 [lindex $splits [incr i]]
		
		dui add dtext $page 0.5 [expr {int(($y1-$y0)/2)}] -tags title -style menu_dlg_title -text [translate "Choose a Visualizer action:"] 
		dui add dbutton $page [expr {$page_width-120}] 0 $page_width 120 -tags close_dialog -style menu_dlg_close
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline
		
		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags upload -style menu_dlg_btn \
			-label [translate "Upload this shot"] -symbol cloud-upload -label1variable upload_status_msg
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline -tags line_up_down

		dui add variable $page 0.5 $y1 -anchor center -justify center -width 0.8 -tags warning_msg -fill red -font_size +3 
		
		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags download -style menu_dlg_btn \
			-label [translate "Download this shot"] -symbol cloud-download -label1variable download_status_msg
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline

		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags browse -style menu_dlg_btn \
			-label "[translate {Browse shot}]..." -label_pos {0.25 0.1} -label_anchor w \
			-symbol chart-line -symbol_pos {0.15 0.1} -symbol_anchor center -symbol_justify center \
			-label1variable browse_msg -label1_pos {0.1 0.3} -label1_anchor nw -label1_width 300
				
		image create photo [namespace current]::qr_img -width [dui::platform::rescale_x 1500] \
			-height [dui::platform::rescale_y 1500]
		dui add image $page 0.5 [expr {$y0+100}] {} -tags qr
		dui item config $page qr -image [namespace current]::qr_img
	
		set w [dui add entry $page 0.85 [expr {$y0+25}] -tags download_code -width 6 -canvas_anchor ne \
			-vcmd [list [namespace current]::validate_download_code %P] -validate key]
		bind $w <KeyRelease> [namespace current]::download_code_modified
		
		dui add dcheckbox $page 0.15 [expr {$y0+140}] -tags download_beans -label [translate "Beans"] -style menu_dlg 
		dui add dcheckbox $page 0.55 [expr {$y0+140}] -tags download_equipment -label [translate "Grinder"] -style menu_dlg  
		dui add dcheckbox $page 0.15 [expr {$y0+240}] -tags download_ratio -label [translate "Ratio"] -style menu_dlg 
		dui add dcheckbox $page 0.55 [expr {$y0+240}] -tags download_profile -label [translate "Profile"] -style menu_dlg 

		dui add variable $page 0.05 [expr {$y1-160}] -anchor nw -justify left -width 0.4 -tags download_by_code_status_msg \
			-font_size -1 -style menu_dlg
				
		dui add dbutton $page 0.9 [expr {$y1-35}] -bwidth 0.4 -bheight 100 -anchor se -tags download_by_code \
			-style menu_dlg -label [translate "Download"]
		
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline
		
		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags settings -style menu_dlg_btn \
			-label "[translate {Visualizer settings}]" -symbol cogs -label1variable settings_msg
	}

	
	proc load { page_to_hide page_to_show {shot_clock {}} {visualizer_id {}} {repo_link {}} } {
		variable data
		if { ![plugins available visualizer_upload] } {
			return 0
		}
		
		set data(shot_clock) $shot_clock
		if { $visualizer_id eq {} && $repo_link ne {} } {
			set visualizer_id [file tail $repo_link]
		} 
		set data(visualizer_id) $visualizer_id

		if { $repo_link eq {} && $visualizer_id ne {} } {
			set repo_link [plugins::visualizer_upload::id_to_url $visualizer_id browse]
		}
		set data(repo_link) $repo_link
	
		set data(upload_status_msg) {}
		set data(download_status_msg) {}
		set data(download_by_code_status_msg) {}
		set data(browse_msg) {}
		set data(settings_msg) {}
		set data(warning_msg) {}
		set data(downloaded_shot) {}
		set data(download_code) {}
		set data(apply_download_to) {}
		
		if { $shot_clock eq {} } {
			# Next
			dui item config $page_to_show browse-lbl -text [translate "Download code"]
			dui item config $page_to_show browse-sym -text [dui symbol get cloud-download]
		} else {
			dui item config $page_to_show browse-lbl -text [translate "Browse shot"]
			dui item config $page_to_show browse-sym -text [dui symbol get chart-line]
		}
		return 1
	}
	
	proc show { page_to_hide page_to_show } {
		variable data
		
		if { ![plugins enabled visualizer_upload] } {
			set data(warning_msg) [translate "\"Upload to Visualizer\" extension is not enabled"]
			dui item config $page_to_show settings-lbl -text [translate "Enable Visualizer"]
		} elseif { $::android == 1 && [borg networkinfo] eq "none" } {
			set data(warning_msg) [translate "No wifi, can't access Visualizer"]
		} elseif { ![::plugins::visualizer_upload::has_credentials] } {
			set data(warning_msg) [translate "Visualizer username or password is not defined, can't access Visualizer"]
		} else {
			dui item config $page_to_show settings-lbl -text "[translate {Visualizer settings}]"
			set data(settings_msg) {}
			set data(warning_msg) {}
		}
		
		if { $data(warning_msg) eq {} } {			
			dui item show $page_to_show {upload* download* line_up_down}
			dui item enable_or_disable [expr {$data(shot_clock) ne {} }] $page_to_show upload*
			
			if { $data(shot_clock) ne {} } {
				dui item enable_or_disable [expr {$data(repo_link) ne {}}] $page_to_show {download* browse*}
				dui item hide $page_to_show {download_code* download_beans* download_equipment* download_ratio*
					download_profile* download_by_code*}
			} else {
				# Next shot
				dui item show $page_to_show {download_code* download_beans* download_equipment* download_ratio*
					download_profile* download_by_code*}
				dui item disable $page_to_show {download* download_by_code*}
				dui item enable $page_to_show browse*
			}
		} else {
			dui item hide $page_to_show {upload* download* line_up_down download_code* download_beans* download_equipment* 
				download_ratio* download_profile* download_by_code*}
			dui item enable_or_disable [expr {$data(shot_clock) ne {} && $data(repo_link) ne {}}] $page_to_show browse*
		}
		
		if { $data(repo_link) eq {} } {
			dui item config $page_to_show upload-lbl -text [translate "Upload shot"]
			set data(browse_msg) ""
		} else {
			dui item config $page_to_show upload-lbl -text [translate "Re-upload shot"]
			try {
				package present zint
				set data(browse_msg) [translate "Scan the QR code or tap here to open the link in the system browser"]
			} on error err {
				set data(browse_msg) [translate "Tap here to open the link in the system browser"]
			}
		}		
		generate_qr $data(repo_link)
	}
	
	proc close_dialog {} {
		variable data
		dui page close_dialog $data(repo_link) $data(downloaded_shot) $data(apply_download_to)
	}
	
	proc upload {} {
		variable data
		set page [namespace tail [namespace current]]
		if { $data(shot_clock) eq {} } {
			return
		}
		
		dui item config $page upload-lbl1 -fill [dui aspect get dtext fill -theme [dui page theme $page]]
		set data(upload_status_msg) "[translate Uploading]..."
		set new_repo_link [::plugins::DYE::upload_to_visualizer_and_save $data(shot_clock)]

		if { $new_repo_link eq "" } {
			dui item config $page upload-lbl1 -fill [dui aspect get dtext fill -theme [dui page theme $page] -style error]
			set data(upload_status_msg) [translate "Failed, see details on settings page"]
		} else {
			set data(repo_link) [lindex $new_repo_link 1]
			set data(visualizer_id) [file tail $data(repo_link)]
			set data(upload_status_msg) [translate "Successful"]
			#show {} $page
			dui page close_dialog $data(repo_link) {} {} 
		}
	}
	
	# See http://www.androwish.org/index.html/file?name=jni/zint/backend_tcl/demo/demo.tcl&ci=b68e63bacab3647f
	proc generate_qr { repo_link } {
		if { $repo_link eq {} } {
			[namespace current]::qr_img blank
		} else {
			catch {
				zint encode $repo_link [namespace current]::qr_img -barcode QR -scale 2.5
			}
		}
	}
	
	proc download {} {
		variable data
		set page [namespace tail [namespace current]]
		if { $data(visualizer_id) eq {} } {
			return
		}
		
		dui item config $page download-lbl1 -fill [dui aspect get dtext fill -theme [dui page theme $page]]
		set data(download_status_msg) "[translate Downloading]..."
		set vis_shot [plugins::visualizer_upload::download $data(visualizer_id)]

		if { [dict size $vis_shot] == 0 } {	
			dui item config $page download-lbl1 -fill [dui aspect get dtext fill -theme [dui page theme $page] -style error]
			set data(download_status_msg) [translate "Failed, see details on settings page"]
		} else {
			set data(download_status_msg) [translate "Successful"]
			set data(downloaded_shot) $vis_shot
			dui page close_dialog {} $vis_shot {}
		}
		
		#return $vis_shot
	}
	
	proc download_by_code {} {
		variable data
		variable widgets
		set page [namespace tail [namespace current]]
		if { $data(download_code) eq {} } {
			return
		}

		dui item config $widgets(download_by_code_status_msg) -fill [dui aspect get dtext fill -theme [dui page theme $page]]
		set data(download_by_code_status_msg) "[translate Downloading]..."
		set vis_shot [plugins::visualizer_upload::download $data(download_code)]

		if { [dict size $vis_shot] == 0 } {
			dui item config $widgets(download_by_code_status_msg) \
				-fill [dui aspect get dtext fill -theme [dui page theme $page] -style error]
			set data(download_by_code_status_msg) [translate "Failed. Check code or details on settings page"]
		} else {
			set data(download_by_code_status_msg) [translate "Successful"]
			set data(downloaded_shot) $vis_shot
			set data(apply_download_to) {}
			foreach what {beans equipment ratio profile} {
				if { $data(download_$what) } {
					lappend data(apply_download_to) $what
				}
			}
			
			dui page close_dialog {} $vis_shot $data(apply_download_to)
		}
	}
	
	proc download_code_modified {} {
		variable data
		dui item enable_or_disable [expr {[string len $data(download_code)]==4}] [namespace tail [namespace current]] download_by_code*
	}
	
	proc validate_download_code { value } {
		return [expr {[string len $value]<=4}]
	}
	
	proc browse {} {
		variable data
		if { $data(repo_link) ne {} } {
			web_browser $data(repo_link)
			dui page close_dialog {} {} {}
		}
	}
	
	proc settings {} {
		variable data
		
		if { [plugins enabled visualizer_upload] } {
			dui page close_dialog {} {} {}
			dui page open_dialog visualizer_settings
		} else {
			if { [plugins enable visualizer_upload] } {
				show {} [namespace tail [namespace current]]
			} else {
				set data(settings_msg) "Can't enable Visualizer"
			}
		}
	}
	
}

### DESCRIBE WHICH SHOT SELECTOR DIALOG ################################################################################

namespace eval ::dui::pages::dye_which_shot_dlg {
	variable widgets
	array set widgets {}
		
	variable data
	array set data {
		next_shot_summary {}
		last_shot_date {}
		last_shot_summary {}
	}
	
	# Actions: Plan next shot, describe last shot, select past shot to describe, history viewer?, DYE settings?
	proc setup {} {
		variable data
		set page [namespace tail [namespace current]]
		
		set splits [dui page split_space 0 [dui page height $page 0] 0.2 0.2 0.1 0.1 0.1]
		
		set i 0		
		set y0 [lindex $splits $i]
		set y1 [lindex $splits [incr i]]

		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags plan_next -style menu_dlg_btn \
			-symbol fast-forward -symbol_pos {0.1 0.5} -label [translate "Plan NEXT shot"] -label_pos {0.2 0.1} -label_anchor nw \
			-label_font_family notosansuibold -label_font_size -1 -label_width 0.75 \
			-label1variable next_shot_summary -label1_pos {0.2 0.35} -label1_width 0.75 -label1_anchor nw -label1_justify left
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline 

		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags describe_last -style menu_dlg_btn \
			-symbol backward -symbol_pos {0.1 0.5} -label [translate "Describe LAST shot"] -label_pos {0.2 0.08} -label_anchor nw \
			-label_font_family notosansuibold -label_font_size -1 -label_width 0.75 \
			-label1variable last_shot_summary -label1_pos {0.2 0.32} -label1_width 0.75 -label1_anchor nw -label1_justify left \
			-label2variable last_shot_date -label2_pos {0.9 0.08} -label2_anchor ne -label2_justify right -label2_font_size -2
		
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline 

		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags select_shot -style menu_dlg_btn \
			-symbol list -symbol_pos {0.1 0.5} -label "[translate {Select shot to describe}]..." -label_pos {0.2 0.5} \
			-label_width 0.75 
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline 

		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags search_shot -style menu_dlg_btn \
			-symbol search -symbol_pos {0.1 0.5} -label "[translate {Search shot to describe}]..." -label_pos {0.2 0.5} \
			-label_width 0.75
		dui add canvas_item line $page 0.01 $y1 0.99 $y1 -style menu_dlg_sepline
		
		set y0 $y1
		set y1 [lindex $splits [incr i]]
		dui add dbutton $page 0.01 $y0 0.99 $y1 -tags dye_settings -style menu_dlg_btn \
			-symbol cogs -symbol_pos {0.1 0.5} -label "[translate {Describe Your Espresso settings}]" -label_pos {0.2 0.5} \
			-label_width 0.75
	}

	proc load { page_to_hide page_to_show args } {
		variable data
		set data(next_shot_summary) "[format_shot_description $::settings(profile_title) \
			$::plugins::DYE::settings(next_grinder_dose_weight) $::plugins::DYE::settings(next_drink_weight) {} \
			$::plugins::DYE::settings(next_bean_brand) $::plugins::DYE::settings(next_bean_type) \
			$::plugins::DYE::settings(next_roast_date) $::plugins::DYE::settings(next_grinder_model) \
			$::plugins::DYE::settings(next_grinder_setting)]"
		if { [value_or_default ::settings(espresso_clock)] == 0 } {
			set data(last_shot_date) [translate {No shot}]
		} else {
			set data(last_shot_date) [::plugins::DYE::format_date $::settings(espresso_clock)]
			
			array set shot [::plugins::SDB::shots {profile_title grinder_dose_weight drink_weight extraction_time 
				bean_brand bean_type roast_date grinder_model grinder_setting espresso_enjoyment} 1 \
				"clock=$::settings(espresso_clock)" 1]
			if { [array size shot] == 0 } {
				set data(last_shot_summary) [translate "Not saved to history"] 
			} else {
				set data(last_shot_summary) "[format_shot_description $shot(profile_title) $shot(grinder_dose_weight) \
					$shot(drink_weight) $shot(extraction_time) $shot(bean_brand) $shot(bean_type) $shot(roast_date) \
					$shot(grinder_model) $shot(grinder_setting)]"
			}
		}
		
		return 1
	}
	
	# Returns a 2 or 3-lines formatted string with the summary of a shot description.
	proc format_shot_description { {profile_title {}} {dose {}} {yield {}} {time {}} {bean_brand {}} {bean_type {}} \
			{roast_date {}} {grinder_model {}} {grinder_setting {}} {enjoyment 0} {default_if_empty "No description" }} {
		set shot_desc ""
	
		set ratio {}
		if { $dose ne {} || $yield ne {} || $time ne {} } {
			if { $dose eq {} || ![string is double $dose] } { 
				set dose "?" 
			} else {
				set dose [round_to_one_digits $dose]
			}
			if { $yield eq {} || ![string is double $yield] } { 
				set yield "?" 			
			} else {
				set yield [round_to_one_digits $yield]
			}
			append ratio "${dose}[translate g] [translate in]:${yield}[translate g] [translate out]"
			if { $dose ne "?" && $yield ne "?" } {
				append ratio " (1:[round_to_one_digits [expr {$yield*1.0/$dose}]])"
			}
			if { $time ne {} && [string is double $time] } {
				append ratio " [translate in] [expr {int(${time})}][translate s]"
			}
		}
		
		set beans_items [list_remove_element [list {*}$profile_title - {*}$bean_brand {*}$bean_type {*}$roast_date] ""]
		set grinder_items [list_remove_element [list {*}$grinder_model {*}$grinder_setting] ""]
		if { $enjoyment > 0} { 
			lappend grinder_items "[translate Enjoyment] $espresso_enjoyment" 
		}
		
		set each_line {}
		if {[string length $ratio] > 0} { lappend each_line $ratio }
		if {[llength $beans_items] > 0} { lappend each_line [string trim [join $beans_items " "]] }
		if {[llength $grinder_items] > 0} { lappend each_line [string trim [join $grinder_items " \@ "]] }
				
		set shot_desc [join $each_line "\n"]
	
		if {$shot_desc eq ""} { 
			set shot_desc "\[[translate $default_if_empty]\]" 
		}
		return $shot_desc
	}	
	
	proc plan_next {} {
		dui page close_dialog
		::plugins::DYE::open next
	}
	
	proc describe_last {} {
		dui page close_dialog
		::plugins::DYE::open current
	}

	proc select_shot {} {
		array set shots [::plugins::SDB::shots "clock shot_desc" 1 {} 500]
		if { [array size shots] > 0 } {
			dui page open_dialog dui_item_selector {} $shots(shot_desc) -values_ids $shots(clock) -listbox_width 2300 \
				-page_title [translate "Select the shot to describe"] -return_callback [namespace current]::select_shot_callback \
				-theme [dui theme get]
		}
	}
	
	proc select_shot_callback { shot_desc shot_id args } {
		dui page close_dialog
		if { [llength $shot_id] > 0 } {			
			::plugins::DYE::open [lindex $shot_id 0]
		}
	}
	
	proc search_shot {} {
		dui page open_dialog DYE_fsh -page_title [translate "Select the shot to describe"] \
			-return_callback [namespace current]::search_shot_callback
	}
	
	proc search_shot_callback { selected_shots matched_shots } {
		dui page close_dialog
		if { [llength $selected_shots] > 0 } {			
			::plugins::DYE::open [lindex $selected_shots 0] 
		}
	}
	
	proc dye_settings {} {
		dui page close_dialog
		dui page open_dialog DYE_settings
	}
}

### "FILTER SHOT HISTORY" PAGE #########################################################################################

namespace eval ::dui::pages::DYE_fsh {
	variable widgets
	array set widgets {}
	
	variable data
	array set data {
		page_title "Filter Shot History"
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
	dui add dtext $page [expr {$x_left+340}] [expr {$y+15}] -text "\[ [translate "Reset"] \]" -tags reset_categories1 \
		-style remark -command true 
	
	# Categories2 listbox
	set x_left2 750
	dui add variable $page $x_left2 $y -tags categories2_label -style section_header -command categories2_label_dropdown
	dui add symbol $page [expr {$x_left2+300}] $y -symbol sort-down -tags categories2_label_dropdown \
		-aspect_type dcombobox_ddarrow -command true
	
	dui add listbox $page $x_left2 [expr {$y+80}] -tags categories2 -canvas_width 500 -canvas_height 560 \
		-selectmode multiple -yscrollbar yes -font_size -1

	# Reset categories2
	dui add dtext $page [expr {$x_left2+340}] [expr {$y+15}] -text "\[ [translate "Reset"] \]" -tags reset_categories2 \
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
	dui add dtext $page $x_right_label 688 -tags order_by_label -text [translate "Order by"] -font_size +2

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
	
	dui item show_or_hide [expr {$::settings(skin) eq "DSx" && [dui page previous] eq "DSx_past"}] $page_to_show \
		{apply_to_left_side* apply_to_right_side*}
	
#	dui item show_or_hide [expr {$::settings(skin) eq "DSx" && $data(previous_page) eq "DSx_past"}] $page_to_show \
#		{apply_to_left_side* apply_to_right_side*}
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
	dui page open_dialog dui_item_selector [namespace current]::data(category1) $items -selected $data(categories1_label) \
		-values_ids $item_ids -item_type categories -page_title [translate "Select a category"] \
		-return_callback [namespace current]::select_category1_callback -theme [dui theme get]
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
	dui page open_dialog dui_item_selector [namespace current]::data(category2) $items -selected $data(categories2_label)  \
		-values_ids $item_ids -item_type categories -page_title [translate "Select a category"] \
		-return_callback [namespace current]::select_category2_callback -theme [dui theme get]
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
	
	dui page close_dialog {} {}
#	if { $data(callback_cmd) ne "" } {
#		uplevel #0 [list $data(callback_cmd) {} {}]
#	} elseif { $data(previous_page) eq "" } {
#		if { $::settings(skin) eq "DSx" } {
#			dui page show DSx_past
#		} else {
#			dui page show DYE
#		}
#	} else {
#		dui page show $data(previous_page)
#	} 	
}

proc ::dui::pages::DYE_fsh::page_done {} {
	variable data
	dui say [translate {save}] button_in
	
	set previous_page [dui page previous]
	dui page close_dialog [dui item listbox_get_selection DYE_fsh shots $data(matched_clocks)] $data(matched_clocks)
	
#	if { $data(callback_cmd) ne "" } {
#		#msg "::dui::pages::DYE_fsh::page_done, callback_cmd=$data(callback_cmd)"
#		#msg "::dui::pages::DYE_fsh::page_done, matched_clocks=$data(matched_clocks), selected_clock=[dui item listbox_get_selection DYE_fsh shots $data(matched_clocks)]"				
#		uplevel #0 [list $data(callback_cmd) [dui item listbox_get_selection DYE_fsh shots $data(matched_clocks)] $data(matched_clocks)]
#		return
#	} elseif { $data(previous_page) eq "" } {
#		if { $::settings(skin) eq "DSx" } {
#			dui page show DSx_past
#		} else {
#			dui page show DYE
#		}
#	} else {
#		dui page show $data(previous_page)
#	} 
	
	if { $::settings(skin) eq "DSx" && $previous_page eq "DSx_past" } {
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
	dui add dtext $page 1280 100 -tags page_title -text [translate "Describe Your Espresso Settings"] -style page_title

	dui add canvas_item rect $page 10 190 2550 1430 -fill "#ededfa" -width 0
	dui add canvas_item line $page 14 188 2552 189 -fill "#c7c9d5" -width 2
	dui add canvas_item line $page 2551 188 2552 1426 -fill "#c7c9d5" -width 2
	
	dui add canvas_item rect $page 22 210 1270 1410 -fill white -width 0
	dui add canvas_item rect $page 1290 210 2536 850 -fill white -width 0	
	dui add canvas_item rect $page 1290 870 2536 1410 -fill white -width 0
		
	# LEFT SIDE
	set x 75; set y 250; set vspace 150; set lwidth 1050
	set panel_width 1248
	
	dui add dtext $page $x $y -text [translate "General options"] -style section_header
		
	dui add dtext $page $x [incr y $vspace] -tags {propagate_previous_shot_desc_lbl propagate_previous_shot_desc*} \
		-width [expr {$panel_width-250}] -text [translate "Propagate Beans, Equipment, Ratio & People from last to next shot"]
	dui add dtoggle $page [expr {$x+$panel_width-100}] $y -anchor ne -tags propagate_previous_shot_desc \
		-variable ::plugins::DYE::settings(propagate_previous_shot_desc) -command propagate_previous_shot_desc_change 
	
	dui add dtext $page $x [incr y $vspace] -tags {describe_from_sleep_lbl describe_from_sleep*} \
		-width [expr {$panel_width-250}] -text [translate "Icon on screensaver to describe last shot without waking up the DE1"]
	dui add dtoggle $page [expr {$x+$panel_width-100}] $y -anchor ne -tags describe_from_sleep \
		-variable ::plugins::DYE::settings(describe_from_sleep) -command describe_from_sleep_change 
	
	dui add dtext $page $x [incr y $vspace] -tags {backup_modified_shot_files_lbl backup_modified_shot_files*} \
		-width [expr {$panel_width-250}] -text [translate "Backup past shot files when they are modified (.bak extension)"]
	dui add dtoggle $page [expr {$x+$panel_width-100}] $y -anchor ne -tags backup_modified_shot_files \
		-variable ::plugins::DYE::settings(backup_modified_shot_files) -command backup_modified_shot_files_change 

	dui add dtext $page $x [incr y $vspace] -tags {use_stars_to_rate_enjoyment_lbl use_stars_to_rate_enjoyment*} \
		-width [expr {$panel_width-700}] -text [translate "Rate enjoyment using"]
	dui add dselector $page [expr {$x+$panel_width-100}] $y -bwidth 600 -anchor ne -tags use_stars_to_rate_enjoyment \
		-variable ::plugins::DYE::settings(use_stars_to_rate_enjoyment) -values {1 0} \
		-labels [list [translate {0-5 stars}] [translate {0-100 slider}]] -command [list ::plugins::save_settings DYE]

	dui add dtext $page $x [incr y $vspace] -tags {relative_dates_lbl relative_dates*} \
		-width [expr {$panel_width-700}] -text [translate "Format of shot dates in DYE pages"]
	dui add dselector $page [expr {$x+$panel_width-100}] $y -bwidth 600 -anchor ne -tags relative_dates \
		-variable ::plugins::DYE::settings(relative_dates) -values {1 0} \
		-labels [list [translate Relative] [translate Absolute]] -command [list ::plugins::save_settings DYE]
		
	# RIGHT SIDE, TOP
	set x 1350; set y 250
	dui add dtext $page $x $y -text [translate "DSx skin options"] -style section_header
	
	dui add dtext $page $x [incr y 100] -tags {show_shot_desc_on_home_lbl show_shot_desc_on_home*} \
		-width [expr {$panel_width-375}] -text [translate "Show next & last shot description summaries on DSx home page"]
	dui add dtoggle $page [expr {$x+$panel_width-100}] $y -anchor ne -tags show_shot_desc_on_home \
		-variable ::plugins::DYE::settings(show_shot_desc_on_home) -command show_shot_desc_on_home_change 
	
	incr y [expr {int($vspace * 1.40)}]
	
	dui add dtext $page $x $y -tags shot_desc_font_color_label -width 725 -text [translate "Color of shot descriptions summaries"]

	dui add dbutton $page [expr {$x+$panel_width-100}] $y -anchor ne -tags shot_desc_font_color -style dsx_settings \
		-command shot_desc_font_color_change -label [translate "Change color"] -label_width 250 \
		-symbol paint-brush -symbol_fill $::plugins::DYE::settings(shot_desc_font_color)

	dui add dbutton $page [expr {$x+700}] [expr {$y+[dui aspect get dbutton bheight -style dsx_settings]}] \
		-bwidth 425 -bheight 100 -anchor se -tags use_default_color \
		-shape outline -outline $::plugins::DYE::default_shot_desc_font_color -arc_offset 35 \
		-label [translate {Use default color}] -label_fill $::plugins::DYE::default_shot_desc_font_color \
		-label_font_size -1 -command set_default_shot_desc_font_color 

	# RIGHT SIDE, BOTTOM
	set y 925
	dui add dtext $page $x $y -text [translate "Insight / MimojaCafe skin options"] -style section_header
	
	dui add dtext $page $x [incr y 100] -tags default_launch_action_label -width 725 \
		-text [translate "Default action when DYE icon or button is tapped"]
	
	dui add dselector $page [expr {$x+$panel_width-100}] $y -bwidth 400 -bheight 271 -orient v -anchor ne -values {last next dialog} \
		-variable ::plugins::DYE::settings(default_launch_action) -labels {"Describe last" "Plan next" "Launch dialog"} \
		-command [list ::plugins::save_settings DYE]
	
	# FOOTER
	dui add dbutton $page 1035 1460 -tags page_done -style insight_ok -command page_done -label [translate Ok]
}

# Normally not used as this is not invoked directly but by the DSx settings pages carousel, but still kept for 
# consistency or for launching the page from a menu.
proc ::dui::pages::DYE_settings::load { page_to_hide page_to_show args } {
	return 1
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
msg -INFO "RUNNING propagate_previous_shot_desc_change"
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
	dui page close_dialog
}

#### DYE v3  #########################################################################################

namespace eval ::dui::pages::DYE_v3 {
	variable widgets
	array set widgets {}
	
	variable data
	# which_shot can be "next", "last" or "past"
	array set data {
		previous_page {}
		callback_cmd {}
		page_title {translate {Describe your espresso}}
		which_shot {current}
		clock 0		
		shot_file {}
		which_compare {previous}
		compare_clock {}
		compare_file {}
		field_being_edited {}
		ok_cancel_clicked 0
		menu {}
		chart_stage_idx 0
		chart_stage {Full shot}
		
		test_msg {}
	}
	
	variable pages
	set pages {DYE_v3 DYE_v3_next DYE_v3_beans_desc DYE_v3_beans_batch DYE_v3_equipment DYE_v3_extraction DYE_v3_beverage
		DYE_v3_tasting DYE_v3_chart DYE_v3_manage DYE_v3_compare}
		
	variable page_coords
	array set page_coords {
		margin_width 75
		middle_width 150
		scrollbar_width 100
		y_top_panel 175
		y_main_panel 300
		top_panel_height 125
		main_panel_height 1100 
		field_label_width 425
	}
	set page_coords(panel_width) [expr {int(($dui::_base_screen_width-$page_coords(margin_width)*2-$page_coords(middle_width))/2)}]
	set page_coords(x_right_panel) [expr {int($page_coords(margin_width)+$page_coords(panel_width)+$page_coords(middle_width))}]
	set page_coords(x_field_widget) [expr {int($page_coords(x_right_panel)+$page_coords(field_label_width))}]
	set page_coords(field_widget_width) [expr {int($page_coords(panel_width)-$page_coords(field_label_width)-$page_coords(scrollbar_width)-50)}]
	
	variable original_shot
	array set original_shot {}
	variable edited_shot
	array set edited_shot {}
	variable compare_shot
	array set compare_shot {}
	
	namespace eval vectors {
		namespace eval edited {
			proc init {} {
				blt::vector create elapsed pressure_goal flow_goal temperature_goal
				blt::vector create pressure flow flow_weight weight state_change resistance_weight resistance 
				blt::vector create temperature_basket temperature_mix  temperature_goal
			}
		}

		namespace eval compare {
			proc init {} {
				blt::vector create elapsed pressure_goal flow_goal temperature_goal
				blt::vector create pressure flow flow_weight weight state_change resistance_weight resistance
				blt::vector create temperature_basket temperature_mix  temperature_goal
			}
		}

		proc init {} {
			edited::init
			compare::init
		}
	}
	
}

proc ::dui::pages::DYE_v3::setup {} {
	variable data
	variable widgets
	variable pages
	variable page_coords
	set page [namespace tail [namespace current]]
	
	init_shot_arrays
	
	### TOP NAVIGATION BAR (common to all pages) ###
	set x $page_coords(margin_width)
	set y 50
	set bar_width [expr {$dui::_base_screen_width-$x*2}]
	set btn_width [expr {int($bar_width/11)}]
	set btn_height 90
	# Summary Chart Profile Beans Equipment Extraction Other | Compare Search
	
	dui add dbutton $pages $x $y -tags nav_summary -style dyev3_topnav -label [translate Summary] \
		-command {%NS::navigate_to summary} -shape round -bwidth [expr {$btn_width+60}] -label_pos {0.45 0.5}
	set i 0
	dui add dbutton $pages [expr {$x+$btn_width*[incr i]}] $y -bwidth $btn_width -tags nav_chart -style dyev3_topnav \
		-label [translate Chart] -command {%NS::navigate_to chart} 
	dui add dbutton $pages [expr {$x+$btn_width*[incr i]}] $y -bwidth $btn_width -tags nav_profile -style dyev3_topnav \
		-label [translate Profile] -command {%NS::navigate_to profile} -label_fill "#ddd" 	
	dui add dbutton $pages [expr {$x+$btn_width*[incr i]}] $y -bwidth $btn_width -tags nav_beans_desc -style dyev3_topnav \
		-label [translate Beans] -command {%NS::navigate_to beans_desc}
	dui add dbutton $pages [expr {$x+$btn_width*[incr i]}] $y -bwidth $btn_width -tags nav_beans_batch -style dyev3_topnav \
		-label [translate Batch] -command {%NS::navigate_to beans_batch}
	dui add dbutton $pages [expr {$x+$btn_width*[incr i]}] $y -bwidth $btn_width -tags nav_equipment -style dyev3_topnav \
		-label [translate Equipment] -command {%NS::navigate_to equipment} 
	dui add dbutton $pages [expr {$x+$btn_width*[incr i]}] $y -bwidth $btn_width -tags nav_extraction -style dyev3_topnav \
		-label [translate Extraction] -command {%NS::navigate_to extraction}
	dui add dbutton $pages [expr {$x+$btn_width*[incr i]}] $y -bwidth $btn_width -tags nav_beverage -style dyev3_topnav \
	-label [translate Beverage] -command {%NS::navigate_to beverage}	
	dui add dbutton $pages [expr {$x+$btn_width*[incr i]}] $y -bwidth $btn_width -tags nav_tasting -style dyev3_topnav \
		-label [translate Tasting] -command {%NS::navigate_to tasting} 	
	
	dui add dbutton $pages [expr {$x+$btn_width*($i+2)-75}] $y -tags nav_compare -style dyev3_topnav -label [translate Compare] \
		-command {%NS::navigate_to compare} -shape round -bwidth [expr {$btn_width+60}] -label_pos {0.55 0.5}
	dui add dbutton $pages [expr {$x+$btn_width*($i+1)}] $y -bwidth $btn_width -tags nav_manage -style dyev3_topnav \
		-label [translate Manage] -command {%NS::navigate_to manage} 
	
	### LEFT PANEL (common to all pages) ###
	set width [expr {$page_coords(panel_width)-$page_coords(scrollbar_width)}]
	
	dui add text $pages $x $page_coords(y_top_panel) -tags edited_summary -canvas_width $width \
		-canvas_height $page_coords(top_panel_height) -style dyev3_top_panel_text
	
	# We need to handle the yscrollbar in a special way to manually hide the graph on top of the text widget,
	# otherwise it overflows the space on top of the text widget when scrolling down (Androwish bug?) 
	dui add text $pages $x $page_coords(y_main_panel) -tags edited_text -canvas_width $width \
		-canvas_height $page_coords(main_panel_height) -style dyev3_bottom_panel_text -yscrollbar yes \
		-yscrollbar_width $page_coords(scrollbar_width) -yscrollcommand [list ::dui::pages::DYE_v3::text_scale_scroll edited] \
		-yscrollbar_command [list ::dui::pages::DYE_v3::text_scroll_moveto edited]
	
	# Create graph (but don't add them, they'are added to the text widgets when shots are loaded) 
	set widget [dui canvas].[string tolower $page]-edited_graph
	set widgets(edited_graph) $widget
	graph $widget -width [dui platform rescale_x [expr {$width-10}]] -height [dui platform rescale_y 600] \
		{*}[dui aspect list -type graph -style dyev3_text_graph -as_options yes] 
	vectors::init
	setup_graph $widget edited 1
	bind $widget [dui platform button_press] [list ::dui::pages::DYE_v3::navigate_to chart]
		
	### RIGHT PANELS ###
	setup_right_panel $page "Summary" [page_fields $page]
	setup_right_panel DYE_v3_next "Summary" [page_fields DYE_v3_next]
	setup_right_panel DYE_v3_beans_desc "Beans" [page_fields DYE_v3_beans_desc]
	setup_right_panel DYE_v3_beans_batch "Beans batch" [page_fields DYE_v3_beans_batch]
	setup_right_panel DYE_v3_equipment "Equipment" [page_fields DYE_v3_equipment]
	setup_right_panel DYE_v3_extraction "Extraction" [page_fields DYE_v3_extraction]
	setup_right_panel DYE_v3_beverage "People & Beverage" [page_fields DYE_v3_beverage]
	setup_right_panel DYE_v3_tasting "Tasting" [page_fields DYE_v3_tasting]
	
	setup_chart_page
	setup_manage_page
	setup_compare_page
	
#	dui add variable $page 1890 500 -tags test_msg -font_size +2 -anchor center -justify center -width 1200
#	dui add text $page [expr {$x+$width+150+100}] 300 -tags text_right -canvas_width $width -canvas_height 1100 \
#		-yscrollbar yes -yscrollbar_width 100
	
	### BOTTOM BAR (common to all pages ###
	# Shot navigation
	set y 1460; set x [expr {$page_coords(margin_width)-15}]; set hspace 105

	dui add dbutton $pages $x $y -bwidth 100 -bheight 120 -symbol backward -tags move_backward \
		-style dyev3_nav_button	
	dui add dbutton $pages [incr x $hspace] $y -bwidth 100 -bheight 120 -symbol forward \
		-tags move_forward -style dyev3_nav_button	
	dui add dbutton $pages [incr x $hspace] $y -bwidth 100 -bheight 120 -symbol fast-forward \
		-tags move_to_next -style dyev3_nav_button
	
	dui add dbutton $pages [incr x [expr {$hspace+30}]] $y -bwidth 100 -bheight 120 -symbol list \
		-tags select_shot -style dyev3_nav_button
	dui add dbutton $pages [incr x $hspace] $y -bwidth 100 -bheight 120 -symbol binoculars \
		-tags search_shot -style dyev3_nav_button
	dui add dbutton $pages [incr x $hspace] $y -bwidth 100 -bheight 120 -symbol history \
		-tags open_history_viewer -style dyev3_nav_button
	
	
	# Ok & Cancel 
	dui add dbutton $pages 770 1460 -tags page_cancel -style insight_ok -label [translate Cancel]
	dui add dbutton $pages 1310 1460 -tags page_done -style insight_ok -label [translate Ok]
	
	# Go to settings
	dui add dbutton {DYE_v3 DYE_v3_manage} [expr {$dui::_base_screen_width-$page_coords(margin_width)}] $y \
		-tags go_to_settings -symbol cogs -style dyev3_nav_button -anchor ne
}

# We need the description array variables defined from the beginning so as to be able to put traces on them.
# Beware not to unset them or the trace will be lost (including the traces set by some DUI widgets).
proc ::dui::pages::DYE_v3::init_shot_arrays {} {
	variable edited_shot
	variable compared_shot
	
	foreach field [metadata fields -domain shot -category description] {
		set edited_shot($field) {}
	}
}

# This proc and the next add code to the standard scrollbar commands so that the graph widget on top doesn't 
# overflow the page space on top of the text widget when it is scrolled (which seems like a bug in Tk::Text or Androwish)
proc ::dui::pages::DYE_v3::text_scale_scroll { {target edited} args } {
	variable widgets
	variable data
	if { $target eq "compare" } {
		set page "DYE_v3_compare"
	} else {
		set target "edited"
		set page "DYE_v3"
	}
	if { [dui item cget $page ${target}_text -state] in {hidden {}} } { 
		return
	}
	
	::dui::item::scale_scroll $page ${target}_text ::dui::item::sliders(${page},${target}_text) {*}$args
	# Change for DUI multi-canvas:
	#::dui::item::scale_scroll $page ${target}_text ::dui::item::sliders(${page},${target}_text) [dui::canvas::get] {*}$args
	
	set ygraph ""
	catch { set ygraph [lindex [$widgets(${target}_text) dlineinfo chart] 1] }
	if { $ygraph ne "" } {
		if { $ygraph < -1 } {
			$widgets(${target}_graph) configure -height 0
		} elseif { $ygraph >=0 && $data(which_shot) ne "next" } {
			$widgets(${target}_graph) configure -height [dui platform rescale_y 600]
		}
	}
}

proc ::dui::pages::DYE_v3::text_scroll_moveto { {target edited} args } {
	variable widgets
	variable data
	if { $target eq "compare" } {
		set page "DYE_v3_compare"
	} else {
		set target "edited"
		set page "DYE_v3"
	}
	if { [dui item cget $page ${target}_text -state] eq {hidden {}} } { 
		return
	}
	
	::dui::item::scrolled_widget_moveto $page ${target}_text $::dui::item::sliders(${page},${target}_text) {*}$args
	
	set ygraph ""
	catch { set ygraph [lindex [$widgets(${target}_text) dlineinfo chart] 1] }
	if { $ygraph ne "" } {
		if { $ygraph < -1 } {
			$widgets(${target}_graph) configure -height 0
		} elseif { $ygraph >=0 && $data(which_shot) ne "next" } {
			$widgets(${target}_graph) configure -height [dui platform rescale_y 600]
		}
	}
}

proc ::dui::pages::DYE_v3::setup_graph { widget {target edited} {create_axis 0} } {
	set ns [namespace current]
	if { $create_axis } {
		$widget axis create temp
		$widget axis configure temp {*}[dui aspect list -type graph_axis -style hv_graph_axis -as_options yes]
		$widget axis configure x {*}[dui aspect list -type graph_xaxis -style hv_graph_axis -as_options yes]
		$widget axis configure y {*}[dui aspect list -type graph_yaxis -style hv_graph_axis -as_options yes]
		$widget grid configure {*}[dui aspect list -type graph_grid -style hv_graph_grid -as_options yes]
	}

	foreach lt {temperature_goal temperature_basket temperature_mix} {
		$widget element create line_${target}_$lt -xdata ${ns}::vectors::${target}::elapsed \
			-ydata ${ns}::vectors::${target}::$lt -mapy temp {*}[dui aspect list -type graph_line -style hv_${lt} -as_options yes]
	}
	
	foreach lt {pressure_goal flow_goal pressure flow flow_weight weight} {
		$widget element create line_${target}_$lt -xdata ${ns}::vectors::${target}::elapsed \
			-ydata ${ns}::vectors::${target}::$lt {*}[dui aspect list -type graph_line -style hv_${lt} -as_options yes]
	}
	
	foreach lt {state_change resistance} {
		$widget element create line_${target}_$lt -xdata ${ns}::vectors::${target}::elapsed \
			-ydata ${ns}::vectors::${target}::$lt {*}[dui aspect list -type graph_line -style hv_${lt} -as_options yes]
	}
	
}

proc ::dui::pages::DYE_v3::setup_right_side_title { page title {y {}} {tag right_side_title} } {
	variable page_coords
	
	set x [expr {int($page_coords(x_right_panel)+($page_coords(panel_width)-$page_coords(scrollbar_width))/2)}]	
	if { $y eq "" } {
		set y [expr {int($page_coords(y_top_panel)+$page_coords(top_panel_height)*0.4)}]
	}
	
	dui add dtext $page $x $y -tags $tag -style dyev3_right_panel_title -text [translate $title]
}

proc ::dui::pages::DYE_v3::setup_right_panel { page title fields } {
	variable page_coords
	set ns [namespace current]
	
	set width [expr {$page_coords(panel_width)-$page_coords(scrollbar_width)}]
	set x_label $page_coords(x_right_panel)
	set x_widget $page_coords(x_field_widget)
	set label_width [expr {$x_widget-$x_label}]
	set widget_width $page_coords(field_widget_width)
	set y $page_coords(y_main_panel)	
	set default_vspace 100
	
	setup_right_side_title $page $title
	
	foreach field $fields {
		if { $field eq "" } {
			incr y [expr {int($vspace*0.4)}]
			continue
		}
		set vspace $default_vspace
		
		lassign [metadata get $field name short_name data_type n_decimals min max default \
				smallincrement bigincrement measure_unit length] \
				name short_name data_type n_decimals min max default smallinc biginc measure_unit length
#		lassign [::plugins::SDB::field_lookup $field {name short_name data_type n_decimals min_value max_value 
#			default_value small_increment big_increment}] \
#			name short_name data_type n_decimals min max default smallinc biginc
		if { $name eq "" } {
			msg -ERROR "setup_right_panel: summary field '$field' not recognized"
			continue
		}
		set varname ${ns}::edited_shot($field)
		
		if { $data_type eq "number" } {
			if { $field eq "espresso_enjoyment" } {
				dui add drater $page $x_widget $y -tags $field -width $widget_width -variable $varname \
					-label [translate $name] -label_pos [list $x_label $y] -label_width $label_width -min $min -max $max 
			} else {
				dui add dtext $page $x_label $y -text [translate $name] -tags [list ${field}_label ${field}*]
				dui add dclicker $page $x_widget $y -tags $field -bwidth $widget_width -bheight [expr {$vspace-20}] \
					-style dye_double -variable $varname -labelvariable "\$$varname $measure_unit" -label_width $label_width -default $default \
					-n_decimals $n_decimals -min $min -max $max -smallincrement $smallinc -bigincrement $biginc -editor_page yes \
					-editor_page_title [translate "Enter $name"]
			}
		} elseif { $data_type eq "category" } {
			set w [dui add dcombobox $page $x_widget $y -tags $field -canvas_width $widget_width -textvariable $varname \
				-label [translate $name] -label_pos [list $x_label $y] -label_width $label_width \
				-values "\[::plugins::SDB::available_categories $field\]" -page_title [translate "Select the $name"]]
			bind $w <FocusIn> [list + ${ns}::highlight_field $field]
		} elseif { $data_type eq "boolean" } {
			dui add dcheckbox $page $x_label $y -textvariable $varname -tags [list ${field}_label ${field}*] \
				-label [translate $name] -command [list ${ns}::highlight_field $field]
		} elseif { $data_type eq "long_text" } {
			set w [dui add multiline_entry $page [expr {$x_widget-200}] $y -tags $field -canvas_width [expr {$widget_width+200}] \
				-canvas_height 170 -label [translate $name] -label_pos [list $x_label $y] -label_width [expr {$label_width-200}] \
				-textvariable $varname -yscrollbar yes -yscrollbar_width 100]
			bind $w <FocusIn> [list + ${ns}::highlight_field $field]
			# Trace add variable is not working with multiline_entry, so we need a fix:
			#bind $w <<Modified>> [list ::dui::pages::DYE_v3::multiline_entry_modified $w $field] 
			set vspace 225
		} else {
			set w [dui add entry $page $x_widget $y -tags $field -canvas_width $widget_width -label $name -label_pos [list $x_label $y] \
				-textvariable $varname -data_type $data_type]
			bind $w <FocusIn> [list + ${ns}::highlight_field $field]
		}
		
		incr y $vspace
	}
	
	if { $page eq "DYE_v3_beans_batch" } {
		#dui add variable DYE_v3_beans_batch $x_label [incr y 50] -textvariable days_offroast_string -width $width
	}
}

#proc ::dui::pages::DYE_v3::multiline_entry_modified { widget field } {
#	msg "FIELD $field MODIFIED, value=[$widget get 1.0 end]"
#	#[subst {set ${ns}::edited_shot($fields) \[$w get 1.0 end\] }]
#}

proc ::dui::pages::DYE_v3::setup_chart_page {} {
	variable page_coords
	set page "DYE_v3_chart"
	
	set x_label $page_coords(x_right_panel)
	set y [expr {$page_coords(y_main_panel)+50}]
	
	setup_right_side_title $page "Chart"
	
#	dui add dbutton $page $page_coords(x_right_panel) $y -bwidth 120 -bheight 120 -symbol chevron-left \
#		-tags previous_chart_stage -style dyev3_nav_button -symbol_pos {0.5 0.5} -anchor w

	set x [expr {int($page_coords(x_right_panel)+($page_coords(panel_width)-$page_coords(scrollbar_width))/2)}]	
	dui add variable $page $x $y -tags chart_stage -style dyev3_chart_stage_title \
		-textvariable {$%NS::data(chart_stage_idx). $%NS::data(chart_stage)} 
 
#	dui add dbutton $page [expr {$page_coords(x_right_panel)+$page_coords(panel_width)}] $y -bwidth 120 -bheight 120 \
#		-symbol chevron-right -tags next_chart_stage -style dyev3_nav_button -symbol_pos {0.5 0.5} -anchor e
	
	array set series {
		elapsed "Elapsed (sec)"
		pressure "Pressure (bar)"
		flow "Flow (mL/s)"
		flow_weight "Flow weight (g)"
		weight "Weight (g)"
		temperature_basket "Temp.bkt (ºC)"
	}
	
	set x_start [expr {$x_label+375}]
	set hspace 170
	set x_min [expr {$x_start+$hspace}]
	set x_avg [expr {$x_min+$hspace}]
	set x_max [expr {$x_avg+$hspace}]
	set x_end [expr {$x_max+$hspace}]
	set vspace 100
	
	incr y 100
	dui add dtext $page $x_start $y -tags start_label -text [translate Start] -style dyev3_chart_stage_colheader
	dui add dtext $page $x_min $y -tags min_label -text [translate Min] -style dyev3_chart_stage_colheader
	dui add dtext $page $x_avg $y -tags avg_label -text [translate Mean] -style dyev3_chart_stage_colheader
	dui add dtext $page $x_max $y -tags max_label -text [translate Max] -style dyev3_chart_stage_colheader
	dui add dtext $page $x_end $y -tags end_label -text [translate End] -style dyev3_chart_stage_colheader

	dui add canvas_item line $page $x_label [expr {$y+50}] [expr {$x_label+$page_coords(panel_width)}] [expr {$y+50}] -fill grey 
	
	foreach var {elapsed pressure flow flow_weight weight temperature_basket} {
		incr y $vspace
		if { $var eq "elapsed" } {
			set color [dui aspect get dtext fill]
		} else {
			set color [dui aspect get graph_line color -style hv_${var}]
		}
		dui add dtext $page $x_label $y -tags ${var}_label -text [translate $series($var)] -anchor w -fill $color
		
		foreach stat {start min avg max end} {
			dui add variable $page [subst \$x_$stat] $y -tags chart_stage_${var}_${stat} -style dyev3_chart_stage_value -fill $color 
			dui add variable $page [subst \$x_$stat] [expr {$y+40}] -tags chart_stage_comp_${var}_${stat} \
				-style dyev3_chart_stage_comp
		}
	}
		
	dui add canvas_item line $page $x_label [expr {$y+75}] [expr {$x_label+$page_coords(panel_width)}] [expr {$y+75}] \
		-style dyev3_chart_stage_line_sep 
}

proc ::dui::pages::DYE_v3::setup_manage_page {  } {
	variable page_coords
	set page "DYE_v3_manage"
	
	set x_label $page_coords(x_right_panel)
	set x_widget $page_coords(x_field_widget)
	#	set width [expr {$page_coords(panel_width)-$page_coords(scrollbar_width)}]
		
	set btn_spacing 100
	set btn_width [dui aspect get dbutton bwidth -style dyev3_action_half]
	set vspace 100
	set y $page_coords(y_main_panel)
	
	setup_right_side_title $page "Manage shot"

	dui add dbutton $page $x_label $y -tags archive_shot -style dyev3_action_half -label [translate "Archive"] \
		-symbol archive
	
	dui add dbutton $page [expr {$x_label+$btn_width+$btn_spacing}] $y -tags delete_shot -style dyev3_action_half \
		-label [translate "Delete"] -symbol trash
	
	incr y 175
	dui add dbutton $page $x_label $y -tags export_shot -style dyev3_action_half \
		-label [translate "Export"] -symbol file-export
	
	incr y 275
	setup_right_side_title $page Visualizer $y visualizer_title 
	#dui add dtext $page 1890 $y -tags visualizer_title -font_size +2 -anchor center -justify center -text [translate Visualizer]
	
	incr y 75
	dui add dbutton $page $x_label $y -tags upload_to_visualizer -style dyev3_action_half -label [translate "Upload"] \
		-symbol cloud-upload
	
	dui add dbutton $page [expr {$x_label+$btn_width+$btn_spacing}] $y -tags download_from_visualizer -style dyev3_action_half \
		-label [translate "Download"] -symbol cloud-download
		
	incr y 175
	dui add dbutton $page $x_label $y -tags visualizer_browse -style dyev3_action_half \
		-label [translate "Browse"] -symbol eye
	
}

proc ::dui::pages::DYE_v3::setup_compare_page {  } {
	variable widgets
	variable page_coords
	set page "DYE_v3_compare"
	
	set width [expr {$page_coords(panel_width)-$page_coords(scrollbar_width)}]
	set x $page_coords(x_right_panel)
	
	dui add text $page $x $page_coords(y_top_panel) -tags compare_summary -canvas_width $width \
		-canvas_height $page_coords(top_panel_height) -style dyev3_top_panel_text
	
	# We need to handle the yscrollbar in a special way to manually hide the graph on top of the text widget,
	# otherwise it overflows the space on top of the text widget when scrolling down (Androwish bug?) 
	dui add text $page $x $page_coords(y_main_panel) -tags compare_text -canvas_width $width \
		-canvas_height $page_coords(main_panel_height) -style dyev3_bottom_panel_text -yscrollbar yes \
		-yscrollbar_width $page_coords(scrollbar_width) -yscrollcommand [list ::dui::pages::DYE_v3::text_scale_scroll compare] \
		-yscrollbar_command [list ::dui::pages::DYE_v3::text_scroll_moveto compare]
	
	# Create graph (but don't add them, they'are added to the text widgets when shots are loaded) 
	set widget [dui canvas].[string tolower $page]-compare_graph
	set widgets(compare_graph) $widget
	graph $widget -width [dui platform rescale_x [expr {$width-15}]] \
		-height [dui platform rescale_y 600] {*}[dui aspect list -type graph -style dyev3_text_graph -as_options yes]
	setup_graph $widget compare 1
}


# Named arguments:
# -which_shot 'last', 'next' or a shot clock or file. Default is 'last' 
# -which_compare: 'previous' or a shot clock or file. Default is 'previous'
# -open_page: the subpage where to open DYE_v3
# -callback_cmd
proc ::dui::pages::DYE_v3::load { page_to_hide page_to_show args } {
	variable data
	variable widgets
	variable original_shot
	variable edited_shot
	variable compare_shot

	array set opts $args
	set page [namespace tail [namespace current]]
	set orig_page_to_show $page_to_show
	
	array set original_shot {}
	array set edited_shot {espresso_notes "" bean_notes ""}
	array set compare_shot {espresso_notes "" bean_notes ""}
	set data(ok_cancel_clicked) 0
	set data(field_being_edited) ""
	
	if { [string range $page_to_hide 0 5] ne "DYE_v3" } {
		set data(previous_page) $page_to_hide
	}
	set data(callback_cmd) [value_or_default opts(-callback_cmd)]
	set which_shot [value_or_default opts(-which_shot) "last"]
	if { $which_shot eq "next" } {
		set data(which_shot) next
		set data(clock) {}		
#		set data(shot_file) {}
		$widgets(edited_graph) configure -height 0
		if { $page_to_show eq "DYE_v3" } {
			set page_to_show DYE_v3_next
		}
	} else {
		if { $which_shot in {last current} } {
			set data(which_shot) "last"
			set data(clock) $::settings(espresso_clock)
			set data(path) [::plugins::SDB::get_shot_file_path $data(clock)]
			if { $page_to_show eq "DYE_v3_next" } {
				set page_to_show DYE_v3
			}		
		} elseif { [string is integer $which_shot] } {
			if { $which_shot == $::settings(espresso_clock) } {
				set data(which_shot) last
			} else {			
				set data(which_shot) past
			}
			set data(clock) $which_shot
			set data(path) [::plugins::SDB::get_shot_file_path $data(clock)]
		} else {
			set data(path) [::plugins::SDB::get_shot_file_path $which_shot]
			if { $data(path) eq "" } {
				msg -ERROR [namespace current] "'which_shot' value '$which_shot' is not valid"
				return 0
			}
		}
		
		$widgets(edited_graph) configure -height [dui platform rescale_y 600]
		if { $page_to_show eq "DYE_v3_next" } {
			set page_to_show DYE_v3
		}
	}
	
	set data(compare_clock) ""
	set data(compare_file) ""
	set data(which_compare) [value_or_default opts(-which_compare) "previous"]
	if { $data(which_compare) eq "previous" } {
		# BEWARE $data(clock) may not be defined if -which_shot was a filename
		if { $data(which_shot) eq "next" } {
			set data(compare_clock) $::settings(espresso_clock)
		} else {
			set data(compare_clock) [::plugins::SDB::previous_shot $data(clock)]
		}
		if { $data(compare_clock) ne "" } { 
			set data(compare_file) [::plugins::SDB::get_shot_file_path $data(compare_clock)]
		}
	} else {		
		set data(compare_file) [::plugins::SDB::get_shot_file_path $data(which_compare)]
		if { $data(compare_file) ne "" } {
			set data(which_compare) "past"
		}
	}
	
	if { $data(path) eq "" } {
		if { $data(which_shot) ne "next" } {
			msg -ERROR [namespace current] "shot file '$which_shot' not found"
			return 0
		}
		set shot_list [::plugins::DYE::load_next_shot]
	} else {
		set shot_list [::plugins::SDB::load_shot $data(path)]
	}
	#calc_derived_shot_values
	
	array set original_shot $shot_list 
	array set edited_shot $shot_list
	load_graph edited
	
	if { $data(compare_file) ne "" } {
		set compare_list [::plugins::SDB::load_shot $data(compare_file)]
		array set compare_shot $compare_list
		load_graph compare
		shot_to_text compare
	}
	
	shot_to_text edited	
	calc_chart_stage_stats edited
	calc_chart_stage_stats compare
	
	if { $page_to_show eq $orig_page_to_show } {
		return 1
	} else {
		return $page_to_show
	}
}

proc ::dui::pages::DYE_v3::load_graph { {target edited} } {
	variable edited_shot
	variable compare_shot
	
	set ns ::dui::pages::DYE_v3::vectors::${target}
	
	foreach fn {elapsed pressure_goal pressure flow_goal flow flow_weight weight temperature_basket temperature_mix
			temperature_goal state_change} {
		if { [info exists ${target}_shot(espresso_$fn)] } {
			${ns}::${fn} set [subst \$${target}_shot(espresso_$fn)]
		} else {
			msg -ERROR [namespace current] "load_graph: can't add chart series '$fn' to '$target'"
		}
	}

	set fn resistance
	if { [info exists ${target}_shot($fn)] } {
		${ns}::${fn} set [subst \$${target}_shot($fn)]
	} else {
		msg -ERROR [namespace current] "load_graph: can't add chart series '$fn' to '$target'"
	}
}

proc ::dui::pages::DYE_v3::show { page_to_hide page_to_show args } {
	variable data
	variable widgets
	variable edited_shot

	# Highlight current page menu on the top menu bar
	if { $data(menu) ne "" } {
		dui item config DYE_v3 nav_$data(menu)-btn -fill [dui aspect get dbutton fill -style dyev3_topnav]
	}
	
	if { $page_to_show in {DYE_v3 DYE_v3_next} } {
		set data(menu) "summary"
	} else {
		set data(menu) [string range $page_to_show 7 end]
	}
	
	if { $data(menu) ne "" } {
		dui item config DYE_v3 nav_$data(menu)-btn -fill grey
	}
	
	# Scroll the text widget to the current section
	set tw $widgets(edited_text)
	unhighlight_field "" $tw
	if { $data(menu) eq "" } {
		set section "summary"
	} elseif { $data(menu) eq "people" } {
		set section "beverage"
	} else {
		set section $data(menu)
	}
	try {
		$tw see $section
		$tw see ${section}:end
	} on error err {
		$tw see summary
		$tw see summary:end
		msg -WARNING [namespace current] "navigate_to: marks '$section' or '${section}:end' not found in text widget '$tw'"
	}
	
	# Enable or disable navigation arrows (botton left) depending on whether it's the "next shot" plan 
	dui item enable_or_disable [expr {$data(which_shot) ne "next"}] DYE_v3 {move_to_next* move_forward*}
	
	foreach field [page_fields $page_to_show] {
		# Disable field widgets that shouldn't be editable in "next" shot plan (those that don't propagate)
		if { [metadata get $field propagate] == 0 && $field ne "espresso_notes" && [dui page has_item $page_to_show $field] } {
			dui item enable_or_disable [expr {$data(which_shot) ne "next"}] $page_to_show ${field}*
			# Force redrawing stars after enabling
			if { $field eq "espresso_enjoyment" && $data(which_shot) ne "next" } {
				set edited_shot(espresso_enjoyment) $edited_shot(espresso_enjoyment)
			}
		}
		
		# If there are category fields whose dropdown depends on another category, enable or disable its dropdown arrow
		set related_fields [metadata fields -domain shot -category description -sdb_type_column1 $field]
		append related_fields [metadata fields -domain shot -category description -sdb_type_column2 $field]
		if { [llength $related_fields] > 0 } {
			set value $edited_shot($field)
			foreach rel_field $related_fields {
				if { [metadata get $rel_field data_type] eq "category" && [dui page has_item $page_to_show ${rel_field}-dda] } {
					dui item enable_or_disable [expr {$value ne ""}] [dui page current] ${rel_field}-dda
				}
			}
		}
	}
	
}

proc ::dui::pages::DYE_v3::menu_to_page { menu } {
	variable data
	
	if { $menu eq "" } {
		set menu"summary
	} else {
		switch $menu {
			people {set menu beverage}
		}
	}
#			bean_batch {set menu bean} 
	
	if { $menu eq "summary" } {
		if { $data(which_shot) eq "next" } {
			set dest_page DYE_v3_next
		} else {
			set dest_page DYE_v3
		}
	} else {
		set dest_page DYE_v3_$menu
	}

	return $dest_page
}

proc ::dui::pages::DYE_v3::navigate_to { dest {change_page 1} } {
	variable widgets
	variable data
	set tw $widgets(edited_text)
		
	if { [string is true $change_page] } {
		set dest_page [menu_to_page $dest]
		
		if { $dest_page ne [dui page current] } {
			if { [dui page exists $dest_page] } {
				dui page show $dest_page
			} else {
				msg -WARNING [namespace current] "show: destination page '$dest_page' not found"
			}
		}
	}
} 

# Returns a list with the set of fields (=widgets) that can be (potentially?) edited in the current page 
proc ::dui::pages::DYE_v3::page_fields { {page {}} } {
	if { $page eq "" } {
		set page [dui page current]
	}
	if { [string range $page 0 5] ne "DYE_v3" } {
		return {}
	}
	set page_suffix [string range $page 7 end]
	
	if { $page_suffix eq "" } {
		return $::plugins::DYE::settings(summary_fields)
	} elseif { $page_suffix eq "next" } {
		return $::plugins::DYE::settings(next_summary_fields)
	} elseif { $page_suffix in {beans_desc beans_batch} } {
		return [metadata fields -domain shot -category description -section beans -subsection $page_suffix]
	} elseif { $page_suffix eq "beverage" } {
		return [metadata fields -domain shot -category description -section {beverage people}]
	} else {
		return [metadata fields -domain shot -category description -section $page_suffix]
	}
}

proc ::dui::pages::DYE_v3::shot_to_text { {target edited} } {
	variable widgets
	variable data
	set ns [namespace current]
	set page [namespace tail $ns]

	if { $target ni {edited compare} } {
		msg -ERROR [namespace current] "shot_to_text: target value '$target' not supported. Use 'edited' or 'compare'"
		return 0
	}
	set shot [array get ${ns}::${target}_shot]
	array set shot_array $shot
	set tw $widgets(${target}_text)
	set sw $widgets(${target}_summary)

	set do_compare 0
	if { $target eq "edited" && $data(compare_clock) ne "" } {
		set do_compare 1
		set shot [array get ${ns}::compare_shot]
		array set comp_array $shot
	}
	unset -nocomplain shot

	### TOP PANEL (2-lines shot summary) ###########################################################
	$sw configure -state normal
	$sw delete 1.0 end
		
	#$sw tag configure which -foreground black -font [dui font get notosansuibold 15] -justify center	
	$sw tag configure which {*}[dui aspect list -type text_tag -style dyev3_which_shot -as_options yes]
	$sw tag configure profile_title {*}[dui aspect list -type text_tag -style dyev3_profile_title -as_options yes]
	
	if { $target eq "edited" } {
		if { $data(which_shot) eq "next" } {
			set which [translate "NEXT SHOT PLAN"]
		} elseif { $data(which_shot) eq "last" } {
			set which [translate "LAST SHOT"]
		} else {
			set which [translate "PAST SHOT"]
		}
	} else {
		if { $data(which_compare) eq "next" } {
			set which [translate "NEXT SHOT PLAN"]
		} elseif { $data(which_compare) eq "previous" } {
			set which [translate "PREVIOUS SHOT"]
		} else {
			set which [translate "PAST SHOT"]
		}
	}

	$sw insert insert [translate $which] which
	if { $data(which_shot) eq "next" } {
		if { [string is true $::plugins::DYE::settings(next_modified)] } {
			$sw insert insert " (modified*)" next_modified "\n"
		} else {
			$sw insert insert " " next_modified "\n"
		}
	} else {
		$sw insert insert ": " {} $shot_array(date_time) "date_time" "\n"
	}
	if { $shot_array(profile_title) eq "" } {
		$sw insert insert " " profile_title
	} else {
		$sw insert insert $shot_array(profile_title) "profile_title" " - "
	}
	
	if { $shot_array(grinder_dose_weight) eq "" } {
		set dose "?"
	} else {
		set dose $shot_array(grinder_dose_weight)
	}
	if { $shot_array(drink_weight) eq "" } {
		set yield "?"
	} else {
		set yield $shot_array(drink_weight)
	}
	set ratio [calc_ratio $dose $yield]

	$sw insert insert $dose grinder_dose_weight " g : " "" $yield drink_weight " g "
	if { $ratio eq "" } {
		$sw insert insert " " ratio
	} else {
		$sw insert insert "($ratio) " ratio
	}
	
	if { $data(which_shot) ne "next" && $shot_array(extraction_time) ne "" } {
		$sw insert insert [format [translate "in %.0f sec"] $shot_array(extraction_time)] extraction_time
	}

	$sw configure -state disabled

	### MAIN (BOTTOM) PANEL, full shot description ###########################################################
	$tw configure -state normal
	# First time this is run mark "chart:end" does not exist
	set first_time 0
	try { 
		$tw delete chart:end end 
	} on error err {
		set first_time 1
	}
	#$tw delete chart:end end

	# Tag styles
	$tw tag configure section {*}[dui aspect list -type text_tag -style dyev3_section -as_options yes]
	$tw tag configure field {*}[dui aspect list -type text_tag -style dyev3_field -as_options yes]  
	$tw tag configure value {*}[dui aspect list -type text_tag -style dyev3_value -as_options yes]
	$tw tag configure measure_unit {*}[dui aspect list -type text_tag -style dyev3_measure_unit -as_options yes]
	$tw tag configure compare -elide [expr {!$do_compare}] {*}[dui aspect list -type text_tag -style dyev3_compare -as_options yes]
	set non_highlighted_aspects [dui aspect list -type text_tag -style dyev3_field_nonhighlighted -as_options yes]

#	$tw tag configure section -foreground black -font [dui font get notosansuibold 17] -spacing1 [dui platform rescale_y 20]
#	$tw tag configure field -foreground brown -lmargin1 [dui platform rescale_x 35] -lmargin2 [dui platform rescale_x 45]  
#	$tw tag configure value -foreground blue
	
#	# Add graph to the shot text widget
	if { $first_time } {
		foreach mark {summary summary:end chart} {
			$tw mark set $mark insert
			$tw mark gravity $mark left
		}
		$tw window create insert -window $widgets(${target}_graph) -align center
		
		$tw mark set chart:end insert
		$tw mark gravity chart:end left
		
	}
	
	# Shot meta description
	set sections [dict create beans:beans_desc Beans beans:beans_batch "Beans batch" equipment Equipment \
		extraction Extraction people People beverage Beverage tasting Tasting]
	#bean_batch "Beans batch"
	
	foreach section_key [dict keys $sections] {
		set section_parts [split $section_key :]
		if { [llength $section_parts] > 1 } {
			set section [lindex $section_parts 0]
			set subsection [lindex $section_parts 1]
			set section_tag $subsection
			set fields [metadata fields -domain shot -category description -section $section -subsection $subsection]
		} else {
			set section $section_key
			set section_tag $section
			set subsection ""
			set fields [metadata fields -domain shot -category description -section $section]
		}
		$tw mark set $section_tag insert 
		$tw mark gravity $section_tag left
		$tw insert insert [translate [dict get $sections $section_key]] [list section $section_tag] "\n"
		
		foreach field $fields {
			if { ![info exists shot_array($field)] } continue
			# Just make sure we don't have any remaining highlighted field (sometimes happen!) 
			$tw tag configure $field {*}$non_highlighted_aspects
			
			lassign [metadata get $field {name data_type n_decimals measure_unit}] name data_type n_decimals measure_unit
			$tw insert insert "[translate $name]: " [list field $field ${field}:n] 
			# ": " [list colon $field]
			
			if { $shot_array($field) eq "" } {
				$tw insert insert " " [list value $field ${field}:v]
			} else {
				$tw insert insert $shot_array($field) [list value $field ${field}:v]
				if { $measure_unit ne "" } {
					$tw insert insert " $measure_unit" [list measure_unit $field ${field}:mu]
				}
			}

			if { $do_compare } {
				set compare_text [field_compare_string $shot_array($field) [value_or_default comp_array($field) ""] \
					$field $data_type $n_decimals]
				$tw insert insert $compare_text [list compare $field ${field}:c] "\n"
			} else {
				$tw insert insert "\n"
			}

			if { $target eq "edited" } {
				trace add variable ${ns}::edited_shot($field) write ${ns}::shot_variable_changed
			}
		}
		$tw mark set ${section_tag}:end insert
		$tw mark gravity ${section_tag}:end left 
	}

	# Shot management
	set section manage
	$tw mark set $section insert 
	$tw mark gravity $section left
	$tw insert insert [translate "Shot management"] [list section $section] "\n"
	
	if { [info exists shot_array(filename)] } {
		set field filename
		set filename [::plugins::SDB::get_shot_file_path $shot_array($field) 1]
		if { $filename ne "" } {
			$tw insert insert [translate File] [list field $field ${field}:n] ": " [list colon $field]
			$tw insert insert $filename [list readonly $field ${field}:v] "\n"
		}
	}
	if { $do_compare && [info exists comp_array(filename)] } {
		set field comp_filename
		set filename [::plugins::SDB::get_shot_file_path $comp_array(filename) 1]
		if { $filename ne "" } {
			$tw insert insert [translate "Compare to file"] [list field $field ${field}:n] ": " [list colon $field]
			$tw insert insert $filename [list readonly $field ${field}:v] "\n"
		}
	}
	
	if { [info exists shot_array(repository_links)] } {
		set field "visualizer"
		$tw insert insert [translate Visualizer] [list field $field ${field}:n] ": " [list colon $field]
		
		set visualizer_link ""
		set i 0
		while { $i < [llength $shot_array(repository_links)] } {
			set repo_link [lindex $shot_array(repository_links) $i]
			if { [lindex $repo_link 0] eq "Visualizer" && [lindex $repo_link 1] ne "" } {
				set visualizer_link [lindex $repo_link 1]
				break
			}
			incr i
		}
		
		if { $visualizer_link eq "" } {
			$tw insert insert [translate "Not uploaded"] [list $field ${field}:v] "\n"
		} else {
			$tw insert insert [translate "Uploaded"] [list link $field ${field}:v] "\n"
		}
	}

	set field app_version
	set app_version ""
	if { [info exists shot_array(app_version)] } {
		append app_version "app=$shot_array(app_version), "	
	}
	if { [info exists shot_array(firmware_version_number)] } {
		append app_version "fw=$shot_array(firmware_version_number), "
	}
	if { [info exists shot_array(skin)] } {
		append app_version "skin=$shot_array(skin), "
	}
	if { [info exists shot_array(enabled_plugins)] } {
		append app_version "plugins=$shot_array(enabled_plugins), "
	}

	if { $app_version ne "" } {
		set app_version [string range $app_version 0 end-2]
		$tw insert insert [translate "Versions"] [list field $field ${field}:n] ": " [list colon $field]
		$tw insert insert $app_version [list readonly $field ${field}:v] "\n"
	}

	$tw mark set ${section}:end insert
	$tw mark gravity ${section}:end left 

	# Bind "clickable" tags 
	if {$target eq "edited" } { 
		$tw tag bind section [dui platform button_press] [list + ${ns}::click_shot_text %W %x %y %X %Y]
		$tw tag bind field [dui platform button_press] [list + ${ns}::click_shot_text %W %x %y %X %Y]
		$tw tag bind value [dui platform button_press] [list + ${ns}::click_shot_text %W %x %y %X %Y]
	}
	
	$tw configure -state disabled
	return 1
}

proc ::dui::pages::DYE_v3::field_compare_string { value compare {field {}} {data_type {}} {n_decimals {}} } {
	#msg -INFO [namespace current] "COMPARING $value and $compare, field=$field, data_type=$data_type, n_dec=$n_decimals"	
	if { [string trim $value] eq "" || [string trim $compare] eq "" } {
		return " "
	}

	if { $field ne "" && ($data_type eq "" || $n_decimals eq "") } {
		lassign [metadata get $field {data_type n_decimals}] data_type n_decimals
		if { $data_type eq "" } {
			if { [string is double $value] && [string is double $compare] } {
				set data_type "number"
				if { [string is integer $value] && [string is integer $compare] } {
					set n_decimals 0
				} else {
					set n_decimals 2
				}
			} else {
				set data_type text
			}
		}
	}
	
	if { $data_type eq "long_text" } {
		set compare_text " "
	} elseif { $data_type eq "number" } {
		if { $value == $compare } {
			set compare_text "  ="
		} else {
			set comparison [expr {$value-$compare}]
			set compare_text [format "%.${n_decimals}f" $comparison]
			if { $comparison > 0 } {
				set compare_text "+$compare_text"
			}
		}
	} else {
		#{text category date boolean}
		if { $value eq $compare } {
			set compare_text "  ="
		} else {
			set compare_text "[translate was] \"$compare\""
		}
	}
	
	if { $compare_text ne "  =" && [string trim $compare_text] ne "" } {
		set compare_text "  (${compare_text})"
	}
	return $compare_text
}

proc ::dui::pages::DYE_v3::calc_ratio { {dose {}} {yield {}} {target edited} } {
	variable edited_shot
	variable compare_shot
	if { $dose eq "" && $yield eq "" && $target ni {edited compare} } {
		msg -WARNING [namesapce current] "calc_ratio: target '$target' not recognized, must be one of {target edited}. Assuming 'edited'"
		set target "edited"
	}
	
	if { $dose eq "" } {
		set dose [subst \$${target}_shot(grinder_dose_weight)]
	}
	if { $yield eq "" } {
		set yield [subst \$${target}_shot(drink_weight)]
	}
	
	set ratio ""
	if { [string is double -strict $dose] && [string is double -strict $yield] } {
		set ratio "1:[format {%.1f} [expr {$yield/$dose}]]"
	}
	return $ratio
}

proc ::dui::pages::DYE_v3::calc_days_offroast { {espresso_clock {}} {roast_date {}} {freeze_date {}} {unfreeze_date {}} {target edited} } {
	variable edited_shot
	variable compare_shot
	variable data
	set days_offroast ""
	
	if { $espresso_clock eq "" && $target ni {edited compare} } {
		msg -WARNING [namesapce current] "calc_days_offroast: target '$target' not recognized, must be one of {target edited}. Assuming 'edited'"
		set target "edited"
	}
	
	if { $espresso_clock eq "" } {
		if { $target eq "edited" && $data(which_shot) eq "next" } {
			set espresso_clock [clock seconds]
		} else {
			set espresso_clock [subst \$${target}_shot(clock)]
		}
	}
	set date_format [dui cget date_input_format]
	if { $date_format eq "" } {
		set date_format "%d/%m/%Y"
	}
	
	foreach fn { roast_date freeze_date unfreeze_date } { 
		if { [subst \$$fn] eq "" } {
			set $fn [subst \$${target}_shot(bean_$fn)]
		}
		set dt [subst \$$fn]
		if { $dt ne "" && ![string is integer $dt] } {
			try {
				set $fn [clock scan $dt -format $date_format]
			} on error err {
				set $fn ""
			}
		}
	}
	
	if { [string is integer -strict $roast_date] } {
		set days_offroast [expr {round(($espresso_clock - $roast_date) / double(60*60*24))}]
	}
	
	return $days_offroast
}

proc ::dui::pages::DYE_v3::shot_variable_changed { arrname varname op } {
	if { $arrname ne "::dui::pages::DYE_v3::edited_shot" } return
	if { $op ne "write" } return
	variable original_shot
	variable edited_shot
	variable data
	
	highlight_field $varname
	change_text_shot_field $varname ${arrname}(${varname})
#	if { $edited_shot($varname) ne $original_shot($varname) } {
#		set data(shot_modified) 1
#	}
	
	set related_fields [metadata fields -domain shot -category description -sdb_type_column1 $varname]
	append related_fields [metadata fields -domain shot -category description -sdb_type_column2 $varname]
	if { [llength $related_fields] > 0 } {
		set value [subst \$${arrname}(${varname})]
		foreach field $related_fields {
			if { [metadata get $field data_type] eq "category" && [dui page has_item [dui page current] ${field}-dda] } {
				dui item enable_or_disable [expr {$value ne ""}] [dui page current] ${field}-dda
			}
		}
	}
	
	if { $data(which_shot) eq "next" && $edited_shot($varname) ne $original_shot($varname) } {
		#if { $::plugins::DYE::settings(next_modified) != 1 } {
			variable widgets
			set ::plugins::DYE::settings(next_modified) 1
			modify_text_tag $widgets(edited_summary) next_modified " (modified*)"
		#}	
	}
}

proc ::dui::pages::DYE_v3::highlight_field { field {widget {}} } { 
	variable widgets
	variable data
	set is_edited_shot 0
	if { $widget eq "" } { 
		set widget $widgets(edited_text) 
		set is_edited_shot 1
	}
	if { $is_edited_shot } {
		if { $data(field_being_edited) eq $field } {
			return
		}
		if { $data(field_being_edited) ne "" } {
			unhighlight_field $data(field_being_edited) $widget
		}
		set data(field_being_edited) $field
	}
	
	$widget tag configure $field {*}[dui aspect list -type text_tag -style dyev3_field_highlighted -as_options yes]
	$widget see $field.first
	$widget see $field.last
}

proc ::dui::pages::DYE_v3::unhighlight_field { field {widget {}} } { 	
	variable data
	if { $widget eq "" } {
		variable widgets
		set widget $widgets(edited_text)
	}
	if { $field eq "" } {
		set field $data(field_being_edited)
	}
	
	$widget tag configure $field {*}[dui aspect list -type text_tag -style dyev3_field_nonhighlighted -as_options yes] 
	
	if { $field eq $data(field_being_edited) } {
		set data(field_being_edited) ""
	}
	
}

proc ::dui::pages::DYE_v3::change_text_shot_field { field var {widget {}} } { 
	variable widgets
	variable data
	variable edited_shot
	variable compare_shot
	if { $widget eq "" } { 
		set widget $widgets(edited_text)
	}
	set value [subst \$$var]
	set start_index [$widget index ${field}:v.first]
	
	if { $start_index eq "" } {
		msg -WARNING [namespace current] "change_text_shot_field: tag '${field}:v' not found in text shot widget '$widget'"
		return
	}
	
	modify_text_tag $widget ${field}:v $value
	
	# If there's no measure unit it may be because the field was originally empty and the measure unit was not shown.
	set mu_start ""
	catch { set mu_start [$widget index ${field}:mu.first] }
	if { $value ne "" && $mu_start eq "" } {
		set measure_unit [lindex [metadata get $field measure_unit] 0]
		if { $measure_unit ne "" } {
			$widget configure -state normal
			$widget insert [$widget index ${field}:v.last] " $measure_unit" [list measure_unit $field ${field}:mu]
			$widget configure -state disabled
		}
	}
	
	if { $data(which_compare) ne "" } {
		set compare [value_or_default compare_shot($field) ""]
		set compare_text [field_compare_string $value $compare $field]
		modify_text_tag $widget ${field}:c "$compare_text"
	}	

	# Some fields need to be modified on the summary top panel too
	if { $field in {date_time profile_title grinder_dose_weight drink_weight extraction_time} } {
		if { $field in {grinder_dose_weight drink_weight} } {
			if { $value eq "" } {
				set value "?"
			}
			set ratio [calc_ratio "" "" edited]
		}

		set widget $widgets(edited_summary)	
		
		modify_text_tag $widget $field $value
		
		if { $field in {grinder_dose_weight drink_weight} } {
			if { $ratio eq "" } {
				set ratio " "
			} else {
				set ratio "($ratio) "
			}
			modify_text_tag $widget ratio $ratio
		}
	}
}

proc ::dui::pages::DYE_v3::modify_text_tag { widget tag new_value } {
	set start_index ""
	try {
		set start_index [$widget index ${tag}.first]
	} on error err {
		msg -ERROR [namespace current] "modify_text_tag: can't find tag '$tag' in text widget '$widget'"
	}
	if { $new_value eq "" } {
		# An empty string would make the field tag disappear
		set new_value " "
	}
	if { $start_index ne "" } {
		set tags [$widget tag names ${tag}.first]
		$widget configure -state normal 
		$widget delete $start_index ${tag}.last	
		$widget insert $start_index $new_value $tags
		$widget configure -state disabled
	}
}

proc ::dui::pages::DYE_v3::click_shot_text { widget x y X Y } {
	variable widgets
	variable data

	# On PC the coordinates taken by [Text tag names] are screen absolute, whereas on android we need to first transform
	# them, then make then relative to the Text widget left-top coordinate	
	set rx [dui platform translate_coordinates_finger_down_x $x]
	set ry [dui platform translate_coordinates_finger_down_y $y]
	if { $::android == 1 } {
		set wcoords [[dui canvas] bbox $widget]
		set rx [expr {$rx-[lindex $wcoords 0]}]
		set ry [expr {$ry-[lindex $wcoords 1]}]
	}
	
	set clicked_tags [$widget tag names @$rx,$ry]
	
	set type [lindex $clicked_tags 0] 
	if { $type ni {section field colon value} } {
		return
	}
	set field [lindex $clicked_tags 1]
	
	if { $type eq "section" } {
		navigate_to $field
	}

#	set tag_rg [$tw tag ranges $field_name]
#	set tag_start [lindex $tag_rg 0] 
#	set tag_end [lindex $tag_rg 1]
#	set value [$tw get $tag_start $tag_end] 
#	
#	set data(test_msg) "Clicked ${field_name}!\r(from $tag_start to $tag_end)\rValue is '$value'"
#	#$tw tag configure comp -elide [expr {![$tw tag cget comp -elide]}]
#	
#	$tw delete $tag_start $tag_end
#	$tw insert $tag_start "New value" [list value $field_name]
	
	#after 1000 {set ::dui::pages::DYE_v3::data(test_msg) ""} 
}

proc ::dui::pages::DYE_v3::calc_chart_stage_stats { {target edited} {stage_index 0} } {
	variable data

	if { $target eq "compare" } { 
		set target_str "_comp"
	} else {
		set target_str ""
		set target "edited"
	}
	vector create subvec
	
	foreach var {elapsed pressure flow flow_weight weight temperature_basket} {
		set vecname [namespace current]::vectors::${target}::${var}
		
		if { [info commands $vecname] eq $vecname && [$vecname length] > 1 } {
			#$vecname variable vec
			if { [subvec length] > 0 } {
				subvec delete 0:end
			}
			subvec append [$vecname range 1 end]
			
			if { $var eq "elapsed" } {
				set start_idx 0
			} else {
				set start_idx 1
			}
			if { $var eq "elapsed" && $stage_index == 0 } {
				set data(chart_stage${target_str}_${var}_start) 0.0
			} else {
				set data(chart_stage${target_str}_${var}_start) [format {%.2f} $subvec(0)]
			}
			set data(chart_stage${target_str}_${var}_end) [format {%.2f} $subvec(end)]
			if { $var ne "elapsed" } {
				set data(chart_stage${target_str}_${var}_min) [format {%.2f} [vector expr min(subvec)]]
				set data(chart_stage${target_str}_${var}_max) [format {%.2f} [vector expr max(subvec)]]
				set data(chart_stage${target_str}_${var}_avg) [format {%.2f} [vector expr mean(subvec)]]
			}
		} else {
			set data(chart_stage${target_str}_${var}_start) "-"
			set data(chart_stage${target_str}_${var}_end) "-"
			if { $var ne "elapsed" } {
				set data(chart_stage${target_str}_${var}_min) "-"
				set data(chart_stage${target_str}_${var}_max) "-"
				set data(chart_stage${target_str}_${var}_avg) "-"
			}
		}
	}
}

proc ::dui::pages::DYE_v3::previous_chart_stage { } {
}

proc ::dui::pages::DYE_v3::next_chart_stage { } {
}

proc ::dui::pages::DYE_v3::archive_shot { } {
}

proc ::dui::pages::DYE_v3::delete_shot { } {
	
}

proc ::dui::pages::DYE_v3::export_shot { } {

}

proc ::dui::pages::DYE_v3::upload_to_visualizer { } {
	
}

proc ::dui::pages::DYE_v3::download_from_visualizer { } {
	
}

proc ::dui::pages::DYE_v3::visualizer_browse { } {
	
}
	
proc ::dui::pages::DYE_v3::move_backward {} {
	variable data
	save_description
	
	if { $data(which_shot) eq "next" } {
		dui page load [dui page current] -which_shot last -reload yes
	} else {
		set previous_clock [::plugins::SDB::previous_shot $data(clock)]
		if { $previous_clock ne "" && $previous_clock > 0 } {
			dui page load [dui page current] -which_shot $previous_clock -reload yes
		}
	}
}

proc ::dui::pages::DYE_v3::move_forward {} {
	variable data
	if { $data(which_shot) eq "next" } return
	save_description
	
	if { $data(which_shot) eq "last" || $data(clock) == $::settings(espresso_clock) } {
		dui page load [dui page current] -which_shot next -reload yes
	} else {		
		set next_clock [::plugins::SDB::next_shot $data(clock)]
		if { $next_clock ne "" && $next_clock > 0} {
			dui page load [dui page current] -which_shot $next_clock -reload yes
		}
	}
}

proc ::dui::pages::DYE_v3::move_to_next {} {
	variable data
	if { $data(which_shot) eq "next" } return
	save_description
	
	dui page load [dui page current] -which_shot next -reload yes
}

proc ::dui::pages::DYE_v3::select_shot {} {
	save_description
	
	array set shots [::plugins::SDB::shots "clock shot_desc" 1 {} 500]
	dui page open_dialog dui_item_selector {} $shots(shot_desc) -values_ids $shots(clock) \
		-page_title [translate "Select the shot to describe"] -theme [dui theme get] \
		-return_callback [namespace current]::select_shot_callback -listbox_width 2300
}

proc ::dui::pages::DYE_v3::select_shot_callback { shot_desc shot_id args } {
	variable data

	if { [llength $shot_id] == 0 } { 
		dui page show [menu_to_page $data(menu)]
	} else {
		set previous_page $data(previous_page)
		dui page load [menu_to_page $data(menu)] -reload yes -which_shot [lindex $shot_id 0]
		set data(previous_page) $previous_page
	}
}

proc ::dui::pages::DYE_v3::search_shot {} {
	save_description
	dui page load DYE_fsh -page_title [translate "Select the shot to describe"] -callback_cmd [namespace current]::search_shot_callback
}

proc ::dui::pages::DYE_v3::search_shot_callback { selected_shots matched_shots } {
	variable data
	if { [llength $selected_shots] == 0 } { 
		dui page show [menu_to_page $data(menu)]
	} else {
		set previous_page $data(previous_page)
		dui page load [menu_to_page $data(menu)] -reload yes -which_shot [lindex $selected_shots 0]
		set data(previous_page) $previous_page
	}
}

proc ::dui::pages::DYE_v3::open_history_viewer {} {
	save_description
	
	if { $::settings(skin) eq "DSx" } {
		::history_prep
	} else {
		history_viewer open -callback_cmd [namespace current]::history_viewer_callback
	}
}

proc ::dui::pages::DYE_v3::history_viewer_callback { left_clock right_clock } {
	variable data
	
	if { $left_clock eq "" } { 
		dui page show [menu_to_page $data(menu)] 
	} else {
		set previous_page $data(previous_page)
		dui page load [menu_to_page $data(menu)] -reload yes -which_shot [lindex $left_clock 0]
		set data(previous_page) $previous_page
	}
}

proc ::dui::pages::DYE_v3::go_to_settings {} {
	save_description
	dui page load DYE_settings
}

proc ::dui::pages::DYE_v3::save_description {} {
	variable data
	variable edited_shot
	variable original_shot
	array set changes {}
	
	foreach field [metadata fields -domain shot -category description] {
		if { $edited_shot($field) ne $original_shot($field) } {
			set changes($field) $edited_shot($field)
		}
	}	
	if { [array size changes] == 0 } {
		return
	}
	
	if { $data(which_shot) eq "next" } {
		foreach field [array names changes] {
			if { [info exists ::plugins::DYE::settings(next_$field)] } {
				set ::plugins::DYE::settings(next_$field) $edited_shot($field)
			}
		}
		plugins save_settings DYE
		::plugins::DYE::define_next_shot_desc
	} else {
		if { $data(which_shot) eq "last" } {
			foreach field [array names changes] {
				if { [info exists ::settings($field)] } {
					set ::settings($field) $edited_shot($field)
				}
			}
			::save_settings
			::plugins::DYE::define_last_shot_desc
		}
		
		::plugins::SDB::modify_shot_file $data(path) changes
		
		if { $::plugins::SDB::settings(db_persist_desc) == 1 } {
			set changes(file_modification_date) [file mtime $data(path)]
			::plugins::SDB::update_shot_description $data(clock) changes
		}
	}
}

proc ::dui::pages::DYE_v3::page_cancel {} {
	variable data
	# Normally we only save changes when leaving the page, but also when leaving to "dialog" pages like shot selection,
	# so if cancel is clicked we make sure to revert to original shot values and resave. 
	
	set data(ok_cancel_clicked) 1
	
	if { $data(callback_cmd) ne "" } {
		$data(callback_cmd) {}
	} else {
		dui page show $data(previous_page)
	}
	
	page_unload
}

proc ::dui::pages::DYE_v3::page_done {} {
	variable data
	set data(ok_cancel_clicked) 1
	save_description

	if { $data(callback_cmd) ne "" } {
		$data(callback_cmd) {}
	} else {
		dui page show $data(previous_page)
	}
	
	page_unload
}

# TODO: If we unset the array, traces created on widget creation are removed, don't do!!!
proc ::dui::pages::DYE_v3::page_unload {} {
#	set ns [namespace current]
#	# Force removal of shot arrays, so all traces are removed too
#	unset -nocomplain ${ns}::original_shot
#	unset -nocomplain ${ns}::edited_shot
#	unset -nocomplain ${ns}::compare_shot
}

# Ensure the shot description is saved if it has been modified and we're leaving the page unexpectedly, for example
# if a GHC button is tapped while editing the shot, or the machine is starting up .
proc ::dui::pages::DYE_v3::hide { page_to_hide page_to_show } {
	variable data
	variable pages
	
	if { !$data(ok_cancel_clicked) && [string range $page_to_show 0 5] ni $pages && \
			$page_to_show ni {dui_number_editor DYE_fsh DYE_settings} } {
		save_description
		page_unload
	}
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

