# "Describe Your Espresso" DE1app plugin

"Describe Your Espresso" (DYE) is a plugin for the [Decent Espresso machine](https://decentespresso.com/) [DE1 app](https://github.com/decentespresso/de1app).

It improves the default shot logging functionality, allowing users to edit, modify and use shot metadata such as beans, grinder, EY & TDS or espresso description, for any shot in the history.

By Enrique Bengoechea (with lots of copy/paste/tweak from Damian, John, Johanna and Barney's code!)

Manual available on [Decent Diaspora site](https://3.basecamp.com/3671212/buckets/7351439/documents/3344125879) (Decent owners only): 

## Features

1. "Describe your espresso" accesible from home screen with a single click, for both next and last shots.

2. All main description data in a single screen for easier data entry.
    - Irrelevant options ("I weight my beans" / "I use a refractometer") are removed.
    
3. Facilitate data entry in the UI:
    - Numeric fields can be typed directly, using clicker arrows, or double tapping on them to launch a full-page numeric-pad.
    - Keyboard return in non-multiline entries take you directly to the next field.
    - Choose categories fields (bean brand, type, grinder, etc) from a list of all previously typed values.
    - Star-rating system for Enjoyment
    - Mass-modify past entered categories values at once.
    
4. Description data from previous shots can now be retrieved and modified:
    - A summary is shown on the DSx History Viewer page, below the profile on both the left and right shots.
    - When that summary is clicked, the describe page is open showing the description for the past shot, which can be modified

5. Create a SQLite database of shot descriptions.
    - Populate on startup
    - User decides to store only shot descriptions or shot description+shot series.
    - Update whenever there are new shots or shot data changes
    - Update (synchronize) on startup when a shot file has been added, changed or deleted on disk, or trigger synch from the settings page.
    
6. "Filter Shot History" page callable from the DSx History Viewer to restrict the shots being shown on both left and right listboxes.

7. Upload shot files to Miha's [Visualizer](https://visualizer.coffee/) repository, either automatically when finished, or on demand with a button press. 

8. Configuration page allows defining settings and launch database maintenance actions from within the app. 

9. TBD Add new description data: other equipment, beans details (country, variety), detailed coffee ratings like
		in cupping scoring sheets, etc.
