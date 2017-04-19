% ======================================================================
%> @file PABatchTool.cpp
%> @brief PABatchTool serves as Padaco's batch processing controller.
%> The class creates and controls the batch processing figure that is used
%> to process a collection of Actigraph GT3X+ data files.
% ======================================================================
classdef PABatchTool < handle
   
    properties(Constant)
        % In minutes
        featureDurationStr = {
            %'1 second'
            '15 seconds'
            '30 seconds'
            '1 minute'
            '5 minutes'
            '10 minutes'
            '15 minutes'
            '20 minutes'
            '30 minutes'
            '1 hour'};
        featureDurationVal = {
            % 0  % 0 is used to represent 1 sample frames.
            0.25
            0.5
            1
            5
            10
            15
            20
            30
            60};
        
        maxDaysAllowedStr = {
            '1 day'
            '7 days'
            'No Limit'
            };
        maxDaysVal = {
            1
            7
            Inf
            };
    end
    
    events
        BatchToolStarting;
        BatchToolRunning;
        BatchToolComplete;
        BatchToolClosing;
        SwitchToResults;
    end
    
    properties(Access=private) 
        %> Struct with the following fields:
        %> - @c sourceDirectory Directory of Actigraph files that will be batch processed
        %> - @c outputDirectory Output directory for batch processing
        %> - @c classifyUsageState Describe activity, inactivity, non-wear
        %> periods, and sleep state estimates.
        settings;
        %> Handle to the figure we create.  
        figureH;
        
        %> result of guidata(figureH) at time of construction
        handles;
        
        %> Flag for determining if batch mode is running or not.  Can be
        %> changed to false by user cancelling.
        isRunning;
    end
    
    methods(Access=private)
        function disable(this)
            disableHandles(this.figureH);
        end
        function enable(this)
            enableHandles(this.figureH);
        end
        
        function hide(this)
            set(this.figureH,'visible','off');
        end
        function show(this)
            this.unhide();
        end
        function unhide(this)
            set(this.figureH,'visible','on');
        end
    end
    
    methods
        
        %> @brief Class constructor.
        %> @param batchSettings Struct containing settings to use for the batch process (optional).  if
        %> it is not inclded then the getDefaultParameters() method will be called to obtain default
        %> values.
        %> @retval  PABatchTool Instance of PABatchTool.
        function this = PABatchTool(batchSettings)
            if(nargin>0 && ~isempty(batchSettings))
                this.settings = batchSettings;
            else
                this.settings = this.getDefaultParameters();
            end
                        
            batchFig = batchTool('visible','off','name','','sizechangedfcn',[]);
            this.handles = guidata(batchFig);
            
            contextmenu_directory = uicontextmenu('parent',batchFig);
            if(ismac)
                label = 'Show in Finder';
            elseif(ispc)
                label = 'Show in Explorer';
            else
                label = 'Show in browser';
            end
            
            this.isRunning = false;
            uimenu(contextmenu_directory,'Label',label,'callback',@showPathContextmenuCallback);
            
            set(this.handles.button_getSourcePath,'callback',@this.getSourceDirectoryCallback);  
            set(this.handles.button_getOutputPath,'callback',@this.getOutputDirectoryCallback);
            
            set(this.handles.text_outputPath,'string',this.settings.outputDirectory,'uicontextmenu',contextmenu_directory);
            set(this.handles.text_sourcePath,'string','','uicontextmenu',contextmenu_directory);
            
            set(this.handles.check_linkInOutPaths,'callback',@this.toggleOutputToInputPathLinkageCallbackFcn,'value',this.settings.isOutputPathLinked);
            
            % Send a refresh to the widgets that may be effected by the
            % current value of the linkage checkbox.
            this.toggleOutputToInputPathLinkageCallbackFcn(this.handles.check_linkInOutPaths,[]);            
            %             set(this.handles.check_usageState,'value',this.settings.classifyUsageState);

            
            
            set(this.handles.menu_frameDurationMinutes,'string',this.featureDurationStr,'userdata',this.featureDurationVal,'value',find(cellfun(@(x)(x==this.settings.frameDurationMinutes),this.featureDurationVal)));
            set(this.handles.menu_maxDaysAllowed,'string',this.maxDaysAllowedStr,'userdata',this.maxDaysVal,'value',find(cellfun(@(x)(x==this.settings.numDaysAllowed),this.maxDaysVal)));
            
            
            set(this.handles.button_go,'callback',@this.startBatchProcessCallback);

            % try and set the source and output paths.  In the event that
            % the path is not set, then revert to the empty ('') path.
            if(~this.setSourcePath(this.settings.sourceDirectory))
                this.setSourcePath('');
            end
            if(~this.setOutputPath(this.settings.outputDirectory))
                this.setOutputPath('');
            end
            
            %             imgFmt = this.settings.images.format;
            %             imageFormats = {'JPEG','PNG'};
            %             imgSelection = find(strcmpi(imageFormats,imgFmt));
            %             if(isempty(imgSelection))
            %                 imgSelection = 1;
            %             end
            %             set(this.handles.menu_imageFormat,'string',imageFormats,'value',imgSelection);
            %
            featureFcns = fieldnames(PAData.getFeatureDescriptionStruct()); %spits field-value pairs of feature names and feature description strings
            featureDesc = PAData.getExtractorDescriptions();  %spits out the string values      

            featureFcns = [featureFcns; 'all_sans_psd'; 'all']; 
            featureLabels = [featureDesc;'All (sans PSD)'; 'All'];
            

            featureLabel = this.settings.featureLabel;
            featureSelection = find(strcmpi(featureLabels,featureLabel));
            
            if(isempty(featureSelection))
                featureSelection =1;
            end
            set(this.handles.menu_featureFcn,'string',featureLabels,'value',featureSelection,'userdata',featureFcns);

            % Make visible
            this.figureH = batchFig;
            set(this.figureH,'visible','on','closerequestFcn',@this.close);
        end
            
        function refreshSettings(this)
            if(ishandle(this.figureH))
                this.settings.featureLabel = getMenuString(this.handles.menu_featureFcn);            
                this.settings.frameDurationMinutes = getSelectedMenuUserData(this.handles.menu_frameDurationMinutes);
                this.settings.numDaysAllowed = getMenuUserData(this.handles.menu_maxDaysAllowed);
            end            
        end
        
        function close(this, varargin)
            if(ishandle(this.figureH))
                this.refreshSettings();
                this.notify('BatchToolClosing',EventData_BatchTool(this.settings));
                delete(this.figureH);
            end
            delete(this);
        end
        
        % Callbacks
        % --------------------------------------------------------------------
        %> @brief Batch figure button callback for getting a directory of
        %> actigraph files to process.
        %> @param this Instance of PAController
        %> @param hObject    handle to buttont (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        % --------------------------------------------------------------------        
        function getSourceDirectoryCallback(this,hObject,eventdata)
        % --------------------------------------------------------------------
            displayMessage = 'Select the directory containing .raw or count actigraphy files';
            initPath = get(this.handles.text_sourcePath,'string');
            tmpSrcDirectory = uigetfulldir(initPath,displayMessage);
            this.setSourcePath(tmpSrcDirectory);
        end        
 
        % --------------------------------------------------------------------
        %> @brief Batch figure button callback for getting a directory to
        %> save processed output files to.
        %> @param this Instance of PAController
        %> @param hObject    handle to buttont (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        % --------------------------------------------------------------------
        function getOutputDirectoryCallback(this,hObject,eventdata)
            displayMessage = 'Select the output directory to place processed results.';
            initPath = get(this.handles.text_outputPath,'string');
            tmpOutputDirectory = uigetfulldir(initPath,displayMessage);
            this.setOutputPath(tmpOutputDirectory);
        end
        
        
        function didUpdate = toggleOutputToInputPathLinkageCallbackFcn(this, checkboxHandle, eventData)
            try
                this.settings.isOutputPathLinked = this.isOutputPathLinkedToInputPath();
                if(this.settings.isOutputPathLinked)
                    this.setOutputPath(this.getSourcePath());
                    set(this.handles.button_getOutputPath,'enable','off');                    
                else
                    set(this.handles.button_getOutputPath,'enable','on');
                end
                didUpdate = true;
            catch me
                showME(me);
                didUpdate = false;
            end
        end
        
        function didSet = setSourcePath(this,tmpSrcPath)
            if(~isempty(tmpSrcPath) && isdir(tmpSrcPath))
                %assign the settings directory variable
                this.settings.sourceDirectory = tmpSrcPath;
                set(this.handles.text_sourcePath,'string',tmpSrcPath);
                this.calculateFilesFound();                
                if(this.isOutputPathLinkedToInputPath())
                    didSet = this.setOutputPath(tmpSrcPath);
                else
                    didSet = true;
                end
            else
                didSet = false;
            end            
        end
        
        function isLinked = isOutputPathLinkedToInputPath(this)
            isLinked = get(this.handles.check_linkInOutPaths,'value');
        end
        
        function didSet = setOutputPath(this,tmpOutputPath)
            if(~isempty(tmpOutputPath) && isdir(tmpOutputPath))
                %assign the settings directory variable
                this.settings.outputDirectory = tmpOutputPath;
                set(this.handles.text_outputPath,'string',tmpOutputPath);
                this.updateOutputLogs();
                didSet = true;
            else
                didSet = false;
            end            
        end
        
        function pathName = getOutputPath(this)
            pathName = this.settings.outputDirectory;
        end
        
        function pathName = getSourcePath(this)
            pathName = this.settings.sourceDirectory;
        end
                        
        % --------------------------------------------------------------------
        %> @brief Determines the number of actigraph files located in the
        %> specified source path and updates the GUI's count display.
        %> @param this Instance of PAController
        %> @param text_sourcePath_h Text graphic handle for placing the path
        %> selected on the GUI display
        %> @param text_filesFound_h Text graphic handle to place the number
        %> of actigraph files found in the source directory.        
        % --------------------------------------------------------------------        
        function calculateFilesFound(this,sourcePathname,text_filesFound_h)
        % --------------------------------------------------------------------
            
           %update the source path edit field with the source directory
           if(nargin<3)
               text_filesFound_h = this.handles.text_filesFound;
               if(nargin<2)
                   sourcePathname = this.getSourcePath();
               end
           end
          
           %get the file count and update the file count text field. 
           rawFileCount = numel(getFilenamesi(sourcePathname,'.raw'));
           binFileCount = numel(getFilenamesi(sourcePathname,'.bin'));           
           csvFileCount = numel(getFilenamesi(sourcePathname,'.csv'));
           msg = '';
           if(rawFileCount==0 && csvFileCount==0 && binFileCount==0)
               msg = '0 files found.';
               set(this.handles.button_go,'enable','off','tooltipstring','No files found!');
           else
              if(rawFileCount>0)
                  msg = sprintf('%s%u .raw file(s) found.\n',msg,rawFileCount);
              end
              if(csvFileCount>0)
                  msg = sprintf('%s%u .csv file(s) found.',msg,csvFileCount);
              end
              if(binFileCount>0)
                  msg = sprintf('%s%u .bin file(s) found.',msg,binFileCount);
              end
              
              if(binFileCount+rawFileCount>0 && csvFileCount>0)
                 msg = sprintf('%s Only .csv file(s) will be processed; place .raw/.bin files in a separate directory for processing.',msg);
              end
              
              set(this.handles.button_go,'enable','on','tooltipstring','');
           end
           set(text_filesFound_h,'string',msg);
        end
               
        % --------------------------------------------------------------------
        %> @brief Determines the number of actigraph files located in the
        %> specified source path and updates the GUI's count display.
        %> @param this Instance of PAController
        %> @param outputPathname (optional) Pathname of output directory (string)
        %> @param text_outputLogs_h Text graphic handle to write results to.
        % --------------------------------------------------------------------        
        function updateOutputLogs(this,outputPathname,text_outputLogs_h)
        % --------------------------------------------------------------------
            
           %update the source path edit field with the source directory
           if(nargin<3)
               text_outputLogs_h = this.handles.text_outputLogs;
               if(nargin<2)
                   outputPathname = this.getOutputPath();
               end
           end
          
           set(text_outputLogs_h,'string','','hittest','off');

           %get the log files with most recent ones first on the list.
           sortNewestToOldest = true;
           [filenames, fullfilenames, filedates] = getFilenamesi(outputPathname,'.txt',sortNewestToOldest);
           
           newestIndex = find(strncmpi(filenames,'batchRun',numel('batchRun')),1);
           if(~isempty(newestIndex))
               logFilename = filenames{newestIndex};
               logFullFilename = fullfilenames{newestIndex};
               % logDate = filedates(newestIndex);
               logMsg = sprintf('Last log file: %s',logFilename);
               %tooltip = '<html><body><h4>Click to view last batch run log file</h4></body></html>';
               % tooltip = 'Click to view.';
               callbackFcn = {@viewTextFileCallback,logFullFilename};
               enableState = 'inactive';  % This prevents the tooltip from being seen :(, but allows the buttondownfcn to work :)
               
               fid = fopen(logFullFilename,'r');
               if(fid>0)
                   fopen(fid);
                   tooltip = fread(fid,'uint8=>char')';
                   fclose(fid);
                   enableState = 'on';
               
               else
                   tooltip = '';                   
               end
               
           else
               logMsg = '';
               tooltip = '';
               callbackFcn = [];
               enableState = 'on';
               
           end
           set(text_outputLogs_h,'string',logMsg,'tooltipstring',tooltip,'buttondownFcn',callbackFcn,'enable',enableState);
        end
        
        % --------------------------------------------------------------------        
        %> @brief Callback that starts a batch process based on batch gui
        %> paramters.
        %> @param this Instance of PAController
        %> @param hObject MATLAB graphic handle of the callback object
        %> @param eventdata reserved by MATLAB, not used.
        % --------------------------------------------------------------------        
        function startBatchProcessCallback(this,hObject,eventdata)
                        
            this.disable();
            dateMap.Sun = 0;
            dateMap.Mon = 1;
            dateMap.Tue = 2;
            dateMap.Wed = 3;
            dateMap.Thu = 4;
            dateMap.Fri = 5;
            dateMap.Sat = 6;
            
            
            % initialize batch processing file management
            [countFilenames, countFullFilenames] = getFilenamesi(this.getSourcePath(),'.csv');
            
            if(numel(countFilenames)>0)
                accelType = 'count';
                filenames = countFilenames;
                fullFilenames = countFullFilenames;
            else
                accelType = 'raw';
                [rawFilenames, rawFullFilenames] = getFilenamesi(this.getSourcePath(),{'.bin','.raw'});
                filenames = rawFilenames;
                fullFilenames = rawFullFilenames;
            end
            
            failedFiles = {};
            fileCount = numel(fullFilenames);
            fileCountStr = num2str(fileCount);

            % Get batch processing settings from the GUI     
            
            this.notify('BatchToolStarting',EventData_BatchTool(this.settings));


            
            this.isRunning = true;
            
            % Establish waitbar - do this early, otherwise the program
            % appears to hang.

            %             waitH = waitbar(pctDone,filenames{1},'name','Batch processing','visible','off');
            
            % Job security:
            %             waitH = waitbar(pctDone,filenames{1},'name','Batch processing','visible','on','CreateCancelBtn',{@(hObject,eventData) feval(get(get(hObject,'parent'),'closerequestfcn'),get(hObject,'parent'),[])},'closerequestfcn',{@(varargin) delete(varargin{1})});
           
            % Program security:
            waitH = waitbar(0,{'','','Configuring rules and output file headers',''},'name','Batch processing','visible','off',...
                'CreateCancelBtn',@this.waitbarCancelCallback,'closerequestfcn',@this.waitbarCloseRequestCallback,...
                'resize','off','windowstyle','modal','color',[0.9 0.9 0.9]);         
            
            % We have a cancel button and an axes handle on our waitbar
            % window; so look for the one that has the title on it. 
            titleH = get(findobj(get(waitH,'children'),'flat','-property','title'),'title');
            buttonH = findobj(get(waitH,'children'),'flat','style','pushbutton');
            
            newFontSize = 12;
            oldFontSize = get(buttonH,'fontsize');
            changeRatio = newFontSize/oldFontSize;
            oldButtonPos = get(buttonH,'position');
            newW = oldButtonPos(3)*changeRatio;
            newH = oldButtonPos(4)*changeRatio;
            dW = newW-oldButtonPos(3);
            dH = newH-oldButtonPos(4);
            newButtonPos = [oldButtonPos(1)-dW/2, oldButtonPos(2)+dH/2, newW, newH];

            set(titleH,'interpreter','none','fontsize',newFontSize);  % avoid '_' being interpreted as subscript instruction       
            set(buttonH,'fontsize',newFontSize,'position',newButtonPos);
            set(waitH,'visible','on');  %now show the results
            drawnow;
            
            
            % Get maximum days allowed for any one subject            
            maximumDaysAllowed = getMenuUserData(this.handles.menu_maxDaysAllowed);
            this.settings.numDaysAllowed = maximumDaysAllowed;
            
            % get feature settings
            % determine which feature to process
            
            featureFcn = getMenuUserData(this.handles.menu_featureFcn);
            this.settings.featureLabel = getMenuString(this.handles.menu_featureFcn);            
            
            % determine frame aggreation size - size to calculate each
            % feature from
            %             allFrameDurationMinutes = get(handles.menu_frameDurationMinutes,'userdata');
            %             frameDurationMinutes = allFrameDurationMinutes(get(handles.menu_frameDurationMinutes,'value'));
            frameDurationMinutes = getSelectedMenuUserData(this.handles.menu_frameDurationMinutes);
            this.settings.frameDurationMinutes = frameDurationMinutes;                           

            % features are grouped for all studies into one file per
            % signal, place groupings into feature function directories
            
            
            this.settings.alignment.elapsedStartHours = 0; %when to start the first measurement
            this.settings.alignment.intervalLengthHours = 24;  %duration of each interval (in hours) once started
            
            % setup developer friendly variable names
            elapsedStartHour  = this.settings.alignment.elapsedStartHours;
            intervalDurationHours = this.settings.alignment.intervalLengthHours;
            maxNumIntervals = 24/intervalDurationHours*maximumDaysAllowed;  %set maximum to a week
            %this.settings.alignment.singalName = 'X';
            
            signalNames = strcat('accel.',accelType,'.',{'x','y','z','vecMag'})';
            %signalNames = {strcat('accel.',this.accelObj.accelType,'.','x')};
            
            startDateVec = [0 0 0 elapsedStartHour 0 0];
            stopDateVec = startDateVec + [0 0 0 intervalDurationHours -frameDurationMinutes 0]; %-frameDurMin to prevent looping into the start of the next interval.
            frameInterval = [0 0 0 0 frameDurationMinutes 0];
            timeAxis = datenum(startDateVec):datenum(frameInterval):datenum(stopDateVec);
            timeAxisStr = datestr(timeAxis,'HH:MM:SS');
            
            [logFid, logFullFilename, summaryFid, summaryFullFilename] = this.prepLogAndSummaryFiles(this.settings);
            fprintf(logFid,'File count:\t%u',fileCount);

            %% Setup output folders

            % PAData separates the psd feature into bands in order to
            % create feature vectors.  Unfortunately, this does not give a
            % clean way to separate the groups into the expanded feature
            % vectors, hence the gobbly goop code here:
            if(strcmpi(featureFcn,'all'))
                featureStructWithPSDBands= PAData.getFeatureDescriptionStructWithPSDBands();
                outputFeatureFcns = fieldnames(featureStructWithPSDBands);
                outputFeatureLabels = struct2cell(featureStructWithPSDBands);  % leave it here for the sake of other coders; yes, you can assign this using a second output argument from getFeatureDescriptionWithPSDBands                
            elseif(strcmpi(featureFcn,'all_sans_psd')) % and sans usage state
                outputFeatureStruct = rmfield(PAData.getFeatureDescriptionStruct(),{'psd','usagestate'});
                outputFeatureFcns = fieldnames(outputFeatureStruct);
                outputFeatureLabels = struct2cell(outputFeatureStruct);
            else
                outputFeatureFcns = {featureFcn};
                outputFeatureLabels = {this.settings.featureLabel};
            end
            
            outputFeaturePathnames =   strcat(fullfile(this.getOutputPath(),'features'),filesep,outputFeatureFcns);
            
            for fn=1:numel(outputFeatureFcns)
                
                % Prep output alignment files.
                outputFeatureFcn = outputFeatureFcns{fn};
                features_pathname = outputFeaturePathnames{fn};
                feature_description = outputFeatureLabels{fn};
                if(~isdir(features_pathname))
                    mkdir(features_pathname);
                end
                
                for s=1:numel(signalNames)
                    signalName = signalNames{s};
                    
                    featureFilename = fullfile(features_pathname,strcat('features.',outputFeatureFcn,'.',signalName,'.txt'));
                    fid = fopen(featureFilename,'w');
                    fprintf(fid,'# Feature:\t%s\n',feature_description);
                    
                    fprintf(fid,'# Length:\t%u\n',size(timeAxisStr,1));
                    
                    fprintf(fid,'# Study_ID\tStart_Datenum\tStart_Day');
                    for t=1:size(timeAxisStr,1)
                        fprintf(fid,'\t%s',timeAxisStr(t,:));
                    end
                    fprintf(fid,'\n');
                    fclose(fid);
                end            
            end
            
            totalDayCount = 0;
            completeDayCount = 0;
            incompleteDayCount = 0;            
           
            % setup timers
            pctDone = 0;
            pctDelta = 1/fileCount;
            
            waitbar(pctDone,waitH,filenames{1});            
            
            startTime = now;
            startClock = clock;
            
            % batch process
            f = 0;
            while(f< fileCount && this.isRunning)                
                f = f+1;
                %                 waitbar(pctDone,waitH,filenames{f});
                ticStart = tic;
                %for each featureFcnArray item as featureFcn                
                try 
                    fprintf('Processing %s\n',filenames{f});
                    curData = PAData(fullFilenames{f});%,this.SETTINGS.DATA
                    
                    curStudyID = curData.getStudyID('numeric');
                    if(isnan(curStudyID))
                        curStudyID = f;
                    end
                    
                    setFrameDurMin = curData.setFrameDurationMinutes(frameDurationMinutes);
                    if(frameDurationMinutes~=setFrameDurMin)
                        fprintf('There was an error in setting the frame duration.\n');
                    else                        
                        % [~,filename,~] = fileparts(curData.getFilename());
                        
                        for s=1:numel(signalNames)
                            signalName = signalNames{s};
                        
                            % Calculate/extract the features for the
                            % current signal (e.g. x, y, z, or vecMag) and
                            % the given feature function (e.g.
                            % 'mode','psd','all')
                            curData.extractFeature(signalName,featureFcn);
                            
                            
                                
                            for fn=1:numel(outputFeatureFcns)
                                outputFeatureFcn = outputFeatureFcns{fn};
                                features_pathname = outputFeaturePathnames{fn};
                                
                                featureFilename = fullfile(features_pathname,strcat('features.',outputFeatureFcn,'.',signalName,'.txt'));
                                [alignedVec, alignedStartDateVecs] = curData.getAlignedFeatureVecs(outputFeatureFcn,signalName,elapsedStartHour, intervalDurationHours);
                                
                                numIntervals = size(alignedVec,1);
                                if(numIntervals>maxNumIntervals)
                                    alignedVec = alignedVec(1:maxNumIntervals,:);
                                    alignedStartDateVecs = alignedStartDateVecs(1:maxNumIntervals, :);
                                    numIntervals = maxNumIntervals;
                                end
                                
                                % Currently, only x,y,z or vector magnitude
                                % are considered for signal names.  And
                                % they all have the same number of samples.
                                % Thus, it is not necessary to perform the
                                % following caluclations on the first
                                % iteration through.
                                if(s==1)
                                    % Need to apply datenum to get back to
                                    % proper time for datestr to work.  
                                    startDatenums = datenum(alignedStartDateVecs);
                                    % There is a bug if you try to do this
                                    % datestr(alignedStartDateVecs,'ddd')
                                    % and the date vecs have a different
                                    % number of days due to extra or less
                                    % time in other columns (e.g. hours,
                                    % minutes).
                                    alignedStartDaysOfWeek = datestr(startDatenums,'ddd');
                                    alignedStartNumericDaysOfWeek = nan(numIntervals,1);
                                    for a=1:numIntervals
                                        alignedStartNumericDaysOfWeek(a)=dateMap.(alignedStartDaysOfWeek(a,:));
                                    end

                                    studyIDs = repmat(curStudyID,numIntervals,1);
                                
                                    result = [studyIDs,startDatenums,alignedStartNumericDaysOfWeek,alignedVec];
                                else
                                    % Just fill in the new part, which is a
                                    % MxN array of features - taken for M
                                    % days at N time intervals.
                                    result =[result(:,1:3), alignedVec];
                                end
                                % Added this because of issues with raw
                                % data loaded as a single.
                                if(~isa(result,'double'))
                                    result = double(result);
                                end
                                save(featureFilename,'result','-ascii','-tabs','-append');
                            end                            
                        end
                        
                        [curCompleteDayCount, curIncompleteDayCount, curTotalDayCount] = curData.getDayCount(elapsedStartHour, intervalDurationHours);
                        totalDayCount = totalDayCount + curTotalDayCount;
                        completeDayCount = completeDayCount + curCompleteDayCount;
                        incompleteDayCount = incompleteDayCount + curIncompleteDayCount;           
                    end                    
                catch me
                    showME(me);
                    failedFiles{end+1} = filenames{f};
                    failMsg = sprintf('\t%s\tFAILED.\n',fullFilenames{f});
                    fprintf(1,failMsg);
                    
                    % Log error
                    fprintf(logFid,'\n=======================================\n');
                    fprintf(logFid,failMsg);
                    showME(me,logFid);
                    
                end  
                
                num_files_completed = f;
                pctDone = pctDone+pctDelta;
                
                elapsed_dur_sec = toc(ticStart);
                fprintf('File %d of %d (%0.2f%%) Completed in %0.2f seconds\n',num_files_completed,fileCount,pctDone,elapsed_dur_sec);
                elapsed_dur_total_sec = etime(clock,startClock);
                avg_dur_sec = elapsed_dur_total_sec/num_files_completed;
                
                if(this.isRunning)
                    remaining_dur_sec = avg_dur_sec*(fileCount-num_files_completed);
                    est_str = sprintf('%01ihrs %01imin %01isec',floor(mod(remaining_dur_sec/3600,24)),floor(mod(remaining_dur_sec/60,60)),floor(mod(remaining_dur_sec,60)));
                    
                    msg = {['Processing ',filenames{f}, ' (file ',num2str(f) ,' of ',fileCountStr,')'],...
                        ['Elapsed Time: ',datestr(now-startTime,'HH:MM:SS')],...
                        ['Time Remaining: ',est_str]};
                    fprintf('%s\n',msg{2});
                    if(ishandle(waitH))                        
                        waitbar(pctDone,waitH,char(msg));
                    else
                        %                     waitHandle = findall(0,'tag','waitbarHTag');
                    end
                end
            end
            elapsedTimeStr = datestr(now-startTime,'HH:MM:SS');
            
            % Let the user have a glimpse of the most recent update -
            % otherwise they have been waiting for this point long enough
            % already because they pressed the 'cancel' button 
            if(this.isRunning)
                pause(1);
            end
            
            waitbar(1,waitH,'Finished!');
            pause(1);  % Allow the finish message time to be seen.
            
            delete(waitH);  % we are done with this now.
            
            fileCount = numel(filenames);
            failCount = numel(failedFiles);
            
            skipCount = fileCount - f;  %f is number of files processed.
            successCount = f-failCount;
            
            if(~this.isRunning)
                userCanceledMsg = sprintf('User canceled batch operation before completion.\n\n');
            else
                userCanceledMsg = '';
            end
            
            batchResultStr = sprintf(['%sProcessed %u files in (hh:mm:ss)\t %s.\n',...
                '\tSucceeded:\t%5u\n',...
                '\tSkipped:\t%5u\n',...
                '\tFailed:\t%5u\n\n'],userCanceledMsg,fileCount,elapsedTimeStr,successCount,skipCount,failCount);
            
            batchResultStr = sprintf(['%sTotal day count:\t%5u\n',...
                'Complete day count:\t%5u\n',...
                'Incomplete day count:\t%5u\n'],batchResultStr,totalDayCount, completeDayCount, incompleteDayCount);
            
            fprintf(logFid,'\n====================SUMMARY===============\n');
            fprintf(logFid,batchResultStr);
            fprintf(1,batchResultStr);
            if(failCount>0 || skipCount>0)
                
                promptStr = str2cell(sprintf('%s\nThe following files were not processed:',batchResultStr));
                failMsg = sprintf('\n\n%u Files Failed:\n',numel(failedFiles));
                fprintf(1,failMsg);
                fprintf(logFid,failMsg);
                for f=1:numel(failedFiles)
                    failMsg = sprintf('\t%s\tFAILED.\n',failedFiles{f});
                    fprintf(1,failMsg);
                    fprintf(logFid,failMsg);
                end
                
                fclose(logFid);
                
                % Only handle the case where non-skipped files fail here.
                if(failCount>0)
                    skipped_filenames = failedFiles(:);
                    if(failCount<=10)
                        listSize = [180 150];  %[ width height]
                    elseif(failCount<=20)
                        listSize = [180 200];
                    else
                        listSize = [180 300];
                    end
                    
                    [selections,clicked_ok]= listdlg('PromptString',promptStr,'Name','Batch Completed',...
                        'OKString','Copy to Clipboard','CancelString','Close','ListString',skipped_filenames,...
                        'listSize',listSize);
                    
                    if(clicked_ok)
                        %char(10) is newline
                        skipped_files = [char(skipped_filenames(selections)),repmat(char(10),numel(selections),1)];
                        skipped_files = skipped_files'; %filename length X number of files
                        
                        clipboard('copy',skipped_files(:)'); %make it a column (1 row) vector
                        selectionMsg = [num2str(numel(selections)),' filenames copied to the clipboard.'];
                        disp(selectionMsg);
                        h = msgbox(selectionMsg);
                        pause(1);
                        if(ishandle(h))
                            delete(h);
                        end
                    end;
                    
                    dlgName = 'Errors found';
                    showLogFileStr = 'Open log file';
                    returnToBatchToolStr = 'Return to batch tool';
                    options.Default = showLogFileStr;

                    options.Interpreter = 'none';
                    buttonName = questdlg(batchResultStr,dlgName,showLogFileStr,returnToBatchToolStr,options);
                    switch buttonName
                        case returnToBatchToolStr
                            % Bring the figure to the front/onscreen
                            movegui(this.figureH);
                        case showLogFileStr
                            textFileViewer(logFullFilename);
                        otherwise
                    end
                
                end
            else
                fclose(logFid);
                
                
                dlgName = 'Batch complete';
                showResultsStr = 'Switch to results';
                showOutputFolderStr = 'Open output folder';
                returnToBatchToolStr = 'Return to batch tool';
                options.Default = showResultsStr;
                options.Interpreter = 'none';
                buttonName = questdlg(batchResultStr,dlgName,showResultsStr,showOutputFolderStr,returnToBatchToolStr,options);
                switch buttonName
                    case returnToBatchToolStr
                        % Bring the figure to the front/onscreen
                        movegui(this.figureH);
                    case showResultsStr
                        % Close the batch mode
                        
                        % Set the results path to be that of the normal
                        % settings path.
                        this.hide();
                        this.notify('SwitchToResults',EventData_SwitchToResults);
                        this.close();  % close this out, 'return',
                        return;       %  and go to the results view
                    case showOutputFolderStr
                        openDirectory(this.getOutputPath())
                    otherwise
                end
            end
            
            this.updateOutputLogs();
            this.isRunning = false;
            this.enable();
            
            %             this.resultsPathname = this.getOutputPath();
        end
        
        
        % Helper functions for close request and such
        function waitbarCloseRequestCallback(this,hWaitbar, ~)
            this.isRunning = false;
            waitbar(100,hWaitbar,'Cancelling .... please wait while current iteration finishes.');
        end
        
        function waitbarCancelCallback(this,hCancelBtn, eventData) 
            this.waitbarCloseRequestCallback(get(hCancelBtn,'parent'),eventData);
        end
        
    end
    
    methods(Static)
        % ======================================================================
        %> @brief Returns a structure of PABatchTool default, saveable parameters as a struct.
        %> @retval pStruct A structure of parameters which include the following
        %> fields
        %> - @c sourceDirectory
        %> - @c outputDirectory
        %> - @c alignment.elapsedStartHours when to start the first measurement
        %> - @c alignment.intervalLengthHours  duration of each interval (in hours) once started
        %> - @c frameDurationMinutes
        %> - @c featureLabel;
        %> - @c logFilename
        %> - @c isOutputPathLinked
        %> - @c signalTagLine
        % ======================================================================
        function pStruct = getDefaultParameters()
            try
                docPath = findpath('docs');
            catch
                docPath = fileparts(mfilename('fullpath'));
            end
            
            pStruct.sourceDirectory = docPath;
            pStruct.outputDirectory = docPath;
            
            pStruct.alignment.elapsedStartHours = 0; %when to start the first measurement
            pStruct.alignment.intervalLengthHours = 24;  %duration of each interval (in hours) once started
            pStruct.frameDurationMinutes = 15;
            pStruct.numDaysAllowed = 7;
            pStruct.featureLabel = 'All';
            pStruct.logFilename = 'batchRun_@TIMESTAMP.txt'; 
            pStruct.summaryFilename = 'batchSummary_@TIMESTAMP.txt';            
            pStruct.isOutputPathLinked = false;  
        end            
        
        % --------------------------------------------------------------------
        %> @brief Prepares the current run's log and summary files.
        %> @param this Instance of PABatchTool
        %> @param settings
        %> @retval logFID The <i>open</i> file identifier of the created
        %> log file.
        % --------------------------------------------------------------------        
        function [logFID, logFullFilename, summaryFID, summaryFullFilename] = prepLogAndSummaryFiles(settings)
        % --------------------------------------------------------------------        
            startDateTime = datestr(now);            
            summaryFilename = strrep(settings.logFilename,'@TIMESTAMP',startDateTime);
            summaryFullFilename = fullfile(settings.outputDirectory,summaryFilename); 
            summaryFID = fopen(summaryFullFilename,'w');
            
            logFilename = strrep(settings.logFilename,'@TIMESTAMP',startDateTime);
            logFullFilename = fullfile(settings.outputDirectory,logFilename);
            
            logFID = fopen(logFullFilename,'w');
            versionStr = PAController.getVersionInfo('num');
            fprintf(logFID,'Padaco batch processing log\nStart time:\t%s\n',startDateTime);
            fprintf(logFID,'Padaco version %s\n',versionStr);
            fprintf(logFID,'Source directory:\t%s\n',settings.sourceDirectory);
            fprintf(logFID,'Output directory:\t%s\n',settings.outputDirectory);
            fprintf(logFID,'Features:\t%s\n',settings.featureLabel);
            fprintf(logFID,'Frame duration (minutes):\t%0.2f\n',settings.frameDurationMinutes);
            
            fprintf(logFID,'Alignment settings:\n');
            fprintf(logFID,'\tElapsed start (hours):\t%u\n',settings.alignment.elapsedStartHours);
            fprintf(logFID,'\tInterval length (hours):\t%u\n',settings.alignment.intervalLengthHours);
        end
                
        
    end
end
