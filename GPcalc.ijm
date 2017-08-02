/*
 ImageJ macro for GP image analysis
*/

print("\\Clear");

requires("1.44d");
closeAllImages();

// Select images folder
dir = getDirectory("Choose a Directory ");
//dir ="/home/dave/Network/daveDS/Data/170726 - di4ANE and Microtubules/";

//listDir = getFileList(dir);
//numberOfImages = listDir.length;

// Init some vars
LUTlist1 = newArray("Grays","Fire","candyBright DavLUT","Rainbow RGB");
YNquestion = newArray("Yes","No");
GFapplication = newArray("Image data (pre GP calc)","Histogram data (post GP calc)");
InputFileExt = ".nd2";
HSBrightChannelOptions = newArray("Ordered channel","Disordered channel","Immunofluoresence channel", "Sum of Ordered + Disordered", "Sum O+D and also IF channel");
ThreshList = newArray("Normal","Otsu");

// get all the available LUTs
Lut_Dir = getDirectory("luts");
LUTlist = ListFiles(Lut_Dir, ".lut");
for (q = 0; q < LUTlist.length; q++) {
 LUTlist[q] =replace(LUTlist[q], ".lut", "");
}
LUTlist_builtin = newArray("Fire", "Grays", "Ice", "Spectrum", "3-3-2 RGB", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow", "Red/Green");
LUTlist = Array.concat(LUTlist_builtin, LUTlist);

// Choose image channels and threshold value
Dialog.create("GP analysis parameters");
Dialog.addString("Input File Extension:", InputFileExt);
Dialog.addString("Short Results Descriptor:", "");

Dialog.addMessage("------------------------------------------- Image channels -------------------------------------------");
Dialog.addNumber("Membrane dye - Ordered channel:", 1);
Dialog.addNumber("Membrane dye - Disordered channel:", 2);
Dialog.addNumber("Immunofluorescence channel (0 = None):", 0);

Dialog.addMessage("------------------------------------------- GP Calculation -------------------------------------------");
Dialog.addChoice("Use native bit depth?",YNquestion, "Yes");
Dialog.addNumber("G factor (1 if unknown):", 1);
Dialog.addChoice("Apply G factor to image data or histograms?",GFapplication, "Histogram data (post GP calc)");
Dialog.addChoice("Lookup Table for GP Images:", LUTlist1, "Grays");

Dialog.addMessage("------------------------------------------- Mask Thresholds ------------------------------------------");
Dialog.addChoice("Threshold method: ", ThreshList, "Normal");
Dialog.addNumber("Normal method: GP-mask threshold from", 15);
Dialog.addNumber("Normal method: IF-mask threshold from: ", 10);
Dialog.addChoice("Normal method: Tweak thresholds manually?",YNquestion, "Yes");

Dialog.addMessage("--------------------------------------------- HSB Images ---------------------------------------------");
Dialog.addChoice("Do you want to generate HSB images?",YNquestion, "Yes");
Dialog.addChoice("HSB Brightness from: ", HSBrightChannelOptions, "Ordered channel");
Dialog.addChoice("Lookup Table for GP data: ",LUTlist, "16_colors");
Dialog.addChoice("Apply fixed intensity range to all images?",YNquestion, "No");

Dialog.addMessage("\n");
Dialog.show();


// Set variables from dialog input
InputFileExt = Dialog.getString();
FolderNote = Dialog.getString();

chOrdered = Dialog.getNumber();
chDisordered = Dialog.getNumber();
ch_IF = Dialog.getNumber();

UseNativeBitDepth = Dialog.getChoice();
GFactor = Dialog.getNumber();
GFactorAppliedTo = Dialog.getChoice();
GPLUTname = Dialog.getChoice();

ThresholdType = Dialog.getChoice();
GPmaskThreshold = Dialog.getNumber();
IFmaskThreshold = Dialog.getNumber();
TweakThreshold =Dialog.getChoice();

MakeHSBimages = Dialog.getChoice();
HSBrightChannel = Dialog.getChoice();
HSBLUTName = Dialog.getChoice();
ApplySameBrightness =Dialog.getChoice();


// these have to survive inside the HSB function
var GPminUserSet = -1;
var GPmaxUserSet = 1;

// Check we have something to process
listDir = ListFiles(dir, InputFileExt);
numberOfImages = listDir.length;
if (numberOfImages == 0) {exit("There are no files with extension \"" + InputFileExt + "\"in folder \n" + dir);}

// Check IF channel exists if we plan to use it
if (ch_IF == 0) {
	if (HSBrightChannel == "Immunofluoresence channel" || HSBrightChannel == "Sum O+D and also IF channel") {
		
		Dialog.create("GP analysis parameters");
		Dialog.addMessage("Whoops! You want to use the IF channel but haven't specified a channel number for it.");
		Dialog.addNumber("Immunofluorescence channel (0 = None):", 3);
		Dialog.addMessage("\n");
		Dialog.show();
		ch_IF = Dialog.getNumber();

		if (ch_IF == 0) {
			exit("You still have not specified an immunofluoresence channel!");
		}
	}
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

ordered_images_Dir = InputImages_Dir + "Ordered Images" + File.separator;
File.makeDirectory(ordered_images_Dir);

disordered_images_Dir = InputImages_Dir + "Disordered Images" + File.separator;
File.makeDirectory(disordered_images_Dir);

GP_images_Dir = results_Dir + "GP-masked GP images" + File.separator;
File.makeDirectory(GP_images_Dir);

histogramGP_Dir = GP_images_Dir + "Histograms" + File.separator;
File.makeDirectory(histogramGP_Dir);

rawGP_images_Dir = results_Dir + "GP images" + File.separator;
File.makeDirectory(rawGP_images_Dir);


if (MakeHSBimages == "Yes") {
 HSB_Dir = results_Dir + "HSB images" + File.separator;
 File.makeDirectory(HSB_Dir);

 if (ApplySameBrightness == "No") {
	HSB_LUTs_Dir = HSB_Dir + "colorbars" + File.separator;
	File.makeDirectory(HSB_LUTs_Dir);
 }

}


if (ch_IF != 0) {
 IF_images_Dir = InputImages_Dir + "Immunofluorescence Images" + File.separator;
 File.makeDirectory(IF_images_Dir);

 GP_IF_images_Dir = results_Dir + "IF-masked GP images" + File.separator;
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
	run("Bio-Formats Importer", "open='" + dir + imgName + "' color_mode=Default view=[Standard ImageJ] stack_order=Default virtual split_channels");
	
	// set window titles
	ordWindowTitle = imgName + " - C=" + chOrdered - 1;
	disWindowTitle = imgName + " - C=" + chDisordered - 1;
	if (ch_IF != 0) {
		imfWindowTitle = imgName + " - C=" + ch_IF - 1;
	}

	//select ordered
	selectWindow(ordWindowTitle);
	if (UseNativeBitDepth == "No") {
		run("8-bit");
		run("Grays");
		run("32-bit");
	}
	saveAs("Tiff", ordered_images_Dir + imgName + "_ordered_32bit.tif");
	rename(ordWindowTitle);

	//select disordered, apply GFactor correction
	selectWindow(disWindowTitle);
	run("Grays");

	if (UseNativeBitDepth == "No") {
		run("8-bit");
		run("32-bit");
	}
	
	if (GFactorAppliedTo == "Image data (pre GP calc)") {
		run("Multiply...","value=" + GFactor);
		saveAs("Tiff", disordered_images_Dir + imgName + "_disordered_GFactorCorrected_32bit.tif");
	} else {
		saveAs("Tiff", disordered_images_Dir + imgName + "_disordered_32bit.tif");
	}
	
	rename(disWindowTitle); // restore the window name after saving this image

	if (ch_IF != 0) {
		selectWindow(imfWindowTitle);
		run("Grays");
		if (UseNativeBitDepth == "No") {
			run("8-bit");
			run("32-bit");
		}
		saveAs("Tiff", IF_images_Dir + imgName + "_IF_32bit.tif");
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
	SumMaskName = "SumMask";
	rename(SumMaskName);
		 
	if (ThresholdType == "Normal") {
		if (TweakThreshold == "Yes"){
			if (i == 0) { // first image in the list
		 		setBatchMode("show");
				setOption("BlackBackground", true);
				getMinAndMax(currGPMin,currGPMax);
				setThreshold(GPmaskThreshold, currGPMax);
				run("Threshold...");
				waitForUser("Summed Intensity Image for GP Mask\nAdjust threshold and press OK");
				if (isOpen('Threshold')) {selectWindow('Threshold'); run('Close');}
				run("Threshold...");
				getThreshold(GPmaskThreshold,currGPMax);
				if (isOpen('Threshold')) {selectWindow('Threshold'); run('Close');}
		 		setBatchMode("hide");
			}
		} else {
			getMinAndMax(currGPMin,currGPMax);
			setThreshold(GPmaskThreshold, currGPMax);
		}

	} else if (ThresholdType == "Otsu") {
		setAutoThreshold("Otsu dark");
	}

	
	run("Convert to Mask");
	run("Subtract...", "value=254");
	rename(SumMaskName);
	imageCalculator("Multiply create", SumMaskName, rawGPname);
	run(GPLUTname);
	GPname = imgName + " - GP";
	saveAs("tiff", GP_images_Dir + imgName + "_maskedGP");
	rename(GPname);
	selectWindow("SumMask");
	close();

	// histograms
	HistoFileName=histogramGP_Dir + imgName + "_Histogram.tsv";
	HistogramGeneration(GPname, HistoFileName);

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
					setBatchMode("show");
					setOption("BlackBackground", true);
					getMinAndMax(currIFMin,currIFMax);
					setThreshold(IFmaskThreshold, currIFMax);
	 	 			run("Threshold...");
	 	 			waitForUser("Immunofluoresence channel image for IF-mask\nAdjust threshold and press OK");
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
		imageCalculator("Multiply create", GPname, IFmaskName);
		rename(GPIFName);
		selectWindow(GPIFName);
		run(GPLUTname);
		saveAs("tiff", GP_IF_images_Dir + imgName + "_GP-IF");
		rename(GPIFName);
		HistoFileName=histogramIF_Dir + imgName + "_GP-IF_Histogram.tsv";
		HistogramGeneration(GPIFName, HistoFileName);

		selectWindow(IFmaskName);
		close();
	}

	if (MakeHSBimages=="Yes") {

		// Select and copy the channel to be used for 'brightness' (the raw ord/dis/IF image)
		if (HSBrightChannel=="Ordered channel") {
			HSBgeneration(ordWindowTitle, "ordered");
		} else if (HSBrightChannel=="Disordered channel") {
			HSBgeneration(disWindowTitle, "disordered");
		} else if (HSBrightChannel=="Immunofluoresence channel") {
			HSBgeneration(imfWindowTitle, "immunofl");
		} else if (HSBrightChannel=="Sum of Ordered + Disordered") {
			HSBgeneration(sumName, "sum ord+dis");
		} else if (HSBrightChannel=="Sum O+D and also IF channel") {
			HSBgeneration(sumName, "sum ord+dis");
			HSBgeneration(imfWindowTitle, "immunofl");
		}

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

	//run("Set Measurements...", "min limit display redirect=None decimal=5"); // ? not sure what this does here

	// Select and copy the channel to be used for 'hue' (the GP image)
	selectWindow(rawGPname);
	run("Duplicate..."," ");
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

	time0 = getTime();

	selectWindow(HueChannel);
	run("RGB Color");
	run("Split Channels");

	selectWindow(BrightChannel);

	imageCalculator("Multiply create 32-bit", HueChannel + " (red)", BrightChannel);
	rename("bR");
	run("8-bit");

	imageCalculator("Multiply create 32-bit", HueChannel + " (green)", BrightChannel);
	rename("bG");
	run("8-bit");

	imageCalculator("Multiply create 32-bit", HueChannel + " (blue)", BrightChannel);
	rename("bB");
	run("8-bit");

	run("Merge Channels...", "red=bR green=bG blue=bB gray=*None*");
	selectWindow("RGB");
	HSBname = imgName + " HSB";
	rename(HSBname);
	saveAs("tiff", HSB_Dir + imgName + "_HSB by " + OutfileSuffix);

	selectWindow(HueChannel + " (red)");
	close();
	selectWindow(HueChannel + " (green)");
	close();
	selectWindow(HueChannel + " (blue)");
	close();
	selectWindow(BrightChannel);
	close();

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
	saveAs("tiff", SaveFileName);
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
