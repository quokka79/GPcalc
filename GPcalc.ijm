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
HSBrightChannelOptions = newArray("Ordered channel","Disordered channel","Immunofluoresence channel");
ThreshList = newArray("Normal","Otsu");

// get all the available LUTs
Lut_Dir = getDirectory("luts");
LUTlist = ListFiles(Lut_Dir, ".lut");
for (q = 0; q < LUTlist.length; q++) {
   LUTlist[q] =  replace(LUTlist[q], ".lut", "");
}
LUTlist_builtin = newArray("Fire", "Grays", "Ice", "Spectrum", "3-3-2 RGB", "Red", "Green", "Blue", "Cyan", "Magenta", "Yellow", "Red/Green");
LUTlist = Array.concat(LUTlist_builtin, LUTlist);

// Choose image channels and threshold value
Dialog.create("GP analysis parameters");
Dialog.addString("Input File Extension:  ", InputFileExt);
Dialog.addString("Short Results Descriptor:  ", "");
Dialog.addNumber("Acquisition ordered channel:  ", 1);
Dialog.addNumber("Acquisition disordered channel:  ", 2);
Dialog.addMessage("\n");
Dialog.addChoice("Use native bit depth?",YNquestion, "Yes");
Dialog.addMessage("\n");
Dialog.addNumber("Lower Threshold Value for GP the mask:  ", 15);
Dialog.addChoice("Lookup Table for GP Images:  ", LUTlist1, "Grays");
Dialog.addMessage("\n");
Dialog.addNumber("Immunofluorescence channel (0 = None):  ", 0);
Dialog.addChoice("IF Channel Threshold by: ", ThreshList, "Normal");
Dialog.addNumber("Normal Threshold pixels over: ", 10);
Dialog.addMessage("\n");
Dialog.addNumber("G factor (1 if unknown):  ", 1);
Dialog.addChoice("Apply G factor to image data or histograms?",GFapplication, "Histogram data (post GP calc)");
Dialog.addMessage("\n");
Dialog.addChoice("Do you want to generate HSB images?",YNquestion, "Yes");
Dialog.addChoice("HSB Brightness from: ", HSBrightChannelOptions, "Ordered channel");
Dialog.addChoice("Apply brightness from first image to all?",YNquestion, "No");
Dialog.addChoice("Lookup Table for HSB Images: ",LUTlist, "16_colors");
Dialog.addMessage("\n");
Dialog.show();


// Feeding variables from dialog choices
InputFileExt = Dialog.getString();
FolderNote = Dialog.getString();
chOrdered = Dialog.getNumber();
chDisordered = Dialog.getNumber();
UseNativeBitDepth = Dialog.getChoice();
GPmaskThreshold = Dialog.getNumber();
lut1 = Dialog.getChoice();
ch_IF = Dialog.getNumber();
ThresholdType = Dialog.getChoice();
tc = Dialog.getNumber();
GFactor = Dialog.getNumber();
GFactorAppliedTo = Dialog.getChoice();
MakeHSBimages = Dialog.getChoice();
HSBrightChannel = Dialog.getChoice();
ApplySameBrightness =  Dialog.getChoice();
HSBLUTName = Dialog.getChoice();

// these have to survive inside the HSB function
var GPminUserSet = -1;
var GPmaxUserSet = 1;

// Check we have something to process
listDir = ListFiles(dir, InputFileExt);
numberOfImages = listDir.length;
if (numberOfImages == 0) {exit("There are no files with extension \"" + InputFileExt + "\"in folder \n" + dir);}

