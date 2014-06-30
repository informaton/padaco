%> @file PAController.m
%> @brief PAController serves as Padaco's controller component (i.e. in the model, view, controller paradigm).
% ======================================================================
%> @brief PAController serves as the UI component of event marking in
%> the Padaco.  
%
%> In the model, view, controller paradigm, this is the
%> controller. 


classdef PAController < handle
    
    properties
        %> acceleration activity object - instance of PAData
        accelObj;
        %> Instance of PASettings - this is brought in to eliminate the need for several globals
        SETTINGS; 
        %> Instance of PAView - Padaco's view component.
        VIEW;
        %> Instance of PAModel - Padaco's model component.  To be implemented. 
        MODEL;        
        %> for the patch handles when editing and dragging
        hg_group; 
        %> label of the currently selected channel
        channel_label; 
        %>current index of channel with associated event being marked
        class_channel_index; 
        %>index of start_stop sample location of the event pointed to by event_index
        start_stop_matrix_index;
        %>holds the labels of the events that can be selected
        event_label_cell;
        %>name of the current event being marked
        event_label; 
        %>index of the event in the events_container object
        event_index; 
        %>linehandle in Padaco currently selected;
        current_linehandle;
        
        %>cell of string choices for the marking state (off, 'marking','general')
        state_choices_cell; 
        %>string of the current selected choice
        %>handle to the figure an instance of this class is associated with
        %> struct of handles for the context menus
        contextmenuhandle; 
        
        %> @brief struct with field
        %> - .x_minorgrid which is used for the x grid on the main axes
        linehandle;
         
        
        epoch_resolution;%struct of different time resolutions, field names correspond to the units of time represented in the field        
        edit_epoch_h;  %handle to the editable epoch handle
        current_epoch;
        num_epochs;
        display_samples; %vector of the samples to be displayed
        shift_display_samples_delta; %number of samples to adjust display by for moving forward or back
        startDateTime;
        study_duration_in_seconds;
        study_duration_in_samples;

        STATE; %struct to keep track of various Padaco states
        Padaco_loading_file_flag; %boolean set to true when initially loading a src file
        Padaco_mainaxes_ylim;
        Padaco_mainaxes_xlim;        
    end
    
    methods(Access=private)
        % --------------------------------------------------------------------
        %> @brief Initializes the display using instantiated instance
        %> variables VIEW (PAView) and accelObj (PAData)
        %> @param Instance of PAContraller
        % --------------------------------------------------------------------
        function initView(obj)
            %keep record of our settings
            obj.SETTINGS.DATA.lastPathname = obj.accelObj.pathname;
            obj.SETTINGS.DATA.lastFilename = obj.accelObj.filename;
            
            obj.VIEW.showReady();
            obj.VIEW.initWithAccelData(obj.accelObj);
            
            lineHandles = obj.VIEW.getLinehandle();
            
            obj.setLineScale(lineHandles);
            obj.setLineColor(lineHandles);
            obj.setLineOffset(lineHandles);
            
        end
    end

    methods
        
        function obj = PAController(Padaco_fig_h,...
                rootpathname,...
                parameters_filename)
            if(nargin<1)
                Padaco_fig_h = [];
            end
            if(nargin<2)
                rootpathname = fileparts(mfilename('fullpath'));
            end
            
            %check to see if a settings file exists
            if(nargin<3)
                parameters_filename = '_padaco.parameters.txt';
            end;
            
            %create/intilize the settings object            
            obj.SETTINGS = PASettings(rootpathname,parameters_filename);

            if(ishandle(Padaco_fig_h))
                %let's create a VIEW class
                obj.VIEW = PAView(Padaco_fig_h);
                
                handles = guidata(Padaco_fig_h);
                
                %configure the menu bar
                obj.configureMenubar();                
                
                %configure the user interface widgets
                obj.configureWidgetCallbacks();
                
                % Synthesize edit callback to trigger first display
                obj.edit_curEpochCallback(handles.edit_curEpoch,[]);
                
            end                
        end
        
        %% Shutdown functions        
        %> Destructor
        function close(obj)
            obj.saveParameters(); %requires SETTINGS variable
            obj.SETTINGS = [];
        end        
        
        function saveParameters(obj)
            obj.SETTINGS.saveParametersToFile();
        end
        
        function paramStruct = getSaveParametersStruct(obj)
            paramStruct = obj.SETTINGS.VIEW;
        end            
        

        %% Startup configuration functions
        %-- Menubar configuration --
        % --------------------------------------------------------------------
        %> @brief Assign figure's menubar callbacks.
        %> Called internally during class construction.
        %> @param Instance of PAContraller
        % --------------------------------------------------------------------        
        function configureMenubar(obj)
            handles = guidata(obj.VIEW.getFigHandle());
            
            %file
            set(handles.menu_file_open,'callback',@obj.openFileCallback);
        end
        
        % --------------------------------------------------------------------
        %> @brief Assign callbacks to various user interface widgets.
        %> Called internally during class construction.
        %> @param Instance of PAContraller
        % --------------------------------------------------------------------
        function configureWidgetCallbacks(obj)
            handles = guidata(obj.VIEW.getFigHandle());
            set(handles.edit_curEpoch,'callback',@obj.edit_curEpochCallback);
        end
    
        % --------------------------------------------------------------------
        %> @brief Callback for current epoch's edit textbox.
        %> @param Instance of PAContraller
        %> @param Handle to the edit text widget
        %> @param Required by MATLAB, but not used
        % --------------------------------------------------------------------
        function edit_curEpochCallback(obj,hObject,eventdata)
            epoch = str2double(get(hObject,'string'));
            
            if(~obj.setCurEpoch(epoch))
                epoch = obj.curEpoch();
            end
            set(hObject,'string',num2str(epoch));
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
            success= false;
            if(~isempty(obj.accelObj))
                success = obj.accelObj.setCurEpoch(epoch);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the current epoch of the instance variable accelObj
        %> (PAData)
        %> @param Instance of PAContraller
        %> @param The  current epoch, or null if it has not been initialized.
        function epoch = curEpoch(obj)
            if(isempty(obj.accelObj))
                epoch = [];
            else
                epoch = obj.accelObj.curEpoch;
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Menubar callback for opening a file.
        %> @param Instance of PAContraller
        %> @param hObject    handle to menu_file_open (see GCBO)
        % --------------------------------------------------------------------
        function openFileCallback(obj,hObject,eventdata)
            f=uigetfullfile({'*.csv','Comma Separated Vectors';'*.dat','Raw text (space delimited)'},'Select a file','off',fullfile(obj.SETTINGS.DATA.lastPathname,obj.SETTINGS.DATA.lastFilename));
            
            if(~isempty(f))
                obj.VIEW.showBusy('Loading');
                obj.accelObj = PAData(f);
                
                %initialize the PAData object's visual properties
                obj.initView();
            end
        end
        

 
        % --------------------------------------------------------------------
        function menu_file_screenshot_callback(obj,hObject, eventdata)
            % hObject    handle to menu_file_screenshot (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)            
            if(~isfield(obj.SETTINGS.VIEW,'screenshot_path'))
                obj.SETTINGS.VIEW.screenshot_path = pwd;
            end
            
            filterspec = {'png','PNG';'jpeg','JPEG'};
            save_format = {'-dpng','-djpeg'};
            img_filename = [obj.SETTINGS.VIEW.src_edf_filename,'_epoch ',num2str(obj.current_epoch),'.png'];
            [img_filename, img_pathname, filterindex] = uiputfile(filterspec,'Screenshot name',fullfile(obj.SETTINGS.VIEW.screenshot_path,img_filename));
            if isequal(img_filename,0) || isequal(img_pathname,0)
                disp('User pressed cancel')
            else
                try
                    if(filterindex>2)
                        filterindex = 1; %default to .png
                    end
                    fig_h = obj.figurehandle.Padaco;
                    axes1_copy = copyobj(obj.axeshandle.main,fig_h);
                    f = figure('visible','off','paperpositionmode','auto','inverthardcopy','on',...
                        'units',get(fig_h,'units'),'position',get(fig_h,'position'),...
                        'toolbar','none','menubar','none');
                    set(f,'units','normalized');
                    set(axes1_copy,'parent',f);
                    cropFigure2Axes(f,axes1_copy);

                    set(f,'visible','on');
                    set(f,'clipping','off');
                    
                    print(f,save_format{filterindex},'-r0',fullfile(img_pathname,img_filename));
                    
                    delete(f);
                    
                    obj.SETTINGS.VIEW.screenshot_path = img_pathname;
                catch ME
                    showME(ME);
                    %         set(handles.axes1,'parent',handles.Padaco_main_fig);
                end
            end
        end
        
 
        
        %--------------------------------%
        %      Analyzer Callbacks        %
        %--------------------------------%        
        % --------------------------------------------------------------------
        function filter_channel_callback(obj,hObject, eventdata)
            % hObject    handle to menu_tools_filter_toolbox (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            global CHANNELS_CONTAINER;
            
            channel_label_str = cell(CHANNELS_CONTAINER.num_channels,1);
            for k=1:numel(channel_label_str)
                channel_label_str{k} = CHANNELS_CONTAINER.cell_of_channels{k}.EDF_label;
            end
            
            filter_struct = prefilter_dlg(channel_label_str,CHANNELS_CONTAINER.filterArrayStruct,[],obj.SETTINGS.VIEW.filter_path,obj.SETTINGS.VIEW.filter_inf_file,CHANNELS_CONTAINER);
            
            %filter_struct has the following fields
            % src_channel_index   (the index of the event_container EDF channel)
            % src_channel_label   (cell label of the string that holds the EDF channel
            %                      label
            % m_file                matlab filename to use for the filtering (feval)
            % ref_channel_index   (the index or indices of additional channels to use
            %                       as a reference when and where necessary
            % ref_channel_label   (cell of strings that hold the EDF channel label
            % associated with the ref_channel_index
            if(~isempty(filter_struct))
                obj.showBusy();
                try
                    CHANNELS_CONTAINER.filter(filter_struct);
                catch me
                    showME(me);
                end
                obj.refreshAxes();
            end
            
        end
        

        
        % --------------------------------------------------------------------
        function menu_tools_timelineEventsSelection_callback(obj,hObject, eventdata)
            % hObject    handle to menu_tools_viewAllEvents (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            %called from the menu bar, and is used to determine how the lower axes
            %should display events
            global EVENT_CONTAINER;
            % global CHANNELS_CONTAINER;
            
            if(EVENT_CONTAINER.num_events<1)
                warndlg('No events currently available');
            else
                units = 'points';
                dlg = dialog('visible','off','units',units);
                
                pan_file = uipanel('title','External Events (file or user)','parent',dlg,'units',units);
                pan_channels = uipanel('title','Padaco Events','parent',dlg,'units',units);
                
                %loop through each channel, and then through each event object within that
                %channel - make a control for each and set to enable/checked if previously
                %selected...
                for k=1:EVENT_CONTAINER.num_events;
                    
                    eventLabel = [EVENT_CONTAINER.cell_of_events{k}.label,' (',num2str(EVENT_CONTAINER.channel_vector(k)),')'];
                    
                    if(EVENT_CONTAINER.channel_vector(k)) %i.e. it is not ==0 and thus not a file event
                        parent = pan_channels;
                    else
                        parent = pan_file;
                    end;
                    uicontrol('style','checkbox','units',units,'string',eventLabel,'parent',pan_channels,'userdata',k,'value',CHANNELS_CONTAINER.events_to_plot(k));
                end;
                
                
                
                % left and bottom are the distance from the lower-left corner of the parent object to the lower-left corner of the uicontrol object. width and height are the dimensions of the uicontrol rectangle. All measurements are in units specified by the Units property.
                
                width = 25;
                
                delta = 5;
                cur_pos = [delta, delta, 0 0];
                
                h = allchild(pan_channels);
                h = h(1:end-1); %skip the initial channel, which is not there
                h_channels = h;
                for k=1:numel(h)
                    extent = get(h(k),'extent');
                    cur_pos(3:4) = max(cur_pos(3:4),extent(3:4)+20);
                    set(h(k),'position',cur_pos);
                    cur_pos(2) = cur_pos(2)+cur_pos(4);
                    
                end
                
                bOK = uicontrol('parent',dlg,'style','pushbutton','string','OK','units',units,'position',[50,20,50,20]);
                bCancel = uicontrol('parent',dlg,'style','pushbutton','string','Cancel','units',units,'position',[50+50+10,20,50,20],'callback','output = [],close(gcbf)');
                bPos = get(bOK,'position');
                
                set(pan_channels,'units',units,'position',[width*1.5, 2*bPos(2)+bPos(4), cur_pos(3)+width*3,cur_pos(2)+delta*2]);
                pan_channelsPos = get(pan_channels,'position');
                
                cur_pos = [delta, delta, 0 0];
                
                h = allchild(pan_file);
                h = h(1:end-1); %skip the initial channel, which is not there
                h_file = h;
                for k=1:numel(h)
                    extent = get(h(k),'extent');
                    cur_pos(3:4) = max(cur_pos(3:4),extent(3:4)+20);
                    set(h(k),'position',cur_pos);
                    cur_pos(2) = cur_pos(2)+cur_pos(4);
                end
                
                set(bOK,'callback','uiresume(gcbf)');
                
                set(pan_file,'units',units,'position',[width*1.5, pan_channelsPos(2)+pan_channelsPos(4)+bPos(4), cur_pos(3)+width*3,cur_pos(2)+delta*2]);
                pan_filePos = get(pan_file,'position');
                max_width = max(pan_channelsPos(3),pan_filePos(3));
                pan_filePos(3) = max_width;
                pan_channelsPos(3)=max_width;
                set(pan_file,'position',pan_filePos);
                set(pan_channels,'position',pan_channelsPos);
                bPos(1) = width*1.5;
                set(bOK,'position',bPos);
                bPos(1) = max_width+width*1.5-bPos(3);
                set(bCancel,'position',bPos);
                figPosition = get(dlg,'position');
                
                set(0,'Units',units)
                scnsize = get(0,'ScreenSize');
                
                figPosition(3:4) = [max_width+width*3,...
                    bPos(4)+pan_filePos(4)+pan_filePos(2)]; %[width, height]
                set(dlg,'position',[(scnsize(3:4)-figPosition(3:4))/2,figPosition(3:4)],'visible','on');
                uiwait(dlg);
                
                %output will contain a boolean matrix containing the on/off selection
                %values for each label that was created.  This is changed to just indices of the true values so
                %they can be used to determine
                %which values should be drawn along the entire night axes (axes2) in
                %updateAxes2 function
                if(ishghandle(dlg)) %if it is still a graphic, then...
                    if(numel(h_file)==1)
                        if(get(h_file,'value'))
                            file_events_to_plot = get(h_file,'userdata');
                        else
                            file_events_to_plot = [];
                        end
                    else
                        file_events_to_plot = get(h_file(cell2mat(get(h_file,'value'))==1),'userdata');
                    end;
                    if(iscell(file_events_to_plot))
                        file_events_to_plot = cell2mat(file_events_to_plot);
                    end;
                    
                    if(numel(h_channels)==1)
                        if(get(h_channels,'value'))
                            channel_events_to_plot = get(h_channels,'userdata');
                        else
                            channel_events_to_plot = [];
                        end
                    else
                        channel_events_to_plot = get(h_channels(cell2mat(get(h_channels,'value'))==1),'userdata');
                    end;
                    if(iscell(channel_events_to_plot))
                        channel_events_to_plot = cell2mat(channel_events_to_plot);
                    else
                        channel_events_to_plot = false(EVENT_CONTAINER.num_eventS);
                        
                    end
                    EVENT_CONTAINER.events_to_plot = [file_events_to_plot,channel_events_to_plot];
                    delete(dlg);
                    obj.refreshAxes(handles);
                end;
            end;
        end


        
        % ----------------------
        % Main Axes Contextmenus 
        % ----------------------
        function configureMainAxesContextmenu(obj)
            %%% reference line contextmenu
            
            contextmenu_mainaxes_h = uicontextmenu('callback',@obj.contextmenu_mainaxes_callback);
            obj.contextmenuhandle.axesmain.alignchannels = uimenu(contextmenu_mainaxes_h,'Label','Align Channels');
            obj.contextmenuhandle.axesmain.centerepoch = uimenu(contextmenu_mainaxes_h,'Label','Center Here','callback',@obj.contextmenu_mainaxes_center_callback);
            obj.contextmenuhandle.axesmain.unhide = uimenu(contextmenu_mainaxes_h,'Label','Unhide');
            obj.contextmenuhandle.axesmain.x_minorgrid = uimenu(contextmenu_mainaxes_h,'Label','Minor Grid','callback',@obj.contextmenu_mainaxes_minorgrid_callback,'checked','on','separator','on');
            obj.contextmenuhandle.axesmain.x_majorgrid = uimenu(contextmenu_mainaxes_h,'Label','Major Grid','callback',@obj.contextmenu_mainaxes_majorgrid_callback,'checked','on');
            uimenu(contextmenu_mainaxes_h,'Label','Pop out','callback',{@obj.popout_axes,obj.axeshandle.main});
            uimenu(contextmenu_mainaxes_h,'Label','Event Toolbox','separator','on','callback',@obj.eventtoolbox_callback);
            set(obj.axeshandle.main,'uicontextmenu',contextmenu_mainaxes_h);
        end
        
        % --------------------------------------------------------------------
        function contextmenu_mainaxes_callback(obj,hObject, eventdata)
            %configure sub contextmenus
            global CHANNELS_CONTAINER;
            set(obj.contextmenuhandle.axesmain.alignchannels,'callback',@CHANNELS_CONTAINER.align_channels_on_axes);
%             gridstate = get(obj.axesmain,'grid');
%             if(strcmpi(gridstate,'on'))
%                 set(obj.contextmenuhandle.axesmain.grid,'string','Turn Grid Off');
%             else
%                 set(obj.contextmenuhandle.axesmain.grid,'string','Turn Grid On');
%             end
            CHANNELS_CONTAINER.configure_contextmenu_unhidechannels(obj.contextmenuhandle.axesmain.unhide);
        end
        
        function contextmenu_mainaxes_center_callback(obj,hObject,evetdata)
            pos = round(get(obj.axeshandle.main,'currentpoint'));
            
            startSample = round((pos(1)-obj.getSamplesPerEpoch()/2));  %make mouse position be in the middle of the new epoch
            
            %don't do this call:
            %    obj.setStartSample(startSample);
            %becasue it will realign on the epoch if the centering changes
            %the epoch start position.
            samples_per_epoch = obj.getSamplesPerEpoch();
            if(startSample<1)
                obj.display_samples = 1:samples_per_epoch;
            elseif(startSample+samples_per_epoch>obj.study_duration_in_samples)
                obj.display_samples = obj.study_duration_in_samples-samples_per_epoch+1:obj.study_duration_in_samples;
            else
                obj.display_samples = startSample:startSample+samples_per_epoch-1;
            end
            obj.Padaco_mainaxes_xlim = [obj.display_samples(1),obj.display_samples(end)];
            
            obj.updateMainAxes();
        end 

        function setStartSample(obj,startSample)
            %begin the main axes at start sample
            samples_per_epoch = obj.getSamplesPerEpoch();
            if(startSample<1)
                obj.display_samples = 1:samples_per_epoch;
            elseif(startSample+samples_per_epoch>obj.study_duration_in_samples)
                obj.display_samples = obj.study_duration_in_samples-samples_per_epoch+1:obj.study_duration_in_samples;
            else
                obj.display_samples = startSample:startSample+samples_per_epoch-1;
            end
            obj.Padaco_mainaxes_xlim = [obj.display_samples(1),obj.display_samples(end)];
            
            new_epoch = obj.getEpochAtSamplePt(obj.Padaco_mainaxes_xlim(1));
            
            if(new_epoch~=obj.current_epoch)
                obj.setEpoch(new_epoch);
            else
                obj.updateMainAxes();
            end;
        end
        
        function increaseStartSample(obj)
            obj.setStartSample(obj.display_samples+obj.shift_display_samples_delta); 
        end
        function decreaseStartSample(obj)
            obj.setStartSample(obj.display_samples-obj.shift_display_samples_delta); 
        end
        
        % --------------------------------------------------------------------
        function contextmenu_mainaxes_majorgrid_callback(obj,hObject, eventdata)
            if(strcmp(get(hObject,'Checked'),'on'))
                set(hObject,'Checked','off');
                set(obj.axeshandle.main,'xgrid','off');%,'ygrid','on');
            else
                set(hObject,'Checked','on');
                set(obj.axeshandle.main,'xgrid','on');%,'ygrid','off');
            end;
        end
        function contextmenu_mainaxes_minorgrid_callback(obj,hObject, eventdata)
            if(strcmp(get(hObject,'Checked'),'on'))
                set(hObject,'Checked','off');
                set(obj.linehandle.x_minorgrid,'visible','off');
            else
                set(hObject,'Checked','on');
                obj.draw_x_minorgrid();
                set(obj.linehandle.x_minorgrid,'visible','on');
            end;
        end
        


        function setDateTimeFromHDR(obj,HDR)
            %setup values based on EDF HDR passed in
            if(nargin==1)
                HDR = obj.EDF_HDR;
            end
            obj.startDateTime = HDR.T0;
            
            %this causes problems with alternatively sampled data
            %WORKSPACE.study_duration_in_samples = numel(CHANNELS_CONTAINER.cell_of_channels{1}.raw_data);
            
            
            %This caused problems when channels are of different sampling rates or durations.  Everything should be converted to 100 Hz, but still there were some problems in APOE.  Convert to time to adjust.
            obj.study_duration_in_seconds = HDR.duration_sec;
            obj.study_duration_in_samples = obj.study_duration_in_seconds*obj.SETTINGS.VIEW.samplerate;
            
            seconds_per_epoch = obj.getSecondsPerEpoch();
            
            if(seconds_per_epoch<=0)
                obj.num_epochs = 1;
            else
                obj.num_epochs = ceil(HDR.duration_sec/seconds_per_epoch); %floor(HDR.duration_sec/seconds_per_epoch);
            end
        end
        
        
        function setAxesXlim(obj)  %called when there is a change to the xlimit to be displayed
            obj.Padaco_mainaxes_xlim = [obj.display_samples(1),obj.display_samples(end)];
            obj.refreshAxes();
            
        end
        
        function setEpoch(obj,new_epoch)  
            
            if(new_epoch>0 && new_epoch <=obj.num_epochs) %&& new_epoch~=obj.current_epoch
                obj.current_epoch = new_epoch;
                if(ishandle(obj.edit_epoch_h))
                    set(obj.edit_epoch_h,'string',num2str(new_epoch));
                end

                if(obj.getSecondsPerEpoch() > 0 )
                    
                    obj.display_samples = (new_epoch-1)*obj.getSamplesPerEpoch()+1:new_epoch*obj.getSamplesPerEpoch();                    
                end
            end
            
            obj.setAxesXlim();
            
        end
        
        function setEditEpochHandle(obj,edit_epoch_handle)
            if(ishandle(edit_epoch_handle))                
                obj.edit_epoch_h = edit_epoch_handle;
                set(obj.edit_epoch_h,'callback',@obj.edit_epoch_callback);
            end
        end
        
        function edit_epoch_callback(obj,hObject, eventdata)
            % Hints: get(hObject,'String') returns contents of edit_cur_epoch as text
            %        str2double(get(hObject,'String')) returns contents of edit_cur_epoch as a double
            epoch = str2double(get(hObject,'String'));
            
            if(epoch>obj.num_epochs || epoch<1)
                set(hObject,'string',num2str(obj.current_epoch));
            else
                obj.setEpoch(epoch);
            end;
        end
        function setEpochResolutionHandle(obj,time_scale_menu_h_in)
            %time_scale_menu_h_in is popup menu for epoch scales
            if(ishandle(time_scale_menu_h_in))
                
                %initialize controls
                %establish various time views in the Padaco.
                obj.epoch_resolution.sec = [1 2 4 5 10 15 30];% [30 20 10 4 2 1];
                obj.epoch_resolution.min = [1 2 5 10 15 30];
                obj.epoch_resolution.hr = [1 2];
                obj.epoch_resolution.stage = 0:5;
                obj.epoch_resolution.all_night = 1;
                
                fields = fieldnames(obj.epoch_resolution);
                num_choices = 0;
                
                for f=1:numel(fields)
                    num_choices = num_choices+numel(obj.epoch_resolution.(fields{f}));
                end
                
                epoch_selection.units = '';
                epoch_selection.value_sec = [];
                epoch_selection.stage = [];
                epoch_selection = repmat(epoch_selection,num_choices,1);
                epoch_resolution_string = cell(num_choices,1);
                
                cur_index = 0;
                for f=1:numel(fields)
                    fname = fields{f};
                    if(strcmpi(fname,'all_night'))
                        cur_index = cur_index+1;
                        epoch_resolution_string{cur_index} = 'Entire Study';                    
                        epoch_selection(cur_index).units = fname;                        
                        epoch_selection(cur_index).value_sec = -1;
                    else
                        for k=1:numel(obj.epoch_resolution.(fname))
                            cur_index = cur_index+1;
                            
                            cur_value = obj.epoch_resolution.(fname)(k);
                            epoch_selection(cur_index).units = fname;                            

                            if(strcmpi(fname,'stage'))
                                epoch_selection(cur_index).stage = cur_value;
                                epoch_selection(cur_index).value_sec = -1;
                                epoch_resolution_string{cur_index} = sprintf('STAGE - %u',cur_value);
                            else
                                if(strcmpi(fname,'sec'))
                                    epoch_selection(cur_index).value_sec = cur_value;
                                elseif(strcmpi(fname,'min'))
                                    epoch_selection(cur_index).value_sec = cur_value*60;
                                elseif(strcmpi(fname,'hr'))
                                    epoch_selection(cur_index).value_sec = cur_value*3600;
                                end
                                epoch_resolution_string{cur_index} = sprintf('%u %s',cur_value,fname);
                            end
                        end
                    end
                end
                obj.epoch_resolution.selection_choices = epoch_selection;
                obj.epoch_resolution.current_selection_index = find(obj.epoch_resolution.sec==obj.SETTINGS.VIEW.standard_epoch_sec);
                
                
                obj.epoch_resolution.menu_h = time_scale_menu_h_in;
                set(obj.epoch_resolution.menu_h,'string',epoch_resolution_string,'value',obj.epoch_resolution.current_selection_index,'callback',@obj.epoch_resolution_callback);
            end
        end
        
        function refreshAxes(obj)
            obj.showBusy('Updating Plot');
            handles = guidata(obj.figurehandle.Padaco);
            
            obj.updateMainAxes();
            
            obj.updateTimelineAxes();
            %more of an initializeAxes type thing...
            obj.updateUtilityAxes();
            obj.showReady();
            set(handles.text_status,'string','');
        end
        
        
        function updateMainAxes(obj)
            %limits and lines are set/drawn
            global CHANNELS_CONTAINER;
            
            set([obj.texthandle.previous_stage;obj.texthandle.current_stage;...
                obj.texthandle.next_stage],'string','');

            CHANNELS_CONTAINER.setCurrentSamples(obj.display_samples);
            
            samples_per_epoch = obj.getSamplesPerEpoch();
            
            if(samples_per_epoch>0)
                %handle outputting the current and next sleep stages as text onto the axes.
                previous_stage = obj.getStageAtSamplePt(obj.display_samples(1)-1);
                next_stage = obj.getStageAtSamplePt(obj.display_samples(end)+1);
                current_stage = obj.getStageAtSamplePt(obj.display_samples(1));
                set(obj.texthandle.current_stage,'position',[obj.Padaco_mainaxes_xlim(1)+samples_per_epoch*9/20,-240,0],'string',num2str(current_stage),'parent',obj.axeshandle.main,'color',[1 1 1]*.7,'fontsize',42);
                set(obj.texthandle.previous_stage,'position',[obj.Padaco_mainaxes_xlim(1)+samples_per_epoch/20,-240,0],'string',['< ', num2str(previous_stage)],'parent',obj.axeshandle.main,'color',[1 1 1]*.8,'fontsize',35);
                set(obj.texthandle.next_stage,'position',[obj.Padaco_mainaxes_xlim(1)+samples_per_epoch*9/10,-240,0],'string',[num2str(next_stage) ' >'],'parent',obj.axeshandle.main,'color',[1 1 1]*.8,'fontsize',35);
            end;
            
            x_ticks = obj.Padaco_mainaxes_xlim(1):samples_per_epoch/6:obj.Padaco_mainaxes_xlim(end);
            set(obj.axeshandle.main,'xlim',obj.Padaco_mainaxes_xlim,'ylim',obj.Padaco_mainaxes_ylim,...
                'xticklabel',obj.getTimestampAtSamplePt(x_ticks),'xtick',x_ticks);
            
            if(strcmp(get(obj.linehandle.x_minorgrid,'visible'),'on'))
                obj.draw_x_minorgrid();
            end;

        end
        
        function updateTimelineAxes(obj)
            %axes2 is for hypnogram (sleep stages) and detected events
            
            global EVENT_CONTAINER;
            

            cla(obj.axeshandle.timeline);  %do this so I don't have to have transition line handles and sleep stage line handles, etc.
            
                        %show hypnogram and such
            xticks = linspace(1,obj.num_epochs,min(obj.num_epochs,5));
            
            set(obj.axeshandle.timeline,...
                'xlim',[0 obj.num_epochs+1],... %add a buffer of one to each side of the x limit/axis
                'ylim',[0 10],...
                'xtick',xticks,...
                'xticklabel',obj.getTimestampAtSamplePt(xticks*obj.getSamplesPerEpoch(),'HH:MM'));

            ylim = get(obj.axeshandle.timeline,'ylim');
            events_to_plot = find(EVENT_CONTAINER.event_indices_to_plot);
            
            num_events = sum(events_to_plot>0);
            
            axes_buffer = 0.05;
            if(num_events==0)
                upper_portion_height_percent = axes_buffer;
                fontsize=10;
            else
                upper_portion_height_percent = min(0.5+axes_buffer,0.2*num_events);
                fontsize = 7;
            end;
            
            lower_portion_height_percent = 1-upper_portion_height_percent;
            y_delta = abs(diff(ylim))/(num_events+1)*upper_portion_height_percent; %just want the top part - the +1 is to keep it in the range a little above and below the portion set aside for it
            
            ylim(2) = ylim(2)-y_delta/2;
            for k = 1:num_events
                EVENT_CONTAINER.cell_of_events{events_to_plot(k)}.draw_all(obj.axeshandle.timeline,ylim(2)-k*y_delta,y_delta,obj.Padaco_adjusted_STAGES);
            end;
            
            y_max = 10*lower_portion_height_percent;
            adjustedStageLine = obj.Padaco_adjusted_STAGES.line;
            
            
            %expect stages to be 0, 1, 2, 3, 4, 5, 6, 7
            possible_stages = [7,6,5,4,3,2,1,0];
            tick = linspace(0,y_max,numel(possible_stages));
            
            for k=1:numel(tick)
%                 adjustedStageLine(obj.Padaco_STAGES.line==possible_stages(k))=tick(k);
                adjustedStageLine(obj.Padaco_adjusted_STAGES.line==possible_stages(k))=tick(k);
            end
            cycle_y = tick(2); %put the cycle label where stage 6 might be shown
            tick(2) = []; %don't really want to show stage 6 as a label
            set(obj.axeshandle.timeline,...
                'ytick',tick,...
                'yticklabel','7|5|4|3|2|1|0','fontsize',fontsize);
            
            
            %reverse the ordering so that stage 0 is at the top
            x = 0:obj.num_epochs-1;
            x = [x;x+1;nan(1,obj.num_epochs)];
            % y = [STAGES.line'; STAGES.line'; nan(1,num_epochs)]; %want three rows
            % y = y_max-(y(:)+1)*y_delta-axes_buffer;
            
            y = [adjustedStageLine'; adjustedStageLine'; nan(1,obj.num_epochs)]; %want three rows
            line('xdata',x(:),'ydata',y(:),'color',[1 1 1]*.4,'linestyle','-','parent',obj.axeshandle.timeline,'linewidth',1.5,'hittest','off');
            
            %update the vertical lines with sleep cycle information
            adjustedStageCycles = obj.Padaco_adjusted_STAGES.cycles;
            transitions = [0;find(diff(adjustedStageCycles)==1);numel(adjustedStageCycles)];
            
            cycle_z = -0.5; %put slightly back
            for k=3:numel(transitions)
                curCycle = k-2;
                cycle_x = floor(mean(transitions(k-1:k)));
                text('string',num2str(curCycle),'parent',obj.axeshandle.timeline,'color',[1 1 1]*.5,'fontsize',fontsize,'position',[cycle_x,cycle_y,cycle_z]);
                %     if(k<numel(transitions)) %don't draw the very last transition
                line('xdata',[transitions(k-1),transitions(k-1)],'ydata',ylim,'linestyle',':','parent',obj.axeshandle.timeline,'linewidth',1,'hittest','off','color',[1 1 1]*0.5);
                %     end
            end
            pos = get(obj.axeshandle.timeline,'position');
            
            startX = pos(1)+obj.current_epoch/(obj.num_epochs+1)*pos(3);
            
            %draw annotation/position line along the lower axes
            if(isfield(obj.annotationhandle,'timeline')&&ishandle(obj.annotationhandle.timeline))
                set(obj.annotationhandle.timeline,'x',[startX startX],'y',[pos(2) pos(2)+pos(4)]);
            else
                obj.annotationhandle.timeline = annotation(obj.figurehandle.Padaco,'line',[startX, startX], [pos(2) pos(2)+pos(4)],'hittest','off');
            end;  
        end
        

        function timeStrCell = getTimestampAtSamplePt(obj,sample_points,fmt)
            
            if(nargin<3)
                fmt = 'HH:MM:SS';
            end
            datetime = repmat(obj.startDateTime,numel(sample_points),1);
            datetime(:,end) = datetime(:,end)+sample_points(:)/obj.SETTINGS.VIEW.samplerate;
            
            timeStrCell = datestr(datenum(datetime),fmt);
            
        end
        
        function epoch =  getEpochAtSamplePt(obj,x)
            %returns the epoch that x occurs in based on current select
            %epoch scale reoslution
            epoch = obj.sample2epoch(x, obj.getSecondsPerEpoch());
        end
        
        function epoch =  getPadacoEpochAtSamplePt(obj,x)
            %returns the epoch that x occurs in based on the standard epoch
            %length used in the Padaco (e.g. 30 seconds per epoch 
            epoch = obj.sample2epoch(x, obj.SETTINGS.VIEW.standard_epoch_sec);
        end
        
        function stage = getCurrentStage(obj)
            %returns the stage of teh currently displayed epoch
            stage = obj.getStageAtSamplePt(obj.display_samples(1));
        end
       
        function epoch = getCurrentEpoch(obj)
            %returns the currently displayed epoch in terms of elapsed
            %standard epochs (e.g. 30 s epoch sizes)
            epoch = sample2epoch(obj.display_samples(1));
        end
        function stage = getStageAtEpoch(obj, epoch)
            %returns the stage that x occurs in based on the standard epoch
            %length used in the Padaco (e.g. 30 seconds per epoch
            if(epoch<=0 || epoch> obj.num_epochs)
                stage = [];
            else
                stage = obj.Padaco_adjusted_STAGES.line(epoch);
            end
        end
        
        function stage = getStageAtSamplePt(obj, x)
            stage = obj.getStageAtEpoch(obj.getEpochAtSamplePt(x));
        end
        
        function epoch = sample2epoch(obj,index,epoch_dur_sec,sampleRate)
            % function epoch = sample2epoch(index,epoch_dur_sec,sampleRate)
            %returns the epoch for the given sample index of a signal that uses an
            %epoch size in seconds of epoch_dur_sec and that was sampled at a sample
            %rate of sampleRate - works with vectors of values as well.
            %[DEFAULT] = [VALUE]
            %[epoch_dur_sec] = [30]
            %[sampleRate] = [100]
            if(nargin<4)
                sampleRate = obj.SETTINGS.VIEW.samplerate;
            end
            if(nargin<3)
                epoch_dur_sec = obj.SETTINGS.VIEW.standard_epoch_sec;
            end;
            epoch = ceil(index/(epoch_dur_sec*sampleRate));
            
        end
        
        function epoch_resolution_callback(obj,hObject,~)            
            obj.epoch_resolution.current_selection_index = get(hObject,'value');             
            obj.setAxesResolution();
        end
        
        function seconds_per_epoch = getSecondsPerEpoch(obj)
            seconds_per_epoch = obj.epoch_resolution.selection_choices(obj.epoch_resolution.current_selection_index).value_sec;
        end
        function units_for_epoch = getEpochUnits(obj)
            units_for_epoch = obj.epoch_resolution.selection_choices(obj.epoch_resolution.current_selection_index).units;
        end
        function samples_per_epoch = getSamplesPerEpoch(obj)
            samples_per_epoch  = obj.getSecondsPerEpoch()*obj.SETTINGS.VIEW.samplerate;
        end
        
        function setAxesResolution(obj)
            global CHANNELS_CONTAINER;
            seconds_per_epoch = obj.getSecondsPerEpoch();
            if(seconds_per_epoch == obj.SETTINGS.VIEW.standard_epoch_sec)
                %                     set(obj.axeshandle.main,'dataaspectratiomode','manual','dataaspectratio',[30 12 1]);
                set(obj.axeshandle.main,'plotboxaspectratiomode','manual','plotboxaspectratio',[30 12 1]);
            else
                %                     set(obj.axeshandle.main,'dataaspectratiomode','auto');
                set(obj.axeshandle.main,'plotboxaspectratiomode','auto');
            end;

            if(seconds_per_epoch<0)
                set(obj.edit_epoch_h,'enable','off');
                epoch_units = obj.getEpochUnits();                              
                if(strcmpi(epoch_units,'stage'))
                    stage2show = obj.epoch_resolution.selection_choices(obj.epoch_resolution.current_selection_index).stage;
                    stage_epoch_ind = find(obj.Padaco_STAGES.line==stage2show);
                    epochs2samples = obj.SETTINGS.VIEW.samplerate*obj.SETTINGS.VIEW.standard_epoch_sec;
                    if(isempty(stage_epoch_ind))
                        warndlg('This stage does not exist for the current study - just showing first epoch');
                        obj.display_samples = 1:epochs2samples;
                        new_epoch = 1;
                    else
                        num_stage_epochs = numel(stage_epoch_ind);
                        obj.display_samples = zeros(num_stage_epochs,epochs2samples);
                        
                        for n=1:num_stage_epochs
                            obj.display_samples(n,:)=(stage_epoch_ind(n)-1)*epochs2samples+1:(stage_epoch_ind(n))*epochs2samples;
                        end;
                        obj.display_samples = reshape(obj.display_samples',1,[]);
                        new_epoch = stage2show;
                    end
                elseif(strcmpi(epoch_units,'all_night'))
                    obj.display_samples = 1:obj.study_duration_in_samples;
                    new_epoch = -1;
                end

            else
                set(obj.edit_epoch_h,'enable','on');                            
                obj.num_epochs = ceil(obj.study_duration_in_seconds/seconds_per_epoch);
                new_epoch = sample2epoch(obj.Padaco_mainaxes_xlim(1),seconds_per_epoch,obj.SETTINGS.VIEW.samplerate);
            end
            CHANNELS_CONTAINER.setDrawEvents();  %inform the channel container to notify all channels that their events need to be redrawn (to reflect change of axes);
            
            obj.Padaco_adjusted_STAGES.line = obj.Padaco_STAGES.line(round(linspace(1,numel(obj.Padaco_STAGES.line),obj.num_epochs)));
            obj.Padaco_adjusted_STAGES.cycles = obj.Padaco_STAGES.cycles(round(linspace(1,numel(obj.Padaco_STAGES.cycles),obj.num_epochs)));
            obj.setEpoch(new_epoch);
        end;        
                
        function obj = combo_selectEventLabel_callback(obj,hObject,eventdata)
            %             hObject is the jCombo box
            obj.event_label = get(hObject,'SelectedItem'); %hObject.getSelectedItem();            
        end
        
        
        %VIEW parts of the class....
    
        function Padaco_main_fig_WindowButtonUpFcn(obj,hObject,eventdata)            
            obj.Padaco_button_up();
        end
        
        function Padaco_main_fig_WindowButtonDownFcn(obj,hObject,eventdata)
            obj.Padaco_button_down();            
        end
        
        function Padaco_button_up(obj)                        
            selected_obj = get(obj.figurehandle.Padaco,'CurrentObject');
            
            if ~isempty(selected_obj)
                if(selected_obj==obj.axeshandle.timeline)                    
                    if(obj.getSecondsPerEpoch()>0)
                        pos = round(get(obj.axeshandle.timeline,'currentpoint'));
                        clicked_epoch = pos(1);
                        obj.setEpoch(clicked_epoch);
                    end;
                end;
            end;
        end
        
        function obj = Padaco_button_down(obj)
            if(strcmpi(obj.marking_state,'off')) %don't want to reset the state if we are marking events
                if(~isempty(obj.current_linehandle))
                    obj.restore_state();
                end;
            else
                if(ishghandle(obj.hg_group))
                    if(~any(gco==allchild(obj.hg_group))) %did not click on a member of the object being drawn...
                        obj.clear_handles();
                    end;
                end;
            end;
            if(~isempty(obj.current_linehandle)&&ishandle(obj.current_linehandle) && strcmpi(get(obj.current_linehandle,'selected'),'on'))
                set(obj.current_linehandle,'selected','off');
            end
        end

        
        function setLinehandle(obj, line_h)
            obj.clear_handles();
            obj.current_linehandle = line_h;
            set(obj.current_linehandle,'selected','on');
        end
        

        function status = isActive(obj)
            status = ~strcmpi(obj.marking_state,'off');
        end
        
        function obj = set_channel_index(obj,channelIndex,channel_linehandle)
            %   previously implemented in Padaco's...          line_buttonDownFcn(hObject, eventdata)
            global EVENT_CONTAINER;
            global CHANNELS_CONTAINER;
            
            obj.clear_handles();
            obj.current_linehandle = channel_linehandle;
            obj.class_channel_index = channelIndex;
            obj.channel_label = CHANNELS_CONTAINER.getChannelName(obj.class_channel_index);
            obj.event_index = EVENT_CONTAINER.eventExists(obj.event_label,obj.class_channel_index);
            EVENT_CONTAINER.cur_event_index = obj.event_index;
            obj.start_stop_matrix_index = 0;
        end

        function indices = getSelectedIndices(obj)
            if(ishghandle(obj.hg_group))
                rectangle_h = findobj(obj.hg_group,'tag','rectangle');
                rec_pos = floor(get(rectangle_h,'position'));
                start = rec_pos(1);
                stop = start+rec_pos(3);
                indices = start:stop;
            else
                indices = [];
            end
        end
        function data = getSelectedChannelData(obj)
            %returns the plotted data for the channel selection made by the
            %user as highlighed with a rectangular patch
            global CHANNELS_CONTAINER;
            ROI = obj.getSelectedIndices();
            if(isempty(ROI))
                data = [];
            else
                data = CHANNELS_CONTAINER.getData(obj.class_channel_index,ROI);
            end
        end
        function [varargout] = copyChannelData2clipboard(obj)
            global CHANNELS_CONTAINER;
            if(ishghandle(obj.hg_group))
                rectangle_h = findobj(obj.hg_group,'tag','rectangle');
                rec_pos = floor(get(rectangle_h,'position'));
                start = rec_pos(1);
                stop = start+rec_pos(3);
                channel_index = obj.class_channel_index;
                ROI = start:stop;
                data = CHANNELS_CONTAINER.copy2clipboard(channel_index,ROI);
                if(nargout==1)
                    varargout{1}=data;
                end
            else
                varargout{1}=[];
            end;
        end
    

        function obj = startMarking(obj,editing_flag)
            %called when a user begins to mark a line...see line_buttonDownFcn for
            %calling function
            global EVENT_CONTAINER;
            global CHANNELS_CONTAINER;
            y = get( obj.current_linehandle,'ydata' );
            obj.class_channel_index = get(obj.current_linehandle,'userdata');
            obj.channel_label = CHANNELS_CONTAINER.getChannelName(obj.class_channel_index);
            
            min_y = max(min(y),obj.Padaco_mainaxes_ylim(1));
            max_y = min(max(y),obj.Padaco_mainaxes_ylim(2));
            h = max_y-min_y; %height
            y_mid = CHANNELS_CONTAINER.cell_of_channels{obj.class_channel_index}.line_offset; %min_y+h/2;
            
            obj.clear_handles();
            %editing an existing event
            if(obj.start_stop_matrix_index && obj.event_index) %index exists
                start_stop=EVENT_CONTAINER.cell_of_events{obj.event_index}.start_stop_matrix(obj.start_stop_matrix_index,:);
                x = start_stop(1);
                xdata = [start_stop;start_stop];
                w = diff(start_stop);
                num_events = size(EVENT_CONTAINER.cell_of_events{obj.event_index}.start_stop_matrix,1);
                dur_sec = w/obj.SETTINGS.VIEW.samplerate;
                %status Text...
                set(obj.texthandle.status,'string',sprintf('%s (%s)[%u of %u]: %0.2f s',obj.event_label,obj.channel_label,obj.start_stop_matrix_index,num_events,dur_sec));
            %editing a new event
            else
                mouse_pos = get(obj.axeshandle.main,'currentpoint');
                x = mouse_pos(1,1);
                w = 0.01;
                xdata = [x,x+w;x,x+w];
            end;
            
            ydata = [min_y, min_y;max_y, max_y];
            
            
            rect_pos = [x,min_y,w,h];
            obj.hg_group = hggroup('parent',obj.axeshandle.main,'hittest','off','handlevisibility','off');
            
            uicontextmenu_handle = uicontextmenu('parent',obj.figurehandle.Padaco,'callback',[]);%,get(parentAxes,'parent'));
            uimenu(uicontextmenu_handle,'Label','Plot data','separator','off','callback',@obj.plotSelection_callback);
            uimenu(uicontextmenu_handle,'Label','Copy to Clipboard','separator','off','callback',@obj.copy2clipboard_callback);
            uimenu(uicontextmenu_handle,'Label','Show PSD','separator','off','callback',@obj.plotPSDofSelection_callback);
            uimenu(uicontextmenu_handle,'Label','Show MUSIC','separator','off','callback',@obj.plotMUSICofSelection_callback);
            
            surface('parent',obj.hg_group,'xdata',xdata,'ydata',ydata,'zdata',zeros(2),...
                'cdata',1,'hittest','on','tag','surface','facealpha',0.5,'uicontextmenu',uicontextmenu_handle);
            rectangle('parent',obj.hg_group,'position',rect_pos,...
                'hittest','on','handlevisibility','on','tag','rectangle'); %turn this on so as not to be interrupted by other mouse clicks on top of this one..
            zdata = 1;
            markersize=3;
            obj.drag_left_h = line('marker','square','linewidth',markersize,'zdata',zdata,'xdata',x,'ydata',y_mid,'parent',obj.hg_group,...
                'handlevisibility','on','hittest','on','tag','left','selected','off',...
                'buttondownfcn',@obj.enableDrag_callback);
            obj.drag_right_h =line('marker','square','linewidth',markersize,'zdata',zdata,'xdata',x+w,'ydata',y_mid,'parent',obj.hg_group,...
                'handlevisibility','on','hittest','on','tag','right','selected','off',...
                'buttondownfcn',@obj.enableDrag_callback);
            
            set(obj.figurehandle.Padaco,'currentobject',obj.drag_right_h);
            
            if(nargin<2)
                editing_flag=false;
            end
            if(~editing_flag)
                obj.enableDrag_callback(obj.drag_right_h);
            else
                %let the person click on something and start moving at that time
            end
            %     set(hObject,'WindowButtonMotionFcn',@dragEdge);
            %     set(hObject,'WindowButtonUpFcn',@disableDrag)
        end
        
        function dragEdge_callback(obj,hObject,eventdata)
            
            mouse_pos = get(obj.axeshandle.main,'currentpoint');            
            cur_obj = gco;  %findobj(allchild(rectangle_h),'flat','selected','on');
            side = get(cur_obj,'tag');
            
            rectangle_h = findobj(obj.hg_group,'tag','rectangle');
            surf_h = findobj(obj.hg_group,'tag','surface');
            rec_pos = get(rectangle_h,'position');
            w=0;
            if(strcmp(side,'left'))
                w = rec_pos(1)-mouse_pos(1)+rec_pos(3);
                rec_pos(1) = mouse_pos(1);
                if(w<0)
                    w=-w;
                    rightObj = findobj(obj.hg_group,'tag','right');
                    rightObj = rightObj(1);
                    rec_pos(1)=get(rightObj,'xdata');
                    set(cur_obj,'tag','right');
                    set(rightObj,'tag','left');
                else
                    set(cur_obj,'xdata',mouse_pos(1));
                end;
            elseif(strcmp(side,'right'))
                w = mouse_pos(1)-rec_pos(1);
                if(w<0)
                    rec_pos(1)=mouse_pos(1);
                    w=-w;
                    leftObj = findobj(obj.hg_group,'tag','left');
                    leftObj = leftObj(1);
                    set(leftObj,'tag','right');
                    set(cur_obj,'tag','left');
                else
                    set(cur_obj,'xdata',mouse_pos(1));
                end;
                
            else
                disp 'oops.';
            end;
            
            if(w==0)
                w=0.001;
            end;
            
            rec_pos(3) = w;
            set(rectangle_h,'position',rec_pos);
            set(surf_h,'xdata',repmat([rec_pos(1),rec_pos(1)+rec_pos(3)],2,1),'ydata',repmat([rec_pos(2);rec_pos(2)+rec_pos(4)],1,2));
            
            dur_sec = w/obj.SETTINGS.VIEW.samplerate;
            %status Text...
            set(obj.texthandle.status,'string',sprintf('%s (%s): %0.2f s',obj.event_label,obj.channel_label,dur_sec));
        end
        
        function enableDrag_callback(obj,hObject,eventdata)
            %called as part of interactive marking of the graph to annotate events
            %this is called when the user presses the left mouse button over a channel
%             obj.class_channel_index
            set(hObject,'selected','on');
            
            set(obj.figurehandle.Padaco,'WindowButtonMotionFcn',@obj.dragEdge_callback);
            set(obj.figurehandle.Padaco,'WindowButtonUpFcn',@obj.disableDrag_callback)            
        end
        
        function disableDrag_callback(obj,hObject,eventdata)
            %called as part of interactive marking of the graph to annotate events
            %this is called when the user releases the mouse button            
            global EVENT_CONTAINER;
            global CHANNELS_CONTAINER;
            
           
            
            cur_obj = gco; %findobj(allchild(rectangle_h),'flat','selected','on');
            
            if(ishandle(cur_obj))
                set(cur_obj,'selected','off');
                %         set(fig,'currentobject',rectangle_h); %this disables the current object...
            end;
            
            set(obj.figurehandle.Padaco,'WindowButtonUpFcn',@obj.Padaco_main_fig_WindowButtonUpFcn); %let the user move across again...            
            set(obj.figurehandle.Padaco,'WindowButtonMotionFcn','');
            
            rectangle_h = findobj(obj.hg_group,'tag','rectangle');
            if(~isempty(rectangle_h))
                rec_pos = floor(get(rectangle_h,'position'));
                
                start = rec_pos(1);
                stop = start+rec_pos(3);
                event_data = [start,stop];
                
                %use this to avoid adding events by mistake (which are too small)
                if(strcmpi(obj.marking_state,'marking'))
                    if(abs(diff(event_data))>.1*CHANNELS_CONTAINER.getSamplerate(obj.class_channel_index))  %WORKSPACE.samplerate?
                        
                        sourceStruct.algorithm = 'Manually_Entered';
                        sourceStruct.channel_indices = [];
                        sourceStruct.editor = 'none';
                        
                        
                        [obj.event_index,obj.start_stop_matrix_index] = EVENT_CONTAINER.updateSingleEvent(event_data,...
                            obj.class_channel_index,obj.event_label,...
                            obj.event_index,obj.start_stop_matrix_index,sourceStruct);
                        channel_obj = CHANNELS_CONTAINER.getChannel(obj.class_channel_index);
                        EVENT_CONTAINER.updateYOffset(obj.event_index,channel_obj.line_offset);
                        obj.refreshAxes();
                        
                    end;
                end
            end
        end
        
        %
        %Contextmenu functions for draggable selection
        %
        
        function varargout = copy2clipboard_callback(obj,varargin)
            %copy selected vector data to the clipboard, for access by pressing
            %control-V (paste) or str=clipboard('paste');
            % global CHANNELS_CONTAINER;
            
            data = obj.copyChannelData2clipboard();
            if(nargout==1)
                varargout{1}=data;
            else
                varargout{1}=[];
            end
        end
        
        function plotMUSICofSelection_callback(obj,varargin)
            global CHANNELS_CONTAINER;

            f=figure;
            a = axes('parent',f);
            roi = obj.getSelectedIndices();
            
            if(~isempty(roi))
                CHANNELS_CONTAINER.showMUSIC(obj.SETTINGS.MUSIC,a,obj.class_channel_index,roi);
%                 try
%                     waitforbuttonpress();
%                 catch ME
%                     showME(ME);
%                 end;
%                 if(ishandle(f))
%                     close(f);
%                 end
            end            
        end
        
        function plotPSDofSelection_callback(obj,varargin)
            global CHANNELS_CONTAINER;            
            f = figure;
            a = axes('parent',f);
            roi = obj.getSelectedIndices();
            
            if(~isempty(roi))
                CHANNELS_CONTAINER.showPSD(obj.SETTINGS.PSD,a,obj.class_channel_index,roi);
%                 try
%                     waitforbuttonpress();
%                 catch ME
%                     showME(ME);
%                 end;
%                 if(ishandle(f))
%                     close(f);
%                 end
            end
        end;
        

        function grid_handle = draw_x_minorgrid(obj)
            %plots minor grid lines using specified properties
            %y_lines is a vector containing sample points where y-grid lines should be
            %drawn
            %parent_axes is the handle to the axes that the grids will be drawn to
            %grid_handle is a graphics handle to the line
            parent_axes = obj.axeshandle.main;
            spacing_sec = 1.0;
            y_lines = obj.Padaco_mainaxes_xlim(1):spacing_sec*obj.SETTINGS.VIEW.samplerate:obj.Padaco_mainaxes_xlim(2);

            
            y_lim = get(parent_axes,'ylim');
            y_data = repmat([y_lim(:); nan],1,numel(y_lines));
            x_data = repmat(y_lines(:)',3,1);
            % z_data = x_data*0-1;
            
            np = get(parent_axes,'nextplot') ;
            set(parent_axes,'nextplot','add') ;
            
            % gh = line('parent',parent_axes);
            if(~isfield(obj.linehandle,'x_minorgrid')||isempty(obj.linehandle.x_minorgrid)||~ishandle(obj.linehandle.x_minorgrid))
                obj.linehandle.x_minorgrid = line(x_data(:),y_data(:),'parent',parent_axes,'color',[0.8 0.8 0.8],'linewidth',0.5,'linestyle',':','hittest','off');
            else
                set(obj.linehandle.x_minorgrid,'xdata',x_data(:),'ydata',y_data(:));
            end
            gh = obj.linehandle.x_minorgrid;
            
            uistack(gh,'bottom'); %move it below everything else
            
            set(parent_axes,'nextplot',np,'Layer','top') ;    % reset the nextplot state
            
            if(nargout==1)
                grid_handle = gh;
            end;
        end
        
   
    end
end

