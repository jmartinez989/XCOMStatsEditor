#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REFERENCEDIR="$SCRIPTDIR/references"
MODULESFILE="$REFERENCEDIR/modules.ini"
JSONFILESDIR="$SCRIPTDIR/jsonfiles"

#The folder where steam will store the folders for all of the mods.
MODSDIR="$SCRIPTDIR/modsfolder"

function createModules() {
    > $MODULESFILE
    RAWMODULESFILE="$SCRIPTDIR/rawmoduleinfo.txt"
    DEFAULTSTATSFILENAME="DefaultGameData_CharacterStats.ini"

    echo "[Module War_of_the_Chosen Character Stats]" >> $MODULESFILE
    echo "name=\"War_of_the_Chosen\"" >> $MODULESFILE
    echo "jsonfile=\"War_of_the_Chosen.json\"" >> $MODULESFILE
    echo "inifiledir=\"$1\"" >> $MODULESFILE
    echo "inifilename=\"$DEFAULTSTATSFILENAME\"" >> $MODULESFILE
    echo "[End Module War_of_the_Chosen Character Stats]" >> $MODULESFILE
    echo >> $MODULESFILE

    #The file may or may not exist but want it to be empty regardless so just clear it out even if it doesn't already exist.
    > $RAWMODULESFILE

    ls -1 $MODSDIR | while read modfolder
    do
        configdir="$MODSDIR/$modfolder/config"
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

if [[ $1 =~ -C:.+ ]]
then
    option=$1
    defaultstatsfiledir=${option//-C:/}
    
    createModules $defaultstatsfiledir
fi

#output of loadmodules script "name jsonfile inifiledir inifilename"
$SCRIPTDIR/loadmodules.awk $MODULESFILE | while read line
do

    modulevalues=( $line )

    modulename=$(  echo ${modulevalues[0]} | sed 's/["\r]//g' )

    jsonfile=$(  echo ${modulevalues[1]} | sed 's/["\r]//g' )
    jsonfiledir="$SCRIPTDIR/jsonfiles"
    jsonfullfilename="$jsonfiledir/$jsonfile"

    inifiledir=$( echo ${modulevalues[2]} | sed 's/["\r]//g' )
    inifilename=$( echo ${modulevalues[3]} | sed 's/["\r]//g' )
    inifilefullname="$inifiledir/$inifilename"

    
    #If character data ini file exists then look for json file.
    if [[ -e $inifilefullname ]]
    then
        #If json file does not exist that means either it was delete or never generated so generate it.
        if [[ ! -e $jsonfullfilename ]]
        then
            echo $jsonfullfilename
            $SCRIPTDIR/characterstatstoobject.awk -v "module=$modulename" -v "jsonfile=$jsonfullfilename" $inifilefullname
        fi
    fi
done

jsonfiles=( $( ls $JSONFILESDIR ) )