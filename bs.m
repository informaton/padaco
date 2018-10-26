function bootstrapFcn(hObject,eventdata,handles,se_vs_sp_alpha,getAUC_flag)
%hObject's userdata will contain the config_ind of the selected point.
%config_ind is the index of the point selected by the user which indexes
%into the TPR and FPR field values in all_userdata which can be used to
%create a model for the rule/weight of this point in choosing the matching
%points from the bootstrap runs.
%
%If se_vs_sp_alpha is empty, then a bootstrap of the current configuration
%is performed in order to obtain 95% CI of sensitivity and specficity of
%the current configuration index instead.
%
%if getAUC is included and true then compute the 95% AUC CI as well

%retrieve the userdata from the parent figure....
all_userdata = get(get(get(hObject,'parent'),'parent'),'userdata');

decimal_format = ['%0.',num2str(handles.user.settings.decimal_places,'%d'),'f'];


% 1. get all bootstrap indices for the number of bootstraps desired
% (settings)
sample_size = all_userdata.sample_size;
numBootstraps = handles.user.settings.bootstrap_iterations;
boot_ind = randi(sample_size,[numBootstraps,sample_size]);
 
% 2. run the bootstrap function using these samples instead
handles = excludeBadRows(handles); %remove unwanted rows based on exclusion criteria established in settings

params = handles.user.paramStruct.params;
controls = handles.user.controlStruct;
config_mat = handles.user.paramStruct.config_mat;

if(nargin<4)
    %determine ROC confidence interval for one configuration
    config_ind = get(hObject,'userdata');
    se_vs_sp_alpha = [];
    config_mat = config_mat(config_ind,:);  %only use the selected configuration...
    bootstrapped_TPR = zeros(numBootstraps,1);
    bootstrapped_FPR = zeros(numBootstraps,1); 
    getAUC_flag = false;
else
    %otherwise determine the configuration Confidence Intervals
    bootstrapped_config = zeros(numBootstraps,size(config_mat,2));
    
    %if getAUC_flag is included and true, compute the 95% AUC CI as well
    if(nargin<5 || isempty(getAUC_flag))
        getAUC_flag = false;
    elseif(getAUC_flag)
        bootstrapped_AUC = zeros(numBootstraps,1);  
    end
end;

%could estimate the time required for one iteration ... 
%[TPR,FPR,K_1_0,K_0_0, CohensKappa,PPV,NPV, EFF,chi_square,P, Q] = confusion2roc(handles.user.confusion, sample_size);
 

h=waitbar(0,'Bootstrapping');


num_symptoms = numel(params);
for n = 1:numBootstraps
    
    %resample the raw symptoms with matching resample of
    %controls/positivity (i.e. controls.raw)
    for k=1:num_symptoms
        params(k).raw = handles.user.paramStruct.params(k).raw(boot_ind(n,:),:);
    end    
    controls.raw = handles.user.controlStruct.raw(boot_ind(n,:),:);
    
    %get the confusion values for the resampled data and obtain ROC results
    [confusion,sample_size] = getConfusion(handles, controls, params, config_mat);
    
    [TPR,FPR,K_1_0,K_0_0, CohensKappa,PPV,NPV, EFF,chi_square,P, Q] = confusion2roc(confusion, sample_size);

    if(getAUC_flag)
        optimal_indices = getOutermostROCIndices(TPR,FPR);
        outer_TPR = [0;TPR(optimal_indices);1];
        outer_FPR = [0;FPR(optimal_indices);1];
        AUC = trapz(outer_FPR,outer_TPR);
        bootstrapped_AUC(n) = AUC;
    else
        if(~isempty(se_vs_sp_alpha))
            %get the optimal point based on the rule established via slider or
            %model parameter extraction
            model_fcn = (1-se_vs_sp_alpha)*TPR+(se_vs_sp_alpha).*(1-FPR);
            bootstrap_config_ind = max(model_fcn)==model_fcn;
            bootstrapped_config(n,:) = mean(config_mat(bootstrap_config_ind,:),1); %take the mean of the columns
        else
            bootstrapped_TPR(n) = TPR(1); %put the (1) here in case duplicate entries returned above
            bootstrapped_FPR(n) = FPR(1);
        end
    end
    
    
    if(mod(n,5)==0)
        waitbar(n/numBootstraps,h);
    end
end

%calculate 95% confidence intervals using (1) basic percentile and (2)
%normal/gaussian approximations

