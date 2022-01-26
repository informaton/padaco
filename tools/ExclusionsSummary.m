classdef ExclusionsSummary < handle
    properties(SetAccess=protected)
        exclusions_filename;
        summaryStruct;
    end
    
    methods
        function this = ExclusionsSummary(exclusions_filename)
            if nargin > 0
                this.setExclusionsFilename(exclusions_filename);
            end
        end
        function didSet = setExclusionsFilename(this, exclusionsFilename)
            narginchk(2,2);
            didSet = false;
            if exist(exclusionsFilename, 'file')
                this.summaryStruct = this.getExclusionsSummary(exclusionsFilename);
                if ~isempty(this.summaryStruct)
                    this.exclusions_filename = exclusionsFilename;
                    didSet = true;
                end
            end
        end
        
        function showInteractiveSummary(this, summary, varargin)
            if nargin<2 || isempty(summary)
                summary = this.summaryStruct;
            end
            if isempty(summary)
                fprintf('Summary data is empty.  Cannot show interactive summary.\n');
            else
                this.interactiveSummary(summary, varargin{:});
            end            
        end
        
        function showSummaryTable(this, summary, varargin)
            if nargin<2 || isempty(summary)
                summary = this.summaryStruct;
            end
            if isempty(summary)
                fprintf('Summary data is empty.  Cannot show summary table.\n');
            else
                this.printSummary(summary, varargin{:});
            end            
        end
        
    end
    methods(Static)
        
        function printSummary(summary, min_start, min_duration)
            if nargin< 3
                min_duration = 12; %12 hours
                if nargin<2
                    min_start = 5; % 5:00am or later
                end
            end
            
            idx = summary.duration>=min_duration & summary.startHour>= min_start;
            s_profiles_per_subject = summary.nonwear_profiles_per_subject(idx);
            s_unique_subjects_excluded = summary.num_unique_subjects_with_exclusion(idx);
            s_profiles_excluded = summary.num_profiles_with_exclusion(idx);
            s_duration = summary.duration(idx);
            s_startHour = summary.startHour(idx);
            s_endHour = summary.endHour(idx);
            s_time_str =summary.time_str(idx);
            s_resultStr = summary.result_str(idx);
            
            fprintf('Start-Stop, Duration (h), Profiles Excluded (n), Unique Individuals Excluded (n)\n');
            for s=1:numel(s_resultStr)
                fprintf('%s, %d, %d, %d \n', s_time_str{s}, s_duration(s), s_profiles_excluded(s), s_unique_subjects_excluded(s));
                % fprintf('%s\n', s_resultStr{s});
            end
            
            fprintf('\n\t\tSubjects with x+ profiles\n');
            fprintf(' Start-Stop, Duration (h), 0 profiles (n), 1+ (n), 2+ (n), 3+ (n), 4+ (n), 5+ (n), 6+ (n), 7+ (n)\n');
            for s=1:numel(s_resultStr)
                zero_count = 0;
                fprintf('%s, %d, %d', s_time_str{s}, s_duration(s), zero_count);
                for n=1:7
                    n_count = n;
                    fprintf(', %d', n_count);
                end
                fprintf('\n');
            end            
            
        end
        
        function interactiveSummary(summary, min_start, min_duration)
            if nargin< 3
                min_duration = 12; %12 hours
                if nargin<2
                    min_start = 5; % 5:00am or later
                end
            end
            
            idx = summary.duration>=min_duration & summary.startHour>= min_start;
            s_profiles_per_subject = summary.nonwear_profiles_per_subject(idx);
            s_unique_subjects = summary.num_unique_subjects_with_exclusion(idx);
            s_profiles_excluded = summary.num_profiles_with_exclusion(idx);
            s_duration = summary.duration(idx);
            s_startHour = summary.startHour(idx);
            s_endHour = summary.endHour(idx);
            s_time_str =summary.time_str(idx);
            s_resultStr = summary.result_str(idx);
            figure('numbertitle','off','name','Exclusions Summary'); %,'menubar','none');
            
            s = scatter(s_duration, s_profiles_per_subject);
            xlabel('Hours evaluated (h)');
            ylabel('Profiles excluded per subject (n)');
            % s.DataTipTemplate.DataTipRows(1).Label='Hours evaluted';
            % s.DataTipTemplate.DataTipRows(2).Label='Profiles excluded per subject';
            %s.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('Start',s_startHour,'%02d:00');
            %s.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('Stop',s_endHour,'%02d:00');
            s.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('Time',s_time_str);
            
            s.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('Unique subject',s_unique_subjects);
            s.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('Profiles',s_profiles_excluded);
            % s.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('Summary', s_resultStr);
            set(gca,'box','on');
            % rows = nonwear.rows;
        end
        
        function summary = getExclusionsSummary(exclusionsFile)
            summary = struct();
            narginchk(1,1);

            if ~exist(exclusionsFile,'file')
                error('Exclusions file (%s) does not exist', exclusionsFile);
            end

            mat = load(exclusionsFile,'-mat');
            if isempty(mat) || ~isfield(mat, 'nonwear')
                error('Exclusions files (%s) is malformed.  Missing ''nonwear'' field', exclusionsFile);
            end
            if isempty(which('PAStatTool'))
                error('Run <strong>pathsetup</strong> first. It is located in Padaco''s main directory');
            end
            nonwear = mat.nonwear;
            
            % nonwearRows = PAStatTool.getNonwearRows(nonwear.methods, nonwear);
            isSpecial = true;
            if ~isSpecial
                summary = nonwear;
            elseif isSpecial
                [p, c] = PAStatTool.intersectExclusions(nonwear.imported_file.padaco, nonwear.choi);
                
                c.startHours = hours(duration(c.startTimes,'inputformat','hh:mm'));
                p.startHours = hours(duration(p.startTimes,'inputformat','hh:mm'));
                nonwear.methods = {'padaco','choi'};
                nonwear.padaco = p;
                
                studyIDs = nonwear.studyIDs;
                num_unique_subjects = numel(unique(studyIDs));
                num_rows = numel(nonwear.rows);
                
                curEntry=0;
                numEntries = sum(1:24);
                startStopHours = nan(numEntries, 2);
                summary.startHour = startStopHours(:,1);
                summary.endHour = startStopHours(:,1);
                summary.duration = nan(numEntries,1);
                summary.time_str = cell(numEntries,1);
                summary.num_unique_subjects_with_exclusion = nan(numEntries,1);
                summary.num_profiles_with_exclusion = nan(numEntries,1);
                summary.result_str  = cell(numEntries,1);
                for startHour = 0:23
                    for endHour = startHour+1:24
                        curEntry=curEntry+1;
                        startStopHours(curEntry,:) = [startHour, endHour];
                        choiRange = c.startHours>=startHour & c.startHours<=endHour;
                        pRange = p.startHours>=startHour & p.startHours<=endHour;
                        nonwear.padaco.shapes = p.shapes(:, pRange);
                        nonwear.choi.shapes = c.shapes(:, choiRange);
                        rows = PAStatTool.getNonwearRows({'padaco','choi'},nonwear);
                        
                        nonwear_occurrences = sum(rows);
                        num_unique_subjects_with_nonwear = numel(unique(studyIDs(rows)));
                        summary.time_str{curEntry} = sprintf('%02d:00-%02d:00', startHour, endHour);
                        resultStr = sprintf(['Nonwear Occurrences from %d:00 to %d:00:\n',...
                            ' * Profiles with nonwear: %d of %d\n',...
                            ' * Unique individuals with nonwear: %d of %d'],...
                            startHour, endHour, ...
                            nonwear_occurrences, num_rows,...
                            num_unique_subjects_with_nonwear, num_unique_subjects);
                        summary.startHour(curEntry) = startHour;
                        summary.endHour(curEntry) = endHour;
                        summary.result_str{curEntry} = resultStr;
                        summary.num_unique_subjects_with_exclusion(curEntry) = num_unique_subjects_with_nonwear;
                        summary.num_profiles_with_exclusion(curEntry) = nonwear_occurrences;
                    end
                end
                
                summary.duration = summary.endHour-summary.startHour;
                summary.nonwear_profiles_per_subject = summary.num_profiles_with_exclusion./summary.num_unique_subjects_with_exclusion;
                
                summary.nonwear_profiles_per_subject(isinf(summary.nonwear_profiles_per_subject)) = nan; % address divide by 0 this way.
                
            end
        end

    end
end