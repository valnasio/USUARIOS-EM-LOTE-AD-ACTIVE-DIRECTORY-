# Caminhos e domínio
$csvFilePath = Join-Path -Path $PSScriptRoot -ChildPath "usuarios.csv"
$ouPath = "OU=Usuarios,DC=dominio,DC=local"
$domain = "dominio.local"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$errorReportPath = Join-Path -Path $PSScriptRoot -ChildPath ("erros_{0}.csv" -f $timestamp)

# Mapeamento de colunas
$csvMapping = @{
    NameColumn     = "NOME"
    PasswordColumn = "DOCUMENTO"
}

# Verifica existência do CSV
if (!(Test-Path $csvFilePath)) {
    Write-Error "Arquivo CSV não encontrado: $csvFilePath"
    exit
}

# Verifica módulo Active Directory
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Módulo ActiveDirectory não disponível"
    exit
}

# Lista de erros
$errors = @()

# Importa dados do CSV
$csvData = Import-Csv -Path $csvFilePath -Delimiter ';'

# Valida conteúdo do CSV
if (!$csvData -or $csvData.Count -eq 0) {
    Write-Warning "CSV vazio"
    exit
}

# Processa registros do CSV
foreach ($row in $csvData) {
    $nomeCompleto = $row.($csvMapping.NameColumn)
    $doc          = $row.($csvMapping.PasswordColumn)

    # Valida campos obrigatórios
    if ([string]::IsNullOrEmpty($nomeCompleto) -or [string]::IsNullOrEmpty($doc)) {
        $errors += [PSCustomObject]@{
            NomeCompleto = $nomeCompleto
            Documento    = $doc
            LoginGerado  = "N/A"
            Erro         = "Dados obrigatórios ausentes"
        }
        Write-Warning "Registro ignorado"
        continue
    }

    # Geração de login
    $partesNome = $nomeCompleto.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
    $loginGerado = ""

    if ($partesNome.Count -ge 2) {
        $primeiroNome = $partesNome[0]
        $ultimoSobrenome = $partesNome[-1]
        $loginGerado = "$($primeiroNome.ToLower()).$($ultimoSobrenome.ToLower())"
        $loginGerado = [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::GetEncoding("Cyrillic").GetBytes($loginGerado))
        $loginGerado = ($loginGerado -replace '[^a-zA-Z0-9\.]', '')
    } elseif ($partesNome.Count -eq 1) {
        $loginGerado = $partesNome[0].ToLower()
        $loginGerado = [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::GetEncoding("Cyrillic").GetBytes($loginGerado))
        $loginGerado = ($loginGerado -replace '[^a-zA-Z0-9\.]', '')
    } else {
        $errors += [PSCustomObject]@{
            NomeCompleto = $nomeCompleto
            Documento    = $doc
            LoginGerado  = "N/A"
            Erro         = "Falha na geração de login"
        }
        Write-Warning "Registro inválido"
        continue
    }

    # Define senha padrão
    $senhaFinal = "Senha@$doc"

    # Parâmetros do usuário
    $newUserParams = @{
        Name                  = $nomeCompleto
        DisplayName           = $nomeCompleto
        SamAccountName        = $loginGerado
        UserPrincipalName     = "$loginGerado@$domain"
        AccountPassword       = (ConvertTo-SecureString $senhaFinal -AsPlainText -Force)
        Enabled               = $true
        Path                  = $ouPath
        ChangePasswordAtLogon = $true
    }

    try {
        # Cria usuário no AD
        New-ADUser @newUserParams -ErrorAction Stop
        Write-Host "Usuário criado: $loginGerado" -ForegroundColor Green
    }
    catch {
        # Registra erro na criação
        $errors += [PSCustomObject]@{
            NomeCompleto = $nomeCompleto
            Documento    = $doc
            LoginGerado  = $loginGerado
            Erro         = $_.Exception.Message
        }
        Write-Error "Erro ao criar usuário: $loginGerado"
    }
}

# Gera relatório de erros
if ($errors.Count -gt 0) {
    $errors | Export-Csv -Path $errorReportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Processo finalizado com erros" -ForegroundColor Yellow
    Write-Host "Relatório: $errorReportPath" -ForegroundColor Yellow
}
else {
    Write-Host "Processo finalizado com sucesso" -ForegroundColor Green
}
