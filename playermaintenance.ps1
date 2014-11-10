    $regex = "\d{4}-\d{2}-\d{2}"
    $dte = Get-Date
    $dte = $dte.AddDays(-14)  #this is the number of days a player would have to be afk for this script to delete things.
    $dte = $dte.DayofYear
    [int]$deletefactions = 0
    [int]$counter = 0
    [int]$deletedplayer = 0

    #save paths

    $filePath = 'yoursavepath\SANDBOX_0_0_0_.sbs'         
    #$filePath = 'yourtestsavepath\SANDBOX_0_0_0_.sbs'
    $filePath2 = 'yoursavepath\SANDBOX.sbc'
    #$filePath2 = 'yourtestsavepath\SANDBOX.sbc'
    $playerslog = "youradminlogpath\Admin Logs\Audits\Active Players\"
    $serverlogs = 'C:\ProgramData\SpaceEngineersDedicated\your server save logs&root path'   #<--- example only
    #$serverlogs = 'yourtestlogspath'

   #=======MAKE NO CHANGES BELOW THIS POINT UNLESS YOU KNOW WHAT YOU ARE DOING ==========


    $CurrentDateTime = Get-Date -Format "MM-dd-yyyy_HH-mm"
    $playerfilename = "Players_log_" +$CurrentDateTime+ ".log"
    $playerspath = $playerslog + $playerfilename

    Write-Host -ForegroundColor Green "SE-Player-Clean loading please wait ... "

    [xml]$myXML = Get-Content $filePath
    $ns = New-Object System.Xml.XmlNamespaceManager($myXML.NameTable)
    $ns.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

    [xml]$myXML2 = Get-Content $filePath2
    $ns2 = New-Object System.Xml.XmlNamespaceManager($myXML2.NameTable)
    $ns2.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

    New-Item -path $playerspath -type file

    Add-Content -path $playerspath -Value "[$([DateTime]::Now)] FoH Space Engineers Dedicated Players Audit Log  ==================="

    #wipe orphaned id's (permanent death issue) if dead player owns nothing.
    [string]$compare = "360"
    $nodePIDs = $myXML2.SelectNodes("//Identities/MyObjectBuilder_Identity"  , $ns2)
    $nodeOwns = $myXML.SelectNodes("//SectorObjects/MyObjectBuilder_EntityBase[(@xsi:type='MyObjectBuilder_CubeGrid')]/CubeBlocks/MyObjectBuilder_CubeBlock[Owner='$playerid']"  , $ns)
    ForEach($node in $nodePIDs){
        $NPCID = [string]$node.PlayerId.InnerText[0] + [string]$node.PlayerId.InnerText[1] + [string]$node.PlayerId.InnerText[2]
        $playerid = $node.PlayerId
        $clientcount=$myXML2.SelectNodes("//ConnectedPlayers/dictionary/item[Value='$playerid'] | //DisconnectedPlayers/dictionary/item[Value='$playerid']" , $ns2).count
        $nodeOwns = $myXML.SelectNodes("//SectorObjects/MyObjectBuilder_EntityBase[(@xsi:type='MyObjectBuilder_CubeGrid')]/CubeBlocks/MyObjectBuilder_CubeBlock[Owner='$playerid']"  , $ns).count
        IF($clientcount -eq 0 -and $nodeOwns -eq 0 -and $NPCID -ne $compare){
            $selectdelete = $myXML2.SelectSingleNode("//Factions/Factions/MyObjectBuilder_Faction/Members/MyObjectBuilder_FactionMember[PlayerId='$playerid']" , $ns2)
            Try{$selectdelete.ParentNode.RemoveChild($selectdelete)}
            Catch{Write-Host -ForegroundColor Green "[$($node.DisplayName)] is not a member of a faction, proceeding..."}
            $selectdelete = $myXML2.SelectSingleNode("//Factions/Players/dictionary/item[Key='$playerid']", $ns2)
            Try{$selectdelete.ParentNode.RemoveChild($selectdelete)}
            Catch{Write-Host -ForegroundColor Green "[$($node.DisplayName)]; no faction dictionary data found, proceeding..."}
            $selectdelete = $myXML2.SelectSingleNode("//Factions/Factions/MyObjectBuilder_Faction/JoinRequests/MyObjectBuilder_FactionMember[PlayerId='$playerid']" , $ns2)
            Try{$selectdelete.ParentNode.RemoveChild($selectdelete)}
            Catch{Write-Host -ForegroundColor Green "[$($node.DisplayName)] has no faction join requests, proceeding..."}
            $node.ParentNode.RemoveChild($node)
            Write-Host -ForegroundColor Green " abandoned ID deleted "
        } 
    }

    #find block owners and delete blocks based on last log in
    Add-Content -Path $playerspath -Value "="
    Add-Content -Path $playerspath -Value "Ships ========="
    $nodePIDs = $myXML2.SelectNodes("//Identities/MyObjectBuilder_Identity"  , $ns2)
    $nodeClientID=$myXML2.SelectNodes("//ConnectedPlayers/dictionary/item | //DisconnectedPlayers/dictionary/item" , $ns2) 
    $nodeOwns = $myXML.SelectNodes("//SectorObjects/MyObjectBuilder_EntityBase[(@xsi:type='MyObjectBuilder_CubeGrid')]/CubeBlocks/MyObjectBuilder_CubeBlock"  , $ns)
    ForEach($node in $nodePIDs){
        ForEach($node3 in $nodeClientID){
            IF($node3.Value.InnerText -eq $node.PlayerId){
                $nodename = $node3.Key.ClientId
                $findlogin = $null
                $findlogin = dir $serverlogs -Include *.log -Recurse | Select-String -Pattern "Peer2Peer_SessionRequest $nodename" 
                Add-Content -Path $playerspath -Value "="
                Add-Content -Path $playerspath -Value "Checking Player [$($node.PlayerId)] [$($node.DisplayName)]!"
                Try{Add-Content -Path $playerspath -Value "Last login: [$($findlogin[-1])]"}
                Catch{
                    Write-Host -ForegroundColor Yellow "ERROR! Log Entry not found! Check your server logs path. This player may also not have any log entries if logging was not previously enabled.  Skipping ..."
                    Write-Host -ForegroundColor Yellow "****You can use a 3rd Party tool such as SEToolBox to manually remove this player's assets.****"
                    Add-Content -Path $playerspath -Value "****ERROR! Log Entry not found! Check your server logs path. This Player may also not have any log entries if logging was not previously enabled.****"
                    Add-Content -Path $playerspath -Value "****You can use a 3rd Party tool such as SEToolBox to manually remove this player's assets.****"
                    } 
                Add-Content -Path $playerspath -Value "****blocks owned/deleted****"
                ForEach($node2 in $nodeOwns){
                  if ($node.PlayerId -eq $node2.Owner){
                    $matchInfos = $null
                    Try{$matchInfos = @(Select-String -Pattern $regex -AllMatches -InputObject [$($findlogin[-1])])
                    foreach ($minfo in $matchInfos){
                        foreach ($match in @($minfo.Matches | Foreach {$_.Groups[0].value})){
                            if ([datetime]::parseexact($match, "yyyy-MM-dd", $null).DayOfYear -lt $dte){
                               Add-Content -Path $playerspath -Value "[$($node2.SubtypeName)] Grid Coordinates: $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select X) , $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select Y) , $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select Z)" 
                               Add-Content -Path $playerspath -Value "owner not active this block has been deleted"
                               $node2.ParentNode.RemoveChild($node2)
                               $counter = $counter + 1
                            }
                        
                        }
                   }
                   }
                   Catch{}
                 }
            }
        } 
      }
    }


    #player clean    

    Add-Content -Path $playerspath -Value "="
    Add-Content -Path $playerspath -Value "Player Cleanup ========="
    $nodePIDs = $myXML2.SelectNodes("//Identities/MyObjectBuilder_Identity"  , $ns2)
    $nodeClientID=$myXML2.SelectNodes("//ConnectedPlayers/dictionary/item | //DisconnectedPlayers/dictionary/item" , $ns2) 
    ForEach($node in $nodePIDs){
        ForEach($node3 in $nodeClientID){
            IF($node3.Value.InnerText -eq $node.PlayerId){
                $nodename = $node3.Key.ClientId
                $nodeid = $node.PlayerId
                Add-Content -Path $playerspath -Value "="
                Add-Content -Path $playerspath -Value "Checking [$($node.DisplayName)] ..."
                $nodeOwns = $myXML.SelectNodes("//SectorObjects/MyObjectBuilder_EntityBase[(@xsi:type='MyObjectBuilder_CubeGrid')]/CubeBlocks/MyObjectBuilder_CubeBlock[Owner='$nodeid']"  , $ns).Count
                Add-Content -Path $playerspath -Value "$nodeOwns blocks owned"
                If($nodeOwns -eq 0){
                  $selectdelete = $myXML2.SelectSingleNode("//Factions/Factions/MyObjectBuilder_Faction/Members/MyObjectBuilder_FactionMember[PlayerId='$nodeid']" , $ns2)
                  Try{$selectdelete.ParentNode.RemoveChild($selectdelete)}
                  Catch{Write-Host -ForegroundColor Green "[$($node.DisplayName)] is not a member of a faction, proceeding..."}
                  $selectdelete = $myXML2.SelectSingleNode("//Factions/Players/dictionary/item[Key='$nodeid']", $ns2)
                  Try{$selectdelete.ParentNode.RemoveChild($selectdelete)}
                  Catch{Write-Host -ForegroundColor Green "[$($node.DisplayName)]; no faction dictionary data found, proceeding..."}
                  $selectdelete = $myXML2.SelectSingleNode("//Factions/Factions/MyObjectBuilder_Faction/JoinRequests/MyObjectBuilder_FactionMember[PlayerId='$nodeid']" , $ns2)
                  Try{$selectdelete.ParentNode.RemoveChild($selectdelete)}
                  Catch{Write-Host -ForegroundColor Green "[$($node.DisplayName)] has no faction join requests, proceeding..."}
                  Add-Content -Path $playerspath -Value "Deleting [$nodename] [$nodeid] [$($node.DisplayName)]"
                  $node3.ParentNode.RemoveChild($node3)
                  $node.ParentNode.RemoveChild($node)
                  $deletedplayer = $deletedplayer + 1
                } 
            }
        }
    }

    #factioncleaning
    Add-Content -Path $playerspath -Value "="
    Add-Content -Path $playerspath -Value "Empty Faction Cleanup ========="
    $nodeFactions = $myXML2.SelectNodes("//Factions/Factions/MyObjectBuilder_Faction" , $ns2)
    ForEach($faction in $nodeFactions){
        $membercount = $faction.SelectNodes("Members/MyObjectBuilder_FactionMember" , $ns2).count
        $factionid = $faction.FactionId
        If($membercount -eq 0 -or $membercount -eq $null){
            $selectdelete = $myXML2.SelectNodes("//Factions/Requests/MyObjectBuilder_FactionRequests[FactionId='$factionid']" , $ns2)
            ForEach($selected in $selectdelete){
                $selected.ParentNode.RemoveChild($selected)
            }
            $selectdelete = $myXML2.SelectNodes("//Factions/Relations/MyObjectBuilder_FactionRelation[FactionId1='$factionid' or FactionId2='$factionid']" , $ns2)
            ForEach($selected in $selectdelete){
                $selected.ParentNode.RemoveChild($selected)
            }
            Add-Content -Path $playerspath -Value "Deleted faction $($faction.Name) ..."
            #Write-Host -ForegroundColor Green "actioned! $membercount"
            $faction.ParentNode.RemoveChild($faction)
            $deletefactions = $deletefactions + 1
        }
        #IF($membercount -ne 0 -or $membercount-ne $null){Write-Host -ForegroundColor Green "no action $membercount"}
    }



        Add-Content -Path $playerspath -Value "="
        Add-Content -Path $playerspath -Value "$counter owned blocks deleted due to owners not logging in." 
        
        Add-Content -Path $playerspath -Value "="
        Add-Content -Path $playerspath -Value "$deletedplayer players removed for not owning anything."

        Add-Content -Path $playerspath -Value "="
        Add-Content -Path $playerspath -Value "$deletefactions empty factions removed."




        $myXML.Save($filePath)
        $myXML2.Save($filePath2)
