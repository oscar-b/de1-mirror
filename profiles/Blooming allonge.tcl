advanced_shot {{exit_if 1 flow 4.50 volume 100 transition fast exit_flow_under 0 temperature 95.00 name {fast pre} sensor coffee pump flow exit_type pressure_over exit_flow_over 6 exit_pressure_over 3.50 seconds 5.00 exit_pressure_under 0} {exit_if 1 flow 2.00 volume 100 transition smooth exit_flow_under 0 temperature 93.00 name {ramp down pre} sensor coffee pump flow exit_type pressure_over exit_flow_over 6 exit_pressure_over 3.50 exit_pressure_under 0 seconds 15.00} {exit_if 0 flow 0.00 volume 100 transition fast exit_flow_under 0 temperature 93.00 pressure 0 name bloom sensor coffee pump flow exit_flow_over 6 exit_pressure_over 11 exit_pressure_under 0 seconds 30.00} {exit_if 0 flow 3.50 volume 100 transition smooth exit_flow_under 0 temperature 92.50 pressure 0 name ramp sensor coffee pump flow exit_flow_over 6 exit_pressure_over 11 seconds 7.00 exit_pressure_under 0} {exit_if 1 flow 3.50 volume 100 transition fast exit_flow_under 0 temperature 91.00 name {hold at 3.5 ml/s} sensor coffee pump flow exit_type pressure_over exit_flow_over 6 exit_pressure_over 9.00 exit_pressure_under 0 seconds 60.00} {exit_if 0 flow 3.50 volume 100 transition fast exit_flow_under 0 temperature 91.00 pressure 9.50 name {9.5 bar alternate} sensor coffee pump pressure exit_type pressure_over exit_flow_over 6 exit_pressure_over 9.00 exit_pressure_under 0 seconds 60.00}}
author Decent
espresso_decline_time 18
espresso_hold_time 10
espresso_pressure 8.6
espresso_temperature 95.0
final_desired_shot_volume 100
final_desired_shot_volume_advanced 180
final_desired_shot_weight 32
final_desired_shot_weight_advanced 135
flow_profile_decline 3.5
flow_profile_decline_time 17
flow_profile_hold 4.5
flow_profile_hold_time 8
flow_profile_minimum_pressure 4
flow_profile_preinfusion 4
flow_profile_preinfusion_time 5
preinfusion_flow_rate 4.5
preinfusion_guarantee 0
preinfusion_stop_pressure 4
preinfusion_time 20
pressure_end 6.0
profile_hide 1
profile_language en
profile_notes {An amazing long espresso for light roasts, this is a fruit bomb of a brewing method. 5:1 ratio, 60 seconds, very fine grind. If close to the right pressure, make 0.5g dose adjustments to get to an 8-9 bar peak. The very high flow rate means small grind adjustments cause big pressure changes. A very advanced technique, extractions average 26%.}
profile_title {Blooming Allongé}
settings_profile_type settings_2c
tank_desired_water_temperature 0
water_temperature 80
beverage_type {espresso}

