
Foldername=(299_42 301_19 318_31 322_46 323_16 330_27 338_17 338_17 339_23)  
# ##--------parameter setup-----------------
fil_l="0.01"; fil_h="0.25"; #temporal filtering
ampX="100";

for (( i=0; i<${#Foldername[@]}; i++ ))
do
	workingdir="${Foldername[i]}"

# ##-------------Apply brain mask-------- 
	echo " $workingdir: Masking brain"
	fslmaths ./"${workingdir}"/EPI_n4_bet_edit.nii.gz -thrp 20 -bin ./"${workingdir}"/EPI_n4_mask.nii.gz
	fslmaths ./"${workingdir}"/EPI_n4_bet.nii.gz -mas ./"${workingdir}"/EPI_n4_mask.nii ./"${workingdir}"/EPI_n4_brain
	
# ##-------------EPI registration estimation-------- 
	echo " $workingdir: EPI registration estimation & wmcsf/csf mask creation"
	antsRegistrationSyNQuick.sh -d 3 -f ./SIGMA_Wistar/SIGMA_Rat_Functional_Imaging/SIGMA_EPI_Brain_Template_Masked.nii -m ./"${workingdir}"/EPI_n4_brain.nii.gz -o ./"${workingdir}"/EPI_n4_brain_reg -t s -n 8
	
	antsApplyTransforms -d 3 -i ./SIGMA_Wistar/SIGMA_Rat_Functional_Imaging/SIGMA_EPI_CSF.nii -r ./"${workingdir}"/EPI_n4_brain.nii.gz -t [./"${workingdir}"/EPI_n4_brain_reg0GenericAffine.mat, 1] -t ./"${workingdir}"/EPI_n4_brain_reg1InverseWarp.nii.gz -o ./"${workingdir}"/EPI_n4_csf.nii.gz	
	fslmaths ./"${workingdir}"/EPI_n4_csf.nii.gz  -thrp 80 -bin ./"${workingdir}"/EPI_n4_csf_mask.nii.gz	
	antsApplyTransforms -d 3 -i ./SIGMA_Wistar/SIGMA_Rat_Functional_Imaging/SIGMA_EPI_WM.nii -r ./"${workingdir}"/EPI_n4_brain.nii.gz -t [./"${workingdir}"/EPI_n4_brain_reg0GenericAffine.mat, 1] -t ./"${workingdir}"/EPI_n4_brain_reg1InverseWarp.nii.gz -o ./"${workingdir}"/EPI_n4_wm.nii.gz
	fslmaths ./"${workingdir}"/EPI_n4_wm.nii.gz.nii.gz  -thrp 40 -bin ./"${workingdir}"/EPI_n4_wm_mask.nii.gz	
	fslmaths ./"${workingdir}"/EPI_n4_wm_mask.nii.gz -add ./"${workingdir}"/EPI_n4_csf_mask.nii.gz ./"${workingdir}"/EPI_n4_wmcsf_mask.nii.gz

# ##-------------PCA denoising-------------------
	echo " $workingdir: PCA noise selection"
	fslmaths ./"${workingdir}"/EPI_n4.nii.gz -thrp 10 -bin -sub ./"${workingdir}"/EPI_n4_mask.nii.gz ./"${workingdir}"/bg_mask_EPI.nii.gz
	3dpc -overwrite -mask ./"${workingdir}"/bg_mask_EPI.nii.gz -pcsave 10 -prefix ./"${workingdir}"/EPI_nonbrain_PCA ./"${workingdir}"/EPI_mc.nii.gz	
	fsl_tsplot -i ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D -o ./"${workingdir}"/EPI_nonbrain_PCA_vec -t 'Top PCA vectors' -x 'scan number' -y 'intensity (au)'

### Begin----------PCA selection QC----------------------------
# determine influence of PCA in brain
	fsl_glm -i ./"${workingdir}"/EPI_mc.nii.gz -d ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D -o ./"${workingdir}"/EPI_nuisance --des_norm --out_p=./"${workingdir}"/EPI_nuisance_p
# Find significance pixels in the brain at p<0.001
	fslmaths ./"${workingdir}"/EPI_nuisance_p -mas ./"${workingdir}"/EPI_n4_mask -uthr 0.001 -bin ./"${workingdir}"/EPI_nuisance_brain
# Calc proportion of significant pixel in the brain
	3dROIstats -mask ./"${workingdir}"/EPI_n4_mask.nii.gz -nobriklab -quiet ./"${workingdir}"/EPI_nuisance_brain.nii.gz > ./"${workingdir}"/EPI_nuisance_pixel.txt
	# Get PCA that affect more than 1% pixels in brain
	# select the PCA that affects the brain the most
	PCAcount=0;
	NUIcom='paste -d" "' # For combine nuisance
	while read value
	do
	PCAin=$(echo "${value} > 0.01" | bc);
	if [ ${PCAin} -eq 1 ]
	    # if value is > 0.01
	then
	NUIcom="${NUIcom} ./${workingdir}/${EPI_nonbrain_PCA}0${PCAcount}.1D"
	# appends to NUIcom
	echo "include PCA #${PCAcount}"
	# echoes the index of read to be included, where value > 0.01
	fi
	PCAcount=$(( ${PCAcount} + 1 ));
	# increments index       
	done < ./"${workingdir}"/EPI_nuisance_pixel.txt
	# output filename for the indices
	### ----------PCA selection QC----------------------------END

# ##-------------Nuisance regressors---------------------------
	echo " $workingdir: Nuisance regression: motions, PCA noise, linear and quadratic trends, gs/wmcsf/csf"
	# Calculate motion derivative regressors (AFNI)---works for small motion defects
	1d_tool.py -overwrite -infile ./"${workingdir}"/EPI_mc.par -derivative -write ./"${workingdir}"/motionEPI.deriv.par
	# get data matrix info NR= number of timepoints
	NR=$(3dinfo -nv ./"${workingdir}"/EPI_mc.nii.gz);
	1dBport -band 0 0 -nodata ${NR} -quad > ./"${workingdir}"/quad_regressionEPI.txt
	# extract CSF/WMCSF/Global signals---noise
	fslmeants -i ./"${workingdir}"/EPI_mc.nii.gz -o ./"${workingdir}"/csfEPI.txt -m ./"${workingdir}"/EPI_n4_csf_mask.nii.gz
	fslmeants -i ./"${workingdir}"/EPI_mc.nii.gz -o ./"${workingdir}"/wmcsfEPI.txt -m ./"${workingdir}"/EPI_n4_wmcsf_mask.nii.gz
	fslmeants -i ./"${workingdir}"/EPI_mc.nii.gz -o ./"${workingdir}"/gsEPI.txt -m ./"${workingdir}"/EPI_n4_mask.nii.gz
	# combine all regressors into one design matrix---
	paste -d ./"${workingdir}"/quad_regressionEPI.txt ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D ./"${workingdir}"/EPI_mc.par ./"${workingdir}"/motionEPI.deriv.par ./"${workingdir}"/csfEPI.txt >> ./"${workingdir}"/EPI_nuisance_design_csf.txt
	paste -d ./"${workingdir}"/quad_regressionEPI.txt ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D ./"${workingdir}"/EPI_mc.par ./"${workingdir}"/motionEPI.deriv.par ./"${workingdir}"/wmcsfEPI.txt >> ./"${workingdir}"/EPI_nuisance_design_wmcsf.txt
	paste -d ./"${workingdir}"/quad_regressionEPI.txt ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D ./"${workingdir}"/EPI_mc.par ./"${workingdir}"/motionEPI.deriv.par ./"${workingdir}"/gsEPI.txt >> ./"${workingdir}"/EPI_nuisance_design_gs.txt

	# Run nuisance regression and estimate contribution of regressors
	fsl_glm -i ./"${workingdir}"/EPI_mc.nii.gz -d ./"${workingdir}"/EPI_nuisance_design_wmcsf.txt -o ./"${workingdir}"/EPI_nuisance_wmcsf --out_res=./"${workingdir}"/EPI_mc_res_wmcsf --out_p=./"${workingdir}"/EPI_nuisance_p_wmcsf --out_z=./"${workingdir}"/EPI_nuisance_z_wmcsf
	fslmaths ./"${workingdir}"/EPI_nuisance_z_wmcsf -abs ./"${workingdir}"/EPI_nuisance_z_abs_wmcsf
	3dROIstats -mask ./"${workingdir}"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"${workingdir}"/EPI_nuisance_z_abs_wmcsf.nii.gz > ./"${workingdir}"/EPI_nuisance_brain_z_wmcsf.txt
	fsl_glm -i ./"${workingdir}"/EPI_mc.nii.gz -d ./"${workingdir}"/EPI_nuisance_design_gs.txt -o ./"${workingdir}"/EPI_nuisance_gs --out_res=./"${workingdir}"/EPI_mc_res_gs --out_p=./"${workingdir}"/EPI_nuisance_p_gs --out_z=./"${workingdir}"/EPI_nuisance_z_gs
	fslmaths ./"${workingdir}"/EPI_nuisance_z_gs -abs ./"${workingdir}"/EPI_nuisance_z_abs_gs
	3dROIstats -mask ./"${workingdir}"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"${workingdir}"/EPI_nuisance_z_abs_gs.nii.gz > ./"${workingdir}"/EPI_nuisance_brain_z_gs.txt
	### END of nuisance#######################################

	fslmaths ./"${workingdir}"/EPI_mc_res_gs -div ./"${workingdir}"/EPI_mean -mul $ampX ./"${workingdir}"/EPI_mc_norm_gs
	3dBandpass -band $fil_l $fil_h -notrans -overwrite -prefix ./"${workingdir}"/EPI_mc_norm_fil_gs.nii.gz -input ./"${workingdir}"/EPI_mc_norm_gs.nii.gz
	antsApplyTransforms -r ./SIGMA_Wistar/SIGMA_Rat_Functional_Imaging/SIGMA_EPI_Brain_Template_Masked.nii \
	-i ./"${workingdir}"/EPI_mc_norm_fil_gs.nii.gz -e 3 -t ./"${workingdir}"/EPI_n4_brain_reg1Warp.nii.gz -t ./"${workingdir}"/EPI_n4_brain_reg0GenericAffine.mat -o ./"${workingdir}"/EPI_mc_norm_fil_reg_gs.nii.gz --float
	
	fslmaths ./"${workingdir}"/EPI_mc_res_wmcsf -div ./"${workingdir}"/EPI_mean -mul $ampX ./"${workingdir}"/EPI_mc_norm_wmcsf
	3dBandpass -band $fil_l $fil_h -notrans -overwrite -prefix ./"${workingdir}"/EPI_mc_norm_fil_wmcsf.nii.gz -input ./"${workingdir}"/EPI_mc_norm_wmcsf.nii.gz
	antsApplyTransforms -r ./SIGMA_Wistar/SIGMA_Rat_Functional_Imaging/SIGMA_EPI_Brain_Template_Masked.nii \
	-i ./"${workingdir}"/EPI_mc_norm_fil_wmcsf.nii.gz -e 3 -t ./"${workingdir}"/EPI_n4_brain_reg1Warp.nii.gz -t ./"${workingdir}"/EPI_n4_brain_reg0GenericAffine.mat -o ./"${workingdir}"/EPI_mc_norm_fil_reg_wmcsf.nii.gz --float
	
## Apply spatial smoothing & masking
# Note: FWHM=2.3548*sigma
# 0.25mm â†’ 10x = 2.5mm â†’ use 2.5/2.3548 = 1.0166
# 0.3mm â†’ 10x=3.0mm â†’ use 1.274
# 0.25mm â†’ 20x = 5mm â†’ use 2.1233226
	fslmaths ./"${workingdir}"/EPI_mc_norm_fil_reg_gs.nii.gz -kernel gauss 2.1233226 -fmean ./"${workingdir}"/EPI_mc_norm_fil_reg_sm_gs.nii.gz
	fslmaths ./"${workingdir}"/EPI_mc_norm_fil_reg_wmcsf.nii.gz -kernel gauss 2.1233226 -fmean ./"${workingdir}"/EPI_mc_norm_fil_reg_sm_wmcsf.nii.gz
#  -kernel gauss  <sigma>    : gaussian kernel (sigma in mm, not voxels)
# -fmean   : Mean filtering, kernel weighted (conventionally used with gauss kernel)

# # ###########################################
# # # TASK fMRI
# # ##########################
# # # estimate activation by GLM using TASKFDESIGN file generated by FSL-FEAT
# # # #fsl_glm -i ${DATAIN}.nii.gz -d ${TASKDESIGN} -o ${DATAIN}_task --out_p=${DATAIN}_task_p --out_z=${DATAIN}_task_z
# # # exit

# ###########################################
# # REST fMRI
# ##########################
# Seed based  connectivity analysis using Labelled template
# extract mean time-course from labeled atlas (AFNI)
	3dROIstats -mask ./SIGMA_Wistar/SIGMA_Rat_Brain_Atlases/SIGMA_Functional_Atlas/SIGMA_Functional_Brain_Atlas_Functional_Template.nii \
-nomeanout -nobriklab -nzmean -quiet ./"${workingdir}"/EPI_mc_norm_fil_reg_sm_wmcsf.nii.gz > ./"${workingdir}"/EPI_mc_norm_fil_reg_sm_label_seed_wmcsf.txt
	3dROIstats -mask ./SIGMA_Wistar/SIGMA_Rat_Brain_Atlases/SIGMA_Functional_Atlas/SIGMA_Functional_Brain_Atlas_Functional_Template.nii \
-nomeanout -nobriklab -nzmean -quiet ./"${workingdir}"/EPI_mc_norm_fil_reg_sm_gs.nii.gz > ./"${workingdir}"/EPI_mc_norm_fil_reg_sm_label_seed_gs.txt
# refer to line 365



done