# Changelog - "Describe Your Espresso" Decent DE1 app plugin

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.23] - 2021-12-09

### Changed
- Fix bug showing the wrong shot duration on the Shot Selector when using a string filter. Reported by JoeD.

## [2.22] - 2021-12-08

### New
- Added setting `reset_next_plan` to auto-clear the next shot plan data after pulling each shot. It is exposed in the DYE settings page and can only be enabled when propagation is disabled. Should handle the workflow/use case presented by Bob Stern.
- New setting `date_input_format`, exposed in the DYE settings page, can take values "MDY", "DMY" or "YMD", with "MDY" as default. Replaces the previous `date_input_formats`. It is initialized to the closest matching format of the first item in `date_input_formats`, if it exists. Setting `date_input_formats` is removed.
- New setting `roast_date_format` defines how to show the roast date after it's entered.

### Changed
- Read from previous now ignores zero-valued fields for determining blank shots.
- Profiles imported from Visualizer whose title already include a folder ("&lt;folder&gt;/&lt;profile_name&gt;") now get the correct title ("Visualizer/&lt;profile_name&gt;"). Reported by Ricco Rosini.
- New more user-friendly roast date parser, using the new date settings. Allows entering partial dates (only day or day+month), using any field separator (spaces, hyphens, dashes...), month numbers or 3-letter abbreviations, full or abbreviated years ("21" or "2021"), and adding extra text after the date (e.g. "21/12/2021 Roast 2") while still correctly parsing the date for computing days off-roast.
- Update DYE page calculated/derived fields (days off-roast, enable/disable grinder setting, TDS) when data is cleared or imported.

## [2.21] - 2021-12-05

### New
- The Visualizer dialog, when on the next shot plan, now allows downloading any of the "Recently selected shots" in Visualizer. A summary of the shots is shown when the "Shared" option is selected.

### Changed
- Selecting shots in the Shot Selector dialog now works correctly irrespective of the values of settings variables `use_finger_down_for_tap` and `disable_long_press`. 
- Filtering shots in the Shot Selector by a search string is now performed in Tcl instead of passing it to SQLite like in previous versions. This is done because SQLite cannot perform case-insensitive searches on concatenated fields on the tablet build of Androwish (whereas on PC it works). This also improves responsiveness, but has the drawback that the search is performed only on the subset of shots downloaded in current filter and within the maximum number of rows (currently 500).
- Selection of shots in the Shot Selector when the preview panel is collapsed is now slightly faster, as the summary info is now not written to the preview Tk Text panel when not needed.

## [2.20] - 2021-11-30

### New
- New "Shot Selector" page dialog (`dye_shot_select_dlg`), replaces the plain listbox-based selector used previously in all instances where a shot can be selected in DYE.
- New option "Copy to next shot plan" in the "Edit data menu" allows to send data from the currently viewed shot in DYE to be used in the next shot plan.

## [2.19] - 2021-11-24

### New
- New "Profile Selector" page dialog (`dye_profile_select_dlg`)
- New option to compare to "Another profile" in the Profile Viewer page.
- New buttons on the profile settings "presets" and "editing" pages to directly launch the Profile Viewer and Profile Selector dialogs.
- New "Change profile" option on the "Manage" menu when in "Plan next shot" page.

### Changed
- Icon to launch DYE on Insight home page.
- Bigger tapping area in many buttons, using the new DUI `-tap_pad` option of dbuttons.

## [2.18] - 2021-11-18

### New
- The Profile Viewer can now compare profiles to their saved versions, and show a "differences only" version.

### Changed
- The textual representation of profiles has been improved, refactored and moved to `::profile::legacy_to_textual` in the base app, so it can be reused by all skin & plugin authors.

## [2.17] - 2021-11-14

### New
- New "Manage" button and matching dialog page `dye_managed_dlg` with menus to delete shots, export shots, view profiles, and go to the DYE settings page.
- Shots can be deleted from the history. They are actually moved to subfolder `de1plus/bin`, which is created if it doesn't exist, and flagged with removed=1 in the SDB database, so the removal can be manually undone.
- Shots can be exported to formats "Tcl .shot" (really just copied from `de1plus/history` to the target folder), CSV (only the main chart series), and JSON v2. The user is given the choice of format and destination path, which defaults to `de1plus/history/export`.
- New dialog to view profiles in a text form for any past shot or the currently selected one (through the "Plan next shot"). The dialog also gives the option to apply the profile to the next shot.
- Improve profile importing (command `plugins::DYE::import_profile`), now can be done from a shot or an array, plus the GUI is properly updated for the type of profile, and also it is ensure that it is sent to the DE1 in case an espresso is started immediately from the GHC. This works both for local history and Visualizer imports.

