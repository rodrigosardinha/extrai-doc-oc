# === CONSTANTES ===
$CAMINHO_NO_POD = "/opt/silfaepub-docs"
$DEST_DIR = "C:\Users\rodri\Downloads\silfaedocs"
$ARQUIVO_LISTA = "silfaedocslist.txt"
$ARQUIVO_LOG = "processamento_erros.log"
$DEPLOYMENT_CONFIG = "api-service"

# Mapeamento de tipos MIME para extensões
$MIME_TO_EXTENSION = @{
    'application/pdf' = '.pdf'
    'application/msword' = '.doc'
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' = '.docx'
    'application/vnd.ms-excel' = '.xls'
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' = '.xlsx'
    'text/plain' = '.txt'
    'image/jpeg' = '.jpg'
    'image/png' = '.png'
    'application/zip' = '.zip'
    'application/xml' = '.xml'
    'text/html' = '.html'
    'application/json' = '.json'
}

Write-Host "🚀 Iniciando script..."
Write-Host "📁 Diretório atual: $(Get-Location)"
Write-Host "📄 Arquivo de lista: $ARQUIVO_LISTA"
Write-Host "📁 Diretório de destino: $DEST_DIR"

# === FUNÇÕES DE VALIDAÇÃO ===
function Validar-Entrada {
    param($valor, $descricao)
    if ([string]::IsNullOrEmpty($valor)) {
        Write-Host "❌ Erro: $descricao não pode estar vazio."
        exit 1
    }
}

function Validar-Pod {
    param($pod, $namespace)
    $podExiste = oc get pod -n $namespace $pod 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro: Pod '$pod' não encontrado no namespace '$namespace'."
        exit 1
    }
}

function Validar-ArquivoLista {
    if (-not (Test-Path $ARQUIVO_LISTA)) {
        Write-Host "❌ Erro: Arquivo '$ARQUIVO_LISTA' não encontrado."
        exit 1
    }
    if ((Get-Item $ARQUIVO_LISTA).length -eq 0) {
        Write-Host "❌ Erro: Arquivo '$ARQUIVO_LISTA' está vazio."
        exit 1
    }
}

function Verificar-EspacoDisco {
    $espacoLivre = (Get-PSDrive C).Free
    if ($espacoLivre -lt 1GB) {
        Write-Host "⚠️ Aviso: Espaço em disco baixo no diretório de destino."
        return $false
    }
    return $true
}

function Log-Erro {
    param($mensagem)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $ARQUIVO_LOG -Value "[$timestamp] $mensagem"
}

function Obter-TipoArquivo {
    param($arquivoNoPod)
    
    Write-Host "🔍 Verificando tipo do arquivo..."
    $tipoArquivo = oc exec -n $NAMESPACE $POD -- file $arquivoNoPod 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Não foi possível determinar o tipo do arquivo. Usando extensão padrão."
        return ".bin"
    }
    
    Write-Host "📄 Tipo do arquivo detectado: $tipoArquivo"
    
    # Mapeamento de descrições do comando file para extensões
    if ($tipoArquivo -match "PDF document") {
        return ".pdf"
    } elseif ($tipoArquivo -match "Microsoft Word") {
        return ".doc"
    } elseif ($tipoArquivo -match "Microsoft Excel") {
        return ".xls"
    } elseif ($tipoArquivo -match "ASCII text") {
        return ".txt"
    } elseif ($tipoArquivo -match "JPEG image") {
        return ".jpg"
    } elseif ($tipoArquivo -match "PNG image") {
        return ".png"
    } elseif ($tipoArquivo -match "Zip archive") {
        return ".zip"
    } elseif ($tipoArquivo -match "XML") {
        return ".xml"
    } elseif ($tipoArquivo -match "HTML") {
        return ".html"
    } elseif ($tipoArquivo -match "JSON") {
        return ".json"
    }
    
    Write-Host "⚠️ Tipo de arquivo não mapeado. Usando extensão padrão."
    return ".bin"
}

