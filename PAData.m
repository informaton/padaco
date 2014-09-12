% ======================================================================
%> @file PAData.cpp
%> @brief Accelerometer data loading class.
% ======================================================================
%> @brief The class loads and stores accelerometer data used in the 
%> Physical Activity monitoring project aimed to reduce obesity 
%> and improve child health.
% ======================================================================
classdef PAData < handle
   properties
       %> @brief Type of acceleration stored; can be 
       %> - raw This is not processed
       %> - count This is preprocessed
       accelType;
       %> @brief Structure of raw x,y,z accelerations.  Fields are:
       %> @li - x x-axis
       %> @li - y y-axis
       %> @li - z z-axis       
       accelRaw;
       %> @brief Structure of actigraph derived counts for x,y,z acceleration readings.  Fields are:
       %> @li - x x-axis
       %> @li - y y-axis
       %> @li - z z-axis       
       accelCount;
       %> @brief Structure of inclinometer values.  Fields include:
       %> @li - off
       %> @li - standing
       %> @li - sitting
       %> @li - lying   
       inclinometer;
       %> @brief Steps - unknown?  Maybe pedometer type reading?  
       steps;
       %> @brief Magnitude of tri-axis acceleration vectors.
       vecMag;
       %> @brief Time of day (HH:MM:SS) of sample reading
       timeStamp;
       %> @brief Luminance levels.
       lux;
       %> @brief Start Time
       startTime;
       %> @brief Start Date
       startDate;       
       %> Durtion of the sampled data in seconds.       
       durationSec;
       %> @brief The numeric value for each date time sample provided by
       %the file name.
       dateTimeNum;

       %> @brief Struct of line handle properties corresponding to the
       %> fields of linehandle.  These are derived from the input files
       %> loaded by the PAData class.
       lineproperty;
       
       label;
       color;
       offset;
       scale;
       yDelta;
       
   end
   
   properties (Access = private)
       %> @brief Pathname of file containing accelerometer data.
       pathname;
       %> @brief Name of file containing accelerometer data that is loaded.
       filename;

       %> Current window.  Current position in the raw data.  The first window is '1' (i.e. not zero because this is MATLAB programming)
       curWindow; 
       %> Number of samples contained in the data (accelRaw.x)
       durSamples;
       %> @brief Defined in the accelerometer's file output and converted to seconds.
       %> This is, most likely, the sampling rate of the output file.
       windowPeriodSec;
       %> @brief Window duration (in seconds). 
       %> This can be adjusted by the user, but is 30 s by default.
       windowDurSec;    
       
       %> @brief Initial aggregation duration in minutes.  Frames are
       %comprised of consecutive aggregated windows of data.
       aggregateDurMin;
       
       %> @brief Frame duration minute's units.  Features are extracted
       %from frames.
       %> @note  Frame duration is calculated as
       %> obj.frameDurMin+obj.frameDurHour*60
       frameDurMin;
       %> @brief Frame duration hour's units.  Features are extracted from frames. 
       %> @note  Frame duration is calculated as
       %> obj.frameDurMin+obj.frameDurHour*60
       frameDurHour;
       
       
       %> @brief Number of bins that the time series data can be aggregated
       %> into.  It is calculated as the ceiling of the study's duration in
       %> minutes divided by aggregate duration in minutes.
       numBins;
       
       %> @brief
       bins;
       
       %> @brief Vector magnitude signal at frame rate.
       frames;
       
       %> @brief Number of frames that the time series data can be aggregated
       %> into.  It is calculated as the ceiling of the study's duration in
       %> minutes divided by the current frame duration in minutes.       
       numFrames;

       %> @brief Struct of features as extracted from frames.
       features;

       %> @brief Sample rate of time series data.
       sampleRate;
   end
   
   
   methods
       
       % ======================================================================
       %> @brief Constructor for PAData class.
       %> @param fullFilename The full filename (i.e. with pathname) of accelerometer data to load.
       %> @param pStruct Optional struct of parameters to use.  If it is not
       %> included then parameters from getDefaultParameters method are used.
       %> @retval Instance of PAData.
       %fullFile = '~/Google Drive/work/Stanford - Pediatrics/sampledata/female child 1 second epoch.csv'
       % =================================================================
       function obj = PAData(fullFilename,pStruct)
           if(exist(fullFilename,'file'))
               [p,name,ext] = fileparts(fullFilename);
               if(isempty(p))
                   obj.pathname = pwd;
               else
                   obj.pathname = p;
               end
               obj.filename = strcat(name,ext);
           end
           if(nargin<2 || isempty(pStruct))
               pStruct = obj.getDefaultParameters();
           end
           
           
           
           % Can summarize these with defaults from below...last f(X) call.
           %            obj.aggregateDurMin = 1;
           %            obj.frameDurMin = 0;
           %            obj.frameDurHour = 1;
           %            obj.curWindow = 1;
           %            obj.windowDurSec = 60*5;  %this is the window size                     
           fields = fieldnames(pStruct);
           for f=1:numel(fields)
               
               %need to make sure we are not overwriting the filename we just
               %brought in
               if(~strcmpi(fields{f},'pathname') && ~strcmpi(fields{f},'filename'))
                   obj.(fields{f}) = pStruct.(fields{f});
               end
           end                
           
           obj.numBins = 0;
           obj.bins = [];
           obj.numFrames = 0;
           obj.features = [];
           
           % Removed in place of getSampleRate()
           %            obj.sampleRate.accelRaw = 40;
           %            obj.sampleRate.inclinometer = 40;
           %            obj.sampleRate.lux = 40;
           %            obj.sampleRate.vecMag = 40;
           
           
           % label properties for visualization
           obj.label.timeSeries.accelRaw.x.string = 'X_R_A_W';
           obj.label.timeSeries.accelRaw.y.string = 'Y_R_A_W';
           obj.label.timeSeries.accelRaw.z.string = 'Z_R_A_W';
           
           obj.label.timeSeries.vecMag.string = 'Magnitude';
           obj.label.timeSeries.steps.string = 'Steps';
           obj.label.timeSeries.lux.string = 'Lux';
           
           obj.label.timeSeries.inclinometer.standing.string = 'Standing';
           obj.label.timeSeries.inclinometer.sitting.string = 'Sitting';
           obj.label.timeSeries.inclinometer.lying.string = 'Lying';
           obj.label.timeSeries.inclinometer.off.string = 'Off';
           