### Changed
- Improve handling of arguments in `plugins::DYE::open` (for launching DYE from MimojaCafe)

## [2.16] - 2021-11-08

### New
- Add setting variable `default_launch_action` with possible values `last`, `next` and `dialog` that determines what is done when the DYE icon or button is tapped. Its value can be set in a new section of the DYE settings page.
- Support for the new **Insight Dark** skin. New "Insight_Dark" DUI theme.
- Add `filelist.txt`.

### Changed
- Correct mispelled package name "zint**o**".
- DYE settings page use the new DUI widgets "dselector" and "dtoggle".
- Close the Visualizer dialog when selecting "Visualizer settings" and coming back.

## [2.15] - 2021-11-01

### Changed
- Hide the "download by code" controls in the dye_visualizer_dlg page if the visualizer_upload is not enabled, as they were being shown overlapping the browse controls.
- Avoid runtime errors if the zint package (that generates QR codes) is not available, as may happen in non-androwish installs.

## [2.14] - 2021-10-28

### New
- New dialog page `dye_which_shot_dlg` shows a menu of main DYE actions (plan next shot, describe last shot,
select shot, search shot and go to DYE settings). It is launched by long tapping the DYE icons/labels in Insight & DSx.
- New setting `relative_dates` makes DYE show shot dates relative to today (e.g. "25 minutes ago", "Yesterday at 07:55", or "4 days ago at 12:01"). This can be modified either on the DYE settings page, or tapping on DYE page title.
- Show "days off-roast" near the "Roast date" field, whenever the roast date can be parsed as a date. Input format can be modified by manually editing the new setting `input_date_formats`, which is a list of valid formats accepted by `clock scan`. Each format is tried from the first to the last until a parsing raises no error.
- Shot output date/time format can now also be user-modified through the new settings `date_output_format`, `time_output_format`and `time_output_format_ampm`.

### Changed
- The DYE icon in Insight home page now has a bigger tapping area.
- The top navigation buttons in the DYE page now have much bigger tapping areas.
- Update theme aspects for DYE top navigation buttons.
- Modify DYE page titles (shorter titles, replace "espresso" by "shot", capitalize "NEXT" and "LAST", remove "past")

## [2.13] - 2021-10-26

### New
- The "Edit data" dialog in the DYE page now allows selecting to which block of data any of the edit actions have to be applied, including the new option "Profile" that imports profiles from past shots. The profile option is only enabled on the "Next" shot plan.
- The "Browse" section in the Visualizer dialog now changes to "Download by code" on the "Next" shot plan, and allows to download shots of any user from Visualizer. This is only available with the new version 1.2 of the visualizer_upload extension, and only works with shots recently uploaded to Visualizer (as the profile was not kept in previous versions).

### Changed
- When the propagation subtitle is "Shot not saved to history", it is now shown in error (usually red, depends on theme) color.
- Prevent runtime errors and log warnings when DYE is launched on a brand new DE1app install with no shots on the history.

## [2.12] - 2021-10-17

### Changed
- Don't reset skin target variables in DSx and MimojaCafe if the next shot variables in DYE are cleared.
- Use the correct variables for storing target drink weight in MimojaCafe depending on bluetooth scale connected or not and `settings(settings_profile_type)`.
- Read from last and read from past shot now bring also the dose and yield.

## [2.11] - 2021-10-14

### Changed
- Make dose and yield (`grinder_dose_weight` and `drink_weight` settings variables) editable in the next shot plan.
  - Changes in next shot `grinder_dose_weight`, `drink_weight` and `grinder_setting` in the DYE page are now reflected in MimojaCafe home page, and viceversa.
  - Changes in next shot `grinder_dose_weight` and `drink_weight` in the DYE page are now reflected in DSx home page, and viceversa.

- Last & next shot summary description variables `last_shot_desc` and `next_shot_desc` are  now stored in DYE settings instead of being namespace variables, so they persist. This prevents the error of showing an empty `last_shot_desc` when restarting the app after v2.08 changes.
- DSx link to open last shot desc in DYE now launches DYE even if the last shot was not saved to history.

## [2.09/2.10] - 2021-10-12

### Changed
- Corrected a few bugs introduced by the refactoring of the last/next shot descriptions in v2.08 (reported by JoeD, Robert Jordan & TMC):

  - Next shot description was not being saved
  - Next shot summary string was not being updated when propagating last shot data (only visible in DSx)
  - Field "espresso_notes" was not being saved/loaded in next shot description in some scenarios.

