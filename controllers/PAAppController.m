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
    properties(Access=private)
        resizeValues; % for handling resize functions
        versionNum;
        
        %> @brief Vector for keeping track of the feature handles that are
        %> displayed on the secondary axes field.
        featureHandles;
        
        
        %> String identifying Padaco's current view mode.  Values include
        %> - @c timeseries
        %> - @c results
        viewMode;   
        
        iconFilename;
        
    end
    properties(SetAccess=protected)
        %> acceleration activity object - instance of PASensorData
        SensorData;
        
        %> Instance of PAStatTool - results controller when in results view
        %> mode.
        StatTool;
        
        %> Instance of PAOutcomesTable - for importing outcomes data to be
        %> used with cluster analysis.
        outcomesTable;
        
        %> Instance of PAAppSettings - keeps track of application wide settings.
        AppSettings;
        %> Instance of PASingleStudyController - Padaco's view component.
        SingleStudy;
       
        
        
        %> Linehandle in Padaco that is currently selected by the user.
        current_linehandle;
        
        %> cell of string choices for the marking state (off, 'marking','general')
        state_choices_cell;
        %> string of the current selected choice
        %> handle to the figure an instance of this class is associated with
        %> struct of handles for the context menus
        contextmenuhandle;
        
        %> struct of different time resolutions, field names correspond to the units of time represented in the field
        window_resolution;
        num_windows;
        display_samples; %vector of the samples to be displayed
        shift_display_samples_delta; %number of samples to adjust display by for moving forward or back
        startDateTime;
        
        %> Struct of batch settings with fields as described by
        %PABatchTool's getDefault
        % batch;
        
        %> Foldername of most recent screenshot.
        screenshotPathname;
        %> Foldername of most recent results output pathname used.
        resultsPathname;
        
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
            
            %check to see if a settings file exists
            if(nargin<3)
                parameters_filename = '_padaco.parameters.txt';
            end
            
            obj.iconFilename = fullfile(rootPathname,'resources','icons','logo','icon_32.png');
            obj.setVersionNum();            
            obj.StatTool = [];
            
            obj.addlistener('StatToolCreationSuccess',@obj.StatToolCreationCallback);
            obj.addlistener('StatToolCreationFailure',@obj.StatToolCreationCallback);
            
            %create/intilize the settings object
            obj.AppSettings = PAAppSettings(rootPathname,parameters_filename);
            obj.outcomesTable = PAOutcomesTable(obj.AppSettings.outcomesTable);            
            obj.outcomesTable.addlistener('LoadSuccess',@obj.outcomesLoadCb);
            obj.outcomesTable.addlistener('LoadFail',@obj.outcomesLoadCb);
            obj.screenshotPathname = obj.AppSettings.CONTROLLER.screenshotPathname;
            obj.resultsPathname = obj.AppSettings.CONTROLLER.resultsPathname;
            
            if(obj.setFigureHandle(hFigure))
                if(obj.initFigure())
                    obj.setStatusHandle(obj.handles.text_status);                    
                    obj.featureHandles = [];
                    
                    % Create a SingleStudy class
                    singleStudySettings = obj.AppSettings.CONTROLLER;
                    obj.SingleStudy = PASingleStudyController(obj.figureH, singleStudySettings);
                    
                    set(obj.figureH,'visible','on');
                    
                    obj.SingleStudy.showBusy([],'all');                    
                    set(obj.figureH,'CloseRequestFcn',{@obj.figureCloseCallback,guidata(obj.figureH)});
                    
                    % set(obj.figureH,'scrollable','on'); - not supported
                    % for guide figures (figure)
                    %configure the menu bar callbacks.
                    obj.initMenubarCallbacks();
                    
                    % attempt to load the last set of results
                    lastViewMode = obj.AppSettings.CONTROLLER.viewMode;
                    try
                        obj.setViewMode(lastViewMode);
                        obj.initResize();
                    catch me
                        showME(me);
                    end
                end
            end
        end
        
        %% Shutdown functions
        %> Destructor
        function close(obj)
            obj.saveParameters(); %requires AppSettings variable
            obj.AppSettings = [];
            if(~isempty(obj.StatTool))
                obj.StatTool.delete();
            end
        end
        
        function saveParameters(obj)
            obj.refreshSettings(); % updates the parameters based on current state of the gui.
            obj.AppSettings.saveParametersToFile();
            fprintf(1,'Settings saved to disk.\n');
        end

        %> @brief Sync the controller's settings with the SETTINGS object
        %> member variable.
        %> @param Instance of PAAppController;
        %> @retval Boolean Did refresh = true, false otherwise (e.g. an
        %> error occurred)
        function didRefresh = refreshSettings(obj)
            try
                % Overwrite the current AppSettings.DATA if we have an SensorData
                % instantiated.
                if(~isempty(obj.SensorData))
                    obj.AppSettings.DATA = obj.SensorData.getSaveParameters();
                end
                
                % update the stat tool settings if it was used successfully.
                if(~isempty(obj.StatTool) && obj.StatTool.getCanPlot())
                    obj.AppSettings.StatTool = obj.StatTool.getSaveParameters();
                end
                
                if(~isempty(obj.outcomesTable))
                    obj.AppSettings.outcomesTable = obj.outcomesTable.getSaveParameters();
                end
                obj.AppSettings.CONTROLLER = obj.getSaveParameters();
                didRefresh = true;
            catch me
                showME(me);
                didRefresh = false;
            end
        end
        
        %         function paramStruct = getSaveParametersStruct(obj)
        %             paramStruct = obj.AppSettings.SingleStudy;
        %         end
        
        
        %% Startup configuration functions and callbacks
        % --------------------------------------------------------------------
        %> @brief Configure callbacks for the figure, menubar, and widets.
        %> Called internally during class construction.
        %> @param obj Instance of PAAppController
        % --------------------------------------------------------------------
        function initCallbacks(obj)
            figH = obj.SingleStudy.getFigHandle();
            
            % mouse and keyboard callbacks
            set(figH,'KeyPressFcn',@obj.keyPressCallback);
            set(figH,'KeyReleaseFcn',@obj.keyReleaseCallback);
            set(figH,'WindowButtonDownFcn',@obj.windowButtonDownCallback);
            set(figH,'WindowButtonUpFcn',@obj.windowButtonUpCallback);
            
                  
            %         function setLinehandle(obj, line_h)
            %             obj.clear_handles();
            %             obj.current_linehandle = line_h;
            %             set(obj.current_linehandle,'selected','on');
            %         end
            
            
            %configure the user interface widgets
            obj.initWidgetCallbacks();
        end
        
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
        
        % --------------------------------------------------------------------
        %> @brief  Executes on key press with focus on figure and no controls selected.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to figure (gcf)
        %> @param eventdata Structure of key press information.
        % --------------------------------------------------------------------
        function keyPressCallback(obj,hObject, eventdata)
            % key=double(get(hObject,'CurrentCharacter')); % compare the values to the list
            key=eventdata.Key;
            %             handles = guidata(hObject);
            window = obj.getCurWindow();
            
            if(strcmp(key,'add'))
                
            elseif(strcmp(key,'subtract'))
                
            elseif(strcmp(key,'leftarrow')||strcmp(key,'pagedown'))
                %go backward 1 window
                obj.setCurWindow(window-1);
            elseif(strcmp(key,'rightarrow')||strcmp(key,'pageup'))
                %go forward 1 window
                obj.setCurWindow(window+1);
            elseif(strcmp(key,'uparrow'))
                %go forward 10 windows
                obj.setCurWindow(window+10);
            elseif(strcmp(key,'downarrow'))
                %go back 10 windows
                obj.setCurWindow(window-10);
            end
            
            if(strcmp(eventdata.Key,'shift'))
                set(obj.SingleStudy.getFigHandle(),'pointer','ibeam');
            end
            if(strcmp(eventdata.Modifier,'control'))
                %kill the program
                if(strcmp(eventdata.Key,'x'))
                    delete(hObject);
                    %take screen capture of figure
                elseif(strcmp(eventdata.Key,'f'))
                    obj.figureScreenshot();
                    %take screen capture of main axes
                elseif(strcmp(eventdata.Key,'s'))
                    if(isa(obj.SingleStudy,'PASingleStudyController') &&ishandle(obj.SingleStudy.axeshandle.secondary))
                        obj.screenshotPathname = screencap(obj.SingleStudy.axeshandle.secondary,[],obj.screenshotPathname);
                    end
                elseif(strcmp(eventdata.Key,'p'))
                    if(isa(obj.SingleStudy,'PASingleStudyController') &&ishandle(obj.SingleStudy.axeshandle.primary))
                        obj.screenshotPathname = screencap(obj.SingleStudy.axeshandle.primary,[],obj.screenshotPathname);
                    end
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes on key press with focus on figure and no controls selected.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventdata Structure of key press information.
        % --------------------------------------------------------------------
        function keyReleaseCallback(obj,~, eventdata)            
            key=eventdata.Key;
            if(strcmp(key,'shift'))
                set(obj.SingleStudy.getFigHandle(),'pointer','arrow');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes when user releases mouse click
        %> If the currentObject selected is the secondary axes, then
        %> the current window is set to the closest window corresponding to
        %> the mouse's x-position.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventData Structure of mouse press information; unused
        % --------------------------------------------------------------------
        function windowButtonUpCallback(obj,hObject,~)
            selected_obj = get(hObject,'CurrentObject');
            if(~isempty(selected_obj) && ~strcmpi(get(hObject,'SelectionType'),'alt'))   % Dont get confused with mouse button up due to contextmenu call
                if(selected_obj==obj.SingleStudy.axeshandle.secondary)
                    pos = get(selected_obj,'currentpoint');
                    clicked_datenum = pos(1);
                    cur_window = obj.SensorData.datenum2window(clicked_datenum,obj.SingleStudy.getDisplayType());
                    obj.setCurWindow(cur_window);
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes when user first clicks the mouse.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventData Structure of mouse press information; unused
        %> @param Note - this turns off all other mouse movement and mouse
        %> wheel callback methods.
        % --------------------------------------------------------------------
        function windowButtonDownCallback(obj,varargin)
            if(ishandle(obj.current_linehandle))
                set(obj.SingleStudy.figurehandle,'windowbuttonmotionfcn',[]);
                
                obj.deactivateLineHandle();
            end
        end
        
        function deactivateLineHandle(obj)
            set(obj.current_linehandle,'selected','off');
            obj.current_linehandle = [];
            obj.SingleStudy.showReady();
            set(obj.SingleStudy.figurehandle,'windowbuttonmotionfcn',[],'WindowScrollWheelFcn',[]);
        end
        
        %-- Menubar configuration --
        % --------------------------------------------------------------------
        %> @brief Assign figure's menubar callbacks.
        %> Called internally during class construction.
        %> @param obj Instance of PAAppController
        % --------------------------------------------------------------------
        function initMenubarCallbacks(obj)
            figH = obj.SingleStudy.getFigHandle();
            viewHandles = guidata(figH);
            
            %% file
            % settings and about
            set(viewHandles.menu_file_about,'callback',@obj.menuFileAboutCallback);
            set(viewHandles.menu_file_settings_application,'callback',@obj.menuFileSettingsApplicationCallback);
            set(viewHandles.menu_file_settings_usageRules,'callback',@obj.menuFileSettingsUsageRulesCallback);
            set(viewHandles.menu_load_settings,'callback',@obj.loadSettingsCb);
            
            %  open
            set(viewHandles.menu_file_open,'callback',@obj.menuFileOpenCallback);
            set(viewHandles.menu_file_open_resultspath,'callback',@obj.menuFileOpenResultsPathCallback);
            
            % import
            set(viewHandles.menu_file_openVasTrac,'callback',@obj.menuFileOpenVasTracCSVCallback,'enable','off','visible','off');
            set(viewHandles.menu_file_openFitBit,'callback',@obj.menuFileOpenFitBitCallback,'enable','off','visible','off');
            
            set(viewHandles.menu_file_import_csv,'callback',@obj.menuFileOpenCsvFileCallback,'enable','off');
            set(viewHandles.menu_file_import_general,'label','Text (custom)',...
                'callback',@obj.menuFileOpenGeneralCallback,'enable','on');
            set(viewHandles.menubar_import_outcomes,'callback',@obj.importOutcomesFileCb);
            
            % screeshots
            set(viewHandles.menu_file_screenshot_figure,'callback',{@obj.menuFileScreenshotCallback,'figure'});
            set(viewHandles.menu_file_screenshot_primaryAxes,'callback',{@obj.menuFileScreenshotCallback,'primaryAxes'});
            set(viewHandles.menu_file_screenshot_secondaryAxes,'callback',{@obj.menuFileScreenshotCallback,'secondaryAxes'});
            
            %  quit - handled in main window.
            set(viewHandles.menu_file_quit,'callback',{@obj.menuFileQuitCallback,guidata(figH)},'label','Close');
            set(viewHandles.menu_file_restart,'callback',@restartDlg);
            
            % export
            set(viewHandles.menu_file_export,'callback',@obj.menu_file_exportMenu_callback);
            if(~isdeployed)
                set(viewHandles.menu_file_export_SensorData,'callback',@obj.menu_file_export_SensorData_callback);%,'label','Sensor object to MATLAB');
                set(viewHandles.menu_file_export_clusterObj,'callback',@obj.menu_file_export_clusterObj_callback); %,'label','Cluster object to MATLAB');
            % No point in sending data to the workspace on deployed
            % version.  There is no 'workspace'.
            else
                set(viewHandles.menu_file_export_SensorData,'visible','off');
                set(viewHandles.menu_file_export_clusterObj,'visible','off');
            end
            set(viewHandles.menu_file_export_clusters_to_csv,'callback',{@obj.exportClustersCb,'csv'});%, 'label','Cluster results to disk');
            set(viewHandles.menu_file_export_clusters_to_xls,'callback',{@obj.exportClustersCb,'xls'});%, 'label','Cluster results to disk');
            set(viewHandles.menu_export_timeseries_to_disk,'callback',@obj.exportTimeSeriesCb);%,'label','Wear/nonwear to disk');
            
            
            %% View Modes
            set(viewHandles.menu_viewmode_timeseries,'callback',{@obj.setViewModeCallback,'timeSeries'});
            set(viewHandles.menu_viewmode_results,'callback',{@obj.setViewModeCallback,'results'});
            
            %% Tools
            set(viewHandles.menu_tools_batch,'callback',@obj.menuToolsBatchCallback);
            set(viewHandles.menu_tools_bootstrap,'callback',@obj.menuToolsBootstrapCallback,'enable','off');  % enable state depends on PAStatTool construction success (see obj.events)
            set(viewHandles.menu_tools_raw2bin,'callback',@obj.menuToolsRaw2BinCallback);
            set(viewHandles.menu_tools_coptr2act,'callback',@obj.coptr2actigraphCallback);
            
            
            %% Help
            set(viewHandles.menu_help_faq,'callback',@obj.menuHelpFAQCallback);
            
            % enable remaining 
            set([
                viewHandles.menu_file
                viewHandles.menu_file_about
                viewHandles.menu_file_settings
                viewHandles.menu_file_open    
                viewHandles.menu_file_quit
                viewHandles.menu_viewmode
                viewHandles.menu_help
                viewHandles.menu_help_faq
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
            this.SingleStudy.showBusy('Initializing help');
            filename = fullfile(this.AppSettings.rootpathname,'resources/html','PadacoFAQ.html');
            url = sprintf('file://%s',filename);
            %             web(url,'-notoolbar','-noaddressbox');
            htmldlg('url',url);
            
            this.SingleStudy.showReady();
            %             web(url);
        end
        
        function importOutcomesFileCb(this, varargin)
            %f=getOutcomeFiles();
            this.outcomesTable.importFilesFromDlg();
            %             
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
            obj.refreshSettings();
            wasModified = obj.AppSettings.defaultsEditor(optionalSettingsName);
            if(wasModified)
                if(isa(obj.StatTool,'PAStatTool'))
                    initializeOnSet = true;  % This is necessary to update widgets, which are used in follow on call to saveParameters
                    obj.StatTool.setWidgetSettings(obj.AppSettings.StatTool, initializeOnSet);
                end
                obj.setStatus('Settings have been updated.');
                
                % save parameters to disk - this saves many parameters
                % based on gui selection though ...
                obj.saveParameters();
                
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
                usageRules = obj.AppSettings.DATA.usageStateRules;
            end
            defaultRules = PASensorData.getDefaults();
            defaultRules = defaultRules.usageStateRules;
            updatedRules = simpleEdit(usageRules,defaultRules);
            
            if(~isempty(updatedRules))
                if(~isempty(obj.SensorData))
                    obj.SensorData.setUsageClassificationRules(updatedRules);
                else
                    obj.AppSettings.DATA.usageStateRules = updatedRules;
                end
                
                %                 if(isa(obj.StatTool,'PAStatTool'))
                %                     obj.StatTool.setWidgetSettings(obj.AppSettings.StatTool);
                %                 end
                fprintf('Settings have been updated.\n');
                
                % save parameters to disk
                obj.saveParameters();
                
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
            %DATA.pathname	/Volumes/SeaG 1TB/sampleData/csv
            %DATA.filename	700023t00c1.csv.csv
            f=uigetfullfile({'*.csv;*.raw;*.bin','All (counts, raw accelerations)';
                '*.csv','Comma Separated Values';
                '*.bin','Raw Acceleration (binary format: firmwares 2.2.1, 2.5.0, and 3.1.0)';
                '*.raw','Raw Acceleration (comma separated values)';
                '*.gt3x','Raw GT3X binary'},...
                'Select a file',fullfile(obj.AppSettings.DATA.pathname,obj.AppSettings.DATA.filename));
            try
                if(~isempty(f))
                    %                     if(~strcmpi(obj.getViewMode(),'timeseries'))
                    %                         obj.SingleStudy.setViewMode('timeseries'); % bypass the this.setViewMode() for now to avoid follow-up query that a file has not been loaded yet.
                    %                     end
                    
                    obj.SingleStudy.showBusy('Loading','all');
                    obj.SingleStudy.disableWidgets();
                    [pathname,basename, baseext] = fileparts(f);
                    obj.AppSettings.DATA.pathname = pathname;
                    obj.AppSettings.DATA.filename = strcat(basename,baseext);
                    
                    obj.SensorData = PASensorData(f,obj.AppSettings.DATA);
                    
                    obj.SensorData.addlistener('LinePropertyChanged',@obj.linePropertyChangeCallback);
                    
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
            importObj = PASensorDataImport(obj.AppSettings.IMPORT);
            if(~importObj.cancelled)
                obj.AppSettings.IMPORT = importObj.getSettings();
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a .csv file
        %> @param obj Instance of PAAppController
        function menuFileOpenCsvFileCallback(obj, ~, ~)
            f=uigetfullfile({'*.csv','Comma separated values (.csv)';'*.*','All files'},...
                'Select a file',fullfile(obj.AppSettings.DATA.pathname,obj.AppSettings.DATA.filename));
            try
                if(~isempty(f))
                    obj.SingleStudy.showBusy('Loading','all');
                    [pathname,basename, baseext] = fileparts(f);
                    obj.AppSettings.DATA.pathname = pathname;
                    obj.AppSettings.DATA.filename = strcat(basename,baseext);
                    
                    obj.SensorData = PASensorData([],obj.AppSettings.DATA);
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
                'Select a file',fullfile(obj.AppSettings.DATA.pathname,obj.AppSettings.DATA.filename));
            try
                if(~isempty(f))
                    obj.SingleStudy.showBusy('Loading','all');
                    [pathname,basename, baseext] = fileparts(f);
                    obj.AppSettings.DATA.pathname = pathname;
                    obj.AppSettings.DATA.filename = strcat(basename,baseext);
                    
                    obj.SensorData = PASensorData([],obj.AppSettings.DATA);
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
        %> @brief Menubar callback for opening a fitbit file.
        %> @param obj Instance of PAAppController
        %> @param hObject  handle to menu_file_open (see GCBO)
        %> @param eventdata Required by MATLAB, but not used.
        % --------------------------------------------------------------------
        function menuFileOpenFitBitCallback(obj,varargin)
            
            f=uigetfullfile({'*.txt;*.fbit','Fitbit';
                '*.csv','Comma Separated Values'},...
                'Select a file',fullfile(obj.AppSettings.DATA.pathname,obj.AppSettings.DATA.filename));
            try
                if(~isempty(f))

                    
                    
                    obj.SingleStudy.showBusy('Loading','all');
                    [pathname,basename, baseext] = fileparts(f);
                    obj.AppSettings.DATA.pathname = pathname;
                    obj.AppSettings.DATA.filename = strcat(basename,baseext);
                    
                    obj.SensorData = PASensorData(f,obj.AppSettings.DATA);
                    
                    
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
            initialPath = obj.resultsPathname;
            resultsPath = uigetfulldir(initialPath, 'Select path containing PADACO''s features directory');
            try
            if(~isempty(resultsPath))
                % Say good bye to your old stat tool if you selected a
                % directory.  This ensures that if a breakdown occurs in
                % the following steps, we do not have a previous StatTool
                % hanging around showing results and the user unaware that
                % a problem occurred (i.e. no change took place).
                % obj.StatTool = [];
                obj.resultsPathname = resultsPath;
                if(~strcmpi(obj.getViewMode(),'results'))
                    obj.SingleStudy.showBusy('Switching to results view');
                    obj.setViewMode('results');
                end
                
                obj.SingleStudy.showBusy('Initializing results view','all');
                if(obj.initResultsView())
                    obj.SingleStudy.showReady('all');
                else
                    f=warndlg('I could not find any feature files in the directory you selected.  Check the editor window for further information','Load error','modal');
                    waitfor(f);
                    obj.SingleStudy.showReady();
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
                obj.SingleStudy.showReady();
                
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
                    handle = obj.SingleStudy.figurehandle;
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
                    obj.screenshotPathname = screencap(handle,[],obj.screenshotPathname);
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
            timeSeriesH = [curHandles.menu_file_export_SensorData
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
        function menu_file_export_SensorData_callback(obj,varargin)
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
            viewMode = obj.viewMode;
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
            
            if(strcmpi(obj.viewMode,viewMode))
                obj.setStatus('Refreshing %s view',viewMode);
            else
                obj.SingleStudy.showBusy(['Switching to ',viewMode,' view'],'all');        
                obj.viewMode = viewMode;
                obj.SingleStudy.setViewMode(viewMode);

            end
            figure(obj.figureH);  %redraw and place it on top
            refresh(obj.figureH); % redraw it
            %             shg();  %make sure it is on top.
            
            switch lower(viewMode)
                case 'timeseries'
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
                    obj.initResultsView();
            end
            % Show ready when everything has been initialized to avoid
            % flickering (i.e. don't place this above the switch
            % statement).
            obj.SingleStudy.showReady();
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
            if(isdir(obj.AppSettings.BatchMode.outputDirectory))
                obj.resultsPathname = obj.AppSettings.BatchMode.outputDirectory;
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
        
        % ======================================================================
        %> @brief Returns a structure of PAAppControllers saveable parameters as a struct.
        %> @param obj Instance of PASingleStudyController.
        %> @retval pStruct A structure of save parameters which include the following
        %> fields
        %> - @c featureFcn
        %> - @c signalTagLine
        %> - @
        function pStruct = getSaveParameters(obj)
            pStruct = obj.AppSettings.CONTROLLER;
            
            pStruct.featureFcnName = obj.getExtractorMethod();
            pStruct.signalTagLine = obj.getSignalSelection();
            
            % If we did not load a file then our signal selection will be
            % empty (don't know if were going to use count or raw data,
            % etc.  So, just stick with whatever we began with at time of construction.
            if(isempty(pStruct.signalTagLine))
                pStruct.signalTagLine = obj.AppSettings.CONTROLLER.signalTagLine;
            end
            
            pStruct.highlightNonwear = obj.SingleStudy.getNonwearHighlighting();
            pStruct.useSmoothing = obj.SingleStudy.getUseSmoothing();
            pStruct.screenshotPathname = obj.screenshotPathname;
            pStruct.viewMode = obj.viewMode;
            pStruct.resultsPathname = obj.resultsPathname;
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
            
            % SensorData has already been initialized with default/saved
            % settings (i.e. obj.AppSettings.DATA) and these are in turn
            % passed along to the SingleStudy class here and used to initialize
            % many of the selected widgets.
            
            obj.SingleStudy.showBusy('Initializing View','all');            
            
            obj.initSignalSelectionMenu();
            
            curAccelType = obj.getAccelType();
            if(any(strcmpi(curAccelType, {'all','raw'})))
                obj.accelTypeShown = 'raw';
            else
                obj.accelTypeShown = 'count';
            end
            
            
            % Shows line labels after initWithAccelData
            obj.SingleStudy.initWithAccelData(obj.SensorData);
            
            
            %set signal choice
            signalSelection = obj.setSignalSelection(obj.AppSettings.CONTROLLER.signalTagLine); %internally sets to 1st in list if not found..
            obj.setExtractorMethod(obj.AppSettings.CONTROLLER.featureFcnName);
            
            % Go ahead and extract features using current settings.  This
            % is good because then we can use
            obj.SingleStudy.showBusy('Calculating features','all');
            tic
            obj.SensorData.extractFeature(signalSelection,'all');
            toc
            
            % This was disabled until the first time features are
            % calculated.
            obj.SingleStudy.enableTimeSeriesRadioButton();
            obj.SingleStudy.enableFeatureRadioButton();
            
            % set the display to show time series data initially.
            displayType = 'Time Series';
            displayStructName = PASensorData.getStructNameFromDescription(displayType);
            obj.setRadioButton(displayStructName);
            
            % Now I am showing labels
            obj.setDisplayType(displayStructName);
            
            %but not everything is shown...
            
            obj.setCurWindow(obj.SensorData.getCurWindow());
            
            % Update the secondary axes
            % Items to display = 8 when count or all views exist.  
            if(strcmpi(obj.getAccelType(),'raw'))
                obj.numViewsInSecondaryDisplay = 7;
            else
                obj.numViewsInSecondaryDisplay = 8;
                
            end
            % Items 1-5
            % Starting from the bottom of the axes - display the features
            % for x, y, z, vec magnitude, and 1-d values
            heightOffset = obj.updateSecondaryFeaturesDisplay();
            
            itemsToDisplay = obj.numViewsInSecondaryDisplay-5; % usage state, mean lumens, daylight approx
            remainingHeight = 1-heightOffset;
            height = remainingHeight/itemsToDisplay;
            if(obj.SensorData.getSampleRate()<=1)
                
                usageVec = obj.getUsageState();
                obj.SingleStudy.addWeartimeToSecondaryAxes(usageVec,obj.SensorData.dateTimeNum,height,heightOffset);
                % Old
                % vecHandles = obj.SingleStudy.addFeaturesVecToSecondaryAxes(usageVec,obj.SensorData.dateTimeNum,height,heightOffset);
                
                % Older
                %[usageVec,usageState, startStopDatenums] = obj.getUsageState();

                %obj.SingleStudy.addOverlayToSecondaryAxes(usageState,startStopDatenums,1/numRegions,curRegion/numRegions);
            else
                % Old
                %                 vecHandles = [];
            end
            
            numFrames = obj.getFrameCount();
            
            if(~strcmpi(obj.getAccelType(),'raw'))
                % Next, add lumens intensity to secondary axes
                heightOffset = heightOffset+height;
                maxLumens = 250;

                [meanLumens,startStopDatenums] = obj.getMeanLumenPatches(numFrames);
                [overlayLineH, overlayPatchH] = obj.SingleStudy.addOverlayToSecondaryAxes(meanLumens,startStopDatenums,height,heightOffset,maxLumens); %#ok<ASGLU>
                uistack(overlayPatchH,'bottom');
                %             [medianLumens,startStopDatenums] = obj.getMedianLumenPatches(1000);
                %             obj.SingleStudy.addLumensOverlayToSecondaryAxes(meanLumens,startStopDatenums);
            end
            
            % Finally Add daylight to the top.
            maxDaylight = 1;            
            [daylight,startStopDatenums] = obj.getDaylight(numFrames);
            heightOffset = heightOffset+height;

            [overlayLineH, overlayPatchH] = obj.SingleStudy.addOverlayToSecondaryAxes(daylight,startStopDatenums,height-0.005,heightOffset,maxDaylight); %#ok<ASGLU>
            uistack(overlayPatchH,'bottom');
            
            obj.initCallbacks(); %initialize callbacks now that we have some data we can interact with.
            
            obj.SingleStudy.showReady('all');
            
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
            if(isdir(this.resultsPathname))
                if(~isempty(this.StatTool))
                    
                    StatToolResultsPath = this.StatTool.getResultsDirectory();
                    
                    refreshPath = false;
                    if(~strcmpi(StatToolResultsPath,this.resultsPathname))
                        msgStr = sprintf('There has been a change to the results path.\nWould you like to load features from the updated path?\n%s',this.resultsPathname);
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
                                this.resultsPathname = StatToolResultsPath;  
                            otherwise
                                refreshPath = false;
                        end                                
                    end

                    if(refreshPath)
                        this.StatTool.setResultsDirectory(this.resultsPathname);
                    else
                        % Make sure the resultsPath is up to date (e.g. when
                        % switching back from a batch mode.
                        this.StatTool.init();  %calls a plot refresh
                        
                    end
                else
                    this.StatTool = PAStatTool(this.SingleStudy.figurehandle,this.resultsPathname,this.AppSettings.StatTool);
                    this.StatTool.setIcon(this.iconFilename);
                    if(~isempty(this.outcomesTable) && this.outcomesTable.importOnStartup && this.StatTool.useOutcomes)
                        this.StatTool.setOutcomesTable(this.outcomesTable);
                    end
                end
                success = this.StatTool.getCanPlot();
            end
            
            if(~success)
                if(isfield(this,'StatTool') && isa(this.StatTool,'PAStatTool'))
                    this.StatTool.disable();
                end
                
                this.StatTool = [];
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
            
            fig_h = obj.SingleStudy.figurehandle;
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
            [img_filename, img_pathname, filterindex] = uiputfile(filterspec,'Screenshot name',fullfile(obj.screenshotPathname,img_filename));
            if isequal(img_filename,0) || isequal(img_pathname,0)
                disp('User pressed cancel');
            else
                try
                    if(filterindex>2)
                        filterindex = 1; %default to .png
                    end
                    fig_h = obj.SingleStudy.figurehandle;
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
                    obj.screenshotPathname = img_pathname;
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
            if(obj.setFigureHandle(hFigure))
                % Place this sooner so that we can go ahead and crush the
                % figure if something breaks down and we get get stuck
                % before reaching the closerequestfcn we want to use later
                % on (Which requires certain initializations to complete).
                set(hFigure,'closeRequestFcn','delete(gcbo)');

                figColor = get(hFigure,'color');
                defaultUnits = 'pixels';
                handles = guidata(hFigure);
                
                set([handles.text_status;
                    handles.panel_results;
                    handles.panel_timeseries],'backgroundcolor',figColor,'units',defaultUnits);
                
                set([handles.panel_results;
                    handles.panel_timeseries],'bordertype','none');
                
                set([hFigure
                    handles.panel_timeseries
                    handles.panel_results
                    handles.panel_resultsContainer
                    handles.panel_epochControls
                    handles.panel_displayButtonGroup
                    handles.btngrp_clusters],'units','pixels');
                
                screenSize = get(0,'screensize');
                figPos = get(hFigure,'position');
                timeSeriesPanelPos = get(handles.panel_timeseries,'position');
                resultsPanelPos = get(handles.panel_results,'position');
                
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
                    set(handles.panel_results,'position',[timeSeriesPanelPos(1),newResultsPanelY,resultsPanelPos(3:4)]);
                   
                    metaDataHandles = [handles.panel_study;get(handles.panel_study,'children')];
                    set(metaDataHandles,'backgroundcolor',[0.94,0.94,0.94],'visible','off');
                    
                    whiteHandles = [handles.panel_features_prefilter
                        handles.panel_features_aggregate
                        handles.panel_features_frame
                        handles.panel_features_signal
                        handles.edit_minClusters
                        handles.edit_clusterConvergenceThreshold];
                    sethandles(whiteHandles,'backgroundcolor',[1 1 1]);
                    
                    innerPanelHandles = [
                        handles.panel_clusteringSettings
                        handles.panel_timeFrame
                        handles.panel_source
                        handles.panel_shapeAdjustments
                        handles.panel_clusterSettings
                        handles.panel_shapeSettings
                        handles.btngrp_clusters
                        handles.panel_chunking];
                    sethandles(innerPanelHandles,'backgroundcolor',[0.9 0.9 0.9]);
                    
                    % Make the inner edit boxes appear white
                    set([handles.edit_minClusters
                        handles.edit_clusterConvergenceThreshold],'backgroundcolor',[1 1 1]);
                    
                    set(handles.text_threshold,'tooltipstring','Smaller thresholds result in more stringent conversion requirements and often produce more clusters than when using higher threshold values.');
                    % Flush our drawing queue
                    drawnow();
                end
                
                %     renderOffscreen(hObject);
                movegui(hFigure,'northwest');
                obj.handles = handles;
                
                didInit = true;
            end
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
            mPath = fileparts(mfilename('fullpath'));
            pStruct.screenshotPathname = mPath;
            
            pStruct.viewMode = 'timeseries';
            batchSettings = PABatchTool.getDefaults();
            pStruct.resultsPathname = batchSettings.outputDirectory;
        end
    end
    
end

