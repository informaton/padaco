%> @file PAAppController.cpp
%> @brief PAAppController serves as Padaco's controller component (i.e. in the model, view, controller paradigm).
% ======================================================================
%> @brief PAAppController serves as the UI component of event marking in
%> the Padaco.
%
%> In the model, view, controller paradigm, this is the
%> controller.
classdef PAAppController < PAFigureController    
    events
       StatToolCreationSuccess;
       StatToolCreationFailure;
    end
    
    properties(Constant)
        versionMatFilename = 'version.chk';
    end
    
    properties(Constant,Access=private)
        NWAnchor = struct('tag','text_status','y',0.967,'units','normalized');
    end
    
    properties(Access=private)
        resizeValues; % for handling resize functions
        versionNum;
        iconFilename;
    end
    
    properties(SetAccess=protected)
        toolbarH; % struct containining handles for toolbar buttons
        
        %> acceleration activity object - instance of PASensorData
        SensorData;
        
        %> Instance of PAStatTool - results controller when in results view
        %> mode.
        StatTool;
        
        %> Instance of PAOutcomesTableData - for importing outcomes data to be
        %> used with cluster analysis.
        OutcomesTableData;
        
        %> Instance of PAAppSettings - keeps track of application wide settings.
        AppSettings;
        %> Instance of PASingleStudyController - Padaco's view component.
        SingleStudy;

        %> Struct of batch settings with fields as described by
        %PABatchTool's getDefault
        % batch;
        rootpathname;
        
        %> struct to keep track of various Padaco states
        %         STATE;  % commented out on 5/5/2016
        Padaco_loading_file_flag; %boolean set to true when initially loading a src file
        Padaco_mainaxes_ylim;
        Padaco_mainaxes_xlim;
    end
    
    methods
        
        function obj = PAAppController(hFigure,...
                rootPathname,...
                parameters_filename)
            
            if(nargin<1)
                hFigure = [];
            end
            if(nargin<2)
                rootPathname = fileparts(mfilename('fullpath'));
            end
            obj@PAFigureController(hFigure);
            obj.rootpathname = rootPathname;
            %check to see if a settings file exists
            if(nargin<3)
                parameters_filename = '_padaco.parameters.txt';
            end
            
            configPath = getSavePath();
            obj.iconFilename = fullfile(rootPathname,'resources','icons','logo','icon_32.png');
            obj.setVersionNum();
            
            obj.addlistener('StatToolCreationSuccess',@obj.StatToolCreationCallback);
            obj.addlistener('StatToolCreationFailure',@obj.StatToolCreationCallback);
            
            %create/intilize the settings object
            obj.AppSettings = PAAppSettings(configPath,parameters_filename);
            obj.OutcomesTableData = PAOutcomesTableData(obj.AppSettings.OutcomesTableData);
            obj.OutcomesTableData.addlistener('LoadSuccess',@obj.outcomesLoadCb);
            obj.OutcomesTableData.addlistener('LoadFail',@obj.outcomesLoadCb);
            
            % if did Init then we are here ...
            obj.setStatusHandle(obj.handles.text_status);
            
            % Create a SingleStudy class
            obj.SingleStudy = PASingleStudyController(obj.figureH, obj.AppSettings.SingleStudy);
            
            % Create a results class
            obj.StatTool = PAStatTool(obj.figureH, obj.AppSettings.StatTool); % obj.resultsPathname
            obj.StatTool.setIcon(obj.iconFilename);
           
            fprintf(1,'Need to return to outcomes table data refactor\n');
