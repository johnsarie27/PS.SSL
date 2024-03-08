# New-CertificateSigningRequest

## SYNOPSIS
Generate new CSR and Private key file

## SYNTAX

### __conf (Default)
```
New-CertificateSigningRequest [-OutputDirectory <String>] [-Days <String>] -ConfigFile <String> [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### __input
```
New-CertificateSigningRequest [-OutputDirectory <String>] [-Days <String>] -CommonName <String>
 [-Country <String>] [-State <String>] [-Locality <String>] [-Organization <String>]
 [-OrganizationalUnit <String>] [-Email <String>] [-SubjectAlternativeName <String[]>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Generate new CSR and Private key file

## EXAMPLES

### EXAMPLE 1
```
New-CertificateSigningRequest -CommonName www.myDomain.com
Creates a new CSR and private key for www.myDomain.com
```

## PARAMETERS

### -OutputDirectory
Output directory for CSR and key file

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: "$HOME\Desktop"
Accept pipeline input: False
Accept wildcard characters: False
```

### -Days
Validity period in days (default is 365)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 365
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConfigFile
Path to configuration template file

```yaml
Type: String
Parameter Sets: __conf
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CommonName
Common Name (CN)

```yaml
Type: String
Parameter Sets: __input
Aliases: CN

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Country
Country Name (C)

```yaml
Type: String
Parameter Sets: __input
Aliases: C

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -State
State or Province Name (ST)

```yaml
Type: String
Parameter Sets: __input
Aliases: ST

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Locality
Locality Name (L)

```yaml
Type: String
Parameter Sets: __input
Aliases: L

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Organization
Organization Name (O)

```yaml
Type: String
Parameter Sets: __input
Aliases: O

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OrganizationalUnit
Organizational Unit Name (OU)

```yaml
Type: String
Parameter Sets: __input
Aliases: OU

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Email
Email Address

```yaml
Type: String
Parameter Sets: __input
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SubjectAlternativeName
Subject Alternative Name (SAN)

```yaml
Type: String[]
Parameter Sets: __input
Aliases: SAN

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
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
Name:      New-CertificateSigningRequest
Author:    Justin Johns
Version:   0.2.0 | Last Edit: 2024-03-08
- 0.2.0 - (2024-03-08) Fixed SupportsShouldProcess, updated SAN input, renamed function
- 0.1.1 - (2022-06-20) Added SupportsShouldProcess
- 0.1.0 - Initial versions
General notes
Example commands
openssl req -newkey rsa:2048 -sha256 -keyout PRIVATEKEY.key -out MYCSR.csr -subj "/C=US/ST=CA/L=Redlands/O=Esri/CN=myDomain.com"
openssl req -new -newkey rsa:2048 -nodes -sha256 -out company_san.csr -keyout company_san.key -config req.conf

## RELATED LINKS
