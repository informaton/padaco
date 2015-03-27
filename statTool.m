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



handles.user.trimResults = false;
handles.user.signalTypes = {'x','y','z','vecMag'};
handles.user.processedTypes = {'count','raw'};    

handles.user.normalizationTypes = {'values','normalizedValues'};
normalizationSelection = 1;
set(handles.check_normalizevalues,'min',1,'max',2,'value',normalizationSelection);

handles.user.signalDescriptions = {'X','Y','Z','Vector Magnitude'};
signalSelection = 4;
set(handles.menu_signalsource,'string',handles.user.signalDescriptions,'userdata',handles.user.signalTypes,'value',signalSelection);
handles.user.plotTypes = {'dailyaverage','dailytally','morningheatmap','heatmap','rolling','morningrolling'};
handles.user.plotTypeDescriptions = {'Average Daily Tallies','Total Daily Tallies','Heat map (early morning)','Heat map','Time series','Time series (morning)'};
plotTypeSelection = 1;
set(handles.menu_plottype,'userdata',handles.user.plotTypes,'string',handles.user.plotTypeDescriptions,'value',plotTypeSelection);

handles.user.featureDescriptions = {'Mean','Mode','RMS','Std Dev','Sum','Variance'};
handles.user.baseFeatureTypes = {'mean','mode','rms','std','sum','var'};
baseFeatureSelection = 5;
set(handles.menu_feature,'string',handles.user.featureDescriptions,'userdata',handles.user.baseFeatureTypes,'value',baseFeatureSelection);

processedTypeSelection = 1;
handles.user.inputPathname = '/Volumes/SeaG 1TB/sampleData/output/features';
handles.user.inputFilePattern = ['%s',filesep,'%s',filesep,'features.%s.accel.%s.%s.txt']; 
handles.user.inputFileFielndames = {'inputPathname','displaySeletion','processType','curSignal'};

% handles.user.plotType = handles.user.plotTypes{plotTypeSelection};
% handles.user.processType = handles.user.processedTypes{processedTypeSelection};
% handles.user.baseFeature = handles.user.baseFeatureTypes{baseFeatureSelection};
% handles.user.processType = handles.user.processedTypes{2};
% handles.user.curSignal = handles.user.signalTypes{signalSelection};
% handles.user.normalizationType = handles.user.normalizationTypes{normalizationSelection};


handles.user.daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
handles.user.daysofweekOrder = 1:7;

set([handles.check_normalizevalues,handles.menu_feature,handles.menu_signalsource,handles.menu_plottype],'callback',@refreshPlot);


guidata(hObject,handles);


refreshPlot(hObject);
end

function refreshPlot(hObject,~)
    handles = guidata(hObject);
    pSettings = getPlotSettings(handles);

    inputFilename = sprintf(handles.user.inputFilePattern,pSettings.inputPathname,pSettings.baseFeature,pSettings.baseFeature,pSettings.processType,pSettings.curSignal);
    if(exist(inputFilename,'file'))
        featureStruct = loadAlignedFeatures(inputFilename);
        loadFeatures = featureStruct.(pSettings.normalizationType);
        
        if(pSettings.trimResults)
            trimInd = loadFeatures < prctile(loadFeatures,99);
            features = loadFeatures(trimInd);
            daysofweek = pSettings.daysofweek(trimInd);
        else
            features =  loadFeatures;
        end
        featureStruct.features = features;
        pSettings.ylabelstr = sprintf('%s of %s %s activity',pSettings.baseFeature,pSettings.processType,pSettings.curSignal);
        pSettings.xlabelstr = 'Days of Week';
        
        plotSelection(handles.axes1,featureStruct,pSettings);
    else
       warndlg(sprintf('Could not find %s',inputFilename)); 
    end
end

% Refresh the user settings from current GUI configuration.
function userSettings = getPlotSettings(handles)

processedTypeSelection = 1;
baseFeatureSelection = get(handles.menu_feature,'value');
signalSelection = get(handles.menu_signalsource,'value');
normalizationSelection = get(handles.check_normalizevalues,'value');

plotTypeSelection = get(handles.menu_plottype,'value');

userSettings.inputPathname = handles.user.inputPathname;
userSettings.trimResults = false;
userSettings.processType = handles.user.processedTypes{processedTypeSelection};
userSettings.baseFeature = handles.user.baseFeatureTypes{baseFeatureSelection};
userSettings.curSignal = handles.user.signalTypes{signalSelection};
userSettings.normalizationType = handles.user.normalizationTypes{normalizationSelection};    
userSettings.plotType = handles.user.plotTypes{plotTypeSelection};

userSettings.numShades = 1000;

end


function menu_plottype_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

end


function menu_feature_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end


function menu_signalsource_CreateFcn(hObject, eventdata, handles)

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end




function plotSelection(axesHandle,featureStruct,plotOptions)

daysofweek = featureStruct.startDaysOfWeek;
daysofweekStr = {'Sun','Mon','Tue','Wed','Thur','Fri','Sat'};
daysofweekOrder = 1:7;
features = featureStruct.features;
divisionsPerDay = size(features,2);


    switch(plotOptions.plotType)
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
            imageMap = round(imageMap*plotOptions.numShades);
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
            imageMap = round(imageMap*plotOptions.numShades);
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