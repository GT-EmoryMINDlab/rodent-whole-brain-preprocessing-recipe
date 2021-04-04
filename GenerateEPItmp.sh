model="rat"
# model="mouse"
Foldername=(data_"$model"1)
# Foldername=(data_"$model"1, data_"$model"2, data_"$model"3, data_"$model"4)
for (( i=0; i<${#Foldername[@]}; i++ ))
do
	workingdir="${Foldername[i]}"

	antsRegistrationSyNQuick.sh -d 3 -f ./lib/tmp/"$model"T2tmp.nii -m ./"$workingdir"/EPI_n4_bet_edit.nii.gz  -o ./lib/tmp/"$model_${workingdir}_EPI_" -t s -n 8

done

fslmerge -t ./lib/tmp/"$model"allRegEPI.nii.gz ./lib/tmp/*_EPI_Warped.nii.gz
fslmaths ./lib/tmp/"$model"allRegEPI.nii.gz -Tmean ./lib/tmp/"$model"EPItmp.nii
rm ./lib/tmp/*_EPI_Warped.nii.gz