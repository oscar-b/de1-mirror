# Functions for creating the Metric menu framework

proc add_background { contexts } {
	set background_id [.can create rect 0 0 [rescale_x_skin 2560] [rescale_y_skin 1600] -fill $::color_background -width 0 -state "hidden"]
	add_visual_items_to_contexts $contexts $background_id
}

# add a back button and page title to a context
proc add_back_button { contexts text } {
	set y 160
	set item_id [.can create line [rescale_x_skin 120] [rescale_y_skin [expr $y - 60]] [rescale_x_skin 60] [rescale_y_skin $y] [rescale_x_skin 120] [rescale_y_skin [expr $y + 60]] -width [rescale_x_skin 24] -fill $::color_text -state "hidden"]
	add_visual_items_to_contexts $contexts $item_id
	set page_title_id [add_de1_text $contexts 180 $y -text $text -font $::font_main_menu -fill $::color_text -anchor "w" -state "hidden"]
	add_de1_button $contexts {say [translate "back"] $::settings(sound_button_in); metric_jump_to "off" } 0 0 1280 [expr $y * 2]
	return $page_title_id
}

proc add_page_title { contexts text } {
	set page_title_id [add_de1_text $contexts 1280 160 -text $text -font $::font_main_menu -fill $::color_text -anchor "center" -state "hidden"]
	return $page_title_id
}

proc add_page_title_left { contexts text } {
	set page_title_id [add_de1_text $contexts 180 160 -text $text -font $::font_main_menu -fill $::color_text -anchor "w" -state "hidden"]
	return $page_title_id
}

# button with a symbol on
proc create_symbol_button {contexts x y padding label symbol color action {symbolsize 64}} {
	set button_id [create_symbol_box $contexts $x $y $label $symbol $color $symbolsize]
	add_de1_button $contexts $action [expr $x - $padding] [expr $y - $padding] [expr $x + 180 + $padding] [expr $y + 180 + $padding]
	return $button_id
}

# variable size button with a symbol on
proc create_symbol_button2 {contexts x y size padding label symbol color action {symbolsize 128} {fontsize 24}} {
	set font_symbol [get_font "Mazzard SemiBold" $symbolsize]
	set font_label [get_font "Mazzard Regular" $fontsize]
	set button_id [rounded_rectangle $contexts .can [rescale_x_skin $x] [rescale_y_skin $y] [rescale_x_skin [expr $x + $size]] [rescale_y_skin [expr $y + $size]] [rescale_x_skin [expr $size / 6]] $color]
	add_de1_text $contexts [expr $x + ($size / 2)] [expr $y + ($size / 2) - ($size / 18)] -text $symbol -font $font_symbol -fill "#000" -anchor "center" -state "hidden"
	add_de1_text $contexts [expr $x + ($size / 2)] [expr $y + $size - ($size / 24)] -text $label -font $font_label -fill "#000" -anchor "s" -state "hidden"
	add_de1_button $contexts $action [expr $x - $padding] [expr $y - $padding] [expr $x + 180 + $padding] [expr $y + $size + $padding]
	return $button_id
}

# add a button for starting a DE1 function
proc create_action_button { contexts x y label_text label_font label_textcolor icon_text icon_font backcolor icon_textcolor action fullscreen } {
	if { [info exists ::_button_id] != 1 } { set ::_button_id 0 }
    set radius 180
    set x1 [expr $x - $radius]
    set y1 [expr $y - $radius]
    set x2 [expr $x + $radius]
    set y2 [expr $y + $radius]
    .can create oval [rescale_x_skin $x1] [rescale_y_skin $y1] [rescale_x_skin $x2] [rescale_y_skin $y2] -fill $backcolor -width 0 -tag "button_$::_button_id" -state "hidden"
    add_visual_items_to_contexts $contexts "button_$::_button_id"
    add_de1_text $contexts $x [expr $y - ($radius * 0.15)] -text $icon_text -font $icon_font -fill $icon_textcolor -anchor "center" -state "hidden"
	add_de1_text $contexts $x [expr $y + ($radius * 0.25)] -text $label_text -font $label_font -fill $label_textcolor -anchor "n" -state "hidden"
    if {$fullscreen != ""} {
        add_de1_button $contexts $action 0 0 2560 1600
    } else {
        add_de1_button $contexts $action $x1 $y1 $x2 $y2
    }
    incr ::_button_id
	return [expr $::_button_id -1]
}

proc update_button_color { button_id backcolor } {
	.can itemconfigure "button_$button_id" -fill $backcolor
}

### page navigation ###

proc metric_jump_to { pagename } {
	set_next_page "off" $pagename
	page_show "off"
	start_idle
	# when tank is empty, stay on current page
	set_next_page "tankempty" $pagename
}


### drawing functions ###

