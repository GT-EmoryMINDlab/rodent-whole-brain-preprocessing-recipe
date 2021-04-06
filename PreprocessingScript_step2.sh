##########################################################################
##########################    Parameters    ##############################
##########################################################################
model="rat"
# model="mouse"
Foldername=(data_"$model"1) #If you have group data, this can be extended to ...
# Foldername=(data_"$model"1, data_"$model"2, data_"$model"3, data_"$model"4)
TR="2" # the time sampling rate (TR) in sec of your data
fil_l="0.01"; fil_h="0.25"; # temporal filtering bandwidth in Hz
# fil_l="0.01"; fil_h="0.3"; # temporal filtering bandwidth in Hz
sm_sigma="2.1233226" # spatial smoothing sigma
# Note: FWHM=2.3548*sigma
# 0.25mm â†’ 10x = 2.5mm â†’ sm_sigma=2.5/2.3548 = 1.0166
# 0.3mm â†’ 10x=3.0mm â†’ sm_sigma=1.274
# 0.25mm â†’ 20x = 5mm â†’ sm_sigma=2.1233226


##########################################################################
##########################     Program      ##############################
##########################################################################
for (( i=0; i<${#Foldername[@]}; i++ ))
do
	workingdir="${Foldername[i]}"

	# ##-------------EPI registration estimation-------- 
	echo "====================$workingdir: EPI registration estimation===================="
	# fslmaths ./"$workingdir"/EPI_n4_brain.nii.gz -thrp 20 -bin ./"$workingdir"/EPI_n4_mask.nii.gz
	fslmaths ./"$workingdir"/EPI_n4.nii.gz -mas ./"$workingdir"/EPI_n4_mask.nii ./"$workingdir"/EPI_n4_brain
	
	antsRegistrationSyNQuick.sh -d 3 -f ./lib/tmp/"$model"EPItmp.nii -m ./"$workingdir"/EPI_n4_brain.nii.gz -o ./"$workingdir"/EPI_n4_brain_reg -t s -n 8
	
	if [ "$model" = "rat" ]; then
	    echo "====================$workingdir: wmcsf & csf mask creation for rat===================="
		antsApplyTransforms -d 3 -i ./lib/tmp/"$model"csfEPI.nii -r ./"$workingdir"/EPI_n4_brain.nii.gz -t [./"$workingdir"/EPI_n4_brain_reg0GenericAffine.mat, 1] -t ./"$workingdir"/EPI_n4_brain_reg1InverseWarp.nii.gz -o ./"$workingdir"/EPI_n4_csf.nii.gz	
		fslmaths ./"$workingdir"/EPI_n4_csf.nii.gz  -thrp 40 -bin ./"$workingdir"/EPI_n4_csf_mask.nii.gz	
		antsApplyTransforms -d 3 -i ./lib/tmp/"$model"wmEPI.nii -r ./"$workingdir"/EPI_n4_brain.nii.gz -t [./"$workingdir"/EPI_n4_brain_reg0GenericAffine.mat, 1] -t ./"$workingdir"/EPI_n4_brain_reg1InverseWarp.nii.gz -o ./"$workingdir"/EPI_n4_wm.nii.gz
		fslmaths ./"$workingdir"/EPI_n4_wm.nii.gz.nii.gz  -thrp 40 -bin ./"$workingdir"/EPI_n4_wm_mask.nii.gz	
		fslmaths ./"$workingdir"/EPI_n4_wm_mask.nii.gz -add ./"$workingdir"/EPI_n4_csf_mask.nii.gz ./"$workingdir"/EPI_n4_wmcsf_mask.nii.gz
		fslmaths ./"$workingdir"/EPI_n4_wmcsf_mask.nii.gz -bin ./"$workingdir"/EPI_n4_wmcsf_mask.nii.gz
	fi

	
	#-------------PCA denoising-------------------
	echo "====================$workingdir: PCA noise selection===================="
	fslmaths ./"$workingdir"/EPI_n4.nii.gz -thrp 10 -bin -sub ./"$workingdir"/EPI_n4_mask.nii.gz ./"$workingdir"/bg_mask_EPI.nii.gz
	3dpc -overwrite -mask ./"$workingdir"/bg_mask_EPI.nii.gz -pcsave 10 -prefix ./"$workingdir"/EPI_nonbrain_PCA ./"$workingdir"/EPI_topup.nii.gz	
	fsl_tsplot -i ./"$workingdir"/EPI_nonbrain_PCA_vec.1D -o ./"$workingdir"/EPI_nonbrain_PCA_vec -t 'Top PCA vectors' -x 'scan number' -y 'intensity (au)'

	### Begin----------PCA selection QC----------------------------
	fsl_glm -i ./"$workingdir"/EPI_topup.nii.gz -d ./"$workingdir"/EPI_nonbrain_PCA_vec.1D -o ./"$workingdir"/EPI_nuisance --des_norm --out_p=./"$workingdir"/EPI_nuisance_p
	fslmaths ./"$workingdir"/EPI_nuisance_p -mas ./"$workingdir"/EPI_n4_mask -uthr 0.001 -bin ./"$workingdir"/EPI_nuisance_brain
	3dROIstats -mask ./"$workingdir"/EPI_n4_mask.nii.gz -nobriklab -quiet ./"$workingdir"/EPI_nuisance_brain.nii.gz > ./"$workingdir"/EPI_nuisance_pixel.txt
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
	done < ./"$workingdir"/EPI_nuisance_pixel.txt
	# output filename for the indices
	### ----------PCA selection QC----------------------------END

	# ##-------------Nuisance regressors---------------------------
	echo "====================$workingdir: Nuisance regression: motions, motion devs, PCA noise, trends, gs/wmcsf/csf===================="
	# Calculate motion derivative regressors (AFNI)---works for small motion defects
	1d_tool.py -overwrite -infile ./"$workingdir"/EPI_mc.par -derivative -write ./"$workingdir"/motionEPI.deriv.par
	# get constant, linear, quad trends
	NR=$(3dinfo -nv ./"$workingdir"/EPI_topup.nii.gz);
	1dBport -band 0 0 -nodata ${NR} -quad > ./"$workingdir"/quad_regressionEPI.txt
	# extract CSF/WMCSF/Global signals---noise
	fslmeants -i ./"$workingdir"/EPI_topup.nii.gz -o ./"$workingdir"/csfEPI.txt -m ./"$workingdir"/EPI_n4_csf_mask.nii.gz	
	fslmeants -i ./"$workingdir"/EPI_topup.nii.gz -o ./"$workingdir"/gsEPI.txt -m ./"$workingdir"/EPI_n4_mask.nii.gz
	
	# 	# combine all regressors into one design matrix---
	paste -d ./"$workingdir"/quad_regressionEPI.txt ./"$workingdir"/EPI_nonbrain_PCA_vec.1D ./"$workingdir"/EPI_mc.par ./"$workingdir"/motionEPI.deriv.par ./"$workingdir"/csfEPI.txt >> ./"$workingdir"/csfEPI_nuisance_design.txt
	paste -d ./"$workingdir"/quad_regressionEPI.txt ./"$workingdir"/gsEPI.txt >> ./"$workingdir"/gsEPI_nuisance_design.txt
	# paste -d ./"$workingdir"/quad_regressionEPI.txt ./"$workingdir"/EPI_nonbrain_PCA_vec.1D ./"$workingdir"/EPI_mc.par ./"$workingdir"/motionEPI.deriv.par ./"$workingdir"/gsEPI.txt >> ./"$workingdir"/gsEPI_nuisance_design.txt
	
	fsl_glm -i ./"$workingdir"/EPI_topup.nii.gz -d ./"$workingdir"/gsEPI_nuisance_design.txt -o ./"$workingdir"/gsEPI_nuisance --out_res=./"$workingdir"/gsEPI_mc_topup_res --out_p=./"$workingdir"/gsEPI_nuisance_p --out_z=./"$workingdir"/gsEPI_nuisance_z
	fslmaths ./"$workingdir"/gsEPI_nuisance_z -abs ./"$workingdir"/gsEPI_nuisance_z_abs
	3dROIstats -mask ./"$workingdir"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/gsEPI_nuisance_z_abs.nii.gz > ./"$workingdir"/gsEPI_nuisance_brain_z.txt
	
	fsl_glm -i ./"$workingdir"/EPI_topup.nii.gz -d ./"$workingdir"/csfEPI_nuisance_design.txt -o ./"$workingdir"/csfEPI_nuisance --out_res=./"$workingdir"/csfEPI_mc_topup_res --out_p=./"$workingdir"/csfEPI_nuisance_p --out_z=./"$workingdir"/csfEPI_nuisance_z
	fslmaths ./"$workingdir"/csfEPI_nuisance_z -abs ./"$workingdir"/csfEPI_nuisance_z_abs
	3dROIstats -mask ./"$workingdir"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/csfEPI_nuisance_z_abs.nii.gz > ./"$workingdir"/csfEPI_nuisance_brain_z.txt
	if [ "$model" = "rat" ]; then
		fslmeants -i ./"$workingdir"/EPI_topup.nii.gz -o ./"$workingdir"/wmcsfEPI.txt -m ./"$workingdir"/EPI_n4_wmcsf_mask.nii.gz
		paste -d ./"$workingdir"/quad_regressionEPI.txt ./"$workingdir"/EPI_nonbrain_PCA_vec.1D ./"$workingdir"/EPI_mc.par ./"$workingdir"/motionEPI.deriv.par ./"$workingdir"/wmcsfEPI.txt >> ./"$workingdir"/wmcsfEPI_nuisance_design.txt
		fsl_glm -i ./"$workingdir"/EPI_topup.nii.gz -d ./"$workingdir"/wmcsfEPI_nuisance_design.txt -o ./"$workingdir"/wmcsfEPI_nuisance --out_res=./"$workingdir"/wmcsfEPI_mc_topup_res --out_p=./"$workingdir"/wmcsfEPI_nuisance_p --out_z=./"$workingdir"/wmcsfEPI_nuisance_z
		fslmaths ./"$workingdir"/wmcsfEPI_nuisance_z -abs ./"$workingdir"/wmcsfEPI_nuisance_z_abs
		3dROIstats -mask ./"$workingdir"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/wmcsfEPI_nuisance_z_abs.nii.gz > ./"$workingdir"/wmcsfEPI_nuisance_brain_z.txt
	fi

	### END of nuisance#######################################

	echo "====================$workingdir: Normalization & temporal filtering===================="
	fslmaths ./"$workingdir"/gsEPI_mc_topup_res -div ./"$workingdir"/EPI_topup_mean -mul 10000 ./"$workingdir"/gsEPI_mc_topup_norm
	3dBandpass -band $fil_l $fil_h -dt "$TR" -notrans -overwrite -prefix ./"$workingdir"/gsEPI_mc_topup_norm_fil.nii.gz -input ./"$workingdir"/gsEPI_mc_topup_norm.nii.gz	
	fslmaths ./"$workingdir"/csfEPI_mc_topup_res -div ./"$workingdir"/EPI_topup_mean -mul 10000 ./"$workingdir"/csfEPI_mc_topup_norm
	3dBandpass -band $fil_l $fil_h -dt "$TR" -notrans -overwrite -prefix ./"$workingdir"/csfEPI_mc_topup_norm_fil.nii.gz -input ./"$workingdir"/csfEPI_mc_topup_norm.nii.gz

	if [ "$model" = "rat" ]; then
		fslmaths ./"$workingdir"/wmcsfEPI_mc_topup_res -div ./"$workingdir"/EPI_topup_mean -mul 10000 ./"$workingdir"/wmcsfEPI_mc_topup_norm
		3dBandpass -band $fil_l $fil_h -dt "$TR" -notrans -overwrite -prefix ./"$workingdir"/wmcsfEPI_mc_topup_norm_fil.nii.gz -input ./"$workingdir"/wmcsfEPI_mc_topup_norm.nii.gz
	fi
	echo "====================$workingdir: EPI registration & spatial smoothing & seed extraction===================="
	antsApplyTransforms -r ./lib/tmp/"$model"EPItmp.nii \
	-i ./"$workingdir"/gsEPI_mc_topup_norm_fil.nii.gz -e 3 -t ./"$workingdir"/EPI_n4_brain_reg1Warp.nii.gz -t ./"$workingdir"/EPI_n4_brain_reg0GenericAffine.mat -o ./"$workingdir"/gsEPI_mc_topup_norm_fil_reg.nii.gz --float
	antsApplyTransforms -r ./lib/tmp/"$model"EPItmp.nii \
	-i ./"$workingdir"/csfEPI_mc_topup_norm_fil.nii.gz -e 3 -t ./"$workingdir"/EPI_n4_brain_reg1Warp.nii.gz -t ./"$workingdir"/EPI_n4_brain_reg0GenericAffine.mat -o ./"$workingdir"/csfEPI_mc_topup_norm_fil_reg.nii.gz --float

	fslmaths ./"$workingdir"/gsEPI_mc_topup_norm_fil_reg.nii.gz -kernel gauss $sm_sigma -fmean ./"$workingdir"/gsEPI_mc_topup_norm_fil_reg_sm.nii.gz
	fslmaths ./"$workingdir"/csfEPI_mc_topup_norm_fil_reg.nii.gz -kernel gauss $sm_sigma -fmean ./"$workingdir"/csfEPI_mc_topup_norm_fil_reg_sm.nii.gz

	3dROIstats -mask ./lib/tmp/"$model"EPIatlas.nii \
	-nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/gsEPI_mc_topup_norm_fil_reg_sm.nii.gz > ./"$workingdir"/gsEPI_mc_topup_norm_fil_reg_sm_seed.txt
	3dROIstats -mask ./lib/tmp/"$model"EPIatlas.nii \
	-nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/csfEPI_mc_topup_norm_fil_reg_sm.nii.gz > ./"$workingdir"/csfEPI_mc_topup_norm_fil_reg_sm_seed.txt

	if [ "$model" = "rat" ]; then
		antsApplyTransforms -r ./lib/tmp/"$model"EPItmp.nii \
		-i ./"$workingdir"/wmcsfEPI_mc_topup_norm_fil.nii.gz -e 3 -t ./"$workingdir"/EPI_n4_brain_reg1Warp.nii.gz -t ./"$workingdir"/EPI_n4_brain_reg0GenericAffine.mat -o ./"$workingdir"/wmcsfEPI_mc_topup_norm_fil_reg.nii.gz --float
		fslmaths ./"$workingdir"/wmcsfEPI_mc_topup_norm_fil_reg.nii.gz -kernel gauss $sm_sigma -fmean ./"$workingdir"/wmcsfEPI_mc_topup_norm_fil_reg_sm.nii.gz
		3dROIstats -mask ./lib/tmp/"$model"EPIatlas.nii \
		-nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/wmcsfEPI_mc_topup_norm_fil_reg_sm.nii.gz > ./"$workingdir"/wmcsfEPI_mc_topup_norm_fil_reg_sm_seed.txt
	fi
done
