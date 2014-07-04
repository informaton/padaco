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
            
            obj.setCurEpoch(1);
%             lineHandles = obj.VIEW.getLinehandle();
%             
%             obj.setLineScale(lineHandles);
%             obj.setLineColor(lineHandles);
%             obj.setLineOffset(lineHandles);
            
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
            obj.setCurEpoch(epoch);
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
        function success = setCurEpoch(obj,new_epoch)
            success= false;
            if(~isempty(obj.accelObj))                
                cur_epoch = obj.accelObj.setCurEpoch(new_epoch);
                obj.VIEW.setCurEpoch(num2str(cur_epoch));
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
        

        
   
    end
end

