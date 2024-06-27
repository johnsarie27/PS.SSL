# Export-Base64Certificate

## SYNOPSIS
Convert a byte array to a base64 encoded certificate file

## SYNTAX

```
Export-Base64Certificate [-ByteArray] <Byte[]> [-Path] <String> [<CommonParameters>]
```

## DESCRIPTION
Convert a byte array to a base64 encoded certificate file

## EXAMPLES

### EXAMPLE 1
```
$cert = Get-RemoteSSLCertificate -ComputerName 'example.com'
PS C:\> Export-Base64Certificate -ByteArray $cert.RawData -Path "$HOME\Desktop\example.com.crt"
Convert the remote SSL certificate byte array to a base64 encoded certificate file and save to the desktop
```

## PARAMETERS

### -ByteArray
Byte array

```yaml
Type: Byte[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Path to output certificate file

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None.
## OUTPUTS

### None.
## NOTES
Name:     Export-Base64Certificate
Author:   Justin Johns
Version:  0.1.1 | Last Edit: 2024-06-27
- Version history is captured in repository commit history
Comments: \<Comment(s)\>

## RELATED LINKS
