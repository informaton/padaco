%> @file PASingleStudyController.cpp
%> @brief PASingleStudyController serves as Padaco's time series view controller
% ======================================================================
%> @brief PASingleStudyController serves as Padaco's time series view controller.
classdef PASingleStudyController < PAViewController
    properties(Constant)
        viewTag = 'timeSeries';
    end
    properties (SetAccess = protected)
        
        %> for the patch handles when editing and dragging
        hg_group;   %may be unused?
        
        %>cell of string choices for the marking state (off, 'marking','general')
        state_choices_cell;
        
        
        %> @brief struct of line handles with matching fieldnames of
        %> instance variable linehandle which are used to draw a dotted reference
        %> line corresponding to zero.
        referencelinehandle;
        
        %> @brief Graphic handle of the vertical bar which provides a
        %> visual reference of where the window is in comparison to the entire
        %> study.
        positionBarHandle;
         
        %> PASensorData instance
        accelObj;
        
        window_resolution;%struct of different time resolutions, field names correspond to the units of time represented in the field        
        num_windows;
        display_samples; %vector of the samples to be displayed
        shift_display_samples_delta; %number of samples to adjust display by for moving forward or back
        startDateTime;
        
        %> @brief Struct of line handle properties corresponding to the
        %> fields of linehandle.  These are derived from the input files
        %> loaded by the PASensorData class.
        %  lineproperty;

    end
    properties(Access=private)
       %> @brief The number of items to be displayed in the secondary
        %> axes.
        numViewsInSecondaryDisplay;
        %> @brief Identifies the acceleration type ('mims', 'raw' or 'count' [default])
        %> displayed in the primary and secondary axes.  This is controlled
        %> by the users signal selection via GUI dropdown menu.  See
        %> updateSecondaryFeaturesDisplayCallback
        accelTypeShown; 
        
        %> @brief Vector for keeping track of the feature handles that are
        %> displayed on the secondary axes field.
        featureHandles;
        
    end

    methods
        
        % --------------------------------------------------------------------
        %> PASingleStudyController class constructor.
        %> @param Padaco_fig_h Figure handle to assign PASingleStudyController instance to.
        %> @param lineContextmenuHandle Contextmenu handle to assign to
        %> VIEW's line handles
        %> @param primaryAxesContextmenuHandle Contextmenu to assign to
        %> VIEW's primary axes.
        %> @param featureLineContextmenuHandle Contextmenu to assign to
        %> VIEW's feature line handles.
        %> @retval obj Instance of PASingleStudyController
        % --------------------------------------------------------------------
        function obj = PASingleStudyController(varargin) %,lineContextmenuHandle,primaryAxesContextmenuHandle,featureLineContextmenuHandle,secondaryAxesContextmenuHandle)
            obj@PAViewController(varargin{:});
        end
        
        % --------------------------------------------------------------------
        function updateWidgets(obj, varargin)
            
            updateWidgets@PAViewController(obj, varargin{:});
            
            %set signal choice
            obj.setExtractorMethod(obj.getSetting('featureFcnName'));
            obj.setDisplayType(obj.getSetting('displayType'));

            if(isempty(obj.accelObj))
                % obj.setRadioButton(obj.getSetting('displayType'));            
            else
                % This only works if we have an initialized timeseries dataset.
                obj.setSignalSelection(obj.getSetting('signalTagLine')); %internally sets to 1st in list if not found..
                
                
                % FAILS:
                % obj.setFrameDurationHours(obj.getSetting('frameDurationHours'));
                % obj.setFrameDurationMinutes(obj.getSetting('frameDurationMinutes'));
                %%
                
                % This used to be in the init with accel data -right below
                % the update widgets call.
                obj.setAggregateDurationMinutes(num2str(obj.accelObj.aggregateDurMin));
                [frameDurationMinutes, frameDurationHours] = obj.accelObj.getFrameDuration();
                obj.setFrameDurationMinutes(frameDurationMinutes);
                obj.setFrameDurationHours(frameDurationHours);
                
                windowDurationSec = obj.accelObj.getWindowDurSec();
                obj.setWindowDurSecMenu(windowDurationSec);
            end            
        end
        
        % returns visible linehandles in the upper axes of padaco.
        function visibleLineHandles = getVisibleLineHandles(obj)
            lineHandleStructs = obj.getLinehandle(obj.getDisplayType());
            lineHandles = struct2vec(lineHandleStructs);
            visibleLineHandles = lineHandles(strcmpi(get(lineHandles,'visible'),'on'));
        end        
        
        function hiddenLineHandles = getHiddenLineHandles(obj)
            lineHandleStructs = obj.getLinehandle(obj.getDisplayType());
            lineHandles = struct2vec(lineHandleStructs);
            hiddenLineHandles = lineHandles(strcmpi(get(lineHandles,'visible'),'off'));
        end
                
        %> @brief Want to redistribute or evenly distribute the lines displayed in
        %> this axis.
        function redistributePrimaryAxesLineHandles(obj)
            visibleLineHandles = obj.getVisibleLineHandles();
            numLines = numel(visibleLineHandles);
            if(numLines>0)
                curYLim = get(obj.axeshandle.primary,'ylim');
                
                axesHeight = diff(curYLim);
                deltaHeight = axesHeight/numLines;
                offset = deltaHeight/2;
                for n=1:numLines
                    curH = visibleLineHandles(n);
                    curTag = get(curH,'tag');
                    obj.accelObj.setOffset(curTag,offset);
                    offset = offset+deltaHeight;
                end
            end
            obj.draw()
        end

        % --------------------------------------------------------------------
        %> @brief Retrieves the window duration drop down menu's current value as a number.
        %> @param obj Instance of PASingleStudyController.
        %> @retval windowDurSec Duration of the current view's window as seconds.
        % --------------------------------------------------------------------
        function windowDurSec = getWindowDurSec(obj)
            userChoice = get(obj.menuhandle.windowDurSec,'value');
            userData = get(obj.menuhandle.windowDurSec,'userdata');
            windowDurSec = userData(userChoice);
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets the window duration drop down menu's current value
        %> based on the input parameter (as seconds).  If the duration in
        %> seconds is not found, then the value is appended to the drop down
        %> menu prior to being set.
        %> @param obj Instance of PASingleStudyController.
        %> @param windowDurSec Duration in seconds to set the drop downmenu's selection to
        % --------------------------------------------------------------------
        function windowDurSec = setWindowDurSecMenu(obj, windowDurSec)
            windowDurSecMat = get(obj.menuhandle.windowDurSec,'userdata');
            userChoice = find(windowDurSecMat==windowDurSec,1);
            
            % We did not find a match!  and need to append
            if(isempty(userChoice))
                windowDurStrCell = get(obj.menuhandle.windowDurSec,'string');
                windowDurStrCell(end+1) = num2str(windowDurSec);
                windowDurSecMat(end+1) = windowDurSec;
                userChoice =numel(windowDurStrCell);
                
                set(obj.menuhandle.windowDurSec,'userdata',windowDurSecMat,'string',windowDurStrCell);
            end
            set(obj.menuhandle.windowDurSec,'value',userChoice);
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves the current window's edit box string value as a
        %> number
        %> @param obj Instance of PASingleStudyController.
        %> @retval curWindow Numeric value of the current window displayed in the edit box.
        % --------------------------------------------------------------------
        function curWindow = getCurWindow(obj)
            curWindow = str2double(get(obj.texthandle.curWindow,'string'));
            
            % --------------------------------------------------------------------
            %> @brief Returns the current window of the instance variable accelObj
            %> (PASensorData)
            %> @param obj Instance of PAController
            %> @retval window The  current window, or null if it has not been initialized.
            %if(isempty(obj.accelObj))
            %    window = [];
            %else
            %    window = obj.accelObj.getCurWindow;
            %end
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves the aggregate duration edit box value as a
        %> number.
        %> @param obj Instance of PASingleStudyController.
        %> @retval aggregateDurMin The aggregate duration (in minutes) currently set in the text edit box
        %> as a numeric value.
        % --------------------------------------------------------------------
        function aggregateDurMin = getAggregateDurationMinutes(obj)
            aggregateDurMin = str2double(get(obj.texthandle.aggregateDuration,'string'));
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Set the frame size hour's units and 
        %> @brief Sets frame duration edit box (hours) string value
        %> @param obj Controller instance.
        %> @param new_frameDurationHours Hours for frame duration.
        %> @retval success True if the frame duration is changed, and false otherwise.
        % --------------------------------------------------------------------
        function success = setFrameDurationHours(obj,new_frameDurationHours)
            success = false;
            if(~isempty(obj.accelObj))
                cur_frameDurationHours = obj.accelObj.setFrameDurationHours(new_frameDurationHours);
                set(obj.texthandle.frameDurationHours,'string',num2str(cur_frameDurationHours));
                
                if(new_frameDurationHours==cur_frameDurationHours)
                    success=true;
                    
                    % update the aggregate duration if new frame duration is
                    % smaller.
                    frameDurationTotalMinutes = obj.getFrameDurationAsMinutes();
                    if(frameDurationTotalMinutes<obj.getAggregateDurationAsMinutes())
                        obj.setAggregateDurationMinutes(frameDurationTotalMinutes);
                    end
                end
            end
        end
           
        % --------------------------------------------------------------------
        %> @brief Set the aggregate duration in minutes and sets aggregate duration edit box string value
        %> @param obj Instance of controller
        %> @param new_aggregateDuration Aggregate duration in minutes.
        %> @retval success True if the aggregate duration is changed, and false otherwise.
        % --------------------------------------------------------------------
        function success = setAggregateDurationMinutes(obj,new_aggregateDuration)
            success = false;
            if(~isempty(obj.accelObj))
                cur_aggregateDuration = obj.accelObj.setAggregateDurationMinutes(new_aggregateDuration);
                aggregateDurationStr = num2str(cur_aggregateDuration);
                set(obj.texthandle.aggregateDuration,'string',aggregateDurationStr);
                if(new_aggregateDuration==cur_aggregateDuration)
                    success=true;
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Set the frame size minute's units and Sets frame duration
        %> edit box (minutes) string value.
        %> @param obj Controller instance.
        %> @param new_frameDurationMinutes Frame duration minutes measure.
        %> @retval success True if the frame duration is changed, and false otherwise.
        % --------------------------------------------------------------------
        function success = setFrameDurationMinutes(obj,new_frameDurationMinutes)
            success = false;
            if(~isempty(obj.accelObj))
                cur_frameDurationMinutes = obj.accelObj.setFrameDurationMinutes(new_frameDurationMinutes);
                
                frameDurationMinutesStr = num2str(cur_frameDurationMinutes);
                set(obj.texthandle.frameDurationMinutes,'string',frameDurationMinutesStr);
        
                if(new_frameDurationMinutes==cur_frameDurationMinutes)
                    success=true;
                    % update the aggregate duration if new frame duration is
                    % smaller.
                    frameDurationTotalMinutes = obj.getFrameDurationAsMinutes();
                    if(frameDurationTotalMinutes<obj.getAggregateDurationAsMinutes())
                        obj.setAggregateDurationMinutes(frameDurationTotalMinutes);
                    end
                end
            end
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Set the current window for the instance variable accelObj
        %> (PASensorData) and the current window edit box string value
        %> @param obj Instance of PASingleStudyController.
        %> @param new_window Value of the new window to set.
        %> @retval success True if the window is set successfully, and false otherwise.
        %> @note Reason for failure include window values that are outside
        %> the range allowed by accelObj (e.g. negative values or those
        %> longer than the duration given.
        % --------------------------------------------------------------------
        function success = setCurWindow(obj,new_window)
            success= false;
            if(~isempty(obj.accelObj))
                curWindow = obj.accelObj.setCurWindow(new_window);
                windowStartDateNum = obj.accelObj.window2datenum(new_window);
                windowEndDateNum = obj.accelObj.window2datenum(new_window+1);
                if(new_window==curWindow)                    
                    windowStr = num2str(curWindow);
                    set(obj.texthandle.curWindow,'string',windowStr);
                    xposStart=windowStartDateNum;
                    xposEnd=windowEndDateNum;
                    set(obj.positionBarHandle,'xdata',[repmat(xposStart,1,2),repmat(xposEnd,1,2),xposStart]);
                    set(obj.patchhandle.positionBar,'xdata',[repmat(xposStart,1,2),repmat(xposEnd,1,2)]);
                    obj.draw();                    
                    success=true;
                end
            end
        end  
      
        
        % --------------------------------------------------------------------
        %> @brief Sets line smoothing state for feature vectors displayed on the secondary axes.
        %> @param obj Instance of PASingleStudyController.
        %> @param smoothingState  Possible values include:
        %> - @c true Smoothing is on.
        %> - @c false Smoothing is off.
        % --------------------------------------------------------------------
        function setUseSmoothing(obj,smoothingState)
            if(nargin<2 || isempty(smoothingState))
                obj.setSetting('useSmoothing', true);
            else
                obj.setSetting('useSmoothing', smoothingState==true);
            end
        end
        
        function smoothing = getUseSmoothing(obj)
            smoothing = obj.getSetting('useSmoothing');
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets nonwear highlighting flag for secondary axis
        % display.
        %> @param obj Instance of PASingleStudyController.
        %> @param smoothingState  Possible values include:
        %> - @c true Nonwear highlighting is on.
        %> - @c false Nonwear highlighting is off.
        % --------------------------------------------------------------------
        function setNonwearHighlighting(obj,showNonwearHighlighting)
            if(nargin<2 || isempty(showNonwearHighlighting))
                obj.setSetting('highlightNonwear', true);
            else
                obj.setSetting('highlightNonwear', showNonwearHighlighting==true);
            end
        end
        
        function smoothing = getNonwearHighlighting(obj)
            smoothing = obj.getSetting('highlightNonwear');
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Sets display type instance variable.    
        %> @param obj Instance of PASingleStudyController.
        %> @param displayTypeStr A string representing the display type.  Can be 
        %> @li @c timeSeries
        %> @li @c bins
        %> @li @c features
        %> @param visibleProps Struct with the visibility property for each
        %> lineTag that can be displayed under the current displayType
        %> specified.        
        % --------------------------------------------------------------------
        function setDisplayType(obj,displayTypeStr,visibleProps)
            %                     % --------------------------------------------------------------------
            %         %> @brief Sets display type instance variable for the view.
            %         %> @param obj Instance of PASingleStudyController.
            %         %> @param displayType A string representing the display type structure.  Can be
            %         %> @li @c timeSeries
            %         %> @li @c bins
            %         %> @li @c features
            %         % --------------------------------------------------------------------
            %         function setDisplayType(obj,displayType)
            %             visibleProps = obj.accelObj.getVisible(displayType);
            %             obj.setDisplayType(displayType,visibleProps);
            %         end
        
            if(nargin<3)
                visibleProps = [];
            end
            if(isempty(visibleProps) && isa(obj.accelObj,'PASensorData'))
                % visibleProps = obj.settings.visible.(displayTypeStr);
                visibleProps = obj.accelObj.getVisible(displayTypeStr);
            end
            
            if(any(strcmpi(fieldnames(PASensorData.getStructTypes()),displayTypeStr)))
                obj.setRadioButton(displayTypeStr);
                
                if(isstruct(obj.labelhandle))
                    allProps.visible = 'off';
                    allStructTypes = PASensorData.getStructTypes();
                    fnames = fieldnames(allStructTypes);
                    for f=1:numel(fnames)
                        curStructName = fnames{f};
                        recurseHandleInit(obj.labelhandle.(curStructName), allProps);
                        recurseHandleInit(obj.referencelinehandle.(curStructName), allProps);
                        recurseHandleInit(obj.linehandle.(curStructName), allProps);                        
                    end
                end
                obj.setSetting('displayType',displayTypeStr);                
                if(isstruct(obj.labelhandle))
                    if(isstruct(visibleProps))
                        recurseHandleSetter(obj.referencelinehandle.(displayTypeStr), visibleProps);
                        recurseHandleSetter(obj.linehandle.(displayTypeStr), visibleProps);
                        recurseHandleSetter(obj.labelhandle.(displayTypeStr), visibleProps);
                    end
                end
            else
                fprintf('Warning, this string (%s) is not an acceptable option.\n',displayTypeStr);
            end
        end        
        
        % --------------------------------------------------------------------
        %> @brief Returns the display type instance variable.    
        %> @param obj Instance of PASingleStudyController.
        %> @retval displayTypeStr A string representing the display type.
        %> Will be one of:
        %> @li @c Time Series
        %> @li @c Aggregate Bins
        %> @li @c Features
        % --------------------------------------------------------------------
        function displayTypeStr = getDisplayType(obj)
            displayTypeStr = obj.getSetting('displaytype');
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves the frame duration edit box value (minutes) as a
        %> number.
        %> @param obj Instance of PASingleStudyController.
        %> @retval frameDurMinutes The frame duration (in minutes) currently set in the text edit box
        %> as a numeric value.
        % --------------------------------------------------------------------
        function frameDurMinutes = getFrameDurationMinutes(obj)
            frameDurMinutes = str2double(get(obj.texthandle.frameDurationMinutes,'string'));
        end        
        % --------------------------------------------------------------------
        %> @brief Retrieves the frame duration hours edit box value ) as a
        %> number.
        %> @param obj Instance of PASingleStudyController.
        %> @retval frameDurHours The frame duration (hours) currently set in the text edit box
        %> as a numeric value.
        % --------------------------------------------------------------------
        function frameDurHours = getFrameDurationHours(obj)
            frameDurHours = str2double(get(obj.texthandle.frameDurationHours,'string'));
        end        
        
        % --------------------------------------------------------------------
        %> @brief Returns the total frame duration (i.e. hours and minutes) in aggregated minutes.
        %> @param obj Instance of PASensorData
        %> @retval curFrameDurationMin The current frame duration as total
        %> minutes.
        % --------------------------------------------------------------------
        function curFrameDurationTotalMin = getFrameDurationAsMinutes(obj)
            [curFrameDurationMin, curFrameDurationHour] = obj.accelObj.getFrameDuration();
            curFrameDurationTotalMin = [curFrameDurationMin, curFrameDurationHour]*[1;60];
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Returns the total frame duration (i.e. hours and minutes) in aggregated minutes.
        %> @param obj Instance of PASensorData
        %> @retval curFrameDurationMin The current frame duration as total
        %> minutes.
        % --------------------------------------------------------------------
        function aggregateDurationTotalMin = getAggregateDurationAsMinutes(obj)
            aggregateDurationTotalMin = obj.accelObj.getAggregateDurationInMinutes();
            
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Returns the current study's duration as seconds.
        %> @param obj Instance of PASensorData
        %> @retval curStudyDurationSec The duration of the current study in seconds.
        % --------------------------------------------------------------------
        function curStudyDurationSec = getStudyDurationSec(obj)
            curStudyDurationSec = obj.accelObj.durationSec;
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the number of frames the study can be broken into based
        %> on the frame duration set in the GUI.
        %> @param obj Instance of PAController.
        %> @note The accelObj property must be set (i.e. a file must be
        %> loaded for this function to work).
        % --------------------------------------------------------------------
        function frameCount = getFrameCount(obj)
            frameCount = obj.accelObj.getFrameCount();
        end
        
        % --------------------------------------------------------------------
        %> @brief Calculates the mean lux value for a given number of sections.
        %> @param obj Instance of PAController
        %> @param numSections (optional) Number of patches to break the
        %> accelObj lux time series data into and calculate the mean
        %> lumens over.
        %> @param paDataObj Optional instance of PASensorData.  Mean lumens will
        %> be calculated from this when included, otherwise the instance
        %> variable accelObj is used.
        %> @retval meanLumens Vector of mean lumen values calculated
        %> from the lux field of the accelObj PASensorData object instance
        %> variable.  Vector values are in consecutive order of the section they are calculated from.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the meanLumens
        %> value (at the same row position) was derived from.
        %> @note  Sections will not be calculated on equally lenghted
        %> sections when numSections does not evenly divide the total number
        %> of samples.  In this case, the last section may be shorter or
        %> longer than the others.
        % --------------------------------------------------------------------
        function [meanLumens,startStopDatenums] = getMeanLumenPatches(obj,numSections,paDataObj)
            if(nargin<2 || isempty(numSections))
                numSections = 100;
            end
            if(nargin<3) ||isempty(paDataObj)
                paDataObj = obj.accelObj;
            end
            luxData = paDataObj.lux;
            indices = ceil(linspace(1,numel(luxData),numSections+1));
            meanLumens = zeros(numSections,1);
            startStopDatenums = zeros(numSections,2);
            for i=1:numSections
                meanLumens(i) = mean(luxData(indices(i):indices(i+1)));
                startStopDatenums(i,:) = [paDataObj.dateTimeNum(indices(i)),paDataObj.dateTimeNum(indices(i+1))];
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Estimates daylight intensity across the study.
        %> @param obj Instance of PAController
        %> @param numSections (optional) Number of chunks to estimate
        %> daylight at across the study.  Default is 100.
        %> @param paDataObj Optional instance of PASensorData.  Date time will
        %> be calculated from this when included, otherwise date time from the
        %> instance variable accelObj is used.
        %> @retval daylightVector Vector of estimated daylight from the time of day at startStopDatenums.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the meanLumens
        %> value (at the same row position) was derived from.
        % --------------------------------------------------------------------
        function [daylightVector,startStopDatenums] = getDaylight(obj,numSections,paDataObj)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            if(nargin<3) ||isempty(paDataObj)
                paDataObj = obj.accelObj;
            end
            
            indices = ceil(linspace(1,numel(paDataObj.dateTimeNum),numSections+1));
            startStopDatenums = [paDataObj.dateTimeNum(indices(1:end-1)),paDataObj.dateTimeNum(indices(2:end))];
            [y,mo,d,H,MI,S] = datevec(mean(startStopDatenums,2));
            dayTime = [H,MI,S]*[1; 1/60; 1/3600];
            %             dayTime = [[H(:,1),MI(:,1),S(:,1)]*[1;1/60;1/3600], [H(:,2),MI(:,2),S(:,2)]*[1;1/60;1/3600]];
            
            % obtain the middle spot of the daytime chunk. --> this does
            % not work because the hours flip over at 24:00.
            %             dayTime = [H,MI,S]*[1;1;1/60;1/60;1/3600;1/3600]/2;
            
            
            % linear model for daylight
            %             daylightVector = (-abs(dayTime-12)+12)/12;
            
            % sinusoidal models for daylight
            T = 24;
            %             daylightVector = cos(2*pi/T*(dayTime-12));
            %             daylightVector = sin(pi/T*dayTime);  %just take half of a cycle here ...
            
            daylightVector= (cos(2*pi*(dayTime-12)/T)+1)/2;  %this is spread between 0 and 1; with 1 being brightest at noon.
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Calculates a desired feature for a particular acceleration object's field value.
        %> @note This is the general form of getMeanLuxPatches
        %> @param obj Instance of PAController
        %> @param featureFcn Function name or handle to use to obtain
        %> features.
        %> @param fieldName String name of the accelObj field to obtain data from.
        %> @note Data is obtained using dynamic indexing of
        %> accelObj instance variable (ie.. data = obj.accelObj.(fildName))
        %> @param numSections (optional) Number of patches to break the
        %> accelObj time series data into and calculate the features from.
        %> @param paDataObj Optional instance of PASensorData.  Date time will
        %> be calculated from this when included, otherwise date time from the
        %> instance variable accelObj is used.
        %> @retval featureVec Vector of specified feature values calculated
        %> from the specified (fieldName) field of the accelObj PASensorData object instance
        %> variable.  Vector values are in consecutive order of the section they are calculated from.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the feature vector
        %> value (at the same row position) was derived from.
        %> @note  Sections will not be calculated on equally lenghted
        %> sections when numSections does not evenly divide the total number
        %> of samples.  In this case, the last section may be shorter or
        %> longer than the others.
        % --------------------------------------------------------------------
        function [featureVec,varargout] = getFeatureVec(obj,featureFcnName,fieldName,numSections,paDataObj)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            
            if(nargin<5) ||isempty(paDataObj)
                paDataObj = obj.accelObj;
            end
            
            % Here we deal with features, which *should* already have the
            % correct number of sections needed.
            featureStruct = paDataObj.getStruct('all','features');
            if(strcmpi(featureFcnName,'psd'))
                psdBand = strcat('psd_band_',fieldName(end));
                if(isfield(featureStruct,psdBand))
                    featureVec = featureStruct.(psdBand);
                else
                    switch fieldName(end)
                        case 'g'  % accel.count.vecMag
                            featureVec = featureStruct.psd_band_1;
                        case 'x'
                            featureVec = featureStruct.psd_band_2;
                        case 'y'
                            featureVec = featureStruct.psd_band_3;
                        case 'z'
                            featureVec = featureStruct.psd_band_4;
                        otherwise
                            featureVec = featureStruct.psd_band_1;
                    end
                end
            else
                %featureVec = zeros(numSections,1);            
                featureVec = featureStruct.(featureFcnName);
                featureFcn = PASensorData.getFeatureFcn(featureFcnName);

                
                timeSeriesStruct = paDataObj.getStruct('all','timeSeries');
                
                % Can't get nested fields directly with
                % timeSeriesStruct.(fieldName) where fieldName =
                % 'accel.count.x', for example.
                fieldData = eval(['timeSeriesStruct.',fieldName]);
                
                indices = ceil(linspace(1,numel(fieldData),numSections+1));
                try
                    for i=1:numSections
                        featureVec(i) = feval(featureFcn,fieldData(indices(i):indices(i+1)));
                    end
                catch me
                    showME(me);
                end
            end
            
            if(nargout>1)
                varargout{1} = obj.getFeatureStartStopDatenums(featureFcnName,fieldName,numSections,paDataObj);
            end
        end
        
        
        % Retrieves the start stop datenum pairs for the provided feature function and fieldName.
        % Originally this function was implemented inside getFeatureFcn
        % with the thinking that it would degrade performance to call a
        % second for loop to calculate the startStopDatenums.  This was not
        % the case in practice, however, because the features would be
        % retrieved for different signals which all had the same number of
        % samples and startStopDatenums (so it was redundant to keep
        % calculating the same values.
        function startStopDatenums = getFeatureStartStopDatenums(obj,featureFcnName,fieldName,numSections,paDataObj)
            if(nargin<2 || isempty(numSections) || numSections <=1)
                numSections = 100;
            end
            
            if(nargin<5) ||isempty(paDataObj)
                paDataObj = obj.accelObj;
            end
            
            startStopDatenums = zeros(numSections,2);
            
            if(strcmpi(featureFcnName,'psd'))
                indices = ceil(linspace(1,numel(paDataObj.dateTimeNum),numSections+1));
                for i=1:numSections
                    startStopDatenums(i,:) = [paDataObj.dateTimeNum(indices(i)),paDataObj.dateTimeNum(indices(i+1))];
                end
            else
                timeSeriesStruct = paDataObj.getStruct('all','timeSeries');
                fieldData = eval(['timeSeriesStruct.',fieldName]);
                
                indices = ceil(linspace(1,numel(fieldData),numSections+1));
                for i=1:numSections
                    startStopDatenums(i,:) = [paDataObj.dateTimeNum(indices(i)),paDataObj.dateTimeNum(indices(i+1))];
                end
            end
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Calculates a desired feature for a particular acceleration object's field value.
        %> @note This is the general form of getMeanLuxPatches
        %> @param obj Instance of PAController
        %> @param featureFcn Function name or handle to use to obtain
        %> features.
        %> @param fieldName String name of the accelObj field to obtain data from.
        %> @note Data is obtained using dynamic indexing of
        %> accelObj instance variable (ie.. data = obj.accelObj.(fildName))
        %> @param numSections (optional) Number of patches to break the
        %> accelObj time series data into and calculate the features from.
        %> @param paDataObj Optional instance of PASensorData.  Date time will
        %> be calculated from this when included, otherwise date time from the
        %> instance variable accelObj is used.
        %> @retval featureVec Vector of specified feature values calculated
        %> from the specified (fieldName) field of the accelObj PASensorData object instance
        %> variable.  Vector values are in consecutive order of the section they are calculated from.
        %> @retval startStopDatenums Nx2 matrix of datenum values whose
        %> rows correspond to the start/stop range that the feature vector
        %> value (at the same row position) was derived from.
        %> @note  Sections will not be calculated on equally lengthed
        %> sections when numSections does not evenly divide the total number
        %> of samples.  In this case, the last section may be shorter or
        %> longer than the others.
        % --------------------------------------------------------------------
        %function [usageVec, usageStates,startStopDatenums] = getUsageState(obj)
        function usageVec = getUsageState(obj, paDataObj)
            if nargin < 2
                paDataObj = obj.accelObj;
            end
            usageVec = [];
            %usageStates = [];
            %startStopDatenums = [];
            if isfield(obj.accelObj.usage,'vecMag')
                usageVec = paDataObj.usage.vecMag;
            else
                if(paDataObj.classifyUsageForAllAxes())
                    %[usageVec, usageStates, startStopDatenums] = paDataObj.classifyUsageForAllAxes();
                    usageVec = paDataObj.usage.vecMag;
                else
                    obj.logWarning('Unable to classify usage state for all axis');
                end
            end
        end
        
        % --------------------------------------------------------------------
        % --------------------------------------------------------------------
        %
        %   Initializations
        %
        % --------------------------------------------------------------------
        % --------------------------------------------------------------------
        
       
        % --------------------------------------------------------------------
        %> @brief Clears the main figure's handles (deletes all children
        %> handles).
        %> @param obj Instance of PASingleStudyController.
        % --------------------------------------------------------------------
        function clearFigure(obj)
            
            %clear the figure handle
            set(0,'showhiddenhandles','on');
            
            cf = get(0,'children');
            for k=1:numel(cf)
                if(cf(k)==obj.figureH)
                    set(0,'currentfigure',cf(k));
                else
                    delete(cf(k)); %removes other children aside from this one
                end
            end
            
            set(0,'showhiddenhandles','off');
        end
      

        function didSet = setSensorData(obj, sensorDataObj)
            didSet = false;
            if(nargin>1 && isa(sensorDataObj,'PASensorData'))
                obj.accelObj = sensorDataObj;
                obj.accelObj.addlistener('LinePropertyChanged',@obj.linePropertyChangeCallback);
                didSet = true;
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Initializes the graphic handles (label and line handles) and maps figure tag names
        %> to PASingleStudyController instance variables.  Initializes the menubar and various widgets.  Also set the acceleration data instance variable and assigns
        %> line handle y values to those found with corresponding field
        %> names in PASensorDataObject.        
        %> @note Resets the currentWindow to 1.
        %> @param obj Instance of PASingleStudyController
        %> @param PASensorDataObject (Optional) PASensorData display struct that matches the linehandle struct of
        %> obj and whose values will be assigned to the 'ydata','xdata', and 'color' fields of the
        %> line handles.  A label property struct will be created
        %> using the string values of labelStruct and the initial x, y value of the line
        %> props to initialize the 'string' and 'position' properties of 
        %> obj's corresponding label handles.          
        % --------------------------------------------------------------------
        function obj = initWithAccelData(obj, sensorDataObject)
            if(~obj.setSensorData(sensorDataObject))
            else
                % SensorData has already been initialized with default/saved
                % settings (i.e. obj.AppSettings.accelObj) and these are in turn
                % passed along to the SingleStudy class here and used to initialize
                % many of the selected widgets.
                
                obj.showBusy('Initializing View','all');
                                    
                obj.initSignalSelectionMenu();
                
                
                curAccelType = obj.getAccelType();
                switch lower(curAccelType)
                    case {'all','raw'}
                        obj.accelTypeShown = 'raw';
                    case 'count'
                        obj.accelTypeShown = 'count';
                    case 'mims'
                        obj.accelTypeShown = 'mims';
                    otherwise
                        obj.logWarning('Unknown type ''%s''.  Using ''count'' instead.', curAccelType);
                        obj.accelTypeShown = 'count';
                end
                
                obj.initView();                
                
                
                % Go ahead and extract features using current settings.  This
                % is good because then we can use
                obj.showBusy('Calculating features','all');
                obj.accelObj.extractFeature(obj.getSignalSelection(),'all');
                
                % This was disabled until the first time features are
                % calculated.
                obj.enableTimeSeriesRadioButton();
                obj.enableFeatureRadioButton();
                
                % set the display to show time series data initially.
                displayStructName = 'timeSeries';
                obj.setDisplayType(displayStructName);
                
                
                obj.setCurWindow(obj.accelObj.getCurWindow());
                
                % Update the secondary axes
                % Items to display = 8 when count or all views exist.
                if(strcmpi(obj.getAccelType(),'count') || strcmpi(obj.getAccelType(),'all'))
                    obj.numViewsInSecondaryDisplay = 8;
                else
                    obj.numViewsInSecondaryDisplay = 7;                    
                end
                
                % Items 1-5
                % Starting from the bottom of the axes - display the features
                % for x, y, z, vec magnitude, and 1-d values
                heightOffset = obj.updateSecondaryFeaturesDisplay();
                
                itemsToDisplay = obj.numViewsInSecondaryDisplay-5; % usage state, mean lumens, daylight approx
                remainingHeight = 1-heightOffset;
                height = remainingHeight/itemsToDisplay;
                
                usageVec = obj.getUsageState();
                obj.addWeartimeToSecondaryAxes(usageVec,obj.accelObj.dateTimeNum,height,heightOffset);
                % if(obj.accelObj.getSampleRate()<=1)
                    
                    % usageVec = obj.getUsageState();
                    % obj.addWeartimeToSecondaryAxes(usageVec,obj.accelObj.dateTimeNum,height,heightOffset);
                    
                    % Old
                    % vecHandles = obj.addFeaturesVecToSecondaryAxes(usageVec,obj.accelObj.dateTimeNum,height,heightOffset);
                    
                    % Older
                    %[usageVec,usageState, startStopDatenums] = obj.getUsageState();
                    
                    %obj.addOverlayToSecondaryAxes(usageState,startStopDatenums,1/numRegions,curRegion/numRegions);
                % else
                    
                    % Old
                    %                 vecHandles = [];
                % end
                
                numFrames = obj.getFrameCount();
                
                if strcmpi(curAccelType, 'all') || strcmpi(curAccelType, 'count')
                    % Next, add lumens intensity to secondary axes
                    heightOffset = heightOffset+height;
                    maxLumens = 250;
                    
                    [meanLumens,startStopDatenums] = obj.getMeanLumenPatches(numFrames);
                    [overlayLineH, overlayPatchH] = obj.addOverlayToSecondaryAxes(meanLumens,startStopDatenums,height,heightOffset,maxLumens); %#ok<ASGLU>
                    uistack(overlayPatchH,'bottom');
                    %             [medianLumens,startStopDatenums] = obj.getMedianLumenPatches(1000);
                    %             obj.addLumensOverlayToSecondaryAxes(meanLumens,startStopDatenums);
                end
                
                % Finally Add daylight to the top.
                maxDaylight = 1;
                [daylight,startStopDatenums] = obj.getDaylight(numFrames);
                heightOffset = heightOffset+height;
                
                [overlayLineH, overlayPatchH] = obj.addOverlayToSecondaryAxes(daylight,startStopDatenums,height-0.005,heightOffset,maxDaylight); %#ok<ASGLU>
                uistack(overlayPatchH,'bottom');
                
                obj.showReady('all');
                
            end
        end
        
        function initView(obj)
            axesProps.primary.xlim = obj.accelObj.getCurWindowRange();
            axesProps.primary.ylim = obj.accelObj.getDisplayMinMax();
            
            % Show this regardless of whether we have something to show or
            % not
            curAccelType = obj.getAccelType();
            if strcmpi(curAccelType, 'raw') || strcmpi(curAccelType, 'all')
                ytickLabel = {'X','Y','Z','|X,Y,Z|','|X,Y,Z|','Activity','Lumens','Daylight'};
            else
                ytickLabel = {'X','Y','Z','|X,Y,Z|','|X,Y,Z|','Activity','Daylight'};                
            end
            
            axesProps.secondary.ytick = getTicksForLabels(ytickLabel);
            axesProps.secondary.yticklabel = ytickLabel;
            
            axesProps.secondary.TickDir = 'in';
            axesProps.secondary.TickDirMode = 'manual';
            
            axesProps.secondary.TickLength = [0.001 0];
            
            obj.initAxesHandles(axesProps);
            
            %             axesChildren = allchild(obj.axeshandle.secondary);
            %             for h=1:numel(axesChildren)
            %                 if(strcmpi(get(axesChildren(h),'type'),'text') && isfield(get(axesChildren(h)),'Rotation'))
            %                     set(axesChildren(h),'rotation',90,'string','blahs');
            %                 end
            %             end
            
            
            %creates and initializes line handles (obj.linehandle fields)
            % lineContextMenuHandle Contextmenu handle to assign to
            %VIEW's line handles
            
            % However, all lines are invisible.
            obj.createLineAndLabelHandles(obj.accelObj);
            
            %resize the secondary axes according to the new window
            %resolution
            obj.updateSecondaryAxes(obj.accelObj.getStartStopDatenum());
            
            %initialize the various line handles and label content and
            %color.  Struct types consist of
            %> 1. timeSeries
            %> 2. features
            structType = obj.accelObj.getStructTypes();
            fnames = fieldnames(structType);
            for f=1:numel(fnames)
                curStructType = fnames{f};
                
                labelStringStruct = obj.accelObj.getLabel(curStructType);                
                labelPosStruct = obj.getLabelhandlePosition(curStructType);
                labelProps = mergeStruct(labelStringStruct,labelPosStruct);
                
                colorStruct = obj.accelObj.getColor(curStructType);
                
                visibleStruct = obj.accelObj.getVisible(curStructType);
                
                % Keep everything invisible at this point - so ovewrite the
                % visibility property before we merge it together.
                visibleStruct = structEval('overwrite',visibleStruct,visibleStruct,'off');
                allStruct = mergeStruct(colorStruct,visibleStruct);
                
                labelProps = mergeStruct(labelProps,allStruct);
                
                lineProps = obj.accelObj.getStruct('dummydisplay',curStructType);
                lineProps = mergeStruct(lineProps,allStruct);
                
                recurseHandleSetter(obj.linehandle.(curStructType),lineProps);
                recurseHandleSetter(obj.referencelinehandle.(curStructType),lineProps);
                
                recurseHandleSetter(obj.labelhandle.(curStructType),labelProps);
            end
            
            obj.setFilename(obj.accelObj.getFilename());
            
            obj.setStudyPanelContents(obj.accelObj.getHeaderAsString());
            
            % initialize and enable widgets (drop down menus, edit boxes, etc.)
            obj.updateWidgets();
            
            
            
            set(obj.positionBarHandle,'visible','on','xdata',nan(1,5),'ydata',[0 1 1 0 0],'linestyle',':');
            set(obj.patchhandle.positionBar,'visible','on','xdata',nan(1,4),'ydata',[0 1 1 0]);
            
            % Enable and some panels
            timeseriesPanels = [obj.handles.panel_timeseries;
                obj.handles.panel_epochControls];
            set(findall(timeseriesPanels,'enable','off'),'enable','on');
            
            % This has not been implemented yet, so disable it.
            set(findall(obj.handles.panel_features_prefilter,'enable','on'),'enable','off');
            
            % Disable button group - option to switch radio buttons will be
            % allowed after go callback (i.e. user presses a gui button).
            
            set(findall(obj.handles.panel_displayButtonGroup,'enable','on'),'enable','off');
            
            % This is in the panel display button group, but is not
            % actually part of it and should be moved to another place
            % soon.
            set(obj.handles.menu_displayFeature,'enable','on');
            
            % Turn on the meta data handles - panel that shows information
            % about the current file/study.
            metaDataHandles = [obj.panelhandle.metaData;get(obj.panelhandle.metaData,'children')];
            set(metaDataHandles,'visible','on');
            
            obj.initCallbacks();
        end
         
        % --------------------------------------------------------------------
        %> @brief Updates the secondary axes x and y axes limits.
        %> @param obj Instance of PASingleStudyController
        %> @param axesRange A 1x2 vector of the starting and stoping
        %> date numbers for the primary axes' x-axis.
        % --------------------------------------------------------------------
        function updatePrimaryAxes(obj,axesRange)
            axesProps.primary.xlim = axesRange;
            curWindow = obj.getCurWindow();
            windowDurSec = obj.getWindowDurSec();
            curDateNum = obj.accelObj.window2datenum(curWindow);
            nextDateNum = obj.accelObj.window2datenum(curWindow+1); 
            numTicks = 10;
            xTick = linspace(axesRange(1),axesRange(2),numTicks);
            dateTicks = linspace(curDateNum,nextDateNum,numTicks);
            % if number of seconds or window length is less than 10 minute then include seconds;
            if(windowDurSec < 60*10)
                axesProps.primary.XTickLabel = datestr(dateTicks,'ddd HH:MM:SS');                
            %  else if it is less than 120 minutes then include minutes.
            elseif(windowDurSec < 60*120)
                axesProps.primary.XTickLabel = datestr(dateTicks,'ddd HH:MM');
            %  otherwise just include day and hours.
            else 
                axesProps.primary.XTickLabel = datestr(dateTicks,'ddd HH:MM PM');
            end    
            
            axesProps.primary.XTick = xTick;            
            obj.initAxesHandles(axesProps);
        end

        % --------------------------------------------------------------------
        % Wear states
        % Awake
        % 35        ACTIVE
        % 25        INACTIVE
        % Sleep
        % 20        NAP
        %                    15        NREM
        % 10        REMS
        % Non-wear states
        % 5        Study-not-over
        % 0        Study-over
        % -1         Unknown
        % --------------------------------------------------------------------
        function featureHandles = addWeartimeToSecondaryAxes(obj, featureVector, startStopDatenum, overlayHeightRatio, overlayOffset)
            featureVector(end) = 35;
            featureHandles = addFeaturesVecToAxes(obj.axeshandle.secondary, featureVector, startStopDatenum, overlayHeightRatio, overlayOffset, obj.getUseSmoothing());
            
            nonwearHeightRatio = overlayHeightRatio*((7.5)/(35--1));
            wearHeightRatio = overlayHeightRatio-nonwearHeightRatio;
            axesH = obj.axeshandle.secondary;
            yLim = get(axesH,'ylim');
            
            % nonwear is lower down
            yLimPatches = yLim*nonwearHeightRatio+overlayOffset;
            ydata = [yLimPatches, fliplr(yLimPatches)]';
            xStart = startStopDatenum(1);
            xEnd = startStopDatenum(end);
            xdata = [xStart xStart xEnd xEnd]';
             
            set(obj.patchhandle.nonwear,'xdata',xdata,'ydata',ydata,'visible','on');
            
            % place wear above it.  xData is same, but yDdata is shifted up
            % some.
            overlayOffset2 = yLimPatches(end);
            yLimPatches2 = yLim*wearHeightRatio+overlayOffset2;
            ydata2 = [yLimPatches2, fliplr(yLimPatches2)]';            
            set(obj.patchhandle.wear,'xdata',xdata,'ydata',ydata2,'visible','on');
            obj.draw();
            
        end
        
        % --------------------------------------------------------------------
        %> @brief Adds a feature vector as a heatmap and as a line plot to the secondary axes.
        %> @param obj Instance of PASingleStudyController.
        %> @param featureVector A vector of features to be displayed on the
        %> secondary axes.
        %> @param startStopDatenum A vector of start and stop date nums that
        %> correspond to the start and stop times of the study that the
        %> feature in featureVector at the same index corresponds to.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the secondary axes.
        %> @param overlayOffset The normalized y offset ([0, 1]) that is applied to
        %> the featureVector when displayed on the secondary axes.        
        % --------------------------------------------------------------------
        function [feature_patchH, feature_lineH, feature_cumsumLineH] = addFeaturesVecAndOverlayToSecondaryAxes(obj, featureVector, startStopDatenum, overlayHeight, overlayOffset)
            if(ishandle(obj.patchhandle.feature))
                delete(obj.patchhandle.feature);
            end
            if(ishandle(obj.linehandle.feature))
                delete(obj.linehandle.feature);
            end
            if(ishandle(obj.linehandle.featureCumsum))
                delete(obj.linehandle.featureCumsum);
            end
            [feature_patchH, feature_lineH, feature_cumsumLineH] = obj.addFeaturesVecAndOverlayToAxes(obj.axeshandle.secondary, featureVector, startStopDatenum, overlayHeight, overlayOffset, obj.getUseSmoothing(), obj.contextmenuhandle.featureLine);
            [obj.patchhandle.feature, obj.linehandle.feature, obj.linehandle.featureCumsum] = deal(feature_patchH, feature_lineH, feature_cumsumLineH);
        end
        
        % --------------------------------------------------------------------
        %> @brief Plots a feature vector on the secondary axes.
        %> @param obj Instance of PASingleStudyController.
        %> @param featureVector A vector of features to be displayed on the
        %> secondary axes.
        %> @param startStopDatenum A vector of start and stop date nums that
        %> correspond to the start and stop times of the study that the
        %> feature in featureVector at the same index corresponds to.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the secondary axes.
        %> @param overlayOffset The normalized y offset ([0, 1]) that is applied to
        %> the featureVector when displayed on the secondary axes.
        %> @retval featureHandles Line handles created from the method.
        % --------------------------------------------------------------------
        function featureHandles = addFeaturesVecToSecondaryAxes(obj, featureVector, startStopDatenum, overlayHeight, overlayOffset)
            featureHandles = addFeaturesVecToAxes(obj.axeshandle.secondary, featureVector, startStopDatenum, overlayHeight, overlayOffset, obj.getUseSmoothing());
        end
        
        % --------------------------------------------------------------------
        %> @brief Adds a magnitude vector as a heatmap to the secondary axes.
        %> @param obj Instance of PASingleStudyController.
        %> @param overlayVector A magnitude vector to be displayed in the
        %> secondary axes as a heat map.
        %> @param startStopDatenum An Nx2 matrix start and stop datenums which
        %> correspond to the start and stop times of the same row in overlayVector.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the secondary axes.
        %> @param overlayOffset The normalized y offset that is applied to
        %> the overlayVector when displayed on the secondary axes.
        %> @param maxValue The maximum value to normalize the overlayVector
        %> with so that the normalized overlayVector's maximum value is 1.
        % --------------------------------------------------------------------
        function [overlayLineH, overlayPatchH] = addOverlayToSecondaryAxes(obj, overlayVector, startStopDatenum, overlayHeight, overlayOffset,maxValue)
            [overlayLineH,overlayPatchH] = addOverlayToAxes(obj.axeshandle.secondary, overlayVector, startStopDatenum, overlayHeight, overlayOffset,maxValue,obj.contextmenuhandle.featureLine);
        end

        
        % --------------------------------------------------------------------
        %> @brief Updates the secondary axes x and y axes limits.
        %> @param obj Instance of PASingleStudyController
        %> @param startStopDatenum A 1x2 vector of the starting and stoping
        %> date numbers.
        % --------------------------------------------------------------------
        function updateSecondaryAxes(obj,startStopDatenum)
            
            axesProps.secondary.xlim = startStopDatenum;
            [~,~,d,h,mi,s] = datevec(diff(startStopDatenum));
            durationDays = d+h/24+mi/60/24+s/3600/24;
            if(durationDays<0.25)
                dateScale = 1/48; %show every 30 minutes
            elseif(durationDays<0.5)
                dateScale = 1/24; %show every hour
            elseif(durationDays<0.75)
                dateScale = 1/12; %show every couple hours
            elseif(durationDays<=1)
                dateScale = 1/6; %show every four hours
            elseif(durationDays<=2)
                dateScale = 1/3; %show every 8 hours
            elseif(durationDays<=10)
                dateScale = 1/2; %show every 12 hours
            else
                dateScale = 1; %show every 24 hours.
                
            end    
            if(dateScale >= 1/3)
                timeDeltaSec = datenum(0,0,1)/24/3600;
                studyDatenums = startStopDatenum(1):timeDeltaSec:startStopDatenum(2);
                [~,~,~,hours,minutes,sec] = datevec(studyDatenums);
                newDayIndices = mod([hours(:),minutes(:),sec(:)]*[1;1/60;1/3600],24)==0;
