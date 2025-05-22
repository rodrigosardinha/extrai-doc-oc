# Solicitar informações do pod
$NAMESPACE = Read-Host "Digite o namespace do pod"
$POD_NAME = Read-Host "Digite o nome do pod"

# Caminho no pod
$CAMINHO_NO_POD = "/opt/silfaepub-docs"
# Diretório local de destino
$DEST_DIR = "C:\Users\rodri\Downloads\silfaedocs"

# Criar diretório local se não existir
if (-not (Test-Path $DEST_DIR)) {
    New-Item -ItemType Directory -Path $DEST_DIR | Out-Null
}

Write-Host "Iniciando cópia do pod $POD_NAME no namespace $NAMESPACE..." -ForegroundColor Yellow

# Copiar todos os arquivos do pod para o diretório local
oc rsync -n $NAMESPACE "${POD_NAME}:${CAMINHO_NO_POD}" $DEST_DIR

Write-Host "Arquivos copiados com sucesso do pod para $DEST_DIR" -ForegroundColor Green 