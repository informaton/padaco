% ======================================================================
%> @file PAData.m
%> @brief Accelerometer data loading class.
% ======================================================================
%> @brief The class loads and stores accelerometer data used in the 
%> Physical Activity monitoring project aimed to reduce obesity 
%> and improve child health.
% ======================================================================
classdef PAData < handle
   properties
       %> @brief Pathname of file containing accelerometer data.
       pathname;
       %> @brief Name of file containing accelerometer data that is loaded.
       filename;
       %> @brief Type of acceleration stored; can be 
       %> - raw This is not processed
       %> - count This is preprocessed
       accelType;
       %> @brief Structure of raw x,y,z accelerations.  Fields are:
       %> @li - x x-axis
       %> @li - y y-axis
       %> @li - z z-axis       
       accelRaw;
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
       %> @brief Struct of sample rates corresponding to time series data stored
       %> by class instances.  Fields include:
       %> - accelRaw [default is 80Hz]
       %> - inclinometer
       %> - lux
       %> - vecMag
       sampleRate;
       %> Current epoch.  Current position in the raw data.  The first epoch is '1' (i.e. not zero because this is MATLAB programming)
       curEpoch; 
       %> Durtion of the sampled data in seconds.  
       durationSec; 
       %> @brief Defined in the accelerometer's file output and converted to seconds.
       %> This is the sampling rate of the output file. ???
       epochPeriodSec;
       %> @brief Epoch duration (in seconds). 
       %> This can be adjusted by the user, but is 30 s by default.
       epochDurSec;    
       
       %> @brief Struct of line handle properties corresponding to the
       %> fields of linehandle.  These are derived from the input files
       %> loaded by the PAData class.
       lineproperty;
        
       color;
       offset;
       scale;
       
   end
   
   methods
       
       % ======================================================================
       %> @brief Constructor for PAData class.
       %> @param Optional entries can be either
       %> @li Full filename (i.e. with pathname) of accelerometer data to load.
       %> %li Pathname containing accelerometer files to be loaded.
       %> @param Optional Filename of accelerometer data to load.
       %> @note: This is only supplied in the event that the first
       %> parameter is passed as the pathname for the acceleromter files.
       %> @retval Instance of PAData.
       % =================================================================
       function obj = PAData(fullfileOrPath,filename)
           
           if(nargin==2)
               if(isdir(fullfileOrPath))
                   obj.pathname = fullfileOrPath;               
               end
               if(exist(fullfile(fullfileOrPath,filename),'file'))
                   obj.filename = filename;
               end
           elseif(nargin==1)
               if(isdir(fullfileOrPath))
                   obj.pathname = fullfileOrPath;               
               elseif(exist(fullfileOrPath,'file'))
                   [obj.pathname, obj.filename, ext] = fileparts(fullfileOrPath);
                   obj.filename = strcat(obj.filename,ext);
               end               
           end
           
           obj.color.accelRaw.x = 'r';
           obj.color.accelRaw.y = 'b';
           obj.color.accelRaw.z = 'g';
           obj.color.inclinometer = 'k';
           obj.color.lux = 'y';
           obj.color.vecMag = 'm';
           obj.color.steps = 'o'; 
           
           obj.scale.accelRaw.x = ;
           obj.scale.accelRaw.y = ;
           obj.scale.accelRaw.z = ;
           obj.scale.inclinometer = ;
           obj.scale.lux = ;
           obj.scale.vecMag = ;
           obj.scale.steps = ; 
           
           
           
           
           
           
           obj.sampleRate.accelRaw = 80;
           obj.sampleRate.inclinometer = 80;
           obj.sampleRate.lux = 80;
           obj.sampleRate.vecMag = 80;
           obj.epochDurSec = 30;
           obj.curEpoch = 1;
           obj.loadFile();
           
           test = false;
           if(test)
               % testFile = '/Users/hyatt4/Google Drive/work/prospects/handwriting recognition/reacceldata/Sensor_record_20140407_160400_W1.csv';
               obj.pathname = '/Users/hyatt4/Google Drive/work/Stanford - Pediatrics/sampledata';
               [filenames,~] = getFilenamesi(obj.pathname,'csv');
               if(iscell(filenames))
                   obj.filename=filenames{2};
               else
                   obj.filename = filenames;
               end
               obj.loadFile(obj.getFullFilename());
           end
       end
       
       
       % ======================================================================
       %> @brief Returns a structure of an instnace PAData's time series data.
       %> @param Instance of PAData.
       %> @retval tsStruct A struct of PAData's time series instance data.  The fields
       %> include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - inclinometer
       %> - lux
       %> - vecMag
       % =================================================================      
       function dat = getStruct(obj)
           dat.accelRaw = obj.accelRaw;
           dat.inclinometer = obj.inclinometer;
           dat.lux = obj.lux;
           dat.vecMag = obj.vecMag;
       end
       
       
       % ======================================================================
       %> @brief Returns a structure of an instnace PAData's time series data.
       %> @param Instance of PAData.
       %> @retval The start, stop range of the current epoch returned as samples beginning with 1 for the first sample.
       %> @note This uses instance variables epochDurSec, curEpoch, and sampleRate to
       %> determine the sample range for the current epoch.
       % =================================================================      
       function epochRange = getCurEpochRangeAsSamples(obj)
           epochDurSamples = obj.getEpochDurSamples();
           epochRange = (obj.curEpoch-1)*epochDurSamples+[1,epochDurSamples];
       end

       % ======================================================================
       %> @brief Returns the duration of an epoch in terms of sample points.
       %> @param Instance of PAData.
       %> @retval (Integer) Duration of the epoch window in units of sample points.
       %> @note Calcuation based on instance variables epochDurSec and sampleRate
       % =================================================================      
       function epochDurSamples = getEpochDurSamples(obj)
           epochDurSamples = obj.epochDurSec*obj.sampleRate.accelRaw;
       end
       
       % --------------------------------------------------------------------
       %> @brief Set the current epoch for the instance variable accelObj
       %> (PAData)
       %> @param Instance of PAContraller
       %> @param True if the epoch is set successfully, and false otherwise.
       %> @note Reason for failure include epoch values that are outside
       %> the range allowed by accelObj (e.g. negative values or those
       %> longer than the duration given.
       % --------------------------------------------------------------------
       function success = setCurEpoch(obj,epoch)
           if(epoch>0 && epoch<=obj.getMaxEpoch())
               obj.curEpoch = epoch;
               success = true;
           else
               success= false;
           end
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the total number of epochs the data can be divided
       %> into based on sampling rate, epoch resolution (i.e. duration), and the size of the time
       %> series data.
       %> @param Instance of PAData
       %> @param The maximum/last epoch allowed
       %> @note In the case of data size is not broken perfectly into epochs, but has an incomplete epoch, the
       %> epoch count is rounded up.  For example, if the time series data is 10 s in duration and the epoch size is 
       %> defined as 30 seconds, then the epochCount is 1.  
       % --------------------------------------------------------------------
       function epochCount = getEpochCount(obj)
           epochCount = ceil(obj.durationSec/obj.epochDurSec);
       end
       
       % ======================================================================
       %> @brief Returns the minmax value(s) for the object's (obj) time series data
       %> Returns either a structure or 1x2 vector of [min, max] values for the field
       %> specified.
       %> @param Instance of PAData.
       %> @param String value identifying the time series data to perform
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
       %> @retval Minimum maximum values for each time series field
       %> contained in obj.getStruct() or a single 2x1 vector of min max
       %> values for the field name specified.
       % =================================================================      
       function minMax = getMinmax(obj,field)
           if(nargin<2 || isempty(field))
               field = 'all';
           end
           dataStruct = obj.getStruct();
           if(strcmpi(field,'all'))
               minMax = obj.getRecurseMinmax(dataStruct);
           else
               
               if(~strcmpi(field,'struct'))
                   dataStruct = dataStruct.(field);
               end
               minMax = obj.minmax(dataStruct);
           end
       end
       
       
       % ======================================================================
       %> @brief Returns the filename, pathname, and full filename (pathname + filename) of
       %> the file that the accelerometer data was loaded from.
       %> @param obj Instance of PAData
       %> @retval The short filename of the accelerometer data.
       %> @retval The pathname of the accelerometer data.
       %> @retval The full filename of the accelerometer data.
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
       %> @retval The full filenmae of the accelerometer data.
       %> @note See also getFilename()
       % =================================================================
       function fullFilename = getFullFilename(obj)
           [~,~,fullFilename] = obj.getFilename();
       end

       % ======================================================================
       %> @brief Load CSV header values (start time, start date, and epoch
       %> period).
       %> @param obj Instance of PAData.
       %> @param File handle (fid) to open file.  Will be rewound on exit.
       % =================================================================
       function loadFileHeader(obj,fid)
           %  ------------ Data Table File Created By ActiGraph GT3XPlus ActiLife v6.9.2 Firmware v3.2.1 date format M/d/yyyy Filter Normal -----------
           %  Serial Number: NEO1C15110135
           %  Start Time 18:00:00
           %  Start Date 1/23/2014
           %  Epoch Period (hh:mm:ss) 00:00:01
           %  Download Time 12:59:00
           %  Download Date 1/24/2014
           %  Current Memory Address: 0
           %  Current Battery Voltage: 4.13     Mode = 61
           %  --------------------------------------------------
           
           %get to the start
           frewind(fid);
           tline = fgetl(fid);
           commentLine = '------------';
           %make sure we are dealing with a file which has a header           
           if(strncmp(tline,commentLine, numel(commentLine)))
               fgetl(fid);
               tline = fgetl(fid);
               exp = regexp(tline,'^Start Time (.*)','tokens');
               if(~isempty(exp))
                   obj.startTime = exp{1}{1};
               end
               %  Start Date 1/23/2014
               tline = fgetl(fid);
               obj.startDate = strrep(tline,'Start Date ','');
               
               % Pull the following line from the file and convert hh:mm:ss
               % to total seconds
               %  Epoch Period (hh:mm:ss) 00:00:01
               a=fscanf(fid,'%*s %*s %*s %d:%d:%d');
               obj.epochPeriodSec = [3600 60 1]* a;
           end
           frewind(fid);
       end
       
       % ======================================================================
       %> @brief Loads an accelerometer data file.
       %> @param obj Instance of PAData.
       %> @param fullfilename (optional) Full filename to load.  If this
       %> is not included, or does not exist, then the instance variables pathname and filename
       %> are used to identify the file to load.
       % =================================================================
       function loadFile(obj,fullfilename)
           
           if(nargin<2 || ~exist(fullfilename,'file'))
               fullfilename = obj.getFullFilename();
               
               %filtercell = {'*.csv','semicolon separated data';'*.*','All files (*.*)'};
               %msg = 'Select the .csv file';
               %fullfilename = uigetfullfile(filtercell,pwd,msg);
           end           
           
           if(exist(fullfilename,'file'))
               fid = fopen(fullfilename,'r');
               if(fid>0)
                   try
                       obj.loadFileHeader(fid);
                       delimiter = ',';
                       % header = 'Date	 Time	 Axis1	Axis2	Axis3	Steps	Lux	Inclinometer Off	Inclinometer Standing	Inclinometer Sitting	Inclinometer Lying	Vector Magnitude';
                       headerLines = 11; %number of lines to skip
                       scanFormat = '%s %s %u16 %u16 %u16 %u8 %u8 %u8 %u8 %u8 %f32';
                       dataCell = textscan(fid,scanFormat,'delimiter',delimiter,'headerlines',headerLines);

                       %Date time is not handled yet
                       % obj.date = dataCell{1};
                       % obj.time = dataCell{2};
                       
                       obj.accelRaw.x = dataCell{3};
                       obj.accelRaw.y = dataCell{4};
                       obj.accelRaw.z = dataCell{5};
                       obj.steps = dataCell{6}; %what are steps?
                       obj.lux = dataCell{7};
                       obj.inclinometer.off = dataCell{8};
                       obj.inclinometer.standing = dataCell{8};
                       obj.inclinometer.sitting = dataCell{8};
                       obj.inclinometer.lying = dataCell{8};
                       obj.vecMag = dataCell{8};
                       numSamples = numel(obj.accelRaw.x);
                       fprintf('%d rows loaded from %s\n',numSamples,fullfilename);
                       obj.durationSec = numSamples*obj.epochPeriodSec;
                       fclose(fid);
                   catch me
                       showME(me);
                       fclose(fid);
                   end
               else
                   fprintf('Warning - could not open %s for reading!\n',fullfilename);
               end
           else
               if(isempty(fullfilename))
                   
               else
                   fprintf('Warning - %s does not exist!\n',fullfilename);
               end
           end
           
       end
       
   end
   
   methods(Static)
       
       % ======================================================================
       %> @brief Evaluates the range (min, max) of components found in the
       %> input struct argument and returns the range as struct values with
       %> matching fieldnames/organization as the input struct's highest level.
       %> @param A structure whose fields are either structures or vectors.
       %> @retval structRange a struct whose fields correspond to those of
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
       %> @param A structure whose fields are either structures or vectors.
       %> @retval Nx2 vector of minmax values for the given dataStruct.
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
               minmaxVec = minmax(dataStruct(:)');
           end
       end
       
       
       % ======================================================================
       %> @brief Returns an empty struct with fields that mirror PAData's
       %> time series instance variables that contain 
       %> @retval tsStruct A struct of PAData's time series instance variables, which 
       %> include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - inclinometer
       %> - lux
       %> - vecMag
       % =================================================================      
       function dat = getDummyStruct()
           accelR.x =[];
           accelR.y = [];
           accelR.z = [];
           dat.accelRaw = accelR;
           incl.off = [];
           incl.standing = [];
           incl.sitting = [];
           incl.lying = [];
           dat.inclinometer = incl;
           dat.lux = [];
           dat.vecMag = [];
       end
   end
end