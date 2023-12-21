# Export-CertificateData

## SYNOPSIS
Short description

## SYNTAX

```
Export-CertificateData [-Path] <String> [[-OutputDirectory] <String>] [-Data] <String> [<CommonParameters>]
```

## DESCRIPTION
Long description

## EXAMPLES

### EXAMPLE 1
```
Export-CertificateData -Path C:\cert.pem -Data Chain
Export the certificate chain for SSL certificate
```

## PARAMETERS

### -Path
Path to PEM file

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputDirectory
Output directory for Certificate Data

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: "$HOME\Desktop"
Accept pipeline input: False
Accept wildcard characters: False
```

### -Data
Data to export

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
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
Name:     Export-CertificateData
Author:   Justin Johns
Version:  0.1.0 | Last Edit: 2022-09-30
- 0.1.0 - Initial version
Comments: \<Comment(s)\>
General notes:

## RELATED LINKS
