classdef PAData < PABaseWithSettings
    
    properties(SetAccess=protected)
        %> @brief Folder where exported files are saved to .
        exportPathname;
        
        %> @brief file formats
        exportFormat;
        
        pathname;
        filename;
        
        EXPORT_FORMATS = {'csv','xls','mat'};
    end
    methods(Abstract)
       didExport = exportToDisk(this); 
       %didSet = setInputData(this, dataOrFile)
    end
    methods
        
        function this = PAData(varargin)  
            this@PABaseWithSettings(varargin{:})            
        end        
        
        % --------------------------------------------------------------------
        % Helper functions for setting the export paths to be used when
        % saving data about clusters and covariates to disk.
        % --------------------------------------------------------------------
        function didUpdate = updateExportPath(this)
            displayMessage = 'Select a directory to place the exported files.';
            initPath = this.getExportPath();
            tmpOutputDirectory = uigetfulldir(initPath,displayMessage);
            if(isempty(tmpOutputDirectory))
                didUpdate = false;
            else
                didUpdate = this.setExportPath(tmpOutputDirectory);
            end
        end
        
        
        % ======================================================================
        %> @brief Returns the filename, pathname, and full filename (pathname + filename) of
        %> the file that the accelerometer data was loaded from.
        %> @param obj Instance of PAData
        %> @retval filename The short filename of the accelerometer data.
        %> @retval pathname The pathname of the accelerometer data.
        %> @retval fullFilename The full filename of the accelerometer data.
        % =================================================================
        function [filename,pathname,fullFilename] = getFilename(obj)
            filename = obj.filename;
            pathname = obj.pathname;
            fullFilename = fullfile(obj.pathname,obj.filename);
        end

        % ======================================================================
        %> @brief Sets the pathname and filename instance variables using
        %> the input full filename.
        %> @param obj Instance of PASensorData
        %> @param fullfilename The full filenmae of the accelerometer data
        %> that will be set
        %> @retval success (T/F)
        %> -true: if fullfilename exists and is instance variables are set
        %> - false: otherwise
        %> @note See also getFilename()
        % =================================================================
        function success = setFullFilename(obj,fullfilename)
            if(exist(fullfilename,'file'))
                [obj.pathname, basename,ext] = fileparts(fullfilename);
                obj.filename = strcat(basename,ext);
                success = true;
            else
                success = false;
            end

        end

        % ======================================================================
        %> @brief Returns the full filename (pathname + filename) of
        %> the accelerometer data.
        %> @param obj Instance of PASensorData
        %> @retval fullFilename The full filenmae of the accelerometer data.
        %> @note See also getFilename()
        % =================================================================
        function fullFilename = getFullFilename(obj)
            [~,~,fullFilename] = obj.getFilename();
        end

        % --------------------------------------------------------------------
        function exportPath = getExportPath(this)
            exportPath = this.exportPathname;
        end
        
        % --------------------------------------------------------------------
        function exportFmt = getExportFormat(this)
            exportFmt = this.exportFormat;
        end
        
        % --------------------------------------------------------------------
        function didSet = setExportPath(this, newPath)
            try
                oldPath = this.exportPathname;
                this.exportPathname = newPath;
                didSet = true;
                if ~isequal(oldPath, newPath)
                    this.notify('DefaultParameterChange',EventData_ParameterChange('exportPathname',newPath, oldPath));
                end
            catch me
                showME(me);
                didSet = false;
            end
        end
        
        % --------------------------------------------------------------------
        function didSet = setExportFormat(this, newFmt)
            try
                oldFmt = this.exportFormat;
                if(ismember(newFmt, this.EXPORT_FORMATS))
                    this.exportFormat = newFmt;
                    didSet = true;
                    if ~isequal(oldFmt, newFmt)
                        this.notify('DefaultParameterChange',EventData_ParameterChange('exportFormat',newFmt, oldFmt));
                    end
                else
                    didSet = false;
                end
            catch me
                showME(me);
                didSet = false;
            end
        end
        
        function exportRequestCb(this, varargin)
            % If this is not true, then we can just leave this
            % function since the user would have cancelled.
            if(this.updateExportPath())
                try
                    [didExport, msg] = this.exportToDisk();
                catch me
                    msg = 'An error occurred while trying to save the data to disk.  A thousand apologies.  I''m very sorry.';
                    showME(me);
                end
                
                % Give the option to look at the files in their saved folder.
                if(didExport)
                    dlgName = 'Export complete';
                    closeStr = 'Close';
                    showOutputFolderStr = 'Open output folder';
                    options.Default = closeStr;
                    options.Interpreter = 'none';
                    buttonName = questdlg(msg,dlgName,closeStr,showOutputFolderStr,options);
                    if(strcmpi(buttonName,showOutputFolderStr))
                        openDirectory(this.getExportPath())
                    end
                else
                    makeModal = true;
                    pa_msgbox(msg,'Export',makeModal);
                end
            end
        end
    end
    methods(Static)
        function settings = getDefaults()
            settings.exportPathname = PAPathParam('default',getSavePath(),'description','Export pathname');
        end


        %======================================================================
        %> @brief Helper function to convert an Nx2 matrix of start stop
        %> events into a single logical vector with 1's located at the
        %> locations corresponding to the samples inclusively between
        %> eventStartStops row entries.
        %> @param eventStartStop
        %> @param vectorSize The length or size of the sample data to unroll
        %> the start stop events back to.
        %> @note eventStartStop = thresholdCrossings(vector,0);
        %> @retval vector
        %======================================================================
        function vector = unrollEvents(eventsStartStop,vectorSize)
            vector = false(vectorSize,1);
            for e=1:size(eventsStartStop,1)
                vector(eventsStartStop(e,1):eventsStartStop(e,2))=true;
            end
        end



        %> @brief Returns start and stop pairs of the sample points where where line_in is
        %> greater (i.e. crosses) than threshold_line
        %> threshold_line and line_in must be of the same length if threshold_line is
        %> not a scalar value.
        %> @retval
        %> - Nx2 matrix of start and stop pairs of the sample points where where line_in is
        %> greater (i.e. crosses) than threshold_line
        %> - An empty matrix if no pairings are found
        %> @note Lifted from informaton/sev suite.  Authored by Hyatt Moore, IV (< June, 2013)
        function x = thresholdcrossings(line_in, threshold_line)

            if(nargin==1 && islogical(line_in))
                ind = find(line_in);
            else
                ind = find(line_in>threshold_line);
            end
            cur_i = 1;

            if(isempty(ind))
                x = ind;
            else
                x_tmp = zeros(length(ind),2);
                x_tmp(1,:) = [ind(1) ind(1)];
                for k = 2:length(ind)
                    if(ind(k)==x_tmp(cur_i,2)+1)
                        x_tmp(cur_i,2)=ind(k);
                    else
                        cur_i = cur_i+1;
                        x_tmp(cur_i,:) = [ind(k) ind(k)];
                    end
                end
                x = x_tmp(1:cur_i,:);
            end
        end

        % ======================================================================
        %> @brief Merges events, that are separated by less than some minimum number
        %> of samples, into a single event that stretches from the start of the first event
        %> and spans until the last event of each minimally separated event
        %> pairings.  Events that are not minimally separated by another
        %> event are retained with the output.
        %> @param event_mat_in is a two column matrix
        %> @param min_samples is a scalar value
        %> @retval merged_events The output of merging event_mat's events
        %> that are separated by less than min_samples.
        %> @retval merged_indices is a logical vector of the row indices that
        %> were merged from event_mat_in. - these are the indices of the
        %> in event_mat_in that are removed/replaced
        %> @note Lifted from SEV's CLASS_events.m - authored by Hyatt Moore
        %> IV
        % =================================================================
        function [merged_events, merged_indices] = merge_nearby_events(event_mat_in,min_samples)

            if(nargin==1)
                min_samples = 100;
            end

            merged_indices = false(size(event_mat_in,1),1);

            if(~isempty(event_mat_in))
                merged_events = zeros(size(event_mat_in));
                num_events_out = 1;
                num_events_in = size(event_mat_in,1);
                merged_events(num_events_out,:) = event_mat_in(1,:);
                for k = 2:num_events_in
                    if(event_mat_in(k,1)-merged_events(num_events_out,2)<min_samples)
                        merged_events(num_events_out,2) = event_mat_in(k,2);
                        merged_indices(k) = true;
                    else
                        num_events_out = num_events_out + 1;
                        merged_events(num_events_out,:) = event_mat_in(k,:);
                    end
                end
                merged_events = merged_events(1:num_events_out,:);
            else
                merged_events = event_mat_in;
            end
        end        
        
        %> @brief Parses the input file's basename (i.e. sans folder and extension)
        %> for the study id.  This will vary according from site to site as
        %> there is little standardization for file naming.
        %> @param  File basename (i.e. sans path and file extension).
        %> @retval Study ID
        function studyID = getStudyIDFromBasename(baseName)
            % Appropriate for GOALS output
            try
                studyID = baseName(1:6);
            catch me
                studyID = baseName;
            end
        end
    end
end