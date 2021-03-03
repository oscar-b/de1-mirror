#######################################################################################################################
### A Decent DE1 app plugin to keep a synchronized SQLite database of shots and manage shots history.
#######################################################################################################################

namespace eval ::plugins::SDB {
	variable author "Enrique Bengoechea"
	variable contact "enri.bengoechea@gmail.com"
	variable version 1.02
	variable github_repo ebengoechea/de1app_plugin_SDB
	variable name [translate "Shot DataBase"]
	variable description [translate "Keeps your shot history in a SQLite database, and provides functions to manage shot history files."]

	variable db {}
	variable updating_db 0
	variable db_version 4
	variable sqlite_version {}
	
	variable min_de1app_version {1.34}
	variable filename_clock_format "%Y%m%dT%H%M%S"
	variable friendly_clock_format "%Y/%m/%d %H:%M"
	
	variable progress_msg {}
	
	namespace export string2sql strings2sql get_shot_file_path load_shot modify_shot_file \
		get_db db_close persist_shot update_shot_description \
		available_categories shots_using_category update_category previous_values \
		has_shot_series_data
}

proc ::plugins::SDB::main {} {	
	variable settings
	package require sqlite3
	
	msg "Starting the 'Shots DataBase' plugin"
	if { ![info exists ::debugging] } { set ::debugging 0 }
	
	if { [plugins available DGUI] } {
		plugins load DGUI
	} else {
		error [translate "Can't load SDB plugin because required plugin DGUI is not available"]
	}
	
	set is_created [create]	
	trace add execution app_exit {enter} { ::plugins::SDB::db_close }
	
	if { $is_created || $settings(sync_on_startup) } {
		populate
	}

	# Ensure the last shot is persisted to the database whenever it is saved to history.
	# We don't use 'register_state_change_handler' as that would not update the shot file if its metadata is 
	#	changed in the Godshots page in Insight or DSx (though currently that does not work)
	#register_state_change_handler Espresso Idle ::plugins::SDB::save_espresso_to_history_hook
	if { [plugins enabled visualizer_upload] } {
		plugins load visualizer_upload
		trace add execution ::plugins::visualizer_upload::uploadShotData leave ::plugins::SDB::save_espresso_to_history_hook
	} else {
		trace add execution ::save_this_espresso_to_history leave ::plugins::SDB::save_espresso_to_history_hook
	}
}

# Paint settings screen
proc ::plugins::SDB::preload {} {
	variable data

	check_settings
	plugins save_settings SDB

	if { [plugins available DGUI] } {
		plugins preload DGUI
		::plugins::DGUI::set_symbols db "\uf1c0" sync "\uf021"
		::plugins::SDB::CFG::setup_ui
		return "::plugins::SDB::CFG"
	} else {
		return ""
	}
}

proc ::plugins::SDB::check_settings {} {
	variable settings

	set settings(version) $::plugins::SDB::version
	set settings(db_version) $::plugins::SDB::db_version
	
	if {[info exists settings(db_path)] == 0 } {
		set settings(db_path) "[plugin_directory]/SDB/shots.db" 
	} elseif { ! [file exists "[homedir]/$settings(db_path)"] } {
		set settings(db_path) "[plugin_directory]/SDB/shots.db"
	}
	
	ifexists settings(backup_modified_shot_files) 0	
	ifexists settings(db_persist_desc) 1	
	ifexists settings(db_persist_series) 0
	ifexists settings(sync_on_startup) 1
	ifexists settings(log_sql_statements) 0
	ifexists settings(github_latest_url) "https://api.github.com/repos/ebengoechea/de1app_plugin_SDB/releases/latest"
	
	if { ![info exists settings(last_sync_clock)] } {
		set settings(last_sync_clock) 0
		foreach fn "analyzed inserted modified archived unarchived removed unremoved" {
			set settings(last_sync_$fn) 0
		}
	}
}

proc ::plugins::SDB::msg { {flag ""} args } {
	if { [string range $flag 0 0] eq "-" && [llength $args] > 0 } {
		::logging::default_logger $flag "::plugins::SDB" {*}$args
	} else {
		::logging::default_logger "::plugins::SDB" $flag {*}$args
	}
}

# Logs SQL statements
proc ::plugins::SDB::log_sql { sql } {
	variable settings
	if { $settings(log_sql_statements) } {
		msg "SQL $sql"
	}
}

