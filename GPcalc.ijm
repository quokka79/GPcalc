/*
 ImageJ macro for GP image analysis
*/

print("\\Clear");

requires("1.44d");
closeAllImages();

// Select images folder
dir = getDirectory("Choose a Directory ");
GuessFileExtn = PopularFileType(dir);

// Initialise defaults and selection lists
InputFileExt = GuessFileExtn;
YNquestion = newArray("Yes","No");
GFapplication = newArray("Image data (pre GP calc)","Histogram data (post GP calc)");
ThreshList = newArray("Normal","Otsu");
LUTlist = getLUTlist();

// Choose image channels and threshold value
Dialog.create("GP analysis parameters");
Dialog.addString("Input File Extension:", InputFileExt);
Dialog.addString("Short Results Descriptor:", "");

Dialog.addMessage("------------------------------------------- Image channels -------------------------------------------");
Dialog.addNumber("Channel A (Ordered):", 1);
Dialog.addString("Channel A Label:", "ordered");
Dialog.addMessage("\n");
Dialog.addNumber("Channel B (Disordered):", 2);
Dialog.addString("Channel B Label:", "disordered");
Dialog.addMessage("\n");
Dialog.addNumber("Channel C (Immunofluorescence, (0 = None):", 3);
Dialog.addString("Channel C Label:", "proteinX");

Dialog.addMessage("------------------------------------------- GP Calculation -------------------------------------------");
Dialog.addChoice("Use native bit depth?",YNquestion, "Yes");
Dialog.addNumber("G factor (1 if unknown, -1 to estimate):", 1);
Dialog.addChoice("Apply G factor to image data or histograms?",GFapplication, "Histogram data (post GP calc)");
Dialog.addChoice("Lookup Table for GP Images:", LUTlist, "Blu2Yel");

Dialog.addMessage("------------------------------------------- Mask Thresholds ------------------------------------------");
Dialog.addChoice("Threshold method: ", ThreshList, "Normal");
Dialog.addNumber("Normal method: GP-mask threshold from", 15);
Dialog.addNumber("Normal method: IF-mask threshold from: ", 10);
Dialog.addChoice("Normal method: Tweak thresholds manually?",YNquestion, "Yes");

Dialog.addMessage("--------------------------------------------- False-colour Images ---------------------------------------------");
Dialog.addChoice("Do you want to generate False-colour images?",YNquestion, "Yes");

Dialog.addMessage("\n");
Dialog.show();

// make sure we aren't doing 'weighted' conversions, in case the input data is formatted as an RGB stack.
run("Conversions...", "scale");

// Set variables from dialog input
InputFileExt = Dialog.getString();
FolderNote = Dialog.getString();

chOrdered = Dialog.getNumber();
LabelchOrdered = Dialog.getString();

chDisordered = Dialog.getNumber();
LabelchDisordered = Dialog.getString();

ch_IF = Dialog.getNumber();
LabelchIF = Dialog.getString();

UseNativeBitDepth = Dialog.getChoice();
GFactor = Dialog.getNumber();
GFactorAppliedTo = Dialog.getChoice();
GPLUTname = Dialog.getChoice();

ThresholdType = Dialog.getChoice();
GPmaskThreshold = Dialog.getNumber();
IFmaskThreshold = Dialog.getNumber();
TweakThreshold =Dialog.getChoice();

MakeHSBimages = Dialog.getChoice();

// these have to survive inside the HSB function
var GPminUserSet = -1;
var GPmaxUserSet = 1;

// Check we have something to process
listDir = ListFiles(dir, InputFileExt);
numberOfImages = listDir.length;
if (numberOfImages == 0) {exit("There are no files with extension \"" + InputFileExt + "\"in folder \n" + dir);}


