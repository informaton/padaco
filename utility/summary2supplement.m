% A one-off script to export a summary file of 1-minute nonwear data into
% other 

function summary2supplement( config )
if(nargin < 1)
   config = struct('summary_csv_filename', '/Users/unknown/data/goals/t_1/processed/allWear.csv', ...    
    'id_column',1, ...
    'datetime_column',2,...
    'datetime_fmt','yyyy-mm-dd HH:MM:SS',...
    'choi_nw_column',3,...
    'tudor_locke_sleep_column',4,...
    'final_nw_column',5,...
    'wake_nw_column',6,...
    'export_path', '/Users/unknown/data/goals/t_1/nonwear_csv/',...
    'export_filename_pattern','%dt00c11minSupplTable.csv');
end

exportHeaderStr = 'Date, Time,choiNW,FinalSleep,FinalNW,wakeNW';
if( ~exist(config.summary_csv_filename,'file') || ~isormkdir(config.export_path) )
    printError('Summary file (%s) or export path (%s) does not exit',config.summary_csv_filename, config.export_path);
else
    fid = fopen(config.summary_csv_filename,'r');
    if(fid>1)
        tic
        headerStr = fgetl(fid);
        
        allCell = textscan(fid,'%d %q %c %c %c %c','headerlines',1,'delimiter',',');
        fclose(fid);
        numRows = size(allCell{1},1);
        toc
        tic
        datestrMat = datestr(datenum(char(allCell{config.datetime_column}),config.datetime_fmt),'mm/dd/yyyy,HH:MM:SS');
        toc
        ids = unique(allCell{config.id_column});
        tic
        for ind = 1:numel(ids)
            id = ids(ind);
            filename = fullfile(config.export_path,sprintf(config.export_filename_pattern,id));
            fid_exp = fopen(filename,'w');
            if(fid_exp>1)
                fprintf(fid_exp, '%s\n',exportHeaderStr);
                fclose(fid_exp);
            else
                printError('Failed to open %s',filename);
            end
        end
        toc
        fprintf('Finished creating all files\n');
        tic
        for r=1:numRows            
            id = allCell{config.id_column}(r);
            filename = fullfile(config.export_path,sprintf(config.export_filename_pattern,id));
            if(exist(filename,'file'))
                fid_exp = fopen(filename,'a');
                if(fid_exp>1)
                    dStr = datestrMat(r,:);
                    choi = allCell{config.choi_nw_column}(r);
                    tudor = allCell{config.tudor_locke_sleep_column}(r);
                    nw_final = allCell{config.final_nw_column}(r);
                    nw_wake_only = allCell{config.wake_nw_column}(r);
                    fprintf(fid_exp,'%s,%c,%c,%c,%c\n',dStr,choi,tudor,nw_final,nw_wake_only);
                    fclose(fid_exp);
                end
            end
            if(~mod(r,1000))
                fprintf('%02.f %% complete\n',r/numRows*100);
            end
        end
        toc
    else
        printError();
    end
end
end

function printError(varargin)
    if(~nargin)
        errorMSG = 'Cannot run.  <helpful message goes here>';
    else
        errorMSG = sprintf(varargin{:});
    end
    fprintf(1,'%s\n',errorMSG);
end

% Header(0): "ID","TimeStamp","choiNW","FinalSleep","FinalNW","wakeNW"
% Row(1): 700023,"2012-10-31 00:00:00",1,1,0,0
% Row(2): 700023,"2012-10-31 00:01:00",1,1,0,0


% ------------ Data Table File Created By ActiGraph GT3XPlus ActiLife v6.10.2 Firmware v2.0.0 date format M/d/yyyy Filter Normal -----------
% Serial Number: CLE1B41120204
% Start Time 00:00:00
% Start Date 1/30/2013
% Epoch Period (hh:mm:ss) 00:00:01
% Download Time 13:25:46
% Download Date 2/6/2013
% Current Memory Address: 0
% Current Battery Voltage: 3.95     Mode = 61
% --------------------------------------------------
% Date, Time, Axis1,Axis2,Axis3,Steps,Lux,Inclinometer Off,Inclinometer Standing,Inclinometer Sitting,Inclinometer Lying,Vector Magnitude
% 1/30/2013,00:00:00,0,0,0,0,0,0,0,0,1,0
% 1/30/2013,00:00:01,0,0,0,0,0,0,0,0,1,0
% 1/30/2013,00:00:02,0,0,0,0,0,0,0,0,1,0