// Check IF channel exists if we plan to use it
if (ch_IF == 0) {
   if (HSBrightChannel == "Immunofluoresence channel") {
      exit("You have not specified an immunofluoresence channel!");
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

ordered_images_Dir = results_Dir + "Ordered Images" + File.separator;
File.makeDirectory(ordered_images_Dir);

disordered_images_Dir = results_Dir + "Disordered Images" + File.separator;
File.makeDirectory(disordered_images_Dir);

GP_images_Dir = results_Dir + "GP images" + File.separator;
File.makeDirectory(GP_images_Dir);

histogramGP_Dir = GP_images_Dir + "Histograms" + File.separator;
File.makeDirectory(histogramGP_Dir);

rawGP_images_Dir = results_Dir + "raw GP images" + File.separator;
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
   IF_images_Dir = results_Dir + "Immunofluorescence Images" + File.separator;
   File.makeDirectory(IF_images_Dir);

   GP_IF_images_Dir = results_Dir + "GP-IF images" + File.separator;
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

// process each image
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
      setThreshold(GPmaskThreshold * 2, 510);
      run("Convert to Mask");
      run("Subtract...", "value=254");
      rename("SumMask");
      imageCalculator("Multiply create", "SumMask", rawGPname);
      run(lut1);
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
            getMinAndMax(currMin,currMax);
            setThreshold(tc, currMax);
         } else if (ThresholdType == "Otsu") {
            setAutoThreshold("Otsu dark");
         }
         run("Options...", "black");
         run("Convert to Mask");
         run("Divide...","value=255");
         setMinAndMax(0.0,1.0);;

         GPIFName = imgName + " - GPIF";
         imageCalculator("Multiply create", GPname, IFmaskName);
         rename(GPIFName);
         selectWindow(GPIFName);
         run(lut1);
         saveAs("tiff", GP_IF_images_Dir + imgName + "_GP-IF");
         rename(GPIFName);
         HistoFileName=histogramIF_Dir + imgName + "_GP-IF_Histogram.tsv";
         HistogramGeneration(GPIFName, HistoFileName);

         selectWindow(IFmaskName);
         close();
      }

      if (MakeHSBimages=="Yes") {
         	HSBgeneration();
      }

      closeAllImages();

      FractionDone = i / numberOfImages;
      showProgress(FractionDone);
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
    print(HistogramOutFile, "Intensity    Counts    Smooth    Norm Av Dist    GP    GP GF-corrected");
    for (m = 0; m < 256; m++) {
        NAvDist[m] = 100 * Smo[m] / Sa;
        print(HistogramOutFile, Int[m] + "    " + Cou[m] + "    " + Smo[m] + "    " + NAvDist[m] + "    " + GPuncorrected[m] + "    " + GPcorrected[m]);
    }
    File.close(HistogramOutFile);
}


function HSBgeneration() {

    // Select and copy the channel to be used for 'brightness' (the raw ord/dis/IF image)
    if (HSBrightChannel=="Ordered channel") {
        selectWindow(ordWindowTitle);
    } else if (HSBrightChannel=="Disordered channel") {
        selectWindow(disWindowTitle);
    } else {
        selectWindow(imfWindowTitle);
    }
    BrightChannel = "BrightnessChannel";
    run("Duplicate..."," ");
    rename(BrightChannel);
    run("Enhance Contrast", "saturated=0.5 normalize");

    //run("Set Measurements...", "  min limit display redirect=None decimal=5"); // ? not sure what this does here

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
    
    getMinAndMax(GPmin,GPmax);

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
    saveAs("tiff", HSB_Dir + imgName + "_HSB by " + HSBrightChannel);

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
            MakeLUTbar(HSBLUTName, GPmin, GPmax, HSB_Dir + "All Images - LUT annotated");
        }
    } else {
        MakeLUTbar(HSBLUTName, GPmin, GPmax, HSB_LUTs_Dir + imgName + "_LUT annotated");
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
    print("GP images analysis macro");
    print("   Quantitative Imaging of Membrane Lipid Order in Cells and Organisms");
    print("   Dylan M. Owen, Carles Rentero, Astrid Magenau, Ahmed Abu-Siniyeh and Katharina Gaus");
    print("   Nature Protocols 2011");
    print("   version June 2011");
    print("\n");
    print("Ordered channel: " + chOrdered);
    print("Disordered channel: " + chDisordered);
    print("   Lower threshold value: " + GPmaskThreshold);
    if (ch_IF != 0) {
        print("Channel IF: " + ch_IF);
        print("   Lower threshold value IF mask: " + tc); }
    print("");
    print("GP images (" + (listGP.length-1) + ") saved at:");
    print("  " + GP_images_Dir);
    print("G factor: " + GFactorSupplied);
    print("Scale color for GP images: " + lut1);
    print("");
    if (ch_IF != 0) {
        listGP2 = getFileList(GP_IF_images_Dir);
        print("GP-IF images (" + (listGP2.length-1) + ") saved at:");
        print("  " + GP_IF_images_Dir);
        print(""); }
    if (MakeHSBimages=="Yes") {
        print("HSB images saved at:");
        print("  " + HSB_Dir);
        print("");
    }
    print("");
    print("Execution time: " + d2s(TOTALtime,2) + " seconds.");
    print("");
    print("Analysis date: "+DayNames[dayOfWeek]+", "+dayOfMonth+" "+MonthNames[month]+" "+year+" - "+hours+":"+minutes);
    print("ImageJ version " + getVersion());

    selectWindow("Log");
    saveAs("Text", results_Dir + "Log GP images generation "+year+"-"+months+"-"+dayOfMonths+" "+hours+"h"+minutes);

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
