add_background "espresso_done"
add_back_button "espresso_done" [translate "analysis"]

set ::font_chart [get_font "Mazzard Regular" 14]
add_de1_widget "espresso_done" graph 280 280 {
	$widget axis configure x -color $::color_grey_text -tickfont $::font_chart -subdivisions 1; 
	$widget axis configure y -color $::color_grey_text -tickfont $::font_chart -stepsize 1 -subdivisions 1 -min 0 -max 12; 
	$widget grid configure -hide true;


	$widget element create line2_espresso_pressure -xdata espresso_elapsed -ydata espresso_pressure -symbol none -label "" -linewidth [rescale_x_skin 10] -color $::color_pressure -smooth $::settings(live_graph_smoothing_technique) -pixels 0;
	$widget element create line_espresso_pressure_goal -xdata espresso_elapsed -ydata espresso_pressure_goal -symbol none -label "" -linewidth [rescale_x_skin 5] -color $::color_pressure -smooth $::settings(live_graph_smoothing_technique) -pixels 0 -dashes {1 3}; 

	$widget element create line_espresso_flow_2x -xdata espresso_elapsed -ydata espresso_flow -symbol none -label "" -linewidth [rescale_x_skin 10] -color $::color_flow -smooth $::settings(live_graph_smoothing_technique) -pixels 0;
	$widget element create line_espresso_flow_goal_2x -xdata espresso_elapsed -ydata espresso_flow_goal -symbol none -label "" -linewidth [rescale_x_skin 5] -color $::color_flow -smooth $::settings(live_graph_smoothing_technique) -pixels 0 -dashes {1 3};

	$widget element create line_espresso_total_flow -xdata espresso_elapsed -ydata espresso_water_dispensed -symbol none -label "" -linewidth [rescale_x_skin 10] -color $::color_yield -smooth $::settings(live_graph_smoothing_technique) -pixels 0;

} -plotbackground $::color_background -width [rescale_x_skin 2000] -height [rescale_y_skin 1200] -borderwidth 1 -background $::color_background -plotrelief flat

add_de1_text "espresso_done" 2300 340 -text [translate "Flow (mL/s)"] -font $::font_chart -fill $::color_flow -justify "left" -anchor "nw"
add_de1_text "espresso_done" 2300 400 -text [translate "Pressure (bar)"] -font $::font_chart -fill $::color_pressure -justify "left" -anchor "nw"
add_de1_text "espresso_done" 2300 460 -text [translate "Yield (g)"] -font $::font_chart -fill $::color_yield -justify "left" -anchor "nw"
add_de1_text "espresso_done" 2300 1400 -text [translate "Time (s)"] -font $::font_chart -fill $::color_text -justify "left" -anchor "nw"
