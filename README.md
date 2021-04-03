# Rodents Whole Brain fMRI Data Preprocessing Toolbox
This pipeline has been tested on 4 different fMRI whole brain group datasets of rodents with different imaging protocols and experimental conditions (3 rats groups and 1 mice group) to obtain reasonable FC maps and QPPs.

## I. Prerequisite software
1. FSL5.0, AFNI and ANTs--can be installed on a PC (see "SoftwareInstallation_fsl_afni_ants.txt")
2. PCNN3d toolbox in Matlab (optional for mice brain preprocessing, see below for details). 

## II. Main Pipeline
### Step1: run "PreprocessingScript_step1.sh"
The following 4 procedures are included in this step.
#### 1. Slice time correction: optional for long TRs (e.g., TR>=1s)
#### 2. Motion correction: (motions are corrected to its mean)
    a. Generate 3 mc plots: "EPI_mc_rot.png", "EPI_mc_trans.png", and "EPI_mc_disp.png". One can use these 3 plots as a quality control of motions during the imaging session.
    b. Quality control files in./data/QC_info/:
#### 3. Distortion correction using fsl topup: 
    a. Relign 1 reverse EPI scan to the 1st volume of the forward EPI data 
    b. Estimate the topup correction parameters (see the required topup parameter files in 3 below) 
    c. Apply topup correction
#### 4. Brain extraction: 
Two brain extraction options are provided: *fsl bet* function, and Matlab *PCNN3d* toolbox. 

    fsl bet: does better job for rat brain extraction.
    PCNN3d: does better job for mice brain extraction. One can run PCNN3d in Matlab after Step 1 is completed. 
    One can also run both functions and pick the best extrated brain for manual editing in the next step.
    
### Step2: edit the extracted brain using fsleyes editing tool
    Manually edit the mask slice by slice in fsleyes
### Step3: run "PreprocessingScript_step2.sh"
The following 5 procedures are included in this step.

## III. Data Folder 
The two files are required:

    EPI0.nii(.gz), 4-dim: the forward epi scan of the whole brain
    EPI_reverse0.nii(.gz), 3-dim: 1 reverse epi scan volume of the same brain
    (Note: EPI_reverse0.nii(.gz) needs to be in the same dimension and resolution as the 1st volume of EPI0.nii(.gz).)
Two datasamples, one for rat whole brain (./data_rat/) and one for mouse whole brain (./data_mouse/), are provided.     

## IV. Library Folder 
### Templates (./lib/tmp/)
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
  




