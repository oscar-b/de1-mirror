# Setup the UI integration with the DSx skin.
proc ::plugins::DYE::setup_ui_DSx {} {
	variable widgets 
	variable settings
	
	### DUI ASPECTS & STYLES ###
	dui theme add DSx
	dui theme set DSx

	# General DSx aspects
	dui font add_dir $::DSx_settings(font_dir)
	
	set disabled_colour "#35363d"
	set default_font_size 15
	dui aspect set -theme DSx [subst {
		page.bg_img {}
		page.bg_color $::DSx_settings(bg_colour)
		
		font.font_family $::DSx_settings(font_name)
		font.font_size $default_font_size
		
		text.font_family $::DSx_settings(font_name)
		text.font_size $default_font_size
		text.fill $::DSx_settings(font_colour)
		text.disabledfill $disabled_colour
		text.anchor nw
		text.justify left
		
		text.fill.remark $::DSx_settings(orange)
		text.fill.error $::DSx_settings(red)
		text.font_family.section_title $::DSx_settings(font_name)
		
		text.font_family.page_title $::DSx_settings(font_name)
		text.font_size.page_title 24
		text.fill.page_title $::DSx_settings(heading_colour)
		text.anchor.page_title center
		text.justify.page_title center
					
		symbol.font_family "Font Awesome 5 Pro-Regular-400"
		symbol.font_size 55
		symbol.fill $::DSx_settings(font_colour)
		symbol.disabledfill $disabled_colour
		symbol.anchor nw
		symbol.justify left
		
		symbol.font_size.small 24
		symbol.font_size.medium 40
		symbol.font_size.big 55
		
		dbutton.debug_outline yellow
		dbutton.fill {}
		dbutton.disabledfill {}
		dbutton.outline white
		dbutton.disabledoutline $disabled_colour
		dbutton.activeoutline $::DSx_settings(orange)
		dbutton.width 0
		
		dbutton_label.pos {0.5 0.5}
		dbutton_label.font_size [expr {$default_font_size+1}]
		dbutton_label.anchor center	
		dbutton_label.justify center
		dbutton_label.fill $::DSx_settings(font_colour)
		dbutton_label.disabledfill $disabled_colour
		
		dbutton_label1.pos {0.5 0.8}
		dbutton_label1.font_size [expr {$default_font_size-1}]
		dbutton_label1.anchor center
		dbutton_label1.justify center
		dbutton_label1.fill $::DSx_settings(font_colour)
		dbutton_label1.activefill $::DSx_settings(orange)
		dbutton_label1.disabledfill $disabled_colour
		
		dbutton_symbol.pos {0.2 0.5}
		dbutton_symbol.font_size 28
		dbutton_symbol.anchor center
		dbutton_symbol.justify center
		dbutton_symbol.fill $::DSx_settings(font_colour)
		dbutton_symbol.disabledfill $disabled_colour
		
		dbutton.shape.insight_ok outline
		dbutton.width.insight_ok 4
		dbutton.arc_offset.insight_ok 20
		dbutton.bwidth.insight_ok 480
		dbutton.bheight.insight_ok 118
		dbutton_label.font_family.insight_ok $::DSx_settings(font_name)
		dbutton_label.font_size.insight_ok 19
		
		dclicker.fill $::DSx_settings(font_colour)
		dclicker.disabledfill $disabled_colour
		dclicker_label.pos {0.5 0.5}
		dclicker_label.font_size 16
		dclicker_label.fill $::DSx_settings(font_colour)
		dclicker_label.anchor center
		dclicker_label.justify center
		
		entry.relief sunken
		entry.bg $::DSx_settings(bg_colour)
		entry.disabledbackground $disabled_colour
		entry.width 2
		entry.foreground $::DSx_settings(font_colour)
		entry.font_size $default_font_size
		 
		multiline_entry.relief sunken
		multiline_entry.foreground $::DSx_settings(font_colour)
		multiline_entry.bg $::DSx_settings(bg_colour)
		multiline_entry.width 2
		multiline_entry.font_family $::DSx_settings(font_name)
		multiline_entry.font_size $default_font_size
		multiline_entry.width 15
		multiline_entry.height 5
	
		dcombobox.relief sunken
		dcombobox.bg $::DSx_settings(bg_colour)
		dcombobox.width 2
		dcombobox.font_family $::DSx_settings(font_name)
		dcombobox.font_size $default_font_size
		
		dcombobox_ddarrow.font_size 24
		dcombobox_ddarrow.disabledfill $disabled_colour
		
		dcheckbox.font_family "Font Awesome 5 Pro"
		dcheckbox.font_size 18
		dcheckbox.fill $::DSx_settings(font_colour)
		dcheckbox.anchor nw
		dcheckbox.justify left
		
		dcheckbox_label.pos "en 30 -10"
		dcheckbox_label.anchor nw
		dcheckbox_label.justify left
		
		listbox.relief sunken
		listbox.borderwidth 1
		listbox.foreground $::DSx_settings(font_colour)
		listbox.background $::DSx_settings(bg_colour)
		listbox.selectforeground $::DSx_settings(bg_colour)
		listbox.selectbackground $::DSx_settings(font_colour)
		listbox.selectborderwidth 1
		listbox.disabledforeground $disabled_colour
		listbox.selectmode browse
		listbox.justify left
		
		listbox_label.pos "wn -10 0"
		listbox_label.anchor ne
		listbox_label.justify right
		
		listbox_label.font_family.section_title $::DSx_settings(font_name)
		
		scrollbar.orient vertical
		scrollbar.width 120
		scrollbar.length 300
		scrollbar.sliderlength 120
		scrollbar.from 0.0
		scrollbar.to 1.0
		scrollbar.bigincrement 0.2
		scrollbar.borderwidth 1
		scrollbar.showvalue 0
		scrollbar.resolution 0.01
		scrollbar.background $::DSx_settings(font_colour)
		scrollbar.foreground white
		scrollbar.troughcolor $::DSx_settings(bg_colour)
		scrollbar.relief flat
		scrollbar.borderwidth 0
		scrollbar.highlightthickness 0
		
		dscale.orient horizontal
		dscale.foreground "#4e85f4"
		dscale.background "#7f879a"
		dscale.sliderlength 75
		
		scale.orient horizontal
		scale.foreground "#FFFFFF"
		scale.background $::DSx_settings(font_colour)
		scale.troughcolor $::DSx_settings(bg_colour)
		scale.showvalue 0
		scale.relief flat
		scale.borderwidth 0
		scale.highlightthickness 0
		scale.sliderlength 125
		scale.width 150
		
		drater.fill $::DSx_settings(font_colour) 
		drater.disabledfill $disabled_colour
		drater.font_size 24
		
		rect.fill.insight_back_box $::DSx_settings(bg_colour)
		rect.width.insight_back_box 0
		line.fill.insight_back_box_shadow $::DSx_settings(bg_colour)
		line.width.insight_back_box_shadow 2
		rect.fill.insight_front_box $::DSx_settings(bg_colour)
		rect.width.insight_front_box 0
		
		graph.plotbackground $::DSx_settings(bg_colour)
		graph.borderwidth 1
		graph.background white
		graph.plotrelief raised
		graph.plotpady 0 
		graph.plotpadx 10
	}]
	
#	dui aspect set { dbutton.width 3 }
	# DUI-specific styles
	dui aspect set -style dsx_settings {dbutton.shape outline dbutton.bwidth 384 dbutton.bheight 192 dbutton.width 3 
		dbutton_symbol.pos {0.2 0.5} dbutton_symbol.font_size 37 
		dbutton_label.pos {0.65 0.5} dbutton_label.font_size 17 
		dbutton_label1.pos {0.65 0.8} dbutton_label1.font_size 16}
	
	dui aspect set -style dsx_midsize {dbutton.shape outline dbutton.bwidth 220 dbutton.bheight 140 dbutton.width 6 dbutton.arc_offset 15
		dbutton_label.pos {0.7 0.5} dbutton_label.font_size 14 dbutton_symbol.font_size 24 dbutton_symbol.pos {0.25 0.5} }

	dui aspect set -style dsx_archive {dbutton.shape outline dbutton.bwidth 180 dbutton.bheight 110 dbutton.width 6 
		canvas_anchor nw anchor nw dbutton.arc_offset 12 dbutton_label.pos {0.7 0.5} dbutton_label.font_size 14 
		dbutton_symbol.font_size 24 dbutton_symbol.pos {0.3 0.5} }
	
	set bold_font [dui aspect get text font_family -theme default -style bold]
	dui aspect set -style dsx_done [list dbutton.shape outline dbutton.bwidth 220 dbutton.bheight 140 dbutton.width 5 \
		dbutton_label.pos {0.5 0.5} dbutton_label.font_size 20 dbutton_label.font_family $bold_font]
	
	dui aspect set -type symbol -style dye_main_nav_button { font_size 24 fill "#7f879a" }
	
	dui aspect set -type text -style section_header [list font_family $bold_font font_size 20]
	
	dui aspect set -type dclicker -style dye_double [subst {shape {} fill $::DSx_settings(bg_colour) 
		disabledfill $::DSx_settings(bg_colour) width 0 orient horizontal use_biginc 1 
		symbol chevron-double-left symbol1 chevron-left symbol2 chevron-right symbol3 chevron-double-right}]
	dui aspect set -type dclicker_symbol -style dye_double [subst {pos {0.075 0.5} font_size 24 anchor center 
		fill "#7f879a" disabledfill $disabled_colour}]
	dui aspect set -type dclicker_symbol1 -style dye_double [subst {pos {0.275 0.5} font_size 24 anchor center 
		fill "#7f879a" disabledfill $disabled_colour}]
	dui aspect set -type dclicker_symbol2 -style dye_double [subst {pos {0.725 0.5} font_size 24 anchor center 
		fill "#7f879a" disabledfill $disabled_colour}]
	dui aspect set -type dclicker_symbol3 -style dye_double [subst {pos {0.925 0.5} font_size 24 anchor center 
		fill "#7f879a" disabledfill $disabled_colour}]

	dui aspect set -type dclicker -style dye_single {orient horizontal use_biginc 0 symbol chevron-left symbol1 chevron-right}
	dui aspect set -type dclicker_symbol -style dye_single {pos {0.1 0.5} font_size 24 anchor center fill "#7f879a"} 
	dui aspect set -type dclicker_symbol1 -style dye_single {pos {0.9 0.5} font_size 24 anchor center fill "#7f879a"} 
			
	### DE1APP SPLASH PAGE ###
	#	add_de1_variable "splash" 1280 1200 -justify center -anchor "center" -font [::plugins::DGUI::get_font $::plugins::DGUI::font 12] \
	#		-fill $::plugins::DYE::settings(orange) -textvariable {$::plugins::DGUI::db_progress_msg}
	
	### DSx HOME PAGE ###
	# Shortcuts menu (EXPERIMENTAL)
#	if { [info exists ::debugging] && $::debugging == 1 } {
#		::plugins::DGUI::add_symbol $::DSx_standby_pages 100 60 bars -size small -has_button 1 \
#			-button_cmd ::plugins::DYE::MENU::load_page
	#		add_de1_text "$::DSx_standby_pages" 100 60 -font fontawesome_reg_small -fill $::plugins::DGUI::font_color \
	#			-anchor "nw" -text $::plugins::DGUI::symbol_bars
	#		::add_de1_button "$::DSx_standby_pages" { ::plugins::DYE::MENU::load_page } 70 40 175 150
#	}
	
	# Icon and summary of next shot description below the profile & specs for next shot (left side)
	set x [lindex $settings(next_shot_DSx_home_coords) 0]
	set y [lindex $settings(next_shot_DSx_home_coords) 1]
	if { $x > 0 && $y > 0 } {
		set ::plugins::DYE::next_shot_desc [::plugins::DYE::define_next_shot_desc]
		
		dui add dbutton $::DSx_standby_pages [expr {$x-375}] [expr {$y-85}] [expr {$x+400}] [expr {$y+85}] \
			-tags launch_dye_next -symbol $settings(describe_icon) -symbol_pos {0.01 0.5} -symbol_anchor w -symbol_justify left \
			-symbol_font_size 28 -labelvariable {$::plugins::DYE::next_shot_desc} -label_pos {0.575 0.5} -label_anchor center \
			-label_justify center -label_font_size -2 -label_fill $settings(shot_desc_font_color) -label_width 700 \
			-command [list dui page load DYE next]
	}
	
	# Icon and summary of the current (last) shot description below the shot chart and steam chart (right side)
	set x [lindex $settings(last_shot_DSx_home_coords) 0]
	set y [lindex $settings(last_shot_DSx_home_coords) 1]
	if { $x > 0 && $y > 0 } {
		set ::plugins::DYE::last_shot_desc [::plugins::DYE::define_last_shot_desc]
		
		dui add dbutton $::DSx_standby_pages [expr {$x-375}] [expr {$y-85}] [expr {$x+400}] [expr {$y+85}] \
			-tags launch_dye_last -symbol $settings(describe_icon) -symbol_pos {0.99 0.5} -symbol_anchor e -symbol_justify right \
			-symbol_font_size 28 -labelvariable {$::plugins::DYE::last_shot_desc} -label_pos {0.45 0.5} -label_anchor center \
			-label_justify center -label_font_size -2 -label_fill $settings(shot_desc_font_color) -label_width 700 \
			-command { if { $::settings(history_saved) == 1 && [info exists ::DSx_settings(live_graph_time)] } {
					dui page load DYE current }}
	}
		
	### HISTORY VIEWER PAGE ###
	# Show espresso summary description (beans, grind, TDS, EY and enjoyment), and make it clickable to show to full
	# espresso description.
	dui add dbutton DSx_past 40 850 1125 975 -tags dsx_past_launch_dye -labelvariable {$::plugins::DYE::past_shot_desc} \
		-label_pos { 0.001 0.01 } -label_font_size -1 -label_anchor nw \
		-label_fill $::plugins::DYE::settings(shot_desc_font_color) -label_justify left -label_width 1100 \
		-command { if { [ifexists ::DSx_settings(past_shot_file) ""] ne "" } { dui page load DYE DSx_past } }
	
	dui add dbutton DSx_past 1300 850 2400 975 -tags dsx_past2_launch_dye -labelvariable {$::plugins::DYE::past_shot_desc2} \
		-label_pos { 0.001 0.01 } -label_font_size -1 -label_anchor nw \
		-label_fill $::plugins::DYE::settings(shot_desc_font_color) -label_justify left -label_width 1100 \
		-command { if { [ifexists ::DSx_settings(past_shot_file2) ""] ne "" } { dui page load DYE DSx_past2 } }
	
	# Update left and right side shot descriptions when they change
	trace add execution ::load_DSx_past_shot {leave} { ::plugins::DYE::define_past_shot_desc }
	trace add execution ::load_DSx_past2_shot {leave} { ::plugins::DYE::define_past_shot_desc2 }
	trace add execution ::clear_graph {leave} { ::plugins::DYE::define_past_shot_desc2 }	
	
	# Search/filter button for left side
	dui add dbutton DSx_past 935 1445 -tags dsx_past_filter -style dsx_archive -symbol filter \
		-labelvariable {$::dui::pages::DYE_fsh::data(left_filter_status)} -command { 
			if { $::dui::pages::DYE_fsh::data(left_filter_status) eq "on" } {
				set ::dui::pages::DYE_fsh::data(left_filter_status) "off"
				unset -nocomplain ::DSx_filtered_past_shot_files
				fill_DSx_past_shots_listbox
			} else {
				dui page load DYE_fsh
			}
		} 
	
	# Search/filter button for right side
	dui add dbutton DSx_past 1440 1445 -tags dsx_past_filter2 -style dsx_archive -symbol filter \
		-labelvariable {$::dui::pages::DYE_fsh::data(right_filter_status)}  -command {
			if { $::dui::pages::DYE_fsh::data(right_filter_status) eq "on" } {
				set ::dui::pages::DYE_fsh::data(right_filter_status) "off"
				unset -nocomplain ::DSx_filtered_past_shot_files2
				fill_DSx_past2_shots_listbox
			} else {
				dui page load DYE_fsh
			}
		} 
		
	### FULL PAGE CHARTS FROM HISTORY VIEWER ###
	dui add variable DSx_past_zoomed 1280 1535 -tags dye_shot_desc -textvariable {$::plugins::DYE::past_shot_desc_one_line} \
		-font_size 12 -fill $settings(shot_desc_font_color) -anchor center -justify center -width 2200

	dui add variable DSx_past2_zoomed 1280 1535 -tags dye_shot_desc -textvariable {$::plugins::DYE::past_shot_desc_one_line2} \
		-font_size 12 -fill $settings(shot_desc_font_color) -anchor center -justify center -width 2200
	
	trace add execution ::history_godshots_switch leave ::plugins::DYE::history_godshots_switch_leave_hook
	
	### SCREENSAVER ###
	# Makes the left side of the app screensaver clickable so that you can describe your last shot without waking up 
	# the DE1. Note that this would overlap with the DSx plugin management option, if enabled. Provided by Damian.
	if { [string is true $settings(describe_from_sleep)] } {
		set sleep_describe_symbol $settings(describe_icon)
		set sleep_describe_button_coords {230 0 460 230}
	} else { 
		set sleep_describe_symbol ""
		set sleep_describe_button_coords {0 0 0 0}
	}

	set widgets(describe_from_sleep) [dui add dbutton saver {*}$sleep_describe_button_coords -tags saver_to_dye \
		-symbol $sleep_describe_symbol -symbol_pos {0.5 0.5} -symbol_font_size 45 -symbol_anchor center -symbol_justify center \
		-command [list dui page load DYE current]]
	
	### DEBUG TEXT IN SOME PAGES ###
	# Show the debug text variable. Set it to any value I want to see on screen at the moment.
	if { $::DSx_skindebug == 1 } {
		dui add variable [concat $::plugins::DGUI::pages DSx_past $::DSx_standby_pages] 20 20 -tags dye_debug_text \
			-font_size 12 -fill orange -anchor "nw" -textvariable {$::plugins::DYE::debug_text}
		
		#-textvariable {enjoyment=$::plugins::DYE::DE::data(espresso_enjoyment)}
		
		# Debug button/text to do some debugging action (current to go straight to the ::plugins::DYE::DE page)
		# TODO This is not working. Console hides in background as soon as focus is given to anything, and cannot
		#	get it back.
		#add_de1_text "$::DSx_home_pages" 2300 225 -font [::plugins::DGUI::get_font $::plugins::DGUI::font 7] -fill $::DSx_settings(orange) -anchor "nw" \
		#	-text "CONSOLE"
		#add_de1_button "$::DSx_standby_pages" { catch { console hide } \
		# 	console show; set DYE_window {[focus -displayof .can]} } 2250 220 2500 280		
	}	
}

# Reset the descriptions of the shot in the right of the DSx History Viewer whenever the status of the right list is
# modified.
proc ::plugins::DYE::history_godshots_switch_leave_hook { args } {
	if { $::settings(skin) ne "DSx" } return
	if {[info exists ::DSx_settings(history_godshots)] && $::DSx_settings(history_godshots) ne "history" } {
		set ::plugins::DYE::past_shot_desc2 {}
		set ::plugins::DYE::past_shot_desc_one_line2 {}
	}
}