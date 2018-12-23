function varargout = clusterAnalysisFig(varargin)
% CLUSTERANALYSISFIG MATLAB code for clusterAnalysisFig.fig
%      CLUSTERANALYSISFIG, by itself, creates a new CLUSTERANALYSISFIG or raises the existing
%      singleton*.
%
%      H = CLUSTERANALYSISFIG returns the handle to a new CLUSTERANALYSISFIG or the handle to
%      the existing singleton*.
%
%      CLUSTERANALYSISFIG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CLUSTERANALYSISFIG.M with the given input arguments.
%
%      CLUSTERANALYSISFIG('Property','Value',...) creates a new CLUSTERANALYSISFIG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before clusterAnalysisFig_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to clusterAnalysisFig_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help clusterAnalysisFig

% Last Modified by GUIDE v2.5 23-Dec-2018 11:32:12

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @clusterAnalysisFig_OpeningFcn, ...
                   'gui_OutputFcn',  @clusterAnalysisFig_OutputFcn, ...
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


% --- Executes just before clusterAnalysisFig is made visible.
function clusterAnalysisFig_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to clusterAnalysisFig (see VARARGIN)

% Choose default command line output for clusterAnalysisFig
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes clusterAnalysisFig wait for user response (see UIRESUME)
% uiwait(handles.clusterAnalysisFig);


% --- Outputs from this function are returned to the command line.
function varargout = clusterAnalysisFig_OutputFcn(hObject, eventdata, handles) 
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
