function varargout = statTool(varargin)
% STATTOOL MATLAB code for statTool.fig
%      STATTOOL, by itself, creates a new STATTOOL or raises the existing
%      singleton*.
%
%      H = STATTOOL returns the handle to a new STATTOOL or the handle to
%      the existing singleton*.
%
%      STATTOOL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in STATTOOL.M with the given input arguments.
%
%      STATTOOL('Property','Value',...) creates a new STATTOOL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before statTool_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to statTool_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help statTool

% Last Modified by GUIDE v2.5 26-Mar-2015 14:12:51

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @statTool_OpeningFcn, ...
                   'gui_OutputFcn',  @statTool_OutputFcn, ...
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


% --- Executes just before statTool is made visible.
function statTool_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to statTool (see VARARGIN)

% Choose default command line output for statTool
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes statTool wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = statTool_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

signalTypes = {'x','y','z','vecMag'};
valueTypes = {'values','normalizedValues'};
processedTypes = {'raw','count'};    

signalDescriptions = {'X','Y','Z','Vector Magnitude'};
signalSelection = 4;
set(handles.menu_signalsource,'string',signalDescriptions,'userdata',signalTypes,'value',signalSelection);

featureDescriptions = {'Mean','Mode','RMS','Std Dev','Sum','Variance'};
baseFeatureTypes = {'mean','mode','rms','std','sum','var'};
baseFeatureSelection = 5;
set(handles.menu_feature,'string',featureDescriptions,'userdata',baseFeatureTypes,'value',baseFeatureSelection);

handles.user.baseFeature = baseFeatureTypes{baseFeatureSelection};
handles.user.processType = processedTypes{2};
handles.user.curSignal = signalTypes{signalSelection};


function menu_plottype_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function check_normalizevalues_Callback(hObject, eventdata, handles)


function menu_feature_Callback(hObject, eventdata, handles)


function menu_feature_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function menu_signalsource_Callback(hObject, eventdata, handles)


function menu_signalsource_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
