add_background "steam"
add_page_title "steam" [translate "steam"]

add_de1_text "steam" 1280 360 -text [translate "Warning: steam wand will purge a few seconds after stopping."] -font $::font_setting_heading -fill $::color_text -anchor "center" 


set ::steam_stop_button_id [create_action_button "steam" 1280 1340 [translate "stop"] $::font_action_label $::color_text $::symbol_hand $::font_action_button $::color_action_button_stop $::color_action_button_text {say [translate "stop"] $::settings(sound_button_in); update_button_color $::steam_stop_button_id $::color_grey_text; start_idle; check_if_steam_clogged } "fullscreen"]

set ::steam_power_1_id [rounded_rectangle "steam" .can [rescale_x_skin 340] [rescale_y_skin 550] [rescale_x_skin 620] [rescale_y_skin 830] [rescale_x_skin 55] $::color_background]
rounded_rectangle "steam" .can [rescale_x_skin 350] [rescale_y_skin 560] [rescale_x_skin 610] [rescale_y_skin 820] [rescale_x_skin 50] $::color_menu_background
create_symbol_button "steam" 390 600 20 [translate "steam"] $::symbol_steam $::color_menu_background { say [translate "steam"] $::settings(sound_button_in); set ::settings(steam_flow) 50; set_steam_flow 50; set_steam_button_colors } 38

set ::steam_power_2_id [rounded_rectangle "steam" .can [rescale_x_skin 740] [rescale_y_skin 550] [rescale_x_skin 1020] [rescale_y_skin 830] [rescale_x_skin 55] $::color_background]
rounded_rectangle "steam" .can [rescale_x_skin 750] [rescale_y_skin 560] [rescale_x_skin 1010] [rescale_y_skin 820] [rescale_x_skin 50] $::color_menu_background
create_symbol_button "steam" 790 600 20 [translate "steamy"] $::symbol_steam $::color_menu_background { say [translate "steamy"] $::settings(sound_button_in); set ::settings(steam_flow) 100; set_steam_flow 100; set_steam_button_colors } 46

set ::steam_power_3_id [rounded_rectangle "steam" .can [rescale_x_skin 1140] [rescale_y_skin 550] [rescale_x_skin 1420] [rescale_y_skin 830] [rescale_x_skin 55] $::color_background]
rounded_rectangle "steam" .can [rescale_x_skin 1150] [rescale_y_skin 560] [rescale_x_skin 1410] [rescale_y_skin 820] [rescale_x_skin 50] $::color_menu_background
create_symbol_button "steam" 1190 600 20 [translate "steamier"] $::symbol_steam $::color_menu_background { say [translate "steamier"] $::settings(sound_button_in); set ::settings(steam_flow) 150; set_steam_flow 150; set_steam_button_colors } 52

set ::steam_power_4_id [rounded_rectangle "steam" .can [rescale_x_skin 1540] [rescale_y_skin 550] [rescale_x_skin 1820] [rescale_y_skin 830] [rescale_x_skin 55] $::color_background]
rounded_rectangle "steam" .can [rescale_x_skin 1550] [rescale_y_skin 560] [rescale_x_skin 1810] [rescale_y_skin 820] [rescale_x_skin 50] $::color_menu_background
create_symbol_button "steam" 1590 600 20 [translate "steamiest"] $::symbol_steam $::color_menu_background { say [translate "steamiest"] $::settings(sound_button_in); set ::settings(steam_flow) 200; set_steam_flow 200; set_steam_button_colors } 58

set ::steam_power_5_id [rounded_rectangle "steam" .can [rescale_x_skin 1940] [rescale_y_skin 550] [rescale_x_skin 2220] [rescale_y_skin 830] [rescale_x_skin 55] $::color_background]
rounded_rectangle "steam" .can [rescale_x_skin 1950] [rescale_y_skin 560] [rescale_x_skin 2210] [rescale_y_skin 820] [rescale_x_skin 50] $::color_menu_background
create_symbol_button "steam" 1990 600 20 [translate "steamongous"] $::symbol_steam $::color_menu_background { say [translate "steamongous"] $::settings(sound_button_in); set ::settings(steam_flow) 250; set_steam_flow 250; set_steam_button_colors } 64

proc set_steam_button_colors { } {
    if {$::settings(steam_flow) < 75} {
        .can itemconfigure $::steam_power_1_id -fill $::color_water
    } else {
        .can itemconfigure $::steam_power_1_id -fill $::color_background
    }
    if {$::settings(steam_flow) >= 75 && $::settings(steam_flow) < 125} {
        .can itemconfigure $::steam_power_2_id -fill $::color_water
    } else {
        .can itemconfigure $::steam_power_2_id -fill $::color_background
    }
    if {$::settings(steam_flow) >= 125 && $::settings(steam_flow) < 175} {
        .can itemconfigure $::steam_power_3_id -fill $::color_water
    } else {
        .can itemconfigure $::steam_power_3_id -fill $::color_background
    }
    if {$::settings(steam_flow) >= 175 && $::settings(steam_flow) < 225} {
        .can itemconfigure $::steam_power_4_id -fill $::color_water
    } else {
        .can itemconfigure $::steam_power_4_id -fill $::color_background
    }
    if {$::settings(steam_flow) > 225} {
        .can itemconfigure $::steam_power_5_id -fill $::color_water
    } else {
        .can itemconfigure $::steam_power_5_id -fill $::color_background
    }

}

set_steam_button_colors
