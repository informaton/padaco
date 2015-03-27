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

% Last Modified by GUIDE v2.5 26-Mar-2015 18:08:54

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
end

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
end

% --- Outputs from this function are returned to the command line.
function varargout = statTool_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

signalTypes = {'x','y','z','vecMag'};
normalizationTypes = {'values','normalizedValues'};
processedTypes = {'raw','count'};    

signalDescriptions = {'X','Y','Z','Vector Magnitude'};
signalSelection = 4;
set(handles.menu_signalsource,'string',signalDescriptions,'userdata',signalTypes,'value',signalSelection);

featureDescriptions = {'Mean','Mode','RMS','Std Dev','Sum','Variance'};
baseFeatureTypes = {'mean','mode','rms','std','sum','var'};
baseFeatureSelection = 5;
set(handles.menu_feature,'string',featureDescriptions,'userdata',baseFeatureTypes,'value',baseFeatureSelection);

processedTypeSelection = 1;
handles.user.processType = processedTypes{processedTypeSelection};
handles.user.inputPathname = '/Volumes/SeaG 1TB/sampleData/output/features/';
handles.user.inputFilePattern = '%s/%s/features.%s.accel.%s.%s.txt';
handles.user.inputFileFielnames = {'inputPathname','displaySeletion','processType','curSignal'};
handles.user.baseFeature = baseFeatureTypes{baseFeatureSelection};
handles.user.processType = processedTypes{2};
handles.user.curSignal = signalTypes{signalSelection};

normalizationSelection = 2;
handles.user.normalizationType = normalizationTypes{normalizationSelection};

handles.user.daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
handles.user.daysofweekOrder = 1:7;

guidata(hObject,handles);

menu_plottype_Callback(handles.menu_plottype,[],handles)

end

% Refresh the user settings from current GUI configuration.
function userSettings = refreshUserSettings(hObject)
    handles = guidata(hObject);
    userSettings = handles.user;
end
function menu_plottype_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

end

function check_normalizevalues_Callback(hObject, eventdata, handles)
end

function menu_feature_Callback(hObject, eventdata, handles)
end

function menu_feature_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end

function menu_signalsource_Callback(hObject, eventdata, handles)

end
function menu_signalsource_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function menu_plottype_Callback(hObject, eventdata, handles)
    
    userData = get(hObject,'userdata');
    displaySelection = userData{get(hObject,'value')};
    
    u = handles.user;
    inputFilename = sprintf(u.inputFilePattern,u.inputPathname,u.baseFeature,u.baseFeature,u.processType,u.curSignal);
    featureStruct = loadAlignedFeatures(inputFilename);
    loadFeatures = featureStruct.(u.normalizationType);

    if(u.trimResults)
        trimInd = loadFeatures < prctile(loadFeatures,99);
        features = loadFeatures(trimInd);
        daysofweek = u.daysofweek(trimInd);
    else
        features =  loadFeatures;
    end
    featureStruct.features = features;
    featureStruct.ylabelstr = sprintf('%s of %s %s activity',u.baseFeature,u.processType,u.curSignal);
    featureStruct.xlabelstr = 'Days of Week';
    plotSelection(handles.axes1,featureStruct,displaySelection,featureStruct.startDaysOfWeek);
    
end

function plotSelection(axesHandle,featureStruct,displaySelection)

daysofweek = featureStruct.startDaysOfWeek;
daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
daysofweekOrder = 1:7;
features = featureStruct.features;
divisionsPerDay = size(features,2);

    switch(displaySelection)
        case 'dailyaverage'
            imageMap = nan(7,1);
            for dayofweek=0:6
                dayofweekIndex = daysofweekOrder(dayofweek+1);
                numSubjects = sum(dayofweek==daysofweek);
                if(numSubjects==0)
                    imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1));
                else
                    imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1))/numSubjects;                 
                end
                daysofweekStr{dayofweekIndex} = sprintf('%s\n(n=%u)',daysofweekStr{dayofweekIndex},numSubjects);
                    
            end
            bar(axesHandle,imageMap);
            title('Average Daily Tallies');
            weekdayticks = linspace(1,7,7);

        case 'dailytally'
            imageMap = nan(7,1);
            for dayofweek=0:6
               imageMap(dayofweek+1) = sum(sum(features(dayofweek==daysofweek,:),1));               
            end
            bar(imageMap);
            title('Total Daily Tallies');
            weekdayticks = linspace(1,7,7);

        case 'morningheatmap'  %note: I use 24 to represent the first 6 hours of the morning (24 x 15 minute blocks = 6 hours)
            imageMap = nan(7,24);
            for dayofweek=0:6                
                imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,1:24),1);
                numSubjects = sum(dayofweek==daysofweek);
                if(numSubjects~=0)
                    imageMap(dayofweek+1,:) = imageMap(dayofweek+1,:)/numSubjects;
                end
            end
            
            imageMap=imageMap/max(imageMap(:));
            imageMap = round(imageMap*numShades);
            imagesc(imageMap');
            weekdayticks = 1:1:7; %linspace(0,6,7);
            dailyDivisionTicks = 1:2:24;
            set(axesHandle,'ytick',dailyDivisionTicks,'yticklabel',featureStruct.startTimes(1:2:24));
            title('Heat map');        
        case 'heatmap'
            imageMap = nan(7,size(features,2));
            for dayofweek=0:6                
                imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,:),1);
                numSubjects = sum(dayofweek==daysofweek);
                if(numSubjects~=0)
                    imageMap(dayofweek+1,:) = imageMap(dayofweek+1,:)/numSubjects;
                end
            end
            
            imageMap=imageMap/max(imageMap(:));
            imageMap = round(imageMap*numShades);
            imagesc(imageMap');
            weekdayticks = 1:1:7; %linspace(0,6,7);
            dailyDivisionTicks = 1:8:featureStruct.totalCount;
            set(axesHandle,'ytick',dailyDivisionTicks,'yticklabel',featureStruct.startTimes(1:8:end));
            title('Heat map');
        case 'rolling'
            imageMap = nan(7,size(features,2));
            for dayofweek=0:6
               imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,:),1);
            end
%            imageMap=imageMap/max(imageMap(:));
            rollingMap = imageMap';            
            plot(rollingMap(:));
            title('Rolling Map');
            weekdayticks = linspace(0,divisionsPerDay*6,7);
            set(axesHandle,'ygrid','on');
        case 'morningrolling'
            imageMap = nan(7,24);
            for dayofweek=0:6
               imageMap(dayofweek+1,:) = sum(features(dayofweek==daysofweek,1:24),1);
            end
%            imageMap=imageMap/max(imageMap(:));
            rollingMap = imageMap';            
            plot(rollingMap(:));
            title('Morning Rolling Map (00:00-06:00AM daily)');
            weekdayticks = linspace(0,24*6,7);
            set(axesHandle,'ygrid','on');
            
        case 'quantile'
            
        otherwise
            disp Oops!;
    end

    set(axesHandle,'xtick',weekdayticks,'xticklabel',daysofweekStr,'xgrid','on');
    
end