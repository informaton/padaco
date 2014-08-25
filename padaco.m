function varargout = padaco(varargin)
% Files brought in:
%     showME(ME);
%     killall;
    
% PADACO MATLAB code for padaco.fig
%      PADACO, by itself, creates a new PADACO or raises the existing
%      singleton*.
%
%      H = PADACO returns the handle to a new PADACO or the handle to
%      the existing singleton*.
%
%      PADACO('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PADACO.M with the given input arguments.
%
%      PADACO('Property','Value',...) creates a new PADACO or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before padaco_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to padaco_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help padaco

% Last Modified by GUIDE v2.5 12-Aug-2014 18:39:55

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @padaco_OpeningFcn, ...
                   'gui_OutputFcn',  @padaco_OutputFcn, ...
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


% --- Executes just before padaco is made visible.
function padaco_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to padaco (see VARARGIN)

% Choose default command line output for padaco
handles.output = hObject;

initializeGUI(hObject);
% Update handles structure
guidata(hObject, handles);

mPathname = fileparts(mfilename('fullpath'));

guidata(hObject, handles);
try
    parametersFile = '_padaco.parameters.txt';
    handles.user.controller = PAController(hObject,mPathname,parametersFile); 
    guidata(hObject,handles);
catch me
    %     me.message
    %     me.stack(1)
    showME(me);
    fprintf(1,['The default settings file may be corrupted or inaccessible.',...
        '  This can occur when installing the software on a new computer or from editing the settings file externally.',...
        '\nChoose OK in the popup dialog to correct the settings file.\n']);
    %menu_help_defaults_Callback([],[],[]);   
end



function initializeGUI(hObject)

% set(hObject,'visible','on');
figColor = get(hObject,'color');

ch = findall(hObject,'type','uipanel');
set(ch,'backgroundcolor',figColor);

ch = findobj(hObject,'-regexp','tag','text.*');

ch(strcmp(get(ch,'type'),'uimenu'))=[];
set(ch,'backgroundcolor',figColor);

ch = findobj(hObject,'-regexp','tag','axes.*');
set(ch,'units','normalized');



% --------------------------------------------------------------------
% --- Outputs from this function are returned to the command line.
function varargout = padaco_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in button_go.
function button_go_Callback(hObject, eventdata, handles)
% hObject    handle to button_go (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
