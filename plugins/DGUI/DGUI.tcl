#######################################################################################################################
### A Decent DE1 app plugin that provides a skin-independent, themable, page-oriented GUI "mini framework".
#######################################################################################################################

namespace eval ::plugins::DGUI {
	variable author "Enrique Bengoechea"
	variable contact "enri.bengoechea@gmail.com"
	variable version 1.02
	variable name [translate "Describe GUI"]
	variable github_repo ebengoechea/de1app_plugin_DGUI
	variable description [translate "A skin-independent, \"themable\", GUI \"mini framework\" for skin and plugin writters.
Simplify page creation, auto-adapt aspect to current skin/theme, ready-made widget combos and full-page field editors."]

	variable pages {}
	
	# Aspect variables. Initialized here to default (Insight light theme), which is used if there's not a 
	# ::plugins::DGUI::setup_aspect_<skin> proc available.
	variable page_bg_image {}
	# button 1 is medium-size button for done/cancel actions
	variable button1_img {}
	variable button1_width 220
	variable button1_height 140	
	# button 2 is big-size button for icon+explanation actions (such as "Calc EY from TDS") 
	variable button2_img {}	
	variable button2_width 384
	variable button2_height 192
	# button 3 is usual Ok button in Insight (245 x 65)
	variable button3_img {}
	variable button3_width 490
	variable button3_height 120
	variable button_font "font"
	
	variable button_font_fill "#ffffff"
	variable button_fill "#c0c5e3"
					
	variable bg_color {}
	variable font_color {}
	variable default_shot_desc_font_color {#206ad4}
	variable page_title_color {}
	variable remark_color {}
	variable error_color {}
	variable disabled_color {}
	variable highlight_color {}
	variable insert_bg_color {}
	
	variable font {}
	variable font_size 7
	variable header_font "font"	
	variable header_font_size 11
	variable section_font_size 10
	variable button_font "font"
	variable button_font_fill "#ffffff"
	variable button_fill white
	
	variable entry_relief sunken
	variable entry_bg_color "#ffffff"	
	
	variable listbox_relief sunken
	variable listbox_bwidth 1
	variable listbox_fg "#ffffff"
	variable listbox_sfg ""
	variable listbox_bg ""
	variable listbox_sbg "#ffffff"
	variable listbox_sbwidth 1
	variable listbox_hthickness 1
	variable listbox_hcolor "#ffffff"
	
	variable scrollbar_bwidth 0
	variable scrollbar_relief flat		
	variable scrollbar_bg $font_color
	variable scrollbar_fg "#FFFFFF"
	variable scrollbar_troughcolor $bg_color
	variable scrollbar_hthickness 0

	# Symbols in Fontawesome regular, see https://fontawesome.com/icons?d=gallery
	variable symbols
	array set symbols {
		square "\uf0c8"
		square_check "\uf14a"
		sort_down "\uf0dd"
		star "\uf005"
		half_star "\uf089"
		chevron_left "\uf053"
		chevron_double_left "\uf323"
		arrow_to_left "\uf33e"
		chevron_right "\uf054"
		chevron_double_right "\uf324"
		arrow_to_right "\uf340"
		eraser "\uf12d"
		eye "\uf06e"
	}
	
	# Used to map booleans to their checkbox representation (square/square_check) in fontawesome.
	variable checkbox_symbols_map {"\uf0c8" "\uf14a"}

	# DATA DICTIONARY CONVENTIONS:
	#  * The column name in the shot table or the lookup table must be identical to the array item key.
	#  * The shot_field is the variable name in the shot file, settings section. May not match the array item key in 
	#		cases like 'other_equipment'.
	#  * desc_section has to be one of bean, bean_batch, equipment, extraction or people.
	#  * data_type has to be one of text, long_text, category, numeric or date.
	variable field_lookup_whats {name name_plural short_name short_name_plural \
		desc_section db_table lookup_table db_type_column1 db_type_column2 shot_field data_type \
		min_value max_value n_decimals default_value small_increment big_increment
	}
		
	variable data_dictionary
	array set data_dictionary {
		profile_title {"Profile" "Profiles" "Profile" "Profiles" \
			"" shot "" "" "" profile_title category 0 0 0}
		bean_desc {"Beans" "Beans" "Beans" "Beans" \
			bean V_shot "" "" "" bean_brand||bean_type category 0 0 0}
		bean_brand {"Beans roaster" "Beans roasters" "Roaster" "Roasters" \
			bean shot "" "" "" bean_brand category 0 0 0}
		bean_type {"Beans type" "Beans types" "Name" "Names" \
			bean shot "" "" "" bean_type category 0 50 0}
		bean_notes {"Beans notes" "Beans notes" "Note" "Notes" \
			bean_batch shot "" "" "" bean_notes long_text 0 1000 0}
		roast_date {"Roast date" "Roast dates" "Date" "Dates" \
			bean_batch shot "" "" "" roast_date date 0 0 0}
		roast_level {"Roast level" "Roast levels" "Level" "Levels" \
			bean_batch shot "" "" "" roast_level category 0 50 0}
		grinder_model {"Grinder name" "Grinder names" "Grinder" "Grinders" \
			equipment shot "" "" "" grinder_model category 0 100 0}
		grinder_setting {"Grinder setting" "Grinder settings" "Setting" "Settings" \
			equipment shot "" "" "" grinder_setting category 0 100 0}
		grinder_dose_weight {"Dose weight" "Dose weights" "Dose" "Doses" \
			extraction shot "" "" "" grinder_dose_weight numeric 0 30 1 18 0.1 1.0}
		drink_weight {"Drink weight" "Drink weights" "Weight" "Weights" \
			extraction shot "" "" "" drink_weight numeric 0 500 1 36 1.0 10.0}
		drink_tds {"Total Dissolved Solids (TDS %)" "Total Dissolved Solids %" "TDS" "TDS" \
			extraction shot "" "" "" drink_tds numeric 0 15 2 8 0.01 0.1}
		drink_ey {"Extraction Yield (EY %)" "Extraction Yields %" "EY" "EYs" \
			extraction shot "" "" "" drink_ey numeric 0 30 2 20 0.1 1.0}	
		espresso_enjoyment {"Enjoyment (0-100)" "Enjoyments" "Enjoyment" "Enjoyment" \
			extraction shot "" "" "" espresso_enjoyment numeric 0 100 0 50 1 10}
		espresso_notes {"Notes" "Notes" "Notes" "Notes" \
			extraction shot "" "" "" espresso_notes long_text 0 1000 0}	
		my_name {"Barista" "Baristas" "Barista" "Baristas" \
			people shot "" "" "" my_name category 0 100 0 people}
		drinker_name {"Drinker" "Drinkers" "Drinker" "Drinkers" \
			people shot "" "" "" drinker_name category 0 100 0}
		skin {"Skin" "Skins" "Skin" "Skins" \
			"" shot "" "" "" skin category 0 0 0}
		beverage_type {"Beverage type" "Beverage types" "Bev type" "Bev types" \
			"" shot "" "" "" beverage_type category 0 0 0}
		repository_links {"Repository link" "Repository links" "Repo link" "Repo links" \
			"" "" "" "" "" repository_links "array" 0 0 0}
	}	
	
	namespace export field_lookup field_names get_font set_symbols value_or_default \
		args_add_option_if_not_exists args_remove_option args_has_option args_get_option args_get_prefixed \
		set_previous_page enable_or_disable_widgets enable_widgets disable_widgets \
		show_or_hide_widgets show_widgets hide_widgets add_page add_cancel_button add_button1 add_button2 \
		add_button add_text add_symbol add_variable add_entry add_select_entry add_multiline_entry \
		relocate_dropdown_arrows set_scrollbars_dims relocate_text_wrt ensure_size \
		add_listbox listbox_get_sellection listbox_set_sellection add_checkbox add_rating draw_rating horizontal
}

proc ::plugins::DGUI::main {} {
	msg "Starting the 'Describe GUI' plugin"
		
	foreach ns {IS NUME TXT} { ::plugins::DGUI::${ns}::setup_ui }	
}

proc ::plugins::DGUI::preload {} {	
	if { ![info exists ::debugging] } { set ::debugging 0 }
	
	set skin $::settings(skin)
	set skin_src_fn "[plugin_directory]/DGUI/setup_${skin}.tcl"
	if { [file exists $skin_src_fn] } { 
		source $skin_src_fn
	} else { 
		source "[plugin_directory]/DGUI/setup_Insight.tcl"
	}
	setup_aspect
	
	# No settings page for this plugin
	return ""
}

proc ::plugins::DGUI::msg { {flag ""} args } {
	if { [string range $flag 0 0] eq "-" && [llength $args] > 0 } {
		::logging::default_logger $flag "::plugins::DGUI" {*}$args
	} else {
		::logging::default_logger "::plugins::DGUI" $flag {*}$args
	}
}

# Setup the general aspect parameters (colors, fonts etc.) depending on the skin used.
proc ::plugins::DGUI::setup_aspect { } {
	load_font fontawesome_reg_big "[homedir]/fonts/Font Awesome 5 Pro-Regular-400.otf" 55
	load_font fontawesome_reg_medium "[homedir]/fonts/Font Awesome 5 Pro-Regular-400.otf" 40
	load_font fontawesome_reg_small "[homedir]/fonts/Font Awesome 5 Pro-Regular-400.otf" 24

	set skin $::settings(skin)
	if { [namespace which -command "::plugins::DGUI::setup_aspect_$skin"] ne "" } {
		::plugins::DGUI::setup_aspect_$skin
	} else {
		::plugins::DGUI::setup_aspect_Insight
	}
}

# Skin-independent font selection. A wrapper to either ::get_font in utils.tcl, or a skin-specific font management
# function.
proc ::plugins::DGUI::get_font { {font_name {}} {size {}} } {
	variable font
	variable font_size
	if { $font_name eq "" } { set font_name $font }
	if { $size eq "" } { set size $font_size }
	
	if { $::settings(skin) eq "DSx" } {
		return [::DSx_font $font_name $size]
	} elseif { $::settings(skin) eq "Insight" } {
		if { [string range $font_name end-4 end] eq "_bold" } {
			set fontn "[string range $font_name 0 end-4]${size}_bold"
		} else {
			set fontn "${font_name}_$size"
		}
#		if { [lsearch -exact [font names] $font] == -1 } {
#			load_font 
#		}
		return $fontn
	} else {
		return [::get_font $font_name $size]
	}
}

# Define Fontawesome symbols by name. If a symbol name is already defined and the value differs, it is not changed
#	and a warning added to the log.
proc ::plugins::DGUI::set_symbols { args } {
	variable symbols
	
	set n [expr {[llength $args]-1}]
	for { set i 0 } { $i < $n } { incr i 2 } {
		set sn [lindex $args $i]
		set sv [lindex $args [expr {$i+1}]]
		set idx [lsearch [array names symbols] $sn]
		if { $idx == -1 } {
			msg "add symbol $sn='$sv'"
			set symbols($sn) $sv
		} elseif { $symbols($sn) ne $sv } {
			msg -WARN "symbol '$sn' already defined with a different value"
		}
	}
}
# A one-liner to return a default if a variable is undefined.
# Similar to ifexists in updater.tcl but does not set var (only returns the new value), and assigns empty values
proc ::plugins::DGUI::value_or_default { var default } {
	upvar $var thevar
	
	if {[info exists thevar] == 1} {
		return [subst "\$thevar"]
	} else {
		return $default
	}
}

# Adds a named option "-option_name option_value" to a named argument list if the option doesn't exist in the list.
# Returns the option value.
proc ::plugins::DGUI::args_add_option_if_not_exists { proc_args option_name option_value } {
	upvar $proc_args largs	
	if { [string range $option_name 0 0] ne "-" } { set option_name "-$option_name" }
	set opt_idx [lsearch -exact $largs $option_name]
	if {  $opt_idx == -1 } {
		lappend largs $option_name $option_value
	} else {
		set option_value [lindex $largs [expr {$opt_idx+1}]]
	}
	return $option_value
}

# Removes the named option "-option_name" from the named argument list, if it exists.
proc ::plugins::DGUI::args_remove_option { proc_args option_name } {
	upvar $proc_args largs
	if { [string range $option_name 0 0] ne "-" } { set option_name "-$option_name" }	
	set option_idx [lsearch -exact $largs $option_name]
	if { $option_idx > -1 } {
		if { $option_idx == [expr {[llength $largs]-1}] } {
			set value_idx $option_idx 
		} else {
			set value_idx [expr {$option_idx+1}]
		}
		set largs [lreplace $largs $option_idx $value_idx]
	}
}

# Returns 1 if the named arguments list has a named option "-option_name".
proc ::plugins::DGUI::args_has_option { proc_args option_name } {
	if { [string range $option_name 0 0] ne "-" } { set option_name "-$option_name" }	
	set n [llength $proc_args]
	set option_idx [lsearch -exact $proc_args $option_name]
	return [expr {$option_idx > -1 && $option_idx < [expr {$n-1}]}]
}

# Returns the value of the named option in the named argument list
proc ::plugins::DGUI::args_get_option { proc_args option_name {default_value {}} {rm_option 0} } {
	upvar $proc_args largs	
	if { [string range $option_name 0 0] ne "-" } { set option_name "-$option_name" }
	set n [llength $largs]
	set option_idx [lsearch -exact $largs $option_name]
	if { $option_idx > -1 && $option_idx < [expr {$n-1}] } {
		set result [lindex $largs [expr {$option_idx+1}]]
		if { $rm_option == 1 } {
			set largs [lreplace $largs $option_idx [expr {$option_idx+1}]]
		}
	} else {
		set result $default_value
	}	
	return $result
}

# Extracts from args all pairs whose key start by the prefix. And returns the extracted named options in a new
# args list that contains the pairs, with the prefix stripped from the keys. 
# For example, "-label_fill X" will return "-fill X" if prefix="-label_", and args will be emptied.
proc ::plugins::DGUI::args_extract_prefixed { proc_args prefix } {
	upvar $proc_args largs
	set new_args {}
	set n [expr {[string length $prefix]-1}]
	set i 0 
	while { $i < [llength $largs] } { 
		if { [string range [lindex $largs $i] 0 $n] eq $prefix } {
			lappend new_args "-[string range [lindex $largs $i] 7 9999]"
			lappend new_args [lindex $largs [expr {$i+1}]]
			set largs [lreplace $largs $i [expr {$i+1}]]
		} else {
			incr i 2
		}
	}
	return $new_args
}

# Looks up fields metadata in the data dictionary. 'what' can be a list with multiple items, then a list is returned.
proc ::plugins::DGUI::field_lookup { field {what name} } {
	variable data_dictionary
	variable field_lookup_whats
	
	if { $field eq "" } return
	
	if { ![info exists data_dictionary($field)] } { 
		msg "WARNING data field '$field' unmatched in proc field_lookup"
		return {} 
	}
	
	set result {}
	foreach whatpart $what {
		set match_idx [lsearch -all $field_lookup_whats $whatpart]
		if { $match_idx == -1 } { 
			msg "WARNING what item '$whatpart' unmatched in proc field_lookup"
			lappend result {}
		} else {
			lappend result [lindex $data_dictionary($field) $match_idx]
		}
	}

	if { [llength $result] == 1 } { set result [lindex $result 0] }
	return $result
}

proc ::plugins::DGUI::field_names { {data_types {} } {db_tables {}} } {
	variable data_dictionary
	variable field_lookup_whats
	
	if { $data_types eq "" && $db_tables eq "" } {
		return [array names data_dictionary]
	} 
	
	if { $data_types eq "" } {
		set dt_idx -1
	} else { 
		set dt_idx [lsearch -all $field_lookup_whats "data_type"]
	}
	if { $db_tables eq "" } {
		set tab_idx -1
	} else {
		set tab_idx [lsearch -all $field_lookup_whats "db_table"]
	}
	
	set fields {}	
	foreach fn [array names data_dictionary] {
		set data_type [lindex $data_dictionary($fn) $dt_idx]
		set db_table [lindex $data_dictionary($fn) $tab_idx]
		
		set matches_dt [expr {$dt_idx == -1 || [lsearch -all $data_types $data_type] > -1 }]
		set matches_tab [expr {$tab_idx == -1 || [lsearch -all $db_tables $db_table] > -1 }]
		if { $matches_dt && $matches_tab } { lappend fields $fn }
	}
	
	return $fields
}

# TODO: USE A MEANINGFUL VALIDATION FUNCTION INSTEAD!
proc ::plugins::DGUI::keypress_is_number_or_dot {keyvalue} {
	# set ::DYE::debug_text "PRESSED \"$keyvalue\""
	return [expr { [string is integer $keyvalue] || $keyvalue eq "period" } ]
}

# TODO: USE A MEANINGFUL VALIDATION FUNCTION INSTEAD!
proc ::plugins::DGUI::keypress_is_number_or_slash {keyvalue} {
	#set ::DYE::debug_text "PRESSED \"$keyvalue\""
	return [expr { [string is integer $keyvalue] || $keyvalue eq "slash" } ]
}

proc ::plugins::DGUI::page_name_is_namespace { page_name } {
	return [expr {[string range $page_name 0 1] eq "::" && [info exists ${page_name}::widgets]}]
}

# Call this on the page "load_page" namespace proc, before the actual page_show call, to store the page from which
# the new one was called.
proc ::plugins::DGUI::set_previous_page { ns } {
	if { ! [page_name_is_namespace $ns] } return
	
	set prev_page $::de1(current_context)
	if { $prev_page eq "::plugins::DYE::MENU" } {
		set prev_page $::plugins::DYE::MENU::data(previous_page)
	}
	set "${ns}::data(previous_page)" $prev_page
}


# "Smart" widget names selector. If 'ns' is specified, looks for the widgets in <ns>::widgets(<widget_name>),
#	otherwise assumes 'widgets' directly references the widgets names.
# If a namespace 'ns' is provided, and a widget_name final character is a "*", tries to find all "related" widgets
#	with that name, namely those with suffix "_label", "_state", "_symbol", "_img" and "_button".
# Also, if the widget_name ends in "_rating*", tries to find _rating_button, _rating1, _rating_half1, etc.
proc ::plugins::DGUI::select_widgets { widgets {ns {}} } {
	set result {}
	if { $ns eq "" } { 
		foreach wn $widgets {
			if { $wn ne "" && [info exists $wn] } { 
				lappend result $wn  
			} else {
				msg "ERROR: select_widgets - can't find widget '$wn'"
			}
		}
	} else {
		foreach wn $widgets {
			if { [string range $wn end end] eq "*" } {
				set some_found 0
				if { [string range $wn end-7 end] eq "_rating*"} {
					set wn [string range $wn 0 end-1]					
					if { [info exists "${ns}::widgets(${wn}_button)"] } {
						lappend result [subst \$${ns}::widgets(${wn}_button)]
						set some_found 1
						set i 1
						while { [info exists "${ns}::widgets(${wn}$i)"] } {
							lappend result [subst \$${ns}::widgets(${wn}$i)]
							if { [info exists "${ns}::widgets(${wn}_half$i)"] } {
								lappend result [subst \$${ns}::widgets(${wn}_half$i)]
							}
							incr i
						}
					}
				} elseif { [string range $wn end-8 end] eq "_clicker*"} {
					set wn [string range $wn 0 end-1]					
					foreach subtype "{} _dec_small_inc _dec_big_inc _inc_small_inc _inc_big_inc _button" {
						if { [info exists "${ns}::widgets(${wn}$subtype)"] } {
							lappend result [subst \$${ns}::widgets(${wn}$subtype)]
							set some_found 1
						}
					}
				} else {
					set wn [string range $wn 0 end-1]
					
					foreach subtype "{} _label _symbol _img _button _state _clicker _rating" {
						if { $subtype eq "_clicker" } {
							foreach subsubtype "{} _dec_small_inc _dec_big_inc _inc_small_inc _inc_big_inc _button" {
								if { [info exists "${ns}::widgets(${wn}_clicker${subsubtype})"] } {
									lappend result [subst \$${ns}::widgets(${wn}_clicker${subsubtype})]
									set some_found 1
								}
							}
						} elseif { $subtype eq "_rating " } {
							set i 1
							while { [info exists "${ns}::widgets(${wn}_rating$i)"] } {
								lappend result [subst \$${ns}::widgets(${wn}_rating$i)]
								if { [info exists "${ns}::widgets(${wn}_rating_half$i)"] } {
									lappend result [subst \$${ns}::widgets(${wn}_rating_half$i)]
								}
								incr i
							}
						} else {
							if { [info exists "${ns}::widgets(${wn}$subtype)"] } {
								lappend result [subst \$${ns}::widgets(${wn}$subtype)]
								set some_found 1
							}
						}
					}
				}
				if { $some_found == 0 } {
					msg "ERROR: select_widgets - can't find any widget variable ${ns}::widgets($wn)"
				}
			} else {
				if { [info exists "${ns}::widgets($wn)"] } {
					lappend result [subst \$${ns}::widgets($wn)]
				} else {
					msg "ERROR: select_widgets - can't find widget variable ${ns}::widgets($wn)"
				}
			}
		}
	}
	return $result
}

# "Smart" widgets enabler or disabler. 'enabled' can take any value equivalent to boolean (1, true, yes, etc.) 
# For text, changes its fill color to the default or provided font or disabled color.
# For other widgets like rectangle "clickable" button areas, enables or disables them.
# Does nothing if the widget is hidden.
# If 'ns' is given, takes the widgets spec accepted by 'select_widgets'.
proc ::plugins::DGUI::enable_or_disable_widgets { enabled widgets {ns {}} { enabled_color {}} { disabled_color {} } } {
	if { $enabled_color eq "" } { set enabled_color $::plugins::DGUI::font_color }
	if { $disabled_color eq "" } { set disabled_color $::plugins::DGUI::disabled_color }
	
	if { [string is true $enabled] } {
		set color $enabled_color
		set state normal		
	} else {
		set color $disabled_color
		set state disabled		
	}
	
	foreach wn [::plugins::DGUI::select_widgets $widgets $ns] {		
#		set wc ""; catch { append wc [winfo class widget] }
#		msg "DYE disabling widget $wn - class $wc"
		# DE1 prefixes: text / image / .btn			
		if { [string range $wn 0 3] eq "text" } {
			if { [.can itemconfig $wn -state] ne "hidden" } { .can itemconfig $wn -fill $color }
		} elseif { [string range $wn 0 3] eq ".btn" } {
			if { [.can itemconfig $wn -state] ne "hidden" } { .can itemconfig $wn -state $state }
		} elseif { [string range $wn 0 5] eq ".can.w"} {
			if { [$wn cget -state] ne "hidden" } { $wn configure -state $state }
		}
	}
	
	update		
} 

# "Smart" widgets disabler. 
# For text, changes its fill color to the default or provided disabled color.
# For other widgets like rectangle "clickable" button areas, disables them.
# Does nothing if the widget is hidden. 
proc ::plugins::DGUI::disable_widgets { widgets {ns {}} { disabled_color {}} } {
	::plugins::DGUI::enable_or_disable_widgets 0 $widgets $ns {} $disabled_color
}

proc ::plugins::DGUI::enable_widgets { widgets {ns {}} { enabled_color {} } } {
	::plugins::DGUI::enable_or_disable_widgets 1 $widgets $ns $enabled_color {}
}

# "Smart" widgets shower or hider. 'show' can take any value equivalent to boolean (1, true, yes, etc.)
# If 'contex' is provided, only hides or shows if that context is currently active. For example, if you're showing
#	after a delay, the page/context may not be currently shown.
# If 'ns' is given, takes the widgets spec accepted by 'select_widgets'. 
proc ::plugins::DGUI::show_or_hide_widgets { show widgets {ns {}} { context {}} } {
	if { $context ne "" && $context ne $::de1(current_context) } return
	
	if { [string is true $show] } {
		set state normal
	} else {
		set state hidden
	}
	
	foreach wn [::plugins::DGUI::select_widgets $widgets $ns] {
		.can itemconfig $wn -state $state
	}

	update
}

proc ::plugins::DGUI::show_widgets { widgets {ns {}} { context {} } } {
	show_or_hide_widgets 1 $widgets $ns $context
}

proc ::plugins::DGUI::hide_widgets { widgets {ns {}} { context {}} } {
	show_or_hide_widgets 0 $widgets $ns $context
}
		
# Adds a standard DYE dialog page to the DE1 GUI.
# New named options:
#	* -title: The page title. If not defined, uses variable <namespace>::data(page_title). A widget named "page_title"
#		is added to the namespace widgets array.
#   * -add_bg_img: Whether to add the background image, default 1. Use 0 if the page needs to be initialized in some
#		other way, like for DSx configuration pages carousel.
#	* -done_button: 0 or 1 (default), to include a "done" button. This will call a "<namespace>::page_done" command 
#	* -cancel_button: 0 or 1 (default), to include a "cancel" button. This will call a "<namespace>::page_cancel" command
#	* -buttons_loc: one of "left", "center" or "right" (default).
proc ::plugins::DGUI::add_page { page args } {		
	array set opts $args
	set has_ns [page_name_is_namespace $page]

	if { [ifexists opts(-add_bg_img) 1] == 1 && $::plugins::DGUI::page_bg_image ne "" } {
		add_de1_image $page 0 0 $::plugins::DGUI::page_bg_image
	} else {
		set background_id [.can create rect 0 0 [rescale_x_skin 2560] [rescale_y_skin 1600] \
			-fill $::plugins::DGUI::bg_color -width 0 -state "hidden"]
		add_visual_item_to_context $page $background_id
	}
	
	if { $has_ns } {
		set "${page}::data(page_name)" $page
		lappend ::plugins::DGUI::pages $page
	}
	
	if { [info exists opts(-title)] } {
		set w [::add_de1_text $page 1280 60 \
			-font [::plugins::DGUI::get_font $::plugins::DGUI::header_font $::plugins::DGUI::header_font_size] \
			-fill $::plugins::DGUI::page_title_color -anchor "center" -text $opts(-title)]
		if { $has_ns } { set "${page}::widgets(page_title)" $w }
	} elseif { $has_ns && [info exists ${page}::data(page_title)] } {
		set "${page}::widgets(page_title)" [::add_de1_variable $page 1280 60 \
			-font [::plugins::DGUI::get_font $::plugins::DGUI::header_font $::plugins::DGUI::header_font_size] \
			-fill $::plugins::DGUI::page_title_color -anchor "center" -textvariable [subst {\$${page}::data(page_title)}] ]
	}
	
	set done_button 1
	if { [info exists opts(-done_button)] && $opts(-done_button) == 0 } { set done_button 0 }
	set cancel_button 1
	if { [info exists opts(-cancel_button)] && $opts(-cancel_button) == 0 } { set cancel_button 0 }  
	
	if { !$done_button && !$cancel_button } return
	
	set y 1425
	if { [info exists opts(-buttons_loc)] && $opts(-buttons_loc) eq "center" } {
		if { $done_button && $cancel_button } {
			set x_cancel [expr {1280-[rescale_x_skin $::plugins::DGUI::button2_width]-75}]
			set x_done [expr {1280+75}]
		} elseif { $done_button } {
			set x_done [expr {1280-[rescale_x_skin $::plugins::DGUI::button2_width]/2}]
		} elseif { $cancel_button } {
			set x_cancel [expr {1280-[rescale_x_skin $::plugins::DGUI::button2_width]/2}]
		}
	} elseif { [info exists opts(-buttons_loc)] && $opts(-buttons_loc) eq "left" } {
		if { $done_button && $cancel_button } {
			set x_cancel 100
			set x_done 400
		} elseif { $done_button } {
			set x_done 100
		} elseif { $cancel_button } {
			set x_cancel 100
		}
	} else {
		if { $done_button && $cancel_button } {
			set x_cancel 1900
			set x_done 2200
		} elseif { $done_button } {
			set x_done 2200
		} elseif { $cancel_button } {
			set x_cancel 2200
		}
	}
	
	if { $cancel_button } {
		::plugins::DGUI::add_cancel_button $page $x_cancel $y ${page}::page_cancel
	}
	if { $done_button } {
		::plugins::DGUI::add_done_button $page $x_done $y ${page}::page_done
	}
}

# Adds a Cancel button to a page. Two widgets called "cancel_text" and "cancel_button" are added to the namespace 
#	widgets array, and the "cancel_button" widget is returned.
proc ::plugins::DGUI::add_cancel_button { page x y { command {} } { text {Cancel} } } {	
	return [add_button1 $page page_cancel $x $y $text $command]
}

# Adds an Ok / Done button to a page. Two widgets called "done_text" and "done_button" are added to the namespace 
#	widgets array, and the "done_button" widget is returned.
proc ::plugins::DGUI::add_done_button { page x y { command {} } { text {Done} } } {
	return [add_button1 $page page_done $x $y $text $command]
}

# Adds a button1 (the same as used for the Done/Cancel)
proc ::plugins::DGUI::add_button1 { page widget_name x y label command args } {
	set has_ns [page_name_is_namespace $page]
	set width $::plugins::DGUI::button1_width
	set height $::plugins::DGUI::button1_height
	
	args_add_option_if_not_exists args -font [::plugins::DGUI::get_font $::plugins::DGUI::button_font 10] 
	#[::plugins::DGUI::get_font $::plugins::DGUI::button_font 10]
	args_add_option_if_not_exists args -fill $::plugins::DGUI::button_font_fill
	args_add_option_if_not_exists args -anchor "center"

#	variable button_font "font"
#	variable button_font_fill "#ffffff"
#	variable button_fill "#c0c5e3"

	if { $::plugins::DGUI::button1_img eq "" } {
		if { $::settings(skin) eq "DSx" } {
			set w [::plugins::DGUI::rounded_rectangle_outline $page $x $y [expr {$x+$width}] [expr {$y+$height}] \
				[rescale_x_skin 50] $::plugins::DGUI::button_fill 5]			
		} else {
			set w [::plugins::DGUI::rounded_rectangle $page $x $y [expr {$x+$width}] [expr {$y+$height}] \
				[rescale_x_skin 40] $::plugins::DGUI::button_fill]
		}
	} else {	
		#set w [::add_de1_image $page $x $y $::plugins::DGUI::button1_img]
	}
	if { $has_ns } { set "${page}::widgets(${widget_name}_img)" $w }
	if { $label ne "" } {
		set w [::add_de1_text $page [expr {$x + ($width / 2)}] [expr {$y + ($height / 2) - 4}] \
			-text [translate $label] {*}$args ]
		if { $has_ns } { set "${page}::widgets(${widget_name}_label)"  $w }
	}
	
	set widget [::add_de1_button $page $command $x $y [expr {$x + $width}] [expr {$y + $height}]]
	if { $has_ns } { set "${page}::widgets(${widget_name}_button)" $widget }
	return $widget 	
}
	
# Adds a button2 (the big buttons on DSx History Viewer).
# The button can have any of the following 3 components:
#	* label: Main text
#	* state_variable: Variable with the status text, which is shown in a smaller size, below the label. 
#		For showing states like on/off. If the value is.
#	* symbol: A fontawesome symbol shown on the left third of the button
# Adds to the namespace widgets array <widget_name> (clickable button area, returned by the function), 
#	<widget_name>_symbol, <widget_name>_label and <widget_name>_state.
# New named options_
#	-label_fill, -symbol_fill, -state_fill the font color of each element.
proc ::plugins::DGUI::add_button2 { page widget_name x y label state_variable symbol {command {}} args } {
	set has_ns [page_name_is_namespace $page]
	set width $::plugins::DGUI::button2_width
	set height $::plugins::DGUI::button2_height
	
	set label_fill [args_get_option args -label_fill $::plugins::DGUI::button_font_fill 1]
	set symbol_fill [args_get_option args -symbol_fill $::plugins::DGUI::button_font_fill 1]
	set state_fill [args_get_option args -state_fill $::plugins::DGUI::button_font_fill 1]
	set fill [args_get_option args -state_fill $::plugins::DGUI::button_fill 1]
	
	if { $::plugins::DGUI::button2_img eq "" } {
		if { $::settings(skin) eq "DSx" } {
			set w [::plugins::DGUI::rounded_rectangle_outline $page $x $y [expr {$x+$width}] [expr {$y+$height}] \
				[rescale_x_skin 60] $fill 3]
		} else {
			set w [::plugins::DGUI::rounded_rectangle $page $x $y [expr {$x+$width}] [expr {$y+$height}] \
				[rescale_x_skin 40] $fill]
		}
	} else {
		#set w [::add_de1_image $page $x $y $::plugins::DGUI::button2_img ]
	}
	if { $has_ns } { set "${page}::widgets(${widget_name}_img)" $w } 

	if { $symbol eq "" } {
		set x_label [expr {$x+$width/2}]
		set x_state [expr {$x+$width/2}]
	} else {
		set x_label [expr {$x+$width*2/3}]
		set x_state [expr {$x+$width*2/3}]
	}
	if { $state_variable eq "" } {
		set y_label [expr {$y+$height/2}]
		set label_size 8
	} else {
		if { [regexp {[\r\n]} $label] } {
			set y_label [expr {$y+$height/3}]
			set y_state [expr {$y+$height*4/5}]
			set label_size 8
			set state_size 7
		} else {
			set y_label [expr {$y+$height/3}]
			set y_state [expr {$y+$height*2/3}]
			set label_size 8
			set state_size 8
		}
	}
	
	if { $symbol ne "" } {
		set w [::add_de1_text $page [expr {$x+$width/5}] [expr {$y+$height/2}] \
			-text [subst \$::plugins::DGUI::symbols($symbol)] \
			-fill $symbol_fill -font fontawesome_reg_medium -justify "center" -anchor "center"]
		if { $has_ns } { set "${page}::widgets(${widget_name}_symbol)" $w } 
	}
	if { $label eq "" && [info exists "${page}::data(${widget_name}_label)"] } {
		set w [::add_de1_variable $page $x_label [expr {$y_label+3}] \
			-font [::plugins::DGUI::get_font $::plugins::DGUI::button_font $label_size] -fill $label_fill \
			-justify "center" -anchor "center" \
			-textvariable "\$${page}::data(${widget_name}_label)" ]
		if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
	} else {
		set w [::add_de1_text $page $x_label $y_label \
			-text $label -font [::plugins::DGUI::get_font $::plugins::DGUI::button_font $label_size] -fill $label_fill \
			-justify "center" -anchor "center"]
		if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
	}
	if { $state_variable ne "" } {
		if { $state_variable eq "auto" || $state_variable eq "1" } {
			set state_variable "\$${page}::data(${widget_name}_state)"
		}
		set w [::add_de1_variable $page $x_state $y_state \
			-font [::plugins::DGUI::get_font $::plugins::DGUI::button_font $state_size] -fill $state_fill \
			-justify "center" -anchor "center" -textvariable $state_variable]
		if { $has_ns } { set "${page}::widgets(${widget_name}_state)" $w }
	}
	
	set w [::add_de1_button $page $command [expr {$x-14}] [expr {$y-12}] \
		[expr {$x+$width+10}] [expr {$y+$height+10}]]
	if { $has_ns } { set "${page}::widgets(${widget_name})" $w }
	return $w
}

# Adds a button3 (the standard "Ok" wide short button in DSx).
# The button can have any of the following 3 components:
#	* label: Main text
#	* symbol: A fontawesome symbol shown on the left third of the button
# Adds to the namespace widgets array <widget_name> (clickable button area, returned by the function), 
#	<widget_name>_symbol, <widget_name>_label and <widget_name>_state.
# New named options_
#	-label_fill, -symbol_fill, -state_fill the font color of each element.
proc ::plugins::DGUI::add_button3 { page widget_name x y label symbol {command {}} args } {
	set has_ns [page_name_is_namespace $page]
	
	set width [args_get_option args -width $::plugins::DGUI::button3_width 1]
	set height [args_get_option args -width $::plugins::DGUI::button3_height 1]
	set label_fill [args_get_option args -label_fill $::plugins::DGUI::button_font_fill 1]
	set symbol_fill [args_get_option args -symbol_fill $::plugins::DGUI::button_font_fill 1]
	set fill [args_get_option args -state_fill $::plugins::DGUI::button_fill 1]
	
	if { $::settings(skin) eq "DSx" } {
		set w [::plugins::DGUI::rounded_rectangle_outline $page $x $y [expr {$x+$width}] [expr {$y+$height}] \
			[rescale_x_skin 60] $fill 3]
	} else {
		set w [::plugins::DGUI::rounded_rectangle $page $x $y [expr {$x+$width}] [expr {$y+$height}] \
			[rescale_x_skin 40] $fill]
	}
	if { $has_ns } { set "${page}::widgets(${widget_name}_img)" $w } 

	if { $symbol eq "" } {
		set x_label [expr {$x+$width/2}]
	} else {
		set x_label [expr {$x+$width*2/3}]
	}
	set y_label [expr {$y+$height/2}]
	set label_size 8
	
	if { $symbol ne "" } {
		set w [::add_de1_text $page [expr {$x+$width/5}] [expr {$y+$height/2}] \
			-text [subst \$::plugins::DGUI::symbols($symbol)] \
			-fill $symbol_fill -font fontawesome_reg_small -justify "center" -anchor "center"]
		if { $has_ns } { set "${page}::widgets(${widget_name}_symbol)" $w } 
	}
	if { $label eq "" && [info exists "${page}::data(${widget_name}_label)"] } {
		set w [::add_de1_variable $page $x_label [expr {$y_label+3}] \
			-font [::plugins::DGUI::get_font $::plugins::DGUI::button_font $label_size] -fill $label_fill \
			-justify "center" -anchor "center" \
			-textvariable "\$${page}::data(${widget_name}_label)" ]
		if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
	} else {
		set w [::add_de1_text $page $x_label $y_label \
			-text $label -font [::plugins::DGUI::get_font $::plugins::DGUI::button_font $label_size] -fill $label_fill \
			-justify "center" -anchor "center"]
		if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
	}
	
	set w [::add_de1_button $page $command [expr {$x-14}] [expr {$y-12}] \
		[expr {$x+$width+10}] [expr {$y+$height+10}]]
	if { $has_ns } { set "${page}::widgets(${widget_name})" $w }
	return $w
}

# Adapted from gui.tcl "proc add_de1_button", but allowing user-defined options like fill, outline, width etc., 
# as there is not base proc to do that.
# Use -label_* to pass named options to the label. 
proc ::plugins::DGUI::add_button { page widget_name x0 y0 x1 y1 label command args } {
	set has_ns [page_name_is_namespace $page]
	global button_cnt
	incr button_cnt
	set btn_name ".btn_$button_cnt"
	incr button_cnt
	set btn2_name ".btn_$button_cnt"
	
	set rx0 [rescale_x_skin $x0]
	set rx1 [rescale_x_skin $x1]
	set ry0 [rescale_y_skin $y0]
	set ry1 [rescale_y_skin $y1]
	
	args_add_option_if_not_exists args -fill $::plugins::DGUI::entry_bg_color
	args_add_option_if_not_exists args -outline $::plugins::DGUI::font_color
	args_add_option_if_not_exists args -disabledoutline $::plugins::DGUI::disabled_color
	args_add_option_if_not_exists args -activeoutline $::plugins::DGUI::remark_color
	args_add_option_if_not_exists args -width 3

	set label_args {}
	set label_args [args_extract_prefixed args -label_]
	set font_size [args_get_option label_args -font_size $::plugins::DGUI::font_size 1]
	args_add_option_if_not_exists label_args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $font_size] 
	args_add_option_if_not_exists label_args -fill $::plugins::DGUI::font_color
	
	.can create rect $rx0 $ry0 $rx1 $ry1 -tag $btn_name -state hidden {*}$args
	if { $has_ns && $widget_name ne "" } { set "${page}::widgets(${widget_name}_button)" $btn_name }
	
	if { $label ne "" || [info exists "${page}::data(${widget_name}_label)"] } {
		set x_label [expr {$x0+($x1-$x0)/2}]
		set y_label [expr {$y0+($y1-$y0)/2}]
		
		if { $label ne "" } {			
			set w [::add_de1_text $page $x_label $y_label \
				-anchor center -justify center -text $label {*}$label_args ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		} elseif { [info exists "${page}::data(${widget_name}_label)"] } {
			set w [::add_de1_variable $page $x_label $y_label \
				-anchor center -justify center {*}$label_args -textvariable "\$${page}::data(${widget_name}_label)" ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		}
	}

	.can create rect $rx0 $ry0 $rx1 $ry1 -fill {} -outline black -width 0 -tag $btn2_name -state hidden
	if { $has_ns && $widget_name ne "" } { set "${page}::widgets(${widget_name})" $btn2_name }
	
	if { $command ne "" } {
		regsub {%x0} $command $rx0 command
		regsub {%x1} $command $rx1 command
		regsub {%y0} $command $ry0 command
		regsub {%y1} $command $ry1 command
		.can bind $btn2_name [platform_button_press] $command
	}

	add_visual_item_to_context $page $btn_name
	add_visual_item_to_context $page $btn2_name
	return $btn2_name
}

# Discovered through Johanna's MimojaCafe skin code, attributed to Barney.
proc ::plugins::DGUI::rounded_rectangle {context x1 y1 x2 y2 radius colour } {
	set x1 [rescale_x_skin $x1] 
	set y1 [rescale_y_skin $y1] 
	set x2 [rescale_x_skin $x2] 
	set y2 [rescale_y_skin $y2]
	if { [info exists ::_rect_id] != 1 } { set ::_rect_id 0 }
	set tag "rect_$::_rect_id"
	.can create oval $x1 $y1 [expr $x1 + $radius] [expr $y1 + $radius] -fill $colour -outline $colour -width 0 \
		-tag $tag -state "hidden"
	.can create oval [expr $x2-$radius] $y1 $x2 [expr $y1 + $radius] -fill $colour -outline $colour -width 0 \
		-tag $tag -state "hidden"
	.can create oval $x1 [expr $y2-$radius] [expr $x1+$radius] $y2 -fill $colour -outline $colour -width 0 \
		-tag $tag -state "hidden"
	.can create oval [expr $x2-$radius] [expr $y2-$radius] $x2 $y2 -fill $colour -outline $colour -width 0 \
		-tag $tag -state "hidden"
	.can create rectangle [expr $x1 + ($radius/2.0)] $y1 [expr $x2-($radius/2.0)] $y2 -fill $colour -outline $colour \
		-width 0 -tag $tag -state "hidden"
	.can create rectangle $x1 [expr $y1 + ($radius/2.0)] $x2 [expr $y2-($radius/2.0)] -fill $colour -outline $colour \
		-width 0 -tag $tag -state "hidden"
	::add_visual_item_to_context $context $tag
	incr ::_rect_id
	return $tag
}

# Inspired by Barney's rounded_rectangle, mimic DSx buttons showing a button outline without a fill.
proc ::plugins::DGUI::rounded_rectangle_outline {context x1 y1 x2 y2 arc_offset colour width } {
	set x1 [rescale_x_skin $x1] 
	set y1 [rescale_y_skin $y1] 
	set x2 [rescale_x_skin $x2] 
	set y2 [rescale_y_skin $y2]
	if { [info exists ::_rect_id] != 1 } { set ::_rect_id 0 }
	set tag "rect_$::_rect_id"

	.can create arc [expr $x1] [expr $y1+$arc_offset] [expr $x1+$arc_offset] [expr $y1] -style arc -outline $colour \
		-width [expr $width-1] -tag $tag -start 90 -disabledoutline $::plugins::DGUI::disabled_color -state "hidden"
	.can create arc [expr $x1] [expr $y2-$arc_offset] [expr $x1+$arc_offset] [expr $y2] -style arc -outline $colour \
		-width [expr $width-1] -tag $tag -start 180 -disabledoutline $::plugins::DGUI::disabled_color -state "hidden"
	.can create arc [expr $x2-$arc_offset] [expr $y1] [expr $x2] [expr $y1+$arc_offset] -style arc -outline $colour \
		-width [expr $width-1] -tag $tag -start 0 -disabledoutline $::plugins::DGUI::disabled_color -state "hidden"
	.can create arc [expr $x2-$arc_offset] [expr $y2] [expr $x2] [expr $y2-$arc_offset] -style arc -outline $colour \
		-width [expr $width-1] -tag $tag -start -90 -disabledoutline $::plugins::DGUI::disabled_color -state "hidden"
	
	.can create line [expr $x1+$arc_offset/2] [expr $y1] [expr $x2-$arc_offset/2] [expr $y1] -fill $colour \
		-width $width -tag $tag -disabledfill $::plugins::DGUI::disabled_color -state "hidden"
	.can create line [expr $x2] [expr $y1+$arc_offset/2] [expr $x2] [expr $y2-$arc_offset/2] -fill $colour \
		-width $width -tag $tag -disabledfill $::plugins::DGUI::disabled_color -state "hidden"
	.can create line [expr $x1+$arc_offset/2] [expr $y2] [expr $x2-$arc_offset/2] [expr $y2] -fill $colour \
		-width $width -tag $tag -disabledfill $::plugins::DGUI::disabled_color -state "hidden"
	.can create line [expr $x1] [expr $y1+$arc_offset/2] [expr $x1] [expr $y2-$arc_offset/2] -fill $colour \
		-width $width -tag $tag -disabledfill $::plugins::DGUI::disabled_color -state "hidden"
	
	::add_visual_item_to_context $context $tag
	incr ::_rect_id
	return $tag
}


# Calls add_de1_text but with the DYE GUI aspect by default. Returns the created widget. 
# Named options (except the new ones described below) are passed through to add_de1_text.
# New named options:
#  -widget_name, if specified the widget is saved into the widgets array of the namespace, with name "widget_name".
#  -has_button: if 1, makes a clickable rectangular area around the symbol, with action given by -button_cmd
proc ::plugins::DGUI::add_text { page x y text args } {
	set has_ns [page_name_is_namespace $page]
	set widget_name [args_get_option args -widget_name {} 1]
	
	set has_button [args_get_option args -has_button 0 1]
	set button_cmd [args_get_option args -button_cmd {} 1]
	set button_width [args_get_option args -button_width 200 1]
	set button_height [args_get_option args -button_height 40 1]
	
	set font_size [args_get_option args -font_size $::plugins::DGUI::font_size 1]
	args_add_option_if_not_exists args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $font_size]
	args_add_option_if_not_exists args -fill $::plugins::DGUI::font_color
	set anchor [args_add_option_if_not_exists args -anchor nw]

	set widget [::add_de1_text $page $x $y {*}$args -text $text]
	if { $has_ns && $widget_name ne "" } { set "${page}::widgets($widget_name)" $widget }
	
	if { $has_button == 1 } {
		set offset 20
		if { $anchor eq "center" } {
			set x0 [expr {$x-$button_width/2-$offset}]
			set y0 [expr {$y-$button_height/2-$offset}]
			set x1 [expr {$x+$button_width/2+$offset}]
			set y1 [expr {$y+$button_height/2+$offset}]
		} elseif { $anchor eq "ne" } {
			set x0 [expr {$x-$offset-$button_width}]
			set y0 [expr {$y-$offset-$button_height}]
			set x1 [expr {$x+$offset}]
			set y1 [expr {$y+$offset}]
		} else {
			#assume nw
			set x0 [expr {$x-$offset}]
			set y0 [expr {$y-$offset}]
			set x1 [expr {$x+$button_width+$offset}]
			set y1 [expr {$y+$button_height+$offset}]
		}
		
		set button_widget [::add_de1_button $page $button_cmd $x0 $y0 $x1 $y1]
		if { $has_ns && $widget_name ne "" } { set "${page}::widgets(${widget_name}_button)" $button_widget}
	}
	
	return $widget	
}

# Inserts a fontawesome symbol. Returns the created symbol text widget. Named arguments are passed through to add_de1_text.
# New named arguments:
#  -widget_name: if specified the widget is saved into the widgets array of the namespace, with name "widget_name".
#  -size: size of the symbol, can be one of small (default), medium or big.
#  -has_button: if 1, makes a clickable rectangular area around the symbol, with action given by -button_cmd
proc ::plugins::DGUI::add_symbol { page x y symbol args } {
	variable symbols
	set has_ns [page_name_is_namespace $page]
	args_add_option_if_not_exists args -fill $::plugins::DGUI::font_color
	set anchor [args_add_option_if_not_exists args -anchor nw]
	set has_button [args_get_option args -has_button 0 1]
	set button_cmd [args_get_option args -button_cmd {} 1]
	
	set size [args_get_option args -size small 1]
	if { [info exists symbols($symbol) ] } {
		set text $symbols($symbol)
		#set text [subst \$::plugins::DGUI::symbol_$symbol]
	} else {
		set text $symbol
	}
	set widget_name [args_get_option args -widget_name {} 1]
	
	set widget [::add_de1_text $page $x $y -font fontawesome_reg_$size {*}$args -text $text]
	if { $has_ns && $widget_name ne "" } { set "${page}::widgets($widget_name)" $widget }
	
	if { $has_button == 1 } {
		set offset 20
		if { $size eq "small"} { set symbol_space 65
		} elseif { $size eq "medium"} { set symbol_space 90
		} elseif { $size eq "big"} { set symbol_space 150 }
		
		if { $anchor eq "center" } {
			set x0 [expr {$x-$symbol_space/2-$offset}]
			set y0 [expr {$y-$symbol_space/2-$offset}]
			set x1 [expr {$x+$symbol_space/2+$offset}]
			set y1 [expr {$y+$symbol_space/2+$offset}]
		} elseif { $anchor eq "ne" } {
			set x0 [expr {$x-$offset-$symbol_space}]
			set y0 [expr {$y-$offset-$symbol_space}]
			set x1 [expr {$x+$offset}]
			set y1 [expr {$y+$offset}]
			
		} else { 
			#assume nw
			set x0 [expr {$x-$offset}]
			set y0 [expr {$y-$offset}]
			set x1 [expr {$x+$symbol_space+$offset}]
			set y1 [expr {$y+$symbol_space+$offset}]
		}
		
		set button_widget [::add_de1_button $page $button_cmd $x0 $y0 $x1 $y1]
		if { $has_ns && $widget_name ne "" } { set "${page}::widgets(${widget_name}_button)" $button_widget}
	}
	
	return $widget	
}

# Calls add_de1_variable but with the DYE GUI aspect by default. Returns the created widget.
# Named options (except the new ones described below) are passed through to add_de1_widget.
# If textvariable is a plain name (no parenthesis, ::, etc.) and <page>::data($textvariable) exists, it is used,
#	and the widget receives the textvariable value name, unless -widget_name is explicitly provided. 
# New named options:
#  -widget_name: if specified the widget is saved into the widgets array of the namespace, with name "widget_name".
#  -has_button: if 1, makes a clickable rectangular area around the symbol, with action given by -button_cmd
proc ::plugins::DGUI::add_variable { page x y textvariable args } {	
	set has_ns [page_name_is_namespace $page]

	set font_size [args_get_option args -font_size $::plugins::DGUI::font_size 1]
	args_add_option_if_not_exists args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $font_size]
	args_add_option_if_not_exists args -fill $::plugins::DGUI::font_color
	set anchor [args_add_option_if_not_exists args -anchor nw]
	
	if { $has_ns && [string is wordchar $textvariable] && [info exists "${page}::data($textvariable)"] } {
		if { ![args_has_option args -widget_name] } {
			set widget_name $textvariable
		}		
		set textvariable "\$${page}::data($textvariable)"
	} else {
		set widget_name [args_get_option args -widget_name {} 1]
	}

	set has_button [args_get_option args -has_button 0 1]
	set button_cmd [args_get_option args -button_cmd {} 1]
	set button_width [args_get_option args -button_width 200 1]
	set button_height [args_get_option args -button_height 40 1]
	
	set widget [::add_de1_variable $page $x $y {*}$args -textvariable $textvariable]
	if { $has_ns && $widget_name ne "" } { set "${page}::widgets($widget_name)" $widget }

	if { $has_button == 1 } {
		set offset 20
		if { $anchor eq "center" } {
			set x0 [expr {$x-$button_width/2-$offset}]
			set y0 [expr {$y-$button_height/2-$offset}]
			set x1 [expr {$x+$button_width/2+$offset}]
			set y1 [expr {$y+$button_height/2+$offset}]
		} elseif { $anchor eq "ne" } {
			set x0 [expr {$x-$offset-$button_width}]
			set y0 [expr {$y-$offset-$button_height}]
			set x1 [expr {$x+$offset}]
			set y1 [expr {$y+$offset}]
		} else {
			#assume nw
			set x0 [expr {$x-$offset}]
			set y0 [expr {$y-$offset}]
			set x1 [expr {$x+$button_width+$offset}]
			set y1 [expr {$y+$button_height+$offset}]
		}
		
		set button_widget [::add_de1_button $page $button_cmd $x0 $y0 $x1 $y1]
		if { $has_ns && $widget_name ne "" } { set "${page}::widgets(${widget_name}_button)" $button_widget}
	}
		
	return $widget
}
	
# Adds a text entry widget and its label using DYE GUI standards:
# 	Stores the entry widget in the widgets array of the namespace, and stores the data in the data array of the namespace.
# 	If field_name is specified, uses the data dictionary to automate things, such as validation
#	Named options (except the new ones described below) are passed through to add_de1_widget.
#	If -textvariable is not specified, variable ::DYE::<page>::data(field_name) is used.
# New named options: 
#	-widget_name: if not specified the widget is stored as ::DYE::<page>::widgets(field_name). Its label, if defined,
#		is stored as ::DYE::<page>::widgets(field_name_label)
#	-label: if not specified and field_name is in the data dictionary, uses the data dictionary name lookup.
#			If still blank, and <page>::data(<widget_name>_label) exists, uses it as -textvariable.
#			Use x_label=-1 & y_label=-1 to not paint a label.
#	-data_type, -n_decimals, -min_value, -max_value: all used for validation, if not specified uses the values
#		looked up in the data dictionary for $field_name.
#	-dropdown_cmd: For categories, the command to execute when tapping the dropdown arrow. If not specified,
#		launches the DYE_item_selection page to show the category field_type.
# 	-dropdown_callback_cmd: For categories, the callback command from the IS page. Defaults to ${page}::select_${field_name}_callback
#	-clicker: If not empty and the data_type is numeric, adds clicker arrows to change the value.
#		Must be a list with 3 elements, big increment, small increment, and default value on first click.
#		Use empty "-clicker {}" to take those values from the data dictionary.
#	-extra_clicker_cmd: Tcl code to be run *after* the clicker command is run. 
#	-editor_page: If 1 (default), double tapping the box will launch a dedicated editor page for the field. Currently 
#		supported for numeric data only. By default all numeric entries launch the numeric pad editor, unless 
#		editor_page=0

proc ::plugins::DGUI::add_entry { page field_name x_label y_label x_widget y_widget width args } {
	set has_ns [page_name_is_namespace $page]
	set widget_name [args_get_option args -widget_name $field_name 1]

	if { $::debugging } { msg "add_entry $page - $widget_name" }
	# If the field name is found in the data dictionary, use its metadata unless they are provided in the proc call
	lassign [field_lookup $field_name {name data_type n_decimals min_value max_value \
		small_increment big_increment default_value}] \
		f_label f_data_type f_n_decimals f_min_value f_max_value f_small_increment f_big_increment f_default_value
	foreach fn {label data_type n_decimals min_value max_value small_increment big_increment default_value} {
		set $fn [args_get_option args "-$fn" [subst \$f_$fn] 1]
	}		
	
	# Parse arguments to extract those that are not going to be re-passed through to "entry", and set defaults
	# for those that the client code has not defined.
	set textvariable [args_add_option_if_not_exists args -textvariable "${page}::data($widget_name)"]
	args_add_option_if_not_exists args -width [expr {int($width * $::globals(entry_length_multiplier))}]
	set font_size [args_get_option args -font_size $::plugins::DGUI::font_size 1]
	args_add_option_if_not_exists args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $font_size]	
	args_add_option_if_not_exists args -justify left
	args_add_option_if_not_exists args -relief $::plugins::DGUI::entry_relief
	args_add_option_if_not_exists args -borderwidth 1 
	args_add_option_if_not_exists args -bg $::plugins::DGUI::entry_bg_color
	args_add_option_if_not_exists args -highlightthickness 1
	args_add_option_if_not_exists args -highlightcolor $::plugins::DGUI::font_color
	args_add_option_if_not_exists args -foreground $::plugins::DGUI::font_color 
	args_add_option_if_not_exists args -insertbackground $::plugins::DGUI::insert_bg_color
	args_add_option_if_not_exists args -disabledbackground $::plugins::DGUI::disabled_color
	args_add_option_if_not_exists args -disabledforeground $::plugins::DGUI::bg_color
	args_add_option_if_not_exists args -exportselection 1
	set editor_page [args_get_option args -editor_page 1 1]
	
