function summary = getExclusionsSummary(exclusionsFile, varargin)
    if nargin<1 || isempty(exclusionsFile)
        exclusionsFile = fullfile('~/Documents/padaco','choi_and_imported_file_count_exclusions.mat');
    end
    if ~exist(exclusionsFile,'file')
        error('Exclusions file (%s) does not exist', exclusionsFile);
    end

    summary = ExclusionsSummary(exclusionsFile);
    for v=1:numel(varargin)
        flag = varargin{v};
        if strcmpi(flag, 'interactive')
            summary.showInteractiveSummary();
        elseif strcmpi(flag,'table')
            summary.showSummaryTable();
        else
            fprintf('Unrecognized flag (''%s'').  Valid flags include ''interactive'' and ''table''\n', flag);
        end
    end
end