## [2.08] - 2021-10-03

### Changed
- Now any edition in the DYE page is saved by default, even if leaving the page in abnormal ways
- Remove the cancel button, now there's an "Undo" equivalent action in the "Edit data" dialog
- Ok button moves to the center of the page 
- Moved all editing actions to a new "Edit data" dialog
- The visualizer button now launches a Visualizer dialog with options for upload, download, browse (direct or QR),
and see visualizer settings or enable visualizer
- Shots that are not saved to history now are shown with a message and all fields disabled, instead of showing
an error page as before. The old way closed the DYE page and prevented moving to other shots, which now is possible.
- Disabled dclickers or draters background colors now transparent
- Color of cursor in entries and multiline_entries modified to orange in DSx theme, to make it visible

## [2.07] - 2021-09-18

### Changed
- All DYE pages now have type=fpdialog
- Shot confirmation save dialog now uses dui_confirm_dialog instead of Tk message box
- Ensure -theme option is used in all calls to DUI dialogs

## [2.06] - 2021-07-26 (bundled with DE1app v1.37)

### Added
- DYE v3 prototype for testing, can be enabled on the settings page.
- New `dui::add::text` to add Tk widgets

### Changed
- `dui::add::text` now is `dui::add::dtext`
- Fix bug "can't set ::settings(grinder_dose_weight) to non-numeric"
- Fix bug under DSx, editing last shot from history page was not saving shot
- Initialize DYE added fields (drinker_name & repository_links) as metadata

## [2.03] - 2021-05-08

### Added
- New navigation menu on the main DYE page (top right) provides 3 options to search shots: select from a list, search, or call History Viewer (new one or DSx one)

### Changed
- Correct "cup" symbol name (now named "mug").
- Move package dependencies to preload to avoid problems when downgrading versions
- Set DYE_settings page through 'dui page add' instead of inside setup

## [2.01] - 2021-04-30

### Changed
- Change the Fontawesome symbol names to standard names.

## [2.00] - 2021-04-29

### Added
- New navigation menu on the main DYE page (top left) allow to move through the shot history. Specially useful under the Insight skin as it has no history viewer.

### Changed
- Migrated from a DSx plugin to a DE1app plugin. Could now potentially work with any skin, though currently it's only integrated with Insight, DSx and MimojaCafe.
- Namespaces GUI, IS, and NUME split-off to the new 'de1_dui' package integrated in the DE1app core app. GUI building now uses the DUI framework.
- Namespace DB split-off to new DE1app plugin "Shot DataBase" (SDB).
- Auto-update from GitHub functionality split-off to new DE1app plugin "GitHub Plugins".
- Upload to visualizer extra functionality moved to the visualizer_upload plugin.
- Corrected bug in the reset button in the Filter Shot History page, that was not resetting the stars.
- Search listboxes in the Filter Shot History page now show 'Skin' and 'Beverage type' and cannot choose the category 
already selected in the other listbox.
- 'web_browser' command removed as its changes to work on Windows have already been incorporated into the de1app.
- Listboxes now scroll correctly until the final elements.
- Size of text-based widgets like listboxes has been fixed to reduce collisions with other widgets when user changes font size.
- comes_from_sleep no longer needed in DE::load_page, now uses the more general mechanism 'previous_page'.

## [1.18] - [Unreleased]

### Added
- Completed the parametrization of the aspect. Now a different set of backgrounds, fonts, and colors can be defined
per skin/theme. All images used in buttons have been replaced by Fontawesome icons or canvas items.

## [1.17] - 2021-02-08

### Added
- Enable Visualizer auto-upload. "Upload to Visualizer" button on the main DYE page now toggles to 
"Re-Upload to Visualizer" instead of "See in Visualizer". New settings "auto_upload_to_visualizer" (default 0)
and "min_seconds_visualizer_auto_upload" (default 6), which can be set from the DYE Settings page.
Requested from @Miha Rehar, @TMC and @Jakub Olesky.
- Visualizer password is now hidden by default, this can be changed tapping the "eye" icon on its right.
- The 2 search criteria category listboxes in the Filter Shot History page now can be redefined by the user.
- New proc ::DYE::GUI::relocate_widget_wrt to help placing widgets relative to one another.

### Changed
- DE1app minimum required version increased to 1.34 (to ensure than "beverage_type" is defined).
- Listboxes default selectmode changed from "single" to "browse".
- On FSH page, the [Reset] buttons are now aligned dinamically using relocate_widget_wrt.

## [1.16] - 2021-02-06

### Added
- New plugin auto-update system from GitHub latest release (suggested by @TMC)
- New ::DYE::TXT page for single-page text entry (or just showing text if read-only).

