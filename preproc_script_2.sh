##########################################################################
##########################    Parameters    ##############################
##########################################################################
model="rat"
TR="2" # the time sampling rate (TR) in sec of your data
fil_l="0.01"; fil_h="0.25"; # temporal filtering bandwidth in Hz
# fil_l="0.01"; fil_h="0.3"; # temporal filtering bandwidth in Hz
# sm_sigma="2.1233226" # spatial smoothing sigma
smfwhm="3" # spatial smoothing FWHM
# Note: FWHM=2.3548*sigma
# 0.25mm â†’ 10x = 2.5mm â†’ sm_sigma=2.5/2.3548 = 1.0166
# 0.3mm â†’ 10x=3.0mm â†’ sm_sigma=1.274
# 0.5mm â†’ 10x = 5mm â†’ sm_sigma=2.1233226
nuis=true
user_fldir=false
custom_atlas=false
epi_atlas=./lib/tmp/"$model"EPIatlas.nii
custom_regressor=""

usage() {
  printf "=== Rodent Whole-Brain fMRI Data Preprocessing Toolbox === \n\n"
  printf "Usage: ./preproc_script_2.sh [OPTIONS]\n\n"
  printf "[Example]\n"
  printf "    ./preproc_script_2.sh --model mouse\ \n"
  printf "    > --fldir data_mouse1,data_mouse2,data_mouse3\ \n"
  printf "    > --nuis trends,mot,spca,csf --add_regr taskreg.txt\ \n"
  printf "    > --tr 1  --l_band 0.01 --h_band 0.3\ \n"
  printf "    > --smooth 4 --atlas ./lib/tmp/mouseEPIatlas.nii\n\n"
  printf "Options:\n"
  printf " --help      Help (displays these usage details)\n\n"
  printf " --model     Specifies which rodent type to use\n"
  printf "             [Values]\n"
  printf "             rat: Select rat-related files and directories (Default)\n"
  printf "             mouse: Select mouse-related files and directories\n\n"
  printf " --fldir     Name of the data folder (or folders for group data) to be preprocessed\n"
  printf "             [Values]\n"
  printf "             Any string value or list of comma-delimited string values (Default: data_<model>1)\n\n"
  printf " --nuis      Nuisance Regression Parameters (combinations supported)\n"
  printf "             [Values]\n"
  printf "             trends: 3 Detrends (constant/linear/quadratic trends)\n"
  printf "             gs: Global Signals\n"
  printf "             mot: 6 Motion Regressors (based on motion correction)\n"
  printf "             motder: 6 Motion Derivative Regressors (temporal derivatives of c)\n"
  printf "             csf: CSF Signals\n"
  printf "             wmcsf: WMCSF Signals only valid for rat brains\n"
  printf "             10pca: 10 Principle Components (non-brain tissues)\n"
  printf "             spca: Selected Principle Components (non-brain tissues)\n"
  printf "             [Note:] All specified regressors will be aggregated to the output file nuisance_design.txt.\n"
  printf "                     In addition, the specificed brain signals (i.e., global, WMCSF, or CSF signals) will\n"
  printf "                     also be saved into an individual file, i.e., gsEPI.txt, csfEPI.txt, or wmcsfEPI.txt.\n"
  printf "             [Note:] By default, nuisance regressions with only 3 detrends will be generated,\n"
  printf "                     and the default output files have the prefix 0EPI_*\n"
  printf " --add_regr  Name of the file that contains additional nuisance regressor(s) (e.g., task patterns to be\n"
  printf "             regressed) to add to nuisance_design.txt\n\n"
  printf "             [Values]\n"
  printf "             Any string value with the relative path of the file (Default: None)\n\n" 
  printf " --tr        The time sampling rate (TR) in seconds\n"
  printf "             [Values]\n"
  printf "             Any numerical value (Default: 2)\n\n"
  printf " --l_band    Minimum temporal filtering bandwidth in Hz\n"
  printf "             [Values]\n"
  printf "             Any numerical value (Default: 0.01)\n\n"
  printf " --h_band    Maximum temporal filtering bandwidth in Hz\n"
  printf "             [Values]\n"
  printf "             Any numerical value (Default: 0.25)\n\n"
  printf " --smooth    Spatial smoothing FWHM in mm, which determines the spatial smoothing sigma\n"
  printf "             [Values]\n"
  printf "             Any numerical value (Default: smfwhm=3 (mm))\n\n"
  printf " --atlas     Name of the file to use as the EPI atlas\n"
  printf "             [Values]\n"
  printf "             Any string value with the relative path of the file (Default: ./lib/tmp/<model>EPIatlas.nii)\n\n"

}

