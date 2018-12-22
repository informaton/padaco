function padaco()
    
    mPathname = pathsetup();
    hObject = padacoFig('visible','off');
    handles = initializeGUI(hObject);

    try
        parametersFile = '_padaco.parameters.txt';
        handles.user.controller = PAController(hObject,mPathname,parametersFile);
        %         set(hObject,'visible','on');  % handled inside
        %         PAController constructor.
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
function handles = initializeGUI(hFigure)
    
    % set(hObject,'visible','on');
    figColor = get(hFigure,'color');
    defaultUnits = 'pixels';
    handles = guidata(hFigure);
    
    
       % get our panels looking nice and pretty.
            % This is taken care of in the initializeGUI call found in
            % padaco.m now
            %             set([
            %                     handles.panel_timeseries;
            %                     handles.panel_results
            %                 ],'backgroundcolor',[0.75,0.75,0.75]);
    
    set([handles.text_status;
        handles.panel_results;
        handles.panel_timeseries],'backgroundcolor',figColor,'units',defaultUnits);
    
    set([handles.panel_results;
         handles.panel_timeseries],'backgroundcolor',figColor...
                                   ,'units',defaultUnits...
                                   ,'bordertype','none');
    
    % ch = findall(hObject,'type','uipanel');
    % set(ch,'units','normalized');
    % set(ch,'backgroundcolor',figColor);
    %
    % ch = findobj(hObject,'-regexp','tag','text.*');
    %
    % ch(strcmp(get(ch,'type'),'uimenu'))=[];
    % set(ch,'backgroundcolor',figColor);
    
    % ch = findobj(hObject,'-regexp','tag','axes.*');
    % set(ch,'units','normalized');
    
    set(hFigure,'closeRequestFcn','delete(gcbo)');
    
    % More notes --->
    % Figure handle - pixels
    % Figure position -         [624, -67, 1460, 850]
    % panel_result              [49, 19, 221, 802]
    % panel_results_container   [11, 10, 200, 790]
    % panel_features            [10, 10.18, 288, 388.8]
    % panel_timeseries          [21, 418.26, 221, 401]
    % text_status               [30, 824.25, 201, 21]
    
    
    % Adjustments as panel results
    % 1460+ 221+19 (offset boarder for viewing) -> 1900
    % panel_result(1) = 1460
    set([hFigure
        handles.panel_timeseries
        handles.panel_results
        handles.panel_resultsContainer
        handles.panel_controlCentroid
        handles.panel_epochControls
        handles.panel_displayButtonGroup],'units','pixels');
    
    figPos = get(hFigure,'position');
    % Line our panels up to same top left position - do this here
    % so I can edit them easy in GUIDE and avoid to continually
    % updating the position property each time i need to drag the
    % panel(s) around to make edits.  Position is given as
    % 'x','y','w','h' with 'x' starting from left (and increasing right)
    % and 'y' starting from bottom (and increasing up)
    timeSeriesPanelPos = get(handles.panel_timeseries,'position');
    resultsPanelPos = get(handles.panel_results,'position');
    
    if(resultsPanelPos(1)>sum(timeSeriesPanelPos([1,3])))
        figPos(3) = resultsPanelPos(1);  % The start of the results panel (x-value) indicates the point that the figure should be clipped
        set(hFigure,'position',figPos);
        newResultsPanelY = sum(timeSeriesPanelPos([2,4]))-resultsPanelPos(4);
        set(handles.panel_results,'position',[timeSeriesPanelPos(1),newResultsPanelY,resultsPanelPos(3:4)]);
        
        %set(handles.panel_resultsContainer,'backgroundcolor',[0.9 0.9 0.9]);
        %set(handles.panel_resultsContainer,'backgroundcolor',[0.94 0.94 0.94]);
        %set(handles.panel_resultsContainer,'backgroundcolor',[1 1 1]);
        
        
        % Line up panel_controlCentroid with panel_epochControls
        epochControlsPos = get(handles.panel_epochControls,'position');
        coiControlsPos = get(handles.panel_controlCentroid,'position');
        coiControlsPos(2) = sum(epochControlsPos([2,4]))-coiControlsPos(4);  % This is y_ = y^ + h^ - h_
        set(handles.panel_controlCentroid,'position',coiControlsPos);
        drawnow();
        
        metaDataHandles = [handles.panel_study;get(handles.panel_study,'children')];
        set(metaDataHandles,'backgroundcolor',[0.94,0.94,0.94],'visible','off');
        
        %             whiteHandles = [handles.text_aggregate
        %                 handles.text_frameSizeMinutes
        %                 handles.text_frameSizeHours
        %                 handles.text_trimPct
        %                 handles.text_cullSuffix
        %                 handles.edit_trimToPercent
        %                 handles.edit_cullToValue
        %                 handles.panel_features_prefilter
        %                 handles.panel_features_aggregate
        %                 handles.panel_features_frame
        %                 handles.panel_features_signal
        %                 handles.panel_plotType
        %                 handles.panel_plotSignal
        %                 handles.panel_plotData
        %                 handles.panel_controlCentroid
        %                 handles.panel_plotCentroid];
        whiteHandles = [handles.panel_features_prefilter
            handles.panel_features_aggregate
            handles.panel_features_frame
            handles.panel_features_signal
            handles.panel_plotType
            handles.panel_plotSignal
            handles.panel_plotData
            handles.panel_controlCentroid
            handles.panel_plotCentroid];
        sethandles(whiteHandles,'backgroundcolor',[1 1 1]);
        %set(whiteHandles,'backgroundcolor',[0.94,0.94,0.94]);
        %            set(findobj(whiteHandles,'-property','backgroundcolor'),'backgroundcolor',[0.94 0.94 0.94]);
        
        %             set(findobj(whiteHandles,'-property','shadowcolor'),'shadowcolor',[0 0 0],'highlightcolor',[0 0 0]);
        
        innerPanelHandles = [handles.panel_centroidSettings
            handles.panel_timeFrame];
        sethandles(innerPanelHandles,'backgroundcolor',[0.9 0.9 0.9]);
        
        % Make the inner edit boxes appear white
        set([handles.edit_centroidMinimum
            handles.edit_centroidThreshold],'backgroundcolor',[1 1 1]);
        
        set(handles.text_threshold,'tooltipstring','Smaller thresholds result in more stringent conversion requirements and often produce more clusters than when using higher threshold values.');
        % Flush our drawing queue
        drawnow();
    end
    
    
    
    
    
%     renderOffscreen(hObject);
    movegui(hFigure,'northwest');
    
end

