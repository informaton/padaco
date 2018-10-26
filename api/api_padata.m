    
## Public methods

### getBinRate
        function fs = getBinRate(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the aggregate bin rate in units of aggregate bins/second.
        %> @param obj Instance of PAData
        %> @retval fs Aggregate bins per second.
        % --------------------------------------------------------------------

### setCurWindow
        function curWindow = setCurWindow(obj,window)        
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

        
### getCurWindow
        function curWindow = getCurWindow(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the current window.
        %> @param obj Instance of PAData
        %> @retval curWindow The current window;
        % --------------------------------------------------------------------

### getFrameRate
        function fs = getFrameRate(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the frame rate in units of frames/second.
        %> @param obj Instance of PAData
        %> @retval fs Frames rate in Hz.
        % --------------------------------------------------------------------
        
### setUsageClassificationRules
        function didSet = setUsageClassificationRules(this, ruleStruct)        
        %> @brief Updates the usage state rules with an input struct.  
        %> @param
        %> @param

### getUsageClassificationRules
        function usageRules = getUsageClassificationRules(this)
### getCountsPerMinute
        function [x, varargout] = getCountsPerMinute(obj, signalToGet)
### getSamplesPerWindow
        function windowDur = getSamplesPerWindow(obj,structType)
        % ======================================================================
        %> @brief Returns the number of sample units (samples, bins, frames) for the
        %> for the current window resolution (duration in seconds).
        %> @param obj Instance of PAData.
        %> @param structType Optional string identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval Number of samples, frames, or bins per window display;
        %not necessarily an integer result; can be a fraction.
        %> @note Calcuation based on instance variables windowDurSec and
        %> sampleRate
        

### getWindowSamplerate
        function windowRate = getWindowSamplerate(obj,structType)        
        % --------------------------------------------------------------------
        %> @brief Returns the sampling rate for the current window display selection
        %> @param obj Instance of PAData
        %> @param structType Optional string identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - sample units are sample points
        %> @li @c features - sample units are frames
        %> @li @c bins - sample units are bins
        %> @retval Sample rate of the data being viewed in Hz.
        % --------------------------------------------------------------------     

###  getSampleRate        
        function fs = getSampleRate(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the samplerate of the x-axis accelerometer.
        %> @param obj Instance of PAData
        %> @retval fs Sample rate of the x-axis accelerometer.
        % --------------------------------------------------------------------



### getCurUncorrectedWindowRange
        function windowRange = getCurUncorrectedWindowRange(obj,structType)
        % ======================================================================
        %> @brief Returns the current windows range
        %> @param obj Instance of PAData.
        %> @param structType Optional string identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval A 2x1 vector with start, stop range of the current window returned as
        %> samples beginning with 1 for the first sample.
        %> @note This uses instance variables windowDurSec, curWindow, and sampleRate to
        %> determine the sample range for the current window.  The first
        %> value is floored and the second is ceil'ed.
        % =================================================================

### getCurWindowRange
        function correctedWindowRange = getCurWindowRange(obj,structType)
        % ======================================================================
        %> @brief Returns a structure of PAData's time series data.
        %> @param obj Instance of PAData.
        %> @param structType Optional string identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval A 2x1 vector with start, stop range of the current window returned as
        %> samples beginning with 1 for the first sample.  The second value
        %> (i.e. the stop sample) is capped at the current value of
        %> getDurationSamples().
        %> @note This uses instance variables windowDurSec, curWindow, and sampleRate to
        %> determine the sample range for the current window.
        % =================================================================

   
### setAggregateDurationMinutes        
        function aggregateDurationMin = setAggregateDurationMinutes(obj,aggregateDurationMin)        
        % --------------------------------------------------------------------
        %> @brief Set the aggregate duration (in minutes) instance variable.
        %> @param obj Instance of PAData
        %> @param aggregateDurationMin The aggregate duration to set aggregateDurMin to.
        %> @retval aggregateDurationMin The current value of instance variable aggregateDurMin.
        %> @note If the input argument for aggregateDurationMin is negative or exceeds
        %> the current frame duration value (in minutes), then it is not used
        %> and the current frame duration is retained (and also returned).
        % --------------------------------------------------------------------
           
         
### getAggregateDurationInMinutes
        function aggregateDuration = getAggregateDurationInMinutes(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the current aggregate duration in minutes.
        %> @param obj Instance of PAData
        %> @retval aggregateDuration The current window;
        % --------------------------------------------------------------------
        
        
### getBinCount
        function binCount = getBinCount(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the total number of aggregated bins the data can be divided
        %> into based on frame rate and the duration of the time series data.
        %> @param obj Instance of PAData
        %> @retval binCount The total number of frames contained in the data.
        %> @note In the case of data size is not broken perfectly into frames, but has an incomplete frame, the
        %> window count is rounded down.  For example, if the frame duration 1 min, and the study is 1.5 minutes long, then
        %> the frame count is 1.
        % --------------------------------------------------------------------
        
        
### getStudyID
        function studyID = getStudyID(obj,outputType)
        %> @brief Returns studyID instance variable.
        %> @param Instance of PAData
        %> @param Optional output format for the study id.  Can be
        %> - 'string'
        %> - 'numeric'
        %> @retval Study ID that identifies the data (i.e. what or who it is
        %> attributed to).
        
        
### setFrameDurationMinutes
        function frameDurationMin = setFrameDurationMinutes(obj,frameDurationMin)
        % --------------------------------------------------------------------
        %> @brief Set the frame duration (in minutes) instance variable.
        %> @param obj Instance of PAData
        %> @param frameDurationMin The frame duration to set frameDurMin to.
        %> @retval frameDurationMin The current value of instance variable frameDurMin.
        %> @note If the input argument for frameDurationMin is negative or exceeds
        %> the maximum duration of data, then it is not used
        %> and the current frame duration is retained (and also returned).
        % --------------------------------------------------------------------
        
        
### setFrameDurationHours
        function frameDurationHours = setFrameDurationHours(obj,frameDurationHours)
        % --------------------------------------------------------------------
        %> @brief Set the frame duration (hours) instance variable.
        %> @param obj Instance of PAData
        %> @param frameDurationHours The frame duration to set frameDurHours instance variable to.
        %> @retval frameDurationHours The current value of instance variable frameDurHour.
        %> @note If the input argument for frameDurationHours is negative or exceeds
        %> the maximum duration of data, then it is not used
        %> and the current frame duration is retained (and also returned).
        % --------------------------------------------------------------------
        
        
### getFrameDuration
        function [curFrameDurationMin, curFrameDurationHour] = getFrameDuration(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the frame duration (in hours and minutes)
        %> @param obj Instance of PAData
        %> @retval curFrameDurationMin The current frame duration minutes field;
        %> @retval curFramDurationHour The current frame duration hours field;
        % --------------------------------------------------------------------
        
        
### getFrameDurationInHours
        function frameDurationHours = getFrameDurationInHours(obj)
        % N/A
       
        
        
### getFrameDurationInMinutes
        function frameDurationMin = getFrameDurationInMinutes(obj)
        % N/A

        
### getFrameCount
        function frameCount = getFrameCount(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the total number of frames the data can be divided
        %> into evenly based on frame rate and the duration of the time series data.
        %> @param obj Instance of PAData
        %> @retval frameCount The total number of frames contained in the data.
        %> @note In the case of data size is not broken perfectly into frames, but has an incomplete frame, the
        %> window count is rounded down (floor).  For example, if the frame duration 1 min, and the study is 1.5 minutes long, then
        %> the frame count is 1.
        % --------------------------------------------------------------------
        
        
### getDurationSamples
        function durationSamp = getDurationSamples(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the number of samples contained in the time series data.
        %> @param obj Instance of PAData
        %> @retval durationSamp Number of elements contained in durSamples instance var
        %> (initialized by number of elements in accelRaw.x
        % --------------------------------------------------------------------
         
        
### setWindowDurSec
        function durSec = setWindowDurSec(obj,durSec)
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
        
        
### getVisible
        function visibleStruct = getVisible(obj,structType)
        % --------------------------------------------------------------------
        %> @brief Returns the visible instance variable
        %> @param obj Instance of PAData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this is not)
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval visibileStruct A struct of obj's visible field values
        % --------------------------------------------------------------------
        
        
        
### getColor
        function colorStruct = getColor(obj,structType)
        % --------------------------------------------------------------------
        %> @brief Returns the color instance variable
        %> @param obj Instance of PAData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this is not)
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval colorStruct A struct of color values correspodning to the time series
        %> fields of obj.color.
        % --------------------------------------------------------------------
        
        
### getScale
        function scaleStruct = getScale(obj,structType)
        % --------------------------------------------------------------------
        %> @brief Returns the scale instance variable
        %> @param obj Instance of PAData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this not):
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval scaleStruct A struct of scalar values correspodning to the time series
        %> fields of obj.scale.
        % --------------------------------------------------------------------
        
        
### getOffset
        function offsetStruct = getOffset(obj,structType)
        % --------------------------------------------------------------------
        %> @brief Returns the offset instance variable
        %> @param obj Instance of PAData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this not):
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval offsetStruct A struct of scalar values correspodning to the struct type
        %> fields of obj.offset.
        % --------------------------------------------------------------------
        
        
### getLabel
        function labelStruct = getLabel(obj,structType)
        % --------------------------------------------------------------------
        %> @brief Returns the label instance variable
        %> @param obj Instance of PAData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include:
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval labelStruct A struct of string values which serve to label the correspodning to the time series
        %> fields of obj.label.
        % --------------------------------------------------------------------
         
        
### getOffAccelType
        function offAccelType = getOffAccelType(obj,accelTypeStr)
        %> @brief Retuns the accelType that is not set.  This is useful in
        %> later removing unwanted accel fields.
        %> @param obj Instance of PAData.
        %> @param accelTypeStr (optional) String that can be used in place
        %> of obj.accelType for determining the current accel type to find
        %> the opposing accel type of (i.e. the offAccelType).
        %> @retval offAccelType Enumerated type which is either
        %> - @c count When accelType is @c raw
        %> - @c raw When accelType is @c count
        %> - @c [] All other cases.
        
        
### getPropertyStruct
        function propertyStruct = getPropertyStruct(obj,propertyName,structType)
        % --------------------------------------------------------------------
        %> @brief Returns the visible instance variable
        %> @param obj Instance of PAData
        %> @param propertyName Name of instance variable being requested.
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this is not)
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval visibileStruct A struct of obj's visible field values
        % --------------------------------------------------------------------
        
        
### pruneStruct
        function prunedStruct = pruneStruct(obj,accelStruct)
        % curtail unwanted acceleration type.
         
        
### setOffset
        function varargout = setOffset(obj,fieldName,newOffset)
        % --------------------------------------------------------------------
        %> @brief Sets the offset instance variable for a particular sub
        %> field.
        %> @param obj Instance of PAData
        %> @param fieldName Dynamic field name to set in the 'offset' struct.
        %> @note For example if fieldName = 'timeSeries.vecMag' then
        %> obj.offset.timeSeries.vecMag = newOffset; is evaluated.
        %> @param newOffset y-axis offset to set obj.offset.(fieldName) to.
        % --------------------------------------------------------------------
        
        
### setScale
        function varargout = setScale(obj,fieldName,newScale)
        % --------------------------------------------------------------------
        %> @brief Sets the scale instance variable for a particular sub
        %> field.
        %> @param obj Instance of PAData
        %> @param fieldName Dynamic field name to set in the 'scale' struct.
        %> @note For example if fieldName = 'timeSeries.vecMag' then
        %> obj.scale.timeSeries.vecMag = newScale; is evaluated.
        %> @param newScale Scalar value to set obj.scale.(fieldName) to.
        % --------------------------------------------------------------------
        
        
### setColor
        function varargout = setColor(obj,fieldName,newColor)
        % --------------------------------------------------------------------
        %> @brief Sets the color instance variable for a particular sub
        %> field.
        %> @param obj Instance of PAData
        %> @param fieldName Dynamic field name to set in the 'color' struct.
        %> @note For example if fieldName = 'timeSeries.accel.vecMag' then
        %> obj.color.timeSerie.accel.vecMag = newColor; is evaluated.
        %> @param newColor 1x3 vector to set obj.color.(fieldName) to.
        % --------------------------------------------------------------------
        
        
### setVisible
        function varargout = setVisible(obj,fieldName,newVisibilityStr)
        % --------------------------------------------------------------------
        %> @brief Sets the visible instance variable for a particular sub
        %> field.
        %> @param obj Instance of PAData
        %> @param fieldName Dynamic field name to set in the 'visible' struct.
        %> @param newVisibilityStr Visibility property value.
        %> @note Valid values include
        %> - @c on
        %> - @c off
        % --------------------------------------------------------------------
        
        
### setProperty
        function varargout = setProperty(obj,propertyName,fieldName,propertyValueStr)
        % --------------------------------------------------------------------
        %> @brief Sets the specified instance variable for a particular sub
        %> field.
        %> @param obj Instance of PAData
        %> @param propertyName instance variable to set the property of.
        %> @param fieldName Dynamic field name to set in the propertyName struct.
        %> @param propertyValueStr String value of property to set fieldName
        %> to.
        % --------------------------------------------------------------------
        
        
### getAccelType
        function accelType = getAccelType(obj)
        % NA
        
### getWindowCount
        function windowCount = getWindowCount(obj)
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
        
        
### getStartStopDatenum
        function startstopnum =  getStartStopDatenum(obj)
        % --------------------------------------------------------------------
        %> @brief Returns the start and stop datenums for the study.
        %> @param obj Instance of PAData
        %> @retval startstopnum A 1x2 vector.
        %> - startstopnum(1) The datenum of the study's start
        %> - startstopnum(2) The datenum of the study's end.
        % --------------------------------------------------------------------
        
        
### getDisplayMinMax
        function yLim = getDisplayMinMax(obj)
        % ======================================================================
        %> @brief Returns the minimum and maximum amplitudes that can be
        %> displayed uner the current configuration.
        %> @param obj Instance of PAData.
        %> @retval yLim 1x2 vector containing ymin and ymax.
        % ======================================================================
        
        
### getMinmax
        function minMax = getMinmax(obj,fieldType)
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
        %> - @b accel.count Returns a struct of minmax values for x,y, and z
        %and vecMag count fields.
        %> - @b accel.raw Returns a struct of minmax values for x,y, and z
        %and vecMag count fields.
        %> - @b lux Returns a 1x2 minmax vector for lux values.
        %> - @b inclinometer Returns a struct of minmax values for lux fields.
        %> - @b steps Returns a struct of minmax values for step fields.
        %> @retval minMax Minimum maximum values for each time series field
        %> contained in obj.getStruct() or a single 2x1 vector of min max
        %> values for the field name specified.
        % =================================================================
        
        
### getFilename
        function [filename,pathname,fullFilename] = getFilename(obj)
        % ======================================================================
        %> @brief Returns the filename, pathname, and full filename (pathname + filename) of
        %> the file that the accelerometer data was loaded from.
        %> @param obj Instance of PAData
        %> @retval filename The short filename of the accelerometer data.
        %> @retval pathname The pathname of the accelerometer data.
        %> @retval fullFilename The full filename of the accelerometer data.
        % =================================================================
        
        
### setFullFilename
        function success = setFullFilename(obj,fullfilename)
        % ======================================================================
        %> @brief Sets the pathname and filename instance variables using
        %> the input full filename.
        %> @param obj Instance of PAData
        %> @param fullfilename The full filenmae of the accelerometer data
        %> that will be set
        %> @retval success (T/F)
        %> -true: if fullfilename exists and is instance variables are set
        %> - false: otherwise
        %> @note See also getFilename()
        % =================================================================
        
        
### getFullFilename
        function fullFilename = getFullFilename(obj)
        % ======================================================================
        %> @brief Returns the full filename (pathname + filename) of
        %> the accelerometer data.
        %> @param obj Instance of PAData
        %> @retval fullFilename The full filenmae of the accelerometer data.
        %> @note See also getFilename()
        % =================================================================
        
        
### getWindowDurSec
        function windowDurationSec = getWindowDurSec(obj)
        % ======================================================================
        %> @brief Returns the protected intance variable windowDurSec.
        %> @param obj Instance of PAData
        %> @retval windowDurationSec The value of windowDurSec
        % =================================================================
        
            
### loadFileHeader
        function loadFileHeader(obj,fullFilename)
        % ======================================================================
        %> @brief Load CSV header values (start time, start date, and window
        %> period).
        %> @param obj Instance of PAData.
        %> @param fullFilename The full filename to open and examine.
        % =================================================================
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
        
        
### getHeaderAsString
        function headerStr = getHeaderAsString(obj)
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
        
        
### loadFile
        function didLoad = loadFile(obj,fullfilename)
        % ======================================================================
        %> @brief Loads an accelerometer data file.
        %> @param obj Instance of PAData.
        %> @param fullfilename (optional) Full filename to load.  If this
        %> is not included, or does not exist, then the instance variables pathname and filename
        %> are used to identify the file to load.
        % =================================================================
        
        
### loadCountFile
        function didLoad = loadCountFile(obj,fullCountFilename)
        % ======================================================================
        %> @brief Loads an accelerometer "count" data file.
        %> @param obj Instance of PAData.
        %> @param fullCountFilename The full (i.e. with path) filename to load.
        % =================================================================
                
        
### loadRawCSVFile
        function didLoad = loadRawCSVFile(obj,fullRawCSVFilename, loadFastOption)
        % ======================================================================
        %> @brief Loads an accelerometer raw data file.  This function is
        %> intended to be called from loadFile() to ensure that
        %> loadCountFile is called in advance to guarantee that the auxialiary
        %> sensor measurements are loaded into the object (obj).  The
        %> auxialiary measures (e.g. lux, steps) are upsampled to the
        %> sampling rate of the raw data (typically 40 Hz).
        %> @param obj Instance of PAData.
        %> @param fullRawCSVFilename The full (i.e. with path) filename for raw data to load.
        % =================================================================
        
        
### loadGT3XFile
        function didLoad = loadGT3XFile(obj, fullFilename)
        % ======================================================================
        %> @brief Loads an accelerometer's raw data from binary files stored
        %> in the path name given.
        %> @param obj Instance of PAData.
        %> @param pathWithRawBinaryFiles Name of the path (a string) that
        %> contains raw acceleromater data stored in one or more binary files.
        %> @note Currently, only two firmware versions are supported:
        %> - 2.5.0
        %> - 3.1.0
        
        
### loadPathOfRawBinary
        function didLoad = loadPathOfRawBinary(obj, pathWithRawBinaryFiles)
        % ======================================================================
        %> @brief Loads an accelerometer's raw data from binary files stored
        %> in the path name given.
        %> @param obj Instance of PAData.
        %> @param pathWithRawBinaryFiles Name of the path (a string) that
        %> contains raw acceleromater data stored in one or more binary files.
        %> @note Currently, only two firmware versions are supported:
        %> - 2.5.0
        %> - 3.1.0
        % =================================================================
        
                
### setRawXYZ
        function setRawXYZ(obj, rawXorXYZ, rawY, rawZ)
        % ======================================================================
        %> @brief Resamples previously loaded 'count' data to match sample rate of
        %> raw accelerometer data that has been loaded in a following step (see loadFile()).
        %> @param obj Instance of PAData.       %
        %> @note countPeriodSec, sampleRate, steps, lux, and accel values
        %> must be set in advance of this call.
        % ======================================================================
        
        
### resampleCountData
        function resampleCountData(obj)
        % ======================================================================
        %> @brief Resamples previously loaded 'count' data to match sample rate of
        %> raw accelerometer data that has been loaded in a following step (see loadFile()).
        %> @param obj Instance of PAData.       %
        %> @note countPeriodSec, sampleRate, steps, lux, and accel values
        %> must be set in advance of this call.
        % ======================================================================
        
        
### sample2window
        function window = sample2window(obj,sample,windowDurSec,samplerate)
        % ======================================================================
        %> @brief Calculates, and returns, the window for the given sample index of a signal.
        %> @param obj Instance of PAData.
        %> @param sample Sample point to discover the containing window of.
        %> @param windowDurSec Window duration in seconds (scalar) (optional)
        %> @param samplerate Sample rate of the data (optional)
        %> @retval window The window.
        % ======================================================================
        
        
### datenum2window
        function window = datenum2window(obj,datenumSample,structType)
        % ======================================================================
        %> @brief Returns the display window for the given datenum
        %> @param obj Instance of PAData.
        %> @param datenumSample A date number (datenum) that should be in the range of
        %> instance variable dateTimeNum
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval window The window.
        % ======================================================================
        
        
        
### window2datenum
        function dateNum = window2datenum(obj,windowSample)
        % ======================================================================
        %> @brief Returns the starting datenum for the window given.
        %> @param obj Instance of PAData.
        %> @param windowSample Index of the window to check.       %
        %> @retval dateNum the datenum value at the start of windowSample.
        %> @note The starting point is adjusted based on obj startDatenum
        %> value and its windowDurSec instance variable.
        % ======================================================================
        
        
        
### prefilter
        function obj = prefilter(obj,method)
        % ======================================================================
        %> @brief Prefilters accelerometer data.
        %> @note Not currently implemented.
        %> @param obj Instance of PAData.
        %> @param method String name of the prefilter method.
        % ======================================================================
        
        
### getFrameableSampleCount
        function frameableSamples = getFrameableSampleCount(obj)
        % NA
        
### extractFeature
        function obj = extractFeature(obj,signalTagLine,method)
        % ======================================================================
        %> @brief Extracts features from the identified signal using the
        %> given method.
        %> @param obj Instance of PAData.
        %> @param signalTagLine Tag identifying the signal to extract
        %> features from.  Default is 'accel.count.vecMag'
        %> @param method String name of the extraction method.  Possible
        %> values include:
        %> - c none
        %> - c all
        %> - c rms
        %> - c mean
        %> - c mad        
        %> - c median
        %> - c sum
        %> - c var
        %> - c std
        %> - c mode
        %> - c usagestate
        %> - c psd
        % ======================================================================
        
        
### calculatePSD
        function obj = calculatePSD(obj,signalTagLine)
        %> @brief Calculates the PSD for the current frames and assigns the
        %> result to obj.psd.frames.  Will also assign
        %> obj.frames_signalTagLine to the signalTagLine argument when
        %> provided, otherwise the current value for
        %> obj.frames_signalTagLine is assumed to be correct and specific for
        %> the source of the frame data.  PSD bands are assigned to their
        %> named fields (e.g. psd_band_1) in the obj.features.(bandName)
        %> field.  
                
### getPSD
        function dataPSD = getPSD(obj)
        % NA
        
        
### getPSDBands
        function [psdBands, psdAll] = getPSDBands(obj, numBands)
        % NA
        
        
### getPSDSettings
        function [psdSettings, Fs] = getPSDSettings(obj)
        % NA
        
### getDayCount
        function [completeDayCount, incompleteDayCount, totalDayCount] = getDayCount(obj,elapsedStartHour, intervalDurationHours)
        % --------------------------------------------------------------------
        %> @brief Calculates the number of complete days and the number of
        %> incomplete days available in the data for the most recently
        %> defined feature vector.
        %> @param obj Instance of PAData
        %> @param featureFcn Function name or handle to use to obtain
        % --------------------------------------------------------------------
        
        
### getAlignedFeatureVecs
        function [alignedFeatureVecs, alignedStartDateVecs] = getAlignedFeatureVecs(obj,featureFcn,signalTagLine,elapsedStartHour, intervalDurationHours)
        % --------------------------------------------------------------------
        %> @brief Calculates a desired feature for a particular acceleration object's field value.
        %> and returns it as a matrix of elapsed time aligned vectors.
        %> @param obj Instance of PAData
        %> @param featureFcn Function name or handle to use to obtain
        %> features.
        %> @param signalTagLine String name of the field to obtain data from.
        %> @param elapsedStartHour Elapsed hour (starting from 00:00 for new
        %> day) to begin aligning feature vectors.
        %> @param intervalDurationHours number of hours between
        %> consecutively aligned feature vectors.
        %> @note For example if elapsedStartHour is 1 and intervalDurationHours is 24, then alignedFeatureVecs will
        %> start at 01:00 of each day (and last for 24 hours a piece).
        %> @retval alignedFeatureVecs Matrix of row vectors, each of which is a
        %> feature calculated according to featureFcn and aligned according to elapsed start time and
        %> interval duration in hours.  Consecutive rows are vector values in order of the section they are calculated from.
        %> @retval alignedStartDateVecs Nx6 matrix of datevec values whose
        %> rows correspond to the start datevec of the corresponding row of alignedFeatureVecs.
        % --------------------------------------------------------------------
        
        
### classifyUsageForAllAxes
        function didClassify = classifyUsageForAllAxes(obj)
        % ======================================================================
        %> @brief Classifies the usage state for each axis using count data from
        %> each axis.
        %> @param obj Instance of PAData.
        %> @retval didClassify True/False depending on success.
        % ======================================================================        
        
        
### classifyWearNonwear
        function [wearVec,wearState, startStopDateNums] = classifyWearNonwear(obj, countActivity, classificationMethod)
        % ======================================================================
        %> @brief Classifies epochs into wear and non-wear state using the 
        %> count activity values and classification method given.
        %> @param obj Instance of PAData.
        %> @param vector of count activity to apply classification rules
        %> too.  If not provided, then the vector magnitude is used by
        %> default.
        %> @param String identifying the classification to use; can be:
        %> - padaco [default]
        %> - troiano 
        %> - choi
        %> @retval usageVec A vector of length obj.dateTimeNum whose values
        %> represent the usage category at each sample instance specified by
        %> @b dateTimeNum.
        %> - c Nonwear 0
        %> - c Wear 1        
        %> @retval usageState A three column matrix identifying usage state
        %> and duration.  Column 1 is the usage state, column 2 and column 3 are
        %> the states start and stop times (datenums).
        %> @note Usage states are categorized as follows:
        %> - c 0 Nonwear
        %> - c 1 Wear
        %> @retval startStopDatenums Start and stop datenums for each usage
        %> state row entry of usageState.
        % ======================================================================
        
        
### classifyTroianoWearNonwear
        function nonWearVec = classifyTroianoWearNonwear(obj, minNonWearPeriod_minutes, countActivity,  )
        %> @brief Implementation of Troiano algorithm used with NHANES data
        %> and later updated by Choi et al.
        %> A non-wear period starts at a minute with the intensity count of zero. Minutes with intensity count=0 or
        %> up to 2 consecutive minutes with intensity counts between 1 and 100 are considered to be valid non-wear 
        %> minutes. A non-wear period is established when the specified length of consecutive non-wear minutes is  
        %> reached. The non-wear period stops when any of the following conditions is met: 
        %>  - one minute with intensity count >100    
        %>  - one minute with a missing intensity count
        %>  - 3 consecutive minutes with intensity counts between 1 and 100 
        %>  - the last minute of the day 
        %> @param countActivity Vector of count activity.  Default is to
        %> use vector magnitude counts currently loaded.
        %> @param minNonWearPeriod_minutes minimum length for the non-wear
        %period in minutes, must be >1 minute.  Default is 90 minutes.
        
        
### classifyUsageState
        function [usageVec, wearState, startStopDateNums] = classifyUsageState(obj, countActivity)
        % ======================================================================
        %> @brief Categorizes the study's usage state.
        %> @param obj Instance of PAData.
        %> @param vector of count activity to apply classification rules
        %> too.  If not provided, then the vector magnitude is used by
        %> default.
        %> @retval usageVec A vector of length obj.dateTimeNum whose values
        %> represent the usage category at each sample instance specified by
        %> @b dateTimeNum.
        %> - c usageVec(activeVec) = 30
        %> - c usageVec(inactiveVec) = 25
        %> - c usageVec(~awakeVsAsleepVec) = 20
        %> - c usageVec(sleepVec) = 15  sleep period (could be a nap)
        %> - c usageVec(remSleepVec) = 10  REM sleep
        %> - c usageVec(nonwearVec) = 5  Non-wear
        %> - c usageVec(studyOverVec) = 0  Non-wear, study over.
        %> @retval whereState Vector of wear vs non-wear state.  Each element represent the
        %> consecutive grouping of like states found in the usage vector.
        %> @note Wear states are categorized as follows:
        %> - c 5 Nonwear
        %> - c 10 Wear
        %> @retval startStopDatenums Start and stop datenums for each usage
        %> state row entry of usageState.
        % ======================================================================
        
        
### describeActivity
        function activityStruct = describeActivity(obj,categoryStr)
        % ======================================================================
        %> @brief Describes an activity.
        %> @note This is not yet implemented.
        %> @param obj Instance of PAData.
        %> @param categoryStr The type of activity to describe.  This is a string.  Values include:
        %> - c sleep
        %> - c wake
        %> - c inactivity
        %> @retval activityStruct A struct describing the activity.  Fields
        %> include:
        %> - c empty
        % ======================================================================
        
        
### saveToFile
        function obj = saveToFile(obj,activityType, saveFilename)
        % ======================================================================
        %> @brief Saves data to an ascii file.
        %> @note This is not yet implemented.
        %> @param obj Instance of PAData.
        %> @param activityType The type of activity to save.  This is a string.  Values include:
        %> - c usageState
        %> - c activitiy
        %> - c inactivity
        %> - c sleep
        %> @param saveFilename Name of the file to save data to.
        %> @note This method is under construction and does not actually
        %> save any data at the moment.
        % ======================================================================
        
        
### subsindex
        function dat = subsindex(obj,indices,structType)
        % ======================================================================
        %> @brief overloaded subsindex method returns structure of time series data
        %> at indices provided.
        %> @param obj Instance of PAData
        %> @param indices Vector (logical or ordinal) of indices to select time
        %> series data by.
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PAData's time series instance data for the indices provided.  The fields
        %> include:
        %> - accel.(accelType).x
        %> - accel.(accelType).y
        %> - accel.(accelType).z
        %> - accel.(accelType).vecMag
        %> - steps
        %> - lux
        %> - inclinometer
        % ======================================================================
        
### subsref
        function [sref,varargout] = subsref(obj,s)
        %> NA
        
        
### getStruct
        function dat = getStruct(obj,choice,structType)
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
        %> - @b all All (default) All available sensor fields
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins        
        %> @retval dat A struct of PAData's time series, aggregate bins, or features instance data.  The fields
        %> for time series data include:
        %> - @c accel.(obj.accelType).x
        %> - @c accel.(obj.accelType).y
        %> - @c accel.(obj.accelType).z
        %> - @c accel.(obj.accelType).vecMag
        %> - @c steps
        %> - @c inclinometer
        %> - @c lux
        % =================================================================
        
        
### getSaveParameters
        function pStruct = getSaveParameters(obj)
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
        %> - @c scale
        %> - @c label
        %> - @c offset
        %> - @c color
        %> - @c yDelta
        %> - @c visible
        %> - @c usageStateRules

        
    
## Protected methods            
        
### loadPadacoRawBinFile
        function [didLoad,recordCount] = loadPadacoRawBinFile(obj,fullBinFilename)
        %> N/A

### loadRawActivityBinFile
        function recordCount = loadRawActivityBinFile(obj,fullRawActivityBinFilename,firmwareVersion)
        % ======================================================================
        %> @brief Loads raw accelerometer data from binary file produced via
        %> actigraph Firmware 2.5.0 or 3.1.0.  This function is
        %> intended to be called from loadFile() to ensure that
        %> loadCountFile is called in advance to guarantee that the auxialiary
        %> sensor measurements are loaded into the object (obj).  The
        %> auxialiary measures (e.g. lux, steps) are upsampled to the
        %> sampling rate of the raw data (typically 40 Hz).
        %> @param obj Instance of PAData.
        %> @param fullRawActivityBinFilename The full (i.e. with path) filename for raw data,
        %> stored in binary format, to load.
        %> @param firmwareVersion String identifying the firmware version.
        %> Currently only '2.5.0' and '3.1.0' are supported.
        % Testing:  logFile = /Volumes/SeaG 1TB/sampledata_reveng/T1_GT3X_Files/700851/log.bin
        %> @retval recordCount - The number of records (or samples) found
        %> and loaded in the file.
        % =================================================================
        
        
### getAllStruct
        function dat = getAllStruct(obj,structType)
        % ======================================================================
        %> @brief Returns a structure of an insance PAData's time series data.
        %> @param obj Instance of PAData.
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PAData's time series instance data.  The fields
        %> include:
        %> - @c accel
        %> - @c accel
        %> - @c accel
        %> - @c accel
        %> - @c steps
        %> - @c lux
        %> - @c inclinometer
        %> - @c windowDurSec
        % =================================================================
        
        
### getCurrentStruct
        function curStruct = getCurrentStruct(obj,structType)
        % ======================================================================
        %> @brief Returns a structure of an insance PAData's time series
        %> data at the current window.
        %> @param obj Instance of PAData.
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval curStruct A struct of PAData's time series or features instance data.  The fields
        %> for time series include:
        %> - @c accel.(obj.accelType).x
        %> - @c accel.(obj.accelType).y
        %> - @c accel.(obj.accelType).z
        %> - @c accel.(obj.accelType).vecMag
        %> - @c steps
        %> - @c lux
        %> - @c inclinometer (struct with more fields)
        %> While the fields for @c features include
        %> @li @c median
        %> @li @c mean
        %> @li @c rms
        % =================================================================
        
        
### getCurrentDisplayStruct
        function dat = getCurrentDisplayStruct(obj,structType)
        % ======================================================================
        %> @brief Returns the time series data as a struct for the current window range,
        %> adjusted for visual offset and scale.
        %> @param obj Instance of PAData.
        %> @param structType (Optional) String identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PAData's time series or features instance data.  The fields
        %> for time series data include:
        %> - accel.(obj.accelType).x
        %> - accel.(obj.accelType).y
        %> - accel.(obj.accelType).z
        %> - accel.(obj.accelType).vecMag
        %> - steps
        %> - lux
        %> - inclinometer (struct with more fields)
        %> The fields for feature data include:
        %> @li @c median
        %> @li @c mean
        %> @li @c rms
        % =================================================================
        
        
### getCurrentOffsetStruct
        function dat = getCurrentOffsetStruct(obj,structType)
        % ======================================================================
        %> @brief Returns [x,y,z] offsets of the current time series
        %> data being displayed.  Values are stored in .position child field
        %> @param obj Instance of PAData.
        %> @param structType (Optional) String identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval dat A struct of [x,y,z] starting location of each
        %> data field.  The fields (for 'time series') include:
        %> - accel.(obj.accelType).x
        %> - accel.(obj.accelType).y
        %> - accel.(obj.accelType).z
        %> - accel.(obj.accelType).vecMag
        %> - steps
        %> - lux
        %> - inclinometer (struct with more fields)
        % =================================================================
        
        

## Static methods
        
        
### loadPadacoRawBinFileHeader
        function fileHeader = loadPadacoRawBinFileHeader(fid)
        %> @param fid File identifier is expected to be a file resource
        %> for a binary file obainted using fopen(<filename>,'r');
        %> @retval fileHeader A struct with file header field value pairs.
        %> An empty value is returned in the event that the fid is bad.
        

        
### parseInfoTxt
        function [infoStruct, firmware] = parseInfoTxt(infoTxtFullFilename)
        % ======================================================================
        %> @brief Parses the information found in input file name and returns
        %> the result as a struct of field-value pairs.
        %> @param obj Instance of PAData.
        %> @param infoTxtFullFilename Name of the info.txt that contains
        %> sensor meta data.
        %> @retval infoStruct A struct of the field value pairings parsed
        %> from info.txt
        %> @retval firmware String value of Firmware field as found in the
        %> info.txt file.  It is set to the empty string when not found.
        %> @note Currently, only two firmware versions are supported:
        %> - 2.5.0
        %> - 3.1.0
        % =================================================================
        
### calcFeatureVector
        function featureVector = calcFeatureVector(dataVector,samplesPerFrame,featureFcn)
        % =================================================================
        %> @brief Calculates a feature vector for the provided data and feature function.
        %> @param dataVector An N*Mx1 row vector.
        %> @param samplesPerFrame The number of samples to be used per
        %> frame.  The dataVector is reshaped into an NxM matrix whose
        %> columns are taken sample by sample from the dataVector.  Thus,
        %> each column represents a frame that the feature function is
        %> applied to.
        %> @param featureFcn String name of the feature function to be
        %> applied.  See calcFeatureVectorFromFrames for a list of
        %> supported feature functions and corresponding labels.
        %> @retval featureVector Mx1 vector of feature values.  The ith row
        %> entry corresponds to the ith frame's feature value.
        
        
### calcFeatureVectorFromFrames
        function Mx1_featureVector = calcFeatureVectorFromFrames(NxM_dataFrames,featureFcn)
        % NA

### getFeatureFcn
        function featureFcn = getFeatureFcn(functionName)
        %> NA
        
### reprocessEventVector
        function processVec = reprocessEventVector(logicalVec,min_duration_samples,merge_distance_samples)
        % =================================================================
        %> @brief Removes periods of activity that are too short and groups
        %> nearby activity groups together.
        %> @param logicalVec Initial vector which has 1's where an event or
        %> activity is occurring at that sample.
        %> @param min_duration_samples The minimum number of consecutive
        %> samples required for a run of on (1) samples to be kept.
        %> @param merge_distance_samples The maximum number of samples
        %> considered when looking for adjacent runs to merge together.
        %> Adjacent runs that are within this distance are merged into a
        %> single run beginning at the start of the first and stopping at the end of the last run.
        %> @retval processVec A vector of size (logicalVec) that has removed
        %> runs (of 1) that are too short and merged runs that are close enough
        %> together.
        %======================================================================
        
        
### movingSummer
        function summedSignal = movingSummer(signal, filterOrder)
        %======================================================================
        %> @brief Moving summer finite impulse response filter.
        %> @param signal Vector of sample data to filter.
        %> @param filterOrder filter order; number of taps in the filter
        %> @retval summedSignal The filtered signal.
        %> @note The filter delay is taken into account such that the
        %> return signal is offset by half the delay.
        %======================================================================
        
        
        
### unrollEvents
        function vector = unrollEvents(eventsStartStop,vectorSize)
        %======================================================================
        %> @brief Helper function to convert an Nx2 matrix of start stop
        %> events into a single logical vector with 1's located at the
        %> locations corresponding to the samples inclusively between
        %> eventStartStops row entries.
        %> @param eventStartStop
        %> @param vectorSize The length or size of the sample data to unroll
        %> the start stop events back to.
        %> @note eventStartStop = thresholdCrossings(vector,0);
        %> @retval vector
        %======================================================================
        
        
        

### getDefaultTagLineLabels
        function [tagLines,labels] = getDefaultTagLineLabels()
        %======================================================================
        %> @brief returns a cell of tag lines and the associated label
        %> describing the tag line.
        %> @retval tagLines Cell of tag lines
        %> @retval labels Cell of string descriptions that correspond to tag
        %> lines in the tagLines cell.
        %> @note Tag lines are useful for dynamic struct indexing into
        %> structs returned by getStruct.
        %======================================================================
        %> tagLines = 
        %> - @c accel.raw.vecMag';
        %> - @c accel.raw.x';
        %> - @c accel.raw.y';
        %> - @c accel.raw.z';
        %> - @c accel.count.vecMag';
        %> - @c accel.count.x';
        %> - @c accel.count.y';
        %> - @c accel.count.z';
        %> - @c steps';
        %> - @c lux';
        %> - @c inclinometer.standing';
        %> - @c inclinometer.sitting';
        %> - @c inclinometer.lying';
        %> - @c inclinometer.off';
        %> labels
        %> - @c Magnitude (raw)';
        %> - @c X (raw)';
        %> - @c Y (raw)';
        %> - @c Z (raw)';
        %> - @c Magnitude (count)';
        %> - @c X (count)';
        %> - @c Y (count)';
        %> - @c Z (count)';
        %> - @c Steps';
        %> - @c Luminance'
        %> - @c inclinometer.standing';
        %> - @c inclinometer.sitting';
        %> - @c inclinometer.lying';
        %> - @c inclinometer.off';
        
        
### getDefaultParameters
        function pStruct = getDefaultParameters()
        % ======================================================================
        %> @brief Returns a structure of PAData's default parameters as a struct.
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
        %> - @c scale
        %> - @c label
        %> - @c offset
        %> - @c color
        %> - @c visible
        %> - @c usageState Struct defining usage state classification
        %> thresholds and parameters.
        %> @note This is useful with the PASettings companion class.
        %> @note When adding default parameters, be sure to match saveable
        %> parameters in getSaveParameters()
        %======================================================================

        
### subsStruct
        function structOut = subsStruct(structIn,indices)
        % ======================================================================
        %> @brief Returns structure whose values are taken from the struct
        %> and indices provided.
        %> @param structIn Struct of indicable data.
        %> @param indices Vector (logical or ordinal) of indices to select time
        %> series data by.
        %> @retval structOut Struct with matching fields as input struct, with values taken at indices.
        %======================================================================
        
        
        
### mergedCell
        function [orderedDataCell, synthDateNum, synthDateVec] = mergedCell(startDateNum, stopDateNum, dateNumDelta, sampledDateVec,tmpDataCellOrMatrix,missingValue)
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
        %> @param tmpDataCellOrMatrix A cell or matrix of row vectors whose individual values correspond to
        %> the order of sampledDateVec.  @note tmpDataMatrix(:,x)==tempDataCell{x}       
        %> @param missingValue (Optional) Value to be used in the ordered output data
        %> cell where the tmpDataCell does not have corresponding values.
        %> The default is 'nan'.
        %> @retval orderedDataCell A cell of vectors that are taken from tmpDataCell but
        %> initially filled with the missing value parameter and ordered
        %> according to synthDateNum.
        %> @retval synthDateNum Vector of date numbers corresponding to the date vector
        %> matrix return argument.
        %> @retval synthDateVec Matrix of date vectors ([Y, Mon,Day, Hr, Mn, Sec]) generated by
        %> startDateNum:dateNumDelta:stopDateNum which correponds to the
        %> row order of orderedDataCell cell values/vectors
        %> @note This is a helper function for loading raw and count file
        %> formats to ensure proper ordering and I/O error handling.
        %======================================================================
        
        
        
### datespace      
        function [synthDateNum, synthDateVec] = datespace(startDateNum, stopDateNum, dateNumDelta)            
        % ======================================================================
        %> @brief Linearly spaced dates from start to stop dates provided.
        %> @param startDateNum The start date number that the ordered data cell should
        %> begin at.  (should be generated using datenum())
        %> @param stopDateNum The date number (generated using datenum()) that the ordered data cell
        %> ends at.
        %> @param dateNumDelta The difference between two successive date number samples.
        %> @param sampledDateVec Vector of date number values taken between startDateNum
        %> and stopDateNum (inclusive) and are in the order and size as the
        %> individual cell components of tmpDataCell
        %> @retval synthDateNum Vector of date numbers corresponding to the date vector
        %> matrix return argument.
        %> @retval synthDateVec Matrix of date vectors ([Y, Mon,Day, Hr, Mn, Sec]) generated by
        %> startDateNum:dateNumDelta:stopDateNum which correponds to the
        %> row order of orderedDataCell cell values/vectors
        %======================================================================
            
        
### structEval
        function resultStruct = structEval(operand,ltStruct,rtStruct,optionalDestFieldOrValue)
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
        %> @note PAData.structEval('overwrite',ltStruct,ltStruct,value)
        %> @note ans =
        %> @note         x: value
        %> @note     accel: [1x1 struct]
        %> @note              [x]: value
        %> @note              [y]: value
        %> @note        
        %> @note
        % ======================================================================
        
        
### structScalarEval
        function resultStruct = structScalarEval(operand,ltStruct,A,optionalDestField)
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
        
        
### appendStruct
        function ltStruct = appendStruct(ltStruct,rtStruct)
        % ======================================================================
        %> @brief Appends the fields of one to another.  Values for fields of the same name are taken from the right struct (rtStruct)
        %> and built into the output struct.  If the left struct does not
        %> have a matching field, then it will be created with the right
        %> structs value.  
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
        %> @note PAData.structEval(ltStruct,rtStruct)
        %> @note ans =
        %> @note     ydata: [1 1]
        %> @note     xdata: [1 100]
        %> @note     accel: [1x1 struct]
        %> @note            [xdata]: [1 100]
        %> @note            [x]: [10.5000 10.5000 2.5000]
        %> @note            [y]: [2 3 4]
        %> @note
        % ======================================================================
        
        
### mergeStruct
        function ltStruct = mergeStruct(ltStruct,rtStruct)
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
        %> @note            [x]: [1.0]
        %> @note            [pos]: [0.5000, 1, 0]
        %> @note
        %> @note
        %> @note PAData.structEval(rtStruct,ltStruct)
        %> @note ans =
        %> @note     accel: [1x1 struct]
        %> @note              [x]: 1.0
        %> @note              [y]: 1
        %> @note            [pos]: [0.5000, 1, 0]
        %> @note     lux: [1x1 struct]
        %> @note            [z]: 0.5000
        %> @note            [pos]: [0.5000, 1, 0]
        %> @note
        % ======================================================================
         
        
### overwriteEmptyStruct
        function ltStruct = overwriteEmptyStruct(ltStruct,rtStruct)
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
        
        
### struct2vec
        function vector = struct2vec(structure,vector)
        %======================================================================
        %> @brief flattens a structure to a single dimensional array (i.e. a
        %> vector)
        %> @param structure A struct with any number of fields.
        %> @retval vector A vector with values that are taken from the
        %> structure.
        %======================================================================
        
        
### minmax
        function structMinmax = minmax(dataStruct)
        % ======================================================================
        %> @brief Evaluates the range (min, max) of components found in the
        %> input struct argument and returns the range as struct values with
        %> matching fieldnames/organization as the input struct's highest level.
        %> @param dataStruct A structure whose fields are either structures or vectors.
        %> @retval structMinMax a struct whose fields correspond to those of
        %> the input struct and whose values are [min, max] vectors that
        %> correspond to the minimum and maximum values found in the input
        %> structure for that field.
        %> @note Consider the example
        %> @note dataStruct.accel.x = [-1 20 5 13];
        %> @note dataStruct.accel.y = [1 70 9 3];
        %> @note dataStruct.accel.z = [-10 2 5 1];
        %> @note dataStruct.lux = [0 0 0 9];
        %> @note structRange.accel is [-10 70]
        %> @note structRange.lux is [0 9]
        %======================================================================
         
        
### updateStructWithStruct
        function structToUpdate = updateStructWithStruct(structToUpdate, structToUpdateWith)
        % NA
        
### getRecurseMinmax
        function minmaxVec = getRecurseMinmax(dataStruct)
        % ======================================================================
        %> @brief Recursive helper function for minmax()
        %> input struct argument and returns the range as struct values with
        %> matching fieldnames/organization as the input struct's highest level.
        %> @param dataStruct A structure whose fields are either structures or vectors.
        %> @retval minmaxVec Nx2 vector of minmax values for the given dataStruct.
        % ======================================================================
        
        
        
### getDummyStruct
        function dat = getDummyStruct(structType)
        % ======================================================================
        %> @brief Returns an empty struct with fields that mirror PAData's
        %> time series instance variables that contain
        %> @param structType (Optional) String identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PAData's time series, feature, or aggregate bin instance variables.
        %> Time series include:
        %> - accel.(accelType).x
        %> - accel.(accelType).y
        %> - accel.(accelType).z
        %> - accel.(accelType).vecMag
        %> - steps
        %> - lux
        %> - inclinometer
        % =================================================================
        
        
### getDummyDisplayStruct
        function dat = getDummyDisplayStruct(structType)
        % ======================================================================
        %> @brief Returns a struct with subfields that hold the line properties
        %> for graphic display of the time series instance variables.
        %> @param structType (Optional) String identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) units are sample points
        %> @li @c features units are frames
        %> @li @c bins units are bins
        %> @retval dat A struct of PAData's time series instance variables, which
        %> include:
        %> - accel.(accelType).x.(xdata, ydata, color)
        %> - accel.(accelType).y.(xdata, ydata, color)
        %> - accel.(accelType).z.(xdata, ydata, color)
        %> - accel.(accelType).vecMag.(xdata, ydata, color)
        %> - inclinometer.(xdata, ydata, color)
        %> - lux.(xdata, ydata, color)
        % =================================================================
        
        
### getPrefilterMethods
        function prefilterMethods = getPrefilterMethods()
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
        
        
### getExtractorDescriptions
        function extractorDescriptions = getExtractorDescriptions()
        % --------------------------------------------------------------------
        %> @brief Returns a cell listing of available feature extraction methods as strings.
        %> @retval extractorDescriptions Cell listing with description of feature extraction methods.
        %> - @c none No feature extraction
        %> - @c rms  Root mean square
        %> - @c hash
        %> - @c sum
        %> - @c median
        %> - @c mean
        %> @note These methods can be passed as the argument to PAData's
        %> prefilter() method.
        % --------------------------------------------------------------------
        
        
### getFeatureDescriptionStruct
        function [featureStruct, varargout] = getFeatureDescriptionStruct()
        % --------------------------------------------------------------------
        %> @brief Returns a struct of feature extraction methods and string descriptions as the corresponding values.
        %> @retval featureStruct A struct of  feature extraction methods and string descriptions as the corresponding values.
        % --------------------------------------------------------------------
        
        
### getFeatureDescriptionStructWithPSDBands
        function [featureStructWithPSDBands, varargout] = getFeatureDescriptionStructWithPSDBands()
        %> @brief Returns descriptive text as key value pair for features
        %> where the feature names are the keys.
        %> @retval featureStructWithPSDBands struct with keyname to 'Value description'
        %> pairs.
        %> @retval varargout Cell with descriptive labels in the same order
        %> as they appear in argument one's keyvalue paired struct.
        
        
### getPSDFeatureDescriptionStruct
        function [psdFeatureStruct, varargout] = getPSDFeatureDescriptionStruct()
        
        
### getPSDExtractorDescriptions
        function psdExtractorDescriptions = getPSDExtractorDescriptions()
               
        
### getStructTypes
        function structType = getStructTypes()
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
        
        
### getStructNameFromDescription
        function structName = getStructNameFromDescription(description)
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
        
        
### thresholdcrossings
        function x = thresholdcrossings(line_in, threshold_line)
        %> @brief Returns start and stop pairs of the sample points where where line_in is
        %> greater (i.e. crosses) than threshold_line
        %> threshold_line and line_in must be of the same length if threshold_line is
        %> not a scalar value.
        %> @retval
        %> - Nx2 matrix of start and stop pairs of the sample points where where line_in is
        %> greater (i.e. crosses) than threshold_line
        %> - An empty matrix if no pairings are found
        %> @note Lifted from informaton/sev suite.  Authored by Hyatt Moore, IV (< June, 2013)
        
        
### merge_nearby_events
        function [merged_events, merged_indices] = merge_nearby_events(event_mat_in,min_samples)
        % ======================================================================
        %> @brief Merges events, that are separated by less than some minimum number
        %> of samples, into a single event that stretches from the start of the first event
        %> and spans until the last event of each minimally separated event
        %> pairings.  Events that are not minimally separated by another
        %> event are retained with the output.
        %> @param event_mat_in is a two column matrix
        %> @param min_samples is a scalar value
        %> @retval merged_events The output of merging event_mat's events
        %> that are separated by less than min_samples.
        %> @retval merged_indices is a logical vector of the row indices that
        %> were merged from event_mat_in. - these are the indices of the
        %> in event_mat_in that are removed/replaced
        %> @note Lifted from SEV's CLASS_events.m - authored by Hyatt Moore
        %> IV
        % =================================================================
        
        
### getStudyIDFromBasename
        function studyID = getStudyIDFromBasename(baseName)
        %> @brief Parses the input file's basename (i.e. sans folder and extension)
        %> for the study id.  This will vary according from site to site as
        %> there is little standardization for file naming.
        %> @param  File basename (i.e. sans path and file extension).
        %> @retval Study ID
         
        
### getActivityTags
        function tagStruct = getActivityTags()
        %> - @c ACTIVE = 35;
        %> - @c INACTIVE = 25;
        %> - @c NAP  = 20;
        %> - @c NREM =  15;
        %> - @c REMS = 10;
        %> - @c WEAR = 10;
        %> - @c NONWEAR = 5;
        %> - @c STUDYOVER = 0;
        %> - @c UNKNOWN = -1;
            
            
        
### getPSDBandNames
        function bandNamesAsCell = getPSDBandNames()
        % N/A



