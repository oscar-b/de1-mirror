# Barney's Mini Metric skin
package provide mini-metric 0.1
package require de1plus 1.0

set ::skindebug 0
set ::debugging 0

proc add_metric_package {name} { source "[skin_directory]/packages/$name.tcl" }
proc add_metric_page {name} { source "[skin_directory]/pages/$name.tcl" }

# load the other packages for this skin
add_metric_package "constants"
add_metric_package "functions"
add_metric_package "framework"
add_metric_package "meter"

add_metric_page "home"
add_metric_page "espresso"
add_metric_page "steam"
add_metric_page "water"
add_metric_page "flush" 
add_metric_page "analysis"

# add status bar after loading Metric pages to ensure it draws on top of everything else
add_metric_package "statusbar"

# standard includes
source "[homedir]/skins/default/standard_includes.tcl"
# override "tankempty" because we don't want to move you off the espresso page just because you ran out of water.
set_next_page "tankempty" "off"
# tap to close screen saver
add_de1_button "saver" {say [translate "wake"] $::settings(sound_button_in); metric_jump_to "off"} 0 0 2560 1600

# debug info
if {$::debugging == 1} {
	add_de1_variable "off espresso espresso_done steam water flush debug" 1280 10 -text "" -font [get_font "Mazzard Medium" 12] -fill #fff -anchor "n" -textvariable {[join $::::metric_page_history " > "]}
    #.can create rectangle [rescale_x_skin 0] [rescale_y_skin 210] [rescale_x_skin 1500] [rescale_y_skin 1150] -fill "#fff" 
    add_de1_variable "off espresso espresso_done steam water flush debug" 10 220 -text "" -font Helv_6 -fill "#fff" -anchor "nw" -justify left -width 440 -textvariable {$::debuglog}
}

create_grid

show_android_navigation true

bind Canvas <KeyPress> {handle_keypress %k}