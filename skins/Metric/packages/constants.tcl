# special characters
set ::symbol_temperature "\uE000"
set ::symbol_espresso "\uE001"
set ::symbol_hand "\uE002"
set ::symbol_flush "\uE003"
set ::symbol_water "\uE004"
set ::symbol_menu "\uE005"
set ::symbol_steam "\uE006"
set ::symbol_ratio "\uE007"
set ::symbol_bean "\uE008"
set ::symbol_grind "\uE009"
set ::symbol_tick "\uE00A"
set ::symbol_box "\uE00B"
set ::symbol_box_checked "\uE00C"
set ::symbol_star "\uE00D"
set ::symbol_star_outline "\uE00E"
set ::symbol_tea "\uE00F"
set ::symbol_filter "\uE010"
set ::symbol_de1 "\uE011"
set ::symbol_niche "\uE012"
set ::symbol_battery_0 "\uE013"
set ::symbol_battery_25 "\uE014"
set ::symbol_battery_50 "\uE015"
set ::symbol_battery_75 "\uE016"
set ::symbol_battery_100 "\uE017"
set ::symbol_bluetooth "\uE018"
set ::symbol_wifi "\uE019"
set ::symbol_usb "\uE01A"
set ::symbol_settings "\uE01B"
set ::symbol_power "\uE01C"
set ::symbol_chart "\uE01D"

# colours
set ::color_text "#eee"
set ::color_grey_text "#777"
set ::color_background "#1e1e1e"
set ::color_menu_background "#333333"
set ::color_status_bar "#252525"
set ::color_water "#19BBFF"
set ::color_temperature "#D34237"
set ::color_pressure "#6A9949"
set ::color_yield "#995A27"
set ::color_dose "#986F4A"
set ::color_ratio "#3F4E65"
set ::color_profile "#424F54"
set ::color_flow "#4237D3"
set ::color_grind "#4B9793"
set ::color_arrow "#666"
set ::color_button "#333333"
set ::color_button_text "#eee"
set ::color_action_button_start "#6A9949"
set ::color_action_button_stop "#D34237"
set ::color_action_button_disabled "#333333"
set ::color_action_button_text "#eee"
set ::color_meter_grey "#bbb"

# fonts
set ::font_setting_heading [get_font "Mazzard Regular" 24]
set ::font_setting_description [get_font "Mazzard Regular" 14]
set ::font_setting [get_font "Mazzard Regular" 36]
set ::font_button [get_font "Mazzard Regular" 24]
set ::font_list [get_font "Mazzard Regular" 24]
set ::font_action_button [get_font "Mazzard Regular" 80]
set ::font_action_label [get_font "Mazzard Regular" 28]
set ::font_main_menu [get_font "Mazzard SemiBold" 48]

# settings 
# grind settings for Niche Zero
set ::metric_setting_grind_min 0.0
set ::metric_setting_grind_max 50.0
set ::metric_setting_grind_default 18.0

set ::metric_setting_dose_min 5.0
set ::metric_setting_dose_max 30.0
set ::metric_setting_dose_default 15.0

set ::metric_setting_ratio_min 1.0
set ::metric_setting_ratio_max 25.0
set ::metric_setting_ratio_default 2.0

set ::metric_setting_yield_min 10.0
set ::metric_setting_yield_max 500.0
set ::metric_setting_yield_default 30.0