%            pStruct.label.timeSeries.accelRaw.x.position = [0 0 0];
%            pStruct.label.timeSeries.accelRaw.y.position = [0 0 0];
%            pStruct.label.timeSeries.accelRaw.z.position = [0 0 0];
%            
%            pStruct.label.timeSeries.vecMag.position = [0 0 0];
%            pStruct.label.timeSeries.steps.position = [0 0 0];
%            pStruct.label.timeSeries.lux.position = [0 0 0];
%            
%            pStruct.label.timeSeries.inclinometer.standing.position = [0 0 0];
%            pStruct.label.timeSeries.inclinometer.sitting.position = [0 0 0];
%            pStruct.label.timeSeries.inclinometer.lying.position = [0 0 0];
%            pStruct.label.timeSeries.inclinometer.off.position = [0 0 0];
           obj.loadFile();
       end

       % ======================================================================
       %> @brief Returns a structure of an instnace PAData's time series data.
       %> @param obj Instance of PAData.
       %> @param structType Optional string identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default)
       %> @li @c features
       %> @li @c aggregate bins
       %> @retval A 2x1 vector with start, stop range of the current window returned as
       %> samples beginning with 1 for the first sample.  The second value
       %> (i.e. the stop sample) is capped at the current value of
       %> durationSamples().
       %> @note This uses instance variables windowDurSec, curWindow, and sampleRate to
       %> determine the sample range for the current window.
       % =================================================================      
       function correctedWindowRange = getCurWindowRange(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end
           
           correctedWindowRange = obj.getCurUncorrectedWindowRange(structType);
                   
           switch lower(structType)
               case 'time series'
                   maxValue = obj.durationSamples();
               case 'aggregate bins'
                   maxValue = obj.getBinCount();
               case 'features'
                   maxValue = obj.getFrameCount();
               otherwise
                   fprintf('This structure type is not handled (%s).\n',structType);
                   maxValue = nan;                   
           end
           correctedWindowRange(2) = min([correctedWindowRange(2),maxValue]);
       end
       
       % ======================================================================
       %> @brief Returns the current windows range
       %> @param obj Instance of PAData.
       %> @param structType Optional string identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default)
       %> @li @c features
       %> @li @c aggregate bins
       %> @retval A 2x1 vector with start, stop range of the current window returned as
       %> samples beginning with 1 for the first sample.  
       %> @note This uses instance variables windowDurSec, curWindow, and sampleRate to
       %> determine the sample range for the current window.  The first
       %value is floored and the second is ceil'ed.
       % =================================================================      
       function windowRange = getCurUncorrectedWindowRange(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end
           
           windowResolution = obj.getSamplesPerWindow(structType);
           windowRange = (obj.curWindow-1)*windowResolution+[1,windowResolution];
           windowRange = [floor(windowRange(1)), ceil(windowRange(2))];
       end
       
       % ======================================================================
       %> @brief Returns the number of sample units (samples, bins, frames) for the
       %> for the current window resolution (duration in seconds).
       %> @param obj Instance of PAData.       
       %> @param structType Optional string identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins
       %> @retval Number of samples, frames, or bins per window display;
       %not necessarily an integer result; can be a fraction.
       %> @note Calcuation based on instance variables windowDurSec and
       %> sampleRate
       function windowDur = getSamplesPerWindow(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end
           windowDur = obj.windowDurSec*obj.getWindowSamplerate(structType);
       end  
       
       % --------------------------------------------------------------------
       %> @brief Returns the sampling rate for the current window display selection
       %> @param obj Instance of PAData   
       %> @param structType Optional string identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - sample units are sample points
       %> @li @c features - sample units are frames
       %> @li @c aggregate bins - sample units are bins
       %> @retval Sample rate of the data being viewed in Hz.  
       % --------------------------------------------------------------------
       function windowRate = getWindowSamplerate(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end
           
           switch lower(structType)
               case 'time series'                   
                   windowRate = obj.getSampleRate();
               case 'aggregate bins'
                   windowRate = obj.getBinRate();
               case 'features'
                   windowRate = obj.getFrameRate();
               otherwise
                   fprintf('This structure type is not handled (%s).\n',structType);
           end
                      
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the samplerate of the x-axis accelerometer.
       %> @param obj Instance of PAData
       %> @retval fs Sample rate of the x-axis accelerometer.
       % --------------------------------------------------------------------
       function fs = getSampleRate(obj)
           fs = obj.sampleRate;           
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the frame rate in units of frames/second.
       %> @param obj Instance of PAData
       %> @retval fs Frames rate in Hz.
       % --------------------------------------------------------------------
       function fs = getFrameRate(obj)
           [frameDurationMinutes, frameDurationHours] = obj.getFrameDuration();
           frameDurationSeconds = frameDurationMinutes*60+frameDurationHours*60*60;
           fs = 1/frameDurationSeconds;
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the aggregate bin rate in units of aggregate bins/second.
       %> @param obj Instance of PAData
       %> @retval fs Aggregate bins per second.
       % --------------------------------------------------------------------
       function fs = getBinRate(obj)
           fs = 1/60/obj.aggregateDurMin;
       end
       
       % --------------------------------------------------------------------
       %> @brief Set the current window for the instance variable accelObj
       %> (PAData)
       %> @param obj Instance of PAData
       %> @param window The window to set curWindow to.
       %> @retval curWindow The current value of instance variable curWindow.
       %> @note If the input argument for window is negative or exceeds 
       %> the maximum window value for the time series data, then it is not used
       %> and the curWindow value is retained, and also returned.
       % --------------------------------------------------------------------
       function curWindow = setCurWindow(obj,window)
           if(window>0 && window<=obj.getWindowCount())
               obj.curWindow = window;
           end
           %returns the current window, wether it be 'window' or not.
           curWindow = obj.getCurWindow();
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the current window.
       %> @param obj Instance of PAData
       %> @retval curWindow The current window;
       % --------------------------------------------------------------------
       function curWindow = getCurWindow(obj)
           curWindow = obj.curWindow;
       end    
       
       % --------------------------------------------------------------------
       %> @brief Set the aggregate duration (in minutes) instance variable.
       %> @param obj Instance of PAData
       %> @param aggregateDurationMin The aggregate duration to set aggregateDurMin to.
       %> @retval aggregateDurationMin The current value of instance variable aggregateDurMin.
       %> @note If the input argument for aggregateDurationMin is negative or exceeds 
       %> the current frame duration value (in minutes), then it is not used
       %> and the current frame duration is retained (and also returned).
       % --------------------------------------------------------------------
       function aggregateDurationMin = setAggregateDurationMinutes(obj,aggregateDurationMin)
           if(aggregateDurationMin>0 && aggregateDurationMin<=obj.getAggregateDuration())
               obj.aggregateDurMin = aggregateDurationMin;
           end
           %returns the current frame duration, whether it be 'frameDurationMin' or not.
           aggregateDurationMin = obj.getAggregateDuration();
       end
       
       % --------------------------------------------------------------------
       % @brief Returns the current aggregate duration in minutes.
       % @param obj Instance of PAData
       % @retval aggregateDuration The current window;
       % --------------------------------------------------------------------
       function aggregateDuration = getAggregateDuration(obj)
           aggregateDuration = obj.aggregateDurMin;
       end       
       
       % --------------------------------------------------------------------
       %> @brief Returns the total number of aggregated bins the data can be divided
       %> into based on frame rate and the duration of the time series data.
       %> @param obj Instance of PAData
       %> @retval binCount The total number of frames contained in the data.
       %> @note In the case of data size is not broken perfectly into frames, but has an incomplete frame, the
       %> window count is rounded down.  For example, if the frame duration 1 min, and the study is 1.5 minutes long, then 
       %> the frame count is 1.
       % --------------------------------------------------------------------
       function binCount = getBinCount(obj)
           binCount = floor(obj.durationSec/60/obj.getAggregateDuration());        
       end
       
       
       % --------------------------------------------------------------------
       %> @brief Set the frame duration (in minutes) instance variable.
       %> @param obj Instance of PAData
       %> @param frameDurationMin The frame duration to set frameDurMin to.
       %> @retval frameDurationMin The current value of instance variable frameDurMin.
       %> @note If the input argument for frameDurationMin is negative or exceeds 
       %> the maximum duration of data, then it is not used
       %> and the current frame duration is retained (and also returned).
       % --------------------------------------------------------------------
       function frameDurationMin = setFrameDurationMinutes(obj,frameDurationMin)
           if(frameDurationMin>=0 && frameDurationMin<=obj.durationSec/60)
               obj.frameDurMin = frameDurationMin;
           end
           %returns the current frame duration, whether it be 'frameDurationMin' or not.
           [frameDurationMin,~] = obj.getFrameDuration();
       end
       
       % --------------------------------------------------------------------
       %> @brief Set the frame duration (hours) instance variable.
       %> @param obj Instance of PAData
       %> @param frameDurationHours The frame duration to set frameDurHours instance variable to.
       %> @retval frameDurationHours The current value of instance variable frameDurHour.
       %> @note If the input argument for frameDurationHours is negative or exceeds 
       %> the maximum duration of data, then it is not used
       %> and the current frame duration is retained (and also returned).
       % --------------------------------------------------------------------
       function frameDurationHours = setFrameDurationHours(obj,frameDurationHours)
           if(frameDurationHours>=0 && frameDurationHours<=obj.durationSec/60/60)
               obj.frameDurHour = frameDurationHours;
           end
           %returns the current frame duration, whether it be 'frameDurationMin' or not.
           [~,frameDurationHours] = obj.getFrameDuration();
       end
       
       
       
       
       % --------------------------------------------------------------------
       % @brief Returns the frame duration (in minutes)
       % @param obj Instance of PAData
       % @retval curFrameDurationMin The current frame duration minutes field;
       % @retval curFramDurationHour The current frame duration hours field;
       % --------------------------------------------------------------------
       function [curFrameDurationMin, curFrameDurationHour] = getFrameDuration(obj)
           curFrameDurationMin = obj.frameDurMin;
           curFrameDurationHour = obj.frameDurHour;
           
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the total number of frames the data can be divided
       %> into evenly based on frame rate and the duration of the time series data.
       %> @param obj Instance of PAData
       %> @retval frameCount The total number of frames contained in the data.
       %> @note In the case of data size is not broken perfectly into frames, but has an incomplete frame, the
       %> window count is rounded down (floor).  For example, if the frame duration 1 min, and the study is 1.5 minutes long, then 
       %> the frame count is 1.
       % --------------------------------------------------------------------
       function frameCount = getFrameCount(obj)
           [frameDurationMinutes, frameDurationHours] = obj.getFrameDuration();
           frameDurationSeconds = frameDurationMinutes*60+frameDurationHours*60*60;
           frameCount = floor(obj.durationSec/frameDurationSeconds);        
       end
       
       % --------------------------------------------------------------------
       % @brief Returns the number of samples contained in the time series data.
       % @param obj Instance of PAData
       % @retval durationSamp Number of elements contained in durSamples instance var
       %> (initialized by number of elements in accelRaw.x
       % --------------------------------------------------------------------
       function durationSamp = durationSamples(obj)
           durationSamp = obj.durSamples;
       end       
       
       % --------------------------------------------------------------------
       %> @brief Set the window duration value in seconds.  This is the
       %> displays window size (i.e. one window shown at a time), in seconds.
       %> @param obj Instance of PAData
       %> @param durSec Duration in seconds.  Must be positive.  Value is first
       %> rounded to ensure it is an integer.
       %> @retval durSec Window duration in seconds of obj.
       %> @note Instance variable curWindow is recalculated based on new
       %> window duration.
       % --------------------------------------------------------------------
       function durSec = setWindowDurSec(obj,durSec)
           durSec = round(durSec);
           if(durSec>0)
               % requires the current windowDurSec value be initialized
               % already.
               windowRange = obj.getCurWindowRange();                            
               obj.windowDurSec = durSec;
               
               %calculate the current window based on the start sample using
               %the previous versions window
               obj.setCurWindow(obj.sample2window(windowRange(1)));      
           else
               durSec = obj.windowDurSec;
           end
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the color instance variable
       %> @param obj Instance of PAData
       %> @param structType String specifying the structure type of label to retrieve.
       %> Possible values include (all are included if this is not)
       %> @li @c time series
       %> @li @c features
       %> @li @c aggregate bins
       %%> @retval color A struct of color values correspodning to the time series
       %> fields of obj.
       % --------------------------------------------------------------------
       function color = getColor(obj,structType)
           if(nargin<2 || isempty(structType))               
               color = obj.color;
           else
               fname = PAData.getStructNameFromDescription(structType);
               color = obj.color.(fname);
           end
           
       end
       

       % --------------------------------------------------------------------
       %> @brief Returns the scale instance variable
       %> @param obj Instance of PAData
       %> @param structType String specifying the structure type of label to retrieve.
       %> Possible values include (all are included if this not):
       %> @li @c time series 
       %> @li @c features
       %> @li @c aggregate bins
       %%> @retval scale A struct of scalar values correspodning to the time series
       %> fields of obj.
       % --------------------------------------------------------------------
       function scale = getScale(obj,structType)
           if(nargin<2 || isempty(structType))
               scale = obj.scale;
           else
               fname = PAData.getStructNameFromDescription(structType);
           
               scale = obj.scale.(fname);
           end
       end
       

       
       % --------------------------------------------------------------------
       %> @brief Sets the offset instance variable for a particular sub
       %> field.
       %> @param obj Instance of PAData
       %> @param fieldName Dynamic field name to set in the 'offset' struct.
       %> @note For example if fieldName = 'timeSeries.vecMag' then
       %> obj.offset.timeSeries.vecMag = newOffset; is evaluated.
       %> @param newOffset y-axis offset to set obj.offset.(fieldName) to.
       % --------------------------------------------------------------------
       function varargout = setOffset(obj,fieldName,newOffset)
           eval(['obj.offset.',fieldName,' = ',num2str(newOffset)]);
           if(nargout>0)
               varargout = cell(1,nargout);
           end
       end
              
       % --------------------------------------------------------------------
       %> @brief Sets the scale instance variable for a particular sub
       %> field.
       %> @param obj Instance of PAData
       %> @param fieldName Dynamic field name to set in the 'scale' struct.
       %> @note For example if fieldName = 'timeSeries.vecMag' then
       %> obj.scale.timeSeries.vecMag = newScale; is evaluated.
       %> @param newScale Scalar value to set obj.scale.(fieldName) to.
       % --------------------------------------------------------------------
       function varargout = setScale(obj,fieldName,newScale)
           eval(['obj.scale.',fieldName,' = ',num2str(newScale)]);
           if(nargout>0)
               varargout = cell(1,nargout);
           end
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the label instance variable
       %> @param obj Instance of PAData
       %> @param structType String specifying the structure type of label to retrieve.
       %> Possible values include:
       %> @li @c time series (default)
       %> @li @c features
       %> @li @c aggregate bins
       %> @retval label A struct of string values which serve to label the correspodning to the time series
       %> fields of obj.
       % --------------------------------------------------------------------
       function label = getLabel(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end           
           switch lower(structType)
               case 'time series'
                   label = obj.label.timeSeries;       
               case 'features'
                   label = obj.label.features;
               otherwise
                   fprintf('This structure type is not handled (%s).\n',structType);
                   label = [];
           end
           
       end
       
       
       % --------------------------------------------------------------------
       %> @brief Returns the total number of windows the data can be divided
       %> into based on sampling rate, window resolution (i.e. duration), and the size of the time
       %> series data.
       %> @param obj Instance of PAData
       %> @retval windowCount The maximum/last window allowed
       %> @note In the case of data size is not broken perfectly into windows, but has an incomplete window, the
       %> window count is rounded up.  For example, if the time series data is 10 s in duration and the window size is 
       %> defined as 30 seconds, then the windowCount is 1.  
       % --------------------------------------------------------------------
       function windowCount = getWindowCount(obj)
           windowCount = ceil(obj.durationSec/obj.windowDurSec);
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the start and stop datenums for the study.
       %> @param obj Instance of PAData
       %> @retval startstopnum A 1x2 vector.  
       %> - startstopnum(1) The datenum of the study's start
       %> - startstopnum(2) The datenum of the study's end.
       % --------------------------------------------------------------------
       function startstopnum =  getStartStopDatenum(obj)
           startstopnum = [obj.dateTimeNum(1), obj.dateTimeNum(end)];
           
       end
       
       % ======================================================================
       %> @brief Returns the minimum and maximum amplitudes that can be
       %> displayed uner the current configuration.
       %> @param obj Instance of PAData.
       %> @retval yLim 1x2 vector containing ymin and ymax.
       % ======================================================================
       function yLim = getDisplayMinMax(obj)           
           yLim = [0, 20 ]*obj.yDelta;
       end    
       
       % ======================================================================
       %> @brief Returns the minmax value(s) for the object's (obj) time series data
       %> Returns either a structure or 1x2 vector of [min, max] values for the field
       %> specified.
       %> @param obj Instance of PAData.
       %> @param fieldType String value identifying the time series data to perform
       %> the minmax operation on.  Can be one of the following:
       %> - @b struct Returns a structure of minmax values with organization 
       %> correspoding to that found by getStruct() instance method.
       %> - @b all Returns a 1x2 vector of the global minimum and maximum
       %> value found for any of the time series data stored in obj.
       %> - @b accelRaw Returns a struct of minmax values for x,y, and z
       %> fields.        
       %> - @b vecMag Returns a 1x2 minmax vector for vecMag values.
       %> - @b lux Returns a 1x2 minmax vector for lux values.
       %> - @b inclinometer Returns a struct of minmax values for lux fields.
       %> - @b steps Returns a struct of minmax values for step fields.
       %> @retval minMax Minimum maximum values for each time series field
       %> contained in obj.getStruct() or a single 2x1 vector of min max
       %> values for the field name specified.
       % =================================================================      
       function minMax = getMinmax(obj,fieldType)
           
           % get all data for all structs.
           dataStruct = obj.getStruct('all'); 
           
           if(nargin<2 || isempty(fieldType))
               fieldType = 'all';
           end

           % get all fields
           if(strcmpi(fieldType,'all'))
               minMax = obj.getRecurseMinmax(dataStruct);
           else
               
               % if it is not a struct (and is a 'string')
               % then get the value for it.
               if(~strcmpi(fieldType,'struct'))
                   dataStruct = dataStruct.(fieldType);
               end
               minMax = obj.minmax(dataStruct);
           end
       end
       
       % ======================================================================
       %> @brief Returns the filename, pathname, and full filename (pathname + filename) of
       %> the file that the accelerometer data was loaded from.
       %> @param obj Instance of PAData
       %> @retval filename The short filename of the accelerometer data.
       %> @retval pathname The pathname of the accelerometer data.
       %> @retval fullFilename The full filename of the accelerometer data.
       % =================================================================
       function [filename,pathname,fullFilename] = getFilename(obj)
           filename = obj.filename;
           pathname = obj.pathname;
           fullFilename = fullfile(obj.pathname,obj.filename);
       end
       
       % ======================================================================
       %> @brief Returns the full filename (pathname + filename) of
       %> the accelerometer data.
       %> @param obj Instance of PAData
       %> @retval fullFilename The full filenmae of the accelerometer data.
       %> @note See also getFilename()
       % =================================================================
       function fullFilename = getFullFilename(obj)
           [~,~,fullFilename] = obj.getFilename();
       end

       % ======================================================================
       %> @brief Returns the private intance variable windowDurSec.
       %> @param obj Instance of PAData
       %> @retval windowDurationSec The value of windowDurSec
       % =================================================================
       function windowDurationSec = getWindowDurSec(obj)
           windowDurationSec = obj.windowDurSec();
       end

       
       % ======================================================================
       %> @brief Load CSV header values (start time, start date, and window
       %> period).
       %> @param obj Instance of PAData.
       %> @param fullFilename The full filename to open and examine.
       % =================================================================
       function loadFileHeader(obj,fullFilename)
           %  ------------ Data Table File Created By ActiGraph GT3XPlus ActiLife v6.9.2 Firmware v3.2.1 date format M/d/yyyy Filter Normal -----------
           %  Serial Number: NEO1C15110135
           %  Start Time 18:00:00
           %  Start Date 1/23/2014
           %  Window Period (hh:mm:ss) 00:00:01
           %  Download Time 12:59:00
           %  Download Date 1/24/2014
           %  Current Memory Address: 0
           %  Current Battery Voltage: 4.13     Mode = 61
           %  --------------------------------------------------           
           fid = fopen(fullFilename,'r');
           if(fid>0)
               try
                   tline = fgetl(fid);
                   commentLine = '------------';
                   %make sure we are dealing with a file which has a header
                   if(strncmp(tline,commentLine, numel(commentLine)))
                       fgetl(fid);
                       tline = fgetl(fid);
                       exp = regexp(tline,'^Start Time (.*)','tokens');
                       if(~isempty(exp))
                           obj.startTime = exp{1}{1};
                       else
                           obj.startTime = 'N/A';
                       end
                       %  Start Date 1/23/2014
                       tline = fgetl(fid);
                       obj.startDate = strrep(tline,'Start Date ','');
                       
                       % Pull the following line from the file and convert hh:mm:ss
                       % to total seconds
                       %  Window Period (hh:mm:ss) 00:00:01
                       a=fscanf(fid,'%*s %*s %*s %d:%d:%d');
                       obj.windowPeriodSec = [3600 60 1]* a;                       
                   else
                       % unset - we don't know - assume 1 per second
                       obj.windowPeriodSec = 1;
                       obj.startTime = 'N/A';
                       obj.startDate = 'N/A';
                       fprintf(' File does not include header.  Default values set for start date and windowPeriodSec (1).\n');
                   end
                   fclose(fid);
               catch me
                   showME(me);
               end
           end
       end       
       
       % ======================================================================
       %> @brief Returns header values as a single, printable string.  
       %> Results include
       %> - Filename
       %> - Duration ([dd] Days, [hh] hr [mm] min [ss] sec]
       %> - Window count
       %> - Start Date
       %> - Start Time
       %> @param obj Instance of PAData.
       %> @retval headerStr Character array listing header fields and
       %> corresponding values.  Field and values are separated by colon (:), 
       %> while field:values are separated from each other with newlines (\n).
       % =================================================================
       function headerStr = getHeaderAsString(obj)
           numTabs = 16;
           durStr = strrep(strrep(strrep(strrep(datestr(datenum([0 0 0 0 0 obj.durationSec]),['\n',repmat('\t',1,numTabs),'dd x1\tHH x2\n',repmat('\t',1,numTabs),'MM x3\tSS x4']),'x1','days'),'x2','hr'),'x3','min'),'x4','sec');
           %            windowPeriod = datestr(datenum([0 0 0 0 0 obj.windowPeriodSec]),'HH:MM:SS');
           %            obj.getWindowCount,windowPeriod
           
           headerStr = sprintf('Filename:\t%s\nStart Date: %s\nStart Time: %s\nDuration:\t%s\n\nSample Rate:\t%u Hz',...
               obj.filename,obj.startDate,obj.startTime,durStr,obj.getSampleRate());
       end
       
       % ======================================================================
       %> @brief Loads an accelerometer data file.
       %> @param obj Instance of PAData.
       %> @param fullfilename (optional) Full filename to load.  If this
       %> is not included, or does not exist, then the instance variables pathname and filename
       %> are used to identify the file to load.
       % =================================================================
       function loadFile(obj,fullfilename)
       % Ensure that we have a negative number or some way of making sure
       % that we have sequential data (fill in all with Nan or -1 eg)
           
           if(nargin<2 || ~exist(fullfilename,'file'))
               fullfilename = obj.getFullFilename();
               
               %filtercell = {'*.csv','semicolon separated data';'*.*','All files (*.*)'};
               %msg = 'Select the .csv file';
               %fullfilename = uigetfullfile(filtercell,pwd,msg);
           end           

           % Have one file version for counts...
           
           if(exist(fullfilename,'file'))
               [path, name, ext] = fileparts(fullfilename);
               if(strcmpi(ext,'.raw'))
                   fullCountFilename = fullfile(path,strcat(name,'.csv'));
                   tic
                   obj.loadCountFile(fullCountFilename);
                   toc
                   tic
                   obj.loadRawFile(fullfilename);
                   toc
               else
                   obj.loadCountFile(fullfilename);
               end
           end           
       end       
       
       % ======================================================================
       %> @brief Loads an accelerometer "count" data file.
       %> @param obj Instance of PAData.
       %> @param fullCountFilename The full (i.e. with path) filename to load. 
       % =================================================================
       function loadCountFile(obj,fullCountFilename)           
           
           if(exist(fullCountFilename,'file'))
               fid = fopen(fullCountFilename,'r');
               if(fid>0)
                   try
                       obj.loadFileHeader(fullCountFilename);
%                        delimiter = ',';
                       % header = 'Date	 Time	 Axis1	Axis2	Axis3	Steps	Lux	Inclinometer Off	Inclinometer Standing	Inclinometer Sitting	Inclinometer Lying	Vector Magnitude';
                       headerLines = 11; %number of lines to skip
                       % Date,Time,Axis1,Axis2,Axis3,Steps,Lux,Inclinometer Off,Inclinometer Standing,Inclinometer Sitting,Inclinometer Lying,Vector Magnitude

                       %scanFormat = '%s %s %u16 %u16 %u16 %u8 %u8 %u8 %u8 %u8 %u8 %f32';
                       % 1/23/2014 18:00:00.000, --> MM/DD/YYYY HH:MM:SS.FFF,
%                        scanFormat = '%u8/%u8/%u16,%u8:%u8:%u8,%u16,%u16,%u16,%u8,%u8,%u8,%u8,%u8,%u8,%f32';
                       %                        scanFormat = '%f/%f/%f %f:%f:%f %u16 %u16 %u16 %u8 %u8 %u8 %u8 %u8 %u8 %f32';
                       %                        tmpDataCell = textscan(fid,scanFormat,'headerlines',headerLines);
                       %                        tic
                       
                       scanFormat = '%2d/%2d/%4d,%2d:%2d:%2d,%d,%d,%d,%d,%d,%1d,%1d,%1d,%1d,%f32';
                       frewind(fid);
                       for f=1:headerLines
                           fgetl(fid);
                       end
                       A  = fread(fid,'*char');
                       tmpDataCell = textscan(A, scanFormat);
                       
%                        scanFormat = '%[^,],%[^,],%d,%d,%d,%d,%d,%1d,%1d,%1d,%1d,%f32';
                       
                       % This takes 7.16 seconds
                       %                        tmpDataCell = textscan(fid,scanFormat,'delimiter',delimiter,'headerlines',headerLines);
                       %                        toc                       
                       %This takes 13.1 seconds
                       %                        for f=1:headerLines
                       %                            fgetl(fid);
                       %                        end
                       %
                       %                        fseek(fid,558,'bof');
                       %                        tic
                       %                        A=fscanf(fid,'%2d%*c%2d%*c%4d,%2d%*c%2d%*c%2d,%d,%d,%d,%d,%d,%1d,%1d,%1d,%1d,%f',[16,inf])';
                       %
                       %                        toc
                       
                       %Date time handling
                       %                        dateTime = strcat(tmpDataCell{1},{' '},tmpDataCell{2});
                       % dateVecFound = round(datevec(dateTime,'mm/dd/yyyy HH:MM:SS'));
                       dateVecFound = double([tmpDataCell{3},tmpDataCell{1},tmpDataCell{2},tmpDataCell{4},tmpDataCell{5},tmpDataCell{6}]);
                       samplesFound = size(dateVecFound,1);  
                       
                       startDateNum = datenum(strcat(obj.startDate,{' '},obj.startTime),'mm/dd/yyyy HH:MM:SS');
                       stopDateNum = datenum(dateVecFound(end,:));
                                              
                       windowDateNumDelta = datenum([0,0,0,0,0,obj.windowPeriodSec]);
                       
                       missingValue = nan;
                       
                       % NOTE:  Chopping off the first six columns: date time values;
                       tmpDataCell(1:6) = [];
                       
                       [dataCell, ~, obj.dateTimeNum] = obj.mergedCell(startDateNum,stopDateNum,windowDateNumDelta,dateVecFound,tmpDataCell,missingValue);
                       
                       tmpDataCell = []; %free up this memory;
                       
                       %MATLAB has some strange behaviour with date num -
                       %looks to be a precision problem
                       %math.
                       %                        dateTimeDelta2 = diff([datenum(2010,1,1,1,1,10),datenum(2010,1,1,1,1,11)]);
                       %                        dateTimeDelta2 = datenum(2010,1,1,1,1,11)-datenum(2010,1,1,1,1,10); % or this one
                       %                        dateTimeDelta = datenum(0,0,0,0,0,1);
                       %                        dateTimeDelta == dateTimeDelta2  %what is going on here???
                       
                       obj.durSamples = numel(obj.dateTimeNum);
                       numMissing = obj.durationSamples() - samplesFound;
                                              
                       if(obj.durationSamples()==samplesFound)
                           fprintf('%d rows loaded from %s\n',samplesFound,fullCountFilename); 
                       else
                           if(numMissing>0)
                               fprintf('%d rows loaded from %s.  However %u rows were expected.  %u missing samples are being filled in as %s.\n',samplesFound,fullCountFilename,numMissing,num2str(missingValue));
                           else
                               fprintf('This case is not handled yet.\n');
                               fprintf('%d rows loaded from %s.  However %u rows were expected.  %u missing samples are being filled in as %s.\n',samplesFound,fullCountFilename,numMissing,num2str(missingValue));
                           end
                       end
                       
                       obj.accelRaw.x = dataCell{1};
                       obj.accelRaw.y = dataCell{2};
                       obj.accelRaw.z = dataCell{3};
                       
                       obj.steps = dataCell{4}; %what are steps?
                       obj.lux = dataCell{5}; %0 to 612 - a measure of lumins...
                       obj.inclinometer.standing = dataCell{7};
                       obj.inclinometer.sitting = dataCell{8};
                       obj.inclinometer.lying = dataCell{9};
                       obj.inclinometer.off = dataCell{6};
                       
%                        inclinometerMat = cell2mat(dataCell(6:9));
%                        unique(inclinometerMat,'rows');
                       obj.vecMag = dataCell{10};

                       %either use windowPeriodSec or use samplerate.
                       if(obj.windowPeriodSec>0)
                           obj.sampleRate = 1/obj.windowPeriodSec;
                           obj.durationSec = obj.durationSamples()*obj.windowPeriodSec;
                       else
                           fprintf('There was an error when loading the window period second value (non-positive value found in %s).\n',fullCountFilename);
                           obj.durationSec = 0;
                       end                       
                       fclose(fid);
                   catch me
                       showME(me);
                       fclose(fid);
                   end
               else
                   fprintf('Warning - could not open %s for reading!\n',fullCountFilename);
               end
           else
               fprintf('Warning - %s does not exist!\n',fullCountFilename);
           end           
       end       
       

       % ======================================================================
       %> @brief Loads an accelerometer raw data file.  This function is
       %> intended to be called from loadFile() to ensure that
       %loadCountFile is called in advance to guarantee that the auxialiary
       %> sensor measurements are loaded into the object (obj).  The
       %> auxialiary measures (e.g. lux, vecMag) are upsampled to the
       %> sampling rate of the raw data (typically 40 Hz).
       %> @param obj Instance of PAData.
       %> @param fullRawFilename The full (i.e. with path) filename for raw data to load.
       % =================================================================
       function loadRawFile(obj,fullRawFilename)
           if(exist(fullRawFilename,'file'))
               
               fid = fopen(fullRawFilename,'r');
               if(fid>0)
                   try
                       delimiter = ',';
                       % header = 'Date	 Time	 Axis1	Axis2	Axis3
                       headerLines = 11; %number of lines to skip
                       %                        scanFormat = '%s %f32 %f32 %f32'; %load as a 'single' (not double) floating-point number
%                        scanFormat = '%f/%f/%f %f:%f:%f %f32 %f32 %f32';
%                        tmpDataCell = textscan(fid,scanFormat,'delimiter',delimiter,'headerlines',headerLines);

                       
                       scanFormat = '%2d/%2d/%4d %2d:%2d:%f,%f32,%f32,%f32';
                       frewind(fid);
                       for f=1:headerLines
                           fgetl(fid);
                       end
                       
                       %This takes 46 seconds; //or 24 seconds or 4.547292
                       %or 8.8 ...
                       %seconds. or 219.960772 seconds (what is going on
                       %here?)
                       tic                       
                       A  = fread(fid,'*char');
                       toc
                       tic
                       tmpDataCell = textscan(A,scanFormat);
                       toc
%                        toc
%                        pattern = '(?<datetimestamp>[^,]+),(?<axis1>[^,]+),(?<axis2>[^,]+),(?<axis3>[^\s]+)\s*';
%                        tic
%                        result = regexp(A(1:2e+8)',pattern,'names')  % seconds
% %                        result = regexp(A(1:1e+8)',pattern,'names')  %23.7 seconds
%                        toc
                       
                       %                        scanFormat = '%u8/%u8/%u16 %2d:%2d:%f,%f32,%f32,%f32';
                       %tmpDataCell = textscan(A(1:1e+9),scanFormat)
%                        tmpDataCell = textscan(A(1:1e+8),scanFormat)
%                        tmpDataCell = textscan(A(1e+8+2:2e+8),scanFormat)
%                        tmpDataCell = textscan(A(2e+8-15:3e+8),scanFormat)
%                        tmpDataCell = textscan(A(3e+8:4e+8),scanFormat) %12.7 seconds
%                        tmpDataCell = textscan(A(4e+8-3:5e+8),scanFormat) %8.8 seconds
%                        tmpDataCell = textscan(A(5e+8+10:6e+8+100)',scanFormat) %7.9 seconds
%                        tmpDataCell = textscan(A(6e+8+15:7e+8+100)',scanFormat) %7.86 seconds
%                        tmpDataCell = textscan(A(7e+8+7:8e+8+100)',scanFormat) %7.8 seconds
%                        tmpDataCell = textscan(A(8e+8-13:9e+8+100)',scanFormat) %7.9 seconds
%                        tmpDataCell = textscan(A(9e+8-1:10e+8+100)',scanFormat) %7.87 seconds
% 
% tic
% tmpDataCell = textscan(A(10e+8-17:11e+8+100)',scanFormat) %7.94 seconds
% toc,tic
% tmpDataCell = textscan(A(11e+8+4:12e+8+100)',scanFormat) %7.73 seconds
% toc,tic
% tmpDataCell = textscan(A(12e+8-2:13e+8+100)',scanFormat) %8.08 seconds
% toc,tic
% tmpDataCell = textscan(A(13e+8-3:14e+8+100)',scanFormat) %9.45 seconds
% toc,tic
% tmpDataCell = textscan(A(14e+8+4:14.106e+8)',scanFormat) %1.03 seconds
% toc                       
%                        toc

                       
                       %Date time handling
                       dateVecFound = double([tmpDataCell{3},tmpDataCell{1},tmpDataCell{2},tmpDataCell{4},tmpDataCell{5},tmpDataCell{6}]);
                       
                       %Date time handling
                       %dateVecFound = datevec(tmpDataCell{1},'mm/dd/yyyy HH:MM:SS.FFF');
                       
                       
                       obj.sampleRate = 40;                       
                       samplesFound = size(dateVecFound,1);  
                       
                       %start, stop and delta date nums
                       startDateNum = datenum(strcat(obj.startDate,{' '},obj.startTime),'mm/dd/yyyy HH:MM:SS');
                       stopDateNum = datenum(dateVecFound(end,:));                       
                       windowDateNumDelta = datenum([0,0,0,0,0,1/obj.sampleRate]);
                       missingValue = nan;

                       % NOTE:  Chopping off the first six columns: date time values;
                       tmpDataCell(1:6) = [];                       
                       [dataCell, ~, obj.dateTimeNum] = obj.mergedCell(startDateNum,stopDateNum,windowDateNumDelta,dateVecFound,tmpDataCell,missingValue);                       
                       tmpDataCell = []; %free up this memory;
                       
                       obj.durSamples = numel(obj.dateTimeNum);
                       obj.durationSec = floor(obj.durationSamples()/obj.sampleRate);
                       
                       numMissing = obj.durationSamples() - samplesFound;
                                              
                       if(obj.durationSamples()==samplesFound)
                           fprintf('%d rows loaded from %s\n',samplesFound,fullRawFilename); 
                       else                           
                           
                           if(numMissing>0)
                               fprintf('%d rows loaded from %s.  However %u rows were expected.  %u missing samples are being filled in as %s.\n',samplesFound,fullCountFilename,numMissing,num2str(missingValue));
                           else
                               fprintf('This case is not handled yet.\n');
                               fprintf('%d rows loaded from %s.  However %u rows were expected.  %u missing samples are being filled in as %s.\n',samplesFound,fullCountFilename,numMissing,num2str(missingValue));
                           end
                       end
                       
                       obj.accelCount.x = dataCell{1};
                       obj.accelCount.y = dataCell{2};
                       obj.accelCount.z = dataCell{3};
                       
                       N = obj.windowPeriodSec*obj.sampleRate;
                       
                       obj.steps = reshape(repmat(obj.steps(:),N,1),[],1);
                       obj.lux = reshape(repmat(obj.lux(:)',N,1),[],1);
                       
                       obj.inclinometer.standing = reshape(repmat(obj.inclinometer.standing(:)',N,1),[],1);
                       obj.inclinometer.sitting = reshape(repmat(obj.inclinometer.sitting(:)',N,1),[],1);
                       obj.inclinometer.lying = reshape(repmat(obj.inclinometer.lying(:)',N,1),[],1);
                       obj.inclinometer.off = reshape(repmat(obj.inclinometer.off(:)',N,1),[],1);
                       
                       % obj.vecMag = reshape(repmat(obj.vecMag(:)',N,1),[],1);
                       % derive vecMag from x, y, z axes directly...
                       obj.vecMag = sqrt(obj.accelRaw.x.^2+obj.accelRaw.y.^2+obj.accelRaw.z.^2);
                       
                       
                       
                       %Use a different scale for raw data so it can be
                       %seen more easily...
                       obj.scale.timeSeries.accelRaw.x = 10;
                       obj.scale.timeSeries.accelRaw.y = 10;
                       obj.scale.timeSeries.accelRaw.z = 10;
                       obj.scale.timeSeries.vecMag = 10;
                       obj.scale.timeSeries.steps = 5;
                       obj.scale.timeSeries.lux = 5;
                       obj.scale.timeSeries.inclinometer.standing = 5;
                       obj.scale.timeSeries.inclinometer.sitting = 5;
                       obj.scale.timeSeries.inclinometer.lying = 5;
                       obj.scale.timeSeries.inclinometer.off = 5;

                       fclose(fid);
                   catch me
                       showME(me);
                       fclose(fid);
                   end
               else
                   fprintf('Warning - could not open %s for reading!\n',fullRawFilename);
               end
           else
               fprintf('Warning - %s does not exist!\n',fullRawFilename);
           end
       end
       
       % ======================================================================
       %> @brief Calculates, and returns, the window for the given sample index of a signal.
       %> @param obj Instance of PAData.
       %> @param sample Sample point to discover the containing window of.
       %> @param windowDurSec Window duration in seconds (scalar) (optional)
       %> @param samplerate Sample rate of the data (optional)
       %> @retval window The window.
       % ======================================================================
       function window = sample2window(obj,sample,windowDurSec,samplerate)           
           if(nargin<4)
               samplerate = obj.getSampleRate();
           end
           if(nargin<3)
               windowDurSec = obj.windowDurSec;
           end;
           window = ceil(sample/(windowDurSec*samplerate));
       end

       % ======================================================================
       %> @brief Returns the display window for the given datenum
       %> @param obj Instance of PAData.
       %> @param datenumSample A date number (datenum) that should be in the range of
       %> instance variable dateTimeNum
       %> @param structType String (optional) identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins       
       %> @retval window The window.
       % ======================================================================
       function window = datenum2window(obj,datenumSample,structType)           
           if(nargin<3 || isempty(structType))
               structType = 'time series';
           end           
           
           startstopDatenum = obj.getStartStopDatenum();
           elapsed_time = datenumSample - startstopDatenum(1);
           [y,m,d,mi,s] = datevec(elapsed_time);
           elapsedSec = [d, mi, s] * [24*60; 60; 1/60]*60;
           windowSamplerate = obj.getWindowSamplerate(structType);
           
           window = ceil(elapsedSec/(obj.windowDurSec*windowSamplerate));
       end
       
       
       % ======================================================================
       %> @brief Returns the starting datenum for the window given.
       %> @param obj Instance of PAData.
       %> @param windowSample Index of the window to check.       %   
       %> @retval dateNum the datenum value at the start of windowSample.
       %> @note The starting point is adjusted based on obj startDatenum
       %> value and its windowDurSec instance variable.
       % ======================================================================
       function dateNum = window2datenum(obj,windowSample)           
           elapsed_time_sec = (windowSample-1) * obj.windowDurSec;
           startStopDatenum = obj.getStartStopDatenum();
           dateNum  = startStopDatenum(1)+datenum([0,0,0,0,0,elapsed_time_sec]);
       end
       
       function obj = prefilter(obj,method)
           currentNumBins = floor((obj.durationSec/60)/obj.aggregateDurMin);
           if(currentNumBins~=obj.numBins)
               obj.numBins = currentNumBins;
               obj.bins = nan(obj.numBins,1);
           end
           
           
           switch(lower(method))
               case 'none'
               case 'rms'
               case 'median'
               case 'mean'
               case 'hash'
               otherwise
                   fprintf(1,'Unknown method (%s)\n',method);
           end
       end

       
       
       function obj = extractFeature(obj,signalTagLine,method)
           if(nargin<3 || isempty(method))
               method = 'all';
               if(nargin<2 || isempty(signalTagLine))
                   signalTagLine = 'vecMag';
               end
           end
           
           currentNumFrames = obj.getFrameCount();
           if(currentNumFrames~=obj.numFrames)
               [frameDurMinutes, frameDurHours ] = obj.getFrameDuration();
               frameDurSeconds = frameDurMinutes*60+frameDurHours*60*60;
               obj.numFrames = currentNumFrames;
               frameableSamples = obj.numFrames*frameDurSeconds*obj.getSampleRate();
               data = obj.getStruct('all');
               data = eval(['data.',signalTagLine]);
               obj.frames =  reshape(data(1:frameableSamples),[],obj.numFrames);  %each frame consists of a column of data.  Consecutive columns represent consecutive frames.
               obj.features = [];
           end
           
           
           %frames are stored in consecutive columns.
           data = obj.frames;
           switch(lower(method))
               case 'none'
               case 'all'
                   obj.features.rms = sqrt(mean(data.^2))';
                   obj.features.median = median(data)';
                   obj.features.mean = mean(data)';
                   obj.features.sum = sum(data)';
                   obj.features.var = var(data)';
                   obj.features.std = std(data)';
                   obj.features.mode = mode(data)';
%                    obj.features.count = obj.getCount(data)';
               case 'rms'
                   obj.features.rms = sqrt(mean(data.^2))';
               case 'mean'
                   obj.features.mean = mean(data)';
               case 'sum'
                   obj.features.sum = sum(data)';
               case 'mode'
                   obj.features.mode = mode(data)';
               otherwise
                   fprintf(1,'Unknown method (%s)\n',method);
           end
       end
       
       % ======================================================================
       %> @brief overloaded subsindex method returns structure of time series data
       %> at indices provided. 
       %> @param obj Instance of PAData
       %> @param indices Vector (logical or ordinal) of indices to select time
       %> series data by.
       %> @param structType String (optional) identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins       
       %> @retval dat A struct of PAData's time series instance data for the indices provided.  The fields
       %> include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - vecMag
       %> - steps
       %> - lux
       %> - inclinometer
       % ======================================================================
       function dat = subsindex(obj,indices,structType)
           
           if(nargin<3 ||isempty(structType))
               structType = 'time series';
           end
           switch(lower(structType))
               case 'time series'
                   dat.accelRaw.x = double(obj.accelRaw.x(indices));
                   dat.accelRaw.y = double(obj.accelRaw.y(indices));
                   dat.accelRaw.z = double(obj.accelRaw.z(indices));
                   dat.vecMag = double(obj.vecMag(indices));
                   dat.steps = double(obj.steps(indices));
                   dat.lux = double(obj.lux(indices));
                   dat.inclinometer.standing = double(obj.inclinometer.standing(indices));
                   dat.inclinometer.sitting = double(obj.inclinometer.sitting(indices));
                   dat.inclinometer.lying = double(obj.inclinometer.lying(indices));
                   dat.inclinometer.off = double(double(obj.inclinometer.off(indices)));
               case 'features'
                   dat = PAData.subsStruct(obj.features,indices);
               case 'aggregate bins'
                   dat.median = double(obj.feature.median(indices));
               otherwise
                   fprintf('Warning!  This case is not handled (%s).\n',structType);
           end
       end
       
       function [sref,varargout] = subsref(obj,s)
           
           if(strcmp(s(1).type,'()') && length(s)<2)
               % Note that obj.Data is passed to subsref
               sref = obj.subsindex(cell2mat(s.subs));               
           else
               if(strcmpi(s(1).subs,'getFrameDuration'))
                   [sref, varargout{1}] = builtin('subsref',obj,s);
               else
                   sref = builtin('subsref',obj,s);
               end
           end
       end
       
       % ======================================================================
       %> @brief Returns a structure of PAData's time series fields and
       %> values, depending on the user's input selection.
       %> @param obj Instance of PAData.
       %> @param choice (optional) String indicating the type of structure to be returned; optional. Can be
       %> - @b dummy Empty data.
       %> - @b dummydisplay Holds generic line properties for the time series structure.
       %> - @b current Time series data with offset and scaling values applied.
       %> - @b currentdisplay Time series data with offset and scaling values applied
       %> and stored as 'ydata' child fields.
       %> - @b displayoffset [x,y,z] offsets of the current time series
       %> data being displayed.  Values are stored in .position child field
       %> - @b all All (default) original time series data.
       %> @param structType String (optional) identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins       
       %> @retval dat A struct of PAData's time series, aggregate bins, or features instance data.  The fields
       %> for time series data include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - inclinometer
       %> - lux
       %> - vecMag
       % =================================================================      
       function dat = getStruct(obj,choice,structType)
           if(nargin<3)
               structType = 'time series';
               if(nargin<2)
                   choice = 'all';
               end
           end
           switch(choice)
               case 'dummy'
                   dat = obj.getDummyStruct(structType);
               case 'dummydisplay'
                   dat = obj.getDummyDisplayStruct(structType);
               case 'current'
                   dat = obj.getCurrentStruct(structType);
                case 'displayoffset'
                    dat = obj.getCurrentOffsetStruct(structType);
               case 'currentdisplay'
                   dat = obj.getCurrentDisplayStruct(structType);               
               case 'all'                   
                   dat = obj.getAllStruct(structType);
               otherwise
                   dat = obj.getAllStruct(structType);
           end
       end
       
       
       
       % ======================================================================
       %> @brief Returns a structure of PAData's saveable parameters as a struct.
       %> @param obj Instance of PAData.
       %> @retval pStruct A structure of save parameters which include the following
       %> fields
       %> - @c curWindow
       %> - @c pathname
       %> - @c filename
       %> - @c windowDurSec
       %> - @c aggregateDurMin
       %> - @c frameDurMin
       %> - @c frameDurHour
       function pStruct = getSaveParameters(obj)
           fields= {'curWindow';
               'pathname';
               'filename';
               'windowDurSec';
               'aggregateDurMin';       
               'frameDurMin';
               'frameDurHour';
               'scale';
               'label';
               'offset';
               'color';
               'yDelta'
               };
           pStruct = struct();
           for f=1:numel(fields)
               pStruct.(fields{f}) = obj.(fields{f});
           end
       end

   end
   
   methods (Access = private)
   
       % ======================================================================
       %> @brief Returns a structure of an insance PAData's time series data.
       %> @param obj Instance of PAData.
       %> @param structType String (optional) identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins       
       %> @retval dat A struct of PAData's time series instance data.  The fields
       %> include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - vecMag
       %> - steps
       %> - lux
       %> - inclinometer
       %> - windowDurSec
       % =================================================================      
       function dat = getAllStruct(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end
           
           switch lower(structType)
               case 'time series'
                   dat.accelRaw = obj.accelRaw;
                   dat.vecMag = obj.vecMag;
                   dat.steps = obj.steps;
                   dat.lux = obj.lux;
                   dat.inclinometer = obj.inclinometer;
               case 'aggregate bins'
                   dat = obj.bins;
               case 'features'
                   dat = obj.features;
               otherwise
                   fprintf('This structure type is not handled (%s).\n',structType);
           end
       end
       
       
       
       % ======================================================================
       %> @brief Returns a structure of an insance PAData's time series
       %> data at the current window.
       %> @param obj Instance of PAData.
       %> @param structType String (optional) identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins       
       %> @retval curStruct A struct of PAData's time series or features instance data.  The fields
       %> for time series include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - vecMag
       %> - steps
       %> - lux
       %> - inclinometer (struct with more fields)
       %> While the fields for @c features include
       %> @li @c median
       %> @li @c mean
       %> @li @c rms
       % =================================================================
       function curStruct = getCurrentStruct(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end
           
           windowRange = obj.getCurWindowRange(structType);
           curStruct = obj.subsindex(windowRange(1):windowRange(end),structType);
       end
       
       % ======================================================================
       %> @brief Returns the time series data as a struct for the current window range,
       %> adjusted for visual offset and scale.
       %> @param obj Instance of PAData.
       %> @param structType (Optional) String identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins
       %> @retval dat A struct of PAData's time series or features instance data.  The fields
       %> for time series data include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - vecMag
       %> - steps
       %> - lux
       %> - inclinometer (struct with more fields)
       %> The fields for feature data include:
       %> @li @c median
       %> @li @c mean
       %> @li @c rms
       % =================================================================
       function dat = getCurrentDisplayStruct(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end
           
           switch lower(structType)
               case 'time series'
                   structFieldName = 'timeSeries';
               case 'features'
                   structFieldName = 'features';
               otherwise
                   fprintf('This structure type is not handled (%s).\n',structType);
           end
           dat = PAData.structEval('times',obj.getStruct('current',structType),obj.scale.(structFieldName));
           
           windowRange = obj.getCurWindowRange(structType);
           
           %we have run into the problem of trying to zoom in on more than
           %we have resolution to display.  
           if(diff(windowRange)==0)
               windowRange(2)=windowRange(2)+1;
               dat = PAData.structEval('repmat',dat,dat,size(windowRange));
           end
           
           lineProp.xdata = windowRange(1):windowRange(end);
           % put the output into a 'ydata' field for graphical display
           % property of a line.
           dat = PAData.structEval('plus',dat,obj.offset.(structFieldName),'ydata');
           dat = PAData.appendStruct(dat,lineProp);
       end       
       
       % ======================================================================
       %> @brief Returns [x,y,z] offsets of the current time series
       %> data being displayed.  Values are stored in .position child field
       %> @param obj Instance of PAData.
       %> @param structType (Optional) String identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default)
       %> @li @c features
       %> @li @c aggregate bins
       %> @retval dat A struct of [x,y,z] starting location of each
       %> data field.  The fields (for 'time series') include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - vecMag
       %> - steps
       %> - lux
       %> - inclinometer (struct with more fields)
       % =================================================================
       function dat = getCurrentOffsetStruct(obj,structType)
           if(nargin<2 || isempty(structType))
               structType = 'time series';
           end
           switch(lower(structType))
               case 'time series'
                   dat = obj.offset.timeSeries;
               case 'features'
                   dat = obj.offset.features;
               otherwise
                   fprintf('Unknown offset type (%s).\n',structType)
           end
           
           windowRange = obj.getCurWindowRange(structType);
           %            lineProp.xdata = windowRange(1);
           lineProp.xdata = windowRange;
           % put the output into a 'position'
           
           dat = PAData.structEval('repmat',dat,dat,size(windowRange));
           
           dat = PAData.structEval('passthrough',dat,dat,'ydata');
           
           dat = PAData.appendStruct(dat,lineProp);
       end
       
   end
   
   methods(Static)

       %> @brief returns a cell of tag lines and the associated label
       %> describing the tag line.
       %> @retval tagLines Cell of tag lines
       %> @retval labels Cell of string descriptions that correspond to tag
       %> lines in the tagLines cell.
       %> @note Tag lines are useful for dynamic struct indexing into
       %> structs returned by getStruct.
       function [tagLines,labels] = getDefaultTagLineLabels()
           tagLines = {'accelRaw.x';
                   'accelRaw.y';
                   'accelRaw.z';
                   'vecMag';
                   'steps';
                   'lux';
                   'inclinometer.standing';
                   'inclinometer.sitting';
                   'inclinometer.lying';
                   'inclinometer.off';
                   };
           labels = {'X';
                   'Y';
                   'Z';
                   'Magnitude';
                   'Steps';
                   'Luminance'
                   'inclinometer.standing';
                   'inclinometer.sitting';
                   'inclinometer.lying';
                   'inclinometer.off';
                   };    
       end
       
       % ======================================================================
       %> @brief Returns a structure of PAData's default parameters as a struct.
       %> @param obj Instance of PAData.
       %> @retval pStruct A structure of default parameters which include the following
       %> fields
       %> - @c curWindow
       %> - @c pathname
       %> - @c filename
       %> - @c windowDurSec
       %> - @c aggregateDurMin
       %> - @c frameDurMin
       %> - @c frameDurHour
       %> - @c windowDurSec       
       %> @note This is useful with the PASettings companion class.
       function pStruct = getDefaultParameters()           
           pStruct.pathname = '.'; %directory of accelerometer data.
           pStruct.filename = ''; %last accelerometer data opened.
           pStruct.curWindow = 1;
           pStruct.frameDurMin = 15;
           pStruct.frameDurHour = 0;
           pStruct.aggregateDurMin = 3;
           pStruct.windowDurSec = 60*5;
           
           featureStruct = PAData.getFeatureDescriptionStruct();
           fnames = fieldnames(featureStruct);

           windowHeight = 1000; %diff(obj.getMinmax('all'))

           pStruct.yDelta = 0.05*windowHeight; %diff(obj.getMinmax('all'));

           featuresYDelta = windowHeight/(numel(fnames)+1);
           
           colorChoices = {'y','r','k','g','b','k'};
           for f = 1 : numel(fnames)
               curFeature = fnames{f};
               curColor = colorChoices{mod(f,numel(colorChoices))+1};
               curDescription = featureStruct.(curFeature);
               pStruct.offset.features.(curFeature) = featuresYDelta*f;
               
               if(strcmpi(curFeature,'rms'))
                   scaleVal = 2;
               elseif(strcmpi(curFeature,'sum'))
                   scaleVal = 0.001;
               elseif(strcmpi(curFeature,'std'))
                   scaleVal = 1;
               elseif(strcmpi(curFeature,'var'))
                   scaleVal = 0.1;
               else
                   scaleVal = 1;
               end
               
               pStruct.scale.features.(curFeature) = scaleVal;
               pStruct.label.features.(curFeature).string = curDescription;
               pStruct.label.features.(curFeature).position = [0 0 0];
               pStruct.color.features.(curFeature).color = curColor;
           end
           
           % yDelta = 1/20 of the vertical screen space (i.e. 20 can fit)
           pStruct.offset.timeSeries.accelRaw.x = pStruct.yDelta*1;
           pStruct.offset.timeSeries.accelRaw.y = pStruct.yDelta*4;
           pStruct.offset.timeSeries.accelRaw.z = pStruct.yDelta*7;
           pStruct.offset.timeSeries.vecMag = pStruct.yDelta*10;
           pStruct.offset.timeSeries.steps = pStruct.yDelta*14;
           pStruct.offset.timeSeries.lux = pStruct.yDelta*15;
           pStruct.offset.timeSeries.inclinometer.standing = pStruct.yDelta*19.0;
           pStruct.offset.timeSeries.inclinometer.sitting = pStruct.yDelta*18.25;
           pStruct.offset.timeSeries.inclinometer.lying = pStruct.yDelta*17.5;
           pStruct.offset.timeSeries.inclinometer.off = pStruct.yDelta*16.75;
           

           
           pStruct.color.timeSeries.accelRaw.x.color = 'r';
           pStruct.color.timeSeries.accelRaw.y.color = 'b';
           pStruct.color.timeSeries.accelRaw.z.color = 'g';
           pStruct.color.timeSeries.vecMag.color = 'm';
           pStruct.color.timeSeries.steps.color = 'k'; %[1 0.5 0.5];
           pStruct.color.timeSeries.lux.color = 'y';
           pStruct.color.timeSeries.inclinometer.standing.color = 'k';
           pStruct.color.timeSeries.inclinometer.lying.color = 'k';
           pStruct.color.timeSeries.inclinometer.sitting.color = 'k';
           pStruct.color.timeSeries.inclinometer.off.color = 'k';
           
           % scale to show at - place before the loadFile command,
           % b/c it will differe based on the type of file loading done.
           pStruct.scale.timeSeries.accelRaw.x = 1;
           pStruct.scale.timeSeries.accelRaw.y = 1;
           pStruct.scale.timeSeries.accelRaw.z = 1;
           pStruct.scale.timeSeries.vecMag = 1;
           pStruct.scale.timeSeries.steps = 5;
           pStruct.scale.timeSeries.lux = 1;
           pStruct.scale.timeSeries.inclinometer.standing = 5;
           pStruct.scale.timeSeries.inclinometer.sitting = 5;
           pStruct.scale.timeSeries.inclinometer.lying = 5;
           pStruct.scale.timeSeries.inclinometer.off = 5;         
           
       end
       
       % ======================================================================
       %> @brief Returns structure whose values are taken from the struct
       %> and indices provided.
       %> @param structIn Struct of indicable data.
       %> @param indices Vector (logical or ordinal) of indices to select time
       %> series data by.
       %> @retval structOut Struct with matching fields as input struct, with values taken at indices.
       function structOut = subsStruct(structIn,indices)
           if(isstruct(structIn))
               fnames = fieldnames(structIn);
               structOut = struct();
               for f=1:numel(fnames)
                   structOut.(fnames{f}) = PAData.subsStruct(structIn.(fnames{f}),indices);
               end
           elseif(isempty(structIn))
               structOut = [];
           else
               structOut = structIn(indices);
           end
       end
       
       
       % ======================================================================
       %> @brief Helper function for loading raw and count file
       %> formats to ensure proper ordering and I/O error handling.
       %> @param startDateNum The start date number that the ordered data cell should
       %> begin at.  (should be generated using datenum())
       %> @param stopDateNum The date number (generated using datenum()) that the ordered data cell 
       %> ends at.
       %> @param dateNumDelta The difference between two successive date number samples.
       %> @param sampledDateVec Vector of date number values taken between startDateNum
       %> and stopDateNum (inclusive) and are in the order and size as the
       %> individual cell components of tmpDataCell
       %> @param tmpDataCell A cell of vectors whose individual values correspond to
       %> the order of sampledDateVec
       %> @param missingValue (Optional) Value to be used in the ordered output data
       %> cell where the tmpDataCell does not have corresponding values.
       %> The default is 'nan'.
       %> @retval orderedDataCell A cell of vectors that are taken from tmpDataCell but
       %> initially filled with the missing value parameter and ordered
       %> according to synthDateNum.
       %> @retval synthDateVec Matrix of date vectors ([Y, Mon,Day, Hr, Mn, Sec]) generated by
       %> startDateNum:dateNumDelta:stopDateNum which correponds to the
       %> row order of orderedDataCell cell values/vectors
       %> @retval synthDateNum Vector of date numbers corresponding to the date vector
       %> matrix return argument.
       %> @note This is a helper function for loading raw and count file
       %> formats to ensure proper ordering and I/O error handling.
       function [orderedDataCell, synthDateVec, synthDateNum] = mergedCell(startDateNum, stopDateNum, dateNumDelta, sampledDateVec,tmpDataCell,missingValue)
           if(nargin<6 || isempty(missingValue))
               missingValue = nan;
           end
           
           %sampledDateNum = datenum(sampledDateVec);           
           synthDateVec = datevec(startDateNum:dateNumDelta:stopDateNum);
           synthDateVec(:,6) = round(synthDateVec(:,6)*1000)/1000;
           numSamples = size(synthDateVec,1);
           
           %make a cell with the same number of column as
           %loaded in the file less 2 (remove date and time
           %b/c already have these, with each column entry
           %having an array with as many missing values as
           %originally found.
           orderedDataCell =  repmat({repmat(missingValue,numSamples,1)},1,size(tmpDataCell,2));
           
           %This takes 2.0 seconds!
           synthDateNum = datenum(synthDateVec);
           sampledDateNum = datenum(sampledDateVec);
           [~,IA,~] = intersect(synthDateNum,sampledDateNum);
           
           %This takes 153.7 seconds! - 'rows' option is not as helpful
           %here.
           %            [~,IA,~] = intersect(synthDateVec,sampledDateVec,'rows');
           for c=1:numel(orderedDataCell)
               orderedDataCell{c}(IA) = tmpDataCell{c};
           end
       end
       
       % ======================================================================
       %> @brief Evaluates the two structures, field for field, using the function name
       %> provided.
       %> @param operand A string name of the operation (via 'eval') to conduct at
       %> the lowest level.  Additional operands include:
       %> - passthrough Requires Optional field name to be set.
       %> - calculateposition (requires rtStruct to have .xdata and .ydata
       %> fields.
       %> @param ltStruct A structure whose fields are either structures or vectors.
       %> @param rtStruct A structure whose fields are either structures or vectors.
       %> @param optionalDestField Optional field name to subset the resulting output
       %> structure to (see last example).  This can be useful if the
       %> output structure will be passed as input that expects a specific
       %> sub field name for the values (e.g. line properties).  See last
       %> example below.
       %> @retval resultStruct A structure with same fields as ltStruct and rtStruct
       %> whose values are the result of applying operand to corresponding
       %> fields.  
       %> @note In the special case that operand is set to 'passthrough'
       %> only ltStruct is used (enter ltStruct as the rtStruct value)
       %> and the optionalDestField must be set (i.e. cannot be empty).  
       %> The purpose of the 'passthrough' operation is to insert a field named
       %> optionalDestField between any field/non-struct value pairs.
       %> 
       %> @note For example:
       %> @note ltStruct =
       %> @note         x: 2
       %> @note     accel: [1x1 struct]
       %> @note       [x]: 0.5000
       %> @note       [y]: 1
       %> @note
       %> @note rtStruct =
       %> @note         x: [10 10 2]
       %> @note     accel: [1x1 struct]
       %> @note             [x]: [10 10 2]
       %> @note             [y]: [1 2 3]
       %> @note
       %> @note
       %> @note
       %> @note PAData.structEval('plus',rtStruct,ltStruct)
       %> @note ans =
       %> @note         x: [12 12 4]
       %> @note     accel: [1x1 struct]
       %> @note             [x]: [10.5000 10.5000 2.5000]
       %> @note             [y]: [2 3 4]
       %> @note
       %> @note PAData.structEval('plus',rtStruct,ltStruct,'ydata')
       %> @note ans =
       %> @note         x.ydata: [12 12 4]
       %> @note           accel: [1x1 struct]
       %> @note                   [x].ydata: [10.5000 10.5000 2.5000]
       %> @note                   [y].ydata: [2 3 4]
       %> @note
       %> @note PAData.structEval('passthrough',ltStruct,ltStruct,'string')
       %> @note ans =
       %> @note         x.string: 2
       %> @note            accel: [1x1 struct]
       %> @note                    [x].string: 0.5000
       %> @note                    [y].string: 1
       %> @note
       %> @note       
       % ======================================================================
       function resultStruct = structEval(operand,ltStruct,rtStruct,optionalDestField)
           if(nargin < 4)
              optionalDestField = []; 
           end
           
           if(isstruct(ltStruct))               
               fnames = fieldnames(ltStruct);
               resultStruct = struct();
               for f=1:numel(fnames)
                   curField = fnames{f};
                   resultStruct.(curField) = PAData.structEval(operand,ltStruct.(curField),rtStruct.(curField),optionalDestField);
               end
           else
               if(strcmpi(operand,'calculateposition'))
                   resultStruct.position = [rtStruct.xdata(1), rtStruct.ydata(1), 0];               
                   
               else
                   if(~isempty(optionalDestField))
                       if(strcmpi(operand,'passthrough'))
                           resultStruct.(optionalDestField) = ltStruct;
                       elseif(strcmpi(operand,'repmat'))
                           resultStruct = repmat(ltStruct,optionalDestField);
                       else
                           resultStruct.(optionalDestField) = feval(operand,ltStruct,rtStruct);
                       end
                   else
                       resultStruct = feval(operand,ltStruct,rtStruct);
                   end
               end
           end
       end
       
       % ======================================================================
       %> @brief Evaluates the two structures, field for field, using the function name
       %> provided.
       %> @param operand A string name of the operation (via 'eval') to conduct at
       %> the lowest level. 
       %> @param ltStruct A structure whose fields are either structures or vectors.
       %> @param A Matrix value of the same dimension as the first structure's (ltStruct)
       %> non-struct field values.
       %> @param optionalDestField Optional field name to subset the resulting output
       %> structure to (see last example).  This can be useful if the
       %> output structure will be passed as input that expects a specific
       %> sub field name for the values (e.g. line properties).  See last
       %> example below.
       %> @retval resultStruct A structure with same fields as ltStruct and optionally 
       %> the optionalDestField whose values are the result of applying operand to corresponding
       %> fields and the input matrix.
       %> 
       %> @note For example:
       %> @note
       %> @note ltStruct =
       %> @note         x.position: [10 10 2]
       %> @note     accel: [1x1 struct]
       %> @note             [x.position]: [10 10 2]
       %> @note             [y.position]: [1 2 3]
       %> @note
       %> @note A =
       %> @note     [1 1 0]
       %> @note
       %> @note PAData.structEval('plus',ltStruct,A)
       %> @note ans =
       %> @note         x.position: [11 11 2]
       %> @note     accel: [1x1 struct]
       %> @note             [x.position]: [11 11 2]
       %> @note             [y.position]: [2 3 3]
       %> @note       
       % ======================================================================
       function resultStruct = structScalarEval(operand,ltStruct,A,optionalDestField)
           if(nargin < 4)
              optionalDestField = []; 
           end
           
           if(isstruct(ltStruct))               
               fnames = fieldnames(ltStruct);
               resultStruct = struct();
               for f=1:numel(fnames)
                   curField = fnames{f};
                   resultStruct.(curField) = PAData.structScalarEval(operand,ltStruct.(curField),A,optionalDestField);
               end
           else               
               if(~isempty(optionalDestField))
                   if(strcmpi(operand,'passthrough'))
                       resultStruct.(optionalDestField) = ltStruct;
                   else
                       resultStruct.(optionalDestField) = feval(operand,ltStruct,A);
                   end
               else
                   resultStruct = feval(operand,ltStruct,A);
               end
           end
       end
       
       % ======================================================================
       %> @brief Appends the fields of one to another.
       %> @param ltStruct A structure whose fields are to be appended by the other.
       %> @param rtStruct A structure whose fields are will be appened to the other.
       %> @retval ltStruct The resultof append rtStruct to ltStruct.
       %> @note For example:
       %> @note ltStruct =
       %> @note     ydata: [1 1]
       %> @note     accel: [1x1 struct]
       %> @note            [x]: 0.5000
       %> @note            [y]: 1
       %> @note
       %> @note rtStruct =
       %> @note     xdata: [1 100]
       %> @note     
       %> @note PAData.structEval(rtStruct,ltStruct)
       %> @note ans =
       %> @note     ydata: [1 1]
       %> @note     xdata: [1 100]
       %> @note     accel: [1x1 struct]
       %> @note            [xdata]: [1 100]
       %> @note            [x]: [10.5000 10.5000 2.5000]
       %> @note            [y]: [2 3 4]
       %> @note
       % ======================================================================
       function ltStruct = appendStruct(ltStruct,rtStruct)
           if(isstruct(ltStruct))               
               fnames = fieldnames(ltStruct);
               for f=1:numel(fnames)
                   curField = fnames{f};
                   if(isstruct(ltStruct.(curField)))
                       ltStruct.(curField) = PAData.appendStruct(ltStruct.(curField),rtStruct);
                   else
                       appendNames=fieldnames(rtStruct);
                       for a=1:numel(appendNames)
                           ltStruct.(appendNames{a}) = rtStruct.(appendNames{a});
                       end
                   end
               end
           end           
       end
       
       % ======================================================================
       %> @brief Merge the fields of one struct with another.  Copies over
       %> matching field values.  Similar to appendStruct, but now the second argument 
       %> is itself a struct with similar organization as the first
       %> argument.
       %> @param ltStruct A structure whose fields are to be appended by the other.
       %> @param rtStruct A structure whose fields are will be appened to the other.
       %> @retval ltStruct The result of merging rtStruct with ltStruct.
       %> @note For example:
       %> @note ltStruct =
       %> @note     accel: [1x1 struct]
       %> @note            [x]: 0.5000
       %> @note            [y]: 1
       %> @note     lux: [1x1 struct]
       %> @note            [z]: 0.5000       
       %> @note
       %> @note rtStruct =
       %> @note     accel: [1x1 struct]
       %> @note            [pos]: [0.5000, 1, 0]
       %> @note            
       %> @note     
       %> @note PAData.structEval(rtStruct,ltStruct)
       %> @note ans =   
       %> @note     accel: [1x1 struct]
       %> @note              [x]: 0.5000
       %> @note              [y]: 1
       %> @note            [pos]: [0.5000, 1, 0]
       %> @note     lux: [1x1 struct]
       %> @note            [z]: 0.5000       
       %> @note            [pos]: [0.5000, 1, 0]
       %> @note
       % ======================================================================
       function ltStruct = mergeStruct(ltStruct,rtStruct)

           if(isstruct(rtStruct))               
               fnames = fieldnames(rtStruct);
               for f=1:numel(fnames)
                   curField = fnames{f};
                   if(isstruct(rtStruct.(curField)))
                       if(isfield(ltStruct,curField))
                           ltStruct.(curField) = PAData.mergeStruct(ltStruct.(curField),rtStruct.(curField));
                       else
                           ltStruct.(curField) = rtStruct.(curField);
                       end
                   else
                       ltStruct.(curField) = rtStruct.(curField);
                   end
               end
           end           
       end
       
       
       % ======================================================================
       %> @brief Inserts the second argument into any empty fields of the first
       %> struct argument.
       %> @param ltStruct A structure whose empty fields will be set to the second argument.
       %> @param rtStruct A structure 
       %> @retval ltStruct The structure that results from inserting rtStruct into ltStruct.
       %> @note For example:
       %> @note ltStruct =
       %> @note     accel: [1x1 struct]
       %> @note            [x]: []
       %> @note            [y]: []
       %> @note     lux: []     
       %> @note
       %> @note rtStruct =
       %> @note     color: 'k'
       %> @note     data: [1x1 struct]
       %> @note            [pos]: [0.5000, 1, 0]
       %> @note            
       %> @note     
       %> @note PAData.structEval(rtStruct,ltStruct)
       %> @note ans =   
       %> @note     accel: [1x1 struct]
       %> @note              [x]: [1x1 struct]
       %> @note                   color: 'k'
       %> @note                   data: [1x1 struct]
       %> @note                         [pos]: [0.5000, 1, 0]
       %> @note              [y]: [1x1 struct]
       %> @note                   color: 'k'
       %> @note                   data: [1x1 struct]
       %> @note                         [pos]: [0.5000, 1, 0]
       %> @note     lux: [1x1 struct]
       %> @note          color: 'k'
       %> @note          data: [1x1 struct]
       %> @note                [pos]: [0.5000, 1, 0]
       %> @note
       % ======================================================================
       function ltStruct = overwriteEmptyStruct(ltStruct,rtStruct)
           if(isstruct(ltStruct))               
               fnames = fieldnames(ltStruct);
               for f=1:numel(fnames)
                   curField = fnames{f};
                   ltStruct.(curField) = PAData.overwriteEmptyStruct(ltStruct.(curField),rtStruct);
               end
           elseif(isempty(ltStruct))
               ltStruct = rtStruct;
           end           
       end
       
       
       % ======================================================================
       %> @brief Evaluates the range (min, max) of components found in the
       %> input struct argument and returns the range as struct values with
       %> matching fieldnames/organization as the input struct's highest level.
       %> @param dataStruct A structure whose fields are either structures or vectors.
       %> @retval structMinMax a struct whose fields correspond to those of
       %the input struct and whose values are [min, max] vectors that
       %correspond to the minimum and maximum values found in the input
       %structure for that field.
       %> @note Consider the example
       %> @note dataStruct.accel.x = [-1 20 5 13];
       %> @note dataStruct.accel.y = [1 70 9 3];
       %> @note dataStruct.accel.z = [-10 2 5 1];
       %> @note dataStruct.lux = [0 0 0 9];
       %> @note structRange.accel is [-10 70]
       %> @note structRange.lux is [0 9]
       function structMinmax = minmax(dataStruct)
           fnames = fieldnames(dataStruct);
           structMinmax = struct();
           for f=1:numel(fnames)
               curField = dataStruct.(fnames{f});
               structMinmax.(fnames{f}) = minmax(PAData.getRecurseMinmax(curField));
           end
       end
       
       % ======================================================================
       %> @brief Recursive helper function for minmax()
       %> input struct argument and returns the range as struct values with
       %> matching fieldnames/organization as the input struct's highest level.
       %> @param dataStruct A structure whose fields are either structures or vectors.
       %> @retval minmaxVec Nx2 vector of minmax values for the given dataStruct.
       % ======================================================================
       function minmaxVec = getRecurseMinmax(dataStruct)
           if(isstruct(dataStruct))
               minmaxVec = [];
               fnames = fieldnames(dataStruct);
               for f=1:numel(fnames)
                   minmaxVec = minmax([PAData.getRecurseMinmax(dataStruct.(fnames{f})),minmaxVec]);
               end
           else
               %minmax is performed on each row; just make one row
               minmaxVec = double(minmax(dataStruct(:)'));
           end
       end
       
       
       % ======================================================================
       %> @brief Returns an empty struct with fields that mirror PAData's
       %> time series instance variables that contain 
       %> @param structType (Optional) String identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins       
       %> @retval dat A struct of PAData's time series, feature, or aggregate bin instance variables.
       %> Time series include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - vecMag
       %> - steps
       %> - lux
       %> - inclinometer
       % =================================================================      
       function dat = getDummyStruct(structType)
           if(nargin<1 || isempty(structType))
               structType = 'time series';
           end
           switch(lower(structType))
               case 'time series'
                   accelR.x =[];
                   accelR.y = [];
                   accelR.z = [];
                   incl.standing = [];
                   incl.sitting = [];
                   incl.lying = [];
                   incl.off = [];
                   dat.accelRaw = accelR;
                   dat.vecMag = [];
                   dat.steps = [];
                   dat.lux = [];
                   dat.inclinometer = incl;
               case 'aggregate bins'
                   binNames =  PAData.getPrefilterMethods();
                   dat = struct;
                   for f=1:numel(binNames)
                       dat.(lower(binNames{f})) = [];
                   end
                   dat = rmfield(dat,{'none','all'});
                   
               case 'features'
                   %                    featureNames =  PAData.getExtractorMethods();
                   featureNames = fieldnames(PAData.getFeatureDescriptionStruct());
                   dat = struct;
                   for f=1:numel(featureNames)
                       dat.(lower(featureNames{f})) = [];
                   end
                   % dat = rmfield(dat,{'none','all'});                   
               otherwise
                   dat = [];
                   fprintf('Unknown offset type (%s).\n',structType)
           end
       end
       
       % ======================================================================
       %> @brief Returns a struct with subfields that hold the line properties
       %> for graphic display of the time series instance variables.
       %> @param structType (Optional) String identifying the type of data to obtain the
       %> offset from.  Can be 
       %> @li @c time series (default) - units are sample points
       %> @li @c features - units are frames
       %> @li @c aggregate bins - units are bins       
       %> @retval dat A struct of PAData's time series instance variables, which 
       %> include:
       %> - accelRaw.x.(xdata, ydata, color)
       %> - accelRaw.y.(xdata, ydata, color)
       %> - accelRaw.z.(xdata, ydata, color)
       %> - inclinometer.(xdata, ydata, color)
       %> - lux.(xdata, ydata, color)
       %> - vecMag.(xdata, ydata, color)
       % =================================================================      
       function dat = getDummyDisplayStruct(structType)
           lineProps.xdata = [1 1200];
           lineProps.ydata = [1 1];
           lineProps.color = 'k';
           lineProps.visible = 'on';
           
           
           if(nargin<1 || isempty(structType))
               structType = 'time series';
           end
           
           dat = PAData.getDummyStruct(structType);
           dat = PAData.overwriteEmptyStruct(dat,lineProps);
%            
%            switch(lower(structType))
%                case 'time series'
%                    accelR.x = lineProps;
%                    accelR.y = lineProps;
%                    accelR.z = lineProps;
%                    
%                    incl.standing = lineProps;
%                    incl.sitting = lineProps;
%                    incl.lying = lineProps;
%                    incl.off = lineProps;
%                    
%                    dat.accelRaw = accelR;
%                    dat.vecMag = lineProps;
%                    dat.steps = lineProps;
%                    dat.lux = lineProps;
%                    dat.inclinometer = incl;
%                case 'aggregate bins'
%                    
%                    
%                case 'features'
%                    
%                otherwise
%                    dat = [];
%                    fprintf('Unknown offset type (%s).\n',structType)
%            end
           
       end
      
       % --------------------------------------------------------------------
       %> @brief Returns a cell listing of available prefilter methods as strings.
       %> @retval prefilterMethods Cell listing of prefilter methods.
       %> - @c none No prefiltering
       %> - @c rms  Root mean square
       %> - @c hash
       %> - @c sum
       %> - @c median
       %> - @c mean
       %> @note These methods can be passed as the argument to PAData's
       %> prefilter() method.
       % --------------------------------------------------------------------
       function prefilterMethods = getPrefilterMethods()
           prefilterMethods = {'None','RMS','Hash','Sum','Median','Mean'};           
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns a cell listing of available feature extraction methods as strings.
       %> @retval extractorMethods Cell listing of prefilter methods.
       %> - @c none No feature extraction
       %> - @c rms  Root mean square
       %> - @c hash
       %> - @c sum
       %> - @c median
       %> - @c mean
       %> @note These methods can be passed as the argument to PAData's
       %> prefilter() method.
       % --------------------------------------------------------------------
       function extractorMethods = getExtractorMethods()
           featureStruct = PAData.getFeatureDescriptionStruct();
           
           fnames = fieldnames(featureStruct);
           
           extractorMethods = cell(numel(fnames),1);
           for f=1:numel(fnames)
               extractorMethods{f} = featureStruct.(fnames{f});
           end
           %extractorMethods = ['All';extractorMethods;'None'];   
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns a struct of feature extraction methods and string descriptions as the corresponding values.
       %> @retval featureStruct A struct of  feature extraction methods and string descriptions as the corresponding values.
       % --------------------------------------------------------------------
       function featureStruct = getFeatureDescriptionStruct()           
           featureStruct.mean = 'Mean';
           featureStruct.median = 'Median';
           featureStruct.std = 'Standard Deviation';           
           featureStruct.rms = 'Root mean square';
           featureStruct.sum = 'sum';           
           featureStruct.var = 'Variance';
           featureStruct.mode = 'Mode';
           %            featureStruct.count = 'Count';
       end
       
       
       % --------------------------------------------------------------------
       %> @brief Returns a struct representing the internal architecture
       %> used by PAData to hold and process acceleration data.  
       %> @li @c timeSeries = 'time series';
       %> @li @c bins = 'aggregate bins';
       %> @li @c features = 'features';
       %> @retval structType Struct with the following fields and corresponding string
       %> values.
       %> @note This is helpful in identifying different offset, scale, label, color,  and
       %> miscellaneous graphic and data choices.
       % --------------------------------------------------------------------
       function structType = getStructTypes()
           structType.timeSeries = 'time series';
           %            structType.bins = 'aggregate bins';
           structType.features = 'features';
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the fieldname of PAData's struct types (see getStructTypes())
       %> that matches the string argument.  
       %> @param description String description that can be 
       %> @li @c timeSeries = 'time series';
       %> @li @c bins = 'aggregate bins';
       %> @li @c features = 'features';
       %> @retval structName Name of the field that matches the description.
       %> @note For example:
       %> @note structName = PAData.getStructNameFromDescription('time series');
       %> @note results in structName = 'timeSeries'
       % --------------------------------------------------------------------
       function structName = getStructNameFromDescription(description)
           structType = PAData.getStructTypes();
           fnames = fieldnames(structType);
           structName = [];
           for f=1:numel(fnames)
               if(strcmpi(description,structType.(fnames{f})))
                   structName = fnames{f};
                   break;
               end
           end
       end
   end
end



% obj.offset.features.median = obj.yDelta;
% obj.offset.features.mean = obj.yDelta*4;
% obj.offset.features.rms = obj.yDelta*8;
% obj.offset.features.std = obj.yDelta*12;
% obj.offset.features.variance = obj.yDelta*16;
% 
% obj.scale.features.median = 1;
% obj.scale.features.mean = 1;
% obj.scale.features.rms = 1;
% obj.scale.features.std = 1;
% obj.scale.features.variance = 1;
% 
% obj.label.features.median.string = 'Median';
% obj.label.features.mean.string = 'Mean';
% obj.label.features.rms.string = 'RMS';
% obj.label.features.std.string = 'Standard Deviation';
% obj.label.features.variance.string = 'Variance';
% 
% obj.label.features.median.position = [0 0 0];
% obj.label.features.mean.position = [0 0 0];
% obj.label.features.rms.position = [0 0 0];
% obj.label.features.std.position = [0 0 0];
% obj.label.features.variance.position = [0 0 0];
% 
% obj.color.features.median.color = 'r';
% obj.color.features.mean.color = 'g';
% obj.color.features.rms.color = 'b';
% obj.color.features.std.color = 'k';
% obj.color.features.variance.color = 'y';
