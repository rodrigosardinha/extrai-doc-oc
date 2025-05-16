#!/bin/bash

# === CONSTANTES ===
CAMINHO_NO_POD="/opt/silfaepub-docs"
DEST_DIR="/mnt/c/Users/rodri/Downloads/silfaedocs"
ARQUIVO_LISTA="silfaedocslist.txt"
ARQUIVO_LOG="processamento_erros.log"
DEPLOYMENT_CONFIG="api-service"

# === FUNÇÕES DE VALIDAÇÃO ===
validar_entrada() {
    if [ -z "$1" ]; then
        echo "❌ Erro: $2 não pode estar vazio."
        exit 1
    fi
}

validar_pod() {
    if ! oc get pod -n "$NAMESPACE" "$POD" &>/dev/null; then
        echo "❌ Erro: Pod '$POD' não encontrado no namespace '$NAMESPACE'."
        exit 1
    fi
}

validar_arquivo_lista() {
    if [ ! -f "$ARQUIVO_LISTA" ]; then
        echo "❌ Erro: Arquivo '$ARQUIVO_LISTA' não encontrado."
        exit 1
    fi
    if [ ! -s "$ARQUIVO_LISTA" ]; then
        echo "❌ Erro: Arquivo '$ARQUIVO_LISTA' está vazio."
        exit 1
    fi
}

verificar_espaco_disco() {
    local espaco_livre=$(df -P "$DEST_DIR" | awk 'NR==2 {print $4}')
    if [ "$espaco_livre" -lt 1000000 ]; then  # Menos de 1GB livre
        echo "⚠️ Aviso: Espaço em disco baixo no diretório de destino."
        return 1
    fi
    return 0
}

log_erro() {
    local mensagem="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $mensagem" >> "$ARQUIVO_LOG"
}

processar_arquivo() {
    local TRECHO="$1"
    echo "🔍 Processando arquivo com trecho: $TRECHO"
    
    # === ENCONTRA O NOME DO ARQUIVO NO POD PELO TRECHO ===
    echo "🔍 Buscando arquivo no pod..."
    
    # Adiciona verificação de conexão com o pod
    if ! oc get pod -n "$NAMESPACE" "$POD" &>/dev/null; then
        local erro="Pod '$POD' não está acessível no namespace '$NAMESPACE'"
        echo "❌ $erro"
        log_erro "FALHA: $erro"
        return 1
    fi

    # Verifica se o diretório existe no pod
    if ! oc exec -n "$NAMESPACE" "$POD" -- test -d "$CAMINHO_NO_POD" &>/dev/null; then
        local erro="Diretório '$CAMINHO_NO_POD' não existe no pod '$POD'"
        echo "❌ $erro"
        log_erro "FALHA: $erro"
        return 1
    fi

    # Executa o comando find com redirecionamento de erro
    ARQUIVO_NO_POD=$(oc exec -n "$NAMESPACE" "$POD" -- find "$CAMINHO_NO_POD" -type f -name "*$TRECHO*" 2>> "$ARQUIVO_LOG" | head -n 1)

    if [ -z "$ARQUIVO_NO_POD" ]; then
        local erro="Nenhum arquivo encontrado contendo '$TRECHO' em '$CAMINHO_NO_POD' no pod '$POD'"
        echo "❌ $erro"
        log_erro "FALHA: $erro"
        return 1
    fi

    echo "📄 Arquivo encontrado no pod: $ARQUIVO_NO_POD"

    # Verifica se o arquivo existe no pod
    if ! oc exec -n "$NAMESPACE" "$POD" -- test -f "$ARQUIVO_NO_POD" 2>> "$ARQUIVO_LOG"; then
        local erro="Arquivo '$ARQUIVO_NO_POD' não existe no pod ou não tem permissão de leitura"
        echo "❌ $erro"
        log_erro "FALHA: $erro"
        return 1
    fi

    # Extrai o nome base do arquivo
    NOME_BASICO=$(basename "$ARQUIVO_NO_POD")
    ARQUIVO_LOCAL="$DEST_DIR/$NOME_BASICO"

    echo "📦 Copiando arquivo '$NOME_BASICO' do pod..."
    if ! oc cp "$NAMESPACE/$POD:$ARQUIVO_NO_POD" "$ARQUIVO_LOCAL" 2>> "$ARQUIVO_LOG"; then
        local erro="Falha ao copiar o arquivo '$ARQUIVO_NO_POD' do pod"
        echo "❌ $erro"
        log_erro "FALHA: $erro"
        return 1
    fi

    # === DETECTA O TIPO DE ARQUIVO ===
    echo "🔍 Detectando tipo do arquivo..."
    if ! command -v file &>/dev/null; then
        local erro="Comando 'file' não encontrado. Instale o pacote 'file' para continuar"
        echo "❌ $erro"
        log_erro "FALHA: $erro"
        return 1
    fi

    TIPO=$(file --mime-type -b "$ARQUIVO_LOCAL")
    echo "🔍 Tipo MIME detectado: $TIPO"

    # === MAPEIA EXTENSÃO ===
    EXT=""
    case "$TIPO" in
        application/pdf) EXT="pdf" ;;
        text/plain) EXT="txt" ;;
        application/zip) EXT="zip" ;;
        application/gzip) EXT="gz" ;;
        image/jpeg) EXT="jpg" ;;
        image/png) EXT="png" ;;
        application/msword) EXT="doc" ;;
        application/vnd.openxmlformats-officedocument.wordprocessingml.document) EXT="docx" ;;
        application/vnd.ms-excel) EXT="xls" ;;
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet) EXT="xlsx" ;;
        *) EXT="bin" ;;
    esac

    # === RENOMEIA COM EXTENSÃO DETECTADA ===
    ARQUIVO_FINAL="$DEST_DIR/${TRECHO}.${EXT}"
    if ! mv "$ARQUIVO_LOCAL" "$ARQUIVO_FINAL" 2>> "$ARQUIVO_LOG"; then
        local erro="Erro ao renomear o arquivo para '$ARQUIVO_FINAL'"
        echo "❌ $erro"
        log_erro "FALHA: $erro"
        return 1
    fi

    echo "✅ Arquivo salvo como: $ARQUIVO_FINAL"
    log_erro "SUCESSO: Arquivo '$TRECHO' processado e salvo como '$ARQUIVO_FINAL'"
    return 0
}

