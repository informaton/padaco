function handles  = resizePanelAndFigureForUIControls(panel_h,num_rows_desired,handles,optional_vertical_buffer)
%
%panel_h is the handle of the panel that is to be resized
%num_rows_desired = number of rows to be used; if this is smaller than the
%current number of rows, then the rows in excess will be hidden.  If this
%is larger than the current of rows in panel_h, then additional uicontrols
%will be added for each row.
%handles = 
%optional_vertical_buffer = optional distance to offset uicontrols from
%the top and bottom of the panel.

% Hyatt Moore, IV (August, 2013)



parent_h = get(panel_h,'parent');
parentFig = parent_h;

while(~strcmpi(get(parentFig,'type'),'figure'))
    parentFig = get(parentFig,'parent');
end

peer_h = get(parent_h,'children');
pan_children_h = get(panel_h,'children');

if(nargin<3||isempty(handles))
    handles = guidata(parent_h);
end

%find the largest suffix that currently exists...
pan_children_tag = get(pan_children_h,'tag');
f=regexp(pan_children_tag,'.*_(?<suffix>\d+)','names');
suffixes = zeros(numel(f),1);

for k=1:numel(f)
    if(isempty(f{k}))
        suffixes(k)=-1;
    else
        suffixes(k) = str2double(f{k}.suffix);
    end
end
 %the largest tag suffix that we have.
 % later we will add or (remove||hide)
max_suffix = max(suffixes);
min_suffix = min(suffixes);

%let's calculate the size that we need to set this too now.
%get the units so we can restore later
parent_units0 = get(parent_h,'units');
peer_units0 = get(peer_h,'units');
pan_children_units0 = get(pan_children_h,'units');
if(numel(peer_h)==1) %only dealing with the panel itself, so don't worry about things
    peer_units0 = {peer_units0};
end
if(~iscell(pan_children_units0))
    pan_children_units0 =  {pan_children_units0};
end

%normalize the units to pixels
set([parent_h;peer_h;pan_children_h],'units','pixels');

panel_pos = get(panel_h,'position');
parent_pos = get(parent_h,'position');
peer_pos = get(peer_h,'position');

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
tag_prefixes = unique({parseStr.prefix});

first_uicontrol_pos = get(first_uicontrol_h,'position');

%could be a cell if we have a column wise layout for unique control types
if(iscell(first_uicontrol_pos))
    first_uicontrol_pos = cell2mat(first_uicontrol_pos);
end

original_panel_height = panel_pos(4);

%if not passed an optional height offset then we should go ahead and
%calculate it based on the distance between the top of the panel and the
%lowest y_position from the uicontrol with the smallest suffix (i.e. assume
%we order suffixes from 1 to N, starting from the top and working our way
%down to the bottom of the panel.
if(nargin<4||isempty(optional_height_offset))
    vertical_buffer = min(original_panel_height-sum([first_uicontrol_pos(:,2),first_uicontrol_pos(:,4)],2));
else
    vertical_buffer = optional_vertical_buffer;
end

delta_h = original_panel_height-min(first_uicontrol_pos(:,2));

new_panel_height = (num_rows_desired)*delta_h+vertical_buffer;

%negative value means we expanded
%positive value means we shrunk
delta_panel_height = original_panel_height-new_panel_height; %i.e. new_height+delta_height = original_height

%do we need to adjust up or down?
if(new_panel_height~=original_panel_height)
    for k =1:max(max_suffix,num_rows_desired)
        for t=1:numel(tag_prefixes)
            tmp_h = first_uicontrol_h(t);
            tmp_pos = first_uicontrol_pos(t,:);
            y_offset = new_panel_height-(original_panel_height-tmp_pos(2))-delta_h*(k-1);
            tagStr = sprintf('%s_%u',tag_prefixes{t},k);
            tmp_pos(2) = y_offset;
            


            %add
            if(k>max_suffix)
                if(~isfield(handles,tagStr)||~ishandle(handles.(tagStr)))
                    handles.(tagStr) = copyobj(tmp_h,panel_h);
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
            
            set(handles.(tagStr),'tag',tagStr,'position',tmp_pos);
            if(isempty(get(handles.(tagStr),'string')))
                set(handles.(tagStr),'string',tagStr);
            end
        end
    end
    
    pan_children_pos = cell2mat(get(pan_children_h,'position'));   
    
    %y_location remains the same, but the height changes
    new_panel_pos = [panel_pos(1), panel_pos(2), panel_pos(3), new_panel_height];

    peers_above = peer_pos(:,2)>panel_pos(2);  %peers above
   
    new_parent_pos = [parent_pos(1), parent_pos(2)+delta_panel_height, parent_pos(3), parent_pos(4)-delta_panel_height];
    
    %move the peers above up according to the changed shape...
    peer_pos(peers_above,2) = peer_pos(peers_above,2)-delta_panel_height;

    set(parent_h,'position',new_parent_pos);
    peer_pos(peer_h==panel_h,:) = new_panel_pos;

    for k=1:numel(peer_h)
        set(peer_h(k),'position',peer_pos(k,:),'units',peer_units0{k})
    end
    
    %adjust everything up the newly resized panel
    for k=1:numel(pan_children_h)
        set(pan_children_h(k),'position',pan_children_pos(k,:),'units',pan_children_units0{k});
    end
    
    set(parent_h,'units',parent_units0);
end

