model="mouse"
Foldername=(data_"$model"1) 
# ##--------parameter setup-----------------
fil_l="0.01"; fil_h="0.3"; # temporal filtering bandwidth in Hz
sm_sigma="2.1233226" # spatial smoothing sigma
# Note: FWHM=2.3548*sigma
# 0.25mm â†’ 10x = 2.5mm â†’ sm_sigma=2.5/2.3548 = 1.0166
# 0.3mm â†’ 10x=3.0mm â†’ sm_sigma=1.274
# 0.25mm â†’ 20x = 5mm â†’ sm_sigma=2.1233226

# ##--------running-----------------
for (( i=0; i<${#Foldername[@]}; i++ ))
do
	workingdir="${Foldername[i]}"

# ##-------------Apply brain mask-------- 
	echo " $workingdir: Masking brain"
	fslmaths ./"${workingdir}"/EPI_n4_bet_edit.nii.gz -thrp 20 -bin ./"${workingdir}"/EPI_n4_mask.nii.gz
	fslmaths ./"${workingdir}"/EPI_n4.nii.gz -mas ./"${workingdir}"/EPI_n4_mask.nii ./"${workingdir}"/EPI_n4_brain
	
# ##-------------EPI registration estimation & mask creation-------- 
	echo " $workingdir: EPI registration estimation"
	antsRegistrationSyNQuick.sh -d 3 -f ./lib/tmp/"$model"EPItmp.nii -m ./"${workingdir}"/EPI_n4_brain.nii.gz -o ./"${workingdir}"/EPI_n4_brain_reg -t s -n 8
	
	echo " $workingdir: csf mask creation for mouse"
	fslmaths ./"$workingdir"/EPI_n4.nii.gz -thrp 99 -bin ./"$workingdir"/EPI_csf_mask1pass
	fslmaths ./"$workingdir"/EPI_n4.nii.gz -mas ./"$workingdir"/EPI_csf_mask1pass ./"$workingdir"/EPI_csf_masked1pass
	fslmaths ./"$workingdir"/EPI_csf_masked1pass -thrP 90 -bin ./"${workingdir}"/EPI_n4_csf_mask.nii.gz	
	rm ./"$workingdir"/EPI_csf_masked1pass
	rm ./"$workingdir"/EPI_csf_mask1pass
	
	#-------------PCA denoising-------------------
	echo " $workingdir: PCA noise selection"
	fslmaths ./"${workingdir}"/EPI_n4.nii.gz -thrp 10 -bin -sub ./"${workingdir}"/EPI_n4_mask.nii.gz ./"${workingdir}"/bg_mask_EPI.nii.gz
	3dpc -overwrite -mask ./"${workingdir}"/bg_mask_EPI.nii.gz -pcsave 10 -prefix ./"${workingdir}"/EPI_nonbrain_PCA ./"${workingdir}"/EPI_topup.nii.gz	
	fsl_tsplot -i ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D -o ./"${workingdir}"/EPI_nonbrain_PCA_vec -t 'Top PCA vectors' -x 'scan number' -y 'intensity (au)'

	### Begin----------PCA selection QC----------------------------
	fsl_glm -i ./"${workingdir}"/EPI_topup.nii.gz -d ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D -o ./"${workingdir}"/EPI_nuisance --des_norm --out_p=./"${workingdir}"/EPI_nuisance_p
	fslmaths ./"${workingdir}"/EPI_nuisance_p -mas ./"${workingdir}"/EPI_n4_mask -uthr 0.001 -bin ./"${workingdir}"/EPI_nuisance_brain
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
	echo " $workingdir: Nuisance regression: motions, motion devs, PCA noise, const&linear&quadratic trends, gs/csf"
	# Calculate motion derivative regressors (AFNI)---works for small motion defects
	1d_tool.py -overwrite -infile ./"${workingdir}"/EPI_mc.par -derivative -write ./"${workingdir}"/motionEPI.deriv.par
	# get constant, linear, quad trends
	NR=$(3dinfo -nv ./"${workingdir}"/EPI_topup.nii.gz);
	1dBport -band 0 0 -nodata ${NR} -quad > ./"${workingdir}"/quad_regressionEPI.txt
	# extract CSF/Global signals---noise
	fslmeants -i ./"${workingdir}"/EPI_topup.nii.gz -o ./"${workingdir}"/csfEPI.txt -m ./"${workingdir}"/EPI_n4_csf_mask.nii.gz	
	fslmeants -i ./"${workingdir}"/EPI_topup.nii.gz -o ./"${workingdir}"/gsEPI.txt -m ./"${workingdir}"/EPI_n4_mask.nii.gz
	# 	# combine all regressors into one design matrix---
	paste -d ./"${workingdir}"/quad_regressionEPI.txt ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D ./"${workingdir}"/EPI_mc.par ./"${workingdir}"/motionEPI.deriv.par ./"${workingdir}"/csfEPI.txt >> ./"${workingdir}"/csfEPI_nuisance_design.txt
	paste -d ./"${workingdir}"/quad_regressionEPI.txt ./"${workingdir}"/EPI_nonbrain_PCA_vec.1D ./"${workingdir}"/EPI_mc.par ./"${workingdir}"/motionEPI.deriv.par ./"${workingdir}"/gsEPI.txt >> ./"${workingdir}"/gsEPI_nuisance_design.txt

	fsl_glm -i ./"${workingdir}"/EPI_topup.nii.gz -d ./"${workingdir}"/gsEPI_nuisance_design.txt -o ./"${workingdir}"/gsEPI_nuisance --out_res=./"${workingdir}"/gsEPI_mc_topup_res --out_p=./"${workingdir}"/gsEPI_nuisance_p --out_z=./"${workingdir}"/gsEPI_nuisance_z
	fslmaths ./"${workingdir}"/gsEPI_nuisance_z -abs ./"${workingdir}"/gsEPI_nuisance_z_abs
	3dROIstats -mask ./"${workingdir}"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"${workingdir}"/gsEPI_nuisance_z_abs.nii.gz > ./"${workingdir}"/gsEPI_nuisance_brain_z.txt
	
	fsl_glm -i ./"${workingdir}"/EPI_topup.nii.gz -d ./"${workingdir}"/csfEPI_nuisance_design.txt -o ./"${workingdir}"/csfEPI_nuisance --out_res=./"${workingdir}"/csfEPI_mc_topup_res --out_p=./"${workingdir}"/csfEPI_nuisance_p --out_z=./"${workingdir}"/csfEPI_nuisance_z
	fslmaths ./"${workingdir}"/csfEPI_nuisance_z -abs ./"${workingdir}"/csfEPI_nuisance_z_abs
	3dROIstats -mask ./"${workingdir}"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"${workingdir}"/csfEPI_nuisance_z_abs.nii.gz > ./"${workingdir}"/csfEPI_nuisance_brain_z.txt
	### END of nuisance#######################################

	echo " $workingdir: Normalization & temporal filtering"
	fslmaths ./"${workingdir}"/gsEPI_mc_topup_res -div ./"${workingdir}"/EPI_topup_mean -mul 10000 ./"${workingdir}"/gsEPI_mc_topup_norm
	3dBandpass -band $fil_l $fil_h -notrans -overwrite -prefix ./"${workingdir}"/gsEPI_mc_topup_norm_fil.nii.gz -input ./"${workingdir}"/gsEPI_mc_topup_norm.nii.gz

	fslmaths ./"${workingdir}"/csfEPI_mc_topup_res -div ./"${workingdir}"/EPI_topup_mean -mul 10000 ./"${workingdir}"/csfEPI_mc_topup_norm
	3dBandpass -band $fil_l $fil_h -notrans -overwrite -prefix ./"${workingdir}"/csfEPI_mc_topup_norm_fil.nii.gz -input ./"${workingdir}"/csfEPI_mc_topup_norm.nii.gz

	echo " $workingdir: EPI registration & spatial smoothing"
	antsApplyTransforms -r ./lib/tmp/"$model"EPItmp.nii \
	-i ./"${workingdir}"/gsEPI_mc_topup_norm_fil.nii.gz -e 3 -t ./"${workingdir}"/EPI_n4_brain_reg1Warp.nii.gz -t ./"${workingdir}"/EPI_n4_brain_reg0GenericAffine.mat -o ./"${workingdir}"/gsEPI_mc_topup_norm_fil_reg.nii.gz --float
	antsApplyTransforms -r ./lib/tmp/"$model"EPItmp.nii \
	-i ./"${workingdir}"/csfEPI_mc_topup_norm_fil.nii.gz -e 3 -t ./"${workingdir}"/EPI_n4_brain_reg1Warp.nii.gz -t ./"${workingdir}"/EPI_n4_brain_reg0GenericAffine.mat -o ./"${workingdir}"/csfEPI_mc_topup_norm_fil_reg.nii.gz --float

	fslmaths ./"${workingdir}"/gsEPI_mc_topup_norm_fil_reg.nii.gz -kernel gauss $sm_sigma -fmean ./"${workingdir}"/gsEPI_mc_topup_norm_fil_reg_sm.nii.gz
	fslmaths ./"${workingdir}"/csfEPI_mc_topup_norm_fil_reg.nii.gz -kernel gauss $sm_sigma -fmean ./"${workingdir}"/csfEPI_mc_topup_norm_fil_reg_sm.nii.gz

	3dROIstats -mask ./lib/tmp/"$model"EPIatlas.nii \
	-nomeanout -nobriklab -nzmean -quiet ./"${workingdir}"/gsEPI_mc_topup_norm_fil_reg_sm.nii.gz > ./"${workingdir}"/gsEPI_mc_topup_norm_fil_reg_sm_label_seed.txt
	3dROIstats -mask ./lib/tmp/"$model"EPIatlas.nii \
	-nomeanout -nobriklab -nzmean -quiet ./"${workingdir}"/csfEPI_mc_topup_norm_fil_reg_sm.nii.gz > ./"${workingdir}"/csfEPI_mc_topup_norm_fil_reg_sm_label_seed.txt

done