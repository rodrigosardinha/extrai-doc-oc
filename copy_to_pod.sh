#!/bin/bash

# Solicitar informações do pod
read -p "Digite o namespace do pod: " NAMESPACE
read -p "Digite o nome do pod: " POD_NAME

# Caminho de origem (onde os arquivos estão)
ORIGEM="/mnt/c/Users/rodri/Downloads/silfaedocs"
# Caminho de destino no pod
DESTINO_NO_POD="/opt/silfaepub-docs"

# Verificar se o diretório local existe
if [ ! -d "$ORIGEM" ]; then
    echo "Erro: Diretório $ORIGEM não encontrado"
    exit 1
fi

echo "Iniciando cópia para o pod $POD_NAME no namespace $NAMESPACE..."

# Copiar todos os arquivos do diretório local para o pod
oc rsync -n "$NAMESPACE" "$ORIGEM/" "$POD_NAME:$DESTINO_NO_POD" --no-perms

echo "Arquivos copiados com sucesso de $ORIGEM para o pod" 