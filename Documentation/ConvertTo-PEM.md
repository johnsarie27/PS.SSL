# ConvertTo-PEM

## SYNOPSIS
Convert PFX/P12 file to PEM file

## SYNTAX

```
ConvertTo-PEM [-PFX] <String> [[-OutputDirectory] <String>] [-Password] <SecureString> [<CommonParameters>]
```

## DESCRIPTION
Convert PFX/P12 file to PEM file including private key

## EXAMPLES

### EXAMPLE 1
```
ConvertTo-PEM -PFX .\myCert.pfx -OutputDirectory .\newFolder -Password $pw
Converts myCert.pfx to myCert.pem exposing all certificate details in plain text
```

## PARAMETERS

### -PFX
Path to PFX file

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
Path to plain text output directory

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

### -Password
Password to PFX file

```yaml
Type: SecureString
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
General notes

## RELATED LINKS
