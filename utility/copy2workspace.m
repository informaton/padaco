function copy2workspace(data2copy,workspaceName)
    if(nargin>0)
        if(nargin<2)
            workspaceName = 'dataTmp';
        end
        assignin('base',workspaceName,data2copy);
        uiwait(msgbox(sprintf('Data saved to workspace variable %s',workspaceName)));
    else
        errordlg('No data entered to send to work space');
    end
end
    
