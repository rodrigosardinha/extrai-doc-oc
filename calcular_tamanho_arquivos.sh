#!/bin/bash

# Verifica se está logado no OpenShift
if ! oc whoami &>/dev/null; then
    echo "Realizando login automático no OpenShift..."
    oc login --token=sha256~ZP8azFm7voU4t-yWjxP_8BRh8iQy1N_gacq1ayasFVE --server=https://api.ocp.rio.gov.br:6443
    if [ $? -ne 0 ]; then
        echo "Erro ao realizar login. Por favor, verifique suas credenciais."
        exit 1
    fi
    echo "Login realizado com sucesso!"
fi

# Lista todos os projetos disponíveis
echo "Projetos disponíveis:"
echo "----------------------------------------"
oc projects | grep -v "^You have" | grep -v "^Using" | grep -v "^$" | sed 's/^  \* //' | sed 's/^    //' | awk '{print NR") " $1}'
echo "----------------------------------------"

# Solicita a seleção do projeto
read -p "Digite o número do projeto que deseja utilizar: " NAMESPACE_NUMBER

# Obtém o nome do projeto selecionado
NAMESPACE=$(oc projects | grep -v "^You have" | grep -v "^Using" | grep -v "^$" | sed 's/^  \* //' | sed 's/^    //' | awk '{print $1}' | sed -n "${NAMESPACE_NUMBER}p")

if [ -z "$NAMESPACE" ]; then
    echo "Número de projeto inválido!"
    exit 1
fi

echo "Usando projeto: $NAMESPACE"

# Lista todos os pods em status Running
echo "Pods disponíveis em status Running:"
echo "----------------------------------------"
oc get pods -n $NAMESPACE | grep Running | awk '{print NR") " $1}'
echo "----------------------------------------"

# Solicita a seleção do pod
read -p "Digite o número do pod que deseja utilizar: " POD_NUMBER

# Obtém o nome do pod selecionado
POD_NAME=$(oc get pods -n $NAMESPACE | grep Running | sed -n "${POD_NUMBER}p" | awk '{print $1}')

if [ -z "$POD_NAME" ]; then
    echo "Número de pod inválido!"
    exit 1
fi

echo "Usando pod: $POD_NAME"

# Função para somar todos os valores em M
somar_valores() {
    local total=0
    while read -r linha; do
        if [[ $linha =~ ([0-9]+)M$ ]]; then
            total=$((total + ${BASH_REMATCH[1]}))
        fi
    done
    echo "${total}M"
}

# Função para converter para a unidade mais apropriada
converter_unidade() {
    local valor=$1
    local unidade=${valor: -1}
    local numero=${valor%[KMGTP]}
    
    case $unidade in
        M)
            if (( $(echo "$numero >= 1024" | bc -l) )); then
                echo "$(echo "scale=2; $numero/1024" | bc)G"
            else
                echo "${valor}"
            fi
            ;;
        G)
            if (( $(echo "$numero >= 1024" | bc -l) )); then
                echo "$(echo "scale=2; $numero/1024" | bc)T"
            else
                echo "${valor}"
            fi
            ;;
        T)
            if (( $(echo "$numero >= 1024" | bc -l) )); then
                echo "$(echo "scale=2; $numero/1024" | bc)P"
            else
                echo "${valor}"
            fi
            ;;
        *)
            echo "${valor}"
            ;;
    esac
}

# Calcula o tamanho dos arquivos com sufixo -draf
TAMANHO_DRAF=$(oc exec $POD_NAME -n $NAMESPACE -- find /opt/silfaepub-docs -type f -name "*-draf" -exec du -ch {} + | grep total | awk '{print $1}' | somar_valores)
TAMANHO_DRAF=$(converter_unidade "$TAMANHO_DRAF")