%             if(~isempty(obj.OutcomesTableData) && obj.OutcomesTableData.importOnStartup && obj.StatTool.useOutcomes)
%                 obj.StatTool.setOutcomesTable(obj.OutcomesTableData);
%             end

            obj.showBusy([],'all')
            set(obj.figureH,'visible','on');            
            
            set(obj.figureH,'CloseRequestFcn',{@obj.figureCloseCallback,guidata(obj.figureH)});
            
            % set(obj.figureH,'scrollable','on'); - not supported
            % for guide figures (figure)
            %configure the menu bar callbacks.
            obj.initMenubarCallbacks();
            
            % attempt to load the last set of results
            lastViewMode = obj.getSetting('viewMode');
            try
                obj.setViewMode(lastViewMode);
                obj.initResize();
            catch me
                showME(me);
            end
        end
        
        %% Shutdown functions
        %> Destructor
        function close(obj)
            obj.saveAppSettings(); %requires AppSettings variable
            obj.AppSettings = [];
            if(~isempty(obj.StatTool))
                obj.StatTool.delete();
            end
        end
        
        function saveAppSettings(obj)
            obj.refreshAppSettings(); % updates the parameters based on current state of the gui.
            obj.AppSettings.saveToFile();
            fprintf(1,'Settings saved to disk.\n');
        end
        
        %> @brief Sync the controller's settings with the SETTINGS object
        %> member variable.
        %> @param Instance of PAAppController;
        %> @retval Boolean Did refresh = true, false otherwise (e.g. an
        %> error occurred)
        function didRefresh = refreshAppSettings(obj)
            try
                
                refreshObjects = {'SensorData','SingleStudy','StatTool','OutcomesTableData'};
                % importing and batch settings are handled separately..
                for r = 1:numel(refreshObjects)
                    tag = refreshObjects{r};
                    if(~isempty(obj.(tag)))
                        obj.AppSettings.(tag) = obj.(tag).getSaveParameters();
                    end
                    %
                    %                 % update the stat tool settings if it was used successfully.
                    %                 if(~isempty(obj.StatTool) && obj.StatTool.getCanPlot())
                    %                     obj.AppSettings.StatTool = obj.StatTool.getSaveParameters();
                    %                 end
                    %
                end
                obj.AppSettings.Main = obj.getSaveParameters();
                didRefresh = true;
            catch me
                showME(me);
                didRefresh = false;
            end
        end
        
        %% Startup configuration functions and callbacks
        % --------------------------------------------------------------------
        %> @brief Executes when user attempts to close figure_padaco.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to menu_file_quit (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function figureCloseCallback(obj,hObject, varargin)
            try
                obj.close();
                delete(hObject);
            catch ME
                showME(ME);
                pause;
                killall;
            end
        end
        
        %-- Menubar configuration --
        % --------------------------------------------------------------------
        %> @brief Assign figure's menubar callbacks.
        %> Called internally during class construction.
        %> @param obj Instance of PAAppController
        % --------------------------------------------------------------------
        function initMenubarCallbacks(obj)
            
            figHandles = obj.handles;
            
            %% file
            % settings and about
            safeset(figHandles,'menu_file_about','callback',@obj.menuFileAboutCallback);
            safeset(figHandles,'menu_file_settings_application','callback',@obj.menuFileSettingsApplicationCallback);
            safeset(figHandles,'menu_file_settings_usageRules','callback',@obj.menuFileSettingsUsageRulesCallback);
            safeset(figHandles,'menu_load_settings','callback',@obj.loadSettingsCb);
            
            %  open
            safeset(figHandles,'menu_file_open','callback',@obj.menuFileOpenCallback);
            safeset(figHandles,'menu_file_open_resultspath','callback',@obj.menuFileOpenResultsPathCallback);
            
            % import
            safeset(figHandles,'menu_file_openVasTrac','callback',@obj.menuFileOpenVasTracCSVCallback,'enable','off','visible','off');
            safeset(figHandles,'menu_file_openFitBit','callback',@obj.menuFileOpenFitBitCallback,'enable','off','visible','off');
            
            safeset(figHandles,'menu_file_import_csv','callback',@obj.menuFileOpenCsvFileCallback,'enable','off');
            safeset(figHandles,'menu_file_import_general','label','Text (custom)',...
                'callback',@obj.menuFileOpenGeneralCallback,'enable','on');
            safeset(figHandles,'menubar_import_outcomes','callback',@obj.importOutcomesFileCb);
            
            % screeshots
            safeset(figHandles,'menu_file_screenshot_figure','callback',{@obj.menuFileScreenshotCallback,'figure'});
            safeset(figHandles,'menu_file_screenshot_primaryAxes','callback',{@obj.menuFileScreenshotCallback,'primaryAxes'});
            safeset(figHandles,'menu_file_screenshot_secondaryAxes','callback',{@obj.menuFileScreenshotCallback,'secondaryAxes'});
            
            %  quit - handled in main window.
            safeset(figHandles,'menu_file_quit','callback',{@obj.menuFileQuitCallback,guidata(obj.figureH)},'label','Close');
            safeset(figHandles,'menu_file_restart','callback',@restartDlg);
            
            % export
            safeset(figHandles,'menu_file_export','callback',@obj.menu_file_exportMenu_callback);
            if(~isdeployed)
                safeset(figHandles,'menu_file_export_sensorDataObj','callback',@obj.menu_file_export_sensorDataObj_callback);%,'label','Sensor object to MATLAB');
                safeset(figHandles,'menu_file_export_clusterObj','callback',@obj.menu_file_export_clusterObj_callback); %,'label','Cluster object to MATLAB');
            % No point in sending data to the workspace on deployed
            % version.  There is no 'workspace'.
            else
                safeset(figHandles,'menu_file_export_sensorDataObj','visible','off');
                safeset(figHandles,'menu_file_export_clusterObj','visible','off');
            end
            
            safeset(figHandles,'menu_file_export_clusters_to_csv','callback',{@obj.exportClustersCb,'csv'});%, 'label','Cluster results to disk');
            safeset(figHandles,'menu_file_export_clusters_to_xls','callback',{@obj.exportClustersCb,'xls'});%, 'label','Cluster results to disk');
            safeset(figHandles,'menu_export_timeseries_to_disk','callback',@obj.exportTimeSeriesCb);%,'label','Wear/nonwear to disk');
            
            %% View Modes
            safeset(figHandles,'menu_viewmode_timeseries','callback',{@obj.setViewModeCallback,'timeSeries'});
            safeset(figHandles,'menu_viewmode_results','callback',{@obj.setViewModeCallback,'results'});
            
            %% Tools
            safeset(figHandles,'menu_tools_batch','callback',@obj.menuToolsBatchCallback);
            safeset(figHandles,'menu_tools_bootstrap','callback',@obj.menuToolsBootstrapCallback,'enable','off');  % enable state depends on PAStatTool construction success (see obj.events)
            safeset(figHandles,'menu_tools_raw2bin','callback',@obj.menuToolsRaw2BinCallback);
            safeset(figHandles,'menu_tools_coptr2act','callback',@obj.coptr2actigraphCallback);
            
            %% Help
            safeset(figHandles,'menu_help_faq','callback',@obj.menuHelpFAQCallback);
            
            % enable remaining 
            set([
                figHandles.menu_file
                figHandles.menu_file_about
                figHandles.menu_file_settings
                figHandles.menu_file_open    
                figHandles.menu_file_quit
                figHandles.menu_viewmode
                figHandles.menu_help
                figHandles.menu_help_faq
                ],'enable','on');
        end
        
        % Activate the tool when it makes sense to do so.
        function StatToolCreationCallback(this,varargin)            
            if(isa(this.StatTool,'PAStatTool'))
                set(this.handles.menu_tools_bootstrap,'enable','on');
            else
                set(this.handles.menu_tools_bootstrap,'enable','off');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback to display help FAQ from the menubar help->faq menu.
        %> @param obj Instance of PAAppController
        %> @param hObject
        %> @param eventdata
        % --------------------------------------------------------------------
        function menuHelpFAQCallback(this,varargin)
            %msg = sprintf('Help FAQ');
            this.showBusy('Initializing help');
            filename = fullfile(this.rootpathname,'_resources','html','PadacoFAQ.html');
            url = sprintf('file://%s',filename);
            %             web(url,'-notoolbar','-noaddressbox');
            web(url,'-notoolbar','-noaddressbox','-browser');
            %             if(isdeployed)
            %                 web(url,'-notoolbar','-noaddressbox','-browser');
            %             else
            %                 [stat, browserH] = web(url,'-notoolbar','-noaddressbox','-helpbrowser');
            %             end
            %htmldlg('url',url,'title','Padaco FAQ');
            
            this.showReady();
            %             web(url);
        end
        
        function importOutcomesFileCb(this, varargin)
            %f=getOutcomeFiles();
            a = PAOutcomesTableSetup(this.settings.OutcomesTableSetup);
            if(~isempty(a.outcomesFileStruct))
                this.settings.OutcomesTableSetup = a.getSaveParameters();
                showLoadStatus = true;
                this.OutcomesTableData.import(showLoadStatus);
            else
                this.logStatus('User cancelled');
            end
        end
        
        function outcomesLoadCb(this, outcomesController, evtData)
            switch(evtData.EventName)
                case 'LoadSuccess'
                    if(~isempty(this.StatTool))
                        this.StatTool.setOutcomesTable(outcomesController);
                    end
                    this.logStatus('Outcome data loaded successfully');
                case 'LoadFail'
                    this.logStatus('Outcome data did not load successfully');
                otherwise
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Assign figure's file->about menubar callback.
        %> @param obj Instance of PAAppController
        %> @param hObject
        %> @param eventdata
        % --------------------------------------------------------------------
        function menuFileAboutCallback(obj,varargin)
            
            msg = sprintf(['\nPadaco %s\n',...
                '\nA collaborative effort between:',...
                '\n\t1. Stanford''s Pediatric''s Solution Science Lab',...
                '\n\t2. Stanford''s Civil Engineering''s Sustainable Energy Lab',...
                '\n\t3. Stanford''s Quantitative Science Unit',...
                '\n\nSoftware license: TBD',...
                '\nCopyright 2014-%s\n'
                ],obj.getVersionNum(),datestr(max(now,datenum([2019,0,1,0,0,0])),'YYYY'));
            h=pa_msgbox(msg,'About');
            
            mbox_h=findobj(h,'tag','MessageBox');
            ok_h = findobj(h,'tag','OKButton');
            if(~isempty(mbox_h))
                mpos = get(h,'position');
                set(h,'visible','off');
                set(mbox_h,'fontname','arial','fontsize',12');
                set(h,'position',[mpos(1:2), mpos(3:4)*12/10]);
                
                axes_h = get(mbox_h,'parent');
                apos = get(axes_h,'position');
                set(axes_h,'position',apos*12/10);
                
                okPos = get(ok_h,'position');
                set(ok_h,'position',okPos*12/10,'fontsize',12);
                set(h,'visible','on');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Assign figure's menubar callbacks.
        %> Called internally during class construction.
        %> @param obj Instance of PAAppController
        %> @param hObject
        %> @param eventdata
        %> @param optionalSettingsName String specifying the settings to
        %> update (optional)
        % --------------------------------------------------------------------
        function menuFileSettingsApplicationCallback(obj,~,~,optionalSettingsName)
            if(nargin<4)
                optionalSettingsName = [];
            end
            
            % Need to refresh the current settings
            obj.refreshAppSettings();
            settingsEditor = PASettingsEditor(obj.AppSettings);
            
            %wasModified = obj.AppSettings.defaultsEditor(optionalSettingsName);
            
            wasCanceled = isempty(settingsEditor.settings);
            if(~wasCanceled)
                obj.AppSettings = settingsEditor.settings;  
                
                if(strcmpi(obj.getViewMode(),'results'))                
                    initializeOnSet = true;  % This is necessary to update widgets, which are used in follow on call to saveAppSettings
                    obj.StatTool.setWidgetSettings(obj.AppSettings.StatTool, initializeOnSet);
                else
                    obj.SingleStudy.updateWidgets()
                end
                
                obj.setStatus('Settings have been updated.');
                % save parameters to disk - this saves many parameters based on gui selection though ...
                obj.saveAppSettings();
                
                % Activate a refresh()
                obj.setViewMode(obj.getViewMode());                
            end

        end
        
        % --------------------------------------------------------------------
        %> @brief Assign values for usage state classifier rules.
        %> Called internally during class construction.
        %> @param obj Instance of PAAppController
        %> @param hObject
        %> @param eventdata
        %> @param optionalSettingsName String specifying the settings to
        %> update (optional)
        % --------------------------------------------------------------------
        function menuFileSettingsUsageRulesCallback(obj,varargin)
            
            if(~isempty(obj.SensorData))
                usageRules= obj.SensorData.usageStateRules;
            else
                usageRules = obj.AppSettings.SensorData.usageStateRules;
            end
            defaultRules = PASensorData.getDefaults();
            defaultRules = defaultRules.usageStateRules;
            updatedRules = simpleEdit(usageRules,defaultRules);
            
            if(~isempty(updatedRules))
                if(~isempty(obj.SensorData))
                    obj.SensorData.setUsageClassificationRules(updatedRules);
                else
                    obj.AppSettings.SensorData.usageStateRules = updatedRules;
                end
                
                %                 if(isa(obj.StatTool,'PAStatTool'))
                %                     obj.StatTool.setWidgetSettings(obj.AppSettings.StatTool);
                %                 end
                fprintf('Settings have been updated.\n');
                
                % save parameters to disk
                obj.saveAppSettings();
                
                % Activate a refresh()
                obj.setViewMode(obj.getViewMode());
                
            end
        end 
        
        function loadSettingsCb(obj, varargin)
            obj.StatTool.loadSettings();
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a file.
        %> @param obj Instance of PAAppController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        % --------------------------------------------------------------------
        function menuFileOpenCallback(obj,varargin)
            %SensorData.pathname	/Volumes/SeaG 1TB/sampleData/csv
            %SensorData.filename	700023t00c1.csv.csv
            f=uigetfullfile({'*.csv;*.raw;*.bin','All (counts, raw accelerations)';
                '*.csv','Comma Separated Values';
                '*.bin','Raw Acceleration (binary format: firmwares 2.2.1, 2.5.0, and 3.1.0)';
                '*.raw','Raw Acceleration (comma separated values)';
                '*.gt3x','Raw GT3X binary'},...
                'Select a file',fullfile(obj.SingleStudy.getSetting('pathname'),obj.SingleStudy.getSetting('filename')));
            try
                if(~isempty(f))                    
                    obj.showBusy('Loading','all');
                    obj.SingleStudy.disableWidgets();
                    [pathname,basename, baseext] = fileparts(f);
                    obj.SingleStudy.setSetting('pathname', pathname);
                    obj.SingleStudy.setSetting('filename', strcat(basename,baseext));
                    
                    obj.SensorData = PASensorData(f,obj.AppSettings.SensorData);
                    
                    if(~strcmpi(obj.getViewMode(),'timeseries'))
                        obj.setViewMode('timeseries');  % Call initAccelDataView as well 
                    else
                        %initialize the PASensorData object's visual properties
                        obj.initAccelDataView(); %calls show obj.SingleStudy.showReady() Ready...                        
                    end
                    
                    % For testing/debugging
                    %                     featureFcn = 'mean';
                    %                     elapsedStartHour = 0;
                    %                     intervalDurationHours = 24;
                    %                     signalTagLine = obj.getSignalSelection(); %'accel.count.x';
                    %                     obj.SensorData.getAlignedFeatureVecs(featureFcn,signalTagLine,elapsedStartHour, intervalDurationHours);
                end
            catch me
                showME(me);
                obj.SingleStudy.showReady('all');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a text file
        %> @param obj Instance of PAAppController
        function menuFileOpenGeneralCallback(obj, ~, ~)
            importObj = PASensorDataImport(obj.AppSettings.Importing);
            if(~importObj.cancelled)
                obj.AppSettings.Importing = importObj.getSettings();
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a .csv file
        %> @param obj Instance of PAAppController
        function menuFileOpenCsvFileCallback(obj, ~, ~)
            f=uigetfullfile({'*.csv','Comma separated values (.csv)';'*.*','All files'},...
                'Select a file',fullfile(obj.AppSettings.SensorData.pathname,obj.AppSettings.SensorData.filename));
            try
                if(~isempty(f))
                    obj.showBusy('Loading','all');
                    [pathname,basename, baseext] = fileparts(f);
                    obj.AppSettings.SensorData.pathname = pathname;
                    obj.AppSettings.SensorData.filename = strcat(basename,baseext);
                    
                    obj.SensorData = PASensorData([],obj.AppSettings.SensorData);
                    fmtStruct.datetime = 1;
                    fmtStruct.datetimeType = 'elapsed'; %datetime
                    fmtStruct.datetimeFmtStr = '%f';
                    fmtStruct.x = 2;
                    fmtStruct.y = 3;
                    fmtStruct.z = 4;
                    fmtStruct.fieldOrder = {'datetime','x','y','z'};
                    fmtStruct.headerLines = 2;
                    
                    obj.SensorData.loadCustomRawCSVFile(f,fmtStruct); % two header lines %elapsed time stamp, x, y, z
                    
                    if(~strcmpi(obj.getViewMode(),'timeseries'))
                        obj.setViewMode('timeseries');
                    end
                    
                    %initialize the PASensorData object's visual properties
                    obj.initAccelDataView(); %calls show obj.SingleStudy.showReady() Ready...
                end
            catch me
                showME(me);
                obj.SingleStudy.showReady('all');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a VasTrack CSV file
        %> @param obj Instance of PAAppController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        %> @note First three lines of .csv file:
        %> - [0] Timestamp,x,y,z
        %> - [1]
        %> - [2] 0.0000,0.0052,-0.0378,-0.9986
        % --------------------------------------------------------------------
        function menuFileOpenVasTracCSVCallback(obj, varargin)
            f=uigetfullfile({'*.csv','VasTrac (.csv)'},...
                'Select a file',fullfile(obj.AppSettings.SensorData.pathname,obj.AppSettings.SensorData.filename));
            try
                if(~isempty(f))
                    obj.showBusy('Loading','all');
                    [pathname,basename, baseext] = fileparts(f);
                    obj.AppSettings.SensorData.pathname = pathname;
                    obj.AppSettings.SensorData.filename = strcat(basename,baseext);
                    
                    obj.SensorData = PASensorData([],obj.AppSettings.SensorData);
                    fmtStruct.datetime = 1;
                    fmtStruct.datetimeType = 'elapsed'; %datetime
                    fmtStruct.datetimeFmtStr = '%f';
                    fmtStruct.x = 2;
                    fmtStruct.y = 3;
                    fmtStruct.z = 4;
                    fmtStruct.fieldOrder = {'datetime','x','y','z'};
                    fmtStruct.headerLines = 2;
                    
                    obj.SensorData.loadCustomRawCSVFile(f,fmtStruct); % two header lines %elapsed time stamp, x, y, z 
                    
                    if(~strcmpi(obj.getViewMode(),'timeseries'))
                        obj.setViewMode('timeseries');
                    end
                    
                    %initialize the PASensorData object's visual properties
                    obj.initAccelDataView(); %calls show obj.SingleStudy.showReady() Ready...
                end
            catch me
                showME(me);
                obj.SingleStudy.showReady('all');
            end          
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a fitbit file.
        %> @param obj Instance of PAAppController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        % --------------------------------------------------------------------
        function menuFileOpenFitBitCallback(obj,varargin)
            f=uigetfullfile({'*.txt;*.fbit','Fitbit';
                '*.csv','Comma Separated Values'},...
                'Select a file',fullfile(obj.AppSettings.SensorData.pathname,obj.AppSettings.SensorData.filename));
            try
                if(~isempty(f))
 
                    obj.showBusy('Loading','all');
                    [pathname,basename, baseext] = fileparts(f);
                    obj.AppSettings.SensorData.pathname = pathname;
                    obj.AppSettings.SensorData.filename = strcat(basename,baseext);
                    
                    obj.SensorData = PASensorData(f,obj.AppSettings.SensorData);
                    
                    if(~strcmpi(obj.getViewMode(),'timeseries'))
                        obj.setViewMode('timeseries');
                    end
                    
                    %initialize the PASensorData object's visual properties
                    obj.initAccelDataView(); %calls show obj.SingleStudy.showReady() Ready...
                    
                    % For testing/debugging
                    %                     featureFcn = 'mean';
                    %                     elapsedStartHour = 0;
                    %                     intervalDurationHours = 24;
                    %                     signalTagLine = obj.getSignalSelection(); %'accel.count.x';
                    %                     obj.SensorData.getAlignedFeatureVecs(featureFcn,signalTagLine,elapsedStartHour, intervalDurationHours);
                end
            catch me
                showME(me);
                obj.SingleStudy.showReady('all');
            end            
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a results path for use with
        %> the results view mode.
        %> @param obj Instance of PAAppController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        % --------------------------------------------------------------------
        function menuFileOpenResultsPathCallback(obj,varargin)
            initialPath = obj.getResultsPathname();
            resultsPath = uigetfulldir(initialPath, 'Select path containing PADACO''s features directory');
            try
            if(~isempty(resultsPath))
                % Say good bye to your old stat tool if you selected a
                % directory.  This ensures that if a breakdown occurs in
                % the following steps, we do not have a previous StatTool
                % hanging around showing results and the user unaware that
                % a problem occurred (i.e. no change took place).
                % obj.StatTool = [];
                obj.setResultsPathname(resultsPath);
                
                if(~strcmpi(obj.getViewMode(),'results'))
                    obj.showBusy('Switching to results view');
                    obj.setViewMode('results');
                end
                
                obj.showBusy('Initializing results view','all');
                if(obj.initResultsView())
                    obj.showReady('all');
                else
                    f=warndlg('I could not find any feature files in the directory you selected.  Check the editor window for further information','Load error','modal');
                    waitfor(f);
                    obj.showReady();
                end
            else
                % switch back to other mode?
                % No - maybe we already were in a results view
                % Yes - maybe we were not in a results view                
            end
            
            catch me
                showME(me);
                f=warndlg('An error occurred while trying to load the feature set.  See the console log for details.');
                waitfor(f);
                obj.showReady();                
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar file->screenshot callback.
        %> @param obj Instance of PAAppController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        %> @param screenshotDescription String label for which part of the
        %> GUI is to be captured.  Valid labels include:
        %> - @c figure
        %> - @c primaryAxes
        %> - @c secondaryAxes
        % --------------------------------------------------------------------
        function menuFileScreenshotCallback(obj,~,~,screenshotDescription)
            
            switch(lower(screenshotDescription))
                case 'figure'
                    handle = obj.SingleStudy.figureH;
                case 'primaryaxes'
                    handle = obj.SingleStudy.axeshandle.primary;
                case 'secondaryaxes'
                    handle = obj.SingleStudy.axeshandle.secondary;
                otherwise
                    handle = [];
                    fprintf('%s is not a recognized description.  No screenshot will be taken',screenshotDescription);
            end
            if(ishandle(handle))
                if(strcmpi(screenshotDescription,'figure'))
                    obj.figureScreenshot();
                else
                    obj.setSetting('screenshotPathname', screencap(handle,[],obj.getSetting('screenshotPathname')));
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for quitting the program.
        %> Executes when user attempts to close padaco fig.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to menu_file_quit (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @note See startBatchProcessCallback for actual batch processing
        %> steps.
        % --------------------------------------------------------------------
        function menuFileQuitCallback(obj,~,eventdata,handles)
            obj.figureCloseCallback(gcbf,eventdata,handles);
        end
        
        %         % --------------------------------------------------------------------
        %         %> @brief Menubar callback for restarting the program.
        %         %> Executes when user clicks restart from the menubar's file->restart item.
        %         %> @param obj Instance of PAAppController
        %         %> @param hObject    handle to menu_file_quit (see GCBO)
        %         %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %         %> @note See startBatchProcessCallback for actual batch processing
        %         %> steps.
        %         % --------------------------------------------------------------------
        %         function menuFileRestartCallback(obj,hObject,~)
        %             restartDlg();  % or just go straight to a restart() call
        %         end
        
        
        % --------------------------------------------------------------------
        %> @brief Call back for export menu option under menubar 'file'
        %> option.
        % --------------------------------------------------------------------
        function menu_file_exportMenu_callback(this,hObject, ~)
            curHandles = guidata(hObject); %this.SingleStudy.getFigHandle());
            timeSeriesH = [curHandles.menu_file_export_sensorDataObj
                curHandles.menu_export_timeseries_to_disk];
            resultsH = [curHandles.menu_file_export_clusterObj;
                curHandles.menu_file_export_clusters_to_csv];
                    
            set([timeSeriesH(:);resultsH(:)],'enable','off');
            switch lower(this.getViewMode())
                case 'timeseries'
                    if(isempty(this.SensorData))
                        set(timeSeriesH,'enable','off');
                    else
                        set(timeSeriesH,'enable','on');
                    end                    
                case 'results'
                    if(isempty(this.StatTool) || ~this.StatTool.hasCluster())
                        set(resultsH,'enable','off');
                    else
                        set(resultsH,'enable','on');
                    end                       
                otherwise
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for exporting PAAppController's data object to the
        %> workspace.  This is useful for debugging and developing methods
        %> ad hoc.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to menu_tools_batch (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function menu_file_export_sensorDataObj_callback(obj,varargin)
            SensorData = obj.SensorData; %#ok<PROPLC>
            varName = 'SensorDataect';
            makeModal = true;
            titleStr = 'Data Export';
            try
                assignin('base',varName,SensorData);                 %#ok<PROPLC>
                pa_msgbox(sprintf('Data object was assigned to workspace variable %s',varName),titleStr,makeModal);
                
            catch me
                showME(me);
                pa_msgbox('An error occurred while trying to export data object to a workspace variable.  See console for details.','Warning!',makeModal);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for exporting PAAppController's data object to the
        %> workspace.  This is useful for debugging and developing methods
        %> ad hoc.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to menu_tools_batch (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function menu_file_export_clusterObj_callback(obj,varargin)
            centroidObj = obj.StatTool.getClusterObj();
            varName = 'centroidObj';
            makeModal = true;
            titleStr = 'Data Export';
            try
                assignin('base',varName,centroidObj);
                pa_msgbox(sprintf('Cluster object was assigned to workspace variable %s',varName),titleStr,makeModal);                
            catch me
                showME(me);
                pa_msgbox('An error occurred while trying to export the centroid object to a workspace variable.  See console for details.','Warning',makeModal);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for exporting PAAppController's data object
        %> to disk, in two separate .csv files.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to menu_tools_batch (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function exportClustersCb(obj,hObject, evtData, exportAs)
            obj.StatTool.exportClusters(exportAs);
        end
        
        function exportTimeSeriesCb(obj, varargin)
            
            dataObj = obj.SensorData;
            if(isempty(dataObj) || ~isa(dataObj,'PASensorData'))
                msg = 'No time series data found.  Nothing to export.';
                pa_msgbox(msg,'Warning');
            else
                obj.SensorData.exportRequestCb();
            end
            
        end
        
        function viewMode = getViewMode(obj)
            viewMode = obj.getSetting('viewMode');
        end
        
        function setViewModeCallback(obj, ~, ~, viewMode)
            obj.setViewMode(viewMode);
        end
        
        % --------------------------------------------------------------------
        %% Settings menubar callbacks
        %> @brief Sets padaco's view mode to either time series or results viewing.
        %> @param obj Instance of PAAppController
        %> @param viewMode A string with one of two values
        %> - @c timeseries
        %> - @c results
        % --------------------------------------------------------------------
        function setViewMode(obj,viewMode)
            
            if(~strcmpi(viewMode,'timeseries') && ~strcmpi(viewMode,'results'))
                warndlg(sprintf('Unrecognized view mode (%s) - switching to ''timeseries''',viewMode));
                viewMode = 'timeseries';
            end
            
            if(strcmpi(obj.getSetting('viewMode'),viewMode))
                obj.setStatus('Refreshing %s view',viewMode);
                obj.showBusy(['Refreshing ',viewMode,' view'],'all'); 
            else
                obj.showBusy(['Switching to ',viewMode,' view'],'all');        
                obj.setSetting('viewMode', viewMode);
            end
            
            switch lower(viewMode)
                case 'timeseries'
                    obj.SingleStudy.refreshView();
                    if(isempty(obj.SensorData))
                        checkToOpenFile = false; % can be a user setting.
                        if(checkToOpenFile)
                            responseButton = questdlg('A time series file is not currently loaded.  Would you like to open one now?','Find a time series file to load?');
                            if(strcmpi(responseButton,'yes'))
                                obj.menuFileOpenCallback();
                            end
                        end
                    else
                        obj.initAccelDataView();
                    end
                case 'results'
                    obj.StatTool.refreshView();
                    obj.initResultsView();
            end
            
            figure(obj.figureH);  %redraw and place it on top
            %refresh(obj.figureH); % redraw it
            %             shg();  %make sure it is on top.
            
            % Show ready when everything has been initialized to avoid
            % flickering (i.e. don't place this above the switch
            % statement).
            obj.showReady();
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for running the batch tool.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to menu_tools_batch (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param handles    structure with handles and user data (see GUIDATA)
        % --------------------------------------------------------------------
        function menuToolsBatchCallback(obj,varargin)            
            batchTool = PABatchTool(obj.AppSettings.BatchMode);
            batchTool.addlistener('BatchToolStarting',@obj.updateBatchToolSettingsCallback);
            batchTool.addlistener('SwitchToResults',@obj.setResultsViewModeCallback);
            batchTool.addlistener('BatchToolClosing',@obj.updateBatchToolSettingsCallback);
        end
        
        function menuToolsBootstrapCallback(this, varargin)
            this.StatTool.bootstrapCallback(varargin{:});
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for starting the raw .csv to .bin file
        %> converter.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to the menu item (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        % --------------------------------------------------------------------
        function menuToolsRaw2BinCallback(varargin)
            %batchTool = PABatchTool(obj.AppSettings.BatchMode);
            %batchTool.addlistener('BatchToolStarting',@obj.updateBatchToolSettingsCallback);
            %batchTool.addlistener('SwitchToResults',@obj.setResultsViewModeCallback);
        end        
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for starting the COPTR data to actigraph file conversion.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to the menu item (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        % --------------------------------------------------------------------
        function coptr2actigraphCallback(varargin)
            coptr2actigraph();
        end        
        
        % Pass through callback for setViewModeCallback method with
        % 'results' argument.
        function setResultsViewModeCallback(obj, hObject, eventData)
            obj.setViewModeCallback(hObject,eventData,'results');
        end
        
        function updateBatchToolSettingsCallback(obj,batchToolObj,eventData)
            obj.AppSettings.BatchMode = eventData.settings;
            try
                resultsPath = obj.AppSettings.BatchMode.outputDirectory.value;
                if(isdir(resultsPath))
                    obj.resultsPathname = resultsPath;
                end
            catch me
                showME(me);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Creates a temporary figure and axes, draws an overlay
        %> image on it using curData, saves the image to disk, and then
        %> removes the figure from view.
        %> @param obj Instance of PAAppController
        %> @param curData Instance of PASensorData
        %> @param featureFcn Extractor method for obtaining features from
        %> curData.
        %> @param img_filename Filename to save image to.
        %> @note The image format is determined from the extension of
        %> img_filename (e.g. if img_filename = 'picture.jpg', then a jpeg
        %> is used.
        % --------------------------------------------------------------------
        function save2image(obj, curData,featureFcn, img_filename)
            obj.overlayScreenshot(curData,featureFcn,img_filename);
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the display type instance variable.
        %> @param obj Instance of PASingleStudyController.
        %> @retval structName Name of the field that matches the description of the current display type used.
        %> - @c timeSeries
        %> - @c bins
        %> - @c features
        %> @note See PASensorData.getStructTypes()
        % --------------------------------------------------------------------
        function structName = getDisplayType(obj)
            structName = obj.SingleStudy.getDisplayType();
        end
        
        
    end
    
    methods(Access=private)
        
        % --------------------------------------------------------------------
        %> @brief Initializes the version number based on internal file
        %> specified by variable @c versionMatFilename.
        %> @param obj Instance of PAAppController
        % --------------------------------------------------------------------
        function setVersionNum(obj)
            versionStruct = obj.getVersionInfo();
            obj.versionNum = versionStruct.num;
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the current version number as a string.
        %> @param obj Instance of PAAppController
        %> @retval versionNum String value of Padaco's current version.
        % --------------------------------------------------------------------
        function versionNum = getVersionNum(obj)
            versionNum = obj.versionNum;
        end
        
        function resizeFigCb(obj, figH, szEvtData)
            %obj.logStatus('Resizing');     
            figPos = figH.Position;
            
            figPos(3) = max(min(figPos(3),obj.resizeValues.figure.max.w),obj.resizeValues.figure.min.w);
            figPos(4) = max(min(figPos(4),obj.resizeValues.figure.max.h),obj.resizeValues.figure.min.h);
            
            %dW = (figPos(3) - obj.resizeValues.figure.init.w)/obj.resizeValues.figure.init.w;
            %dH = (figPos(4) - obj.resizeValues.figure.init.h)/obj.resizeValues.figure.init.h;
            
            dW = figPos(3)/obj.resizeValues.figure.init.w;
            dH = figPos(4)/obj.resizeValues.figure.init.h;
            
            figH.Position = figPos;
            
            hoi = {
                'text_status';
                'panel_timeseries';'panel_results';'axes_primary';'text_clusterResultsOverlay';
                'panel_displayButtonGroup';'panel_epochControls';
                'btngrp_clusters';
                'panel_study';'axes_secondary';'panel_clusterInfo';
                };
            
            statusPos = get(obj.handles.text_status,'position');
            initPosX = obj.resizeValues.text_status.init.pos(1);
            statusPos(1) = initPosX*dW;
            statusPos(2) = figPos(4)-statusPos(4);
            set(obj.handles.text_status,'position',statusPos);
            
            panelPos = get(obj.handles.panel_timeseries,'position');
            initPosX = obj.resizeValues.panel_timeseries.init.pos(1);
            panelPos(1) = initPosX*dW;            
            panelPos(2) = statusPos(2)-panelPos(4);
            set(obj.handles.panel_timeseries,'position',panelPos);
            
            resultsPos = get(obj.handles.panel_results,'position');
            initPosX = obj.resizeValues.panel_results.init.pos(1);
            resultsPos(1) = initPosX*dW;            
            resultsPos(2) = statusPos(2)-resultsPos(4);
            set(obj.handles.panel_results,'position',resultsPos);
            
            axes1Pos = get(obj.handles.axes_primary,'position');
            initPosX = obj.resizeValues.axes_primary.init.pos(1);
            initPosW = obj.resizeValues.axes_primary.init.pos(3);
            axes1Pos(1) = initPosX*dW;            
            axes1Pos(2) = statusPos(2)-axes1Pos(4);
            axes1Pos(3) = initPosW*dW;
            set(obj.handles.axes_primary,'position',axes1Pos);
            
            axes2Pos = get(obj.handles.axes_secondary,'position');            
            axes2Pos(1) = axes1Pos(1);
            axes2Pos(3) = axes1Pos(3);
            set(obj.handles.axes_secondary,'position',axes2Pos);
            
            axes2CeilingY = sum(axes2Pos([2,4]));
            btngrpPos = obj.resizeValues.btngrp_clusters.init.pos;
            btngrpPos(1) = axes2Pos(1);
            btngrpPos(2) = axes2CeilingY+1;      
            set(obj.handles.btngrp_clusters, 'position', btngrpPos);
            
            betweenAxes = 0.5*(axes1Pos(2)+axes2CeilingY);
            h = obj.handles.panel_displayButtonGroup;
            controlPos = get(h,'position');
            initPos = obj.resizeValues.panel_displayButtonGroup.init.pos;
            controlPos(1) = axes2Pos(1);
            controlPos(2) = betweenAxes-0.5*controlPos(4);
            controlPos(3) = initPos(3)*dW;
            set(h,'position',controlPos);
            
            h = obj.handles.panel_epochControls;
            control2Pos = get(h,'position');
            initPos = obj.resizeValues.panel_epochControls.init.pos;
            control2Pos(1) = initPos(1)*dW;
            control2Pos(2) = betweenAxes-0.5*control2Pos(4);
            control2Pos(3) = initPos(3)*dW;
            set(h,'position',control2Pos);
            
            drawnow();
        end
        
        function initResize(obj)
            set(obj.figureH,'Resize','on',...
                'SizeChangedFcn',@obj.resizeFigCb);
                     
            hoi = {'figure_padaco';
                'text_status';
                'panel_timeseries';'panel_results';'axes_primary';'text_clusterResultsOverlay';
                'panel_displayButtonGroup';'panel_epochControls';
                'btngrp_clusters';
                'panel_study';'axes_secondary';'panel_clusterInfo';
                };
            
            initPos = struct;
            for n = 1:numel(hoi)
                tag = hoi{n};
                h = obj.handles.(tag);
                % set(h,'units','normalized');
                set(h,'units','pixels');
                initPos.(tag) = struct('handle',h,'position',h.Position); 
                obj.resizeValues.(tag).init.pos = initPos.(tag).position;                
            end
            
            figPos = obj.figureH.Position;
            minScale.w = 0.8;
            minScale.h = 0.9;
            
            maxScale.w = 1.1;
            maxScale.h = 1.2;
            
            obj.resizeValues.figure.init.w = figPos(3);
            obj.resizeValues.figure.init.h = figPos(4);
            
            obj.resizeValues.figure.min.w = figPos(3)*minScale.w;
            obj.resizeValues.figure.min.h = figPos(4)*minScale.h;
            
            obj.resizeValues.figure.max.w = figPos(3)*maxScale.w;
            obj.resizeValues.figure.max.h = figPos(4)*maxScale.h;
        end
         
        % --------------------------------------------------------------------
        %> @brief Initializes the display for accelerometer data viewing
        %> using instantiated instance
        %> variables SingleStudy (PASingleStudyController) and SensorData (PASensorData)
        %> @param obj Instance of PAAppController
        % --------------------------------------------------------------------
        function initAccelDataView(obj)
            % Shows line labels after initWithAccelData
            obj.SingleStudy.initWithAccelData(obj.SensorData);
        end
        
        function resultsPath = getResultsPathname(this)
           resultsPath = this.StatTool.getResultsDirectory(); 
        end
        
        function didSet = setResultsPathname(this, resultsPath)
           didSet = this.StatTool.setResultsDirectory(resultsPath); 
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Initializes widgets for results view mode.  Widgets are
        %> disabled if the resultsPathname does not exist or cannot be
        %> found.
        %> @param this Instance of PAAppController
        %> @retval success A boolean value (true on successful initialization of the resultsPathname into padaco's view
        % --------------------------------------------------------------------
        function success = initResultsView(this)
            success = false;
            StatToolResultsPath = this.StatTool.getResultsDirectory();
          
            if(isdir(this.getResultsPathname()))
                refreshPath = false;
                if(~strcmpi(StatToolResultsPath,this.resultsPathname))
                    msgStr = sprintf('There has been a change to the results path.\nWould you like to load features from the updated path?\n%s',this.getResultsPathname());
                    titleStr = 'Refresh results path?';
                    buttonName = questdlg(msgStr,titleStr,'Yes','No','Yes');
                    switch(buttonName)
                        case 'Yes'
                            refreshPath = true;
                        case 'No'
                            refreshPath = false;
                            %make it so we do not ask the quesiton
                            %again by matching the pathname to the one
                            %the user wants to use.
                            % resultsPathname = StatToolResultsPath;
                        otherwise
                            refreshPath = false;
                    end
                end
                
                if(refreshPath)
                    this.StatTool.setResultsDirectory(resultsPathname);
                else
                    % Make sure the resultsPath is up to date (e.g. when
                    % switching back from a batch mode.
                    this.StatTool.init();  %calls a plot refresh
                    
                end
                success = this.StatTool.getCanPlot();
            end
            
            if(~success)
                this.StatTool.disable();
                this.notify('StatToolCreationFailure');
                checkToOpenResultsPath = false; % can be a user setting.
                if(checkToOpenResultsPath)
                    responseButton = questdlg('Results output pathname is either not set or was not found.  Would you like to choose one now?','Find results output path?');
                    if(strcmpi(responseButton,'yes'))
                        this.menuFileOpenResultsPathCallback();
                    end
                end

            else
                this.SingleStudy.showReady();
                this.notify('StatToolCreationSuccess');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Creates a temporary overlay from paDataObject's values
        %> and takes a screenshot of it which is saved as img_filename.
        %> @param obj Instance of PAAppController
        %> @param paDataObject Instance of PASensorData
        %> @param featureFcn Extractor method for obtaining features from
        %> curData.
        %> @param img_filename Filename (full) to save the screenshot too.
        %> @note The image format is determined from img_filename's
        %> extension.
        % --------------------------------------------------------------------
        function overlayScreenshot(obj, paDataObject, featureFcn, img_filename)
            [~,~, ext] = fileparts(img_filename);
            ext = strrep(ext,'.','');  %remove leading '.' when it exists (i.e. not an empty string).
            if(strcmpi(ext,'jpg'))
                imgFmt = '-djpeg';
            else
                imgFmt = strcat('-d',lower(ext));
            end
            
            fig_h = obj.SingleStudy.figureH;
            axes_copy = copyobj(obj.SingleStudy.axeshandle.secondary,fig_h);
            
            f = figure('visible','off','paperpositionmode','auto','inverthardcopy','on',...
                'units',get(fig_h,'units'),'position',get(fig_h,'position'),...
                'toolbar','none','menubar','none');
            set(f,'units','normalized','renderer','zbuffer');
            set(axes_copy,'parent',f);
            
            obj.drawOverlay(paDataObject,featureFcn,axes_copy);
            obj.cropFigure2Axes(f,axes_copy);
            
            set(f,'visible','on');
            set(f,'clipping','off');
            print(f,imgFmt,'-r0',img_filename);
            delete(f);
        end
        
        %> Draw all parts of the overlay to axesH using paDataObject
        %> This is used for batch processing, when taking screenshots.
        function [featureHandles] = drawOverlay(obj,paDataObject,featureFcn,axesH)
            
            numFrames = paDataObject.getFrameCount();
            maxLumens = 250;
            
            % Modified - by adding paDataObject as secondary value.
            [meanLumens,startStopDatenums] = obj.getMeanLumenPatches(numFrames,paDataObject);
            
            % Modified - by adding axesH as second argument
            addOverlayToAxes(axesH,meanLumens,startStopDatenums,1/7,5/7,maxLumens);
            
            maxDaylight = 1;
            % Modified get daylight somehow - perhaps to include SensorData as second argument.
            [daylight,startStopDatenums] = obj.getDaylight(numFrames,paDataObject);
            
            % Modified - by adding axesH as last argument
            addOverlayToAxes(axesH,daylight,startStopDatenums,1/7-0.005,6/7,maxDaylight);
            
            % updateSecondaryFeaturesDisplay
            signalTagLines = strcat('accel.',paDataObject.accelType,'.',{'x','y','z','vecMag'})';
            numViews = (numel(signalTagLines)+1)+2;
            height = 1/numViews;
            heightOffset = 0;
            featureHandles = [];
            for s=1:numel(signalTagLines)
                signalName = signalTagLines{s};
                % Modified to pass in the PASensorDataObj as last parameter
                [featureVec, startStopDatenums] = obj.getFeatureVec(featureFcn,signalName,numFrames,paDataObject);
                if(s<numel(signalTagLines))
                    vecHandles = addFeaturesVecToAxes(axesH, featureVec,startStopDatenums,height,heightOffset);
                else
                    % This requires twice the height because it will have a
                    % feature line and heat map
                    vecHandles = obj.SingleStudy.addFeaturesVecAndOverlayToAxes(featureVec,startStopDatenums,height*2,heightOffset,axesH);
                end
                heightOffset = heightOffset+height;
                featureHandles = [featureHandles(:);vecHandles(:)];
            end
            
            % Added this to keep consistency with updateSecondaryFeaturesDisplay method
            ytickLabel = {'X','Y','Z','|X,Y,Z|','|X,Y,Z|'};
            
            if(strcmpi(obj.getAccelType(),'raw'))
                ytickLabel = [ytickLabel,'Activity','Daylight'];
            else
                ytickLabel = [ytickLabel,'Activity','Lumens','Daylight'];
            end
            
            numViews = numel(ytickLabel);
            startStopDatenum = [startStopDatenums(1),startStopDatenums(end)];
            axesProps.yticklabel = ytickLabel;
            axesProps.ytick = 1/numViews/2:1/numViews:1;
            axesProps.TickDir = 'in';
            axesProps.TickDirMode = 'manual';
            axesProps.TickLength = [0.001 0];
            
            axesProps.xlim = startStopDatenum;
            [~,~,d,h,mi,s] = datevec(diff(startStopDatenum));
            durationDays = d+h/24+mi/60/24+s/3600/24;
            if(durationDays<0.25)
                dateScale = 1/48; %show every 30 minutes
            elseif(durationDays<0.5)
                dateScale = 1/24; %show every hour
            elseif(durationDays<0.75)
                dateScale = 1/12; %show every couple hours
            elseif(durationDays<=1)
                dateScale = 1/6; %show every four hours
            elseif(durationDays<=2)
                dateScale = 1/3; %show every 8 hours
            elseif(durationDays<=10)
                dateScale = 1/2; %show every 12 hours
            else
                dateScale = 1; %show every 24 hours.
                
            end
            if(dateScale >= 1/3)
                timeDeltaSec = datenum(0,0,1)/24/3600;
                studyDatenums = startStopDatenum(1):timeDeltaSec:startStopDatenum(2);
                [~,~,~,hours,minutes,sec] = datevec(studyDatenums);
                newDayIndices = mod([hours(:),minutes(:),sec(:)]*[1;1/60;1/3600],24)==0;
                %                 quarterDayIndices =  mod([hours(:),min(:),sec(:)]*[1;1/60;1/3600],24/4)==0;
                
                xTick = studyDatenums(newDayIndices);
                axesProps.XGrid = 'on';
                axesProps.XMinorGrid = 'off';
                axesProps.XMinorTick = 'on';
                
            else
                timeDelta = datenum(0,0,1)*dateScale;
                xTick = [startStopDatenum(1):timeDelta:startStopDatenum(2), startStopDatenum(2)];
                axesProps.XMinorTick = 'off';
                axesProps.XGrid = 'off';
            end
            
            axesProps.gridlinestyle = '--';
            axesProps.YGrid = 'off';
            axesProps.YMinorGrid = 'off';
            axesProps.ylim = [0 1];
            axesProps.xlim = startStopDatenum;
            
            axesProps.XTick = xTick;
            axesProps.XTickLabel = datestr(xTick,'ddd HH:MM');
            
            fontReduction = min([4, floor(durationDays/4)]);
            axesProps.fontSize = 14-fontReduction;
            
            set(axesH,axesProps);            
        end
        
        % --------------------------------------------------------------------
        %> @brief Takes a screenshot of the padaco figure.
        %> @param obj Instance of PAAppController
        % --------------------------------------------------------------------
        function figureScreenshot(obj)
            
            filterspec = {'png','PNG';'jpeg','JPEG'};
            save_format = {'-dpng','-djpeg'};
            if(isa(obj.SensorData,'PASensorData'))
                img_filename = [obj.SensorData.filename,'_window ',num2str(obj.getCurWindow),'.png'];
            else
                img_filename = ['padaco_window ',num2str(obj.getCurWindow),'.png'];
            end
            [img_filename, img_pathname, filterindex] = uiputfile(filterspec,'Screenshot name',fullfile(obj.getSetting('screenshotPathname'),img_filename));
            if isequal(img_filename,0) || isequal(img_pathname,0)
                disp('User pressed cancel');
            else
                try
                    if(filterindex>2)
                        filterindex = 1; %default to .png
                    end
                    fig_h = obj.SingleStudy.figureH;
                    axes_copy = copyobj(obj.SingleStudy.axeshandle.secondary,fig_h);
                    
                    f = figure('visible','off','paperpositionmode','auto','inverthardcopy','on',...
                        'units',get(fig_h,'units'),'position',get(fig_h,'position'),...
                        'toolbar','none','menubar','none');
                    set(f,'units','normalized');
                    set(axes_copy,'parent',f);
                    
                    cropFigure2Axes(f,axes_copy);
                    
                    set(f,'visible','on');
                    set(f,'clipping','off');
                    
                    print(f,save_format{filterindex},'-r0',fullfile(img_pathname,img_filename));
                    
                    %save the screenshot
                    %         print(f,['-d',filterspec{filterindex,1}],'-r75',fullfile(img_pathname,img_filename));
                    %         print(f,fullfile(img_pathname,img_filename),['-d',filterspec{filterindex,1}]);
                    %         print(f,['-d',filterspec{filterindex,1}],fullfile(img_pathname,img_filename));
                    %         set(handles.axes1,'position',apos,'dataaspectratiomode','manual' ,'dataaspectratio',dataaspectratio,'parent',handles.sev_main_fig)
                    delete(f);
                    obj.setSetting('screenshotPathname', img_pathname);
                catch ME
                    showME(ME);
                    %         set(handles.axes1,'parent',handles.sev_main_fig);
                end
            end
        end
        

        %> @brief Check if I the viewing mode passed in is current, and if it is
        %> displayable (i.e. has an accel or stat tool object)
        %> @param obj Instance of PAAppController
        %> @param viewingMode View mode to check.  Valid strings include:
        %> - @c timeseries
        %> - @c results
        %> @retval viewable True/False
        function viewable = isViewable(obj, viewingMode)
            if(strcmpi(obj.getViewMode(),viewingMode))
                if(strcmpi(viewingMode,'timeseries') && ~isempty(obj.SensorData))
                    viewable = true;
                elseif(strcmpi(viewingMode,'results') && ~isempty(obj.StatTool))
                    viewable = true;
                else
                    viewable = false;
                end
            else
                viewable = false;
            end
        end        
    end
    
    methods (Access=protected)
        
        function didInit = initFigure(obj)
            didInit = false;
            hFigure = obj.figureH;
            if(ishandle(hFigure))
                % Place this sooner so that we can go ahead and crush the
                % figure if something breaks down and we get get stuck
                % before reaching the closerequestfcn we want to use later
                % on (Which requires certain initializations to complete).
                set(hFigure,'closeRequestFcn','delete(gcbo)');
                set(obj.figureH,'renderer','zbuffer'); %  set(obj.figureH,'renderer','OpenGL');


                figColor = get(hFigure,'color');
                defaultUnits = 'pixels';
                
                
                set([obj.handles.text_status;
                    ],'backgroundcolor',figColor,'units',defaultUnits);
                
                set([hFigure
                    obj.handles.panel_timeseries
                    obj.handles.panel_results
                    obj.handles.panel_epochControls
                    obj.handles.panel_displayButtonGroup
                    obj.handles.btngrp_clusters],'units','pixels');
                
                hAnchor = obj.handles.(obj.NWAnchor.tag);
                set(hAnchor,'units','normalized');
                posAnchorPct = get(hAnchor,'position');
                % screenSize = get(0,'screensize');
                figPos = get(hFigure,'position');
                
                diffY = posAnchorPct(2)-obj.NWAnchor.y;
                diffYpixels = figPos(4)*diffY;
                % Adjust for changing screen sizes first ...
                
                anchoredTags = {'text_status'
                    'panel_timeseries'
                    'panel_study'
                    'axes_primary'
                    'axes_secondary'
                    'text_clusterResultsOverlay'
                    'panel_displayButtonGroup'
                    'panel_epochControls'
                    'btngrp_clusters'
                    'panel_results'
                    };
                for t= 1:numel(anchoredTags)
                    tag = anchoredTags{t};
                    if(isfield(obj.handles,tag))
                        h = obj.handles.(tag);
                        set(h,'units','pixels');
                        pos = get(h,'position');  % get adjusted position
                        pos(2)=pos(2)-diffYpixels; %undo
                        set(h,'position',pos);   % reset 
                    end
                end
                
                timeSeriesPanelPos = get(obj.handles.panel_timeseries,'position');
                resultsPanelPos = get(obj.handles.panel_results,'position');

                % Line our panels up to same top left position - do this here
                % so I can edit them easy in GUIDE and avoid to continually
                % updating the position property each time i need to drag the
                % panel(s) around to make edits.  Position is given as
                % 'x','y','w','h' with 'x' starting from left (and increasing right)
                % and 'y' starting from bottom (and increasing up)
                
                if(resultsPanelPos(1)>sum(timeSeriesPanelPos([1,3])))
                    figPos(3) = resultsPanelPos(1);  % The start of the results panel (x-value) indicates the point that the figure should be clipped
                    set(hFigure,'position',figPos);
                    newResultsPanelY = sum(timeSeriesPanelPos([2,4]))-resultsPanelPos(4);
                    set(obj.handles.panel_results,'position',[timeSeriesPanelPos(1),newResultsPanelY,resultsPanelPos(3:4)]);
                   
                    metaDataHandles = [obj.handles.panel_study;get(obj.handles.panel_study,'children')];
                    set(metaDataHandles,'backgroundcolor',[0.94,0.94,0.94],'visible','off');
                    
                    whiteHandles = [obj.handles.panel_features_prefilter
                        obj.handles.panel_features_aggregate
                        obj.handles.panel_features_frame
                        obj.handles.panel_features_signal
                        obj.handles.edit_minClusters
                        obj.handles.edit_clusterConvergenceThreshold];
                    sethandles(whiteHandles,'backgroundcolor',[1 1 1]);
                    
                    innerPanelHandles = [
                        obj.handles.panel_clusteringSettings
                        obj.handles.panel_timeFrame
                        obj.handles.panel_source
                        obj.handles.panel_shapeAdjustments
                        obj.handles.panel_clusterSettings
                        obj.handles.panel_shapeSettings
                        obj.handles.btngrp_clusters
                        obj.handles.panel_chunking];
                    sethandles(innerPanelHandles,'backgroundcolor',[0.9 0.9 0.9]);
                    
                    % Make the inner edit boxes appear white
                    set([obj.handles.edit_minClusters
                        obj.handles.edit_clusterConvergenceThreshold],'backgroundcolor',[1 1 1]);
                    
                    set(obj.handles.text_threshold,'tooltipstring','Smaller thresholds result in more stringent conversion requirements and often produce more clusters than when using higher threshold values.');
                    % Flush our drawing queue
                    drawnow();
                end
                
                %     renderOffscreen(hObject);
                movegui(hFigure,'northwest');
                
                
                didInit = true;
            end
        end
        
        function initToolbar(this)  
            toolbarHandles.cluster = {
                'toggle_backgroundColor'
                'toggle_holdPlots'
                'toggle_yLimit'
                'toggle_membership'
                'toggle_summary'
                'toggle_analysisFigure'
                'push_right'
                'push_left'
                };
            
            fnames = fieldnames(toolbarHandles);
            this.toolbarH = mkstruct(fnames);
            for f=1:numel(fnames)
                fname = fnames{f};
                %                 this.toolbarH.(fname) = mkstruct(toolbarHandles.(fname));
                for h=1:numel(toolbarHandles.(fname))
                    hname = toolbarHandles.(fname){h};
                    tH = tmpHandles.(hname);
                    this.toolbarH.(fname).(hname) = tH;
                    
                    if(isa(tH,'matlab.ui.container.toolbar.ToggleTool'))
                        cdata.Off = get(tH,'cdata');
                        cdata.On = max(cdata.Off-0.2,0);
                        cdata.On(isnan(cdata.Off)) = nan;
                        set(tH,'userdata',cdata,'oncallback',@this.toggleOnOffCb,'offcallback',@this.toggleOnOffCb,'state','Off');
                    end
                end
            end
            
            %             cdata.Off = get(this.toolbarH.cluster.toggle_membership,'cdata');
            %             cdata.On = cdata.Off;
            %             cdata.On(cdata.Off==1) = 0.7;
            %             set(this.toolbarH.cluster.toggle_membership,'userdata',cdata,'oncallback',@this.toggleOnOffCb,'offcallback',@this.toggleOnOffCb);
            %             sethandles(this.handles.toolbar_results,'handlevisibility','callback');
            %             set(this.toolbarH.cluster.toggle_backgroundColor,'handlevisibility','off');
            %             set(this.handles.toolbar_results,'handlevisibility','off');
            
            set(this.toolbarH.cluster.toggle_membership,'clickedcallback',@this.checkShowClusterMembershipCallback);
            set(this.toolbarH.cluster.toggle_summary,'clickedcallback',@this.plotCb);
            
            set(this.toolbarH.cluster.toggle_holdPlots,'clickedcallback',@this.checkHoldPlotsCallback);
            set(this.toolbarH.cluster.toggle_yLimit,'clickedcallback',@this.togglePrimaryAxesYCb);
            set(this.toolbarH.cluster.toggle_analysisFigure,'clickedcallback',@this.toggleAnalysisFigureCb);
            set(this.toolbarH.cluster.toggle_backgroundColor,'ClickedCallback',@this.plotCb); %'OffCallback',@this.toggleBgColorCb,'OnCallback',@this.toggleBgColorCb);
            
            set(this.toolbarH.cluster.push_right,'clickedcallback',@this.showNextClusterCallback);
            set(this.toolbarH.cluster.push_left,'clickedcallback',@this.showPreviousClusterCallback);
            
            
            this.logStatus('Need to add toolbar callbacks');
            % Refactoring for toolbars
            offOnState = {'off','on'}; % 0 -> 'off', 1 -> 'on'  and then +1 to get matlab 1-based so that 1-> 'off' and 2-> 'on'
            
            %             set(this.toolbarH.cluster.toggle_holdPlots,'state',offOnState{this.holdPlots+1});
            %             set(this.toolbarH.cluster.toggle_yLimit,'state',offOnState{strcmpi(this.getSetting('primaryAxis_yLimMode'),'manual')+1});
            %             set(this.toolbarH.cluster.toggle_analysisFigure,'state',offOnState{this.getSetting('showAnalysisFigure')+1});
            %             set(this.toolbarH.cluster.toggle_backgroundColor,'state',offOnState{this.getSetting('showTimeOfDayAsBackgroundColor')+1}); %'OffCallback',@this.toggleBgColorCb,'OnCallback',@this.toggleBgColorCb);
            %
        end        
        
        function showBusy(obj, varargin)
            obj.SingleStudy.showBusy(varargin{:});
        end            
    end
    methods (Static)
        % --------------------------------------------------------------------
        %> @brief Returns version info in a struct.
        %> @param Optional string tag identifying a single parameter to be
        %> returned.  The tag request must match a structure field name of
        %> versionInfo.  See below.  
        %> @retval versionInfo Struct values include
        %> - @c num The version number (string)
        % --------------------------------------------------------------------
        function versionInfo = getVersionInfo(tagRequest)
            if(exist(PAAppController.versionMatFilename,'file'))
                try
                    versionInfo = load(PAAppController.versionMatFilename,'-mat');
                    % num = '2.001';
                    % save(PAAppController.versionMatFilename,'num','-mat');
                catch me
                    showME(me);
                    versionInfo.num = '1.85x';
                end
            else
                versionInfo.num = '1.85a';
            end
            
            if(nargin > 0 && isfield(versionInfo,tagRequest))
                versionInfo = versionInfo.(tagRequest);
            end
        end
        
        function cropFigure2Axes(fig_h,axes_h)
            %places axes_h in middle of figure with handle fig_h
            %useful for prepping screen captures
            
            % Hyatt Moore IV
            % 1/16/2013
            
            fig_units_in = get(fig_h,'units');
            axes_units_in = get(axes_h,'units');
            
            set(fig_h,'units','pixels');
            set(axes_h,'units','pixels');
            
            
            a_pos = get(axes_h,'position'); %x, y, width, height
            f_pos = get(fig_h,'position');
            
            a_width = a_pos(3);
            a_height = a_pos(4);
            
            set(axes_h,'position',[a_width*0.06,a_height*0.1,a_width,a_height]);
            set(fig_h,'position',[f_pos(1),f_pos(2),a_width*1.1,a_height*1.2]);
            
            %reset units to original
            set(fig_h,'units',fig_units_in);
            set(axes_h,'units',axes_units_in);
            
        end
        
        % ======================================================================
        %> @brief Returns a structure of PAAppControllers default, saveable parameters as a struct.
        %> @retval pStruct A structure of saveable parameters
        function pStruct = getDefaults()
            
            %> String identifying Padaco's current view mode.  Values include
            %> - @c timeseries
            %> - @c results
            
            
            pStruct.viewMode = PAEnumParam('default','timeseries','categories',{'timeseries','results'},'description','Current View','help','String identifying Padaco''s current view mode.');

            %> Foldername of most recent screenshot.        
            pStruct.screenshotPathname = PAPathParam('default',getSavePath(),'description','Screenshot save path','help','Foldername of most recent screenshot');
            
            
            % pStruct.filter_inf_file = PAFilenameParam('default','filter.inf','description','Filter configuration file');
            % pStruct.database_inf_file = PAFilenameParam('default','database.inf','description','Database configuration file');
            
            % batchSettings = PABatchTool.getDefaults();
            % pStruct.resultsPathname = batchSettings.outputDirectory;
        end
    end
    
end


% 
% % --------------------------------------------------------------------
% %> @brief Clears axes handles of any children and sets default properties.
% %> Called when first creating a view.  See also initAxesHandles.
% %> @param obj Instance of PASingleStudyController
% %> @param viewMode A string with one of two values
% %> - @c timeseries
% %> - @c results
% % --------------------------------------------------------------------
% function initAxesHandlesViewMode(obj,viewMode)
% 
% obj.clearAxesHandles();
% 
% axesProps.primary.xtickmode='manual';
% axesProps.primary.xticklabelmode='manual';
% axesProps.primary.xlimmode='manual';
% axesProps.primary.xtick=[];
% axesProps.primary.xgrid='on';
% axesProps.primary.visible = 'on';
% 
% %             axesProps.primary.nextplot='replacechildren';
% axesProps.primary.box= 'on';
% axesProps.primary.plotboxaspectratiomode='auto';
% axesProps.primary.fontSize = 14;
% % axesProps.primary.units = 'normalized'; %normalized allows it to resize automatically
% if verLessThan('matlab','7.14')
%     axesProps.primary.drawmode = 'normal'; %fast does not allow alpha blending...
% else
%     axesProps.primary.sortmethod = 'childorder'; %fast does not allow alpha blending...
% end
% 
% axesProps.primary.ygrid='off';
% axesProps.primary.ytick = [];
% axesProps.primary.yticklabel = [];
% axesProps.primary.uicontextmenu = [];
% 
% if(strcmpi(viewMode,'timeseries'))
%     % Want these for both the primary (upper) and secondary (lower) axes
%     axesProps.primary.xAxisLocation = 'top';
%     axesProps.primary.ylimmode = 'manual';
%     axesProps.primary.ytickmode='manual';
%     axesProps.primary.yticklabelmode = 'manual';
%     
%     axesProps.secondary = axesProps.primary;
%     
%     % Distinguish primary and secondary properties here:
%     axesProps.primary.xminortick='on';
%     axesProps.primary.uicontextmenu = obj.contextmenuhandle.primaryAxes;
%     
%     axesProps.secondary.xminortick = 'off';
%     axesProps.secondary.uicontextmenu = obj.contextmenuhandle.secondaryAxes;
%     
% elseif(strcmpi(viewMode,'results'))
%     axesProps.primary.ylimmode = 'auto';
%     %                 axesProps.primary.ytickmode='auto';
%     %                 axesProps.primary.yticklabelmode = 'auto';
%     axesProps.primary.xAxisLocation = 'bottom';
%     axesProps.primary.xminortick='off';
%     
%     axesProps.secondary = axesProps.primary;
%     % axesProps.secondary.visible = 'off';
% end
% 
% axesProps.secondary.xgrid = 'off';
% axesProps.secondary.xminortick = 'off';
% axesProps.secondary.xAxisLocation = 'bottom';
% 
% %initialize axes
% obj.initAxesHandles(axesProps);
% end