### Changed
- Solved bug that settings initialized to an empty string were not being stored into DYE_settings.tdb.
- Solved bug reported by @Idan that having never put a chart on the right side of the History Viewer could raise
a runtime error in proc ::DYE::define_past_shot_desc2 when tapping on the "Temperature on/off" button.

## [1.14] - 2021-02-03

### Added
- New settings "last_shot_DSx_home_coords" and "next_shot_DSx_home_coords" to allow user-positioning or disabling of each shot desc & icon in the DSx home page. Specially useful for the new user-customizable DSx home page. 
- New page ::DYE::NUME to edit numeric values with an in-screen numeric pad, clicker arrows and past values.
Invoked by double tapping on any DYE numeric entry field. 

### Changed
- "Reset" button on Filter Shot History page wasn't clearing enjoyment ratings when they were showing as stars.
- Change all calls to opening pages to use "page_to_show_when_off", as suggested by John. Also start to use context 
actions for the DYE::DE page.
- Remove all borg spinner calls on page_load procs, that were causing the android bar to appear.
- Finished migration of all pages drawing (setup_ui procs) to use the GUI framework.
- Qualify every single proc declaration with its full namespace. 
- All pages names are now the full namespace, so all GUI functions have been simplified and adapted for it.
- GUI add_* commands now should work with any page, either from DYE or not. If the given page name does not start by "::" and does not have a "widgets" array, no attempt is done to add to its widgets collection.
- Reordering of code. Move general generic DE functions and data/variables to ::DYE.

## [1.13] - 2021-01-27
- New DB Schema version 4.
- Patches bug when grinder_dose_weight was empty or zero in the database, V_shot.shot_desc was NULL.
Also works if profile_title is empty (very first 2016 shot files), doesn't add '@' if there's no grinder setting,
and gets back TDS,EY & Enjoyment in shot descs.
- Make next not be emptied if propagation is disabled (suggested by Damian)
- Changed "focus .can" in hide_android_keyboard as suggested by Damian.
- Force hiding the android bar immediately on every page change.

## [1.12] - 2021-01-25
- Patches bug detected by Damian that restarting the app after changing next shot description loses the next shot 
description.

## [1.11] - 2021-01-24
- Patches bugs detected by @Jason C that changing the profile for next shot, then editing last shot, overwrites the 
wrong next profile on last shot file.
Essentially I shouldn't be calling ::save_espresso_rating_to_history in DYE::DE::save_description.  

## [1.10] - 2021-01-23
- Patches minor bugs introduced in 1.09.
    * Cup icon from screensaver was waking up the DE1 (reported by  Robert Fickel Robert )
    * Clickable area for the arrows in the EY & TDS fields was oversized.
    * EY & TDS fields had their maximum values swapped. 

## [1.09] - 2021-01-21
- New configuration page. Allows setting all plugin options, manage the database, and shows the status of last 
  Visualizer upload and last DB sync. All changes apply dymically, no need to restart the app.
- Better handling of Visualizer upload errors. Last result shown on the DYE settings page.
- Database storage of chart series is now done in a single SQL statement per shot, which is 60x faster, so enabling it is now perfectly feasible.
- Full synch of database to history and history_archive folders on every startup, detecting every added, modified, 
removed or archived shots (no longer "fast-check").
- Shots manually removed from the history and history_archive are still kept in the database, but no longer appear in  searches.
- Better formed shot description strings in listboxes, now unified coming from a DB view. No more empty " - " or " @ ". parts, and the ratio is shown.  
- Corrected runtime error when tapping the cup icon on the sleepsaver page and there is no chart on the DSx home page. Reported by Pedro Ponce de León. 	Profited to improve how DE::load_page handles, now returns 0 or 1, and an 
informative message is shown if the description could not be loaded. 
- Usability improvement: When a category is empty (often for first-time users), shows a message explaining that it 
gets filled from current & past description data. Coming from bug report by Jakub Oleksy.
- Usability improvement: Tapping "Cancel" on the main DYE page now checks if some data has been modified and if it 
has, it ask for user confirmation before cancelling. 
- Usability improvement: UI elements that are disabled are now homogeneous (same color, apply to all labels & images)
- Added "hide_android_keyboard" as the final line of every load_page proc.
- Introduce new GUI namespace to encapsulate GUI code like widgets creation, parameterization of aspect variables
 	(colors, fonts, etc.) This should facilitate future migration to DE1 extension system.
