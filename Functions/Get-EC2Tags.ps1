function Get-EC2Tags {
    param(
        [Parameter(ValueFromPipeline=$true)][PsObject[]]$InputObject,
        [string[]]$ExpandProperty=@("Tags")
    )
    process {
        foreach ($o in $InputObject) {
            foreach ($e in $ExpandProperty) {
                if ($o | Get-Member $e) {
                    foreach($t in $o.$e) {
                        $o | Add-Member -MemberType NoteProperty -Name $t.Key -Value $t.Value -ErrorAction SilentlyContinue -Force
                    }
                }
                $o
            }
        }
    }
}