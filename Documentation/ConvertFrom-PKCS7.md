# ConvertFrom-PKCS7

## SYNOPSIS
Convert PKCS7 formatted certificate

## SYNTAX

```
ConvertFrom-PKCS7 [-Path] <String> [[-OutputDirectory] <String>] [<CommonParameters>]
```

## DESCRIPTION
Convert PKCS7 formatted certificate to non-PKCS7 format

## EXAMPLES

### EXAMPLE 1
```
ConvertFrom-PKCS7 -Path .\myCert.cer -OutputDirectory .\newFolder
Converts a PKCS7 formatted certificate to non-PKCS7 format with .crt extension
```

## PARAMETERS

### -Path
Path to PKCS7 formatted certificate file

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
Output directory path

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None.
## OUTPUTS

### None.
## NOTES
General notes

## RELATED LINKS
