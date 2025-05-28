#!/bin/bash

# Solicitar informações do pod
read -p "Digite o namespace do pod: " NAMESPACE
read -p "Digite o nome do pod: " POD_NAME

# Caminho do diretório a ser limpo no pod
DIRETORIO_NO_POD="/opt/silfaepub-docs"

echo "ATENÇÃO: Todos os arquivos no diretório $DIRETORIO_NO_POD serão permanentemente apagados e não poderão ser recuperados!"
read -p "Tem certeza que deseja continuar? (s/N): " CONFIRMACAO

if [[ "$CONFIRMACAO" != "s" && "$CONFIRMACAO" != "S" ]]; then
    echo "Operação cancelada pelo usuário."
    exit 1
fi

echo "Iniciando limpeza dos arquivos no diretório $DIRETORIO_NO_POD no pod $POD_NAME no namespace $NAMESPACE..."

# Executar comando para remover apenas os arquivos, mantendo as pastas
oc exec -n "$NAMESPACE" "$POD_NAME" -- find "$DIRETORIO_NO_POD" -type f -delete

echo "Limpeza concluída com sucesso!" 