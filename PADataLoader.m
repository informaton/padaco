%> @file PADataLoader.m
%> @brief Accelerometer data loading class.
% ======================================================================
%> @brief The class loads and stores accelerometer data used in the 
%> Physical Activity monitoring project aimed to reduce bbesity 
%> and improve child health.
% ======================================================================
classdef PADataLoader < handle
   properties
       %> @brief Pathname of file containing accelerometer data.
       pathname;
       %> @brief Name of file containing accelerometer data that is loaded.
       filename;
       %> @brief Type of acceleration stored; can be 
       %> - raw This is not processed
       %> - count This is preprocessed
       accelType;
       %> @brief Structure of x,y,z accelerations.  Fields are:
       %> @li - x x-axis
       %> @li - y y-axis
       %> @li - z z-axis       
       accel;
       %> @brief Structure of inclimoter values.  Fields include:
       %> @li - off
       %> @li - standing
       %> @li - sitting
       %> @li - lying   
       inclinometer;
       %> @brief Epoch duration (in seconds) that file data was stored at.
       %> This is the sampling rate of the file output.       
       epochDurSec;       
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
   end
   
   methods
       
        % ======================================================================
        %> @brief Constructor for PADataLoader class.
        %> @param Optional entries can be either
        %> @li Full filename (i.e. with pathname) of accelerometer data to load.
        %> %li Pathname containing accelerometer files to be loaded.
        %> @param Optional Filename of accelerometer data to load.
        %> @note: This is only supplied in the event that the first
        %> parameter is passed as the pathname for the acceleromter files.
        %> @retval Instance of PADataLoader.
        % =================================================================       
       function obj = PADataLoader(fullfileOrPath,filename)
           
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
        %> @brief Returns the full filename (pathname + filename) of 
        %> the accelerometer data.
        %> @param obj Instance of PADataLoader
        % =================================================================
       function fullFilename = getFullFilename(obj)
           fullFilename = fullfile(obj.pathname,obj.filename);
       end

       % ======================================================================
       %> @brief Load CSV header values (start time, start date, and epoch
       %> period).
       %> @param obj Instance of PADataLoader.
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
               a=fscanf(fid,'%*s %*s %*s %d:%d:%d');
               obj.epochDurSec  =[3600 60 1]* a;
           end
           frewind(fid);
       end
       
       % ======================================================================
       %> @brief Loads an accelerometer data file.
       %> @param obj Instance of PADataLoader.
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
                       
                       obj.accel.x = dataCell{3};
                       obj.accel.y = dataCell{4};
                       obj.accel.z = dataCell{5};
                       obj.steps = dataCell{6}; %what are steps?
                       obj.lux = dataCell{7};
                       obj.inclinometer.off = dataCell{8};
                       obj.inclinometer.standing = dataCell{8};
                       obj.inclinometer.sitting = dataCell{8};
                       obj.inclinometer.lying = dataCell{8};
                       obj.vecMag = dataCell{8};
                       fprintf('%d rows loaded from %s\n',numel(obj.accel.x),fullfilename);
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
      
   end
end