	# Validation
	if { ![args_has_option $args -vcmd] } {
		if { $data_type eq "numeric" } {
			set vcmd "expr \{\[string trimleft %P 0\] eq \{\} || ("
			if { $n_decimals == 0 } {
				append vcmd "\[string is entier %P\] && "
			} else {
				append vcmd "\[string is double %P\] && "
			}
			if { $min_value ne "" } {
				append vcmd "\[string trimleft %P 0\] >= $min_value && "
			}
			if { $max_value ne "" } {
				append vcmd "\[string trimleft %P 0\] <= $max_value && "
			}
			set vcmd [string range $vcmd 0 end-4]
			append vcmd ")\}"
		} elseif { $data_type eq "date" } {
			set vcmd "regexp \{^\[0-9/\]\{0,10\}\$\} %P"
		} else {
			set vcmd ""
		}
		
		if { $vcmd ne "" } {
			args_add_option_if_not_exists args -vcmd $vcmd
			args_add_option_if_not_exists args -validate key
		}
	}

	# Label
	if { $x_label > -1 && $y_label > -1 } {
		set label_args {}
		set label_args [args_extract_prefixed args -label_]
		set label_font_size [args_get_option label_args -font_size $font_size 1]
		args_add_option_if_not_exists label_args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $label_font_size] 
		args_add_option_if_not_exists label_args -fill $::plugins::DGUI::font_color
		args_add_option_if_not_exists label_args -anchor "nw"
		
