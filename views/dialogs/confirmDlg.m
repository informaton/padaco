% --------------------------------------------------------------------
function isConfirmed = confirmDlg(promptStr, titleStr)
    narginchk(1,2);
    if nargin<2 || isempty(titleStr)
        titleStr = '';
    end

    choice = questdlg(promptStr, titleStr, ...
        'Yes','No','Yes');
    isConfirmed = strncmp(choice, 'Yes', 3);
end

