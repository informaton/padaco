function varargout = batchTool(varargin)
% BATCHTOOL MATLAB code for batchTool.fig
%      BATCHTOOL, by itself, creates a new BATCHTOOL or raises the existing
%      singleton*.
%
%      H = BATCHTOOL returns the handle to a new BATCHTOOL or the handle to
%      the existing singleton*.
%
%      BATCHTOOL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in BATCHTOOL.M with the given input arguments.
%
%      BATCHTOOL('Property','Value',...) creates a new BATCHTOOL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before batchTool_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to batchTool_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help batchTool

% Last Modified by GUIDE v2.5 10-Oct-2014 11:30:28

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @batchTool_OpeningFcn, ...
                   'gui_OutputFcn',  @batchTool_OutputFcn, ...
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


% --- Executes just before batchTool is made visible.
function batchTool_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to batchTool (see VARARGIN)

% Choose default command line output for batchTool
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes batchTool wait for user response (see UIRESUME)
% uiwait(handles.figure_batch);


% --- Outputs from this function are returned to the command line.
function varargout = batchTool_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
