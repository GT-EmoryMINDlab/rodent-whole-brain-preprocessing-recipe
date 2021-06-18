%% PCNN3D auto brain extraction
% save as *_pcnn3d_mask.nii.gz
% requires nifti toolbox
%
% 2017/07/27 ver1.0
% 2017/08/29 ver1.1 bug fix; add ZoomFactor; use mean image for 4D data
% 2017/09/12 ver1.2 save as 8-bit mask
% 2018/01/23 ver1.3 use with command line bash script
% Kai-Hsiang Chuang, QBI/UQ
% 4/4/2021 modified by Nan Xu

%% init setup
% datpath='./data_mouse1/EPI_n4.nii.gz'; % data path 
% BrSize=[300,400]; % brain size range for MOUSE (mm3).
BrSize=[1500,3000]; % brain size range for RAT (mm3)
StrucRadius=7; % use =3 for low resolution, use 5 or 7 for highres data
ZoomFactor=10; % resolution magnification factor
addpath('./PCNN3D_matlab/')
if model_type=='mouse'
    BrSize=[300,400]
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% run PCNN
[nii] = load_untouch_nii(datpath);
mtx=size(nii.img);
if length(mtx)==4
    disp('Data is 4D, use the average image to generate mask')
    nii.img=mean(nii.img,4);
end
voxdim=nii.hdr.dime.pixdim(2:4);
[I_border, G_I, optG] = PCNN3D(single(nii.img), StrucRadius, voxdim, BrSize*ZoomFactor^3);
V=zeros(mtx);
for n=1:mtx(3)
    V(:,:,n)=I_border{optG}{n};
end

%% save data
p=strfind(datpath, '.nii.gz');
disp(['Saving mask at ',datpath(1:p-1),'_pcnn3d_mask',datpath(p:end),' -----'])
nii.img=V;
nii.hdr.dime.dim(1)=3; nii.hdr.dime.dim(5)=1;
nii.hdr.dime.datatype=2; nii.hdr.dime.bitpix=8; % save as unsigned char
save_untouch_nii(nii,[datpath(1:p-1),'_pcnn3d_mask',datpath(p:end)]);

disp('Done')
