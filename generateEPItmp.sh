# model="rat"
model="mouse"

user_fldir=false
custom_tmp=false
tmp=./lib/tmp/"$model"T2tmp.nii


usage() {
  printf "=== Rodent Whole-Brain fMRI Data Preprocessing Toolbox === \n\n"
  printf "Usage: ./generateEPItmp.sh [OPTIONS]\n\n"
  printf "[Example]\n"
  printf "    ./generateEPItmp.sh --model mouse --fldir data_mouse1,data_mouse2 --tmp ./lib/tmp/mouseT2tmp.nii\n\n"
  printf "Options:\n"
  printf " --help         Help (displays these usage details)\n\n"
  printf " --model        Specifies which rodent type to use\n"
  printf "                [Values]\n"
  printf "                rat: Select rat-related files and directories\n"
  printf "                mouse: Select mouse-related files and directories (Default)\n\n"
  printf " --fldir        Name of the data folder (or folders for group data) to be preprocessed.\n"
  printf "                [Values]\n"
  printf "                Any string value or list of comma-delimited string values (Default: data_<model>1)\n\n"
  printf " --tmp        Name of the file to use as the anatomical template\n"
  printf "                [Values]\n"
  printf "                Any string value with the relative path of the file (Default: ./lib/tmp/<model>T2tmp.nii)\n\n"
  printf "Output:  ./lib/tmp/<model>EPItmp_gp.nii\n\n"  
}

# === Command Line Argument Parsing
# Parsing long options to short
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--model") set -- "$@" "-m" ;;
    "--fldir") set -- "$@" "-f" ;;
    "--tmp") set -- "$@" "-t" ;;
    *)        set -- "$@" "$arg"
  esac
done

# Evaluating set options
OPTIND=1
while getopts "hm:f:t:" opt
do
  case "$opt" in
    "h") usage; exit 0 ;;
    "m") model="${OPTARG}" ;;
    "f") user_fldir=true
         fldir_args="${OPTARG}" ;;
    "t") custom_tmp=true
 		 custom_tmp_path="${OPTARG}" ;;
    "?") usage >&2; exit 1 ;;
  esac
done
shift $(($OPTIND-1))

Foldername=(data_"$model"1) #If you have group data, this can be extended to ...
# Foldername=(data_"$model"1, data_"$model"2, data_"$model"3, data_"$model"4)

if [[ $user_fldir == true ]]; then
  IFS=',' read -r -a Foldername <<< "$fldir_args"
fi

if [[ $custom_tmp == true ]]; then
  t2_tmp="$custom_tmp_path"
fi

for (( i=0; i<${#Foldername[@]}; i++ ))
do
	workingdir="${Foldername[i]}"
	fslmaths ./"$workingdir"/EPI_n4.nii.gz -mas ./"$workingdir"/EPI_n4_mask.nii ./"$workingdir"/EPI_n4_brain
	antsRegistrationSyNQuick.sh -d 3 -f "$t2_tmp" -m ./"$workingdir"/EPI_n4_brain.nii.gz  -o ./lib/tmp/"$model_${workingdir}_EPI_" -t s -n 8	
done

fslmerge -t ./lib/tmp/"$model"allRegEPI.nii.gz ./lib/tmp/*_EPI_Warped.nii.gz
fslmaths ./lib/tmp/"$model"allRegEPI.nii.gz -Tmean ./lib/tmp/"$model"EPItmp.nii
rm ./lib/tmp/*Warped.nii.gz ./lib/tmp/*Warp.nii.gz ./lib/tmp/*Affine.mat ./lib/tmp/*allRegEPI.nii.gz
gunzip ./lib/tmp/"$model"EPItmp.nii.gz
