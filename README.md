# GPcalc
ImageJ macro to calculate general polarization (GP) values from microscopy images, e.g. two-channel images of polarity-sensitive membrane dyes such as Laurdan and di-4-ANEPPDHQ.

The original macro supplied with the publication (see below) doesn't work as-is. This version should fix that and various other reported issues as well as supplying a few more options for processing.

## Software Requirements
- [Fiji](https://fiji.sc/) (which includes BioFormats)
or
- [ImageJ](https://imagej.nih.gov/ij/)
- [BioFormats](http://downloads.openmicroscopy.org/bio-formats/)

## Input Image Requirements
This is detailed in the original paper (see below) but you just need at least one two-channel image where each channel is one of the reporter channels for your favourite environmentally sensitive membrane dye, e.g. ordered and disordered. An optional third channel can contain immunofluoresence of some other interesting target should you wish to check GP vs InterestingTarget.

If you acquire multiple images it is important to keep your acquisition settings constant, e.g. consistent channel order, laser power, image area ('zoom'), gain, offset, scan times etc, etc. The macro will process all images (of the file-type specified in set-up) that it finds within the input folder (which is also specified during set-up).

Unlike the original macro there's no need to split everything into separate TIFF images with special names -- the original proprietary format is fine, so long as it can be read by BioFormats (which is almost everything) then it's fine. TIFF stacks are fine too. Just so long as one file contains the two or three channels for that image.

Files don't have to be named anything in particular for this macro to work.

## Installation
As with any ImageJ macro, it's just a text file. Download it an save it somewhere convenient. You can also drag it from your file explorer into the status bar of any running ImageJ instance and it will open it in the macro editor. Or you can click Plugins --> Macros --> Install... and have it available in the Macros menu. 

## Running it
Once installed or open in the editor, run the macro (click it in the Plugins --> Macros menu or click the Run button in Fiji's text editor or Macros --> Run Macro in ImageJ's text editor) to begin using it.

The first thing is to find the folder containing the images you wish to process. The macro will process all images that it finds in this folder but will not traverse subdirectories. It will only process images of the type specified in the next step.

After selecting an input folder you will see the options available for processing:

**Input File Extension** _(text, Default: .nd2)_ The extension of the images that you wish to process, e.g. .nd2 or .czi. Only files with the specified extension will be processed. Subfolders are also ignored.

**Short Results Descriptor** _(text, Default: (empty))_ The results folder will have this at the front of it, so you know what's going on. This can be blank and the results folder will be called 'Results'. A timestamp will also be included to help keep track and avoid over-writing previously processed stuff.

**Acquisition ordered channel** _(a number, Default: 1)_ and **Acquisition disordered channel** _(also a number, Default: 2)_ The channel number which contains the ordered and disordered image data. Channel numbering begins at 1, not zero, as far as this macro is concerned.

**Use native bit depth?** _(Yes or No choice, Default: Yes)_ As the GP calculation is ratiometric it doesn't matter the bit-depth of your input images. However, the original macro converted all input images first to 8-bit and then to 32-bit prior to calculations. Choosing 'No' here will perform this sort of conversion as per the original macro. Choosing 'Yes' here will perform the calculations on your image data as it is, probably preserving the large dynamic range afforded by the higher bit depth.

**Lower Threshold Value for GP the mask** _(a number, Default: 15)_ A mask of the 32-bit GP image will be made at this threshold and a 'masked GP' image created containing the pixels with values above the threshold.

**Lookup Table for GP Images** _(list selection, Default: Grays)_ The selected lookup table will be applied to all GP images.

The IF channel will be used to mask the GP image, so you can check GP against your IF staining.

**Immunofluorescence channel** _(a number, Default: 0)_ The channel number containing the non-GP data, such as a far-red immunofluoresence image. If there is no such channel, give this a value of 0 (zero) and it will be ignored.

**IF Channel Threshold by** _(list selection)_ Choose Otsu or Normal. If you choose Normal you'll need to give a threshold value below.

**Normal Threshold pixels over** _(a number, Default: 10)_ If 'Normal' threshold method is selected above then this value will be used for the threshold. This value will need to be appropriate for your choice for 'Use native bit-depth'.

**G factor** _(a number, Default: 1)_ If you have calculated a G factor, enter it here. If you don't have one or don't need to use one, then use 1 here.

**Apply G factor to image data or histograms?** _(a choice, Default:"Histogram data (post GP calc)_ The G Factor correction can be applied to image data prior to the calculation of the GP values, or to the histogram values after GP calculation (leaving the GP image uncorrected). If you have set G factor (above) to 1 then this choice is irrelevant.

HSB images: The GP image can be merged with intensity values from an original image channel to make a faux-coloured intensity image.

**Do you want to generate HSB images?** _(Yes or No choice, Default: Yes)_ Yes to make such an image.

**HSB Brightness from** _(list selection, Default: Ordered channel)_ Intensity values will be used from this raw data channel.

**Apply brightness from first image to all?** _(Yes or No choice, Default: No)_ The first image that is processed will be used to set a brightness adjustment (you'll be given a chance to set this adjustment manually). This brightness range will be applied for all subsequent images. This is here because it was an option in the original macro but it is highly dependent on the properties (and your judgement) of the first image in your folder!

**Lookup Table for HSB Images** _(list selection)_ GP values will be colourised according to this LUT.

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