		if { $label ne "" } {			
			set w [::add_de1_text $page $x_label [expr {$y_label+3}] -text $label {*}$label_args ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		} elseif { [info exists "${page}::data(${widget_name}_label)"]} {
			set w [::add_de1_variable $page $x_label [expr {$y_label+3}] {*}$label_args \
				-textvariable "\$${page}::data(${widget_name}_label)" ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		}
	}
	
	# Clicker arrows around the entry
	if { [args_has_option $args -clicker] } {
		set clicker_opts [args_get_option args -clicker "" 1]
		if { [llength $clicker_opts] > 0 } { set big_increment [lindex $clicker_opts 0] }
		if { [llength $clicker_opts] > 1 } { set small_increment [lindex $clicker_opts 1] }
		if { [llength $clicker_opts] > 2 } { set default_value [lindex $clicker_opts 2] }
				
		set extra_clicker_cmd [args_get_option args -clicker_cmd "" 1]

		if { $data_type eq "numeric" } { 
			set clicker_cmd "say \"\" \$::settings(sound_button_in); "
			if { $default_value ne "" } {
				append clicker_cmd "if \{ \$$textvariable eq \"\" \} \{ set $textvariable $default_value \};"
			}
			append clicker_cmd "::plugins::DGUI::horizontal_clicker $big_increment $small_increment $textvariable $min_value $max_value %x %y %%x0 %%y0 %%x1 %%y1;"

			if { $n_decimals == 0 } {
				append clicker_cmd "set $textvariable \[expr \{round(\$$textvariable)\}\];"
			}
			if { $extra_clicker_cmd ne "" } { append clicker_cmd $extra_clicker_cmd } 
			
#			set w [::add_de1_image $page [expr {$x_widget-250}] [expr {$y_widget-8}] \
#				 "[skin_directory_graphics]/icons/click_no_box.png"]
#			if { $has_ns } { set "${page}::widgets(${widget_name}_clicker_img)" $w}
			set w [::plugins::DGUI::add_symbol $page [expr {$x_widget-235}] [expr {$y_widget-3}] chevron_double_left]
			if { $has_ns } { set "${page}::widgets(${widget_name}_clicker_dec_big_inc)" $w}
			set w [::plugins::DGUI::add_symbol $page [expr {$x_widget-100}] [expr {$y_widget-3}] chevron_left]
			if { $has_ns } { set "${page}::widgets(${widget_name}_clicker_dec_small_inc)" $w}
			set w [::plugins::DGUI::add_symbol $page [expr {$x_widget+180}] [expr {$y_widget-3}] chevron_right]
			if { $has_ns } { set "${page}::widgets(${widget_name}_clicker_inc_small_inc)" $w}
			set w [::plugins::DGUI::add_symbol $page [expr {$x_widget+270}] [expr {$y_widget-3}] chevron_double_right]
			if { $has_ns } { set "${page}::widgets(${widget_name}_clicker_inc_big_inc)" $w}
			
			set w [::add_de1_button $page $clicker_cmd \
				[expr {$x_widget-250}] [expr {$y_widget-8}] [expr {$x_widget+360}] [expr {$y_widget+75}] ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_clicker)" $w }
		}
	}
			
	set widget [::add_de1_widget $page entry $x_widget $y_widget {
			bind $widget <Return> { hide_android_keyboard ; focus [tk_focusNext %W] }
		} -exportselection 1 {*}$args ]
	
	# Default actions on leaving a text entry: Trim text and hide_android_keyboard
	if { $data_type eq "text" || $data_type eq "long_text" || $data_type eq "category" } {
		set leave_cmd "set $textvariable \[string trim \$$textvariable\]; hide_android_keyboard;"
	} elseif { $data_type eq "numeric" && $n_decimals > 0 } {
		set leave_cmd "if \{\$$textvariable ne \{\} \} \{ 
			set $textvariable \[format \"%%.${n_decimals}f\" \$$textvariable\] 
			\}; hide_android_keyboard;"
	} else {
		set leave_cmd "hide_android_keyboard"
	}	
	bind $widget <Leave> $leave_cmd
	
	if { $has_ns } { set "${page}::widgets($widget_name)" $widget }
	
	# Invoke editor page on double tap
	if { $data_type eq "numeric" && $editor_page == 1 } {
		set editor_cmd "if \{ \[$widget cget -state\] eq \"normal\" \} \{ ::plugins::DGUI::NUME::load_page \"$field_name\" \
			$textvariable -n_decimals $n_decimals -min_value $min_value -max_value $max_value \
			-default_value $default_value -small_increment $small_increment -big_increment $big_increment \}"
		bind $widget <Double-Button-1> $editor_cmd
	}
	
	return $widget
}

# Adds a "fake combobox", an entry box with an "dropdown arrow" symbol on its right that allows selecting its value
# 	from a list of available values/items. 
# Takes all named arguments of 'add_entry' plus the following:
#	-items: the list of available items to choose from.
#	-item_ids: a list of the same length as 'items' with matching IDs/primary keys. 
#	-select_cmd: the command to run when the "dropdown arrow" is tapped, or when the entry box is double tapped.
#		By default, the Item Selection ::plugins::DGUI::IS page is launched.
#	-callback_cmd: the command to pass to the IS page to be run when returning from the selection. This is not needed
#		in general as the IS page will automatically write its selection to -textvariable, but is here for cases where
#		further customization is needed.

proc ::plugins::DGUI::add_select_entry { page field_name x_label y_label x_widget y_widget width args } {
	set has_ns [page_name_is_namespace $page]
	set widget_name [args_get_option args -widget_name $field_name 1]

	if { $::debugging } { msg "add_select_entry $page - $field_name" }
	# Extract all specific argument related to the selection part, then invoke add_entry
	set textvariable [args_add_option_if_not_exists args -textvariable "${page}::data($widget_name)"]
	set callback_cmd [args_get_option args -callback_cmd "" 1]
	if { $callback_cmd eq "" && [namespace which -command "${page}::select_${widget_name}_callback"] ne "" } {
		set callback_cmd "${page}::select_${widget_name}_callback"
	}
	set items [args_get_option args -items {} 1]
	set item_ids [args_get_option args -item_ids {} 1]
	
	set select_cmd [args_get_option args -select_cmd "" 1]
	if { $select_cmd eq "" } {
		set select_cmd "say \"select\" $::settings(sound_button_in)
			::plugins::DGUI::IS::load_page $field_name $textvariable \"$items\""
		if { $callback_cmd ne "" } {
			append select_cmd  " -callback_cmd \"$callback_cmd\""
		}
		foreach fn "item_ids page_title" { 
			if { [args_has_option $args -$fn] } {
				append select_cmd " -$fn \"[args_get_option args -$fn {} 1]\""
			}
		}
	}

	set widget [add_entry $page $field_name $x_label $y_label $x_widget $y_widget $width {*}$args]
	bind $widget <Double-Button-1> $select_cmd
	
	# Dropdown selection arrow	
	set w [add_de1_text $page [expr {$x_widget+300}] [expr {$y_widget-11}] -font fontawesome_reg_small \
		-fill $::plugins::DGUI::font_color -anchor "nw" -justify "left" -text $::plugins::DGUI::symbols(sort_down) ]
	if { $has_ns } { set "${page}::widgets(${widget_name}_dropdown)" $w }
							
	set w [add_de1_button $page $select_cmd [expr {$x_widget+295}] $y_widget \
		[expr {$x_widget+360}] [expr {$y_widget+68}] ]
	if { $has_ns } { set "${page}::widgets(${widget_name}_dropdown_button)" $w }
	
	return $widget
}

# Adds a multiline text entry widget and its label using DYE GUI standards:
# 	Stores the entry widget in the widgets array of the namespace, and stores the data in the data array of the namespace.
# 	If field_name is specified, uses the data dictionary to automate things, such as validation
#	Named options (except the new ones described below) are passed through to add_de1_widget.
#	If -textvariable is not specified, variable ::DYE::<page>::data(field_name) is used.
# New named options: 
#	-widget_name: if not specified the widget is stored as ::DYE::<page>::widgets(field_name). Its label, if defined,
#		is stored as ::DYE::<page>::widgets(field_name_label)
#	-label: if not specified and field_name is in the data dictionary, uses the data dictionary name lookup.
#			If still blank, and <page>::data(<widget_name>_label) exists, uses it as -textvariable.
#			Use x_label=-1 & y_label=-1 to not paint a label.
#	-data_type, -n_decimals, -min_value, -max_value: all used for validation, if not specified uses the values
#		looked up in the data dictionary for $field_name.
# 	-dropdown_callback_cmd: For categories, the callback command from the IS page. Defaults to ${page}::select_${field_name}_callback
proc ::plugins::DGUI::add_multiline_entry { page field_name x_label y_label x_widget y_widget {width 20} {height 3} args } {
	set has_ns [page_name_is_namespace $page]
	set widget_name [args_get_option args -widget_name $field_name 1]

	if { $::debugging } { msg "add_multiline_entry $page - $field_name" }
	# If the field name is found in the data dictionary, use its metadata unless they are provided in the proc call
	lassign [field_lookup $field_name {name data_type n_decimals min_value max_value}] \
		f_label f_data_type f_n_decimals f_min_value f_max_value 	
	foreach fn {label data_type n_decimals min_value max_value} {
		set $fn [args_get_option args "-$fn" [subst \$f_$fn] 1]
	}
	
	set textvariable [args_add_option_if_not_exists args -textvariable "${page}::data($field_name)"]
	args_add_option_if_not_exists args -width [expr {int($width * $::globals(entry_length_multiplier))}]
	args_add_option_if_not_exists args -height $height
	set font_size [args_get_option args -font_size $::plugins::DGUI::font_size 1]
	args_add_option_if_not_exists args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $font_size]
	set dropdown_callback_cmd [args_get_option args -dropdown_callback_cmd "${page}::select_${field_name}_callback" 1]
	set editor_page [args_get_option args -editor_page 1 1]
	