# Iterate through all specified nuisance regressors
iter_nuis() {
  nuis_arr="$1"
  paste_files=""

  # If trends is not explicitly set by user, set it as default nuisance parameter
  # shellcheck disable=SC2199
  if [[ ! " ${nuis_arr[@]} " =~ " trends " ]]; then
    declare -p nuis_arr >/dev/null
    nuis_arr=('trends' "${nuis_arr[@]}")
    declare -p nuis_arr >/dev/null
  fi

  for i in "${nuis_arr[@]}"
    do
      paste_files="${paste_files} $(eval_nuis "$i")"
    done

  if [ "$paste_files" != "" ]; then
    paste_files="${paste_files:1}"
    paste -d"\t" $paste_files > ./"$workingdir"/nuisance_design.txt
  fi
  if [ "$custom_regressor" != "" ]; then
    paste -d"\t" $paste_files $custom_regressor > ./"$workingdir"/nuisance_design.txt
  fi
}

# Evaluate which options need to be written to the nuisance design text file
eval_nuis() {
  param="$1"

  if [[ $param = "trends" ]]; then
    1dBport -band 0 0 -nodata ${NR} -quad > ./"$workingdir"/quad_regressionEPI.txt
    echo ./"$workingdir"/quad_regressionEPI.txt
  fi
  if [[ $param = "gs" ]]; then
    fslmeants -i ./"$workingdir"/EPI_topup.nii.gz -o ./"$workingdir"/gsEPI.txt -m ./"$workingdir"/EPI_n4_mask.nii.gz
    echo ./"$workingdir"/gsEPI.txt
  fi
  if [[ $param = "mot" ]]; then
    echo ./"$workingdir"/EPI_mc.par
  fi
  if [[ $param = "motder" ]]; then
    # Calculate motion derivative regressors (AFNI)---works for small motion defects
	  1d_tool.py -overwrite -infile ./"$workingdir"/EPI_mc.par -derivative -write ./"$workingdir"/motionEPI.deriv.par
	  echo ./"$workingdir"/motionEPI.deriv.par
  fi
  if [[ $param = "10pca" ]]; then
    echo ./"$workingdir"/EPI_nonbrain_PCA_vec.1D
  fi
  if [[ $param = "spca" ]]; then
    echo ./"$workingdir"/EPI_nonbrain_PCA_select.txt
  fi
  if [[ $param = "csf" ]]; then
    fslmeants -i ./"$workingdir"/EPI_topup.nii.gz -o ./"$workingdir"/csfEPI.txt -m ./"$workingdir"/EPI_n4_csf_mask.nii.gz
    echo ./"$workingdir"/csfEPI.txt
  fi
  if [[ $param = "wmcsf" ]]; then
    fslmeants -i ./"$workingdir"/EPI_topup.nii.gz -o ./"$workingdir"/wmcsfEPI.txt -m ./"$workingdir"/EPI_n4_wmcsf_mask.nii.gz
    echo ./"$workingdir"/wmcsfEPI.txt
  fi
}

eval_model_wmcsf() {
#  nuis_arr="$1"
  for i in "${nuis_arr[@]}"
    do
      if [[ $model == mouse ]] && [[ $i == wmcsf ]]; then
        printf "ERROR: Model cannot be mouse with wmcsf selected. Exiting...\n"
        exit 1
      fi
    done
}