- Parameterization of metadata fields in a data dictionary (not in use yet)
- More runtime info (mainly SQL) written to log.txt file if log is activated, which should facilitate bug solving. 
- New database initialization procedure "DB::init" and other DB-related code refactorings.
- load_shot refactored to simplify code
- If on Android, check there's wifi before launching Visualizer upload. If not, tells the user.
- Fails if you try to use a database schema version higher that the used by the current version of the plugin.
- New star-ratings optional UI to enter and search Enjoyment. Suggested by Damian. Activated by default, can revert 
to previous system in the settings page.
- Parameterization of metadata fields in a data dictionary (USE) 	 
- New field "drinker_name" in the People section.

## [1.08] - 2021-01-16
- Patches 2 bugs introduced in 1.07:
    * Runtime error when Visualizer credentials are not introduced in DYE_settings.tdb
    * Runtime error for invoking http::cleanup on the catch of the main request 

## [1.07] - 2021-01-15
- Correct bug spotted by @Andreas D'Hollandere on first run of DSx+DYE or removal of DSx_settings.tdb:
- Tests all DSx_settings/settings variables exist in reset_gui_starting_espresso_leave_hook, to prevent error on 
first-time installs or accidental removal of settings.tdb/DSx_settings.tdb
- Check existance of ::DSx_settings(live_graph_time) to enter the DYE_describe_espresso page for "current", to 
prevent error on first-time installs or accidental removal of settings.tdb/DSx_settings.tdb
- Check existance of ::DSx_settings(past_file_name(2)) to enter the DYE_describe_espresso page for "past" or 
"past2" in History Viewer, to prevent error on first-time installs or accidental removal of settings.tdb/DSx_settings.tdb
- Requires DSx 4.39
- Visualizer integration!!!
- Corrected bug reported by @Jakub Oleksy that tapping on a category dropdwon without actual values would freeze the application (missing "borg spinner off" when returning early from IS::load_page)

## [1.06] - 2021-01-14
- Corrects version 1.05 bug that produced a "unable to open database file" error (due to using [history] instead of [homedir])
- Declares 1.06 version according to DSx 4.38 new versioning system.

## [1.05] - 2021-01-14
- New dropdown for grinder setting, shows per-grinder model past settings (requested by Ed Laufer), sorted 
lexicographically (unlike other categories that are sorted by last used)
- All description fields now have whitespace trimmed (requested by Ed Laufer)
- If the database file from the DYE_settings is not found at startup, it is reset to its default value. Also now
the relative instead of the absolute path is stored, preventing "Unable to open database" errors when DYE_settings 
are moved from tablet to computer and viceversa (related to bug reported by Bob Stern) 
- Corrected bug using settings(espresso_clock) which may be undefined in a new install. Also, set the shot data(clock) in DE::load_description(), and remove 'clock' from extra_shot_fields (related to bug reported by Bob Stern)
- Listbox to select previous shots to import its description data now only shows shots with some data actually filled.
- "Dropdown" categories (roaster, beans, etc.) item selection page now shows the currently selected value in the 
description page even if it's new one and not yet added to the database.
- Checks the minimum required versions of both DE1app and DSx are installed, otherwise fails on startup.

## [1.04] - 2021-01-12
- Make setting propagate_previous_shot_desc=0 work correctly (bug reported by Robert Fickel)
- Added GPLv3 license mention in the source code header.

## [1.03] - 2021-01-09
- Solve runtime error when modifying a category in a file that has been manually removed from the history folder.
- Solve runtime error in the History Viewer when filters have been set that select a file that is indexed in the 
database but has been removed from the history/history_archive folder.

## [1.02] - 2020-12-26
- Many internal changes, including bugs fixes and a complete refactoring of the code to use namespaces.
- Dose and drink weight fields now appear in the "Describe your espresso" page for users that don't use a bluetooth 
scale (request from Idan)
- The propagation of descriptive data from one shot to the next one is now under user control (request from Roger Jordan)
 - The page for selecting past entered categories gains two new textboxes, one on top for filtering the shown 
categories, and one on bottom to bulk-modify existing values throughout the whole history.

## [1.00] - 2020-12-16
- New "Describe your espresso" page for editing basic shot metadata in a single page, with the possibility of 
recovering previously typed values of all categories from listboxes in the new "Item select" page.
- Allows describing both the last and next shots from the home DSx page, and any past shot from the History Viewer.
- Shows shot summary descriptions (beans, grinder and extraction) for next and last shots in the home DSx page, and 
for shots selected in both left and right sides of the History Viewer.
- New "Filter shot history" page to filter and sort the shots being shown in the History Viewer by different criteria.
- Icon in the scrensaver page to allow rating your last shot without waking up the DE1.
