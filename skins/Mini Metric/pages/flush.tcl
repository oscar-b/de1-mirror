add_background "flush"
add_page_title "flush" [translate "flush"]

set_next_page "hotwaterrinse" "flush"

create_action_button "flush" 1280 1240 [translate "stop"] $::font_action_label $::color_action_button_text $::symbol_hand $::font_action_button $::color_action_button_stop $::color_action_button_text {say [translate "stop"] $::settings(sound_button_in); start_idle} "fullscreen"