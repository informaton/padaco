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
       %> - accelRaw [default is 40Hz]
       %> - inclinometer
       %> - lux
       %> - vecMag
       sampleRate;
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
       
       label;
       color;
       offset;
       scale;
       yDelta;
       
   end
   
   properties (Access = private)
       %> Current epoch.  Current position in the raw data.  The first epoch is '1' (i.e. not zero because this is MATLAB programming)
       curEpoch; 
       %> Number of samples contained in the data (accelRaw.x)
       durSamples; 
       
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
           
           obj.color.accelRaw.x.color = 'r';
           obj.color.accelRaw.y.color = 'b';
           obj.color.accelRaw.z.color = 'g';
           
           obj.color.inclinometer.standing.color = 'k';
           obj.color.inclinometer.lying.color = 'k';
           obj.color.inclinometer.sitting.color = 'k';
           obj.color.inclinometer.off.color = 'k';
           
           obj.color.lux.color = 'y';
           obj.color.vecMag.color = 'm';
           obj.color.steps.color = 'o'; 
           
           
           obj.scale.accelRaw.x = 1;
           obj.scale.accelRaw.y = 1;
           obj.scale.accelRaw.z = 1;
           obj.scale.inclinometer.standing = 1;
           obj.scale.inclinometer.lying = 1;
           obj.scale.inclinometer.sitting = 1;
           obj.scale.inclinometer.off = 1;
           obj.scale.lux = 1;
           obj.scale.vecMag = 1;
           obj.scale.steps = 1; 
          
           obj.sampleRate.accelRaw = 40;
           obj.sampleRate.inclinometer = 40;
           obj.sampleRate.lux = 40;
           obj.sampleRate.vecMag = 40;
           obj.curEpoch = 1;
           obj.epochDurSec = 30;
           
           obj.loadFile();
           
           obj.yDelta = 0.05*diff(obj.getMinmax('all'));
           obj.offset.accelRaw.x = obj.yDelta*1;
           obj.offset.accelRaw.y = obj.yDelta*5;
           obj.offset.accelRaw.z = obj.yDelta*10;
           obj.offset.inclinometer.standing = obj.yDelta*14;
           obj.offset.inclinometer.lying = obj.yDelta*15;
           obj.offset.inclinometer.sitting = obj.yDelta*16;
           obj.offset.inclinometer.off = obj.yDelta*17;
           obj.offset.lux = obj.yDelta*18;
           obj.offset.vecMag = obj.yDelta*19;
           obj.offset.steps = obj.yDelta*20; 
           
           
           % label properties for visualization
           obj.label.accelRaw.x.string = 'X';
           obj.label.accelRaw.y.string = 'Y';
           obj.label.accelRaw.z.string = 'Z';
           
           obj.label.inclinometer.standing.string = 'Standing';
           obj.label.inclinometer.lying.string = 'Lying';
           obj.label.inclinometer.sitting.string = 'Sitting';
           obj.label.inclinometer.off.string = 'Off';
           
           obj.label.lux.string = 'Lux';
           obj.label.vecMag.string = 'Magnitude';
           obj.label.steps.string = 'Steps';  
           
           obj.label.accelRaw.x.position = [0 0 0];
           obj.label.accelRaw.y.position = [0 0 0];
           obj.label.accelRaw.z.position = [0 0 0];
           
           obj.label.inclinometer.standing.position = [0 0 0];
           obj.label.inclinometer.lying.position = [0 0 0];
           obj.label.inclinometer.sitting.position = [0 0 0];
           obj.label.inclinometer.off.position = [0 0 0];
           
           obj.label.lux.position = [0 0 0];
           obj.label.vecMag.position = [0 0 0];
           obj.label.steps.position = [0 0 0]; 
           
       end
       
       % ======================================================================
       %> @brief Returns a structure of PAData's time series fields and
       %> values, depending on the user's input selection.
       %> @param Instance of PAData.
       %> @param Type of structure to be returned; optional.  A string.  Possible
       %> values include:
       %> - @b dummy Empty data.
       %> - @b dummydisplay Holds generic line properties for the time series structure.
       %> - @b current Time series data with offset and scaling values applied.
       %> - @b currentdisplay Time series data with offset and scaling values applied
       %> and stored as 'ydata' child fields.
       %> - @b all All, original time series data.
       %> @retval tsStruct A struct of PAData's time series instance data.  The fields
       %> include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - inclinometer
       %> - lux
       %> - vecMag
       % =================================================================      
       function dat = getStruct(obj,choice)
           if(nargin<2)
               choice = '';
           end
           switch(choice)
               case 'dummy'
                   dat = obj.getDummyStruct();
               case 'dummydisplay'
                   dat = obj.getDummyDisplayStruct();
               case 'current'
                   dat = obj.getCurrentStruct();
               case 'currentdisplay'
                   dat = obj.getCurrentDisplayStruct();
               case 'all'
                   dat = obj.getAllStruct();
               otherwise
                   dat = obj.getAllStruct();
           end
       end
       
       %> @brief overloaded subsindex method returns structure of time series data
       %> at indices provided. 
       %> @param Instance of PAData
       %> @param Vector (logical or ordinal) of indices to select time
       %> series data by.
       %> @retval A struct of PAData's time series instance data for the indices provided.  The fields
       %> include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - inclinometer
       %> - lux
       %> - vecMag
       function dat = subsindex(obj,indices)
           
           dat.accelRaw.x = double(obj.accelRaw.x(indices));
           dat.accelRaw.y = double(obj.accelRaw.y(indices));
           dat.accelRaw.z = double(obj.accelRaw.z(indices));
           dat.inclinometer.off = double(double(obj.inclinometer.off(indices)));
           dat.inclinometer.standing = double(obj.inclinometer.standing(indices));
           dat.inclinometer.sitting = double(obj.inclinometer.sitting(indices));
           dat.inclinometer.lying = double(obj.inclinometer.lying(indices));
           dat.lux = double(obj.lux(indices));
           dat.vecMag = double(obj.vecMag(indices));           
       end
       
       
       function sref = subsref(obj,s)
           if(strcmp(s(1).type,'()') && length(s)<2)
               % Note that obj.Data is passed to subsref
               sref = obj.subsindex(cell2mat(s.subs));               
           else
               sref = builtin('subsref',obj,s);
           end
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
           
           epochRange(2) = min([epochRange(2),obj.durationSamples()]);
       end

       % ======================================================================
       %> @brief Returns the duration of an epoch in terms of sample points.
       %> @param Instance of PAData.
       %> @retval (Integer) Duration of the epoch window in units of sample points.
       %> @note Calcuation based on instance variables epochDurSec and sampleRate
       % =================================================================      
       function epochDurSamples = getEpochDurSamples(obj)
           epochDurSamples = obj.epochDurSec*obj.getSampleRate();
       end
       
       % --------------------------------------------------------------------
       %> @brief Set the current epoch for the instance variable accelObj
       %> (PAData)
       %> @param Instance of PAContraller
       %> @param The epoch to set curEpoch to.
       %> @retval The current value of instance variable curEpoch.
       %> @note If the input argument for epoch is negative or exceeds 
       %> the maximum epoch value for the time series data, then it is not used
       %> and the curEpoch value is retained, and also returned.
       % --------------------------------------------------------------------
       function curEpoch = setCurEpoch(obj,epoch)
           if(epoch>0 && epoch<=obj.getEpochCount())
               obj.curEpoch = epoch;
               %obj.setCurrentStruct();
           end
           %returns the current epoch, wether it be 'epoch' or not.
           curEpoch = obj.getCurEpoch();
       end
       
       % --------------------------------------------------------------------
       % @brief Returns the current epoch.
       % @param Instance of PAData
       % @retval The current epoch;
       % --------------------------------------------------------------------
       function curEpoch = getCurEpoch(obj)
           curEpoch = obj.curEpoch;
       end
       
       % --------------------------------------------------------------------
       % @brief Returns the number of samples contained in the time series data.
       % @param Instance of PAData
       % @retval Number of elements contained in durSamples instance var
       %> (initialized by number of elements in accelRaw.x
       % --------------------------------------------------------------------
       function durationSamp = durationSamples(obj)
           durationSamp = obj.durSamples;
       end
       
       % --------------------------------------------------------------------
       %> @brief Set the epoch duration value in seconds.  This is the
       %> displays window size (i.e. one epoch shown at a time), in seconds.
       %> @param Instance of PAData
       %> @param Duration in seconds.  Must be positive.  Value is first
       %> rounded to ensure it is an integer.
       %> @retval Epoch duration in seconds of obj.
       %> @note Instance variable curEpoch is recalculated based on new
       %> epoch duration.
       % --------------------------------------------------------------------
       function durSec = setEpochDurSec(obj,durSec)
           durSec = round(durSec);
           if(durSec>0)
               % requires the current epochDurSec value be initialized
               % already.
               epochRange = obj.getCurEpochRangeAsSamples();                            
               obj.epochDurSec = durSec;
               
               %calculate the current epoch based on the start sample using
               %the previous versions epoch
               obj.setCurEpoch(obj.sample2epoch(epochRange(1)));      
           else
               durSec = obj.epochDurSec;
           end
       end
       
       % --------------------------------------------------------------------
       % @brief Returns the color instance variable
       % @param Instance of PAData
       % @retval A struct of color values correspodning to the time series
       % fields of obj.
       % --------------------------------------------------------------------
       function color = getColor(obj)
           color = obj.color;
       end

       % --------------------------------------------------------------------
       % @brief Returns the label instance variable
       % @param Instance of PAData
       % @retval A struct of string values which serve to label the correspodning to the time series
       % fields of obj.
       % --------------------------------------------------------------------
       function label = getLabel(obj)
           label = obj.label;
       end
       
       % --------------------------------------------------------------------
       %> @brief Returns the samplerate of the x-axis accelerometer.
       %> @param Instance of PAData
       %> @retval Sample rate of the x-axis accelerometer.
       % --------------------------------------------------------------------
       function fs = getSampleRate(obj)
           fs = obj.sampleRate.accelRaw;
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
       %> @brief Returns the minimum and maximum amplitudes that can be
       %> displayed uner the current configuration.
       %> @param Instance of PAData.
       %> @retval 1x2 vector containing ymin and ymax.
       % ======================================================================
       function yLim = getDisplayMinMax(obj)
           
           yLim = [0, 20 ]*obj.yDelta;
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
           
           % get all data for all structs.
           dataStruct = obj.getStruct('all'); 
           
           if(nargin<2 || isempty(field))
               field = 'all';
           end

           % get all fields
           if(strcmpi(field,'all'))
               minMax = obj.getRecurseMinmax(dataStruct);
           else
               
               % if it is not a struct (and is a 'string')
               % then get the value for it.
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
           else
               % unset - we don't know
               obj.epochPeriodSec = 0;
               obj.startDate = 'N/A';
               fprintf(' File does not include header.  Default values set for start date and epochPeriodSec (1).\n');
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
                       obj.durSamples = numel(obj.accelRaw.x);
                       numSamples = obj.durationSamples();
                       
                       fprintf('%d rows loaded from %s\n',numSamples,fullfilename);
                       
                       %either use epochPeriodSec or use samplerate.
                       if(obj.epochPeriodSec>0)
                           obj.durationSec = numSamples*obj.epochPeriodSec;
                       else
                           obj.durationSec = numSamples/obj.getSampleRate();   
                       end                       
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
       
       % ======================================================================
       %> @brief Calculates, and returns, the epoch for the given sample index of a signal.
       %> @param Instance of PAData.
       %> @param Sample point to discover the containing epoch of.
       %> @param epoch Epoch duration in seconds (scalar) (optional)
       %> @param Sample rate of the data (optional)
       %> @retval The epoch.
       % ======================================================================
       function epoch = sample2epoch(obj,sample,epochDurSec,samplerate)           
           if(nargin<4)
               samplerate = obj.getSampleRate();
           end
           if(nargin<3)
               epochDurSec = obj.epochDurSec;
           end;
           epoch = ceil(sample/(epochDurSec*samplerate));
       end
   end
   
   methods (Access = private)
   
       % ======================================================================
       %> @brief Returns a structure of an insance PAData's time series data.
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
       function dat = getAllStruct(obj)
           dat.accelRaw = obj.accelRaw;
           dat.inclinometer = obj.inclinometer;
           dat.lux = obj.lux;
           dat.vecMag = obj.vecMag;
       end
       
       
       % ======================================================================
       %> @brief Returns a structure of an insance PAData's time series
       %> data at the current epoch.
       %> @param Instance of PAData.
       %> @retval tsStruct A struct of PAData's time series instance data.  The fields
       %> include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - inclinometer (struct with more fields)
       %> - lux
       %> - vecMag
       % =================================================================      
       function curStruct = getCurrentStruct(obj)
           epochRange = obj.getCurEpochRangeAsSamples();
           % This does not work:
           % obj.curStruct = obj(epochRange);
           curStruct = obj.subsindex(epochRange(1):epochRange(end));
       end
       
       % ======================================================================
       %> @brief Returns the time series data as a struct for the current epoch range,
       %> adjusted for visual offset and scale.       
       %> @param Instance of PAData.
       %> @retval tsStruct A struct of PAData's time series instance data.  The fields
       %> include:
       %> - accelRaw.x
       %> - accelRaw.y
       %> - accelRaw.z
       %> - inclinometer (struct with more fields)
       %> - lux
       %> - vecMag
       % =================================================================      
       function dat = getCurrentDisplayStruct(obj)
           dat = PAData.structEval('times',obj.getStruct('current'),obj.scale);
           
           epochRange = obj.getCurEpochRangeAsSamples();
           lineProp.xdata = epochRange(1):epochRange(end);            
           % put the output into a 'ydata' field for graphical display
           % property of a line.
           dat = PAData.structEval('plus',dat,obj.offset,'ydata');
           
           dat = PAData.appendStruct(dat,lineProp);
       end
              
       
   end
   
   methods(Static)

       % ======================================================================
       %> @brief Evaluates the two structures, field for field, using the function name
       %> provided.
       %> @param A string name of the operation (via 'eval') to conduct at
       %> the lowest level.  Additional operands include:
       %> - passthrough Requires Optional field name to be set.
       %> - calculateposition (requires rtStruct to have .xdata and .ydata
       %> fields.
       %> @param A structure whose fields are either structures or vectors.
       %> @param A structure whose fields are either structures or vectors.
       %> @param Optional field name to subset the resulting output
       %> structure to (see last example).  This can be useful if the
       %> output structure will be passed as input that expects a specific
       %> sub field name for the values (e.g. line properties).  See last
       %> example below.
       %> @retval A structure with same fields as ltStruct and rtStruct
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
       %> @param A string name of the operation (via 'eval') to conduct at
       %> the lowest level. 
       %> @param A structure whose fields are either structures or vectors.
       %> @param A matrix value of the same dimension as the first structure's (ltStruct)
       %> non-struct field values.
       %> @param Optional field name to subset the resulting output
       %> structure to (see last example).  This can be useful if the
       %> output structure will be passed as input that expects a specific
       %> sub field name for the values (e.g. line properties).  See last
       %> example below.
       %> @retval A structure with same fields as ltStruct and optionally 
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
       %> @param A structure whose fields are to be appended by the other.
       %> @param A structure whose fields are will be appened to the other.
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
       %> @param A structure whose fields are to be appended by the other.
       %> @param A structure whose fields are will be appened to the other.
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
               minmaxVec = double(minmax(dataStruct(:)'));
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
       
       % ======================================================================
       %> @brief Returns a struct with subfields that hold the line properties
       %> for graphic display of the time series instance variables.
       %> @retval tsStruct A struct of PAData's time series instance variables, which 
       %> include:
       %> - accelRaw.x.(xdata, ydata, color)
       %> - accelRaw.y.(xdata, ydata, color)
       %> - accelRaw.z.(xdata, ydata, color)
       %> - inclinometer.(xdata, ydata, color)
       %> - lux.(xdata, ydata, color)
       %> - vecMag.(xdata, ydata, color)
       % =================================================================      
       function dat = getDummyDisplayStruct()
           lineProps.xdata = [1 1200];
           lineProps.ydata = [1 1];
           lineProps.color = 'k';
           lineProps.visible = 'on';
           accelR.x = lineProps;
           accelR.y = lineProps;
           accelR.z = lineProps;
           dat.accelRaw = accelR;
           incl.off = lineProps;
           incl.standing = lineProps;
           incl.sitting = lineProps;
           incl.lying = lineProps;
           dat.inclinometer = incl;
           dat.lux = lineProps;
           dat.vecMag = lineProps;
       end
       
       
   end
end