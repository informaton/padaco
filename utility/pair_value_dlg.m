function varargout = pair_value_dlg(varargin)
    % PAIR_VALUE_DLG M-file for pair_value_dlg.fig
    %      PAIR_VALUE_DLG, by itself, creates a new PAIR_VALUE_DLG or raises the existing
    %      singleton*.
    %
    %      H = PAIR_VALUE_DLG returns the handle to a new PAIR_VALUE_DLG or the handle to
    %      the existing singleton*.
    %
    %      PAIR_VALUE_DLG('CALLBACK',hObject,eventData,handles,...) calls the local
    %      function named CALLBACK in PAIR_VALUE_DLG.M with the given input arguments.
    %
    %      PAIR_VALUE_DLG('Property','Value',...) creates a new PAIR_VALUE_DLG or raises the
    %      existing singleton*.  Starting from the left, property value pairs are
    %      applied to the GUI before pair_value_dlg_OpeningFcn gets called.  An
    %      unrecognized property name or invalid value makes property application
    %      stop.  All inputs are passed to pair_value_dlg_OpeningFcn via varargin.
    %
    %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
    %      instance to run (singleton)".
    %
    % See also: GUIDE, GUIDATA, GUIHANDLES
    
    % Edit the above text to modify the response to help pair_value_dlg
    
    % Last Modified by GUIDE v2.5 08-Mar-2016 12:31:25
    
    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
        'gui_Singleton',  gui_Singleton, ...
        'gui_OpeningFcn', @pair_value_dlg_OpeningFcn, ...
        'gui_OutputFcn',  @pair_value_dlg_OutputFcn, ...
        'gui_LayoutFcn',  [] , ...
        'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end
    
    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT
    
    
    % --- Executes just before pair_value_dlg is made visible.
function pair_value_dlg_OpeningFcn(hObject, eventdata, handles, varargin)
    % This function has no output args, see OutputFcn.
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    % varargin   command line arguments to pair_value_dlg (see VARARGIN)
    
    %these are unique to this figure (.fig) and must be udpated to reflect
    %changes in the .fig file.
    handles.user.static_prefix = 'text_key_';
    handles.user.edit_prefix = 'edit_value_';
    handles.user.maxNumRecordsShown = 10;
    
    %varargin{1} is an object of CLASS_settings
    if(numel(varargin)>0)
        handles.user.settings_obj = varargin{1};
        guidata(hObject,handles);
        %in the case that there is only one structure being presented.
        %     if(~isfield(handles.user.settings_obj,'fieldNames'))
        %         handles.user.settings_obj.fieldNames = 'Settings';
        %     end
        %
        
        %make the view
        handles = initializeView(handles);
        guidata(hObject,handles);
        %initialize the panel
        eventdata = struct('EventName','SelectionChanged',...
            'OldValue',0,...
            'NewValue', 1);
        tabgroup_callback(handles.tabgroup,eventdata);
        
    end
    
    % Choose default command line output for pair_value_dlg
    handles.output = [];
    
    % Update handles structure
    guidata(hObject, handles);
    
    % UIWAIT makes pair_value_dlg wait for user response (see UIRESUME)
    uiwait(handles.figure1);
    
    % --- Initializes the display; creates the text and edit uicontrols.
function handles = initializeView(handles)
    
    
    %make the tab groups...
    tabgroup = uitabgroup('parent',handles.panel_tabs);
    % set(handles.tabgroup,'callback',{@tabgroup_callback,guidata(gcbo)});
    
    numTabs = numel(handles.user.settings_obj.fieldNames);
    tabs = zeros(numTabs,1);
    
    numRecords = 0;
    for f=1:numTabs %fieldNames; %The field names of the parameters to be shown to the user (i.e. VIEW, BATCH_PROCESS, PSD,....)
        fname = handles.user.settings_obj.fieldNames{f}; %current field/tab name
        
        if(verLessThan('matlab','7.14'))
            tabs(f) = uitab('v0','parent',tabgroup,'Title',fname);
        else
            tabs(f) = uitab('parent',tabgroup,'Title',fname);
        end
        
        if(f==1)            
            numRecords = numel(fieldnames(handles.user.settings_obj.(fname)));
        end
%         records = numel(fieldnames(handles.user.settings_obj.(fname)));
%         if(records>maxRecords)
%             maxRecords = records;
%         end
    end
    
    
    % User maxRecords on the first iteration through
    handles = resizePanelWithScrollbarOption(handles.panel_main,handles.slider_verticalScroll, numRecords,handles.user.maxNumRecordsShown,handles);
    
    
    handles.tabgroup = tabgroup;
    handles.tabs = tabs;

    
    if(verLessThan('matlab','7.14'))
        set(handles.tabgroup,'SelectionChangeFcn',@tabgroup_callback);
    else
        set(handles.tabgroup,'SelectionChangedFcn',@tabgroup_callback);
    end
    
