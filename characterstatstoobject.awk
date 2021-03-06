#!/usr/bin/gawk -f
BEGIN {
    #This will indicate the current unit in the ini file that is being processed. When the file reeaches a unit definition header
    #Such as [BerserkerM4 X2CharacterTemplate] it will take the name in the brackets and assign that as the current unit being processed.
    currentUnit = ""

    #This array will hold the lines that will be written to the JSON file.
    lines[0] = ""
    delete lines[0]
    #This will be the current running line number for the JSON file.
    linesCount = 0

    #This array will hold the lines that are going to be written to the characterstats template file.
    templateFileLines[0] = ""
    delete templateFileLines[0]
    #This will be the current running line number for the template file.
    templateFileLinsCount = 1

    #This is going to be used as a boolean flag to check if the current line of the file has been written to the temple. The reason this is
    #used is because in some cases we want to just write the current record to the template file as is because there is no template information
    #for that line. In other cases though we have lines that define a stat for the unit that is being processed. The line will look like
    #+CharacterBaseStats[eStat_*statName*]=*statamount*. We want to take that and transform it into a templatized format so that program that
    #handles writing the JSON files to the ini via using jinja emplates can just pass the dictionary (JSON object loaded from JSON file) to
    #the template manager and load it. Below is the format for the tempaltized line:
    #    +CharacterBaseStats[eStat_Strength] = {{ *moduleName*['units'][*unitName*][*difficultyOfStatsToAlter*][*statName*] }}
    wroteLineToTemplate = 0

    #The main array of units that will hold all of the stats. It will be a mult-dimensional array that will be used as
    #a json object. Below is the format of the array:
    #    units[unitname][properties][statName]
    #
    #    Keys:
    #        unitName:
    #            Name if the unit as it is defined in the ini file. So for example each section for units is in the
    #            format of "[unitname X2CharacterTemplate]" where the unit name will be extracted from that header.
    #
    #        properties:
    #            This will be the different properties for a unit (not really the stats, the stats will be different
    #            items of the properties as a lot of these properties will actually be sets of stats for each
    #            difficulty). The main properties here are going to be "defaultStats" which will be the set of base
    #            stats the unit has, "rookieStats" which will be stat overrides for the rookie difficulty,
    #            "veteranStats", "commanderStats" and "legendStats" are stat sets for overriding stats for their
    #            respective difficulties. This can also be a property that holds the units name as it is displayed in
    #            the tactical so when handling the keys for the array of unit properties you have to make sure that this
    #            key is checked for specifically because of you try to do something like
    #            "units[unitName][tacticaleName][statName]" it will cause an error since it is trying to use
    #            units[unitName][tacticaleName] as an array when it is a scalar.
    #
    #        statName:
    #            The name of the stat in the set of stats for a given difficulty.
    #          
    units[0]  ""
    delete units[0]
    
    #Flag to indicate whether or not the section that the scraper is on is a section that overrides some stats
    #on a given difficulty.
    statOverride = 0

    #The current diffculty level to override stats for. This will actually be increased by 1 when it is assigned as it
    #is going to be used in an array that starts indexing at 1.
    currentDiffOverride = 0

    #Array of keys that will be used in the units array when modifying a particular units set of stats for a given
    #difficulty.
    diffOverrideKeys[1] = "rookieStats"
    diffOverrideKeys[2] = "veteranStats"
    diffOverrideKeys[3] = "commanderStats"
    diffOverrideKeys[4] = "legendStats"

    #This array holds the names of the units that are displayed in tactical.
    aliases[0] = ""
    delete alieases[0]

    #Command to run as a bash command to a file channel.
    command = "cat " aliasesFile

    #Read in lines from the command output (which is the file that holds all aliases). Each line is split up betwen
    #the "=" so that the values can be stored in the aliases array (keys for the array are the first item in the array
    #of the line that was split and the value is the 2nd item in the array.)
    while((command | getline) > 0) {
        if($0 ~ /=/) {
            split($0, alias, /=/)
            sub(/\r/, "", alias[1])
            sub(/\r/, "", alias[2])

            aliases[alias[1]] = alias[2]
        }
    }

    close(command)
}

#[Soldier X2CharacterTemplate]
/^\[[[:alnum:]]+ X2CharacterTemplate\]/ {
    statOverride = 0

    currentUnit = gensub(/^\[([[:alnum:]]+) X2CharacterTemplate\]/, "\\1", "g")

    #The substituation for some reason inserts a carriage return in the result so have to get rid of it
    #with another substitution.
    gsub(/[^[:alnum:]]/, "", currentUnit)

    if(aliases[currentUnit] != "") {
        units[currentUnit]["tacticalName"] = aliases[currentUnit]
    } else {
        units[currentUnit]["tacticalName"] = "\"" currentUnit "\""
        delete aliases[currentUnit]
    }

    templateFileLines[templateFileLinsCount] = $0
    templateFileLinsCount = templateFileLinsCount + 1
    wroteLineToTemplate = 1
}