if (MakeHSBimages == "Yes") {

	Option_A = LabelchOrdered;
	Option_B = LabelchDisordered;
	Option_C = LabelchIF;
	Option_D = "Sum of " + LabelchOrdered + " + " + LabelchDisordered;
	Option_E = "Sum of " + LabelchOrdered + " + " + LabelchDisordered + " and also " + LabelchIF + ", separately";

	HSBrightChannelOptions_3Ch = newArray(Option_A, Option_B, Option_C, Option_D, Option_E);
	HSBrightChannelOptions_2Ch = newArray(Option_A, Option_B, Option_D);

	// Choose brightness channels and LUT
	Dialog.create("HSB Image generation");
	Dialog.addMessage("--------------------------------------------- False-colour Images ---------------------------------------------");
	Dialog.addChoice("Hue - use Lookup Table for GP data: ",LUTlist, "DavLUT-Bright-BlackMinimum");	
	if (ch_IF == 0) {
		Dialog.addChoice("Brightness - Use intensity from: ", HSBrightChannelOptions_2Ch, Option_D);
	} else {
		Dialog.addChoice("Brightness - Use intensity from: ", HSBrightChannelOptions_3Ch, Option_E);
	}
	Dialog.addChoice("Apply fixed restricted intensity range to all images?",YNquestion, "No");
	Dialog.addChoice("Apply 1px median filter prior to save?",YNquestion, "No");

	Dialog.addMessage("\n");
	Dialog.show();

	HSBLUTName = Dialog.getChoice();
	HSBrightChannel = Dialog.getChoice();
	ApplySameBrightness =Dialog.getChoice();
	ApplyMedianFilter =Dialog.getChoice();
}


// initialise the timer for the log
time0 = getTime();

// Set up results folder & logging info
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
if (hour<10) {hours = "0"+hour;}
else {hours=hour;}
if (minute<10) {minutes = "0"+minute;}
else {minutes=minute;}
if (month<10) {months = "0"+(month+1);}
else {months=month+1;}
if (dayOfMonth<10) {dayOfMonths = "0"+dayOfMonth;}
else {dayOfMonths=dayOfMonth;}
MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");

if (FolderNote == "") {
 results_Dir = dir + "Results " + year + months + dayOfMonths + "(" + hours + "h" + minutes + ")" + File.separator;
} else {
 results_Dir = dir + FolderNote + " - " + year + months + dayOfMonths + "(" + hours + "h" + minutes + ")" + File.separator;
}
File.makeDirectory(results_Dir);

InputImages_Dir = results_Dir + "Input images" + File.separator;
File.makeDirectory(InputImages_Dir);

ordered_images_Dir = InputImages_Dir + LabelchOrdered + File.separator;
File.makeDirectory(ordered_images_Dir);

disordered_images_Dir = InputImages_Dir + LabelchDisordered + File.separator;
File.makeDirectory(disordered_images_Dir);

sumGP_images_Dir = InputImages_Dir + "Sum (" + LabelchOrdered + "+" + LabelchDisordered +") Images" + File.separator;
File.makeDirectory(sumGP_images_Dir);

GP_images_Dir = results_Dir + "Masked (by " + Option_D +") GP images" + File.separator;
File.makeDirectory(GP_images_Dir);

histogramGP_Dir = GP_images_Dir + "Histograms" + File.separator;
File.makeDirectory(histogramGP_Dir);

rawGP_images_Dir = results_Dir + "GP images" + File.separator;
File.makeDirectory(rawGP_images_Dir);


if (MakeHSBimages == "Yes") {

	HSB_Dir = results_Dir + "HSB images" + File.separator;
	File.makeDirectory(HSB_Dir);
	
//	HSB_TIF_Dir = HSB_Dir + "TIF" + File.separator;
//	File.makeDirectory(HSB_TIF_Dir);

 if (ApplySameBrightness == "No") {
	HSB_LUTs_Dir = HSB_Dir + "colorbars" + File.separator;
	File.makeDirectory(HSB_LUTs_Dir);
 }

}


if (ch_IF != 0) {
 IF_images_Dir = InputImages_Dir + LabelchIF + File.separator;
 File.makeDirectory(IF_images_Dir);

 GP_IF_images_Dir = results_Dir + "Masked (by " + LabelchIF + ") GP images" + File.separator;
 File.makeDirectory(GP_IF_images_Dir);

 histogramIF_Dir = GP_IF_images_Dir + "Histograms" + File.separator;
 File.makeDirectory(histogramIF_Dir);
}

