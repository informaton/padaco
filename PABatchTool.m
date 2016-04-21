% ======================================================================
%> @file PABatchTool.cpp
%> @brief PABatchTool serves as Padaco's batch processing controller.
%> The class creates and controls the batch processing figure that is used
%> to process a collection of Actigraph GT3X+ data files.
% ======================================================================
classdef PABatchTool < handle
   
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
        
        %> Flag for determining if batch mode is running or not.  Can be
        %> changed to false by user cancelling.
        isRunning;
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
            batchHandles = guidata(batchFig);
            
            contextmenu_directory = uicontextmenu('parent',batchFig);
            if(ismac)
                label = 'Show in Finder';
            elseif(ispc)
                label = 'Show in Explorer';
            else
                label = 'Show in browser';
            end
            
            isRunning = false;
            uimenu(contextmenu_directory,'Label',label,'callback',@showPathContextmenuCallback);
            
            set(batchHandles.button_getSourcePath,'callback',{@this.getSourceDirectoryCallback,batchHandles.text_sourcePath,batchHandles.text_filesFound});  
            set(batchHandles.button_getOutputPath,'callback',{@this.getOutputDirectoryCallback,batchHandles.text_outputPath});
            
            
            
            set(batchHandles.text_outputPath,'string',this.settings.outputDirectory,'uicontextmenu',contextmenu_directory);
            set(batchHandles.text_sourcePath,'string',this.settings.sourceDirectory,'uicontextmenu',contextmenu_directory);
            %             set(batchHandles.check_usageState,'value',this.settings.classifyUsageState);

            
            set(batchHandles.button_go,'callback',@this.startBatchProcessCallback);
            
            this.calculateFilesFound(batchHandles.text_sourcePath,batchHandles.text_filesFound);
            
            %             imgFmt = this.settings.images.format;
            %             imageFormats = {'JPEG','PNG'};
            %             imgSelection = find(strcmpi(imageFormats,imgFmt));
            %             if(isempty(imgSelection))
            %                 imgSelection = 1;
            %             end
            %             set(batchHandles.menu_imageFormat,'string',imageFormats,'value',imgSelection);
            %
            featureFcns = fieldnames(PAData.getFeatureDescriptionStruct()); %spits field-value pairs of feature names and feature description strings
            featureDesc = PAData.getExtractorDescriptions();  %spits out the string values      

            featureFcns = [featureFcns; 'all']; 
            featureLabels = [featureDesc; 'All'];

            featureLabel = this.settings.featureLabel;
            featureSelection = find(strcmpi(featureLabels,featureLabel));
            
            if(isempty(featureSelection))
                featureSelection =1;
            end
            set(batchHandles.menu_featureFcn,'string',featureLabels,'value',featureSelection,'userdata',featureFcns);

            % Make visible
            this.figureH = batchFig;
            set(this.figureH,'visible','on','closerequestFcn',@this.close);
        end
            
        function close(this, varargin)
            if(ishandle(this.figureH))
                delete(this.figureH);
            end
            delete(this);
        end
        
        % Callbacks
        % --------------------------------------------------------------------
        %> @brief Batch figure button callback for getting a directory of
        %> actigraph files to process.
        %> @param obj Instance of PAController
        %> @param hObject    handle to buttont (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param text_sourcePathH Text graphic handle for placing the path
        %> selected on the GUI display
        %> @param text_filesFoundH Text graphic handle to place the number
        %> of actigraph files found in the source directory.        
        % --------------------------------------------------------------------        
        function getSourceDirectoryCallback(obj,hObject,eventdata,text_sourcePathH,text_filesFoundH)
        % --------------------------------------------------------------------
            displayMessage = 'Select the directory containing .raw or count actigraphy files';
            initPath = get(text_sourcePathH,'string');
            tmpSrcDirectory = uigetfulldir(initPath,displayMessage);
            if(~isempty(tmpSrcDirectory))
                %assign the settings directory variable
                obj.settings.sourceDirectory = tmpSrcDirectory;
                obj.calculateFilesFound(text_sourcePathH,text_filesFoundH);
            end
        end        
 
        % --------------------------------------------------------------------
        %> @brief Determines the number of actigraph files located in the
        %> specified source path and updates the GUI's count display.
        %> @param obj Instance of PAController
        %> @param text_sourcePath_h Text graphic handle for placing the path
        %> selected on the GUI display
        %> @param text_filesFound_h Text graphic handle to place the number
        %> of actigraph files found in the source directory.        
        % --------------------------------------------------------------------        
        function calculateFilesFound(obj,text_sourcePath_h,text_filesFound_h)
        % --------------------------------------------------------------------
           %update the source path edit field with the source directory
           handles = guidata(text_sourcePath_h);
           set(text_sourcePath_h,'string',obj.settings.sourceDirectory);
           %get the file count and update the file count text field. 
           rawFileCount = numel(getFilenamesi(obj.settings.sourceDirectory,'.raw'));
           csvFileCount = numel(getFilenamesi(obj.settings.sourceDirectory,'.csv'));
           msg = '';
           if(rawFileCount==0 && csvFileCount==0)
               msg = '0 files found.';
               set(handles.button_go,'enable','off');
            
           else
              if(rawFileCount>0)
                  msg = sprintf('%u .raw file(s) found.\n',rawFileCount);
              end
              if(csvFileCount>0)
                  msg = sprintf('%s%u .csv file(s) found.',msg,csvFileCount);
              end
              set(handles.button_go,'enable','on');
           end
           set(text_filesFound_h,'string',msg);
        end
               
        % --------------------------------------------------------------------
        %> @brief Batch figure button callback for getting a directory to
        %> save processed output files to.
        %> @param obj Instance of PAController
        %> @param hObject    handle to buttont (see GCBO)
        %> @param eventdata  reserved - to be defined in a future version of MATLAB
        %> @param textH Text graphic handle for placing the output path
        %> selected on the GUI display
        % --------------------------------------------------------------------        
        function getOutputDirectoryCallback(obj,hObject,eventdata,textH)
            displayMessage = 'Select the output directory to place processed results.';
            initPath = get(textH,'string');
            tmpOutputDirectory = uigetfulldir(initPath,displayMessage);
            if(~isempty(tmpOutputDirectory))
                %assign the settings directory variable
                obj.settings.outputDirectory = tmpOutputDirectory;
                set(textH,'string',tmpOutputDirectory);
            end
        end
        
        % --------------------------------------------------------------------        
        %> @brief Callback that starts a batch process based on batch gui
        %> paramters.
        %> @param obj Instance of PAController
        %> @param hObject MATLAB graphic handle of the callback object
        %> @param eventdata reserved by MATLAB, not used.
        % --------------------------------------------------------------------        
        function startBatchProcessCallback(obj,hObject,eventdata)
                        
            dateMap.Sun = 0;
            dateMap.Mon = 1;
            dateMap.Tue = 2;
            dateMap.Wed = 3;
            dateMap.Thu = 4;
            dateMap.Fri = 5;
            dateMap.Sat = 6;
            
            % initialize batch processing file management
            [filenames, fullFilenames] = getFilenamesi(obj.settings.sourceDirectory,'.csv');
            failedFiles = {};
            fileCount = numel(fullFilenames);
            fileCountStr = num2str(fileCount);
            
            % Get batch processing settings from the GUI     
            handles = guidata(hObject);
            
            obj.notify('BatchToolStarting',EventData_BatchTool(obj.settings));
            accelType = 'count';
            
            obj.isRunning = true;
            % get feature settings
            % determine which feature to process
            
            featureFcn = getMenuUserData(handles.menu_featureFcn);
            obj.settings.featureLabel = getMenuString(handles.menu_featureFcn);
            
%             userdata = get(handles.menu_featureFcn,'userdata');
%             featureSelectionIndex = get(handles.menu_featureFcn,'value');
%             allFeatureFcns = userdata.featureFunctions;
%             allFeatureDescriptions = userdata.featureDescriptions;
%             allFeatureLabels = get(handles.menu_featureFcn,'string');
            
%             obj.settings.featureLabel = featureLabel;  
%             featureDescription = allFeatureDescriptions{featureSelectionIndex};
%             featureFcn = allFeatureFcns{featureSelectionIndex};
            
            % determine frame aggreation size - size to calculate each
            % feature from
            allFrameDurationMinutes = get(handles.menu_frameDurationMinutes,'userdata');
            frameDurationMinutes = allFrameDurationMinutes(get(handles.menu_frameDurationMinutes,'value'));
            obj.settings.frameDurationMinutes = frameDurationMinutes;                           

            % features are grouped for all studies into one file per
            % signal, place groupings into feature function directories
            
            
            obj.settings.alignment.elapsedStartHours = 0; %when to start the first measurement
            obj.settings.alignment.intervalLengthHours = 24;  %duration of each interval (in hours) once started
            
            % setup developer friendly variable names
            elapsedStartHour  = obj.settings.alignment.elapsedStartHours;
            intervalDurationHours = obj.settings.alignment.intervalLengthHours;
            maxNumIntervals = 24/intervalDurationHours*7;  %set maximum to a week
            %obj.settings.alignment.singalName = 'X';
            
            signalNames = strcat('accel.',accelType,'.',{'x','y','z','vecMag'})';
            %signalNames = {strcat('accel.',obj.accelObj.accelType,'.','x')};
            
            startDateVec = [0 0 0 elapsedStartHour 0 0];
            stopDateVec = startDateVec + [0 0 0 intervalDurationHours -frameDurationMinutes 0]; %-frameDurMin to prevent looping into the start of the next inteval.
            frameInterval = [0 0 0 0 frameDurationMinutes 0];
            timeAxis = datenum(startDateVec):datenum(frameInterval):datenum(stopDateVec);
            timeAxisStr = datestr(timeAxis,'HH:MM');
            
            logFid = obj.prepLogFile(obj.settings);
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
            else
                outputFeatureFcns = {featureFcn};
                outputFeatureLabels = {obj.settings.featureLabel};
            end
            
            outputFeaturePathnames =   strcat(fullfile(obj.settings.outputDirectory,'features'),filesep,outputFeatureFcns);
            
            
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
            
           
            % setup timers
            pctDone = 0;
            pctDelta = 1/fileCount;

            %             waitH = waitbar(pctDone,filenames{1},'name','Batch processing','visible','off');
            
            % Job security:
            %             waitH = waitbar(pctDone,filenames{1},'name','Batch processing','visible','on','CreateCancelBtn',{@(hObject,eventData) feval(get(get(hObject,'parent'),'closerequestfcn'),get(hObject,'parent'),[])},'closerequestfcn',{@(varargin) delete(varargin{1})});
           
            % Program security:
            waitH = waitbar(pctDone,filenames{1},'name','Batch processing','visible','on','CreateCancelBtn',@obj.waitbarCancelCallback,'closerequestfcn',@obj.waitbarCloseRequestCallback);
            
            % We have a cancel button and an axes handle on our waitbar
            % window; so look for the one that has the title on it. 
            titleH = get(findobj(get(waitH,'children'),'flat','-property','title'),'title');
            set(titleH,'interpreter','none');  % avoid '_' being interpreted as subscript instruction
            set(waitH,'visible','on');  %now show the results
            drawnow;
            startTime = now;
            startClock = clock;
            
            % batch process
            f = 0;
            while(f< fileCount && obj.isRunning)                
                f = f+1;
                %                 waitbar(pctDone,waitH,filenames{f});
                ticStart = tic;
                %for each featureFcnArray item as featureFcn                
                try 
                    fprintf('Processing %s\n',filenames{f});
                    curData = PAData(fullFilenames{f});%,obj.SETTINGS.DATA
                    
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
                                    alignedStartDaysOfWeek = datestr(alignedStartDateVecs,'ddd');
                                    alignedStartNumericDaysOfWeek = nan(numIntervals,1);
                                    for a=1:numIntervals
                                        alignedStartNumericDaysOfWeek(a)=dateMap.(alignedStartDaysOfWeek(a,:));
                                    end
                                    startDatenums = datenum(alignedStartDateVecs);
                                    studyIDs = repmat(curData.getStudyID('numeric'),numIntervals,1);
                                
                                    result = [studyIDs,startDatenums,alignedStartNumericDaysOfWeek,alignedVec];
                                else
                                    % Just fill in the new part, which is a
                                    % MxN array of features - taken for M
                                    % days at N time intervals.
                                    result =[result(:,1:3), alignedVec];
                                end
                                save(featureFilename,'result','-ascii','-tabs','-append');
                            end
                            
                        end
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
                
                if(obj.isRunning)
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
            
            % Let the user have a glimplse of the most recent update -
            % otherwise they have been waiting for this point long enough
            % already because they pressed the 'cancel' button 
            if(obj.isRunning)
                pause(1);
            end
            
            waitbar(1,waitH,'Finished!');
            pause(1);  % Allow the finish message time to be seen.
            
            delete(waitH);  % we are done with this now.
            
            fileCount = numel(filenames);
            failCount = numel(failedFiles);
            
            skipCount = fileCount - f;  %f is number of files processed.
            successCount = f-failCount;
            
            if(~obj.isRunning)
                userCanceledMsg = sprintf('User canceled batch operation before completion.\n\n');
            else
                userCanceledMsg = '';
            end
            
            batchResultStr = sprintf(['%sProcessed %u files in %s.\n',...
                '\tSucceeded:\t%u\n',...
                '\tSkipped:\t%u\n',...
                '\tFailed:\t%u\n\n'],userCanceledMsg,fileCount,elapsedTimeStr,successCount,skipCount,failCount);
            
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
                end
            else
                
                fclose(logFid);
                
                dlgName = 'Batch complete';
                defaultBtn = 'Show results';
                options.Default = defaultBtn;
                options.Interpreter = 'none';
                buttonName = questdlg(batchResultStr,dlgName,'Show results','Return to batch tool',options);
                switch buttonName
                    case 'Show results'
                        % Close the batch mode
                        
                        % Set the results path to be that of the normal
                        % settings path.
                        obj.notify('SwitchToResults',EventData_SwitchToResults);
                        obj.close();
                        % Go to the results view
                    case 'Return to batch tool'
                        % Bring the figure to the front/onscreen
                        movegui(obj.figureH);
                        
                end
                
            end
            
            obj.isRunning = false;
            
            %             obj.resultsPathname = obj.settings.outputDirectory;
        end
        
        
        % Helper functions for close request and such
        function waitbarCloseRequestCallback(obj,hWaitbar, ~)
            obj.isRunning = false;
            waitbar(100,hWaitbar,'Cancelling .... please wait while current iteration finishes.');
        end
        
        function waitbarCancelCallback(obj,hCancelBtn, eventData) 
            obj.waitbarCloseRequestCallback(get(hCancelBtn,'parent'),eventData);
        end
        
    end
    
    methods(Static)
        % ======================================================================
        %> @brief Returns a structure of PABatchTool default, saveable parameters as a struct.
        %> @retval pStruct A structure of parameters which include the following
        %> fields
        %> - @c featureFcn
        %> - @c signalTagLine
        % ======================================================================
        function pStruct = getDefaultParameters()
            mPath = fileparts(mfilename('fullpath'));

            pStruct.sourceDirectory = mPath;
            pStruct.outputDirectory = mPath;
            pStruct.alignment.elapsedStartHours = 0; %when to start the first measurement
            pStruct.alignment.intervalLengthHours = 24;  %duration of each interval (in hours) once started
            pStruct.frameDurationMinutes = 15;
            pStruct.featureLabel = 'All';
            pStruct.logFilename = 'batchRun_@TIMESTAMP.txt';  
        end            
        
        function logFID = prepLogFile(settings)
            startDateTime = datestr(now);            
            logFilename = strrep(settings.logFilename,'@TIMESTAMP',startDateTime);
            logFID = fopen(fullfile(settings.outputDirectory,logFilename),'w');
            fprintf(logFID,'Padaco batch processing log\nStart time:\t%s\n',startDateTime);
            fprintf(logFID,'Source directory:\t%s\n',settings.sourceDirectory);
            fprintf(logFID,'Output directory:\t%s\n',settings.outputDirectory);
            fprintf(logFID,'Features:\t%s\n',settings.featureLabel);
            fprintf(logFID,'Frame duration (minutes):\t%u\n',settings.frameDurationMinutes);
            
            fprintf(logFID,'Alignment settings:\n');
            fprintf(logFID,'\tElapsed start (hours):\t%u\n',settings.alignment.elapsedStartHours);
            fprintf(logFID,'\tInterval length (hours):\t%u\n',settings.alignment.intervalLengthHours);
        end
        
    end
end