# Embed text string in single quotes and escape any SQL character that may produce problems: duplicate single quotes.
# If text is a list, escapes and embeds each one in single quotes, and concatenates by , to be used in an "IN" sql
# statement.
proc ::plugins::SDB::strings2sql { text } {
	set result [regsub -all {'} $text {''}]
	set result [lmap a $result {
		if {[string is integer -strict $a]} { set a } else { subst {'$a'} } }]	 
	return [join $result ","]
} 

# Escapes a string to be used within SQL
proc ::plugins::SDB::string2sql { text } {
	#return "'[regsub -all {'} $text {''}]'"
	return "'[string map {' ''} $text]'"
} 

# Builds a full path to a shot file and returns the path if the file exists, otherwise an empty string.
# If the filename happens to be an integer number, it is assumed it's a clock rather than a filename, and it is
#	transformed to a shot filename.
# If the filename does not have ".shot" extension, adds it.
# If the filename is already a full path and the file exists, returns it. If it's just the filename, checks
# 	existence of file first in history folder, then in history_archive folder.
proc ::plugins::SDB::get_shot_file_path { filename } {
	variable filename_clock_format
	
	if { $filename eq "" } {
		msg "WARNING empty filename argument in get_shot_file_path" 
		return
	}
	if { [string is integer $filename] } {
		set filename "[clock format $filename -format $filename_clock_format].shot"
	} elseif { [string range $filename end-4 end] ne ".shot" } { append filename ".shot" }
	
	if { [file dirname $filename] eq "." } {
		if { [file exists "[homedir]/history/$filename"] } {
			return "[homedir]/history/$filename"
		} elseif { [file exists "[homedir]/history_archive/$filename"] } {
			return "[homedir]/history_archive/$filename"
		}
	} elseif { [file exists $filename] } {
		return $filename
	} 
	
	return ""
}

# Loads from a shot file the data we use in the DYE plugin. Returns an array.
# Input can be a filename, with or without .shot extension, a clock value, or a full path to a shot file.
proc ::plugins::SDB::load_shot { filename } {
	set path [get_shot_file_path $filename]
	if { $path eq "" } return
	
	msg "Loading shot file $path"
	array set shot_data {}
	array set file_props  [encoding convertfrom utf-8 [read_binary_file $path]]
	
	if { [file tail [file dirname $path]] eq "history_archive" } {
		set shot_data(comes_from_archive) 1
	} else {
		set shot_data(comes_from_archive) 0
	}

	set shot_data(path) $path
	set shot_data(filename) [file rootname [file tail $path]]
	set shot_data(file_modification_date) [file mtime $path]
	set shot_data(clock) $file_props(clock)
	set shot_data(date_time) [clock format $file_props(clock) -format {%a, %d %b %Y   %I:%M%p}]
	
	if {[llength [ifexists file_props(espresso_elapsed)]] > 0} {
		set shot_data(espresso_elapsed) $file_props(espresso_elapsed)
		set shot_data(extraction_time) [round_to_one_digits [expr ([lindex $file_props(espresso_elapsed) end]+0.05)]]
	} else {
		set shot_data(espresso_elapsed) {0.0}
		set shot_data(extraction_time) 0.0
	}
	
	foreach field_name {espresso_pressure espresso_weight espresso_flow espresso_flow_weight \
			espresso_temperature_basket espresso_temperature_mix espresso_flow_weight_raw espresso_water_dispensed \
			espresso_temperature_goal espresso_pressure_goal espresso_flow_goal espresso_state_change } {
		if { [info exists file_props($field_name)] } {
			set shot_data($field_name) $file_props($field_name)
		} else {
			set shot_data($field_name) {0.0}
		}
	}
	
	array set file_sets $file_props(settings)
	
	set text_fields [::plugins::DGUI::field_names "category text long_text date" "shot"]
	lappend text_fields profile_title skin beverage_type
	foreach field_name $text_fields {
		if { [info exists file_sets($field_name)] == 1 } {
			set shot_data($field_name) [string trim $file_sets($field_name)]
		} else {
			set shot_data($field_name) {}
		}
	}
	
	foreach field_name [::plugins::DGUI::field_names "numeric" "shot"] {
		if { [info exists file_sets($field_name)] == 1 && $file_sets($field_name) > 0 } {
			set shot_data($field_name) $file_sets($field_name)
		} else {
			# We use {} instead of 0 to get DB NULLs and empty values in entry textboxes
			set shot_data($field_name) {}
		}
	}

	if { $shot_data(grinder_dose_weight) eq "" } {
		if {[info exists file_sets(DSx_bean_weight)] == 1} {
			set shot_data(grinder_dose_weight) $file_sets(DSx_bean_weight)
		} elseif {[info exists file_sets(dsv4_bean_weight)] == 1} {
			set shot_data(grinder_dose_weight) $file_sets(dsv4_bean_weight)
		} elseif {[info exists file_sets(dsv3_bean_weight)] == 1} {
			set shot_data(grinder_dose_weight) $file_sets(dsv3_bean_weight)
		} elseif {[info exists file_sets(dsv2_bean_weight)] == 1} {
			set shot_data(grinder_dose_weight) $file_sets(dsv2_bean_weight)
		}
	}
	
	return [array get shot_data]
}

# Reads a shot file, modifies the settings that are defined in arr_new_settings, and optionally backups the old file 
# 	before modifying and updates the file in disk. Returns the string with the text that is/would be written to disk.
# This is normally called with write_file=1, but can be invoked with write_file=0 only to use the return string,
# 	for example for Visualizer uploads.
# Multivalued settings such as parts of "other_equipment" are flagged with a "~" initial character and are handled differently:  
#	~equipment_X (X=type/name/setting): a 2-items list with the old and new equipment value to replace in the 'other_equipment' list.
		
proc ::plugins::SDB::modify_shot_file { path arr_new_settings { backup_file {} } { write_file 1 } } {
	variable settings
	upvar $arr_new_settings new_settings
	
	if { $backup_file eq {} } {
		set backup_file $settings(backup_modified_shot_files)
	}
msg "modify_shot_file, path=$path"	
	set path [get_shot_file_path $path]
	
	array set past_props [encoding convertfrom utf-8 [read_binary_file $path]] 
	array set past_sets $past_props(settings)
	array set past_mach $past_props(machine)

	foreach key [array names new_settings] {
		if { [string range $key 0 0] eq "~" } {
			if { $key eq "~equipment_type" } {
				if { [llength $new_settings($key)] == 2 && [info exists past_sets(other_equipment)] } {
					#set old_value $past_sets(other_equipment)
					set new_settings(other_equipment) [modify_other_equipment $past_sets(other_equipment) [string range $key 1 9999] \
						[lindex $new_settings($key) 0] [lindex $new_settings($key) 1]]  
					set key other_equipment
				} else {
					msg "new_settings($key)='$new_settings($key)' malformed or other_equipment doesn't exist, when modifying shot file '[file tail $path]'"
					continue
				}
			} elseif { $key eq "~equipment_name" } { 
				if { [llength $new_settings($key)] == 3 && [info exists past_sets(other_equipment)] } {
					#set old_value $past_sets(other_equipment)
					set new_settings(other_equipment) [modify_other_equipment $past_sets(other_equipment) [string range $key 1 9999] \
						[lindex $new_settings($key) 0] [lindex $new_settings($key) 1] [lindex $new_settings($key) 2]]  
					set key other_equipment
				} else {
					msg "new_settings($key)='$new_settings($key)' malformed or other_equipment doesn't exist, when modifying shot file '[file tail $path]'"
					continue
				}
			} elseif { $key eq "~equipment_setting" } { 
				if { [llength $new_settings($key)] == 4 && [info exists past_sets(other_equipment)] } {
					#set old_value $past_sets(other_equipment)
					set new_settings(other_equipment) [modify_other_equipment $past_sets(other_equipment) [string range $key 1 9999] \
						[lindex $new_settings($key) 0] [lindex $new_settings($key) 1] [lindex $new_settings($key) 2] [lindex $new_settings($key) 3]]  
					set key other_equipment
				} else {
					msg "new_settings($key)='$new_settings($key)' malformed or other_equipment doesn't exist, when modifying shot file '[file tail $path]'"
					continue
				}								
			} else {
				msg "key $key in new_settings not recognized when modifying shot file '[file tail $path]'"
				continue 
			}
			
			if { [info exists past_sets($key)] } {
				msg "Modified $key from '$past_sets($key)' to '$new_settings($key)' in shot file '[file tail $path]'"
			} else {
				msg "Added new $key='$new_settings($key)' in shot file '[file tail $path]'"
			}			
		} elseif { [info exists past_sets($key)] } {			
			#set old_value $past_sets($key)
			msg "Modified $key from '$past_sets($key)' to '$new_settings($key)' in shot file '[file tail $path]'"
		} else {
			#set old_value {}
			msg "Added new $key='$new_settings($key)' in shot file '[file tail $path]'"
		}
		
		set past_sets($key) $new_settings($key)
	}
	
	set espresso_data {}

	# Sort the variables in the first part of the file exactly as in the original. 
	set default_pars {clock espresso_elapsed espresso_pressure espresso_weight espresso_flow espresso_flow_weight \
		espresso_flow_weight_raw espresso_temperature_basket espresso_temperature_mix espresso_water_dispensed \
		espresso_pressure_goal espresso_flow_goal espresso_temperature_goal}
	set past_props_keys [array names past_props]	
	foreach k $default_pars {
		if { [lsearch $past_props_keys $k] > -1 } {
			set v $past_props($k)
			append espresso_data [subst {[list $k] [list $v]\n}]
		}
	}	
	
	# Check if there's any variable in the first shot section not in our default list and add it afterwards.
	set past_props_keys [list_remove_element $past_props_keys settings]
	set past_props_keys [list_remove_element $past_props_keys machine]
	foreach k $past_props_keys {
		if { [lsearch $default_pars $k] == -1 } {
			set v $past_props($k)
			append espresso_data [subst {[list $k] [list $v]\n}]
		}
	}

	append espresso_data "settings {\n"
	foreach k [lsort -dictionary [array names past_sets]] {
		set v $past_sets($k)
		append espresso_data [subst {\t[list $k] [list $v]\n}]
	}
	append espresso_data "}\n"

	append espresso_data "machine {\n"
	foreach k [lsort -dictionary [array names past_mach]] {
		set v $past_mach($k)
		append espresso_data [subst {\t[list $k] [list $v]\n}]
	}
	append espresso_data "}\n"

	if { $write_file == 1 && $backup_file == 1 } {
		set backup_path [string range $path 0 end-5].bak
		if {[file exists $backup_path]} { file delete $backup_path }
		file rename $path $backup_path
	}
	if { $write_file == 1 } {
		write_file $path $espresso_data
		msg "Updated past espresso history file $path"
	}
	
	return $espresso_data	
}

proc ::plugins::SDB::db_path { } {
	return "[homedir]/$::plugins::SDB::settings(db_path)"
}

# Creates the SQLite shot database from scratch.
# Returns 1 if the database is actually (re)created, 0 otherwise. 
proc ::plugins::SDB::create { {recreate 0} {make_backup 1} {update_screen 0} } {
	variable db
	variable updating_db
	variable progress_msg
	
	set updating_db 1
	
	set db_path [db_path]
	if {[file exists $db_path] == 1} {
		if { $recreate == 1 } {
			db_close
			if { $make_backup == 1 } {
				set backup_path  "[file dirname $db_path]/shots_bak.db"
				# BEWARE that "file rename -force" may fail on Windows, so we delete/rename.
				if { [file exists $backup_path] } { file delete $backup_path }
				file rename $db_path $backup_path
			} else {
				file delete $db_path
			}
		} else { 
			upgrade $update_screen
#			after 3000 { set progress_msg "" }
			set updating_db 0
			return 0
		}
	}
	
	say [translate "Creating shots database"] {}
	msg "Creating shots database"
	
	set progress_msg [translate "Creating DB"]
	if { $update_screen == 1 } update
	
	sqlite3 db $db_path -create 1
	
	# Seems the PC undrowish version was not compiled to allow foreign key enforcement
	#db config enable_fkey 1
	# Just use empty strings {}, which are translated to NULL
	#db nullvalue NULL

	db eval { PRAGMA user_version = 0 } 	
	upgrade	$update_screen
#	after 3000 { set progress_msg "" }
	
	set updating_db 0
	return 1
}

# Grab the reference to the shots database. 
proc ::plugins::SDB::get_db {} {
	variable db
	variable sqlite_version
	
	if { $db eq {} } { 
		sqlite3 db [db_path] -create 0
		# According to documentation, 'db trace' should get you the SQL statements after variable substitution is done,
		# but it's not the case, so we need to log manually on every statement if we want to have the actual statement. 
		if { $::plugins::SDB::settings(log_sql_statements) == 1 } {
			db trace ::plugins::SDB::log_sql
		}
		set sqlite_version [db version]
	}
	return $db
}

# Detects whether the current shots database schema is from an earlier version of the plugin and upgrades its
# structure if needed. Also used to create the database schema incrementally from scratch.
proc ::plugins::SDB::upgrade { {update_screen 0} } {
	set db [get_db]
	variable updating_db
	variable db_version
	variable version
	variable progress_msg 
	
	set updating_db 1
	
	set setting_table [db eval {SELECT name FROM sqlite_master WHERE type='table' AND name='setting'}]
	if { $setting_table eq "" } {
		set disk_db_version [db eval {PRAGMA user_version}]
	} else {
		set disk_db_version [db eval {SELECT value FROM setting WHERE code='db_version'}]
		if { $disk_db_version eq "" } {
			set disk_db_version [db eval {PRAGMA user_version}]	
		} else {
			db eval "PRAGMA user_version=$disk_db_version"
			db eval "DELETE FROM setting WHERE code='db_version'"
		}
	}

	msg "Using SQLite version [db version]"	
	msg "Comparing shot db versions: disk $disk_db_version, current $db_version"
	if { $disk_db_version > $db_version } {
		message_page "[translate {Plugin 'Shots DataBase'}] v$version [translate {uses database schema version}]\
			$db_version, [translate {but shots.db schema is from a higher version}] (v$disk_db_version)" \
			[translate Ok]		
	}

	if { $disk_db_version == $db_version } { return }
	
	# SET WHILE DEBUGGING TO FORCE SCHEMA (RE)CREATION
	#set disk_db_version 0	

	msg "Upgrading shot db from schema version $disk_db_version to schema version $db_version"

	if { $disk_db_version <= 0 } {
		set progress_msg [translate "Upgrading DB to v1"]
		if { $update_screen == 1 } update
			
		db eval {
		CREATE TABLE IF NOT EXISTS shot (clock INTEGER PRIMARY KEY, filename TEXT(15) UNIQUE NOT NULL, 
			file_modification_date INTEGER, archived INTEGER DEFAULT 0, profile_title TEXT, bean_weight REAL, 
			drink_weight REAL, extraction_time REAL, bean_brand TEXT, bean_type TEXT, 
			bean_notes TEXT, roast_date TEXT, roast_level TEXT, grinder_model TEXT, grinder_setting TEXT,
			drink_tds REAL, drink_ey REAL, espresso_enjoyment INT, espresso_notes TEXT, my_name TEXT, scentone TEXT,
			beverage_type TEXT, skin TEXT, visualizer_link TEXT);

		CREATE TABLE IF NOT EXISTS shot_series (shot_clock INTEGER, elapsed REAL,
			pressure REAL, weight REAL, flow REAL, flow_weight REAL, flow_weight_raw REAL,
			temperature_basket REAL, temperature_mix REAL, water_dispensed REAL,
			pressure_goal REAL, flow_goal REAL, temperature_goal REAL,
			FOREIGN KEY (shot_clock) REFERENCES shot(clock));

		CREATE UNIQUE INDEX IF NOT EXISTS IX_shot_series ON shot_series(shot_clock, elapsed);

		CREATE TABLE IF NOT EXISTS shot_state_change (shot_clock INTEGER, elapsed REAL,
			FOREIGN KEY (shot_clock) REFERENCES shot(clock));

		CREATE UNIQUE INDEX IF NOT EXISTS IX_shot_state_change ON shot_state_change(shot_clock, elapsed);

		CREATE TABLE IF NOT EXISTS profile (name TEXT(15) PRIMARY KEY, filename TEXT UNIQUE);

		CREATE TABLE IF NOT EXISTS profile_step (profile_name TEXT(15), name TEXT, filename TEXT UNIQUE,
			FOREIGN KEY (profile_name) REFERENCES profile(name));

		CREATE TABLE IF NOT EXISTS shot_profile_step (shot_clock INTEGER, name TEXT, filename TEXT UNIQUE,
			FOREIGN KEY (shot_clock) REFERENCES shot(clock));

		CREATE TABLE IF NOT EXISTS setting (code TEXT(30) PRIMARY KEY, value TEXT);
		
		INSERT OR REPLACE INTO setting (code, value) VALUES ('last_updated', 1);
		}
	}
	
	if { $disk_db_version <= 1 } {
		set progress_msg [translate "Upgrading DB to v2"]
		if { $update_screen == 1 } update		
		rename_columns shot bean_weight grinder_dose_weight
	}
		
	if { $disk_db_version <= 2 } {
		set progress_msg [translate "Upgrading DB to v3"]
		if { $update_screen == 1 } update		
		catch { db eval { ALTER TABLE shot ADD COLUMN drinker_name TEXT} }
		catch { db eval { ALTER TABLE shot ADD COLUMN removed INTEGER DEFAULT 0} }
		
		db eval { 
		CREATE VIEW IF NOT EXISTS V_shot AS
		SELECT s.clock, s.filename, 
			CASE WHEN s.archived=0 THEN '/history/'||s.filename||'.shot' 
				ELSE '/history_archive/'||s.filename||'.shot' END as rel_path,
			s.file_modification_date, s.archived, s.removed,
			strftime('%d/%m/%Y %H:%M',s.clock,'unixepoch','localtime')||' '||s.profile_title||
				CASE WHEN LENGTH(COALESCE(s.grinder_dose_weight,''))>0 OR LENGTH(COALESCE(s.drink_weight,''))>0 THEN 
					' - '|| CASE WHEN s.grinder_dose_weight IS NULL OR s.grinder_dose_weight='' THEN '0' ELSE s.grinder_dose_weight END ||'g : '||
					CASE WHEN s.drink_weight IS NULL OR s.drink_weight='' THEN '0' ELSE s.drink_weight END ||'g'||
					CASE WHEN LENGTH(COALESCE(s.grinder_dose_weight,''))>0 AND LENGTH(COALESCE(s.drink_weight,''))>0 THEN
						' (1:' || ROUND(s.drink_weight / s.grinder_dose_weight, 1) || ') '
					ELSE '' END 
				ELSE '' END ||
				CASE WHEN LENGTH(COALESCE(s.bean_brand,''))>0 OR LENGTH(COALESCE(s.bean_type,''))>0 OR LENGTH(COALESCE(s.roast_date,''))>0 THEN
					' - '|| TRIM(COALESCE(s.bean_brand||' ','')||COALESCE(s.bean_type||' ','')||COALESCE(s.roast_date,''))
				ELSE '' END ||
				CASE WHEN LENGTH(COALESCE(s.grinder_model,''))>0 OR LENGTH(COALESCE(s.grinder_setting,''))>0 THEN
					' - '|| COALESCE(s.grinder_model, '') ||' @ '|| COALESCE(s.grinder_setting,'') 
				ELSE '' END ||
				CASE WHEN removed=1 THEN ' [REMOVED]' ELSE '' END AS shot_desc,
			s.profile_title, s.grinder_dose_weight, s.drink_weight, s.extraction_time,
			s.bean_brand, s.bean_type, s.bean_notes, s.roast_date, s.roast_level,
			CASE WHEN LENGTH(COALESCE(s.bean_brand,''))>0 OR LENGTH(COALESCE(s.bean_type,''))>0 OR LENGTH(COALESCE(s.roast_date,''))>0 THEN
				TRIM(COALESCE(s.bean_brand||' ','')||COALESCE(s.bean_type||' ','')||COALESCE(s.roast_date,''))
				ELSE '' END AS bean_desc,	
			s.grinder_model, s.grinder_setting, 
			s.drink_tds, s.drink_ey, s.espresso_enjoyment, s.espresso_notes, s.scentone,
			s.my_name, s.drinker_name, s.beverage_type, s.skin,
			s.visualizer_link
		FROM shot s;
						
		DELETE FROM setting WHERE code='db_version';
		}
	}
	
	# v4 corrects an error in V_shot when grinder_dose_weight was 0 the ratio was computed, returned NULL, and 
	# then shot_desc was NULL. Also on the very first .shot files in DE1 the profile_title could be empty.
	if { $disk_db_version <= 3 } {
		set progress_msg [translate "Upgrading DB to v4"]
		if { $update_screen == 1 } update
		
		db eval {
		DROP VIEW IF EXISTS V_shot;
			
		CREATE VIEW IF NOT EXISTS V_shot AS
		SELECT s.clock, s.filename, 
			CASE WHEN s.archived=0 THEN '/history/'||s.filename||'.shot' 
				ELSE '/history_archive/'||s.filename||'.shot' END as rel_path,
			s.file_modification_date, s.archived, s.removed,
			strftime('%d/%m/%Y %H:%M',s.clock,'unixepoch','localtime')||' '||COALESCE(s.profile_title,'')||
			CASE WHEN LENGTH(COALESCE(s.grinder_dose_weight,''))>0 OR LENGTH(COALESCE(s.drink_weight,''))>0 THEN 
				' - '|| CASE WHEN s.grinder_dose_weight IS NULL OR s.grinder_dose_weight='' THEN '0' ELSE s.grinder_dose_weight END ||'g : '||
				CASE WHEN s.drink_weight IS NULL OR s.drink_weight='' THEN '0' ELSE s.drink_weight END ||'g'||
				CASE WHEN LENGTH(COALESCE(s.grinder_dose_weight,''))>0 AND LENGTH(COALESCE(s.drink_weight,''))>0 
						AND s.grinder_dose_weight > 0 AND s.drink_weight > 0 THEN
					' (1:' || ROUND(s.drink_weight / s.grinder_dose_weight, 1) || ')'
				ELSE '' END 
			ELSE '' END ||
			CASE WHEN LENGTH(COALESCE(s.bean_brand,''))>0 OR LENGTH(COALESCE(s.bean_type,''))>0 OR LENGTH(COALESCE(s.roast_date,''))>0 THEN
				' - '|| TRIM(COALESCE(s.bean_brand||' ','')||COALESCE(s.bean_type||' ','')||COALESCE(s.roast_date,''))
			ELSE '' END ||
			CASE WHEN LENGTH(COALESCE(s.grinder_model,''))>0 OR LENGTH(COALESCE(s.grinder_setting,''))>0 THEN
				' - '|| COALESCE(s.grinder_model, '') || 
					CASE WHEN LENGTH(COALESCE(s.grinder_setting,''))>0 THEN ' @ '||s.grinder_setting ELSE '' END
			ELSE '' END ||
			CASE WHEN LENGTH(COALESCE(s.drink_ey,''))>0 OR LENGTH(COALESCE(s.drink_tds,''))>0 OR LENGTH(COALESCE(s.espresso_enjoyment,''))>0 THEN
				' - '||
				CASE WHEN LENGTH(COALESCE(s.drink_tds,''))>0 THEN 'TDS '||s.drink_tds||'% ' ELSE '' END ||
				CASE WHEN LENGTH(COALESCE(s.drink_ey,''))>0 THEN 'EY '||s.drink_ey||'% ' ELSE '' END ||
				CASE WHEN LENGTH(COALESCE(s.espresso_enjoyment,''))>0 THEN 'Enjoy '||s.espresso_enjoyment||' ' ELSE '' END 
			ELSE '' END ||
			CASE WHEN removed=1 THEN ' [REMOVED]' ELSE '' END AS shot_desc,
			s.profile_title, s.grinder_dose_weight, s.drink_weight, s.extraction_time,
			s.bean_brand, s.bean_type, s.bean_notes, s.roast_date, s.roast_level,
			CASE WHEN LENGTH(COALESCE(s.bean_brand,''))>0 OR LENGTH(COALESCE(s.bean_type,''))>0 OR LENGTH(COALESCE(s.roast_date,''))>0 THEN
				TRIM(COALESCE(s.bean_brand||' ','')||COALESCE(s.bean_type||' ','')||COALESCE(s.roast_date,''))
				ELSE '' END AS bean_desc,	
			s.grinder_model, s.grinder_setting, 
			s.drink_tds, s.drink_ey, s.espresso_enjoyment, s.espresso_notes, s.scentone,
			s.my_name, s.drinker_name, s.beverage_type, s.skin, s.visualizer_link
		FROM shot s;
		}
	}
	
	db eval "PRAGMA user_version=$db_version"
	set progress_msg [translate "DB Upgraded"]
	if { $update_screen == 1 } update		
	
	set updating_db 0
}
	
# Closes the shot SQLite database.
# Add unnecessary { args } for this to work on trace add execution.
proc ::plugins::SDB::db_close { args } {	
	if { [info exists ::plugins::SDB::db] } {
		variable db
		if { [catch {
			db close
		} err ] != 0 } {
			msg "ERROR while trying to close the database: $err"
		}		
		unset -nocomplain ::plugins::SDB::db
		set db {}
	} else {
		variable db
		set db {}
	}
}

	
# Backwards-compatible table column renamer. Takes into account the SQLite version, as before 3.25.0 
#	"ALTER TABLE RENAME COLUMN" was not supported. Also fail-safe if the old column does not exist, or the new 
#	column already does.
# Returns 1 if at least one column is renamed, 0 otherwise.
proc ::plugins::SDB::rename_columns { db_table old_columns new_columns } {
	set db [get_db]
	set result 0
	
	if { [package vcompare [db version] 3.25] >= 0 } {
		for { set i 0 } { $i < [llength $old_columns] } { incr i } {
			if { $i < [llength $new_columns] } {
				set sql "ALTER TABLE $db_table RENAME COLUMN [lindex $old_columns $i] TO [lindex $new_columns $i]"
				if { [ catch {db eval "$sql"} err ] != 0 } {
					msg "ERROR, can't rename column [lindex $old_columns $i] to [lindex $new_columns $i] in table $db_table: $err"
				} else { 
					set result 1
				}
			}
		}
		
		return $result
	}

	set old_all_columns {}		
	db eval "PRAGMA table_info($db_table)" { lappend old_all_columns $name }
	set new_all_columns $old_all_columns	
	if { [llength $old_all_columns] == 0 } {
		msg "ERROR, can't find DB table $db_table"
		return $result
	}
	
	set create_sql [db eval "SELECT sql FROM sqlite_master WHERE type='table' AND name='$db_table'" ]
	set create_sql [regsub "\\m$db_table\\M" $create_sql "NEW_$db_table"]
	
	set i 0
	set n_changes 0
	foreach old_col $old_columns {
		set new_col [lindex $new_columns $i]
				
		if { [regexp "\\m$old_col\\M" $create_sql] } {
			set create_sql [regsub "\\m$old_col\\M" $create_sql $new_col]
			set col_idx [lsearch $new_all_columns $old_col]
			if { $col_idx > -1 } {
				set new_all_columns [lreplace $new_all_columns $col_idx $col_idx $new_col]
				incr n_changes
			} else {
				msg "ERROR column $old_col not found in table $db_table"
			}
		} else {
			msg "ERROR column $old_col not found in table $db_table"
		}
		incr i
	}

	if { $n_changes > 0 } {
		set sql "BEGIN TRANSACTION;
			[join $create_sql];
			INSERT INTO NEW_$db_table ([join $new_all_columns ,]) SELECT [join $old_all_columns ,] FROM $db_table;
			DROP TABLE $db_table;
			ALTER TABLE NEW_$db_table RENAME TO $db_table;
			COMMIT TRANSACTION;"
		db eval "$sql";
		set result 1
	}
	
	return $result
}
		
# Fully synchronizes every file in the shot history and history_archive folders to the shots database.
# As a side effect, updates the last_sync_* variables in the settings.
proc ::plugins::SDB::populate { {persist_desc {}} { persist_series {}} {update_screen 0} {force_update_series 0} } {
	variable updating_db
	variable settings
	variable progress_msg
	variable friendly_clock_format
	set db [get_db]
	
	if { $persist_desc eq "" } { set persist_desc $settings(db_persist_desc) }
	if { $persist_series eq "" } { set persist_series $settings(db_persist_series) }
	if { !$persist_desc && !$persist_series } return

	set updating_db 1	
	set screen_msg [translate "Synchronizing DB"]
	set progress_msg $screen_msg
	
	set last_sync_start [clock seconds]
	foreach fn "analyzed inserted modified archived unarchived removed unremoved" { set "cnt_$fn" 0 }
	
	#set last_db_updated [db eval { SELECT CAST(value AS integer) FROM setting WHERE code='last_updated' }]
	array set db_shots {}
	db eval { SELECT filename, clock, file_modification_date, archived, removed FROM shot } {
		set db_shots(${filename}.shot) "$clock $file_modification_date $archived $removed"
	}
	
	set files [lsort -dictionary [glob -nocomplain -tails -directory "[homedir]/history/" *.shot]]
	set afiles [lsort -dictionary [glob -nocomplain -tails -directory "[homedir]/history_archive/" *.shot]]
	set n [expr {[llength $files]+[llength $afiles]}]
	set cnt 1
	set progress_msg "$screen_msg: 0/$n (0\%)"
	if { $update_screen == 1 } { update }
	
	foreach f $files {
		if { [info exists db_shots($f)] } {
			set something_changed 0
			lappend db_shots($f) 1
		
			set fmtime [file mtime "[homedir]/history/$f"]
			set db_mtime [lindex $db_shots($f) 1]
			if { $fmtime > $db_mtime } {
				log_sql "Processing history/$f, as modif time ($fmtime=[clock format $fmtime -format $friendly_clock_format]) > DB modif time ($db_mtime=[clock format $db_mtime -format $friendly_clock_format])"
				array set shot [load_shot "[homedir]/history/$f"]
				persist_shot shot $persist_desc $persist_series 0
				incr cnt_modified
				set something_changed 1
			} elseif { $persist_series == 1 && $force_update_series == 1} {
				set shot_clock [lindex $db_shots($f) 0]
				set shot_has_series [db exists {SELECT 1 FROM shot_series WHERE shot_clock=$shot_clock LIMIT 1}]
				if { $shot_has_series != 1 } {
					log_sql "Processing history/$f, as it needs its chart series added"
					array set shot [load_shot "[homedir]/history/$f"]
				
					persist_shot shot 0 1 0
					incr cnt_modified
					set something_changed 1
				}
			} 
			set sql {}
			if { [lindex $db_shots($f) 2] == 1 } { 
				append sql " archived=0," 
				incr cnt_unarchived
			}
			if { [lindex $db_shots($f) 3] == 1 } { 
				append sql " removed=0," 
				incr cnt_unremoved
			}
			if { $sql ne "" } {
				set sql "UPDATE shot SET [string range $sql 0 end-1] WHERE clock=[lindex $db_shots($f) 0]"
				db eval "$sql"
				set something_changed 1
			} 
			if { $something_changed == 0 } {
				log_sql "shot file history/$f does not need any updating"
			}
		} else {
			log_sql "Processing history/$f, as it's a new shot file not yet in the database"
			array set shot [load_shot "[homedir]/history/$f"]
			persist_shot shot $persist_desc $persist_series 0
			if { $update_screen == 1 } update
			incr cnt_inserted
		}
		
		incr cnt
		if {[expr {$cnt % 10}] == 0 } {
			set perc [expr {int($cnt*100.0/$n)}]
			set progress_msg "$screen_msg: $cnt/$n ($perc\%)"
			if { $update_screen == 1 } { update }
		}
	}
	
	foreach f $afiles {
		if { [info exists db_shots($f)] } {
			set something_changed 0
			lappend db_shots($f) 1
			set fmtime [file mtime "[homedir]/history_archive/$f"]
			set db_mtime [lindex $db_shots($f) 1]
			if { $fmtime > $db_mtime } {
				log_sql "Processing history_archive/$f, as modif time ($fmtime=[clock format $fmtime -format $friendly_clock_format]) > DB modif time ($db_mtime=[clock format $db_mtime -format $friendly_clock_format])"
				array set shot [load_shot "[homedir]/history_archive/$f"]
				persist_shot shot $persist_desc $persist_series 0
				incr cnt_modified
				set something_changed 1
			} elseif { $persist_series == 1 && $force_update_series == 1} {
				set shot_clock [lindex $db_shots($f) 0]
				set shot_has_series [db exists {SELECT 1 FROM shot_series WHERE shot_clock=$shot_clock LIMIT 1}]
				if { $shot_has_series != 1 } {
					log_sql "Processing history/$f, as it needs its chart series added"
					array set shot [load_shot "[homedir]/history_archive/$f"]
					persist_shot shot 0 1 0
					incr cnt_modified
				}				
				set something_changed 1
			} 
			set sql {}
			if { [lindex $db_shots($f) 2] == 0 } { 
				append sql " archived=1," 
				incr cnt_archived
			}
			if { [lindex $db_shots($f) 3] == 1 } { 
				append sql " removed=0," 
				incr cnt_unremoved
			}
			if { $sql ne "" } {
				set sql "UPDATE shot SET [string range $sql 0 end-1] WHERE clock=[lindex $db_shots($f) 0]"
				db eval "$sql"
				set something_changed 1
			}
			if { $something_changed == 1 } {
				log_sql "Shot file history/$f does not need any updating"
			}			
		} else {
			log_sql "Processing history_archive/$f, as it's a new shot file not yet in the database"
			array set shot [load_shot "[homedir]/history_archive/$f"]
			persist_shot shot $persist_desc $persist_series 0
			incr cnt_inserted
		}
		
		incr cnt
		if {[expr {$cnt % 10}] == 0 } {
			set perc [expr {int($cnt*100.0/$n)}]			
			set progress_msg "$screen_msg: $cnt/$n ($perc\%)"
			if { $update_screen == 1 } { update }
		}
	}

	# Check files deleted from disk and flag them as removed.
	set rm_clocks {}
	foreach f [array names db_shots] {
		if { [llength $db_shots($f)] < 5 } { 
			lappend rm_clocks [lindex $db_shots($f) 0]
			log_sql "Shot file $f removed from history and history_archive"
		}
	}
	if { [llength $rm_clocks] > 0} {
		set sql "UPDATE shot SET removed=1 WHERE clock IN ([join $rm_clocks ,]) AND removed=0"
		db eval "$sql"
		set cnt_removed [db changes]
	}

	set progress_msg "$screen_msg: $n/$n (100\%)"
	if { $update_screen == 1} update
#	after 3000 { set progress_msg "" } 
	
	update_last_updated
	
	set settings(last_sync_clock) $last_sync_start 	
	set settings(last_sync_analyzed) $n
	foreach fn "inserted modified archived unarchived removed unremoved" {
		set settings(last_sync_$fn) [subst \$cnt_$fn]
	}	
	
	plugins save_settings SDB
	set updating_db 0
}

proc ::plugins::SDB::update_last_updated {} {
	set db [get_db]
	set sql "UPDATE setting SET value=(SELECT COALESCE(MAX(file_modification_date), 1) FROM shot) \
		WHERE code='last_updated' "
	db eval "$sql"
}

# Persists shot data to the SQLite shot database.
# The shot data should be an array reference as produced by proc 'load_shot'.
# Detects whether the shot is already in the DB and INSERTs or UPDATEs the description as needed.
# Series are only inserted once, never updated as they never change after shot creation.
proc ::plugins::SDB::persist_shot { arr_shot {persist_desc {}} {persist_series {}} {calc_last_updated 1} } {
	variable settings
	
	upvar $arr_shot shot
	set db [get_db]
	
	if { $persist_desc eq "" } { set persist_desc $settings(db_persist_desc) }
	if { $persist_series eq "" } { set persist_series $settings(db_persist_series) }

	if { $persist_desc == 1 } {
		if {[db exists {SELECT 1 FROM shot WHERE clock=$shot(clock)}]} {
			# We only update the description fields, not the others which should not change.
			db eval { UPDATE shot SET archived=COALESCE($shot(comes_from_archive),0),
				grinder_dose_weight=$shot(grinder_dose_weight),drink_weight=$shot(drink_weight),
				bean_brand=$shot(bean_brand),bean_type=$shot(bean_type),
				bean_notes=$shot(bean_notes), roast_date=$shot(roast_date),roast_level=$shot(roast_level),
				grinder_model=$shot(grinder_model),grinder_setting=$shot(grinder_setting),
				drink_tds=$shot(drink_tds),drink_ey=$shot(drink_ey),
				espresso_enjoyment=$shot(espresso_enjoyment),espresso_notes=$shot(espresso_notes),
				my_name=$shot(my_name),drinker_name=$shot(drinker_name),scentone=$shot(scentone),
				file_modification_date=$shot(file_modification_date),skin=$shot(skin),
				beverage_type=$shot(beverage_type)
				WHERE clock=$shot(clock) }
			
			if { [info exists shot(other_equipment)] } {
				update_shot_equipment $shot(clock) $shot(other_equipment) 0
			}						
		} else {
			db eval { INSERT INTO shot (clock,filename,archived,
				profile_title,grinder_dose_weight,drink_weight,extraction_time,
				bean_brand,bean_type,bean_notes,roast_date,roast_level,grinder_model,grinder_setting,
				drink_tds,drink_ey,espresso_enjoyment,espresso_notes,my_name,drinker_name,scentone,
				file_modification_date,skin,beverage_type)
				VALUES ( $shot(clock),$shot(filename),COALESCE($shot(comes_from_archive),0),
				$shot(profile_title),$shot(grinder_dose_weight),$shot(drink_weight),
				$shot(extraction_time),$shot(bean_brand),$shot(bean_type),$shot(bean_notes),$shot(roast_date),
				$shot(roast_level),$shot(grinder_model),$shot(grinder_setting),$shot(drink_tds),$shot(drink_ey),
				$shot(espresso_enjoyment),$shot(espresso_notes),$shot(my_name),$shot(drinker_name),$shot(scentone),
				$shot(file_modification_date),$shot(skin),$shot(beverage_type) ) }
			
			if { [info exists shot(other_equipment)] && $shot(other_equipment) ne "" } {
				update_shot_equipment $shot(clock) $shot(other_equipment) 0
			}									
		}
	} elseif { $persist_series == 1 } {
		# Prevents breaking a FK constraint (though FK are not supported in this compilation of undrowish) if the shot 
		# description has never been persisted and the arguments specify to save the series but not the description.
		set persist_series [db exists {SELECT 1 FROM shot WHERE clock=$shot(clock)}]
	}

	# Only make series inserts, never updates
	if { $persist_series == 1 && [db exists {SELECT 1 FROM shot_series WHERE shot_clock=$shot(clock) LIMIT 1}] == 0 } {
		if { [llength $shot(espresso_elapsed)] > 1 } {
			set n_weight [llength $shot(espresso_weight)]
			set n_flow_weight_raw [llength $shot(espresso_flow_weight_raw)]
			set n_water_dispensed [llength $shot(espresso_water_dispensed)]
			set n_pressure_goal [llength $shot(espresso_pressure_goal)]

			set sql "INSERT INTO shot_series (shot_clock,elapsed,pressure,weight,flow,flow_weight,flow_weight_raw,\
temperature_basket,temperature_mix,water_dispensed,pressure_goal,flow_goal,temperature_goal) VALUES "
			for {set i 0} { $i < [llength $shot(espresso_elapsed)] } {incr i} {
				# I can't make embedding the [lindex ...] statement in the SQL string work, so
				# I need to create each variable
				set elapsed [lindex $shot(espresso_elapsed) $i]
				set pressure [lindex $shot(espresso_pressure) $i]
				if { $i < $n_weight } {
					set weight [lindex $shot(espresso_weight) $i]
				} elseif {[info exists weight] == 1} {
					set weight "NULL"
				}
				set flow [lindex $shot(espresso_flow) $i]
				set flow_weight [lindex $shot(espresso_flow_weight) $i]
				if { $i < $n_flow_weight_raw } {
					set flow_weight_raw [lindex $shot(espresso_flow_weight_raw) $i]
				} else {
					set flow_weight_raw "NULL"
				}
				set temperature_basket [lindex $shot(espresso_temperature_basket) $i]
				set temperature_mix [lindex $shot(espresso_temperature_mix) $i]
				if { $i < $n_water_dispensed } {
					set water_dispensed [lindex $shot(espresso_water_dispensed) $i]
				} else {
					set water_dispensed "NULL"
				}
				if {$i < $n_pressure_goal } {
					set pressure_goal [lindex $shot(espresso_pressure_goal) $i]
					set flow_goal [lindex $shot(espresso_flow_goal) $i]
					set temperature_goal [lindex $shot(espresso_temperature_goal) $i]
				} else {
					set pressure_goal "NULL"
					set flow_goal "NULL"
					set temperature_goal "NULL"
				}

				append sql "($shot(clock),$elapsed,$pressure,$weight,$flow,$flow_weight,$flow_weight_raw,\
$temperature_basket,$temperature_mix,$water_dispensed,$pressure_goal,$flow_goal,$temperature_goal),\r"
			}
			set sql [string range $sql 0 [expr {[string length $sql]-3}]]
			db eval "$sql"
		}
	}

	if { $calc_last_updated == 1 } { update_last_updated }
}

# Updates the shot table for the requested shot (identified by its clock) using the data from provided array.
# Array names must match shot table column names.
proc ::plugins::SDB::update_shot_description { clock arr_new_settings } {
	set db [get_db]
	upvar $arr_new_settings new_settings
	
	if { [string trim $clock] eq "" } return
	if { [array size new_settings] == 0 } return
	
	db eval "SELECT * FROM shot LIMIT 1" x {set columns $x(*)}
	
	set field_updates {}
	foreach field_name [array names new_settings] {
		# TODO: Replace following test by a parametrized done using the data dictionary?
		if { $field_name eq "other_equipment" } {
			update_shot_equipment $clock $new_settings(other_equipment)
		} else {		
			if { [lsearch $columns $field_name] > -1 } {
				lappend field_updates "$field_name=\$new_settings($field_name)"
			} else {
				msg "ERROR: Unmatched column name $field_name in update_shot_description"
			}
		}
	}
	
	if { [llength $field_updates] > 0 } {
		set sql "UPDATE shot SET [join $field_updates ,] WHERE clock=$clock"
		db eval "$sql"
	}
}

# Hook executed after save_espresso_rating_to_history if visualizer_upload is not enabled, and after 
# uploading to visualizer if it is.
proc ::plugins::SDB::save_espresso_to_history_hook { args } {
	variable settings 	
	if { $::settings(history_saved) != 1 } return
msg "save_espresso_to_history_hook"
	
	if { [plugins enabled visualizer_upload] &&
			[info exists ::plugins::visualizer_upload::settings(last_upload_shot)] &&
			$::plugins::visualizer_upload::settings(last_upload_shot) eq $::settings(espresso_clock) &&
			$::plugins::visualizer_upload::settings(last_upload_id) ne "" } {
		regsub "<ID>" $::plugins::visualizer_upload::settings(visualizer_browse_url) \
			$::plugins::visualizer_upload::settings(last_upload_id) link
		set repo_link "Visualizer $link" 
		if { $::settings(repository_links) eq "" } { 
			set ::settings(repository_links) $repo_link
		} elseif { $::settings(repository_links) ne $repo_link } {
			lappend ::settings(repository_links) $repo_link
		}

msg "save_espresso_to_history_hook - adding repository_links to shot file"
		array set new_settings "repository_links \{$::settings(repository_links)\}"
		modify_shot_file $::settings(espresso_clock) new_settings
		::save_settings
	}
		
	if { $settings(db_persist_desc) == 1 || $settings(db_persist_series) == 1 } {
		# We need the shot data in DYE::DB::persist_shot in an array that is a bit different from ::settings,
		# e.g. "clock" is "espresso_clock" in the settings, chart series are not in ::settings but in other vars,
		# we miss the filename and the modification time, and we need to build some variables with a priority
		# (like dose may come from DSx vars or from base vars). So, rather than replicate everything, we just read
		# the just-written file, which is not highly efficient but it's very straightforward.
		#set fn "[homedir]/history/[clock format $::settings(espresso_clock) -format $::DYE::filename_clock_format].shot"
		array set shot [load_shot $::settings(espresso_clock)]
		persist_shot shot $settings(db_persist_desc) $settings(db_persist_series) 1
	}
}

# Returns shots data.  
# 'return_what' is a list of column names to return, or 'count' for just the number of shots. If a single column
#	is requested, a list is returned. If more than one column is returned, returns an array with one list per 
#	column.
# 'args' provide 'type' values that must be matched in the target db table (e.g. for an equipment item, its equipment type).
proc ::plugins::SDB::shots { {return_columns clock} {exc_removed 1} {filter {}} {max_rows 500} } {
	set db [get_db]
	
	if { $return_columns eq "count" } { 
		set sql "SELECT COUNT(clock) "
	} else { 
		set sql "SELECT [join $return_columns ,] "
	}
	append sql "FROM V_shot "
	if { $exc_removed == 1 || $filter ne "" } {
		append sql "WHERE "
		if { $exc_removed == 1 } { append sql "removed=0 AND " }
		if { $filter ne "" } { append sql "$filter AND " }
		set sql [string range $sql 0 end-4]
	}
	append sql " ORDER BY clock DESC LIMIT $max_rows"
		
	if { [llength $return_columns] == 1 } {
		return [db eval "$sql"]
	} else {
		array set result {}		
		set i 0 
		db eval "$sql" values {
			if { $i == 0 } {
				foreach fn $values(*) { set result($fn) {} }
			}
			foreach fn $values(*) { 
				lappend result($fn) $values($fn)
			}
			incr i
		}		
		return [array get result]
	}
}

# Returns a list of available categories. "field_name" must be available in the data dictionary with 
# 	data_type=category. Returns a list for single-column categories, and an array of lists for multi-column
# 	categories such as equipment_name (which requires equipment_type).
# If use_lookup_table=1, grabs the categories from the lookup_table (e.g. equipment_type) instead of from the
#	actual values as used in shots (e.g. shot_equipment inner join equipment_type)
# If args are provided and the field has db_type_column<i>, filters to category values matching the corresponding
#	types.
proc ::plugins::SDB::available_categories { field_name {exc_removed_shots 1} {filter {}} {use_lookup_table 1} args } {
	set db [get_db]	
	
	lassign [::plugins::DGUI::field_lookup $field_name {data_type db_table lookup_table db_type_column1 db_type_column2}] \
		data_type db_table lookup_table db_type_column1 db_type_column2 
	if { $data_type ne "category" } return
	if { $use_lookup_table == 1 && $lookup_table eq "" } { set use_lookup_table 0 }	
	
	set fields {}
	set grouping_fields {}
	lappend fields "TRIM($field_name) as $field_name"
	lappend grouping_fields "TRIM($field_name)"
	
	set extra_from ""
	set extra_wheres {}
	set type1_db_table ""
	if { $db_type_column1 ne "" } { 
		lappend fields "TRIM($db_type_column1) AS $db_type_column1" 
		lappend grouping_fields "TRIM($db_type_column1)"
		if { $use_lookup_table == 1 } {							
			lassign [::plugins::DGUI::field_lookup $db_type_column1 {lookup_table}] type1_db_table 
			if { $type1_db_table ne "" } {
				append extra_from "LEFT JOIN $type1_db_table ON $db_type_column1=${type1_db_table}.$db_type_column1 "
			}
		}
		
		if { [llength $args] > 0 && [lindex $args 0] ne "" } {
			lappend extra_wheres "$db_type_column1 IN ([strings2sql [lindex $args 0]])"
		}
	}
	
	if { $db_type_column2 ne "" } { 
		lappend fields "TRIM($db_type_column2) as $db_type_column2" 
		lappend grouping_fields "TRIM($db_type_column2)"
		if { [llength $args] > 1 && [lindex $args 1] ne "" } {
			lappend extra_wheres "$db_type_column2 IN ([strings2sql [lindex $args 1]])"
		}
	}
	
	if { $db_table eq "shot" } {
		set sql "SELECT [join $fields ,] FROM shot "
	} elseif { $use_lookup_table } {
		set sql "SELECT [join $fields ,] FROM $lookup_table $extra_from"
	} else {
		set sql "SELECT [join $fields ,] FROM $db_table INNER JOIN shot ON ${db_table}.clock=shot.clock "
	}
	
	append sql "WHERE LENGTH(TRIM(COALESCE($field_name,''))) > 0 "
	if { $exc_removed_shots == 1 && $use_lookup_table == 0 } { append sql "AND shot.removed=0 " }
	if { $filter ne "" } { append sql "AND $filter " }
	if { [llength $extra_wheres] > 0 } { append sql "AND [join $extra_wheres { AND }] "  }
	
	if { $use_lookup_table != 1 } {
		append sql "GROUP BY [join $grouping_fields { AND }] "
	}		

	append sql "ORDER BY "
	if { $field_name eq "grinder_setting" } {
		# TODO Include sorting in data dictionary!
		append sql "TRIM($field_name)"
	} elseif { $use_lookup_table == 1 }  { 
		if { $type1_db_table ne ""} {
			append sql "${type1_db_table}.sort_number,"
		}
		append sql "sort_number"
	} else {
		append sql "MAX(shot.clock)"
	}
	
	if { [llength $fields] == 1 } {
		return [db eval "$sql"]
	} else {
		array set result {}
		
		db eval "$sql LIMIT 1" columns break
		set fields $columns(*)
		
		foreach fn $fields { set result($fn) {} }
		db eval "$sql" {
			for {set i 0} {$i < [llength $fields]} {incr i 1} {
				lappend result([lindex $fields $i]) [subst $[lindex $fields $i]]
			}
		}
		return [array get result]
	}
}

# Returns data for shots that use a given category.  
# 'field_name' must be available in the data dictionary with data_type=category.
# 'return_what' is a list of column names to return, or 'count' for just the number of shots. If a single column
#	is requested, a list is returned. If more than one column is returned, returns an array with one list per 
#	column.
# 'args' provide 'type' values that must be matched in the target db table (e.g. for an equipment item, its equipment type).
proc ::plugins::SDB::shots_using_category { field_name value {return_what clock} args } {
	set db [get_db]
	
	lassign [::plugins::DGUI::field_lookup $field_name {data_type db_table db_type_column1 db_type_column2}] \
		data_type db_table db_type_column1 db_type_column2
	if { $data_type ne "category" } { return {} }
	
	if { $db_table eq "shot" } {
		if { $return_what eq "count" } { 
			set sql "SELECT COUNT(clock) "
		} else { 
			set sql "SELECT [join $return_what ,] "
		}
		append sql " FROM V_shot WHERE removed=0 AND $field_name=[string2sql $value] ORDER BY clock DESC"
	} else {
		if { $return_what eq "count" } { 
			set sql "SELECT COUNT(DISTINCT t.clock) " 
		} else { 
			set sql "SELECT DISTINCT [join $return_what ,] " 
		}
		append sql "FROM $db_table t INNER JOIN V_shot s ON t.clock=s.clock WHERE t.$field_name=[string2sql $value] "
		if { $db_type_column1 ne "" && [llength $args] > 0 } {
			append sql "AND $db_type_column1=[string2sql [lindex $args 0]] " 
		}
		if { $db_type_column2 ne "" && [llength $args] > 1 } {
			append sql "AND $db_type_column2=[string2sql [lindex $args 1]] " 
		}
		append sql "ORDER BY t.clock DESC"
	}
		
	if { [llength $return_what] == 1 } {
		return [db eval "$sql"]
	} else {
		array set result {}
		foreach fn $return_what { set result($fn) {} }
		db eval "$sql" {
			for {set i 0} {$i < [llength $return_what]} {incr i} {
				lappend result([lindex $return_what $i]) [subst $[lindex $return_what $i]]
			}
		}		
		return [array get result]
	}
}

# Updates a category value both in the database and in all shot files that used it.
# Returns the list of modified shot file names (basenames only, no path nor extension).
proc ::plugins::SDB::update_category { field_name old_value new_value { update_files 1 } } {
	variable settings 	
	
	set db [get_db]
	set filenames {}
	set clocks {}
	set new_value [string trim $new_value]
	
	set sql "SELECT clock, filename FROM shot WHERE $field_name=[string2sql $old_value]"
	db eval "$sql" {
		lappend clocks $clock
		lappend filenames $filename
	}

	set i 0
	foreach shot_file $filenames {
		# Update in shot history files			
		if { [file exists "[homedir]/history/${shot_file}.shot"] } {
			set path "[homedir]/history/${shot_file}.shot"		
		} elseif { [file exists "[homedir]/history_archive/${shot_file}.shot"] } {
			set path "[homedir]/history_archive/${shot_file}.shot"		
		} else {
			set path {}
		}
			
		if { $path eq "" } {
			set fmtime "NULL"
		} else {
			if { $update_files == 1 } {
				array set new_settings {} 
				set new_settings($field_name) $new_value 
				modify_shot_file $path new_settings
			}			
			set fmtime [file mtime $path]
		}
	
		# Update in database
		if { $settings(db_persist_desc) == 1 } {
			set sql "UPDATE shot SET file_modification_date=COALESCE($fmtime,file_modification_date), $field_name=[string2sql $new_value] WHERE clock=[lindex $clocks $i]"
			db eval "$sql"
		}
		
		incr i
	}

#	# Update in-memory variables, if they happen to use that category value
#	if { $::settings($field_name) eq $old_value } {
#		set ::settings($field_name) $new_value
#		::DYE::define_last_shot_desc
#	}
#	if { $::DSx_settings(past_$field_name) eq $old_value } {
#		set ::DSx_settings(past_$field_name) $new_value
#		::DYE::define_past_shot_desc
#	}
#	if { $::DSx_settings(past_${field_name}2) eq $old_value } {
#		set ::DSx_settings(past_${field_name}2) $new_value
#		::DYE::define_past_shot_desc2
#	}
#	if { $::plugins::SDB::settings(next_$field_name) eq $old_value } {
#		set ::plugins::SDB::settings(next_$field_name) $new_value
#		::DYE::define_next_shot_desc
#	}	
#	if { $::DYE::DE::data($field_name) eq $old_value } {
#		set "::DYE::DE::data($field_name)" $new_value
#	}
	
	update_last_updated
#	::save_settings
#	::save_DSx_settings
#	::DYE::save_settings
	
	return $filenames
}
	
# Updates a category value both in the database and in shot files that used it.
# Returns the list of modified shot file names (basenames only, no path nor extension).
# 'field_name' must be available in the data dictionary with data_type=category.
proc ::plugins::SDB::NEW_update_category { field_name old_value new_value { use_specified_files 1 } { files_to_modify {} } args } {
	set db [get_db]
	set filenames {}
	set clocks {}
	set update_shots 1
	
	if { [string trim $old_value] eq "" || $old_value eq $new_value } { return }
	set new_value [string trim $new_value]
	lassign [::plugins::DGUI::field_lookup $field_name {data_type db_table db_type_column1 db_type_column2 \
		shot_field lookup_table desc_section}] \
		data_type db_table db_type_column1 db_type_column2 shot_field lookup_table desc_section
	if { $data_type ne "category" } { return }

	if { $use_specified_files == 1 && [llength $files_to_modify] == 0 } { 
		set update_shots 0
	}

	if { $db_table eq "shot" } {
		set sql "SELECT s.clock, s.filename FROM shot s WHERE s.removed=0 AND $field_name=[string2sql $old_value] "
		set sql_count "SELECT COUNT(clock) FROM shot s WHERE s.removed=0 AND $field_name=[string2sql $old_value] "
	} else {
		set sql "SELECT s.clock, s.filename FROM $db_table t INNER JOIN V_shot s ON t.clock=s.clock 
			WHERE s.removed=0 AND $field_name=[string2sql $old_value] "
		set sql_count "SELECT COUNT(DISTINCT s.clock) FROM $db_table t INNER JOIN V_shot s ON t.clock=s.clock 
			WHERE s.removed=0 AND $field_name=[string2sql $old_value] "			
	}
	if { $use_specified_files == 1 } {
		if { [llength $files_to_modify] == 0 } { set update_shots 0 }
		append sql "AND s.filename IN ([strings2sql $files_to_modify]) "
	}
	if { $db_type_column1 ne "" && [llength $args] > 0 } {
		append sql "AND $db_type_column1=[string2sql [lindex $args 0]] "
		append sql_count "AND $db_type_column1=[string2sql [lindex $args 0]] "
	}
	if { $db_type_column2 ne "" && [llength $args] > 1 } {
		append sql "AND $db_type_column2=[string2sql [lindex $args 1]] "
		append sql_count "AND $db_type_column1=[string2sql [lindex $args 0]] "
	}
	append sql "ORDER BY s.clock DESC"	

	set n_total_shots_using_category [db eval "$sql_count"]
		
	set i 0
	if { $update_shots == 1 } {
		db eval "$sql" {
			lappend clocks $clock
			lappend filenames $filename
		}
	
		foreach shot_file $filenames {
			# Update shot history files
			set path [get_shot_file_path $shot_file]

			if { $path eq "" } {
				set fmtime "NULL"
				msg "ERROR: can't find shot file ${shot_file}.shot for modifying category $category"
			} else {
				array set new_settings {}
				if { $db_table eq "shot" } {
					set new_settings($field_name) $new_value
				} else {
					# This works for both equipment_type and equipment_name, review in future cases
					set new_settings("~$field_name") [list $old_value $new_value] 	
				}
				modify_shot_file $path new_settings
				
				set fmtime [file mtime $path]
			}
		
			# Update database
			if { $::plugins::SDB::settings(db_persist_desc) == 1 } {
				set sql "UPDATE shot SET file_modification_date=COALESCE($fmtime,file_modification_date)"
				if { $db_table eq "shot" } {
					append sql ",$field_name=[string2sql $new_value]" 
				}						
				append sql " WHERE clock=[lindex $clocks $i] AND $field_name=[string2sql $old_value]"
				db eval "$sql"
				
				if { $db_table ne "shot" } {
					set sql "UPDATE $db_table SET $field_name=[string2sql $new_value] 
						WHERE clock=[lindex $clocks $i] AND $field_name=[string2sql $old_value] "
					if { $db_type_column1 ne "" && [llength $args] > 0 } {
						append sql "AND $db_type_column1=[string2sql [lindex $args 0]] " 
					}
					if { $db_type_column2 ne "" && [llength $args] > 1 } {
						append sql "AND $db_type_column2=[string2sql [lindex $args 1]] " 
					}						
					db eval "$sql"
				}
			}
			
			incr i
		}
		
		if { $i > 0 } update_last_updated
	}
	
	# Update category db lookup table, if necessary (other_equipment elements). Because the change may have only
	# affected some shots, we don't know whether we need to update the category (no longer used), so we check
	# existence first.
	if { $lookup_table ne "" && $n_total_shots_using_category == $i} {
		# Are there still shots using the old value? If there is, do nothing. If there aren't, update the lookup table. 
	
		set sql "UPDATE $lookup_table SET $field_name=[string2sql $new_value] WHERE $field_name=[string2sql $old_value] "
		if { $db_type_column1 ne "" && [llength $args] > 0 } {
			append sql "AND $db_type_column1=[string2sql [lindex $args 0]] "
		}
		if { $db_type_column2 ne "" && [llength $args] > 1 } {
			append sql "AND $db_type_column2=[string2sql [lindex $args 1]] "
		}

		db eval "$sql"
		
		if { $desc_section eq "equipment" } { ::plugins::SDB::update_equipment_categories }
		
		# TODO: Use the data dictionary 
#		if { $desc_section eq "equipment" } {
#			if { $field_name eq "equipment_type" } {
#				set existing_new_type [db eval { SELECT equipment_name FROM equipment_type WHERE equipment_name=$new_value }]
#				if { $existing_new_type eq "" } {
#					db eval { UPDATE equipment_type SET equipment_name=$new_value WHERE equipment_name=$old_value }
#				} else {
#					db eval { DELETE FROM equipment_type WHERE equipment_name=$old_value }
#				}
#				db eval { UPDATE equipment SET equipment_type=$new_value WHERE equipment_type=$old_value }
#			} elseif { $field_name eq "equipment_name" } {
#				set existing_new_equipment [db eval { SELECT equipment_name FROM equipment 
#					WHERE equipment_name=$new_value AND equipment_type=$equipment_type }]
#				if { $existing_new_equipment eq "" } {
#					db eval { UPDATE equipment SET equipment_name=$new_value 
#						WHERE equipment_name=$old_value AND equipment_type=$equipment_type }
#				} else {
#					db eval { DELETE FROM equipment WHERE equipment_name=$old_value AND equipment_type=$equipment_type }
#				}										
#			}
#			::plugins::SDB::update_equipment_categories
#		}		
	}
	
#	# Update in-memory variables, if they happen to use that category value
#	if { $db_table eq "shot" } {
#		if { [info exists ::settings($field_name)] && $::settings($field_name) eq $old_value } {
#			set ::settings($field_name) $new_value
#			::DYE::define_last_shot_desc
#		}
#		if { [info exists ::DSx_settings(past_$field_name)] && $::DSx_settings(past_$field_name) eq $old_value } {
#			set ::DSx_settings(past_$field_name) $new_value
#			::DYE::define_past_shot_desc
#		}
#		if { [info exists ::DSx_settings(past_${field_name}2)] && $::DSx_settings(past_${field_name}2) eq $old_value } {
#			set ::DSx_settings(past_${field_name}2) $new_value
#			::DYE::define_past_shot_desc2
#		}
#		if { [info exists ::plugins::SDB::settings(next_$field_name)] && $::plugins::SDB::settings(next_$field_name) eq $old_value } {
#			set ::plugins::SDB::settings(next_$field_name) $new_value
#			::DYE::define_next_shot_desc
#		}	
#		if { [info exists ::DYE::DE::data($field_name)] && $::DYE::DE::data($field_name) eq $old_value } {
#			set "::DYE::DE::data($field_name)" $new_value
#		}
#	} elseif { $shot_field ne "" } {
#		if { [info exists ::settings($shot_field)] && $::settings($shot_field) ne "" } {
#			set ::settings($shot_field) [::DYE::modify_$shot_field $::settings($shot_field) $field_name $old_value $new_value]
#		}
#		if { [info exists ::DSx_settings(past_$field_name)] && $::DSx_settings(past_$shot_field) ne "" } {
#			set ::DSx_settings(past_$shot_field) [::DYE::modify_$shot_field $::DSx_settings(past_$shot_field) \
#				$field_name $old_value $new_value]
#		}
#		if { [info exists ::DSx_settings(past_${field_name}2)] && $::DSx_settings(past_${shot_field}2) ne "" } {
#			set ::DSx_settings(past_${shot_field}2) [::DYE::modify_$shot_field $::DSx_settings(past_${shot_field}2) \
#				$field_name $old_value $new_value]
#		}
#		if { [info exists ::plugins::SDB::settings(next_$field_name)] && $::plugins::SDB::settings(next_$shot_field) ne "" } {
#			set ::plugins::SDB::settings(next_${shot_field}) [::DYE::modify_$shot_field $::plugins::SDB::settings(next_$shot_field) \
#				$field_name $old_value $new_value]
#		}	
#		if { [info exists ::DYE::DE::data($field_name)] && $::DYE::DE::data($field_name) ne "" } {
#			set "::DYE::DE::data($shot_field)" [::DYE::modify_$shot_field $::DYE::DE::data($shot_field) \
#				$field_name $old_value $new_value]
#		}
#	} else {
#		msg "DYE ERROR: DB::update_category - can't modify $field_name value in memory variables"
#	}
#	
#	::save_settings
#	::save_DSx_settings
#	::DYE::save_settings
	
	return $filenames
}

# Adds a new category value to a lookup table. Note that categories that are entered directly in shots (like 
# 	grinder_model) don't have a lookup table and can't be added to.
# Returns the number of insertions done, 0 if none.
# 'args', if specified, gives extra column_name column_value pairs to insert.  
proc ::plugins::SDB::add_category { field_name new_value {type1 {}} {type2 {}} args } {
	set db [get_db]
	set new_value [string trim $new_value]
	if { $new_value eq "" } { return 0 }
	
	lassign [::plugins::DGUI::field_lookup $field_name {data_type db_type_column1 db_type_column2 lookup_table}] \
		data_type db_type_column1 db_type_column2 lookup_table
	if { $data_type ne "category" } { return }
	
	set fields {}
	set field_values {}
	lappend fields $field_name
	lappend field_values [string2sql $new_value]
	set where_conds {}
	if { $db_type_column1 ne "" && $type1 ne "" } {
		lappend where_conds "$db_type_column1=[string2sql $type1]"
		lappend fields "$db_type_column1"
		lappend field_values [string2sql $type1]
	}
	if { $db_type_column2 ne "" && $type2 ne "" } {
		lappend where_conds "$db_type_column2=[string2sql $type2]"
		lappend fields "$db_type_column2"
		lappend field_values [string2sql $type2]
	}
	
	if { [llength $args] > 0 } {
		for { set i 0 } { $i < [llength $args] } { incr i 2 } {
			if { [expr {$i+1}] < [llength $args] } {
				lappend fields [lindex $args $i]
				lappend field_values [lindex $args [expr {$i+1}]]
			}
		}
	}
	lappend fields "sort_number"
	lappend field_values "(SELECT (COUNT($field_name)+1)*10 FROM $lookup_table)"
	
	set check_sql "SELECT $field_name FROM $lookup_table WHERE $field_name=[string2sql $new_value] "
	if { $where_conds ne "" } { append check_sql " AND [join $where_conds { AND }]" }
		
	if { [db exists "$check_sql"] } { return 0 }
	
	set insert_sql "INSERT INTO $lookup_table ([join $fields ,]) VALUES ([join $field_values ,])"
	
	msg "add_category, insert_sql=$insert_sql"	
	db eval "$insert_sql"	
	return [db changes]
}

proc ::plugins::SDB::remove_category { field_name value {type1 {}} {type2 {}} } {
	set db [get_db]
	if { $value eq "" } { return 0 }

	set n_shots [shots_using_category $field_name $value "count" $type1 $type2]
	if { $n_shots > 0 } { return 0 }
	
	lassign [::plugins::DGUI::field_lookup $field_name {data_type db_type_column1 db_type_column2 lookup_table}] \
		data_type db_type_column1 db_type_column2 lookup_table
	if { $data_type ne "category" } { return }
	
	set sql "DELETE FROM $lookup_table WHERE $field_name=[string2sql $value]"
	if { $db_type_column1 ne "" && $type1 ne "" } {
		append sql " AND $db_type_column1=[string2sql $type1]"
	}
	if { $db_type_column2 ne "" && $type2 ne "" } {
		append sql " AND $db_type_column2=[string2sql $type2]"
	}

	db eval "$sql"
	return [db changes]
}

# Returns whether the database contains some chart series data.
proc ::plugins::SDB::has_shot_series_data {} {
	set db [get_db]
	return [db eval { SELECT EXISTS(SELECT 1 FROM shot_series LIMIT 1) }]
}

# Number of shots that have no chart series data.
proc ::plugins::SDB::n_shots_without_series {} {
	set db [get_db]
	return [db eval { SELECT COUNT(DISTINCT clock) FROM shot s LEFT JOIN shot_series ss ON s.clock=ss.shot_clock 
		WHERE ss.shot_clock IS NULL } ]
}

# List of distinct (previously typed) values of any category field. 
proc ::plugins::SDB::previous_values { field_name {exc_removed_shots 1} {filter {}} {max_items 500} } {
	set db [get_db]	
	lassign [::plugins::DGUI::field_lookup $field_name {data_type db_table lookup_table db_type_column1 db_type_column2}] \
		data_type db_table lookup_table db_type_column1 db_type_column2 
	if { $data_type eq "" } {
		msg "ERROR in proc previous_values, field_name '$field_name' not found in data dictionary"
		return
	}
	
	set fields {}
	set grouping_fields {}
	lappend fields "$field_name"
	lappend grouping_fields "$field_name"
	
	if { $db_table eq "shot" } {
		set sql "SELECT [join $fields ,] FROM shot "
	} else {
		set sql "SELECT [join $fields ,] FROM $db_table t INNER JOIN shot ON t.clock=shot.clock "
	}
	
	append sql "WHERE LENGTH(TRIM(COALESCE($field_name,''))) > 0 "
	if { $exc_removed_shots == 1  } { append sql "AND shot.removed=0 " }
	if { $filter ne "" } { append sql "AND $filter " }
	append sql "GROUP BY [join $grouping_fields ,] "
	append sql "ORDER BY MAX(shot.clock)"
	
	if { [llength $fields] == 1 } {
		return [db eval "$sql LIMIT $max_items"]
	} else {
		array set result {}
		
		db eval "$sql LIMIT 1" columns break
		set fields $columns(*)
				
		foreach fn $fields { set result($fn) {} }
		db eval "$sql LIMIT $max_items" {
			for {set i 0} {$i < [llength $fields]} {incr i 1} {
				lappend result([lindex $fields $i]) [subst $[lindex $fields $i]]
			}
		}		
		return [array get result]
	}
	
} 

# Deletes all chart series data.
proc ::plugins::SDB::delete_shot_series_data {} {
	set db [get_db]
	db eval { DELETE FROM shot_series }
}

### SDB CONFIGURATION PAGE ##########################################################################################

namespace eval ::plugins::SDB::CFG {
	variable widgets
	array set widgets {}
		
	# NOTE that we use "item_values" to hold all available items, not "items" as the listbox widget, as we need
	# to have the full list always stored. So the "items" listbox widget does not have a list_variable but we
	# directly add to it.
	variable data
	array set data {
		page_name "::plugins::SDB::CFG"
		db_status_msg {}
		sql_and_schema_versions {}
	}	
}

# Added to context actions, so invoked automatically whenever the page is loaded
proc ::plugins::SDB::CFG::show_page {} {
	variable data
	set data(sql_and_schema_versions) "[translate {SQLite version}] $::plugins::SDB::sqlite_version
[translate {Schema version}] #$::plugins::SDB::db_version"
	
	if { ![plugins enabled SDB] } {
		::plugins::DGUI::disable_widgets "resync_db* rebuild_db*" [namespace current] 
	}
}

proc ::plugins::SDB::CFG::setup_ui {} {
	variable widgets
	variable db
	set page [namespace current]

	# HEADERS
	::plugins::DGUI::add_page $page -title [translate "Shot DataBase Plugin Settings"] \
		-buttons_loc center -cancel_button 0 
	#-add_bg_img 0 
		
	set y 250
	::plugins::DGUI::add_text $page 600 $y [translate "General options"] -font_size $::plugins::DGUI::section_font_size \
		-anchor "center" -justify "center" 	
	::plugins::DGUI::add_text $page 1900 $y [translate "Manage database"] -font_size $::plugins::DGUI::section_font_size \
		-anchor "center" -justify "center"	
	
	# LEFT SIDE
	set x_label 200
	
	::plugins::DGUI::add_checkbox $page ::plugins::SDB::settings(db_persist_desc) $x_label [incr y 100] \
		::plugins::SDB::CFG::db_persist_desc_change -use_page_var 0 -widget_name db_persist_desc \
		-label [translate "Store shot descriptions on database"]
	
	::plugins::DGUI::add_checkbox $page ::plugins::SDB::settings(db_persist_series) $x_label [incr y 100] \
		::plugins::SDB::CFG::db_persist_series_change -use_page_var 0 -widget_name db_persist_series \
		-label [translate "Store chart series on database"]
	
	::plugins::DGUI::add_checkbox $page ::plugins::SDB::settings(sync_on_startup) $x_label [incr y 100] \
		::plugins::SDB::CFG::sync_on_startup_change -use_page_var 0 -widget_name sync_on_startup \
		-label [translate "Resync database to history on startup"]
	
	# RIGHT SIDE
	set x_label 1600; set y 350
	::plugins::DGUI::add_button2 $page resync_db $x_label $y [translate "Resync\rdatabase"] \
		"" sync ::plugins::SDB::CFG::resync_db
	
	::plugins::DGUI::add_variable $page [expr {$x_label+$::plugins::DGUI::button2_width+75}] $y {[translate {Last full sync}]:
[clock format $::plugins::SDB::settings(last_sync_clock) -format $::plugins::SDB::friendly_clock_format]\r 
[translate {# Analyzed}]: $::plugins::SDB::settings(last_sync_analyzed)
[translate {# Added}]: $::plugins::SDB::settings(last_sync_inserted)
[translate {# Modified}]: $::plugins::SDB::settings(last_sync_modified)
[translate {# Archived}]: $::plugins::SDB::settings(last_sync_archived)
[translate {# Unarchived}]: $::plugins::SDB::settings(last_sync_unarchived)
[translate {# Removed}]: $::plugins::SDB::settings(last_sync_removed)
[translate {# Unremoved}]: $::plugins::SDB::settings(last_sync_unremoved)} \
		-widget_name "last_sync" -fill $::plugins::DGUI::default_shot_desc_font_color
	
	incr y [expr {$::plugins::DGUI::button2_height+100}]
	::plugins::DGUI::add_button2 $page rebuild_db $x_label $y [translate "Rebuild\rdatabase"] \
		"" db ::plugins::SDB::CFG::rebuild_db

	incr y [expr {$::plugins::DGUI::button2_height+100}]
	::plugins::DGUI::add_variable $page $x_label $y {$::plugins::SDB::progress_msg} -fill $::plugins::DGUI::remark_color

	incr y 100
	::plugins::DGUI::add_variable $page $x_label $y {$::plugins::SDB::CFG::data(db_status_msg)} -fill $::plugins::DGUI::error_color
	
	# Auto-updater
#	incr y 60
#	::plugins::DGUI::add_button2 $page update_plugin $x_label $y [translate "Update\rplugin"] 1 cloud_download_alt \
#		::plugins::SDB::CFG::update_plugin_click
#		
#	::plugins::DGUI::add_variable $page [expr {$x_label+$::plugins::DGUI::button2_width+60}] $y \
#		{$::plugins::SDB::CFG::data(update_plugin_msg)} -width 220 -fill $::plugins::DGUI::remark_color -has_button 1 \
#		-button_cmd ::plugins::SDB::CFG::show_latest_plugin_description
	
	# FOOTER (versions)
	::plugins::DGUI::add_variable $page 2150 1520 {$::plugins::SDB::CFG::data(sql_and_schema_versions)} \
		-justify center -anchor center
	
	::add_de1_action $page ::plugins::SDB::CFG::show_page
}

proc ::plugins::SDB::CFG::db_persist_desc_change {} {
	#set ns [namespace current]	
	plugins save_settings SDB
}

proc ::plugins::SDB::CFG::db_persist_series_change {} {
	set ns [namespace current]
	plugins save_settings SDB	
	if { ![plugins enabled SDB] } return
	
	if { $::plugins::SDB::updating_db == 1 } {
		set ::plugins::SDB::CFG::data(db_status_msg) [translate "Database busy. Try later"]
		set ::plugins::SDB::settings(db_persist_series) [expr {!$::plugins::SDB::settings(db_persist_series)}]
		after 3000 { set ::plugins::SDB::CFG::data(db_status_msg) "" }
		return
	}
	
	if { $::plugins::SDB::settings(db_persist_series) == 1 } {
		if { [::plugins::SDB::n_shots_without_series] > 0 } {
			set answer [tk_messageBox -message "[translate {Do you want to add missing shot series to the database now?}]\r\r\
				[translate {(if you select 'No', only the series for new shots will be stored)}]" \
				-type yesnocancel -icon question]
			if { $answer eq "yes" } { 
				borg spinner on	 
				::plugins::DGUI::disable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
				if {[catch { ::plugins::SDB::populate 0 1 1 1 } err] != 0} {
					SDB::msg "ERROR populating DB: $err"
					set ::plugins::SDB::progress_msg [translate "Failed to sync DB:\r$err"]
					update	
				}
				::plugins::DGUI::enable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
				borg spinner off
				borg systemui $::android_full_screen_flags
				after 3000 { set ::plugins::SDB::progress_msg "" }
			} elseif { $answer eq "cancel" } {
				set ::plugins::SDB::settings(db_persist_series) 0
				return
			}
		}
	} else {
		if { [::plugins::SDB::has_shot_series_data] } {
			set answer [tk_messageBox -message "[translate {The database currently contains some shot series data.}]\r\r\
				[translate {Do you want to remove them? (select 'No' to maintain them)}]" \
				-type yesnocancel -icon question]
			if { $answer eq "yes" } { 
				::plugins::DGUI::disable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
				::plugins::SDB::delete_shot_series_data
				::plugins::DGUI::enable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
			} elseif { $answer eq "cancel" } {
				set ::plugins::SDB::settings(db_persist_series) 1
				return
			}
		}
		
	}
	
}

proc ::plugins::SDB::CFG::sync_on_startup_change {} {
	plugins save_settings SDB
}

proc ::plugins::SDB::CFG::rebuild_db {} {
	say "" $::settings(sound_button_in)
	if { ![plugins enabled SDB] } return
	set ns [namespace current]
	
	if { $::plugins::SDB::updating_db == 1 } {
		set ::plugins::SDB::CFG::data(db_status_msg) [translate "Database busy. Try later"]
		after 3000 { set ::plugins::SDB::CFG::data(db_status_msg) "" }
		return
	}
	
	borg spinner on	
	::plugins::DGUI::disable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
	
	if {[catch { ::plugins::SDB::create 1 1 1 } err] != 0} {
		msg "ERROR recreating DB: $err"
		set ::plugins::SDB::progress_msg [translate "Failed to recreate DB:\r$err"]
		update
		after 3000 { set ::plugins::SDB::progress_msg "" }
		::plugins::DGUI::enable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
		borg spinner off
		borg systemui $::android_full_screen_flags
#		set ::plugins::SDB::updating_db 0
		return		
	}
	if {[catch { ::plugins::SDB::populate "" "" 1 } err] != 0} {
		msg "ERROR populating DB: $err"
		set ::plugins::SDB::progress_msg [translate "Failed to sync DB:\r$err"]
		update
		after 3000 { set ::plugins::SDB::progress_msg "" }
		::plugins::DGUI::enable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
		borg spinner off
		borg systemui $::android_full_screen_flags
		return				
	}
	
	::plugins::DGUI::enable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
	borg spinner off
	borg systemui $::android_full_screen_flags
	after 3000 { set ::plugins::SDB::progress_msg "" }
	say "" $::settings(sound_button_out)
}

proc ::plugins::SDB::CFG::resync_db {} {
	say "" $::settings(sound_button_in)
	if { ![plugins enabled SDB] } return
	set ns [namespace current]
	
	if { $::plugins::SDB::updating_db == 1 } {
		set ::plugins::SDB::CFG::data(db_status_msg) [translate "Database busy. Try later"]
		update
		after 3000 { set ::plugins::SDB::CFG::data(db_status_msg) "" }
		return
	}

	borg spinner on
	::plugins::DGUI::disable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
	
	if {[catch { ::plugins::SDB::populate "" "" 1 } err] != 0} {
		SDB::msg "ERROR populating DB: $err"
		set ::plugins::SDB::progress_msg [translate "Failed to sync DB:\r$err"]
		update		
	}

	::plugins::DGUI::enable_widgets {db_persist_series* rebuild_db* resync_db*} $ns
	borg spinner off
	borg systemui $::android_full_screen_flags
	after 3000 { set ::plugins::SDB::progress_msg "" }
	say "" $::settings(sound_button_out)
}

proc ::plugins::SDB::CFG::page_done {} {
	say [translate {Done}] $::settings(sound_button_in)
	page_to_show_when_off extensions
}