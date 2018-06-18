function coptr2actigraph(fileOrPathname)
    persistent lastDirname;
    if(nargin<1 || isempty(fileOrPathname) || ~exist(fileOrPathname,'file'))
        lastDirname = uigetfulldir(lastDirname,'Enter the path containg .csv files to convert');
        if(~isempty(lastDirname))
            coptr2actigraph(lastDirname);        
        else
            fprintf('User cancelled\n');
        end        
    else
        if(isdir(fileOrPathname))
            % get all .csv files in the directory
            [files,fullnames] = getFilenamesi(fileOrPathname,'csv');
            toFolder = fullfile(fileOrPathname,'transcodeOut');
            if(isormkdir(toFolder))
                for f=1:numel(fullnames)
                    transcode(fullnames{f},toFolder);
                end
                fprintf('All done!\n');
            end            
        elseif(exist(fileOrPathname,'file'))
            transcode(fileOrPathName);
        end
    end
end

function didTranscode = transcode(fromFullFilename,toPathOrFilename)
    didTranscode = false;
    [fromPath, fromFile, fromExt]  = fileparts(fromFullFilename);
    fromFilename = [fromFile,fromExt];
    
    % clean up some file naming convention here
    toFilename = strrep(fromFilename,'merge1sec_','');

    if(nargin<2 || isempty(toPathOrFilename))
        toFullFilename = fullfile(fromPath, sprintf('transcoded_%s',toFilename));
    elseif(isdir(toPathOrFilename))
        toFullFilename = fullfile(toPathOrFilename,toFilename);
    else
        toFullFilename=toPathOrFilename;
    end
    fidIn = fopen(fromFullFilename,'r');
    if(fidIn>0)
        fidOut = fopen(toFullFilename,'w');
        if(fidOut>0)
            fprintf('Transcode %s to %s\n',fromFullFilename,toFullFilename);

            % headerInStr = fgetl(fidIn); % waistwaist_axis1,waistwaist_axis2,waistwaist_axis3,waistwaist_steps,waistwaist_lux,waistwaist_incl_off,waistwaist_incl_stand,waistwaist_incl_sit,waistwaist_incl_lying,waistwaist_vm,id,se_event,impute,new_dttm
            % actigraphHeader=              'Date,Time,Axis1,Axis2,Axis3,Steps,                                            Lux,Inclinometer.Off,Inclinometer.Standing,Inclinometer.Sitting,Inclinometer.Lying,Vector.Magnitude'],...
        
            frewind(fidIn);
            fmtIn = [repmat('%d',1,9),'%f %*d %*s %*d %d'];
            dataIn = textscan(fidIn,fmtIn,'headerlines',1,'delimiter',',','collectoutput',true);
            matIn = double(dataIn{1}); %int32
            vmIn = double(dataIn{2}); % float
            sasDatenums = double(dataIn{3}); %int32
            matlabDatenums = datenum_sas2matlab(sasDatenums);
            epochPeriodSec = 1;
            startDatenum=matlabDatenums(1);
            downloadDatenum = matlabDatenums(1)+datenum(0,0,0,0,0,1);            
            headerStr = generateActigraphHeader(startDatenum,downloadDatenum,epochPeriodSec);
            fprintf(fidOut,headerStr);
            dateStrings = datestr(matlabDatenums,'mm/dd/yyyy,HH:MM:SS');
            %for row = 1:size(matIn,1)
            fmt = ['\n',repmat('%c',1,size(dateStrings,2)),repmat(',%d',1,size(matIn,2)),',%f'];
            dataOut = [dateStrings+0,matIn,vmIn];
            fprintf(fidOut,fmt,dataOut');
            %end
            
            
            fclose(fidOut);
            fprintf('Finished that one\n');
            
            didTranscode = true;
        end
        fclose(fidIn);
    end
end
% 1/1/17,12:00:00,0,0,0,0,0,1,0,0,0,0

function headerStr = generateActigraphHeader(startDatenum,downloadDatenum,epochPeriodSec)
    if(nargin<3)
        epochPeriodSec = 1;
    end
    if(nargin<2 || isempty(downloadDatenum))
        downloadDatenum = now;
    end
    downloadTimeStr = datestr(downloadDatenum,'HH:MM:SS');
    downloadDateStr = datestr(downloadDatenum,'mm/dd/yyyy');
    startTimeStr = datestr(startDatenum,'HH:MM:SS');
    startDateStr = datestr(startDatenum,'mm/dd/yyyy');
    
    epochPeriodStr = datestr(epochPeriodSec/24/3600,'HH:MM:SS');
    headerStr = sprintf(['------------ Data Table File Created By ActiGraph GT3XPlus ActiLife v6.10.2 Firmware v2.5.0 date format M/d/yyyy Filter Normal -----------',...
        '\nSerial Number: NEO1C15110116',...
        '\nStart Time %s',...
        '\nStart Date %s',...
        '\nEpoch Period (hh:mm:ss) %s',...
        '\nDownload Time %s',...
        '\nDownload Date %s',...
        '\nCurrent Memory Address: 0',...
        '\nCurrent Battery Voltage: 3.9     Mode = 61',...
        '\n--------------------------------------------------',...
        '\nDate,Time,Axis1,Axis2,Axis3,Steps,Lux,Inclinometer.Off,Inclinometer.Standing,Inclinometer.Sitting,Inclinometer.Lying,Vector.Magnitude'],...
        startTimeStr,startDateStr,epochPeriodStr,downloadTimeStr,downloadDateStr);
end

