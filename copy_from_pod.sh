#!/bin/bash

# Solicitar informações do pod
read -p "Digite o namespace do pod: " NAMESPACE
read -p "Digite o nome do pod: " POD_NAME

# Caminho no pod
CAMINHO_NO_POD="/opt/silfaepub-docs"
# Diretório local de destino
DEST_DIR="/mnt/c/Users/rodri/Downloads/silfaedocs"

# Criar diretório local se não existir
mkdir -p "$DEST_DIR"

echo "Iniciando cópia do pod $POD_NAME no namespace $NAMESPACE..."

# Copiar todos os arquivos do pod para o diretório local
oc rsync -n "$NAMESPACE" "$POD_NAME:$CAMINHO_NO_POD" "$DEST_DIR"

echo "Arquivos copiados com sucesso do pod para $DEST_DIR" 