function handles = getCurrentSettings(handles,tabName)
    %grab the current settings panel values and return in the handles structure
    
    fnames = fieldnames(handles.user.settings_obj.(tabName));
    
    for f = 1:numel(fnames)
        value_tag = sprintf('%s%u',handles.user.edit_prefix,f);
        value_Str = get(handles.(value_tag),'string');
        if(isnan(str2double(value_Str)))
            handles.user.settings_obj.(tabName).(fnames{f})=value_Str;
        else
            handles.user.settings_obj.(tabName).(fnames{f})=str2double(value_Str);
        end
    end
    
function tabgroup_callback(hObject,eventdata)
    %
    % eventdata =
    %
    %     EventName: 'SelectionChanged'
    %      OldValue: 0
    %      NewValue: 1
    
    handles = guidata(hObject);
    h=get(handles.figure1,'currentobject');
    % get(h,'string')
    if(ishandle(h))
        if(strcmpi(get(h,'type'),'uicontrol')&& strcmpi(get(h,'style'),'edit'))
            try
                refresh(handles.figure1);
                getframe(handles.figure1);
                get(h,'string')
            catch me
                showME(me);
            end
            
        end
    end
    
    if(eventdata.OldValue == 0)
        tabName = get(handles.tabs(eventdata.NewValue),'Title');
        fnames = fieldnames(handles.user.settings_obj.(tabName));
        
    else
        if(verLessThan('matlab','7.14'))
            tabName = get(handles.tabs(eventdata.NewValue),'Title');
        else
            tabName = eventdata.NewValue.Title;
        end
        fnames = fieldnames(handles.user.settings_obj.(tabName));
        
        %i.e. don't do this on the first pass through, when called from the
        %initialization function
        if(verLessThan('matlab','7.14'))
            oldTabName = get(handles.tabs(eventdata.OldValue),'Title');
        else
            oldTabName = eventdata.OldValue.Title;
        end
        handles = getCurrentSettings(handles,oldTabName);
        numRecords = numel(fnames);
        handles = resizePanelWithScrollbarOption(handles.panel_main,handles.slider_verticalScroll, numRecords,handles.user.maxNumRecordsShown,handles);

    end
    
    %want to return the new handles that I have here...
    % handles = resizePanelAndFigureForUIControls(handles.panel_main,maxRecords,handles);
    
    try
        
        for f = 1:numel(fnames)
            text_tag = sprintf('%s%u',handles.user.static_prefix,f);
            value_tag = sprintf('%s%u',handles.user.edit_prefix,f);
            set(handles.(text_tag),'string',fnames{f});
            set(handles.(value_tag),'string',handles.user.settings_obj.(tabName).(fnames{f}));
        end
        
    catch me
        showME(me);
    end
    guidata(hObject,handles);
    
    
    % --- Outputs from this function are returned to the command line.
function varargout = pair_value_dlg_OutputFcn(hObject, eventdata, handles)
    % varargout  cell array for returning output args (see VARARGOUT);
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    
    % Get default command line output from handles structure
    varargout{1} = handles.output;
    delete(hObject);
    
    
    % --- Executes on button press in push_defaults.
function push_defaults_Callback(hObject, eventdata, handles)
    % hObject    handle to push_defaults (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    if(verLessThan('matlab','7.14'))
        tab_index =  get(handles.tabgroup,'selectedindex');
        tabName = get(handles.tabs(tab_index),'Title');
    else
        tabName = handles.tabgroup.SelectedTab.Title;
        tab_index = find(handles.tabgroup.Children==handles.tabgroup.SelectedTab,1);
    end
    
    handles.user.settings_obj.setDefaults(tabName);
    
    eventdata = struct('EventName','SelectionChanged',...
        'OldValue',0,... %leave 0, so the callback does not try to resize
        'NewValue', tab_index);
    
    %refresh view
    tabgroup_callback(handles.tabgroup,eventdata);
    guidata(hObject,handles);
    
    % --- Executes on button press in push_ok_close.
function push_ok_close_Callback(hObject, eventdata, handles)
    % hObject    handle to push_ok_close (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    
    if(verLessThan('matlab','7.14'))
        tab_index =  get(handles.tabgroup,'selectedindex');
        tabName = get(handles.tabs(tab_index),'Title');
    else
        tabName = handles.tabgroup.SelectedTab.Title;
    end
    
    handles = getCurrentSettings(handles,tabName);
    handles.output = handles.user.settings_obj;
    guidata(hObject,handles);
    uiresume(handles.figure1);
    
    % --- Executes on button press in push_cancel.
function push_cancel_Callback(hObject, eventdata, handles)
    % hObject    handle to push_cancel (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    handles.output = [];
    guidata(hObject,handles);
    uiresume(handles.figure1);
    
    
    % --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
    % hObject    handle to figure1 (see GCBO)
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    
    % Hint: delete(hObject) closes the figure
    handles.output = [];
    guidata(hObject,handles);
    uiresume(handles.figure1);
    
    
function slider_verticalScroll_Callback(hObject, eventdata, handles)
    
    
function slider_verticalScroll_CreateFcn(hObject, eventdata, handles)
    
    % Hint: slider controls usually have a light gray background.
    if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor',[.9 .9 .9]);
    end
