add_background "steam"
add_page_title "steam" [translate "steam"]
add_de1_text "steam" 1280 360 -text [translate "Warning: steam wand will purge a few seconds after stopping."] -font $::font_setting_heading -fill $::color_text -anchor "center" 

set ::steam_stop_button_id [create_action_button "steam" 1280 820 [translate "stop"] $::font_action_label $::color_text $::symbol_hand $::font_action_button $::color_action_button_stop $::color_action_button_text {say [translate "stop"] $::settings(sound_button_in); update_button_color $::steam_stop_button_id $::color_grey_text; start_idle; check_if_steam_clogged } "fullscreen"]