%                 quarterDayIndices =  mod([hours(:),min(:),sec(:)]*[1;1/60;1/3600],24/4)==0;

                xTick = studyDatenums(newDayIndices);
                axesProps.secondary.XGrid = 'on';
                axesProps.secondary.XMinorGrid = 'off';
                axesProps.secondary.XMinorTick = 'on';
                
                
            else
                timeDelta = datenum(0,0,1)*dateScale;
                xTick = [startStopDatenum(1):timeDelta:startStopDatenum(2), startStopDatenum(2)];
                axesProps.secondary.XMinorTick = 'off';
                axesProps.secondary.XGrid = 'off';

            end
            
            axesProps.secondary.gridlinestyle = '--';
            
            axesProps.secondary.YGrid = 'off';
            axesProps.secondary.YMinorGrid = 'off';
            
            axesProps.secondary.ylim = [0 1];
            axesProps.secondary.xlim = startStopDatenum;
            
            axesProps.secondary.XTick = xTick;
            axesProps.secondary.XTickLabel = datestr(xTick,'ddd HH:MM');
            
           
            fontReduction = min([4, floor(durationDays/4)]);
            axesProps.secondary.fontSize = 14-fontReduction;
            obj.initAxesHandles(axesProps);
%             datetick(obj.axeshandle.secondary,'x','ddd HH:MM')
        end
        
        % --------------------------------------------------------------------
        %> @brief Create the line handles and text handles that describe the lines,
        %> that will be displayed by the view.
        %> This is based on the structure template generated by member
        %> function getStruct('dummydisplay').
        %> @param PASensorDataObject Instance of PASensorData.
        %> @param obj Instance of PASingleStudyController
        % --------------------------------------------------------------------
        function createLineAndLabelHandles(obj,PASensorDataObject)
            % Kill off anything else still in the primary and secondary
            % axes...
            zombieLines = findobj([obj.axeshandle.primary;obj.axeshandle.secondary],'type','line');
            zombiePatches = findobj([obj.axeshandle.primary;obj.axeshandle.secondary],'type','patch');
            zombieText = findobj([obj.axeshandle.primary;obj.axeshandle.secondary],'type','text');
            
            zombieHandles = [zombieLines(:);zombiePatches(:);zombieText(:)];
            delete(zombieHandles);
            
            obj.linehandle = [];
            obj.labelhandle = [];
            obj.referencelinehandle = [];
            
            handleProps.UIContextMenu = obj.contextmenuhandle.signals;
            handleProps.Parent = obj.axeshandle.primary;

            handleProps.visible = 'off';
            
            structType = PASensorDataObject.getStructTypes();            
            fnames = fieldnames(structType);
            for f=1:numel(fnames)
                curName = fnames{f};
                dataStruct = PASensorDataObject.getStruct('dummy',curName);
            
                handleType = 'line';
                handleProps.tag = curName;

                obj.linehandle.(curName) = recurseHandleGenerator(dataStruct,handleType,handleProps);
            
                obj.referencelinehandle.(curName) = recurseHandleGenerator(dataStruct,handleType,handleProps);
            
                handleType = 'text';
                obj.labelhandle.(curName) = recurseHandleGenerator(dataStruct,handleType,handleProps);
            end
            
            %secondary axes
            obj.positionBarHandle = line('parent',obj.axeshandle.secondary,'visible','off');%annotation(obj.figureH.sev,'line',[1, 1], [pos(2) pos(2)+pos(4)],'hittest','off');
