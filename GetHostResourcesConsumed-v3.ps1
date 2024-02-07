Function Get-HvStats {
    param(
        [Parameter(Mandatory=$true, Position=0,HelpMessage="Hyper-V host.")]
        [string[]]$ComputerName = $(throw = "Please specify a remote Hyper-V host to gather memory details from.")
    )
	
    # Create an array to return
    $allStats = @()
	
	ForEach ($node in (Get-ClusterNode)) {
	

	
		# Create an array to contain this computer's metrics
        $a = @()
	
		# Construct an array of properties to return
        $item = New-Object PSObject
	
		# Get total RAM consumed by running VMs.
		$total = 0
		Get-VM -ComputerName $node | Where-Object { $_.State -eq "Running" } | Select-Object Name, MemoryAssigned | ForEach-Object { $total = $total + $_.MemoryAssigned }
	
		#Get available RAM via performance counters
		$Bytes = Get-Counter -ComputerName $node -Counter "\Memory\Available Bytes"
	
		# Convert values to GB
		$availGB = ($Bytes[0].CounterSamples.CookedValue / 1GB)
		$hostGB = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb
		$vmInUse = ($total / 1GB)
		

		
		#Get CPU/vCPU Details
		$processors =  gwmi -ComputerName $node -ns root\virtualization\v2 MSvm_Processor
		$NumLogicalCPUs = @($processors | Where-Object{ $_.ElementName.toLower().Contains( "logical processor")  }).count
		$NumVirtualCPUs = @($processors | Where-Object{ $_.ElementName.toLower() -eq "processor"  }).count
		
		# Add host name
        $item | Add-Member -type NoteProperty -Name 'Name' -Value $node.Name

        # Host RAM in GB
        $item | Add-Member -type NoteProperty -Name 'HostRAMGB' -Value $hostGB

        # In use RAM in GB
        $item | Add-Member -type NoteProperty -Name 'VMInUseGB' -Value $vmInUse

        # System used in GB
        $item | Add-Member -type NoteProperty -Name 'SystemUsedGB' -Value ($hostGB - ($vmInUse + $availGB))

        # Available RAM in GB
        $item | Add-Member -type NoteProperty -Name 'AvailableGB' -Value $availGB
		
		#CPU info
		$item | Add-Member -type NoteProperty -Name 'Logical CPUs' -Value $NumLogicalCPUs
		$item | Add-Member -type NoteProperty -Name 'Virtual CPUs' -Value $NumVirtualCPUs
		
		$a += $item
		# Add the current machine details to the array to return
        $allStats += $a
		
	}
	
	return $allstats
}
$timestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
Get-HvStats -ComputerName slcdhyp01.leadventure.dev,slcdhyp02.leadventure.dev,slcdhyp03.leadventure.dev,slcdhyp04.leadventure.dev,slcdhyp05.leadventure.dev,slcdhyp06.leadventure.dev,slcdhyp07.leadventure.dev | Export-CSV -Path "C:\Scripts\ScriptResults\ResourceConsumption$timestamp.csv"

Send-MailMessage -From 'slcdhyp* <slcdevcluster@leadventure.com>' -To 'Daniel Niska <daniel.niska@leadventure.com>' -Subject 'Resource Report for SLC Dev Cluster Nodes' -Attachment "C:\Scripts\ScriptResults\ResourceConsumption$timestamp.csv" -SmtpServer 'o365.smtp.relay'