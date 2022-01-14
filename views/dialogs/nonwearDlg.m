function [selection, okayChecked] = nonwearDlg(nonwearOptions, currentSelections)
    if nargin<1
        padacoDefaults = PAStatTool.getDefaults();
        discardDefaults = padacoDefaults.discardMethod;
        nonwearOptions = discardDefaults.categories;
    end
    if nargin<2 || isempty(currentSelections)
        currentIndices = 1;
    else
        [~, currentIndices, ~] = intersect(nonwearOptions, currentSelections);
    end
    
    name = 'Nonwear Selection';    
    promptString = 'Select method(s) for nonwear exclusion';
    selectionMode = 'multiple';
    listSize = [200, 100];
    
    [selection, okayChecked] = listdlg('liststring',nonwearOptions,...
        'name',name,'promptString',promptString,...
        'listSize',listSize,...
        'initialValue',currentIndices,'selectionMode',selectionMode);

end