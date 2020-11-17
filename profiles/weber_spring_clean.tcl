advanced_shot {{exit_if 1 flow 0.90 volume 100 transition fast exit_flow_under 0 temperature 110 name {Initial fill} pressure 1 sensor coffee pump flow exit_type pressure_over exit_flow_over 6 exit_pressure_over 0.30 exit_pressure_under 0 seconds 70.00} {exit_if 1 flow 0.30 volume 100 transition fast exit_flow_under 0 temperature 110 name {Fill and stir} pressure 1 sensor coffee pump flow exit_type pressure_over exit_flow_over 6 exit_pressure_over 9.00 exit_pressure_under 0 seconds 127} {exit_if 0 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 110 name Hold pressure 1 sensor coffee pump flow exit_type pressure_over exit_flow_over 6 exit_pressure_over 9.00 exit_pressure_under 0 seconds 10.00} {exit_if 1 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 110 name {Short flush} pressure 0 sensor coffee pump pressure exit_type pressure_under exit_flow_over 6 exit_pressure_over 9.00 exit_pressure_under 7.00 seconds 1.00} {exit_if 0 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 110 name Hold pressure 1 sensor coffee pump flow exit_type pressure_under exit_flow_over 6 exit_pressure_over 9.00 seconds 10.00 exit_pressure_under 4.00} {exit_if 1 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 110 name {Short flush} pressure 0 sensor coffee pump pressure exit_type pressure_under exit_flow_over 6 exit_pressure_over 9.00 seconds 1 exit_pressure_under 4.00} {exit_if 0 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 110 name Hold pressure 0 sensor coffee pump flow exit_type pressure_under exit_flow_over 6 exit_pressure_over 9.00 exit_pressure_under 4.00 seconds 10.00} {exit_if 1 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 110 name {Long flush} pressure 0.00 sensor coffee pump pressure exit_type pressure_under exit_flow_over 6 exit_pressure_over 9.00 seconds 20.00 exit_pressure_under 0.10} {exit_if 1 flow 4.00 volume 100 transition fast exit_flow_under 0 temperature 110 name {Fill to rinse} pressure 8.00 sensor coffee pump flow exit_type pressure_over exit_flow_over 6 exit_pressure_over 7.80 seconds 30.00 exit_pressure_under 4.00} {exit_if 1 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 110 name {Flush to rinse} pressure 0 sensor coffee pump pressure exit_type pressure_under exit_flow_over 6 exit_pressure_over 9.00 seconds 20.00 exit_pressure_under 1.00} {exit_if 1 flow 4.00 volume 100 transition fast exit_flow_under 0 temperature 110 name {Fill to rinse} pressure 8.00 sensor coffee pump flow exit_type pressure_under exit_flow_over 6 exit_pressure_over 9.00 seconds 20.00 exit_pressure_under 8.00} {exit_if 1 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 110 name {Full flush} pressure 0 sensor coffee pump pressure exit_type pressure_under exit_flow_over 6 exit_pressure_over 9.00 exit_pressure_under 0.10 seconds 20.00}}
author Decent
espresso_decline_time 35
espresso_hold_time 38
espresso_pressure 8.6
espresso_temperature 110
espresso_temperature_0 110
espresso_temperature_1 88.0
espresso_temperature_2 88.0
espresso_temperature_3 88.0
espresso_temperature_steps_enabled 1
final_desired_shot_volume 36
final_desired_shot_volume_advanced 36
final_desired_shot_volume_advanced_count_start 2
final_desired_shot_weight 36
final_desired_shot_weight_advanced 36
flow_profile_decline 1.2
flow_profile_decline_time 17
flow_profile_hold 2
flow_profile_hold_time 8
flow_profile_minimum_pressure 4
flow_profile_preinfusion 4
flow_profile_preinfusion_time 5
preinfusion_flow_rate 0.5
preinfusion_guarantee 0
preinfusion_stop_pressure 0.2
preinfusion_time 3
pressure_end 6.0
profile_hide 1
profile_language en
profile_notes {This profile is gentle on the coffee puck and not too demanding on the barista.  Produces a very acceptable espresso in a wide variety of settings.}
profile_title {Cleaning/Weber Spring Clean}
settings_profile_type settings_2c
tank_desired_water_temperature 0
water_temperature 80

