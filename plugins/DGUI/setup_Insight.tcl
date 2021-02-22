# Sets up DGUI aspect variables for the Insight skin.

proc ::plugins::DGUI::setup_aspect_Insight {} {
	# See skins/Insight/skin.tcl
	#variable bg_color "#ffffff"
	variable bg_color "#edecfa"
	variable font_color "#7f879a"
	variable page_title_color black
	variable remark_color orange
	variable error_color red
	variable disabled_color "#ddd"
	variable highlight_color $font_color
	variable insert_bg_color orange
	variable font "Helv"
	variable font_size 7
	variable header_font "Helv_bold"
	variable header_font_size 11
	variable section_font_size 10	
	
	variable entry_relief flat
	variable entry_bg_color "#ffffff"
	
	variable button_font "Helv_bold"
	variable button_font_fill "#ffffff"
	variable button_fill "#c0c5e3"
	
	variable listbox_relief flat
	variable listbox_bwidth 0
	variable listbox_fg $font_color
	variable listbox_sfg black
	variable listbox_bg $entry_bg_color
	variable listbox_sbg "#c0c4e1"
	variable listbox_sbwidth 0
	variable listbox_hthickness 1
	variable listbox_hcolor $font_color

	variable scrollbar_bwidth 0
	variable scrollbar_relief flat		
	variable scrollbar_bg "#d3dbf3"
	variable scrollbar_fg "#FFFFFF"
	variable scrollbar_troughcolor "#f7f6fa"
	variable scrollbar_hthickness 0
}

