#######################################################################################################################
### A Decent DE1 app plugin to keep a synchronized SQLite database of shots and manage shots history.
###
### https://github.com/ebengoechea/de1app_plugin_SDB
### This code is released under GPLv3 license. 
#######################################################################################################################
package require sqlite3

set plugin_name "SDB"

source "[plugin_directory]/${plugin_name}/${plugin_name}.tcl"