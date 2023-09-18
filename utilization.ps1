# Connect to your vCenter server
Connect-VIServer -Server Your-vCenter-Server -User Your-Username -Password Your-Password

# Function to get VM utilization
function Get-VMUtilization {
    param (
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$vm
    )
    $vmView = $vm | Get-View
    $stats = $vmView.Summary.QuickStats
    $vmInfo = @{
        VMName = $vm.Name
        CPUUsageMHz = $stats.OverallCpuUsage
        MemoryUsageMB = $stats.OverallMemoryUsage
        CPUPercentUsage = $stats.OverallCpuUsage / $vm.Config.Hardware.NumCPU * 100
        MemoryPercentUsage = $stats.OverallMemoryUsage / $vm.Config.Hardware.MemoryMB * 100
    }
    New-Object PSObject -Property $vmInfo
}

# Function to get Host utilization
function Get-HostUtilization {
    param (
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$host
    )
    $hostView = $host | Get-View
    $stats = $hostView.Summary.QuickStats
    $hostInfo = @{
        HostName = $host.Name
        CPUUsageMHz = $stats.OverallCpuUsage
        MemoryUsageMB = $stats.OverallMemoryUsage
        CPUPercentUsage = $stats.OverallCpuUsage / $host.Summary.Hardware.CpuMhz * 100
        MemoryPercentUsage = $stats.OverallMemoryUsage / $host.Summary.Hardware.MemorySize / 1MB * 100
    }
    New-Object PSObject -Property $hostInfo
}

# Function to get Cluster utilization
function Get-ClusterUtilization {
    param (
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl]$cluster
    )
    $clusterView = $cluster | Get-View
    $clusterStats = $clusterView.ResourcePool.Summary.QuickStats
    $clusterInfo = @{
        ClusterName = $cluster.Name
        CPUUsageMHz = $clusterStats.OverallCpuUsage
        MemoryUsageMB = $clusterStats.OverallMemoryUsage
        CPUPercentUsage = $clusterStats.OverallCpuUsage / $clusterView.TotalCpu / 100
        MemoryPercentUsage = $clusterStats.OverallMemoryUsage / $clusterView.TotalMemory / 1MB * 100
    }
    New-Object PSObject -Property $clusterInfo
}

# Get a list of all VMs, Hosts, and Clusters
$vms = Get-VM
$hosts = Get-VMHost
$clusters = Get-Cluster

# Collect and display VM utilization
$vmUtilization = $vms | ForEach-Object { Get-VMUtilization $_ }
$vmUtilization | Format-Table -AutoSize

# Collect and display Host utilization
$hostUtilization = $hosts | ForEach-Object { Get-HostUtilization $_ }
$hostUtilization | Format-Table -AutoSize

# Collect and display Cluster utilization
$clusterUtilization = $clusters | ForEach-Object { Get-ClusterUtilization $_ }
$clusterUtilization | Format-Table -AutoSize

# Disconnect from the vCenter server
Disconnect-VIServer -Server Your-vCenter-Server -Confirm:$false