// Set up GP and GPcorrected Arrays for histogram calculations

GPuncorrected = newArray(256);
for (j = 0; j < 256; j++) {
	GPuncorrected[j] = ((j - 127) / 127);
}

GPcorrected = newArray(256);
if (GFactorAppliedTo == "Image data (pre GP calc)") {
	GFHistograms = 1; // GFactor will be applied to the image data, the histograms are not modified.
} else {
	//"Histogram data (post GP calc)"
	GFHistograms = GFactor; // the histograms are corrected, the image data will not be modified.
}

for (k = 0; k < 256; k++) {
	GPcorrected[k] = -(1 + GPuncorrected[k] + (GFHistograms * GPuncorrected[k]) - GFHistograms) / (-1 - GPuncorrected[k] + (GFHistograms * GPuncorrected[k]) - GFHistograms);
}


// -=-=-=-=-=-=-=-=-=- Begin processing images in turn -=-=-=-=-=-=-=-=-=-

for (i = 0; i < numberOfImages; i++) {
 if (endsWith(listDir[i], InputFileExt)) {

	imgName = listDir[i];

	setBatchMode(true);

	// open the current image
	run("Bio-Formats Importer", "open=[" + dir + imgName + "] color_mode=Default view=[Standard ImageJ] stack_order=Default virtual split_channels");
	
	// set window titles
	ordWindowTitle = imgName + " - C=" + chOrdered - 1;
	disWindowTitle = imgName + " - C=" + chDisordered - 1;
	if (ch_IF != 0) {
		imfWindowTitle = imgName + " - C=" + ch_IF - 1;
	}

	//select ordered
	selectWindow(ordWindowTitle);
	run("Grays");
	if (UseNativeBitDepth == "No") {
		run("8-bit");
		run("32-bit");
		saveAs("Tiff", ordered_images_Dir + imgName + "_ordered_32bit.tif");
	} else {
		saveAs("Tiff", ordered_images_Dir + imgName + "_ordered.tif");
	}
	
	rename(ordWindowTitle);


	//select disordered, apply GFactor correction
	selectWindow(disWindowTitle);
	run("Grays");
	if (UseNativeBitDepth == "No") {
		run("8-bit");
		run("32-bit");

		if (GFactorAppliedTo == "Image data (pre GP calc)") {
			run("Multiply...","value=" + GFactor);
			saveAs("Tiff", disordered_images_Dir + imgName + "_disordered_GFactorCorrected_32bit.tif");
		} else {
			saveAs("Tiff", disordered_images_Dir + imgName + "_disordered_32bit.tif");
		}

	} else {
		if (GFactorAppliedTo == "Image data (pre GP calc)") {
			run("Multiply...","value=" + GFactor);
			saveAs("Tiff", disordered_images_Dir + imgName + "_disordered_GFactorCorrected.tif");
		} else {
			saveAs("Tiff", disordered_images_Dir + imgName + "_disordered.tif");
		}
	}
	
	rename(disWindowTitle); // restore the window name after saving this image

	if (ch_IF != 0) {
		selectWindow(imfWindowTitle);
		run("Grays");
		if (UseNativeBitDepth == "No") {
			run("8-bit");
			run("32-bit");
			saveAs("Tiff", IF_images_Dir + imgName + "_IF_32bit.tif");
		} else {
			saveAs("Tiff", IF_images_Dir + imgName + "_IF.tif");
		}

		rename(imfWindowTitle);
	}


	//GP Analysis

	// difference channels (ordered - disordered)
	imageCalculator("Subtract create 32-bit", ordWindowTitle, disWindowTitle);
	diffName = imgName + " - ordered minus disordered";
	rename(diffName);

	// sum channels (ordered + disordered)
	imageCalculator("Add create 32-bit", ordWindowTitle, disWindowTitle);
	sumName = imgName + " - ordered plus disordered";
	rename(sumName);

	// GP = (difference / sum)
	imageCalculator("Divide create 32-bit", diffName, sumName);
	rawGPname = imgName + " - raw GP";
	saveAs("Tiff", rawGP_images_Dir + imgName + "_rawGP_32bit.tif");
	rename(rawGPname);

	// set same scale
	setMinAndMax(-1.0000, 1.0000);
	call("ij.ImagePlus.setDefault16bitRange", 0);

	// create masked GP by thresholding
	selectWindow(sumName);
	run("Duplicate..."," ");
	saveAs("Tiff", sumGP_images_Dir + imgName + "_Ord+Dis_32bit.tif");
	// run("Add...", "value=2");
	SumMaskName = "SumMask";
	rename(SumMaskName);
		 
	if (ThresholdType == "Normal") {
		if (TweakThreshold == "Yes"){
			if (i == 0) { // first image in the list
				selectWindow(SumMaskName);
		 		setBatchMode("show");
				setOption("BlackBackground", true);
				getMinAndMax(currGPMin,currGPMax);
				setThreshold(GPmaskThreshold, currGPMax);
				run("Threshold...");
				waitForUser("Summed Intensity Image for GP Mask\nAdjust threshold, click Apply (UN-check: set bg pixels to NaN when asked)\n then click OK here to continue...");
				if (isOpen('Threshold')) {selectWindow('Threshold'); run('Close');}
				run("Threshold...");
				getThreshold(GPmaskThreshold,currGPMax);
				if (isOpen('Threshold')) {selectWindow('Threshold'); run('Close');}
		 		setBatchMode("hide");
			}
		} else {
			selectWindow(SumMaskName);
			getMinAndMax(currGPMin,currGPMax);
			setThreshold(GPmaskThreshold, currGPMax);
		}

	} else if (ThresholdType == "Otsu") {
		selectWindow(SumMaskName);
		setAutoThreshold("Otsu dark");
	}

	run("Macro...", "code=[if (v != v) v = 0;]"); //convert NaNs to zero.
	run("Convert to Mask");
	run("Subtract...", "value=254");
	rename(SumMaskName);
	
	selectWindow(rawGPname);
	run("Duplicate..."," ");
	premaskGPname = "premaskGP";
	rename(premaskGPname);
	run("Add...", "value=2"); // this bumps the low-end from -1 to 0 which allows ImageJ to turn NaN-background to black and the LUT applies across the rest of the image.
	run("Macro...", "code=[if (v != v) v = 0;]");
	
	imageCalculator("Multiply create", SumMaskName, premaskGPname);
	run(GPLUTname);
	maskedGPname = imgName + " - GP";
	saveAs("tiff", GP_images_Dir + imgName + " (" + Option_D + ")-masked GP");
	rename(maskedGPname);
	selectWindow(SumMaskName);
	close();

	// histograms
	HistoFileName=histogramGP_Dir + imgName + "GP Histogram" + "(masked by " + Option_D + ").tsv";
	HistogramGeneration(maskedGPname, HistoFileName);

	// if we are given some other intensity channel (the immunofluoresence channel) then...
	if (ch_IF != 0) {
	
		 // make a binary mask from the IF image
		 selectWindow(imfWindowTitle);
		 run("Duplicate..."," ");
		 IFmaskName = "IFMask";
		 rename(IFmaskName);


		if (ThresholdType == "Normal") {
			if (TweakThreshold == "Yes"){
				if (i == 0) { // first image in the list
					selectWindow(IFmaskName);
					setBatchMode("show");
					setOption("BlackBackground", true);
					getMinAndMax(currIFMin,currIFMax);
					setThreshold(IFmaskThreshold, currIFMax);
	 	 			run("Threshold...");
	 	 			waitForUser("Immunofluoresence channel image for IF-mask\nAdjust threshold, click Apply and then click OK here to continue...");
	 	 			if (isOpen('Threshold')) {selectWindow('Threshold'); run('Close');}
					run("Threshold...");
					getThreshold(IFmaskThreshold,currIFMax);
					if (isOpen('Threshold')) {selectWindow('Threshold'); run('Close');}
			 		setBatchMode("hide");
				}
			} else {
				getMinAndMax(currIFMin,currIFMax);
				setThreshold(IFmaskThreshold, currIFMax);
			}

		} else if (ThresholdType == "Otsu") {
			setAutoThreshold("Otsu dark");
		}

		selectWindow(IFmaskName);
		run("Options...", "black");
		run("Convert to Mask");
		run("Divide...","value=255");
		setMinAndMax(0.0,1.0);

		GPIFName = imgName + " - GPIF";
		imageCalculator("Multiply create", rawGPname, IFmaskName);
		rename(GPIFName);
		selectWindow(GPIFName);
		run(GPLUTname);
		saveAs("tiff", GP_IF_images_Dir + imgName + " (" + Option_C + ")-masked GP");
		rename(GPIFName);
		HistoFileName=histogramIF_Dir + imgName + "GP Histogram" + "(masked by " + Option_C + ").tsv";
		HistogramGeneration(GPIFName, HistoFileName);

		selectWindow(IFmaskName);
		close();
	}

	if (MakeHSBimages=="Yes") {

		// Select and copy the channel to be used for 'brightness' (the raw ord/dis/IF image)
		if (HSBrightChannel==Option_A) {
			HSBgeneration(ordWindowTitle, Option_A);
		} else if (HSBrightChannel==Option_B) {
			HSBgeneration(disWindowTitle, Option_B;
		} else if (HSBrightChannel==Option_C) {
			HSBgeneration(imfWindowTitle, Option_C);
		} else if (HSBrightChannel==Option_D) {
			HSBgeneration(sumName, Option_D);
		} else if (HSBrightChannel==Option_E) {
			HSBgeneration(sumName, Option_D);
			HSBgeneration(imfWindowTitle, Option_C);
		}

//		// HSBv2
//		if (HSBrightChannel==Option_A) {
//			HSBv2(ordWindowTitle, Option_A);
//		} else if (HSBrightChannel==Option_B) {
//			HSBv2(disWindowTitle, Option_B);
//		} else if (HSBrightChannel==Option_C) {
//			HSBv2(imfWindowTitle, Option_C);
//		} else if (HSBrightChannel==Option_D) {
//			HSBv2(sumName, Option_D);
//		} else if (HSBrightChannel==Option_E) {
//			HSBv2(sumName, Option_D);
//			HSBv2(imfWindowTitle, Option_C);
//		}


	}

	closeAllImages();

	FractionDone = i / numberOfImages;
	showProgress(FractionDone);
	}

}

// finished now! Write the log.
printInfo();


///////////////// Supporting Functions ////////////////////

function closeAllImages() {

	while (nImages>0) {
		selectImage(nImages);
		close(); }

}


function newFolder() {

	File.makeDirectory(Folder);
	listZ = getFileList(Folder);
	for (f = 0; f < listZ.length; f++) {
		File.delete(Folder + listZ[f]);
	}

}


function HistogramGeneration (WindowName, HistoFileName) {

	Int=newArray(256);
	Cou=newArray(256);
	Smo=newArray(256);
	NAvDist=newArray(256);
	nBins = 256;

	selectWindow(WindowName);
	getHistogram(values, counts, nBins);

	for (u = 0; u < nBins; u++) {
		Int[u] = u;
		Cou[u] = counts[u];
		if (u <= 1) {
			Smo[u] = 0;
		} else if (u == 255) {
			Smo[u] = 0;
		} else {
			Smo[u] = (counts[u - 1] + counts[u] + counts[u + 1]) / 3;
		}
	}
	Array.getStatistics(Cou,min,max,mean,stdDev);
	Sa=(mean*256)-counts[0]-counts[255];
	HistogramOutFile=File.open(HistoFileName);
	print(HistogramOutFile, "Intensity	Counts	Smooth	Norm Av Dist	GP	GP GF-corrected");
	for (m = 0; m < 256; m++) {
		NAvDist[m] = 100 * Smo[m] / Sa;
		print(HistogramOutFile, Int[m] + "	" + Cou[m] + "	" + Smo[m] + "	" + NAvDist[m] + "	" + GPuncorrected[m] + "	" + GPcorrected[m]);
	}
	File.close(HistogramOutFile);

}


function HSBgeneration(HSBIntensityChannel, OutfileSuffix) {

	selectWindow(HSBIntensityChannel);
	BrightChannel = "BrightnessChannel";
	run("Duplicate..."," ");
	rename(BrightChannel);
	run("Enhance Contrast", "saturated=0.35 normalize");
	run("8-bit");

	//run("Set Measurements...", "min limit display redirect=None decimal=5"); // ? not sure what this does here

	// Select and copy the channel to be used for 'hue' (the GP image)
	selectWindow(rawGPname);
	run("Duplicate..."," ");

	// This will offset the data slightly in order to distinguish NaN values from minimum (-1.00) values.
	run("Add...", "value=1.00785");
	run("Macro...", "code=[if (v != v) v = 0;]"); //convert NaNs to zero.
	setMinAndMax(0,2.00785);
	
	run(HSBLUTName);
	HueChannel = "HueChannel";
	rename(HueChannel);
	selectWindow(HueChannel);
	
	// adjust the GP image (Hue) brightness, if needed, based on the first processed image
	if (ApplySameBrightness == "Yes") {
		if (i == 0) { // first image in the list
			selectWindow(HueChannel);
			setBatchMode("show");			
			run("Brightness/Contrast...");
			waitForUser("set min & max","set min & max");
			getMinAndMax(GPminUserSet,GPmaxUserSet);
			setBatchMode("hide");
		}
		setMinAndMax(GPminUserSet,GPmaxUserSet);
	}
	
	getMinAndMax(GPminActual,GPmaxActual); // get the actual min/max (in case brightness was not adjusted ... should still be -1/+1)

	GPminActual = GPminActual - 1.00785;
	GPmaxActual = GPmaxActual - 1.00785;

	time0 = getTime();

	selectWindow(HueChannel);
	run("RGB Color");
	run("Split Channels");

	selectWindow(BrightChannel);

	imageCalculator("Multiply create 32-bit", HueChannel + " (red)", BrightChannel);
	rename("bR");

	imageCalculator("Multiply create 32-bit", HueChannel + " (green)", BrightChannel);
	rename("bG");

	imageCalculator("Multiply create 32-bit", HueChannel + " (blue)", BrightChannel);
	rename("bB");

	run("Conversions...", " "); // don't rescale
	
	selectWindow("bR");
	run("Divide...", "value=255");
	run("8-bit");

	selectWindow("bG");
	run("Divide...", "value=255");
	run("8-bit");

	selectWindow("bB");
	run("Divide...", "value=255");
	run("8-bit");

	run("Merge Channels...", "red=bR green=bG blue=bB gray=*None*");
	selectWindow("RGB");
	run("RGB Color");
	HSBname = imgName + " False Colour";
	rename(HSBname);

	if (ApplyMedianFilter == "Yes") {
		run("Median...", "radius=1");
		saveAs("png", HSB_Dir + imgName + "_HSB(medianfiltered) by " + OutfileSuffix);
	} else {
		saveAs("png", HSB_Dir + imgName + "_HSB by " + OutfileSuffix);
	}
	close();

	selectWindow(HueChannel + " (red)");
	close();
	selectWindow(HueChannel + " (green)");
	close();
	selectWindow(HueChannel + " (blue)");
	close();
	selectWindow(BrightChannel);
	close();

	run("Conversions...", "scale"); // restore the conversions to default

	// make a LUT colorbar from the first image only if all images have the same brightness range applied.
	// Otherwise save a colorbar for each image.
	if (ApplySameBrightness == "Yes") {
		if (i == 0) {
			MakeLUTbar(HSBLUTName, GPminActual, GPmaxActual, HSB_Dir + "All Images - LUT annotated");
		}
	} else {
		MakeLUTbar(HSBLUTName, GPminActual, GPmaxActual, HSB_LUTs_Dir + imgName + "_LUT annotated");
	}

}


function MakeLUTbar(CmapLUTName, CmapMin, CmapMax,SaveFileName) {

	// Make HSB LUT bar
	newImage("LUT-Hue", "8-bit Ramp", 256, 256, 1);
	run(CmapLUTName);
	run("Duplicate...", "title=LUT-Brightness");
	run("Rotate 90 Degrees Left");
	run("32-bit");
	selectWindow("LUT-Hue");
	run("RGB Color");
	run("Split Channels");
	imageCalculator("Multiply create 32-bit", "LUT-Brightness", "LUT-Hue (red)");
	rename("bR");
	run("8-bit");
	imageCalculator("Multiply create 32-bit", "LUT-Brightness", "LUT-Hue (green)");
	rename("bG");
	run("8-bit");
	imageCalculator("Multiply create 32-bit", "LUT-Brightness", "LUT-Hue (blue)");
	rename("bB");
	run("8-bit");
	run("Merge Channels...", "red=bR green=bG blue=bB gray=*None*");
	selectWindow("RGB");
	rename("HSB LUT");
	run("Rotate 90 Degrees Left");
	run("Size...", "width=32 height=256 interpolation=None");

	selectWindow("LUT-Hue (red)");
	close();
	selectWindow("LUT-Hue (green)");
	close();
	selectWindow("LUT-Hue (blue)");
	close();
	selectWindow("LUT-Brightness");
	close();

	// Annotate LUT bar with min/max values
	selectWindow("HSB LUT");
	run("Copy");
	newImage("LUT Panel", "RGB White", 70, 264, 1);
	makeRectangle(4,4,32,256);
	run("Paste");
	run("Colors...", "foreground=black background=black selection=yellow");
	run("Line Width...", "line="+2);
	run("Draw");
	run("Select None");
	setFont("Arial", 12);
	setColor(0, 0, 0);
	drawString(d2s(CmapMax,2),39,15);
	drawString(d2s(CmapMin,2),39,264);
	run("Select None");
	selectWindow("LUT Panel");
	saveAs("png", SaveFileName);
	close();

}

function printInfo () {

	time2 = getTime();
	TOTALtime = (time2 - time0) / 1000;
	listGP = getFileList(GP_images_Dir);

	print("\\Clear");
	print("----------------------------------");
	print("	 GP images analysis macro");
	print("	 version DW 2017.08.01");
	print("----------------------------------");
	print("Original Reference:");
	print(" Quantitative Imaging of Membrane Lipid Order in Cells and Organisms");
	print(" Owen DM, Rentero C, Magenau A, Abu-Siniyeh A, and Gaus K.");
	print(" Nature Protocols 2011 7(1) p24-35.");
	print("\n");
	
	print("----------------------------------");
	print("ImageJ version " + getVersion());
	print(""+DayNames[dayOfWeek]+", "+dayOfMonth+" "+MonthNames[month]+" "+year+" - "+hours+":"+minutes);
	print("----------------------------------");
	print("Processed " + numberOfImages + " files with extension: " + InputFileExt);
	print("Output (all results) saved to folder: ");
	print(" " + GP_images_Dir);
	print("\n");
	
	print("------ Input Images ------");
	print("Ordered channel: " + chOrdered);
	print("Disordered channel: " + chDisordered);
	if (ch_IF != 0) {
		print("Immunofluoresence channel: " + ch_IF); 
	} else { 
		print("Immunofluoresence channel: Not present"); 
	};
	print("\n");
	
	print("------ Output GP Images ------");
	print("GP images were calculated using input image bit depth: " + UseNativeBitDepth);
	print("GP images' lookup table: " + GPLUTname);
	print("G factor: " + GFactor + " was applied to " + GFactorAppliedTo + ".");
	print("\n");
	
	print("------ Output GP-masked GP Images ------");
	print("GP mask threshold method: " + ThresholdType);
	if (ThresholdType=="Normal") {
		print("GP-mask threshold value (lower limit, 32 bit): " + GPmaskThreshold);
	}
	print("\n");
	
	if (ch_IF != 0) { 
		print("------ Output IF-masked GP Images ------");
		print("IF-mask threshold method: " + ThresholdType);
		if (ThresholdType=="Normal") {
			print("IF-mask threshold value (lower limit): "+ IFmaskThreshold);
		}
		print("\n");
	}
	
	if (MakeHSBimages=="Yes") {
		print("------ Output HSB GP Images ------");
		print("Intensity from: " + HSBrightChannel);
		if (ApplySameBrightness=="Yes") {
			print("Forced consistent GP intensity range: " + GPminUserSet + " (min) to " + GPmaxUserSet + " (max)");	
		}
		print("HSB images' lookup table: " + HSBLUTName);
	print("\n");
	}

	print("----------------------------------");
	print("Execution time: " + d2s(TOTALtime,2) + " seconds.");
	print("-------------- EoF ---------------");

	selectWindow("Log");
	saveAs("Text", results_Dir + "ProcessingLog_ "+year+months+dayOfMonths+"("+hours+"h"+minutes+")");
	setBatchMode("exit and display");

}


// Returns a list of the available LUTs from the 'luts' folder as well as the built-in ones
function getLUTlist() {
	userLUTdir = getDirectory("luts");
	userLUTlist = ListFiles(userLUTdir, ".lut");
	for (q = 0; q < userLUTlist.length; q++) {
 		userLUTlist[q] =replace(userLUTlist[q], ".lut", "");
	}
	IJ_default_LUTlist = newArray("Fire", "Grays", "Ice", "Spectrum", "3-3-2 RGB", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow", "Red/Green");
	LUTlist = Array.concat(IJ_default_LUTlist, userLUTlist);
	return LUTlist;
}

// This shows only those files with TargetExtn found within InputFolder.
// To show only the subfolders use TargetExtn = "/"
function ListFiles(InputFolder, TargetExtn) {

	AllFilesAndFolders = getFileList(InputFolder);
	TargetFiles = newArray();
	for (i = 0; i < AllFilesAndFolders.length; i++) {
		if (endsWith(AllFilesAndFolders[i], TargetExtn)) {
			TargetFiles = Array.concat(TargetFiles, AllFilesAndFolders[i]);
		}
	}
	return TargetFiles;

}


function PopularFileType(InputFolder) {

	AllFilesAndFolders = getFileList(InputFolder);
	
	FoundExtns = newArray();
	for (i = 0; i < AllFilesAndFolders.length; i++) {
		testName = AllFilesAndFolders[i];
		dotIndex = lastIndexOf(testName, ".");
		
		if (dotIndex > -1) {
			extn = substring(testName, dotIndex, lengthOf(testName));
			FoundExtns = Array.concat(FoundExtns, extn);
		} 
	}

	UniqueExtns = newArray();
	for (u = 0; u < FoundExtns.length; u++) {
		testValue = FoundExtns[u];
		Uniqueness = 1;
		
		for (t = 0; t < UniqueExtns.length; t++) {
			if (UniqueExtns[t] == testValue) {
				Uniqueness = 0;
			}
		}

		if (Uniqueness == 1) {
			UniqueExtns = Array.concat(UniqueExtns, testValue);
		}
	}

	if (UniqueExtns.length > 1) {
		PopularityContest = newArray();
		for (p = 0; p < UniqueExtns.length; p++) {
			
			searchValue = UniqueExtns[p];
			popularity = 0;
			
			for (q = 0; q < FoundExtns.length; q++) {
				if (FoundExtns[q] == searchValue) {
					popularity++;
				}
			}
	
			PopularityContest = Array.concat(PopularityContest, popularity);
		}
		idxMostPopular = Array.findMaxima(PopularityContest,1);
		idxMostPopular = idxMostPopular[0];
		MostPopularExtn = UniqueExtns[idxMostPopular];
		
	} else {
		MostPopularExtn = UniqueExtns[0];
	}
	
	return MostPopularExtn;

}
