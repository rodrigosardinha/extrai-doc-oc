# Solicitar informações do pod
$NAMESPACE = Read-Host "Digite o namespace do pod"
$POD_NAME = Read-Host "Digite o nome do pod"

# Caminho de origem (onde os arquivos estão)
$ORIGEM = "/mnt/c/Users/rodri/Downloads/silfaedocs"
# Caminho de destino no pod
$DESTINO_NO_POD = "/opt/silfaepub-docs"

# Verificar se o diretório local existe
if (-not (Test-Path $ORIGEM)) {
    Write-Host "Erro: Diretório $ORIGEM não encontrado" -ForegroundColor Red
    exit 1
}

Write-Host "Iniciando cópia para o pod $POD_NAME no namespace $NAMESPACE..." -ForegroundColor Yellow

# Copiar todos os arquivos do diretório local para o pod
oc rsync -n $NAMESPACE "$ORIGEM/" "${POD_NAME}:${DESTINO_NO_POD}" --no-perms

Write-Host "Arquivos copiados com sucesso de $ORIGEM para o pod" -ForegroundColor Green 