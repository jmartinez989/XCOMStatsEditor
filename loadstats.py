import sys
import os
import json

def main():
    #The below 2 are going to be used to store values from a call to input() and a while loop will be used to
    #check these against a set value for the situation needed. statValue will be used to replace the desired
    #value of the desired unit. Difficulty will be used to choose which difficulty to change stats for.
    statValue = -1
    difficulty = -1

    continueChanging = True
    #Set of keys that will be used in the characterData[moduleName]["units"][unitName] section of the json object.
    #The key "defaultStats" will be used for 
    difficultyKeys = ["defaultStats", "rookieStats", "veteranStats", "commanderStats", "legendStats"]
    difficultyStrings = ["Base", "Rookie", "Veteran", "Commander", "Legend"]

    #Name of the file with full path. This script will be called from a main wrapper script that will have already checked if the file exists so no need to do here.
    jsonFile = sys.argv[1]
    characterData = json.load(open(jsonFile))

    moduleName = characterData.keys()[0]
    
    while continueChanging:
        for unit in characterData[moduleName]["units"].keys():
            print unit

        unitName = input("\nChoose unit whose stats you wish to edit from above: ")

        while unitName not in characterData[moduleName]["units"].keys():
            unitName = input("\nInvalid unit name \"{}\". Please change: ".format(unitName))

        print("\nChoose difficulty for which you wish to change stats for (base means default stats so applies to all)")
        print("1: Base\n2: Rookie\n3: Veteran\n4: Commander\n5: Legend")

        while difficulty < 1:
            try:
                difficulty = int(input("\nChoice: ")) - 1

                if difficulty < 1 or difficulty > 5:
                    print("Invalid choice \"{}\". Please re enter: ")
                    difficulty = -1
            except ValueError:
                print("Invalid choice \"{}\". Please re enter: ")

        difficultyName = difficultyStrings[difficulty]
        statSet = difficultyKeys[difficulty]

        #When grabing stats for a specific difficulty you wont get all stats listed, only the ones that got changed for that difficulty.
        #What this does is grabs the default stats (so all of them) so that when we grab the stats from the specific difficulty we
        #can override the ones in the baseStats object. Have to use the copy() method or else any changes made to it will also reflect
        #on the original object.
        baseStats = characterData[moduleName]["units"][unitName]["defaultStats"].copy()

        #Take the base stats that are to be replaced and replace them with the stat for the given difficulty.
        for statName in characterData[moduleName]["units"][unitName][statSet]:
            baseStats[statName] = characterData[moduleName]["units"][unitName][statSet][statName]

        if(difficultyName == "Base"):
            print("\nBase stats for unit {}".format(unitName))
        else:
            print("\nStats for unit {} on {} difficulty:".format(unitName, difficultyName))

        #main loop for editing unit stats
        for statName in baseStats:
            print("    {}: {}".format(statName, baseStats[statName]))

        statToChange = input("\nEnter stat to change (best to copy paste and don't forget quotes): ")

        while statToChange not in baseStats:
            statToChange =  input("\nInvalid stat to change \"{}\". Please change: ".format(statToChange))

        while statValue < 0:
            try:
                statValue = int(input("\nEnter amount for stat \"{}\" (careful with amounts here, can cause bad behavior or even break things): ".format(statToChange)))
            except ValueError:
                print("Ivalid value for stat \"{}\"".format(statToChange))

        characterData[moduleName]["units"][unitName][statSet][statToChange] = statValue
        
        try:
            continueChanging = int(input("\nStat \"{}\" has been changed for unit \"{}\" on difficulty \"{}\". Continue changing stats? (1 = yes, anything else = no): ".format(statToChange, unitName, difficultyName)))
        except ValueError:
            continueChanging = False
        except NameError:
            continueChanging = False
if __name__ == "__main__":
    main()
else:
    raise ImportWarning("Do not import this module, run it as main.")