#CharacterBaseStats[eStat_HP]=5 or +CharacterBaseStats[eStat_HP]=5
/^\+?CharacterBaseStats/ {
    templateFileLine = ""
    replaceString = ""

    stat = gensub(/^\+?CharacterBaseStats\[eStat_([[:alnum:]]+)\] *= *.*/, "\\1" , "g")
    gsub(/[^[:alnum:]]/, "", stat)

    value = gensub(/^\+?CharacterBaseStats\[eStat_[[:alnum:]]+\] *= *([0-9]+).*/, "\\1" , "g")
    gsub(/[^[:alnum:]]/, "", value)

    if(!statOverride) {
        units[currentUnit]["defaultStats"][stat] = value
        #"= {{ WotC['units']['Sectoid']['defaultStats']['HP'] }}"
        replaceString = "\\1{{ " module "['units']['" currentUnit "']['defaultStats']['" stat "'] }}"
        templateFileLine = gensub(/(^\+?CharacterBaseStats\[eStat_[[:alnum:]]+\] *= *)([0-9]+).*/, replaceString, "g", $0)
    } else {
        units[currentUnit][diffOverrideKeys[currentDiffOverride]][stat] = value
        replaceString = "\\1{{ " module "['units']['" currentUnit "']['" diffOverrideKeys[currentDiffOverride] "']['" stat "'] }}"
        templateFileLine = gensub(/(^\+?CharacterBaseStats\[eStat_[[:alnum:]]+\] *= *)([0-9]+).*/, replaceString, "g", $0)
    }

    templateFileLines[templateFileLinsCount] = templateFileLine
    templateFileLinsCount = templateFileLinsCount + 1
    wroteLineToTemplate = 1
}

#[Soldier_Diff_1 X2CharacterTemplate]
/^\[[[:alnum:]]+_Diff_[0-3] X2CharacterTemplate\]/ {
    statOverride = 1

    currentUnit = gensub(/^\[([[:alnum:]]+)_Diff_[0-3] X2CharacterTemplate\]/, "\\1", "g")
    gsub(/[^[:alnum:]]/, "", currentUnit)

    currentDiffOverride = gensub(/^\[[[:alnum:]]+_Diff_([0-3]) X2CharacterTemplate\]/, "\\1", "g")
    currentDiffOverride = currentDiffOverride + 1

    templateFileLines[templateFileLinsCount] = $0
    templateFileLinsCount = templateFileLinsCount + 1
    wroteLineToTemplate = 1
}

{
    if(!wroteLineToTemplate) {
        templateFileLines[templateFileLinsCount] = $0
        templateFileLinsCount = templateFileLinsCount + 1
    } else {
        wroteLineToTemplate = 0
    }
}

#This is where the JSON Object for all of the stats read in gets created and then printed to file.
END {
    print ";" FILENAME >> templateFile

    for(i = 1; i <= length(templateFileLines); i++) {
        print templateFileLines[i] >> templateFile
    }

    linesCount = 1
    lines[linesCount] = "{"
    linesCount = linesCount + 1

    lines[linesCount] = "    \"" module "\": {"
    linesCount = linesCount + 1
    
    lines[linesCount] = "        \"units\": {"
    linesCount = linesCount + 1

    for(unit in units) {
        if(length(units[unit]["defaultStats"]) != 0) {
            lines[linesCount] = "            \"" unit "\": {"
            linesCount = linesCount + 1

            for(property in units[unit]) {
                if(property == "tacticalName") {
                    lines[linesCount] = "                \"" property "\": " units[unit]["tacticalName"] ","
                    linesCount = linesCount + 1
                } else {
                    lines[linesCount] = "                \"" property "\": {"
                    linesCount = linesCount + 1

                    for(stat in units[unit][property]) {
                        lines[linesCount] = "                    \"" stat "\": " units[unit][property][stat] ","
                        linesCount = linesCount + 1
                    }

                    lines[linesCount] = "                },"
                    linesCount = linesCount + 1
                }
            }

            lines[linesCount] = "            },"
            linesCount = linesCount + 1
        }
    }

    lines[linesCount] = "        },"
    linesCount = linesCount + 1

    lines[linesCount] = "        \"iniStatsFileName\": \"" FILENAME "\","
    linesCount = linesCount + 1

    lines[linesCount] = "        \"templateFileName\": \"" templateFile "\","
    linesCount = linesCount + 1

    lines[linesCount] = "    }"
    linesCount = linesCount + 1

    lines[linesCount] = "}"
    linesCount = linesCount + 1

    #What for loop does is looks for any index in the lines[] array and if the index ahead of this one is a "}" character
    #then the current line wil likely have a "," at the. This is due to the way that the strings are added to the array above
    #(there is no way for the loop avbove) to know when the last key/value pair of an object is so it adds a "," to all even
    #if it is the last key/value pair for the object so this will remove the "," if the line in the position at "index + 1"
    #is a "}"
    for(i = 1; i < linesCount; i++) {
        nextIndex = i + 1
        if(lines[nextIndex] ~ /}/) {
            sub(/,$/, "", lines[i])
        }

        print lines[i] >> jsonfile
    }
}