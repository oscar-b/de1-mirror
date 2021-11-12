# Meter for displaying live readings

# helper proc for named arguments
# creates a variable called _argname for each parameter -argname
# there may be a better way to do this in Tcl!
proc named {args defaults} {
	foreach {key value} [string map {- _} $defaults] {
		upvar 1 $key varname
		set varname $value
	}

	foreach {key value} [string map {- _} $args] {
		upvar 1 $key varname
		set varname $value
	}
}

oo::class create meter {
	variable _x _y _width _minvalue _maxvalue _arc_range _arc_color _needle_width _needle_color
	variable _tick_width _tick_frequency _tick_color _label_frequency _label_color _label_font _title _title_font _units _show_empty_full
	variable _get_meter_value
    variable _get_target_value

	variable _meter_needle_id _meter_target_id
	variable _arc_width _center_x _center_y _needle_length
	variable _contexts

	variable _previous_value

	constructor { args } {
		set defaults {-x 0 -y 0 -width 100 -minvalue 0 -maxvalue 10 -arc_range 240 -arc_color "#dcdcdc" -needle_width 4 -needle_color #e00 -tick_width 2 -tick_frequency 1 -label_frequency 0 -label_color #fff -get_meter_value "" -show_empty_full 0 -tick_color #fff -contexts "x" -title "" -units "" -get_target_value ""}
		named $args $defaults

		if {$_width < [rescale_x_skin 300]} {
			set _label_font [get_font "Mazzard Medium" 12]
			set _title_font [get_font "Mazzard Regular" 12]
		} elseif {$_width < [rescale_x_skin 600]} {
			set _label_font [get_font "Mazzard Medium" 18]
			set _title_font [get_font "Mazzard Regular" 20]
		} else {
			set _label_font [get_font "Mazzard Medium" 22]
			set _title_font [get_font "Mazzard Regular" 24]
		}
		set _arc_width [expr [reverse_scale_x $_width] * 0.035]
		set _center_x [expr ($_x + ($_width / 2.0))]
		set _center_y [expr ($_y + ($_width / 2.0))]
		set _needle_length [expr (($_width - ($_arc_width * 2.0) - ($_needle_width * 3.0)) / $_width)]
		set _previous_value 0
		my draw
	}

	method get_angle_from_percent { percent } {
		# calculate angle of needle
		set arc_min [expr ($_arc_range / 2.0) + 90.0]
		set angle [expr $arc_min - ($_arc_range * $percent)]
		set degrees_to_radians 0.017453292519943001
		return [expr $angle * $degrees_to_radians]
	}

	# set the coordinates of a line to be a radial of the dial.  Use for positioning tick marks and needle.
	# inner and outer are the start and finish positions of the needle (0.0 = centre, 1.0 = on dial)
	method set_radial_coords { item_id inner outer value } {
		set percent [expr (($value - $_minvalue) / ($_maxvalue - $_minvalue))]
		set inner_radius [expr ($_width * $inner / 2.0)]
		set outer_radius [expr ($_width * $outer / 2.0)]

		# limit value to range 0.0 .. 1.0
		set value [expr min (1.0, max(0.0, $value))]

		# calculate angle of needle
		set needle_angle_rads [my get_angle_from_percent $percent]

		# get (x,y) for ends of needle
		set inner_x [expr ($_center_x + ($inner_radius * cos ($needle_angle_rads)))]
		set inner_y [expr ($_center_y + ($inner_radius * -sin ($needle_angle_rads)))]
		set outer_x [expr ($_center_x + ($outer_radius * cos ($needle_angle_rads)))]
		set outer_y [expr ($_center_y + ($outer_radius * -sin ($needle_angle_rads)))]

		.can coords $item_id $inner_x $inner_y $outer_x $outer_y
	}

	method draw_number { value label } {
		set percent [expr (($value - $_minvalue) / ($_maxvalue - $_minvalue))]
		set angle_rads [my get_angle_from_percent $percent]
		set radius [expr ($_width * 0.33)]
		set x [expr $_center_x + ($radius * cos ($angle_rads)) ]
		set y [expr $_center_y - ($radius * sin ($angle_rads)) ]

		add_de1_text $_contexts [expr [reverse_scale_x $x]] [expr [reverse_scale_y $y]] -justify center -anchor "center" -text $label -font $_label_font -fill $_label_color -width $_width -state "hidden"
	}

	method draw {} {
		# pre-calculate some geometry
		set meter_x0 [expr $_x + ($_arc_width / 2.0)]
		set meter_y0 [expr $_y + ($_arc_width / 2.0)]
		set meter_x1 [expr $_x + $_width - ($_arc_width / 2.0)]
		set meter_y1 [expr $_y + $_width - ($_arc_width / 2.0)]
		set arc_min [expr ($_arc_range / 2.0) + 90.0]

        # draw the target value
        set _meter_target_id [.can create line 0 0 0 0 -width [expr $_arc_width * 0.5] -fill $_needle_color -capstyle round -state "hidden"]
		add_visual_items_to_contexts $_contexts $_meter_target_id

		# draw the arc
		set item_id [.can create arc $meter_x0 $meter_y0 $meter_x1 $meter_y1 -start $arc_min -extent [expr $_arc_range * -1] -style arc -width $_arc_width -outline $_arc_color -state "hidden"]
		add_visual_items_to_contexts $_contexts $item_id

		# add some tick marks
		if {$_tick_frequency > 0} {
			for {set i [expr $_minvalue + $_tick_frequency]} {$i < $_maxvalue} { set i [expr $i + $_tick_frequency] } {
				set item_id [.can create line 0 0 0 0 -width $_tick_width -fill $_tick_color -state "hidden"]
				my set_radial_coords $item_id 0.8 0.92 $i
				add_visual_items_to_contexts $_contexts $item_id
			}
		}

		if {$_label_frequency > 0} {
			for {set i $_minvalue} {$i <= $_maxvalue} { set i [expr $i + $_label_frequency] } {
				my draw_number $i [round_to_integer $i] 
			}
		}

		if {$_show_empty_full == 1} {
			my draw_number $_minvalue [translate "E"]
			my draw_number $_maxvalue [translate "F"]
		}

		add_de1_text $_contexts [expr [reverse_scale_x [expr $_x + ($_width/2.0)]]] [expr [reverse_scale_y [expr $_y + ($_width * 0.665)]]] -anchor "center" -text $_units -font $_label_font -fill $_label_color -state "hidden"

		add_de1_text $_contexts [expr [reverse_scale_x [expr $_x + ($_width/2.0)]]] [expr [reverse_scale_y [expr $_y + ($_width * 0.84)]]] -anchor "center" -text $_title -font $_title_font -fill $_needle_color -state "hidden"

		# add needle
		set _meter_needle_id [.can create line 0 0 0 0 -width $_needle_width -fill $_needle_color -capstyle round -state "hidden"]
		add_visual_items_to_contexts $_contexts $_meter_needle_id
		my update
	}

	method smooth { value } {
		set mean [expr ($value + $_previous_value) / 2.0]
		set _previous_value $value
		return $mean
	}

	method update { } {
		if {[.can itemcget $$_meter_needle_id -state] != "hidden"} {
			set value [$_get_meter_value]
			set value [my smooth $value]
			if {$value < $_minvalue} { set value $_minvalue }
			if {$value > $_maxvalue} { set value $_maxvalue }
			my set_radial_coords $_meter_needle_id 0.0 $_needle_length $value
		}

        if {$_get_target_value != "" && [.can itemcget $$_meter_needle_id -state] != "hidden"} {
            set target [$_get_target_value]
            if {$target <= $_minvalue || $target >= $_maxvalue} {
                .can coords $_meter_target_id -100 -100 -100 -100
            } else {
                my set_radial_coords $_meter_target_id 0.98 1.1 $target
            }
        }
	}
}