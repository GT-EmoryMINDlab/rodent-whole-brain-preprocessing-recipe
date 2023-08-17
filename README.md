# Rodent Whole-Brain fMRI Data Processing Toolbox
This is a generally applicable and user-friendly fMRI preprocessing toolbox for the whole brain of mice and rats. It provides the standard preprocessing procedures for preprocessing rodent brains as described in (Chuang et al., 2018; Lee et al., 2019). This toolbox was generalized for both mice and rat group data. It normalizes the group datasets to a standard template of the mouse or the rat brain, and then extracts timeseries based on an atlas. This software toolbox allows a variety of combinations of preprocessing procedures and parameters that are specified by users depending on the applications. Moreover, a user-specified regressors file can be added for task pattern regressions in addition to the classical detrending, motion parameters, brain tissue or noise regressions. This toolbox has been tested on 5 different fMRI group datasets of rodent whole brains with different imaging and experimental settings (3 rat groups and 2 mouse groups). Decent functional connectivity maps and quasiperiodic dynamic patterns (Thompson et al., 2014) were obtained. A video tutorial for using this toolbox is available [here](https://youtube.com/playlist?list=PLzl6lxEF9yCb3i0Coc5noXWzINKqWXTOd). A comprehensive user manual is enclosed below.

CITATION: Nan Xu, Leo Zhang+, Sam Larson+, Zengmin Li, Nmachi Anumba, Lauren Daley, Wen-Ju Pan, Kai-Hsiang Chuang, Shella Keilholz. (2023). Rodent Whole-Brain fMRI Data Preprocessing Toolbox. Aperture Neuro, 3, 1-3. https://doi.org/10.52294/001c.85075. (+ equal contributions)
# Table of Contents
* 1 - [Dependencies](#section-1)
* 2 - [Data Files](#section-2)
* 3 - [Library Files](#section-3
    * 3.1 [Template Preparation (./lib/tmp/)](#section-3-1)
    * 3.2 [Topup Parameters (./lib/topup/)](#section-3-2)
        * 3.2.1 [Imaging acquisition parameter file (datain_topup_\*.txt)](#section-3-2-1)
        * 3.2.2 [Image parameter configuration file (\*.cnf)](#section-3-2-2)
* 4 - [Main Pipeline](#section-4)
    * 4.1 [(Step 1) Run 'preproc_script_1.sh'](#section-4-1)
        * 4.1.1 [Slice time correction](#section-4-1-1)
        * 4.1.2 [Motion correction](#section-4-1-2)
        * 4.1.3 [Distortion correction](#section-4-1-3)
        * 4.1.4 [Raw brain mask creation](#section-4-1-4)
    * 4.2 [(Step 2) Precise brain extraction & EPI template generation](#section-4-2)
        * 4.2.1 [Manual brain mask edits](#section-4-2-1)
        * 4.2.2 [EPI template generation](#section-4-2-2)
    * 4.3 [(Step 3) Run 'preproc_script_2.sh'](#section-4-3)
        * 4.3.1 [EPI registration estimation & wm/csf mask generation](#section-4-3-1)
        * 4.3.2 [Non-brain tissue noise estimation by PCA](#section-4-3-2)
        * 4.3.3 [Nuisance regressions](#section-4-3-3)
        * 4.3.4 [Normalization & temporal filtering](#section-4-3-4)
        * 4.3.5 [EPI template registration & spatial smoothing & seed extraction](#section-4-3-5)
* 5 - [References](#section-5)


<a name="section-1"></a>
## 1. Dependencies
1. [FSL5.0](https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/FslInstallation(2f)Linux.html) (Jenkinson et al., 2012), [AFNI](https://afni.nimh.nih.gov/download) (Cox, 1996; Cox & Hyde, 1997), and [ANTs](https://github.com/ANTsX/ANTs/wiki/Compiling-ANTs-on-Linux-and-Mac-OS) (Avants et al., 2022): A Linux (i.e., Ubuntu, Fedora, and Red Hat) or MacOS system with the above 3 software packages installed is required. For Windows systems, it's possible to install the three packages through a Windows Subsystem for Linux (WSL, see "SoftwareInstallation_fsl_afni_ants.txt" for more details).
2. [Matlab](https://www.mathworks.com/) (The Mathworks Inc., Natick, MA, USA, R2018a or a later version) and [NIfTI and ANALYZE toolbox](https://www.mathworks.com/matlabcentral/fileexchange/8797-tools-for-nifti-and-analyze-image) (Chen, 2022) are required for calling PCNN3D (Chou et al., 2011), which is superior for mouse brain mask creation (see Section 4.1.4 for more details). 
The toolbox has been cloned to this repository in *NIfTI_toolbox* for convenience.

    *Supported Matlab Operating Systems:* Matlab software is supported in Windows (10, 11, and Server 2019) as well as MacOS and Linux (i.e., Ubuntu, Debian, RedHat, SUSE). For the full Linux system requirements, please refer to the [official documentation](https://www.mathworks.com/support/requirements/matlab-linux.html). If installing WSL using a Linux distribution other than Ubuntu or Debian as described in *SoftwareInstallation_fsl_afni_ants.txt*, replace all `apt` and `apt-get` commands with the equivalent command for your OS package manager (e.g., [zypper](https://en.opensuse.org/SDB:Zypper_usage) for SUSE).

    *Running Without Matlab Support:* By default, in *preproc_script_1.sh*, if WSL isn't detected, the default Matlab directory is set to `matlab`. Override this by passing a `--matlab_dir` argument in 
the CLI. To run the first script without Matlab or PCNN3D, set the `--matlab_dir` argument to `NA`.

<a name="section-2"></a>
## 2. Data Files 
If the data will be processed with the topup distortion correction (an optional procedure in Step 1), three input data files are required, each has a voxel size 10X from the scanning file (i.e., use 10X when generating .nii files by Bruker2nifti):

    EPI0.nii(.gz), 4-dim: the forward epi scan of the whole brain timeseries  
    EPI_forward0.nii(.gz), 3-dim: a 1 volume forward epi scan of the brain
    EPI_reverse0.nii(.gz), 3-dim: a 1 volume reverse epi scan of the same brain
Note: The 3D volumes in the above three .nii(.gz) files need to be in the same dimension and resolution.\
--*If the EPI0.nii was scanned immediately after EPI_reverse0.nii, then the 1st volume of EPI0.nii can be extracted as EPI_forward0.nii. E.g.,*

	fslroi EPI0 EPI_forward0 0 1
--*Similarly, one can extract the last volume of EPI0.nii as EPI_forward0.nii if EPI0.nii was scanned immediately before.*

The user can also process the data without the topup distortion correction, especially when the user did not record the reverse scan (EPI_reverse0.nii(.gz)). In such case, only the 4-dim EPI0.nii(.gz) file is required.

This is an EPI template registration pipeline, so the anatomical scan of each brain (usually the T2 scan due to the smaller brain size of rodents (Xu et al., 2022)) is not required. Two data samples, one for rat whole brain (./data_rat1/) and one for mouse whole brain (./data_mouse1/), are provided. 

Notably, there is a clear brain size difference across humans, rats and mice. Ratiometrically, an isotropic voxel size of 1 mm in human brain is comparable to an isotropic voxel size of 114 um in the rat brain or an isotropic voxel size of 70 um in the mouse brain (Xu et al., 2022). Standard preprocessing software packages, including FSL5.0 (Jenkinson et al., 2012) and AFNI (Cox, 1996; Cox & Hyde, 1997), employed in this pipeline, are designed for human datasets. To make them applicable to the rodent datasets, it is recommended to convert the raw scanning file from bruker to nifti format, using the 10x voxel-size increment.

<a name="section-3"></a>
## 3. Library Files 
<a name="section-3-1"></a>
### 3.1 Template Preparation (./lib/tmp/)

The template folder includes the following 4 files for either rat or mouse. 
	
	EPItmp.nii: an EPI brain template (If you don't have this, you need to generate one in Section 4.2.2.)	
	EPIatlas.nii: the atlas for extracting seed based timeseries.
	T2tmp.nii: a T2 template (If you already have EPItmp.nii, this file is optional.)
	brainMask.nii: a whole brain mask
	wmMask.nii, *csfMask.nii or *wmEPI.nii, *csfEPI.nii: WM and/or CSF mask or masked EPI
All these files need to be in the same orientation and similar resolution as your EPI images, i.e., EPI0.nii(.gz). 
Check this in fsleyes! If they are not, you need to reorient and rescale the template files to align with your EPI images. One simple reorientation approach includes the following 3 steps:

	1. Delete orientation labels: fslorient -deleteorient T2tmp.nii
	2. Reorient & rescale voxel size of the template: SPM does a good job!
	3. Re-assign the labels: fslorient -setsformcode 1 T2tmp.nii
Do the same for all files in your template folder (see the 1st 2 mins of the [SPM reorientation tutorial](https://www.youtube.com/watch?v=J_aXCBKRc1k&t=371s)).
You might also need to crop the template files to better fit the field of view (FOV) of your EPI scans. The matlab function nii_clip.m in the NIfTI toolbox does a good job on this. Two templates are provided, the SIGMA_Wistar rat brain template (Barrière et al., 2019), and a modified Allen Brain Institute Mouse template. The Allen mouse template (Lein et al., 2006) was modified to better fit the mouse data sample provided. The voxel size for the provided template is 2mm for mouse and 3mm for rat. If you have a different FOV in your scan, please create your own study-specific template.

<a name="section-3-2"></a>
### 3.2 Topup Parameters (./lib/topup/)
<a name="section-3-2-1"></a>
#### 3.2.1 Imaging acquisition parameter file (datain_topup_\*.txt)
Two options are provided: 

    mousedatain_topup.txt: for the mouse data sample
    ratdatain_topup_rat.txt: for the rat data sample
The parameters totally depend on your imaging acquisition protocol (see [the topup user guide](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup/TopupUsersGuide#A--datain) for more details). It's IMPORTANT to setup the correct parameters, as they significantly impact the final results. 

<a name="section-3-2-2"></a>
#### 3.2.2 Image parameter configuration file (\*.cnf)
Three "\*.cnf" options are provided:

    b02b0.cnf: a generally applicable (default) configuration file provided by fsl 
    mouseEPI_topup.cnf: a configuration file optimized for the mouse data sample (./data_mouse1/)
    ratEPI_topup.cnf: a configuration file optimized for the rat data sample (./data_rat1/)
These parameters totally depend on your image (e.g., dimension, resolution, etc). If you would like to use b02b0.cnf, rename the file as mouseEPI_topup.cnf or ratEPI_topup.cnf to be used.

<a name="section-4"></a>
## 4. Main Pipeline
<a name="section-4-1"></a>
### 4.1 (Step 1) Run 'preproc_script_1.sh'
The following details describe the parameters available to users via the command line:
```
Usage: ./preproc_script_1.sh [OPTIONS]

[Example]
    ./preproc_script_1.sh --model rat\
    > --fldir data_rat1,data_rat2\
    > --stc 1 --dc 1 --bet 0.55\
    > --matlab_dir matlab

Options:
 --help         Help (displays these usage details)

 --model        Specifies which rodent type to use
                [Values]
                rat: Select rat-related files and directories (Default)
                mouse: Select mouse-related files and directories

 --fldir        Name of the data folder(s) to be preprocessed.
                [Values]
                Any string value or list of comma-delimited string values
                (Default: data_<model>1)

 --stc          Specifies if slice time correction (STC) is needed (long TR vs. short TR)
                [Values]
                1: STC is required, long TR (Default)
                0: STC is not required, short TR

 --dc           Specifies if topup distortion correction (DC) will be performed
                [Values]
                1: perform DC. A reverse EPI scan EPI_reverse0.nii is required (Default)
                0: do not perform DC. E.g., if EPI_reverse0.nii is not available.

 --bet          Brain mask parameter in FSL bet
                [Values]
                Any numerical value (Default: 0.55)

 --matlab_dir   Location of matlab on the system
                [Values]
                Any string value (Default: matlab)
                NA: if Matlab is not installed in the system
```
The above documentation can also be retrieved from the command line via `help` argument:

    ./preproc_script_1.sh --help

The following 4 procedures can be performed in this step.

<a name="section-4-1-1"></a>
#### 4.1.1 Slice time correction: optional for long TRs (e.g., TR>1s)
This is controlled by the indicator "--stc" in the option.

<a name="section-4-1-2"></a>
#### 4.1.2 Motion correction: (motions are corrected to its mean) 
The following files are generated in ./data_*/mc_qc/ to control the quality of motions:

    3 motion plots: 
        --rotational motions (EPI_mc_rot.png) 
	    --translational motions (EPI_mc_trans.png)
	    --mean displacement (EPI_mc_disp.png)
    Temporal SNR (*_tSNR.txt)
    Difference between 1st and last time frame (*_sub.nii.gz)
Output: \_mc

<a name="section-4-1-3"></a>
#### 4.1.3 Distortion correction using fsl topup
This is controlled by the indicator "--dc" in the option.

If “--dc 1”, then the pipeline will

    a. Realign EPI_forward0 to the temporal mean of EPI0
    b. Apply the same realignment to EPI_reverse0
    c. Estimate the topup correction parameters (see the required topup parameter files in section III) 
    d. Apply topup correction   
Output: \_topup, \_c (which is a copy of \_topup)

If “--dc 0”, then topup correction is not performed. Output: \_c (which is a copy of \_mc)


<a name="section-4-1-4"></a>

#### 4.1.4 Initial brain mask creation
Two brain extraction options are provided: *FSL bet* function and Matlab *PCNN3D* toolbox. In the script, both functions can be called, and one can pick the tightest mask for manual editing in the next step. You might need to play with the "--bet" parameter in the option of "preproc_script_1.sh" as well as the parameters at the head of "PCNN3D_run_v1_3.m" to get a tighter mask.


    FSL bet: better for some rat brains.
    PCNN3D: better for some mouse brains. 
Output:  \_n4_bet_mask, \_n4_pcnn3d_mask (\_n4_csf_mask0 for mouse)    

<a name="section-4-2"></a>
### 4.2 (Step 2) Precise Brain Extraction & EPI Template Generation
<a name="section-4-2-1"></a>
#### 4.2.1  Manual brain mask edits (fsleyes editing tool)
Select the automated generated mask file generated from the last procedure. If you have both \_n4_bet_mask, \_n4_pcnn3d_mask, you can pick the one which better fits your data. 

    a. Overlay the mask file _mask.nii.gz or _mask0.nii.gz on top of the _n4.nii.gz file    
    b. Consistently follow ONE direction slice-by-slice and edit the mask (20~30mins/rat mask, 15~20mins/mouse mask)
    c. Save the edited brain mask as "EPI_n4_mask.nii.gz".
    d. (Only for mouse data) save the edited csf mask as "EPI_n4_csf_mask.nii.gz" 

For *Step a*, you can change the Opacity of the mask to visualize its boundary location on brain. The edited brain (and csf) masks for these two sample data are included in the data folder.

Output: \_n4_mask (\_n4_csf_mask)

<a name="section-4-2-2"></a>
#### 4.2.2 EPI template generation (optional): run "generateEPItmp.sh"
The script normalizes the masked EPI brains to a standard template, and then compute the average of the normalized EPI brains, which gives the final EPI template of your group data. This procedure is only needed when you do not have "\*EPItmp.nii" in the template folder or want to generate your data specific EPI template. If the latter case (likely for the mouse group data preprocessing), please rename the existing "<model>EPItmp.nii" (if there's one in the template folder) as "<model>EPItmp0.nii" before running the script to avoid overwriting. The following details describe the parameters available to users via the command line:
```
Usage: ./generateEPItmp.sh [OPTIONS]

[Example]
    ./generateEPItmp.sh --model mouse --fldir data_mouse1,data_mouse2 --tmp ./lib/tmp/mouseT2tmp.nii

Options:
 --help         Help (displays these usage details)

 --model        Specifies which rodent type to use
                [Values]
                rat: Select rat-related files and directories
                mouse: Select mouse-related files and directories (Default)

 --fldir        Name of the data folder (or folders for group data) to be preprocessed.
                [Values]
                Any string value or list of comma-delimited string values (Default: data_<model>1)

 --tmp          Name of the file to use as the standard template
                [Values]
                Any string value with the relative path of the file (Default: ./lib/tmp/<model>T2tmp.nii)

Output:  ./lib/tmp/<model>EPItmp.nii
```
The above documentation can also be retrieved from the command line via `help` argument:

    ./generateEPItmp.sh --help

<a name="section-4-3"></a>
### 4.3 (Step 3) Run 'preproc_script_2.sh'
The input files are "EPI_n4", "EPI_c", and "EPI_c_mean" generated from Step 1, as well as the mask(s) "EPI_n4_mask" (and "EPI_n4_csf_mask" for mouse data) saved from Step 2. As described in 4.3.1--4.3.5, 5 procedures will be performed. The following details describe the parameters available to users via the command line:
```
Usage: ./preproc_script_2.sh [OPTIONS]

[Example]
    ./preproc_script_2.sh --model mouse\
    > --fldir data_mouse1,data2,data3\
    > --nuis trends,mot,spca,csf --add_regr taskreggresors.txt\
    > --tr 1 --l_band 0.01 --h_band 0.3\
    > --smooth 4 --atlas ./lib/tmp/mouseEPIatlas.nii

Options:
 --help      Help (displays these usage details)

 --model     Specifies which rodent type to use
             [Values]
             rat: Select rat-related files and directories (Default)
             mouse: Select mouse-related files and directories

 --fldir     Name of the data folder (or folders for group data) to be preprocessed
             [Values]
             Any string value or list of comma-delimited string values (Default: data_<model>1)

 --nuis      Nuisance Regression Parameters (combinations supported)
             [Values]
             trends: 3 Detrends (constant/linear/quadratic trends)
             gs: Global Signal
             mot: 6 Motion Regressors (based on motion correction)
             motder: 6 Motion Derivative Regressors (temporal derivatives of c)
             csf: CSF Signal
             wmcsf: WMCSF Signal only valid for rat brains
             10pca: 10 Principal Components (non-brain tissues)
             spca: Selected Principal Components (non-brain tissues)
             [Note:] All specified regressors will be aggregated to the output file nuisance_design.txt. 
	     	     In addition, the specified brain signal (i.e., global, WMCSF, or CSF signal) will 
		     also be saved into an individual file, i.e., gsEPI.txt, csfEPI.txt, or wmcsfEPI.txt.
             [Note:] By default, nuisance regressions with only 3 detrends will be generated, and the 
	     	     default output files have the prefix 0EPI_*
		     
 --add_regr  Name of the file that contains additional nuisance regressor(s) (e.g., task patterns to be regressed)
             [Values]
             Any string value with the relative path of the file (Default: None)

 --tr        The time sampling rate (TR) in seconds
             [Values]
             Any numerical value (Default: 2)

 --l_band    Minimum temporal filtering bandwidth in Hz
             [Values]
             Any numerical value (Default: 0.01)

 --h_band    Maximum temporal filtering bandwidth in Hz
             [Values]
             Any numerical value (Default: 0.25)

 --smooth    Spatial smoothing FWHM in mm, which determines the spatial smoothing sigma
             [Values]
             Any numerical value (Default: smfwhm=3 (mm))

 --atlas     Name of the file to use as the EPI atlas
             [Values]
             Any string value with the relative path of the file (Default: ./lib/tmp/<model>EPIatlas.nii)
```
The above documentation can also be retrieved from the command line via the `help` argument:

    ./preproc_script_2.sh --help

<a name="section-4-3-1"></a>
#### 4.3.1 EPI registration estimation and wm/csf mask generation
    a. Estimated by antsRegistration: rigid + affine + deformable (3 stages) transformation
    b. Generate wm and/or csf mask: for rat brains, this is generated by the inverse transformation estimated in a.
One can check the alignment of "EPI_n4_brain_regWarped.nii.gz" with the EPI template.\
Output: \_n4_brain_reg

<a name="section-4-3-2"></a>
#### 4.3.2 Non-brain tissue noise estimation by PCA
    a. Generate a mask for non-brain tissues
    b. Extract the top 10 PCs from the masked tissues.
    
<a name="section-4-3-3"></a>
#### 4.3.3 Nuisance regressions: 26 possible regressors (Chuang et al., 2018) & a user specified file of regressors
    a. 3 for detrends: constant, linear, and quadratic trends
    b. 10 PCs from non-brain tissues
    c. 6 motion regressors (based on motion correction results) 
    d. 6 motion derivative regressors: the temporal derivative of each motion regressor
    e. csf or/and wmcsf signal(s)
    f. one *.txt file containing user specified regressors (e.g., task patterns to be regressed)
The script also generates a default outputs (0EPI_\*) which only regresses out the 3 trends (a). One can specify any combinations of above regressors in the command line. If you are preprocessing a group dataset, the same combination of regressors will be applied to all data.

<a name="section-4-3-4"></a>
#### 4.3.4 Normalization & temporal filtering
    a. Normalize the regressed signals
    b. Bandpass filter: bandwidth depends on the use of anesthesia
    	e.g., 0.01–0.1Hz for iso and 0.01–0.25Hz for dmed (Pan et al., 2013)
Output: \_mc_c_norm_fil

<a name="section-4-3-5"></a>
#### 4.3.5 EPI template registration & spatial smoothing & seed extraction
    a. EPI template registration: transform cleaned-up data to template space by the transformation matrix estimated in (2.a)
    b. Use Gaussian kernel for spatial smoothing. Set the FWHM value in mm in command line options
    c. Extract the averaged timeseries based on atlas.
Output: \_mc_c_norm_fil_reg_sm, \_mc_c_norm_fil_reg_sm_seed.txt

In the data sample folder, the functional connectivity map (FC.tif) generated by Matlab in our post analysis using the preprocessed timeseries is also provided.

<a name="section-5"></a>
## 5. References
Avants, B., Tustison, N. J., & Song, G. (2022). Advanced Normalization Tools: V1.0. The Insight Journal. https://doi.org/10.54294/UVNHIN

Barrière, D. A., Magalhães, R., Novais, A., Marques, P., Selingue, E., Geffroy, F., Marques, F., Cerqueira, J., Sousa, J. C., Boumezbeur, F., Bottlaender, M., Jay, T. M., Cachia, A., Sousa, N., & Mériaux, S. (2019). The SIGMA rat brain templates and atlases for multimodal MRI data analysis and visualization. Nature Communications, 10(1), 1–13. https://doi.org/10.1038/s41467-019-13575-7

Chou, N., Wu, J., Bai Bingren, J., Qiu, A., & Chuang, K. H. (2011). Robust automatic rodent brain extraction using 3-D pulse-coupled neural networks (PCNN). IEEE Transactions on Image Processing : A Publication of the IEEE Signal Processing Society, 20(9), 2554–2564. https://doi.org/10.1109/TIP.2011.2126587

Chuang, K.-H., Lee, H.-L., Li, Z., Chang, W.-T., Nasrallah, F. A., Yeow, L. Y., & Singh, K. K. D. /O. R. (2018). Evaluation of nuisance removal for functional MRI of rodent brain. NeuroImage. https://doi.org/10.1016/J.NEUROIMAGE.2018.12.048

Cox, R. W. (1996). AFNI: Software for analysis and visualization of functional magnetic resonance neuroimages. Computers and Biomedical Research, 29(3), 162–173. https://doi.org/10.1006/cbmr.1996.0014

Cox, R. W., & Hyde, J. S. (1997). Software tools for analysis and visualization of fMRI data. NMR in Biomedicine, 10(4–5), 171–178. https://doi.org/10.1002/(SICI)1099-1492(199706/08)10:4/5<171::AID-NBM453>3.0.CO;2-L

Jenkinson, M., Beckmann, C. F., Behrens, T. E. J., Woolrich, M. W., & Smith, S. M. (2012). FSL. NeuroImage, 62(2), 782–790. https://doi.org/10.1016/j.neuroimage.2011.09.015

Lee, H. L., Li, Z., Coulson, E. J., & Chuang, K. H. (2019). Ultrafast fMRI of the rodent brain using simultaneous multi-slice EPI. NeuroImage, 195, 48–58. https://doi.org/10.1016/j.neuroimage.2019.03.045

Lein, E. S., Hawrylycz, M. J., Ao, N., Ayres, M., Bensinger, A., Bernard, A., Boe, A. F., Boguski, M. S., Brockway, K. S., Byrnes, E. J., Chen, L., Chen, L., Chen, T.-M., Chi Chin, M., Chong, J., Crook, B. E., Czaplinska, A., Dang, C. N., Datta, S., … Jones, A. R. (2006). Genome-wide atlas of gene expression in the adult mouse brain. Nature 2006 445:7124, 445(7124), 168–176. https://doi.org/10.1038/nature05453

Pan, W.-J., Thompson, G. J., Magnuson, M. E., Jaeger, D., & Keilholz, S. (2013). Infraslow LFP correlates to resting-state fMRI BOLD signals. Neuroimage, 74(0), 288–297. https://doi.org/10.1016/j.neuroimage.2013.02.035

Thompson, G. J., Pan, W. J., Magnuson, M. E., Jaeger, D., & Keilholz, S. D. (2014). Quasi-periodic patterns (QPP): Large-scale dynamics in resting state fMRI that correlate with local infraslow electrical activity. NeuroImage, 84, 1018–1031. https://doi.org/10.1016/j.neuroimage.2013.09.029

Chen, J. (2022). Tools for NIfTI and ANALYZE image. MATLAB Central File Exchange. https://www.mathworks.com/matlabcentral/fileexchange/8797-tools-for-nifti-and-analyze-image

Xu, N., LaGrow, T. J., Anumba, N., Lee, A., Zhang, X., Yousefi, B., Bassil, Y., Clavijo, G. P., Khalilzad Sharghi, V., Maltbie, E., Meyer-Baese, L., Nezafati, M., Pan, W.-J., & Keilholz, S. (2022). Functional Connectivity of the Brain Across Rodents and Humans. Frontiers in Neuroscience, 0, 272. https://doi.org/10.3389/FNINS.2022.816331
