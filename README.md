# Extrai Doc OC

Script PowerShell para extrair documentos de pods no OpenShift, com detecção automática de tipo de arquivo.

## Requisitos

- PowerShell 7 ou superior
- OpenShift CLI (oc) instalado e configurado
- Acesso ao cluster OpenShift

## Como usar

1. Clone este repositório:
```bash
git clone https://github.com/seu-usuario/extrai-doc-oc.git
cd extrai-doc-oc
```

2. Crie um arquivo de texto com os IDs dos documentos a serem extraídos (um por linha):
```bash
echo "ID_DO_DOCUMENTO" > silfaedocslist.txt
```

3. Execute o script:
```powershell
.\extrai-doc-oc.ps1
```

4. Quando solicitado, informe o namespace do pod.

## Funcionalidades

- Extração automática de documentos de pods no OpenShift
- Detecção automática do tipo de arquivo pelo conteúdo
- Renomeação automática com a extensão correta
- Log detalhado do processamento
- Resumo do processamento ao final

## Tipos de arquivo suportados

- PDF (.pdf)
- ZIP (.zip)
- JPEG (.jpg)
- PNG (.png)
- DOC (.doc)
- RAR (.rar)
- GIF (.gif)
- MP3 (.mp3)
- 7Z (.7z)
- Outros tipos são salvos como .bin

## Logs

O script gera um arquivo de log `processamento_erros.log` com detalhes do processamento.

## Contribuindo

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Crie um Pull Request 