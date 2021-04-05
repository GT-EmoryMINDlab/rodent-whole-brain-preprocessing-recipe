# Rodent Whole Brain fMRI Data Preprocessing Toolbox
This is a generally applicable fMRI preprocessing toolbox for the whole brain of mice and rats developed by Nan Xu. It generally follows the rodent brain preprocessing pipeline as described in ([Kai-Hsiang Chuang, et al., Neuroimage, 2019](https://www.sciencedirect.com/science/article/pii/S105381191832192X)) and adds the distortion correction procedure. In this toolbox, the initial preprocessing script in ([Kai-Hsiang Chuang, et al., Neuroimage, 2019](https://www.sciencedirect.com/science/article/pii/S105381191832192X)) was re-engineered to adapt to multiple fMRI group datasets of rodent brains. This toolbox has been tested on 4 different fMRI whole brain group datasets of rodents with different imaging and experimental settings (3 rats groups and 1 mice group). Reasonable FC maps and QPPs can be obtained. 

<!---If you use this toolbox, please cite as Nan Xu, Leo Zhang, Zengmin Li, Shella D. Keilholz (Date). Title [Type]. doi:10.5281/zenodo.XXXX--->

## I. Prerequisite software
1. FSL5.0, AFNI and ANTs--can be installed on a PC (see "SoftwareInstallation_fsl_afni_ants.txt")
2. Matlab is needed for calling PCNN3D (which is superior for mouse brain mask creation, see below for details). 

## II. Data Files 
Three input data files are needed, each has voxel size 10X from the scanning file (i.e., use 10X when generating .nii files by Bruker2nifti):

    EPI0.nii(.gz), 4-dim: the forward epi scan of the whole brain timeseries  
    EPI_forward0.nii(.gz), 3-dim: a 1 volume forward epi scan of the brain
    EPI_reverse0.nii(.gz), 3-dim: a 1 volume reverse epi scan of the same brain
Note: The 3D volumes in above three .nii(.gz) files need to be in the same dimension and resolution.\
--*If the EPI0.nii was scanned immediately after EPI_reverse0.nii, then the 1st volume of EPI0.nii can be extrated as EPI_forward0.nii. E.g.,*

		fslroi EPI0 EPI_forward0 0 1
--*Similarily, one can extract the last volume of EPI0.nii as EPI_forward0.nii if EPI0.nii was scanned immediately before.*

This is a EPI template registration pipeline, so the T2 scan of each brain is not required. Two datasamples, one for rat whole brain (./data_rat1/) and one for mouse whole brain (./data_mouse1/), are provided.     

## III. Library Files 
### Templates preparation (./lib/tmp/)
The template folder includes the following 4 files for either rat or mouse. 
	
	EPItmp.nii: a EPI brain template (If you don't have this, you need to generate one in Section IV, Step 2.)
	T2tmp.nii: a T2 template (If you already have EPItmp.nii, this file is optional.)
	brainMask.nii: a whole brain mask
	wmMask.nii, *csfMask.nii or *wmEPI.nii, *csfEPI.nii: WM and/or CSF mask or masked EPI
All these files need to be in the same orientation and similar resolution as your EPI images, i.e., EPI0.nii(.gz). 
Check this in fsleyes! If they do not, you need to reorient and rescale the template files to align with your EPI images. One simple reorientation approach includes the following 3 steps:

	1. Delete orientation labels: fslorient -deleteorient T2tmp.nii
	2. Reorient & rescale voxel size of the template: SPM does a good job!
	3. Re-assign the labels: fslorient -setsformcode 1 T2tmp.nii
Do the same for all files in your template folder (Ref: [SPM reorientation, see the 1st 2 mins](https://www.youtube.com/watch?v=J_aXCBKRc1k&t=371s)).
You might also need to crop the template files to better fit the coverage of your EPI scans. The matlab function nii_clip.m in the NIfTI toolbox does a good job on this. Two templates are included, the SIGMA_Wistar rat brain template, and a modified Allen Brain Institute Mouse template.

### Topup parameter files (./lib/topup/)
#### 1. Imaging acquisition parameter file, "datain_topup_\*.txt"
Two options are provided: 

    mousedatain_topup.txt: for the mouse data sample
    ratdatain_topup_rat.txt: for the rat data sample
The parameters totally depend on your imaging acquisition protocal (see [Ref](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup/TopupUsersGuide#A--datain)). It's IMPORTANT to setup the correct parameters, as they significantly impact the final results. 
#### 2. Image parameter configuration file, "\*.cnf": 
Three "\*.cnf" options are provided:

    b02b0.cnf: a generally applicable (default) configration file provided by fsl 
    mouseEPI_topup.cnf: a configration file optimized for the mouse datasample (./data_mouse1/)
    ratEPI_topup.cnf: a configration file optimized for the rat datasample (./data_rat1/)
These parameters totally depend on your image (e.g., dimension, resolution, etc). If you would like to use b020.cnf, rename the file as mouseEPI_topup.cnf or ratEPI_topup.cnf to be used.

## IV. Main Pipeline
### Step1: run "PreprocessingScript_step1.sh"
The following 4 procedures will be performed in this step.
#### 1. Slice time correction: optional for long TRs (e.g., TR>1s)
This is controled by the indicator "NeedSTC" at the beginning of the file. 
#### 2. Motion correction: (motions are corrected to its mean) 
The following files are generated in ./data/mc_qc/ to control the quality of motions:

    3 motion plots: 
    	--rotational motions (EPI_mc_rot.png) 
		--translational motions (EPI_mc_trans.png)
		--mean displacement (EPI_mc_disp.png)
    Temporal SNR (*_tSNR.txt)
    Difference between 1st and last time frame (*_sub.nii.gz)
Output: \_mc   
#### 3. Distortion correction using fsl topup
    a. Relign 1 reverse EPI scan to the 1st volume of the forward EPI data 
    b. Estimate the topup correction parameters (see the required topup parameter files in section III) 
    c. Apply topup correction
Output: \_topup    
#### 4. Raw brain mask creation
Two brain extraction options are provided: *fsl bet* function, and Matlab *PCNN3D* toolbox. In the script, both functions are called, and one can pick the tightest mask for manual editing in the next step. You might need to play with "bet_f" at the head of "PreprocessingScript_step1.sh" as well as the parameters at the head of "PCNN3D_run_v1_3.m" to get a tigher mask.

    fsl bet: better for rat brain. 
    PCNN3D: better for mouse brain. 
Output:  \_n4_bet_mask, \_n4_pcnn3d_mask (\_n4_csf_mask0 for mouse)    
### Step2: Precise brain extraction & EPI template generation
#### 1.  Manually edit the brain mask using fsleyes editing tool
    a. Overlay the mask file _bet_mask.nii.gz or _pcnn3d_mask.nii.gz or \_csf_mask0.nii.gz on top of the _n4.nii.gz file    
    b. Consistently follow ONE direction slice-by-slice and edit the mask (15~20mins/rat mask, 10~15mins/mouse mask)
    c. Save the edited brain mask as "EPI_n4_mask.nii.gz".
    d. (Only for mouse data) save the edited csf mask as "EPI_csf_mask.nii.gz" 
For a, you can change the Opacity of the mask to visualize its boundary location on brain.\
Output: \_n4_mask (\_n4_csf_mask)
#### 2. EPI template generation (optional): run "GenerateEPItmp.sh"
This procedure is only needed when you do not have "\*EPItmp.nii" in the template folder.
### Step3: run "PreprocessingScript_step2.sh"
The input is the "EPI_n4_mask.nii.gz" (and "EPI_csf_mask.nii.gz" for mouse data) saved from Step 2. The following 5 procedures will be performed.
#### 1. EPI registration estimation and wm/csf mask generation
    a. Estimated by antsRegistration: rigid + affine + deformable (3 stages) transformation
    b. Generate wm and/or csf mask: for rat brains, this is generated by the inverse transformtaion estimated in a.
One can check the alignment of "EPI_n4_brain_regWarped.nii.gz" with the EPI template.\
Output: \_n4_brain_reg    
#### 2. Tissue noise estimation by PCA
    a. Generate a tissue mask
    b. Extract the top 10 PCs from the masked brain tissues.
#### 3. Nuisance regressions: 26 regressors ([Kai-HsiangChuang, et al., Neuroimage, 2019](https://www.sciencedirect.com/science/article/pii/S105381191832192X))
    a. 3 for detrends: constant, linear, and quadratic trends
    b. 10 PCs from non brain tissues
    c. 6 motion regressors (based on motion correction results) 
    d. 6 motion derivative regressors: the temporal derivative of each motion regressor
    e. csf or/and wmcsf signals 
The script also generates a global signal regression version which only regresses out the 3 trends (a) and global signals of the brain. One can modify the list of regressors in Ln85--Ln86 and Ln91 in "PreprocessingScript_step2.sh".
#### 4. Normalization & temporal filtering
    a. Normalize the regressed signals
    b. Bandpass filter: bandwidth depends on the use of anesthesia
    	e.g., 0.01–0.1Hz for iso and 0.01–0.25Hz for dmed, see Wen-Ju Pan et al., Neuroimage, 2013
Output: \_mc_topup_norm_fil	
#### 5. EPI template registration & spatial smoothing & seed extraction
    a. EPI template registration: transform cleaned-up data to template space by the transformation matrix estimated in (2.a)
    b. Use Gaussian kernel for spatial smoothing. Setup "sigma" value at the begining of the file:
        FWHM=2.3548*sigma
        0.25mm â†’ 10x = 2.5mm â†’, sigma=2.5/2.3548 = 1.0166
        0.3mm â†’ 10x=3.0mm â†’, sigma=1.274
        0.25mm â†’ 20x = 5mm â†’, sigma=2.1233226        
    c. Extract the averaged timeseries based on atlas.
Output: \_mc_topup_norm_fil_reg_sm, \_mc_topup_norm_fil_reg_sm_seed.txt
