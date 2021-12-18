function varargout = padacoFig(varargin)
% Files brought in:
%     showME(ME);
%     killall;
    
% PADACOFIG MATLAB code for padacoFig.fig
%      PADACOFIG, by itself, creates a new PADACOFIG or raises the existing
%      singleton*.
%
%      H = PADACOFIG returns the handle to a new PADACOFIG or the handle to
%      the existing singleton*.
%
%      PADACOFIG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PADACOFIG.M with the given input arguments.
%
%      PADACOFIG('Property','Value',...) creates a new PADACOFIG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before padacoFig_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to padacoFig_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help padacoFig

% Last Modified by GUIDE v2.5 16-Dec-2021 14:16:54

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @padacoFig_OpeningFcn, ...
                   'gui_OutputFcn',  @padacoFig_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...@padaco_LayoutFcn , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State,varargin{:});
end
% End initialization code - DO NOT EDIT


% function h = padaco_LayoutFcn(varargin)
%     h = openfig('padacoFig.fig',varargin{:},'invisible');
    

% --- Executes just before padacoFig is made visible.
function padacoFig_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to padacoFig (see VARARGIN)

% Choose default command line output for padacoFig

handles.output = hObject;

% Update handles structure
guidata(hObject, handles);


% --------------------------------------------------------------------
% --- Outputs from this function are returned to the command line.
function varargout = padacoFig_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if(ishandle(hObject))
    varargout{1} = handles.output;
else
    varargout{1} = [];
end
