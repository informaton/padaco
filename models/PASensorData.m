% ======================================================================
%> @file PASensorData.cpp
%> @brief Accelerometer data loading class.
% ======================================================================
%> @brief The PASensorData class helps loads and stores accelerometer data used in the
%> physical activity monitoring project.  The project is aimed at reducing
%> obesity and improving health in children.
% ======================================================================
classdef PASensorData < PAData
    events
        LinePropertyChanged;
    end

    properties(Constant)
        NUM_PSD_BANDS = 5;
    end

    properties
        %> @brief Type of acceleration stored; can be
        %> - @c raw This is not processed
        %> - @c count This is preprocessed
        %> - @c all - This is both @c raw and @c count accel fields.
        %> - @c none No data loaded.
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
        
        bai; % 1 second standard deviations available for raw data only

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
        %> @brief stop Time
        stopTime;
        %> @brief stop Date
        stopDate;
        %> Durtion of the sampled data in seconds.
        durationSec;
        %> @brief The numeric value for each date time sample provided by
        %> the file name.
        dateTimeNum;

        %> @brief Numeric values for date time sample for the start of
        %> extracted features.
        startDatenums;
        %> @brief Numeric values for date time sample for when the extracted features stop/end.
        stopDatenums;

        
        % These have to do with how the data is VIEWed.
        % and have been refactored under 'settings' property
        %         label;
        %         color;
        %         offset;
        %         scale;
        %         visible;
        %
        %         yDelta;

        %> @brief Identifier (string) for the file data that was loaded.
        %> @note See getStudyIDFromBasename()
        studyID;

        actigraphActitivityID = 26;    % for loading actilife records
                                       % 0  for acitivity1 records
                                       % 26 for activity2 records.  
                                       % Ref: https://github.com/actigraph/GT3X-File-Format/blob/main/LogRecords/Activity2.md

        samplesPerG = 341;  % bits to encode the dynamic range of gravity.  341 steps per unit of gravity for 12 bit encoding of +/-6g,  255 for 12 bit encoding of +/-8g

    end

    properties (SetAccess = protected)
        
        %> Current window.  Current position in the raw data.
        %> The first window is '1' (i.e. not zero because this is MATLAB programming)
        curWindow;
        %> Number of samples contained in the data (accelRaw.x)
        durSamples;
        %> @brief Defined in the accelerometer's file output and converted to seconds.
        %> This is, most likely, the sampling rate of the output file.
        countPeriodSec;
        

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
        %> See getDefaults for initial values.
        usageStateRules;

        %> @brief Number of frames that the time series data can be aggregated
        %> into.  It is calculated as the ceiling of the study's duration in
        %> minutes divided by the current frame duration in minutes.
        numFrames;

        %> @brief Struct of features as extracted from frames.
        features;

        %> @brief Sample rate of time series data.
        sampleRate;

        
        nonwearAlgorithm;
        
        % Flags for determining if counts and or raw data is loaded.
        hasCounts
        hasRaw;        
        hasMims;
    end

    methods

        % ======================================================================
        %> @brief Constructor for PASensorData class.
        %> @param fullFilenameOrPath Either
        %> - (1) the full filename (i.e. with pathname) of accelerometer data to load.
        %> - or (2) the path that contains raw accelerometer data stored in
        %> binary file(s) - Firmware versions 2.5 or 3.1 only.
        %> @param pStruct Optional struct of parameters to use.  If it is not
        %> included then parameters from getDefaults method are used.
        %> @retval Instance of PASensorData.
         % =================================================================
        function obj = PASensorData(fullFilenameOrPath,varargin)  % inputSettings is second argument
            if(nargin<1)
                fullFilenameOrPath = '';
            end
            obj = obj@PAData(varargin{:});

            obj.hasCounts = false;
            obj.hasRaw = false;
            obj.hasMims = false;
            obj.accelType = 'none';
            obj.startDatenums = [];

            obj.durationSec = 0;  %ensures we get valid, non-empty values from getWindowCount() when we do not have any data loaded.
            % Can summarize these with defaults from below...last f(X) call.
            %            obj.aggregateDurMin = 1;
            %            obj.frameDurMin = 0;
            %            obj.frameDurHour = 1;
            %            obj.curWindow = 1;
            %            obj.windowDurSec = 60*5;  %this is the window size

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
                obj.setFullFilename(fullFilenameOrPath);
                obj.loadFile();
            end

            obj.setCurWindow(obj.getSetting('curWindow'));
        end

