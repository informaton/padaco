function varargout = importOutcomesDlg(varargin)
% IMPORTOUTCOMESDLG MATLAB code for importOutcomesDlg.fig
%      IMPORTOUTCOMESDLG, by itself, creates a new IMPORTOUTCOMESDLG or raises the existing
%      singleton*.
%
%      H = IMPORTOUTCOMESDLG returns the handle to a new IMPORTOUTCOMESDLG or the handle to
%      the existing singleton*.
%
%      IMPORTOUTCOMESDLG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in IMPORTOUTCOMESDLG.M with the given input arguments.
%
%      IMPORTOUTCOMESDLG('Property','Value',...) creates a new IMPORTOUTCOMESDLG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before importOutcomesDlg_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to importOutcomesDlg_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help importOutcomesDlg

% Last Modified by GUIDE v2.5 22-Jan-2019 00:15:23

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @importOutcomesDlg_OpeningFcn, ...
                   'gui_OutputFcn',  @importOutcomesDlg_OutputFcn, ...
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


% --- Executes just before importOutcomesDlg is made visible.
function importOutcomesDlg_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to importOutcomesDlg (see VARARGIN)

% Choose default command line output for importOutcomesDlg
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes importOutcomesDlg wait for user response (see UIRESUME)
% uiwait(handles.importOutcomes);


% --- Outputs from this function are returned to the command line.
function varargout = importOutcomesDlg_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes during object creation, after setting all properties.
function edit_dictionaryFilename_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_dictionaryFilename (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
