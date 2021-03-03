# Sets up DGUI aspect variables for the DSx skin.

proc ::plugins::DGUI::setup_aspect_DSx {} {
	variable page_bg_image "[skin_directory_graphics]/background/$::DSx_settings(bg_name)"
#		variable button1_img "[skin_directory_graphics]/icons/button4.png"
#		variable button2_img "[skin_directory_graphics]/icons/button8.png"
#		variable button3_img "[skin_directory_graphics]/icons/store_button.png"
	variable bg_color $::DSx_settings(bg_colour)
	variable font_color $::DSx_settings(font_colour)
	variable page_title_color $::DSx_settings(heading_colour)
	variable remark_color $::DSx_settings(orange)
	variable error_color $::DSx_settings(red)
	variable disabled_color "#535353"
	variable highlight_color $::DSx_settings(font_colour)
	variable insert_bg_color $::DSx_settings(orange)
	variable font "font"
	variable font_size 7
	variable header_font "font"
	variable header_font_size 11
	variable section_font_size 10
	variable button_font "font"
	variable button_font_fill $::DSx_settings(font_colour)
	variable button_fill white
	
	variable entry_relief sunken
	variable entry_bg_color $::DSx_settings(bg_colour)
	
	variable listbox_relief sunken
	variable listbox_bwidth 1
	variable listbox_fg $::DSx_settings(font_colour)
	variable listbox_sfg $::DSx_settings(bg_colour)
	variable listbox_bg $::DSx_settings(bg_colour)
	variable listbox_sbg $::DSx_settings(font_colour)
	variable listbox_sbwidth 1
	variable listbox_hthickness 1
	variable listbox_hcolor $::DSx_settings(font_colour)
	
	variable scrollbar_bwidth 0
	variable scrollbar_relief flat		
	variable scrollbar_bg $font_color
	variable scrollbar_fg "#FFFFFF"
	variable scrollbar_troughcolor $bg_color
	variable scrollbar_hthickness 0
}
