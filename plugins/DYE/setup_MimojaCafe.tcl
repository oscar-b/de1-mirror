
# Setup the UI integration with the MimojaCafe skin. 
proc ::plugins::DYE::setup_ui_MimojaCafe {} {
	variable widgets 
	variable settings

	### SCREENSAVER ###
	# Makes the left side of the app screensaver clickable so that you can describe your last shot without waking up 
	# the DE1. Note that this would overlap with the DSx plugin management option, if enabled. Provided by Damian.
	if { [string is true $settings(describe_from_sleep)] } {
		set sleep_describe_symbol $settings(describe_icon)
		set sleep_describe_button_coords {0 0 230 230}
	} else { 
		set sleep_describe_symbol ""
		set sleep_describe_button_coords {0 0 0 0}
	}
	set widgets(describe_from_sleep) [dui add dbutton saver {*}$sleep_describe_button_coords -tags saver_to_dye \
		-symbol $sleep_describe_symbol -symbol_pos {0.5 0.5} -symbol_font_size 45 -canvas_anchor center -justify center \
		-command [list ::plugins::DYE::open -which_shot last]]
	
	### THEME DYE-SPECIFIC STYLES ###
	dui aspect set -style dye_main_nav_button [subst { dbutton.shape {} dbutton.fill {} dbutton_symbol.font_size 28 
		dbutton_symbol.fill [::theme button_text_dark] dbutton_symbol.disabledfill "#ccc"}]

	# Profile viewer
	dui aspect set [subst {
		shape.fill.dye_pv_icon_btn CadetBlue2
		dtext.fill.dye_pv_profile_title [::theme background_text]
		dtext.font_size.dye_pv_profile_title +8
		dtext.font_family.dye_pv_profile_title notosansuibold
		text_tag.spacing1.dye_pv_step [dui::platform::rescale_y 20] 
		text_tag.foreground.dye_pv_step Brown
		text_tag.lmargin1.dye_pv_step_line [dui::platform::rescale_x 35]
		text_tag.lmargin2.dye_pv_step_line [dui::platform::rescale_x 55]
		text_tag.foreground.dye_pv_value Blue4
	}]

}
