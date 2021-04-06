model="rat"
# model="mouse"
# Foldername=(data_"$model"1)
Foldername=(299_42 301_19 318_31 322_46 323_16 330_27 338_17 339_23)
# Foldername=(data_"$model"1, data_"$model"2, data_"$model"3, data_"$model"4)
for (( i=0; i<${#Foldername[@]}; i++ ))
do
	workingdir="${Foldername[i]}"
	fslmaths ./"$workingdir"/EPI_n4.nii.gz -mas ./"$workingdir"/EPI_n4_mask.nii ./"$workingdir"/EPI_n4_brain
	antsRegistrationSyNQuick.sh -d 3 -f ./lib/tmp/"$model"T2tmp.nii -m ./"$workingdir"/EPI_n4_brain.nii.gz  -o ./lib/tmp/"$model_${workingdir}_EPI_" -t s -n 8	
done

fslmerge -t ./lib/tmp/"$model"allRegEPI.nii.gz ./lib/tmp/*_EPI_Warped.nii.gz
fslmaths ./lib/tmp/"$model"allRegEPI.nii.gz -Tmean ./lib/tmp/"$model"EPItmp_real.nii
rm ./lib/tmp/*Warped.nii.gz ./lib/tmp/*Warp.nii.gz ./lib/tmp/*Affine.mat
