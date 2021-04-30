% CREATE_SCENE_PATCHES - Creates scene patch stimuli with/without context.
%
% See also patch_cut, get_files

% (c) Visual Cognition Laboratory at the University of California, Davis
%
% 2.1.0 2020-01-17 TRHayes: OSF release updated
% 2.0.0 2019-09-25 TRHayes: Streamlined for OSF release
% 1.0.0 2016-10-15 TRHayes: Wrote it

%% 010: Define parameter structure

%--Directory management
% P.path = 'MMap_pathstr' ;   
P.path = 'MMap_pathstr' ;   
P.scene_in = fullfile(eval(P.path),'data','scene_images') ; 
P.patch_out = {fullfile(eval(P.path),'data','patch_stimuli','fine')
               fullfile(eval(P.path),'data','patch_stimuli','coarse')} ;
P.catch_out = fullfile(eval(P.path),'data','patch_stimuli','catch',...
                       'default') ;

%--Scene parameters
P.img_sz = [224 224] ;   % Default [768 1024], scene image dimensions (px)
% * Note if you are using a different scene size you will have to adjust
%   the patch diameter and patch density accordingly.

%--Patch parameter definition
P.patch_scale = {'fine','coarse'} ;  % Patch scale string IDs
P.scene_context = 1 ;                % 0=patch only, 1=patch in context
P.context_color = [57 255 20] ;      % Color used to highlight patch
P.context_scale = 1 ;              % Scale down context scene size
P.patch_diameter = [42 91] ;        % Patch diameter (px) [fine coarse]
P.patch_density = [95 35] ;        % Patch density (number) [fine coarse]
P.catch_trials = 1 ;                 % Include low meaning catch trials
                                     % *Only for P.scene_context=0 case

%% 020: Get all scene names and verify each scene image matches P.img_sz

%--Get all scene file names
s_filenames = get_files(P.scene_in) ;

%--Verify all scenes match P.img_sz
for k=1:length(s_filenames)
    curr_img = imread([P.scene_in filesep s_filenames{k}]) ;
    if isequal([size(curr_img,1) size(curr_img,2)],P.img_sz)==0
        fprintf('%s did not match P.P.img_sz, resizing\n',s_filenames{k}) ;
        new_img = imresize(curr_img,P.img_sz) ;
        imwrite(new_img,[P.scene_in filesep s_filenames{k}]) ;
    end
end

%% 030: Define and display the fine and coarse grid as sanity-check

%--For each patch grid
x_patch = cell(1,2) ;
y_patch = cell(1,2) ;
for k=1:length(P.patch_diameter)
    
    %-- Determine grid pixel frequency to achieve desired density
    px_freq = round(sqrt(P.img_sz(1)*P.img_sz(2))/sqrt(P.patch_density(k))) ;

    %-- Use meshgrid to grid image space to define fixation center points
    [y,x] = meshgrid(px_freq:px_freq:P.img_sz(1),px_freq:px_freq:P.img_sz(2)) ;
    x = x(:) ;
    y = y(:) ;

    %-- Center grid on image
    y_offset = px_freq - ((P.img_sz(1)-max(y))+px_freq)/2 ;
    x_offset = px_freq - ((P.img_sz(2)-max(x))+px_freq)/2 ;
    x_patch{k} = x - x_offset ;
    y_patch{k} = y - y_offset ;

    %-- Plot grey image with grid boundaries and center points
    grey_img = ones(P.img_sz(1),P.img_sz(2))/1.1 ; % Create grey background
    imshow(grey_img) ;

    %-- Draw circle patch grid with blue center points and numbers
    th = 0:pi/50:2*pi ;
    r = P.patch_diameter(k)/2 ;
    hold on ;
    for f=1:length(x_patch{k})
        xunit = r*cos(th)+x_patch{k}(f) ;
        yunit = r*sin(th)+y_patch{k}(f) ;
        plot(xunit,yunit,'k') ;
        plot(x_patch{k}(f),y_patch{k}(f),'bo','MarkerSize',4,...
            'MarkerFaceColor','b') ;
        text(x_patch{k}(f)-3,y_patch{k}(f)-13,num2str(f),'Color','k') ;
    end
    box on ;
    hold off ;
    set(gcf,'color','w') ; 
    
    %--Save to data folder
    saveas(gcf,[fullfile(eval(P.path),'data') filesep ...
                sprintf('%s_grid_check.png',P.patch_scale{k})]) ;
    close all ;
end

%% 040: Cut patches from each scene and store images in output directory

