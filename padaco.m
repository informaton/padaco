function padaco()
    
    mPathname = fileparts(mfilename('fullpath'));
    if(~isdeployed)
        addpath(mPathname);
        subPaths = {'widgets','figures','icons','utility','html','events'};
        for s=1:numel(subPaths)
            addpath(fullfile(mPathname,subPaths{s}));
        end
    end
    hObject = padacoFig('visible','off');
    handles = initializeGUI(hObject);

    try
        parametersFile = '_padaco.parameters.txt';
        handles.user.controller = PAController(hObject,mPathname,parametersFile);
        set(hObject,'visible','on');
        guidata(hObject,handles);
    catch me
        %     me.message
        %     me.stack(1)
        showME(me);
        fprintf(1,['The default settings file may be corrupted or inaccessible.',...
            '  This can occur when installing the software on a new computer or from editing the settings file externally.',...
            '\nChoose OK in the popup dialog to correct the settings file.\n']);
        resetDlg(hObject,fullfile(mPathname,parametersFile));
    end
    

end
function handles = initializeGUI(hObject)
    
    % set(hObject,'visible','on');
    figColor = get(hObject,'color');
    
    handles = guidata(hObject);
    set(handles.text_status,'backgroundcolor',figColor,'units','normalized');
    
    % ch = findall(hObject,'type','uipanel');
    % set(ch,'units','normalized');
    % set(ch,'backgroundcolor',figColor);
    %
    % ch = findobj(hObject,'-regexp','tag','text.*');
    %
    % ch(strcmp(get(ch,'type'),'uimenu'))=[];
    % set(ch,'backgroundcolor',figColor);
    
    ch = findobj(hObject,'-regexp','tag','axes.*');
    set(ch,'units','normalized');
    
    set(hObject,'closeRequestFcn','delete(gcbo)');
    
%     renderOffscreen(hObject);
    movegui(hObject,'northwest');
    
end

