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
    summary = nonwear;
    % nonwearRows = PAStatTool.getNonwearRows(nonwear.methods, nonwear);
    isSpecial = true;
    
    if isSpecial
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
                resultStr = sprintf(['Nonwear Occurrences from %d:00 to %d:00:\n',...
                    ' * Profiles with nonwear: %d of %d\n',...
                    ' * Unique individuals with nonwear: %d of %d'],...
                    startHour, endHour, ...
                    nonwear_occurrences, num_rows,...
                    num_unique_subjects_with_nonwear, num_unique_subjects);
                fprintf('%s\n', resultStr);

            end
        end
        
        % rows = nonwear.rows;
        
        nonwear_occurrences = sum(rows);        
        num_unique_subjects_with_nonwear = numel(unique(studyIDs(rows)));
        resultStr = sprintf(['Nonwear Occurrences:\n',...
            ' * Profiles with nonwear: %d of %d\n',...
            ' * Unique individuals: %d of %d'],...
            nonwear_occurrences, num_rows,...
            num_unique_subjects_with_nonwear, num_unique_subjects);
        fprintf('%s\n', resultStr);
     
    end
end