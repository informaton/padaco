%> @file PADeriver.cpp
%> @brief PADeriver serves as model and controller for count derivation
%> working using Padaco based classes.
% ======================================================================
classdef PADeriver < handle
    
    properties(Constant)
        SOI_LABELS = {'X','Y','Z','Magnitude'};
        SOI_FIELDS = {'x','y','z','vecMag'};
    end
    
    properties(Access=private)
        figureH;
        handles;
        %> Struct with fields
        %> - raw Instance of PAData
        %> - count Instance of PAData
        dataObject;
        
        %> Struct with fields
        %> - raw Sample rate of raw acceleration
        %> - count Number of epochs per second
        sampleRate;
        
        %> Signal of interest, can be:
        %> - x
        %> - y
        %> - z
        %> - vecMag
        soi;  %signal of interest
    end
    
    methods
        
        function this =PADeriver()
            this.soi = 'x';
            this.initGUI();
        end
        
    end
    
    methods(Access=protected)
    
    end
    
    methods(Access=private)
        function initGUI(this)
            this.figureH = deriveIt();
            this.handles = guidata(this.figureH);            
            set(this.handles.push_loadFile,'callback',@this.deriveIt_LoadFileCallbackFcn);
            
            set(this.handles.menu_soi,'string',this.SOI_LABELS,'value',find(strcmpi(this.soi,this.SOI_FIELDS),1));
        end
        
        function deriveIt_LoadFileCallbackFcn(this,hObject, eventdata)
            testingPath = '/Users/unknown/Data/GOALS/Temp';
            % sqlite_testFile = '704397t00c1_1sec.sql';  % SQLite format 3  : sqlite3 -> .open 704397t00c1_1sec.sql; .tables; select * from settings; .quit;  (ref: https://www.sqlite.org/cli.html)
            csv_testFile = '704397t00c1.csv';
            %             raw_filename = fullfile(testingPath,bin_testFile);
            count_filename = fullfile(testingPath,csv_testFile);
            
            multiSelectFlag = 'off';
            %     fullFilename = uigetfullfile({'*.csv','Counts data (*.csv)';'*.bin','Binary acceleration data (.bin)'},'Select a file with counts or acceleration',...
            %         multiSelectFlag,initFile);
            
            count_filename = uigetfullfile({'*.csv','Counts data (*.csv)'},'Select counts file',...
                multiSelectFlag,count_filename);
            
            if(~isempty(count_filename))
                
                try
                    [filePath, ~, ~] = fileparts(count_filename);
                    bin_testFile = 'activity.bin';  %firmware version 2.5.0
                    
                    raw_filename = fullfile(filePath,bin_testFile);
                    
                    set(hObject,'enable','off');
                    drawnow();
                    this.dataObject.raw = PAData(raw_filename);
                    this.dataObject.count = PAData(count_filename);
                    
                    %raw - sampled at 40 Hz
                    %count - 1 Hz -> though upsampled from file to 40Hz during data object
                    %loading.
                    this.sampleRate = this.dataObject.raw.getSampleRate();  %40;
                    
                    firstNonZeroCountValue = find(this.dataObject.count.accel.count.(this.soi),1);
                    
                    %examine big spike of activitiy
                    firstNonZeroCountValue_At_fs = (firstNonZeroCountValue-1)*this.sampleRate+1;
                    
                catch me
                    showME(me);
                    
                end
                set(hObject,'enable','on');
                drawnow();
                
            end
        end

    
    end
    
end