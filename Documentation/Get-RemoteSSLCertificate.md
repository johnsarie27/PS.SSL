# Get-RemoteSSLCertificate

## SYNOPSIS
Get remote SSL certificate

## SYNTAX

```
Get-RemoteSSLCertificate [-ComputerName] <String[]> [[-Port] <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Get remote SSL certificate

## EXAMPLES

### EXAMPLE 1
```
--- Example 1: Get remote SSL certificate ---
PS C:\> Get-RemoteSSLCertificate -ComputerName "www.microsoft.com"
Get the SSL certificate for www.microsoft.com
```

--- Example 2: Get certificate from multipel sites ---
PS C:\\\> $sites = @('site1.com', 'www.site2.com', 'site3.com', 'www.site4.com')
PS C:\\\> Get-RemoteSSLCertificate -ComputerName $sites | Select-Object NotBefore, NotAfter, Subject
The first command creates an array of multiple websites. The second commands tests each site and returns the expiry info

## PARAMETERS

### -ComputerName
Target Computer System

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Port
TCP Port

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 443
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String.
## OUTPUTS

### System.Object.
## NOTES
General notes
Original code from: https://gist.github.com/jstangroome/5945820
https://docs.microsoft.com/en-us/archive/blogs/parallel_universe_-_ms_tech_blog/reading-a-certificate-off-a-remote-ssl-server-for-troubleshooting-with-powershell

## RELATED LINKS
