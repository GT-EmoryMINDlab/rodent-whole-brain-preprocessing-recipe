# Rodents Whole Brain fMRI Data Preprocessing Toolbox
This pipeline has been tested on 4 different fMRI whole brain group datasets of rodents with different imaging protocols and experimental conditions (3 rats groups and 1 mice group) to obtain reasonable FC maps and QPPs.

## 0. Prerequisite software
1. FSL5.0, AFNI and ANTs--can be installed on a PC by following "SoftwareInstallation_fsl_afni_ants.txt"
2. PCNN3d toolbox in Matlab (optional for mice brain preprocessing, see below for details). 

## 1. Main Pipeline
### Step1: run "PreprocessingScript_step1.sh"
#### 1. Slice time correction: optional for long TRs (e.g., TR>=1s)
#### 2. Motion correction: (motions are corrected to its mean)
    Generate 3 plots in each data folder, EPI_mc_rot.png, EPI_mc_trans.png, and EPI_mc_disp.png. 
    One can use these 3 plots as a quality control of motions during the imaging session.
#### 3. Distortion correction using fsl topup: 
  a. Relign 1 reverse EPI scan to the 1st volume of the forward EPI data \
  b. Estimate the topup correction parameters (see the required topup parameter files in 3 below) \
  c. Apply topup correction
#### 4. Brain extraction: using fsl bet command
### Step2: edit the extracted brain using fsleyes
see 
### Step3: run "PreprocessingScript_step2.sh"

## 2. Data Folder
## 3. Library Folder
### Template requirement
### Topup parameter files
#### 1. Imaging acquisition parameter file, "datain_topup.txt": 
  The parameters totally depend on your imaging acquisition protocal (see Ref: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup/TopupUsersGuide#A--datain). It's IMPORTANT to setup the correct parameters, as these parameters would impact the final results a lot.
#### 2. Image parameter configuration file, "\*.cnf": 
  It's also important to setup the correct parameters in the configuration file. The parameters totally depend on your image (e.g., dimension, resolution, etc). \
  3 "\*.cnf" files are provided in the lib folder: 
    a. b02b0.cnf: a generally applicable (default) configration file provided by fsl \
    b. EPI_topup_HLL_fix_conf: a configration file optimized for the mouse data "data_mouse"\
    c. EPI_topup_HLL_fix_conf2: a configration file optimized for the mouse data "data_rat"





