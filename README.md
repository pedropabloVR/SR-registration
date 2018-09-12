# SR-registration
Code for registering multi-colour single molecule localisation data

## Using the scripts

To perform two-colour or multi-colour registration using these scripts:
* __Use the script getTransform.m to obtain the registration transforms
* __Move the transform .mat file to the folder where the localization files to be registered are stored 
* __Use the script useTransform.m.

The registered localization files can again be imported into ThunderSTORM
to do additional post-processing if necessary.



