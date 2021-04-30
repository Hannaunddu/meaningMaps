% CREATE_QUALTRICS_SURVEYS - Creates Qualtrics surveys from scene patches.
%
% In Qualtrics you can use a type of pseudo-code to build surveys. This 
% script uses Qualtrics pseudo-code to automate the survey creation process
% to gather meaning patch ratings.
%
% See also get_files, datasample

% (c) Visual Cognition Laboratory at the University of California, Davis
%
% 2.1.0 2020-01-17 TRHayes: Simplify parameters, robust to non-divisibles
% 2.0.0 2019-09-26 TRHayes: Streamlined for OSF release
% 1.0.0 2016-02-09 TRHayes: Wrote it

%% 010: Define parameters

%--Directory management
S.path = 'MMap_pathstr' ;  
S.patch_dir = {fullfile(eval(S.path),'data','patch_stimuli','fine')
               fullfile(eval(S.path),'data','patch_stimuli','coarse')} ;
S.survey_out = {fullfile(eval(S.path),'data','surveys','fine')
               fullfile(eval(S.path),'data','surveys','coarse')} ;
S.instructions_path = fullfile(eval(S.path),'data','rating_instructions',...
                               'PatchOnly_instruction_template.txt') ;

%--Survey parameters
% *S.scene_context should match P.scene_context in create_scene_patches
S.scene_context = 1 ;                % 0=patch only, 1=patch in context
S.patch_scale = {'fine','coarse'} ;  % Patch scales
S.job_ratings = 300 ;                % Number of ratings per job
                                     % *Not including catch trials
S.page_items = 10 ;                  % Number of ratings per page
S.rating_type = 'Meaning Rating' ;   % String listed above Likert Scale

%--Catch trial parameters are dependent on S.scene_context value
if S.scene_context==1 % With context
%* User must specify patches from their scenes to use as catch trials. 
    S.catch_path = fullfile(eval(S.path),'data','patch_stimuli','catch',...
                           'custom','catch_patches.csv') ; 
    if exist(S.catch_path,'file')==0
        error('S.catch_custom=1, but catch_patches.csv does not exist\n') ; 
    end
else % Without context
%* Default(no-context), 20 dark->light catch patches auto-generated
    S.catch_path = fullfile(eval(S.path),'data','patch_stimuli','catch',...
                           'default') ; 
end 

%-- Patch hosting parameters
% Each folder in patch stimuli (i.e., fine, coarse, catch-optional) must be 
% hosted somewhere that allows a static url for each folder. Amazon S3 or 
% Github will work.
S.hosting = {'https://raw.githubusercontent.com/Hannaunddu/meaningMaps/main/data/patch_stimuli/coarse/' ...
             'https://raw.githubusercontent.com/Hannaunddu/meaningMaps/main/data/patch_stimuli/fine/'} ;

         %% 020: Define catch trials (default or user-specified)

%--Check if catch patches are user-defined(use for patch in context rating)
%  Note # of custom patches MUST be divisible by S.page_items
if S.scene_context==1
    catch_patches = ezread(S.catch_path) ;
    for p=1:length(S.patch_scale)
        patch_idx = ismember(catch_patches.scale,S.patch_scale{p}) ;
        catch_urls{p} = catch_patches.full_url(patch_idx)' ; %#ok<SAGROW>
    end
%--Otherwise use default dark to light patches(use for patch only rating)
else
    catch_patches = get_files(S.catch_path) ;
    for p=1:length(S.patch_scale)
        patch_idx = ~cellfun(@isempty,regexp(catch_patches,S.patch_scale{p})) ; 
        catch_names = catch_patches(patch_idx) ;
        catch_urls{p} = cellfun(@(x) [S.hosting{p} x],catch_names,'Un',0) ;%#ok<SAGROW>
    end
end

%--Define shuffle to mix in catch patches later
shuffle = @(v)v(randperm(numel(v)));

%% 030: Define patch urls

%--For each patch scale
patch_urls = cell(1,length(S.patch_scale)) ; % Preallocate cell array
for p=1:length(S.patch_scale)
    
    %--Get all patches to be rated and separate from context if present
    patches = get_files(S.patch_dir{p}) ;            
    patch_idx = cellfun(@isempty,regexp(patches,'_context')) ;
    patch_names{p} = patches(patch_idx) ;                  %#ok<SAGROW>
    total_ratings(p) = length(patch_names{p}) ;            %#ok<SAGROW>
        
    %--For each patch define a unique url
    for k=1:length(patch_names{p})
        patch_urls{p}{k,1} = [S.hosting{p} patch_names{p}{k}] ;
    end
    assert(length(patch_urls{p})==total_ratings(p)) ;
end

%% 040: Randomly sample patches to create survey jobs

