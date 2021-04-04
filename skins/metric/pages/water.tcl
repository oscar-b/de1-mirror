add_background "water"
add_page_title "water" [translate "hot water"]

create_action_button "water" 1280 1340 [translate "stop"] $::font_action_label $::color_text $::symbol_hand $::font_action_button $::color_action_button_stop $::color_action_button_text {say [translate "stop"] $::settings(sound_button_in); start_idle } "fullscreen"
