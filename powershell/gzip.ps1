Function Expand-File
{
    Param(
        $infile,
        $outfile = ($infile -replace '\.gz$','')
    )

    $in = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $in, ([IO.Compression.CompressionMode]::Decompress)

    $buffer = New-Object byte[](1024)
    while($true)
    {
        $read = $gzipstream.Read($buffer, 0, 1024)
        if ($read -le 0)
        {break
        }
        $output.Write($buffer, 0, $read)
    }

    $gzipStream.Close()
    $output.Close()
    $in.Close()
    Remove-Item $infile
}