%-- For each spatial scale
for p=1:length(P.patch_scale)
    fprintf('\nGenerating %s scale scene patches...\n',P.patch_scale{p}) ;
    
    %-- For each scene
    for k=1:length(s_filenames)

        %-- Define patch cut parameter structure
        patch.xy = [y_patch{p} x_patch{p}] ; % [y x] = image format
        patch.img_name = s_filenames{k} ;
        patch.img_sz = P.img_sz ;
        patch.diameter = P.patch_diameter(p) ;
        patch.out_dir = P.patch_out{p};

        %-- Select image file
        img_file = [P.scene_in filesep patch.img_name] ;

        %-- Call patch_cut to cut patches from each scene
        patch_cut(img_file,patch) ;
        fprintf('  %s complete\n',s_filenames{k}) ;
    end
end

%--Cleanup
clearvars patch

%% 050: P.scene_context = 1, then add context

%--If scene context
if P.scene_context==1
    
    %-- For each spatial scale
    set(0,'DefaultFigureVisible','off') ;% Do not draw to display for speed
    for p=1:length(P.patch_scale)
        fprintf('\nGenerating %s scale patch context...\n',P.patch_scale{p}) ;
        
        %--Define circular region
        th = 0:pi/50:2*pi ;
        r = (P.patch_diameter(p))/2 ;
        
        %-- For each scene
        for s=1:length(s_filenames)

            %-- Import current scene image 
            curr_scene = imread([P.scene_in filesep s_filenames{s}]) ;

            %-- Draw patch region and save each scene image
            for k=1:length(x_patch{p})    
                
                %-- Get scene
                h(1) = imshow(curr_scene) ;

                %-- Draw circular region in neon green
                hold on ;
                xunit = r*cos(th)+x_patch{p}(k) ;
                yunit = r*sin(th)+y_patch{p}(k) ;
                plot(xunit,yunit,'Color',P.context_color/255,'LineWidth',4) ;
                hold off ;

                %-- Save image to out directory
                [~, curr_name] = fileparts(s_filenames{s}) ;
                fname = [P.patch_out{p} filesep sprintf('%s_%d_context.png',curr_name,k)] ;
                saveas(gcf,fname) ;
                
                %--Resize context image
                curr_img = imread(fname) ;
                resized_file = imresize(curr_img,P.context_scale) ;
                imwrite(resized_file,fname) ;
            end
            fprintf('  %s complete\n',s_filenames{s}) ;
            close all ;
        end
    end
end

%% 060: Generate dummy catch trials to check rating quality

%--If include catch trials==1 and scene context is off
%--Generate N black to grey patches that should be rated as 1 or 2
if (P.catch_trials==1 && P.scene_context==0)
    
    %--For each patch scale
    for p=1:length(P.patch_scale) 
    
        %--Define catch properties
        dark_light = [0 .8] ;
        catch_N = 19 ; % N+1=20 patches
        catch_V = dark_light(1):dark_light(2)/catch_N:dark_light(2) ;
        catch_sz = [P.patch_diameter(p)*2 P.patch_diameter(p)*2] ;
        catch_cent = round(catch_sz/2) ;

        %--For each patch
        for k=1:length(catch_V)

            %--Create grayscale image
            curr_V = catch_V(k) ;
            img = repmat(curr_V,catch_sz) ;


            cut = [catch_cent P.patch_diameter(p)/2] ;
            [xx,yy] = ndgrid((1:catch_sz(1))-cut(1),(1:catch_sz(2))-cut(2));
            mask = (xx.^2 + yy.^2)<cut(3)^2;
            mask = repmat(mask,[1 1 3]) ;

            %--Apply mask to source image
            if (size(img,3)==3)
                new_img = img.*mask ;
            else
                new_img = img.*mask(:,:,1) ;
            end

            %--Define rectangular bounding box around circular patch
            %-Leading edges
            c1 = find(sum(mask, 1), 1, 'first') ;  
            r1 = find(sum(mask, 2), 1, 'first') ;
            %-Trailing edges
            c2 = find(sum(mask, 1), 1, 'last') ;
            while (c2>catch_sz(2))
                c2 = c2-catch_sz(2) ;
            end
            r2 = find(sum(mask, 2), 1, 'last') ;
            while (r2>catch_sz(1))
                r2 = r2-catch_sz(1) ;
            end   

            %--Crop bounding box around masked image
            croppedImg = new_img(r1:r2, c1:c2,:) ;

            %--Use alpha to make rectangular box transparent, write image
            alpha_mask = mask(r1:r2, c1:c2,:) ;
            fname = [P.catch_out filesep sprintf('%s_catch%d.png',...
                     P.patch_scale{p},k)] ;
            imwrite(croppedImg,fname,'Alpha',alpha_mask(:,:,1)+0) ;
        end
    end
end

%--- Return scene patches
%%%%% END OF FUNCTION CREATE_SCENE_PATCHES.M