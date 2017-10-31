# GPcalc
ImageJ macro to calculate general polarization (GP) values from microscopy images, e.g. two-channel images of polarity-sensitive membrane dyes such as Laurdan and di-4-ANEPPDHQ.

The original macro supplied with the publication (see below) doesn't work as-is. This version should fix that and various other reported issues as well as supplying a few more options for processing.

## Software Requirements
- [Fiji](https://fiji.sc/) (which includes BioFormats)
or
- [ImageJ](https://imagej.nih.gov/ij/) and also [BioFormats](http://downloads.openmicroscopy.org/bio-formats/)

## Input Image Requirements
Details on image acquisition requirements are in the original paper (see below) but for this macro you need at least one two-channel image where each channel is one of the reporter channels for your favourite environmentally sensitive membrane dye, e.g. ordered and disordered. An optional third channel can contain immunofluoresence of some other interesting target should you wish to check GP vs InterestingTarget.

If you acquire multiple images it is important to keep your acquisition settings constant, e.g. consistent channel order, laser power, image area ('zoom'), gain, offset, scan times etc, etc. The macro will process all images (of the format specified in set-up) that it finds within the input folder (which is also specified during set-up).

Unlike the original macro there's no need to split all your images out into separate TIFF images with special names -- the original proprietary format and naming is fine. As long as it can be read by BioFormats (which is almost everything) then it's fine, e.g. TIFF stacks are fine too. Just so long as one image file contains the two or three channels for that image.

Files don't have to be named anything in particular for this macro to work but you do need to know which channels contain which type of data and this order should be the same for all images.

## Installation
As with any ImageJ macro, it's just a text file. Download it an save it somewhere convenient. You can also drag it from your file explorer into the status bar of any running ImageJ instance and it will open it in the macro editor. Or you can click Plugins --> Macros --> Install... and have it available in the Macros menu for that session.

The LUTs included here are useful for generating the false-colour (aka HSL or HSB images). You don't have to use them.

## Running it
Once installed or open in the editor, run the macro (click it in the Plugins --> Macros menu or click the Run button in Fiji's text editor or Macros --> Run Macro in ImageJ's text editor) to begin using it.

The first thing is to find the folder containing the images you wish to process. The macro will process all images that it finds in this folder but will not traverse subdirectories. It will only process images of the type specified in the next step.

**Note: Unlike the original macro, you do not have to split apart your images and save them as specially named separate TIF files.** You only need the files as they came off the microscope, e.g. and ND2 file, LIF file, or CZI file. If you do have TIFs then you'll need them as TIF stacks, i.e. all the channels are in a single image file.

After selecting an input folder you will see the options available for processing. These are described below.

### Input Format & Output Folder

**Input File Extension** _(text, Default: .nd2)_  
The extension of the images that you wish to process, e.g. .nd2 or .czi. Only files with the specified extension will be processed. Subfolders are also ignored.

**Short Results Descriptor** _(text, Default: (empty))_  
The results folder will have this at the front of it, so you know what's going on. This can be blank and the results folder will be called 'Results'. A timestamp will also be included to help keep track and avoid over-writing previously processed stuff.

### Image Channels

**Channel A (Ordered)** _(a number, Default: 1)_  
**Channel B (Disordered)** _(also a number, Default: 2)_  
The channel number which contains the ordered and disordered image data, respectively. Channel numbering begins at 1, not zero, as far as this macro is concerned. The number is the order in which the channels are stored in your image file, e.g. if you acquired a file so that you have disordered data in the first channel, then an immunofluorsence image, then the ordered data then you would need to put a 3 for Channel A and a 1 for Channel B. In the Channel C field (below) you would put 2.

**Channel C (Immunofluorescence channel)** _(a number, Default: 3)_  
The channel number containing the non-GP data, such as a far-red immunofluoresence image. If there is no such channel, give this a value of 0 (zero) and it will be ignored.

**Channel labels** _(text, Default: ordereded, disordered, and proteinX)_
These labels will be applied to the output to easily identify which channel is which, especially if you use this for some other ratiometric calculaton which isn't anything to do with membrane order! When not using an IF image (i.e. Channel C = 0) then the label for Channel C is ignored.

### GP Calculation Options

**Use native bit depth?** _(Yes or No choice, Default: Yes)_  
As the GP calculation is ratiometric it doesn't matter the bit-depth of your input images. However, the original macro converted all input images (which are usually 16-bit) first to 8-bit and then to 32-bit prior to calculations. Choosing 'No' here will perform this sort of conversion as per the original macro. Choosing 'Yes' here will perform the calculations on your image data as it is, probably preserving the large dynamic range afforded by saving at the higher bit depth.

**G factor** _(a number, Default: 1)_  
If you have calculated a G factor, enter it here. If you don't have one or don't need to use one, then use 1 here.

**Apply G factor to image data or histograms?** _(a choice, Default:"Histogram data (post GP calc)_  
The G Factor correction can be applied to image data prior to the calculation of the GP values, or to the histogram values after GP calculation (leaving the GP image uncorrected). If you have set G factor (above) to 1 then this choice is irrelevant.

**Lookup Table for GP Images** _(list selection, Default: Blu2Yel)_  
The selected lookup table will be applied to all GP images. The default 'Blu2Yel' LUT is included in this repo.

### Mask Thresholds

The raw GP image will look very messy (noisy) as even the 'background' pixels will have intensity ratios calculated. Applying a threshold to this image can create a binary mask which can then be applied to the original raw GP image. Similarly, a mask can be generated from the third IF channel (if supplied) and applied to the raw GP image to generate 'IF-masked GP' images; this lets you evaluate GP values in regions with strong IF signal.

**Threshold method** _(list selection)_  
Choose from either Otsu or Normal. If you choose Normal you'll need to supply appropriate threshold values in the following boxes. Otsu is an automatic method so none of the following threshold values will be used if this method is chosen.

**Normal method: GP-mask threshold from:** _(a number, Default: 15)_  
If Normal thresholding is chosen, a mask of the 32-bit summed-intensity image (the sum of ordered and disordered channels) will be made at this threshold and a 'GP-masked GP' image created containing GP values only for areas above the threshold.

**Normal method: IF-mask threshold from:** _(a number, Default: 15)_  
If Normal thresholding is chosen, a mask of the IF image will be made at this threshold and an 'IF-masked GP' image created. This value needs to make sense with your IF image bit depth if you have opted to 'Use native bit-depth' above.

**Normal method: Tweak thresholds manually?** _(Yes or No choice, Default: Yes)_  
If Normal thresholding is chosen, and this option is 'Yes', then you'll be given a chance to adjust the threshold manually, both for the GP-mask and the IF-mask. The supplied values will be used as a starting point. Once applied, the new threshold values will then be applied to all subsequent images.

### False-colour Images
Generate a false-coloured GP-intensity image. The raw GP image is colourised with a lookup-table and then modulated using the intensity values from one of the original input images (such as the IF channel) to generate 'IF-masked GP' images.

**Do you want to generate HSB images?** _(Yes or No choice, Default: Yes)_  
Select Yes to make such an image.

If you select 'Yes' here, you will be present with the following options in a new dialog window:

**Hue - use Lookup Table for GP data:** _(list selection, Default: Candy-Bright-BlackMinimum)_ 
GP values will be colourised according to this LUT. The default LUT (Candy-Bright-BlackMinimum) is available here but you don't have to use it.

**Brightness - Use intensity from:** _(list selection, Default: Ordered channel)_  
Intensity values will be used from this raw data channel. You can also select the sum-of-ordered-and-disordered data (to avoid dimming pixels from the opposite order!) or select to make two HSB images, one from the sum and another from the IF channel. If you select an option requiring the IF channel but haven't given an IF channel above (i.e. you gave a '0') then you will be prompted to fix this in a subsequent window.

**Apply fixed restricted intensity range to all images?** _(Yes or No choice, Default: No)_  
The first image that is processed will be used to manually set a brightness adjustment for the GP data. This GP brightness range will be applied for all subsequent images. This is here because it was an option in the original macro but it is highly dependent on the properties (and your judgement) of the first image in your folder!

**Apply 1px median filter prior to save?** _(Yes or No choice, Default: No)_
Due to the ratiometric nature of GP calculations, the false-colour (HSB) images produced in this section can look a little harsh and noisy. For presentation purposes, applying a 1px median filter can improve the appearance by diminishing harsh features like speckled noise.

Once these settings look good, click OK to begin processing. A progress bar in the ImageJ/FiJi main window will inform you of how the overall processing is going.

Upon completion, a log window will appear with processing stats. This information will be saved to the results folder.

The results folder will contain subfolders holding the various images generated by the macro (raw GP, masked GP, HSB, IF-masked GP, etc). There will also be 32-bit images from each channel of each input image (Ordered, Disordered, and (optionally) Immunofluoresence), in order to match the output of the original macro. The GP folder will also contain a tab-delimited text file containing histogram values for each image.

## Origins
The code in this macro was derived from the macro supplied in the Supplementary Information of the following publication:

```
Quantitative Imaging of Membrane Lipid Order in Cells and Organisms
Owen DM, Rentero C, Magenau A, Abu-Siniyeh A, and Gaus K.
Nature Protocols 2011 Dec 8;7(1):24-35.
```
- [DOI: 10.1038/nprot.2011.419](https://doi.org/10.1038/nprot.2011.419)
- [PMID: 22157973](https://www.ncbi.nlm.nih.gov/pubmed/22157973)
