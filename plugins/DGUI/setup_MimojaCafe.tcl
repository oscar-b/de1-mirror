# Sets up DGUI aspect variables for the MimojaCafe skin. Adapt to the theme chosen by the user. 

proc ::plugins::DGUI::setup_aspect_MimojaCafe {} {
	variable bg_color [theme background]
	variable font_color [theme background_text]
	variable page_title_color $font_color
	variable remark_color orange
	variable error_color red
	variable disabled_color "#ddd"
	variable highlight_color $font_color
	variable insert_bg_color orange
	variable font "Mazzard Regular"
	variable font_size 15
	variable header_font "Mazzard Regular"
	variable header_font_size 22
	variable section_font_size 20
	
	variable entry_relief flat
	variable entry_bg_color "#ffffff"
	
	variable button_font "Mazzard Regular"
	variable button_font_fill [theme button_text_light]
	variable button_fill [theme button]
	
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

