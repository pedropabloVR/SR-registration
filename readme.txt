How to use the scripts
======================

To perform two-colour or multi-colour registration using these scripts,
use the script getTransform.m to get the transforms, move the transform
to the folder where you keep the localization files that need to registered
and use the function useTransform.m.
The registered localization files can again be imported into ThunderSTORM
to do additional post-processing if necessary.

 
getTransform.m
==============

    This script uses the localisation files from a series of bead images to
    calculate a transform that can be used to register multi-colour images.

    In order for the code to work, you have to follow a specific naming
    convention. For example, for 3-col registrations, the names of the
    localization files in the directory you specify should be:
        a1_488.csv
        a1_561.csv
        a1_647.csv

    One channel is chosen to be the reference channel, so in the example above,
    if 647 is the reference channel, you would get 2 transform as output:
        Trafo_tform_488.mat
        Trafo_tform_561.mat

    If you acquired many bead images and want to do batch registration, you can
    put all the bead images in one folder:
          a1_488.csv,  a2_488.csv,  a3_488.csv,
          a1_561.csv,  a2_561.csv,  a3_561.csv,   etc.
          a1_647.csv,  a2_647.csv,  a3_647.csv,
    and calculate all the transforms in batch. A summary of the transform
    parameters will in that case also be written away as a csv table.
    
    Plots the raw optical offset between the associated coordinates in the two
    bead channels and also the transform used to register the coordinates as a
    vector field within the field of view of the system. 


useTransform.m
==============

    This script registers localisation files from multi-colour single molecule
    localisation experiments. The script reads the localisation files and uses
    a the transform from getTransform.m to register its coordinates to the
    images of a reference channel.

    In order for the code to work, you have to follow a specific naming
    convention, and put the transform in the same folder as your images that
    need to be transformed. The naming convention for the localization files
    for 3-col registration would be:
          a1_488.csv,  a2_488.csv,  a3_488.csv,
          a1_561.csv,  a2_561.csv,  a3_561.csv,   etc.
          a1_647.csv,  a2_647.csv,  a3_647.csv,

    The names of the transforms should then be something like this:
          Trafo_tform_488.mat
          Trafo_tform_561.mat
    if 647 is your reference channel. The 'Trafo_tform' in the transform
    filename can be any string. Only the '_488.mat' and '_561.mat' are
    important for the script to know which transform to use on which data.
    You can register all localization files in a folder using a transform,
    or chose to register only one.

