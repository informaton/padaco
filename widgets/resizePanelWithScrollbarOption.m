function handles  = resizePanelWithScrollbarOption(innerPanel_H,verticalScrollbarH,num_rows_desired, num_rows_displayable,handles,optional_ceiling_buffer)
    %
    %panel_h is the handle of the panel that is to be resized
    %num_rows_desired = number of rows to be used; if this is smaller than the
    %current number of rows, then the rows in excess will be hidden.  If this
    %is larger than the current of rows in panel_h, then additional uicontrols
    %will be added for each row.
    %handles =
    %optional_vertical_buffer = optional distance to offset uicontrols from
    %the top and bottom of the panel.
    
    % Hyatt Moore, IV 3/8/2016
    
    containerPanel_h = get(innerPanel_H,'parent');
    figureH = containerPanel_h;
    
    while(~strcmpi(get(figureH,'type'),'figure'))
        figureH = get(figureH,'parent');
    end
    
    peer_h = get(figureH,'children');
    
    % Remove possible overlap with any peers
    peer_h(peer_h==containerPanel_h)=[];
    peer_h(peer_h==verticalScrollbarH)=[];
    
    pan_children_h = get(innerPanel_H,'children');
    
%     handles = guidata(figureH);
    
    %find the largest suffix that currently exists...
    pan_children_tag = get(pan_children_h,'tag');
    f=regexp(pan_children_tag,'.*_(?<suffix>\d+)','names');
    
    % remove potentially empty suffixes here so we have a better chance
    % below.  
    f(cellfun(@isempty,f))=[];
    try
        suffixes = cellfun(@(x)str2double(x.suffix),f);
    catch me
        suffixes = zeros(numel(f),1);
        for k=1:numel(f)
            if(isempty(f{k}))
                suffixes(k)=-1;
            else
                suffixes(k) = str2double(f{k}.suffix);
            end
        end
    end
    %the largest tag suffix that we have.
    % later we will add or (remove||hide)
    max_suffix = max(suffixes);
    min_suffix = min(suffixes(suffixes>-1));
    
    %let's calculate the size that we need to set this too now.
    %get the units so we can restore later
    innerPanel_units0 = get(innerPanel_H,'units');
    containerPanel_units0 = get(containerPanel_h,'units');
    peer_units0 = get(peer_h,'units');
    pan_children_units0 = get(pan_children_h,'units');
    
    figure_units0 = get(figureH,'units');
    scrollbar_units0 = get(verticalScrollbarH,'units');
    
    if(numel(peer_h)==1) %only dealing with the panel itself, so don't worry about things
        peer_units0 = {peer_units0};
    end
    if(~iscell(pan_children_units0))
        pan_children_units0 =  {pan_children_units0};
    end
    
    %normalize the units to pixels
    set([innerPanel_H
        containerPanel_h
        peer_h
        pan_children_h
        figureH
        verticalScrollbarH],'units','pixels');
    
    % Get everyone's position
    innerPanel_pos = get(innerPanel_H,'position');
    containerPanel_pos = get(containerPanel_h,'position');
    figure_pos = get(figureH,'position');
    peer_pos = get(peer_h,'position');
    verticalScrollbar_pos = get(verticalScrollbarH,'position');
    
    if(iscell(peer_pos))
        peer_pos = cell2mat(peer_pos);
    end
    
    %first - i.e. first row of ui control handles
    first_uicontrol_h = findobj(pan_children_h,'-regexp','tag',sprintf('.*_%u$',min_suffix));
    tags = get(first_uicontrol_h,'tag');
    parseStr=regexp(tags,'(?<prefix>.+)_\d+','names');
    
    if(iscell(parseStr))
        parseStr = cell2mat(parseStr);
    end
    
    % tag_prefixes = struct2cell(parseStr);
    
    % Sometimes these get out of order when sorted, which causes problems
    % on the x location
    [tag_prefixes, ia] = unique({parseStr.prefix});
    [~,indSort] = sort(ia,'ascend');
    tag_prefixes = tag_prefixes(indSort);
    
    %     [tag_prefixes, ia, ic] = unique({'events_text','events_edit','events_text','events_edit'})
    
    first_uicontrol_pos = get(first_uicontrol_h,'position');
    
    %could be a cell if we have a column wise layout for unique control types
    if(iscell(first_uicontrol_pos))
        first_uicontrol_pos = cell2mat(first_uicontrol_pos);
    end
    
    original_containerPanel_height = containerPanel_pos(4);
    original_innerPanel_height = innerPanel_pos(4);
    
    %if not passed an optional height offset then we should go ahead and
    %calculate it based on the distance between the top of the panel and the
    %lowest y_position from the uicontrol with the smallest suffix (i.e. assume
    %we order suffixes from 1 to N, starting from the top and working our way
    %down to the bottom of the panel.
    if(nargin<6 || isempty(optional_height_offset))
        ceilingBuffer = min(original_innerPanel_height-sum([first_uicontrol_pos(:,2),first_uicontrol_pos(:,4)],2));
        %ceilingBuffer = 11,21;     
        ceilingBuffer = 11;
    else
        ceilingBuffer = optional_ceiling_buffer;
    end
    % rowHeight = original_innerPanel_height-min(first_uicontrol_pos(:,2));
    rowHeight = ceilingBuffer+max(first_uicontrol_pos(:,4));
    
    
    num_rows_displayed = min(num_rows_desired, num_rows_displayable);
    new_containerPanel_height = (num_rows_displayed)*rowHeight+ceilingBuffer;
    new_innerPanel_height = (num_rows_desired)*rowHeight+ceilingBuffer;
    
    %negative value means we expanded
    %positive value means we shrunk
    delta_outerPanel_height = original_containerPanel_height-new_containerPanel_height; %i.e. new_height+delta_height = original_height
    
    delta_innerOuterPanel_height = new_innerPanel_height - new_containerPanel_height;  %figure out if I have a gap/need a scrollbar
    
    % if == Do we need to adjust up or down? A y-value of '1' is at the
    % bottom of the settings figure and should correspond to the number of
    % rows desired (i.e. highest tag(k) should have the small y-offset.
    if(new_containerPanel_height~=original_containerPanel_height)
        for k =1:max(num_rows_desired,max_suffix) % these are the rows
            for t=1:numel(tag_prefixes)  % these are the columns in each row
                
                tmp_h = first_uicontrol_h(t);
                tmp_pos = first_uicontrol_pos(t,:);
                % If we don't adjust k as "num_rows_desired-k+1" then we will
                % be placing our lowest k index at the bottom of the settings window (with the highest y-offset)
                % We don't want this though when we have tabs, because we
                % want to be able to reference the top of the settings
                % figure, which is what a viewer first sees and has
                % access to.
                y_offset = new_innerPanel_height-rowHeight*(k);  %num_rows_desired-k+1);
                tagStr = sprintf('%s_%u',tag_prefixes{t},k);
                tmp_pos(2) = y_offset;
                
                %add
                if(k>max_suffix)
                    if(~isfield(handles,tagStr)||~ishandle(handles.(tagStr)))
                        handles.(tagStr) = copyobj(tmp_h,innerPanel_H);
                        set(handles.(tagStr),'tag',tagStr);
                    end
                end
                
                %sometimes it exists deeper in the data
                if(~isfield(handles,tagStr))
                    handles.(tagStr) = findobj(pan_children_h,'tag',tagStr);
                end
                
                %shrink - make row invisible
                if(k>num_rows_desired)
                    set(handles.(tagStr),'visible','off');
                else
                    set(handles.(tagStr),'visible','on');
                end
                
                set(handles.(tagStr),'position',tmp_pos);
%                 if(isempty(get(handles.(tagStr),'string')))
%                     set(handles.(tagStr),'string',tagStr);
%                 end
            end
        end
        
        pan_children_pos = cell2mat(get(pan_children_h,'position'));
        
        %move the peers above up according to the changed shape...
        peers_above = peer_pos(:,2)>containerPanel_pos(2);  %peers above
        peer_pos(peers_above,2) = peer_pos(peers_above,2)-delta_outerPanel_height;
        
        
        %y_location shifts down when the inner panel is larger than the outer panel (thus cropped); height changes
        new_innerPanel_pos = [innerPanel_pos(1), ceilingBuffer/4-delta_innerOuterPanel_height, innerPanel_pos(3), new_innerPanel_height];
        set(innerPanel_H,'position',new_innerPanel_pos);
        set(innerPanel_H,'units',innerPanel_units0);
        
%         new_outerPanel_pos = [containerPanel_pos(1), containerPanel_pos(2)+delta_outerPanel_height, containerPanel_pos(3), containerPanel_pos(4)-delta_outerPanel_height];
        new_outerPanel_pos = [containerPanel_pos(1), containerPanel_pos(2), containerPanel_pos(3),new_containerPanel_height];
        
        new_figure_pos = [figure_pos(1), figure_pos(2)+delta_outerPanel_height, figure_pos(3), figure_pos(4)-delta_outerPanel_height];
        
        new_verticalScrollbar_pos = [verticalScrollbar_pos(1), new_outerPanel_pos(2), verticalScrollbar_pos(3), new_outerPanel_pos(4)];
        
        set(figureH,'position',new_figure_pos);
        
        
        %         set(containerPanel_h,'position',new_outerPanel_pos);
        %         peer_pos(peer_h==containerPanel_h,:) = new_outerPanel_pos;
        %         peer_pos(peer_h==verticalScrollbarH,:) = new_verticalScrollbar_pos;
        
        set(containerPanel_h,'position',new_outerPanel_pos);
        if(num_rows_desired>num_rows_displayed)
            minScrollbarValue = new_innerPanel_pos(2);
            maxScrollbarValue = ceilingBuffer/4;

            set(verticalScrollbarH,'position',new_verticalScrollbar_pos,'visible','on','min',minScrollbarValue,'max',maxScrollbarValue,'callback',{@scrollbarCallback,innerPanel_H,new_innerPanel_pos});
        else
            set(verticalScrollbarH,'visible','off');
        end
        
        for k=1:numel(peer_h)
            set(peer_h(k),'position',peer_pos(k,:));
            set(peer_h(k),'units',peer_units0{k});
        end
        
        %adjust everything up the newly resized panel
        for k=1:numel(pan_children_h)
            set(pan_children_h(k),'position',pan_children_pos(k,:))
            set(pan_children_h(k),'units',pan_children_units0{k});
        end
        
        set(innerPanel_H,'units',innerPanel_units0);
        set(containerPanel_h,'units',containerPanel_units0);
        set(figureH,'units',figure_units0);
        set(verticalScrollbarH,'units',scrollbar_units0);
        
    end
end

function scrollbarCallback(hObject, eventData, innerPanelH, innerPanelPos)
    innerPanelPos(2) = get(hObject,'min')+(get(hObject,'max')-get(hObject,'value'));
    
    set(innerPanelH,'position',innerPanelPos);
end