	args_add_option_if_not_exists args -relief $::plugins::DGUI::entry_relief
	args_add_option_if_not_exists args -borderwidth 1 
	args_add_option_if_not_exists args -bg $::plugins::DGUI::entry_bg_color
	args_add_option_if_not_exists args -highlightthickness 1
	args_add_option_if_not_exists args -highlightcolor $::plugins::DGUI::font_color
	args_add_option_if_not_exists args -foreground $::plugins::DGUI::font_color 
	args_add_option_if_not_exists args -insertbackground $::plugins::DGUI::insert_bg_color
	args_add_option_if_not_exists args -exportselection 1
#	args_add_option_if_not_exists args -disabledbackground $::plugins::DGUI::disabled_color
#	args_add_option_if_not_exists args -disabledforeground $::plugins::DGUI::bg_color
	
	if { $x_label > -1 && $y_label > -1 } {
		set label_args [args_extract_prefixed args -label_]
		args_add_option_if_not_exists label_args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $::plugins::DGUI::font_size] 
		args_add_option_if_not_exists label_args -fill $::plugins::DGUI::font_color
		args_add_option_if_not_exists label_args -anchor "nw"
		
		if { $label ne "" } {
			set w [::add_de1_text $page $x_label [expr {$y_label+3}] -text [translate $label] {*}$label_args ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		} elseif { [info exists "${page}::data(${widget_name}_label)"]} {
			set w [::add_de1_variable $page $x_label [expr {$y_label+3}] \
				{*}$label_args -textvariable "\$${page}::data(${widget_name}_label)" ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		}
	}
	
	set widget [::add_de1_widget $page multiline_entry $x_widget $y_widget {
			bind $widget <Return> { hide_android_keyboard ; focus [tk_focusNext %W] }
		} {*}$args ]
	
	if { $data_type eq "text" || $data_type eq "long_text" || $data_type eq "category" } {
		set leave_cmd "set $textvariable \[string trim \$$textvariable\]; hide_android_keyboard;"
	} else {
		set leave_cmd "hide_android_keyboard"
	}	
	bind $widget <Leave> $leave_cmd
	
	# Double-tap binding doesn't work on multiline_entry. Think of an alternative way.
#	if { $editor_page == 1 } { 
#		set editor_cmd "if \{ \[$widget cget -state\] eq \"normal\" \} \{ 
#			::plugins::DGUI::TXT::load_page $field_name $textvariable 1
#		\} elseif \{ \[$widget cget -state\] eq \"disabled\" \} \{
#			::plugins::DGUI::TXT::load_page $field_name $textvariable 0
#		\}"
#		bind $widget <Double-Button-1> { set ::DYE::debug_text "DBL_CLICK"; continue }
#	}
	
	if { $has_ns } { set "${page}::widgets($widget_name)" $widget }
	
	return $widget
}

# Moves the dropdown arrows (that launches the page to select a category item) to the right of all entry textboxes.
# This is needed as textbox width is defined in characters not in pixels, thus this must be invoked after the 
# initial rendering of the textbox entry, so its actual width in pixels can be computed and the dropdown arrow
# located exactly in the right spot.
# Receives the full array of page/namespace widgets and assumes a convention for the widgets names ("<field_name>" for 
# the textbox, "<field_name>_dropdown" for the dropdown arrow text label, and "<field_name>_dropdown_button" for the
# clickable button area). This is the convention followed when creating the dropdowns automatically in proc 
# ::plugins::DGUI::add_entry.
proc ::plugins::DGUI::relocate_dropdown_arrows { arr_widgets field_names } {
	upvar $arr_widgets widgets
	foreach fn $field_names {
		set coords [.can bbox $widgets($fn) ]
		set newx [expr {[lindex $coords 2] + 10}]
		set newy [expr {[lindex $coords 1] - 10 }]
		.can coords $widgets(${fn}_dropdown) "$newx $newy"
		.can coords $widgets(${fn}_dropdown_button) "[expr {$newx-5}] $newy [expr {$newx+60}] [expr {$newy+60}]"
	}
}

# Moves a text widget with respect to another, i.e. to a position relative to another one.
# pos can be any of "n", "nw", "ne", "s", "sw", "se", "w", "wn", "ws", "e", "en", "es".
# xoffset and yoffset define a fixed offset with respect to the coordinates obtained from processing 'pos'. 
#	Can be positive or negative.
# anchor is how to position the text widget relative to the point obtained after processing pos & offsets. Takes the
#	same values as the standard -anchor option. If not defined, keeps the existing widget -anchor.
# move_too is a list of other widgets that will be repositioned together with widget, maintaining the same relative
#	distances to widget as they had originally. Typically used for the rectangle "button" areas around text labels.
proc ::plugins::DGUI::relocate_text_wrt { widget wrt { pos w } { xoffset 0 } { yoffset 0 } { anchor {} } { move_too {} } } {
	lassign [.can bbox $wrt ] x0 y0 x1 y1 
	lassign [.can bbox $widget ] wx0 wy0 wx1 wy1
	
	if { $pos eq "center" } {
		set newx [expr {$x0+int(($x1-$x0)/2)+$xoffset}]
		set newy [expr {$y0+int(($y1-$y0)/2)+$yoffset}]
	} else {
		set pos1 [string range $pos 0 0]
		set pos2 [string range $pos 1 1]
		
		if { $pos1 eq "w" || $pos1 eq ""} {
			set newx [expr {$x0+$xoffset}]
			
			if { $pos2 eq "n" } {
				set newy [expr {$y0+$yoffset}]
			} elseif { $pos2 eq "s" } {
				set newy [expr {$y1+$yoffset}]
			} else {
				set newy [expr {$y0+int(($y1-$y0)/2)+$yoffset}]
			}
		} elseif { $pos1 eq "e" } {
			set newx [expr {$x1+$xoffset}]
			
			if { $pos2 eq "n" } {
				set newy [expr {$y0+$yoffset}]
			} elseif { $pos2 eq "s" } {
				set newy [expr {$y1+$yoffset}]
			} else {
				set newy [expr {$y0+int(($y1-$y0)/2)+$yoffset}]
			}			
		} elseif { $pos1 eq "n" } {
			set newy [expr {$y0+$yoffset}]
			
			if { $pos2 eq "w" } {
				set newx [expr {$x0+$xoffset}]
			} elseif { $pos2 eq "e" } {
				set newx [expr {$x1+$xoffset}]
			} else {
				set newx [expr {$x0+int(($x1-$x0)/2)+$xoffset}]
			}
		} elseif { $pos1 eq "s" } {
			set newy [expr {$y1+$yoffset}]
			
			if { $pos2 eq "w" } {
				set newx [expr {$x0+$xoffset}]
			} elseif { $pos2 eq "e" } {
				set newx [expr {$x1+$xoffset}]
			} else {
				set newx [expr {$x0+int(($x1-$x0)/2)+$xoffset}]
			}
		} else return 
	}
	
	if { $anchor ne "" } {
		# Embedded in catch as widgets like rectangles don't support -anchor
		catch { .can itemconfigure $widget -anchor $anchor }
	}
	# Don't use 'moveto' as then -anchor is not acknowledged
	.can coords $widget "$newx $newy"
	
	if { $move_too ne "" } {
		lassign [.can bbox $widget] newx newy
		
		foreach w $move_too {			
			set mtcoords [.can coords $w]
			set mtxoffset [expr {[lindex $mtcoords 0]-$wx0}]
			set mtyoffset [expr {[lindex $mtcoords 1]-$wy0}]
			
			if { [llength $mtcoords] == 2 } {
				.can coords $w "[expr {$newx+$mtxoffset}] [expr {$newy+$mtyoffset}]"
			} elseif { [llength $mtcoords] == 4 } {
				.can coords $w "[expr {$newx+$mtxoffset}] [expr {$newy+$mtyoffset}] \
					[expr {$newx+$mtxoffset+[lindex $mtcoords 2]-[lindex $mtcoords 0]}] \
					[expr {$newy+$mtyoffset+[lindex $mtcoords 3]-[lindex $mtcoords 1]}]"
			}
		}
	}
	
	return "$newx $newy"
}

# Ensures a minimum or maximum size of a widget in pixels. This is normally useful for text base entries like 
#	entry or listbox whose width & height on creation have to be defined in number of characters, so may be too
#	small or too big depending on the actual font in use.
proc ::plugins::DGUI::ensure_size { widgets args } {
	array set opts $args
	foreach w $widgets {
		lassign [.can bbox $w ] x0 y0 x1 y1
		set width [rescale_x_skin [expr {$x1-$x0}]]
		set height [rescale_y_skin [expr {$y1-$y0}]]
		
		set target_width 0
		if { [info exists opts(-width)] } {
			set target_width [rescale_x_skin $opts(-width)]
		} elseif { [info exists opts(-max_width)] && $width > [rescale_x_skin $opts(-max_width)]} {
			set target_width [rescale_x_skin $opts(-max_width)] 
		} elseif { [info exists opts(-min_width)] && $width < [rescale_x_skin $opts(-min_width)]} {
			set target_width [rescale_x_skin $opts(-min_width)]
		}
		if { $target_width > 0 } {
			.can itemconfigure $w -width $target_width
		}
		
		set target_height 0
		if { [info exists opts(-height)] } {
			set target_height [rescale_y_skin $opts(-height)]
		} elseif { [info exists opts(-max_height)] && $height > [rescale_y_skin $opts(-max_height)]} {
			set target_height [rescale_y_skin $opts(-max_width)] 
		} elseif { [info exists opts(-min_height)] && $height < [rescale_y_skin $opts(-min_height)]} {
			set target_height [rescale_y_skin $opts(-min_height)]
		}
		if { $target_height > 0 } {
			.can itemconfigure $w -height $target_height
		}
	}
}

# Adds a listbox widget, its (optional) label and its scrollbar, using DYE GUI standards. New widgets
# 	<widget_name>, <widget_name_label>, <widget_name_scrollbar> and <widget_name_slider> are added to the namespace
# 	widgets array.
# New named options: 
#	-label: Label text. If not specified, and <page>::data(<widget_name>_label) exists, uses it as -textvariable.
#	-scrollbar_width
#	-scrollbar_height
#	-sliderlength
proc ::plugins::DGUI::add_listbox { page widget_name x_label y_label x_widget y_widget width height args } {
	set has_ns [page_name_is_namespace $page]
	if { $::debugging } { msg "add_listbox $page - $widget_name" }
	
	if { ![args_has_option $args -listvariable] && [info exists ${page}::data($widget_name)] } {
		args_add_option_if_not_exists args -listvariable "${page}::data($widget_name)"
	}
	set font_size [args_get_option args -font_size $::plugins::DGUI::font_size 1]
	args_add_option_if_not_exists args -font [get_font $::plugins::DGUI::font $font_size]
	args_add_option_if_not_exists args -relief $::plugins::DGUI::listbox_relief
	args_add_option_if_not_exists args -borderwidth $::plugins::DGUI::listbox_bwidth
	args_add_option_if_not_exists args -foreground $::plugins::DGUI::listbox_fg 	
	args_add_option_if_not_exists args -background $::plugins::DGUI::listbox_bg
	args_add_option_if_not_exists args -selectforeground $::plugins::DGUI::listbox_sfg
	args_add_option_if_not_exists args -selectbackground $::plugins::DGUI::listbox_sbg
	args_add_option_if_not_exists args -selectborderwidth $::plugins::DGUI::listbox_sbwidth
	args_add_option_if_not_exists args -disabledforeground $::plugins::DGUI::disabled_color
	args_add_option_if_not_exists args -highlightthickness $::plugins::DGUI::listbox_hthickness
	args_add_option_if_not_exists args -highlightcolor $::plugins::DGUI::listbox_hcolor
	args_add_option_if_not_exists args -exportselection 0
	args_add_option_if_not_exists args -selectmode browser
	args_add_option_if_not_exists args -justify left
	
	set scrollbar_width [rescale_y_skin [args_get_option args -scrollbar_width 75 1]]
	set scrollbar_height [rescale_x_skin [args_get_option args -scrollbar_height 75 1]]
	set sliderlength [rescale_x_skin [args_get_option args -sliderlength 100 1]]

	if { $x_label > -1 && $y_label > -1 } {
		set label [args_get_option args label "" 1]		
		set label_args [args_extract_prefixed args -label_]
		set label_font_size [args_get_option label_args -font_size $font_size 1]
		args_add_option_if_not_exists label_args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $label_font_size] 
		args_add_option_if_not_exists label_args -fill $::plugins::DGUI::font_color
		args_add_option_if_not_exists label_args -anchor "nw"
			
		if { $label ne "" } {
			set w [::add_de1_text $page $x_label [expr {$y_label+3}] -text [translate $label] {*}$label_args ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		} elseif { [info exists "${page}::data(${widget_name}_label)"]} {
			set w [::add_de1_variable $page $x_label [expr {$y_label+3}] \
				{*}$label_args -textvariable "\$${page}::data(${widget_name}_label)" ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		}
	}
	
	set widget [::add_de1_widget $page listbox $x_widget $y_widget {} \
		-height $height -width [expr {int($width * $::globals(entry_length_multiplier))}] \
		-yscrollcommand "scale_scroll_new \$${page}::widgets(${widget_name}) ${page}::widgets(${widget_name}_slider)" \
		-exportselection 1 {*}$args ] 
	
	if { $has_ns } { set "${page}::widgets($widget_name)" $widget }
	
	# Draw the scrollbar off screen so that it gets resized and moved to the right place on the first draw
	if { $has_ns } { set "${page}::widgets(${widget_name}_slider)" 0 }

	set w [::add_de1_widget $page scale [expr {$x_widget+10*$width}] $y_widget {} \
		-from 0 -to 1.0 -bigincrement 0.2 -borderwidth 1 -showvalue 0 -resolution .01 \
		-length $scrollbar_height -width $scrollbar_width -sliderlength $sliderlength \
		-variable "${page}::widgets(${widget_name}_slider)" \
		-command " listbox_moveto \$${page}::widgets($widget_name) \$${page}::widgets(${widget_name}_slider) " \
		-background $::plugins::DGUI::scrollbar_bg -foreground $::plugins::DGUI::scrollbar_fg \
		-troughcolor $::plugins::DGUI::scrollbar_troughcolor -relief $::plugins::DGUI::scrollbar_relief \
		-font [::plugins::DGUI::get_font $::plugins::DGUI::font $::plugins::DGUI::font_size] \
		-borderwidth $::plugins::DGUI::scrollbar_bwidth -highlightthickness $::plugins::DGUI::scrollbar_hthickness]
	if { $has_ns } { set "${page}::widgets(${widget_name}_scrollbar)" $w }

	return $widget
}

# Returns the values of the selected items in a listbox. If a 'values' list is provided, returns the matching
# items in that list instead of matching to listbox entries, unless 'values' is shorter than the listbox,
# in which case indexes not reachable from 'values' are taken from the listbox values.
proc ::plugins::DGUI::listbox_get_selection { widget {values {}} } {
	set cursel [$widget curselection]
	if { $cursel eq "" } return {}

	set result {}	
	set n [llength $values]
	foreach idx [$widget curselection] {
		if { $values ne "" && $idx < $n } {
			lappend result [lindex $values $idx]
		} else {
			lappend result [$widget get $idx]
		}
	}	
	
#	if { [llength $result] == 1 } {
#		return [lindex $result 0]
#	} else {
#		return $result
#	}
	return $result	
}

# Sets the selected items in a listbox, matching the string values.
# If a 'values' list is provided, 'selected' is matched against that list instead of the actual values shown in the listbox.
# If 'reset_current' is 1, clears the previous selection first.
proc ::plugins::DGUI::listbox_set_selection { widget selected { values {} } { reset_current 1 } } {
	if { $selected eq "" } return
	if { $values eq "" } { 
		set values [$widget get 0 end]
	} else {
		# Ensure values has the same length as the listbox items, otherwises trim it or add the listbox items
		set ln [$widget size]
		set vn [llength $values]
		if { $ln < $vn } {
			set values [lreplace $values $ln end]
		} elseif { $ln > $vn } {
			lappend values [$widget get $vn end]
		}
	}
	
	if { $reset_current == 1 } { $widget selection clear 0 end }	
	if { [$widget cget -selectmode] eq "single" && [llength $selected] > 1 } {
		set selected [lindex $selected end]
	}
	
	
	foreach sel $selected {
		set sel_idx [lsearch -exact $values $sel]
		if { $sel_idx > -1 } { 
			$widget selection set $sel_idx 
			$widget see $sel_idx
		}
	}
}
	
# Configures a page listbox scrollbars locations and sizes. Run once the page is shown for then to be dynamically 
# positioned.
proc ::plugins::DGUI::set_scrollbars_dims { page widget_names } {
	if { ![page_name_is_namespace $page] } return
	
	foreach wn $widget_names {
		set listbox_widget [subst \$${page}::widgets($wn)]
		set scrollbar_widget [subst \$${page}::widgets(${wn}_scrollbar)]
		
		lassign [.can bbox $listbox_widget] x0 y0 x1 y1
		$scrollbar_widget configure -length [expr {$y1-$y0}]
		.can coords $scrollbar_widget "$x1 $y0"
	}
}

# Adds a checkbox consisting of a fontawesome square empty/check symbol plus a label text, and dynamically assigns 
# the checkbox value (0 or 1) whenever it changes to the specified namespace data variable <page>::data(<check_variable>).
# Extra named options are applied to both add_de1_text commands.
# Creates 3 widgets in namespace array <page>::widgets():
#	<check_variable>: the square symbol text. The procedure returns this widget.
#	<check_variable>_button: the "clickable" area in the square symbol text
#	<check_variable>_label: the label text
# New named options: 
#	-label: Label text. If not specified, and <page>::data(<widget_name>_label) exists, uses it as -textvariable.
#	-use_page_var: 0 if check_variable is NOT a page namespace data() variable. 1 by default.
proc ::plugins::DGUI::add_checkbox { page check_variable x y {command {}} args } {
	set has_ns [page_name_is_namespace $page]
	
	if { $::debugging } { msg "add_checkbox $page - $check_variable" }
	set use_page_var [args_get_option args use_page_var 1 1]
	set widget_name [args_get_option args widget_name $check_variable 1]
	
	if { $use_page_var == 1 } {
		set check_variable "${page}::data($check_variable)"
		if { ! [info exists ${page}::data($check_variable)] } {
			set "$check_variable" 0
		}			
	}
	
	set $check_variable [string is true [subst \$$check_variable]]
	
	set font_size [args_get_option args -font_size $::plugins::DGUI::font_size 1]
	set font [args_get_option args -font [::plugins::DGUI::get_font $::plugins::DGUI::font $font_size] 1]
	
	if { [args_has_option $args -label] } {
		set label [args_get_option args -label "" 1]
		set w [::add_de1_text $page [expr {$x+70}] [expr {$y+5}] \
			-font $font -fill $::plugins::DGUI::font_color -anchor "nw" -text [translate $label]]
		if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
	} elseif { [info exists "${page}::data(${widget_name}_label)"]} {
		set w [::add_de1_variable $page [expr {$x+70}] [expr {$y+5}] \
			-font $font -fill $::plugins::DGUI::font_color -anchor "nw" -textvariable "\$${page}::data(${widget_name}_label)" ]
		if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
	}
	
	set widget [::plugins::DGUI::add_variable $page $x $y "\[lindex \$::plugins::DGUI::checkbox_symbols_map \[string is true \$$check_variable\]\]" \
		-widget_name $widget_name -justify left -font fontawesome_reg_small {*}$args]
	if { $has_ns } { set "${page}::widgets(${widget_name}_symbol)" $widget }
	
	set cmd "if { \$$check_variable == 1 } { set $check_variable 0 } else { set $check_variable 1 }
		$command"
		
	set w [::add_de1_button $page $cmd [expr {$x-10}] [expr {$y-2}] [expr {$x+300}] [expr {$y+65}] ]
	if { $has_ns } { set "${page}::widgets(${widget_name}_button)" $w }
	
	return $widget
}

# Adds a combo of widgets for "star ratings". Maps to any existing integer variable.
# Named options:
#	-rating_var, the variable with the ratings. If not specified, uses ${page}::data(${widget_name}) 
#	-symbol, default "star"
#	-n_ratings, default 5
#	-use_halfs, default 1
proc ::plugins::DGUI::add_rating { page field_name x_label y_label x_widget y_widget width args } {
	set has_ns [page_name_is_namespace $page]
	
	if { $::debugging } { msg "add_rating $page - $field_name" }
	set widget_name [args_get_option args -widget_name $field_name 1]
	set ratingvar [args_add_option_if_not_exists args -rating_var "${page}::data($widget_name)"]
	set n_ratings [args_get_option args -n_ratings 5 1]		
	set use_halfs [args_get_option args -use_halfs 1 1]
	set symbol [args_get_option args -symbol "star" 1]
				
	if { $use_halfs == 1 } {
		if { [info exists "::plugins::DGUI::symbols(half_$symbol)"] } {
			set half_symbol [subst \$::plugins::DGUI::symbols(half_$symbol)]
		} else {
			set half_symbol $::plugins::DGUI::symbols(half_star)
		}
	}		
	if { [info exists ::plugins::DGUI::symbols($symbol)] } {
		set symbol [subst \$::plugins::DGUI::symbols($symbol)]
	} 
		
	# If the field name is found in the data dictionary, use its metadata unless they are provided in the proc call
	lassign [field_lookup $field_name {name data_type n_decimals min_value max_value}] \
		f_label f_data_type f_n_decimals f_min_value f_max_value 	
	foreach fn {label data_type n_decimals min_value max_value} {
		set $fn [args_get_option args "-$fn" [subst \$f_$fn] 1]
	}
	
	if { $x_label > -1 && $y_label > -1 } { 
		if { $label ne "" } {
			set w [::add_de1_text $page $x_label [expr {$y_label+3}] \
				-font [::plugins::DGUI::get_font $::plugins::DGUI::font $::plugins::DGUI::font_size] \
				-fill $::plugins::DGUI::font_color -anchor "nw" -text [translate $label]]
			if { $has_ns } { set "${page}::widgets(${widget_name}_rating_label)" $w }
		} elseif { [info exists "${page}::data(${widget_name}_rating_label)"]} {
			set w [::add_de1_variable $page $x_label [expr {$y_label+3}] \
				-font [::plugins::DGUI::get_font $::plugins::DGUI::font $::plugins::DGUI::font_size] \
				-fill $::plugins::DGUI::font_color -anchor "nw" -textvariable "\$${page}::data(${widget_name}_label)" ]
			if { $has_ns } { set "${page}::widgets(${widget_name}_label)" $w }
		}
	}
	
	set space [expr {$width / $n_ratings}]	
	for { set i 1 } { $i <= $n_ratings } { incr i } {
		set w [add_de1_text $page [expr {$x_widget+$space/2+$space*($i-1)}] [expr {$y_widget+25}] \
			-font fontawesome_reg_small \
			-fill $::plugins::DGUI::disabled_color -anchor "center" -justify "center" -text $symbol]
		if { $has_ns } { set "${page}::widgets(${widget_name}_rating$i)" $w }
		if { $use_halfs == 1 } {
			set w [add_de1_text $page [expr {$x_widget+$space/2+$space*($i-1)}] [expr {$y_widget+25}] \
				-font fontawesome_reg_small -fill $::plugins::DGUI::disabled_color -anchor "center" -justify "center" \
				-text $half_symbol]
			if { $has_ns } { set "${page}::widgets(${widget_name}_rating_half$i)" $w }
		}		
	}

	set rating_cmd "::plugins::DGUI::rating_clicker $ratingvar $min_value $max_value $n_ratings $use_halfs %x %y %%x0 %%y0 %%x1 %%y1;\
		::plugins::DGUI::draw_rating $page $field_name -n_ratings $n_ratings -use_halfs $use_halfs -min_value $min_value -max_value $max_value -widget_name $widget_name;"
	set widget [::add_de1_button $page $rating_cmd $x_widget [expr {$y_widget-15}] \
		[expr {$x_widget+$width}] [expr {$y_widget+70}] ]
	if { $has_ns } { set "${page}::widgets(${widget_name}_rating_button)" $widget }

	return $widget
}

# Colors each of the symbols of a ratings "widget combo" according to the value of the underlying variable. 
proc ::plugins::DGUI::draw_rating { page field_name args } {
	set has_ns [page_name_is_namespace $page]
	if { ! $has_ns } return
	
	set widget_name [args_get_option args -widget_name $field_name 1]
	
	if { [info exists ${page}::widgets(${widget_name}_rating_button)] } {
		set button_state [.can itemcget [subst \$${page}::widgets(${widget_name}_rating_button)] -state]
		if { $button_state ne "normal" } { return }
	} else { return }
	
	set ratingvar [args_add_option_if_not_exists args -rating_var "${page}::data($widget_name)"]
	set n_ratings [args_get_option args -n_ratings 5 1]		
	set use_halfs [args_get_option args -use_halfs 1 1]
		
	# If the field name is found in the data dictionary, use its metadata unless they are provided in the proc call
	lassign [field_lookup $field_name {name data_type n_decimals min_value max_value}] \
		f_label f_data_type f_n_decimals f_min_value f_max_value 	
	foreach fn {label data_type n_decimals min_value max_value} {
		set $fn [args_get_option args "-$fn" [subst \$f_$fn] 1]
	}

	set varname [args_add_option_if_not_exists args -rating_var "${page}::data($widget_name)"]	
	
	if { $use_halfs == 1 } { set halfs_mult 2 } else { set halfs_mult 1 }  
	if { ($min_value eq "" || $min_value == 0 ) && ($max_value eq "" || $max_value == 0) } {
		set current_val [return_zero_if_blank [subst \$$varname]]
	} else {
		set current_val [expr {int(([return_zero_if_blank [subst \$$varname]] - 1) / \
			(($max_value-$min_value) / ($n_ratings*$halfs_mult))) + 1}]
	}
	
	for { set i 1 } { $i <= $n_ratings } { incr i } {
		set wn [subst \$${page}::widgets(${widget_name}_rating$i)]
		if { $use_halfs == 1 } {
			set wnh [subst \$${page}::widgets(${widget_name}_rating_half$i)]
		}
		if { [expr {$i * $halfs_mult}] <= $current_val } {
			.can itemconfig $wn -fill $::plugins::DGUI::font_color
			if { $use_halfs == 1 } { .can itemconfig $wnh -state hidden } 
		} else {
			if { $use_halfs == 1 } {
				if { [expr {$i * $halfs_mult - 1}] == $current_val } {
					.can itemconfig $wn -fill $::plugins::DGUI::disabled_color
					.can itemconfig $wnh -state normal 
					.can itemconfig $wnh -fill $::plugins::DGUI::font_color
				} else {
					.can itemconfig $wn -fill $::plugins::DGUI::disabled_color
					.can itemconfig $wnh -state hidden 
				}
			} else {
				.can itemconfig $wn -fill $::plugins::DGUI::disabled_color
			}
		}
	}
}

# Taken verbatim from Damian's DSx.
proc ::plugins::DGUI::horizontal_clicker {bigincrement smallincrement varname minval maxval x y x0 y0 x1 y1} {
	set x [translate_coordinates_finger_down_x $x]
	set y [translate_coordinates_finger_down_y $y]
	set xrange [expr {$x1 - $x0}]
	set xoffset [expr {$x - $x0}]
	set midpoint [expr {$x0 + ($xrange / 2)}]
	set onequarterpoint [expr {$x0 + ($xrange / 5)}]
	set threequarterpoint [expr {$x1 - ($xrange / 5)}]
	if {[info exists $varname] != 1} {
		# if the variable doesn't yet exist, initiialize it with a zero value
		set $varname 0
	}
	set currentval [subst \$$varname]
	set newval $currentval
	if {$x < $onequarterpoint} {
		set newval [expr "1.0 * \$$varname - $bigincrement"]
	} elseif {$x < $midpoint} {
		set newval [expr "1.0 * \$$varname - $smallincrement"]
	} elseif {$x < $threequarterpoint} {
		set newval [expr "1.0 * \$$varname + $smallincrement"]
	} else {
		set newval [expr "1.0 * \$$varname + $bigincrement"]
	}
	set newval [round_to_two_digits $newval]

	if {$newval > $maxval} {
		set $varname $maxval
	} elseif {$newval < $minval} {
		set $varname $minval
	} else {
		set $varname [round_to_two_digits $newval]
	}
	update_onscreen_variables
	return
}

# Similar to horizontal_clicker but for arbitrary discrete values like rating stars. 
proc ::plugins::DGUI::rating_clicker { varname minval maxval n_ratings use_halfs inx iny x0 y0 x1 y1 } {
	set x [translate_coordinates_finger_down_x $inx]
	set y [translate_coordinates_finger_down_y $iny]
#
	set xrange [expr {$x1 - $x0}]
	set xoffset [expr {$x - $x0}]
	
	if { $use_halfs == 1 } { set halfs_mult 2 } else { set halfs_mult 1 }
	
	set interval [expr {int($xrange / $n_ratings)}] 
	set clicked_val [expr {(int($xoffset / $interval) + 1) * $halfs_mult}]
	
	if { ($minval eq "" || $minval == 0 ) && ($maxval eq "" || $maxval == 0) } {
		set current_val [return_zero_if_blank [subst \$$varname]]
	} else {
		set current_val [expr {int(([return_zero_if_blank [subst \$$varname]] - 1) / \
			(($maxval-$minval) / ($n_ratings * $halfs_mult))) + 1}]		
#		set current_val [expr {(int([return_zero_if_blank [subst \$$varname]]-1) / (($maxval-$minval)/$n_ratings))+1}]
	}
	
	if { $current_val == $clicked_val && $current_val > 0 } {
		set clicked_val [expr {$clicked_val-1}]
	} elseif { $use_halfs == 1 && $current_val > 0 && $clicked_val == [expr {$current_val+1}] } {
		set clicked_val [expr {$clicked_val-2}]
	}
	
	if { ($minval eq "" || $minval == 0 ) && ($maxval eq "" || $maxval == 0) } {
		set $varname $clicked_val
	} else {
		set $varname [expr {int($minval + (($maxval - $minval) * $clicked_val / ($n_ratings*$halfs_mult))) }]
	}
	
	#set ::DYE::debug_text "$varname=[subst \$$varname]\rcurrent_value=$current_val, clicked_val=$$clicked_val\rnew_val=[subst \$$varname]"	
}


### GENERIC ITEM SELECTION PAGE #######################################################################################

namespace eval ::plugins::DGUI::IS {
	variable widgets
	array set widgets {}
		
	# NOTE that we use "item_values" to hold all available items, not "items" as the listbox widget, as we need
	# to have the full list always stored. So the "items" listbox widget does not have a list_variable but we
	# directly add to it.
	variable data
	array set data {
		page_name "::plugins::DGUI::IS"
		page_painted 0
		previous_page {}
		callback_cmd {}
		page_title {}
		item_variable {} 
		item_type {}
		selectmode {browser}
		filter_string {}
		allow_modify 1
		filter_indexes {}
		item_ids {}
		item_values {}
		modified_value {}
		modified_results {}
		empty_items_msg {}
	}
	
	namespace import ::plugins::DGUI::*
}

# Launches the dialog page to select an item. DON'T SHOW THE DYE_item_select PAGE ANY OTHER WAY!!
# Requires a callback command/procedure to return control to the calling page, it must be a function with three  
# arguments (item_id item_value item_type) that processes the result and moves to the source page (or somewhere else).
# Names extra arguments:
#	-page_title
#	-select_variable
#	-item_type
#	-item_ids
#	-callback_cmd
#	-selected
#	-selectmode
#	-allow_modify 
#	-empty_items_msg

proc ::plugins::DGUI::IS::load_page { item_type item_variable items args } {	
	variable data
	variable widgets
	set ns [namespace current]
	array set opts $args
	
	if { [info exists opts(-page_title)] } {
		set data(page_title) $opts(-page_title)
	} else {
		set item_name [field_lookup $item_type name]
		if { $item_name eq "" } {
			set data(page_title) [translate "Select an item"]
		} else {
			set data(page_title) [translate "Select $item_name"]
		}
	}
	
	# If no selected is given, but item_variable is given and it has a current value, use it as selected.
	set data(item_variable) $item_variable
	set selected [ifexists opts(-selected) ""]
	if { $item_variable ne "" && $selected eq "" && [subst "\$$item_variable"] ne "" } {
		set selected [subst "\$$data(item_variable)"]
	}	
	# Add the current/selected value if not included in the list of available items
	set data(item_ids) [value_or_default opts(-item_ids) ""]
	if { $selected ne "" } {
		if { [lsearch -exact $items $selected] == -1 } {
			if { [llength $data(item_ids)] > 0 } { lappend data(item_ids) -1 }
			lappend items $selected
		}
	}
	set data(item_values) $items
	
	set data(item_type) $item_type
	set data(callback_cmd) [value_or_default opts(-callback_cmd) ""]
	set data(selectmode) [value_or_default opts(-selectmode) "browser"]
#	set data(filter) $filter
	set data(allow_modify) [::plugins::DGUI::value_or_default opts(-allow_modify) 0]	
	set data(empty_items_msg) [value_or_default opts(-empty_items_msg) \
		[translate "There are no available items to show"]]
	set data(filter_string) {}
	set data(filter_indexes) {}
	set data(modified_value) {}
	set data(modified_result) {} 

	# We load the widget items directly instead of mapping it to a listvariable, as it may have either the full
	# list or a filtered one.	
	$widgets(items) delete 0 end
	$widgets(items) insert 0 {*}$items

	set_previous_page $ns
	page_to_show_when_off $ns
	
	if { ![ifexists data(page_painted) 0] } {
		ensure_size "$widgets(items) $widgets(filter_string) $widgets(modified_value)" -width 1775 
		ensure_size $widgets(items) -height 1000
		set_scrollbars_dims $ns "items"
		set data(page_painted) 1
	}

	if { $selected ne "" } {		
		set idx [lsearch -exact $items $selected]
		if { $idx >= 0 } {
			$widgets(items) selection set $idx
			$widgets(items) see $idx
			items_select
		}
	}
}

proc ::plugins::DGUI::IS::show_page {} {
	variable data
	variable widgets
	set ns [namespace current]

	if { [llength $data(item_values)] == 0 } {
		say [translate "no choices"] $::settings(sound_button_out)
		hide_widgets "filter_string* items_label items* modified_value* modified* modify_*" $ns
	}
	
	show_or_hide_widgets [expr [llength $data(item_values)]>0] empty_items_msg $ns	
	enable_or_disable_widgets $data(allow_modify) "modified_value* modify*" $ns 
}

# Setup the "Item select" page User Interface. 
proc ::plugins::DGUI::IS::setup_ui {} {
	variable data
	variable widgets
	set page [namespace current]
	set font_size [expr {$::plugins::DGUI::font_size+1}]
	
	add_page $page -buttons_loc center
	
	# Items search entry box
	set entries_width 75
	add_entry $page "filter_string" 380 150 400 150 $entries_width -label [translate "Filter values"] \
		-font_size $font_size -label_anchor "ne" -label_justify "right" 
	bind $widgets(filter_string) <KeyRelease> ::plugins::DGUI::IS::filter_string_change 
	
	# Empty category message
	add_variable $page 1280 750 {$::plugins::DGUI::IS::data(empty_items_msg)} -widget_name empty_items_msg \
		-font_size $::plugins::DGUI::section_font_size -fill $::plugins::DGUI::remark_color \
		-anchor "center" -justify "center"

	# Items listbox: Don't use $data(items) as listvariable, as the list changes dinamically with the filter string!
	add_listbox $page items 380 230 400 230 $entries_width 16 -font_size $font_size -label [translate "Values"] \
		-label_anchor "ne" -label_justify "right" 
	bind $widgets(items) <<ListboxSelect>> ::plugins::DGUI::IS::items_select
	bind $widgets(items) <Double-Button-1> ::plugins::DGUI::IS::page_done
	
	# Modify selected item entrybox
	add_entry $page "modified_value" 380 1300 400 1300 $entries_width -label [translate "Modify value"] \
		-font_size $font_size -label_anchor "ne" -label_justify "right" 
	bind $widgets(modified_value) <Leave> { hide_android_keyboard
		set ::plugins::DGUI::IS::data(modified_value) [string trim $::plugins::DGUI::IS::data(modified_value)] }
	
	# Modify button
	add_button1 $page modify 2250 1260 "Modify" ::plugins::DGUI::IS::modify_click
	
	# Modify result text
	add_variable $page 2450 1450 {$::plugins::DGUI::IS::data(modified_result)} -anchor "ne" -justify "right" \
		-font_size $::plugins::DGUI::section_font_size -fill $::plugins::DGUI::remark_color
	
	::add_de1_action $page ${page}::show_page
}

proc ::plugins::DGUI::IS::filter_string_change {} {
	variable data
	variable widgets
	
	set items_widget $widgets(items)
	set item_values $data(item_values)
	set filter_string $data(filter_string) 
	set filter_indexes $data(filter_indexes)
	
	if { [string length $filter_string ] < 3 } {
		# Show full list
		if { [llength $item_values] > [$items_widget index end] } {
			$items_widget delete 0 end
			$items_widget insert 0 {*}$item_values
		}
		set filter_indexes {}
	} else {
		set filter_indexes [lsearch -all -nocase $item_values "*$filter_string*"]

		$items_widget delete 0 end
		set i 0
		foreach idx $filter_indexes { 
			$items_widget insert $i [lindex $item_values $idx]
			incr i 
		}
	}
}

proc ::plugins::DGUI::IS::items_select {} {
	variable data
	variable widgets
	set widget $widgets(items)
	
	if { $data(allow_modify) == 1 } {
		if { [$widget curselection] eq "" } {
			set data(modified_value) {}
		} else {
			set data(modified_value) [$widget get [$widget curselection]]
		}
	}	
}

proc ::plugins::DGUI::IS::modify_click {} {
	variable data
	variable widgets
	if { $data(allow_modify) != 1 } return

#	TODO: Implement a parametrized command from the invoking code!
#	say [translate {modify}] $::settings(sound_button_in)
#	set items_widget $widgets(items)
#	set sel_idx [$items_widget curselection]
#	if { $sel_idx ne "" } {
#		set old_value [$items_widget get $sel_idx]
#		if { $old_value ne $data(modified_value) && $data(modified_value) ne "" } {
#			set data(modified_result) [translate "Modifying data..."]
#			::update_onscreen_variables
#			borg toast [translate "Modifying data..."] 1
#			borg spinner on
#			update 
#			
#			set modified_shots [::DYE::DB::update_category $data(item_type) $old_value $data(modified_value)]
#			
#			if { [llength $modified_shots] > 0 } {
#				$items_widget delete $sel_idx $sel_idx
#				$items_widget insert $sel_idx $data(modified_value)
#				$items_widget selection set $sel_idx
#				
#				if { [llength $modified_shots] == 1 } {
#					set data(modified_result) "[llength $modified_shots] [translate {shot file modified}]"
#				} else {
#					set data(modified_result) "[llength $modified_shots] [translate {shot files modified}]"
#				}
#			} else {
#				set data(modified_result) [translate "No files modified"]
#			}
#			borg spinner off
#			borg systemui $::android_full_screen_flags
#		}
#	}
}
	
proc ::plugins::DGUI::IS::page_cancel {} {
	variable data
	say [translate {cancel}] $::settings(sound_button_in)

	if { $data(callback_cmd) ne "" } {
		$data(callback_cmd) {} {} $data(item_type)
	} else {
		page_to_show_when_off $data(previous_page)
	}
}
	
proc ::plugins::DGUI::IS::page_done {} {
	variable data
	variable widgets
	say [translate {done}] $::settings(sound_button_in)
	
	set items_widget $widgets(items)
	set item_value {}
	set item_id {}
	
	# TODO: Return a list if selectmode=multiple/extended
	if {[$items_widget curselection] ne ""} {
		set sel_idx [$items_widget curselection]
		set item_value [$items_widget get $sel_idx]
					
		if { [llength $data(item_ids)] == 0 } {
			set item_id $item_value
		} else {
			if { [llength $data(filter_indexes)] > 0 } {
				set new_sel_idx [lindex $data(filter_indexes) $sel_idx]
				set sel_idx $new_sel_idx
			}
			set item_id [lindex $data(item_ids) $sel_idx]
		}
	}

	
	if { $data(callback_cmd) ne "" } {
		$data(callback_cmd) $item_id $item_value $data(item_type)
	} else {
		if { $data(item_variable) ne "" } {
			set $data(item_variable) $item_value
		}
		page_to_show_when_off $data(previous_page)
	}
}

### GENERIC NUMERIC ENTRIES EDITION PAGE ##############################################################################

namespace eval ::plugins::DGUI::NUME {
	variable widgets
	array set widgets {}
		
	variable data
	array set data {
		page_name "::plugins::DGUI::NUME"
		previous_page {}
		callback_cmd {}
		page_title {}
		#show_previous_values 1		
		field_name {}
		num_variable {}
		value {}
		min_value {}
		max_value {}
		n_decimals {}
		default_value {}
		small_increment {}
		big_increment {}
		previous_values {}
		value_format {}
	}
	
	namespace import ::plugins::DGUI::*
}

# Accepts any of the named options -page_title, -min_value, -max_value, -n_decimals, -default_value, 
# -small_increment and -big_increment. If not specified, they are taken from the data dictionary entry for 'field_name'.
proc ::plugins::DGUI::NUME::load_page { field_name { num_variable {}} args } {
	variable data
	variable widgets
	array set opts $args
	set ns [namespace current]
		
	foreach fn [array names data] {
		if { $fn ne "page_name" } { set data($fn) {} }
	}
	
	# If the field name is found in the data dictionary, use its metadata unless they are provided in the proc call	
	set opt_names "n_decimals min_value max_value default_value small_increment big_increment"
	lassign [field_lookup $field_name "name data_type $opt_names"] f_name f_data_type f_n_decimals \
		f_min_value f_max_value f_default_value f_small_increment f_big_increment
	foreach fn $opt_names {
		set data($fn) [value_or_default opts(-$fn) [subst \$f_$fn]] 
	}
	
	if { $field_name ne "" && $f_data_type ne "numeric" } {
		msg "WARNING: field '$field_name' is not numeric, cannot load page ::plugins::DGUI::NUME"
		return
	}

	set data(field_name) $field_name
	if { [info exists opts(-callback_cmd)] } {
		set data(callback_cmd) $opts(-callback_cmd)
	}	
	set data(previous_values) [value_or_default opts(-previous_values) {}]
	set data(num_variable) $num_variable
	#if { $data(value) eq "" && $data(default_value) ne "" } { set data(value) $data(default_value) }
	if { $data(small_increment) eq "" } { set data(small_increment) 1.0 }
	if { $data(big_increment) eq "" } { set data(big_increment) 10.0 }
	
	if { [info exists opts(-page_title)] } {
		set data(page_title) $page_title
	} elseif { $f_name ne "" } {
		set data(page_title) [translate "Edit $f_name"]
	} else {
		set data(page_title) [translate "Edit number"]
	}

	set_previous_page $ns
	page_to_show_when_off $ns	
	set_scrollbars_dims $ns "previous_values"

	enable_or_disable_widgets [expr $data(n_decimals)>0] "num_dot*" $ns
	enable_or_disable_widgets [expr [llength $data(previous_values)]>0] "previous_values*" $ns

	if { $num_variable ne "" && [subst \$$num_variable] ne "" } {
		# Without the delay, the value is not selected. Tcl misteries...
		after 10 ::plugins::DGUI::NUME::set_value [subst \$$num_variable]
	}	
}

proc ::plugins::DGUI::NUME::setup_ui {} {
	variable data
	variable widgets
	set page [namespace current]	
	set incs_font_size 6
	
	add_page $page -buttons_loc center
	
	# Value being edited
	# Helv_16 is not defined in Insight, so until I solve this font issue in a generic way, I have to hardcode the 
	#	2 skin cases
	if { $::settings(skin) eq "DSx" } { set text_font [::DSx_font font 16] } else { set text_font Helv_16_bold } 
	set x_left_center 550; set y 275
	add_entry $page $data(field_name) -1 -1 $x_left_center $y 5 -font $text_font \
		-widget_name value -data_type numeric -textvariable ::plugins::DGUI::NUME::data(value) 
	
	# Erase button
	add_symbol $page $x_left_center [expr {$y+140}] eraser -size medium -has_button 1 \
		-button_cmd { set ::plugins::DGUI::NUME::data(value) "" }
	
	# Increment/Decrement value arrows 
	incr y 45; set y_symbol_offset 5; set y_label_offset 90
	add_symbol $page [expr {$x_left_center-100}] [expr {$y+$y_symbol_offset}] chevron_left \
		-size medium -anchor center \
		-has_button 1 -button_cmd { ::plugins::DGUI::NUME::incr_value [expr -$::plugins::DGUI::NUME::data(small_increment)] }
	add_variable $page [expr {$x_left_center-100}] [expr {$y+$y_label_offset}] \
		{-[format [::plugins::DGUI::NUME::value_format] $::plugins::DGUI::NUME::data(small_increment)]} \
		-anchor center -font_size $incs_font_size
	
	add_symbol $page [expr {$x_left_center-260}] [expr {$y+$y_symbol_offset}] chevron_double_left \
		-size medium -anchor center \
		-has_button 1 -button_cmd { ::plugins::DGUI::NUME::incr_value [expr -$::plugins::DGUI::NUME::data(big_increment)] }
	add_variable $page [expr {$x_left_center-260}] [expr {$y+$y_label_offset}] \
		{-[format [::plugins::DGUI::NUME::value_format] $::plugins::DGUI::NUME::data(big_increment)]} \
		-anchor center -font_size $incs_font_size

	add_symbol $page [expr {$x_left_center-400}] [expr {$y+$y_symbol_offset}] arrow_to_left \
		-size medium -anchor center \
		-has_button 1 -button_cmd { ::plugins::DGUI::NUME::set_value $::plugins::DGUI::NUME::data(min_value) }
	add_variable $page [expr {$x_left_center-400}] [expr {$y+$y_label_offset}] \
		{[format [::plugins::DGUI::NUME::value_format] $::plugins::DGUI::NUME::data(min_value)]} \
		-anchor center -font_size $incs_font_size
	
	add_symbol $page [expr {$x_left_center+360}] [expr {$y+$y_symbol_offset}] chevron_right \
		-size medium -anchor center \
		-has_button 1 -button_cmd { ::plugins::DGUI::NUME::incr_value $::plugins::DGUI::NUME::data(small_increment) }
	add_variable $page [expr {$x_left_center+360}] [expr {$y+$y_label_offset}] \
		{+[format [::plugins::DGUI::NUME::value_format] $::plugins::DGUI::NUME::data(small_increment)]} \
		-anchor center -font_size $incs_font_size
	
	add_symbol $page [expr {$x_left_center+510}] [expr {$y+$y_symbol_offset}] chevron_double_right \
		-size medium -anchor center \
		-has_button 1 -button_cmd { ::plugins::DGUI::NUME::incr_value $::plugins::DGUI::NUME::data(big_increment) }
	add_variable $page [expr {$x_left_center+510}] [expr {$y+$y_label_offset}] \
		{+[format [::plugins::DGUI::NUME::value_format] $::plugins::DGUI::NUME::data(big_increment)]} \
		-anchor center -font_size $incs_font_size

	add_symbol $page [expr {$x_left_center+670}] [expr {$y+$y_symbol_offset}] arrow_to_right \
		-size medium -anchor center \
		-has_button 1 -button_cmd { ::plugins::DGUI::NUME::set_value $::plugins::DGUI::NUME::data(max_value) }
	add_variable $page [expr {$x_left_center+670}] [expr {$y+$y_label_offset}] \
		{[format "%.$::plugins::DGUI::NUME::data(n_decimals)f" $::plugins::DGUI::NUME::data(max_value)]} \
		-anchor center -font_size $incs_font_size

	# Previous values listbox
	add_listbox $page previous_values 450 600 450 680 16 9 -label [translate "Previous values"] \
		-font_size $::plugins::DGUI::section_font_size 
	bind $widgets(previous_values) <<ListboxSelect>> ::plugins::DGUI::NUME::previous_values_select
	
	# Numeric type pad
	set x_base 1450; set y_base 225
	set width 280; set height 220; set space 70
	set numpad_font_size 12
	
	set x [expr {$x_base+0*($width+$space)}]
	set y [expr {$y_base+0*($height+$space)}]
	add_button $page num7 $x $y [expr {$x+$width}] [expr {$y+$height}] "7" \
		{::plugins::DGUI::NUME::enter_character 7} -label_font_size $numpad_font_size
	
	set x [expr {$x_base+1*($width+$space)}]
	set y [expr {$y_base+0*($height+$space)}]
	::plugins::DGUI::add_button $page num8 $x $y [expr {$x+$width}] [expr {$y+$height}] "8" \
		{::plugins::DGUI::NUME::enter_character 8} -label_font_size $numpad_font_size

	set x [expr {$x_base+2*($width+$space)}]
	set y [expr {$y_base+0*($height+$space)}]
	add_button $page num9 $x $y [expr {$x+$width}] [expr {$y+$height}] "9" \
		{::plugins::DGUI::NUME::enter_character 9} -label_font_size $numpad_font_size

	set x [expr {$x_base+0*($width+$space)}]
	set y [expr {$y_base+1*($height+$space)}]
	add_button $page num4 $x $y [expr {$x+$width}] [expr {$y+$height}] "4" \
		{::plugins::DGUI::NUME::enter_character 4} -label_font_size $numpad_font_size

	set x [expr {$x_base+1*($width+$space)}]
	set y [expr {$y_base+1*($height+$space)}]
	add_button $page num5 $x $y [expr {$x+$width}] [expr {$y+$height}] "5" \
		{::plugins::DGUI::NUME::enter_character 5} -label_font_size $numpad_font_size

	set x [expr {$x_base+2*($width+$space)}]
	set y [expr {$y_base+1*($height+$space)}]
	add_button $page num6 $x $y [expr {$x+$width}] [expr {$y+$height}] "6" \
		{::plugins::DGUI::NUME::enter_character 6} -label_font_size $numpad_font_size

	set x [expr {$x_base+0*($width+$space)}]
	set y [expr {$y_base+2*($height+$space)}]
	add_button $page num1 $x $y [expr {$x+$width}] [expr {$y+$height}] "1" \
		{::plugins::DGUI::NUME::enter_character 1} -label_font_size $numpad_font_size

	set x [expr {$x_base+1*($width+$space)}]
	set y [expr {$y_base+2*($height+$space)}]
	add_button $page num2 $x $y [expr {$x+$width}] [expr {$y+$height}] "2" \
		{::plugins::DGUI::NUME::enter_character 2} -label_font_size $numpad_font_size

	set x [expr {$x_base+2*($width+$space)}]
	set y [expr {$y_base+2*($height+$space)}]
	add_button $page num3 $x $y [expr {$x+$width}] [expr {$y+$height}] "3" \
		{::plugins::DGUI::NUME::enter_character 3} -label_font_size $numpad_font_size

	set x [expr {$x_base+0*($width+$space)}]
	set y [expr {$y_base+3*($height+$space)}]
	add_button $page num_del $x $y [expr {$x+$width}] [expr {$y+$height}] "Del" \
		{::plugins::DGUI::NUME::enter_character DEL} -label_font_size $numpad_font_size

	set x [expr {$x_base+1*($width+$space)}]
	set y [expr {$y_base+3*($height+$space)}]
	add_button $page num0 $x $y [expr {$x+$width}] [expr {$y+$height}] "0" \
		{::plugins::DGUI::NUME::enter_character 0} -label_font_size $numpad_font_size

	set x [expr {$x_base+2*($width+$space)}]
	set y [expr {$y_base+3*($height+$space)}]
	add_button $page num_dot $x $y [expr {$x+$width}] [expr {$y+$height}] "." \
		{::plugins::DGUI::NUME::enter_character .} -label_font_size $numpad_font_size
	
}

proc ::plugins::DGUI::NUME::value_format {} {
	variable data
	return "%.$data(n_decimals)f"
}

proc ::plugins::DGUI::NUME::set_value { new_value } {
	variable data
	if { $new_value ne "" } {
		if { $new_value != 0 } { set new_value [string trimleft $new_value 0] } 
		set new_value [format [value_format] $new_value]
	}
	set data(value) $new_value
	value_change
	select_value
}

proc ::plugins::DGUI::NUME::select_value {} {
	variable widgets
	focus $widgets(value)
	$widgets(value) selection range 0 end 
}

proc ::plugins::DGUI::NUME::value_change {} {
	variable data
	variable widgets
	
	set widget $widgets(value)
	if { $data(value) ne "" } {
		if { $data(min_value) ne "" && $data(value) < $data(min_value) } {
			$widget configure -foreground $::plugins::DGUI::error_color
		} elseif { $data(max_value) ne "" && $data(value) > $data(max_value) } {
			$widget configure -foreground $::plugins::DGUI::error_color
		} else {
			$widget configure -foreground $::plugins::DGUI::font_color
		}
	}
}

proc ::plugins::DGUI::NUME::enter_character { char } {
	variable data
	variable widgets
	
	set widget $widgets(value)

	set max_len [string length [expr round($data(max_value))]]
	if { $data(n_decimals) > 0 } { incr max_len [expr {$data(n_decimals)+1}] }

	set idx -1
	catch { set idx [$widget index sel.first] }
	#[selection own] eq $widget
	if { $idx > -1 } {
		set idx_last [$widget index sel.last]
		if { $char eq "DEL" } {
			set data(value) "[string range $data(value) 0 [expr {$idx-1}]][string range $data(value) $idx_last end]"
		} else {
			set data(value) "[string range $data(value) 0 [expr {$idx-1}]]$char[string range $data(value) $idx_last end]"
		}
		selection own $widget
		$widget selection clear
		$widget icursor [expr {$idx+1}]
	} else {	
		set idx [$widget index insert]
		if { $char eq "DEL" } {
			set data(value) "[string range $data(value) 0 [expr {$idx-2}]][string range $data(value) $idx end]"
			if { $idx > 0 } { $widget icursor [expr {$idx-1}] }
		} elseif { [string length $data(value)] < $max_len } {
			$widget insert $idx $char
		}
	}
	
	set data(value) [string trimleft $data(value) 0]
	value_change
}

proc ::plugins::DGUI::NUME::incr_value { incr } {
	variable data	
	
	if { $data(value) eq "" } {
		if { $data(default_value) ne "" } {
			set value $data(default_value)
		} elseif { $data(min_value) ne "" && $data(max_value) ne "" } {
			set value [expr {($data(max_value)-$data(min_value))/2}]
		} else {
			set value 0
		}
	} else {
		set value $data(value)
	}

	set new_value [expr {$value + $incr}]
	if { $data(min_value) ne "" && $new_value < $data(min_value) } {
		set new_value $data(min_value)
	} 
	if { $data(max_value) ne "" && $new_value > $data(max_value) } {
		set new_value $data(max_value)
	}
	
	set new_value [format [value_format] $new_value]
	if { $new_value != $data(value) } {
		set_value $new_value
	}
}

proc ::plugins::DGUI::NUME::previous_values_select {} {
	variable widgets
	set new_value [listbox_get_selection $widgets(previous_values)]
	if { $new_value ne "" } { set_value $new_value }
}

proc ::plugins::DGUI::NUME::page_cancel {} {
	variable data
	if { $data(callback_cmd) ne "" } {
		$data(callback_cmd) {}
	} else {
		page_to_show_when_off $data(previous_page)
	}
}

proc ::plugins::DGUI::NUME::page_done {} {
	variable data
	set fmt [value_format]
	
	if { $data(value) ne "" } {
		if { $data(value) < $data(min_value) } {
			set data(value) [format $fmt $data(min_value)]
		} elseif { $data(value) > $data(max_value) } {
			set data(value) [format $fmt $data(max_value)]
		} else {
			if { $data(value) > 0 } { set data(value) [string trimleft $data(value) 0] }
			set data(value) [format $fmt $data(value)]
		}
	}
	
	if { $data(callback_cmd) ne "" } {
		$data(callback_cmd) $data(value)
	} else {		
		set $data(num_variable) $data(value)
		page_to_show_when_off $data(previous_page)
	}
}

### GENERIC TEXT ENTRIES EDITION PAGE ##############################################################################

namespace eval ::plugins::DGUI::TXT {
	variable widgets
	array set widgets {}
		
	variable data
	array set data {
		page_name "::plugins::DGUI::TXT"
		page_painted 0
		previous_page {}
		callback_cmd {}
		read_only 0
		page_title {}
		field_name {}
		text_variable {}
		value {}
	}
	
	namespace import ::plugins::DGUI::*
}

proc ::plugins::DGUI::TXT::load_page { field_name { text_variable {} } {read_only 0} args } {
	variable data
	variable widgets
	array set opts $args
	
	foreach fn [array names data] {
		if { $fn ne "page_name" && $fn ne "page_painted" } { set data($fn) {} }
	}
	
	# If the field name is found in the data dictionary, use its metadata unless they are provided in the proc call
	lassign [field_lookup $field_name "name data_type"] name data_type
	
	set data(field_name) $field_name
	if { [info exists opts(-callback_cmd)] } {
		set data(callback_cmd) $opts(-callback_cmd)
	}
	set data(text_variable) $text_variable
	
	if { [info exists opts(-page_title)] } {
		set data(page_title) $opts(-page_title)
	} elseif { $name ne "" } {
		if { $read_only == 1 } {
			set data(page_title) [translate $name]
		} else {
			set data(page_title) [translate "Edit $name"]
		}
	} else {
		if { $read_only == 1 } {
			set data(page_title) $field_name
		} else {
			set data(page_title) [translate "Edit $name"]
		}
	}
	
	set ns [namespace current]
	set_previous_page $ns
	page_to_show_when_off $ns	

	if { ![ifexists data(page_painted) 0] } {
		ensure_size $widgets(value) -width 2300 -height 1100
		#	set_scrollbars_dims $ns "value"
		set data(page_painted) 1
	}

	if { $text_variable ne "" && [subst \$$text_variable] ne "" } {
		set data(value) [subst \$$text_variable]
	}
	
	enable_or_disable_widgets [expr {!$read_only}] "value*" $ns
}

proc ::plugins::DGUI::TXT::setup_ui {} {
	variable data
	variable widgets
	set page [namespace current]
	
	add_page $page -buttons_loc center
	
	# Value being edited
	set x_left_center 550; set y 275
	add_multiline_entry $page $data(field_name) -1 -1 100 200 115 24 \
		-textvariable ::plugins::DGUI::TXT::data(value) -widget_name value -editor_page 0
	
	# Erase button
	add_symbol $page 100 900 eraser -size medium -has_button 1 \
		-button_cmd { set ::plugins::DGUI::TXT::data(value) "" }
}

proc ::plugins::DGUI::TXT::page_cancel {} {
	variable data
	if { $data(callback_cmd) ne "" } {
		$data(callback_cmd) {}
	} else {
		page_to_show_when_off $data(previous_page)
	}
}

proc ::plugins::DGUI::TXT::page_done {} {
	variable data
	
	if { $data(value) ne "" } {
		set data(value) [string trim $data(value)]
	}
	
	if { $data(callback_cmd) ne "" } {
		$data(callback_cmd) $data(value)
	} else {
		if { $data(read_only) != 1 } {
			set $data(text_variable) $data(value)
		}
		page_to_show_when_off $data(previous_page)
	}
}