# Calcula o tamanho dos outros arquivos (excluindo os -draf)
TAMANHO_OUTROS=$(oc exec $POD_NAME -n $NAMESPACE -- find /opt/silfaepub-docs -type f ! -name "*-draf" -exec du -ch {} + | grep total | awk '{print $1}' | somar_valores)
TAMANHO_OUTROS=$(converter_unidade "$TAMANHO_OUTROS")

# Conta o número de arquivos de cada tipo
NUM_ARQUIVOS_DRAF=$(oc exec $POD_NAME -n $NAMESPACE -- find /opt/silfaepub-docs -type f -name "*-draf" | wc -l)
NUM_ARQUIVOS_OUTROS=$(oc exec $POD_NAME -n $NAMESPACE -- find /opt/silfaepub-docs -type f ! -name "*-draf" | wc -l)
TOTAL_ARQUIVOS=$((NUM_ARQUIVOS_DRAF + NUM_ARQUIVOS_OUTROS))

# Exibe os resultados
echo "----------------------------------------"
echo "Quantidade de arquivos:"
echo "Arquivos com sufixo -draf: $NUM_ARQUIVOS_DRAF"
echo "Outros arquivos: $NUM_ARQUIVOS_OUTROS"
echo "Total de arquivos: $TOTAL_ARQUIVOS"
echo "----------------------------------------"
echo "Tamanho dos arquivos:"
echo "Arquivos com sufixo -draf: $TAMANHO_DRAF"
echo "Outros arquivos: $TAMANHO_OUTROS"
echo "----------------------------------------"

# Função para converter tamanho para bytes
converter_para_bytes() {
    local tamanho=$1
    local unidade=${tamanho: -1}
    local valor=${tamanho%[KMGTP]}
    
    case $unidade in
        K) echo "$(echo "$valor * 1024" | bc)" ;;
        M) echo "$(echo "$valor * 1024 * 1024" | bc)" ;;
        G) echo "$(echo "$valor * 1024 * 1024 * 1024" | bc)" ;;
        T) echo "$(echo "$valor * 1024 * 1024 * 1024 * 1024" | bc)" ;;
        P) echo "$(echo "$valor * 1024 * 1024 * 1024 * 1024 * 1024" | bc)" ;;
        *) echo "$valor" ;;
    esac
}

# Converte os tamanhos para bytes
TAMANHO_DRAF_BYTES=$(converter_para_bytes "$TAMANHO_DRAF")
TAMANHO_OUTROS_BYTES=$(converter_para_bytes "$TAMANHO_OUTROS")

# Calcula o total em bytes
TOTAL_BYTES=$(echo "$TAMANHO_DRAF_BYTES + $TAMANHO_OUTROS_BYTES" | bc)

# Converte o total para formato legível
if (( $(echo "$TOTAL_BYTES >= 1125899906842624" | bc -l) )); then
    TOTAL_GERAL=$(echo "scale=2; $TOTAL_BYTES/1125899906842624" | bc)"P"
elif (( $(echo "$TOTAL_BYTES >= 1099511627776" | bc -l) )); then
    TOTAL_GERAL=$(echo "scale=2; $TOTAL_BYTES/1099511627776" | bc)"T"
elif (( $(echo "$TOTAL_BYTES >= 1073741824" | bc -l) )); then
    TOTAL_GERAL=$(echo "scale=2; $TOTAL_BYTES/1073741824" | bc)"G"
elif (( $(echo "$TOTAL_BYTES >= 1048576" | bc -l) )); then
    TOTAL_GERAL=$(echo "scale=2; $TOTAL_BYTES/1048576" | bc)"M"
elif (( $(echo "$TOTAL_BYTES >= 1024" | bc -l) )); then
    TOTAL_GERAL=$(echo "scale=2; $TOTAL_BYTES/1024" | bc)"K"
else
    TOTAL_GERAL="${TOTAL_BYTES}B"
fi

echo "Total geral: $TOTAL_GERAL"
echo "----------------------------------------" 