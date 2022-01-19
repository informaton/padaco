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
    nonwearRows = PAStatTool.getNonwearRows(nonwear.methods, nonwear);
end