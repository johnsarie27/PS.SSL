# Test-Cipher

## SYNOPSIS
Test cipher suites

## SYNTAX

```
Test-Cipher [-ComputerName] <String> [[-Port] <Int32>] [-Cipher] <String> [<CommonParameters>]
```

## DESCRIPTION
Test cipher suites

## EXAMPLES

### EXAMPLE 1
```
Test-Cipher -ComputerName myServer.com -Port 443 -Cipher 'ECDHE-RSA-AES128-GCM-SHA256'
Uses openssl to test connecting to myServer.com over port 443 using the cipher 'ECDHE-RSA-AES128-GCM-SHA256'
```

## PARAMETERS

### -ComputerName
Target Computer System

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

### -Cipher
Cipher

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
Name:     Test-Cipher
Author:   Justin Johns
Version:  0.1.0 | Last Edit: 2023-12-21
- 0.1.0 - Initial version
Comments:
https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies

## RELATED LINKS