%1 basic percentile
CI = 95;  %i.e. we want the 95% confidence interval
CI_alpha = 100-CI;
CI_range = [CI_alpha/2, 100-CI_alpha/2];  %[2.5, 97.5]

if(getAUC_flag)
    ROC_label = 'AUC';
    AUC_CI_percentile = prctile(bootstrapped_AUC,CI_range);
    message = cell(2,1); %header+AUC
    message{1} = sprintf('95%% Confidence Interval of ROC''s AUC using\n\tbootstrap iterations = %i\n\tsample size = %i\n',numBootstraps,sample_size);
    message{2} = sprintf(['%s [',decimal_format,', ',decimal_format,']'],ROC_label,AUC_CI_percentile(1)*100,AUC_CI_percentile(2)*100);
else
    if(isempty(se_vs_sp_alpha))
        ROC_CI_percentile = prctile([bootstrapped_TPR,bootstrapped_FPR],CI_range); %==> [SE_lower,SP_lower; SE_higher, SP_higher]
        message = cell(num_symptoms+3,1); %symptoms+header+TPR+FPR
        message{1} = sprintf('95%% Confidence Interval(s) using\n\tbootstrap iterations = %i\n\tsample size = %i\n',numBootstraps,sample_size);
        
        if(handles.user.settings.plot_tpr_vs_fpr)
            ROC_label1 = 'TPR';
            ROC_label2 = 'FPR';
        else
            ROC_label1 = 'Sensitivity';
            ROC_label2 = 'Specificity';
            ROC_CI_percentile(:,2) = 1-flipud(ROC_CI_percentile(:,2)); %need to flip this so that lowever value is on top after the subtraction
        end
        paramCell = handles.user.paramStruct.params;
        for k = 1:numel(paramCell)
            message{k+1} = [paramCell(k).label,'(',num2str(config_mat(k),decimal_format),')'];
        end
        message{end-1} = sprintf(['%s [',decimal_format,', ',decimal_format,']'],ROC_label1,ROC_CI_percentile(1,1)*100,ROC_CI_percentile(2,1)*100);
        message{end} =   sprintf(['%s [',decimal_format,', ',decimal_format,']'],ROC_label2,ROC_CI_percentile(1,2)*100,ROC_CI_percentile(2,2)*100);
    else
        config_CI_percentile = prctile(bootstrapped_config,CI_range);
        %handle the case when only one row/configuration is made in which case the
        %prctile function outputs a (1x2) vector that is incompatible with the
        %message labeling system used below
        if(numel(config_CI_percentile)==2)
            config_CI_percentile = config_CI_percentile';
        end
        message = cell(num_symptoms+1,1);
        message{1} = sprintf('95%% Confidence Interval(s) using\n\tbootstrap iterations = %i\n\tsample size = %i\n',numBootstraps,sample_size);
        
        paramCell = handles.user.paramStruct.params;
        for k = 1:numel(paramCell)
            message{k+1} = [paramCell(k).label,' [ ',num2str(config_CI_percentile(1,k),decimal_format),', ',num2str(config_CI_percentile(2,k),decimal_format),']'];
        end
        
    end
end
delete(h);
msgbox(message,'Confidence','modal');
    

%in retrospect - gaussian based confidence intervals were removed as the
%configurations are uniformly distributed across user established ranges

%2 normal/gaussian approxmation
% observed_config = config_mat(handles.user.config_mat(config_ind));
%get the optimal point based on the rule established via slider or
%model parameter extraction

% model_fcn = (1-se_vs_sp_alpha)*all_userdata.TPR+(se_vs_sp_alpha).*(1-all_userdata.FPR);
% original_config_ind = max(model_fcn)==model_fcn;
% original_config = mean(config_mat(original_config_ind,:),1); %take the mean of the columns for the original dataset...
% 
% stdev = std(bootstrapped_config,0,1);  %estimate standard deviation down the columns
% % bias = mean(bootstrapped_config-repmat(original_config,size(bootstrapped_config,1),1),1);
% m = mean(bootstrapped_config,1); %similarly estimate the mean
% bias = m-
% Z = norminv(CI_range/100);  %get the z-values for our tails
% config_CI_normal = [m+stdev*Z(1); m+stdev*Z(2)];



% if(numBootstraps>=100)
%     confid_int = round(numBootstraps*[.025, 0.975]);
%     config_sorted = sort(bootstrapped_config,1); %sort down columns
%     config_interval = config_sorted(confid_int,:);
% end
