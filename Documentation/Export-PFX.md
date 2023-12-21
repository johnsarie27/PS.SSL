# Export-PFX

## SYNOPSIS
Export PFX file

## SYNTAX

```
Export-PFX [[-OutputDirectory] <String>] [-Password] <SecureString> [-Key] <String> [-SignedCSR] <String>
 [[-RootCA] <String>] [[-IntermediateCA] <String>] [-WindowsCompatible] [<CommonParameters>]
```

## DESCRIPTION
Export PFX file from completed CSR, private key, and certificate trust chain

## EXAMPLES

### EXAMPLE 1
```
Export-PFX -Password $secStr -Key .\key.key - SignedCSR .\cert.crt -RootCA .\root.crt
Creates and exports PFX file from private key, signed certificate, and root CA
```

## PARAMETERS

### -OutputDirectory
Output directory for new PFX file

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: "$HOME\Desktop"
Accept pipeline input: False
Accept wildcard characters: False
```

### -Password
Password used to protect exported PFX file

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Key
Path to private key file

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

### -SignedCSR
Path to CA-signed certificate request

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RootCA
Path to root CA public certificate

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IntermediateCA
Path to intermediate CA public certificate

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WindowsCompatible
Export using PBE-SHA1-3DES algorithm

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None.
## OUTPUTS

### System.Object.
## NOTES
General notes
https://man.openbsd.org/openssl.1

## RELATED LINKS
