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
		
		dialog_page.bg_shape round_outline
		dialog_page.bg_color $::DSx_settings(bg_colour)
		dialog_page.fill $::DSx_settings(bg_colour)
		dialog_page.outline white
		dialog_page.width 1
		
		font.font_family "$::DSx_settings(font_name)"
		font.font_size $default_font_size
		
		dtext.font_family "$::DSx_settings(font_name)"
		dtext.font_size $default_font_size
		dtext.fill $::DSx_settings(font_colour)
		dtext.disabledfill $disabled_colour
		dtext.anchor nw
		dtext.justify left
		
		dtext.fill.remark $::DSx_settings(orange)
		dtext.fill.error $::DSx_settings(red)
		dtext.font_family.section_title "$::DSx_settings(font_name)"
		
		dtext.font_family.page_title "$::DSx_settings(font_name)"
		dtext.font_size.page_title 24
		dtext.fill.page_title $::DSx_settings(heading_colour)
		dtext.anchor.page_title center
		dtext.justify.page_title center
					
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
		dbutton_label.font_family.insight_ok "$::DSx_settings(font_name)"
		dbutton_label.font_size.insight_ok 19
		
		dclicker.fill {}
		dclicker.disabledfill {}
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
		entry.disabledforeground black
		entry.font_size $default_font_size
		entry.insertbackground orange
		 
		multiline_entry.relief sunken
		multiline_entry.foreground $::DSx_settings(font_colour)
		multiline_entry.bg $::DSx_settings(bg_colour)
		multiline_entry.width 2
		multiline_entry.font_family "$::DSx_settings(font_name)"
		multiline_entry.font_size $default_font_size
		multiline_entry.width 15
		multiline_entry.height 5
		multiline_entry.insertbackground orange
		multiline_entry.wrap word
	
		dcombobox.relief sunken
		dcombobox.bg $::DSx_settings(bg_colour)
		dcombobox.width 2
		dcombobox.font_family "$::DSx_settings(font_name)"
		dcombobox.font_size $default_font_size
		
		dbutton_dda.shape {}
		dbutton_dda.fill {}
		dbutton_dda.bwidth 70
		dbutton_dda.bheight 65
		dbutton_dda.symbol "sort-down"
		
		dbutton_dda_symbol.pos {0.5 0.2}
		dbutton_dda_symbol.font_size 24
		dbutton_dda_symbol.anchor center
		dbutton_dda_symbol.justify center
		dbutton_dda_symbol.fill $::DSx_settings(font_colour)
		dbutton_dda_symbol.disabledfill $disabled_colour
				
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
		
		listbox_label.font_family.section_title "$::DSx_settings(font_name)"
		
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
		
		text.bg $::DSx_settings(bg_colour)
		text.foreground $::DSx_settings(font_colour)
		text.font_size $default_font_size
		text.relief flat
		text.highlightthickness 1
		text.insertbackground orange
		text.wrap word
	}]
	
	# dui_number_editor page styles
	dui aspect set -theme DSx {
		dbutton.shape.dne_clicker outline 
		dbutton.bwidth.dne_clicker 120 
		dbutton.bheight.dne_clicker 140 
		dbutton.fill.dne_clicker {}
		dbutton.width.dne_clicker 3
		dbutton.anchor.dne_clicker center
		dbutton_symbol.pos.dne_clicker {0.5 0.4} 
		dbutton_symbol.anchor.dne_clicker center 
		dbutton_symbol.font_size.dne_clicker 20
		dbutton_label.pos.dne_clicker {0.5 0.8} 
		dbutton_label.font_size.dne_clicker 10 
		dbutton_label.anchor.dne_clicker center
		
		dbutton.shape.dne_pad_button outline 
		dbutton.bwidth.dne_pad_button 280 
		dbutton.bheight.dne_pad_button 220
		dbutton.fill.dne_pad_button {}
		dbutton.width.dne_pad_button 3
		dbutton.anchor.dne_pad_button nw
		dbutton_label.pos.dne_pad_button {0.5 0.5} 
		dbutton_label.font_family.dne_pad_button notosansuibold 
		dbutton_label.font_size.dne_pad_button 24 
		dbutton_label.anchor.dne_pad_button center
	}
	
	# DUI confirm dialog styles
	dui aspect set -theme DSx {
		dbutton.shape.dui_confirm_button outline
		dbutton.bheight.dui_confirm_button 100
		dbutton.width.dui_confirm_button 1
		dbutton.arc_offset.dui_confirm_button 20
	}

	# Menu dialogs
	dui aspect set -theme DSx [subst {
		dtext.font_size.menu_dlg_title +1
		dtext.anchor.menu_dlg_title center
		dtext.justify.menu_dlg_title center
		
		dbutton.shape.menu_dlg_close rect 
		dbutton.fill.menu_dlg_close {} 
		dbutton.symbol.menu_dlg_close times
		dbutton_symbol.pos.menu_dlg_close {0.5 0.5}
		dbutton_symbol.anchor.menu_dlg_close center
		dbutton_symbol.justify.menu_dlg_close center
		dbutton_symbol.fill.menu_dlg_close white
		
		dbutton.shape.menu_dlg_btn rect
		dbutton.fill.menu_dlg_btn {}
		dbutton.disabledfill.menu_dlg_btn {}
		dbutton_label.pos.menu_dlg_btn {0.3 0.4} 
		dbutton_label.anchor.menu_dlg_btn w
		dbutton_label.fill.menu_dlg_btn $::DSx_settings(font_colour)
		dbutton_label.disabledfill.menu_dlg_btn $disabled_colour
		
		dbutton_label1.pos.menu_dlg_btn {0.3 0.78} 
		dbutton_label1.anchor.menu_dlg_btn w
		dbutton_label1.fill.menu_dlg_btn #bbb
		dbutton_label1.disabledfill.menu_dlg_btn $disabled_colour
		dbutton_label1.font_size.menu_dlg_btn -3
		
		dbutton_symbol.pos.menu_dlg_btn {0.18 0.5} 
		dbutton_symbol.anchor.menu_dlg_btn center
		dbutton_symbol.fill.menu_dlg_btn white
		dbutton_symbol.disabledfill.menu_dlg_btn $disabled_colour
		
		line.fill.menu_dlg_sepline #ddd
		line.width.menu_dlg_sepline 1 
	}]
	
	# History Viewer styles
	set smooth $::settings(live_graph_smoothing_technique)
	dui aspect set -theme DSx [subst {
		graph_axis.color.hv_graph_axis $::DSx_settings(x_axis_colour)
		graph_axis.min.hv_graph_axis 0.0
		graph_axis.max.hv_graph_axis [expr 12 * 10]
		
		graph_xaxis.color.hv_graph_axis $::DSx_settings(x_axis_colour) 
		graph_xaxis.tickfont.hv_graph_axis "[DSx_font font 7]" 
		graph_xaxis.min.hv_graph_axis 0.0
			
		graph_yaxis.color.hv_graph_axis "#008c4c"
		graph_yaxis.tickfont.hv_graph_axis "[DSx_font font 7]"
		graph_yaxis.min.hv_graph_axis 0.0 
		graph_yaxis.max.hv_graph_axis $::DSx_settings(zoomed_y_axis_max)
		graph_yaxis.subdivisions.hv_graph_axis 5 
		graph_yaxis.majorticks.hv_graph_axis {0 1 2 3 4 5 6 7 8 9 10 11 12} 
		graph_yaxis.hide.hv_graph_axis 0
		
		graph_y2axis.color.hv_graph_axis "#206ad4"
		graph_y2axis.tickfont.hv_graph_axis "[DSx_font font 7]"
		graph_y2axis.min.hv_graph_axis 0.0 
		graph_y2axis.max.hv_graph_axis $::DSx_settings(zoomed_y2_axis_max)
		graph_y2axis.subdivisions.hv_graph_axis 2 
		graph_y2axis.majorticks.hv_graph_axis {0 1 2 3 4 5 6 7 8 9 10 11 12} 
		graph_y2axis.hide.hv_graph_axis 0

		graph_grid.color.hv_graph_grid $::DSx_settings(grid_colour)
		
		graph_line.linewidth.hv_temperature_goal $::DSx_settings(hist_temp_goal_curve) 
		graph_line.color.hv_temperature_goal #ffa5a6 
		graph_line.smooth.hv_temperature_goal $smooth 
		graph_line.dashes.hv_temperature_goal {5 5}
		
		graph_line.linewidth.hv_temperature_basket $::DSx_settings(hist_temp_curve) 
		graph_line.color.hv_temperature_basket #e73249
		graph_line.smooth.hv_temperature_basket $smooth 
		graph_line.dashes.hv_temperature_basket [list $::settings(chart_dashes_temperature)]

		graph_line.linewidth.hv_temperature_mix $::DSx_settings(hist_temp_curve) 
		graph_line.color.hv_temperature_mix #ff888c
		graph_line.smooth.hv_temperature_mix $smooth 

		graph_line.linewidth.hv_temperature_goal $::DSx_settings(hist_temp_goal_curve) 
		graph_line.color.hv_temperature_goal #ffa5a6 
		graph_line.smooth.hv_temperature_goal $smooth 
		graph_line.dashes.hv_temperature_goal {5 5}

		graph_line.linewidth.hv_pressure_goal $::DSx_settings(hist_goal_curve) 
		graph_line.color.hv_pressure_goal #69fdb3
		graph_line.smooth.hv_pressure_goal $smooth 
		graph_line.dashes.hv_pressure_goal {5 5}

		graph_line.linewidth.hv_flow_goal $::DSx_settings(hist_goal_curve) 
		graph_line.color.hv_flow_goal #7aaaff
		graph_line.smooth.hv_flow_goal $smooth 
		graph_line.dashes.hv_flow_goal {5 5}
			
		graph_line.linewidth.hv_pressure [dui platform rescale_x 8] 
		graph_line.color.hv_pressure #008c4c
		graph_line.smooth.hv_pressure $smooth 
		graph_line.dashes.hv_pressure [list $::settings(chart_dashes_pressure)]
			
		graph_line.linewidth.hv_flow [dui platform rescale_x 8] 
		graph_line.color.hv_flow #4e85f4
		graph_line.smooth.hv_flow $smooth 
		graph_line.dashes.hv_flow [list $::settings(chart_dashes_flow)]

		graph_line.linewidth.hv_flow_weight [dui platform rescale_x 8] 
		graph_line.color.hv_flow_weight #a2693d
		graph_line.smooth.hv_flow_weight $smooth 
		graph_line.dashes.hv_flow_weight [list $::settings(chart_dashes_flow)]

		graph_line.linewidth.hv_weight [dui platform rescale_x 8] 
		graph_line.color.hv_weight #a2693d
		graph_line.smooth.hv_weight $smooth 
		graph_line.dashes.hv_weight [list $::settings(chart_dashes_espresso_weight)]

		graph_line.linewidth.hv_state_change $::DSx_settings(hist_goal_curve) 
		graph_line.color.hv_state_change #AAAAAA

		graph_line.linewidth.hv_resistance $::DSx_settings(hist_resistance_curve) 
		graph_line.color.hv_resistance #e5e500
		graph_line.smooth.hv_resistance $smooth 
		graph_line.dashes.hv_resistance {6 2}		
	}]
	