obter_pod_automaticamente() {
    echo "🔍 Buscando pod do DeploymentConfig $DEPLOYMENT_CONFIG..."
    POD=$(oc get pods -n "$NAMESPACE" -l deploymentconfig=$DEPLOYMENT_CONFIG -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$POD" ]; then
        echo "❌ Erro: Não foi possível encontrar o pod do DeploymentConfig '$DEPLOYMENT_CONFIG' no namespace '$NAMESPACE'."
        exit 1
    fi
    
    echo "✅ Pod encontrado: $POD"
}

# === PERGUNTA OS PARÂMETROS INTERATIVAMENTE SE NÃO FOREM PASSADOS ===
read -p "Informe o namespace do pod: " NAMESPACE
validar_entrada "$NAMESPACE" "Namespace"

# Obtém o pod automaticamente
obter_pod_automaticamente

# === VALIDAÇÃO DO POD ===
validar_pod

# === VERIFICA DIRETÓRIO DE DESTINO ===
if ! mkdir -p "$DEST_DIR"; then
    echo "❌ Erro: Não foi possível criar o diretório de destino '$DEST_DIR'."
    exit 1
fi

# Verifica permissões do diretório de destino
if [ ! -w "$DEST_DIR" ]; then
    echo "❌ Erro: Sem permissão de escrita no diretório de destino '$DEST_DIR'."
    exit 1
fi

# Verifica espaço em disco
verificar_espaco_disco

# === VALIDAÇÃO DO ARQUIVO DE LISTA ===
validar_arquivo_lista

# Inicializa arquivo de log
echo "=== Início do processamento $(date) ===" > "$ARQUIVO_LOG"

# === PROCESSAMENTO EM LOTE ===
echo "📋 Iniciando processamento em lote..."
TOTAL_ARQUIVOS=$(wc -l < "$ARQUIVO_LISTA")
ARQUIVO_ATUAL=0
SUCESSOS=0
FALHAS=0

while IFS= read -r TRECHO || [ -n "$TRECHO" ]; do
    ARQUIVO_ATUAL=$((ARQUIVO_ATUAL + 1))
    echo "🔄 Processando arquivo $ARQUIVO_ATUAL de $TOTAL_ARQUIVOS"
    
    if processar_arquivo "$TRECHO"; then
        SUCESSOS=$((SUCESSOS + 1))
    else
        FALHAS=$((FALHAS + 1))
    fi
    
    echo "----------------------------------------"
done < "$ARQUIVO_LISTA"

echo "📊 Resumo do processamento:"
echo "✅ Arquivos processados com sucesso: $SUCESSOS"
echo "❌ Arquivos com falha: $FALHAS"
echo "📋 Total de arquivos processados: $TOTAL_ARQUIVOS"
echo "📝 Log detalhado disponível em: $ARQUIVO_LOG"
