Some demo images to play with :)

The ND2 files are real samples. The TIF file is a synthetic sample in which each channel ("ordered" = first channel, "disordered" = second) ramps from zero to 100% intensity with ordered highest on the left and disordered highest on the right side of the image.

### To process the DemoTest_3Ch.tif file:
- Open the macro in ImageJ/Fiji
- Run the macro
- Locate the folder containing DemoTest_3Ch.tif (doesn't matter if the .nd2 files are there also!) and select that folder.
- In the settings:
  - adjust the Input file extension to .tif
  - ordered is channel 1, disordered is channel 2, and immunofluo is channel 3.
  - Highly recommended: change the LUT from 16_colors to something with a sensible (continuous) range. The 'low end' of 16_colors is black, so all your disordered data will be black and these images are also using intensity data from another image which will use black as 'dim intensity'. So it all gets very misleading. The top end is white, which also causes interpretation problems. If you like, run it twice with different LUTs and see which ones are more informative. The 16_colors LUT is selected to be compatible with the history of this macro.
- Click OK to run and check the Results folder when it's done.

### To process the ND2 files:
- As above, but leave the file extension as .nd2
- Leave the IF channel as 3
- Leave the HSB brightness source as 'Sum & IF' (you'll get an HSB image for each).
- Ideally also adjust the LUT to something sensible or at least compare a sensible LUT to 16_colors.
