# === CONSTANTES ===
$CAMINHO_NO_POD = "/opt/silfaepub-docs"
$ARQUIVO_LISTA = "silfaedocslist.txt"
$ARQUIVO_LOG = "verificacao_arquivos.log"

# === FUNÇÕES DE VALIDAÇÃO ===
function Verificar-Login-OpenShift {
    Write-Host "🔍 Verificando login no OpenShift..."
    $loginStatus = oc whoami 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro: Não está logado no OpenShift. Por favor, faça login primeiro."
        exit 1
    }
    Write-Host "✅ Logado como: $loginStatus"
}

function Listar-Namespaces {
    Write-Host "📋 Listando namespaces disponíveis..."
    $namespaces = oc get projects -o jsonpath='{.items[*].metadata.name}' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro ao listar namespaces."
        exit 1
    }
    
    $namespacesArray = $namespaces -split ' '
    Write-Host "`nNamespaces disponíveis:"
    for ($i = 0; $i -lt $namespacesArray.Count; $i++) {
        Write-Host "[$i] $($namespacesArray[$i])"
    }
    
    do {
        $escolha = Read-Host "`nDigite o número do namespace desejado"
        $escolha = [int]$escolha
    } while ($escolha -lt 0 -or $escolha -ge $namespacesArray.Count)
    
    return $namespacesArray[$escolha]
}

function Listar-Pods-Running {
    param($namespace)
    
    Write-Host "📋 Listando pods em estado Running no namespace $namespace..."
    $pods = oc get pods -n $namespace -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro ao listar pods."
        exit 1
    }
    
    $podsArray = $pods -split ' '
    if ($podsArray.Count -eq 0) {
        Write-Host "❌ Nenhum pod em estado Running encontrado."
        exit 1
    }
    
    Write-Host "`nPods em estado Running:"
    for ($i = 0; $i -lt $podsArray.Count; $i++) {
        Write-Host "[$i] $($podsArray[$i])"
    }
    
    do {
        $escolha = Read-Host "`nDigite o número do pod desejado"
        $escolha = [int]$escolha
    } while ($escolha -lt 0 -or $escolha -ge $podsArray.Count)
    
    return $podsArray[$escolha]
}

function Verificar-Arquivos-No-Pod {
    param($namespace, $pod)
    
    Write-Host "🔍 Verificando arquivos no pod $pod..."
    
    # Verifica se o diretório existe
    $dirExiste = oc exec -n $namespace $pod -- test -d $CAMINHO_NO_POD 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Diretório $CAMINHO_NO_POD não existe no pod."
        return
    }
    
    # Lê o arquivo de lista
    if (-not (Test-Path $ARQUIVO_LISTA)) {
        Write-Host "❌ Arquivo $ARQUIVO_LISTA não encontrado."
        return
    }
    
    $arquivos = Get-Content $ARQUIVO_LISTA
    Write-Host "`nVerificando arquivos listados em $ARQUIVO_LISTA:"
    
    foreach ($arquivo in $arquivos) {
        Write-Host "`n🔍 Procurando por: $arquivo"
        $resultado = oc exec -n $namespace $pod -- find $CAMINHO_NO_POD -type f -name "*$arquivo*" 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $resultado) {
            Write-Host "✅ Arquivo encontrado:"
            $resultado | ForEach-Object { Write-Host "   $_" }
        } else {
            Write-Host "❌ Arquivo não encontrado"
        }
    }
}

# === INÍCIO DO SCRIPT ===
Write-Host "🚀 Iniciando verificação de arquivos no OpenShift..."

# Verifica login
Verificar-Login-OpenShift

# Lista e seleciona namespace
$namespace = Listar-Namespaces

# Lista e seleciona pod
$pod = Listar-Pods-Running $namespace

# Verifica arquivos no pod
Verificar-Arquivos-No-Pod $namespace $pod

Write-Host "`n✨ Verificação concluída!" 