%--For each patch scale
for p=1:length(S.patch_scale)
    
    %--Perform random sampling without replacement
    run_samples{p} = datasample(1:total_ratings(p),total_ratings(p),...
                                 'Replace',false) ; %#ok<SAGROW>
                             
    %--Build NaN cell array for maximum job size
    full_jobs = ceil(total_ratings(p)/S.job_ratings) ;
    nan_array = cell(S.job_ratings*full_jobs,1) ;
    nan_array(:) = {NaN} ;
    
    %--Add patch URLs and separate into survey jobs
    nan_array(1:length(run_samples{p})) = patch_urls{p}(run_samples{p}) ;
    jobs{p} = reshape(nan_array,[S.job_ratings,full_jobs]) ; %#ok<SAGROW>
             
    %-- Define current survey job in pages format
    for k=1:size(jobs{p},2)
         %--Get current job 
         curr_job = jobs{p}(:,k) ;
         
         %--Use NaNs location to grab data
         nan_idx = cell2mat(cellfun(@(x)any(isnan(x)),curr_job,'Un',0)) ;
         curr_job = shuffle([curr_job(~nan_idx); catch_urls{p}']);
         
         %--Build NaN cell array for maximum page size
         full_pages = ceil(length(curr_job)/S.page_items) ;
         nan_pages = cell(full_pages*S.page_items,1) ;
         nan_pages(:) = {NaN} ;
         
         %--Turn job into surveys in page format
         nan_pages(1:length(curr_job)) = curr_job ;
         fin_jobs{p}{k}=reshape(nan_pages,[S.page_items,full_pages])' ; %#ok<SAGROW>
         clearvars curr_job nan_idx full_pages nan_pages
    end
end

%% 050: Write text file jobs in Qualtrics pseudo-code

%-- For each patch scale
for s=1:length(S.patch_scale) 
    fprintf('\nWriting %s scale patch surveys...',S.patch_scale{s}) ;
    
    %-- For each job
    for k=1:size(fin_jobs{s},2)

        %-- Create file name
        fname = [S.survey_out{s} filesep sprintf('survey%d.txt',k)] ;

        %--Include instructions first
        copyfile(S.instructions_path,fname) ;   % Add instructions
        dfid = fopen(fname,'at') ;              % append, ASCII text mode
        fprintf(dfid,'[[PageBreak]]\n\n') ;
        fprintf(dfid,'[[Block:BL01]]\n\n') ;

        %--Get current patch survey
        survey_patches = fin_jobs{s}{k} ;
        
        %-- Write page by page questions
        for p=1:size(survey_patches,1)

            %-- Select items from page p
            curr_page_patches = survey_patches(p,:)' ;
            
            %-- Account for incomplete pages<S.page_items, nans
            nan_idx = cell2mat(cellfun(@(x)any(isnan(x)),curr_page_patches,'Un',0)) ;
            curr_page_patches(nan_idx) = [] ;
            
            %-- If scene context is active, define scene context images
            if S.scene_context==1
                for t=1:length(curr_page_patches)
                   [patch_stem,curr_patch,img_ext] = fileparts(curr_page_patches{t}) ;
                   curr_page_contexts{t,1} = [patch_stem '/' curr_patch...
                                    '_context' img_ext] ;   %#ok<SAGROW>
                end
            end

            %-- Put in additional blocks to mark ~halfway point 
            if (p==round(size(survey_patches,1)/2))
                fprintf(dfid,'[[Block:BL02]]\n\n') ;
            end

            %-- For each item on current page
            for c=1:length(curr_page_patches) ;

                %-- Current item
                I_patch = curr_page_patches(c) ;
                if S.scene_context==1
                    I_context = curr_page_contexts(c) ;
                end
            
                %-- Write Qualtrics matrix question command to file
                fprintf(dfid,'[[Question:Matrix]]\n') ;
                
                %-- Write display image html to file (PATCH ONLY)
                if S.scene_context~=1
                    fprintf(dfid,'<div style="text-align: center;">\n') ;
                    fprintf(dfid,...
                    sprintf('<a><img src="%s" /></a\n',I_patch{:})) ;
                    %sprintf('<a><img src="%s"  " style="width:   120px; height: 120px;" /></a\n',I{:})) ;
                    fprintf(dfid,'></div>\n\n') ;
                end

                %-- Write display image html to file
                if S.scene_context==1
                    fprintf(dfid,'<div style="text-align: center;">\n') ;
                    fprintf(dfid,...
                    sprintf('<a><img src="%s"></a>&nbsp;&nbsp;&nbsp;&nbsp; <img src="%s"',I_context{:},I_patch{:})) ;
                    fprintf(dfid,'></div>\n\n') ;
                end

                %-- Write Qualtrics choices = matrix statement
                fprintf(dfid,'[[Choices]]\n') ;
                fprintf(dfid,'%s\n',S.rating_type) ;

                %-- Write Qualtrics answers = Likert scale choices
                fprintf(dfid,'[[Answers]]\n') ;
                fprintf(dfid,'Very Low 1\n') ;
                fprintf(dfid,'Low 2\n') ;
                fprintf(dfid,'Somewhat Low 3\n') ;
                fprintf(dfid,'Somewhat High 4\n') ;
                fprintf(dfid,'High 5\n') ;
                fprintf(dfid,'Very High 6\n\n') ;               
            end

            %-- Write Qualtrics page break command to file
            fprintf(dfid,'[[PageBreak]]\n\n') ;
        end

        %-- Close current job text file
        fprintf(dfid,'\n') ;
        fclose(dfid) ; 
    end
    
    %--Print status update
    fprintf('Complete\n')
end

%--- Return all surveys
%%%%% END OF FUNCTION CREATE_QUALTRICS_SURVEYS.M