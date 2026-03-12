<#
SCRIPT: Remoção de usuários do Active Directory via CSV

Este script remove usuários do AD utilizando um arquivo CSV.
Ele foi escrito de forma genérica para permitir adaptação
para diferentes estruturas de arquivos.

ANTES DE EXECUTAR:
- Ajuste as configurações na seção CONFIGURAÇÕES
- Ajuste o mapeamento das colunas conforme seu CSV
- Certifique-se de possuir permissão para remover usuários
- Certifique-se de que o módulo ActiveDirectory está instalado
#>


# ================================
# CONFIGURAÇÕES
# ================================

# Caminho do arquivo CSV contendo os usuários a serem removidos
# ALTERE conforme necessário
$csvFilePath = "C:\AD.csv"

# Caminho do relatório de erros
# ALTERE se desejar salvar em outro local
$errorReportPath = "C:\erros_remocao_ad.csv"



# ================================
# MAPEAMENTO DE COLUNAS
# ================================
# Defina aqui qual coluna do CSV contém o login do usuário

$csvMapping = @{
    LoginColumn = "RA"   # ALTERE caso seu CSV utilize outro nome
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

# Importar CSV
$csvData = Import-Csv -Path $csvFilePath



# ================================
# PROCESSAMENTO
# ================================

foreach ($row in $csvData) {

    $login = $row.($csvMapping.LoginColumn)

    if ([string]::IsNullOrEmpty($login)) {

        $errors += [PSCustomObject]@{
            Login = $login
            Erro  = "Login vazio no CSV"
        }

        continue
    }

    try {

        $user = Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction Stop

        if ($user) {

            Remove-ADUser -Identity $user -Confirm:$false -ErrorAction Stop
            Write-Host "Usuário removido: $login"

        }
        else {

            $errors += [PSCustomObject]@{
                Login = $login
                Erro  = "Usuário não encontrado no AD"
            }

        }

    }
    catch {

        $errors += [PSCustomObject]@{
            Login = $login
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
    Write-Host "Exclusão de usuários concluída sem erros."

}