#	dui aspect set { dbutton.width 3 }
	# DYE-specific styles
	dui aspect set -style dsx_settings {dbutton.shape outline dbutton.bwidth 384 dbutton.bheight 192 dbutton.width 3 
		dbutton_symbol.pos {0.2 0.5} dbutton_symbol.font_size 37 
		dbutton_label.pos {0.65 0.5} dbutton_label.font_size 17 
		dbutton_label1.pos {0.65 0.8} dbutton_label1.font_size 16}
	
	dui aspect set -style dsx_midsize {dbutton.shape outline dbutton.bwidth 220 dbutton.bheight 140 dbutton.width 6 dbutton.arc_offset 15
		dbutton_label.pos {0.7 0.5} dbutton_label.font_size 14 dbutton_symbol.font_size 24 dbutton_symbol.pos {0.25 0.5} }

	dui aspect set -style dsx_archive {dbutton.shape outline dbutton.bwidth 180 dbutton.bheight 110 dbutton.width 6 
		canvas_anchor nw anchor nw dbutton.arc_offset 12 dbutton_label.pos {0.7 0.5} dbutton_label.font_size 14 
		dbutton_symbol.font_size 24 dbutton_symbol.pos {0.3 0.5} }
	
	set bold_font [dui aspect get dtext font_family -theme default -style bold]
	dui aspect set -style dsx_done [list dbutton.shape outline dbutton.bwidth 220 dbutton.bheight 140 dbutton.width 5 \
		dbutton_label.pos {0.5 0.5} dbutton_label.font_size 20 dbutton_label.font_family $bold_font]
	
	dui aspect set -type symbol -style dye_main_nav_button { font_size 24 fill "#7f879a" }
	
	dui aspect set -type dtext -style section_header [list font_family $bold_font font_size 20]
	
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
			
	### DYE V3 STYLES ####
	set bg_color $::DSx_settings(bg_colour)
	#[dui aspect get page bg_color]
	set btn_spacing 100
	set half_button_width [expr {int(($::dui::pages::DYE_v3::page_coords(panel_width)-$btn_spacing)/2)}]
	
	dui aspect set -theme DSx [subst { 
		dbutton.bheight.dyev3_topnav 90 
		dbutton.shape.dyev3_topnav rect 
		dbutton.fill.dyev3_topnav grey
		dbutton_label.font_size.dyev3_topnav -1 
		dbutton_label.pos.dyev3_topnav {0.5 0.5} 
		dbutton_label.anchor.dyev3_topnav center 
		dbutton_label.justify.dyev3_topnav center 
	
		dbutton.bwidth.dyev3_nav_button 100 
		dbutton.bheight.dyev3_nav_button 120
		dbutton.fill.dyev3_nav_button {} 
		dbutton.disabledfill.dyev3_nav_button {}
		dbutton_symbol.pos.dyev3_nav_button {0.5 0.5} 
		dbutton_symbol.fill.dyev3_nav_button #ccc
		
		text.font_size.dyev3_top_panel_text -1
		text.yscrollbar.dyev3_top_panel_text no
		text.bg.dyev3_top_panel_text $bg_color
		text.borderwidth.dyev3_top_panel_text 0
		text.highlightthickness.dyev3_top_panel_text 0
		text.relief.dyev3_top_panel_text flat
		
		text.font_size.dyev3_bottom_panel_text -1
	
		dtext.font_family.dyev3_right_panel_title "$::DSx_settings(font_name)" 
		dtext.font_size.dyev3_right_panel_title +2
		dtext.fill.dyev3_right_panel_title $::DSx_settings(font_colour)
		dtext.anchor.dyev3_right_panel_title center
		dtext.justify.dyev3_right_panel_title center
		
		graph.background.dyev3_text_graph $bg_color 
		graph.plotbackground.dyev3_text_graph $bg_color 
		graph.borderwidth.dyev3_text_graph 1 
		graph.plotrelief.dyev3_text_graph flat
		
		dtext.font_size.dyev3_chart_stage_title +2 
		dtext.anchor.dyev3_chart_stage_title center 
		dtext.justify.dyev3_chart_stage_title center 
		dtext.fill.dyev3_chart_stage_title $::DSx_settings(font_colour)
		
		dtext.anchor.dyev3_chart_stage_colheader center 
		dtext.justify.dyev3_chart_stage_colheader center
		
		dtext.anchor.dyev3_chart_stage_value center
		dtext.justify.dyev3_chart_stage_value center
		
		dtext.anchor.dyev3_chart_stage_comp center
		dtext.justify.dyev3_chart_stage_comp center
		dtext.font_size.dyev3_chart_stage_comp -4
		dtext.fill.dyev3_chart_stage_comp grey
	
		line.fill.dyev3_chart_stage_line_sep grey

		dbutton.shape.dyev3_action_half outline
		dbutton.fill.dyev3_action_half {}
		dbutton.disabledfill.dyev3_action_half {}
		dbutton.width.dyev3_action_half [dui platform rescale_x 7]
		dbutton.outline.dyev3_action_half white
		dbutton.disabledoutline.dyev3_action_half $disabled_colour
		dbutton.bwidth.dyev3_action_half $half_button_width
		dbutton.bheight.dyev3_action_half 125
		dbutton_symbol.pos.dyev3_action_half {0.2 0.5} 
		dbutton_label.pos.dyev3_action_half {0.6 0.5}
		dbutton_label.width.dyev3_action_half [expr {$half_button_width-75}]
		
		#text_tag.foregroud.which_shot black
		text_tag.font.dyev3_which_shot "[dui font get $::DSx_settings(font_name) 15]"
		text_tag.justify.dyev3_which_shot center
		
		text_tag.justify.dyev3_profile_title center
		
		text_tag.foreground.dyev3_section $::DSx_settings(font_colour)
		text_tag.font.dyev3_section "[dui font get $::DSx_settings(font_name) 17]" 
		text_tag.spacing1.dyev3_section [dui platform rescale_y 20]
		
		text_tag.foreground.dyev3_field $::DSx_settings(font_colour) 
		text_tag.lmargin1.dyev3_field [dui platform rescale_x 35] 
		text_tag.lmargin2.dyev3_field [dui platform rescale_x 45]
		
		text_tag.foreground.dyev3_value #4e85f4
		
		text_tag.foreground.dyev3_compare grey
		
		text_tag.font.dyev3_field_highlighted "[dui font get $::DSx_settings(font_name) 15]"
		text_tag.background.dyev3_field_highlighted darkgrey
		text_tag.font.dyev3_field_nonhighlighted "[dui font get $::DSx_settings(font_name) 15]"
		text_tag.background.dyev3_field_nonhighlighted {}	
	}]

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
			-command [list ::plugins::DYE::open -which_shot next]
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
			-command { if { $::settings(history_saved) == 1 && [info exists ::DSx_settings(live_graph_time)] } { ::plugins::DYE::open -which_shot last }}
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
		-command [list ::plugins::DYE::open -which_shot last]]
	
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