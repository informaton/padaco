function varargout = analysisFig(varargin)
% ANALYSISFIG MATLAB code for analysisFig.fig
%      ANALYSISFIG, by itself, creates a new ANALYSISFIG or raises the existing
%      singleton*.
%
%      H = ANALYSISFIG returns the handle to a new ANALYSISFIG or the handle to
%      the existing singleton*.
%
%      ANALYSISFIG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in ANALYSISFIG.M with the given input arguments.
%
%      ANALYSISFIG('Property','Value',...) creates a new ANALYSISFIG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before analysisFig_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to analysisFig_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help analysisFig

% Last Modified by GUIDE v2.5 23-Dec-2018 11:31:54

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @analysisFig_OpeningFcn, ...
                   'gui_OutputFcn',  @analysisFig_OutputFcn, ...
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


% --- Executes just before analysisFig is made visible.
function analysisFig_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to analysisFig (see VARARGIN)

% Choose default command line output for analysisFig
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes analysisFig wait for user response (see UIRESUME)
% uiwait(handles.analysisFig);


% --- Outputs from this function are returned to the command line.
function varargout = analysisFig_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


function menu_ySelection_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
