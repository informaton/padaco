function varargout = raw2bin_dlg(varargin)
% RAW2BIN_DLG MATLAB code for raw2bin_dlg.fig
%      RAW2BIN_DLG, by itself, creates a new RAW2BIN_DLG or raises the existing
%      singleton*.
%
%      H = RAW2BIN_DLG returns the handle to a new RAW2BIN_DLG or the handle to
%      the existing singleton*.
%
%      RAW2BIN_DLG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RAW2BIN_DLG.M with the given input arguments.
%
%      RAW2BIN_DLG('Property','Value',...) creates a new RAW2BIN_DLG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before raw2bin_dlg_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to raw2bin_dlg_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help raw2bin_dlg

% Last Modified by GUIDE v2.5 05-Jan-2017 15:41:08

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @raw2bin_dlg_OpeningFcn, ...
                   'gui_OutputFcn',  @raw2bin_dlg_OutputFcn, ...
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


% --- Executes just before raw2bin_dlg is made visible.
function raw2bin_dlg_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to raw2bin_dlg (see VARARGIN)

% Choose default command line output for raw2bin_dlg
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes raw2bin_dlg wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = raw2bin_dlg_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


function pushbutton1_Callback(hObject, eventdata, handles)


function edit1_Callback(hObject, eventdata, handles)


function edit1_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function pushbutton2_Callback(hObject, eventdata, handles)


function edit2_Callback(hObject, eventdata, handles)


function edit2_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function pushbutton3_Callback(hObject, eventdata, handles)


function checkbox1_Callback(hObject, eventdata, handles)
