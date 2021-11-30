
# Setup the UI integration with the Insight Dark skin. Dark skin is identical to Insight except for the images and colors,
# so we invoke setup_ui_Insight for Insight Dark too, and use setup_ui_Insight_Dark just for declaring the DUI theme. 

proc ::plugins::DYE::setup_ui_Insight_Dark {} {
	### DUI ASPECTS & STYLES ###
	dui theme add Insight_Dark
	dui theme set Insight_Dark

	# General aspects
	set dark "#5a5d75"
	set lighter "#969eb1"
	set lightest "#bec7db"
	set background "#272d32"
	set button_bg "#3b4145"
	set disabled_colour $dark 
	set blue_water "#598ff6"
	#"#35363d"
	set font "notosansuiregular"
	set boldfont "notosansuibold"
	set default_font_size 16
	
	set toptab_selected_color "#aeb0b1"
	set toptab_unselected_color "#4f5254"
#	set startbutton_font_color "#aeb0b1"
#	set chart_background "#272d32"
#	set steam_control_background "#14181b"
#	set steam_control_foreground "#676b6e"
#	set water_level_widget_background "#20252a"
#	set water_level_widget_background_espresso "#191d20"
#	set ::grid_color "#444444"
#	set progress_text_color "#b1b9cd"
#	set noprogress_text_color "#5a5d75"
	
	dui aspect set -theme Insight_Dark [subst {
		page.bg_img {}
		page.bg_color $background
		
		dialog_page.bg_shape round_outline
		dialog_page.bg_color $background
		dialog_page.fill $background
		dialog_page.outline white
		dialog_page.width 1
		
		font.font_family "$font"
		font.font_size $default_font_size
		
		dtext.font_family "$font"
		dtext.font_size $default_font_size
		dtext.fill $lighter
		dtext.disabledfill $disabled_colour
		dtext.anchor nw
		dtext.justify left
		
		dtext.fill.remark orange
		dtext.fill.error red
		dtext.font_family.section_title "$font"
		
		dtext.font_family.page_title "$font"
		dtext.font_size.page_title 26
		dtext.fill.page_title $lightest
		dtext.anchor.page_title center
		dtext.justify.page_title center
					
		symbol.font_family "Font Awesome 5 Pro-Regular-400"
		symbol.font_size 55
		symbol.fill $lighter
		symbol.disabledfill $disabled_colour
		symbol.anchor nw
		symbol.justify left
		
		symbol.font_size.small 24
		symbol.font_size.medium 40
		symbol.font_size.big 55
		
		dbutton.debug_outline yellow
		dbutton.fill $button_bg
		dbutton.disabledfill $toptab_unselected_color
		dbutton.outline white
		dbutton.disabledoutline $toptab_unselected_color
		dbutton.width 0
		
		dbutton_label.pos {0.5 0.5}
		dbutton_label.font_size [expr {$default_font_size+1}]
		dbutton_label.anchor center	
		dbutton_label.justify center
		dbutton_label.fill $lighter
		dbutton_label.disabledfill $disabled_colour
		
		dbutton_label1.pos {0.5 0.8}
		dbutton_label1.font_size [expr {$default_font_size-1}]
		dbutton_label1.anchor center
		dbutton_label1.justify center
		dbutton_label1.fill $lighter
		dbutton_label1.activefill orange
		dbutton_label1.disabledfill $disabled_colour
		
		dbutton_symbol.pos {0.2 0.5}
		dbutton_symbol.font_size 28
		dbutton_symbol.anchor center
		dbutton_symbol.justify center
		dbutton_symbol.fill $lighter
		dbutton_symbol.disabledfill $disabled_colour
		
		dbutton.shape.insight_ok round
		dbutton.radius.insight_ok 30
		dbutton.bwidth.insight_ok 480
		dbutton.bheight.insight_ok 118
		dbutton_label.font_family.insight_ok "$boldfont"
		dbutton_label.font_size.insight_ok 19
		
		dclicker.fill {}
		dclicker.disabledfill {}
		dclicker_label.pos {0.5 0.5}
		dclicker_label.font_size 16
		dclicker_label.fill $lighter
		dclicker_label.anchor center
		dclicker_label.justify center
		
		entry.relief sunken
		entry.bg $background
		entry.disabledbackground $disabled_colour
		entry.width 2
		entry.foreground $lighter
		entry.disabledforeground black
		entry.font_size $default_font_size
		entry.insertbackground orange
			
		multiline_entry.relief sunken
		multiline_entry.foreground $lighter
		multiline_entry.bg $background
		multiline_entry.width 2
		multiline_entry.font_family "$font"
		multiline_entry.font_size $default_font_size
		multiline_entry.width 15
		multiline_entry.height 5
		multiline_entry.insertbackground orange
		multiline_entry.wrap word
	
		dcombobox.relief sunken
		dcombobox.bg $background
		dcombobox.width 2
		dcombobox.font_family "$font"
		dcombobox.font_size $default_font_size
		
		dbutton_dda.shape {}
		dbutton_dda.fill {}
		dbutton_dda.disabledfill {}
		dbutton_dda.bwidth 70
		dbutton_dda.bheight 65
		dbutton_dda.symbol "sort-down"
		
		dbutton_dda_symbol.pos {0.5 0.2}
		dbutton_dda_symbol.font_size 24
		dbutton_dda_symbol.anchor center
		dbutton_dda_symbol.justify center
		dbutton_dda_symbol.fill $lighter
		dbutton_dda_symbol.disabledfill $disabled_colour
				
		dcheckbox.font_family "Font Awesome 5 Pro"
		dcheckbox.font_size 18
		dcheckbox.fill $lighter
		dcheckbox.anchor nw
		dcheckbox.justify left
		
		dcheckbox_label.pos "e 30 0"
		dcheckbox_label.anchor w
		dcheckbox_label.justify left
		
		listbox.relief sunken
		listbox.borderwidth 1
		listbox.foreground $lighter
		listbox.background $background
		listbox.selectforeground $background
		listbox.selectbackground $lighter
		listbox.selectborderwidth 1
		listbox.disabledforeground $disabled_colour
		listbox.selectmode browse
		listbox.justify left
		
		listbox_label.pos "wn -10 0"
		listbox_label.anchor ne
		listbox_label.justify right
		
		listbox_label.font_family.section_title "$font"
		
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
		scrollbar.background $lighter
		scrollbar.foreground white
		scrollbar.troughcolor $background
		scrollbar.relief flat
		scrollbar.borderwidth 0
		scrollbar.highlightthickness 0
		
		dscale.orient horizontal
		dscale.foreground "#4e85f4"
		dscale.background "#7f879a"
		dscale.sliderlength 75
		
		scale.orient horizontal
		scale.foreground "#FFFFFF"
		scale.background $lighter
		scale.troughcolor $background
		scale.showvalue 0
		scale.relief flat
		scale.borderwidth 0
		scale.highlightthickness 0
		scale.sliderlength 125
		scale.width 150
		
		drater.fill $lighter 
		drater.disabledfill $disabled_colour
		drater.font_size 24
		
		rect.fill.insight_back_box $background
		rect.width.insight_back_box 0
		line.fill.insight_back_box_shadow $background
		line.width.insight_back_box_shadow 2
		rect.fill.insight_front_box $background
		rect.width.insight_front_box 0
		
		graph.plotbackground $background
		graph.borderwidth 1
		graph.background white
		graph.plotrelief raised
		graph.plotpady 0 
		graph.plotpadx 10
		
		text.bg $background
		text.foreground $lighter
		text.font_size $default_font_size
		text.relief flat
		text.highlightthickness 1
		text.insertbackground orange
		text.wrap word
		
		dselector.radius 40
		dselector.fill $button_bg
		dselector.selectedfill "#4e85f4"
		dselector.outline white
		dselector.selectedoutline "#4e85f4"
		dselector.label_fill "#c0c5e3"
		dselector.label_selectedfill white

		dtoggle.width 120
		dtoggle.height 68
		dtoggle.outline_width 0
		dtoggle.background "#c0c5e3"
		dtoggle.foreground white
		dtoggle.outline white
		dtoggle.selectedbackground "light blue"
		dtoggle.selectedforeground "#4e85f4"
		dtoggle.selectedoutline "dark blue"
		dtoggle.disabledbackground "#ccc"
		dtoggle.disabledforeground white
		dtoggle.disabledoutline white		
	}]
	
	# dui_number_editor page styles
	dui aspect set -theme Insight_Dark {
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
	dui aspect set -theme Insight_Dark {
		dbutton.shape.dui_confirm_button outline
		dbutton.bheight.dui_confirm_button 100
		dbutton.width.dui_confirm_button 1
		dbutton.arc_offset.dui_confirm_button 20
	}

	# Menu dialogs
	dui aspect set -theme Insight_Dark [subst {
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
		dbutton_label.pos.menu_dlg_btn {0.25 0.4} 
		dbutton_label.anchor.menu_dlg_btn w
		dbutton_label.fill.menu_dlg_btn $lighter
		dbutton_label.disabledfill.menu_dlg_btn $disabled_colour
		
		dbutton_label1.pos.menu_dlg_btn {0.25 0.78} 
		dbutton_label1.anchor.menu_dlg_btn w
		dbutton_label1.fill.menu_dlg_btn #bbb
		dbutton_label1.disabledfill.menu_dlg_btn $disabled_colour
		dbutton_label1.font_size.menu_dlg_btn -3
		
		dbutton_symbol.pos.menu_dlg_btn {0.15 0.5} 
		dbutton_symbol.anchor.menu_dlg_btn center
		dbutton_symbol.fill.menu_dlg_btn white
		dbutton_symbol.disabledfill.menu_dlg_btn $disabled_colour
		
		line.fill.menu_dlg_sepline #ddd
		line.width.menu_dlg_sepline 1
		
		dtext.fill.menu_dlg $lighter
		dtext.disabledfill.menu_dlg $disabled_colour
		dcheckbox.fill.menu_dlg $lighter
		dcheckbox.disabledfill.menu_dlg $disabled_colour
		dcheckbox_label.fill.menu_dlg $lighter
		dcheckbox_label.disabledfill.menu_dlg $disabled_colour
		
		dbutton.shape.menu_dlg outline
		dbutton.arc_offset.menu_dlg 25
		dbutton.width.menu_dlg 3
	}]
	
	# History Viewer styles
#	set smooth $::settings(live_graph_smoothing_technique)
#	set zoomed_y_axis_max 8
#	set x_axis_colour white
#	dui aspect set -theme Insight_Dark [subst {
#		graph_axis.color.hv_graph_axis $x_axis_colour
#		graph_axis.min.hv_graph_axis 0.0
#		graph_axis.max.hv_graph_axis [expr 12 * 10]
#		
#		graph_xaxis.color.hv_graph_axis $x_axis_colour  
#		graph_xaxis.tickfont.hv_graph_axis "[DSx_font font 7]" 
#		graph_xaxis.min.hv_graph_axis 0.0
#			
#		graph_yaxis.color.hv_graph_axis "#008c4c"
#		graph_yaxis.tickfont.hv_graph_axis "[DSx_font font 7]"
#		graph_yaxis.min.hv_graph_axis 0.0 
#		graph_yaxis.max.hv_graph_axis $zoomed_y_axis_max
#		graph_yaxis.subdivisions.hv_graph_axis 5 
#		graph_yaxis.majorticks.hv_graph_axis {0 1 2 3 4 5 6 7 8 9 10 11 12} 
#		graph_yaxis.hide.hv_graph_axis 0
#		
#		graph_y2axis.color.hv_graph_axis "#206ad4"
#		graph_y2axis.tickfont.hv_graph_axis "[DSx_font font 7]"
#		graph_y2axis.min.hv_graph_axis 0.0 
#		graph_y2axis.max.hv_graph_axis $zoomed_y_axis_max
#		graph_y2axis.subdivisions.hv_graph_axis 2 
#		graph_y2axis.majorticks.hv_graph_axis {0 1 2 3 4 5 6 7 8 9 10 11 12} 
#		graph_y2axis.hide.hv_graph_axis 0
#
#		graph_grid.color.hv_graph_grid $::DSx_settings(grid_colour)
#		
#		graph_line.linewidth.hv_temperature_goal $::DSx_settings(hist_temp_goal_curve) 
#		graph_line.color.hv_temperature_goal #ffa5a6 
#		graph_line.smooth.hv_temperature_goal $smooth 
#		graph_line.dashes.hv_temperature_goal {5 5}
#		
#		graph_line.linewidth.hv_temperature_basket $::DSx_settings(hist_temp_curve) 
#		graph_line.color.hv_temperature_basket #e73249
#		graph_line.smooth.hv_temperature_basket $smooth 
#		graph_line.dashes.hv_temperature_basket [list $::settings(chart_dashes_temperature)]
#
#		graph_line.linewidth.hv_temperature_mix $::DSx_settings(hist_temp_curve) 
#		graph_line.color.hv_temperature_mix #ff888c
#		graph_line.smooth.hv_temperature_mix $smooth 
#
#		graph_line.linewidth.hv_temperature_goal $::DSx_settings(hist_temp_goal_curve) 
#		graph_line.color.hv_temperature_goal #ffa5a6 
#		graph_line.smooth.hv_temperature_goal $smooth 
#		graph_line.dashes.hv_temperature_goal {5 5}
#
#		graph_line.linewidth.hv_pressure_goal $::DSx_settings(hist_goal_curve) 
#		graph_line.color.hv_pressure_goal #69fdb3
#		graph_line.smooth.hv_pressure_goal $smooth 
#		graph_line.dashes.hv_pressure_goal {5 5}
#
#		graph_line.linewidth.hv_flow_goal $::DSx_settings(hist_goal_curve) 
#		graph_line.color.hv_flow_goal #7aaaff
#		graph_line.smooth.hv_flow_goal $smooth 
#		graph_line.dashes.hv_flow_goal {5 5}
#			
#		graph_line.linewidth.hv_pressure [dui platform rescale_x 8] 
#		graph_line.color.hv_pressure #008c4c
#		graph_line.smooth.hv_pressure $smooth 
#		graph_line.dashes.hv_pressure [list $::settings(chart_dashes_pressure)]
#			
#		graph_line.linewidth.hv_flow [dui platform rescale_x 8] 
#		graph_line.color.hv_flow #4e85f4
#		graph_line.smooth.hv_flow $smooth 
#		graph_line.dashes.hv_flow [list $::settings(chart_dashes_flow)]
#
#		graph_line.linewidth.hv_flow_weight [dui platform rescale_x 8] 
#		graph_line.color.hv_flow_weight #a2693d
#		graph_line.smooth.hv_flow_weight $smooth 
#		graph_line.dashes.hv_flow_weight [list $::settings(chart_dashes_flow)]
#
#		graph_line.linewidth.hv_weight [dui platform rescale_x 8] 
#		graph_line.color.hv_weight #a2693d
#		graph_line.smooth.hv_weight $smooth 
#		graph_line.dashes.hv_weight [list $::settings(chart_dashes_espresso_weight)]
#
#		graph_line.linewidth.hv_state_change $::DSx_settings(hist_goal_curve) 
#		graph_line.color.hv_state_change #AAAAAA
#
#		graph_line.linewidth.hv_resistance $::DSx_settings(hist_resistance_curve) 
#		graph_line.color.hv_resistance #e5e500
#		graph_line.smooth.hv_resistance $smooth 
#		graph_line.dashes.hv_resistance {6 2}		
#	}]
	
#	dui aspect set { dbutton.width 3 }
	# DYE-specific styles
	dui aspect set -style dsx_settings [subst {dbutton.shape round dbutton.fill $button_bg dbutton.disabledfill $toptab_unselected_color
		dbutton.bwidth 384 dbutton.bheight 192 dbutton.width 0
		dbutton_symbol.pos {0.2 0.5} dbutton_symbol.font_size 37 
		dbutton_label.pos {0.65 0.5} dbutton_label.font_size 17 
		dbutton_label1.pos {0.65 0.8} dbutton_label1.font_size 16}]
	
	dui aspect set -style dsx_midsize {dbutton.shape outline dbutton.bwidth 220 dbutton.bheight 140 dbutton.width 6 dbutton.arc_offset 15
		dbutton_label.pos {0.7 0.5} dbutton_label.font_size 14 dbutton_symbol.font_size 24 dbutton_symbol.pos {0.25 0.5} }

	dui aspect set -style dsx_archive {dbutton.shape outline dbutton.bwidth 180 dbutton.bheight 110 dbutton.width 6 
		canvas_anchor nw anchor nw dbutton.arc_offset 12 dbutton_label.pos {0.7 0.5} dbutton_label.font_size 14 
		dbutton_symbol.font_size 24 dbutton_symbol.pos {0.3 0.5} }
	
	set bold_font [dui aspect get dtext font_family -theme default -style bold]
	dui aspect set -style dsx_done [list dbutton.shape outline dbutton.bwidth 220 dbutton.bheight 140 dbutton.width 5 \
		dbutton_label.pos {0.5 0.5} dbutton_label.font_size 20 dbutton_label.font_family $bold_font]
	
	dui aspect set -style dye_main_nav_button [subst { dbutton.shape {} dbutton.fill {} dbutton.disabledfill {}
		dbutton_symbol.font_size 28 dbutton_symbol.fill $blue_water dbutton_symbol.disabledfill $disabled_colour}]

	dui aspect set -type dtext -style section_header [list font_family $bold_font font_size 20 fill $lightest]
	
	dui aspect set -type dclicker -style dye_double [subst {shape {} fill $background 
		disabledfill $background width 0 orient horizontal use_biginc 1 
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

	# Profile viewer
	dui aspect set [subst {
		shape.fill.dye_pv_icon_btn CadetBlue4 
		dtext.fill.dye_pv_profile_title white
		dtext.font_size.dye_pv_profile_title +8
		dtext.font_family.dye_pv_profile_title notosansuibold
		text_tag.spacing1.dye_pv_step [dui::platform::rescale_y 20] 
		text_tag.foreground.dye_pv_step Brown2
		text_tag.lmargin1.dye_pv_step_line [dui::platform::rescale_x 35]
		text_tag.lmargin2.dye_pv_step_line [dui::platform::rescale_x 55]
		text_tag.foreground.dye_pv_value $::plugins::DYE::default_shot_desc_font_color
	}]
	
	### DYE V3 STYLES ####
	set bg_color $background
	#[dui aspect get page bg_color]
	set btn_spacing 100
	set half_button_width [expr {int(($::dui::pages::DYE_v3::page_coords(panel_width)-$btn_spacing)/2)}]
	
	dui aspect set -theme Insight_Dark [subst { 
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
	
		dtext.font_family.dyev3_right_panel_title "$font" 
		dtext.font_size.dyev3_right_panel_title +2
		dtext.fill.dyev3_right_panel_title $lighter
		dtext.anchor.dyev3_right_panel_title center
		dtext.justify.dyev3_right_panel_title center
		
		graph.background.dyev3_text_graph $bg_color 
		graph.plotbackground.dyev3_text_graph $bg_color 
		graph.borderwidth.dyev3_text_graph 1 
		graph.plotrelief.dyev3_text_graph flat
		
		dtext.font_size.dyev3_chart_stage_title +2 
		dtext.anchor.dyev3_chart_stage_title center 
		dtext.justify.dyev3_chart_stage_title center 
		dtext.fill.dyev3_chart_stage_title $lighter
		
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
		text_tag.font.dyev3_which_shot "[dui font get $font 15]"
		text_tag.justify.dyev3_which_shot center
		
		text_tag.justify.dyev3_profile_title center
		
		text_tag.foreground.dyev3_section $lighter
		text_tag.font.dyev3_section "[dui font get $font 17]" 
		text_tag.spacing1.dyev3_section [dui platform rescale_y 20]
		
		text_tag.foreground.dyev3_field $lighter 
		text_tag.lmargin1.dyev3_field [dui platform rescale_x 35] 
		text_tag.lmargin2.dyev3_field [dui platform rescale_x 45]
		
		text_tag.foreground.dyev3_value #4e85f4
		
		text_tag.foreground.dyev3_compare grey
		
		text_tag.font.dyev3_field_highlighted "[dui font get $font 15]"
		text_tag.background.dyev3_field_highlighted darkgrey
		text_tag.font.dyev3_field_nonhighlighted "[dui font get $font 15]"
		text_tag.background.dyev3_field_nonhighlighted {}	
	}]
	
}


