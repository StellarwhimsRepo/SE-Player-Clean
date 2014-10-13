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
    $serverlogs = 'yourserverlogspath'

   #=======MAKE NO CHANGES BELOW THIS POINT UNLESS YOU KNOW WHAT YOU ARE DOING ==========


    $CurrentDateTime = Get-Date -Format "MM-dd-yyyy_HH-mm"
    $playerfilename = "Players_log_" +$CurrentDateTime+ ".log"
    $playerspath = $playerslog + $playerfilename

    [xml]$myXML = Get-Content $filePath
    $ns = New-Object System.Xml.XmlNamespaceManager($myXML.NameTable)
    $ns.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

    [xml]$myXML2 = Get-Content $filePath2
    $ns2 = New-Object System.Xml.XmlNamespaceManager($myXML2.NameTable)
    $ns2.AddNamespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

    New-Item -path $playerspath -type file

    Add-Content -path $playerspath -Value "[$([DateTime]::Now)] FoH Space Engineers Dedicated Players Audit Log  ==================="

    #find block owners and delete blocks based on last log in
    Add-Content -Path $playerspath -Value "="
    Add-Content -Path $playerspath -Value "Ships ========="
    $nodePIDs = $myXML2.SelectNodes("//AllPlayers/PlayerItem"  , $ns2) 
    $nodeOwns = $myXML.SelectNodes("//SectorObjects/MyObjectBuilder_EntityBase[(@xsi:type='MyObjectBuilder_CubeGrid')]/CubeBlocks/MyObjectBuilder_CubeBlock"  , $ns)
    ForEach($node in $nodePIDs){
        $nodename = $node.SteamId
        $findlogin = $null
        $findlogin = dir $serverlogs -Include *.log -Recurse | Select-String -Pattern "Peer2Peer_SessionRequest $nodename" 
        Add-Content -Path $playerspath -Value "="
        Add-Content -Path $playerspath -Value "[$($node.PlayerId)] [$($node.Name)] is Dead? : [$($node.IsDead)] !"
        Add-Content -Path $playerspath -Value "Last login: [$($findlogin[-1])]" -EA SilentlyContinue
        Add-Content -Path $playerspath -Value "****blocks owned/deleted****"
        ForEach($node2 in $nodeOwns){
            if ($node.PlayerId -eq $node2.Owner){
              #Add-Content -Path $playerspath -Value "$($node2.ParentNode.ParentNode.DisplayName) Coordinates: $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select X) , $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select Y) , $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select Z)"
                #if($findlogin[-1] -eq $null){

                 #   Add-Content -Path $playerspath -Value "$($node2.SubtypeName) Grid Coordinates: $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select X) , $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select Y) , $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select Z)"
                 #   Add-Content -Path $playerspath -Value "owner not active this block has been deleted"
                 #   $node2.ParentNode.RemoveChild($node2)
                 #   $counter = $counter + 1

                #}
                
                $matchInfos = @(Select-String -Pattern $regex -AllMatches -InputObject [$($findlogin[-1])])
                foreach ($minfo in $matchInfos){
                    foreach ($match in @($minfo.Matches | Foreach {$_.Groups[0].value})){
                        if ([datetime]::parseexact($match, "yyyy-MM-dd", $null).DayOfYear -lt $dte){
                           Add-Content -Path $playerspath -Value "$($node2.SubtypeName) Grid Coordinates: $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select X) , $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select Y) , $($node2.ParentNode.ParentNode.PositionAndOrientation.position | Select Z)" 
                           Add-Content -Path $playerspath -Value "owner not active this block has been deleted"
                           $node2.ParentNode.RemoveChild($node2)
                           $counter = $counter + 1
                        }
                        
                    }
               }
            }
            
        }
        }


    #player clean    

    Add-Content -Path $playerspath -Value "="
    Add-Content -Path $playerspath -Value "Player Cleanup ========="
    $nodePIDs = $myXML2.SelectNodes("//AllPlayers/PlayerItem"  , $ns2) 
    ForEach($node in $nodePIDs){
        Add-Content -Path $playerspath -Value "="
        Add-Content -Path $playerspath -Value "Checking $($node.Name) ..."
        $nodename = $node.SteamId
        $nodeid = $node.PlayerId
        $nodeOwns = $myXML.SelectNodes("//SectorObjects/MyObjectBuilder_EntityBase[(@xsi:type='MyObjectBuilder_CubeGrid')]/CubeBlocks/MyObjectBuilder_CubeBlock[Owner='$nodeid']"  , $ns).Count
        Add-Content -Path $playerspath -Value "$nodeOwns blocks owned"
            If($nodeOwns -eq 0){
              $selectdelete = $myXML2.SelectSingleNode("//Factions/Factions/MyObjectBuilder_Faction/Members/MyObjectBuilder_FactionMember[PlayerId='$nodeid']" , $ns2)
              $selectdelete.ParentNode.RemoveChild($selectdelete)
              $selectdelete = $myXML2.SelectSingleNode("//Factions/Players/dictionary/item[Key='$nodeid']", $ns2)
              $selectdelete.ParentNode.RemoveChild($selectdelete)
              $selectdelete = $myXML2.SelectSingleNode("//Factions/Factions/MyobjectBuilder_Faction/JoinRequests/MyObjectBuilder_FactionMember[PlayerId='$nodeid']" , $ns2)
              $selectdelete.ParentNode.RemoveChild($selectdelete)
              Add-Content -Path $playerspath -Value "Deleting $nodename $nodeid"
              $node.ParentNode.RemoveChild($node)
              $deletedplayer = $deletedplayer + 1
            }
    }

    #factioncleaning
    Add-Content -Path $playerspath -Value "="
    Add-Content -Path $playerspath -Value "Empty Faction Cleanup ========="
    $nodeFactions = $myXML2.SelectNodes("//Factions/Factions/MyObjectBuilder_Faction" , $ns2)
    ForEach($faction in $nodeFactions){
        $membercount = $faction.Members.MybObjectBuilder_FactionMember.count
        $factionid = $faction.FactionId
        If($membercount -eq 0){
            $selectdelete = $myXML2.SelectNodes("//Factions/Requests/MyObjectBuilder_FactionRequests[FactionId='$factionid']" , $ns2)
            ForEach($selected in $selectdelete){
                $selected.ParentNode.RemoveChild($selected)
            }
            $selectdelete = $myXML2.SelectNodes("//Factions/Relations/MyObjectBuilder_FactionRelation[FactionId1='$factionid' or FactionId2='$factionid']" , $ns2)
            ForEach($selected in $selectdelete){
                $selected.ParentNode.RemoveChild($selected)
            }
            Add-Content -Path $playerspath -Value "Deleted faction $($faction.Name) ..."
            $faction.ParentNode.RemoveChild($faction)
            $deletefactions = $deletefactions + 1
        }
    }



        Add-Content -Path $playerspath -Value "="
        Add-Content -Path $playerspath -Value "$counter owned blocks deleted due to owners not logging in." 
        
        Add-Content -Path $playerspath -Value "="
        Add-Content -Path $playerspath -Value "$deletedplayer players removed for not owning anything."

        Add-Content -Path $playerspath -Value "="
        Add-Content -Path $playerspath -Value "$deletefactions empty factions removed."




        $myXML.Save($filePath)
        $myXML2.Save($filePath2)