# === Command Line Argument Parsing
# Parsing long options to short
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--nuis") set -- "$@" "-n" ;;
    "--model") set -- "$@" "-m" ;;
    "--tr") set -- "$@" "-t" ;;
    "--smooth") set -- "$@" "-s" ;;
    "--l_band") set -- "$@" "-l" ;;
    "--h_band") set -- "$@" "-u" ;;
    "--fldir") set -- "$@" "-f" ;;
    "--atlas") set -- "$@" "-a" ;;
    "--add_regr") set -- "$@" "-r" ;;
    *)        set -- "$@" "$arg"
  esac
done

# Evaluating set options
OPTIND=1
while getopts "hn:m:t:s:l:u:f:a:r:" opt
do
  case "$opt" in
    "h") usage; exit 0 ;;
    "n") nuis=true
         nuis_args="${OPTARG}" ;;
    "m") model="${OPTARG}"
         epi_atlas=./lib/tmp/"$model"EPIatlas.nii ;;
    "t") TR="${OPTARG}" ;;
    "s") smfwhm="${OPTARG}" ;;
    "l") fil_l="${OPTARG}" ;;
    "u") fil_h="${OPTARG}" ;;
    "f") user_fldir=true
         fldir_args="${OPTARG}" ;;
    "a") custom_atlas=true
         custom_atlas_path="${OPTARG}" ;;
    "r") custom_regressor="${OPTARG}" ;;
    "?") usage >&2; exit 1 ;;
  esac
done
shift $(($OPTIND-1))

Foldername=(data_"$model"1) #If you have group data, this can be extended to ...
# Foldername=(data_"$model"1, data_"$model"2, data_"$model"3, data_"$model"4)

if [[ $user_fldir == true ]]; then
  IFS=',' read -r -a Foldername <<< "$fldir_args"
fi

if [[ $custom_atlas == true ]]; then
  epi_atlas="$custom_atlas_path"
fi

sm_sigma=$(echo "$smfwhm/2.3548"| bc )