%         function didSet= setSettings(this, inputSettings)
%             didSet = setSettings@PAData(this,inputSettings);
%             fields = fieldnames(this.settings);            
%             for f=1:numel(fields)                
%                 %need to make sure we are not overwriting the filename we just
%                 %brought in
%                 if(~strcmpi(fields{f},'pathname') && ~strcmpi(fields{f},'filename'))
%                     this.(fields{f}) = this.settings.(fields{f});
%                 end
%             end
%         end

        function didSet = setSettings(this, inputSettings)
            didSet = false;
            if(setSettings@PAData(this, inputSettings))
                fnames = fieldnames(inputSettings);
                for f= 1:numel(fnames)
                    fname = fnames{f};
                    value = inputSettings.(fname);
                    if isprop(this, fname)
                        if( isa(value,'PAParam'))
                            this.(fname) = inputSettings.(fname).value;
                        else
                            this.(fname) = inputSettings.(fname);
                        end
                    end
                end
                didSet = true;
            end
        end
        
        function hasIt = hasData(obj)
            hasIt = obj.hasCounts||obj.hasRaw || obj.hasMims;
        end

        function [didExport, resultMsg] = exportToDisk(obj,exportPath)
            didExport = false;
            try
                if(nargin<2 || isempty(exportPath))
                    exportPath = obj.exportPathname;
                else
                    this.setExportPath(exportPath);
                end
                if(~isdir(exportPath))
                    msg = sprintf('Export path does not exist.  Nothing done.\nExport path: %s',exportPath);
                else
                    % Do you want usage stage per second?  With time stamps?
                    % With x, y, z - do you want it framed and just take the
                    % mode?
                    [~,baseName,~] = fileparts(obj.filename);
                    exportFilename = [baseName,'.activity.txt'];
                    fid = fopen(fullfile(exportPath,exportFilename),'w');
                    if(fid>1)
                        fprintf(fid,'# Activity states for %s\n',fullfile(obj.pathname,obj.filename));
                        tagStruct = obj.getActivityTags();
                                                    
                        tagNames = fieldnames(tagStruct);
                        fprintf(fid,'#--Activity Descriptions--\n');
                        for t=1:numel(tagNames)
                            tag = tagNames{t};
                            fprintf( fid,'# %2d: %s\n',tagStruct.(tag),tag);
                        end
                        
                        fprintf(fid,'#-------------------\n');                        
                        fprintf(fid,'# time stamp, x, y, z, vecMag\n');
                        fprintf(fid,'%f, %2d, %2d, %2d, %2d\n',[obj.dateTimeNum,obj.usage.x,obj.usage.y,obj.usage.z,obj.usage.vecMag]');
                        fclose(fid);
                        msg = sprintf('Export saved to %s.',exportFilename);
                        
                        didExport = true;
                    else
                        msg = sprintf('Unable to open export file for writing (%s).\nCheck write permissions or filename.',exportFilename);
                    end
                end
                resultMsg = msg;
            catch me
                showME(me);
                resultMsg = 'Error occurred during export.\nExport failed. Check logs.';
            end
        end
        
        % ======================================================================
        %> @brief Saves data to an ascii file.
        %> @note This is not yet implemented.
        %> @param obj Instance of PASensorData.
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
        %> @brief Returns a structure of PASensorData's time series data.
        %> @param obj Instance of PASensorData.
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
        function correctedWindowRange = getCurWindowRange(obj,structType)
            if(nargin<2 || isempty(structType))
                structType = 'timeSeries';
            end

            correctedWindowRange = obj.getCurUncorrectedWindowRange(structType);

            switch structType
                case 'timeSeries'
                    maxValue = obj.getDurationSamples();
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
        %> @param obj Instance of PASensorData.
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
        %> @param obj Instance of PASensorData.
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
            windowDur = obj.getSetting('windowDurSec')*obj.getWindowSamplerate(structType);
        end

        % --------------------------------------------------------------------
        %> @brief Returns the sampling rate for the current window display selection
        %> @param obj Instance of PASensorData
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
        %> @param obj Instance of PASensorData
        %> @retval fs Sample rate of the x-axis accelerometer.
        % --------------------------------------------------------------------
        function fs = getSampleRate(obj)
            fs = obj.sampleRate;
        end

        function [x, varargout] = getCountsPerMinute(obj, signalToGet)
            if(obj.hasCounts && obj.durationSec>0)
                secPerMin = 60;
                samplesPerSec =  obj.getSampleRate();
                samplesPerMin = samplesPerSec*secPerMin;
                studyDurationSamples = obj.getDurationSamples();

                if(nargin<2)
                    signalToGet = [];
                else
                    signalToGet = intersect(signalToGet,{'x','y','z','vecMag'});
                end
                %just get one of them.
                if(~isempty(signalToGet))
                    x = sum(obj.accel.count.(signalToGet))/studyDurationSamples*samplesPerMin;
                else
                    x = sum(obj.accel.count.x)/studyDurationSamples*samplesPerMin;
                    y = sum(obj.accel.count.y)/studyDurationSamples*samplesPerMin;
                    z = sum(obj.accel.count.z)/studyDurationSamples*samplesPerMin;
                    vecMag = sum(obj.accel.count.vecMag)/studyDurationSamples*samplesPerMin;
                    if(nargout==1)
                        x = [x,y,z,vecMag];
                    else
                        if(nargout>1)
                            varargout{1} = y;
                            if(nargout>2)
                                varargout{2} = z;
                                if(nargout>3)
                                    varargout{3} = vecMag;
                                end
                            end
                        end
                    end
                end
            else
                x = [];
                varargout = cell(1,nargout-1);
            end
        end

        % --------------------------------------------------------------------
        %> @brief Returns the frame rate in units of frames/second.
        %> @param obj Instance of PASensorData
        %> @retval fs Frames rate in Hz.
        % --------------------------------------------------------------------
        function fs = getFrameRate(obj)
            [frameDurationMinutes, frameDurationHours] = obj.getFrameDuration();
            frameDurationSeconds = frameDurationMinutes*60+frameDurationHours*60*60;
            fs = 1/frameDurationSeconds;
        end

        % --------------------------------------------------------------------
        %> @brief Returns the aggregate bin rate in units of aggregate bins/second.
        %> @param obj Instance of PASensorData
        %> @retval fs Aggregate bins per second.
        % --------------------------------------------------------------------
        function fs = getBinRate(obj)
            fs = 1/60/obj.aggregateDurMin;
        end

        % --------------------------------------------------------------------
        %> @brief Set the current window for the instance variable accelObj
        %> (PASensorData)
        %> @param obj Instance of PASensorData
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
        %> @param obj Instance of PASensorData
        %> @retval curWindow The current window;
        % --------------------------------------------------------------------
        function curWindow = getCurWindow(obj)
            curWindow = obj.curWindow;
        end

        % --------------------------------------------------------------------
        %> @brief Set the aggregate duration (in minutes) instance variable.
        %> @param obj Instance of PASensorData
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
        %> @param obj Instance of PASensorData
        %> @retval aggregateDuration The current window;
        % --------------------------------------------------------------------
        function aggregateDuration = getAggregateDurationInMinutes(obj)
            aggregateDuration = obj.aggregateDurMin;
        end

        % --------------------------------------------------------------------
        %> @brief Returns the total number of aggregated bins the data can be divided
        %> into based on frame rate and the duration of the time series data.
        %> @param obj Instance of PASensorData
        %> @retval binCount The total number of frames contained in the data.
        %> @note In the case of data size is not broken perfectly into frames, but has an incomplete frame, the
        %> window count is rounded down.  For example, if the frame duration 1 min, and the study is 1.5 minutes long, then
        %> the frame count is 1.
        % --------------------------------------------------------------------
        function binCount = getBinCount(obj)
            binCount = floor(obj.durationSec/60/obj.getAggregateDurationInMinutes());
        end

        %> @brief Returns studyID instance variable.
        %> @param Instance of PASensorData
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
        %> @param obj Instance of PASensorData
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
        %> @param obj Instance of PASensorData
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
        %> @param obj Instance of PASensorData
        %> @retval curFrameDurationMin The current frame duration minutes field;
        %> @retval curFramDurationHour The current frame duration hours field;
        % --------------------------------------------------------------------
        function [curFrameDurationMin, curFrameDurationHour] = getFrameDuration(obj)
            curFrameDurationMin = obj.frameDurMin;
            curFrameDurationHour = obj.frameDurHour;
        end


        function frameDurationHours = getFrameDurationInHours(obj)
            [curFrameDurationMin, curFrameDurationHour] = obj.getFrameDuration();
            frameDurationHours = curFrameDurationMin/60+curFrameDurationHour;
        end


        function frameDurationMin = getFrameDurationInMinutes(obj)
            [curFrameDurationMin, curFrameDurationHour] = obj.getFrameDuration();
            frameDurationMin = curFrameDurationMin+curFrameDurationHour*60;
        end

        % --------------------------------------------------------------------
        %> @brief Returns the total number of frames the data can be divided
        %> into evenly based on frame rate and the duration of the time series data.
        %> @param obj Instance of PASensorData
        %> @retval frameCount The total number of frames contained in the data.
        %> @note In the case of data size is not broken perfectly into frames, but has an incomplete frame, the
        %> window count is rounded down (floor).  For example, if the frame duration 1 min, and the study is 1.5 minutes long, then
        %> the frame count is 1.
        % --------------------------------------------------------------------
        function [frameCount, frameableSamples] = getFrameCount(obj)
            [frameDurationMinutes, frameDurationHours] = obj.getFrameDuration();
            frameDurationSeconds = frameDurationMinutes*60+frameDurationHours*60*60;
            frameCount = floor(obj.durationSec/frameDurationSeconds);
            frameableSamples = frameCount*frameDurationSeconds*obj.getSampleRate();
        end
        
        function frameableSamples = getFrameableSampleCount(obj)            
            % [frameDurMinutes, frameDurHours ] = obj.getFrameDuration();
            % frameDurSeconds = frameDurMinutes*60+frameDurHours*60*60;
            % frameCount = obj.getFrameCount();
            % frameableSamples = frameCount*frameDurSeconds*obj.getSampleRate();
            [~, frameableSamples] = obj.getFrameCount();            
        end        

        % --------------------------------------------------------------------
        %> @brief Returns the number of samples contained in the time series data.
        %> @param obj Instance of PASensorData
        %> @retval durationSamp Number of elements contained in durSamples instance var
        %> (initialized by number of elements in accelRaw.x
        % --------------------------------------------------------------------
        function durationSamp = getDurationSamples(obj)
            durationSamp = obj.durSamples;
        end

        % --------------------------------------------------------------------
        %> @brief Set the window duration value in seconds.  This is the
        %> displays window size (i.e. one window shown at a time), in seconds.
        %> @param obj Instance of PASensorData
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
                obj.setSetting('windowDurSec',durSec);

                %calculate the current window based on the start sample using
                %the previous versions window
                %                 windowIndex = max(1, min(obj.sample2window(obj.durationSec-durSec),obj.sample2window(windowRange(1))));
                windowIndex = obj.sample2window(windowRange(1));
                obj.setCurWindow(windowIndex);
            else
                durSec = obj.getSetting('windowDurSec');
            end
        end

        % --------------------------------------------------------------------
        %> @brief Returns the visible instance variable
        %> @param obj Instance of PASensorData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this is not)
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval visibileStruct A struct of obj's visible field values
        % --------------------------------------------------------------------
        function visibleOut = getVisible(obj,varargin)
            visibleOut = obj.getSetting('visible',varargin{:});
            visibleOut = appendKeyToStruct(visibleOut, 'visible');
        end

        % --------------------------------------------------------------------
        %> @brief Returns the color instance variable
        %> @param obj Instance of PASensorData
        %> @param structTypeOrTag String specifying the structure type of
        %> label to retrieve, or the tag of the line handle to use.
        %> Possible values include (all are included if this is not)
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @li Stringg with tag line of line handle to obtain
        %> color of.  Example 'timeSeries.accel.count.z'
        %> @retval colorOut Depends on structType parameter.
        %> @li A struct of color values correspodning to the time series
        %> fields of obj.color.
        %> @li 1x3 RGB color matrix.
        % --------------------------------------------------------------------
        function colorOut = getColor(obj,varargin)
            colorOut = obj.getSetting('color',varargin{:});
            colorOut = appendKeyToStruct(colorOut,'color');
        end

        % --------------------------------------------------------------------
        %> @brief Returns the scale instance variable
        %> @param obj Instance of PASensorData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this not):
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval scaleStruct A struct of scalar values corresponding to the time series
        %> fields of obj.settings.scale or possible a scalar value
        %> corresponding to the specified field if given as an argument.
        % --------------------------------------------------------------------
        function scaleOut = getScale(obj,varargin)
            scaleOut = obj.getSetting('scale',varargin{:});            
        end

        % --------------------------------------------------------------------
        %> @brief Returns the offset instance variable
        %> @param obj Instance of PASensorData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this not):
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval offsetStruct A struct of scalar values corresponding to the struct type
        %> fields of obj.offset.
        % --------------------------------------------------------------------
        function offsetOut = getOffset(obj,varargin)
            offsetOut = obj.getSetting('offset',varargin{:});            
        end

        % --------------------------------------------------------------------
        %> @brief Returns the label instance variable
        %> @param obj Instance of PASensorData
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include:
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval labelStruct A struct of string values which serve to label the correspodning to the time series
        %> fields of obj.label.
        % --------------------------------------------------------------------
        function labelOut = getLabel(obj,varargin)
            labelOut = obj.getSetting('label',varargin{:});
            labelOut = appendKeyToStruct(labelOut,'string');
        end

        % --------------------------------------------------------------------
        %> @brief Returns the property requested in the format requested.
        %> @param obj Instance of PASensorData
        %> @param structTypeOrTag String specifying the structure type of
        %> label to retrieve, or the tag of the line handle to use.
        %> Possible values include (all are included if this is not)
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @li String with tag line of line handle to obtain
        %> color of.  Example 'timeSeries.accel.count.z'
        %> @retval propOut Depends on structType parameter.
        %> @li A struct of property values corresponding to the time series
        %> fields of obj.(propToGet).
        %> @li The property value corresponding to obj.(propToGet).(structTypeOrTag)
        function value = getSetting(obj,fieldToGet,structTypeOrTag)
            if(nargin<3)
                structTypeOrTag = [];
            end
            if(any(structTypeOrTag=='.'))
                value = eval(sprintf('obj.settings.%s.%s',fieldToGet,structTypeOrTag));
                if(isstruct(value))
                    fields = fieldnames(value);
                    % should only be one value
                    if(numel(fields)==1)
                        fieldToGet = fields{1};
                    end
                    % otherwise, default to the original propToGet for the
                    % field name to retrieve.
                    value = value.(fieldToGet);
                end
            else
                value = obj.getSettingStruct(fieldToGet,structTypeOrTag);
            end
            if(isa(value, 'PAParam'))
                value = value.value;
            end
        end

        %> @brief Retuns the accelType that is not set.  This is useful in
        %> later removing unwanted accel fields.
        %> @param obj Instance of PASensorData.
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
            elseif(strcmpi(accelTypeStr,'mims'))
                offAccelType = [];
            elseif(strcmpi(accelTypeStr,'all'))
                offAccelType = [];                
            elseif(strcmpi(accelTypeStr,'none'))
                offAccelType = [];
            else
                fprintf('Unrecognized accelTypeStr (%s)\n',accelTypeStr);
                offAccelType = [];
            end
        end

        % --------------------------------------------------------------------
        %> @brief Returns the visible instance variable
        %> @param obj Instance of PASensorData
        %> @param propertyName Name of instance variable being requested.
        %> @param structType String specifying the structure type of label to retrieve.
        %> Possible values include (all are included if this is not)
        %> @li @c timeSeries (default)
        %> @li @c features
        %> @li @c bins
        %> @retval visibileStruct A struct of obj's visible field values
        % --------------------------------------------------------------------
        function propertyStruct = getSettingStruct(obj,fieldName,structType)
            if(nargin<3 || isempty(structType))
                propertyStruct = obj.settings.(fieldName);
            else
                propertyStruct = obj.settings.(fieldName).(structType);
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
        %> @param obj Instance of PASensorData
        %> @param fieldName Dynamic field name to set in the 'offset' struct.
        %> @note For example if fieldName = 'timeSeries.vecMag' then
        %> obj.offset.timeSeries.vecMag = newOffset; is evaluated.
        %> @param newOffset y-axis offset to set obj.offset.(fieldName) to.
        % --------------------------------------------------------------------
        function varargout = setOffset(obj,fieldName,newOffset)
            eval(['obj.settings.offset.',fieldName,' = ',num2str(newOffset),';']);
            if(nargout>0)
                varargout = cell(1,nargout);
            end
        end

        % --------------------------------------------------------------------
        %> @brief Sets the scale instance variable for a particular sub
        %> field.
        %> @param obj Instance of PASensorData
        %> @param fieldName Dynamic field name to set in the 'scale' struct.
        %> @note For example if fieldName = 'timeSeries.vecMag' then
        %> obj.scale.timeSeries.vecMag = newScale; is evaluated.
        %> @param newScale Scalar value to set obj.scale.(fieldName) to.
        % --------------------------------------------------------------------
        function varargout = setScale(obj,fieldName,newScale)
            evtData = LinePropertyChanged_EventData(fieldName,'scale',newScale,obj.getScale(fieldName));

            eval(['obj.settings.scale.',fieldName,' = ',num2str(newScale),';']);
            if(nargout>0)
                varargout = cell(1,nargout);
            end
            obj.notify('LinePropertyChanged',evtData);

        end

        % --------------------------------------------------------------------
        %> @brief Sets the color instance variable for a particular sub
        %> field.
        %> @param obj Instance of PASensorData
        %> @param fieldName Dynamic field name to set in the 'color' struct.
        %> @note For example if fieldName = 'timeSeries.accel.vecMag' then
        %> obj.color.timeSerie.accel.vecMag = newColor; is evaluated.
        %> @param newColor 1x3 vector to set obj.color.(fieldName) to.
        % --------------------------------------------------------------------
        function varargout = setColor(obj,fieldName,newColor)
            evtData = LinePropertyChanged_EventData(fieldName,'color',newColor,obj.getColor(fieldName));
            eval(['obj.settings.color.',fieldName,' = [',num2str(newColor),']',';']);
            if(nargout>0)
                varargout = cell(1,nargout);
            end
            obj.notify('LinePropertyChanged',evtData);
        end

        %> @brief
        %> @param obj - Instance of PASensorData
        %> @param fieldName - Tag (string) of line to the set the label
        %> for.
        %> @param newLabel - String identifying the new label to associate
        %> and display for the given tag line
        function varargout = setLabel(obj,fieldName,newLabel)
            evtData = LinePropertyChanged_EventData(fieldName,'label',newLabel,obj.getLabel(fieldName));

            eval(['obj.settings.label.',fieldName,' = ''',newLabel,''';']);
            if(nargout>0)
                varargout = cell(1,nargout);
            end
            obj.notify('LinePropertyChanged',evtData);
        end

        % --------------------------------------------------------------------
        %> @brief Sets the visible instance variable for a particular sub
        %> field.
        %> @param obj Instance of PASensorData
        %> @param fieldName Dynamic field name to set in the 'visible' struct.
        %> @param newVisibilityStr Visibility property value.
        %> @note Valid values include
        %> - @c on
        %> - @c off
        % --------------------------------------------------------------------
        function varargout = setVisible(obj,fieldName,newVisibilityStr)
            if(strcmpi(newVisibilityStr,'on')||strcmpi(newVisibilityStr,'off'))
                evtData = LinePropertyChanged_EventData(fieldName,'visible',newVisibilityStr,obj.getVisible(fieldName));
                eval(['obj.settings.visible.',fieldName,' = ''',newVisibilityStr,''';']);
                obj.notify('LinePropertyChanged',evtData);
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
        %> @param obj Instance of PASensorData
        %> @param propertyName instance variable to set the property of.
        %> @param fieldName Dynamic field name to set in the propertyName struct.
        %> @param propertyValueStr String value of property to set fieldName
        %> to.
        %>
        %> @example setSettingValue('color','timeSeries.count.x','r')
        % --------------------------------------------------------------------
        function varargout = setSettingValue(obj,settingName,fieldName,valueStr)
            eval(['obj.settings.',settingName,'.',fieldName,' = ',valueStr,';']);
            
            % Not sure about the [] argument here.  Untested @hyatt4
            % 8/4/2019
            evtData = LinePropertyChanged_EventData(fieldName,settingName,valueStr,[]);
            obj.notify('LinePropertyChanged',evtData);                
            if(nargout>0)
                varargout = cell(1,nargout);
            end
        end

        function accelType = getAccelType(obj)
            if(isempty(obj.accelType))
                accelType = 'none';
            else
                accelType = obj.accelType;
            end

        end

        % --------------------------------------------------------------------
        %> @brief Returns the total number of windows the data can be divided
        %> into based on sampling rate, window resolution (i.e. duration), and the size of the time
        %> series data.
        %> @param obj Instance of PASensorData
        %> @retval windowCount The maximum/last window allowed
        %> @note In the case of data size is not broken perfectly into windows, but has an incomplete window, the
        %> window count is rounded up.  For example, if the time series data is 10 s in duration and the window size is
        %> defined as 30 seconds, then the windowCount is 1.
        % --------------------------------------------------------------------
        function windowCount = getWindowCount(obj)
            windowCount = ceil(obj.durationSec/obj.getSetting('windowDurSec'));
        end

        % --------------------------------------------------------------------
        %> @brief Returns the start and stop datenums for the study.
        %> @param obj Instance of PASensorData
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
        %> @param obj Instance of PASensorData.
        %> @retval yLim 1x2 vector containing ymin and ymax.
        % ======================================================================
        function yLim = getDisplayMinMax(obj)
            yLim = [0, 20 ]*obj.settings.yDelta;
        end

        % ======================================================================
        %> @brief Returns the minmax value(s) for the object's (obj) time series data
        %> Returns either a structure or 1x2 vector of [min, max] values for the field
        %> specified.
        %> @param obj Instance of PASensorData.
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
        %> @brief Returns the protected intance variable windowDurSec.
        %> @param obj Instance of PASensorData
        %> @retval windowDurationSec The value of windowDurSec
        % =================================================================
        function windowDurationSec = getWindowDurSec(obj)
            windowDurationSec = obj.getSetting('windowDurSec');
        end


        % ======================================================================
        %> @brief Load CSV header values (start time, start date, and window
        %> period).
        %> @param obj Instance of PASensorData.
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
                        fs = regexp(tline,'.* at (\d+) Hz .*','tokens');

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

                        % Window period (hh:mm:ss) 00:00:01
                        tline = fgetl(fid);
                        tmpPeriod = sscanf(tline,'Epoch Period (hh:mm:ss) %u:%u:%u');
                        obj.countPeriodSec = [3600,60,1]*tmpPeriod(:);

                        if(~isempty(fs))
                            obj.sampleRate = str2double(fs{1}{1});
                        else
                            if(obj.countPeriodSec~=0)
                                obj.sampleRate = 1/obj.countPeriodSec;
                            else
                                obj.sampleRate = obj.countPeriodSec;
                            end
                        end

                        % Pull the following line from the file and convert hh:mm:ss
                        % to total seconds
                        %  Window Period (hh:mm:ss) 00:00:01
                        % [a, c]=fscanf(fid,'%*s %*s %*s %d:%d:%d');  %
                        % This causes a read of the second line as well->
                        % which is very strange.  So don't use this way.
                        % obj.countPeriodSec = [3600 60 1]* a;

                        tline = fgetl(fid);
                        exp = regexp(tline,'^Download Time (.*)','tokens');
                        if(~isempty(exp))
                            obj.stopTime = exp{1}{1};
                        else
                            obj.stopTime = 'N/A';
                        end
                        %  Download Date 1/23/2014
                        tline = fgetl(fid);
                        obj.stopDate = strrep(tline,'Download Date ','');
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
        %> @param obj Instance of PASensorData.
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
        %> @param obj Instance of PASensorData.
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
            
            [~,~, fileExt] = fileparts(fullfilename);
            if strcmpi(fileExt, '.mims')
                didLoad = obj.loadMimsFile(fullfilename);                
            else
                didLoad = obj.loadActigraphFile(fullfilename);
            end
        end

        % Format String
        % %e - elapsed seconds
        % %x - x-axis
        % %y - y-axis
        % %z - z-axis
        function didLoad = loadCustomRawFile(obj, fullfilename, fmtStruct)
            try
                if(nargin<3)
                    fmtStruct = obj.getDefaultCustomFmtStruct();
                end

                fid = fopen(fullfilename);
                if(fid>1)
                    fmtStr = '';
                    for k=1:numel(fmtStruct.fieldOrder)
                        fname = fmtStruct.fieldOrder{k};
                        if(strcmpi(fname,'datetime') && strcmpi(fmtStruct.datetimeType,'datetime'))
                            fmtStr = [fmtStr,'%{',fmtStruct.datetimeFmtStr,'}D'];
                        else
                            fmtStr = [fmtStr,'%f'];
                        end
                    end

                    C = textscan(fid,fmtStr,'delimiter',fmtStruct.delimiter,'headerlines',fmtStruct.headerLines);

                    dateColumn = C{fmtStruct.datetime};
                    if(strcmpi(fmtStruct.datetimeType,'datetime'))
                        datenumFound = datenum(dateColumn,fmtStruct.datetimeFmtStr);
                    elseif(strcmpi(fmtStruct.datetimeType,'elapsed'))
                        datenumFound = datenum(2001,9,11,0,0,0)+dateColumn/24/3600;
                    else
                        % not handled
                        throw(MException('PA:Unhandled','Unhandled date time format'));
                    end

                    datevecFound = datevec(datenumFound);
                    startDatenum = datenumFound(1);
                    stopDatenum = datenumFound(end);
                    obj.sampleRate = 1/(median(diff(datenumFound))*24*3600);   % datenum has units in day.
                    obj.startDate = datestr(startDatenum,'mm/dd/yyyy');
                    obj.startTime = datestr(startDatenum,'HH:MM:SS.FFF');
                    obj.stopDate = datestr(stopDatenum,'mm/dd/yyyy');
                    obj.stopTime = datestr(stopDatenum,'HH:MM:SS.FFF');

                    tmpDataCell = {C{fmtStruct.x},C{fmtStruct.y},C{fmtStruct.z}};
                    samplesFound = numel(tmpDataCell{1}); %size(dateVecFound,1);

                    %                     obj.sampleRate =
                    %start, stop and delta date nums
                    windowDatenumDelta = datenum([0,0,0,0,0,1/obj.sampleRate]);


                    [tmpDataCell, obj.dateTimeNum] = obj.mergedCell(startDatenum,stopDatenum,windowDatenumDelta,datevecFound,tmpDataCell,obj.getSetting('missingValue'));

                    obj.durSamples = numel(obj.dateTimeNum);
                    obj.durationSec = floor(obj.getDurationSamples()/obj.sampleRate);


                    obj.setRawXYZ(tmpDataCell{1},tmpDataCell{2},tmpDataCell{3});

                    obj.printLoadStatusMsg(samplesFound, fullfilename);

                    didLoad = true;

                    fclose(fid);
                else
                    didLoad = false;
                end
            catch me
                showME(me);
                didLoad = false;
            end
        end

        function printLoadStatusMsg(obj, samplesFound, fullFilename)
            if(obj.getDurationSamples()==samplesFound)
                fprintf('%d rows loaded from %s\n',samplesFound,fullFilename);
            else
                numMissing = obj.getDurationSamples() - samplesFound;
                if(numMissing>0)
                    fprintf('%d rows loaded from %s.  However %u rows were expected.  %u missing samples are being filled in as %s.\n',samplesFound,fullFilename,samplesFound+numMissing,numMissing,num2str(obj.getSetting('missingValue')));
                else
                    obj.logWarning(['This case is not handled yet.\n%d rows found in %s.  However %u rows were loaded.\n',...
                        'Most likely %u samples were removed during loading because they did not have valid timestamps.',...
                        '\nSee log for more information.'],samplesFound,fullFilename,obj.getDurationSamples(),-numMissing);
                end
            end
        end

        function didLoad = loadCustomRawCSVFile(obj,fullfilename, fmtStruct)
            fmtStruct.delimiter = ',';
            didLoad = obj.loadCustomRawFile(fullfilename, fmtStruct);
        end
        
        % writes an actigraph .csv file with raw acceleration values
        function didWrite = writeActigraphRawCSV(obj, outputFilename, varargin)
            defaults.start_datenum = obj.dateTimeNum(1);
            defaults.stop_datenum = obj.dateTimeNum(end);            
            defaults.include_header = true;
            defaults.dry_run = false;
            defaults.actilife_version = '';
            defaults.export_timestamp = false;
            params = parse_pv_pairs(defaults, varargin);
            
            if isempty(params.start_datenum)
                params.start_datenum = obj.dateTimeNum(1);
            end
            
            if isempty(params.stop_datenum)
                params.stop_datenum = obj.dateTimeNum(end);
            end
            
            didWrite = false;
            
            if isempty(params.actilife_version)
                if params.export_timestamp
                    params.actilife_version = 'v6.11.4';
                else
                    params.actilife_version = 'v6.13.3';
                end
            else
                params.export_timestamp = isVerLessThan(params.actilife_version, 'v6.12.0');
            end
            
            if params.dry_run
                fid = 1;
            elseif params.include_header
                % Overwrite if it exists
                fid = fopen(outputFilename,'w');
            else
                % Append if it exists
                fid = fopen(outputFilename,'a');
            end
            if fid < 1
                obj.logWarning('Cannot open output file for writing actigraph data as comma-separated values: %s', outputFilename);
            else
                try
                    if params.include_header
                       headerStr = generateActigraphRawHeader(params.start_datenum, 'sampling_frequency', obj.sampleRate,...
                           'actilife_version', params.actilife_version);
                       fprintf(fid,'%s\n', headerStr);
                    end 
                    
                    % ZERO FILL
                    % This could fill your hard drive :(
                    datenum_delta = datenum(0, 0, 0, 0, 0, 1/obj.sampleRate);
                    if params.start_datenum < obj.dateTimeNum(1)
                        % zero pad the file until you are ready
                        time_stamps = params.start_datenum:datenum_delta:obj.dateTimeNum(1)-datenum_delta;
                        
                        if params.export_timestamp
                            fprintf(1,'Creating timestamps for %0.2f days\n', numel(time_stamps)/obj.sampleRate/3600/24);                        
                            tic
                            time_stamps_str = datestr(time_stamps, 'mm/dd/YYYY HH:MM:SS.FFF');
                            toc                            
                        end
                        
                        update_intervals = mod(1:numel(time_stamps),obj.sampleRate*3600*12)==1; % every 12 hours
                        numUpdates = sum(update_intervals);
                        fprintf(1,'Expected:\t%s\n',repmat('|',1,numUpdates));
                        fprintf(1,'Progress:\t');
                        if params.export_timestamp
                            
                            tic
                            for t=1:numel(time_stamps)
                                % 10/7/2012 00:00:00.000,0.27,-0.126,0.974
                                % fprintf(fid, '%s,0,0,0\n',datestr(time_stamps(t),'mm/dd/YYYY HH:MM:SS.FFF'));
                                
                                fprintf(fid, '%s,0,0,0\n',time_stamps_str(t,:));
                                if update_intervals(t)
                                    fprintf(1, '|');
                                end
                            end
                            fprintf(1,'\n');
                            toc
                        else
                            for t=1:numel(time_stamps)                                
                                fprintf(fid, '0,0,0\n');
                                if update_intervals(t)
                                    fprintf(1, '|');
                                end
                            end
                            fprintf(1,'\n');                            
                        end
                        cur_timestamp = obj.dateTimeNum(1);
                    else
                        cur_timestamp = params.start_datenum;
                    end
                    
                    % TRANSFER
                    start_index = find(obj.dateTimeNum==cur_timestamp, 1);
                    if params.stop_datenum > obj.dateTimeNum(end)
                        stop_index = numel(obj.dateTimeNum);
                    elseif params.stop_datenum > params.start_datenum
                        stop_index = find(obj.dateTimeNum==params.stop_datenum, 1);
                    else
                        stop_index = [];
                    end
                    
                    indices = start_index:stop_index;
                    if params.export_timestamp
                        fprintf(1,'Creating timestamps for %0.2f days\n', numel(indices)/obj.sampleRate/3600/24);
                        tic
                        time_stamps_str = datestr(obj.dateTimeNum(indices), 'mm/dd/YYYY HH:MM:SS.FFF');
                        toc
                    end
                    
                    update_intervals = mod(1:numel(indices),obj.sampleRate*3600*12)==1; % every 12 hours                    
                    numUpdates = sum(update_intervals);                    
                    fprintf(1,'Expected:\t%s\n',repmat('|',1,numUpdates));
                    fprintf(1,'Progress:\t');
                    
                    if params.export_timestamp
                        % time_stamps_str = datestr(obj.dateTimeNum(indices), 'mm/dd/YYYY HH:MM:SS.FFF');                    
                        for t=1:numel(indices)
                            index = indices(t);
                            fprintf(fid, '%s,%0.3f,%0.3f,%0.3f\n',time_stamps_str(t,:), obj.accel.raw.x(index), obj.accel.raw.y(index), obj.accel.raw.z(index));
                            % 10/7/2012 00:00:00.000,0.27,-0.126,0.974                            
                            if update_intervals(t)
                                fprintf(1, '|');
                            end
                        end
                        fprintf(1,'\n');                        
                    else
                        for t=1:numel(indices)
                            index = indices(t);
                            fprintf(fid, '%0.3f,%0.3f,%0.3f\n', obj.accel.raw.x(index), obj.accel.raw.y(index), obj.accel.raw.z(index));
                            if update_intervals(t)
                                fprintf(1, '|');
                            end
                        end
                        fprintf(1,'\n');
                    end
                    cur_timestamp = obj.dateTimeNum(stop_index)+datenum_delta;                    
                        
                    if params.stop_datenum > cur_timestamp
                        % zero pad the until you reach the end
                        time_stamps = cur_timestamp:datenum_delta:params.stop_datenum;
                        if params.export_timestamp
                            fprintf(1,'Creating timestamps for %0.2f days\n', numel(time_stamps)/obj.sampleRate/3600/24);
                            tic
                            time_stamps_str = datestr(time_stamps, 'mm/dd/YYYY HH:MM:SS.FFF');
                            toc
                        end
                        
                        update_intervals = mod(1:numel(time_stamps),obj.sampleRate*3600*12)==1; % every 12 hours
                        numUpdates = sum(update_intervals);
                        fprintf(1,'Expected:\t%s\n',repmat('|',1,numUpdates));
                        fprintf(1,'Progress:\t');
                        if params.export_timestamp
                            % time_stamps_str = datestr(time_stamps, 'mm/dd/YYYY HH:MM:SS.FFF');
                            for t=1:numel(time_stamps)
                                % 10/7/2012 00:00:00.000,0.27,-0.126,0.974
                                fprintf(fid, '%s,0,0,0\n',time_stamps_str(t,:));
                                if update_intervals(t)
                                    fprintf(1, '|');
                                end
                            end
                            fprintf(1,'\n');                             
                        else
                            for t=1:numel(time_stamps)                                
                                fprintf(fid, '0,0,0\n');
                                if update_intervals(t)
                                    fprintf(1, '|');
                                end
                            end
                            fprintf(1,'\n');
                        end
                    end
                    didWrite = true;                    
                catch me
                    showME(me);
                end                
                if fid > 2
                    fclose(fid);
                end                
            end
        end
        
        function didLoad = loadMimsFile(obj, fullfilename)
            didLoad = false;
            
            % Have one file version for counts...
            if(exist(fullfilename,'file'))
                [~, baseName, ~] = fileparts(fullfilename);
                obj.studyID = obj.getStudyIDFromBasename(baseName);
                
                try
                    fid = -1;
                    fid = fopen(fullfilename,'r');
                    if fid>2
                        

                        obj.countPeriodSec = 1;
                        obj.startTime = 'N/A';
                        obj.startDate = 'N/A';
                        if(obj.countPeriodSec~=0)
                            obj.sampleRate = 1/obj.countPeriodSec;
                        else
                            obj.sampleRate = 0;
                        end
                        
                        headerLines = 1; %number of lines to skip
                        % "HEADER_TIME_STAMP","MIMS_UNIT","MIMS_UNIT_X","MIMS_UNIT_Y","MIMS_UNIT_Z"
                        % 2012-10-31 00:00:00.000,0.376399670962783,0.0528390934513008,0.285042889836922,0.0385176876745605
                        % 2012-10-31 00:00:01.000,0.327736275887793,0.0461938669228184,0.245819011001523,0.0357233979634518
                        % 2012-10-31 00:00:02.000,0.123508980491169,0.0173216117600595,0.0922664562901966,0.0139209124409133
                        % 2012-10-31 00:00:03.000,0.194921998680942,0.0278222616326401,0.146223793033541,0.0208759440147609
                        % 2012-10-31 00:00:04.000,0.0353253392880519,0,0.0353253392880519,0
                        
                        % MIMS_UNIT is the sum of x, y, and z.
                        scanFormat = '%{yyyy-MM-dd HH:mm:ss.SSS}D%f%f%f%f';
                        scanFormat = '%{yyyy-MM-dd HH:mm:ss}D%f%f%f%f';
                        % frewind(fid);
                        for f=1:headerLines
                            fgetl(fid);
                        end
                        A  = fread(fid,'*char')';
                        fclose(fid);
                        tmpDataCell = textscan(A, scanFormat, 'delimiter',',');
                        
                        samplesFound = numel(tmpDataCell{1});                     
                        obj.logStatus('Loaded %d entries', samplesFound);
                        
                        datetimeFound = tmpDataCell{1};
                        startDateNum = datenum(datetimeFound(1));
                        stopDateNum = datenum(datetimeFound(end));
                                                
                        windowDateNumDelta = datenum([0,0,0,0,0,obj.countPeriodSec]);                        
                        tmpDataCell(1:2) = []; % NOTE:  Chopping off the first two columns: date time values and sum of mim axes.
                        
                        % The following call to mergedCell ensures the data
                        % is chronologically ordered and data is not missing.
                        [dataCell, obj.dateTimeNum] = obj.mergedCell(startDateNum,stopDateNum,windowDateNumDelta,datetimeFound,tmpDataCell,obj.getSetting('missingValue'));
                        
                        tmpDataCell = []; %free up this memory;
                        
                        %MATLAB has some strange behaviour with date num -
                        %looks to be a precision problem
                        %math.
                        %                        dateTimeDelta2 = diff([datenum(2010,1,1,1,1,10),datenum(2010,1,1,1,1,11)]);
                        %                        dateTimeDelta2 = datenum(2010,1,1,1,1,11)-datenum(2010,1,1,1,1,10); % or this one
                        %                        dateTimeDelta = datenum(0,0,0,0,0,1);
                        %                        dateTimeDelta == dateTimeDelta2  %what is going on here???
                        
                        obj.durSamples = numel(obj.dateTimeNum);
                        obj.printLoadStatusMsg(samplesFound, fullfilename);
                        
                        
                        obj.accel.mims.x = dataCell{1};
                        obj.accel.mims.y = dataCell{2};
                        obj.accel.mims.z = dataCell{3};                        
                        obj.accel.mims.vecMag = sqrt(obj.accel.mims.x.^2+obj.accel.mims.y.^2+obj.accel.mims.z.^2);
                        
                        %either use countPeriodSec or use samplerate.
                        if(obj.countPeriodSec>0)
                            obj.sampleRate = 1/obj.countPeriodSec;
                            obj.durationSec = floor(obj.getDurationSamples()*obj.countPeriodSec);
                        else
                            fprintf('There was an error when loading the window period second value (non-positive value found in %s).\n',fullFilename);
                            obj.durationSec = 0;
                        end
                        
                        obj.accelType = 'mims';
                        obj.hasMims = true;
                        obj.classifyUsageForAllAxes();
                        didLoad = true;
                        
                    else
                        this.logWarning('Unable to load file %s', fullfilename);
                    end
                catch me
                    showME(me);
                    if fid>2
                        fclose(fid);
                    end
                end
            end
        end

        function didLoad = loadActigraphFile(obj, fullfilename)
            didLoad = false;

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
                        
                        % Could have a .csv extension on a 'raw' data file.  We only know by the samping rate, which shows up as 0 in the header field. for gravity/raw data files.
                        obj.loadFileHeader(fullfilename);
                        if obj.countPeriodSec == 0
                            loadFast = true;
                            didLoad = obj.loadRawCSVFile(fullfilename,loadFast);
                            obj.hasRaw = didLoad;
                        else
                            didLoad = obj.loadCountFile(fullCountFilename);
                            
                            if(didLoad)
                                obj.accelType = 'count'; % this is modified, below, to 'all' if a
                                % a raw acceleration file (.csv or
                                % .bin) is being loaded, in which
                                % case the count data is replaced
                                % with the raw data.
                            end
                            obj.hasCounts = didLoad;
                        end
                    end

                    % For .raw files, load the count data first so that it can
                    % then be reshaped by the sampling rate found in .raw
                    if(strcmpi(ext,'.raw'))
                        if(~exist(fullCountFilename,'file'))
                             obj.loadFileHeader(fullfilename);
                        end
                        loadFast = true;
                        % loadFast = false;
                        didLoad = obj.loadRawCSVFile(fullfilename,loadFast);
                        obj.hasRaw = didLoad;
                    elseif(strcmpi(ext,'.bin'))
                        %determine firmware version
                        %                        infoFile = fullfile(pathName,strcat(baseName,'.info.txt'));
                        infoFile = fullfile(pathName,'info.txt');

                        % Is it a padaco exported raw bin file?
                        if(~exist(infoFile,'file'))
                            obj.hasRaw = obj.loadPadacoRawBinFile(fullfilename);
                        else
                            %load meta data from info.txt
                            [infoStruct, firmwareVersion] = obj.parseInfoTxt(infoFile);
                            obj.setFullFilename(fullfilename);

                            if isfield(infoStruct,'Acceleration_Scale')
                                obj.samplesPerG = infoStruct.Acceleration_Scale;
                            end
                            if isfield(infoStruct,'Sample_Rate')
                                obj.sampleRate = infoStruct.Sample_Rate;
                            end
                            if isfield(infoStruct,'Subject_Name')
                                obj.studyID = infoStruct.Subject_Name;
                            end
                            if isfield(infoStruct,'Start_Date')
                                obj.startDate = infoStruct.Start_Date;
                                % obj.startTime = infoStruct.Start_Date;
                            end
                            if isfield(infoStruct,'Stop_Date')
                                obj.stopDate = infoStruct.Stop_Date;
                                % obj.stopTime = infoStruct.Stop_Date;
                            end
                            if isfield(infoStruct,'Last_Sample_Time')
                                % obj.stopTime = infoStruct.Start_Date;
                            end

                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            % Ensure firmware version is either 1.5.0, 1.7.2, 2.2.1, 2.5.0 or 3.1.0
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if ~any(strcmp(firmwareVersion,{'2.5.0','3.1.0','2.2.1','1.5.0','1.7.2'}))
                                fprintf(1,'Firmware version (%s) has not been tested specifically with the Padaco software suite.  It may work fine, or it may not :(.\n',firmwareVersion);
                            end

                            % Version 2.5.0, 1.5.0 firmware
                            if any(strcmp(firmwareVersion,{'2.5.0','1.5.0'}))
                                unitsTimePerDay = 24*3600*10^7;
                                matlabDateTimeOffset = 365+1+1;  %367, 365 days for the first year + 1 day for the first month + 1 day for the first day of the month
                                %start, stop and delta date nums

                                % This uses the unix time stamp - but other
                                % firmware versions do not and use a
                                % Net.Ticks approach it seems.
                                binStartDatenum = str2double(infoStruct.Start_Date)/unitsTimePerDay+matlabDateTimeOffset;

                                if(~isempty(obj.startDate))
                                    countStartDatenum = datenum(strcat(obj.startDate,{' '},obj.startTime),'mm/dd/yyyy HH:MM:SS');

                                    if(binStartDatenum~=countStartDatenum)
                                        fprintf('There is a discrepancy between the start date-time in the count file and the binary file.  I''m not sure what is going to happen because of obj.\n');
                                    end
                                else

                                end

                                didLoad = obj.loadRawActivityBinFile(fullfilename,firmwareVersion, obj.actigraphActitivityID, obj.samplesPerG);

                                if didLoad
                                    obj.durationSec = floor(obj.getDurationSamples()/obj.sampleRate);

                                    binDatenumDelta = datenum([0,0,0,0,0,1/obj.sampleRate]);
                                    binStopDatenum = datenum(binDatenumDelta*obj.durSamples)+binStartDatenum;
                                    synthDateVec = datevec(binStartDatenum:binDatenumDelta:binStopDatenum);
                                    synthDateVec(:,6) = round(synthDateVec(:,6)*1000)/1000;

                                    %This takes 2.0 seconds!
                                    obj.dateTimeNum = datenum(synthDateVec);
                                else
                                    warning('Did not load file! (%s)', fullfilename)
                                end
                            else  % any(strcmp(firmwareVersion,{'3.1.0','2.2.1','1.7.2'}))
                                
                                [axesFloatData, datenums]= getActigraphRecordsFromBin(fullfilename, obj.actigraphActitivityID, obj.samplesPerG, obj.getSampleRate());

                                didLoad = ~isempty(axesFloatData);
                                if didLoad
                                    obj.dateTimeNum = datenums;
                                    obj.setRawXYZ(axesFloatData);
                                    obj.durationSec = floor(obj.getDurationSamples()/obj.sampleRate);
                                else
                                    warning('Did not load file! (%s)', fullfilename)
                                end                                
                            end
                            obj.hasRaw = didLoad;
                        end
                    end
                end
            else
                didLoad = false;
            end

            if(didLoad)
                if(obj.hasRaw && obj.hasCounts)
                    obj.accelType = 'all';
                elseif(obj.hasRaw)
                    obj.accelType = 'raw';
                    % I think everything is inivislbe at this point
                    % already.  
                    %                     obj.setVisible('timeSeries.lux','off');
                    %                     obj.setVisible('timeSeries.steps','off');
                    %                     obj.setVisible('timeSeries.inclinometer.standing','off');
                    %                     obj.setVisible('timeSeries.inclinometer.sitting','off');
                    %                     obj.setVisible('timeSeries.inclinometer.lying','off');
                    %                     obj.setVisible('timeSeries.inclinometer.off','off');
                elseif(obj.hasCounts)
                    obj.accelType = 'count';
                else
                    obj.accelType = [];
                end

                if(obj.hasCounts || obj.hasRaw)
                    obj.classifyUsageForAllAxes();
                end
            end
        end



        % ======================================================================
        %> @brief Loads an accelerometer "count" data file.
        %> @param obj Instance of PASensorData.
        %> @param fullCountFilename The full (i.e. with path) filename to load.
        % =================================================================
        function didLoad = loadCountFile(obj,fullFilename)
            if(exist(fullFilename,'file'))
                fid = fopen(fullFilename,'r');
                if(fid>0)
                    try
                        obj.loadFileHeader(fullFilename);
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

                        % This is a mess -
                        %                         obj.startDate(obj.startDate==',')=[];  %sometimes we get extra commas as files are copy and pasted between other programs (e.g. Excel)
                        %                         obj.startTime(obj.startTime==',')=[];
                        %                         startDateNum = datenum(strcat(obj.startDate,{' '},obj.startTime),'mm/dd/yyyy HH:MM:SS');

                        % Trust the timestamps per record instead; even if they may get out of order?
                        startDateNum = datenum(dateVecFound(1,:));

                        stopDateNum = datenum(dateVecFound(end,:));

                        windowDateNumDelta = datenum([0,0,0,0,0,obj.countPeriodSec]);


                        % NOTE:  Chopping off the first six columns: date time values;
                        tmpDataCell(1:6) = [];

                        % The following call to mergedCell ensures the data
                        % is chronologically ordered and data is not
                        % missing.
                        [dataCell, obj.dateTimeNum] = obj.mergedCell(startDateNum,stopDateNum,windowDateNumDelta,dateVecFound,tmpDataCell,obj.getSetting('missingValue'));

                        tmpDataCell = []; %free up this memory;

                        %MATLAB has some strange behaviour with datenum -
                        %looks to be a precision problem
                        %math.
                        %                        dateTimeDelta2 = diff([datenum(2010,1,1,1,1,10),datenum(2010,1,1,1,1,11)]);
                        %                        dateTimeDelta2 = datenum(2010,1,1,1,1,11)-datenum(2010,1,1,1,1,10); % or this one
                        %                        dateTimeDelta = datenum(0,0,0,0,0,1);
                        %                        dateTimeDelta == dateTimeDelta2  %what is going on here???

                        obj.durSamples = numel(obj.dateTimeNum);
                        obj.printLoadStatusMsg(samplesFound, fullFilename);


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
                            obj.durationSec = floor(obj.getDurationSamples()*obj.countPeriodSec);
                        else
                            fprintf('There was an error when loading the window period second value (non-positive value found in %s).\n',fullFilename);
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
                    fprintf('Warning - could not open %s for reading!\n',fullFilename);
                    didLoad = false;
                end
            else
                fprintf('Warning - %s does not exist!\n',fullFilename);
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
        %> @param obj Instance of PASensorData.
        %> @param fullRawCSVFilename The full (i.e. with path) filename for raw data to load.
        % =================================================================
        function didLoad = loadRawCSVFile(obj,fullFilename, loadFastOption)
            if(nargin<3 || isempty(loadFastOption))
                loadFastOption = false;
            end
            if(exist(fullFilename,'file'))
                try
                    if(~exist('loadrawcsv','file')==3) % If the mex file exists and is compiled
                    
                        tic
                        rawMat = loadrawcsv(fullFilename, loadFastOption)';  %loadrawcsv loads rows as columns so we need to transpose the results.
                        toc
                        %Date time handling
                        if(loadFastOption)
                            tmpDataCell = {rawMat(:,1),rawMat(:,2),rawMat(:,3)};
                        else
                            dateVecFound = double([rawMat(:,3),rawMat(:,1),rawMat(:,2),rawMat(:,4),rawMat(:,5),rawMat(:,6)]);
                            tmpDataCell = {rawMat(:,7),rawMat(:,8),rawMat(:,9)};
                        end
                    else
                        closeOnExit = false;
                        [fileHeader, fid] = obj.getActigraphCSVFileHeader(fullFilename, closeOnExit);                        
                        if(fid>0)
                            delimiter = ',';
                            % header = 'Date	 Time	 Axis1	Axis2	Axis3
                            headerLines = 0; %number of lines to skip - 0 if we have opened up the file and extracted the header, 11 otherwise
                            
                            if fileHeader.numColumns == 3                                
                                scanFormat = '%f32 %f32 %f32';                                
                            else
                            
                                %                        scanFormat = '%s %f32 %f32 %f32'; %load as a 'single' (not double) floating-point number
                                if(loadFastOption)
                                    scanFormat = '%*f/%*f/%*f %*f:%*f:%*f %f32 %f32 %f32'; %reads the '/' character from the stream, and throws it away.
                                else
                                    scanFormat = '%f/%f/%f %f:%f:%f %f32 %f32 %f32';
                                end
                            end
                            tic
                            tmpDataCell = textscan(fid,scanFormat,'delimiter',delimiter,'headerlines',headerLines);
                            toc
                            %Date time handling

                            if ~loadFastOption && fileHeader.numColumns ~=3
                                dateVecFound = double([tmpDataCell{3},tmpDataCell{1},tmpDataCell{2},tmpDataCell{4},tmpDataCell{5},tmpDataCell{6}]);
                                %dateVecFound = datevec(tmpDataCell{1},'mm/dd/yyyy HH:MM:SS.FFF');

                                % NOTE:  Chopping off the first six columns: date time values;
                                tmpDataCell(1:6) = [];
                            end

                            fclose(fid);

                        else
                            fprintf('Warning - could not open %s for reading!\n',fullFilename);
                            % didLoad = false;
                            MException('MATLAB:Padaco:FileIO','Could not open file for reading');
                        end
                    end

                    samplesFound = numel(tmpDataCell{1}); %size(dateVecFound,1);

                    %start, stop and delta date nums
                    startDateNum = datenum(strcat(obj.startDate,{' '},obj.startTime),'mm/dd/yyyy HH:MM:SS');
                    windowDateNumDelta = datenum([0,0,0,0,0,1/obj.sampleRate]);

                    if(loadFastOption)
                        %stopDateNum = datenum(strcat(obj.stopDate,{' '},obj.stopTime),'mm/dd/yyyy HH:MM:SS');
                        stopDateNum = startDateNum + (samplesFound-1)/obj.sampleRate/24/3600; % or startDateNum+windowDateNumDelta*samplesFound
                        obj.dateTimeNum = datespace(startDateNum,stopDateNum,windowDateNumDelta);                        
                    else
                        zeroTimes = sum(dateVecFound,2)==0;
                        numZero = sum(zeroTimes);
                        % Some files end up with zero values here at the
                        % end, which is curious.
                        if numZero>0
                            obj.logWarning('%d samples had a timestamp of 0.', numZero);
                            dateVecFound(zeroTimes, :) = [];
                            tmpDataCell{1}(zeroTimes) = [];
                            tmpDataCell{2}(zeroTimes) = [];
                            tmpDataCell{3}(zeroTimes) = [];
                        end
                        dateVecFound(:,end) = round(dateVecFound(:,end), 4);  % avoid some numerical round off so we can keep it to 40 Hz resolution as derived synthetically
                        % otherwise I run into issues like
                        % 0.003725000000000 (synthetic value) versus
                        % 0.003724999904633 (sampled value)
                        % Or 
                        % 16.575001000000000 (sampled) versus
                        % 16.574999999999999 (synthetic)
                        stopDateNum = datenum(dateVecFound(end,:));
                        [tmpDataCell, obj.dateTimeNum] = obj.mergedCell(startDateNum,stopDateNum,windowDateNumDelta,dateVecFound,tmpDataCell,obj.getSetting('missingValue'));
                        
                    end

                    obj.durSamples = numel(obj.dateTimeNum);
                    obj.durationSec = floor(obj.durSamples/obj.sampleRate);                    

                    obj.setRawXYZ(tmpDataCell{1},tmpDataCell{2},tmpDataCell{3});

                    obj.printLoadStatusMsg(samplesFound, fullFilename);


                    % No longer think resampling count data is the way to
                    % go here.
                    if(obj.hasCounts)
                        obj.resampleCountData();
                    end
                    didLoad = true;
                catch me
                    showME(me);
                    didLoad = false;
                    if(exist('fid','var'))
                        fclose(fid);
                    end
                end
            else
                fprintf('Warning - %s does not exist!\n',fullFilename);
                didLoad = false;
            end
        end

        % ======================================================================
        %> @brief Loads an accelerometer's raw data from binary files stored
        %> in the path name given.
        %> @param obj Instance of PASensorData.
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
        %> @param obj Instance of PASensorData.
        %> @param pathWithRawBinaryFiles Name of the path (a string) that
        %> contains raw acceleromater data stored in one or more binary files.
        %> @note Currently, only two firmware versions are supported:
        %> - 2.5.0
        %> - 3.1.0
        % =================================================================
        function didLoad = loadPathOfRawBinary(obj, pathWithRawBinaryFiles, firmwareVersion)
            if nargin<3
                infoFile = fullfile(pathWithRawBinaryFiles,'info.txt');
                if(~exist(infoFile,'file'))
                    firmwareVersion = '???';
                else
                    %load meta data from info.txt
                    [~, firmwareVersion] = obj.parseInfoTxt(infoFile);
                end
            end

            % Determine the .bin file based on the firmware            
            if strcmp(firmwareVersion,'2.5.0')
                fullBinFilename = fullfile(pathWithRawBinaryFiles,'activity.bin');
            elseif any(strcmp(firmwareVersion,{'3.1.0','1.5.0','1.7.2'}))
                fullBinFilename = fullfile(pathWithRawBinaryFiles,'log.bin');
            else
                % for future firmware version loaders
                warndlg(sprintf('Attempting to load data from untested firmware version (%s)',firmwareVersion));
                fullBinFilename = fullfile(pathWithRawBinaryFiles,'log.bin');
            end
            didLoad = obj.loadActigraphFile(fullBinFilename);
        end


        % ======================================================================
        %> @brief Resamples previously loaded 'count' data to match sample rate of
        %> raw accelerometer data that has been loaded in a following step (see loadFile()).
        %> @param obj Instance of PASensorData.       %
        %> @note countPeriodSec, sampleRate, steps, lux, and accel values
        %> must be set in advance of this call.
        % ======================================================================
        function setRawXYZ(obj, rawXorXYZ, rawY, rawZ)
            if(nargin==2)
                if(size(rawXorXYZ,1)==3 && size(rawXorXYZ,2)>3)
                    rawXorXYZ = rawXorXYZ';
                end
                rawY = rawXorXYZ(:,2);
                rawZ = rawXorXYZ(:,3);
                rawX = rawXorXYZ(:,1);
            elseif(nargin==4)
                rawX = rawXorXYZ;
            end
            obj.accel.raw.x = rawX;
            obj.accel.raw.y = rawY;
            obj.accel.raw.z = rawZ;
            obj.accel.raw.vecMag = sqrt(obj.accel.raw.x.^2+obj.accel.raw.y.^2+obj.accel.raw.z.^2);
            obj.durSamples = numel(rawX);
        end


        % ======================================================================
        %> @brief Resamples previously loaded 'count' data to match sample rate of
        %> raw accelerometer data that has been loaded in a following step (see loadFile()).
        %> @param obj Instance of PASensorData.       %
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
        %> @param obj Instance of PASensorData.
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
                windowDurSec = obj.getSetting('windowDurSec');
            end
            window = ceil(sample/(windowDurSec*samplerate));
        end

        % ======================================================================
        %> @brief Returns the display window for the given datenum
        %> @param obj Instance of PASensorData.
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
            window = ceil(elapsedSec/obj.getSetting('windowDurSec'));
        end


        % ======================================================================
        %> @brief Returns the starting datenum for the window given.
        %> @param obj Instance of PASensorData.
        %> @param windowSample Index of the window to check.       %
        %> @retval dateNum the datenum value at the start of windowSample.
        %> @note The starting point is adjusted based on obj startDatenum
        %> value and its windowDurSec instance variable.
        % ======================================================================
        function dateNum = window2datenum(obj,windowSample)
            elapsed_time_sec = (windowSample-1) * obj.getSetting('windowDurSec');
            startStopDatenum = obj.getStartStopDatenum();
            dateNum  = startStopDatenum(1)+datenum([0,0,0,0,0,elapsed_time_sec]);
        end



        % ======================================================================
        %> @brief Prefilters accelerometer data.
        %> @note Not currently implemented.
        %> @param obj Instance of PASensorData.
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
        
        function signal = getSignalFromTagLine(obj, signalTagLine)
            try
                signalTagLine = strrep(signalTagLine, 'timeSeries.', ''); % for backward compatibility.
                data = obj.getStruct('all');
                signal = eval(['data.',signalTagLine]);
            catch me
                showME(me)
                signal = [];
            end
        end

        % ======================================================================
        %> @brief Extracts features from the identified signal using the
        %> given method.
        %> @param obj Instance of PASensorData.
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

                usageVec = [];
                if isstruct(obj.usage) && isfield(obj.usage, axisName)
                    usageVec = obj.usage.(axisName);
                end
            catch me
                rethrow(me);  %this is just for debugging.
            end

            [currentNumFrames, frameableSamples] = obj.getFrameCount();
            %frameableSamples = obj.getFrameableSampleCount();

            % recalculate based on a change in frame size ...
            if(currentNumFrames~=obj.numFrames)
                obj.numFrames = currentNumFrames;

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

            obj.usageFrames =  reshape(usageVec(1:frameableSamples), [], obj.numFrames);  %each frame consists of a column of data.  Consecutive columns represent consecutive frames.

            obj.frames =  reshape(data(1:frameableSamples), [], obj.numFrames);  %each frame consists of a column of data.  Consecutive columns represent consecutive frames.
            % Frames are stored in consecutive columns.  Thus the rows
            % represent the consecutive samples of data for that frame
            % Feature functions operate along columns (i.e. down the rows) and the output is then
            % transposed to produce a final, feature vector (1 row)
            data = obj.frames;
            obj.frames_signalTagLine = signalTagLine;

            switch(lower(method))
                case 'none'
                case {'all', 'all_sans_psd', 'all_sans_psd_usagestate'}
                    obj.features.rms = sqrt(mean(data.^2))';
                    obj.features.mean = mean(data)';
                    obj.features.meanad = mean_abs_dev(data);
                    obj.features.medianad = median_abs_dev(data)';
                    % obj.features.meanad = mad(data,0)';
                    % obj.features.medianad = mad(data,1)';
                    obj.features.median = median(data)';
                    obj.features.sum = sum(data)';
                    obj.features.var = var(data)';
                    obj.features.std = std(data)';
                    obj.features.mode = mode(data)';
                    if ~strcmpi(method, 'all_sans_psd_usagestate')
                        obj.features.usagestate = mode(obj.usageFrames)';
                    end
                    if strcmpi(method, 'all')
                        obj.calculatePSD(signalTagLine);
                    end
                    %                    obj.features.count = obj.getCount(data)';
                case 'psd'
                    obj.calculatePSD(signalTagLine);
                case 'usagestate'
                    obj.features.usagestate = mode(obj.usageFrames)';
                otherwise
                    featureVector = obj.calcFeatureVectorFromFrames(data,method);
                    if(~isempty(featureVector))
                        obj.features.(method) = featureVector;
                    else
                        
                    end
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
        %> @brief Calculates the number of complete days and the number of
        %> incomplete days available in the data for the most recently
        %> defined feature vector.
        %> @param obj Instance of PASensorData
        %> @param featureFcn Function name or handle to use to obtain
        % --------------------------------------------------------------------
        function [completeDayCount, incompleteDayCount, totalDayCount] = getDayCount(obj,elapsedStartHour, intervalDurationHours)
            if(nargin<3)
                intervalDurationHours=24;
                if(nargin<2)
                    elapsedStartHour = 0;
                end
            end


            totalDayCount = 0;
            incompleteDayCount = 0;
            completeDayCount = 0;

            if(~isempty(obj.startDatenums))
                frameDurationInHours = obj.getFrameDurationInHours();
                totalDayCount = ceil(obj.startDatenums(end))-floor(obj.startDatenums(1)); %round up to nearest whole day.

                elapsedStopHour = mod(elapsedStartHour+intervalDurationHours-frameDurationInHours,24);

                % find the first Start Time
                startDateVecs = datevec(obj.startDatenums);
                elapsedStartHours = startDateVecs*[0; 0; 0; 1; 1/60; 1/3600];

                firstStartIndex = find(elapsedStartHours==elapsedStartHour,1,'first');
                firstStopIndex = find(elapsedStartHours==elapsedStopHour,1,'first');
                lastStartIndex = find(elapsedStartHours==elapsedStartHour,1,'last');
                lastStopIndex = find(elapsedStartHours==elapsedStopHour,1,'last');

                firstStartDateVec = startDateVecs(firstStartIndex,:);


                if(firstStopIndex<firstStartIndex)
                    incompleteDayCount = incompleteDayCount+1;
                end

                if(lastStopIndex < lastStartIndex)
                    incompleteDayCount = incompleteDayCount+1;
                    % get the last start date vector that is used for a
                    % complete day; which is not at lastStartIndex in this
                    % case
                    lastStartDateVec = startDateVecs(lastStopIndex,:)-[0 0 0 intervalDurationHours-frameDurationInHours 0 0];
                else
                    lastStartDateVec = startDateVecs(lastStartIndex,:);
                end

                completeDayCount = max(0,datenum(lastStartDateVec) - datenum(firstStartDateVec));

            end
        end


        function [featureVec, startDatenum] = getFeatureVecs(obj,featureFcn,signalTagLine)
            featureStruct = obj.getStruct('all','features');
            if(isempty(featureStruct) || ~isfield(featureStruct,featureFcn) || isempty(featureStruct.(featureFcn)))
                obj.extractFeature(signalTagLine,featureFcn);
                featureStruct = obj.getStruct('all','features');
            end
            if(isempty(featureStruct) || ~isfield(featureStruct,featureFcn) || isempty(featureStruct.(featureFcn)))
                fprintf('There was an error.  Could not extract features!\n');
                featureVec = [];
                startDatenum = [];
            else

                featureVec = featureStruct.(featureFcn);
                % find the first Start Time
                startDatenum = obj.startDatenums;
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Calculates a desired feature for a particular acceleration object's field value.
        %> and returns it as a matrix of elapsed time aligned vectors.
        %> @param obj Instance of PASensorData
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

            if(nargin<5)
                intervalDurationHours=24;
                if(nargin<4)
                    elapsedStartHour = 0;
                    if(nargin<3)
                        signalTagLine = obj.frames_signalTagLine;
                    end
                end
            end

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
        %> @param obj Instance of PASensorData.
        %> @retval didClassify True/False depending on success.
        % ======================================================================
        function didClassify = classifyUsageForAllAxes(obj)
            try
                if(obj.hasCounts || obj.hasRaw || obj.hasMims)
                    dataStruct = obj.getStruct('all');
                    if strcmpi(obj.accelType,'raw') && obj.hasRaw
                        classifyObj = PAClassifyGravities();% %obj.classifyUsageState(dataStruct.(axesName));
                        dataStruct = dataStruct.accel.raw;
                    elseif(strcmpi(obj.accelType,'mims') && obj.hasMims)                        
                        dataStruct = dataStruct.accel.mims;
                        classifyObj = PAClassifyMIMS();
                    else                        
                        classifyObj = PAClassifyCounts();% %obj.classifyUsageState(dataStruct.(axesName));
                        dataStruct = dataStruct.accel.count;
                    end
                    
                    classifyObj.setDatenumVec(obj.dateTimeNum);
                    obj.usage = struct();
                    obj.bai = struct();
                    
                    axesNames = fieldnames(dataStruct);                    

                    if strcmpi(obj.accelType,'raw') && obj.hasRaw
                        [obj.bai.vecMag, obj.bai.x, obj.bai.y, obj.bai.z] = classifyObj.classifiyBaiActivity(dataStruct.x, dataStruct.y, dataStruct.z, obj.sampleRate);
                    end
                    % As long as you don't run into an exception, it passes.
                    didClassify = true;
                    for a=1:numel(axesNames)
                        try
                            axesName=axesNames{a};
                            obj.usage.(axesName) = classifyObj.classifyUsageState(dataStruct.(axesName)); %obj.classifyUsageState(dataStruct.(axesName));
                        catch me
                            showME(me);
                            didClassify = false;
                            obj.usage.(axesName) = zeros(size(dataStruct.(axesName)));
                        end
                    end
                    
                    if isfield(obj.usage, 'vecMag')
                        tags = classifyObj.getActivityTags();
                        stuckID = tags.SENSOR_STUCK;
                        obj.usage.vecMag(obj.usage.x==stuckID) = stuckID;
                        obj.usage.vecMag(obj.usage.y==stuckID) = stuckID;
                        obj.usage.vecMag(obj.usage.z==stuckID) = stuckID;
                    end
                else
                    didClassify = false;
                    obj.usage.(obj.accelType) = [];
                    %                     for a=1:numel(axesNames)
                    %                         axesName = axesNames{a};
                    %                         obj.usage.(axesName) = zeros(size(dataStruct.(axesName)));
                    %                     end
                    fprintf(1,'Usage state is not classif-ied for ''%s'' data\n', obj.accelType);
                end
                
            catch me
                showME(me);
                didClassify=false;
            end
        end

        % ======================================================================
        %> @brief Classifies epochs into wear and non-wear state using the
        %> count activity values and classification method given.
        %> @param obj Instance of PASensorData.
        %> @param vector of count activity to apply classification rules
        %> too.  If not provided, then the vector magnitude is used by
        %> default.
        %> @param String identifying the classification to use; can be:
        %> - padaco [default]
        %> - troiano
        %> - choi
        %> @retval wearVec A vector of length obj.dateTimeNum whose values
        %> represent the usage category at each sample instance specified by
        %> @b dateTimeNum.
        %> - c Nonwear 0
        %> - c Wear 1
        %> @retval wearState A three column matrix identifying usage state
        %> and duration.  Column 1 is the usage state, column 2 and column 3 are
        %> the states start and stop times (datenums).
        %> @note Usage states are categorized as follows:
        %> - c 0 Nonwear
        %> - c 1 Wear
        %> @retval startStopDatenums Start and stop datenums for each usage
        %> state row entry of usageState.
        % ======================================================================
        function [wearVec, wearState, startStopDateNums] = classifyWearNonwear(obj,classificationMethod)
            if(nargin<2)
                classificationMethod = obj.nonwearAlgorithm;
            end
            wearVec = rcall_getnonwear(objcountFilename, classificationMethod);
        end
        
        


        % ======================================================================
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
        % ======================================================================
        function nonWearVec = classifyTroianoWearNonwear(obj, countActivity, minNonWearPeriod_minutes)
            nonWearVec = [];
            if(nargin<3 || minNonWearPeriod_minutes<1)
                minNonWearPeriod_minutes = 90;
                if(nargin<2)
                    countActivity = obj.accel.counts.vecMag;
                end
            end

            nonWearVec = false(size(countActivity));

        end


    

        % ======================================================================
        %> @brief overloaded subsindex method returns structure of time series data
        %> at indices provided.
        %> @param obj Instance of PASensorData
        %> @param indices Vector (logical or ordinal) of indices to select time
        %> series data by.
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PASensorData's time series instance data for the indices provided.  The fields
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

                    % Only counts include these fields in their data file.
                    if(strcmpi(obj.accelType,'counts'))
                        dat.steps = double(obj.steps(indices));
                        dat.lux = double(obj.lux(indices));
                        dat.inclinometer.standing = double(obj.inclinometer.standing(indices));
                        dat.inclinometer.sitting = double(obj.inclinometer.sitting(indices));
                        dat.inclinometer.lying = double(obj.inclinometer.lying(indices));
                        dat.inclinometer.off = double(double(obj.inclinometer.off(indices)));
                    end
                case 'features'
                    dat = PASensorData.subsStruct(obj.features,indices);
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
                if(nargout)
                    varargout = cell(1,nargout-1);
                    
                    [sref,varargout{:}] = builtin('subsref',obj,s);
                else
                    builtin('subsref',obj,s);
                end
            end
        end

        % ======================================================================
        %> @brief Returns a structure of PASensorData's time series fields and
        %> values, depending on the user's input selection.
        %> @param obj Instance of PASensorData.
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

        %> @retval dat A struct of PASensorData's time series, aggregate bins, or features instance data.  The fields
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
        %> @brief Returns a structure of PASensorData's saveable parameters as a struct.
        %> @param obj Instance of PASensorData.
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
            % Why not just use .settings property now?
            pStruct = obj.settings;
            
            % Answer:  At the moment, obj.settings does not include 
            % - pathname
            % - filename
            pStruct.filename = obj.filename;
            pStruct.pathname = obj.pathname;
            
            %             fields= {'curWindow';
            %                 'pathname';
            %                 'filename';
            %                 'windowDurSec';
            %                 'aggregateDurMin';
            %                 'frameDurMin';
            %                 'frameDurHour';
            %                 'scale';
            %                 'label';
            %                 'offset';
            %                 'color';
            %                 'yDelta';
            %                 'visible'
            %                 'usageStateRules'
            %                 };
            %             %            fields = fieldnames(obj.getDefaults());
            %             pStruct = struct();
            %             for f=1:numel(fields)
            %                 pStruct.(fields{f}) = obj.(fields{f});
            %             end
        end

    end

    methods (Access = protected)


        function [didLoad,recordCount] = loadPadacoRawBinFile(obj,fullBinFilename)
            didLoad = false;
            recordCount = 0;
            if(exist(fullBinFilename,'file'))
                fid = fopen(fullBinFilename,'r','n');  %Let's go with native format...

                if(fid>0)
                    binHeader = obj.loadPadacoRawBinFileHeader(fid);
                    recordCount1 = binHeader.sz_remaining/binHeader.num_signals/binHeader.sz_per_signal;
                    recordCount2 = binHeader.samplerate*binHeader.duration_sec;
                    if(recordCount1~=recordCount2)
                        fprintf(1,'A mismatch exists for record count as specified in the binary file %s',fullBinFilename);
                        recordCount = max(recordCount1,recordCount2); % Take the largest of the two for pre-allocation.
                    else
                        recordCount = recordCount1;
                    end
                    %                     curPos = ftell(fid);
                    %                     a=fread(fid, [binHeader.num_signals,inf],'*float')';
                    %                     fseek(fid,curPos,'bof');
                    %                     tic
                    xyzData=fread(fid, [binHeader.num_signals,recordCount],'*float')';
                    obj.setRawXYZ(xyzData);

                    obj.sampleRate = binHeader.samplerate;
                    obj.durationSec = binHeader.duration_sec;

                    % Thu Feb  7 00:00:00 2013
                    daVec = datevec(binHeader.startDateTimeStr,'ddd mmm dd HH:MM:SS yyyy');
                    startDatenum = datenum(daVec);
                    obj.startDate = datestr(startDatenum,'mm/dd/yyyy');
                    obj.startTime = datestr(startDatenum,'HH:MM:SS');
                    daVec(end)=daVec(end)+obj.durationSec-1/obj.sampleRate;
                    stopDatenum = datenum(daVec);
                    obj.stopDate = datestr(stopDatenum,'mm/dd/yyyy');
                    obj.stopTime = datestr(stopDatenum,'HH:MM:SS');

                    datenumDelta = datenum([0,0,0,0,0,1/obj.sampleRate]);
                    obj.dateTimeNum = datespace(startDatenum,stopDatenum,datenumDelta);

                    didLoad = true;
                end
            end
        end

        % ======================================================================
        %> @brief Loads raw accelerometer data from binary file produced via
        %> actigraph Firmware 2.5.0 or 3.1.0.  This function is
        %> intended to be called from loadFile() to ensure that
        %> loadCountFile is called in advance to guarantee that the auxialiary
        %> sensor measurements are loaded into the object (obj).  The
        %> auxialiary measures (e.g. lux, steps) are upsampled to the
        %> sampling rate of the raw data (typically 40 Hz).
        %> @param obj Instance of PASensorData.
        %> @param fullRawActivityBinFilename The full (i.e. with path) filename for raw data,
        %> stored in binary format, to load.
        %> @param firmwareVersion String identifying the firmware version.
        %> Currently only '2.5.0' and '3.1.0' are supported.
        % Testing:  logFile = /Volumes/SeaG 1TB/sampledata_reveng/T1_GT3X_Files/700851/log.bin
        %> @retval recordCount - The number of records (or samples) found
        %> and loaded in the file.
        % =================================================================
        function recordCount = loadRawActivityBinFile(obj,fullFilename,firmwareVersion, samplesPerG, activityTypeID)
            if exist(fullFilename,'file')

                if nargin<4 || isempty(samplesPerG)
                    encodingEPS = 1/obj.samplesPerG; % 1/341 from trial and error - or math:  
                else
                    encodingEPS = 1/samplesPerG;
                end

                if nargin<5 || isempty(activityTypeID)
                    activityTypeID = obj.actigraphActitivityID; % see comments in properties of this class for actigraphActivityID
                end
                
                recordCount = 0;
                fid = fopen(fullFilename,'r','b');  %I'm going with a big endian format here.
                if fid>0
                    precision = 'ubit12=>double';

                    % Testing for ver 2.5.0
                    % fullRawActivityBinFilename = '/Volumes/SeaG 1TB/sampledata_reveng/700851.activity.bin'
                    %                sleepmoore:T1_GT3X_Files $ head -n 15 ../../sampleData/raw/700851t00c1.raw.csv
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
                        tic
                            axesPerRecord = 3;
                            checksumSizeBytes = 1;
                        if ~any(strcmp(firmwareVersion,{'2.5.0','3.1.0','2.2.1','1.5.0'}))

                            [axesFloatData, timeStamps] = fgetactigraphaxesrecords(fid, activityTypeID);
                            obj.setRawXYZ(axesFloatData);
                            obj.timeStamp = timeStamps;

                        else
                            % both fw 2.5 and 3.1.0 use same packet format for
                            % acceleration data.
                            if any(strcmp(firmwareVersion,{'2.5.0'}))
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

                            elseif any(strcmp(firmwareVersion,{'3.1.0','2.2.1','1.5.0'}))
                                % endian format: big
                                % global header: none
                                % packet encoding:
                                %   header:  8 bytes  [packet code: 2][time stamp: 4][packet size (in bytes): 2]
                                %   accel packets:  36 bits each (format: see ver 2.5.0) + 1 byte for checksum

                                triaxialAccelCodeBigEndian = 7680;
                                
                                triaxialAccelCodeLittleEndian = 30;
                                if strcmp(firmwareVersion, '1.7.2')
                                    triaxialAccelCodeLittleEndian = 7686; %? <-- for 1.7.2
                                    triaxialAccelCode = triaxialAccelCodeLittleEndian;
                                else
                                    triaxialAccelCode = triaxialAccelCodeBigEndian;
                                end
                                
                                %                                packetCode = 7686 (popped up in a firmware version 1.5
                                bitsPerByte = 8;
                                bitsPerAccelRecord = 36;  %size in number of bits (12 bits per acceleration axis)
                                recordsPerByte = bitsPerByte/bitsPerAccelRecord;
                                timeStampSizeBytes = 4;
                                % packetHeader.size = 8;
                                % go through once to determine how many
                                % records I have in order to preallocate memory
                                % - should look at meta data record to see if I can
                                % shortcut obj.
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
                                        % handles the issue of strings of
                                        % 0's in there.
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
                            obj.setRawXYZ(axesFloatData);
                        end
                        toc;
                        fclose(fid);

                        fprintf('Skipping resample count data step\n');
                        %                        obj.resampleCountData();

                    catch me
                        showME(me);
                        fclose(fid);
                    end
                else
                    fprintf('Warning - could not open %s for reading!\n',fullFilename);
                end
            else
                fprintf('Warning - %s does not exist!\n',fullFilename);
            end
        end

        % ======================================================================
        %> @brief Returns a structure of an insance PASensorData's time series data.
        %> @param obj Instance of PASensorData.
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PASensorData's time series instance data.  The fields
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
        %> @brief Returns a structure of an insance PASensorData's time series
        %> data at the current window.
        %> @param obj Instance of PASensorData.
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval curStruct A struct of PASensorData's time series or features instance data.  The fields
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
        %> @param obj Instance of PASensorData.
        %> @param structType (Optional) String identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PASensorData's time series or features instance data.  The fields
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

            dat = structEval('times',obj.getStruct('current',structType),obj.getScale(structType));

            windowRange = obj.getCurWindowRange(structType);

            %we have run into the problem of trying to zoom in on more than
            %we have resolution to display.
            if(diff(windowRange)==0)
                windowRange(2)=windowRange(2)+1;
                dat = structEval('repmat',dat,dat,size(windowRange));
            end

            lineProp.xdata = windowRange(1):windowRange(end);
            % put the output into a 'ydata' field for graphical display
            % property of a line.
            dat = structEval('plus',dat,obj.getOffset(structType),'ydata');
            dat = appendStruct(dat,lineProp);
        end

        % ======================================================================
        %> @brief Returns [x,y,z] offsets of the current time series
        %> data being displayed.  Values are stored in .position child field
        %> @param obj Instance of PASensorData.
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

            dat = structEval('repmat',dat,dat,size(windowRange));

            dat = structEval('passthrough',dat,dat,'ydata');

            dat = appendStruct(dat,lineProp);
        end

    end

    methods(Static)
        % File I/O
        
        % ======================================================================
        %> @brief Retrieves CSV header values (start time, start date, and window
        %> period).        
        %> @output fileHeader
        %> @output fid
        %> @param fullFilename The full filename to open and examine.
        %> @param fclose_on_exit [True] close fullFilename when method completes.
        %> Set to False to keep the file id open.  In which case the file identifier 
        %> returned (fid) will be valid
        % =================================================================
        function [fileHeader, fid] = getActigraphCSVFileHeader(fullFilename, fclose_on_exit)
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
            if nargin<2 || isempty(fclose_on_exit)
                fclose_on_exit = true;
            end
            fid = fopen(fullFilename,'r');
            fileHeader = struct;
            if(fid>0)
                try                    
                    tline = fgetl(fid);
                    commentLine = '------------';
                    %make sure we are dealing with a file which has a header
                    if ~strncmp(tline,commentLine, numel(commentLine))
                            % unset - we don't know - assume 1 per second
                        fileHeader.countPeriodSec = 1;
                        fileHeader.startTime = 'N/A';
                        fileHeader.startDate = 'N/A';
                        fprintf(' File does not include header.  Default values set for start date and countPeriodSec (1).\n');                    
                    else
                        
                        % will be empty for count data, in which case window period should be used
                        fs = regexp(tline,'.* at (\d+) Hz .*','tokens');
                        
                        % test_tline = '----...stuff ActiLife v6.9.2 Firmware v3.2.1 date format M/d/yyyy Filter Normal -----'
                        result = regexp(tline,['.+ActiLife (?<actilife>[^\s]+).+',...
                            'Firmware (?<firmware>[^\s]+).+Filter (?<filter>.+)\s-+$'],'names');                        
                        
                        if ~isempty(result)
                            fileHeader = mergeStruct(fileHeader, result);
                        else
                            fileHeader.actilife = '';
                            fileHeader.firmware = '';
                            fileHeader.filter = '';                            
                        end
                        

                        fgetl(fid);
                        tline = fgetl(fid);
                        exp = regexp(tline,'^Start Time (.*)','tokens');
                        if(~isempty(exp))
                            fileHeader.startTime = exp{1}{1};
                        else
                            fileHeader.startTime = 'N/A';
                        end
                        %  Start Date 1/23/2014
                        tline = fgetl(fid);
                        fileHeader.startDate = strrep(tline,'Start Date ','');

                        % Window period (hh:mm:ss) 00:00:01
                        tline = fgetl(fid);
                        tmpPeriod = sscanf(tline,'Epoch Period (hh:mm:ss) %u:%u:%u');
                        fileHeader.countPeriodSec = [3600,60,1]*tmpPeriod(:);

                        if(~isempty(fs))
                            fileHeader.sampleRate = str2double(fs{1}{1});
                        else
                            if(fileHeader.countPeriodSec~=0)
                                fileHeader.sampleRate = 1/fileHeader.countPeriodSec;
                            else
                                fileHeader.sampleRate = fileHeader.countPeriodSec;
                            end
                        end

                        % Pull the following line from the file and convert hh:mm:ss
                        % to total seconds
                        %  Window Period (hh:mm:ss) 00:00:01
                        % [a, c]=fscanf(fid,'%*s %*s %*s %d:%d:%d');  %
                        % This causes a read of the second line as well->
                        % which is very strange.  So don't use this way.
                        % obj.countPeriodSec = [3600 60 1]* a;

                        tline = fgetl(fid);
                        exp = regexp(tline,'^Download Time (.*)','tokens');
                        if(~isempty(exp))
                            fileHeader.downloadTime = exp{1}{1};
                        else
                            fileHeader.downloadTime = 'N/A';
                        end
                        %  Download Date 1/23/2014
                        tline = fgetl(fid);
                        fileHeader.downloadDate = strrep(tline,'Download Date ','');
                       
                        % Skip the next three lines which include:
                        
                        %  Current Memory Address: 0
                        %  Current Battery Voltage: 3.86     Mode = 12
                        % --------------------------------------------------
                        fgetl(fid);
                        fgetl(fid);
                        fgetl(fid);
                        
                        % Accelerometer X,Accelerometer Y,Accelerometer Z                        
                        tline = fgetl(fid);
                        fileHeader.columnNames = strsplit(tline,',');
                        fileHeader.numColumns = numel(fileHeader.columnNames);
                    end
                    if fclose_on_exit
                        fclose(fid);
                    else
                        % The following is true, but is disconcerting now since we don't have a closing 
                        % comment when the file handle is closed later on.
                        % fprintf(1,'File handle remains open for %s\n',fullFilename);
                    end
                catch me
                    showME(me);
                end
            end
        end

        %> @param fid File identifier is expected to be a file resource
        %> for a binary file obtained using fopen(<filename>,'r');
        %> @retval fileHeader A struct with file header field value pairs.
        %> An empty value is returned in the event that the fid is bad.
        function fileHeader = loadPadacoRawBinFileHeader(fid)
            goodFile = fseek(fid,0,'bof')==0;

            if(~goodFile)
                fprintf(1,'Not a good file identifier.  The following error message was received:\n\t%s\n',ferror(fid));
                fileHeader = [];
            else

                fileHeader.samplerate = fread(fid,1,'uint16');
                fileHeader.startDateTimeStr = fread(fid,[1,24],'*char');
                %                 fileHeader.tm_sec=fread(fid,1,'int');    % seconds after the minute (0 to 61) */
                %                 fileHeader.tm_min=fread(fid,1,'int');    % minutes after the hour (0 to 59) */
                %                 fileHeader.tm_hour=fread(fid,1,'int');   % hours since midnight (0 to 23) */
                %                 fileHeader.tm_mday=fread(fid,1,'int');   % day of the month (1 to 31) */
                %                 fileHeader.tm_mon=fread(fid,1,'int');    % months since January (0 to 11) */
                %                 fileHeader.tm_year=fread(fid,1,'int')+1900;   % years since 1900 */
                %                 fileHeader.tm_wday=fread(fid,1,'int');   % days since Sunday (0 to 6 Sunday=0) */
                %                 fileHeader.tm_yday=fread(fid,1,'int');   % days since January 1 (0 to 365) */
                %                 fileHeader.tm_isdst=fread(fid,1,'int');  % Daylight Savings Time */

                fileHeader.firmware = fread(fid,[1,10],'*char');
                fileHeader.serialID = fread(fid,[1,20],'*char');
                fileHeader.duration_sec = fread(fid,1,'uint32');
                fileHeader.num_signals = fread(fid,1,'uint8');
                fileHeader.sz_per_signal = fread(fid,1,'uint8');
                fileHeader.sz_remaining = fread(fid,1,'*uint64');
                if(feof(fid))
                    fprintf(1,'Not a good file identifier.  The following error message was received:\n\t%s\n',ferror(fid));
                    fileHeader = [];
                end
            end
        end

        % ======================================================================
        %> @brief Parses the information found in input file name and returns
        %> the result as a struct of field-value pairs.
        %> @param obj Instance of PASensorData.
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

                numericFields = {'Sample_Rate','Acceleration_Scale',...
                    'Acceleration_Max','Acceleration_Min',...
                    'Download_Date','Start_Date','Stop_Date','Last_Sample_Time',...
                    'Battery_Voltage','Unexpected_Resets','Board_Revision'};

                for field = numericFields
                    fieldName = field{1};
                    if isfield(infoStruct,fieldName)
                        infoStruct.(fieldName) = str2double(infoStruct.(fieldName));
                    end
                end

            else
                infoStruct=[];
                firmware ='';
            end
        end
        
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
        function featureVector = calcFeatureVector(dataVector,samplesPerFrame,featureFcn)
            numelements = numel(dataVector);
            numFrames = floor(numelements/samplesPerFrame);
            frameableSamples = samplesPerFrame*numFrames;
            NxM_dataFrames =  reshape(dataVector(1:frameableSamples),[],numFrames);  %each frame consists of a column of data.  Consecutive columns represent consecutive frames.
            featureVector = PASensorData.calcFeatureVectorFromFrames(NxM_dataFrames,featureFcn);
        end

        function Mx1_featureVector = calcFeatureVectorFromFrames(NxM_dataFrames,featureFcn)
            switch(lower(featureFcn))
                 case 'rms'
                    Mx1_featureVector = sqrt(mean(NxM_dataFrames.^2))';
                case 'mean'
                    Mx1_featureVector = mean(NxM_dataFrames)';
                case 'meanad'
                    % Mx1_featureVector = mad(NxM_dataFrames,0)';
                    Mx1_featureVector = mean_abs_dev(NxM_dataFrames);                    
                case 'medianad'
                    % Mx1_featureVector = mad(NxM_dataFrames,1)';
                    Mx1_featureVector = median_abs_dev(NxM_dataFrames)';
                case 'median'
                    Mx1_featureVector = median(NxM_dataFrames)';
                case 'sum'
                    Mx1_featureVector = sum(NxM_dataFrames)';
                case 'var'
                    Mx1_featureVector = var(NxM_dataFrames)';
                case 'std'
                    Mx1_featureVector = std(NxM_dataFrames)';
                case {'mode','usagestate'}
                    Mx1_featureVector = mode(NxM_dataFrames)';
                otherwise
                    Mx1_featureVector = [];
                    fprintf(1,'Unknown method (%s)\n',featureFcn);
            end
        end

        function featureFcn = getFeatureFcn(functionName)
            switch(lower(functionName))
                 case 'rms'
                    featureFcn = @(data)sqrt(mean(data.^2))';
                case 'mean'
                    featureFcn = @(x)mean(x)';
                case 'meanad'
                    % featureFcn = @(x)mad(x,0)';
                    featureFcn = @(x)mean_abs_dev(x)';
                case 'medianad'
                    % featureFcn = @(x)mad(x,1)';
                    featureFcn = @(x)median_abs_dev(x)';
                case 'median'
                    featureFcn = @(x)median(x)';
                case 'sum'
                    featureFcn = @(x)sum(x)';
                case 'var'
                    featureFcn = @(x)var(x)';
                case 'std'
                    featureFcn = @(x)std(x)';
                case {'mode'}
                    featureFcn = @(x)mode(x)';
                otherwise
                    featureFcn = @(x)x';
                    fprintf(1,'Unknown method (%s)\n',featureFcn);
            end
        end

        %% Interface (can be moved to a controller class)
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
                'accel.mims.vecMag';
                'accel.mims.x';
                'accel.mims.y';
                'accel.mims.z';
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
                'Magnitude (mims)';
                'X (mims)';
                'Y (mims)';
                'Z (mims)';
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

        % Default custom format struct
        function fmtStruct = getDefaultCustomFmtStruct()
             fmtStruct.datetime = 1;
             fmtStruct.datetimeType = 'elapsed'; %datetime
             fmtStruct.datetimeFmtStr = '%f';
             fmtStruct.x = 2;
             fmtStruct.y = 3;
             fmtStruct.z = 4;
             fmtStruct.fieldOrder = {'datetime','x','y','z'};
             fmtStruct.headerLines = 1;
             fmtStruct.delimiter = ',';
        end

        % ======================================================================
        %> @brief Returns a structure of PASensorData's default parameters as a struct.
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
        function pStruct = getDefaults()
            
            pStruct = PAData.getDefaults();
            %> @brief Pathname of file containing accelerometer data.            
            
            pStruct.missingValue = PAStringParam('default','nan','Description','Missing value identifier','help','Used in place of missing data (that is not found in a file)');
            pStruct.missingValue = PANumericParam('default',nan,'Description','Missing value identifier','help','Used in place of missing data (that is not found in a file)');
            pStruct.curWindow = PAIndexParam('default',1,'description','Current window shown');
            
            pStruct.frameDurMin = PANumericParam('default',15,'description','Frame duration (minutes)','help','frame duration minute of 0 equates to frame sizes of 1 frame per sample (i.e. no aggregation)');
            pStruct.frameDurHour = PANumericParam('default',0,'description','Frame duration (hours)');
            pStruct.aggregateDurMin = PANumericParam('default',3,'Description','Aggregatate duration (minutes)','help','This value is not currently used');
            pStruct.windowDurSec = PANumericParam('default',60*60,'Description','Window display duration','help','This can be adjusted by the user, and is 1 hour by default.'); % set to 1 hour
           
            pStruct.nonwearAlgorithm = PAEnumParam('default','padaco','categories',{'padaco','choi','none'},'description','Nonwear classification algorithm');  

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

            featureStruct = PASensorData.getFeatureDescriptionStructWithPSDBands();
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
                pStruct.label.features.(curFeature) = curDescription;
                %                pStruct.label.features.(curFeature).position = [0 0 0];
                pStruct.color.features.(curFeature) = curColor;
                pStruct.visible.features.(curFeature) = 'on';
            end

            %Default is everything to be visible
            timeSeriesStruct = PASensorData.getDummyStruct('timeSeries');
            %visibleProp.visible = 'on';
            visibility = 'on';
            pStruct.visible.timeSeries = overwriteEmptyStruct(timeSeriesStruct,visibility);

            % yDelta = 1/20 of the vertical screen space (i.e. 20 can fit)
            yOffsets.x = pStruct.yDelta*1;
            yOffsets.y = pStruct.yDelta*4;
            yOffsets.z = pStruct.yDelta*7;
            yOffsets.vecMag = pStruct.yDelta*10;
            
            colors.x = 'r';
            colors.y = 'g';
            colors.z = 'b';
            colors.vecMag = 'k';
            
            scales.x = 10;
            scales.y = 10;
            scales.z = 10;            
            scales.vecMag = 10;
            
            accelTypes = {'raw','count','mims'};
            for a=1:numel(accelTypes)
                accelType = accelTypes{a};                
                pStruct.offset.timeSeries.accel.(accelType) = yOffsets;
                pStruct.color.timeSeries.accel.(accelType) = colors;
                pStruct.scale.timeSeries.accel.(accelType) = scales;
            end
            
             pStruct.scale.timeSeries.accel.count.x = 1;
             pStruct.scale.timeSeries.accel.count.y = 1;
             pStruct.scale.timeSeries.accel.count.z = 1;
             pStruct.scale.timeSeries.accel.count.vecMag = 1;
             
             pStruct.scale.timeSeries.accel.mims.x = 100;
             pStruct.scale.timeSeries.accel.mims.y = 100;
             pStruct.scale.timeSeries.accel.mims.z = 100;
             pStruct.scale.timeSeries.accel.mims.vecMag = 100;
            
%             pStruct.offset.timeSeries.accel.raw.x = pStruct.yDelta*1;
%             pStruct.offset.timeSeries.accel.raw.y = pStruct.yDelta*4;
%             pStruct.offset.timeSeries.accel.raw.z = pStruct.yDelta*7;
%             pStruct.offset.timeSeries.accel.raw.vecMag = pStruct.yDelta*10;
%             pStruct.offset.timeSeries.accel.count.x = pStruct.yDelta*1;
%             pStruct.offset.timeSeries.accel.count.y = pStruct.yDelta*4;
%             pStruct.offset.timeSeries.accel.count.z = pStruct.yDelta*7;
%             pStruct.offset.timeSeries.accel.count.vecMag = pStruct.yDelta*10;
            pStruct.offset.timeSeries.steps = pStruct.yDelta*14;
            pStruct.offset.timeSeries.lux = pStruct.yDelta*15;
            pStruct.offset.timeSeries.inclinometer.standing = pStruct.yDelta*19.0;
            pStruct.offset.timeSeries.inclinometer.sitting = pStruct.yDelta*18.25;
            pStruct.offset.timeSeries.inclinometer.lying = pStruct.yDelta*17.5;
            pStruct.offset.timeSeries.inclinometer.off = pStruct.yDelta*16.75;

            
%             pStruct.color.timeSeries.accel.raw.x = 'r';
%             pStruct.color.timeSeries.accel.raw.y = 'g';
%             pStruct.color.timeSeries.accel.raw.z = 'b';
%             pStruct.color.timeSeries.accel.raw.vecMag = 'k';
%             pStruct.color.timeSeries.accel.count.x = 'r';
%             pStruct.color.timeSeries.accel.count.y = 'g';
%             pStruct.color.timeSeries.accel.count.z = 'b';
%             pStruct.color.timeSeries.accel.count.vecMag = 'k';
            pStruct.color.timeSeries.steps = 'm'; %[1 0.5 0.5];
            pStruct.color.timeSeries.lux = 'y';
            pStruct.color.timeSeries.inclinometer.standing = 'k';
            pStruct.color.timeSeries.inclinometer.lying = 'k';
            pStruct.color.timeSeries.inclinometer.sitting = 'k';
            pStruct.color.timeSeries.inclinometer.off = 'k';

            % Scale to show at
            % Increased scale used for raw acceleration data so that it can be
            % seen more easily.
%             pStruct.scale.timeSeries.accel.raw.x = 10;
%             pStruct.scale.timeSeries.accel.raw.y = 10;
%             pStruct.scale.timeSeries.accel.raw.z = 10;
%             pStruct.scale.timeSeries.accel.raw.vecMag = 10;
%             pStruct.scale.timeSeries.accel.count.x = 1;
%             pStruct.scale.timeSeries.accel.count.y = 1;
%             pStruct.scale.timeSeries.accel.count.z = 1;
%             pStruct.scale.timeSeries.accel.count.vecMag = 1;
            pStruct.scale.timeSeries.steps = 5;
            pStruct.scale.timeSeries.lux = 1;
            pStruct.scale.timeSeries.inclinometer.standing = 5;
            pStruct.scale.timeSeries.inclinometer.sitting = 5;
            pStruct.scale.timeSeries.inclinometer.lying = 5;
            pStruct.scale.timeSeries.inclinometer.off = 5;

            [tagLines, labels] = PASensorData.getDefaultTagLineLabels();
            for t=1:numel(tagLines)
                eval(['pStruct.label.timeSeries.',tagLines{t},' = ''',labels{t},''';']);
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
                    structOut.(fnames{f}) = PASensorData.subsStruct(structIn.(fnames{f}),indices);
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
        function [orderedDataCell, synthDateNum, synthDateVec] = mergedCell(startDateNum, stopDateNum, dateNumDelta, sampledDateVec,tmpDataCellOrMatrix,missingValue)
            if(nargin<6 || isempty(missingValue))
                missingValue = nan;
            end

            [synthDateNum, synthDateVec] = datespace(startDateNum, stopDateNum, dateNumDelta);
            numSamples = size(synthDateVec,1);

            %make a cell with the same number of column as
            %loaded in the file less 2 (remove date and time
            %b/c already have these, with each column entry
            %having an array with as many missing values as
            %originally found.
            orderedDataCell =  repmat({repmat(missingValue,numSamples,1)},1,size(tmpDataCellOrMatrix,2));

            %This takes 2.0 seconds!
            sampledDateNum = datenum(sampledDateVec);
            [~,IA,IB] = intersect(synthDateNum,sampledDateNum);
            % c = setdiff(synthDateNum,sampledDateNum);

            %This takes 153.7 seconds! - 'rows' option is not as helpful
            %here.
            %            [~,IA,~] = intersect(synthDateVec,sampledDateVec,'rows');
            for c=1:numel(orderedDataCell)
                if(iscell(tmpDataCellOrMatrix))
                    orderedDataCell{c}(IA) = tmpDataCellOrMatrix{c}(IB);
                else
                    orderedDataCell{c}(IA) = tmpDataCellOrMatrix(IB,c);
                end
            end
        end


        % ======================================================================
        %> @brief Returns an empty struct with fields that mirror PASensorData's
        %> time series instance variables that contain
        %> @param structType (Optional) String identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PASensorData's time series, feature, or aggregate bin instance variables.
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
                    tmp.x = [];
                    tmp.y = [];
                    tmp.z = [];
                    tmp.vecMag = [];
                    accelS.raw = tmp;
                    accelS.count = tmp;
                    accelS.mims = tmp;

                    incl.standing = [];
                    incl.sitting = [];
                    incl.lying = [];
                    incl.off = [];
                    dat.accel = accelS;
                    dat.steps = [];
                    dat.lux = [];
                    dat.inclinometer = incl;
                case 'bins'
                    binNames =  PASensorData.getPrefilterMethods();
                    dat = struct;
                    for f=1:numel(binNames)
                        dat.(lower(binNames{f})) = [];
                    end

                case 'features'
                    %                    featureNames =  PASensorData.getExtractorMethods();
                    featureNames = fieldnames(PASensorData.getFeatureDescriptionStructWithPSDBands());
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
        %> @retval dat A struct of PASensorData's time series instance variables, which
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

            dat = PASensorData.getDummyStruct(structType);
            dat = overwriteEmptyStruct(dat,lineProps);

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
        %> @note These methods can be passed as the argument to PASensorData's
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
        %> @note These methods can be passed as the argument to PASensorData's
        %> prefilter() method.
        % --------------------------------------------------------------------
        function extractorDescriptions = getExtractorDescriptions()
            [~, extractorDescriptions] = PASensorData.getFeatureDescriptionStruct();

            %% This was before I rewrote getFeatureDescriptionStruct
            % featureStruct = PASensorData.getFeatureDescriptionStruct();
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
            featureStruct.medianad = 'Median Absolute Deviation';
            featureStruct.meanad = 'Mean Absolute Deviation';
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

        %> @brief Returns descriptive text as key value pair for features
        %> where the feature names are the keys.
        %> @retval featureStructWithPSDBands struct with keyname to 'Value description'
        %> pairs.
        %> @retval varargout Cell with descriptive labels in the same order
        %> as they appear in argument one's keyvalue paired struct.
        function [featureStructWithPSDBands, varargout] = getFeatureDescriptionStructWithPSDBands()
            featureStruct = rmfield(PASensorData.getFeatureDescriptionStruct(),'psd');
            psdFeatureStruct = PASensorData.getPSDFeatureDescriptionStruct();
            featureStructWithPSDBands = mergeStruct(featureStruct,psdFeatureStruct);
            if(nargout>1)
                varargout{1} = struct2cell(featureStructWithPSDBands);
            end
        end

        function [psdFeatureStruct, varargout] = getPSDFeatureDescriptionStruct()
            psdFeatureStruct = struct();
            psdNames = PASensorData.getPSDBandNames();
            for p=1:numel(psdNames)
                psdFeatureStruct.(psdNames{p}) = sprintf('Power Spectral Density (band - %u)',p);
            end
            if(nargout>1)
                varargout{1} = struct2cell(psdFeatureStruct);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the fieldname of PASensorData's struct types (see getStructTypes())
        %> that matches the string argument.
        %> @param description String description that can be
        %> @li @c timeSeries = 'time series';
        %> @li @c bins = 'aggregate bins';
        %> @li @c features = 'features';
        %> @retval structName Name of the field that matches the description.
        %> @note For example:
        %> @note structName = PASensorData.getStructNameFromDescription('time series');
        %> @note results in structName = 'timeSeries'
        % --------------------------------------------------------------------
        function structName = getStructNameFromDescription(description)
            structType = PASensorData.getStructTypes();
            fnames = fieldnames(structType);
            structName = [];
            for f=1:numel(fnames)
                if(strcmpi(description,structType.(fnames{f})))
                    structName = fnames{f};
                    break;
                end
            end
        end

        function psdExtractorDescriptions = getPSDExtractorDescriptions()
            [~,psdExtractorDescriptions] = PASensorData.getPSDFeatureDescriptionStruct();
        end

        % --------------------------------------------------------------------
        %> @brief Returns a struct representing the internal architecture
        %> used by PASensorData to hold and process acceleration data.
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

        function tagStruct = getActivityTags()            
            tagStruct = PAClassifyUsage.getActivityTags();
        end

        function bandNamesAsCell = getPSDBandNames()
            bandNamesAsCell = str2cell(sprintf('psd_band_%u\n',1:PASensorData.NUM_PSD_BANDS));
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


%  File load Raw notes:
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
