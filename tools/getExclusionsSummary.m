function summary = getExclusionsSummary(exclusionsFile)
    summary = struct();
    if nargin<1 || isempty(exclusionsFile)
        exclusionsFile = fullfile('~/Documents/padaco','choi_and_imported_file_count_exclusions.mat');
    end
    
    if ~exist(exclusionsFile,'file')
        error('Exclusions file (%s) does not exist', exclusionsFile);
    end
    
    mat = load(exclusionsFile,'-mat');
    if isempty(mat) || ~isfield(mat, 'nonwear')
        error('Exclusions files (%s) is malformed.  Missing ''nonwear'' field', exclusionsFile);
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
                
                % fprintf('%s\n', resultStr);
            end
        end
        
        summary.duration = summary.endHour-summary.startHour;
        summary.nonwear_profiles_per_subject = summary.num_profiles_with_exclusion./summary.num_unique_subjects_with_exclusion;

        summary.nonwear_profiles_per_subject(isinf(summary.nonwear_profiles_per_subject)) = nan; % address divide by 0 this way.
        
        % min duration = 10 hours
        min_duration = 10;
        min_start = 5;
        
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
end