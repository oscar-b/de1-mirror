add_background "espresso_done"
add_back_button "espresso_done" [translate "last shot"]

set ::font_summary_text [get_font "Mazzard Regular" 16]
set summary_x0 240
set summary_x1 540
set summary_y 330
set summary_y_step 60

rounded_rectangle "espresso_done" .can [rescale_x_skin 180] [rescale_y_skin 270] [rescale_x_skin 1180] [rescale_y_skin 810] [rescale_x_skin 80] $::color_menu_background

add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Profile:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {$::settings(profile_title)} 
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Date:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {[clock format [expr $::timers(espresso_start) / 1000] -format "%d/%m/%Y" ]} 
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Time:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {[clock format [expr $::timers(espresso_start) / 1000] -format "%R" ]} 
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Grind:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {$::settings(grinder_setting)} 
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Dose:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {$::settings(grinder_dose_weight)g} 
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Target ratio:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {$::metric_ratio x}
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Target yield:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {$::metric_yield g} 
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Temperature:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {$::de1(goal_temperature)[return_html_temperature_units]} 

rounded_rectangle "espresso_done" .can [rescale_x_skin 180] [rescale_y_skin 840] [rescale_x_skin 1180] [rescale_y_skin 1080] [rescale_x_skin 80] $::color_menu_background

set summary_y 900
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Duration:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {[expr {($::timers(espresso_stop) - $::timers(espresso_start))/1000}][translate "s"]} 
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Actual ratio:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {1:[format "%.1f" [expr [get_weight] / $::settings(grinder_dose_weight)]]} 
incr summary_y $summary_y_step
add_de1_text "espresso_done" $summary_x0 $summary_y -text [translate "Actual yield:"] -font $::font_summary_text -fill $::color_text -anchor "w" 
add_de1_variable "espresso_done" $summary_x1 $summary_y -font $::font_summary_text -fill $::color_text -anchor "w" -textvariable {[format "%.1f" [get_weight]]g} 

# chart
set ::font_chart [get_font "Mazzard Regular" 14]
add_de1_widget "espresso_done" graph 1280 260 {
	$widget axis configure x -color $::color_grey_text -tickfont $::font_chart -subdivisions 1; 
	$widget axis configure y -color $::color_grey_text -tickfont $::font_chart -stepsize 1 -subdivisions 1 -min 0 -max 12; 
	$widget grid configure -hide true;


	$widget element create line2_espresso_pressure -xdata espresso_elapsed -ydata espresso_pressure -symbol none -label "" -linewidth [rescale_x_skin 10] -color $::color_pressure -smooth $::settings(live_graph_smoothing_technique) -pixels 0;
	$widget element create line_espresso_pressure_goal -xdata espresso_elapsed -ydata espresso_pressure_goal -symbol none -label "" -linewidth [rescale_x_skin 5] -color $::color_pressure -smooth $::settings(live_graph_smoothing_technique) -pixels 0 -dashes {1 3}; 

	$widget element create line_espresso_flow_2x -xdata espresso_elapsed -ydata espresso_flow -symbol none -label "" -linewidth [rescale_x_skin 10] -color $::color_flow -smooth $::settings(live_graph_smoothing_technique) -pixels 0;
	$widget element create line_espresso_flow_goal_2x -xdata espresso_elapsed -ydata espresso_flow_goal -symbol none -label "" -linewidth [rescale_x_skin 5] -color $::color_flow -smooth $::settings(live_graph_smoothing_technique) -pixels 0 -dashes {1 3};

	$widget element create line_espresso_total_flow -xdata espresso_elapsed -ydata espresso_water_dispensed -symbol none -label "" -linewidth [rescale_x_skin 10] -color $::color_yield -smooth $::settings(live_graph_smoothing_technique) -pixels 0;

} -plotbackground $::color_background -width [rescale_x_skin 1200] -height [rescale_y_skin 840] -borderwidth 1 -background $::color_background -plotrelief flat

add_de1_text "espresso_done" 1280 60 -text [translate "Flow (mL/s)"] -font $::font_chart -fill $::color_flow -justify "left" -anchor "nw"
add_de1_text "espresso_done" 1280 120 -text [translate "Pressure (bar)"] -font $::font_chart -fill $::color_pressure -justify "left" -anchor "nw"
add_de1_text "espresso_done" 1280 180 -text [translate "Yield (g)"] -font $::font_chart -fill $::color_yield -justify "left" -anchor "nw"
add_de1_text "espresso_done" 2480 1100 -text [translate "Time (s)"] -font $::font_chart -fill $::color_text -justify "left" -anchor "ne"
