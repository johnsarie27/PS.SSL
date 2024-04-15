# Test-Protocol

## SYNOPSIS
Test TLS protocol

## SYNTAX

```
Test-Protocol [-ComputerName] <String> [[-Port] <Int32>] [-Protocol] <String> [<CommonParameters>]
```

## DESCRIPTION
Test TLS protocol

## EXAMPLES

### EXAMPLE 1
```
Test-Protocol -ComputerName mySever.com -Port 443 -Protocl 'TLS 1.2'
Uses openssl to test connecting to myServer.com over port 443 using TLS 1.2
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

### -Protocol
Protocol versions

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
Name:     Test-Protocol
Author:   Justin Johns
Version:  0.1.0 | Last Edit: 2023-12-21
- 0.1.0 - Initial version
Comments:

## RELATED LINKS
