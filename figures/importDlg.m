function varargout = importDlg(varargin)
% IMPORTDLG MATLAB code for importDlg.fig
%      IMPORTDLG, by itself, creates a new IMPORTDLG or raises the existing
%      singleton*.
%
%      H = IMPORTDLG returns the handle to a new IMPORTDLG or the handle to
%      the existing singleton*.
%
%      IMPORTDLG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in IMPORTDLG.M with the given input arguments.
%
%      IMPORTDLG('Property','Value',...) creates a new IMPORTDLG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before importDlg_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to importDlg_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help importDlg

% Last Modified by GUIDE v2.5 10-Aug-2018 06:53:04

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @importDlg_OpeningFcn, ...
                   'gui_OutputFcn',  @importDlg_OutputFcn, ...
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


% --- Executes just before importDlg is made visible.
function importDlg_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to importDlg (see VARARGIN)

% Choose default command line output for importDlg
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes importDlg wait for user response (see UIRESUME)
% uiwait(handles.figure_importDlg);


% --- Outputs from this function are returned to the command line.
function varargout = importDlg_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in menu_fieldSeparator.
function menu_fieldSeparator_Callback(hObject, eventdata, handles)
% hObject    handle to menu_fieldSeparator (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns menu_fieldSeparator contents as cell array
%        contents{get(hObject,'Value')} returns selected item from menu_fieldSeparator


% --- Executes during object creation, after setting all properties.
function menu_fieldSeparator_CreateFcn(hObject, eventdata, handles)
% hObject    handle to menu_fieldSeparator (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function edit_numHeaderLines_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_numHeaderLines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function text_fileContents_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text_fileContents (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in push_fileSelect.
function push_fileSelect_Callback(hObject, eventdata, handles)
% hObject    handle to push_fileSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