function Detectar-Extensao-Local {
    param($arquivoLocal)
    $fs = [System.IO.File]::OpenRead($arquivoLocal)
    $bytes = New-Object byte[] 8
    $fs.Read($bytes, 0, 8) | Out-Null
    $fs.Close()
    $hex = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ""

    switch -regex ($hex) {
        '^25504446' { return '.pdf' } # PDF
        '^504B0304' { return '.zip' } # ZIP, DOCX, XLSX, ODT, etc
        '^FFD8FF'   { return '.jpg' } # JPEG
        '^89504E47' { return '.png' } # PNG
        '^D0CF11E0' { return '.doc' } # DOC, XLS (antigos)
        '^52617221' { return '.rar' } # RAR
        '^47494638' { return '.gif' } # GIF
        '^494433'   { return '.mp3' } # MP3
        '^377ABCAF271C' { return '.7z' } # 7z
        default     { return '.bin' }
    }
}

function Processar-Arquivo {
    param($trecho)
    Write-Host "🔍 Processando arquivo com trecho: $trecho"
    
    # === ENCONTRA O NOME DO ARQUIVO NO POD PELO TRECHO ===
    Write-Host "🔍 Buscando arquivo no pod..."
    
    # Adiciona verificação de conexão com o pod
    $podExiste = oc get pod -n $NAMESPACE $POD 2>&1
    if ($LASTEXITCODE -ne 0) {
        $erro = "Pod '$POD' não está acessível no namespace '$NAMESPACE'"
        Write-Host "❌ $erro"
        Log-Erro "FALHA: $erro"
        return $false
    }

    # Verifica se o diretório existe no pod
    $dirExiste = oc exec -n $NAMESPACE $POD -- test -d $CAMINHO_NO_POD 2>&1
    if ($LASTEXITCODE -ne 0) {
        $erro = "Diretório '$CAMINHO_NO_POD' não existe no pod '$POD'"
        Write-Host "❌ $erro"
        Log-Erro "FALHA: $erro"
        return $false
    }

    # Executa o comando find para buscar arquivos que contenham o trecho no nome
    $ARQUIVO_NO_POD = oc exec -n $NAMESPACE $POD -- find $CAMINHO_NO_POD -type f -name "*$trecho*" 2>&1 | Select-Object -First 1

    if ([string]::IsNullOrEmpty($ARQUIVO_NO_POD)) {
        $erro = "Nenhum arquivo encontrado contendo '$trecho' em '$CAMINHO_NO_POD' no pod '$POD'"
        Write-Host "❌ $erro"
        Log-Erro "FALHA: $erro"
        return $false
    }

    Write-Host "🔍 Verificando se o arquivo existe no pod..."
    $verificaArquivo = oc exec -n $NAMESPACE $POD -- ls -l $ARQUIVO_NO_POD 2>&1
    if ($LASTEXITCODE -ne 0) {
        $erro = "Arquivo '$ARQUIVO_NO_POD' não existe no pod ou não tem permissão de leitura"
        Write-Host "❌ $erro"
        Log-Erro "FALHA: $erro"
        return $false
    }
    Write-Host "✅ Arquivo encontrado no pod: $verificaArquivo"

    # Extrai o nome base do arquivo (sem extensão)
    $NOME_BASICO = Split-Path $ARQUIVO_NO_POD -Leaf
    $NOME_BASICO = [System.IO.Path]::GetFileNameWithoutExtension($NOME_BASICO)
    $ARQUIVO_LOCAL = Join-Path $DEST_DIR $NOME_BASICO

    # Copiar o arquivo do pod
    Write-Host "📦 Copiando arquivo '$trecho' do pod..."
    $comandoRsync = "$POD`:$ARQUIVO_NO_POD"
    Write-Host "Comando oc rsync: oc rsync -n $NAMESPACE $comandoRsync $DEST_DIR"
    Log-Erro "Comando oc rsync: oc rsync -n $NAMESPACE $comandoRsync $DEST_DIR"
    
    # Executa o comando oc rsync
    $copiaSaida = oc rsync -n $NAMESPACE $comandoRsync $DEST_DIR 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        $erro = "Falha ao copiar o arquivo '$ARQUIVO_NO_POD' do pod. Saída do comando: $copiaSaida"
        Write-Host "❌ $erro"
        Log-Erro "FALHA: $erro"
        return $false
    }

    # Detecta a extensão pelo conteúdo local
    $arquivoTemp = Join-Path $DEST_DIR (Split-Path $ARQUIVO_NO_POD -Leaf)
    if (Test-Path $arquivoTemp) {
        $extensao = Detectar-Extensao-Local $arquivoTemp
        $ARQUIVO_LOCAL_FINAL = "$ARQUIVO_LOCAL$extensao"
        Move-Item -Path $arquivoTemp -Destination $ARQUIVO_LOCAL_FINAL -Force
        Write-Host "✅ Arquivo salvo como: $ARQUIVO_LOCAL_FINAL"
        Log-Erro "SUCESSO: Arquivo '$trecho' processado e salvo como '$ARQUIVO_LOCAL_FINAL'"
    } else {
        Write-Host "❌ Arquivo não encontrado localmente após cópia."
        Log-Erro "FALHA: Arquivo '$trecho' não encontrado localmente após cópia."
        return $false
    }
    return $true
}

