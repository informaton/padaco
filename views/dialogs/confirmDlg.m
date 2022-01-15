% --------------------------------------------------------------------
function isConfirmed = confirmDlg(promptStr, titleStr)
    %figObj = load('confirmDlg.fig','-mat');    
    narginchk(1,2);
    if nargin<2
        titleStr = 'Confirm';
    end
    % a shameless hack
    isConfirmed = false;    
    f = openfig('confirmDlg.fig','invisible');
    function clickedYesCb(varargin)        
        isConfirmed = true;
        close(f);
    end
    handles=guihandles(f);
    set(handles.push_yes,'callback',@clickedYesCb);
    set(handles.push_no,'callback','closereq');
    set(handles.text,'string',promptStr);
    set(f,'name',titleStr,'visible','on','closeRequestFcn','closereq') 
    waitfor(f);    
end

%     choice = questdlg(promptStr, titleStr, ...
%         'Yes','No','Yes');
%     isConfirmed = strncmp(choice, 'Yes', 3);



