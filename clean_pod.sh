#!/bin/bash

# Solicitar informações do pod
read -p "Digite o namespace do pod: " NAMESPACE
read -p "Digite o nome do pod: " POD_NAME

# Caminho do diretório a ser limpo no pod
DIRETORIO_NO_POD="/opt/silfaepub-docs"

echo "Iniciando limpeza dos arquivos no diretório $DIRETORIO_NO_POD no pod $POD_NAME no namespace $NAMESPACE..."

# Executar comando para remover apenas os arquivos, mantendo as pastas
oc exec -n "$NAMESPACE" "$POD_NAME" -- find "$DIRETORIO_NO_POD" -type f -delete

echo "Limpeza concluída com sucesso!" 