function Obter-PodAutomaticamente {
    Write-Host "🔍 Buscando pod do DeploymentConfig $DEPLOYMENT_CONFIG..."
    $global:POD = oc get pods -n $NAMESPACE -l deploymentconfig=$DEPLOYMENT_CONFIG -o jsonpath='{.items[0].metadata.name}' 2>$null
    
    if ([string]::IsNullOrEmpty($POD)) {
        Write-Host "❌ Erro: Não foi possível encontrar o pod do DeploymentConfig '$DEPLOYMENT_CONFIG' no namespace '$NAMESPACE'."
        exit 1
    }
    
    Write-Host "✅ Pod encontrado: $POD"
}

# === PERGUNTA OS PARÂMETROS INTERATIVAMENTE ===
Write-Host "📝 Solicitando namespace..."
$NAMESPACE = Read-Host "Informe o namespace do pod"
Write-Host "📝 Namespace informado: $NAMESPACE"
Validar-Entrada $NAMESPACE "Namespace"

# Obtém o pod automaticamente
Write-Host "🔍 Obtendo pod automaticamente..."
Obter-PodAutomaticamente

# === VALIDAÇÃO DO POD ===
Write-Host "🔍 Validando pod..."
Validar-Pod $POD $NAMESPACE

# === VERIFICA DIRETÓRIO DE DESTINO ===
Write-Host "🔍 Verificando diretório de destino..."
if (-not (Test-Path $DEST_DIR)) {
    Write-Host "📁 Criando diretório de destino..."
    New-Item -ItemType Directory -Path $DEST_DIR -Force | Out-Null
}

# Verifica permissões do diretório de destino
Write-Host "🔍 Verificando permissões do diretório..."
if (-not (Test-Path $DEST_DIR -PathType Container)) {
    Write-Host "❌ Erro: Diretório de destino '$DEST_DIR' não é um diretório válido."
    exit 1
}

# Verifica espaço em disco
Write-Host "🔍 Verificando espaço em disco..."
Verificar-EspacoDisco

# === VALIDAÇÃO DO ARQUIVO DE LISTA ===
Write-Host "🔍 Validando arquivo de lista..."
Validar-ArquivoLista

# Inicializa arquivo de log
Write-Host "📝 Inicializando arquivo de log..."
"=== Início do processamento $(Get-Date) ===" | Out-File $ARQUIVO_LOG

# === PROCESSAMENTO EM LOTE ===
Write-Host "📋 Iniciando processamento em lote..."
$TOTAL_ARQUIVOS = (Get-Content $ARQUIVO_LISTA).Count
Write-Host "📊 Total de arquivos a processar: $TOTAL_ARQUIVOS"
$ARQUIVO_ATUAL = 0
$SUCESSOS = 0
$FALHAS = 0

Write-Host "📄 Lendo arquivo de lista..."
Get-Content $ARQUIVO_LISTA | ForEach-Object {
    $ARQUIVO_ATUAL++
    Write-Host "🔄 Processando arquivo $ARQUIVO_ATUAL de $TOTAL_ARQUIVOS"
    Write-Host "🔍 Trecho a buscar: $_"
    
    if (Processar-Arquivo $_) {
        $SUCESSOS++
    } else {
        $FALHAS++
    }
    
    Write-Host "----------------------------------------"
}

Write-Host "📊 Resumo do processamento:"
Write-Host "✅ Arquivos processados com sucesso: $SUCESSOS"
Write-Host "❌ Arquivos com falha: $FALHAS"
Write-Host "📋 Total de arquivos processados: $TOTAL_ARQUIVOS"
Write-Host "📝 Log detalhado disponível em: $ARQUIVO_LOG" 