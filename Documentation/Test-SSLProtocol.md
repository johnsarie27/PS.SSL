# Test-SSLProtocol

## SYNOPSIS
Test SSL protcols

## SYNTAX

```
Test-SSLProtocol [-ComputerName] <String> [[-Port] <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Test remote website for SSL protcols

## EXAMPLES

### EXAMPLE 1
```
Test-SSLProtocl -ComputerName 'www.mysite.com'
Tests www.mysite.com for access using various SSL/TLS protocols
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
Original code from:
https://dscottraynsford.wordpress.com/2016/12/24/test-website-ssl-certificates-continuously-with-powershell-and-pester/
https://www.sysadmins.lv/blog-en/test-web-server-ssltls-protocol-support-with-powershell.aspx

## RELATED LINKS
