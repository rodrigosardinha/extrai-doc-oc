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

# Verifica se o arquivo de lista existe
if [ ! -f "silfaedocslist.txt" ]; then
    echo "❌ Arquivo silfaedocslist.txt não encontrado."
    exit 1
fi

# Verifica se o diretório existe no pod
if ! oc exec -n "$NAMESPACE" "$POD_NAME" -- test -d "/opt/silfaepub-docs" &>/dev/null; then
    echo "❌ Diretório /opt/silfaepub-docs não existe no pod."
    exit 1
fi

# Verifica cada arquivo da lista
echo "Verificando arquivos listados em silfaedocslist.txt:"
echo "----------------------------------------"

while IFS= read -r arquivo || [ -n "$arquivo" ]; do
    echo -e "\n🔍 Procurando por: $arquivo"
    if resultado=$(oc exec -n "$NAMESPACE" "$POD_NAME" -- find "/opt/silfaepub-docs" -type f -name "*$arquivo*" 2>/dev/null); then
        if [ -n "$resultado" ]; then
            echo "✅ Arquivo encontrado:"
            echo "$resultado" | while read -r linha; do
                echo "   $linha"
            done
        else
            echo "❌ Arquivo não encontrado"
        fi
    else
        echo "❌ Erro ao procurar arquivo"
    fi
done < "silfaedocslist.txt"

echo "----------------------------------------"
echo "Verificação concluída!" 