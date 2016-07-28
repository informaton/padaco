% ======================================================================
%> @file PAData.cpp
%> @brief Accelerometer data loading class.
% ======================================================================
%> @brief The PAData class helps loads and stores accelerometer data used in the
%> physical activity monitoring project.  The project is aimed at reducing
%> obesity and improving health in children.
% ======================================================================
classdef PAData < handle
    properties(Constant)
        NUM_PSD_BANDS = 5;
    end
    properties
        %> @brief Type of acceleration stored; can be
        %> - @c raw This is not processed
        %> - @c count This is preprocessed
        %> - @c all - This is both @c raw and @c count accel fields.
        accelType;
        %> @brief Structure of count and raw accelerations structs (x,y,z).  Fields are:
        %> - @c raw Structure of raw x,y,z accelerations.  Fields are:
        %> @li x x-axis
        %> @li y y-axis
        %> @li z z-axis
        %> - @c count Structure of actigraph derived counts for x,y,z acceleration readings.  Fields are:
        %> @li x x-axis
        %> @li y y-axis
        %> @li z z-axis
        %> @li vecMag vectorMagnitude
        accel;
        
        %> @brief Structure of usage states determined from the following axes counts:
        %> @li x x-axis
        %> @li y y-axis
        %> @li z z-axis
        %> @li vecMag vectorMagnitude
        usage;
        
        %> @brief Structure of power spectral densities for count and raw accelerations structs (x,y,z).  Fields are:
        %> - @c frames PSD of the data currently in the @c @b frames member
        %> variable.
        %> - @c count Structure of actigraph derived counts for x,y,z acceleration readings.  Fields are:
        %> @li x x-axis
        %> @li y y-axis
        %> @li z z-axis
        %> @li vecMag vectorMagnitude
        %> - @c raw Structure of raw x,y,z accelerations.  Fields are:
        %> @li x x-axis
        %> @li y y-axis
        %> @li z z-axis
        psd;
        
        %> @brief Structure of inclinometer values.  Fields include:
        %> @li off
        %> @li standing
        %> @li sitting
        %> @li lying
        inclinometer;
        %> @brief Steps - unknown?  Maybe pedometer type reading?
        steps;
        % - Removed on 12/15/2014 - @brief Magnitude of tri-axis acceleration vectors.
        % vecMag;
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
        
        %> @brief Numeric values for date time sample for the start of
        %> extracted features.
        startDatenums;
        %> @brief Numeric values for date time sample for when the extracted features stop/end.
        stopDatenums;
        
        %> @brief Struct of line handle properties corresponding to the
        %> fields of linehandle.  These are derived from the input files
        %> loaded by the PAData class.
        lineproperty;
        
        label;
        color;
        offset;
        scale;
        visible;
        yDelta;
        
        %> @brief Identifier (string) for the file data that was loaded.
        %> @note See getStudyIDFromBasename()
        studyID;
        
    end
    
    properties (Access = private)
        %> @brief Pathname of file containing accelerometer data.
        pathname;
        %> @brief Name of file containing accelerometer data that is loaded.
        filename;
        
        %> Current window.  Current position in the raw data.
        %> The first window is '1' (i.e. not zero because this is MATLAB programming)
        curWindow;
        %> Number of samples contained in the data (accelRaw.x)
        durSamples;
        %> @brief Defined in the accelerometer's file output and converted to seconds.
        %> This is, most likely, the sampling rate of the output file.
        countPeriodSec;
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
        
        %> @brief Selected signal (e.g. count vector magnitude) at frame rate.
        frames;
        
        %> @brief The label or tag line of the signal from which frames was
        %> populated with.  (i.e. the original data that was framed and
        %> placed in the member variable @c frames
        frames_signalTagLine;
        
        %> @brief Mode of usage state vector (i.e. taken from getUsageActivity) for current frame rate.
        usageFrames;
        
        
        %> @brief Struct of rules for classifying usage state.
        %> See getDefaultParameters for initial values.
        usageStateRules;        
        
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
        %> @param fullFilenameOrPath Either
        %> - (1) the full filename (i.e. with pathname) of accelerometer data to load.
        %> - or (2) the path that contains raw accelerometer data stored in
        %> binary file(s) - Firmware versions 2.5 or 3.1 only.
        %> @param pStruct Optional struct of parameters to use.  If it is not
        %> included then parameters from getDefaultParameters method are used.
        %> @retval Instance of PAData.
        % fullFile = '~/Google Drive/work/Stanford - Pediatrics/sampledata/female child 1 second epoch.csv'
        % =================================================================
        function obj = PAData(fullFilenameOrPath,pStruct)
            obj.pathname =[];
            obj.filename = [];
            
            if(nargin<2 || isempty(pStruct))
                pStruct = obj.getDefaultParameters();
            end
            
            obj.accelType = [];
            obj.startDatenums = [];
            
            obj.durationSec = 0;  %ensures we get valid, non-empty values from  getWindowCount() when we do not have any data loaded.
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
            
            obj.curWindow = 1;  %don't use current window until after a file has been loaded.
            
            obj.numBins = 0;
            obj.bins = [];
            obj.numFrames = 0;
            obj.features = [];
            
            % Removed in place of getSampleRate()
            %            obj.sampleRate.accelRaw = 40;
            %            obj.sampleRate.inclinometer = 40;
            %            obj.sampleRate.lux = 40;
            %            obj.sampleRate.vecMag = 40;
            
            
            if(isdir(fullFilenameOrPath))
                obj.pathname = fullFilenameOrPath;
                obj.loadPathOfRawBinary(obj.pathname);
                
            elseif(exist(fullFilenameOrPath,'file'))
                [p,name,ext] = fileparts(fullFilenameOrPath);
                if(isempty(p))
                    obj.pathname = pwd;
                else
                    obj.pathname = p;
                end
                obj.filename = strcat(name,ext);
                obj.loadFile();
            end
            
            obj.setCurWindow(pStruct.curWindow);
        end
        
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
        %> durationSamples().
        %> @note This uses instance variables windowDurSec, curWindow, and sampleRate to
        %> determine the sample range for the current window.
        % =================================================================
        function correctedWindowRange = getCurWindowRange(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
            end
            
            correctedWindowRange = obj.getCurUncorrectedWindowRange(structType);
            
            switch structType
                case 'timeSeries'
                    maxValue = obj.durationSamples();
                case 'bins'
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
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval A 2x1 vector with start, stop range of the current window returned as
        %> samples beginning with 1 for the first sample.
        %> @note This uses instance variables windowDurSec, curWindow, and sampleRate to
        %> determine the sample range for the current window.  The first
        %> value is floored and the second is ceil'ed.
        % =================================================================
        function windowRange = getCurUncorrectedWindowRange(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
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
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval Number of samples, frames, or bins per window display;
        %not necessarily an integer result; can be a fraction.
        %> @note Calcuation based on instance variables windowDurSec and
        %> sampleRate
        function windowDur = getSamplesPerWindow(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
            end
            windowDur = obj.windowDurSec*obj.getWindowSamplerate(structType);
        end
        
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
        function windowRate = getWindowSamplerate(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
            end
            
            switch structType
                case 'timeSeries'
                    windowRate = obj.getSampleRate();
                case 'bins'
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
        
        
        function usageRules = getUsageClassificationRules(this)
            usageRules = this.usageStateRules();
        end
        
        %> @brief Updates the usage state rules with an input struct.  
        %> @param
        %> @param
        function didSet = setUsageClassificationRules(this, ruleStruct)
            didSet = false;
            try
                if(isstruct(ruleStruct))
                    this.usageStateRules = this.updateStructWithStruct(this.usageStateRules, ruleStruct);
                    didSet = true;
                end
            catch me
                showME(me);
                didSet = false;
            end            
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
            if(aggregateDurationMin>0 && aggregateDurationMin<=obj.getFrameDurationInMinutes())
                obj.aggregateDurMin = aggregateDurationMin;
            end
            %returns the current frame duration, whether it be 'frameDurationMin' or not.
            aggregateDurationMin = obj.getAggregateDurationInMinutes();
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the current aggregate duration in minutes.
        %> @param obj Instance of PAData
        %> @retval aggregateDuration The current window;
        % --------------------------------------------------------------------
        function aggregateDuration = getAggregateDurationInMinutes(obj)
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
            binCount = floor(obj.durationSec/60/obj.getAggregateDurationInMinutes());
        end
        
        %> @brief Returns studyID instance variable.
        %> @param Instance of PAData
        %> @param Optional output format for the study id.  Can be
        %> - 'string'
        %> - 'numeric'
        %> @retval Study ID that identifies the data (i.e. what or who it is
        %> attributed to).
        function studyID = getStudyID(obj,outputType)
            studyID = obj.studyID;
            if(~isempty(studyID) && nargin>1)
                if(strcmpi(outputType,'string') && isnumeric(studyID))
                    studyID = num2str(studyID);
                elseif(strcmpi(outputType,'numeric') && ischar(studyID))
                    studyID = str2double(studyID);
                else
                    fprintf(1,'Warning:  Unknown outut format passed to getStudyID()\n');
                end
            end
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
            if(frameDurationMin>=0 && frameDurationMin<=obj.durationSec/60 && (frameDurationMin>0 || obj.frameDurHour>0)) % Make sure we have non-zero duration frames
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
            if(frameDurationHours>=0 && frameDurationHours<=obj.durationSec/60/60 && (frameDurationHours>0 || obj.frameDurMin>0))  % Make sure we have non-zero duration frames
                obj.frameDurHour = frameDurationHours;
            end
            %returns the current frame duration, whether it be 'frameDurationMin' or not.
            [~,frameDurationHours] = obj.getFrameDuration();
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the frame duration (in hours and minutes)
        %> @param obj Instance of PAData
        %> @retval curFrameDurationMin The current frame duration minutes field;
        %> @retval curFramDurationHour The current frame duration hours field;
        % --------------------------------------------------------------------
        function [curFrameDurationMin, curFrameDurationHour] = getFrameDuration(obj)
            curFrameDurationMin = obj.frameDurMin;
            curFrameDurationHour = obj.frameDurHour;
        end
        
        function frameDurationMin = getFrameDurationInMinutes(obj)
            [curFrameDurationMin, curFrameDurationHour] = obj.getFrameDuration();
            frameDurationMin = curFrameDurationMin+curFrameDurationHour*60;
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
        %> @brief Returns the number of samples contained in the time series data.
        %> @param obj Instance of PAData
        %> @retval durationSamp Number of elements contained in durSamples instance var
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
        %> @brief Returns the visible instance variable
        %> @param obj Instance of PAData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this is not)
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval visibileStruct A struct of obj's visible field values
        % --------------------------------------------------------------------
        function visibleStruct = getVisible(obj,structType)
            if(nargin<2)
                structType = [];
            end
            visibleStruct = obj.getPropertyStruct('visible',structType);
        end
        
        
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
        function colorStruct = getColor(obj,structType)
            if(nargin<2)
                structType = [];
            end
            
            colorStruct = obj.getPropertyStruct('color',structType);
        end
        
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
        function scaleStruct = getScale(obj,structType)
            if(nargin<2)
                structType = [];
            end
            scaleStruct = obj.getPropertyStruct('scale',structType);
        end
        
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
        function offsetStruct = getOffset(obj,structType)
            if(nargin<2)
                structType = [];
            end
            offsetStruct = obj.getPropertyStruct('offset',structType);
        end
        
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
        function labelStruct = getLabel(obj,structType)
            
            if(nargin<2)
                structType = [];
            end
            
            labelStruct = obj.getPropertyStruct('label',structType);
        end
        
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
        function offAccelType = getOffAccelType(obj,accelTypeStr)
            if(nargin<2 || isempty(accelTypeStr))
                accelTypeStr = obj.accelType;
            end
            if(strcmpi(accelTypeStr,'count'))
                offAccelType = 'raw';
            elseif(strcmpi(accelTypeStr,'raw'))
                offAccelType = 'count';
            elseif(strcmpi(accelTypeStr,'all'))
                offAccelType = [];
            else
                fprintf('Unrecognized accelTypeStr (%s)\n',accelTypeStr);
                offAccelType = [];
            end
        end
        
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
        function propertyStruct = getPropertyStruct(obj,propertyName,structType)
            if(nargin<3 || isempty(structType))
                propertyStruct = obj.(propertyName);
            else
                
                propertyStruct = obj.(propertyName).(structType);
                
            end
        end
        
        function prunedStruct = pruneStruct(obj,accelStruct)
            % curtail unwanted acceleration type.
            prunedStruct = accelStruct;
            if(isfield(accelStruct,'accel'))
                offAccelType = obj.getOffAccelType();
                if(isfield(accelStruct.accel,offAccelType))
                    prunedStruct.accel = rmfield(accelStruct.accel,offAccelType);
                end
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
            eval(['obj.offset.',fieldName,' = ',num2str(newOffset),';']);
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
            eval(['obj.scale.',fieldName,' = ',num2str(newScale),';']);
            if(nargout>0)
                varargout = cell(1,nargout);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets the color instance variable for a particular sub
        %> field.
        %> @param obj Instance of PAData
        %> @param fieldName Dynamic field name to set in the 'color' struct.
        %> @note For example if fieldName = 'timeSeries.accel.vecMag' then
        %> obj.color.timeSerie.accel.vecMag = newColor; is evaluated.
        %> @param newColor 1x3 vector to set obj.color.(fieldName) to.
        % --------------------------------------------------------------------
        function varargout = setColor(obj,fieldName,newColor)
            eval(['obj.color.',fieldName,'.color = [',num2str(newColor),']',';']);
            if(nargout>0)
                varargout = cell(1,nargout);
            end
        end
        
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
        function varargout = setVisible(obj,fieldName,newVisibilityStr)
            if(strcmpi(newVisibilityStr,'on')||strcmpi(newVisibilityStr,'off'))
                eval(['obj.visible.',fieldName,'.visible = ''',newVisibilityStr,''';']);
            else
                fprintf('An invaled argument was passed for the visibility (i.e. visible) parameter.  (%s)\n',newVisibilityStr);
            end
            if(nargout>0)
                varargout = cell(1,nargout);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets the specified instance variable for a particular sub
        %> field.
        %> @param obj Instance of PAData
        %> @param propertyName instance variable to set the property of.
        %> @param fieldName Dynamic field name to set in the propertyName struct.
        %> @param propertyValueStr String value of property to set fieldName
        %> to.
        % --------------------------------------------------------------------
        function varargout = setProperty(obj,propertyName,fieldName,propertyValueStr)
            eval(['obj.',propertyName,'.',fieldName,'.propertyName = ',propertyValueStr,';']);
            if(nargout>0)
                varargout = cell(1,nargout);
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
        function success = setFullFilename(obj,fullfilename)
            if(exist(fullfilename,'file'))
                [obj.pathname, basename,ext] = fileparts(fullfilename);
                obj.filename = strcat(basename,ext);
                success = true;
            else
                success = false;
            end
            
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
                        obj.countPeriodSec = [3600 60 1]* a;
                    else
                        % unset - we don't know - assume 1 per second
                        obj.countPeriodSec = 1;
                        obj.startTime = 'N/A';
                        obj.startDate = 'N/A';
                        fprintf(' File does not include header.  Default values set for start date and countPeriodSec (1).\n');
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
            %            windowPeriod = datestr(datenum([0 0 0 0 0 obj.countPeriodSec]),'HH:MM:SS');
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
        function didLoad = loadFile(obj,fullfilename)
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
                [pathName, baseName, ext] = fileparts(fullfilename);
                obj.studyID = obj.getStudyIDFromBasename(baseName);
                
                if(strcmpi(ext,'.gt3x'))
                    didLoad = obj.loadGT3XFile(fullfilename);
                else
                    %Always load the count data first, just because it holds the
                    %lux and such
                    fullCountFilename = fullfile(pathName,strcat(baseName,'.csv'));
                    
                    if(exist(fullCountFilename,'file'))
                        
                        obj.loadCountFile(fullCountFilename);
                        
                        obj.accelType = 'count'; % this is modified, below, to 'all' if a
                        % a raw acceleration file (.csv or
                        % .bin) is being loaded, in which
                        % case the count data is replaced
                        % with the raw data.
                        obj.classifyUsageForAllAxes();
                    end
                    
                    % For .raw files, load the count data first so that it can
                    % then be reshaped by the sampling rate found in .raw
                    if(strcmpi(ext,'.raw'))
                        tic
                        didLoad = obj.loadRawCSVFile(fullfilename);
                        toc
                        obj.accelType = 'all';
                    elseif(strcmpi(ext,'.bin'))
                        %determine firmware version
                        %                        infoFile = fullfile(pathName,strcat(baseName,'.info.txt'));
                        infoFile = fullfile(pathName,'info.txt');
                        
                        %load meta data from info.txt
                        [infoStruct, firmwareVersion] = obj.parseInfoTxt(infoFile);
                        
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        % Ensure firmware version is either 2.2.1, 2.5.0 or 3.1.0
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        if(strcmp(firmwareVersion,'2.5.0')||strcmp(firmwareVersion,'3.1.0') || strcmp(firmwareVersion,'2.2.1') || strcmp(firmwareVersion,'1.5.0'))
                            obj.setFullFilename(fullfilename);
                            obj.sampleRate = str2double(infoStruct.Sample_Rate);
                            
                            obj.accelType = 'all';
                            
                            didLoad = true;  % will be changed to false if none of the strcmp find a match
                            % Version 2.5.0 firmware
                            if(strcmp(firmwareVersion,'2.5.0'))
                                
                                unitsTimePerDay = 24*3600*10^7;
                                matlabDateTimeOffset = 365+1+1;  %367, 365 days for the first year + 1 day for the first month + 1 day for the first day of the month
                                %start, stop and delta date nums
                                binStartDatenum = str2double(infoStruct.Start_Date)/unitsTimePerDay+matlabDateTimeOffset;
                                
                                if(~isempty(obj.startDate))
                                    countStartDatenum = datenum(strcat(obj.startDate,{' '},obj.startTime),'mm/dd/yyyy HH:MM:SS');
                                
                                    if(binStartDatenum~=countStartDatenum)
                                        fprintf('There is a discrepancy between the start date-time in the count file and the binary file.  I''m not sure what is going to happen because of this.\n');
                                    end
                                else
                                    
                                end
                                    
                                
                                obj.loadRawActivityBinFile(fullfilename,firmwareVersion);
                                
                                obj.durationSec = floor(obj.durationSamples()/obj.sampleRate);
                                
                                binDatenumDelta = datenum([0,0,0,0,0,1/obj.sampleRate]);
                                binStopDatenum = datenum(binDatenumDelta*obj.durSamples)+binStartDatenum;
                                synthDateVec = datevec(binStartDatenum:binDatenumDelta:binStopDatenum);
                                synthDateVec(:,6) = round(synthDateVec(:,6)*1000)/1000;
                                
                                %This takes 2.0 seconds!
                                obj.dateTimeNum = datenum(synthDateVec);
                                
                                % Version 3.1.0 firmware                                % Version 2.2.1 firmware
                                
                            elseif(strcmp(firmwareVersion,'3.1.0') || strcmp(firmwareVersion,'2.2.1') || strcmp(firmwareVersion,'1.5.0'))
                                obj.loadRawActivityBinFile(fullfilename,firmwareVersion);
                            else
                                didLoad = false;
                            end
                            
                        else
                            % for future firmware version loaders
                            % Not 2.2.1, 2.5.0 or 3.1.0 - skip - cannot handle right now.
                            fprintf(1,'Firmware version (%s) either not found or unrecognized in %s.\n',firmwareVersion,infoFile);
                            
                        end
                        
                    else  % if it was not .bin or .raw
                        obj.accelType = 'count';
                    end
                end
            else
                didLoad = false;
            end
        end
        
        % ======================================================================
        %> @brief Loads an accelerometer "count" data file.
        %> @param obj Instance of PAData.
        %> @param fullCountFilename The full (i.e. with path) filename to load.
        % =================================================================
        function didLoad = loadCountFile(obj,fullCountFilename)
            
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
                        
                        windowDateNumDelta = datenum([0,0,0,0,0,obj.countPeriodSec]);
                        
                        missingValue = nan;
                        
                        % NOTE:  Chopping off the first six columns: date time values;
                        tmpDataCell(1:6) = [];
                        
                        % The following call to mergedCell ensures the data
                        % is chronologically ordered and data is not
                        % missing.
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
                        
                        obj.accel.count.x = dataCell{1};
                        obj.accel.count.y = dataCell{2};
                        obj.accel.count.z = dataCell{3};
                        
                        obj.steps = dataCell{4}; %what are steps?
                        obj.lux = dataCell{5}; %0 to 612 - a measure of lumins...
                        obj.inclinometer.standing = dataCell{7};
                        obj.inclinometer.sitting = dataCell{8};
                        obj.inclinometer.lying = dataCell{9};
                        obj.inclinometer.off = dataCell{6};
                        
                        %                        inclinometerMat = cell2mat(dataCell(6:9));
                        %                        unique(inclinometerMat,'rows');
                        obj.accel.count.vecMag = dataCell{10};
                        
                        %either use countPeriodSec or use samplerate.
                        if(obj.countPeriodSec>0)
                            obj.sampleRate = 1/obj.countPeriodSec;
                            obj.durationSec = floor(obj.durationSamples()*obj.countPeriodSec);
                        else
                            fprintf('There was an error when loading the window period second value (non-positive value found in %s).\n',fullCountFilename);
                            obj.durationSec = 0;
                        end
                        fclose(fid);
                        didLoad = true;
                    catch me
                        showME(me);
                        fclose(fid);
                        didLoad = false;
                    end
                else
                    fprintf('Warning - could not open %s for reading!\n',fullCountFilename);
                    didLoad = false;
                end
            else
                fprintf('Warning - %s does not exist!\n',fullCountFilename);
                didLoad = false;
            end
        end
        
        
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
        function didLoad = loadRawCSVFile(obj,fullRawCSVFilename)
            if(exist(fullRawCSVFilename,'file'))
                
                fid = fopen(fullRawCSVFilename,'r');
                if(fid>0)
                    try
                        delimiter = ',';
                        % header = 'Date	 Time	 Axis1	Axis2	Axis3
                        headerLines = 11; %number of lines to skip
                        %                        scanFormat = '%s %f32 %f32 %f32'; %load as a 'single' (not double) floating-point number
                        scanFormat = '%f/%f/%f %f:%f:%f %f32 %f32 %f32';
                        tic
                        tmpDataCell = textscan(fid,scanFormat,'delimiter',delimiter,'headerlines',headerLines);
                        toc
                        
                        %                        scanFormat = '%2d/%2d/%4d %2d:%2d:%f,%f32,%f32,%f32';
                        %                        frewind(fid);
                        %                        for f=1:headerLines
                        %                            fgetl(fid);
                        %                        end
                        %
                        %                        %This takes 46 seconds; //or 24 seconds or 4.547292
                        %                        %or 8.8 ...
                        %                        %seconds. or 219.960772 seconds (what is going on
                        %                        %here?)
                        %                        tic
                        %                        A  = fread(fid,'*char');
                        %                        toc
                        %                        tic
                        %                        tmpDataCell = textscan(A,scanFormat);
                        %                        toc
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
                            fprintf('%d rows loaded from %s\n',samplesFound,fullRawCSVFilename);
                        else
                            
                            if(numMissing>0)
                                fprintf('%d rows loaded from %s.  However %u rows were expected.  %u missing samples are being filled in as %s.\n',samplesFound,fullCountFilename,numMissing,num2str(missingValue));
                            else
                                fprintf('This case is not handled yet.\n');
                                fprintf('%d rows loaded from %s.  However %u rows were expected.  %u missing samples are being filled in as %s.\n',samplesFound,fullCountFilename,numMissing,num2str(missingValue));
                            end
                        end
                        
                        obj.accel.raw.x = dataCell{1};
                        obj.accel.raw.y = dataCell{2};
                        obj.accel.raw.z = dataCell{3};
                        
                        fclose(fid);
                        
                        obj.resampleCountData();
                        didLoad = true;
                        
                    catch me
                        showME(me);
                        fclose(fid);
                        didLoad = false;
                    end
                else
                    fprintf('Warning - could not open %s for reading!\n',fullRawCSVFilename);
                    didLoad = false;
                end
            else
                fprintf('Warning - %s does not exist!\n',fullRawCSVFilename);
                didLoad = false;
            end
        end
        
        
        
        % ======================================================================
        %> @brief Loads an accelerometer's raw data from binary files stored
        %> in the path name given.
        %> @param obj Instance of PAData.
        %> @param pathWithRawBinaryFiles Name of the path (a string) that
        %> contains raw acceleromater data stored in one or more binary files.
        %> @note Currently, only two firmware versions are supported:
        %> - 2.5.0
        %> - 3.1.0
        function didLoad = loadGT3XFile(obj, fullFilename)
            
            if(exist(fullFilename,'file'))
                [pathName, baseName, ext] = fileparts(fullFilename);
                tmpDir = fullfile(pathName,baseName);
                if(~strcmpi(ext,'.gt3x'))
                    fprintf('Warning: Expecting the extension ''.gt3x'', but found ''%s'' instead\n',ext);
                end
                if(exist(tmpDir,'dir'))
                    SUCCESS =  true;
                else
                    [SUCCESS,MESSAGE,~] = mkdir(tmpDir);
                end
                
                if(~SUCCESS)
                    fprintf('Unable to make a temporary folder (%s) to extract the file %s.%s\n.  The following error was generated by the O/S:\t%s\n',tmpDir, baseName, ext,MESSAGE);
                    didLoad = false;
                else
                    unzip(fullFilename, tmpDir);
                    didLoad = obj.loadPathOfRawBinary(tmpDir);
                end
            else
                didLoad = false;
            end
        end
        
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
        function didLoad = loadPathOfRawBinary(obj, pathWithRawBinaryFiles)
            infoFile = fullfile(pathWithRawBinaryFiles,'info.txt');
            
            %load meta data from info.txt
            [infoStruct, firmwareVersion] = obj.parseInfoTxt(infoFile);
            
            % Determine the specification
            
            % It is either 2.5.0 or 3.1.0
            if(strcmp(firmwareVersion,'2.5.0') || strcmp(firmwareVersion,'3.1.0')|| strcmp(firmwareVersion,'1.5.0'))
                if(strcmp(firmwareVersion,'2.5.0'))
                    fullBinFilename = fullfile(pathWithRawBinaryFiles,'activity.bin');
                elseif(strcmp(firmwareVersion,'3.1.0') || strcmp(firmwareVersion,'1.5.0') )
                    fullBinFilename = fullfile(pathWithRawBinaryFiles,'log.bin');
                else
                    % for future firmware version loaders
                    warndlg(sprintf('Attempting to load data from untested firmware version (%s)',firmwareVersion));
                    fullBinFilename = fullfile(pathWithRawBinaryFiles,'log.bin');
                end
                obj.setFullFilename(fullBinFilename);
                didLoad = obj.loadFile(fullBinFilename);
            else
                % Not 2.5.0 or 3.1.0 - skip - cannot handle right now.
                fprintf(1,'Firmware version (%s) either not found or unrecognized in %s.\n',firmwareVersion,infoFile);
                didLoad = false;
            end
        end
        
        
        
        % ======================================================================
        %> @brief Resamples previously loaded 'count' data to match sample rate of
        %> raw accelerometer data that has been loaded in a following step (see loadFile()).
        %> @param obj Instance of PAData.       %
        %> @note countPeriodSec, sampleRate, steps, lux, and accel values
        %> must be set in advance of this call.
        % ======================================================================
        function resampleCountData(obj)
            
            N = obj.countPeriodSec*obj.sampleRate;
            
            obj.accel.count.x = reshape(repmat(obj.accel.count.x(:),1,N)',[],1);
            obj.accel.count.y = reshape(repmat(obj.accel.count.y(:),1,N)',[],1);
            obj.accel.count.z = reshape(repmat(obj.accel.count.z(:),1,N)',[],1);
            obj.accel.count.vecMag = reshape(repmat(obj.accel.count.vecMag(:),1,N)',[],1);
            
            obj.steps = reshape(repmat(obj.steps(:),1,N)',[],1);
            obj.lux = reshape(repmat(obj.lux(:),1,N)',[],1);
            
            obj.inclinometer.standing = reshape(repmat(obj.inclinometer.standing(:)',N,1),[],1);
            obj.inclinometer.sitting = reshape(repmat(obj.inclinometer.sitting(:)',N,1),[],1);
            obj.inclinometer.lying = reshape(repmat(obj.inclinometer.lying(:)',N,1),[],1);
            obj.inclinometer.off = reshape(repmat(obj.inclinometer.off(:)',N,1),[],1);
            
            % obj.vecMag = reshape(repmat(obj.vecMag(:)',N,1),[],1);
            % derive vecMag from x, y, z axes directly...
            obj.accel.raw.vecMag = sqrt(obj.accel.raw.x.^2+obj.accel.raw.y.^2+obj.accel.raw.z.^2);
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
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval window The window.
        % ======================================================================
        function window = datenum2window(obj,datenumSample,structType)
            if(nargin<3 || isempty(structType))
                structType = 'timeSeries';
            end
            
            startstopDatenum = obj.getStartStopDatenum();
            elapsed_time = datenumSample - startstopDatenum(1);
            [y,m,d,h,mi,s] = datevec(elapsed_time);
            elapsedSec = [d, h, mi, s] * [24*60; 60; 1;1/60]*60;
            %            windowSamplerate = obj.getWindowSamplerate(structType);
            window = ceil(elapsedSec/obj.windowDurSec);
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
        
        
        
        % ======================================================================
        %> @brief Prefilters accelerometer data.
        %> @note Not currently implemented.
        %> @param obj Instance of PAData.
        %> @param method String name of the prefilter method.
        % ======================================================================
        function obj = prefilter(obj,method)
            fprintf('Prefiltering is not currently implemented\n');
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
        
        function frameableSamples = getFrameableSampleCount(obj)
            [frameDurMinutes, frameDurHours ] = obj.getFrameDuration();
            frameDurSeconds = frameDurMinutes*60+frameDurHours*60*60;
            frameCount = obj.getFrameCount();
            frameableSamples = frameCount*frameDurSeconds*obj.getSampleRate();
        end
        
        % ======================================================================
        %> @brief Extracts features from the identified signal
        %> @param obj Instance of PAData.
        %> @param signalTagLine Tag identifying the signal to extract
        %> features from.  Default is 'accel.count.vecMag'
        %> @param method String name of the extraction method.  Possible
        %> values include:
        %> - c none
        %> - c all
        %> - c rms
        %> - c median
        %> - c mean
        %> - c sum
        %> - c var
        %> - c std
        %> - c mode
        %> - c usagestate
        %> - c psd
        % ======================================================================
        function obj = extractFeature(obj,signalTagLine,method)
            if(nargin<3 || isempty(method))
                method = 'all';
                if(nargin<2 || isempty(signalTagLine))
                    signalTagLine = 'accel.count.vecMag';
                end
            end
            
            try
                data = obj.getStruct('all');
                data = eval(['data.',signalTagLine]);
                tagParts = strsplit(signalTagLine,'.');  %break it up and give me the 'vecMag' in the default case.
                axisName = tagParts{end};
                usageVec = obj.usage.(axisName);
            catch me                
                rethrow(me);  %this is just for debugging.
            end
            
            currentNumFrames = obj.getFrameCount();
            frameableSamples = obj.getFrameableSampleCount();
            
            % recalculate based on a change in frame size ...
            if(currentNumFrames~=obj.numFrames)
                obj.numFrames =currentNumFrames;
                
                numColumns = frameableSamples/obj.numFrames;  % This could go replace the '[]' in the reshape() methods below
                
                
                obj.features = [];
                dateNumIndices = 1:numColumns:frameableSamples;
                
                %take the first part
                obj.startDatenums = obj.dateTimeNum(dateNumIndices(1:end));
                
                %% This was another approach for calculating start and stop datenums,
                % but unfortunately it had complications when calculating
                % the total sample size and such...
                
                % dateNumIndices = 1:size(obj.frames,1):frameableSamples+size(obj.frames,1);
                % obj.startDatenums = obj.dateTimeNum(dateNumIndices(1:end-1));
                
                %obj.stopDatenums = obj.dateTimeNum(dateNumIndices(2:end)-1); %do it this way to have starts and stops different.
                
                % or equivalently :
                % obj.startDatenums = obj.dateTimeNum(1:size(obj.frames,1):frameableSamples);
                % obj.stopDatenums = obj.dateTimeNum(size(obj.frames,1):size(obj.frames,1):frameableSamples+size(obj.frames,1));
                
            else
                % otherwise just use the original
            end
            
            
            obj.usageFrames =  reshape(usageVec(1:frameableSamples),[],obj.numFrames);  %each frame consists of a column of data.  Consecutive columns represent consecutive frames.
                
            
            obj.frames =  reshape(data(1:frameableSamples),[],obj.numFrames);  %each frame consists of a column of data.  Consecutive columns represent consecutive frames.
            % Frames are stored in consecutive columns.  Thus the rows
            % represent the consecutive samples of data for that frame
            % Feature functions operate along columns (i.e. down the rows) and the output is then
            % transposed to produce a final, feature vector (1 row)
            data = obj.frames;
            obj.frames_signalTagLine = signalTagLine;
            
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
                    obj.features.usagestate = mode(obj.usageFrames)';
                    obj.calculatePSD(signalTagLine);
                    %                    obj.features.count = obj.getCount(data)';
                    
                case 'rms'
                    obj.features.rms = sqrt(mean(data.^2))';
                case 'median'
                    obj.features.median = median(data)';
                case 'mean'
                    obj.features.mean = mean(data)';
                case 'sum'
                    obj.features.sum = sum(data)';
                case 'var'
                    obj.features.var = var(data)';
                case 'std'
                    obj.features.std = std(data)';
                case 'mode'
                    obj.features.mode = mode(data)';
                case 'usagestate'
                    obj.features.usagestate = mode(obj.usageFrames)';
                case 'psd'
                    obj.calculatePSD(signalTagLine);        
                otherwise
                    fprintf(1,'Unknown method (%s)\n',method);
            end
        end
        
        %> @brief Calculates the PSD for the current frames and assigns the
        %> result to obj.psd.frames.  Will also assign
        %> obj.frames_signalTagLine to the signalTagLine argument when
        %> provided, otherwise the current value for
        %> obj.frames_signalTagLine is assumed to be correct and specific for
        %> the source of the frame data.  PSD bands are assigned to their
        %> named fields (e.g. psd_band_1) in the obj.features.(bandName)
        %> field.  
        function obj = calculatePSD(obj,signalTagLine)
            % psd_bands is NxM matrix of M PSD for N epochs (calculated
            % spectrums)
            if(nargin<2)
                signalTagLine = obj.frames_signalTagLine;
            else
                obj.frames_signalTagLine = signalTagLine;
            end
                
            [psd_bands, obj.psd.frames] = obj.getPSDBands();
            eval(['obj.psd.',signalTagLine, '= obj.psd.frames;']);
            psd_bandNames = obj.getPSDBandNames();            
            for p=1:numel(psd_bandNames)
                bandName = psd_bandNames{p};
                obj.features.(bandName) = psd_bands(:,p);
            end
        end
        
        function dataPSD = getPSD(obj)
            %            [r,c] = size(obj.frames);  %c = num frames, r =
            %            samples per frame
            data = obj.frames(:);   %get frame data column wise (i.e. convert it back to data that we can get PSD from
            [psdSettings, Fs] = obj.getPSDSettings();
            
            % Result is num frames X num fft samples.
            dataPSD = featureFcn.getpsd(data,Fs,psdSettings);
        end
        
        function [psdBands, psdAll] = getPSDBands(obj, numBands)
            % Result is num frames X num fft samples.
            psdAll = obj.getPSD();
            [nFrames, nFFT] = size(psdAll);
            if(nargin<2 || isempty(numBands))
                numBands = obj.NUM_PSD_BANDS;
            end
            % bin out our bands...
            psdBands = nan(nFrames,numBands);
            bandInd = floor(linspace(0, nFFT,numBands+1));
            for b=1:numel(bandInd)-1
                psdBands(:,b) = sum(psdAll(:,bandInd(b)+1:bandInd(b+1)),2);  % ,2 to sum across columns (each row will contain the sum of the columns)
            end

        end
        
        function [psdSettings, Fs] = getPSDSettings(obj)
            psdSettings.FFT_window_sec = obj.getFrameDurationInMinutes()*60;
            psdSettings.interval = psdSettings.FFT_window_sec;
            psdSettings.wintype = 'hann';
            psdSettings.removemean =true;
            Fs = obj.getSampleRate();
        end
        
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
        function [alignedFeatureVecs, alignedStartDateVecs] = getAlignedFeatureVecs(obj,featureFcn,signalTagLine,elapsedStartHour, intervalDurationHours)
            %featureVec = getStruct('featureFcn',signalTagLine);
            
            featureStruct = obj.getStruct('all','features');
            alignedFeatureVecs = [];
            if(isempty(featureStruct) || ~isfield(featureStruct,featureFcn) || isempty(featureStruct.(featureFcn)))
                obj.extractFeature(signalTagLine,featureFcn);
                featureStruct = obj.getStruct('all','features');
            end
            if(isempty(featureStruct) || ~isfield(featureStruct,featureFcn) || isempty(featureStruct.(featureFcn)))
                fprintf('There was an error.  Could not extract features!\n');
            else
                featureVec = featureStruct.(featureFcn);
                
                % get frame duration
                frameDurationVec = [0 0 0 obj.frameDurHour obj.frameDurMin 0];
                
                % find the first Start Time
                startDateVecs = datevec(obj.startDatenums);
                elapsedStartHours = startDateVecs*[0; 0; 0; 1; 1/60; 1/3600];
                startIndex = find(elapsedStartHours==elapsedStartHour,1,'first');
                
                startDateVec = startDateVecs(startIndex,:);
                stopDateVecs = startDateVecs+repmat(frameDurationVec,size(startDateVecs,1),1);
                lastStopDateVec = stopDateVecs(end,:);
                
                % A convoluted processes - need to convert datevecs back to
                % datenum to handle switching across months.
                remainingDurationHours = datevec(datenum(lastStopDateVec)-datenum(startDateVec))*[0; 0; 24; 1; 1/60; 1/3600];
                
                numIntervals = floor(remainingDurationHours/intervalDurationHours);
                
                intervalStartDateVecs = repmat(startDateVec,numIntervals,1)+(0:numIntervals-1)'*[0, 0, 0, intervalDurationHours, 0, 0];
                alignedStartDateVecs = intervalStartDateVecs;
                durationDateVec = [0 0 0 numIntervals*intervalDurationHours 0 0];
                stopIndex = find(datenum(stopDateVecs)==datenum(startDateVec+durationDateVec),1,'first');
                
                % reshape the result and return as alignedFeatureVec
                
                clippedFeatureVecs = featureVec(startIndex:stopIndex);
                alignedFeatureVecs = reshape(clippedFeatureVecs,[],numIntervals)';
            end
            
        end
        
        % ======================================================================
        %> @brief Classifies the usage state for each axis using count data from
        %> each axis.
        %> @param obj Instance of PAData.
        %> @retval didClassify True/False depending on success.
        % ======================================================================        
        function didClassify = classifyUsageForAllAxes(obj)
            try
                countStruct = obj.getStruct('all');
                countStruct = countStruct.accel.count;
                axesNames = fieldnames(countStruct);
                for a=1:numel(axesNames)
                    axesName=axesNames{a};
                    obj.usage.(axesName) = obj.classifyUsageState(countStruct.(axesName));
                end
                didClassify=true;
            catch me
                showME(me);
                didClassify=false;
            end
        end
        
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
        %> @retval usageState A three column matrix identifying usage state
        %> and duration.  Column 1 is the usage state, column 2 and column 3 are
        %> the states start and stop times (datenums).
        %> @note Usage states are categorized as follows:
        %> - c -1 Nonwear
        %> - c 0 Sleep - 0.25 rem, 0.75 nonrem
        %> - c 1 Wake - inactive
        %> - c 1 Wake - wake
        %> @retval startStopDatenums Start and stop datenums for each usage
        %> state row entry of usageState.
        % ======================================================================
        function [usageVec, usageState, startStopDateNums] = classifyUsageState(obj, countActivity)
            
            % By default activity determined from vector magnitude signal
            if(nargin<2 || isempty(countActivity))
                countActivity = obj.accel.count.vecMag;
            end
            
            UNKNOWN = -1;
            NONWEAR = 5;
            WEAR = 10;
            %            STUDYOVER=0;
            %            REMS = 10;
            %            NREMS = 15;
            %            NAPPING = 20;
            %            INACTIVE = 25;
            %            ACTIVE = 30;
            
            longClassificationMinimumDurationOfMinutes = obj.usageStateRules.longClassificationMinimumDurationOfMinutes; %15; %a 15 minute or 1/4 hour filter
            shortClassificationMinimumDurationOfMinutes = obj.usageStateRules.shortClassificationMinimumDurationOfMinutes; %5; %a 5 minute or 1/12 hour filter
            
            awakeVsAsleepCountsPerSecondCutoff = obj.usageStateRules.awakeVsAsleepCountsPerSecondCutoff;  %1;  % exceeding the cutoff means you are awake
            activeVsInactiveCountsPerSecondCutoff = obj.usageStateRules.activeVsInactiveCountsPerSecondCutoff; %10; % exceeding the cutoff indicates active
            onBodyVsOffBodyCountsPerMinuteCutoff = obj.usageStateRules.onBodyVsOffBodyCountsPerMinuteCutoff; %1; % exceeding the cutoff indicates on body (wear)


            
            
            
                        
            samplesPerMinute = obj.getSampleRate()*60; % samples per second * 60 seconds per minute
            samplesPerHour = 60*samplesPerMinute;
            
            
            longFilterLength = longClassificationMinimumDurationOfMinutes*samplesPerMinute;
            shortFilterLength = shortClassificationMinimumDurationOfMinutes*samplesPerMinute;
            
            longRunningActivitySum = obj.movingSummer(countActivity,longFilterLength);
            shortRunningActivitySum = obj.movingSummer(countActivity,shortFilterLength);
            
            %            usageVec = zeros(size(obj.dateTimeNum));
            usageVec = repmat(UNKNOWN,(size(obj.dateTimeNum)));
            
            
            % This is good for determining where the study has ended... using a 15 minute duration minimum
            % (essentially 1 count allowed per minute or 15 counts per 900 samples )
            offBodyThreshold = longClassificationMinimumDurationOfMinutes*onBodyVsOffBodyCountsPerMinuteCutoff;
            
            longActiveThreshold = longClassificationMinimumDurationOfMinutes*(activeVsInactiveCountsPerSecondCutoff*60);
            
            
            awakeVsAsleepVec = longRunningActivitySum>awakeVsAsleepCountsPerSecondCutoff; % 1 indicates Awake
            activeVec = longRunningActivitySum>longActiveThreshold; % 1 indicates active
            inactiveVec = awakeVsAsleepVec&~activeVec; %awake, but not active
            sleepVec = ~awakeVsAsleepVec; % not awake
            
            sleepPeriodParams.merge_within_samples = obj.usageStateRules.mergeWithinHoursForSleep*samplesPerHour; % 3600*2*obj.getSampleRate();
            sleepPeriodParams.min_dur_samples = obj.usageStateRules.minHoursForSleep*samplesPerHour; %3600*4*obj.getSampleRate();
            sleepVec = obj.reprocessEventVector(sleepVec,sleepPeriodParams.min_dur_samples,sleepPeriodParams.merge_within_samples);
            
            
            %% Short vector sum - applied to sleep states
            % Examine rem sleep on a shorter time scale
            shortOffBodyThreshold = shortClassificationMinimumDurationOfMinutes*onBodyVsOffBodyCountsPerMinuteCutoff;
            % shortActiveThreshold = shortClassificationMinimumDurationOfMinutes*(activeVsInactiveCountsPerSecondCutoff*60);
            shortNoActivityVec = shortRunningActivitySum<shortOffBodyThreshold;
            
            remSleepPeriodParams.merge_within_samples = obj.usageStateRules.mergeWithinMinutesForREM*samplesPerMinute;  %merge within 5 minutes
            remSleepPeriodParams.min_dur_samples = obj.usageStateRules.minMinutesForREM*samplesPerMinute;   %require minimum of 20 minutes
            remSleepVec = obj.reprocessEventVector(sleepVec&shortNoActivityVec,remSleepPeriodParams.min_dur_samples,remSleepPeriodParams.merge_within_samples);
            
            
            % Check for nonwear
            longNoActivityVec = longRunningActivitySum<offBodyThreshold;
            candidate_nonwear_events= obj.thresholdcrossings(longNoActivityVec,0);
            
            params.merge_within_sec = obj.usageStateRules.mergeWithinHoursForNonWear*samplesPerHour; %4;
            params.min_dur_sec = obj.usageStateRules.minHoursForNonWear*samplesPerHour; %4;
            
            %            params.merge_within_sec = 3600*1;
            %            params.min_dur_sec = 3600*1;
            
            if(~isempty(candidate_nonwear_events))
                
                if(params.merge_within_sec>0)
                    merge_distance = round(params.merge_within_sec*obj.getSampleRate());
                    nonwear_events = obj.merge_nearby_events(candidate_nonwear_events,merge_distance);
                end
                
                if(params.min_dur_sec>0)
                    diff_sec = (candidate_nonwear_events(:,2)-candidate_nonwear_events(:,1))/obj.getSampleRate();
                    nonwear_events = candidate_nonwear_events(diff_sec>=params.min_dur_sec,:);
                end
                
                studyOverParams.merge_within_sec = obj.usageStateRules.mergeWithinHoursForStudyOver*samplesPerHour; %-> group within 6 hours ..
                studyOverParams.min_dur_sec = obj.usageStateRules.minHoursForStudyOver*samplesPerHour;%12;% -> this is for classifying state as over.
                merge_distance = round(studyOverParams.merge_within_sec*obj.getSampleRate());
                candidate_studyover_events = obj.merge_nearby_events(nonwear_events,merge_distance);
                diff_sec = (candidate_studyover_events(:,2)-candidate_studyover_events(:,1))/obj.getSampleRate();
                studyover_events = candidate_studyover_events(diff_sec>=studyOverParams.min_dur_sec,:);
                
            end
            
            nonwearVec = obj.unrollEvents(nonwear_events,numel(usageVec));
            
            % Round the study over events to the end of the study if it is
            % within 4 hours of the end of the study.
            % --- Otherwise, should I remove all study over events, because
            % the study is clearly not over then (i.e. there is more
            % activity being presented).
            if(~isempty(studyover_events))
                diff_hours = (obj.durationSamples()-studyover_events(end))/samplesPerHour; %      obj.getSampleRate()/3600;
                if(diff_hours<=obj.usageStateRules.mergeWithinHoursForStudyOver)
                    studyover_events(end) = obj.durationSamples();
                end
            end
            
            % We really just want one section of study over -> though this
            % may be worthwhile to note in cases where studies have large
            % gaps.
            if(size(studyover_events,1)>1)
                studyover_events = studyover_events(end,:);
            end
            
            studyOverVec = obj.unrollEvents(studyover_events,numel(usageVec));
            
            nonwear_events = obj.thresholdcrossings(nonwearVec,0);
            if(~isempty(nonwear_events))
                nonwearStartStopDateNums = [obj.dateTimeNum(nonwear_events(:,1)),obj.dateTimeNum(nonwear_events(:,2))];
                %durationOff = nonwear(:,2)-nonwear(:,1);
                %durationOffInHours = (nonwear(:,2)-nonwear(:,1))/3600;
            else
                nonwearStartStopDateNums = [];
            end
            nonwearState = repmat(NONWEAR,size(nonwear_events,1),1);
            
            %            wearVec = runningActivitySum>=offBodyThreshold;
            wearVec = ~nonwearVec;
            wear = obj.thresholdcrossings(wearVec,0);
            wearStartStopDateNums = [obj.dateTimeNum(wear(:,1)),obj.dateTimeNum(wear(:,2))];
            wearState = repmat(WEAR,size(wear,1),1);
            
            usageState = [nonwearState;wearState];
            [startStopDateNums, sortIndex] = sortrows([nonwearStartStopDateNums;wearStartStopDateNums]);
            usageState = usageState(sortIndex);
            
            tagStruct = obj.getActivityTags();
            
            %usageVec(awakeVsAsleepVec) = 20;
            %usageVec(wearVec) = 10;   %        This is covered
            % <<<<<<< HEAD
            %            usageVec(activeVec) = ACTIVE;  %None!
            %            usageVec(inactiveVec) = INACTIVE;
            %            usageVec(~awakeVsAsleepVec) = NAPPING;   % Not awake, but may be too short to enter REM or NREMS.
            %            usageVec(sleepVec) = NREMS;   %Sleep period
            %            usageVec(remSleepVec) = REMS;  %REM sleep
            %            usageVec(nonwearVec) = NONWEAR;
            %            usageVec(studyOverVec) = STUDYOVER;
            %            % -1 uncategorized
            %
            %
            % =======
            usageVec(activeVec) = tagStruct.ACTIVE;%35;  %None!
            usageVec(inactiveVec) = tagStruct.INACTIVE;%25;
            usageVec(~awakeVsAsleepVec) = tagStruct.NAP;%20;
            usageVec(sleepVec) = tagStruct.NREM;%15;   %Sleep period
            usageVec(remSleepVec) = tagStruct.REMS;%10;  %REM sleep
            usageVec(nonwearVec) = tagStruct.NONWEAR;%5;
            usageVec(studyOverVec) = tagStruct.STUDYOVER;%0;
            
        end
        
        
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
        function activityStruct = describeActivity(obj,categoryStr)
            activityStruct = struct();
            switch(categoryStr)
                case 'sleep'
                    activityStruct.sleep = [];
                case 'wake'
                    activityStruct.wake = [];
                case 'inactivity'
                    activityStruct.inactivity = [];
            end
        end
        
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
        function obj = saveToFile(obj,activityType, saveFilename)
            switch(activityType)
                case 'usageState'
                    fprintf('Saving %s to %s.\n',activityType,saveFilename);
                case 'activity'
                    fprintf('Saving %s to %s.\n',activityType,saveFilename);
                case 'inactivity'
                    fprintf('Saving %s to %s.\n',activityType,saveFilename);
                case 'sleep'
                    fprintf('Saving %s to %s.\n',activityType,saveFilename);
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
        function dat = subsindex(obj,indices,structType)
            
            if(nargin<3 ||isempty(structType))
                structType = 'timeSeries';
            end
            switch structType
                case 'timeSeries'
                    if(strcmpi(obj.accelType,'all'))
                        accelTypes = {'count','raw'};
                        for a =1:numel(accelTypes)
                            accelTypeStr = accelTypes{a};
                            dat.accel.(accelTypeStr).x = double(obj.accel.(accelTypeStr).x(indices));
                            dat.accel.(accelTypeStr).y = double(obj.accel.(accelTypeStr).y(indices));
                            dat.accel.(accelTypeStr).z = double(obj.accel.(accelTypeStr).z(indices));
                            dat.accel.(accelTypeStr).vecMag = double(obj.accel.(accelTypeStr).vecMag(indices));
                        end
                        
                    else
                        dat.accel.(obj.accelType).x = double(obj.accel.(obj.accelType).x(indices));
                        dat.accel.(obj.accelType).y = double(obj.accel.(obj.accelType).y(indices));
                        dat.accel.(obj.accelType).z = double(obj.accel.(obj.accelType).z(indices));
                        dat.accel.(obj.accelType).vecMag = double(obj.accel.(obj.accelType).vecMag(indices));
                    end
                    dat.steps = double(obj.steps(indices));
                    dat.lux = double(obj.lux(indices));
                    dat.inclinometer.standing = double(obj.inclinometer.standing(indices));
                    dat.inclinometer.sitting = double(obj.inclinometer.sitting(indices));
                    dat.inclinometer.lying = double(obj.inclinometer.lying(indices));
                    dat.inclinometer.off = double(double(obj.inclinometer.off(indices)));
                case 'features'
                    dat = PAData.subsStruct(obj.features,indices);
                case 'bins'
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
                if(~isempty(intersect(lower(s(1).subs),lower({'getFrameDuration','getAlignedFeatureVecs'}))))
                    [sref, varargout{1}] = builtin('subsref',obj,s);
                elseif(~isempty(intersect(lower(s(1).subs),lower({'classifyUsageState'}))))
                    [sref, varargout{1}, varargout{2}] = builtin('subsref',obj,s);
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
        function dat = getStruct(obj,choice,structType)
            
            if(nargin<3)
                structType = 'timeSeries';
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
            
            if(strcmpi(structType,'timeSeries'))
                dat = obj.pruneStruct(dat);
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
                'yDelta';
                'visible'
                'usageStateRules'
                };
            %            fields = fieldnames(obj.getDefaultParameters());
            pStruct = struct();
            for f=1:numel(fields)
                pStruct.(fields{f}) = obj.(fields{f});
            end
        end
        
    end
    
    methods (Access = private)
        
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
        function recordCount = loadRawActivityBinFile(obj,fullRawActivityBinFilename,firmwareVersion)
            if(exist(fullRawActivityBinFilename,'file'))
                
                recordCount = 0;
                
                fid = fopen(fullRawActivityBinFilename,'r','b');  %I'm going with a big endian format here.
                
                if(fid>0)
                    
                    encodingEPS = 1/341; %from trial and error - or math
                    precision = 'ubit12=>double';
                    
                    
                    % Testing for ver 2.5.0
                    % fullRawActivityBinFilename = '/Volumes/SeaG 1TB/sampledata_reveng/700851.activity.bin'
                    %                sleepmoore:T1_GT3X_Files hyatt4$ head -n 15 ../../sampleData/raw/700851t00c1.raw.csv
                    %                 ------------ Data File Created By ActiGraph GT3X+ ActiLife v6.11.1 Firmware v2.5.0 date format M/d/yyyy at 40 Hz  Filter Normal -----------
                    %                 Serial Number: NEO1C15110103
                    %                 Start Time 00:00:00
                    %                 Start Date 10/25/2012
                    %                 Epoch Period (hh:mm:ss) 00:00:00
                    %                 Download Time 16:48:59
                    %                 Download Date 11/2/2012
                    %                 Current Memory Address: 0
                    %                 Current Battery Voltage: 3.74     Mode = 12
                    %                 --------------------------------------------------
                    %                 Timestamp,Axis1,Axis2,Axis3
                    %                 10/25/2012 00:00:00.000,-0.044,0.361,-0.915
                    %                 10/25/2012 00:00:00.025,-0.044,0.358,-0.915
                    %                 10/25/2012 00:00:00.050,-0.047,0.361,-0.915
                    %                 10/25/2012 00:00:00.075,-0.044,0.361,-0.915
                    % Use big endian format
                    try
                        % both fw 2.5 and 3.1.0 use same packet format for
                        % acceleration data.
                        if(strcmp(firmwareVersion,'2.5.0')||strcmp(firmwareVersion,'3.1.0')||strcmp(firmwareVersion,'2.2.1')||strcmp(firmwareVersion,'1.5.0'))
                            tic
                            axesPerRecord = 3;
                            checksumSizeBytes = 1;
                            if(strcmp(firmwareVersion,'2.5.0'))
                                
                                
                                % The following, commented code is for determining
                                % expected record count.  However, the [] notation
                                % is used as a shortcut below.
                                % bitsPerByte = 8;
                                % fileSizeInBits = ftell(fid)*bitsPerByte;
                                % bitsPerRecord = 36;  %size in number of bits
                                % numberOfRecords = floor(fileSizeInBits/bitsPerRecord);
                                % axesUBitData = fread(fid,[axesPerRecord,numberOfRecords],precision)';
                                % recordCount = numberOfRecords;
                                
                                % reads are stored column wise (one column, then the
                                % next) so we have to transpose twice to get the
                                % desired result here.
                                axesUBitData = fread(fid,[axesPerRecord,inf],precision)';
                                
                            elseif(strcmp(firmwareVersion,'3.1.0')||strcmp(firmwareVersion,'2.2.1') || strcmp(firmwareVersion,'1.5.0'))
                                % endian format: big
                                % global header: none
                                % packet encoding:
                                %   header:  8 bytes  [packet code: 2][time stamp: 4][packet size (in bytes): 2]
                                %   accel packets:  36 bits each (format: see ver 2.5.0) + 1 byte for checksum
                                
                                triaxialAccelCodeBigEndian = 7680;
                                trixaialAccelCodeLittleEndian = 7686; %?
                                triaxialAccelCodeLittleEndian = 30;
                                triaxialAccelCode = triaxialAccelCodeBigEndian;
                                %                                packetCode = 7686 (popped up in a firmware version 1.5
                                bitsPerByte = 8;
                                bitsPerAccelRecord = 36;  %size in number of bits (12 bits per acceleration axis)
                                recordsPerByte = bitsPerByte/bitsPerAccelRecord;
                                timeStampSizeBytes = 4;
                                % packetHeader.size = 8;
                                % go through once to determine how many
                                % records I have in order to preallocate memory
                                % - should look at meta data record to see if I can
                                % shortcut this.
                                while(~feof(fid))
                                    
                                    packetCode = fread(fid,1,'uint16=>double');
                                    fseek(fid,timeStampSizeBytes,0);
                                    packetSizeBytes = fread(fid,2,'uint8');  % This works for firmware version 1.5 packetSizeBytes = fread(fid,1,'uint16','l');
                                    if(~feof(fid))
                                        packetSizeBytes = [1 256]*packetSizeBytes;
                                        if(packetCode == triaxialAccelCode)  % This is for the triaxial accelerometers
                                            packetRecordCount = packetSizeBytes*recordsPerByte;
                                            if(packetRecordCount>1)
                                                recordCount = recordCount+packetRecordCount;
                                            else
                                                fprintf('Record count <=1 at file position %u\n',ftell(fid));
                                            end
                                        end
                                        if(packetSizeBytes~=0)
                                            fseek(fid,packetSizeBytes+checksumSizeBytes,0);
                                        else
                                            fprintf('Packet size is 0 bytes at file position %u\n',ftell(fid));
                                        end
                                    end
                                end
                                
                                frewind(fid);
                                curRecord = 1;
                                axesUBitData = zeros(recordCount,axesPerRecord);
                                obj.timeStamp = zeros(recordCount,1);
                                while(~feof(fid) && curRecord<=recordCount)
                                    packetCode = fread(fid,1,'uint16=>double');
                                    if(packetCode==triaxialAccelCode)  % This is for the triaxial accelerometers
                                        obj.timeStamp(curRecord) = fread(fid,1,'uint32=>double');
                                        packetSizeBytes = [1 256]*fread(fid,2,'uint8');
                                        
                                        packetRecordCount = packetSizeBytes*recordsPerByte;
                                        
                                        axesUBitData(curRecord:curRecord+packetRecordCount-1,:) = fread(fid,[axesPerRecord,packetRecordCount],precision)';
                                        curRecord = curRecord+packetRecordCount;
                                        checkSum = fread(fid,checksumSizeBytes,'uint8');
                                    elseif(packetCode==0)
                                        
                                    else
                                        fseek(fid,timeStampSizeBytes,0);
                                        packetSizeBytes = fread(fid,2,'uint8');
                                        if(~feof(fid))
                                            packetSizeBytes = [1 256]*packetSizeBytes;
                                            fseek(fid,packetSizeBytes+checksumSizeBytes,0);
                                        end
                                    end
                                end
                                
                                curRecord = curRecord -1;  %adjust for the 1 base offset matlab uses.
                                if(recordCount~=curRecord)
                                    fprintf(1,'There is a mismatch between the number of records expected and the number of records found.\n\tPlease check your data for corruption.\n');
                                end
                            end
                            
                            
                            axesFloatData = (-bitand(axesUBitData,2048)+bitand(axesUBitData,2047))*encodingEPS;
                            
                            obj.accel.raw.x = axesFloatData(:,1);
                            obj.accel.raw.y = axesFloatData(:,2);
                            obj.accel.raw.z = axesFloatData(:,3);
                            obj.accel.raw.vecMag = sqrt(obj.accel.raw.x.^2+obj.accel.raw.y.^2+obj.accel.raw.z.^2);
                            recordCount = size(axesFloatData,1);
                            obj.durSamples = recordCount;
                            
                            toc;
                        end
                        fclose(fid);
                        
                        fprintf('Skipping resample count data step\n');
                        %                        obj.resampleCountData();
                        
                    catch me
                        showME(me);
                        fclose(fid);
                    end
                else
                    fprintf('Warning - could not open %s for reading!\n',fullRawActivityBinFilename);
                end
            else
                fprintf('Warning - %s does not exist!\n',fullRawActivityBinFilename);
            end
        end
        
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
        function dat = getAllStruct(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
            end
            
            switch structType
                case 'timeSeries'
                    accelTypeStr = obj.accelType;
                    
                    if(strcmpi(accelTypeStr,'all'))
                        dat.accel= obj.accel;
                    else
                        dat.accel.(accelTypeStr) = obj.accel.(accelTypeStr);
                    end
                    dat.steps = obj.steps;
                    dat.lux = obj.lux;
                    dat.inclinometer = obj.inclinometer;
                case 'bins'
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
        function curStruct = getCurrentStruct(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
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
        function dat = getCurrentDisplayStruct(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
            end
            
            dat = PAData.structEval('times',obj.getStruct('current',structType),obj.getScale(structType));
            
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
            dat = PAData.structEval('plus',dat,obj.getOffset(structType),'ydata');
            dat = PAData.appendStruct(dat,lineProp);
        end
        
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
        function dat = getCurrentOffsetStruct(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
            end
            
            dat = obj.getOffset(structType);
            
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
        
        % File I/O
        
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
        function [infoStruct, firmware] = parseInfoTxt(infoTxtFullFilename)
            if(exist(infoTxtFullFilename,'file'))
                fid = fopen(infoTxtFullFilename,'r');
                pat = '(?<field>[^:]+):\s+(?<values>[^\r\n]+)\s*';
                fileText = fscanf(fid,'%c');
                result = regexp(fileText,pat,'names');
                infoStruct = [];
                for f=1:numel(result)
                    fieldName = strrep(result(f).field,' ','_');
                    infoStruct.(fieldName)=result(f).values;
                end
                if(isfield(infoStruct,'Firmware'))
                    firmware = infoStruct.Firmware;
                else
                    firmware = '';
                end
                fclose(fid);
                
            else
                infoStruct=[];
                firmware ='';
            end
        end
        
        % Analysis
        
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
        function processVec = reprocessEventVector(logicalVec,min_duration_samples,merge_distance_samples)
            
            candidate_events= PAData.thresholdcrossings(logicalVec,0);
            
            if(~isempty(candidate_events))
                
                if(merge_distance_samples>0)
                    candidate_events = PAData.merge_nearby_events(candidate_events,merge_distance_samples);
                end
                
                if(min_duration_samples>0)
                    diff_samples = (candidate_events(:,2)-candidate_events(:,1));
                    candidate_events = candidate_events(diff_samples>=min_duration_samples,:);
                end
            end
            
            processVec = PAData.unrollEvents(candidate_events,numel(logicalVec));
            
        end
        
        
        %======================================================================
        %> @brief Moving summer finite impulse response filter.
        %> @param signal Vector of sample data to filter.
        %> @param filterOrder filter order; number of taps in the filter
        %> @retval summedSignal The filtered signal.
        %> @note The filter delay is taken into account such that the
        %> return signal is offset by half the delay.
        %======================================================================
        function summedSignal = movingSummer(signal, filterOrder)
            delay = floor(filterOrder/2);
            B = ones(filterOrder,1);
            A = 1;
            summedSignal = filter(B,A,signal);
            
            %account for the delay...
            summedSignal = [summedSignal((delay+1):end); zeros(delay,1)];
        end
        
        
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
        function vector = unrollEvents(eventsStartStop,vectorSize)
            vector = false(vectorSize,1);
            for e=1:size(eventsStartStop,1)
                vector(eventsStartStop(e,1):eventsStartStop(e,2))=true;
            end
        end
        
        
        %======================================================================
        %> @brief returns a cell of tag lines and the associated label
        %> describing the tag line.
        %> @retval tagLines Cell of tag lines
        %> @retval labels Cell of string descriptions that correspond to tag
        %> lines in the tagLines cell.
        %> @note Tag lines are useful for dynamic struct indexing into
        %> structs returned by getStruct.
        %======================================================================
        function [tagLines,labels] = getDefaultTagLineLabels()
            tagLines = {
                'accel.raw.vecMag';
                'accel.raw.x';
                'accel.raw.y';
                'accel.raw.z';
                'accel.count.vecMag';
                'accel.count.x';
                'accel.count.y';
                'accel.count.z';
                'steps';
                'lux';
                'inclinometer.standing';
                'inclinometer.sitting';
                'inclinometer.lying';
                'inclinometer.off';
                };
            labels = {
                'Magnitude (raw)';
                'X (raw)';
                'Y (raw)';
                'Z (raw)';
                'Magnitude (count)';
                'X (count)';
                'Y (count)';
                'Z (count)';
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
        function pStruct = getDefaultParameters()
            pStruct.pathname = '.'; %directory of accelerometer data.
            pStruct.filename = ''; %last accelerometer data opened.
            pStruct.curWindow = 1;
            pStruct.frameDurMin = 15;  % frame duration minute of 0 equates to frame sizes of 1 frame per sample (i.e. no aggregation)
            pStruct.frameDurHour = 0;
            pStruct.aggregateDurMin = 3;
            pStruct.windowDurSec = 60*60; % set to 1 hour
            
            usageState.longClassificationMinimumDurationOfMinutes=15;
            usageState.shortClassificationMinimumDurationOfMinutes = 5;
            usageState.awakeVsAsleepCountsPerSecondCutoff = 1;  % exceeding the cutoff means you are awake
            usageState.activeVsInactiveCountsPerSecondCutoff = 10; % exceeding the cutoff indicates active
            usageState.onBodyVsOffBodyCountsPerMinuteCutoff = 1; % exceeding the cutoff indicates on body (wear)
            
            usageState.mergeWithinHoursForSleep = 2;
            usageState.minHoursForSleep = 4;
            
            usageState.mergeWithinMinutesForREM = 5;
            usageState.minMinutesForREM = 20;
            
            usageState.mergeWithinHoursForNonWear = 4;
            usageState.minHoursForNonWear = 4;
            
            usageState.mergeWithinHoursForStudyOver = 6;
            usageState.minHoursForStudyOver = 12;% -> this is for classifying state as over.
            usageState.mergeWithinFinalHoursOfStudy = 4;
            
            pStruct.usageStateRules = usageState;
            
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
                %                pStruct.label.features.(curFeature).position = [0 0 0];
                pStruct.color.features.(curFeature).color = curColor;
                pStruct.visible.features.(curFeature).visible = 'on';
                
            end
            
            
            %Default is everything to be visible
            timeSeriesStruct = PAData.getDummyStruct('timeSeries');
            visibleProp.visible = 'on';
            pStruct.visible.timeSeries = PAData.overwriteEmptyStruct(timeSeriesStruct,visibleProp);
            
            % yDelta = 1/20 of the vertical screen space (i.e. 20 can fit)
            pStruct.offset.timeSeries.accel.raw.x = pStruct.yDelta*1;
            pStruct.offset.timeSeries.accel.raw.y = pStruct.yDelta*4;
            pStruct.offset.timeSeries.accel.raw.z = pStruct.yDelta*7;
            pStruct.offset.timeSeries.accel.raw.vecMag = pStruct.yDelta*10;
            pStruct.offset.timeSeries.accel.count.x = pStruct.yDelta*1;
            pStruct.offset.timeSeries.accel.count.y = pStruct.yDelta*4;
            pStruct.offset.timeSeries.accel.count.z = pStruct.yDelta*7;
            pStruct.offset.timeSeries.accel.count.vecMag = pStruct.yDelta*10;
            pStruct.offset.timeSeries.steps = pStruct.yDelta*14;
            pStruct.offset.timeSeries.lux = pStruct.yDelta*15;
            pStruct.offset.timeSeries.inclinometer.standing = pStruct.yDelta*19.0;
            pStruct.offset.timeSeries.inclinometer.sitting = pStruct.yDelta*18.25;
            pStruct.offset.timeSeries.inclinometer.lying = pStruct.yDelta*17.5;
            pStruct.offset.timeSeries.inclinometer.off = pStruct.yDelta*16.75;
            
            
            pStruct.color.timeSeries.accel.raw.x.color = 'r';
            pStruct.color.timeSeries.accel.raw.y.color = 'b';
            pStruct.color.timeSeries.accel.raw.z.color = 'g';
            pStruct.color.timeSeries.accel.raw.vecMag.color = 'm';
            pStruct.color.timeSeries.accel.count.x.color = 'r';
            pStruct.color.timeSeries.accel.count.y.color = 'b';
            pStruct.color.timeSeries.accel.count.z.color = 'g';
            pStruct.color.timeSeries.accel.count.vecMag.color = 'm';
            pStruct.color.timeSeries.steps.color = 'k'; %[1 0.5 0.5];
            pStruct.color.timeSeries.lux.color = 'y';
            pStruct.color.timeSeries.inclinometer.standing.color = 'k';
            pStruct.color.timeSeries.inclinometer.lying.color = 'k';
            pStruct.color.timeSeries.inclinometer.sitting.color = 'k';
            pStruct.color.timeSeries.inclinometer.off.color = 'k';
            
            % Scale to show at
            % Increased scale used for raw acceleration data so that it can be
            % seen more easily.
            pStruct.scale.timeSeries.accel.raw.x = 10;
            pStruct.scale.timeSeries.accel.raw.y = 10;
            pStruct.scale.timeSeries.accel.raw.z = 10;
            pStruct.scale.timeSeries.accel.raw.vecMag = 10;
            pStruct.scale.timeSeries.accel.count.x = 1;
            pStruct.scale.timeSeries.accel.count.y = 1;
            pStruct.scale.timeSeries.accel.count.z = 1;
            pStruct.scale.timeSeries.accel.count.vecMag = 1;
            pStruct.scale.timeSeries.steps = 5;
            pStruct.scale.timeSeries.lux = 1;
            pStruct.scale.timeSeries.inclinometer.standing = 5;
            pStruct.scale.timeSeries.inclinometer.sitting = 5;
            pStruct.scale.timeSeries.inclinometer.lying = 5;
            pStruct.scale.timeSeries.inclinometer.off = 5;
            
            [tagLines, labels] = PAData.getDefaultTagLineLabels();
            for t=1:numel(tagLines)
                eval(['pStruct.label.timeSeries.',tagLines{t},'.string = ''',labels{t},''';']);
            end
            
            %            pStruct.label.timeSeries.accel.raw.x.string = 'X_R_A_W';
            %            pStruct.label.timeSeries.accel.raw.y.string = 'Y_R_A_W';
            %            pStruct.label.timeSeries.accel.raw.z.string = 'Z_R_A_W';
            %            pStruct.label.timeSeries.accel.vecMag.string = 'Magnitude (raw)';
            %
            %            pStruct.label.timeSeries.count.raw.x.string = 'X_R_A_W';
            %            pStruct.label.timeSeries.count.raw.y.string = 'Y_R_A_W';
            %            pStruct.label.timeSeries.count.raw.z.string = 'Z_R_A_W';
            %            pStruct.label.timeSeries.count.vecMag.string = 'Magnitude (count)';
            %
            %            pStruct.label.timeSeries.steps.string = 'Steps';
            %            pStruct.label.timeSeries.lux.string = 'Lux';
            %
            %            pStruct.label.timeSeries.inclinometer.standing.string = 'Standing';
            %            pStruct.label.timeSeries.inclinometer.sitting.string = 'Sitting';
            %            pStruct.label.timeSeries.inclinometer.lying.string = 'Lying';
            %            pStruct.label.timeSeries.inclinometer.off.string = 'Off';
            
            
        end
        
        % ======================================================================
        %> @brief Returns structure whose values are taken from the struct
        %> and indices provided.
        %> @param structIn Struct of indicable data.
        %> @param indices Vector (logical or ordinal) of indices to select time
        %> series data by.
        %> @retval structOut Struct with matching fields as input struct, with values taken at indices.
        %======================================================================
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
        %======================================================================
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
        %> @note PAData.structEval('overwrite',ltStruct,ltStruct,value)
        %> @note ans =
        %> @note         x: value
        %> @note     accel: [1x1 struct]
        %> @note              [x]: value
        %> @note              [y]: value
        %> @note        
        %> @note
        % ======================================================================
        function resultStruct = structEval(operand,ltStruct,rtStruct,optionalDestFieldOrValue)
            if(nargin < 4)
                optionalDestFieldOrValue = [];
            end
            
            if(isstruct(ltStruct))
                fnames = fieldnames(ltStruct);
                resultStruct = struct();
                for f=1:numel(fnames)
                    curField = fnames{f};
                    resultStruct.(curField) = PAData.structEval(operand,ltStruct.(curField),rtStruct.(curField),optionalDestFieldOrValue);
                end
            else
                if(strcmpi(operand,'calculateposition'))
                    resultStruct.position = [rtStruct.xdata(1), rtStruct.ydata(1), 0];
                    
                else
                    if(~isempty(optionalDestFieldOrValue))
                        if(strcmpi(operand,'passthrough'))
                            resultStruct.(optionalDestFieldOrValue) = ltStruct;
                        elseif(strcmpi(operand,'overwrite'))
                            resultStruct = optionalDestFieldOrValue;
                        elseif(strcmpi(operand,'repmat'))
                            resultStruct = repmat(ltStruct,optionalDestFieldOrValue);
                        else
                            resultStruct.(optionalDestFieldOrValue) = feval(operand,ltStruct,rtStruct);
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
        function ltStruct = appendStruct(ltStruct,rtStruct)
            if(isstruct(ltStruct))
                fnames = fieldnames(ltStruct);
                for f=1:numel(fnames)
                    curField = fnames{f};
                    if(isstruct(ltStruct.(curField)))
                        ltStruct.(curField) = PAData.appendStruct(ltStruct.(curField),rtStruct);
                    else
                        % This is a bit of an issue ...
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
        
        %======================================================================
        %> @brief flattens a structure to a single dimensional array (i.e. a
        %> vector)
        %> @param structure A struct with any number of fields.
        %> @retval vector A vector with values that are taken from the
        %> structure.
        %======================================================================
        function vector = struct2vec(structure,vector)
            if(nargin<2)
                vector = [];
            end
            if(~isstruct(structure))
                vector = structure;
            else
                fnames = fieldnames(structure);
                for f=1:numel(fnames)
                    vector = [vector;PAData.struct2vec(structure.(fnames{f}))];
                end
            end
        end
        
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
        function structMinmax = minmax(dataStruct)
            fnames = fieldnames(dataStruct);
            structMinmax = struct();
            for f=1:numel(fnames)
                curField = dataStruct.(fnames{f});
                structMinmax.(fnames{f}) = minmax(PAData.getRecurseMinmax(curField));
            end
        end
        
        function structToUpdate = updateStructWithStruct(structToUpdate, structToUpdateWith)
            
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
            
            
            if(isstruct(ruleStruct))
                ruleFields = fieldnames(this.usageStateRules);
                for f=1:numel(ruleFields)
                    curField = ruleFields{f};
                    if(hasfield(ruleStruct,curField) && class(ruleStruct.(curField)) == class(this.usageStateRules.(curField)))
                        this.usageStateRules.(curField) = ruleStruct.(curField);
                    end
                end
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
        function dat = getDummyStruct(structType)
            if(nargin<1 || isempty(structType))
                structType = 'timeSeries';
            end
            
            switch structType
                case 'timeSeries'
                    accelS.raw.x =[];
                    accelS.raw.y = [];
                    accelS.raw.z = [];
                    accelS.raw.vecMag = [];
                    
                    accelS.count.x =[];
                    accelS.count.y = [];
                    accelS.count.z = [];
                    accelS.count.vecMag = [];
                    
                    incl.standing = [];
                    incl.sitting = [];
                    incl.lying = [];
                    incl.off = [];
                    dat.accel = accelS;
                    dat.steps = [];
                    dat.lux = [];
                    dat.inclinometer = incl;
                case 'bins'
                    binNames =  PAData.getPrefilterMethods();
                    dat = struct;
                    for f=1:numel(binNames)
                        dat.(lower(binNames{f})) = [];
                    end
                    
                case 'features'
                    %                    featureNames =  PAData.getExtractorMethods();
                    featureNames = fieldnames(PAData.getFeatureDescriptionStructWithPSDBands());
                    dat = struct;
                    for f=1:numel(featureNames)
                        dat.(lower(featureNames{f})) = [];
                    end
                    
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
        function dat = getDummyDisplayStruct(structType)
            lineProps.xdata = [1 1200];
            lineProps.ydata = [1 1];
            lineProps.color = 'k';
            lineProps.visible = 'on';
            
            if(nargin<1 || isempty(structType))
                structType = 'timeSeries';
            end
            
            dat = PAData.getDummyStruct(structType);
            dat = PAData.overwriteEmptyStruct(dat,lineProps);
            
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
        function extractorDescriptions = getExtractorDescriptions()
            [~, extractorDescriptions] = PAData.getFeatureDescriptionStruct();
            
            %% This was before I rewrote getFeatureDescriptionStruct
            % featureStruct = PAData.getFeatureDescriptionStruct();
            % extractorDescriptions = struct2cell(featureStruct);
            
            %%  This was apparently before I knew about struct2cell ...
            %            fnames = fieldnames(featureStruct);
            %
            %            extractorDescriptions = cell(numel(fnames),1);
            %            for f=1:numel(fnames)
            %                extractorDescriptions{f} = featureStruct.(fnames{f});
            %            end
            
            %%  And this, apparently (again), was before that ...
            % extractorMethods = ['All';extractorMethods;'None'];
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns a struct of feature extraction methods and string descriptions as the corresponding values.
        %> @retval featureStruct A struct of  feature extraction methods and string descriptions as the corresponding values.
        % --------------------------------------------------------------------
        function [featureStruct, varargout] = getFeatureDescriptionStruct()
            featureStruct.mean = 'Mean';
            featureStruct.median = 'Median';
            featureStruct.std = 'Standard Deviation';
            featureStruct.rms = 'Root mean square';
            featureStruct.sum = 'Sum';
            featureStruct.var = 'Variance';
            featureStruct.mode = 'Mode';
            featureStruct.usagestate = 'Activity Categories';            
            featureStruct.psd = 'Power Spectral Density';
            %           featureStruct.count = 'Count';
            if(nargout>1)
                varargout{1} = struct2cell(featureStruct);
            end
            
        end
        
        
        function [featureStructWithPSDBands, varargout] = getFeatureDescriptionStructWithPSDBands()
            featureStruct = rmfield(PAData.getFeatureDescriptionStruct,'psd');
            psdFeatureStruct = PAData.getPSDFeatureDescriptionStruct();
            featureStructWithPSDBands = PAData.mergeStruct(featureStruct,psdFeatureStruct);
            if(nargout>1)
                varargout{1} = struct2cell(featureStructWithPSDBands);
            end
        end
        
        function [psdFeatureStruct, varargout] = getPSDFeatureDescriptionStruct()
            psdFeatureStruct = struct();
            psdNames = PAData.getPSDBandNames();
            for p=1:numel(psdNames)
                psdFeatureStruct.(psdNames{p}) = sprintf('Power Spectral Density (band - %u)',p);
            end            
            if(nargout>1)
                varargout{1} = struct2cell(psdFeatureStruct);
            end
        end
        
        function psdExtractorDescriptions = getPSDExtractorDescriptions()
            [~,psdExtractorDescriptions] = PAData.getPSDFeatureDescriptionStruct();
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
        
        %> @brief Returns start and stop pairs of the sample points where where line_in is
        %> greater (i.e. crosses) than threshold_line
        %> threshold_line and line_in must be of the same length if threshold_line is
        %> not a scalar value.
        %> @retval
        %> - Nx2 matrix of start and stop pairs of the sample points where where line_in is
        %> greater (i.e. crosses) than threshold_line
        %> - An empty matrix if no pairings are found
        %> @note Lifted from informaton/sev suite.  Authored by Hyatt Moore, IV (< June, 2013)
        function x = thresholdcrossings(line_in, threshold_line)
            
            if(nargin==1 && islogical(line_in))
                ind = find(line_in);
            else
                ind = find(line_in>threshold_line);
            end
            cur_i = 1;
            
            if(isempty(ind))
                x = ind;
            else
                x_tmp = zeros(length(ind),2);
                x_tmp(1,:) = [ind(1) ind(1)];
                for k = 2:length(ind);
                    if(ind(k)==x_tmp(cur_i,2)+1)
                        x_tmp(cur_i,2)=ind(k);
                    else
                        cur_i = cur_i+1;
                        x_tmp(cur_i,:) = [ind(k) ind(k)];
                    end;
                end;
                x = x_tmp(1:cur_i,:);
            end;
        end
        
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
        function [merged_events, merged_indices] = merge_nearby_events(event_mat_in,min_samples)
            
            if(nargin==1)
                min_samples = 100;
            end
            
            merged_indices = false(size(event_mat_in,1),1);
            
            if(~isempty(event_mat_in))
                merged_events = zeros(size(event_mat_in));
                num_events_out = 1;
                num_events_in = size(event_mat_in,1);
                merged_events(num_events_out,:) = event_mat_in(1,:);
                for k = 2:num_events_in
                    if(event_mat_in(k,1)-merged_events(num_events_out,2)<min_samples)
                        merged_events(num_events_out,2) = event_mat_in(k,2);
                        merged_indices(k) = true;
                    else
                        num_events_out = num_events_out + 1;
                        merged_events(num_events_out,:) = event_mat_in(k,:);
                    end
                end;
                merged_events = merged_events(1:num_events_out,:);
            else
                merged_events = event_mat_in;
            end;
        end
        
        %> @brief Parses the input file's basename (i.e. sans folder and extension)
        %> for the study id.  This will vary according from site to site as
        %> there is little standardization for file naming.
        %> @param  File basename (i.e. sans path and file extension).
        %> @retval Study ID
        function studyID = getStudyIDFromBasename(baseName)
            % Appropriate for GOALS output
            studyID = baseName(1:6);
        end
        
        function tagStruct = getActivityTags()
            tagStruct.ACTIVE = 35;
            tagStruct.INACTIVE = 25;
            tagStruct.NAP  = 20;
            tagStruct.NREM =  15;
            tagStruct.REMS = 10;
            tagStruct.NONWEAR = 5;
            tagStruct.STUDYOVER = 0;
        end
        
        function bandNamesAsCell = getPSDBandNames()
            bandNamesAsCell = str2cell(sprintf('psd_band_%u\n',1:PAData.NUM_PSD_BANDS));
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
