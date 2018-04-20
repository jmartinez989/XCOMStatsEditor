#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REFERENCEDIR="$SCRIPTDIR/references"
MODULESFILE="$REFERENCEDIR/modules.ini"
JSONFILESDIR="$SCRIPTDIR/jsonfiles"
DEFAULTDIRSFILE="$SCRIPTDIR/directories.txt"
PYTHONPROG="python $SCRIPTDIR/loadstats.py"

function createModules() {
    local RAWMODULESFILE="$SCRIPTDIR/rawmoduleinfo.txt"
    local DEFAULTSTATSFILENAME="DefaultGameData_CharacterStats.ini"

    local configdir=""
    local modulename=""
    local modulesinfo=()

    #The folder where steam will store the folders for all of the mods.
    local modsdir=$( sed -n -r 's/modsdirectory=(.*)/\1/gp' $DEFAULTDIRSFILE )
    
    #The files may or may not exist but want them to be empty regardless so just clear them out even if they don't already exist.
    > $MODULESFILE
    > $RAWMODULESFILE

    echo "[Module War_of_the_Chosen Character Stats]" >> $MODULESFILE
    echo "name=\"War_of_the_Chosen\"" >> $MODULESFILE
    echo "jsonfile=\"War_of_the_Chosen.json\"" >> $MODULESFILE
    echo "inifiledir=\"$*\"" >> $MODULESFILE
    echo "inifilename=\"$DEFAULTSTATSFILENAME\"" >> $MODULESFILE
    echo "[End Module War_of_the_Chosen Character Stats]" >> $MODULESFILE
    echo >> $MODULESFILE

    ls -1 $modsdir | while read modfolder
    do
        configdir="$modsdir/$modfolder/config"

        if [[ -e $configdir ]]
        then
            modulename=$( cat "$configdir/XComEditor.ini" | awk -F"=" ' 
            $0 ~ /^\+ModPackages/ {
                gsub(/+ModPackages=/, "")
                print
            }' | sed -r 's/\r//g' )

            #There might be some instances where the where the stats file might not be in the config directory of the mod. If that is the
            #case then go one level further down to any other directories that are in the in the config directory. This is to get stas
            #files in cases like A Better Advent where there are stats files for different unit types in sub directories of the config
            #directory.
            if [[ -e "$configdir/XComGameData_CharacterStats.ini" ]]
            then
                echo "$modulename $modulename.json $configdir XComGameData_CharacterStats.ini" >> $RAWMODULESFILE
            else
                ls -la $configdir | sed -r 's/ +/ /g' | awk '
                    $1 ~ /^d/ && $9 !~ /^\.+/ {
                    print $9 
                }' | while read configSubDir
                do
                    if [[ -e "$configdir/$configSubDir/XComGameData_CharacterStats.ini" ]]
                    then
                        echo "${configSubDir}_$modulename ${configSubDir}_$modulename.json $configdir/$configSubDir XComGameData_CharacterStats.ini" >> $RAWMODULESFILE
                    fi
                done
            fi
        fi
    done

    cat $RAWMODULESFILE | while read line
    do
        modulesinfo=( $line )
        echo "[Module ${modulesinfo[0]} Character Stats]" >> $MODULESFILE
        echo "name=\"${modulesinfo[0]}\"" >> $MODULESFILE
        echo "jsonfile=\"${modulesinfo[1]}\"" >> $MODULESFILE
        echo "inifiledir=\"${modulesinfo[2]}\"" >> $MODULESFILE
        echo "inifilename=\"${modulesinfo[3]}\"" >> $MODULESFILE
        echo "[End Module ${modulesinfo[0]} Character Stats]" >> $MODULESFILE
        echo >> $MODULESFILE
    done

    rm $RAWMODULESFILE
}

function createJsonFiles() {
    local modulevalues=""
    local modulename=""
    local jsonfile=""
    local jsonfiledir=""
    local jsonfullfilename=""
    local inifiledir=""
    local inifilename=""
    local inifilefullname=""

    if [[ -e $JSONFILESDIR ]]
    then
        rm -r $JSONFILESDIR
    fi

    mkdir $JSONFILESDIR

    #output of loadmodules script "name jsonfile inifiledir inifilename"
    $SCRIPTDIR/loadmodules.awk $MODULESFILE | while read line
    do

        modulevalues=( $line )

        modulename=$(  echo ${modulevalues[0]} | sed 's/["\r]//g' )

        jsonfile=$(  echo ${modulevalues[1]} | sed 's/["\r]//g' )
        jsonfiledir="$SCRIPTDIR/jsonfiles"
        jsonfullfilename="$jsonfiledir/$jsonfile"

        inifiledir=$( echo ${modulevalues[2]} | sed 's/["\r]//g; s/_/ /g' )
        inifilename=$( echo ${modulevalues[3]} | sed 's/["\r]//g' )
        inifilefullname="$inifiledir/$inifilename"

        #If character data ini file exists then look for json file.
        if [[ -e $inifilefullname ]]
        then
            $SCRIPTDIR/characterstatstoobject.awk -v "module=$modulename" -v "jsonfile=$jsonfullfilename" "$inifilefullname"
        fi
    done
}

function createDefaults() {
    local defaultstatsdir=""
    local defaultstatsfile=""

    read -p "Please enter directory of DefaultGameData_CharacterStats.ini file: " defaultstatsdir
    defaultstatsfile="$defaultstatsdir/DefaultGameData_CharacterStats.ini"

    if [[ -e $defaultstatsfile ]]
    then
        echo "defaultstatsdirectory=$defaultstatsdir" > $DEFAULTDIRSFILE
    else
        echo "Directory $defaultstatsdir does not contain the DefaultGameData_CharacterStats.ini file. Please run again and enter correct directory."
        exit 2
    fi

    read -p "Please enter directory where XCOM2 mods are (make sure you enter the correct one. Using any other directory could cause issues): " modsdir
    
    if [[ -e $modsdir ]]
    then
        echo "modsdirectory=$modsdir" >> $DEFAULTDIRSFILE
    else
        echo "That directory does exist. Please run again and enter correct directory."
        exit 2
    fi

    createModules $defaultstatsdir
    createJsonFiles
}

function printUsage() {
    echo "Usage: characterstats.sh [options]"
    echo "Available options are:"
    echo "    -cdef: Reload defaults for json files and where to find ini files and mod files. This will act as if you are running for ther first time." 
    echo "           If this option is present with others then the others are just ignored."
    echo "    -cmodules: Reload modules that contain information on names of mods, where ini files are and names for json files."
    echo "    -cjson: Reloads the json/stat files created from the modules that were loaded."
    exit 0
}

function processArgs() {
    local bcreateDefaults=0
    local bcreateJson=0
    local bcreateModules=0
    local defaultstatsfiledir=""

    #Print usage for --help or -? options
    if [[ $* =~ --help|-\? ]]
    then
        printUsage
    fi

    #Process any options passed into the script.
    while (($# > 0))
    do
        if [[ $1 == "-cdef" ]]
        then
            bcreateDefaults=1
            shift
        elif [[ $1 == "-cjson" ]]
        then
            bcreateJson=1
            shift
        elif [[ $1 == "-cmodules" ]]
        then
            bcreateModules=1
            shift
        else
            echo "Invalid option $1. Please try run again and provide valid option."
            exit 2
        fi
    done
    
    if (( $bcreateDefaults ))
    then
        createDefaults
    fi

    if (( $bcreateModules  &&  ! $bcreateDefaults ))
    then
        defaultstatsfiledir=$( sed -n -r 's/defaultstatsdirectory=(.*)/\1/gp' $DEFAULTDIRSFILE )
        createModules $defaultstatsfiledir
    fi

    if (( $bcreateJson  &&  ! $bcreateDefaults ))
    then
        createJsonFiles
    fi
}

function displayModules() {
    local jsonfiles=( $( ls $JSONFILESDIR ) )
    local i=0

    echo -e "\nBelow are the mods that have had data loaded for them:"
    for ((i = 0; i < ${#jsonfiles[@]}; i++ ))
    do
        echo "    $(( i + 1 ))) ${jsonfiles[$i]}" | sed 's/\.json//g'
    done

    echo
    read -p "    Enter choice: " choice

    jsonFile="$JSONFILESDIR/${jsonfiles[$((choice - 1))]}"

    $PYTHONPROG $jsonFile
}

function main() {
    if [[ ! -e $DEFAULTDIRSFILE || ! -e $JSONFILESDIR ]]
    then
        echo "Detetcted first time run of script (did not find default files). Setting up defaults."
        createDefaults        
    elif (( $# > 0 ))
    then
        processArgs $*
    fi

    displayModules
}

main $*