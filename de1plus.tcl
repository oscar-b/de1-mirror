#!/usr/local/bin/tclsh

encoding system utf-8
cd "[file dirname [info script]]/"
source "pkgIndex.tcl"
package ifneeded de1app 1.32 {}
package provide de1plus 1.0
package require de1_main
de1_ui_startup

