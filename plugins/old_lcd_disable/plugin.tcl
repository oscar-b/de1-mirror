package require de1_bluetooth 1.1

set plugin_name "old_lcd_disable"

namespace eval ::plugins::${plugin_name} {
    variable author "Brian K"
    variable contact "Via Diaspora"
    variable version 1.0
    variable name "Old Scale LCD Behavior"
    variable description "Restores old scale LCD disabling behavior"

    proc main {} {
        # Old scale lcd behavior
        proc ::scale_disable_lcd {} {
            msg "Scale Disable LCD has been overwritten"
            
            ::bt::msg -NOTICE scale_disable_lcd
            if {$::settings(scale_type) == "atomaxskale"} {
                skale_disable_lcd
            } elseif {$::settings(scale_type) == "decentscale"} {
                decentscale_disable_lcd
                after 500 decentscale_disable_lcd
            }
        }
    }
}