%             obj.patchhandle.positionBar =  patch('xdata',nan(1,4),'ydata',[0 1 1 0],'zdata',repmat(-1,1,4),'parent',obj.axeshandle.secondary,'hittest','off','visible','off','facecolor',[0.5 0.85 0.5],'edgecolor','none','facealpha',0.5);
            obj.patchhandle.positionBar =  patch('xdata',nan(1,4),'ydata',[0 1 1 0],'parent',obj.axeshandle.secondary,'hittest','off','visible','off','facecolor',[0.5 0.85 0.5],'edgecolor','none','facealpha',0.5);
            
            obj.patchhandle.wear =  patch('xdata',nan(1,4),'ydata',[0 1 1 0],'parent',obj.axeshandle.secondary,'hittest','off','visible','off','facecolor',[0 1 1],'edgecolor','none','facealpha',0.5);
            obj.patchhandle.nonwear =  patch('xdata',nan(1,4),'ydata',[0 1 1 0],'parent',obj.axeshandle.secondary,'hittest','off','visible','off','facecolor',[1 0.45 0],'edgecolor','none','facealpha',0.5);
            
            
            uistack(obj.positionBarHandle,'top');
            uistack(obj.patchhandle.positionBar,'top');
            obj.linehandle.feature = [];
            obj.linehandle.featureCumsum = [];
            
        end

        
        % --------------------------------------------------------------------
        %> @brief Enables the aggregate radio button.  
        %> @note Requires aggregate data exists in the associated
        %> PASensorData object instance variable 
        %> @param obj Instance of PASingleStudyController
        %> @param enableState Optional tag for specifying the 'enable' state. 
        %> - @c 'on' [default]
        %> - @c 'off'
        % --------------------------------------------------------------------
        function enableAggregateRadioButton(obj,enableState)
            if(nargin<2)
                enableState = 'on';
            end
            set(obj.handles.radio_bins,'enable',enableState);
        end
        
        % --------------------------------------------------------------------
        %> @brief Enables the Feature radio button
        %> @param obj Instance of PASingleStudyController
        %> @param enableState Optional tag for specifying the 'enable' state. 
        %> - @c 'on' [default]
        %> - @c 'off'
        % --------------------------------------------------------------------
        function enableFeatureRadioButton(obj,enableState)
            if(nargin<2)
                enableState = 'on';
            end
            set(obj.handles.radio_features,'enable',enableState);
        end
        
        % --------------------------------------------------------------------
        %> @brief Enables the time series radio button.  
        %> @note Requires feature data exist in the associated
        %> PASensorData object instance variable 
        %> @param obj Instance of PASingleStudyController
        %> @param enableState Optional tag for specifying the 'enable' state. 
        %> - @c 'on' [default]
        %> - @c 'off'
        % --------------------------------------------------------------------
        function enableTimeSeriesRadioButton(obj,enableState)
            if(nargin<2)
                enableState = 'on';
            end
            set(obj.handles.radio_time,'enable',enableState);
        end
        
        
        
        % --------------------------------------------------------------------
        %> @brief Appends the new feature to the drop down feature menu.
        %> @param obj Instance of PASingleStudyController
        %> @param newFeature String label to append to the drop down feature menu.
        %> @param newUserData Mixed entry to append to the drop down
        %> feature menu's user data field.
        % --------------------------------------------------------------------
        function appendFeatureMenu(obj,newFeature,newUserData)
            
            featureOptions = get(obj.menuhandle.displayFeature,'string');
            userData = get(obj.menuhandle.displayFeature,'userdata');
            if(~iscell(featureOptions))
                featureOptions = {featureOptions};
                userData = {userData};
            end
            if(isempty(intersect(featureOptions,newFeature)))
                featureOptions{end+1} = newFeature;
                userData{end+1} = newUserData;
                set(obj.menuhandle.displayFeature,'string',featureOptions,'userdata',userData);
            end
        end        
        
        % --------------------------------------------------------------------
        %> @brief Displays the string argument in the view.
        %> @param obj PASensorDataObject Instance of PASensorData
        %> @param sourceFilename String that will be displayed in the view as the source filename when provided.
        % --------------------------------------------------------------------
        function setFilename(obj,sourceFilename)
            set(obj.texthandle.filename,'string',sourceFilename,'visible','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Displays the contents of cellString in the study panel
        %> @param obj PASensorDataObject Instance of PASensorData
        %> @param cellString Cell of string that will be displayed in the study panel.  Each 
        %> cell element is given its own display line.
        % --------------------------------------------------------------------
        function setStudyPanelContents(obj,cellString)
            set(obj.texthandle.studyinfo,'string',cellString,'visible','on');
        end
        
        % --------------------------------------------------------------------
        %> @brief Draws the view
        %> @param obj PASensorDataObject Instance of PASensorData
        % --------------------------------------------------------------------
        function draw(obj)
            % Axes range must occur at the top as it is used to determine
            % the position of text labels.
            axesRange   = obj.accelObj.getCurUncorrectedWindowRange(obj.getSetting('displayType'));
            
            %make it increasing
            if(diff(axesRange)==0)
                axesRange(2) = axesRange(2)+1;
            end
            
            set(obj.axeshandle.primary,'xlim',axesRange);
            
            obj.updatePrimaryAxes(axesRange);
            
            structFieldName =obj.getSetting('displayType');
            lineProps   = obj.accelObj.getStruct('currentdisplay',structFieldName);
            recurseHandleSetter(obj.linehandle.(structFieldName),lineProps);
                        
            offsetProps = obj.accelObj.getStruct('displayoffset',structFieldName);
            offsetStyle.LineStyle = '--';
            offsetStyle.color = [0.6 0.6 0.6];
            offsetProps = appendStruct(offsetProps,offsetStyle);
           
            recurseHandleSetter(obj.referencelinehandle.(structFieldName),offsetProps);
                        
            % update label text positions based on the axes position.
            % So the axes range must be set above this!
            % link the x position with the axis x-position ...
            labelStringStruct = obj.accelObj.getLabel(structFieldName);            
            labelPosStruct = obj.getLabelhandlePosition();
            labelProps = mergeStruct(labelStringStruct,labelPosStruct);             
            recurseHandleSetter(obj.labelhandle.(structFieldName),labelProps);
            
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Calculates the 'position' property of the labelhandle
        %> instance variable.
        %> @param obj Instance of PASingleStudyController.      
        %> @param displayTypeStr String representing the current display
        %> type.  This can be
        %> @li @c time series
        %> @li @c aggregate bins
        %> @li @c Features        
        %> @retval labelPosStruct A struct of 'position' properties that can be assigned
        %> to labelhandle instance variable.
        % --------------------------------------------------------------------
        function labelPosStruct = getLabelhandlePosition(obj,displayTypeStr)
            if(nargin<2 || isempty(displayTypeStr))
                displayTypeStr = obj.getSetting('displayType');
            end
            yOffset = -30; %Trial and error
            dummyStruct = obj.accelObj.getStruct('dummy',displayTypeStr);
            offsetStruct = obj.accelObj.getStruct('displayoffset',displayTypeStr);
            labelPosStruct = structEval('calculateposition',dummyStruct,offsetStruct);
            xOffset = 1/250*diff(get(obj.axeshandle.primary,'xlim'));            
            offset = [xOffset, yOffset, 0];
            labelPosStruct = structScalarEval('plus',labelPosStruct,offset);            
        end

        % --------------------------------------------------------------------
        %> @brief Get the view's line handles as a struct.
        %> @param obj Instance of PASingleStudyController
        %> @param structType String of a subfieldname to access the line
        %> handle of.  (e.g. 'timeSeries')
        %> @retval linehandle View's line handles as a struct.        
        % --------------------------------------------------------------------
        function lineHandle = getLinehandle(obj,structType)
            if(nargin<1 || isempty(structType))
                lineHandle = obj.linehandle;
            else
                lineHandle = obj.linehandle.(structType);
            end
        end
    end
    
    methods(Access=protected)
        function didInit = initContextmenus(obj)
            try
                didInit = false;
                % 1. make context menu handles for the lines
                % 2. make context menu handles for the primary axes

                secondaryAxesContextmenuHandle = obj.createSecondaryAxesContextmenuHandle();
                primaryAxesContextmenuHandle = obj.createPrimaryAxesContextmenuHandle();
                lineContextmenuHandle = obj.createLineContextmenuHandle();
                featureLineContextmenuHandle = obj.createFeatureLineContextmenuHandle();
                    

                set(lineContextmenuHandle,'parent',obj.figureH);
                set(primaryAxesContextmenuHandle,'parent',obj.figureH);
                set(secondaryAxesContextmenuHandle,'parent',obj.figureH);
                set(featureLineContextmenuHandle,'parent',obj.figureH)
                
                obj.contextmenuhandle.primaryAxes = primaryAxesContextmenuHandle;
                obj.contextmenuhandle.secondaryAxes = secondaryAxesContextmenuHandle;
                obj.contextmenuhandle.signals = lineContextmenuHandle;
                obj.contextmenuhandle.featureLine = featureLineContextmenuHandle;
                didInit = true;
                
            catch me
                showME(me);
            end
        end
        
        function didInit = initWidgets(obj)
            obj.initContextmenus();
            
            prefilterSelection = PASensorData.getPrefilterMethods();
            set(obj.menuhandle.prefilterMethod,'string',prefilterSelection,'value',1);
            
            % feature extractor
            extractorStruct = rmfield(PASensorData.getFeatureDescriptionStruct(),'usagestate');
            
            % Don't include the following because these are more
            % complicated ... and require fieldnames to correspond to
            % function names.
            
            %             psd_bandNames = PASensorData.getPSDBandNames();
            %             fieldsToRemove = ['usagestate';psd_bandNames];
            %             for f=1:numel(fieldsToRemove)
            %                 fieldToRemove = fieldsToRemove{f};
            %                 if(isfield(extractorStruct,fieldToRemove))
            %                     extractorStruct = rmfield(extractorStruct,fieldToRemove);
            %                 end
            %             end
                        
            extractorMethodFcns = fieldnames(extractorStruct);
            extractorMethodDescriptions = struct2cell(extractorStruct);
            
            set(obj.menuhandle.displayFeature,'string',extractorMethodDescriptions,'userdata',extractorMethodFcns,'value',1);
            
            %             obj.appendFeatureMenu('PSD','getPSD');
            % set(obj.menuhandle.signalSelection,'string',extractorMethods,'value',1);
            
            % Window display resolution
            windowMinSelection = {
                1,'1 s';
                2,'2 s';
                4,'4 s';
                5,'5 s';
                10,'10 s';
                %30,'30 s';
                % 60,'1 min';
                %120,'2 min';
                300,'5 min';
                600,'10 min';
                900,'15 min';
                1800,'30 min';
                3600,'1 hour';
                7200,'2 hours';
                14400,'4 hours';
                28800,'8 hours';
                43200,'12 hours';
                57600,'16 hours';
                86400,'1 day';
                86400*2,'2 days';
                86400*3,'3 days';
                86400*5,'5 days';
                86400*7,'1 week';
                };
            
            set(obj.menuhandle.windowDurSec,'userdata',cell2mat(windowMinSelection(:,1)), 'string',windowMinSelection(:,2),'value',5);
        
            
            set(obj.handles.edit_curWindow,'callback',@obj.edit_curWindowCallback);
            set(obj.handles.edit_aggregate,'callback',@obj.edit_aggregateCallback);
            set(obj.handles.edit_frameSizeMinutes,'callback',@obj.edit_frameSizeMinutesCallback);
            set(obj.handles.edit_frameSizeHours,'callback',@obj.edit_frameSizeHoursCallback);
            
            %initialize dropdown menu callbacks
            set(obj.menuhandle.displayFeature,'callback',@obj.updateSecondaryFeaturesDisplayCallback);
            set(obj.handles.menu_windowDurSec,'callback',@obj.menu_windowDurSecCallback);
            
            %             set(obj.menuhandle.prefilterMethod,'callback',[]);
            %             set(obj.menuhandle.signalSelection,'callback',[]);
            %             set(obj.menuhandle.signalSelection,'callback',@obj.updateSecondaryFeaturesDisplayCallback);
            
            set(obj.handles.panel_displayButtonGroup,'selectionChangeFcn',@obj.displayChangeCallback);
            
            set(obj.handles.button_go,'callback',@obj.button_goCallback);

            % Clear the figure and such.
            obj.clearAxesHandles();
            obj.clearTextHandles();
            obj.clearWidgets();
            obj.disableWidgets();
            didInit = true;
        end
        
        % --------------------------------------------------------------------
        %> @brief Creates line handles and maps figure tags to PASingleStudyController instance variables.
        %> @param obj Instance of PASingleStudyController.
        %> @note This method does not set the view mode.  Call
        %> refreshView or initView(.) to configure the axes and widgets accordingly.
        % --------------------------------------------------------------------
        function designateHandles(obj)
            designateHandles@PAViewController(obj);
            
            obj.texthandle.curWindow = obj.handles.edit_curWindow;
            obj.texthandle.aggregateDuration = obj.handles.edit_aggregate;
            obj.texthandle.frameDurationMinutes = obj.handles.edit_frameSizeMinutes;
            obj.texthandle.frameDurationHours = obj.handles.edit_frameSizeHours;
            obj.texthandle.trimAmount = obj.handles.edit_aggregate;
            
            obj.panelhandle.controls = obj.handles.panel_timeseries;
            obj.panelhandle.epoch = obj.handles.panel_epochControls;
            obj.panelhandle.dispalyFeatures = obj.handles.panel_displayButtonGroup;
            obj.panelhandle.metaData = obj.handles.panel_study;
            
            obj.menuhandle.windowDurSec = obj.handles.menu_windowDurSec;
            obj.menuhandle.signalSelection = obj.handles.menu_signalSelection;
            obj.menuhandle.prefilterMethod = obj.handles.menu_prefilter;
            obj.menuhandle.displayFeature = obj.handles.menu_displayFeature;
            
            obj.menuhandle.signalSource = obj.handles.menu_signalsource;
            obj.menuhandle.featureSource = obj.handles.menu_feature;
            obj.menuhandle.resultType = obj.handles.menu_plottype;
            
            obj.checkhandle.normalizeResults = obj.handles.check_normalizevalues;
            obj.checkhandle.trimResults = obj.handles.check_trim;
                        
            
            % create a spot for it in the struct;
            obj.patchhandle.feature = [];
        end
        
        
        
        
        %% Widget callbacks          
        % --------------------------------------------------------------------
        %> @brief Configure callbacks for the figure, menubar, and widets.
        %> Called internally during class construction.
        %> @param obj Instance of PAAppController
        % --------------------------------------------------------------------
        function didInit = initCallbacks(obj)
            didInit = true;
            figH = obj.figureH;            
            % mouse and keyboard callbacks
            set(figH,'KeyPressFcn',@obj.keyPressCallback);
            set(figH,'KeyReleaseFcn',@obj.keyReleaseCallback);
            set(figH,'WindowButtonDownFcn',@obj.windowButtonDownCallback);
            set(figH,'WindowButtonUpFcn',@obj.windowButtonUpCallback);            
        end
        
        
        % --------------------------------------------------------------------
        %> @brief  Executes on key press with focus on figure and no controls selected.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to figure (gcf)
        %> @param eventdata Structure of key press information.
        % --------------------------------------------------------------------
        function keyPressCallback(obj,hObject, eventdata)
            % key=double(get(hObject,'CurrentCharacter')); % compare the values to the list
            key=eventdata.Key;
            %             handles = guidata(hObject);
            window = obj.getCurWindow();
            
            if(strcmp(key,'add'))
                
            elseif(strcmp(key,'subtract'))
                
            elseif(strcmp(key,'leftarrow')||strcmp(key,'pagedown'))
                %go backward 1 window
                obj.setCurWindow(window-1);
            elseif(strcmp(key,'rightarrow')||strcmp(key,'pageup'))
                %go forward 1 window
                obj.setCurWindow(window+1);
            elseif(strcmp(key,'uparrow'))
                %go forward 10 windows
                obj.setCurWindow(window+10);
            elseif(strcmp(key,'downarrow'))
                %go back 10 windows
                obj.setCurWindow(window-10);
            end
            
            if(strcmp(eventdata.Key,'shift'))
                set(obj.figureH,'pointer','ibeam');
            end
            if(strcmp(eventdata.Modifier,'control'))
                %kill the program
                if(strcmp(eventdata.Key,'x'))
                    delete(hObject);
                    %take screen capture of figure
                elseif(strcmp(eventdata.Key,'f'))
                    obj.figureScreenshot();
                    %take screen capture of main axes
                elseif(strcmp(eventdata.Key,'s'))
                    if(isa(obj.SingleStudy,'PASingleStudyController') &&ishandle(obj.axeshandle.secondary))
                        obj.screenshotPathname = screencap(obj.axeshandle.secondary,[],obj.screenshotPathname);
                    end
                elseif(strcmp(eventdata.Key,'p'))
                    if(isa(obj.SingleStudy,'PASingleStudyController') &&ishandle(obj.axeshandle.primary))
                        obj.screenshotPathname = screencap(obj.axeshandle.primary,[],obj.screenshotPathname);
                    end
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes on key press with focus on figure and no controls selected.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventdata Structure of key press information.
        % --------------------------------------------------------------------
        function keyReleaseCallback(obj,~, eventdata)            
            key=eventdata.Key;
            if(strcmp(key,'shift'))
                set(obj.figureH,'pointer','arrow');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes when user releases mouse click
        %> If the currentObject selected is the secondary axes, then
        %> the current window is set to the closest window corresponding to
        %> the mouse's x-position.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventData Structure of mouse press information; unused
        % --------------------------------------------------------------------
        function windowButtonUpCallback(obj,hObject,~)
            selected_obj = get(hObject,'CurrentObject');
            if(~isempty(selected_obj) && ~strcmpi(get(hObject,'SelectionType'),'alt'))   % Dont get confused with mouse button up due to contextmenu call
                if selected_obj==obj.axeshandle.secondary && ~isempty(obj.accelObj)
                    pos = get(selected_obj,'currentpoint');
                    clicked_datenum = pos(1);
                    cur_window = obj.accelObj.datenum2window(clicked_datenum,obj.getDisplayType());
                    obj.setCurWindow(cur_window);
                end
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief  Executes when user first clicks the mouse.
        %> @param obj Instance of PAAppController
        %> @param hObject    handle to figure (gcf), unused
        %> @param eventData Structure of mouse press information; unused
        %> @param Note - this turns off all other mouse movement and mouse
        %> wheel callback methods.
        % --------------------------------------------------------------------
        function windowButtonDownCallback(obj,varargin)
            if(ishandle(obj.current_linehandle))
                set(obj.figureH,'windowbuttonmotionfcn',[]);                
                obj.deactivateLineHandle();
            end
        end
        
        function deactivateLineHandle(obj)
            set(obj.current_linehandle,'selected','off');
            obj.current_linehandle = [];
            obj.showReady();
            set(obj.figureH,'windowbuttonmotionfcn',[],'WindowScrollWheelFcn',[]);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for radio button change of the panel_displayButtonGroup handle.
        %> The user can select either, 'time series', 'aggregate bins', or
        %> 'features'.  If 'Features' is selected, then the Feature dropdown
        %> menu is enabled, and is disabled otherwise.  The view is
        %> redrawn.
        %> @param obj Instance of PAController
        %> @param hObject Handle to button group panel.
        %> @param eventData Structure of event data to include:
        %> @li @c EventName 'SelectionChanged'
        %> @li @c OldValue Handle to the previous callback
        %> @li @c NewValue Handle to the current callback
        % --------------------------------------------------------------------
        function displayChangeCallback(obj,~,eventData)
            newDisplayType = get(eventData.NewValue,'string');
            obj.setDisplayType(PASensorData.getStructNameFromDescription(newDisplayType));
            obj.draw();
        end
        
        % --------------------------------------------------------------------
        %> @brief Executes a radio button group callback (i.e.
        %> displayChangeCallback).
        %> @param obj Instance of PAController
        %> @param displayType String value of the radio button to set.  Can be
        %> @li @c timeSeries
        %> @li @c bins
        %> @li @c features
        function setRadioButton(obj,displayTypeStr)
            switch lower(displayTypeStr)
                case 'timeseries'
                    radioH = obj.handles.radio_time;
                case 'bins'
                    radioH = obj.handles.radio_bins;
                case 'features'
                    radioH = obj.handles.radio_features;
                otherwise
                    radioH = [];
                    fprintf('Sorry, (%s) is not a recognized type.\n',displayTypeStr);
            end
            set(radioH,'value',1);
        end
        
        
        
        % --------------------------------------------------------------------
        %> @brief Callback for pressing the Go push button.  Method
        %> determines parameters from current view settings (i.e. menu
        %> selections for prefilter and aggregate methods).
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        % --------------------------------------------------------------------
        function button_goCallback(obj,hObject,~)
            try
                %obtain the prefilter and feature extraction methods
                prefilterMethod = obj.getPrefilterMethod();
                
                %                 set(hObject,'enable','off');
                obj.showBusy('Calculating Features','all');
                % get the prefilter duration in minutes.
                % aggregateDurMin = obj.getAggregateDuration();
                
                %Tell the model to prefilter and extract
                if(~strcmpi(prefilterMethod,'none'))
                    obj.accelObj.prefilter(prefilterMethod);
                    obj.enableAggregateRadioButton();
                    
                    % No point of changing to the bin state right now as we
                    % will be selecting features anyway...
                    %                 displayType = 'bins';
                    %                 obj.setRadioButton(displayType);
                else
                    obj.enableAggregateRadioButton('off');
                end
                
                %extractorMethod = obj.getExtractorMethod();
                extractorMethod = 'all';
                selectedSignalTagLine = obj.getSignalSelection();
                
                obj.accelObj.extractFeature(selectedSignalTagLine,extractorMethod);
                obj.enableFeatureRadioButton();
                
                obj.updateSecondaryFeaturesDisplay();
                % obj.appendFeatureMenu(extractorMethod);
                
                obj.setDisplayType('features');
                
                % This is disabled until the first time features are
                % calculated.
                obj.enableTimeSeriesRadioButton();
                
                obj.draw();
                obj.showReady('all');
                set(hObject,'enable','on');
                
            catch me
                showME(me);
                obj.showReady('all');
                set(hObject,'enable','on');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Updates the secondary axes with the current features selected in the GUI
        %> @param obj Instance of PAController
        %> @param numFeatures Optional number of features to extract (i.e. the number of chunks that the
        %> the study data will be broken into and the current feature
        %> category applied to.  Default is the current frame count.
        %> @retval heightOffset y-axis value of the top of the features
        %> displayed.  This is helpful in determining where to stack
        %> additional items on top of in the secondary axes.
        % --------------------------------------------------------------------
        function heightOffset = updateSecondaryFeaturesDisplay(obj,numFeatures)
            try
                heightOffset = [];
                set(obj.menuhandle.displayFeature,'enable','off');
                initColor = get(obj.handles.axes_secondary,'color');
                obj.showBusy('(Updating secondary display)','secondary');
                if(nargin<2 || isempty(numFeatures))
                    numFeatures = obj.getFrameCount();
                end
                
                featureFcnName = obj.getExtractorMethod();
                
                numViews = obj.numViewsInSecondaryDisplay; %(numel(signalTagLines)+1);
                
                % update secondary axes y labels according to our feature
                % function.
                if(strcmpi(featureFcnName,'psd'))
                    ytickLabels = {'Band 5','Band 4','Band 3','Band 2','Band 1'};
                    signalTags = {'b5','b4','b3','b2','b1'};
                else
                    signalTags = {'x','y','z','vecMag'};
                    ytickLabels = {'X','Y','Z','|X,Y,Z|','|X,Y,Z|'};
                end
                
                %axesHeight = 1;
                if any(strcmpi(obj.getAccelType(),{'count','all'}))
                    ytickLabels = [ytickLabels,'Activity','Lumens','Daylight'];
                else
                    ytickLabels = [ytickLabels,'Activity','Daylight'];
                    %                 deltaHeight = 1/(numViews+1);
                    %                 heightOffset = deltaHeight/2;                    
                end
                
                deltaHeight = 1/numViews;
                heightOffset = 0;
                
                % This has already been updated though?
                obj.updateSecondaryAxesLabels('y',ytickLabels);
                
                %  signalTagLine = obj.getSignalSelection();
                %  obj.drawFeatureVecPatches(featureFcn,signalTagLine,numFrames);
                
                signalTagLines = strcat('accel.',obj.accelTypeShown,'.',signalTags)';
                
                if(any(ishandle(obj.featureHandles)))
                    delete(obj.featureHandles);
                end
                obj.featureHandles = [];
                startStopDatenums = obj.getFeatureStartStopDatenums(featureFcnName,signalTagLines{1},numFeatures);
                
                % Normal behavior is to show each axes for the accelerometer
                % x, y, z, vecMag (i.e. accel.count.x, accel.count.y, ...)
                % However, for the PSD, we assign PSD bands to these axes as
                % 'vecMag' - psd_band_1
                % 'x' - psd_band_2
                % 'y' - psd_band_3
                % 'z' - psd_band_4
                for s=1:numel(signalTagLines)
                    signalName = signalTagLines{s};
                    featureVec = obj.getFeatureVec(featureFcnName,signalName,numFeatures);  %  redundant time stamp calculations benig done for start stpop dateneums in here.
                    
                    % x, y, z
                    if(s<numel(signalTagLines) || (s==numel(signalTagLines)&&strcmpi(featureFcnName,'psd')))
                        vecHandles = obj.addFeaturesVecToSecondaryAxes(featureVec,startStopDatenums,deltaHeight,heightOffset);
                        heightOffset = heightOffset+deltaHeight;
                        
                        % vecMag
                    else
                        % This requires twice the height because it will have a
                        % feature line and heat map
                        [patchH, lineH, cumsumH] = obj.addFeaturesVecAndOverlayToSecondaryAxes(featureVec,startStopDatenums,deltaHeight*2,heightOffset);
                        
                        uistack(patchH,'bottom');
                        
                        vecHandles = [patchH, lineH, cumsumH];
                        heightOffset = heightOffset+deltaHeight*2;
                    end
                    obj.featureHandles = [obj.featureHandles(:);vecHandles(:)];
                end
            catch me
                showME(me);
            end
            
            set(obj.handles.axes_secondary,'color',initColor);
            
            obj.showReady('secondary');
            set(obj.menuhandle.displayFeature,'enable','on');
        end
        
       
        % ======================================================================
        %> @brief Returns a structure of PASingleStudyController's primary axes currently displayable line handles.
        %> @param obj Instance of PASingleStudyController.
        %> @retval lineHandles A structure of line handles of the current display type are
        %> showable in the primary axes (i.e. they are only not seen if the
        %user has set the line handle's 'visible' property to 'off'
        function lineHandles = getDisplayableLineHandles(obj)
            lineHandleStruct = obj.getLinehandle(obj.getDisplayType());
            lineHandles = struct2vec(lineHandleStruct);
        end  
        
        % --------------------------------------------------------------------
        %> @brief Retrieves current prefilter method from the GUI
        %> @param obj Instance of PAController
        %> @retval prefilterMethod value of the current prefilter method.
        % --------------------------------------------------------------------
        function prefilterMethod = getPrefilterMethod(obj)
            prefilterMethods = get(obj.menuhandle.prefilterMethod,'string');
            prefilterIndex =  get(obj.menuhandle.prefilterMethod,'value');
            if(~iscell(prefilterMethods))
                prefilterMethod = prefilterMethods;
            else
                prefilterMethod = prefilterMethods{prefilterIndex};
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves current extractor method (i.e. function name) associated with the GUI displayed description.
        %> @param obj Instance of PAController
        %> @retval extractorMethod String value of the function call represented by
        %> the current feature extraction method displayed in the VIEW's displayFeature drop down menu.
        %> @note Results of applying the extractor method to the current
        %> signal (selected from its dropdown menu) are displayed in the
        %> secondary axes of PASingleStudyController.
        % --------------------------------------------------------------------
        function extractorMethodName = getExtractorMethod(obj)
            extractorFcns = get(obj.menuhandle.displayFeature,'userdata');
            extractorIndex =  get(obj.menuhandle.displayFeature,'value');
            if(~iscell(extractorFcns))
                extractorMethodName = extractorFcns;
            else
                extractorMethodName = extractorFcns{extractorIndex};
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Sets the extractor method (i.e. function name) associated with the GUI displayed description.
        %> @param obj Instance of PAController
        %> @param featureFcn String value of the function call represented by
        %> the current feature extraction method displayed in the VIEW's displayFeature drop down menu.
        %> @note No change is made if featureFcn is not found listed in
        %> menu handle's userdata.
        % --------------------------------------------------------------------
        function setExtractorMethod(obj,featureFcn)
            extractorFcns = get(obj.menuhandle.displayFeature,'userdata');
            extractorInd = find(strcmpi(extractorFcns,featureFcn));
            if(~isempty(extractorInd))
                set(obj.menuhandle.displayFeature,'value',extractorInd);
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Returns the accelType parameter of the accelObj object
        %> when it exists and 'none' otherwise.
        %> @param obj Instance of PAController
        %> @retval accelType String value that can be:
        %> - @c all
        %> - @c raw
        %> - @c count
        %> - @c none (not loaded)
        % --------------------------------------------------------------------
        function accelType = getAccelType(obj)
            accelType = 'none';
            if(~isempty(obj.accelObj))
                accelType = obj.accelObj.accelType;
            end            
        end
        
        % --------------------------------------------------------------------
        %> @brief Retrieves current signal selection from the GUI's
        %> signalSelection dropdown menu.
        %> @param obj Instance of PAController
        %> @retval signalSelection The tag line of the selected signal.
        % --------------------------------------------------------------------
        function signalSelection = getSignalSelection(obj)
            signalSelections = get(obj.menuhandle.signalSelection,'userdata');
            selectionIndex =  get(obj.menuhandle.signalSelection,'value');
            if(~iscell(signalSelections))
                signalSelection= signalSelections;
            else
                signalSelection = signalSelections{selectionIndex};
            end
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Sets the Signal Selection's drop down menu's value based on
        %> the input parameter.
        %> @param obj Instance of PAController.
        %> @param signalTagLine String representing the tag line associated with each
        %> signal choice selection and listed as dropdown menus userdata.
        %> @note No change is made if signalTagLine is not found listed in
        %> menu handle's userdata.
        % --------------------------------------------------------------------
        function signalTagLine = setSignalSelection(obj, signalTagLine)
            signalTagLines = get(obj.menuhandle.signalSelection,'userdata');
            selectionIndex = find(strcmpi(signalTagLines,signalTagLine)) ;
            if(isempty(selectionIndex))
                selectionIndex = 1;
                signalTagLine = signalTagLines{selectionIndex};
            end
            
            set(obj.menuhandle.signalSelection,'value',selectionIndex);
            if(isempty(obj.accelTypeShown))
                obj.accelTypeShown = 'count';
            end
            
            if(~isempty(signalTagLines))
                v=regexp(signalTagLines{selectionIndex},'.+\.([^\.]+)\..*','tokens');
                if(~isempty(v))
                    obj.accelTypeShown = v{1}{1};
                end
            end
            %             obj.settingsObj.CONTROLLER.signalTagLine = signalTagLine;
        end
        
        % --------------------------------------------------------------------
        %> @brief Initializes the signal selection drop down menu using PASensorData's
        %> default taglines and associated labels.
        %> signalSelection dropdown menu.
        %> @param obj Instance of PAController
        %> @note Tag lines are stored as user data at indices corresponding
        %> to the menu label descriptions.  For example, label{1} = 'X' and
        %> userdata{1} = 'accelRaw.x'
        % --------------------------------------------------------------------
        function initSignalSelectionMenu(obj)
            [tagLines,labels] = PASensorData.getDefaultTagLineLabels();
            accelType = obj.getAccelType;
            if isempty(accelType) || strcmpi(accelType, 'none')
                set(obj.menuhandle.signalSelection,'string','Nothing loaded','userdata',[],'value',0);
            else
                
                cellIndices = strfind(tagLines,accelType);
                pruneIndices = false(size(cellIndices));
                for k=1:numel(cellIndices)
                    pruneIndices(k) = isempty(cellIndices{k});
                end
                labels(pruneIndices) = [];
                tagLines(pruneIndices) = [];                
                set(obj.menuhandle.signalSelection,'string',labels,'userdata',tagLines,'value',1);                
            end
%             offAccelType = obj.accelObj.getOffAccelType();
%             if(~isempty(offAccelType))
%                 cellIndices = strfind(tagLines,offAccelType);
%                 pruneIndices = false(size(cellIndices));
%                 for k=1:numel(cellIndices)
%                     pruneIndices(k) = ~isempty(cellIndices{k});
%                 end
%                 labels(pruneIndices) = [];
%                 tagLines(pruneIndices) = [];
%             end
%             set(obj.menuhandle.signalSelection,'string',labels,'userdata',tagLines,'value',1);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for menu with window duration selections (values
        %> are in seconds)
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        % --------------------------------------------------------------------
        function menu_windowDurSecCallback(obj,hObject,~)
            % get the current window size selection in seconds
            windowDurSec = getMenuUserData(hObject);
            
            %change it - this internally recalculates the cur window
            obj.accelObj.setWindowDurSec(windowDurSec);
            newWindow = obj.accelObj.getCurWindow();
            obj.setCurWindow(newWindow);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for current window's edit textbox.
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        % --------------------------------------------------------------------
        function edit_curWindowCallback(obj,hObject,~)
            window = str2double(get(hObject,'string'));
            obj.setCurWindow(window);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for aggregate size edit textbox.
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        %> @note Entered values are interepreted as minutes.
        % --------------------------------------------------------------------
        function edit_aggregateCallback(obj,hObject,~)
            aggregateDuration = str2double(get(hObject,'string'));
            obj.setAggregateDurationMinutes(aggregateDuration);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for frame size in minutes edit textbox.
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        %> @note Entered values are interepreted as minutes.
        % --------------------------------------------------------------------
        function edit_frameSizeMinutesCallback(obj,hObject,~)
            frameDurationMinutes = str2double(get(hObject,'string'));
            obj.setFrameDurationMinutes(frameDurationMinutes);
        end
        
        % --------------------------------------------------------------------
        %> @brief Callback for frame size in hours edit textbox.
        %> @param obj Instance of PAController
        %> @param hObject Handle to the edit text widget
        %> @param eventdata Required by MATLAB, but not used
        %> @note Entered values are interepreted as hours.
        % --------------------------------------------------------------------
        function edit_frameSizeHoursCallback(obj,hObject,~)
            frameDurationHours = str2double(get(hObject,'string'));
            obj.setFrameDurationHours(frameDurationHours);
        end
        
        
        % --------------------------------------------------------------------
        %> @brief Callback from signal selection widget that triggers
        %> the update to the secondary axes with the GUI selected feature
        %> and signal.
        %> @param obj Instance of PAController
        %> @param hObject handle to the callback object.
        %> @param eventdata Not used.  Required by MATLAB.
        % --------------------------------------------------------------------
        function updateSecondaryFeaturesDisplayCallback(obj,hObject,~)
            obj.updateSecondaryFeaturesDisplay();            
        end
                
   
        
        %% context menus for the view
        % =================================================================
        %> @brief Configure contextmenu for view's primary axes.
        %> @param obj instance of PAController.
        %> @retval contextmenu_mainaxes_h A contextmenu handle.  This should
        %> be assigned to the primary axes handle of PASingleStudyController.
        % =================================================================
        function contextmenu_mainaxes_h = createPrimaryAxesContextmenuHandle(obj)
            %%% reference line contextmenu
            contextmenu_mainaxes_h = uicontextmenu('parent',obj.figureH);
            uimenu(contextmenu_mainaxes_h,'Label','Display settings','tag','singleStudy_displaySettings','callback',...
                @obj.singleStudyDisplaySettingsCb);
            hideH =uimenu(contextmenu_mainaxes_h,'Label','Hide','tag','hide','separator','on');
            unhideH = uimenu(contextmenu_mainaxes_h,'Label','Unhide','tag','unhide');
            uimenu(contextmenu_mainaxes_h,'Label','Evenly distribute lines','tag','redistribute',...
                'separator','on','callback',@obj.cmenuRedistributeLinesCb);
            set(contextmenu_mainaxes_h,'callback',{@obj.cmenuPrimaryAxesCb,hideH,unhideH});      
        end
        
        % =================================================================
        %> @brief Configure contextmenu for view's secondary axes.
        %> @param obj instance of PAController.
        %> @retval contextmenu_secondary_h A contextmenu handle.  This should
        %> be assigned to the primary axes handle of PASingleStudyController.
        % =================================================================
        function contextmenu_secondaryAxes_h = createSecondaryAxesContextmenuHandle(obj)
            %%% reference line contextmenu
            contextmenu_secondaryAxes_h = uicontextmenu('parent',obj.figureH);
            
            menu_h = uimenu(contextmenu_secondaryAxes_h,'Label','Nonwear highlighting','tag','nonwear');
            nonwearHighlighting_on_menu_h =uimenu(menu_h,'Label','On','tag','nonwear_on','callback',{@obj.cmenuNonwearHighlightingCb,true});
            nonwearHighlighting_off_menu_h = uimenu(menu_h,'Label','Off','tag','nonwear_off','callback',{@obj.cmenuNonwearHighlightingCb,false});
            set(menu_h,'callback',{@obj.cmenuConfigureNonwearHighlightingCb,nonwearHighlighting_on_menu_h,nonwearHighlighting_off_menu_h});

            menu_h = uimenu(contextmenu_secondaryAxes_h,'Label','Line Smoothing','tag','smoothing');
            on_menu_h =uimenu(menu_h,'Label','On','tag','smoothing_on','callback',{@obj.cmenuFeatureSmoothingCb,true});
            off_menu_h = uimenu(menu_h,'Label','Off','tag','smoothing_off','callback',{@obj.cmenuFeatureSmoothingCb,false});
            set(menu_h,'callback',{@obj.cmenuConfigureSmoothingCb,on_menu_h,off_menu_h});
        end
        
        % =================================================================
        %> @brief Configure contextmenu for signals that will be drawn in the view.
        %> @param obj instance of PAController.
        %> @retval uicontextmenu_handle A contextmenu handle.  This should
        %> be assigned to the line handles drawn by the PAController and
        %> PASingleStudyController classes.
        % =================================================================
        function uicontextmenu_handle = createLineContextmenuHandle(obj)
            % --------------------------------------------------------------------
            uicontextmenu_handle = uicontextmenu('callback',@obj.contextmenuLineCb,'parent',obj.figureH);%,get(parentAxes,'parent'));
            uimenu(uicontextmenu_handle,'Label','Resize','separator','off','callback',@obj.contextmenuLineResizeCb);
            uimenu(uicontextmenu_handle,'Label','Use Default Scale','separator','off','callback',@obj.contextmenuLineDefaultScaleCb,'tag','defaultScale');
            uimenu(uicontextmenu_handle,'Label','Move','separator','off','callback',@obj.contextmenuLineMoveCb);
            uimenu(uicontextmenu_handle,'Label','Change Color','separator','off','callback',@obj.contextmenuLineColorCb);
            %            uimenu(uicontextmenu_handle,'Label','Add Reference Line','separator','on','callback',@obj.contextmenu_line_referenceline_callback);
            %            uimenu(uicontextmenu_handle,'Label','Align Channel','separator','off','callback',@obj.align_channels_on_axes);
            uimenu(uicontextmenu_handle,'Label','Hide','separator','on','callback',@obj.cmenuLineHideCb);
            uimenu(uicontextmenu_handle,'Label','Copy entire signal to clipboard','separator','on','callback',{@obj.contextmenuLine2ClipboardCb,'clipboard'}, 'tag','copy_line2clipboard');
            uimenu(uicontextmenu_handle,'Label','Copy current window to clipboard','separator','off','callback',{@obj.contextmenuLine2ClipboardCb,'clipboard'}, 'tag','copy_window2clipboard');
            
            if ~isdeployed
                uimenu(uicontextmenu_handle,'Label','Export entire signal to workspace','separator','on','callback',{@obj.contextmenuLine2ClipboardCb, 'workspace'},'tag','export_line2clipboard');
                uimenu(uicontextmenu_handle,'Label','Export current window to workspace','separator','off','callback',{@obj.contextmenuLine2ClipboardCb, 'workspace'},'tag','export_window2clipboard');
            end
            % uimenu(uicontextmenu_handle,'Label','Copy window to clipboard','separator','off','callback',@obj.contextmenuWindow2ClipboardCb,'tag','copy_window2clipboard');
        end
        
        % =================================================================
        %> @brief Configure contextmenu for feature line which is drawn in the secondary axes.
        %> @param obj instance of PAController.
        %> @retval uicontextmenu_handle A contextmenu handle.  This should
        %> be assigned to the line handles drawn by the PAController and
        %> PASingleStudyController classes.
        % =================================================================
        function uicontextmenu_handle = createFeatureLineContextmenuHandle(obj)
            uicontextmenu_handle = uicontextmenu('parent',obj.figureH);%,get(parentAxes,'parent'));
            uimenu(uicontextmenu_handle,'Label','Copy to clipboard','separator','off','callback',@obj.contextmenuLine2ClipboardCb,'tag','copy_line2clipboard');
        end
        
        
        %         function setLinehandle(obj, line_h)
        %             obj.showReady();
        %             obj.current_linehandle = line_h;
        %             set(obj.current_linehandle,'selected','on');
        %         end
        
        % =================================================================
        %> @brief Contextmenu callback for primary axes line handles
        %> @param obj instance of PAController
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function contextmenuLineCb(obj,hObject,~)
            %parent context menu that pops up before any of the children contexts are
            %drawn...
            %             parent_fig = get(hObject,'parent');
            %             obj_handle = get(parent_fig,'currentobject');
            obj.current_linehandle = gco;
            set(gco,'selected','on');
            
            lineTag = get(gco,'tag');
            set(obj.texthandle.status,'string',lineTag);
            
            child_menu_handles = get(hObject,'children');  %this is all of the handles of the children menu options
            
            % default_scale_handle = child_menu_handles(find(~cellfun('isempty',strfind(get(child_menu_handles,'tag'),'defaultScale')),1));
            default_scale_handle = child_menu_handles(find(contains(get(child_menu_handles,'tag'),'defaultScale'),1));
            
            % lineTag options are returned as scalars
            lineScale = obj.accelObj.getScale(lineTag);
            
            % Default values are returned with scalars at end
            pStruct = PASensorData.getDefaults(); %#ok<NASGU>
            
            defaultScale = eval(strcat('pStruct.scale.',lineTag));
% 
%             if verLessThan('matlab','9.3')
%                 curScale = eval(['allScale.',lineTag]);
%                 defaultScale = eval(strcat('pStruct.scale.',lineTag));
%             else
%                 curScale = allScale.(lineTag);
%                 defaultScale = pStruct.scale.(lineTag);
%             end
            
            if(lineScale==defaultScale)
                set(default_scale_handle,'Label',sprintf('Default Scale (%0.2f)',lineScale))
                set(default_scale_handle,'checked','on');
            else
                set(default_scale_handle,'Label',sprintf('Use Default Scale (%0.2f)',lineScale))
                set(default_scale_handle,'checked','off');
            end

        end
        
        % =================================================================
        %> @brief A line handle's contextmenu 'move' callback.
        %> @param obj instance of PAController.
        %> @param hObject gui handle object
        %> @param eventdata unused
        % =================================================================
        function contextmenuLineMoveCb(obj,varargin)
            y_lim = get(obj.axeshandle.primary,'ylim');
            
            tagLine = get(gco,'tag');
            set(obj.figureH,'pointer','hand',...
                'windowbuttonmotionfcn',...
                {@obj.moveLineMouseFcnCb,tagLine,y_lim}...
                );
        end
        
        % =================================================================
        %> @brief Channel contextmenu callback to move the selected
        %> channel's position in the SEV.
        %> @param obj instance of CLASS_channels_container.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        %> @param lineTag The tag for the current selected linehandle.
        %> @note lineTag = 'timeSeries.accelCount.x'
        %> This is used for dynamic indexing into the accelObj's datastructs.
        %> @param y_lim Y-axes limits; cannot move the channel above or below
        %> these bounds.
        %> @retval obj instance of CLASS_channels_container.
        % =================================================================
        function moveLineMouseFcnCb(obj,~,~,lineTag,y_lim)
            %windowbuttonmotionfcn set by contextmenuLineMoveCb
            %axes_h is the axes that the current object (channel_object) is in
            pos = get(obj.axeshandle.primary,'currentpoint');
            curOffset = max(min(pos(1,2),y_lim(2)),y_lim(1));
            obj.accelObj.setOffset(lineTag,curOffset);            
            obj.draw();
        end
        
        % =================================================================
        %> @brief Resize callback for channel object contextmenu.
        %> @param obj instance of CLASS_channels_container.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        %> @retval obj instance of CLASS_channels_container.
        % =================================================================
        function contextmenuLineResizeCb(obj,varargin)
            
            lineTag = get(gco,'tag');
            set(obj.figureH,'pointer','crosshair','WindowScrollWheelFcn',...
                {@obj.resizeWindowScrollWheelFcnCb,...
                lineTag,obj.texthandle.status});
            
            curScale = obj.accelObj.getScale(lineTag);
            % curScale = eval(['allScale.',lineTag]);
            
            %show the current scale
            click_str = sprintf('Scale: %0.2f',curScale);
            set(obj.texthandle.status,'string',click_str);
            
            %flush the draw queue
            drawnow();
        end
        
        % =================================================================
        %> @brief Contextmenu callback to set a line's default scale.
        %> @param obj instance of PAController
        %> @param hObject gui handle object
        %> @param eventdata unused
        % =================================================================
        function contextmenuLineDefaultScaleCb(obj,hObject,~)
            
            if(strcmp(get(hObject,'checked'),'off'))
                set(hObject,'checked','on');
                lineTag = get(gco,'tag');
                
                pStruct = PASensorData.getDefaults(); %#ok<NASGU>
                % defaultScale = pStruct.scale.(lineTag); %
                defaultScale = eval(strcat('pStruct.scale.',lineTag));
                
                obj.accelObj.setScale(lineTag,defaultScale);
                %obj.draw();
            end
            set(gco,'selected','off');
        end
        
        
        % =================================================================
        %> @brief Contextmenu callback to set a line's color.  MATLAB's
        %> interactive dialog is used to obtain and set the color
        %> (uisetcolor).
        %> @param obj instance of PAController
        %> @param hObject gui handle object
        %> @param eventdata unused
        % =================================================================
        function contextmenuLineColorCb(obj, varargin)
            lineTag = get(gco,'tag');
            c = get(gco,'color');
            c = uisetcolor(c,lineTag);
            if(numel(c)~=1)
                obj.accelObj.setColor(lineTag,c);
                %tagHandles = findobj(get(gco,'parent'),'tag',lineTag);
                %set(tagHandles,'color',c);
            end
            set(gco,'selected','off');
        end
        
        function linePropertyChangeCallback(obj, accelObj, evtData)
            
            if(strcmpi(evtData.name,'scale'))
                obj.draw();
            elseif(strcmpi(evtData.name,'label'))
                textHandle = findobj(obj.figureH,'tag',evtData.lineTag,'type','text');
                set(textHandle,'string',evtData.value);
            else
                tagHandles = findobj(obj.figureH,'tag',evtData.lineTag);
                set(tagHandles,evtData.name,evtData.value);
            end
        end
        
        % =================================================================
        %> @brief Mouse wheel callback to resize the selected channel.
        %> @param obj instance of PAController.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Mouse scroll event data.
        %> @param lineTag The tag for the current selected linehandle.
        %> @note lineTag = 'timeSeries.accelCount.x'
        %> This is used for dynamic indexing into the accelObj's datastructs.
        %> @param text_h Text handle for outputing the channel's size/scale.
        % =================================================================
        function resizeWindowScrollWheelFcnCb(obj,~,eventdata,lineTag,text_h)
            %the windowwheelscrollfcn set by contextmenuLineResizeCb
            %it is used to adjust the size of the selected channel object (channelObj)
            scroll_step = 0.05;
            lowerbound = 0.01;
            
            %kind of hacky
            curScale = obj.accelObj.getScale(lineTag);
            % curScale = eval(['allScale.',lineTag]);
            
            
            newScale = max(lowerbound,curScale-eventdata.VerticalScrollCount*scroll_step);
            obj.accelObj.setScale(lineTag,newScale);  % setScale results in an VIEW.draw call already.  %obj.draw();
            
            %update this text scale...
            click_str = sprintf('Scale: %0.2f',newScale);
            set(text_h,'string',click_str);
        end
        
        % =================================================================
        %> @brief Copy the selected linehandle's ydata to the system
        %> clipboard.
        %> @param obj Instance of PAController
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        %> @param exportOption Optional tag, if 'workspace' then the data is sent to the MATLAB workspace instead of the clipboard
        %> followed by a popup window showing which variable it was exported to.
        % =================================================================
        function contextmenuLine2ClipboardCb(obj,hObject, ~, exportOption)
            menuTag = get(hObject,'tag');
            tagLine = get(gco,'tag');
            parentH = get(gco,'parent');
            
            % get the siblings handles with same tagLine (e.g. label and
            % rereference line handles.
            h = findobj(parentH,'tag',tagLine,'linestyle','-','type','line');
            data = obj.accelObj.getSignalFromTagLine(tagLine);
                                   
            % copy_window2clipboard or export_window2clipboard
            if contains(menuTag, 'window')
                ax = get(h,'parent');
                x_range = round(get(ax, 'xlim'));
                data = data(x_range(1):x_range(2));
            end
            
            % data =get(h(1),'ydata');
            
            if nargin >= 4 && strcmpi(exportOption, 'workspace')
                tokens = strsplit(tagLine, '.');
                copy2workspace(data, [tokens{end},'Data']);
            else                
                clipboard('copy',data);
                disp([num2str(numel(data)),' items copied to the clipboard.  Press Control-V to access data items, or type "str=clipboard(''paste'')"']);
            end
            obj.deactivateLineHandle();
        end
        
        % =================================================================
        %> @brief configures a contextmenu selection to be hidden or to have
        %> attached uimenus with labels of unhidden signals displayed for selection. (if seleceted, the signal is then hidden)
        %> @param obj instance of PAController.
        %> @param contextmenu_h Handle of parent contextmenu to unhide
        %> channels.
        %> @param eventdata Unused.
        % =================================================================
        function cmenuConfigureHideSignals(obj,contextmenu_h)
            % --------------------------------------------------------------------
            % start with a clean slate
            delete(get(contextmenu_h,'children'));
            set(contextmenu_h,'enable','off');
            lineHandles = obj.getDisplayableLineHandles();
            hasVisibleSignals = false;
            for h=1:numel(lineHandles)
                lineH = lineHandles(h);
                if(~strcmpi(get(lineH,'visible'),'off'))
                    tagLine = get(lineH,'tag');
                    set(contextmenu_h,'enable','on');
                    uimenu(contextmenu_h,'Label',tagLine,'separator','off','callback',{@obj.hideLineHandleCb,lineH});
                    hasVisibleSignals = true;
                end
            end
            set(gco,'selected','off');
            if(~hasVisibleSignals)
                set(contextmenu_h,'visible','off');
            else
                set(contextmenu_h,'visible','on');
            end
        end
        
        % =================================================================
        %> @brief configures a contextmenu selection to be hidden or to have
        %> attached uimenus with labels of hidden signalss displayed.
        %> @param obj instance of PAController.
        %> @param contextmenu_h Handle of parent contextmenu to unhide
        %> channels.
        %> @param eventdata Unused.
        % =================================================================
        function cmenuConfigureUnhideSignals(obj,contextmenu_h)
            % --------------------------------------------------------------------
            % start with a clean slate
            delete(get(contextmenu_h,'children'));
            set(contextmenu_h,'enable','off');
            lineHandles = obj.getDisplayableLineHandles();
            hasHiddenSignals = false;
            for h=1:numel(lineHandles)
                lineH = lineHandles(h);
                if(strcmpi(get(lineH,'visible'),'off'))
                    tagLine = get(lineH,'tag');
                    set(contextmenu_h,'enable','on');
                    uimenu(contextmenu_h,'Label',tagLine,'separator','off','callback',{@obj.showLineHandleCb,lineH});
                    hasHiddenSignals = true;
                end
            end
            set(gco,'selected','off');
            if(~hasHiddenSignals)
                set(contextmenu_h,'visible','off');
            else
                set(contextmenu_h,'visible','on');
            end
        end
        
        % --------------------------------------------------------------------
        %> @brief Set's the visible property for the specified line handle
        %> and its associated reference and label handles to 'on'.
        %> @param obj Instance of PAController
        %> @param hObject Handle of the callback object.
        %> @param eventdata Unused.
        %> @param lineHandle Line handle to be shown.
        % --------------------------------------------------------------------
        function showLineHandleCb(obj,~,~,lineHandle)
            % --------------------------------------------------------------------
            lineTag = get(lineHandle,'tag');
            tagHandles = findobj(get(lineHandle,'parent'),'tag',lineTag);
            set(tagHandles,'visible','on','hittest','on')
            obj.accelObj.setVisible(lineTag,'on');
            set(gco,'selected','off');
        end
        
        % --------------------------------------------------------------------
        %> @brief Set's the visible property for the specified line handle
        %> and its associated reference and label handles to 'off'.
        %> @param obj Instance of PAController
        %> @param hObject Handle of the callback object.
        %> @param eventdata Unused.
        %> @param lineHandle Line handle to be shown.
        % --------------------------------------------------------------------
        function hideLineHandleCb(obj,~,~,lineHandle)
            % --------------------------------------------------------------------
            lineTag = get(lineHandle,'tag');
            tagHandles = findobj(get(lineHandle,'parent'),'tag',lineTag);
            set(tagHandles,'visible','off','hittest','off')
            obj.accelObj.setVisible(lineTag,'off');
            set(gco,'selected','off');
        end
        
        % =================================================================
        %> @brief Channel contextmenu callback to hide the selected
        %> channel.
        %> @param hObject Handle of callback object (unused).
        %> @param eventdata Unused.
        % =================================================================
        function cmenuLineHideCb(obj,varargin)
            tagLine = get(gco,'tag');
            parentH = get(gco,'parent');
            obj.accelObj.setVisible(tagLine,'off');
            
            % get the siblings handles with same tagLine (e.g. label and
            % rereference line handles.
            h = findobj(parentH,'tag',tagLine);
            set(h,'visible','off','hittest','off'); % turn the hittest off so I can access contextmenus when clicking over the unseen line.
            set(gco,'selected','off');
        end
        
        % --------------------------------------------------------------------
        function cmenuPrimaryAxesCb(obj,~,~, hide_uimenu_h, unhide_uimenu_h)
            %configure sub contextmenus
            obj.cmenuConfigureUnhideSignals(unhide_uimenu_h);
            obj.cmenuConfigureHideSignals(hide_uimenu_h);
            if(isempty(get(hide_uimenu_h,'children')))
                set(unhide_uimenu_h,'separator','on');
            else
                set(unhide_uimenu_h,'separator','off');
            end
        end
        
        %> @brief Want to redistribute or evenly distribute the lines displayed in
        %> this axis.
        function cmenuRedistributeLinesCb(obj, varargin)
            obj.redistributePrimaryAxesLineHandles();
        end
        
        % =================================================================
        %> @brief Invoke dialog settings for configuring primary axis of
        %> single study view mode.
        %> @param obj instance of PAController.
        %> @param hMenu instance of handle class.  The contextmenu's menu.
        
        % =================================================================
        function singleStudyDisplaySettingsCb(obj, varargin)
            PASensorDataLineSettings(obj.accelObj,obj.getDisplayType(), obj.getDisplayableLineHandles());
        end
        
        % =================================================================
        %> @brief Configure Line Smoothing sub contextmenus for view's secondary axes.
        %> @param obj instance of PAController.
        %> @param hObject Handle to the Line Smoothing context menu
        %> @param eventdata Not used
        %> @param on_uimenu_h Handle to Smoothing on menu option
        %> @param off_uimenu_h Handle to smoothing off menu option
        % =================================================================
        % --------------------------------------------------------------------
        function cmenuConfigureSmoothingCb(obj,~,~, on_uimenu_h, off_uimenu_h)
            %configure sub contextmenus
            if(obj.getUseSmoothing())
                set(on_uimenu_h,'checked','on');
                set(off_uimenu_h,'checked','off');
            else
                set(on_uimenu_h,'checked','off');
                set(off_uimenu_h,'checked','on');                
            end 
        end
        
        % =================================================================
        %> @brief Contextmenu selection callback for turning line smoothing 'on' or 'off'
        %> in the secondary axes when looking at time series data.
        %> @param obj instance of PAController.
        %> @param contextmenu_h Handle of parent contextmenu to unhide
        %> channels.
        %> @param eventdata Unused.
        %> @param useSmoothingState Boolean flag for smoothing state
        %> - @c true  : Turn smoothing on (default)
        %> - @c false : Turn smoothing off
        % =================================================================
        function cmenuFeatureSmoothingCb(obj,~,~,useSmoothing)
            % --------------------------------------------------------------------
            if(nargin<4)
                useSmoothing = true;
            end
            obj.setSmoothingState(useSmoothing == true);
        end
        
        function setSmoothingState(obj,smoothingState)
            if(nargin>1 && ~isempty(smoothingState))  
                obj.setUseSmoothing(smoothingState); 
                if(~isempty(obj.accelObj))
                    obj.showBusy('Setting smoothing state','secondary');
                    obj.updateSecondaryFeaturesDisplay();
                    obj.showReady('secondary');
                end
            end
        end
        
        % =================================================================
        %> @brief Configure nonwear highlighting sub contextmenus for view's secondary axes.
        %> @param on_uimenu_h Handle to Smoothing on menu option
        %> @param off_uimenu_h Handle to smoothing off menu option
        % =================================================================
        function cmenuConfigureNonwearHighlightingCb(obj,~,~, on_uimenu_h, off_uimenu_h)
            %configure sub contextmenus
            if(obj.getSetting('highlightNonwear'))
                set(on_uimenu_h,'checked','on');
                set(off_uimenu_h,'checked','off');
            else
                set(on_uimenu_h,'checked','off');
                set(off_uimenu_h,'checked','on');                
            end 
        end
        
        % =================================================================
        %> @brief Contextmenu selection callback for turning line smoothing 'on' or 'off'
        %> in the secondary axes when looking at time series data.
        %> @param obj instance of PAController.
        %> @param contextmenu_h Handle of parent contextmenu to unhide
        %> channels.
        %> @param eventdata Unused.
        %> @param useSmoothingState Boolean flag for smoothing state
        %> - @c true  : Turn smoothing on (default)
        %> - @c false : Turn smoothing off
        % =================================================================
        function cmenuNonwearHighlightingCb(obj,~,~,highlightNonwear)
            if(nargin<4)
                highlightNonwear = true;
            end
            obj.setNonwearHighlighting(highlightNonwear == true);
        end
        
        function setNonwearHighlightingCb(obj,highlightNonwear)
            if(nargin>1 && ~isempty(highlightNonwear))  
                obj.setNonwearHighlighting(highlightNonwear); 
                if(~isempty(obj.accelObj))
                    obj.showBusy('Highlighting nonwear','secondary');
                    obj.showReady('secondary');
                end
            end
        end        
    end
    
    methods(Static)
      
        
        % --------------------------------------------------------------------
        %> @brief Adds a feature vector as a heatmap and as a line plot to the
        %> specified axes
        %> @param featureVector The vector of features to be displayed.
        %> @param startStopDatenum A vector of start and stop date nums that
        %> correspond to the start and stop times of the study that the
        %> feature in featureVector at the same index corresponds to.
        %> @param overlayHeight - The proportion (fraction) of vertical space that the
        %> overlay will take up in the axes.
        %> @param overlayOffset The normalized y offset ([0, 1]) that is applied to
        %> the featureVector when displayed on the axes. 
        %> @param axesH Handle of the axes to assign features to.
        %> @param useSmoothing Boolean flag to set if feature vector should
        %> be applied (true) or not (false) before display.
        %> @param contextmenuH Optional contextmenu handle.  Is assigned to the overlayLineH lines
        %> contextmenu callback when included.  
        %> @retval feature_patchH Patch handle of feature
        %> @retval feature_lineH Line handle of feature
        %> @retval feature_cumsumLineH Line handle of cumulative sum of feature        
        % --------------------------------------------------------------------
        function [feature_patchH, feature_lineH, feature_cumsumLineH] = addFeaturesVecAndOverlayToAxes(axesH, featureVector, startStopDatenum, overlayHeight, overlayOffset, useSmoothing,contextmenuH)
            if(nargin<7)
                contextmenuH = [];
                if(nargin<6 || isempty(useSmoothing))
                    useSmoothing = true;
                end
            end
            
            yLim = get(axesH,'ylim');
            yLimPatches = (yLim+1)*overlayHeight/2+overlayOffset;
            
            %             minColor = [.0 0.25 0.25];
            minColor = [0.1 0.1 0.1];
            
            %             maxValue = max(featureVector);
            maxValue = featureVector(ceil(numel(featureVector)*0.90));
            % maxValue = quantile(featureVector,0.90); % requires stats toolbox 
            nFaces = numel(featureVector);
            
            x = nan(4,nFaces);
            y = repmat(yLimPatches([1 2 2 1])',1,nFaces);
            vertexColor = nan(4,nFaces,3);
            
            % each column represent a face color triplet            
            featureColorMap = (featureVector/maxValue)*[1,1,1]+ repmat(minColor,nFaces,1);
       
            % patches are drawn clock wise in matlab
            
            for f=1:nFaces
                if(f==nFaces)
                    vertexColor(:,f,:) = featureColorMap([f,f,f,f],:);
                else
                    vertexColor(:,f,:) = featureColorMap([f,f,f+1,f+1],:);
                end
                x(:,f) = startStopDatenum(f,[1 1 2 2])';
            end            
            
            feature_patchH = patch(x,y,vertexColor,'parent',axesH,'edgecolor','interp','facecolor','interp','hittest','off');
                        
            % draw the lines
            % ninetyninth = quantile(featureVector,0.99); % needs stats toolbox
            ninetyninth = featureVector(ceil(numel(featureVector)*0.99));
            
            if(ninetyninth==0)
                normalizedFeatureVector = featureVector*overlayHeight/2;
            else
                normalizedFeatureVector = featureVector/ninetyninth*(overlayHeight/2);
            end
            
            if(useSmoothing)
                n = 10;
                b = repmat(1/n,1,n);
                % Sometimes 'single' data is loaded, particularly with raw
                % accelerations.  We need to convert to double in such
                % cases for filtfilt to work.
                if(~isa(normalizedFeatureVector,'double'))
                    normalizedFeatureVector = double(normalizedFeatureVector);
                end

                try
                    smoothY = filtfilt(b,1,normalizedFeatureVector);
                catch me
                    fprintf(1,'Warning - exception caught when trying to smooth feature overlay plot;\n');
                    smoothY = featureVector;
                end
                
            else
                smoothY = normalizedFeatureVector;
            end
            
            feature_lineH = line('parent',axesH,'ydata',smoothY+overlayOffset,'xdata',startStopDatenum(:,1),'color','b','hittest','on');
            
            if(~isempty(contextmenuH))
                set(feature_lineH,'uicontextmenu',contextmenuH);
                set(contextmenuH,'userdata',featureVector);
            end
            
            % No longer want to keep the cumulative sum in this one.
            %vectorSum = cumsum(featureVector)/sum(featureVector)*overlayHeight/2;
            % feature_cumsumLineH =line('parent',axesH,'ydata',vectorSum+overlayOffset,'xdata',startStopDatenum(:,1),'color','g','hittest','off');
            feature_cumsumLineH = [];
        end
  
        % ======================================================================
        %> @brief Returns a structure of the controller's default, saveable parameters as a struct.
        %> @retval pStruct A structure of parameters which include the following
        %> fields
        %> - @c featureFcnName
        %> - @c signalTagLine
        function pStruct = getDefaults()
            
            % pStruct = PASensorData.getDefaults();
            
            pStruct.pathname = PAPathParam('default',getDocumentsPath(),'Description','Directory of accelerometer sensor data');
            pStruct.filename = PAFilenameParam('default','','Description','Accelerometer filename','help','Name of file containing accelerometer data that is loaded.');

            
            pStruct.yDir = PAEnumParam('default','normal','categories',{'normal','reverse'},'description','y-axis direction');  %or can be 'reverse'
            
            % Main appcontroller should handle screenshots ...
            % pStruct.screenshot_path = obj.rootpathname; %initial directory to look in for EDF files to load
            
            outputPath = fullfile(getSavePath(),'output');
            
            if(~isdir(outputPath))
                try
                    mkdir(outputPath);
                catch me
                    showME(me);
                    %pStruct.output_pathname = fileparts(mfilename('fullpath'));
                end
            end
            
            % There is also an 'exportPathname' at this point from
            % PASensorData.getDefaults()
            pStruct.outputPath = PAPathParam('default',outputPath,'description','Output save path');
            
            [tagLines,~] = PASensorData.getDefaultTagLineLabels();
            featureStruct = PASensorData.getFeatureDescriptionStruct();
            featureFcnNames = fieldnames(featureStruct);
            
            pStruct.featureFcnName = PAEnumParam('default',featureFcnNames{1},'categories',featureFcnNames,'description','Feature function');
            pStruct.signalTagLine = PAEnumParam('default',tagLines{1},'categories',tagLines,'description','Axis');
            
            %> @brief String representing the current type of display being used.
            %> Can be
            %> @li @c Time Series
            %> @li @c Aggregate Bins
            %> @li @c Features
            displayStruct = PASensorData.getStructTypes();
            displayTypes = fieldnames(displayStruct);
            pStruct.displayType = PAEnumParam('default',displayTypes{1},'categories',displayTypes,'description','Top panel display');
            
            %> Boolean value:
            %> - @c true : Apply line smoothing when presenting features on the
            %> secondary axes (Default).
            %> - @c false : Do not apply line smoothing when presenting features on the
            %> secondary axes (show them in original form).            
            helpTxt = {'true : Apply line smoothing when presenting features on the secondary axes (Default).'
                'false : Do not apply line smoothing when presenting features on the secondary axes (show them in original form).'
                };
            pStruct.useSmoothing = PABoolParam('default',true,'description','Line smoothing','help',helpTxt);
            
            %> Boolean value:
            %> - @c true : Highlight nonwear in second secondary axes (Default).
            %> - @c false : Do not highlight nonwear on the secondary axes.
            helpTxt = {
                'true : Highlight nonwear in second secondary axes (Default).'
                'false : Do not highlight nonwear on the secondary axes.'
                };
            pStruct.highlightNonwear = PABoolParam('default',true,'description','Highlight nonwear','help',helpTxt);
%             pStruct.featureFcnName = featureFcnNames{1};
%             pStruct.signalTagLine = tagLines{1};
%             
%             pStruct.viewMode = 'timeSeries';
%             pStruct.useSmoothing = true;
%             pStruct.highlightNonwear = true;
        end
       
    end
end



% Archive

% This was no longer being called - so placed in archive 5/11/2017 @hyatt

% --------------------------------------------------------------------
%> @brief Adds an overlay of the lumens signal to the secondary axes.
%> @param obj Instance of PASingleStudyController.
%> @param lumenVector An Nx1 vector of lumen values to be displayed in the
%> secondary axes.
%> @param startStopDatenum An Nx2 matrix start and stop datenums which
%> correspond to the start and stop times of the same row in overlayVector.
% --------------------------------------------------------------------
% function addLumensOverlayToSecondaryAxes(obj, lumenVector, startStopDatenum)
%     yLim = get(obj.axeshandle.secondary,'ylim');
%     yLim = yLim*1/3+2/3;
%     minColor = [.2 0.1 0];
%
%     maxLumens = 250;
%
%
%     nFaces = numel(lumenVector);
%     x = nan(4,nFaces);
%     y = repmat(yLim([1 2 2 1])',1,nFaces);
%     vertexColor = nan(4,nFaces,3);
%
%     % each column represent a face color triplet
%     luxColorMap = (lumenVector/maxLumens)*[0.8,0.9,1]+ repmat(minColor,nFaces,1);
%
%     % patches are drawn clock wise in matlab
%
%     for f=1:nFaces
%         if(f==nFaces)
%             vertexColor(:,f,:) = luxColorMap([f,f,f,f],:);
%
%         else
%             vertexColor(:,f,:) = luxColorMap([f,f,f+1,f+1],:);
%
%         end
%         x(:,f) = startStopDatenum(f,[1 1 2 2])';
%
%     end
%     patch(x,y,vertexColor,'parent',obj.axeshandle.secondary,'edgecolor','interp','facecolor','interp');
% end
