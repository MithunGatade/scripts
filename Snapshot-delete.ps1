<####################################################################################
.SYNOPSIS
    Generate VM Snapshot Delete report
.DESCRIPTION
    Reports on all snapshots in your VMware vCenter environment
.NOTES
    File Name  : Snapshot-Delete.ps1
    Author     : Mithun Gatade
    Date       : 07-06-2021
    
.LINKS
#>####################################################################################


$vCenters = Get-Content .\vCenterServerList.txt
$ExceptionVMs = Get-Content .\Exception-VMs.txt

$vsphereuser = "vspheresnapshot.svc"
$Creds = .\Get-myCredential.ps1 $vsphereuser .\Creds.txt

$EmailSMTPServer = "smtp.uhi.amerco"
$EmailFROM = "vSphere_Snapshot_delete@uhaul.com"
$EmailSubject = "vSphere Deleted Snapshots Report"

#$EmailCC = 'virtualizationengineering@uhaul.com'

$EmailTO = "mithun_gatade@uhaul.com"
$EmailCC = "mithun_gatade@uhaul.com"
#$EmailTO = "platformoperations@uhaul.com","systems.engineering@uhaul.com"





## Create an array to hold our output objects
$OutputArray = @()



foreach ($vCenter in $vCenters)
{
    $Snapshots = @()
    Connect-VIServer -Server $vCenter -Credential $Creds -Force

    # Get all VM with Snapshot
    $Snapshots = Get-VM | Get-Snapshot | Where { ($_.Created -lt (Get-Date).AddDays(-8)) -AND ($_.Created -gt (Get-Date).AddDays(-30)) -AND ($_.Name -notlike "VEEAM BACKUP TEMPORARY SNAPSHOT") }
    if ( ![string]::IsNullOrWhiteSpace($Snapshots) )
    {
        $VMwithSapshots = $Snapshots.VM | Select-Object -Unique 
        
        if ( [string]::IsNullOrWhiteSpace($ExceptionVMs) )
        {
            $VMs = $VMwithSapshots
        }
        else 
        {
            $VMs = Compare-Object -ReferenceObject $VMwithSapshots -DifferenceObject $ExceptionVMs | Where-Object { $_.SideIndicator -notlike "=>" }
        }
        

        if ( ![string]::IsNullOrWhiteSpace($VMs) )
        {
        ### Delete snapshot
        foreach ($VM in $VMs)   
        {

            $Snapshot = Get-Snapshot -VM $VM.InputObject | Where { ($_.Created -lt (Get-Date).AddDays(-8)) -AND ($_.Created -gt (Get-Date).AddDays(-30)) -AND ($_.Name -notlike "VEEAM BACKUP TEMPORARY SNAPSHOT") }
            # Create an temporary empty object to hold the information we gather
            $ObjTemp = New-Object -TypeName psobject 
        
            # Try to find the event logged when snapshot was created, using the creation time of the snapshot +/- 5 minutes
            $SnapshotEvent = Get-VIEvent -Entity $Snapshot.VM.Name `
                                     -Start $Snapshot.Created.AddMinutes(-5) `
                                     -Finish $Snapshot.Created.AddMinutes(5) `
                                     | Where-Object {$_.FullFormattedMessage -ilike "*Create virtual machine snapshot*"}

            # Add some information from our snapshot to our output object
            Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "vCenter Server"      -Value $vCenter
            Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Virtual Machine"      -Value $Snapshot.VM
            Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Snapshot Name"        -Value $Snapshot.Name
            Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Creation Date"        -Value $Snapshot.Created
            Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Snapshot Age (Days)"  -Value ((Get-Date) - $Snapshot.Created).Days
            Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Snapshot Size (GB)"   -Value ([Math]::Round($Snapshot.SizeGB,2))
            Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Snapshot Description" -Value $Snapshot.Description

            if ($SnapshotEvent -and $SnapshotEvent -is [System.Array])
            {
                # More than one even found, so we can't determine who made the snapshot.
                Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Created By" -Value "Unknown"
            }
            elseif($SnapshotEvent -and -not($SnapshotEvent -is [System.Array]))
            {
                # Found one event
                Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Created By" -Value $SnapshotEvent.UserName
            }
            else
            {
                # No events found
                Add-Member -InputObject $ObjTemp -MemberType NoteProperty -Name "Created By" -Value "Unknown"
            }

            # Add our object to our output array
            $OutputArray += $ObjTemp

            $ObjTemp = ""

        
             #Get-Snapshot -VM $VM.InputObject | Remove-Snapshot -confirm:$false -runasync:$true

        }#ForeachVM

        } #If VMs Not empty
    
    
    }#If snapshot



    
    Disconnect-VIServer -Server $vCenter -Force -Confirm:$false
}#Foreach vCenter


$today_date = Get-Date -Format MMM-dd-yyyy

$Report_Path = "\\fs_infrastructure.amerco.org\CSS-SYSADMIN\VMware\Snapshot-Delete-report\vSphere_VM_snapshot_delete_" + $today_date +"_report.csv"

Write-Host "OutputArray :" $OutputArray

 if ( ![string]::IsNullOrWhiteSpace($OutputArray) ) 
{
        ## Create an empty array to hold formatted output
        $OutputFormatted = @()

        ## Create a pointer variable for formatting
        $FormatPointer = 1

        ## Create a html tag to open the table in our formatted output
        $OutputFormatted = "<table style='border: 1px solid black;border-collapse: collapse;'>"

        ## Add a table row for our data headers
        $OutputFormatted += "<tr style='background-color: #98AFC7;font-weight: bold;'>"
        $OutputFormatted += "<td style='border: 1px solid black;'>vCenter Server</ td>"
        $OutputFormatted += "<td style='border: 1px solid black;'>Virtual Machine</ td>"
        $OutputFormatted += "<td style='border: 1px solid black;'>Snapshot Name</ td>"
        $OutputFormatted += "<td style='border: 1px solid black;'>Creation Date</ td>"
        $OutputFormatted += "<td style='border: 1px solid black;'>Snapshot Age (Days)</ td>"
        $OutputFormatted += "<td style='border: 1px solid black;'>Snapshot Size (GB)</ td>"
        $OutputFormatted += "<td style='border: 1px solid black;'>Snapshot Description</ td>"
        $OutputFormatted += "<td style='border: 1px solid black;'>Created By</ td>"

        ## Close the table row
        $OutputFormatted += "</ tr>"
        
        ## Now, make it pretty
        foreach ($Line in $OutputArray)
        {
            if ($FormatPointer -eq 0)
            {
                # Set our background color, and invert our pointer
                $color = "#98AFC7"
                $FormatPointer = 1
            }
            else
            {
                # Set our background color, and invert our pointer
                $color = "#FFFFFF"
                $FormatPointer = 0
            }

            # Open our table row
            $OutputFormatted += "<tr style='background-color: $color;'>"

            # Add our data in table cells
            $OutputFormatted += "<td style='padding: 0px 5px;'>$($Line.'vCenter Server')</ td>"
            $OutputFormatted += "<td style='padding: 0px 5px;'>$($Line.'Virtual Machine')</ td>"
            $OutputFormatted += "<td style='padding: 0px 5px;'>$($Line.'Snapshot Name')</ td>"
            $OutputFormatted += "<td style='padding: 0px 5px;'>$($Line.'Creation Date')</ td>"
            $OutputFormatted += "<td style='padding: 0px 5px;'>$($Line.'Snapshot Age (Days)')</ td>"
            $OutputFormatted += "<td style='padding: 0px 5px;'>$($Line.'Snapshot Size (GB)')</ td>"
            $OutputFormatted += "<td style='padding: 0px 5px;'>$($Line.'Snapshot Description')</ td>"
            $OutputFormatted += "<td style='padding: 0px 5px;'>$($Line.'Created By')</ td>"

            # Close the table row
            $OutputFormatted += "</ tr>"

            # Add it to our formatted output array
        }

        ## Close our HTML table tag
        $OutputFormatted += "</ table>"

        ## Now create the body of our email
        $EmailBody = "Hello Team, </br> </br> vSphere VM Snapshot Delete report is generated and available at below share location </br> </br> $Report_Path  <br /> <br /> Report is genrated for vCenters <i> $vCenters </i> </br></br></br></br></br> $OutputFormatted" 


## Email Report

Write-host "sending email"

Send-MailMessage -From $EmailFROM -To $EmailTO -Cc $EmailCC -Subject $EmailSubject -Body $EmailBody -BodyAsHtml -SmtpServer $EmailSMTPServer

} #if output empty


$OutputArray | Export-Csv -NoTypeInformation $Report_Path
