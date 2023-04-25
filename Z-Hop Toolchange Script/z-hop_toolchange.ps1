#pass the filename from your slicer to the script
[CmdletBinding()]
param (
    [Parameter(Mandatory, Position = 0)]
    [string]
    $GCodeFile
)

#import the gcode
$gcode = Get-Content -Path $GCodeFile
#start your first layer at 0
$global:current_layer = 0
$global:layerhop = 0
#start line index with 0
$i = 0
#store line where you want to drop the z-axis (in this case 2 lines after pressure advance after the toolchange is found)
$global:index_current_layer = 0
#empty the file to rewrite it with the new code
Clear-Content $GCodeFile
write-host "Working on $GCodeFile, please wait..."
& {
    foreach ($line in $gcode) {
        #count the lines
        $i++
		#search for your current Z-height to calculate Z-hop between toolchanges on the same layer 
        if ($line -match "^;Z:(\d+(\.\d+)?)") {
			#ignore the first layer info from the file prusaslicer creates
            [decimal]$layer = $matches[1]
            #some magic to give european decimals the dot back
            $global:current_layer = $layer -replace ',', '.'
            #amount of layerhop is defined here
            $global:layerhop = [decimal]$current_layer + "0.4" -replace ',', '.'
        }
        # if T1 toolchange GCODE is found add z-hop after toolchange
        if ($line -match "^T1") {
            $line = "$line`n" + "G1 Z$global:layerhop F8400"
			#some progress to look at
            write-host $line
        }
        # same same T0
        if ($line -match "^T0") {
            $line = "$line`n" + "G1 Z$global:layerhop F8400"
			#some progress to look at
            write-host $line
        }
        # if SET_PRESSURE_ADVANCE= is found save the linenumber +2 (in my case this is after the G1 move to the model)
        if ($line -match "^SET_PRESSURE_ADVANCE ADVANCE=") {
            $global:index_current_layer = $i + 2
        }
        # if the line number from above is met in the next cycles, it adds the toolhead down again to "real" Z-height
        if ($i -eq $global:index_current_layer) {
            $line = "$line`n" + "G1 Z$global:current_layer F8400"
        }
        # collect the line data to push it to the new file
        $line
    }
} | Out-File -filepath $GCodeFile -Encoding ascii #end of the loop to speed things up, write all data from RAM to file, enjoy