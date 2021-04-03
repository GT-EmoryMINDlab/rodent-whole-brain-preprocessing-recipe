# Rodent Whole Brain fMRI Data Preprocessing Toolbox
This is a generally applicable fMRI preprocessing toolbox for the whole brain of mice and rats developed by Nan Xu and Leo Zhang. It follows the rodent brain preprocessing pipeline as described in ([Kai-Hsiang Chuang, et al., Neuroimage, 2019](https://www.sciencedirect.com/science/article/pii/S105381191832192X)). In this toolbox, the initial preprocessing script in ([Kai-Hsiang Chuang, et al., Neuroimage, 2019](https://www.sciencedirect.com/science/article/pii/S105381191832192X)) was re-engineered to adapt to multiple fMRI group datasets of rodent brains. This toolbox has been tested on 4 different fMRI whole brain group datasets of rodents with different imaging and experimental settings (3 rats groups and 1 mice group). Reasonable FC maps and QPPs were obtained as a result. 

<!---If you use this toolbox, please cite as Nan Xu, Leo Zhang, Zengmin Li, Shella D. Keilholz (Date). Title [Type]. doi:10.5281/zenodo.XXXX--->

## I. Prerequisite software
1. FSL5.0, AFNI and ANTs--can be installed on a PC (see "SoftwareInstallation_fsl_afni_ants.txt")
2. PCNN3d toolbox in Matlab (optional for mice brain preprocessing, see below for details). 

## II. Data Files 
The two input data files are needed, each has voxel size 10X from the scanning file (i.e., use 10X when generating .nii files by Bruker2nifti):

    EPI0.nii(.gz), 4-dim: the forward epi scan of the whole brain
    EPI_reverse0.nii(.gz), 3-dim: 1 reverse epi scan volume of the same brain
    <Note: EPI_reverse0.nii(.gz) needs to be in the same dimension and resolution as the 1st volume of EPI0.nii(.gz).>
Two datasamples, one for rat whole brain (./data_rat/) and one for mouse whole brain (./data_mouse/), are provided.     

## III. Library Files 
### Templates (./lib/tmp/)
Two templates are included, one for rat brain (./lib/tmp/rat/) and one for mouse brain (./lib/tmp/mouse/). Each folder includes the following 4 files:
	
	EPItmp.nii: a EPI brain template (If you don't have this, you need to generate one in Section IV, Step 2.)
	ANTtmp_crop.nii: an anatomical brain template (If you already have the EPI template, this file is optional.)
	brainMask.nii: a whole brain mask
	wmMask.nii, csfMask.nii or wmEPI.nii, csfEPI.nii: WM and/or CSF mask or masked EPI
### Topup parameter files (./lib/topup/)
#### 1. Imaging acquisition parameter file, "datain_topup_\*.txt"
Two options are provided: 

    datain_topup_mice.txt: for the mouse data sample
    datain_topup_rat.txt: for the rat data sample
The parameters totally depend on your imaging acquisition protocal (see [Ref](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup/TopupUsersGuide#A--datain)). It's IMPORTANT to setup the correct parameters, as they significantly impact the final results. 
#### 2. Image parameter configuration file, "\*.cnf": 
Three "\*.cnf" options are provided:

    b02b0.cnf: a generally applicable (default) configration file provided by fsl 
    EPI_topup_mice.cnf: a configration file optimized for the mouse datasample (./data_mouse/)
    EPI_topup_rat.cnf: a configration file optimized for the rat datasample (./data_rat/)
These parameters totally depend on your image (e.g., dimension, resolution, etc). 


## IV. Main Pipeline
### Step1: run "PreprocessingScript_step1.sh"
The following 4 procedures will be performed in this step.
#### 1. Slice time correction: optional for long TRs (e.g., TR>=1s)
#### 2. Motion correction: (motions are corrected to its mean)
The following files are generated in./data/mc_qc/ to control the quality of motions:

    3 motion plots: rotational and translational motions (EPI_mc_rot.png, EPI_mc_trans.png), mean displacement (EPI_mc_disp.png)
    temporal SNR (\_tSNR.txt), difference between 1st and last time frame (\_sub.nii.gz)
#### 3. Distortion correction using fsl topup: 
    a. Relign 1 reverse EPI scan to the 1st volume of the forward EPI data 
    b. Estimate the topup correction parameters (see the required topup parameter files in section III) 
    c. Apply topup correction
#### 4. Brain extraction: 
Two brain extraction options are provided: *fsl bet* function, and Matlab *PCNN3d* toolbox. One can run both functions and pick the best extrated brain for manual editing in the next step.

    fsl bet: does better job for rat brain extraction.
    PCNN3d: does better job for mice brain extraction. One can run PCNN3d in Matlab after Step 1 is completed.    
### Step2:Precise brain extraction and EPI template generation
1.  Manually edit the mask slice by slice using fsleyes editing tool

    Save the edited brain as "EPI_n4_bet_edit.nii.gz".
2. EPI template generation (optional: when you do not have EPItmp.nii in the template folder)    

### Step3: run "PreprocessingScript_step2.sh"
The following 6 procedures will be performed.
#### 1. Precise brain extraction
The input is the "EPI_n4_bet_edit.nii.gz" file saved from Step 2.
	
#### 2. EPI registration estimation and wm/csf mask generation
    a. Estimated by antsRegistration: rigid + affine + deformable (3 stages) transformation
    b. Generate wm and/or csf mask: for rat brains, this is generated by the inverse transformtaion estimated in a.
#### 3. Tissue noise estimation by PCA
    a. Generate a tissue mask
    b. extract the top 10 PCs from the masked brain tissues.
#### 4. Nuisance regressions: 26 regressors ([Kai-HsiangChuang, et al., Neuroimage, 2019](https://www.sciencedirect.com/science/article/pii/S105381191832192X))
    a. 3 for detrends: constant, linear, and quadratic trends
    b. 10 PCs from non brain tissues
    c. 6 motion regressors (based on motion correction results) 
    d. 6 motion derivative regressors: the temporal derivative of each motion regressor
    e. wmcsf or global signals (rats); csf or global signals (mice)
#### 5. Normalization & temporal filtering
    a. Amplify the regressed signals: ampX=10000 for mice datasample and ampX=100 for the rat datasample
    b. Bandpass filter: bandwidth depends on the use of anesthesia
    	e.g., 0.01–0.1Hz for iso and 0.01–0.25Hz for dmed, see Wen-Ju Pan et al., Neuroimage, 2013
#### 6. EPI template registration & spatial smoothing
    a. EPI template registration: transform cleaned-up data to template space by the transformation matrix estimated in (2.a)
    b. Use Gaussian kernel for spatial smoothing. Set sigma value at the begiing of the file:
        FWHM=2.3548*sigma
        0.25mm â†’ 10x = 2.5mm â†’, sigma=2.5/2.3548 = 1.0166
        0.3mm â†’ 10x=3.0mm â†’, sigma=1.274
        0.25mm â†’ 20x = 5mm â†’, sigma=2.1233226        
