Foldername=(data1) # this can be extended to  Foldername=(data1 data2 data3 data4 ....) if you have group data
bet_f=0.55 # You might need to play with this parameter for creating the tightest brain mask.
for (( i=0; i<${#Foldername[@]}; i++ ))
do
	workingdir="${Foldername[i]}"

	# ##-------------Slice time correction-------- 
	echo " $workingdir: Slice time correction"
#	fslchfiletype NIFTI_GZ ./"$workingdir"/EPI0.nii.gz ./"$workingdir"/EPI0.nii.gz
	slicetimer -i ./"$workingdir"/EPI0.nii.gz  -o ./"$workingdir"/EPI.nii.gz  -r 2 -v
	slicetimer -i ./"$workingdir"/EPI_reverse0 -o ./"$workingdir"/EPI_reverse -r 2

	# ##-------------Motion correction-------- 
	echo " $workingdir: Motion correction"
	fslmaths ./"$workingdir"/EPI.nii.gz -Tmean ./"$workingdir"/EPI_mean.nii.gz
	mcflirt -in ./"$workingdir"/EPI.nii.gz -reffile ./"$workingdir"/EPI_mean.nii.gz -out ./"$workingdir"/EPI_mc -stats -plots -report -rmsrel -rmsabs -mats
	fsl_tsplot -i ./"$workingdir"/EPI_mc.par -t 'MCFLIRT rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 640 -h 144 -o  ./"$workingdir"/EPI_mc_rot.png
	fsl_tsplot -i ./"$workingdir"/EPI_mc.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 640 -h 144 -o ./"$workingdir"/EPI_mc_trans.png
	fsl_tsplot -i ./"$workingdir"/EPI_mc_rel.rms,./"$workingdir"/EPI_mc_abs.rms -t 'MCFLIRT estimated mean displacement (mm)' -u 1 -w 640 -h 144 -a absolute,relative -o ./"$workingdir"/EPI_mc_disp.png

	##-------------Topup correction-------- 
	echo " $workingdir: Topup correction"
	fslroi ./"$workingdir"/EPI.nii ./"$workingdir"/EPI_forward 0 1
	fslmerge -t ./"$workingdir"/rpEPI ./"$workingdir"/EPI_forward ./"$workingdir"/EPI_reverse
	mcflirt -in ./"$workingdir"/rpEPI -refvol 0 -out ./"$workingdir"/rpEPI_mc -stats -plots -report -rmsrel -rmsabs -mats	
	# topup --imain=./"$workingdir"/rpEPI_mc --config=b02b0.cnf \
	# 	--datain=datain_topup.txt --out=./"$workingdir"/tu_g --iout=./"$workingdir"/tus_g -v
	topup --imain=./"$workingdir"/rpEPI_mc --config=EPI_topup_HLL_fix_conf2.cnf \
		--datain=datain_topup.txt --out=./"$workingdir"/tu_g --iout=./"$workingdir"/tus_g -v
	applytopup --imain=./"$workingdir"/EPI_mc --inindex=1 --datain=datain_topup.txt \
		--topup=./"$workingdir"/tu_g --method=jac --out=./"$workingdir"/EPI_g
	fslmaths ./"$workingdir"/EPI_g -abs ./"$workingdir"/EPI_topup
	fslmaths ./"$workingdir"/EPI_topup -Tmean ./"$workingdir"/EPI_topup_mean

	##-------------Brain extraction-------- 
	echo " $workingdir: Brain extraction"
	N4BiasFieldCorrection -d 3 -i ./"$workingdir"/EPI_topup_mean.nii.gz -o ./"$workingdir"/EPI_n4.nii.gz -c [100x100x100,0] -b [50] -s 2
	bet ./"$workingdir"/EPI_n4.nii.gz ./"$workingdir"/EPI_n4_bet.nii.gz -f $bet_f -g 0 -R
	## Then, manually edit the mask slice by slice in fsleyes
done
