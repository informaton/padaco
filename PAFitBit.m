% ======================================================================
%> @file PAFitBit.cpp
%> @brief Accelerometer data loading class.
% ======================================================================
%> @brief The PAFitBit class helps loads and stores accelerometer data used in the
%> physical activity monitoring project.  The project is aimed at reducing
%> obesity and improving health in children.
% ======================================================================
classdef PAFitBit < PAData

    
    methods
        
        % ======================================================================
        %> @brief Constructor for PAFitBit class.
        %> @param fullFilenameOrPath Either
        %> - (1) the full filename (i.e. with pathname) of accelerometer data to load.
        %> - or (2) the path that contains raw accelerometer data stored in
        %> binary file(s) - Firmware versions 2.5 or 3.1 only.
        %> @param pStruct Optional struct of parameters to use.  If it is not
        %> included then parameters from getDefaultParameters method are used.
        %> @retval Instance of PAFitBit.
        % fullFile = '~/Google Drive/work/Stanford - Pediatrics/sampledata/female child 1 second epoch.csv'
        % =================================================================
        function obj = PAFitBit(fullFilenameOrPath,pStruct)
            obj.pathname =[];
            obj.filename = [];
            
            if(nargin<2 || isempty(pStruct))
                pStruct = obj.getDefaultParameters();
            end
            
            obj.accelType = [];
            obj.startDatenums = [];
            
            obj.durationSec = 0;  %ensures we get valid, non-empty values from  getWindowCount() when we do not have any data loaded.

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
        

        
        %> @brief Returns studyID instance variable.
        %> @param Instance of PAFitBit
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
        

        
        % ======================================================================
        %> @brief Load CSV header values (start time, start date, and window
        %> period).
        %> @param obj Instance of PAFitBit.
        %> @param fullFilename The full filename to open and examine.
        % =================================================================
        function loadFileHeader(obj,fullFilename)

            fid = fopen(fullFilename,'r');
            if(fid>0)
                try
                    tline = fgetl(fid);
                    headerLine = 'ActivityMinute,Steps';
                    activityStr = 'ActivityMinute,';
                    %make sure we are dealing with a fitbit file header
                    if(strncmp(tline,activityStr,numel(activityStr)))
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
        %> @param obj Instance of PAFitBit.
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
        %> @param obj Instance of PAFitBit.
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
        %> @param obj Instance of PAFitBit.
        %> @param fullCountFilename The full (i.e. with path) filename to load.
        % =================================================================
        function didLoad = loadFitBitFile(obj,fullCountFilename)
            
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
                        
                        obj.accel.fitbit.steps = dataCell{1};
                        obj.accel.fitbit.mets = dataCell{2};
                        obj.accel.fitbit.intensity = dataCell{3};                        
                        obj.accel.fitbit.calories = dataCell{4};
                        
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
        %> @brief Resamples previously loaded 'count' data to match sample rate of
        %> raw accelerometer data that has been loaded in a following step (see loadFile()).
        %> @param obj Instance of PAFitBit.       %
        %> @note countPeriodSec, sampleRate, steps, lux, and accel values
        %> must be set in advance of this call.
        % ======================================================================
        function resampleCountData(obj)
            
        end
  
        % ======================================================================
        %> @brief Extracts features from the identified signal
        %> @param obj Instance of PAFitBit.
        %> @param signalTagLine Tag identifying the signal to extract
        %> features from.  Default is 'accel.fitbit.steps'
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
                    signalTagLine = 'accel.fitbit.steps';
                end
            end
            
            extractFeature@PAData(obj,signalTagLine,method);

        end

        % ======================================================================
        %> @brief Saves data to an ascii file.
        %> @note This is not yet implemented.
        %> @param obj Instance of PAFitBit.
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
        %> @param obj Instance of PAFitBit
        %> @param indices Vector (logical or ordinal) of indices to select time
        %> series data by.
        %> @param structType String (optional) identifying the type of data to obtain the
        %> offset from.  Can be
        %> @li @c timeSeries (default) - units are sample points
        %> @li @c features - units are frames
        %> @li @c bins - units are bins
        %> @retval dat A struct of PAFitBit's time series instance data for the indices provided.  The fields
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
                    dat = PAFitBit.subsStruct(obj.features,indices);
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

    end
    
    methods(Static)
    
        
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
                'accel.fitbit.calories';
                'accel.fitbit.steps';
                'accel.fitbit.mets';
                'accel.fitbit.intensity';
                };
            labels = {
                'Calories';
                'Steps';
                'Mets';
                'Intensities';
                };
        end
        
        % ======================================================================
        %> @brief Returns a structure of PAFitBit's default parameters as a struct.
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
            
            featureStruct = PAFitBit.getFeatureDescriptionStruct();
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
            timeSeriesStruct = PAFitBit.getDummyStruct('timeSeries');
            visibleProp.visible = 'on';
            pStruct.visible.timeSeries = overwriteEmptyStruct(timeSeriesStruct,visibleProp);
            
            % yDelta = 1/20 of the vertical screen space (i.e. 20 can fit)
            pStruct.offset.timeSeries.accel.fitbit.steps = pStruct.yDelta*1;
            pStruct.offset.timeSeries.accel.fitbit.mets = pStruct.yDelta*4;
            pStruct.offset.timeSeries.accel.fitbit.intensity = pStruct.yDelta*7;
            pStruct.offset.timeSeries.accel.fitbit.calories = pStruct.yDelta*10;
            
            

            pStruct.color.timeSeries.accel.fitbit.steps.color = 'r';
            pStruct.color.timeSeries.accel.fitbit.mets.color = 'b';
            pStruct.color.timeSeries.accel.fitbit.intensity.color = 'g';
            pStruct.color.timeSeries.accel.fitbit.calories.color = 'm';

            
            % Scale to show at
            % Increased scale used for raw acceleration data so that it can be

            pStruct.scale.timeSeries.accel.fitbit.steps = 1;
            pStruct.scale.timeSeries.accel.fitbit.mets = 1;
            pStruct.scale.timeSeries.accel.fitbit.intensity = 1;
            pStruct.scale.timeSeries.accel.fitbit.calories = 1;

            [tagLines, labels] = PAFitBit.getDefaultTagLineLabels();
            for t=1:numel(tagLines)
                eval(['pStruct.label.timeSeries.',tagLines{t},'.string = ''',labels{t},''';']);
            end
            

            
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
        

        
    end
end

