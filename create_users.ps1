<#
SCRIPT: Criação de usuários no Active Directory via CSV

Este script cria usuários no AD utilizando um arquivo CSV.
Ele foi feito de forma genérica para permitir adaptação fácil
para diferentes estruturas de arquivos.

Deve ser rodado no servidor que comtém o serviço do AD

ANTES DE EXECUTAR:
- Ajuste as configurações na seção CONFIGURAÇÕES
- Ajuste o mapeamento de colunas conforme seu CSV
- Certifique-se de que o módulo ActiveDirectory está instalado

Requer permissões para criar usuários no AD.
#>

# ================================
# CONFIGURAÇÕES
# ================================

# Caminho do arquivo CSV de entrada
# ALTERE conforme o local do seu arquivo
$csvFilePath = "C:\AD.csv"

# OU onde os usuários serão criados
# ALTERE para a OU correta do seu domínio
$ouPath = "OU=Usuarios,DC=DOMAIN,DC=corp"

# Domínio usado para gerar o UserPrincipalName
# ALTERE para seu domínio
$domain = "DOMAIN.corp"

# Caminho do relatório de erros
# ALTERE se desejar salvar em outro local
$errorReportPath = "C:\erros_criacao_ad.csv"


# ================================
# MAPEAMENTO DE COLUNAS DO CSV
# ================================
# Aqui você define quais colunas do CSV correspondem
# aos campos utilizados pelo script.

$csvMapping = @{
    LoginColumn    = "RA"      # coluna que contém o login
    NameColumn     = "NOME"    # coluna que contém o nome completo
    PasswordColumn = "CPF"     # coluna que contém a senha inicial
}


# ================================
# VALIDAÇÃO INICIAL
# ================================

if (!(Test-Path $csvFilePath)) {
    Write-Error "Arquivo CSV não encontrado: $csvFilePath"
    exit
}

# Verificar se o módulo AD está disponível
if (!(Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "O módulo ActiveDirectory não está instalado."
    exit
}


# ================================
# INICIALIZAÇÃO
# ================================

$errors = @()

# Carregar CSV
$csvData = Import-Csv -Path $csvFilePath


# ================================
# PROCESSAMENTO DOS USUÁRIOS
# ================================

foreach ($row in $csvData) {

    # Obtém valores dinamicamente conforme mapeamento
    $login = $row.($csvMapping.LoginColumn)
    $nome  = $row.($csvMapping.NameColumn)
    $senha = $row.($csvMapping.PasswordColumn)

    # Validação básica
    if ([string]::IsNullOrEmpty($login) -or [string]::IsNullOrEmpty($nome)) {

        $errors += [PSCustomObject]@{
            Login = $login
            Nome  = $nome
            Erro  = "Login ou nome vazio no CSV"
        }

        continue
    }

    # Parâmetros de criação do usuário
    $newUserParams = @{
        Name              = $nome
        DisplayName       = $nome
        SamAccountName    = $login
        UserPrincipalName = "$login@$domain"
        AccountPassword   = (ConvertTo-SecureString $senha -AsPlainText -Force)
        Enabled           = $true
        Path              = $ouPath
    }

    try {

        New-ADUser @newUserParams -ErrorAction Stop
        Write-Host "Usuário criado: $login"

    }
    catch {

        $errors += [PSCustomObject]@{
            Login = $login
            Nome  = $nome
            Erro  = $_.Exception.Message
        }

    }
}


# ================================
# RELATÓRIO FINAL
# ================================

if ($errors.Count -gt 0) {

    $errors | Export-Csv -Path $errorReportPath -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host "Processo finalizado com erros."
    Write-Host "Relatório salvo em: $errorReportPath"

}
else {

    Write-Host ""
    Write-Host "Processo finalizado sem erros."

}
