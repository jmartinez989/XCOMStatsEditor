#!/usr/bin/gawk -f
BEGIN {
    name = ""
    jsonfile = ""
    inifiledir= ""
    inifilename = ""
    FS = "="
}

#Format of ini file
#[Module War_of_the_Chosen Character Stats]
#name="War_of_the_Chosen"
#jsonfile="./War_of_the_Chosen.json"
#inifiledir="~/shared/XCOMStatsEditor/defaultconfig"
#inifilename="DefaultGameData_CharacterStats.ini"
#[End Module War_of_the_Chosen Character Stats]
/^\[Module /,/End Module / {
    if($1 == "name") {
    	name = $2
    } else if($1 == "jsonfile") {
    	jsonfile = $2
    } else if ($1 == "jsonfiledir") {
        jsonfiledir = $2
    } else if($1 == "inifiledir") {
    	inifiledir = $2
    } else if($1 == "inifilename") {
        inifilename = $2
    } else if($0 ~ /^\[End Module/) {
    	sub(/\r/, "", name)
    	sub(/\r/, "", jsonfiledir)
    	sub(/\r/, "", jsonfile)
    	sub(/\r/, "", inifiledir)

    	print name " " jsonfile " " inifiledir " " inifilename
    }
}