# convert back from screen coords to skin coords for calling functions like add_de1_text (note - can cause rounding roundtrip errors)
proc reverse_scale_x { in } { return [ expr { [skin_xscale_factor] * $in }] }
proc reverse_scale_y { in } { return [ expr { [skin_yscale_factor] * $in }] }

# add multiple visuals to multiple contexts
proc add_visual_items_to_contexts { contexts tags } {
    set context_list [split $contexts " "]
    set tag_list [split $tags " " ]
    foreach context $context_list {
        foreach tag $tag_list {
            add_visual_item_to_context $context $tag
        }
    }
}

proc rounded_rectangle {contexts canvas x1 y1 x2 y2 radius colour } {
	if { [info exists ::_rect_id] != 1 } { set ::_rect_id 0 }
	set tag "rect_$::_rect_id"
    $canvas create oval $x1 $y1 [expr $x1 + $radius] [expr $y1 + $radius] -fill $colour -outline $colour -width 0 -tag $tag -state "hidden"
    $canvas create oval [expr $x2-$radius] $y1 $x2 [expr $y1 + $radius] -fill $colour -outline $colour -width 0 -tag $tag -state "hidden"
    $canvas create oval $x1 [expr $y2-$radius] [expr $x1+$radius] $y2 -fill $colour -outline $colour -width 0 -tag $tag -state "hidden"
    $canvas create oval [expr $x2-$radius] [expr $y2-$radius] $x2 $y2 -fill $colour -outline $colour -width 0 -tag $tag -state "hidden"
    $canvas create rectangle [expr $x1 + ($radius/2.0)] $y1 [expr $x2-($radius/2.0)] $y2 -fill $colour -outline $colour -width 0 -tag $tag -state "hidden"
    $canvas create rectangle $x1 [expr $y1 + ($radius/2.0)] $x2 [expr $y2-($radius/2.0)] -fill $colour -outline $colour -width 0 -tag $tag -state "hidden"
	add_visual_items_to_contexts $contexts $tag
	incr ::_rect_id
	return $tag
}

proc create_symbol_box {contexts x y label symbol color {symbolsize 64}} {
	set font_symbol [get_font "Mazzard SemiBold" $symbolsize]
	set font_label [get_font "Mazzard Regular" 14]
	rounded_rectangle $contexts .can [rescale_x_skin $x] [rescale_y_skin $y] [rescale_x_skin [expr $x + 180]] [rescale_y_skin [expr $y + 180]] [rescale_x_skin 30] $color
	set button_id [add_de1_text $contexts [expr $x + 90] [expr $y + 70] -text $symbol -font $font_symbol -fill "#000" -anchor "center" -state "hidden"]
	add_de1_text $contexts [expr $x + 90] [expr $y + 170] -text $label -font $font_label -fill "#000" -anchor "s" -state "hidden"
	return $button_id
}

proc create_grid { } {
	for {set x 80} {$x < 2560} {incr x 100} {
		.can create line [rescale_x_skin $x] [rescale_y_skin 0] [rescale_x_skin $x] [rescale_y_skin 1600] -width 1 -fill "#fff" -tags "grid" -state "hidden"
		.can create text [rescale_x_skin $x] 0 -text $x -font [get_font "Mazzard Regular" 12] -fill $::color_text -anchor "nw" -tag "grid" -state "hidden"
	}
	for {set y 60} {$y < 1600} {incr y 60} {
		.can create line [rescale_x_skin 0] [rescale_y_skin $y] [rescale_x_skin 2560] [rescale_y_skin $y] -width 1 -fill "#fff" -tags "grid" -state "hidden"
		.can create text 0 [rescale_y_skin $y] -text $y -font [get_font "Mazzard Regular" 12] -fill $::color_text -anchor "nw" -tag "grid" -state "hidden"
	}
}

proc show_android_navigation { visible } {
	set SYSTEM_UI_FLAG_IMMERSIVE_STICKY 0x00001000
	set SYSTEM_UI_FLAG_FULLSCREEN 0x00000004
	set SYSTEM_UI_FLAG_HIDE_NAVIGATION 0x00000002
	set SYSTEM_UI_FLAG_IMMERSIVE 0x00000800
	set SYSTEM_UI_FLAG_LAYOUT_STABLE 0x00000100
	set SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION 0x00000200
	set SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN 0x00000400

	if { $visible == true } {
		set ::android_full_screen_flags [expr {$SYSTEM_UI_FLAG_LAYOUT_STABLE | $SYSTEM_UI_FLAG_IMMERSIVE}]
	} else {
		set ::android_full_screen_flags [expr {$SYSTEM_UI_FLAG_LAYOUT_STABLE | $SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | $SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | $SYSTEM_UI_FLAG_HIDE_NAVIGATION | $SYSTEM_UI_FLAG_FULLSCREEN | $SYSTEM_UI_FLAG_IMMERSIVE}]
	}
	borg systemui $::android_full_screen_flags
}