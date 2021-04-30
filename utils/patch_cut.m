function patch_cut(img_file,patch)

% PATCH_CUT - Takes an input image file and cuts pieces out of the image
%             based on parameters in patch structure.
%
% See also create_scene_patches

% (c) Visual Cognition Laboratory at the University of California, Davis
%
% 2.0.0 2019-09-25 TRHayes: Streamlined for OSF release
% 1.0.0 2016-10-14 TRHayes: Wrote it

%% 010: Unpack patch input structure

xy = patch.xy ;              % center points of patches
img_sz = patch.img_sz ;      % input image dimensions
img_name = patch.img_name ;  % input image name
cut_sz = patch.diameter ;    % patch diameter
output_dir = patch.out_dir ; % patch output directory

%% 020: Size up input image, define cut size, define output directory

%--Read image and convert to double
img = imread(img_file) ;
img = im2double(img) ; 

%--Define cut size in pixels
circle_px = cut_sz ;

%--Destination directory for output images
dest = output_dir ;

%% 030: For each mean fixation (x,y) cut circular piece out from image

%--For each xy position in the image
for k = 1:size(xy,1)
    
    %--Define cut mask
    cut = [round(xy(k,1)) round(xy(k,2)) circle_px/2] ;
    [xx,yy] = ndgrid((1:img_sz(1))-cut(1),(1:img_sz(2))-cut(2));
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
    while (c2>img_sz(2))
        c2 = c2-img_sz(2) ;
    end
    r2 = find(sum(mask, 2), 1, 'last') ;
    while (r2>img_sz(1))
        r2 = r2-img_sz(1) ;
    end   
       
    %--Crop bounding box around masked image
    croppedImg = new_img(r1:r2, c1:c2,:) ;
    
    %--Use alpha to make rectangular box transparent, write image
    alpha_mask = mask(r1:r2, c1:c2,:) ;
    [~, curr_name] = fileparts(img_name) ;
    fname = [dest filesep sprintf('%s_%d.png',curr_name,k)] ;
    imwrite(croppedImg,fname,'Alpha',alpha_mask(:,:,1)+0) ;
end

%--- Return patch
%%%%% END OF FUNCTION PATCH_CUT.M