# Changelog - "Shot DataBase" Decent DE1app plugin

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.16] - 2021-11-?

### Changed
- Ensure in proc `plugins::SDB::modify_shot_file` that chart series in modified shot files are saved in exactly the same order as in the original shot by `shot::create_legacy`. This may be related to the duplicated Visualizer shots reported by Ricco Rosini.

## [1.15] - 2021-11-08

### New
- Add `filelist.txt`.

### Changed
- Avoid errors when shots log longer `espresso_elapsed` charts than other series (reported by Jimmy Leow1). Now only stores in the DB to the shortest length between `espresso_elapsed`, `espresso_pressure` and `espresso_flow` in proc `persist_shot`, and ensures any empty value is set to NULL.

## [1.14] - 2021-11-01

### Changed
- Add chart series `espresso_resistance` and `espresso_resistance_weight` in proc `modify_shot_series`, so they can be uploaded to Visualizer, preventing duplicated shot files (as regular Visualizer auto-upload includes them).

## [1.13] - 2021-10-26

### New
- Proc `load_shot` now can load profiles

### Changed
- Proc `load_shot` has 3 new optional arguments for what to load (chart series, description and/on profile)

## [1.11] - 2021-10-05

### Changed
- Fix saving of `drink_weight` under MimojaCafe in `save_espresso_to_history_hook`

## [1.10] - 2021-10-04

### Changed
- If there is no bluetooth scale connected, so that `settings(drink_weight)` is zero at the end of a shot, save the
target `drink_weight` in the shot, as defined in the skin (DSx & MimojaCafe) or in the DYE extension (`next_drink_weight`). Also updates `$::DSx_settings(live_graph_weight)` on DSx.

## [1.09] - 2021-10-03

### Changed
- Ensure empty numeric values are set to 0 in `modify_shot_file`.

## [1.08] - 2021-09-18

### Changed
- `get_shot_file_path` now searches the database first to match a clock value to a filename, as different
systems (e.g. Android vs Windows 10) may format clock values differently.
- The SDB_settings page now has type "fpdialog".

## [1.07] - 2021-07-28 (Bundled with DE1app 1.37)

### Changed
- Increase TDS maximum value to 25%.
- `load_shot` now uses new metadata package.
- Ensure NULL values on all series in case they're shorter than elapsed.

## [1.06] - 2021-05-08

### Changed
- Don't raise a runtime error if parsing a shot file fails while synchronizing. Only log an error and show the total number of errors in a new line in the settings page
- Sort categories in FSH page by most recently used first
- Move package dependencies to preload to avoid problems when downgrading versions
- Set DYE_settings page through 'dui page add' instead of inside setup


## [1.05] - 2021-04-30

### Changed
- Change the Fontawesome symbol names to standard names.

## [1.04] - 2021-04-29

### Changed 
- Ensure the required minimum version of the DE1app is used (v1.36 for this plugin version)
- Use DUI instead of DGUI to setup the settings page.
- Copy shots.db from the DSx plugin on first install.
- Data dictionary functions are back, now that the DGUI plugin is obsolete.

## [1.03] - 2021-03-29

### Changed 
- Patch bug when $::settings(repository_links) was not initialized.
- Use Jeff K's new events system to hook when a shot is finished.

## [1.02] - 2021-03-01 (Bundled with DE1app 1.34.?)

### Changed 
- Adapt to new plugins and logging systems in 1.34.14
- Define symbols used in the plugin on preload (new DGUI proc set_symbols)

## [1.01] - 2021-02-21 (Bundled with DE1app 1.34.14)

### Changed
- Data dictionary functions moved to DGUI plugin, to avoid circular dependencies.
- `init` proc moved to `main`.
- Handle dependencies using the proposed changes to the extensions system.
- New proc `db_path` returns the path to the database (previously hardcoded).

## [1.00] - 2021-02-17 (Bundled with DE1app 1.34.11)

### Changed
- Initial code split off the DB namespace from the [DSx DYE plugin](https://github.com/ebengoechea/dye_de1app_dsx_plugin/blob/main/changelog.md).
- Added structure to work as a DE1app plugin instead of a DSx plugin.
- Remade `db_close` to prevent runtime errors if called more than once.
- Define which procs are namespace-exported.
- New settings `sync_on_startup` and `log_sql_statements`.
- Added settings page.