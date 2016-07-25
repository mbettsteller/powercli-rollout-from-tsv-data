if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
    Add-PSSnapin VMware.VimAutomation.Core
}

Function Main{

    $vcenter = "vcenter.localdomain"

    #Fixed password in script if you are quickly testing local or want to automate the rollout
    #$username = "yourusername@vsphere6.local"
    #$plainpassword = "password"
    #$securepassword = $plainpassword | ConvertTo-SecureString -AsPlainText -Force
    #$credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securepassword

    #On demand: asking the admin for vcenter credentials at each run of the script
    $credential = Get-Credential -Message "Enter Credentials for $vcenter" -UserName "yourusername@vsphere6.local"
    $Session = Connect-VIServer -Server $vcenter -Force -Credential $credential

    if(!$Session.IsConnected){
        $Session = Connect-VIServer -Server $vcenter -Force -Credential $credential
    }

    #The 
    $ServerListe=@{}
    Import-Csv "rollout.tsv" -Delimiter "`t"| ForEach-Object {
            $server = @{name=$_.vmname;
                template=$_.template;
                vlan=$_.vlan;
                resourcepool=$_.resourcepool;
                customspec=$_.customspec;
                datastore=$_.datastore;
                vmfolder=$_.vmfolder}

                $ServerListe+=@{$server.name=$server}
        }
    

    foreach($server in $ServerListe.Keys)
    {
        New-VM -Location (Get-Folder -Name $ServerListe.$server.vmfolder -Type VM) -Name $ServerListe.$server.name -Server $Session -Template (Get-Template -Name $ServerListe.$server.template -Server $Session) -ResourcePool $ServerListe.$server.resourcepool -Datastore $ServerListe.$server.datastore -OSCustomizationSpec $Serverliste.$server.customspec -RunAsync:$true
    }

    #Once stuff is created, try to do your work, staring by setting the VLAN
    foreach($server in $ServerListe.Keys)
    {
        #try to set the adapter
        Write-Output $("trying to set adapter on " + $ServerListe.$server.name)
        (Set-NetworkAdapter `
            -NetworkAdapter (Get-NetworkAdapter `
                                -VM (Get-VM $ServerListe.$server.name -ErrorAction SilentlyContinue) `
                                -Name "Network adapter 1" `
                                -ErrorAction SilentlyContinue) `
            -NetworkName $ServerListe.$server.vlan `
            -StartConnected:$true `
            -Confirm:$false `
            -Verbose `
            -RunAsync:$false `
            -ErrorAction SilentlyContinue)|Out-Null
        #if it fails enter a loop and try until it succeeds! The New-VM may still be copying the files and is not ready yet!
        #Also  this setup is checking the network adapter 1 and tries to set it. If you have a different config you may need to adapt for more nics.
        #Also you may need another fitting customSpec in the New-VM command above.
        if ($? -eq $false){
            do{
                sleep 5
                Write-Output $("trying to set adapter on " + $ServerListe.$server.name)
                (Set-NetworkAdapter `
                    -NetworkAdapter (Get-NetworkAdapter `
                                        -VM (Get-VM $ServerListe.$server.name -ErrorAction SilentlyContinue) `
                                        -Name "Network adapter 1" `
                                        -ErrorAction SilentlyContinue) `
                    -NetworkName $ServerListe.$server.vlan `
                    -StartConnected:$true `
                    -Confirm:$false `
                    -Verbose `
                    -RunAsync:$false `
                    -ErrorAction SilentlyContinue)|Out-Null
            }
            while($? -eq $false)
        }
    }
    Disconnect-VIServer -Server $vcenter -Confirm:$false
}

Main