IFS=',' read -r -a nuis_arr <<< "$nuis_args"
eval_model_wmcsf "${nuis_arr[@]}"

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
		fslmaths ./"$workingdir"/EPI_n4_wm.nii.gz  -thrp 40 -bin ./"$workingdir"/EPI_n4_wm_mask.nii.gz
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
	NUIcom='paste -d"\t"' # For combine nuisance
	while read value
	do
	PCAin=$(echo "${value} > 0.01" | bc);
	if [ ${PCAin} -eq 1 ]
	    # if value is > 0.01
	then
	NUIcom="${NUIcom} ./${workingdir}/EPI_nonbrain_PCA0${PCAcount}.1D"
	# appends to NUIcom
	echo "include PCA #${PCAcount}"
	# echoes the index of read to be included, where value > 0.01
	fi
	PCAcount=$(( ${PCAcount} + 1 ));
	# increments index
	done < ./"$workingdir"/EPI_nuisance_pixel.txt
	eval "$NUIcom > ./"$workingdir"/EPI_nonbrain_PCA_select.txt"
	echo "NUIcom = ${NUIcom}"
	# output filename for the indices
	### ----------PCA selection QC----------------------------END

	# ##-------------Nuisance regressors---------------------------
  if [[ $nuis == true ]]; then
    echo "====================$workingdir: Nuisance regression: motions, motion devs, PCA noise, trends, gs/wmcsf/csf===================="
    # get constant, linear, quad trends
    NR=$(3dinfo -nv ./"$workingdir"/EPI_topup.nii.gz);
    
    # Parse user set options and iterate through them to write to nuisance design text file
    iter_nuis "${nuis_arr[@]}"

    fsl_glm -i ./"$workingdir"/EPI_topup.nii.gz -d ./"$workingdir"/nuisance_design.txt -o ./"$workingdir"/EPI_nuisance --out_res=./"$workingdir"/EPI_mc_topup_res --out_p=./"$workingdir"/EPI_nuisance_p --out_z=./"$workingdir"/EPI_nuisance_z
    fslmaths ./"$workingdir"/EPI_nuisance_z -abs ./"$workingdir"/EPI_nuisance_z_abs
    3dROIstats -mask ./"$workingdir"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/EPI_nuisance_z_abs.nii.gz > ./"$workingdir"/EPI_nuisance_brain_z.txt

    # default option: only detrending but no signal regression
    fsl_glm -i ./"$workingdir"/EPI_topup.nii.gz -d ./"$workingdir"/quad_regressionEPI.txt -o ./"$workingdir"/0EPI_nuisance --out_res=./"$workingdir"/0EPI_mc_topup_res --out_p=./"$workingdir"/0EPI_nuisance_p --out_z=./"$workingdir"/0EPI_nuisance_z
    fslmaths ./"$workingdir"/EPI_nuisance_z -abs ./"$workingdir"/0EPI_nuisance_z_abs
    3dROIstats -mask ./"$workingdir"/EPI_n4_mask.nii.gz -nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/0EPI_nuisance_z_abs.nii.gz > ./"$workingdir"/0EPI_nuisance_brain_z.txt


    ### END of nuisance #######################################

    echo "====================$workingdir: Normalization & temporal filtering===================="
    fslmaths ./"$workingdir"/EPI_mc_topup_res -div ./"$workingdir"/EPI_topup_mean -mul 10000 ./"$workingdir"/EPI_mc_topup_norm
    3dBandpass -band $fil_l $fil_h -dt "$TR" -notrans -overwrite -prefix ./"$workingdir"/EPI_mc_topup_norm_fil.nii.gz -input ./"$workingdir"/EPI_mc_topup_norm.nii.gz

   
    fslmaths ./"$workingdir"/EPI_mc_topup_res -div ./"$workingdir"/EPI_topup_mean -mul 10000 ./"$workingdir"/0EPI_mc_topup_norm
    3dBandpass -band $fil_l $fil_h -dt "$TR" -notrans -overwrite -prefix ./"$workingdir"/0EPI_mc_topup_norm_fil.nii.gz -input ./"$workingdir"/0EPI_mc_topup_norm.nii.gz
    
    echo "====================$workingdir: EPI registration & spatial smoothing & seed extraction===================="
    antsApplyTransforms -r ./lib/tmp/"$model"EPItmp.nii \
    -i ./"$workingdir"/EPI_mc_topup_norm_fil.nii.gz -e 3 -t ./"$workingdir"/EPI_n4_brain_reg1Warp.nii.gz -t ./"$workingdir"/EPI_n4_brain_reg0GenericAffine.mat -o ./"$workingdir"/EPI_mc_topup_norm_fil_reg.nii.gz --float
    fslmaths ./"$workingdir"/EPI_mc_topup_norm_fil_reg.nii.gz -kernel gauss $sm_sigma -fmean ./"$workingdir"/EPI_mc_topup_norm_fil_reg_sm.nii.gz
    
    3dROIstats -mask "$epi_atlas" \
    -nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/EPI_mc_topup_norm_fil_reg_sm.nii.gz > ./"$workingdir"/EPI_mc_topup_norm_fil_reg_sm_seed.txt

    antsApplyTransforms -r ./lib/tmp/"$model"EPItmp.nii \
    -i ./"$workingdir"/0EPI_mc_topup_norm_fil.nii.gz -e 3 -t ./"$workingdir"/EPI_n4_brain_reg1Warp.nii.gz -t ./"$workingdir"/EPI_n4_brain_reg0GenericAffine.mat -o ./"$workingdir"/0EPI_mc_topup_norm_fil_reg.nii.gz --float
    fslmaths ./"$workingdir"/0EPI_mc_topup_norm_fil_reg.nii.gz -kernel gauss $sm_sigma -fmean ./"$workingdir"/0EPI_mc_topup_norm_fil_reg_sm.nii.gz

    3dROIstats -mask "$epi_atlas" \
    -nomeanout -nobriklab -nzmean -quiet ./"$workingdir"/0EPI_mc_topup_norm_fil_reg_sm.nii.gz > ./"$workingdir"/0EPI_mc_topup_norm_fil_reg_sm_seed.txt
  fi
done
